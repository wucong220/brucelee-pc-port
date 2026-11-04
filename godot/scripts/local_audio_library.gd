extends RefCounted
## Explicit local audio library — resolver API (isolated implementation).
##
## The manifest (res://data/local_audio_library.json) is an EXPLICIT allowlist:
##   cue_key (lowercase WAV basename) -> ONE exact local WAV + pinned SHA-256.
## It contains the 38 unchanged audio/sfx files plus 13 proven extensions whose
## exact data.zpak WAVs were located and proved byte/SHA-256 identical to the
## package copies.  No entry exists for an unproven or missing file.
##
## Contract (fail closed):
##   * configure() preflights EVERY entry: existence, RIFF/WAVE header, pinned
##     SHA-256, AudioStreamWAV decode, non-zero length.  One failure => no
##     streams at all, configured=false, fail_closed=true, explicit error.
##   * resolve() never guesses a path, never substitutes a "similar" WAV and
##     never returns a stream for an unknown/unverified cue.  It returns {}
##     with an explicit error instead.
##   * voice rows (is_voice=true) are out of scope for this SFX library.
##
## Proposed integration call points (see patch/README.md, NOT applied here):
##   main.gd::_play_sfx_cues()  -> one extra lookup after _sfx_audio.get(file)
##   main.gd::_load_combat_sfx()-> load the 13 extension streams separately
##   sfx_music_map.gd           -> companion EXTENDED_SFX_ACTIONS table
##
## This file is delivered under the isolated output directory only; the shared
## worktree is never written to.

const MANIFEST_PATH: String = "res://data/local_audio_library.json"
const SCHEMA: String = "unreachable_sfx_local_audio_library_v1"
const ENV_ROOT: String = "BRUCELEE_LOCAL_AUDIO_ROOT"
const FRAME_RATE: float = 30.0

var data: Dictionary = {}
var root_path: String = ""
var configured: bool = false
var fail_closed: bool = true
var error: String = ""
var play_log: Array = []

var _streams: Dictionary = {}


func load_manifest(path: String = MANIFEST_PATH) -> bool:
	_reset_runtime()
	error = ""
	data = {}
	if not FileAccess.file_exists(path):
		return _fail("local audio library manifest missing: " + path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return _fail("local audio library manifest is not an object: " + path)
	var doc: Dictionary = parsed
	if String(doc.get("schema", "")) != SCHEMA:
		return _fail("unexpected manifest schema: " + String(doc.get("schema", "")))
	var entries: Variant = doc.get("entries", {})
	if not (entries is Dictionary) or (entries as Dictionary).is_empty():
		return _fail("manifest entries are missing or empty")
	var seen: Dictionary = {}
	for key: Variant in (entries as Dictionary):
		var cue_key: String = String(key)
		var row: Variant = (entries as Dictionary)[key]
		if not (row is Dictionary):
			return _fail("manifest entry is not an object: " + cue_key)
		var info: Dictionary = row
		if String(info.get("cue_key", "")) != cue_key:
			return _fail("manifest cue_key mismatch: " + cue_key)
		if String(info.get("local_path", "")).is_empty():
			return _fail("manifest local_path empty: " + cue_key)
		var sha: String = String(info.get("sha256", "")).to_lower()
		if sha.length() != 64:
			return _fail("manifest sha256 incomplete: " + cue_key)
		if seen.has(cue_key):
			return _fail("duplicate manifest cue_key: " + cue_key)
		seen[cue_key] = true
	data = doc
	return true


## Configure from an explicit root, BRUCELEE_LOCAL_AUDIO_ROOT, or the
## project-local audio snapshot (res://audio/<local_path>).
func configure(explicit_root: String = "") -> bool:
	if data.is_empty() and not load_manifest():
		return false
	_reset_runtime()
	root_path = _resolve_root(explicit_root)
	if root_path.is_empty():
		return _fail("local audio root is empty")
	if not DirAccess.dir_exists_absolute(root_path):
		return _fail("local audio root missing: " + root_path)
	var entries: Dictionary = data.get("entries", {})
	var loaded: Dictionary = {}
	for key: Variant in entries:
		var cue_key: String = String(key)
		var info: Dictionary = entries[key]
		var relative: String = String(info.get("local_path", ""))
		var expected: String = String(info.get("sha256", "")).to_lower()
		var path: String = root_path.path_join(relative)
		if not FileAccess.file_exists(path):
			return _fail("required WAV missing for %s: %s" % [cue_key, path])
		if not _has_riff_wave_header(path):
			return _fail("required WAV is not RIFF/WAVE for %s: %s" % [cue_key, path])
		var actual: String = _sha256_file(path)
		if actual.is_empty():
			return _fail("required WAV could not be hashed for %s: %s" % [cue_key, path])
		if actual != expected:
			return _fail("required WAV hash mismatch for %s: %s != %s" % [cue_key, actual, expected])
		var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
		if stream == null:
			return _fail("required WAV did not decode for %s: %s" % [cue_key, path])
		if stream.get_length() <= 0.0:
			return _fail("required WAV has zero length for %s: %s" % [cue_key, path])
		loaded[cue_key] = stream
	_streams = loaded
	configured = true
	fail_closed = false
	error = ""
	return true


func is_configured() -> bool:
	return configured


func is_fail_closed() -> bool:
	return fail_closed


func get_error() -> String:
	return error


func entry_count() -> int:
	return int(data.get("entry_count", 0))


func cue_keys() -> Array:
	if not (data.get("entries", {}) is Dictionary):
		return []
	return (data.get("entries", {}) as Dictionary).keys()


func entry_for(cue_key: String) -> Dictionary:
	var entries: Variant = data.get("entries", {})
	if not (entries is Dictionary):
		return {}
	var row: Variant = (entries as Dictionary).get(cue_key.to_lower(), {})
	return row if row is Dictionary else {}


## Verified stream for a cue key.  Used by the proposed main.gd integration to
## populate a separate extension dictionary; never returns an unverified stream.
func stream_for(cue_key: String) -> AudioStream:
	if not configured:
		return null
	return _streams.get(cue_key.to_lower(), null)


## Resolve ONE recovered sounds[] row.  Returns {} (no sound) on any failure.
## The returned Dictionary carries the verbatim frame/volume/unique so the
## caller can schedule the cue at frame/30 s without inventing timing.
func resolve(row: Dictionary) -> Dictionary:
	if not configured:
		return _reject("resolver is not configured")
	if bool(row.get("is_voice", false)):
		return _reject("voice rows are not resolved by the SFX library")
	var cue_key: String = _cue_key(String(row.get("file", "")))
	if cue_key.is_empty():
		return _reject("row has no WAV filename")
	if not (data.get("entries", {}) as Dictionary).has(cue_key):
		return _reject("unknown cue key (not in explicit library): " + cue_key)
	var stream: AudioStream = _streams.get(cue_key, null)
	if stream == null:
		return _reject("no verified stream for cue key: " + cue_key)
	var info: Dictionary = entry_for(cue_key)
	var path: String = root_path.path_join(String(info.get("local_path", "")))
	play_log.append({"cue_key": cue_key, "path": path,
			"sha256": String(info.get("sha256", ""))})
	return {
		"cue_key": cue_key,
		"stream": stream,
		"path": path,
		"local_path": String(info.get("local_path", "")),
		"sha256": String(info.get("sha256", "")),
		"kind": String(info.get("kind", "")),
		"frame": row.get("frame", null),
		"volume": row.get("volume", 1.0),
		"unique": String(row.get("unique", "")),
	}


## Strict batch: ANY unresolved row returns an empty Array (no partial playback).
func resolve_all(rows: Array) -> Array:
	var out: Array = []
	for value: Variant in rows:
		if not (value is Dictionary):
			return _reject_all("row is not a Dictionary")
		var resolved: Dictionary = resolve(value)
		if resolved.is_empty():
			return _reject_all("row failed to resolve: " + String((value as Dictionary).get("file", "")))
		out.append(resolved)
	return out


## frame / 30 s, matching SfxMusicMap.FRAME_RATE and VoiceCueTiming.FRAME_RATE.
func cue_delay(row: Dictionary) -> float:
	return maxf(float(row.get("frame", 0)), 0.0) / FRAME_RATE


func _cue_key(raw: String) -> String:
	var normalized: String = raw.strip_edges().replace("\\", "/")
	var slash: int = normalized.rfind("/")
	if slash >= 0:
		normalized = normalized.substr(slash + 1)
	return normalized.to_lower()


func _resolve_root(explicit_root: String) -> String:
	var candidate: String = explicit_root.strip_edges()
	if not candidate.is_empty():
		return candidate
	var env: String = OS.get_environment(ENV_ROOT)
	if not env.is_empty():
		return env
	return ProjectSettings.globalize_path("res://")


func _has_riff_wave_header(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var head: PackedByteArray = file.get_buffer(12)
	file.close()
	if head.size() < 12:
		return false
	return (head.slice(0, 4).get_string_from_ascii() == "RIFF"
			and head.slice(8, 12).get_string_from_ascii() == "WAVE")


func _sha256_file(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var ctx: HashingContext = HashingContext.new()
	if ctx.start(HashingContext.HASH_SHA256) != OK:
		return ""
	while not file.eof_reached():
		var chunk: PackedByteArray = file.get_buffer(65536)
		if chunk.size() > 0 and ctx.update(chunk) != OK:
			return ""
	file.close()
	return ctx.finish().hex_encode().to_lower()


func _fail(message: String) -> bool:
	error = message
	configured = false
	fail_closed = true
	_streams.clear()
	return false


func _reject(message: String) -> Dictionary:
	error = message
	fail_closed = true
	return {}


func _reject_all(message: String) -> Array:
	error = message
	fail_closed = true
	return []


func _reset_runtime() -> void:
	_streams.clear()
	play_log.clear()
	configured = false
	fail_closed = true
	error = ""

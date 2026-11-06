extends SceneTree

## Headless validation of the explicit local audio library, the 23 recovered
## non-voice sounds[] rows, exact WAV identity and fail-closed cue resolution.
## No window is created.
##
## Run: godot --headless --path <this dir> --script res://tests/validate_unreachable_sfx.gd

const LibraryScript = preload("res://scripts/local_audio_library.gd")

const EXPECTED_ZPAK_SHA256 := "364b30a10991d6fdc48bb3e1655e19538caee75bd6ddf81962524647e4cab05c"
const EXPECTED_BRUCLEE_SET_SHA256 := "860b6dac1ae5043456fbf72b1cd93a5a1c76f036b3b995df5e57ce68b4d3762c"
const EXPECTED_BASE_HEAD := "1f31826e2043fa46aa4e8bdb2c68b53fabe9a7f0"
const EXPECTED_ROWS_FP := "4b3013930a2063c02fab8cf2410e28e23aed2d848fa044da1f61d3f37b0cb356"
const EXPECTED_LIB_FP := "2f3f91e085aac3643c114d0c5d47834a825f77dbad30fcf8aab425174fc81598"

## SFX_FILES at 1f31826 (hardcoded here so "38 unchanged" is independently checked).
const BASE_SFX_FILES: Array[String] = [
	"Air_Kick_Heavy_1.wav", "Air_Kick_Light_1.wav", "Air_Punch_Heavy_1.wav",
	"Air_Punch_Light_1.wav", "Block_Arms_2.wav", "Block_Legs_1.wav", "Block_Legs_2.wav",
	"Boot_L.wav", "Boot_R.wav", "Boot_Slide_Long.wav", "Boot_Slide_Short.wav",
	"Clothing_2.wav", "Clothing_3.wav", "Clothing_4.wav", "Fall_1_Normal.wav",
	"Fall_2_Normal.wav", "Fall_3_Normal.wav", "Fall_4_Normal.wav",
	"Kick_Body_Heavy_1.wav", "Kick_Body_Heavy_2.wav", "Kick_Body_Light_1.wav",
	"Kick_Body_Light_2.wav", "Kick_Head_Heavy_1.wav", "Kick_Head_Heavy_2.wav",
	"Kick_Head_Light_1.wav", "Kick_Head_Light_2.wav", "Punch_Body_Heavy_1.wav",
	"Punch_Body_Heavy_2.wav", "Punch_Body_Light_1.wav", "Punch_Body_Light_2.wav",
	"Punch_Head_Heavy_1.wav", "Punch_Head_Heavy_2.wav", "Punch_Head_Light_2.wav",
	"Shoe_Foot_L.wav", "Shoe_Foot_Long.wav", "Shoe_Foot_R.wav",
	"Shoe_Foot_Short.wav", "Shoe_Foot_Short_B.wav",
]

var failures: int = 0
var checks: int = 0
var lib_doc: Dictionary = {}
var rows_doc: Dictionary = {}
var identity_doc: Dictionary = {}
var out_of_scope_doc: Dictionary = {}
var canonical_rows: Array = []
var canonical_pinned: Array = []


func check(ok: bool, label: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label, ("  | " + detail) if detail != "" else "")


func check_eq(actual: Variant, expected: Variant, label: String) -> void:
	check(actual == expected, label, "actual=%s expected=%s" % [str(actual), str(expected)])


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


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


func _json_bytes(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _initialize() -> void:
	print("=== Unreachable SFX: headless cue-resolution validation ===")
	lib_doc = _load_json("res://data/local_audio_library.json")
	rows_doc = _load_json("res://data/recovered_unreachable_rows.json")
	identity_doc = _load_json("res://data/archive_wav_identity.json")
	out_of_scope_doc = _load_json("res://data/out_of_scope_set_rows.json")
	var cr: Variant = _json_bytes("res://data/verbatim_rows_canonical.json")
	var cp: Variant = _json_bytes("res://data/pinned_entries_canonical.json")
	canonical_rows = cr if cr is Array else []
	canonical_pinned = cp if cp is Array else []

	_manifest_integrity()
	_fingerprints_and_verbatim_rows()
	_archive_identity()
	_headless_cue_resolution()
	_no_invented_sounds()
	_fail_closed()
	_finish()


# ---------------------------------------------------------------- manifest ----
func _manifest_integrity() -> void:
	check(not lib_doc.is_empty(), "local_audio_library.json loads")
	check_eq(String(lib_doc.get("schema", "")), "unreachable_sfx_local_audio_library_v1", "manifest schema")
	check_eq(String(lib_doc.get("base_head", "")), EXPECTED_BASE_HEAD, "manifest pins task base 1f31826")
	check_eq(String(lib_doc.get("source_zpak_sha256", "")), EXPECTED_ZPAK_SHA256, "manifest pins data.zpak SHA-256")
	check_eq(int(lib_doc.get("entry_count", 0)), 51, "51 hash-pinned entries")
	check_eq(int(lib_doc.get("sfx_files_count", 0)), 38, "38-file SFX library unchanged")
	check_eq(int(lib_doc.get("proven_extension_count", 0)), 13, "13 proven extensions")
	check_eq(int(lib_doc.get("existing_entries", 0)), 38, "38 existing entries")
	check((lib_doc.get("unrecovered_or_unproven", []) as Array).is_empty(), "no unproven/missing files")
	check_eq(float(lib_doc.get("frame_rate", 0.0)), 30.0, "frame rate 30 fps")
	var sfx: Array = lib_doc.get("sfx_files_unchanged", [])
	check_eq(sfx.size(), 38, "SFX_FILES list has 38 names")
	var same: bool = sfx.size() == BASE_SFX_FILES.size()
	if same:
		for i in range(BASE_SFX_FILES.size()):
			if String(sfx[i]) != BASE_SFX_FILES[i]:
				same = false
	check(same, "SFX_FILES is byte-for-byte the base 1f31826 list")

	var entries: Dictionary = lib_doc.get("entries", {})
	check_eq(entries.size(), 51, "entries object has 51 keys")
	var existing: int = 0
	var extension: int = 0
	var pinned_ok: bool = true
	for key: Variant in entries:
		var row: Dictionary = entries[key]
		if String(row.get("kind", "")) == "existing_sfx_library":
			existing += 1
		elif String(row.get("kind", "")) == "proven_extension":
			extension += 1
		if String(row.get("sha256", "")).length() != 64:
			pinned_ok = false
		if String(row.get("local_path", "")).is_empty():
			pinned_ok = false
		if String(row.get("cue_key", "")) != String(key):
			pinned_ok = false
	check_eq(existing, 38, "38 entries marked existing_sfx_library")
	check_eq(extension, 13, "13 entries marked proven_extension")
	check(pinned_ok, "every entry has a 64-hex SHA-256, local_path and matching cue_key")


# ------------------------------------------------------- no invented sounds ----
func _fingerprints_and_verbatim_rows() -> void:
	var rows_fp: String = _sha256_file(ProjectSettings.globalize_path("res://data/verbatim_rows_canonical.json"))
	var lib_fp: String = _sha256_file(ProjectSettings.globalize_path("res://data/pinned_entries_canonical.json"))
	check_eq(rows_fp, EXPECTED_ROWS_FP, "canonical 23-row fingerprint is the recovered one")
	check_eq(lib_fp, EXPECTED_LIB_FP, "canonical 51-entry fingerprint is the recovered one")
	check_eq(String(rows_doc.get("verbatim_fingerprint_sha256", "")), EXPECTED_ROWS_FP, "rows doc carries the same fingerprint")
	check_eq(String(lib_doc.get("pinned_fingerprint_sha256", "")), EXPECTED_LIB_FP, "library doc carries the same fingerprint")
	check_eq(String(rows_doc.get("source_zpak_sha256", "")), EXPECTED_ZPAK_SHA256, "rows doc pins data.zpak")
	check_eq(String(rows_doc.get("brucelee_set_sha256", "")), EXPECTED_BRUCLEE_SET_SHA256, "rows doc pins brucelee.set payload")
	check_eq(int(rows_doc.get("row_count", 0)), 23, "exactly 23 recovered rows")
	check_eq(int(rows_doc.get("distinct_wav_count", 0)), 13, "23 rows use 13 distinct WAVs")
	check_eq(int(rows_doc.get("resolved_row_count", 0)), 23, "all 23 rows resolve in the library")

	var rows: Array = rows_doc.get("rows", [])
	check_eq(rows.size(), 23, "rows array has 23 entries")
	check_eq(canonical_rows.size(), 23, "canonical rows array has 23 entries")

	# Every delivered row equals one canonical recovered row, field for field.
	var fields: Array[String] = ["set", "action", "directory", "file", "frame", "volume", "unique", "is_voice"]
	var by_key: Dictionary = {}
	for value: Variant in rows:
		if value is Dictionary:
			var r: Dictionary = value
			var k: String = "%s|%s|%s|%s" % [String(r.get("action", "")), String(r.get("file", "")),
					str(r.get("frame", "")), String(r.get("unique", ""))]
			by_key[k] = r
	var matched: int = 0
	var fields_ok: bool = true
	for value: Variant in canonical_rows:
		if not (value is Dictionary):
			fields_ok = false
			continue
		var c: Dictionary = value
		var k2: String = "%s|%s|%s|%s" % [String(c.get("action", "")), String(c.get("file", "")),
				str(c.get("frame", "")), String(c.get("unique", ""))]
		if not by_key.has(k2):
			fields_ok = false
			continue
		var r2: Dictionary = by_key[k2]
		for f: String in fields:
			if r2.get(f, null) != c.get(f, null):
				fields_ok = false
		matched += 1
	check_eq(matched, 23, "all 23 canonical recovered rows are present")
	check(fields_ok, "no row field (file/frame/volume/unique/is_voice) is invented or altered")

	# Every library entry equals one canonical pinned entry.
	var entries: Dictionary = lib_doc.get("entries", {})
	var pin_by_key: Dictionary = {}
	for value: Variant in canonical_pinned:
		if value is Dictionary:
			pin_by_key[String((value as Dictionary).get("cue_key", ""))] = value
	check_eq(canonical_pinned.size(), 51, "canonical pinned array has 51 entries")
	var pinned_match: bool = true
	for key: Variant in entries:
		var row: Dictionary = entries[key]
		if not pin_by_key.has(String(key)):
			pinned_match = false
			continue
		var p: Dictionary = pin_by_key[String(key)]
		for f: String in ["cue_key", "kind", "local_path", "sha256"]:
			if row.get(f, null) != p.get(f, null):
				pinned_match = false
	check(pinned_match, "no library entry is invented or repinned")
	check_eq(pin_by_key.size(), entries.size(), "no extra library keys beyond the canonical 51")


# -------------------------------------------------------- archive identity ----
func _archive_identity() -> void:
	check_eq(int(identity_doc.get("unreachable_distinct_wav_count", 0)), 13, "13 distinct unreachable WAVs located in data.zpak")
	check_eq(int(identity_doc.get("proven_count", 0)), 13, "all 13 proved")
	var unreachable: Dictionary = identity_doc.get("unreachable_wavs", {})
	var entries: Dictionary = lib_doc.get("entries", {})
	var ok: bool = true
	var offsets_ok: bool = true
	for key: Variant in unreachable:
		var e: Dictionary = unreachable[key]
		var lib: Dictionary = entries.get(String(key), {})
		if not bool(e.get("byte_identical", false)) or not bool(e.get("archive_riff_wave", false)):
			ok = false
		if int(e.get("archive_pakd_offset", 0)) <= 0 or int(e.get("archive_index_ordinal", -1)) < 0:
			offsets_ok = false
		if String(e.get("archive_sha256", "")) != String(lib.get("sha256", "")):
			ok = false
		if String(e.get("local_path", "")) != String(lib.get("local_path", "")):
			ok = false
	check(ok, "all 13 extension WAVs are RIFF/WAVE and byte/SHA-256 identical archive<->package")
	check(offsets_ok, "all 13 carry exact PAKD offsets and index ordinals")
	var existing: Dictionary = identity_doc.get("existing_sfx_wavs", {})
	check_eq(existing.size(), 38, "38 existing SFX WAVs checked against the archive")
	var sfx_ok: bool = true
	for key: Variant in existing:
		if not bool((existing[key] as Dictionary).get("byte_identical_to_archive", false)):
			sfx_ok = false
	check(sfx_ok, "all 38 existing SFX WAVs are byte-identical to data.zpak")

	# Out-of-scope rows are explicitly listed, not silently dropped.
	check_eq(int(out_of_scope_doc.get("row_count", 0)), 63, "63 out-of-scope rows explicitly listed")
	var by_set: Dictionary = out_of_scope_doc.get("by_set", {})
	check_eq(int(by_set.get("thai", 0)), 41, "41 thai rows listed")
	check_eq(int(by_set.get("kungfu", 0)), 22, "22 kungfu rows listed")
	check_eq(int(by_set.get("karate", 0)), 0, "0 karate rows listed")
	check_eq((out_of_scope_doc.get("rows", []) as Array).size(), 63, "out-of-scope rows array is complete")


# --------------------------------------------- headless cue resolution ----
func _headless_cue_resolution() -> void:
	var lib = LibraryScript.new()
	check(lib.load_manifest(), "resolver loads the explicit library manifest", lib.get_error())
	check_eq(lib.entry_count(), 51, "resolver reports 51 entries")
	check_eq((lib.cue_keys() as Array).size(), 51, "resolver exposes 51 cue keys")
	var audio_root: String = ProjectSettings.globalize_path("res://")
	check(lib.configure(audio_root), "configure() preflights all 51 WAVs headlessly", lib.get_error())
	check(lib.is_configured(), "resolver is configured")
	check(not lib.is_fail_closed(), "configured resolver is not fail-closed")
	check_eq(lib.get_error(), "", "configure() leaves no error")

	var rows: Array = rows_doc.get("rows", [])
	var entries: Dictionary = lib_doc.get("entries", {})
	var resolved: int = 0
	var streams_ok: bool = true
	var hash_ok: bool = true
	var timing_ok: bool = true
	var fields_ok: bool = true
	for value: Variant in rows:
		if not (value is Dictionary):
			continue
		var row: Dictionary = value
		var out: Dictionary = lib.resolve(row)
		if out.is_empty():
			continue
		resolved += 1
		var stream: Variant = out.get("stream", null)
		streams_ok = streams_ok and (stream is AudioStreamWAV) and stream.get_length() > 0.0
		var key: String = String(out.get("cue_key", ""))
		var info: Dictionary = entries.get(key, {})
		hash_ok = hash_ok and String(out.get("sha256", "")) == String(row.get("sha256", "")) \
				and String(out.get("sha256", "")) == String(info.get("sha256", ""))
		fields_ok = fields_ok and String(out.get("local_path", "")) == String(row.get("local_path", "")) \
				and String(out.get("kind", "")) == "proven_extension" \
				and out.get("frame", null) == row.get("frame", null) \
				and out.get("volume", null) == row.get("volume", null) \
				and String(out.get("unique", "")) == String(row.get("unique", ""))
		var expected_delay: float = float(row.get("frame", 0)) / 30.0
		timing_ok = timing_ok and absf(lib.cue_delay(row) - expected_delay) < 0.000001
	check_eq(resolved, 23, "all 23 recovered rows resolve headlessly")
	check(streams_ok, "every resolved cue decodes to a non-empty AudioStreamWAV")
	check(hash_ok, "every resolved cue carries the exact pinned SHA-256")
	check(fields_ok, "resolved cues preserve file/frame/volume/unique verbatim")
	check(timing_ok, "cue delay is exactly frame/30 s (native 30 fps)")
	check_eq((lib.resolve_all(rows) as Array).size(), 23, "resolve_all() returns 23 cues")

	# The 38 original Title-Case names must also resolve (case-insensitive key).
	var originals_ok: bool = true
	for name: String in BASE_SFX_FILES:
		var original: Dictionary = {"file": name, "directory": "sounds/sfx/",
				"frame": 0, "volume": 1.0, "unique": "", "is_voice": false}
		var out2: Dictionary = lib.resolve(original)
		originals_ok = originals_ok and not out2.is_empty() \
				and String(out2.get("kind", "")) == "existing_sfx_library"
	check(originals_ok, "all 38 original SFX_FILES still resolve through the same library")
	# play_log: 23 per-row resolves + 23 resolve_all + 38 original-name resolves.
	check_eq((lib.play_log as Array).size(), 23 + 23 + 38, "play_log has exactly the resolved cues")


func _no_invented_sounds() -> void:
	var rows: Array = rows_doc.get("rows", [])
	var entries: Dictionary = lib_doc.get("entries", {})
	var actions: Dictionary = {}
	var keys: Dictionary = {}
	var unique_tagged: int = 0
	var generic: int = 0
	var outside_sfx: bool = true
	var non_voice: bool = true
	for value: Variant in rows:
		var r: Dictionary = value
		actions[String(r.get("action", ""))] = true
		keys[String(r.get("cue_key", ""))] = true
		if String(r.get("unique", "")).is_empty():
			generic += 1
		else:
			unique_tagged += 1
		if not String(r.get("directory", "")).begins_with("sounds/voices/"):
			outside_sfx = false
		if bool(r.get("is_voice", true)):
			non_voice = false
	check_eq(actions.size(), 5, "rows span the 5 recovered actions")
	check_eq(keys.size(), 13, "rows use exactly the 13 proven WAVs")
	check_eq(unique_tagged, 20, "20 unique-tagged per-character pain takes")
	check_eq(generic, 3, "3 generic Bruce takes flagged is_voice=false")
	check(outside_sfx, "every recovered row is outside audio/sfx (sounds/voices/...)")
	check(non_voice, "every recovered row is is_voice=false")

	# Every extension is referenced by at least one recovered row; nothing extra.
	var used: Dictionary = {}
	for value: Variant in rows:
		used[String((value as Dictionary).get("cue_key", ""))] = true
	var extensions: Array = lib_doc.get("proven_extensions", [])
	check_eq(extensions.size(), 13, "13 proven extension keys declared")
	var referenced: bool = true
	for value: Variant in extensions:
		var k: String = String(value)
		referenced = referenced and used.has(k) and entries.has(k) \
				and String((entries[k] as Dictionary).get("kind", "")) == "proven_extension"
	check(referenced, "every extension is used by a recovered row; no unused/invented WAV")


# ----------------------------------------------------------- fail closed ----
## Fixture roots are prepared read-only by work/make_fixtures.py.  Godot cannot
## create directories in this environment (err 32), so the validator only reads
## pre-made copies: each fixture is the 51 WAVs with one deliberate mutation.
func _fixtures_root() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		return String(args[0])
	var project_dir: String = ProjectSettings.globalize_path("res://")
	if project_dir.ends_with("/") or project_dir.ends_with("\\"):
		project_dir = project_dir.substr(0, project_dir.length() - 1)
	return project_dir.get_base_dir().path_join("work").path_join("fixtures")


func _fail_closed() -> void:
	var fixtures: String = _fixtures_root()
	check(DirAccess.dir_exists_absolute(fixtures), "fail-closed fixtures exist", fixtures)
	var rows: Array = rows_doc.get("rows", [])
	var sample: Dictionary = {}
	for value: Variant in rows:
		if String((value as Dictionary).get("file", "")) == "hit_light_6_bl.wav":
			sample = value
	check(not sample.is_empty(), "found the grab2 master hit_light_6_bl.wav row")

	# 1. Empty root: first required WAV is missing.
	var missing = LibraryScript.new()
	check(not missing.configure(fixtures.path_join("empty")), "empty root refuses configure()", missing.get_error())
	check(String(missing.get_error()).contains("required WAV missing"), "missing WAV error is explicit", missing.get_error())
	check(not missing.is_configured(), "missing WAV leaves configured=false")
	check(missing.is_fail_closed(), "missing WAV is fail-closed")
	check(missing.resolve(sample).is_empty(), "missing WAV resolves to no stream")
	check(missing.stream_for("hit_light_6_bl.wav") == null, "missing WAV exposes no stream")

	# 2. One flipped data byte (RIFF header intact): SHA-256 mismatch.
	var corrupt = LibraryScript.new()
	check(not corrupt.configure(fixtures.path_join("hash_mismatch")), "hash mismatch refuses configure()", corrupt.get_error())
	check(String(corrupt.get_error()).contains("hash mismatch"), "hash mismatch error is explicit", corrupt.get_error())
	check(corrupt.resolve(sample).is_empty(), "hash mismatch resolves to no stream")
	check(corrupt.is_fail_closed(), "hash mismatch is fail-closed")

	# 3. Non-RIFF payload: the header check fails before decode.
	var nonwav = LibraryScript.new()
	check(not nonwav.configure(fixtures.path_join("non_riff")), "non-RIFF WAV refuses configure()", nonwav.get_error())
	check(String(nonwav.get_error()).contains("not RIFF/WAVE"), "non-RIFF error is explicit", nonwav.get_error())

	# 4. Deleted file: explicit missing error.
	var removed = LibraryScript.new()
	check(not removed.configure(fixtures.path_join("missing")), "deleted WAV refuses configure()", removed.get_error())
	check(String(removed.get_error()).contains("required WAV missing"), "deleted WAV error is explicit", removed.get_error())

	# 5. A clean configured instance rejects unknown cues / voice rows / strict batches.
	var good = LibraryScript.new()
	check(good.configure(fixtures.path_join("good")), "clean copy configures", good.get_error())
	var invented: Dictionary = {"file": "invented_sound.wav", "directory": "sounds/sfx/",
			"frame": 0, "volume": 1.0, "unique": "", "is_voice": false}
	check(good.resolve(invented).is_empty(), "unknown cue key resolves to no stream")
	check(String(good.get_error()).contains("unknown cue key"), "unknown cue error is explicit", good.get_error())
	check(good.is_fail_closed(), "unknown cue marks fail-closed")
	var voice_row: Dictionary = {"file": "hit_light_6_bl.wav", "is_voice": true,
			"directory": "sounds/voices/bruce_lee/attack_light/", "frame": 10,
			"volume": 0.7, "unique": ""}
	check(good.resolve(voice_row).is_empty(), "voice row is not resolved as SFX")
	check(String(good.get_error()).contains("voice rows"), "voice-row error is explicit", good.get_error())
	check((good.resolve_all([sample, invented]) as Array).is_empty(), "strict batch with one invented row returns no cues")
	check(String(good.get_error()).contains("failed to resolve"), "strict-batch error is explicit", good.get_error())
	# A valid row still resolves exactly after a rejection (no invented substitute).
	check(not good.resolve(sample).is_empty(), "valid row still resolves exactly after a rejection")


func _finish() -> void:
	print("RESULT checks=%d failures=%d" % [checks, failures])
	if failures == 0:
		print("ALL PASS")
	quit(0 if failures == 0 else 1)

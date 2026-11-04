class_name StoryNoticeAudio
extends Node

## Plays the two recovered notice contexts, using only exact archive WAVs:
##
##   notice state start:  playlevelupsound -> Bonus_Jingle.wav
##                        playunlocksound  -> Map_Selection_Flute.wav
##   menu continue/ok:    levelup.ui      -> Menu_Punch_2.wav
##                        unlock.ui       -> Select_Play_Bl_Shout.wav
##
## The paths and hashes live in res://data/progress/story_notice_audio.json.
## Every required stream is checked (existence, RIFF/WAVE header, SHA-256, and
## AudioStreamWAV decode) before a notice is shown.  Any missing/invalid stream
## or unknown transition fails closed: no fallback WAV and no silent silence.
## New_Event_3_Drum_Hits.wav is evidence-only here because this task has no
## PlayEventSelectSound transition.

const MANIFEST_PATH: String = "res://data/progress/story_notice_audio.json"
const ENV_ROOT: String = "BRUCELEE_NOTICE_AUDIO_ROOT"
const DEFAULT_ROOT: String = "res://audio/menu_sfx"
const REQUIRED_COUNT: int = 4

var data: Dictionary = {}
var root: String = ""
var configured: bool = false
var fail_closed: bool = true
var error: String = ""
var last_cue: String = ""
var play_log: Array = []

var _streams: Dictionary = {}
var _players: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func load_manifest(path: String = MANIFEST_PATH) -> bool:
	error = ""
	data = {}
	if not FileAccess.file_exists(path):
		return _fail("story notice audio manifest missing: " + path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return _fail("story notice audio manifest is not an object: " + path)
	data = parsed
	var cues: Variant = data.get("required_cues", {})
	if not (cues is Dictionary):
		return _fail("manifest required_cues is not an object")
	var order: Variant = data.get("required_cue_order", [])
	if not (order is Array) or (order as Array).size() != REQUIRED_COUNT:
		return _fail("manifest required_cue_order must contain %d cues" % REQUIRED_COUNT)
	for cue_name: Variant in order:
		var cue: String = String(cue_name)
		var row: Variant = (cues as Dictionary).get(cue, null)
		if not (row is Dictionary):
			return _fail("manifest cue missing: " + cue)
		var file_name: String = String((row as Dictionary).get("file", ""))
		var expected: String = String((row as Dictionary).get("sha256", "")).to_lower()
		if file_name.is_empty() or expected.length() != 64:
			return _fail("manifest cue is incomplete: " + cue)
	return true


## Configure from an explicit directory, BRUCELEE_NOTICE_AUDIO_ROOT, or the
## project-local audio/menu_sfx directory.  All four streams are preflighted
## before returning true; a failure leaves configured=false and fail_closed=true.
func configure(explicit_root: String = "") -> bool:
	_reset_runtime()
	if data.is_empty() and not load_manifest():
		return false
	root = _resolve_root(explicit_root)
	if root.is_empty():
		return _fail("story notice audio root is empty")
	if not DirAccess.dir_exists_absolute(root):
		return _fail("story notice audio root missing: " + root)
	var cues: Dictionary = data.get("required_cues", {})
	var order: Array = data.get("required_cue_order", [])
	var loaded: Dictionary = {}
	for cue_name: Variant in order:
		var cue: String = String(cue_name)
		var row: Dictionary = cues.get(cue, {})
		var file_name: String = String(row.get("file", ""))
		var expected: String = String(row.get("sha256", "")).to_lower()
		var path: String = root.path_join(file_name)
		if not FileAccess.file_exists(path):
			return _fail("required WAV missing for %s: %s" % [cue, path])
		if not _has_riff_wave_header(path):
			return _fail("required WAV is not RIFF/WAVE for %s: %s" % [cue, path])
		var actual: String = _sha256_file(path)
		if actual.is_empty():
			return _fail("required WAV could not be hashed for %s: %s" % [cue, path])
		if actual != expected:
			return _fail("required WAV hash mismatch for %s: %s != %s" % [cue, actual, expected])
		var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
		if stream == null:
			return _fail("required WAV did not decode for %s: %s" % [cue, path])
		if stream.get_length() <= 0.0:
			return _fail("required WAV has zero length for %s: %s" % [cue, path])
		loaded[cue] = stream
	_streams = loaded
	configured = true
	fail_closed = false
	error = ""
	return true


func is_configured() -> bool:
	return configured


func is_fail_closed() -> bool:
	return fail_closed


func required_cues() -> Array:
	return (data.get("required_cue_order", []) as Array).duplicate()


func cue_info(cue: String) -> Dictionary:
	return (data.get("required_cues", {}) as Dictionary).get(cue, {}).duplicate(true)


func cue_for_start_action(action: String) -> String:
	return String((data.get("start_action_cues", {}) as Dictionary).get(action, ""))


func cue_for_menu_sound(recovered_path: String) -> String:
	return String((data.get("menu_sound_cues", {}) as Dictionary).get(recovered_path, ""))


## Native state-entry action: playlevelupsound / playunlocksound.
func play_start_for_notice(notice: Dictionary) -> bool:
	if not configured:
		return _fail("cannot play notice start: audio is not configured")
	var layout: Dictionary = notice.get("layout", {})
	var action: String = String(notice.get("start_action", layout.get("start_action", "")))
	var cue: String = cue_for_start_action(action)
	if cue.is_empty():
		return _fail("unrecovered notice start action: " + action)
	var kind: String = String(notice.get("kind", ""))
	var expected: String = ""
	if kind == "levelupnotify":
		expected = "levelup_start"
	elif kind == "experienceunlock":
		expected = "unlock_start"
	else:
		return _fail("unknown notice kind at start: " + kind)
	if cue != expected:
		return _fail("notice start action/kind mismatch: %s/%s" % [kind, action])
	return play(cue)


## Decoded UI menu sound: levelup.ui continue / unlock.ui ok.
func play_menu_for_notice(notice: Dictionary) -> bool:
	if not configured:
		return _fail("cannot play notice menu cue: audio is not configured")
	var recovered_path: String = String(notice.get("sound", ""))
	var cue: String = cue_for_menu_sound(recovered_path)
	if cue.is_empty():
		return _fail("unrecovered notice menu sound: " + recovered_path)
	var kind: String = String(notice.get("kind", ""))
	var expected: String = ""
	if kind == "levelupnotify":
		expected = "levelup_ok"
	elif kind == "experienceunlock":
		expected = "unlock_ok"
	else:
		return _fail("unknown notice kind at menu: " + kind)
	if cue != expected:
		return _fail("notice menu sound/kind mismatch: %s/%s" % [kind, recovered_path])
	return play(cue)


func play(cue: String) -> bool:
	if not configured:
		return _fail("cannot play cue '%s': audio is not configured" % cue)
	if not _streams.has(cue):
		return _fail("cue not preflighted: " + cue)
	var player: AudioStreamPlayer = _players.get(cue, null)
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "Cue_" + cue
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players[cue] = player
	player.stream = _streams[cue]
	if player.playing:
		player.stop()
	player.play()
	last_cue = cue
	var info: Dictionary = cue_info(cue)
	play_log.append({
		"cue": cue,
		"file": String(info.get("file", "")),
		"recovered_path": String(info.get("recovered_path", "")),
		"transition": String(info.get("transition", "")),
	})
	print("STORY_NOTICE_AUDIO_PLAY %s %s" % [cue, String(info.get("file", ""))])
	return true


func debug_state() -> Dictionary:
	return {
		"configured": configured,
		"fail_closed": fail_closed,
		"error": error,
		"root": root,
		"last_cue": last_cue,
		"play_log": play_log.duplicate(true),
		"required_cues": required_cues(),
	}


func _resolve_root(explicit_root: String) -> String:
	var candidate: String = explicit_root.strip_edges()
	if candidate.is_empty():
		candidate = OS.get_environment(ENV_ROOT).strip_edges()
	if candidate.is_empty():
		candidate = DEFAULT_ROOT
	if candidate.begins_with("res://") or candidate.begins_with("user://"):
		candidate = ProjectSettings.globalize_path(candidate)
	if candidate.is_empty():
		return ""
	return candidate.simplify_path()


func _reset_runtime() -> void:
	_clear_players()
	_streams.clear()
	configured = false
	fail_closed = true
	error = ""
	last_cue = ""
	play_log.clear()


func _clear_players() -> void:
	for key: Variant in _players.keys():
		var player: Variant = _players[key]
		if is_instance_valid(player):
			player.stop()
			if player.get_parent() == self:
				remove_child(player)
			player.free()
	_players.clear()


func _fail(message: String) -> bool:
	error = message
	fail_closed = true
	configured = false
	_streams.clear()
	_clear_players()
	printerr("STORY_NOTICE_AUDIO FAIL CLOSED: " + message)
	return false


func _has_riff_wave_header(path: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	if f.get_length() < 12:
		f.close()
		return false
	var head: PackedByteArray = f.get_buffer(12)
	f.close()
	if head.size() != 12:
		return false
	return (
		head[0] == 0x52 and head[1] == 0x49 and head[2] == 0x46 and head[3] == 0x46
		and head[8] == 0x57 and head[9] == 0x41 and head[10] == 0x56 and head[11] == 0x45
	)


func _sha256_file(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var ctx: HashingContext = HashingContext.new()
	if ctx.start(HashingContext.HASH_SHA256) != OK:
		f.close()
		return ""
	var total: int = f.get_length()
	var done: int = 0
	while done < total:
		var chunk: PackedByteArray = f.get_buffer(mini(65536, total - done))
		if chunk.is_empty():
			break
		ctx.update(chunk)
		done += chunk.size()
	f.close()
	var digest: PackedByteArray = ctx.finish()
	return digest.hex_encode().to_lower()

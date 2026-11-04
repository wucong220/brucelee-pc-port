extends SceneTree

## Headless end-to-end check through the real StoryFlow notice chain:
## chapter1/s_master_1 -> 8 ExperienceUnlock notices + 1 LevelUpNotify, with
## native start cues and UI menu cues played at every recovered transition.
## Also proves a missing-WAV root stops the notice chain fail-closed.
##
## Run: godot --headless --path <project> --script res://tests/validate_story_notice_audio_flow.gd

const StoryFlowScript = preload("res://scripts/story_flow.gd")
const StoryDataScript = preload("res://scripts/story_data.gd")
const StoryStateScript = preload("res://scripts/story_state.gd")
const StoryLangScript = preload("res://scripts/story_lang.gd")
const ProgressHooksScript = preload("res://scripts/progress_hooks.gd")
const StoryNoticeAudioScript = preload("res://scripts/story_notice_audio.gd")

const TEST_PROGRESS_SAVE := "user://notice_audio_flow_progress.json"
const TEST_PROGRESS_SAVE_BAD := "user://notice_audio_flow_progress_bad.json"

var failures: int = 0
var checks: int = 0


func check(ok: bool, label: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label, ("  | " + detail) if detail != "" else "")


func check_eq(actual: Variant, expected: Variant, label: String) -> void:
	check(actual == expected, label, "actual=%s expected=%s" % [str(actual), str(expected)])


func _initialize() -> void:
	print("=== Story notice audio flow integration (headless) ===")
	var audio_root: String = ProjectSettings.globalize_path("res://audio/menu_sfx")
	OS.set_environment(StoryNoticeAudioScript.ENV_ROOT, audio_root)
	_cleanup_all()

	var flow: CanvasLayer = await _make_flow(1)
	check(flow.get("notice_audio") != null, "real StoryFlow created StoryNoticeAudio")
	check(flow.notice_audio.configure(), "notice audio preflights on the real flow", flow.notice_audio.error)

	var event_index: int = _event_index(flow, "s_master_1")
	check(event_index >= 0, "found chapter1/s_master_1")
	var hooks: Node = ProgressHooksScript.new()
	hooks.configure(TEST_PROGRESS_SAVE)
	check(bool(hooks.is_active()), "progress hooks active", "service not loaded")
	flow.progress = hooks
	flow.detail_event = event_index
	flow.unlock_mark = 0
	flow._finish_event()

	check_eq(String(flow.screen), "notice", "event completion opened the notice screen")
	var q: Array = flow.notice_queue
	check_eq(q.size(), 9, "queue = 8 unlocks + 1 level-up")
	var kinds: Array = []
	for n: Dictionary in q:
		kinds.append(String(n.get("kind", "")))
	check_eq(kinds[8], "levelupnotify", "final notice is level-up")
	check_eq(String(q[0].get("kind", "")), "experienceunlock", "first notice is unlock")
	check_eq(String(q[0].get("start_action", "")), "playunlocksound", "first notice start action recovered")
	check_eq(String(q[0].get("sound", "")), "sounds/menu_sfx/select_play_bl_shout.wav", "first notice menu sound recovered")
	check_eq(String(q[8].get("start_action", "")), "playlevelupsound", "level-up start action recovered")
	check_eq(String(q[8].get("sound", "")), "sounds/menu_sfx/menu_punch_2.wav", "level-up menu sound recovered")

	var started: Array = _log_cues(flow.notice_audio)
	check_eq(started, ["unlock_start"], "notice entry played the native unlock cue")
	check_eq(String(flow.notice_audio.error), "", "audio preflight left no error")
	check(not bool(flow.notice_audio.is_fail_closed()), "valid flow is not fail-closed")

	var guard: int = 0
	while String(flow.screen) == "notice" and guard < 20:
		flow._advance_notice()
		guard += 1
	check_eq(guard, 9, "exactly 9 dismissals")
	check_eq(String(flow.screen), "rewards", "dismissing the queue lands on rewards")
	check_eq(int(flow.state.level), 6, "story slot persisted level 6")

	var expected_cues: Array = []
	for i: int in range(8):
		expected_cues.append("unlock_start")
		expected_cues.append("unlock_ok")
	expected_cues.append("levelup_start")
	expected_cues.append("levelup_ok")
	var cues: Array = _log_cues(flow.notice_audio)
	check_eq(cues.size(), 18, "18 audio events: 9 starts + 9 menu cues")
	check_eq(cues, expected_cues, "start/menu cue order matches the real chain")

	var files: Array = _log_files(flow.notice_audio)
	var expected_files: Array = []
	for i: int in range(8):
		expected_files.append("Map_Selection_Flute.wav")
		expected_files.append("Select_Play_Bl_Shout.wav")
	expected_files.append("Bonus_Jingle.wav")
	expected_files.append("Menu_Punch_2.wav")
	check_eq(files, expected_files, "exact recovered WAV order")
	check(not files.has("New_Event_3_Drum_Hits.wav"), "event-select sound never played")

	var player_cues: Array = ["levelup_start", "unlock_start", "levelup_ok", "unlock_ok"]
	for cue: String in player_cues:
		var player: Node = flow.notice_audio.get_node_or_null("Cue_" + cue)
		check(player is AudioStreamPlayer, "audio player exists for " + cue)
		if player is AudioStreamPlayer:
			check((player as AudioStreamPlayer).stream is AudioStreamWAV, "player stream is AudioStreamWAV for " + cue)
			check((player as AudioStreamPlayer).stream.get_length() > 0.0, "player stream non-empty for " + cue)

	# ---- fail closed end-to-end: an empty audio root stops the notice chain ----
	var missing_root: String = ProjectSettings.globalize_path("user://notice_audio_missing_flow_%d" % Time.get_ticks_usec())
	check_eq(DirAccess.make_dir_recursive_absolute(missing_root), OK, "empty flow audio root created")
	OS.set_environment(StoryNoticeAudioScript.ENV_ROOT, missing_root)
	var flow2: CanvasLayer = await _make_flow(2)
	var hooks2: Node = ProgressHooksScript.new()
	hooks2.configure(TEST_PROGRESS_SAVE_BAD)
	check(bool(hooks2.is_active()), "second progress hooks active")
	flow2.progress = hooks2
	flow2.detail_event = _event_index(flow2, "s_master_1")
	flow2.unlock_mark = 0
	flow2._finish_event()
	check_eq(String(flow2.screen), "error", "missing WAV stops the notice chain on the error screen")
	check(flow2.notice_queue.is_empty(), "missing WAV leaves no playable notice queue")
	check(not bool(flow2.notice_view.visible), "missing WAV hides the notice view")
	check_eq(flow2.notice_audio.play_log.size(), 0, "missing WAV plays nothing")
	check(bool(flow2.notice_audio.is_fail_closed()), "missing WAV marks the audio fail-closed")
	check(String(flow2.notice_audio_error).contains("required WAV missing"), "flow reports the missing-WAV cause", flow2.notice_audio_error)
	check_eq(String(flow2.screen), "error", "fail-closed screen is not rewards")

	OS.set_environment(StoryNoticeAudioScript.ENV_ROOT, audio_root)
	flow.progress = null
	flow2.progress = null
	flow.free()
	flow2.free()
	await process_frame
	_cleanup_all()
	DirAccess.remove_absolute(missing_root)
	paused = false
	_finish()


func _make_flow(slot: int) -> CanvasLayer:
	var flow: CanvasLayer = StoryFlowScript.new()
	root.add_child(flow)
	await process_frame
	flow.data = StoryDataScript.new()
	flow.lang = StoryLangScript.new()
	flow.state = StoryStateScript.new()
	flow.state.save_slot = slot
	flow.state.difficulty_name = "easy"
	flow.state.chapter_index = 0
	flow.state.level = 1
	flow.state.exp = 1700
	flow.notice_model = StoryNoticeModel.new()
	return flow


func _event_index(flow: CanvasLayer, maptitle: String) -> int:
	var events: Array = flow.data.events(0)
	for i: int in range(events.size()):
		if String(Dictionary(events[i]).get("maptitle", "")) == maptitle:
			return i
	return -1


func _log_cues(audio: Node) -> Array:
	var out: Array = []
	for entry: Dictionary in audio.play_log:
		out.append(String(entry.get("cue", "")))
	return out


func _log_files(audio: Node) -> Array:
	var out: Array = []
	for entry: Dictionary in audio.play_log:
		out.append(String(entry.get("file", "")))
	return out


func _cleanup_all() -> void:
	for slot: int in range(1, 4):
		var p: String = StoryStateScript.slot_path(slot)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	for path: String in [TEST_PROGRESS_SAVE, TEST_PROGRESS_SAVE_BAD]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish() -> void:
	print("RESULT checks=%d failures=%d" % [checks, failures])
	if failures == 0:
		print("ALL PASS")
	quit(0 if failures == 0 else 1)

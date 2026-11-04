extends SceneTree

## Headless validation of the recovered notice-audio manifest and fail-closed
## loader.  No display/window is created.
##
## Run: godot --headless --path <project> --script res://tests/validate_story_notice_audio.gd

const StoryNoticeAudioScript = preload("res://scripts/story_notice_audio.gd")
const StoryNoticeModelScript = preload("res://scripts/story_notice_model.gd")

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
	print("=== Story notice audio validation (headless) ===")
	var audio_root: String = ProjectSettings.globalize_path("res://audio/menu_sfx")
	OS.set_environment(StoryNoticeAudioScript.ENV_ROOT, audio_root)

	var audio = StoryNoticeAudioScript.new()
	root.add_child(audio)
	await process_frame
	check(audio.load_manifest(), "story_notice_audio.json loads", audio.error)
	check_eq(audio.required_cues(), ["levelup_start", "unlock_start", "levelup_ok", "unlock_ok"], "four required cue contexts")

	# ---- recovered native state-entry cues ----
	var lv_start: Dictionary = audio.cue_info("levelup_start")
	check_eq(String(lv_start["file"]), "Bonus_Jingle.wav", "PlayLevelUpSound -> Bonus_Jingle.wav")
	check_eq(String(lv_start["recovered_path"]), "sounds/Menu_SFX/Bonus_Jingle.wav", "levelup start recovered path")
	check_eq(String(lv_start["native_symbol"]), "_Z16PlayLevelUpSoundv", "levelup start native symbol")
	var ul_start: Dictionary = audio.cue_info("unlock_start")
	check_eq(String(ul_start["file"]), "Map_Selection_Flute.wav", "PlayUnlockSound -> Map_Selection_Flute.wav")
	check_eq(String(ul_start["recovered_path"]), "sounds/Menu_SFX/Map_Selection_Flute.wav", "unlock start recovered path")
	check_eq(String(ul_start["native_symbol"]), "_Z15PlayUnlockSoundv", "unlock start native symbol")

	# ---- recovered UI menu cues ----
	var lv_ok: Dictionary = audio.cue_info("levelup_ok")
	check_eq(String(lv_ok["file"]), "Menu_Punch_2.wav", "levelup.ui continue -> Menu_Punch_2.wav")
	check_eq(String(lv_ok["recovered_path"]), "sounds/menu_sfx/menu_punch_2.wav", "levelup continue recovered path")
	check_eq(String(lv_ok["ui"]), "gui/levelup.ui", "levelup menu cue UI provenance")
	var ul_ok: Dictionary = audio.cue_info("unlock_ok")
	check_eq(String(ul_ok["file"]), "Select_Play_Bl_Shout.wav", "unlock.ui ok -> Select_Play_Bl_Shout.wav")
	check_eq(String(ul_ok["recovered_path"]), "sounds/menu_sfx/select_play_bl_shout.wav", "unlock ok recovered path")
	check_eq(String(ul_ok["ui"]), "gui/unlock.ui", "unlock menu cue UI provenance")

	# ---- action/path routing is exact, unknown values get no cue ----
	check_eq(audio.cue_for_start_action("playlevelupsound"), "levelup_start", "start action playlevelupsound")
	check_eq(audio.cue_for_start_action("playunlocksound"), "unlock_start", "start action playunlocksound")
	check_eq(audio.cue_for_start_action(""), "", "empty start action has no cue")
	check_eq(audio.cue_for_start_action("playeventselectsound"), "", "event select is not wired to a notice")
	check_eq(audio.cue_for_menu_sound("sounds/menu_sfx/menu_punch_2.wav"), "levelup_ok", "levelup menu sound routing")
	check_eq(audio.cue_for_menu_sound("sounds/menu_sfx/select_play_bl_shout.wav"), "unlock_ok", "unlock menu sound routing")
	check_eq(audio.cue_for_menu_sound("sounds/menu_sfx/back_bl_shout_short.wav"), "", "unknown menu sound has no cue")

	# ---- New_Event_3_Drum_Hits is evidence-only in this task ----
	var evidence_only: Dictionary = audio.data.get("evidence_only", {})
	var event_row: Dictionary = evidence_only.get("event_select_start", {})
	check_eq(String(event_row.get("file", "")), "New_Event_3_Drum_Hits.wav", "event-select cue recorded as evidence")
	check(bool(event_row.get("not_wired", false)), "event-select cue explicitly not wired")
	var required_files: Array = []
	for cue_name: Variant in audio.required_cues():
		required_files.append(String(audio.cue_info(String(cue_name)).get("file", "")))
	check(not required_files.has("New_Event_3_Drum_Hits.wav"), "event-select cue absent from required cues")

	# ---- preflight all four exact WAVs, then play each context ----
	check(audio.configure(), "configure() preflights all four WAVs", audio.error)
	check(audio.is_configured(), "audio is configured")
	check(not audio.is_fail_closed(), "valid audio is not fail-closed")
	check_eq(audio.root, audio_root.simplify_path(), "audio root resolved from env")
	for cue_name: Variant in ["levelup_start", "unlock_start", "levelup_ok", "unlock_ok"]:
		var cue: String = String(cue_name)
		check(audio.play(cue), "play(%s) accepted" % cue)
	check_eq(audio.play_log.size(), 4, "four playback events recorded")
	var logged_cues: Array = []
	for entry: Dictionary in audio.play_log:
		logged_cues.append(String(entry.get("cue", "")))
	check_eq(logged_cues, ["levelup_start", "unlock_start", "levelup_ok", "unlock_ok"], "playback order follows required cues")
	var logged_files: Array = []
	for entry: Dictionary in audio.play_log:
		logged_files.append(String(entry.get("file", "")))
	check(not logged_files.has("New_Event_3_Drum_Hits.wav"), "no event-select sound is played")

	# ---- real notice dictionaries route to the correct start/menu contexts ----
	var model = StoryNoticeModelScript.new()
	check(model.is_loaded(), "notice model loads", model.error)
	var lv_notice: Dictionary = model.levelup_notice(6)
	var ul_notice: Dictionary = model.unlock_notice(35)
	audio.play_log.clear()
	check(audio.play_start_for_notice(lv_notice), "level-up notice start routes")
	check(audio.play_menu_for_notice(lv_notice), "level-up notice menu routes")
	check(audio.play_start_for_notice(ul_notice), "unlock notice start routes")
	check(audio.play_menu_for_notice(ul_notice), "unlock notice menu routes")
	var route_cues: Array = []
	for entry: Dictionary in audio.play_log:
		route_cues.append(String(entry.get("cue", "")))
	check_eq(route_cues, ["levelup_start", "levelup_ok", "unlock_start", "unlock_ok"], "notice routing order")

	# ---- fail closed: missing directory ----
	var missing = StoryNoticeAudioScript.new()
	root.add_child(missing)
	await process_frame
	var missing_root: String = ProjectSettings.globalize_path("user://notice_audio_missing_%d" % Time.get_ticks_usec())
	var mk: Error = DirAccess.make_dir_recursive_absolute(missing_root)
	check_eq(mk, OK, "empty temp audio root created")
	check(not missing.configure(missing_root), "missing WAVs fail configure", missing.error)
	check(missing.is_fail_closed(), "missing WAVs leave fail_closed=true")
	check(not missing.is_configured(), "missing WAVs leave configured=false")
	check(String(missing.error).contains("required WAV missing"), "missing WAV error is explicit", missing.error)
	check(not missing.play("levelup_start"), "play after missing-WAV failure is refused")
	check_eq(missing.play_log.size(), 0, "missing-WAV failure records no playback")
	DirAccess.remove_absolute(missing_root)

	# ---- fail closed: unknown transition is not silently mapped ----
	var unknown = StoryNoticeAudioScript.new()
	root.add_child(unknown)
	await process_frame
	check(unknown.configure(), "second valid audio instance configured", unknown.error)
	check(not unknown.play_start_for_notice({"kind": "levelupnotify", "start_action": "playeventselectsound", "layout": {}}), "unknown start action refused")
	check(unknown.is_fail_closed(), "unknown start action marks fail_closed")
	check_eq(unknown.play_log.size(), 0, "unknown start action records no playback")

	missing.free()
	unknown.free()
	audio.free()
	paused = false
	_finish()


func _finish() -> void:
	print("RESULT checks=%d failures=%d" % [checks, failures])
	if failures == 0:
		print("ALL PASS")
	quit(0 if failures == 0 else 1)

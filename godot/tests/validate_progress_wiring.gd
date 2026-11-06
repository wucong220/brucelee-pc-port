extends SceneTree
## Headless validation of the *wiring* inside story_flow.gd / game_modes.gd.
##
## Unlike validate_progress_integration.gd (which calls the bridge directly),
## this script drives the real hook call sites:
##   * StoryFlow._finish_event()      -> event unlock grant + chapter completion
##   * StoryFlow._finish_event() [final chapter] -> story-difficulty completion
##   * GameModes._record_progress()   -> arcade / time-attack clear + survival
##
## Run:  godot --headless --path godot --script res://tests/validate_progress_wiring.gd

const StoryFlowScript = preload("res://scripts/story_flow.gd")
const StoryDataScript = preload("res://scripts/story_data.gd")
const StoryStateScript = preload("res://scripts/story_state.gd")
const StoryLangScript = preload("res://scripts/story_lang.gd")
const GameModesScript = preload("res://scripts/game_modes.gd")
const GameModesRules = preload("res://scripts/game_modes_rules.gd")
const ProgressHooksScript = preload("res://scripts/progress_hooks.gd")

const STORY_SAVE := "user://progress_wiring_story.json"
const MODE_SAVE := "user://progress_wiring_modes.json"

var failures := 0
var checks := 0


func check(ok: bool, label: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label, ("  | " + detail) if detail != "" else "")


func check_eq(actual, expected, label: String) -> void:
	check(actual == expected, label, "actual=%s expected=%s" % [str(actual), str(expected)])


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _event_index(data, chapter_index: int, maptitle: String) -> int:
	var rows: Array = data.events(chapter_index)
	for i in range(rows.size()):
		if String(Dictionary(rows[i]).get("maptitle", "")) == maptitle:
			return i
	return -1


func _chapter_end_index(data, chapter_index: int) -> int:
	var rows: Array = data.events(chapter_index)
	for i in range(rows.size()):
		if String(Dictionary(rows[i]).get("chapter_end", "")).to_lower() == "true":
			return i
	return -1


func _initialize() -> void:
	# Let the SceneTree start so add_child() -> _ready() and get_tree() work.
	call_deferred("_run")


func _run() -> void:
	print("=== Progress wiring validation (story_flow / game_modes) ===")
	for slot in range(1, 4):
		_remove("user://story_slot_%d.json" % slot)
	_remove(STORY_SAVE)

	# ---------------------------------------------------------------- story
	var p = ProgressHooksScript.new()
	p.configure(STORY_SAVE)
	var sf = StoryFlowScript.new()
	root.add_child(sf)
	await process_frame
	sf.data = StoryDataScript.new()
	sf.state = StoryStateScript.new()
	sf.lang = StoryLangScript.new()
	sf.progress = p
	check(sf.data.is_loaded(), "story data loads for wiring test")
	check(sf.state.new_story(1, 0, "easy"), "story slot created (easy)")

	var idx1: int = _event_index(sf.data, 0, "s_master_1")
	check(idx1 >= 0, "chapter1 contains s_master_1")
	sf.detail_event = idx1
	sf._finish_event()
	var st: Dictionary = p.state()
	var ids: Array = p.service.unlocked_ids()
	check(ids.has(40) and ids.has(108),
		"StoryFlow._finish_event grants s_master_1 ids [40,108]")
	check_eq(int(st["counters"].get("story_events_completed", 0)), 1,
		"StoryFlow._finish_event increments story_events_completed")

	# chapter 1 ends on its chapter_end event
	var ce1: int = _chapter_end_index(sf.data, 0)
	check(ce1 >= 0, "chapter1 has a chapter_end event")
	sf.detail_event = ce1
	sf._finish_event()
	check_eq(int(p.state()["counters"].get("story_chapters_completed", 0)), 1,
		"chapter_end event completes chapter1 in the service")
	check((p.state()["achievements"]["reached"] as Array).has("achv_finish_chapter_1"),
		"achv_finish_chapter_1 granted via the real chapter hook")

	# chapters 2..4 recorded, then the final chapter ends -> story complete
	for ch in ["chapter2", "chapter3", "chapter4"]:
		p.note_story_chapter(ch)
	sf.state.chapter_index = 4
	sf.detail_event = _chapter_end_index(sf.data, 4)
	check(sf.detail_event >= 0, "chapter5 has a chapter_end event")
	sf._finish_event()
	check((p.state()["achievements"]["reached"] as Array).has("achv_finish_chapter_5"),
		"final chapter_end grants achv_finish_chapter_5")
	check((p.state()["achievements"]["reached"] as Array).has("achv_story_completed_easy"),
		"final chapter_end grants achv_story_completed_easy")
	check((p.state()["story"]["completed_difficulties"] as Array).has("easy"),
		"completed_difficulties records easy")
	check_eq(int(p.state()["story"]["exp"]), 0,
		"story EXP stays 0 (recovered subevents carry no EXP; fail closed)")

	# ------------------------------------------------------------- game modes
	_remove(MODE_SAVE)
	var p2 = ProgressHooksScript.new()
	p2.configure(MODE_SAVE)
	var gm = GameModesScript.new()
	root.add_child(gm)
	gm.progress = p2
	var rules: Dictionary = GameModesRules.load_rules()
	check(not rules.is_empty(), "game_modes.json loads for wiring test")

	gm.current_mode = "arcade"
	gm.run = GameModesRules.build_run("arcade", {"difficulty": 1, "rounds": 0, "time": 1}, rules)
	gm._record_progress({"outcome": "complete"}, true)
	check_eq(p2.state()["mode_clears"]["arcade"]["medium"], true,
		"arcade complete run records a medium clear")
	check((p2.state()["achievements"]["reached"] as Array).has("achv_arcade_medium"),
		"arcade medium clear grants achv_arcade_medium")
	check_eq(p2.state()["mode_clears"]["arcade"]["easy"], false,
		"arcade easy stays false on a medium clear")

	gm.current_mode = "timeattack"
	gm.run = GameModesRules.build_run(
		"timeattack", {"difficulty": 2, "time_limit_preset": 60}, rules)
	gm.run["fights_done"] = int(gm.run.get("opponent_count", 0))
	gm._record_progress({"outcome": "next"}, true)
	check_eq(p2.state()["mode_clears"]["time_attack"]["hard"], true,
		"clearing the recovered time-attack pool records a hard clear")
	check((p2.state()["achievements"]["reached"] as Array).has("achv_time_attack_hard"),
		"time attack hard clear grants achv_time_attack_hard")
	check(not (p2.state()["achievements"]["reached"] as Array).has("achv_time_attack_beginner"),
		"fail-closed achv_time_attack_beginner still not granted")

	gm.current_mode = "survival"
	gm.run = GameModesRules.build_run("survival", {"difficulty": 1, "time": 1}, rules)
	gm.run["fight_results"] = [{"won": true}, {"won": true}, {"won": true}]
	gm._record_progress({"outcome": "failed"}, false)
	check_eq(int(p2.state()["counters"].get("survival_best_round", 0)), 3,
		"survival run records the three fights won")

	# ---------------------------------------------------------------- cleanup
	root.remove_child(sf)
	root.remove_child(gm)
	sf.free()
	gm.free()
	p.free()
	p2.free()
	for slot in range(1, 4):
		_remove("user://story_slot_%d.json" % slot)
	_remove(STORY_SAVE)
	_remove(MODE_SAVE)

	print("")
	print("=== RESULT: %d checks, %d failures ===" % [checks, failures])
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED")
		quit(1)

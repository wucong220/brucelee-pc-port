extends SceneTree

## Headless integration check: instantiating the real StoryFlow node and running
## the recovered event-completion hook actually raises the LevelUpNotify /
## ExperienceUnlock notices, and dismissing the queue lands on the rewards screen.
##
## Run: godot --headless --path <project> --script res://tests/validate_story_notice_flow_integration.gd

const StoryFlowScript = preload("res://scripts/story_flow.gd")
const StoryDataScript = preload("res://scripts/story_data.gd")
const StoryStateScript = preload("res://scripts/story_state.gd")
const StoryLangScript = preload("res://scripts/story_lang.gd")
const ProgressHooksScript = preload("res://scripts/progress_hooks.gd")

const TEST_PROGRESS_SAVE := "user://notice_flow_itest_progress.json"

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
	print("=== Story notice flow integration (headless) ===")
	for slot: int in range(1, 4):
		var p: String = StoryStateScript.slot_path(slot)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if FileAccess.file_exists(TEST_PROGRESS_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROGRESS_SAVE))

	var flow: CanvasLayer = StoryFlowScript.new()
	root.add_child(flow)
	# _initialize() runs before the first idle frame; let one frame pass so the
	# engine delivers _ready() to the flow and its children (no manual calls).
	await process_frame
	check(flow.get("notice_view") != null, "story flow created the notice view")

	flow.data = StoryDataScript.new()
	flow.lang = StoryLangScript.new()
	flow.state = StoryStateScript.new()
	flow.state.save_slot = 1
	flow.state.difficulty_name = "easy"
	flow.state.chapter_index = 0
	flow.state.level = 1
	flow.state.exp = 1700  # as if fights of the first events were won
	# chapter1/events[7] is s_master_1 (decoded story_mode.json), whose authored
	# unlock subevents grant ids 40 and 108.
	var event_index: int = -1
	var events: Array = flow.data.events(0)
	for i: int in range(events.size()):
		if String(Dictionary(events[i]).get("maptitle", "")) == "s_master_1":
			event_index = i
			break
	check(event_index >= 0, "found chapter1/s_master_1 event index")
	flow.notice_model = StoryNoticeModel.new()
	check(flow.notice_model.is_loaded(), "flow notice model loaded")

	var hooks: Node = ProgressHooksScript.new()
	hooks.configure(TEST_PROGRESS_SAVE)
	check(bool(hooks.is_active()), "progress hooks active", "service not loaded")
	flow.progress = hooks

	flow.detail_event = event_index
	flow.unlock_mark = 0
	flow._finish_event()

	check_eq(String(flow.screen), "notice", "event completion opened the notice screen")
	var q: Array = flow.notice_queue
	check_eq(q.size(), 9, "queue = 6 EXP unlocks + 2 event unlocks + 1 level-up")
	var kinds: Array = []
	for n: Dictionary in q:
		kinds.append(n["kind"])
	check_eq(kinds[8], "levelupnotify", "final queued notice is level-up")
	check_eq(String(q[8]["body"]), "Level 6", "level-up body 'Level 6'")
	var has_unlock := false
	for n: Dictionary in q:
		if n["kind"] == "experienceunlock" and String(n["title"]) == "New move learned!":
			has_unlock = true
	check(has_unlock, "at least one 'New move learned!' unlock notice")
	check(flow.notice_view.get_child_count() > 0, "notice view rendered widgets")
	check(bool(flow.notice_view.visible), "notice view visible")

	# Dismiss the whole queue -> rewards screen.
	var guard: int = 0
	while String(flow.screen) == "notice" and guard < 20:
		flow._advance_notice()
		guard += 1
	check_eq(String(flow.screen), "rewards", "dismissing all notices lands on rewards")
	check_eq(guard, 9, "exactly 9 dismissals for 9 notices")

	# Persisted state: progress save keeps the granted ids and level.
	check_eq(int(flow.state.level), 6, "story slot persisted level 6")
	var reloaded: Dictionary = SaveManager.load_state(TEST_PROGRESS_SAVE)
	check(not reloaded.is_empty(), "progress save valid after flow")
	var unlocked: Array = reloaded.get("unlocks", {}).get("unlocked_ids", [])
	check_eq(unlocked.size(), 8, "8 unlock ids persisted (6 exp + 2 event)")

	flow.progress = null
	flow.queue_free()
	for slot: int in range(1, 4):
		var p: String = StoryStateScript.slot_path(slot)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if FileAccess.file_exists(TEST_PROGRESS_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROGRESS_SAVE))
	paused = false
	_finish()

func _finish() -> void:
	print("RESULT checks=%d failures=%d" % [checks, failures])
	if failures == 0:
		print("ALL PASS")
	quit(0 if failures == 0 else 1)

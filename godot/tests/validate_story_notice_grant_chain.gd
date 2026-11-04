extends SceneTree

## Headless validation of the save -> grant -> notice chain for the recovered
## StoryLevelUp / ExperienceUnlock presentation.
##
## Exercises ProgressService + SaveManager end to end: story EXP crosses level /
## unlock thresholds, a checksummed save is written and reloaded, the same
## notices are derivable from the persisted state and nothing is re-granted or
## re-shown on a second pass.
##
## Run: godot --headless --path <project> --script res://tests/validate_story_notice_grant_chain.gd

const TEST_SAVE := "user://story_notice_chain_test.json"

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
	print("=== Story notice save/grant chain validation ===")
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var model = StoryNoticeModel.new()
	check(model.is_loaded(), "notice model loads")

	# --- fresh profile, first EXP award crosses level 1->2 and grants 2 unlocks ---
	var svc1 = ProgressService.new()
	var loaded0: bool = svc1.load_or_default(TEST_SAVE)
	check(not loaded0, "no save file yet -> default state")
	check_eq(int(svc1.state["story"]["exp"]), 0, "fresh exp = 0")
	var fresh1: Array = svc1.add_story_exp(500)
	check_eq(fresh1, [35, 100], "exp 500 grants ids [35,100]")
	var notices1: Array = model.notices_for(0, 500, fresh1, svc1.registry, Callable(self, "_unproven"), 1, -1)
	check_eq(notices1.size(), 3, "2 unlock notices + 1 level-up")
	check_eq(notices1[2]["body"], "Level 2", "level-up body 'Level 2'")
	check_eq(notices1[2]["title"], "Level Up!", "level-up title 'Level Up!'")
	check_eq(notices1[0]["title"], "New move learned!", "id 35 style_anim -> 'New move learned!'")
	check_eq(notices1[1]["title"], "New art unlocked!", "id 100 art_picture -> 'New art unlocked!'")
	check(not notices1[0]["item_name_recovered"], "item name unresolved -> NOT RECOVERED (unproven)")

	# --- persist and reload: grants survive, save is a valid envelope ---
	check(svc1.save(TEST_SAVE), "save writes the checksummed envelope")
	check(FileAccess.file_exists(TEST_SAVE), "save file exists")
	check(not SaveManager.load_state(TEST_SAVE).is_empty(), "reloaded save passes schema/checksum validation")
	var svc2 = ProgressService.new()
	check(svc2.load_or_default(TEST_SAVE), "second service loads the save")
	check_eq(int(svc2.state["story"]["exp"]), 500, "reloaded exp = 500")
	check_eq(svc2.unlocked_ids(), [35, 100], "reloaded unlocked ids [35,100]")
	check_eq(String(svc2.state["unlocks"]["sources"]["35"]), "story_exp", "id 35 source persisted as story_exp")

	# --- idempotent second pass: no re-grant, no duplicate notice ---
	var fresh_again: Array = svc2.add_story_exp(0)
	check_eq(fresh_again, [], "re-apply exp 0 grants nothing")
	var notices_again: Array = model.notices_for(500, 500, fresh_again, svc2.registry, Callable(self, "_unproven"), 2, -1)
	check_eq(notices_again.size(), 0, "no duplicate notice on re-apply")

	# --- next threshold: 500 -> 1100 crosses 2 more unlocks and 2->4 level ---
	var fresh2: Array = svc2.add_story_exp(600)
	check_eq(fresh2, [17, 69], "exp +600 grants ids [17,69]")
	var notices2: Array = model.notices_for(500, 1100, fresh2, svc2.registry, Callable(self, "_unproven"), 2, -1)
	check_eq(notices2.size(), 3, "2 unlock notices + 1 level-up at exp 1100")
	check_eq(notices2[2]["body"], "Level 4", "level-up body 'Level 4'")
	check(svc2.save(TEST_SAVE), "save after second award")
	var svc3 = ProgressService.new()
	check(svc3.load_or_default(TEST_SAVE), "reload after second award")
	check_eq(svc3.unlocked_ids(), [17, 35, 69, 100], "unlocked ids now [17,35,69,100]")

	# --- deterministic story-event unlock (no EXP) still produces an unlock notice ---
	var ev_fresh: Array = svc3.complete_story_event("chapter1", "s_master_1")
	check_eq(ev_fresh, [40, 108], "event s_master_1 grants ids [40,108]")
	var ev_notices: Array = []
	for id: Variant in ev_fresh:
		ev_notices.append(model.unlock_notice(int(id), svc3.registry, Callable(self, "_unproven")))
	check_eq(ev_notices[0]["title"], "New move learned!", "event id 40 style_anim -> 'New move learned!'")
	check_eq(ev_notices[1]["title"], "New profile unlocked!", "event id 108 fighter_profile -> 'New profile unlocked!'")
	check(svc3.save(TEST_SAVE), "save after event unlock")
	var svc4 = ProgressService.new()
	check(svc4.load_or_default(TEST_SAVE), "reload after event unlock")
	check(svc4.unlocked_ids().has(40) and svc4.unlocked_ids().has(108), "event unlocks persisted")
	check_eq(String(svc4.state["unlocks"]["sources"]["40"]), "story_event", "id 40 source persisted as story_event")
	# replay the same event: nothing new
	check_eq(svc4.complete_story_event("chapter1", "s_master_1"), [], "replaying the event grants nothing")

	# --- full-story sweep: every threshold crossed yields exactly one level-up ---
	var sweep = ProgressService.new()
	var prev_level: int = 1
	var level_ups: int = 0
	for target: int in [500, 800, 1100, 1400, 1700, 2000, 2300, 2600, 2900, 3250]:
		var delta: int = target - int(sweep.state["story"]["exp"])
		sweep.add_story_exp(delta)
		var now_level: int = model.level_for_exp(int(sweep.state["story"]["exp"]))
		if now_level > prev_level:
			level_ups += 1
		prev_level = now_level
	check_eq(level_ups, 10, "10 thresholds crossed -> 10 level-ups")
	check_eq(prev_level, 11, "exp 3250 -> level 11")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	_finish()


func _unproven(_t: String, _id: Variant) -> Dictionary:
	return {"name": "", "proven": false}


func _finish() -> void:
	print("RESULT checks=%d failures=%d" % [checks, failures])
	if failures == 0:
		print("ALL PASS")
	quit(0 if failures == 0 else 1)

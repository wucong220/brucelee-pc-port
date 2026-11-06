extends SceneTree
## Headless validation of the *opt-in progress/save integration* (BRUCELEE_PROGRESS=1).
##
## Covers: opt-in service activation, recovered data shape, story EXP + event
## unlock grants, chapter + story-completion achievements, arcade/time-attack
## run-clear grants, survival/versus counters, combat-feat counters
## (grab / final-attack / great / perfect), fail-closed beginner tier,
## checksummed save/load round-trip, and corrupt/unknown-schema rejection.
##
## Run:  godot --headless --path godot --script res://tests/validate_progress_integration.gd
## Exit 0 = all checks pass.

const ProgressHooksScript = preload("res://scripts/progress_hooks.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")

const TEST_SAVE := "user://progress_integration_test.json"
const CORRUPT_SAVE := "user://progress_integration_corrupt.json"
const WRONG_SAVE := "user://progress_integration_wrong.json"

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


func _initialize() -> void:
	print("=== Progress subsystem integration validation ===")
	print("user:// = ", ProjectSettings.globalize_path("user://"))
	_remove(TEST_SAVE)

	var svc = ProgressHooksScript.new()
	svc.configure(TEST_SAVE)
	check(svc.is_active(), "opt-in ProgressHooks activates with recovered data")

	# 1. recovered data shape through the integrated service
	var reg = svc.service.registry
	var ach = svc.service.achievements
	check_eq(reg.num_ids, 117, "unlocks num_ids = 117")
	check_eq(reg.story_unlocks.size(), 40, "40 EXP-gated story unlocks")
	check_eq(reg.event_unlocks.size(), 49, "49 deterministic event unlocks")
	check_eq(ach.rows.size(), 38, "38 achievements")
	var kinds := {}
	for r in ach.rows:
		var k := String(r["condition"]["kind"])
		kinds[k] = int(kinds.get(k, 0)) + 1
	check_eq(kinds.get("counter_threshold", 0), 28, "28 counter-threshold achievements")
	check_eq(kinds.get("mode_clear", 0), 7, "7 mode-clear achievements")
	check_eq(kinds.get("story_complete", 0), 3, "3 story-complete achievements")

	# 2. story EXP unlock grants (recovered thresholds; 1700 -> six ids)
	svc.sync_story_exp(1700)
	check_eq(int(svc.state()["story"]["exp"]), 1700, "story exp accumulates to 1700")
	check_eq(svc.service.unlocked_ids(), [17, 35, 60, 69, 97, 100],
		"EXP 1700 grants the six rows with exp <= 1700")
	check_eq(svc.sync_story_exp(1700).size(), 0, "re-syncing the same EXP grants nothing")

	# 3. story event unlock grants (deterministic)
	svc.note_story_event("chapter1", "s_master_1")
	check(svc.service.unlocked_ids().has(40) and svc.service.unlocked_ids().has(108),
		"event s_master_1 grants ids [40,108]")
	svc.note_story_event("chapter1", "s_master_6")
	var ids6: Array = svc.service.unlocked_ids()
	var ok6 := true
	for want in [7, 24, 84, 90, 110]:
		if not ids6.has(want):
			ok6 = false
	check(ok6, "event s_master_6 grants ids [7,24,84,90,110]")
	check_eq(int(svc.state()["counters"].get("story_events_completed", 0)), 2,
		"story_events_completed counts both events")
	var before_replay: Array = svc.service.unlocked_ids().duplicate()
	svc.note_story_event("chapter1", "s_master_1")
	check_eq(svc.service.unlocked_ids(), before_replay, "replaying an event does not re-grant")
	check_eq(int(svc.state()["counters"].get("story_events_completed", 0)), 2,
		"replay does not double-count events")

	# 4. chapter + story completion achievements
	for ch in ["chapter1", "chapter2", "chapter3", "chapter4", "chapter5"]:
		svc.note_story_chapter(ch)
	svc.note_story_complete("easy")
	var reached: Array = svc.state()["achievements"]["reached"]
	for i in range(1, 6):
		check(reached.has("achv_finish_chapter_%d" % i),
			"finish chapter %d achievement granted" % i)
	check(reached.has("achv_story_completed_easy"), "story completed (easy) granted")
	check(not reached.has("achv_story_completed_medium"), "story completed (medium) NOT granted")

	# 5. mode clears
	svc.note_mode_clear("arcade", "medium")
	svc.note_mode_clear("time_attack", "hard")
	reached = svc.state()["achievements"]["reached"]
	check(reached.has("achv_arcade_medium"), "arcade medium clear grants achv_arcade_medium")
	check(reached.has("achv_time_attack_hard"), "time attack hard clear grants achv_time_attack_hard")
	check(not reached.has("achv_arcade_easy"), "arcade easy NOT granted")

	# 6. survival + versus counters
	svc.note_survival_round(10)
	for i in range(5):
		svc.note_versus_win()
	reached = svc.state()["achievements"]["reached"]
	check(reached.has("achv_survival_10"), "survival round 10 grants achv_survival_10")
	check(not reached.has("achv_survival_20"), "survival round 10 does NOT grant achv_survival_20")
	check(reached.has("achv_versus_5"), "5 versus wins grants achv_versus_5")
	check(not reached.has("achv_versus_15"), "5 versus wins does NOT grant achv_versus_15")

	# 7. combat-feat counters: grabs (5) and final attacks / endmoves (5)
	for i in range(5):
		svc.note_combat_hit("grab1", "grabbed1", true, 100 + i)
	check_eq(int(svc.state()["counters"].get("number_of_grabs", 0)), 5,
		"five distinct grab hits count number_of_grabs = 5")
	svc.note_combat_hit("grab1", "grabbed1", true, 104)  # same attack sequence -> dedupe
	check_eq(int(svc.state()["counters"].get("number_of_grabs", 0)), 5,
		"multi-impact / same-sequence grab hit is de-duplicated")
	svc.note_combat_hit("grab1", "grabbed1", false, 200)  # opponent grab, not player
	check_eq(int(svc.state()["counters"].get("number_of_grabs", 0)), 5,
		"opponent grabs are not counted as player feats")
	for i in range(5):
		svc.note_combat_hit("endattack1", "hitstun", true, 300 + i)
	check_eq(int(svc.state()["counters"].get("number_of_endmoves", 0)), 5,
		"five final attacks count number_of_endmoves = 5")

	# 8. great / perfect round-win grades (recovered health rule)
	for i in range(5):
		svc.note_grade("great")
	for i in range(5):
		svc.note_grade("perfect")
	reached = svc.state()["achievements"]["reached"]
	check_eq(int(svc.state()["counters"].get("number_of_greats", 0)), 5, "number_of_greats = 5")
	check_eq(int(svc.state()["counters"].get("number_of_perfects", 0)), 5, "number_of_perfects = 5")
	check(reached.has("achv_grabs_5"), "grabs=5 grants achv_grabs_5")
	check(not reached.has("achv_grabs_15"), "grabs=5 does NOT grant achv_grabs_15")
	check(reached.has("achv_final_attacks_5"), "final_attacks=5 grants achv_final_attacks_5")
	check(reached.has("achv_greats_5"), "greats=5 grants achv_greats_5")
	check(reached.has("achv_perfects_5"), "perfects=5 grants achv_perfects_5")

	# 9. fail closed: the unrecovered time-attack beginner tier never awards
	svc.service.state["mode_clears"]["time_attack"]["beginner"] = true
	svc.service.refresh_achievements()
	check(not svc.state()["achievements"]["reached"].has("achv_time_attack_beginner"),
		"fail-closed achv_time_attack_beginner never auto-awards")
	check_eq(ach.condition_status("achv_time_attack_beginner"), "unrecovered",
		"achv_time_attack_beginner condition status = unrecovered")
	svc.service.state["mode_clears"]["time_attack"].erase("beginner")

	# 10. save / load round-trip (checksummed user://)
	check(svc.flush(), "flush writes the checksummed save")
	check(FileAccess.file_exists(TEST_SAVE), "save file exists under user://")
	var snapshot: Dictionary = svc.summary()
	var svc2 = ProgressHooksScript.new()
	svc2.configure(TEST_SAVE)
	check(svc2.is_active(), "reloaded service is active")
	check_eq(int(svc2.state()["story"]["exp"]), 1700, "round-trip preserves story exp")
	check_eq(svc2.service.unlocked_ids(), snapshot["unlocked_ids"], "round-trip preserves unlock ids")
	check_eq(svc2.state()["achievements"]["reached"], snapshot["achievements"], "round-trip preserves achievements")
	check_eq(int(svc2.state()["counters"].get("number_of_grabs", -1)), 5, "round-trip preserves grab counter")
	check_eq(int(svc2.state()["counters"].get("number_of_perfects", -1)), 5, "round-trip preserves perfect counter")
	check_eq(svc2.state()["mode_clears"]["arcade"]["medium"], true, "round-trip preserves mode clears")

	# 11. corrupt / unknown schema fail closed
	var cf := FileAccess.open(CORRUPT_SAVE, FileAccess.WRITE)
	cf.store_string('{"schema":"dragonwarrior-progress/1","version":1,"checksum":"deadbeef","payload_json":"{\\"story\\":{\\"exp\\":999}}"}')
	cf.close()
	var svc3 = ProgressHooksScript.new()
	svc3.configure(CORRUPT_SAVE)
	check_eq(int(svc3.state()["story"]["exp"]), 0, "corrupt save falls back to default (exp 0)")

	var payload := JSON.stringify(SaveManagerScript.default_state())
	var wf := FileAccess.open(WRONG_SAVE, FileAccess.WRITE)
	wf.store_string(JSON.stringify({"schema": "other/9", "version": 99,
		"checksum": payload.sha256_text(), "payload_json": payload}))
	wf.close()
	var svc4 = ProgressHooksScript.new()
	svc4.configure(WRONG_SAVE)
	check_eq(int(svc4.state()["story"]["exp"]), 0, "unknown schema/version rejected -> default state")

	# tidy up test saves
	_remove(TEST_SAVE)
	_remove(CORRUPT_SAVE)
	_remove(WRONG_SAVE)
	# release the bridge nodes so the headless exit stays clean
	svc.free()
	svc2.free()
	svc3.free()
	svc4.free()

	print("")
	print("=== RESULT: %d checks, %d failures ===" % [checks, failures])
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED")
		quit(1)

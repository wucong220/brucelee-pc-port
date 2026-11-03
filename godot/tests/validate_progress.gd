extends SceneTree

## Headless validation of the isolated progress/save subsystem.
## Run:  godot.exe --headless --path <project> --script res://tests/validate_progress.gd
## Exit code 0 = all checks pass, 1 = failure.

var failures := 0
var checks := 0
const TEST_SAVE := "user://progress_test_save.json"


func check(ok: bool, label: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label, ("  | " + detail) if detail != "" else "")


func check_eq(actual, expected, label: String) -> void:
	check(actual == expected, label, "actual=%s expected=%s" % [str(actual), str(expected)])


func _initialize() -> void:
	print("=== Dragon Warrior progress subsystem validation ===")
	print("user:// resolves to: ", ProjectSettings.globalize_path("user://"))

	var svc := ProgressService.new()

	# 1. decoded data shape
	check_eq(svc.registry.num_ids, 117, "unlocks.list num_ids = 117")
	check_eq(svc.registry.story_unlocks.size(), 40, "unlocks.list story_unlocks = 40 rows (365 CTX3 records decoded)")
	check_eq(svc.registry.event_unlocks.size(), 49, "chapter story unlock events = 49")
	check_eq(svc.achievements.rows.size(), 38, "achievements.list = 38 rows")
	var kinds := {}
	for r in svc.achievements.rows:
		var k := str(r["condition"]["kind"])
		kinds[k] = int(kinds.get(k, 0)) + 1
	check_eq(kinds.get("counter_threshold", 0), 28, "28 counter-threshold achievements")
	check_eq(kinds.get("mode_clear", 0), 7, "7 mode-clear achievements")
	check_eq(kinds.get("story_complete", 0), 3, "3 story-complete achievements")

	# 2. default state validates
	check(SaveManager._validate_shape(SaveManager.default_state()), "default state passes schema shape")

	# 3. story EXP unlock grant (1700)
	var fresh_exp := svc.add_story_exp(1700)
	check_eq(svc.state["story"]["exp"], 1700, "story exp accumulates to 1700")
	check_eq(svc.unlocked_ids(), [17, 35, 60, 69, 97, 100], "EXP 1700 grants the 6 rows with exp<=1700")
	check_eq(fresh_exp, [17, 35, 60, 69, 97, 100], "add_story_exp returns the newly granted ids")
	check_eq(str(svc.state["unlocks"]["sources"]["35"]), "story_exp", "unlock 35 source recorded as story_exp")
	# re-applying must not double-grant
	var again := svc.add_story_exp(0)
	check_eq(again.size(), 0, "no duplicate grants on repeated application")

	# 4. story event unlock grant (deterministic, chapter1/s_master_1 -> 40,108)
	var ev_ids := svc.complete_story_event("chapter1", "s_master_1")
	check_eq(ev_ids, [40, 108], "story event s_master_1 grants ids [40,108]")
	check(svc.unlocked_ids().has(108), "fighter_profile unlock 108 recorded")
	check_eq(int(svc.state["counters"].get("story_events_completed", 0)), 1, "story_events_completed counter increments")
	# same event twice: no duplicate
	check_eq(svc.complete_story_event("chapter1", "s_master_1").size(), 0, "replaying an event does not re-grant")
	check_eq(int(svc.state["counters"]["story_events_completed"]), 1, "replay does not double-count events")

	# 5. achievement counters + thresholds (grabs at 16 -> 5 and 15, not 25)
	check_eq(svc.achievements.is_fail_closed("achv_time_attack_beginner"), true,
		"time_attack_beginner is fail-closed (no forged beginner tier)")
	svc.set_counter("number_of_grabs", 16)
	var ach1 := svc.refresh_achievements()
	check(ach1.has("achv_grabs_5"), "grabs=16 grants achv_grabs_5")
	check(ach1.has("achv_grabs_15"), "grabs=16 grants achv_grabs_15")
	check(not ach1.has("achv_grabs_25"), "grabs=16 does NOT grant achv_grabs_25")
	svc.set_counter("number_of_grabs", 30)
	var ach2 := svc.refresh_achievements()
	check_eq(ach2, ["achv_grabs_25"], "grabs=30 grants only the newly crossed tier 25")

	# 6. mode clears
	svc.record_mode_clear("arcade", "medium")
	svc.record_mode_clear("time_attack", "hard")
	var ach3 := svc.refresh_achievements()
	check(ach3.has("achv_arcade_medium"), "arcade medium clear grants achv_arcade_medium")
	check(ach3.has("achv_time_attack_hard"), "time attack hard clear grants achv_time_attack_hard")
	check(not svc.state["achievements"]["reached"].has("achv_arcade_easy"), "arcade easy NOT granted")

	# 7. fail-closed: inject the unrecovered beginner tier directly
	svc.state["mode_clears"]["time_attack"]["beginner"] = true
	var ach4 := svc.refresh_achievements()
	check(not ach4.has("achv_time_attack_beginner"), "fail-closed achievement never auto-awards")
	check(not svc.state["achievements"]["reached"].has("achv_time_attack_beginner"),
		"fail-closed achievement stays unreached")
	check_eq(svc.achievements.condition_status("achv_time_attack_beginner"), "unrecovered",
		"condition status is unrecovered")
	# remove the test-only injected tier so the saved schema stays canonical
	svc.state["mode_clears"]["time_attack"].erase("beginner")

	# 8. chapters + story completion
	for ch in ["chapter1", "chapter2", "chapter3", "chapter4", "chapter5"]:
		svc.complete_chapter(ch)
	svc.complete_story_difficulty("easy")
	var ach5 := svc.refresh_achievements()
	for i in range(1, 6):
		check(ach5.has("achv_finish_chapter_%d" % i), "finish chapter %d achievement granted" % i)
	check(ach5.has("achv_story_completed_easy"), "story completed (easy) achievement granted")

	# 9. versus + survival counters
	for i in range(5):
		svc.record_versus_win()
	svc.record_survival_round(10)
	var ach6 := svc.refresh_achievements()
	check(ach6.has("achv_versus_5"), "5 versus wins grants achv_versus_5")
	check(not ach6.has("achv_versus_15"), "5 versus wins does NOT grant achv_versus_15")
	check(ach6.has("achv_survival_10"), "survival round 10 grants achv_survival_10")
	check(not ach6.has("achv_survival_20"), "survival round 10 does NOT grant achv_survival_20")

	# 10. save / load round-trip
	var saved := svc.save(TEST_SAVE)
	check(saved, "save_state returns true")
	check(FileAccess.file_exists(TEST_SAVE), "save file exists under " + ProjectSettings.globalize_path("user://"))
	var snapshot := svc.state.duplicate(true)

	var svc2 := ProgressService.new()
	var loaded_ok := svc2.load_or_default(TEST_SAVE)
	check(loaded_ok, "load_state returns a validated state")
	check_eq(svc2.state["story"]["exp"], 1700, "round-trip preserves story exp")
	check_eq(svc2.unlocked_ids(), snapshot["unlocks"]["unlocked_ids"], "round-trip preserves unlock ids")
	check_eq(svc2.state["achievements"]["reached"], snapshot["achievements"]["reached"], "round-trip preserves achievements")
	check_eq(int(svc2.state["counters"].get("number_of_grabs", -1)), 30, "round-trip preserves counters")
	check_eq(svc2.state["mode_clears"]["arcade"]["medium"], true, "round-trip preserves mode clears")

	# 11. corrupt / tampered save fails closed
	var corrupt_path := "user://progress_corrupt.json"
	var cf := FileAccess.open(corrupt_path, FileAccess.WRITE)
	cf.store_string('{"schema":"dragonwarrior-progress/1","version":1,"checksum":"deadbeef","payload_json":"{\\"story\\":{\\"exp\\":999}}"')
	cf.close()
	var svc3 := ProgressService.new()
	var corrupt_ok := svc3.load_or_default(corrupt_path)
	check(not corrupt_ok, "corrupt save is rejected (load returns false)")
	check_eq(int(svc3.state["story"]["exp"]), 0, "corrupt save falls back to default state (exp 0)")

	# 12. wrong schema/version rejected
	var wrong_path := "user://progress_wrong.json"
	var wf := FileAccess.open(wrong_path, FileAccess.WRITE)
	var payload := JSON.stringify(SaveManager.default_state())
	wf.store_string(JSON.stringify({"schema": "other/9", "version": 99,
		"checksum": payload.sha256_text(), "payload_json": payload}))
	wf.close()
	var svc4 := ProgressService.new()
	check(not svc4.load_or_default(wrong_path), "unknown schema/version is rejected")

	print("")
	print("=== RESULT: %d checks, %d failures ===" % [checks, failures])
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED")
		quit(1)

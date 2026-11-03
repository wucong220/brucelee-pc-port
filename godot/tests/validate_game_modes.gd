extends SceneTree
## Headless validation of the recovered Arcade / Survival / Time Attack rules
## and the match-loader environment handoff. No display required.
##
##   godot --headless --path game --script res://tests/validate_game_modes.gd

const Rules = preload("res://scripts/game_modes_rules.gd")
const GameModes = preload("res://scripts/game_modes.gd")
const PrototypeMenu = preload("res://scripts/prototype_menu.gd")

var fails: Array = []


func _initialize() -> void:
	call_deferred("_run")


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails.append(msg)


func _run() -> void:
	print("== recovered rule table (libdefault.so) ==")
	var report: Dictionary = Rules.rules_report()
	check(report["arcade_rounds_by_index"] == [1, 2, 3, 4],
		"GetNumRoundsFromSetting 0/1/2/else -> 1/2/3/4")
	check(report["time_seconds_by_index"] == [30, 60, 90, 0],
		"GetTimeFromSetting 0/1/2/3 -> 30/60/90/inf(0)")
	check(report["ai_slot_by_difficulty_index"] == [0, 2, 4],
		"difficulty trunc(2*index): easy/medium/hard -> 0/2/4")
	check(report["arcade_fight_score_by_difficulty_index"] == [100, 125, 150],
		"FightBaseScore 100+25*index -> 100/125/150")

	print("== standalone resolve / fail-closed ==")
	var arcade: Dictionary = Rules.resolve("arcade", {"rounds": 2, "time": 0, "difficulty": 2})
	check(bool(arcade["ok"]) and int(arcade["resolved"]["rounds"]) == 3,
		"arcade rounds index 2 -> 3 bouts")
	check(int(arcade["resolved"]["time_limit"]) == 30, "arcade time index 0 -> 30 s")
	check(int(arcade["resolved"]["score_per_fight"]) == 150, "arcade hard -> 150/fight")
	check((arcade["fail_closed"] as Array).has("lives"), "arcade lives flagged fail-closed")

	var survival: Dictionary = Rules.resolve("survival", {"time": 1, "difficulty": 1})
	check(bool(survival["ok"]), "survival starts (time+difficulty recovered)")
	check(int(survival["resolved"]["time_limit"]) == 60, "survival time index 1 -> 60 s")
	for field: String in ["max_fights", "health_recovery", "score", "lives"]:
		check((survival["fail_closed"] as Array).has(field),
			"survival %s flagged fail-closed" % field)

	var ta_blocked: Dictionary = Rules.resolve("timeattack", {"difficulty": 1, "time_limit_preset": -1})
	check(not bool(ta_blocked["ok"]) and (ta_blocked["blocked"] as Array).has("time_limit"),
		"timeattack with no recovered time_limit FAILS CLOSED")
	var ta_ok: Dictionary = Rules.resolve("timeattack", {"difficulty": 2, "time_limit_preset": 120})
	check(bool(ta_ok["ok"]) and int(ta_ok["resolved"]["time_limit"]) == 120,
		"timeattack accepts recovered 120 s preset")

	print("== arcade run scoring (3 bouts, hard) ==")
	var data: Dictionary = Rules.load_rules()
	var built: Dictionary = Rules.build_run("arcade", {"rounds": 2, "time": 1, "difficulty": 2}, data)
	check(bool(built["ok"]), "arcade run builds")
	var run: Dictionary = built
	check((run["opponents"] as Array).size() == 3, "arcade ladder has 3 opponents")
	var outcome := ""
	var score := 0
	for i: int in range(3):
		var advanced: Dictionary = Rules.apply_result(run, {"won": true, "health": 80.0, "fight_seconds": 10.0})
		run = advanced["run"]
		outcome = String(advanced["outcome"])
		score = int(run["score"])
	check(outcome == "complete", "arcade completes after 3 wins")
	check(score == 450, "arcade score = 3 * 150 = 450 (actual %d)" % score)

	print("== survival endless until loss ==")
	var srun: Dictionary = Rules.build_run("survival", {"time": 1, "difficulty": 1}, data)
	var s1: Dictionary = Rules.apply_result(srun, {"won": true, "health": 70.0, "fight_seconds": 12.0})
	check(String(s1["outcome"]) == "next", "survival advances after a win")
	var s2: Dictionary = Rules.apply_result(s1["run"], {"won": false, "health": 0.0, "fight_seconds": 8.0})
	check(String(s2["outcome"]) == "failed", "survival ends on a loss")

	print("== survival with recovered story maximum_fights / health_recovery ==")
	var capped: Dictionary = Rules.build_run(
		"survival", {"time": 1, "difficulty": 1, "max_fights": 3, "health_recovery": 15}, data)
	check(int(capped.get("max_fights", -1)) == 3, "authored maximum_fights=3 applied")
	check(int(capped.get("health_recovery", -1)) == 15, "authored health_recovery=15 applied")
	var c1: Dictionary = Rules.apply_result(capped, {"won": true, "health": 50.0, "fight_seconds": 10.0})
	check(String(c1["outcome"]) == "next", "capped survival advances after win 1")
	check(is_equal_approx(float(c1["run"]["carried_health"]), 65.0),
		"health_recovery 15 carries 50 -> 65")
	var c2: Dictionary = Rules.apply_result(c1["run"], {"won": true, "health": 40.0, "fight_seconds": 10.0})
	check(String(c2["outcome"]) == "next", "capped survival advances after win 2")
	var c3: Dictionary = Rules.apply_result(c2["run"], {"won": true, "health": 30.0, "fight_seconds": 10.0})
	check(String(c3["outcome"]) == "complete", "capped survival completes at maximum_fights=3")

	print("== timeattack total time budget ==")
	var trun: Dictionary = Rules.build_run("timeattack", {"difficulty": 1, "time_limit_preset": 120}, data)
	var t1: Dictionary = Rules.apply_result(trun, {"won": true, "health": 60.0, "fight_seconds": 130.0})
	check(String(t1["outcome"]) == "failed" and String(t1["reason"]).contains("time limit"),
		"timeattack fails when the recovered 120 s budget is exceeded")

	print("== match-loader environment handoff ==")
	var gm: Node = GameModes.new()
	root.add_child(gm)
	gm.configure(null, {"sinfu": {"glb": "x.glb", "texture_root": "t", "clip_prefix": "m04",
		"material_profile": "body", "attack_config": "res://data/attack_config_sinfu.json", "skeleton": "medium"}})
	gm.open_mode("arcade")
	check(String(gm.get("screen")) == "settings", "ARCADE opens the recovered settings screen")
	gm.call("_apply_match_loader_env", {
		"opponent": "sinfu", "scene_variant": "templeyardb", "time": 30,
		"difficulty_slot": 4, "rounds_to_win": 1, "start_health": -1.0,
	})
	check(OS.get_environment("BRUCELEE_SCENE") == "templeyardb", "env BRUCELEE_SCENE set")
	check(OS.get_environment("BRUCELEE_ROUND_TIME") == "30", "env BRUCELEE_ROUND_TIME = 30")
	check(OS.get_environment("BRUCELEE_AI_DIFFICULTY") == "4", "env difficulty slot = 4 (hard)")
	check(OS.get_environment("BRUCELEE_MATCH_ROUNDS") == "1", "env BRUCELEE_MATCH_ROUNDS = 1")
	check(OS.get_environment("BRUCELEE_OPPONENT_GLB") == "x.glb", "env opponent GLB handed off")
	gm.hide_all()
	gm.queue_free()

	print("== menu / wiring ==")
	check(PrototypeMenu.MAIN_COMMANDS.has("arcade")
		and PrototypeMenu.MAIN_COMMANDS.has("survival")
		and PrototypeMenu.MAIN_COMMANDS.has("timeattack"),
		"prototype main menu exposes arcade/survival/timeattack")
	var main_text: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main_text.contains("GameModes = preload"), "main.gd preloads GameModes")
	check(main_text.contains("game_modes.match_finished"), "main.gd reports match end to game_modes")

	print("")
	print("GAME_MODES_VALIDATE " + ("OK" if fails.is_empty() else "FAILED (%d)" % fails.size()))
	for f: Variant in fails:
		print("  FAILED: " + String(f))
	quit(0 if fails.is_empty() else 1)

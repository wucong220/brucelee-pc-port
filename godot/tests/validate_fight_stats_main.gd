extends SceneTree
## Validates the recovered per-fight counters on the real main.tscn and their
## hand-off to the story flow's match_finished EXP award.
##
## The counters have to come from the animation the fighter really starts
## (CFighter::SetAnimation 0x1a6e94 -> CFighter::GetAnmCategory 0x1a6d50), so the
## suite drives the game's own attack entry points (PortFighter.request_attack)
## and the recovered round-win grade path (CBeatEmUpGame::SetState 7).
##
## Run: godot --headless --path godot --script res://tests/validate_fight_stats_main.gd

const StoryFlowScript = preload("res://scripts/story_flow.gd")
const StoryStateScript = preload("res://scripts/story_state.gd")
const StoryDataScript = preload("res://scripts/story_data.gd")

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


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Fight stat counters on the real main.tscn ===")
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")
	var packed: PackedScene = load("res://scenes/main.tscn")
	check(packed != null, "main.tscn loads")
	if packed == null:
		quit(1)
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)

	var player: PortFighter = scene.get("player")
	var computer: PortFighter = scene.get("computer")
	check(player != null and computer != null, "the real match created both fighters")

	# A fresh match has an empty animation-category record (TFightResults 0/0/0).
	var fresh: Dictionary = scene.get_fight_results()
	check_eq(fresh.get("counters"), 0, "a fresh match has no counter")
	check_eq(fresh.get("special_moves"), 0, "a fresh match has no special")
	check_eq(fresh.get("ending_moves"), 0, "a fresh match has no ending move")
	check_eq(fresh.get("perfects"), 0, "a fresh match has no perfect round")
	check_eq(fresh.get("health_remaining"), 100, "a fresh match reports full health")
	check(int(fresh.get("match_millis", -1)) >= 0, "a fresh match reports its millis")

	# Drive the game's own attack entry point; the animation it starts carries
	# the recovered "special" category.
	var started: bool = player.request_attack("special_punch_low_hit")
	check(started, "the game starts the recovered special_punch_low_hit animation")
	check_eq(scene.get_fight_results().get("special_moves"), 1,
		"starting a special animation sets TFightResults +0x08")
	check_eq(scene.get_fight_results().get("counters"), 0,
		"a special does not set the counter flag")

	# The counter category belongs to the parry animations only.
	player._enter_locomotion_state("idle")
	var parried: bool = player.request_attack("parry_high")
	check(parried, "the game starts the recovered parry_high animation")
	check_eq(scene.get_fight_results().get("counters"), 1,
		"entering a parry animation sets TFightResults +0x04")
	check_eq(player.anim_category("counter"), 1, "GetAnmCategory(counter) is 1")

	player._enter_locomotion_state("idle")
	var ended: bool = player.request_attack("endattack1")
	check(ended, "the game starts the recovered endattack1 animation")
	check_eq(scene.get_fight_results().get("ending_moves"), 1,
		"an end attack sets TFightResults +0x0c")

	# A whiffed special animation carries no recovered category: it must not be
	# invented into the record.
	player._enter_locomotion_state("idle")
	player.request_attack("special_punch_low_miss")
	check_eq(player.anim_category("special"), 1,
		"the whiffed special animation does not add a second special")

	# TFightResults +0x10: perfect round wins (winner health == 100).
	player.health = 100.0
	computer.health = 0.0
	scene._show_round_result_text(player, true)
	check_eq(scene.get_fight_results().get("perfects"), 1,
		"an untouched round win counts one perfect round")
	scene._show_round_result_text(player, true)
	check_eq(scene.get_fight_results().get("perfects"), 2,
		"a second untouched round win counts a second perfect round")
	player.health = 55.0
	scene._show_round_result_text(player, true)
	check_eq(scene.get_fight_results().get("perfects"), 2,
		"a round win with damage taken is not a perfect round")

	# CBeatEmUpMatch::NextRound does not clear the record: only a match restart
	# (RestartFight -> Match::Restart -> SetInitialRoundValues) does.
	scene._start_next_round()
	check_eq(scene.get_fight_results().get("special_moves"), 1,
		"a round transition keeps the recorded special")
	check_eq(scene.get_fight_results().get("counters"), 1,
		"a round transition keeps the recorded counter")
	scene._reset_match()
	var reset: Dictionary = scene.get_fight_results()
	check_eq(reset.get("counters"), 0, "a match restart clears the counter record")
	check_eq(reset.get("special_moves"), 0, "a match restart clears the special record")
	check_eq(reset.get("ending_moves"), 0, "a match restart clears the endmove record")
	check_eq(reset.get("perfects"), 0, "a match restart clears the perfect count")

	_hand_off_to_story(scene, player)

	root.remove_child(scene)
	scene.free()
	print("")
	print("=== RESULT: %d checks, %d failures ===" % [checks, failures])
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED")
		quit(1)


func _hand_off_to_story(scene: Node, player: PortFighter) -> void:
	var flow = StoryFlowScript.new()
	root.add_child(flow)
	var state = StoryStateScript.new()
	state.difficulty_slot = 0
	state.save_slot = 0  # no file is written by the test
	flow.state = state
	flow.main = scene
	flow.battle_run = {"kind": "vsbattle", "win_on_lose": "false"}

	# Rebuild a measured fight on the fresh match.
	player.request_attack("special_punch_low_hit")
	player._enter_locomotion_state("idle")
	player.request_attack("parry_high")
	player.health = 100.0
	scene._show_round_result_text(player, true)
	var results: Dictionary = scene.get_fight_results()
	check_eq(results.get("counters"), 1, "the story hand-off sees the live counter")
	check_eq(results.get("special_moves"), 1, "the story hand-off sees the live special")
	check_eq(results.get("perfects"), 1, "the story hand-off sees the live perfect count")

	var stats: Dictionary = flow._story_exp_move_stats()
	check_eq(stats, {"counters": 1, "special_moves": 1, "ending_moves": 0, "perfects": 1},
		"the story flow reads the four counters from the live match")

	# vsbattle easy: 100 + (0+1)*100 + 10*(1+1) + 15*0 + 20*1 = 240.
	flow._award_story_exp(true, 100.0, 0.0, "complete")
	check_eq(state.exp, 240, "the awarded EXP is the exact recovered vsbattle score (240)")

	# The same award through the real match_finished path.  An arcade run with a
	# second opponent left resolves to outcome "next" (no completion bonus):
	# 75 + (0+1)*100 + 10*(1+1) + 15*0 + 20*1 = 215.
	var run: Dictionary = {
		"kind": "arcade", "chapter": "chapter1", "event": "test_event",
		"event_type": "arcade_event", "sub_index": 0, "opponents": ["brick", "johnson"],
		"opponent_index": 0, "player": "brucelee", "scenery": "", "difficulty_slot": 0,
		"difficulty_value": 0, "fights_done": 0, "elapsed_seconds": 0.0,
		"fight_results": [], "carried_health": -1.0, "source": {},
	}
	flow.data = StoryDataScript.new()
	check(flow.data.is_loaded(), "the recovered story data loads for the hand-off")
	flow.battle_spec = {"opponent": "brick"}
	flow.battle_run = run
	flow.battle_started_msec = Time.get_ticks_msec()
	state.set_pending({"run": run, "spec": flow.battle_spec})
	state.exp = 0
	flow.match_finished(true)
	check_eq(state.exp, 215,
		"match_finished awards the exact recovered arcade score from the live counters")
	check_eq(String(state.records.back().get("kind", "")), "arcade",
		"match_finished still records the fight")
	root.remove_child(flow)
	flow.free()

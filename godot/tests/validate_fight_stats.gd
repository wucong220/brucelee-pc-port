extends SceneTree
## Validates the recovered per-fight fight-result counters and the exact story
## EXP they feed.
##
## Native evidence (libdefault.so, SHA-256 1da7a30c...e70):
##   * CFighter::SetAnimation 0x1a6e94 records every category carried by the
##     animation it starts (presence flag; 0x1a76e0 `mov r3,#1; str r3,[r8]`).
##   * CFighter::GetAnmCategory 0x1a6d50 reads that record.
##   * CBeatEmUpGameModes::RegisterLastFightVariables 0x15ca6c fills
##     TFightResults +0x04/+0x08/+0x0c from GetAnmCategory(player, "counter"/
##     "special"/"endmove") and +0x10 from the player fighter record byte +0x174.
##   * CBruceLeeStoryMode::FightWon 0x1e73bc adds
##       base + (D+1)*health + 10*(counters+specials) + 15*endmoves + 20*perfects
##     for vsbattle/arcade, base + (D+1)*health for survival, and
##       base + (D+2)*(time_limit - elapsed_seconds) for timeattack.
##   * CBruceLeeStoryMode::StoryEventCompletionBonus 0x1e47a8 adds the completion
##     bonus once for the score-summary kinds.
##
## Run: godot --headless --path godot --script res://tests/validate_fight_stats.gd

const StoryFlowScript = preload("res://scripts/story_flow.gd")
const StoryStateScript = preload("res://scripts/story_state.gd")
const FightStatsScript = preload("res://scripts/fight_stats.gd")

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


## Independent transcription of the recovered formula, used to prove the
## in-game function against something written separately from it.
func _expected_score(kind: String, difficulty: int, health: int,
		counters: int, specials: int, endmoves: int, perfects: int,
		remaining_seconds: int) -> int:
	var base: int = 0
	match kind:
		"vsbattle", "timeattack":
			base = 25 * difficulty + 100
		"survival":
			base = 15 * difficulty + 125
		"arcade":
			base = 25 * difficulty + 75
	if kind == "vsbattle" or kind == "arcade":
		return (base + (difficulty + 1) * health
			+ 10 * (counters + specials) + 15 * endmoves + 20 * perfects)
	if kind == "survival":
		return base + (difficulty + 1) * health
	if kind == "timeattack":
		return base + (difficulty + 2) * maxi(0, remaining_seconds)
	return 0


func _expected_completion_bonus(kind: String, difficulty: int) -> int:
	match kind:
		"survival":
			return 25 * difficulty + 150
		"timeattack":
			return 25 * difficulty + 125
		"arcade":
			return 25 * difficulty + 250
	return 0


class FakeMain:
	extends Node
	var results: Dictionary = {}

	func get_fight_results() -> Dictionary:
		return results


func _run() -> void:
	print("=== Fight stat counters + story EXP validation ===")
	_category_table()
	_exact_scores()
	_award_through_story_flow()
	print("")
	print("=== RESULT: %d checks, %d failures ===" % [checks, failures])
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED")
		quit(1)


func _category_table() -> void:
	var table = FightStatsScript.new()
	check(table.is_loaded(), "recovered category table loads")
	check_eq(table.action_count(), 53, "category table has the 53 recovered actions")
	check_eq(table.categories_for_action("parryhigh"), ["counter"], "parryhigh is a counter")
	check_eq(table.categories_for_action("parrylow"), ["counter"], "parrylow is a counter")
	check_eq(table.categories_for_action("specialpunchlowhit"), ["special"],
		"specialpunchlowhit is a special")
	check_eq(table.categories_for_action("endattack1"), ["endmove"], "endattack1 is an endmove")
	check_eq(table.categories_for_action("endattack2"), ["endmove"], "endattack2 is an endmove")
	# The whiff/fail special animations carry no recovered special category, and
	# ordinary attacks carry none of the three: the table must not invent them.
	check_eq(table.categories_for_action("specialpunchlowmiss"), [],
		"the whiffed special animation is not classified")
	check_eq(table.categories_for_action("punch"), [], "a normal punch is not classified")
	check_eq(table.categories_for_action("endattackcomp1"), [],
		"endattackcomp1 (no recovered category) is not classified")
	# Port ATTACKS kinds resolve to the native action name the table is keyed on.
	# (The real fighter's ATTACKS table is exercised on main.tscn by the
	# validate_fight_stats_main suite; here only the resolution rule is checked.)
	var attacks: Dictionary = {
		"parry_high": {"source_action": "parryhigh"},
		"special_punch_low_hit": {"source_action": "specialpunchlowhit"},
		"endattack1": {"source_action": "endattack1"},
		"attacktofloor": {},
	}
	check_eq(table.action_for_kind(attacks, "parry_high"), "parryhigh",
		"port parry_high resolves to parryhigh")
	check_eq(table.action_for_kind(attacks, "special_punch_low_hit"),
		"specialpunchlowhit", "port special_punch_low_hit resolves to specialpunchlowhit")
	check_eq(table.action_for_kind(attacks, "attacktofloor"), "attacktofloor",
		"a kind with no source_action falls back to itself")
	check_eq(table.categories_for_action(
		table.action_for_kind(attacks, "endattack1")), ["endmove"],
		"port endattack1 records the endmove category")


func _exact_scores() -> void:
	var kinds: Array[String] = ["vsbattle", "arcade", "survival", "timeattack", "other"]
	var move_sets_values: Array[Dictionary] = [
		{"counters": 0, "special_moves": 0, "ending_moves": 0, "perfects": 0},
		{"counters": 1, "special_moves": 0, "ending_moves": 0, "perfects": 0},
		{"counters": 0, "special_moves": 1, "ending_moves": 0, "perfects": 0},
		{"counters": 0, "special_moves": 0, "ending_moves": 1, "perfects": 0},
		{"counters": 0, "special_moves": 0, "ending_moves": 0, "perfects": 1},
		{"counters": 1, "special_moves": 1, "ending_moves": 1, "perfects": 2},
	]
	var mismatch: int = 0
	for kind: String in kinds:
		for difficulty: int in range(0, 3):
			for health: int in [0, 37, 100]:
				for stats: Dictionary in move_sets_values:
					for remaining: int in [0, 60, 99]:
						var got: int = StoryFlowScript.story_exp_fight_score(
							kind, difficulty, health, stats, remaining)
						var want: int = _expected_score(
							kind, difficulty, health,
							int(stats["counters"]), int(stats["special_moves"]),
							int(stats["ending_moves"]), int(stats["perfects"]),
							remaining)
						if got != want:
							mismatch += 1
	check_eq(mismatch, 0,
		"story_exp_fight_score matches the recovered formula on %d combinations"
			% (kinds.size() * 3 * 3 * move_sets_values.size() * 3))

	# The four counter terms are exactly the recovered weights.
	var base_stats: Dictionary = {
		"counters": 0, "special_moves": 0, "ending_moves": 0, "perfects": 0,
	}
	var base: int = StoryFlowScript.story_exp_fight_score("vsbattle", 0, 50, base_stats, -1)
	check_eq(StoryFlowScript.story_exp_fight_score("vsbattle", 0, 50,
		{"counters": 1, "special_moves": 0, "ending_moves": 0, "perfects": 0}, -1) - base,
		10, "one counter is +10 EXP")
	check_eq(StoryFlowScript.story_exp_fight_score("vsbattle", 0, 50,
		{"counters": 0, "special_moves": 1, "ending_moves": 0, "perfects": 0}, -1) - base,
		10, "one special is +10 EXP")
	check_eq(StoryFlowScript.story_exp_fight_score("vsbattle", 0, 50,
		{"counters": 0, "special_moves": 0, "ending_moves": 1, "perfects": 0}, -1) - base,
		15, "one ending move is +15 EXP")
	check_eq(StoryFlowScript.story_exp_fight_score("vsbattle", 0, 50,
		{"counters": 0, "special_moves": 0, "ending_moves": 0, "perfects": 2}, -1) - base,
		40, "two perfect rounds are +40 EXP")
	check_eq(StoryFlowScript.story_exp_fight_score("vsbattle", 0, 50,
		{"counters": 1, "special_moves": 1, "ending_moves": 1, "perfects": 2}, -1) - base,
		75, "all four terms add 10+10+15+40")
	# Full worked example: vsbattle, hard, untouched, every category used, 2 perfect rounds.
	check_eq(StoryFlowScript.story_exp_fight_score("vsbattle", 2, 100,
		{"counters": 1, "special_moves": 1, "ending_moves": 1, "perfects": 2}, -1),
		150 + 3 * 100 + 10 * 2 + 15 + 40,
		"vsbattle hard perfect fight = 150 + 300 + 20 + 15 + 40")
	# Completion bonus table is unchanged and only applies to the summary kinds.
	check_eq(StoryFlowScript._story_exp_completion_bonus("arcade", 1), 275,
		"arcade completion bonus at medium is 275")
	check_eq(StoryFlowScript._story_exp_completion_bonus("vsbattle", 2), 0,
		"vsbattle has no completion bonus")


func _award_through_story_flow() -> void:
	var flow = StoryFlowScript.new()
	root.add_child(flow)
	var state = StoryStateScript.new()
	state.difficulty_slot = 2
	state.exp = 0
	flow.state = state
	flow.battle_run = {"kind": "vsbattle", "win_on_lose": "false"}

	# No match attached: the move stats are "not measured" and the award is the
	# zero-counter score (still exact for the health/base part).
	flow.main = null
	flow._award_story_exp(true, 100.0, 0.0, "complete")
	check_eq(state.exp, 150 + 300, "unmeasured counters award base + (D+1)*health only")

	# A measured TFightResults must add the recovered 10/15/20 terms.
	var fake := FakeMain.new()
	root.add_child(fake)
	fake.results = {
		"health_remaining": 100, "counters": 1, "special_moves": 1,
		"ending_moves": 1, "perfects": 2, "match_millis": 1234,
	}
	flow.main = fake
	var stats: Dictionary = flow._story_exp_move_stats()
	check_eq(stats, {"counters": 1, "special_moves": 1, "ending_moves": 1, "perfects": 2},
		"_story_exp_move_stats reads the four TFightResults counters")
	state.exp = 0
	flow._award_story_exp(true, 100.0, 0.0, "complete")
	check_eq(state.exp, 150 + 300 + 20 + 15 + 40,
		"measured counters award the exact vsbattle hard score (525)")
	check_eq(_expected_score("vsbattle", 2, 100, 1, 1, 1, 2, -1), state.exp,
		"the awarded EXP equals the independent formula")

	# arcade completion bonus rides on the same call.
	flow.battle_run = {"kind": "arcade", "win_on_lose": "false"}
	fake.results = {
		"health_remaining": 40, "counters": 0, "special_moves": 1,
		"ending_moves": 0, "perfects": 0, "match_millis": 900,
	}
	state.exp = 0
	flow._award_story_exp(true, 40.0, 5.0, "complete")
	check_eq(state.exp, 125 + 3 * 40 + 10 + 300,
		"arcade hard win: base 125 + 120 + 10 special + 300 completion = 555")

	# survival ignores the counters; timeattack uses the remaining seconds.
	flow.battle_run = {"kind": "survival", "win_on_lose": "false"}
	state.exp = 0
	flow._award_story_exp(true, 55.0, 30.0, "complete")
	check_eq(state.exp, 155 + 3 * 55 + 200,
		"survival hard: base 155 + 165 + 200 completion")

	flow.battle_run = {"kind": "timeattack", "win_on_lose": "false", "time_limit": 60}
	fake.results = {
		"health_remaining": 70, "counters": 1, "special_moves": 1,
		"ending_moves": 1, "perfects": 1, "match_millis": 12000,
	}
	state.exp = 0
	flow._award_story_exp(true, 70.0, 20.0, "complete")
	check_eq(state.exp, 150 + 4 * 40 + 175,
		"timeattack hard: base 150 + (D+2)*40 remaining + 175 completion")

	# win_on_lose awards EXP on a lost fight, exactly like PlayerLost 0x190230.
	flow.battle_run = {"kind": "vsbattle", "win_on_lose": "true"}
	fake.results = {
		"health_remaining": 0, "counters": 0, "special_moves": 0,
		"ending_moves": 0, "perfects": 0, "match_millis": 500,
	}
	state.exp = 0
	flow._award_story_exp(false, 0.0, 3.0, "complete")
	check_eq(state.exp, 150 + 0, "win_on_lose still awards the base score on a loss")

	# A plain loss awards nothing (StoryMode::FightLost 0x1e48a4 is a stub).
	flow.battle_run = {"kind": "vsbattle", "win_on_lose": "false"}
	state.exp = 0
	flow._award_story_exp(false, 0.0, 3.0, "failed")
	check_eq(state.exp, 0, "a plain loss awards no EXP")

	root.remove_child(flow)
	flow.free()

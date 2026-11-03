extends SceneTree
## Headless validation of the story-flow data, rules, save state and the
## match-loader handoff.  No 3D scene is created, so this runs fast and
## deterministically.
##
##   godot --headless --path game --script res://tests/story_flow_validate.gd
##
## Exit code 0 = every check passed.  Any failed check prints FAIL and quits 1.

const StoryDataScript = preload("res://scripts/story_data.gd")
const StoryStateScript = preload("res://scripts/story_state.gd")
const StoryRules = preload("res://scripts/story_rules.gd")
const StoryFlowScript = preload("res://scripts/story_flow.gd")

var failures: Array = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(name: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if condition:
		print("PASS %s" % name)
		return
	failures.append(name + (" · " + detail if not detail.is_empty() else ""))
	print("FAIL %s %s" % [name, detail])


## JSON null is a real value here (e.g. `always_available` is absent for nine of
## the ten sceneries); `String(null)` is a runtime error, so read defensively.
func _text(value: Variant, fallback: String = "") -> String:
	if value is String:
		return value
	if value == null:
		return fallback
	return str(value)


func _is_true(value: Variant) -> bool:
	if value is String:
		return (value as String).to_lower() == "true"
	if value is bool:
		return value
	return false


func _run() -> void:
	var data = StoryDataScript.new()
	check("data loads", data.is_loaded(), data.error)
	if not data.is_loaded():
		_finish()
		return

	_validate_counts(data)
	_validate_field_fidelity(data)
	_validate_tables(data)
	_validate_gating(data)
	_validate_difficulty(data)
	_validate_sequences(data)
	_validate_state(data)
	_validate_env_contract(data)
	_finish()


func _validate_counts(data) -> void:
	check("chapter count is 5", data.chapter_count() == 5, str(data.chapter_count()))
	var expected: Dictionary = {
		"chapter1": [13, 17, 11],
		"chapter2": [9, 13, 9],
		"chapter3": [9, 14, 11],
		"chapter4": [10, 16, 11],
		"chapter5": [8, 11, 7],
	}
	var total_events: int = 0
	var total_battles: int = 0
	var total_unlocks: int = 0
	for index: int in range(data.chapter_count()):
		var chapter: Dictionary = data.chapter(index)
		var chapter_id: String = String(chapter.get("id", ""))
		var event_rows: Array = data.events(index)
		var battles: int = 0
		var unlocks: int = 0
		for event_row: Variant in event_rows:
			battles += data.battle_subs(Dictionary(event_row)).size()
			unlocks += data.unlock_subs(Dictionary(event_row)).size()
		total_events += event_rows.size()
		total_battles += battles
		total_unlocks += unlocks
		var want: Array = expected.get(chapter_id, [])
		check("counts %s events" % chapter_id, event_rows.size() == int(want[0]),
			"%d != %d" % [event_rows.size(), int(want[0])])
		check("counts %s battles" % chapter_id, battles == int(want[1]),
			"%d != %d" % [battles, int(want[1])])
		check("counts %s unlocks" % chapter_id, unlocks == int(want[2]),
			"%d != %d" % [unlocks, int(want[2])])
	check("total events 49", total_events == 49, str(total_events))
	check("total battles 71", total_battles == 71, str(total_battles))
	check("total unlocks 49", total_unlocks == 49, str(total_unlocks))


func _validate_field_fidelity(data) -> void:
	## Nothing may appear in the data that the decoder did not recover.
	var event_keys: Dictionary = {
		"versus_event": ["index", "maptitle", "type", "mapx", "mapy", "required_exp", "subevents"],
		"survival_event": ["index", "maptitle", "type", "mapx", "mapy", "subevents"],
		"arcade_event": ["index", "maptitle", "type", "mapx", "mapy", "subevents"],
		"timeattack_event": ["index", "maptitle", "type", "mapx", "mapy", "subevents"],
		"story_event": [
			"index", "maptitle", "type", "mapx", "mapy", "subevents",
			"required_exp", "required_completion", "auto_launch", "chapter_end",
		],
	}
	var sub_keys: Dictionary = {
		"vsbattle": [
			"type", "rounds", "player", "opponent", "scenery", "difficulty", "aitree",
			"advice", "win_on_lose", "player_infinite_rage", "opponent_infinite_rage",
			"player_starting_health", "time",
		],
		"survival": [
			"type", "player", "opponents", "scenery", "difficulty", "aitree",
			"maximum_fights", "health_recovery",
		],
		"arcade": [
			"type", "rounds", "player", "opponents", "scenery", "difficulty", "aitree", "time",
		],
		"timeattack": [
			"type", "player", "opponents", "scenery", "difficulty", "aitree", "time_limit",
		],
		"unlock": ["type", "id", "item_type", "item_id"],
		"picture": ["type", "layers", "text", "music"],
	}
	var unknown_keys: Array = []
	var missing_required: Array = []
	var bad_difficulty: Array = []
	var seen_types: Dictionary = {}
	for index: int in range(data.chapter_count()):
		for event_value: Variant in data.events(index):
			var event_row: Dictionary = event_value
			var event_type: String = String(event_row.get("type", ""))
			seen_types[event_type] = true
			for key_value: Variant in event_row.keys():
				var key: String = String(key_value)
				if not event_keys.get(event_type, []).has(key):
					unknown_keys.append("%s.%s" % [event_type, key])
			for required_key: String in ["maptitle", "type", "mapx", "mapy"]:
				if not event_row.has(required_key):
					missing_required.append("%s missing %s" % [event_type, required_key])
			for sub_value: Variant in data.subevents(event_row):
				var sub: Dictionary = sub_value
				var kind: String = String(sub.get("type", ""))
				if not sub_keys.has(kind):
					unknown_keys.append("subevent type " + kind)
					continue
				for key_value: Variant in sub.keys():
					var key: String = String(key_value)
					if not sub_keys[kind].has(key):
						unknown_keys.append("%s.%s" % [kind, key])
				if kind in StoryRules.BATTLE_TYPES:
					if not sub.has("scenery") or not sub.has("player"):
						missing_required.append(kind + " missing scenery/player")
					var difficulty: Array = sub.get("difficulty", [])
					if difficulty.size() != 3:
						bad_difficulty.append("%s difficulty size %d" % [kind, difficulty.size()])
					for value: Variant in difficulty:
						if typeof(value) != TYPE_INT:
							bad_difficulty.append("%s difficulty value %s" % [kind, str(value)])
					if kind == "vsbattle" and not sub.has("opponent"):
						missing_required.append("vsbattle missing opponent")
					if kind in ["survival", "arcade", "timeattack"] \
							and not sub.has("opponents"):
						missing_required.append(kind + " missing opponents")
	check("no unknown data fields", unknown_keys.is_empty(),
		", ".join(PackedStringArray(unknown_keys.slice(0, 8))))
	check("required fields present", missing_required.is_empty(),
		", ".join(PackedStringArray(missing_required.slice(0, 8))))
	check("difficulty is a 3-int array everywhere", bad_difficulty.is_empty(),
		", ".join(PackedStringArray(bad_difficulty.slice(0, 8))))
	check("all six subevent kinds present", seen_types.has("story_event")
		and seen_types.has("versus_event") and seen_types.has("survival_event")
		and seen_types.has("arcade_event") and seen_types.has("timeattack_event"))

	# Spot checks straight against the decode report tables.
	var chapter1: Array = data.events(0)
	var story_1: Dictionary = {}
	for event_value: Variant in chapter1:
		if String(Dictionary(event_value).get("maptitle", "")) == "s_master_1":
			story_1 = event_value
	var battles: Array = data.battle_subs(story_1)
	check("s_master_1 has 1 vsbattle", battles.size() == 1, str(battles.size()))
	if battles.size() == 1:
		var battle: Dictionary = battles[0]
		check("s_master_1 opponent shen lo", String(battle.get("opponent", "")) == "shen lo",
			String(battle.get("opponent", "")))
		check("s_master_1 scenery market", String(battle.get("scenery", "")) == "market",
			String(battle.get("scenery", "")))
		check("s_master_1 difficulty [0,1,2]",
			str(battle.get("difficulty", [])) == str([0, 1, 2]),
			str(battle.get("difficulty", [])))
		check("s_master_1 rounds 1", int(battle.get("rounds", 0)) == 1)
		check("s_master_1 has no time field", not battle.has("time"))
		check("s_master_1 advice loading1", String(battle.get("advice", "")) == "loading1")
	var chapter1_subs: Array = data.subevents(story_1)
	check("s_master_1 has 12 subevents", chapter1_subs.size() == 12, str(chapter1_subs.size()))
	check("s_master_1 has 2 unlocks", data.unlock_subs(story_1).size() == 2)
	# chapter1 s_master_2 carries difficulty [4,4,4] and win_on_lose true
	var story_2: Dictionary = {}
	for event_value: Variant in chapter1:
		if String(Dictionary(event_value).get("maptitle", "")) == "s_master_2":
			story_2 = event_value
	var battles_2: Array = data.battle_subs(story_2)
	if battles_2.size() == 1:
		check("s_master_2 difficulty [4,4,4]",
			str(Dictionary(battles_2[0]).get("difficulty", [])) == str([4, 4, 4]))
		check("s_master_2 win_on_lose true",
			String(Dictionary(battles_2[0]).get("win_on_lose", "")) == "true")
		check("s_master_2 time 30", int(Dictionary(battles_2[0]).get("time", 0)) == 30)


func _validate_tables(data) -> void:
	var sceneries: Array = data.tables().get("sceneries", [])
	check("sceneries.list has 10 rows", sceneries.size() == 10, str(sceneries.size()))
	var always: Array = []
	for row: Variant in sceneries:
		var scenery_row: Dictionary = row
		if _is_true(scenery_row.get("always_available")):
			always.append(_text(scenery_row.get("name")))
	check("exactly market is always available", always == ["market"], str(always))
	check("sceneries carry a port scene variant",
		_text((sceneries[0] as Dictionary).get("port_scene_variant")) == "squarea",
		_text((sceneries[0] as Dictionary).get("port_scene_variant")))
	var variants: Dictionary = {}
	for row: Variant in sceneries:
		var scenery_row: Dictionary = row
		variants[_text(scenery_row.get("name"))] = scenery_row.get("port_scene_variant")
	check("market maps to squarea", _text(variants.get("market", "?")) == "squarea")
	check("market b maps to squareb", _text(variants.get("market b", "?")) == "squareb")
	check("temple yard maps to the default scene", _text(variants.get("temple yard", "?")) == "")
	check("temple yard b maps to templeyardb",
		_text(variants.get("temple yard b", "?")) == "templeyardb")
	for name: String in ["harbour", "harbour b", "rooftops", "rooftops b",
			"tournament hall", "tournament hall b"]:
		check("scene variant for " + name, variants.has(name) and variants[name] != null,
			str(variants.get(name, null)))
	check("opponents resolve to port candidates",
		String(data.character_row("lo ming b").get("port_candidate", "")) == "loming")
	check("chief b shares the chief candidate",
		String(data.character_row("chief b").get("port_candidate", "")) == "chief")
	check("shen lo resolves to shenlo",
		String(data.character_row("shen lo").get("port_candidate", "")) == "shenlo")
	# scenery unlock ids 1..9 resolve, id 0 is the always-available market
	var resolved_1: Dictionary = data.resolve_unlock("scenery", 1)
	check("scenery unlock 1 resolves with proof",
		String(resolved_1.get("name", "")) == "market b" and bool(resolved_1.get("proven", false)),
		str(resolved_1))
	var resolved_9: Dictionary = data.resolve_unlock("scenery", 9)
	check("scenery unlock 9 resolves to rooftops b",
		String(resolved_9.get("name", "")) == "rooftops b")
	var profile_1: Dictionary = data.resolve_unlock("fighter_profile", 1)
	check("fighter_profile 1 resolves to shenlo",
		String(profile_1.get("name", "")) == "shenlo" and bool(profile_1.get("proven", false)))
	var style: Dictionary = data.resolve_unlock("style_anim", "lpunchmaster")
	check("style_anim id is a recovered string", String(style.get("name", "")) == "")
	var unlocks_table: Dictionary = data.tables().get("story_unlocks", {})
	check("unlocks.list exp table is present (40 rows)", unlocks_table.size() == 40,
		str(unlocks_table.size()))


func _validate_gating(data) -> void:
	var chapter1_id: String = data.chapter_id(0)
	var event_2: Dictionary = {}
	var event_1: Dictionary = {}
	for event_value: Variant in data.events(0):
		var event_row: Dictionary = event_value
		var maptitle: String = String(event_row.get("maptitle", ""))
		if maptitle == "s_master_1":
			event_1 = event_row
		if maptitle == "s_master_2":
			event_2 = event_row
	var gate_locked: Dictionary = StoryRules.event_gate(event_2, [], 0)
	check("s_master_2 locked before s_master_1", not bool(gate_locked.get("available", true)),
		str(gate_locked))
	var gate_open: Dictionary = StoryRules.event_gate(event_2, ["s_master_1"], 0)
	check("s_master_2 available after s_master_1", bool(gate_open.get("available", false)))
	var gate_first: Dictionary = StoryRules.event_gate(event_1, [], 0)
	check("s_master_1 available at exp 0", bool(gate_first.get("available", false)))
	# chapter3 versus node requires exp 4000
	var exp_event: Dictionary = {}
	for event_value: Variant in data.events(2):
		var event_row: Dictionary = event_value
		if int(event_row.get("required_exp", 0)) == 4000:
			exp_event = event_row
	check("chapter3 has a required_exp 4000 event", not exp_event.is_empty())
	if not exp_event.is_empty():
		check("exp 4000 event locked at exp 0",
			not bool(StoryRules.event_gate(exp_event, [], 0).get("available", true)))
		check("exp 4000 event open at exp 4000",
			bool(StoryRules.event_gate(exp_event, [], 4000).get("available", false)))
		check("exp 4000 event locked at exp 3999",
			not bool(StoryRules.event_gate(exp_event, [], 3999).get("available", true)))
	# story chain order from the decoded required_completion links
	var chain: Array = []
	for event_value: Variant in data.events(0):
		var event_row: Dictionary = event_value
		if String(event_row.get("type", "")) == "story_event":
			chain.append(String(event_row.get("maptitle", "")))
	check("chapter1 story chain order", str(chain) == str([
		"s_master_1", "s_master_2", "s_master_3", "s_master_4", "s_master_5", "s_master_6",
	]), str(chain))


func _validate_difficulty(data) -> void:
	var battle: Dictionary = {}
	for event_value: Variant in data.events(0):
		for sub_value: Variant in data.subevents(Dictionary(event_value)):
			var sub: Dictionary = sub_value
			if String(sub.get("type", "")) == "vsbattle" and String(sub.get("opponent", "")) == "shen lo":
				battle = sub
				break
	check("difficulty slot names are easy/medium/hard",
		str(data.difficulty_slot_names()) == str(["easy", "medium", "hard"]))
	check("easy selects 0", data.difficulty_value(battle, 0) == 0)
	check("medium selects 1", data.difficulty_value(battle, 1) == 1)
	check("hard selects 2", data.difficulty_value(battle, 2) == 2)
	check("difficulty values stay verbatim above 2",
		data.difficulty_value({"difficulty": [4, 4, 4]}, 2) == 4)


func _validate_sequences(data) -> void:
	var chapter1_id: String = data.chapter_id(0)
	var story_1: Dictionary = data.event(0, 7)
	var sub: Dictionary = data.battle_subs(story_1)[0]
	var run: Dictionary = StoryRules.build_run(chapter1_id, story_1, sub, 6, 0,
		data.difficulty_value(sub, 0))
	check("run keeps the exact source record",
		str(run.get("source", {})) == str(sub))
	var spec: Dictionary = StoryRules.next_fight_spec(data, run)
	check("spec opponent", String(spec.get("opponent", "")) == "shen lo")
	check("spec candidate", String(spec.get("port_candidate", "")) == "shenlo")
	check("spec scene variant", String(spec.get("scene_variant", "")) == "squarea")
	check("spec rounds", int(spec.get("rounds", -1)) == 1)
	check("spec time 0 (no recovered time)", int(spec.get("time", -1)) == 0)
	check("spec difficulty value", int(spec.get("difficulty_value", -1)) == 0)
	check("spec start health unset", float(spec.get("start_health", -1.0)) < 0.0)
	check("spec keeps the advisory key", String(spec.get("advice", "")) == "loading1")
	var won: Dictionary = StoryRules.apply_result(run, {"won": true, "health": 42.0,
		"fight_seconds": 12.0})
	check("vsbattle win completes the run", String(won.get("outcome", "")) == "complete",
		str(won.get("outcome", "")))
	var lost: Dictionary = StoryRules.apply_result(run, {"won": false, "health": 0.0,
		"fight_seconds": 12.0})
	check("vsbattle loss fails the run", String(lost.get("outcome", "")) == "failed")

	# win_on_lose (s_master_2): a loss still completes the event
	var story_2: Dictionary = data.event(0, 8)
	var sub_2: Dictionary = data.battle_subs(story_2)[0]
	var run_2: Dictionary = StoryRules.build_run(chapter1_id, story_2, sub_2, 4, 0, 4)
	check("s_master_2 spec difficulty 4",
		int(StoryRules.next_fight_spec(data, run_2).get("difficulty_value", -1)) == 4)
	check("s_master_2 loss still completes (win_on_lose)",
		String(StoryRules.apply_result(run_2, {"won": false, "health": 0.0}).get("outcome", ""))
		== "complete")

	# arcade: ordered opponents, rounds to win, advance until complete
	var arcade_run: Dictionary = {}
	for event_value: Variant in data.events(0):
		for sub_value: Variant in data.subevents(Dictionary(event_value)):
			var candidate: Dictionary = sub_value
			if String(candidate.get("type", "")) == "arcade":
				arcade_run = StoryRules.build_run(chapter1_id, Dictionary(event_value),
					candidate, 0, 1, data.difficulty_value(candidate, 1))
	check("arcade run found", not arcade_run.is_empty())
	if not arcade_run.is_empty():
		check("arcade opponents come from the file",
			str(arcade_run.get("opponents", [])) == str(["the master", "johnson", "sin fu",
				"ken godall", "smallboy", "chief a"]),
			str(arcade_run.get("opponents", [])))
		var step1: Dictionary = StoryRules.apply_result(arcade_run, {"won": true, "health": 80.0})
		check("arcade win advances", String(step1.get("outcome", "")) == "next")
		var spec2: Dictionary = StoryRules.next_fight_spec(data, step1.get("run", {}))
		check("arcade next opponent is johnson",
			String(spec2.get("opponent", "")) == "johnson", String(spec2.get("opponent", "")))
		var step_many: Dictionary = step1
		var rounds: int = 0
		while String(step_many.get("outcome", "")) == "next" and rounds < 10:
			step_many = StoryRules.apply_result(step_many.get("run", {}),
				{"won": true, "health": 80.0})
			rounds += 1
		check("arcade completes after the last opponent",
			String(step_many.get("outcome", "")) == "complete", str(step_many.get("outcome", "")))

	# survival: maximum_fights + health_recovery
	var survival_run: Dictionary = {}
	for event_value: Variant in data.events(0):
		for sub_value: Variant in data.subevents(Dictionary(event_value)):
			var candidate: Dictionary = sub_value
			if String(candidate.get("type", "")) == "survival":
				survival_run = StoryRules.build_run(chapter1_id, Dictionary(event_value),
					candidate, 0, 0, 0)
	check("survival run found", not survival_run.is_empty())
	if not survival_run.is_empty():
		check("survival maximum_fights 2", int(survival_run.get("maximum_fights", -1)) == 2)
		check("survival health_recovery 15", int(survival_run.get("health_recovery", -1)) == 15)
		var after: Dictionary = StoryRules.apply_result(survival_run, {"won": true, "health": 70.0})
		var next_run: Dictionary = after.get("run", {})
		check("survival carries health + recovery",
			abs(float(next_run.get("carried_health", -1.0)) - 85.0) < 0.001,
			str(next_run.get("carried_health", -1.0)))
		var next_spec: Dictionary = StoryRules.next_fight_spec(data, next_run)
		check("survival next fight starts at the carried health",
			abs(float(next_spec.get("start_health", -1.0)) - 85.0) < 0.001,
			str(next_spec.get("start_health", -1.0)))
		var second: Dictionary = StoryRules.apply_result(next_run, {"won": true, "health": 60.0})
		check("survival completes at maximum_fights",
			String(second.get("outcome", "")) == "complete", str(second.get("outcome", "")))

	# timeattack: time_limit aborts the sequence
	var timeattack_run: Dictionary = {}
	for event_value: Variant in data.events(0):
		for sub_value: Variant in data.subevents(Dictionary(event_value)):
			var candidate: Dictionary = sub_value
			if String(candidate.get("type", "")) == "timeattack":
				timeattack_run = StoryRules.build_run(chapter1_id, Dictionary(event_value),
					candidate, 0, 0, 0)
	check("timeattack run found", not timeattack_run.is_empty())
	if not timeattack_run.is_empty():
		check("timeattack time_limit 80", int(timeattack_run.get("time_limit", -1)) == 80)
		var over: Dictionary = StoryRules.apply_result(timeattack_run,
			{"won": true, "health": 90.0, "fight_seconds": 81.0})
		check("timeattack fails past the time limit",
			String(over.get("outcome", "")) == "failed", str(over.get("outcome", "")))

	# player_starting_health (chapter5 s_changes)
	var last_chapter: int = data.chapter_count() - 1
	for event_value: Variant in data.events(last_chapter):
		for sub_value: Variant in data.subevents(Dictionary(event_value)):
			var candidate: Dictionary = sub_value
			if int(candidate.get("player_starting_health", 0)) == 90:
				var start_run: Dictionary = StoryRules.build_run(data.chapter_id(last_chapter),
					Dictionary(event_value), candidate, 0, 0,
					data.difficulty_value(candidate, 0))
				var start_spec: Dictionary = StoryRules.next_fight_spec(data, start_run)
				check("player_starting_health reaches the match launcher",
					abs(float(start_spec.get("start_health", -1.0)) - 90.0) < 0.001,
					str(start_spec.get("start_health", -1.0)))
				return
	check("player_starting_health battle not found", false)


func _validate_state(data) -> void:
	for slot: int in range(1, StoryStateScript.SLOT_COUNT + 1):
		if StoryStateScript.slot_exists(slot):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(
				StoryStateScript.slot_path(slot)))
	var state = StoryStateScript.new()
	check("new story writes the slot", state.new_story(2, 1, "medium"))
	check("slot file exists", StoryStateScript.slot_exists(2))
	check("difficulty stored", state.difficulty_slot == 1 and state.difficulty_name == "medium")
	check("chapter starts at 0", state.chapter_index == 0)
	check("unlock dedupe", state.add_unlock(108, "fighter_profile", 1, "chapter1",
		"s_master_1", 10) and not state.add_unlock(108, "fighter_profile", 1, "chapter1",
		"s_master_1", 10))
	check("unlock recorded", state.unlocks.size() == 1 and state.has_unlock(108))
	state.set_pending({"run": {"event": "s_master_1"}, "spec": {"opponent": "shen lo"}})
	check("pending saved", state.save())
	var reloaded = StoryStateScript.new()
	check("slot reloads", reloaded.load_slot(2))
	check("pending survives reload", reloaded.has_pending(),
		str(reloaded.pending))
	check("unlock survives reload", reloaded.unlocks.size() == 1)
	reloaded.clear_pending()
	reloaded.mark_completed("chapter1", "s_master_1")
	check("completion recorded", reloaded.is_event_completed("chapter1", "s_master_1"))
	check("chapter advance", reloaded.advance_chapter(5) and reloaded.chapter_index == 1)
	check("chapter advance stops at the last chapter", not _advance_to_end(reloaded, data))
	for slot: int in range(1, StoryStateScript.SLOT_COUNT + 1):
		if StoryStateScript.slot_exists(slot):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(
				StoryStateScript.slot_path(slot)))


func _advance_to_end(state, data) -> bool:
	while state.chapter_index < data.chapter_count() - 1:
		if not state.advance_chapter(data.chapter_count()):
			return false
	return state.advance_chapter(data.chapter_count())


func _validate_env_contract(data) -> void:
	var configs: Dictionary = {
		"shenlo": {
			"glb": "X:/shenlo.glb", "texture_root": "X:/shenlo-tex",
			"clip_prefix": "m04", "master": "", "material_profile": "body",
			"attack_config": "res://data/attack_config_shenlo.json", "skeleton": "medium",
		},
	}
	var flow = StoryFlowScript.new()
	flow.configure(null, configs)
	var story_1: Dictionary = data.event(0, 7)
	var sub: Dictionary = data.battle_subs(story_1)[0]
	var run: Dictionary = StoryRules.build_run(data.chapter_id(0), story_1, sub, 6, 0, 0)
	var spec: Dictionary = StoryRules.next_fight_spec(data, run)
	flow.apply_match_loader_env(spec)
	check("env story flow", OS.get_environment("BRUCELEE_STORY_FLOW") == "1")
	check("env main menu off", OS.get_environment("BRUCELEE_MAIN_MENU") == "0")
	check("env opponent glb", OS.get_environment("BRUCELEE_OPPONENT_GLB") == "X:/shenlo.glb")
	check("env opponent name key",
		OS.get_environment("BRUCELEE_OPPONENT_NAME_KEY") == "shenlo")
	check("env attack config", OS.get_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG")
		== "res://data/attack_config_shenlo.json")
	check("env scene variant", OS.get_environment("BRUCELEE_SCENE") == "squarea")
	check("env round time 0", OS.get_environment("BRUCELEE_ROUND_TIME") == "0")
	check("env match rounds 1", OS.get_environment("BRUCELEE_MATCH_ROUNDS") == "1")
	check("env ai difficulty 0", OS.get_environment("BRUCELEE_AI_DIFFICULTY") == "0")
	check("env start health cleared",
		OS.get_environment("BRUCELEE_PLAYER_START_HEALTH") == "")
	flow.free()


func _finish() -> void:
	print("")
	print("CHECKS %d · FAILURES %d" % [checks, failures.size()])
	for failure: Variant in failures:
		print("  FAILED: " + String(failure))
	print("STORY_FLOW_VALIDATE " + ("OK" if failures.is_empty() else "FAILED"))
	quit(0 if failures.is_empty() else 1)

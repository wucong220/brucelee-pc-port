extends RefCounted
## Pure, testable rules for the recovered Arcade / Survival / Time Attack modes.
##
## This file contains NO invented numbers. Every value below is either:
##   * copied verbatim from the disassembly of the shipped libdefault.so, or
##   * parsed out of data/game_modes.json (which records its provenance), or
##   * explicitly flagged unrecovered -> the mode fails closed and refuses to
##     fabricate a value.
##
## Disassembly this mirrors (see data/game_modes.json -> provenance):
##   IBeatEmUpGameMode::GetNumRoundsFromSetting @0x1fec94
##       0.0 => 1, 1.0 => 2, 2.0 => 3, else => 4
##   IBeatEmUpGameMode::GetTimeFromSetting @0x1fecdc
##       0.0 => 30, 1.0 => 60, 2.0 => 90, 3.0 => 0 (no countdown), else => 60
##   CBruceLeeArcadeMode::FightBaseScore @0x1e0d18
##       100 + 25 * trunc(GetTReal("arcade_difficulty"))
##   difficulty byte = trunc(2 * setting): easy 0 -> 0, medium 1 -> 2, hard 2 -> 4

const DATA_PATH := "res://data/game_modes.json"
## Byte-identical copy of the same original rules file shipped next to the
## executable as data/game_modes.json (see build_windows.ps1). It is only a
## fallback for packaged/mixed installs where res:// cannot hand out the packed
## copy; the bytes are the original file, never regenerated or invented.
const SIDECAR_PATH := "data/game_modes.json"

## GetNumRoundsFromSetting (index -> rounds)
const ARCADE_ROUNDS_BY_INDEX: Array[int] = [1, 2, 3, 4]
## GetTimeFromSetting (index -> seconds; 0 means no countdown)
const TIME_BY_INDEX: Array[int] = [30, 60, 90, 0]
## difficulty byte = trunc(2 * ui_index)
const AI_SLOT_BY_INDEX: Array[int] = [0, 2, 4]

const MAX_HEALTH: float = 100.0
const MODE_ARCADE := "arcade"
const MODE_SURVIVAL := "survival"
const MODE_TIMEATTACK := "timeattack"
const MODE_LABELS := {"arcade": "ARCADE", "survival": "SURVIVAL", "timeattack": "TIME ATTACK"}


static func _parse_rules_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


static func load_rules() -> Dictionary:
	var rules: Dictionary = _parse_rules_file(DATA_PATH)
	if not rules.is_empty():
		return rules
	# Packaged / mixed installs: read the SAME original file from beside the
	# executable. If neither location yields valid rules, stay fail-closed.
	var exe_dir: String = OS.get_executable_path().get_base_dir()
	if exe_dir.is_empty():
		return {}
	return _parse_rules_file(exe_dir.path_join(SIDECAR_PATH))


static func difficulty_slot(ui_index: int) -> int:
	return AI_SLOT_BY_INDEX[clampi(ui_index, 0, AI_SLOT_BY_INDEX.size() - 1)]


static func rounds_for_index(ui_index: int) -> int:
	return ARCADE_ROUNDS_BY_INDEX[clampi(ui_index, 0, ARCADE_ROUNDS_BY_INDEX.size() - 1)]


static func time_seconds_for_index(ui_index: int) -> int:
	return TIME_BY_INDEX[clampi(ui_index, 0, TIME_BY_INDEX.size() - 1)]


static func arcade_fight_score(difficulty_ui_index: int) -> int:
	return 100 + 25 * clampi(difficulty_ui_index, 0, 2)


## Human-readable, fully recovered rule table. Used by the UI, the tests and
## the report generator; it is the single source of truth for the numbers.
static func rules_report() -> Dictionary:
	return {
		"arcade_rounds_by_index": ARCADE_ROUNDS_BY_INDEX.duplicate(),
		"time_seconds_by_index": TIME_BY_INDEX.duplicate(),
		"ai_slot_by_difficulty_index": AI_SLOT_BY_INDEX.duplicate(),
		"arcade_fight_score_by_difficulty_index": [
			arcade_fight_score(0), arcade_fight_score(1), arcade_fight_score(2)
		],
		"fail_closed": {
			"arcade": ["lives"],
			"survival": ["max_fights", "health_recovery", "score", "lives"],
			"timeattack": ["time_limit", "score", "lives"]
		}
	}


## Resolve a settings selection into concrete match inputs, or fail closed.
## `settings` keys: rounds, time, difficulty, time_limit_preset (mode-dependent).
static func resolve(mode: String, settings: Dictionary) -> Dictionary:
	var difficulty_index: int = int(settings.get("difficulty", 1))
	var out: Dictionary = {
		"mode": mode,
		"ok": true,
		"blocked": [],
		"resolved": {},
		"fail_closed": [],
	}
	out["resolved"]["difficulty_index"] = difficulty_index
	out["resolved"]["difficulty_slot"] = difficulty_slot(difficulty_index)
	if mode == MODE_ARCADE:
		out["resolved"]["rounds"] = rounds_for_index(int(settings.get("rounds", 0)))
		out["resolved"]["time_limit"] = time_seconds_for_index(int(settings.get("time", 1)))
		out["resolved"]["score_per_fight"] = arcade_fight_score(difficulty_index)
		out["fail_closed"] = ["lives"]
	elif mode == MODE_SURVIVAL:
		out["resolved"]["time_limit"] = time_seconds_for_index(int(settings.get("time", 1)))
		out["fail_closed"] = ["max_fights", "health_recovery", "score", "lives"]
		# A caller may supply a recovered per-event value (from a chapter
		# survival_event). Only then is the field used; otherwise it stays
		# fail-closed rather than being invented.
		for key: String in ["max_fights", "health_recovery"]:
			if settings.has(key) and int(settings[key]) > 0:
				out["resolved"][key] = int(settings[key])
				(out["fail_closed"] as Array).erase(key)
	elif mode == MODE_TIMEATTACK:
		var preset: int = int(settings.get("time_limit_preset", -1))
		if preset <= 0:
			out["ok"] = false
			out["blocked"] = ["time_limit"]
			out["fail_closed"] = ["time_limit", "score", "lives"]
			out["resolved"]["time_limit"] = -1
		else:
			out["resolved"]["time_limit"] = preset
			out["fail_closed"] = ["score", "lives"]
	else:
		out["ok"] = false
		out["blocked"] = ["unknown_mode"]
	return out


## Build a fresh run dictionary. Opponents/scenes are drawn deterministically
## from the port candidate pools in game_modes.json (no invented fighters).
static func build_run(mode: String, settings: Dictionary, data: Dictionary) -> Dictionary:
	var resolved: Dictionary = resolve(mode, settings)
	if not bool(resolved.get("ok", false)):
		return {"ok": false, "blocked": resolved.get("blocked", []), "run": {}}
	var pool: Array = data.get("port_opponent_pool", [])
	var scene_pool: Array = data.get("port_scene_pool", [])
	var r: Dictionary = resolved.get("resolved", {})
	var run: Dictionary = {
		"ok": true,
		"mode": mode,
		"kind": mode,
		"settings": settings.duplicate(true),
		"resolved": r,
		"difficulty_index": int(r.get("difficulty_index", 1)),
		"difficulty_slot": int(r.get("difficulty_slot", 2)),
		"time_limit": int(r.get("time_limit", 0)),
		"opponent_index": 0,
		"fights_done": 0,
		"score": 0,
		"carried_health": -1.0,
		"elapsed_seconds": 0.0,
		"fight_results": [],
		"fail_closed": resolved.get("fail_closed", []),
	}
	# Optional recovered per-event combat caps/heals (story survival_event).
	for key: String in ["max_fights", "health_recovery"]:
		if r.has(key):
			run[key] = int(r[key])
	if mode == MODE_ARCADE:
		var rounds: int = int(r.get("rounds", 1))
		run["opponents"] = _pick(pool, rounds, 1)
		run["scenes"] = _pick(scene_pool, rounds, 2)
		run["opponent_count"] = rounds
		run["endless"] = false
	elif mode == MODE_SURVIVAL:
		# Standalone survival: no recovered maximum_fights -> effectively endless
		# until the player loses; opponents cycle through the candidate pool.
		run["opponents"] = _pick(pool, pool.size(), 3)
		run["scenes"] = _pick(scene_pool, pool.size(), 4)
		run["opponent_count"] = -1
		run["endless"] = true
	else: # timeattack
		run["opponents"] = _pick(pool, pool.size(), 5)
		run["scenes"] = _pick(scene_pool, pool.size(), 6)
		run["opponent_count"] = pool.size()
		run["endless"] = true
		run["run_time_limit"] = int(r.get("time_limit", 0))
	return run


static func _pick(pool: Array, count: int, salt: int) -> Array:
	var out: Array = []
	if pool.is_empty():
		return out
	for i: int in range(maxi(1, count)):
		out.append(pool[(i * 2 + salt) % pool.size()])
	return out


static func current_opponent(run: Dictionary) -> String:
	var list: Array = run.get("opponents", [])
	if list.is_empty():
		return ""
	var index: int = int(run.get("opponent_index", 0)) % list.size()
	return String(list[index])


static func current_scene(run: Dictionary) -> String:
	var list: Array = run.get("scenes", [])
	if list.is_empty():
		return ""
	var index: int = int(run.get("opponent_index", 0)) % list.size()
	return String(list[index])


## Match-loader inputs for the current fight of the run.
static func next_fight_spec(run: Dictionary, opponent_config: Dictionary) -> Dictionary:
	var opponent: String = current_opponent(run)
	var config: Dictionary = opponent_config.get(opponent, {})
	var start_health: float = float(run.get("carried_health", -1.0))
	return {
		"mode": String(run.get("mode", "")),
		"kind": String(run.get("kind", "")),
		"opponent": opponent,
		"opponent_index": int(run.get("opponent_index", 0)),
		"opponent_count": int(run.get("opponent_count", -1)),
		"scene_variant": current_scene(run),
		"time": int(run.get("time_limit", 0)),
		"run_time_limit": int(run.get("run_time_limit", -1)),
		"rounds_to_win": 1,
		"difficulty_index": int(run.get("difficulty_index", 1)),
		"difficulty_slot": int(run.get("difficulty_slot", 2)),
		"start_health": start_health,
		"score": int(run.get("score", 0)),
		"port_candidate": String(config.get("port_candidate", opponent)),
	}


## Apply the result of the fight that just ended.
## result: {won: bool, health: float, fight_seconds: float}
## Returns {outcome: "next"|"complete"|"failed", run, reason, score_added}
static func apply_result(run_in: Dictionary, result: Dictionary) -> Dictionary:
	var run: Dictionary = run_in.duplicate(true)
	var won: bool = bool(result.get("won", false))
	var health: float = float(result.get("health", MAX_HEALTH))
	var seconds: float = float(result.get("fight_seconds", 0.0))
	run["elapsed_seconds"] = float(run.get("elapsed_seconds", 0.0)) + seconds
	run["fights_done"] = int(run.get("fights_done", 0)) + 1
	var results: Array = run.get("fight_results", [])
	results.append({
		"opponent": current_opponent(run_in),
		"won": won,
		"health": health,
		"seconds": seconds,
	})
	run["fight_results"] = results
	var score_added: int = 0
	var mode: String = String(run.get("mode", ""))

	# A time-attack run has a total budget that ends the run when exceeded.
	if run.has("run_time_limit") and int(run["run_time_limit"]) > 0:
		if float(run["elapsed_seconds"]) > float(run["run_time_limit"]):
			run["carried_health"] = health
			return {"outcome": "failed", "run": run, "score_added": score_added,
				"reason": "time limit %d s exceeded" % int(run["run_time_limit"])}

	if not won:
		run["carried_health"] = health
		return {"outcome": "failed", "run": run, "score_added": score_added,
			"reason": "match lost"}

	if mode == MODE_ARCADE:
		score_added = arcade_fight_score(int(run.get("difficulty_index", 1)))
		run["score"] = int(run.get("score", 0)) + score_added

	var index: int = int(run.get("opponent_index", 0))
	var endless: bool = bool(run.get("endless", false))
	var count: int = int(run.get("opponent_count", -1))
	# Only authored rules can carry health between fights. Standalone survival
	# carries remaining health but applies NO invented heal.
	if bool(run.get("endless", false)) or mode == MODE_SURVIVAL or mode == MODE_TIMEATTACK:
		var carried: float = health
		if run.has("health_recovery") and int(run["health_recovery"]) > 0:
			carried = minf(MAX_HEALTH, carried + float(int(run["health_recovery"])))
		run["carried_health"] = carried
	else:
		run["carried_health"] = -1.0  # arcade resets to full each bout (no carry rule recovered)

	run["opponent_index"] = index + 1
	if not endless and index + 1 >= count:
		return {"outcome": "complete", "run": run, "score_added": score_added, "reason": ""}
	var max_fights: int = int(run.get("max_fights", -1))
	if max_fights > 0 and int(run["fights_done"]) >= max_fights:
		return {"outcome": "complete", "run": run, "score_added": score_added, "reason": ""}
	return {"outcome": "next", "run": run, "score_added": score_added, "reason": ""}

extends RefCounted
## Story-mode rules: event gating, battle-run construction and run advancement.
##
## Everything here is a pure function of the decoded story data plus the saved
## progress.  No value is invented: a run only ever carries fields that the
## decoded battle subevent actually contains, and an absent field stays absent
## (the caller then leaves the matching match-loader input untouched).

const BATTLE_TYPES: Array[String] = ["vsbattle", "survival", "arcade", "timeattack"]
## PortFighter.MAX_HEALTH; used only to clamp carried-over health.
const MAX_HEALTH: float = 100.0
## main.gd's ROUNDS_TO_WIN default, used only when a battle has no `rounds`.
const DEFAULT_ROUNDS_TO_WIN: int = 2


static func battle_opponents(sub: Dictionary) -> Array:
	var out: Array = []
	var listed: Variant = sub.get("opponents")
	if listed is Array and not (listed as Array).is_empty():
		for value: Variant in listed:
			out.append(String(value))
		return out
	if sub.has("opponent"):
		out.append(String(sub["opponent"]))
	return out


static func battle_kind(sub: Dictionary) -> String:
	return String(sub.get("type", ""))


## Availability of a map event under the recovered gate fields.
## `completed` is the list of finished maptitles inside the same chapter.
static func event_gate(event_row: Dictionary, completed: Array, exp: int) -> Dictionary:
	var required_exp: int = 0
	if event_row.has("required_exp"):
		required_exp = int(event_row["required_exp"])
	var missing: Array = []
	for value: Variant in event_row.get("required_completion", []):
		var name: String = String(value)
		if not completed.has(name):
			missing.append(name)
	var available: bool = missing.is_empty() and exp >= required_exp
	var reasons: Array = []
	if exp < required_exp:
		reasons.append("requires exp %d (saved exp %d)" % [required_exp, exp])
	for name: Variant in missing:
		reasons.append("after " + String(name))
	return {
		"available": available,
		"required_exp": required_exp,
		"missing": missing,
		"reason": " / ".join(reasons),
	}


static func build_run(
	chapter_id: String,
	event_row: Dictionary,
	sub: Dictionary,
	sub_index: int,
	difficulty_slot: int,
	difficulty_value_hint: int = -1
) -> Dictionary:
	var run: Dictionary = {
		"chapter": chapter_id,
		"event": String(event_row.get("maptitle", "")),
		"event_type": String(event_row.get("type", "")),
		"sub_index": sub_index,
		"kind": battle_kind(sub),
		"source": sub.duplicate(true),
		"opponents": battle_opponents(sub),
		"opponent_index": 0,
		"player": String(sub.get("player", "")),
		"scenery": String(sub.get("scenery", "")),
		"difficulty_slot": difficulty_slot,
		"difficulty_value": difficulty_value_hint,
		"fights_done": 0,
		"elapsed_seconds": 0.0,
		"fight_results": [],
		"carried_health": -1.0,
	}
	# Optional recovered fields are copied only when present.
	for key: String in [
		"rounds", "time", "time_limit", "maximum_fights", "health_recovery",
		"advice", "aitree", "win_on_lose", "player_starting_health",
		"player_infinite_rage", "opponent_infinite_rage",
	]:
		if sub.has(key):
			run[key] = sub[key]
	return run


static func opponent_count(run: Dictionary) -> int:
	return (run.get("opponents", []) as Array).size()


static func current_opponent(run: Dictionary) -> String:
	var opponents: Array = run.get("opponents", [])
	var index: int = int(run.get("opponent_index", 0))
	if index < 0 or index >= opponents.size():
		return ""
	return String(opponents[index])


## Everything the match launcher needs for the *current* fight of a run.
## -1 or an absent key means "leave the match loader default in place".
static func next_fight_spec(data, run: Dictionary) -> Dictionary:
	var sub: Dictionary = run.get("source", {})
	var opponent: String = current_opponent(run)
	var character: Dictionary = data.character_row(opponent) if data != null else {}
	var scenery_name: String = String(run.get("scenery", ""))
	var scenery: Dictionary = data.scenery_row(scenery_name) if data != null else {}
	var aitree_file: String = ""
	if sub.get("aitree") is Dictionary:
		aitree_file = String((sub["aitree"] as Dictionary).get("file", ""))
	var advice: String = String(sub.get("advice", ""))
	var spec: Dictionary = {
		"kind": String(run.get("kind", "")),
		"chapter": String(run.get("chapter", "")),
		"event": String(run.get("event", "")),
		"sub_index": int(run.get("sub_index", 0)),
		"opponent": opponent,
		"opponent_index": int(run.get("opponent_index", 0)),
		"opponent_count": opponent_count(run),
		"player": String(run.get("player", "")),
		"scenery": scenery_name,
		"scene_variant": String(scenery.get("port_scene_variant", "")),
		"scene_visuals": scenery.get("visuals", []),
		"scene_translate_name": String(scenery.get("translate_name", "")),
		"port_candidate": String(character.get("port_candidate", "")),
		"character_unique": String(character.get("unique", "")),
		"difficulty_slot": int(run.get("difficulty_slot", 0)),
		"difficulty_value": int(run.get("difficulty_value", -1)),
		"rounds": -1,
		"time": 0,
		"start_health": -1.0,
		"time_limit": -1,
		"maximum_fights": -1,
		"health_recovery": -1,
		"advice": advice,
		"aitree": aitree_file,
		"win_on_lose": String(run.get("win_on_lose", "")).to_lower() == "true",
		"player_infinite_rage": String(run.get("player_infinite_rage", "")).to_lower() == "true",
		"opponent_infinite_rage": String(run.get("opponent_infinite_rage", "")).to_lower() == "true",
	}
	if run.has("rounds"):
		spec["rounds"] = int(run["rounds"])
	if run.has("time"):
		spec["time"] = int(run["time"])
	if run.has("time_limit"):
		spec["time_limit"] = int(run["time_limit"])
	if run.has("maximum_fights"):
		spec["maximum_fights"] = int(run["maximum_fights"])
	if run.has("health_recovery"):
		spec["health_recovery"] = int(run["health_recovery"])
	# Starting health: the recovered per-battle value on the first fight, then
	# the health carried through the sequence.
	var carried: float = float(run.get("carried_health", -1.0))
	if carried >= 0.0:
		spec["start_health"] = carried
	elif run.has("player_starting_health"):
		spec["start_health"] = float(run["player_starting_health"])
	return spec


## Advance a run with the result of the fight that just ended.
## `result`:
##   won              the local player won the match
##   health           player health when the fight ended (PortFighter.health)
##   fight_seconds    wall time the fight took (drives `time_limit`)
static func apply_result(run: Dictionary, result: Dictionary) -> Dictionary:
	var next: Dictionary = run.duplicate(true)
	var won: bool = bool(result.get("won", false))
	var health: float = float(result.get("health", MAX_HEALTH))
	var seconds: float = float(result.get("fight_seconds", 0.0))
	next["elapsed_seconds"] = float(next.get("elapsed_seconds", 0.0)) + seconds
	next["fights_done"] = int(next.get("fights_done", 0)) + 1
	var results: Array = next.get("fight_results", [])
	results.append({
		"opponent": current_opponent(run),
		"won": won,
		"health": health,
		"seconds": seconds,
	})
	next["fight_results"] = results

	var kind: String = String(next.get("kind", ""))
	var win_on_lose: bool = String(next.get("win_on_lose", "")).to_lower() == "true"

	# A sequence-level time limit ends the run as soon as it is exceeded.
	if next.has("time_limit"):
		var limit: float = float(next["time_limit"])
		if float(next["elapsed_seconds"]) > limit:
			next["carried_health"] = health
			return {"outcome": "failed", "run": next,
					"reason": "time limit %d s exceeded" % int(limit)}

	if kind == "vsbattle":
		next["carried_health"] = health
		if won or win_on_lose:
			return {"outcome": "complete", "run": next, "reason": ""}
		return {"outcome": "failed", "run": next, "reason": "match lost"}

	# Multi-opponent kinds: a loss ends the run (there is no recovered
	# win_on_lose on these subevents), a win advances to the next opponent.
	if not won:
		next["carried_health"] = health
		return {"outcome": "failed", "run": next, "reason": "match lost"}

	var index: int = int(next.get("opponent_index", 0))
	var count: int = opponent_count(next)
	var max_fights: int = -1
	if next.has("maximum_fights"):
		max_fights = int(next["maximum_fights"])
	var fought: int = int(next.get("fights_done", 0))
	if index + 1 >= count or (max_fights > 0 and fought >= max_fights):
		next["carried_health"] = health
		return {"outcome": "complete", "run": next, "reason": ""}

	next["opponent_index"] = index + 1
	var carried: float = health
	if next.has("health_recovery"):
		carried = minf(MAX_HEALTH, carried + float(next["health_recovery"]))
	next["carried_health"] = carried
	return {"outcome": "next", "run": next, "reason": ""}


static func rounds_to_win_for(spec: Dictionary) -> int:
	if int(spec.get("rounds", -1)) > 0:
		return int(spec["rounds"])
	return DEFAULT_ROUNDS_TO_WIN


## Which battle subevents of an event still have to be played, in file order.
static func playback_steps(event_row: Dictionary) -> Array:
	return event_row.get("subevents", [])

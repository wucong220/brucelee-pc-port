class_name AchievementEngine
extends RefCounted

## Faithful achievement conditions decoded from adreno_200/achievements.list.
##
## 38 achievements. Each carries a condition descriptor generated only from
## recovered evidence (resource literals + libdefault.so disassembly). A
## condition whose threshold/mechanism was NOT forged is marked
## status="unrecovered", fail_closed=true and can never be auto-awarded.

var rows: Array = []          # [{index,id,pending_icon_index,reached_icon_index,condition}]
var loaded := false


func load_data(path := "res://data/progress/achievements.json") -> bool:
	if not FileAccess.file_exists(path):
		push_error("achievements.json missing at %s" % path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("achievements.json is not an object")
		return false
	for row in parsed.get("achievements", []):
		rows.append({
			"index": int(row["index"]),
			"id": str(row["id"]),
			"pending_icon_index": int(row["pending_icon_index"]),
			"reached_icon_index": int(row["reached_icon_index"]),
			"condition": row["condition"],
		})
	loaded = rows.size() == 38
	return loaded


func row_for_id(id: String) -> Dictionary:
	for r in rows:
		if r["id"] == id:
			return r
	return {}


func is_fail_closed(id: String) -> bool:
	var r := row_for_id(id)
	return not r.is_empty() and bool(r["condition"].get("fail_closed", false))


func condition_status(id: String) -> String:
	var r := row_for_id(id)
	return "" if r.is_empty() else str(r["condition"].get("status", "unrecovered"))


func _satisfied(cond: Dictionary, state: Dictionary) -> bool:
	# Fail closed first: never award an unrecovered / fail-closed condition.
	if bool(cond.get("fail_closed", false)):
		return false
	if str(cond.get("status", "unrecovered")) != "recovered":
		return false
	match str(cond.get("kind", "")):
		"counter_threshold":
			var have := int(state["counters"].get(str(cond["counter"]), 0))
			return have >= int(cond["threshold"])
		"mode_clear":
			var mode := str(cond["mode"])
			var diff := str(cond["difficulty"])
			return bool(state["mode_clears"].get(mode, {}).get(diff, false))
		"story_complete":
			return str(cond["difficulty"]) in state["story"]["completed_difficulties"]
		_:
			return false


func evaluate(state: Dictionary) -> Array:
	## Return ids whose condition is currently satisfied (idempotent).
	var out: Array = []
	for r in rows:
		if _satisfied(r["condition"], state):
			out.append(r["id"])
	return out


func grant(state: Dictionary) -> Array:
	## Add newly satisfied achievement ids to the save state; return the new ids.
	var already: Array = state["achievements"]["reached"]
	var fresh: Array = []
	for id in evaluate(state):
		if not already.has(id):
			already.append(id)
			fresh.append(id)
	already.sort()
	return fresh

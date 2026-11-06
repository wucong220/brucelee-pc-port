class_name UnlockRegistry
extends RefCounted

## Faithful unlock records decoded from adreno_200/unlocks.list.
##
##   num_ids = 117  (id space [0, 116])
##   story_unlocks      -> 40 rows {id, exp, item_type, item_id}; grant when
##                          cumulative story EXP >= exp.
##   story_event_unlocks -> 49 rows authored in chapter*.story subevents; grant
##                          deterministically when that story event completes.
##
## The two id sets are disjoint. Any unlock id that is not covered by either
## recovered source stays locked: nothing is invented.

var num_ids := 0
var story_unlocks: Array = []      # [{id:int, exp:int, item_type, item_id}]
var event_unlocks: Array = []      # [{chapter, event_maptitle, id, item_type, item_id}]
var loaded := false


func load_data(path := "res://data/progress/unlocks.json") -> bool:
	if not FileAccess.file_exists(path):
		push_error("unlocks.json missing at %s" % path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("unlocks.json is not an object")
		return false
	num_ids = int(parsed.get("num_ids", 0))
	for row in parsed.get("story_unlocks", []):
		story_unlocks.append({
			"id": int(row["id"]), "exp": int(row["exp"]),
			"item_type": str(row["item_type"]), "item_id": row["item_id"],
		})
	for row in parsed.get("story_event_unlocks", []):
		event_unlocks.append({
			"chapter": str(row["chapter"]), "event_maptitle": str(row.get("event_maptitle", "")),
			"id": int(row["id"]), "item_type": str(row["item_type"]), "item_id": row["item_id"],
		})
	story_unlocks.sort_custom(func(a, b): return a["exp"] < b["exp"] if a["exp"] != b["exp"] else a["id"] < b["id"])
	loaded = num_ids > 0
	return loaded


func ids_for_exp(exp: int) -> Array:
	var out: Array = []
	for row in story_unlocks:
		if row["exp"] <= exp:
			out.append(row["id"])
	out.sort()
	return out


func ids_for_event(chapter: String, maptitle: String) -> Array:
	var out: Array = []
	for row in event_unlocks:
		if row["chapter"] == chapter and row["event_maptitle"] == maptitle:
			out.append(row["id"])
	out.sort()
	return out


func entry_for_id(id: int) -> Dictionary:
	for row in story_unlocks:
		if row["id"] == id:
			return {"source": "story_exp", "exp": row["exp"], "item_type": row["item_type"], "item_id": row["item_id"]}
	for row in event_unlocks:
		if row["id"] == id:
			return {"source": "story_event", "chapter": row["chapter"], "event_maptitle": row["event_maptitle"],
				"item_type": row["item_type"], "item_id": row["item_id"]}
	return {}

extends RefCounted
## Read-only accessor for `res://data/story/story_mode.json`.
##
## The JSON file is produced by `work/build_story_flow_data.py` from the decoded
## CTX3 story resources (`adreno_200/story/chapter1..5.story`) and from the
## decoded list resources (`sceneries.list`, `unlocks.list`, `characters.list`,
## `artpictures.list`).  Every value served here is copied from that decode; the
## accessors never synthesise a missing field.

const DATA_PATH: String = "res://data/story/story_mode.json"
const BATTLE_TYPES: Array[String] = ["vsbattle", "survival", "arcade", "timeattack"]
## Godot's JSON parser returns every number as float.  These are the recovered
## fields that are integers in the decode, so they are converted back; recovered
## float fields (picture layer x/y/scale/color/alpha, radiusscale,
## displacementscale) are left as floats.
const INT_FIELDS: Array[String] = [
	"mapx", "mapy", "required_exp", "rounds", "time", "time_limit",
	"maximum_fights", "health_recovery", "player_starting_health",
	"id", "index", "item_id", "exp", "records", "decoded_bytes", "unlock_id",
]

var data: Dictionary = {}
var error: String = ""


func _init(path: String = DATA_PATH) -> void:
	load_file(path)


func load_file(path: String) -> bool:
	error = ""
	data = {}
	if not FileAccess.file_exists(path):
		error = "story data missing: " + path
		return false
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		error = "story data unreadable: " + path
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		error = "story data root is not an object: " + path
		return false
	var root: Dictionary = parsed
	if not root.has("chapters") or not root.has("tables"):
		error = "story data lacks chapters/tables: " + path
		return false
	for key: Variant in root.keys():
		root[key] = _normalized_value(String(key), root[key])
	data = root
	return true


func _normalized_value(key: String, value: Variant) -> Variant:
	if value is Dictionary:
		var dict: Dictionary = value
		for child_key: Variant in dict.keys():
			dict[child_key] = _normalized_value(String(child_key), dict[child_key])
		return dict
	if value is Array:
		var out: Array = []
		var as_ints: bool = key == "difficulty"
		for item: Variant in value:
			if as_ints and item is float:
				out.append(int(item))
			else:
				out.append(_normalized_value(key, item))
		return out
	if value is float and INT_FIELDS.has(key):
		return int(value)
	return value


func is_loaded() -> bool:
	return not data.is_empty()


func tables() -> Dictionary:
	return data.get("tables", {})


func chapters() -> Array:
	return data.get("chapters", [])


func chapter_count() -> int:
	return chapters().size()


func chapter(index: int) -> Dictionary:
	var rows: Array = chapters()
	if index < 0 or index >= rows.size():
		return {}
	return rows[index]


func chapter_id(index: int) -> String:
	return String(chapter(index).get("id", ""))


func chapter_title_key(index: int) -> String:
	return String(chapter(index).get("title_key", ""))


func events(chapter_index: int) -> Array:
	return chapter(chapter_index).get("events", [])


func event(chapter_index: int, event_index: int) -> Dictionary:
	var rows: Array = events(chapter_index)
	if event_index < 0 or event_index >= rows.size():
		return {}
	return rows[event_index]


func subevents(event_row: Dictionary) -> Array:
	return event_row.get("subevents", [])


func battle_subs(event_row: Dictionary) -> Array:
	var out: Array = []
	for sub: Variant in subevents(event_row):
		if sub is Dictionary and String(Dictionary(sub).get("type", "")) in BATTLE_TYPES:
			out.append(sub)
	return out


func unlock_subs(event_row: Dictionary) -> Array:
	var out: Array = []
	for sub: Variant in subevents(event_row):
		if sub is Dictionary and String(Dictionary(sub).get("type", "")) == "unlock":
			out.append(sub)
	return out


func picture_subs(event_row: Dictionary) -> Array:
	var out: Array = []
	for sub: Variant in subevents(event_row):
		if sub is Dictionary and String(Dictionary(sub).get("type", "")) == "picture":
			out.append(sub)
	return out


func scenery_row(name: String) -> Dictionary:
	for row: Variant in tables().get("sceneries", []):
		if row is Dictionary and String(Dictionary(row).get("name", "")) == name:
			return row
	return {}


func character_row(name: String) -> Dictionary:
	for row: Variant in tables().get("characters", []):
		if row is Dictionary and String(Dictionary(row).get("name", "")) == name:
			return row
	return {}


func uniques() -> Array:
	return tables().get("uniques", [])


## Resolve an unlock `item_id` through the recovered list that the item type
## indexes.  `proven` is what the export could prove from the data itself
## (always_available rows left out of the story's id range); see
## `tables.unlock_indexing` in the data file.
func resolve_unlock(item_type: String, item_id: Variant) -> Dictionary:
	var table: Dictionary = tables().get("unlock_item_names", {})
	var names: Dictionary = table.get(item_type, {})
	var key: String = str(item_id)
	var indexing: Dictionary = tables().get("unlock_indexing", {})
	var proof: Dictionary = indexing.get(item_type, {})
	if names.has(key):
		var value: Variant = names[key]
		return {
			"name": "" if value == null else str(value),
			"proven": bool(proof.get("proven", false)),
			"note": String(proof.get("note", "")),
		}
	return {"name": "", "proven": false, "note": "no recovered table row"}


func difficulty_values(sub: Dictionary) -> Array:
	return sub.get("difficulty", [])


## Index into the recovered [easy, medium, hard] array.  The numeric value is
## returned verbatim; it is the value the port's AI difficulty index accepts.
func difficulty_value(sub: Dictionary, slot_index: int) -> int:
	var values: Array = difficulty_values(sub)
	if values.is_empty():
		return -1
	var index: int = clampi(slot_index, 0, values.size() - 1)
	return int(values[index])


func difficulty_slot_names() -> Array:
	return tables().get("difficulty_slots", ["easy", "medium", "hard"])

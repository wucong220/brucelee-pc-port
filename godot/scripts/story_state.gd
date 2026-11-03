extends RefCounted
## Story-mode save slots: difficulty, chapter, completed events, recorded
## unlocks and the battle handoff that survives a `reload_current_scene()`.
##
## Save files live in `user://story_slot_<n>.json`; nothing is written inside the
## project or the shared package.

const SCHEMA: String = "story-flow/1"
const SLOT_COUNT: int = 3
const UNLOCK_TYPES: Array[String] = [
	"fighter", "fighter_profile", "style_anim", "scenery", "art_picture",
]

var save_slot: int = 0
var difficulty_slot: int = 0
var difficulty_name: String = ""
var chapter_index: int = 0
var exp: int = 0
var completed: Dictionary = {}
var unlocks: Array = []
var records: Array = []
var pending: Dictionary = {}
var error_msg: String = ""


static func slot_path(slot: int) -> String:
	return "user://story_slot_%d.json" % slot


static func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


static func read_slot(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {}
	var text: String = FileAccess.get_file_as_string(slot_path(slot))
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	return parsed


static func slots_overview(difficulty_names: Array) -> Array:
	var rows: Array = []
	for slot: int in range(1, SLOT_COUNT + 1):
		var raw: Dictionary = read_slot(slot)
		if raw.is_empty():
			rows.append({"slot": slot, "exists": false})
			continue
		var difficulty: int = int(raw.get("difficulty_slot", 0))
		var label: String = String(raw.get("difficulty_name", ""))
		if label.is_empty() and difficulty >= 0 and difficulty < difficulty_names.size():
			label = String(difficulty_names[difficulty])
		rows.append({
			"slot": slot,
			"exists": true,
			"chapter_index": int(raw.get("chapter_index", 0)),
			"difficulty_slot": difficulty,
			"difficulty_name": label,
			"exp": int(raw.get("exp", 0)),
			"completed": int(_completed_total(raw)),
			"unlocks": (raw.get("unlocks", []) as Array).size(),
		})
	return rows


static func _completed_total(raw: Dictionary) -> int:
	var total: int = 0
	var table: Dictionary = raw.get("completed", {})
	for key: Variant in table:
		var rows: Variant = table[key]
		if rows is Array:
			total += (rows as Array).size()
	return total


func new_story(slot: int, difficulty_index: int, difficulty_label: String) -> bool:
	save_slot = slot
	difficulty_slot = difficulty_index
	difficulty_name = difficulty_label
	chapter_index = 0
	exp = 0
	completed = {}
	unlocks = []
	records = []
	pending = {}
	error_msg = ""
	return save()


func load_slot(slot: int) -> bool:
	if not slot_exists(slot):
		error_msg = "slot %d is empty" % slot
		return false
	var raw: Dictionary = read_slot(slot)
	if raw.is_empty():
		error_msg = "slot %d is unreadable" % slot
		return false
	save_slot = slot
	difficulty_slot = int(raw.get("difficulty_slot", 0))
	difficulty_name = String(raw.get("difficulty_name", ""))
	chapter_index = int(raw.get("chapter_index", 0))
	exp = int(raw.get("exp", 0))
	var raw_completed: Variant = raw.get("completed", {})
	completed = raw_completed if raw_completed is Dictionary else {}
	unlocks = raw.get("unlocks", [])
	records = raw.get("records", [])
	var raw_pending: Variant = raw.get("pending", {})
	pending = raw_pending if raw_pending is Dictionary else {}
	error_msg = ""
	return true


func save() -> bool:
	if save_slot <= 0:
		error_msg = "no slot selected"
		return false
	var file: FileAccess = FileAccess.open(slot_path(save_slot), FileAccess.WRITE)
	if file == null:
		error_msg = "cannot write " + slot_path(save_slot)
		return false
	file.store_string(JSON.stringify(to_dict(), " ", false))
	file.close()
	error_msg = ""
	return true


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA,
		"save_slot": save_slot,
		"difficulty_slot": difficulty_slot,
		"difficulty_name": difficulty_name,
		"chapter_index": chapter_index,
		"exp": exp,
		"completed": completed,
		"unlocks": unlocks,
		"records": records,
		"pending": pending,
	}


func completed_list(chapter_id: String) -> Array:
	var rows: Variant = completed.get(chapter_id, [])
	return rows if rows is Array else []


func is_event_completed(chapter_id: String, maptitle: String) -> bool:
	return completed_list(chapter_id).has(maptitle)


func mark_completed(chapter_id: String, maptitle: String) -> void:
	var rows: Array = completed_list(chapter_id).duplicate()
	if not rows.has(maptitle):
		rows.append(maptitle)
	completed[chapter_id] = rows


func chapter_completed_count(chapter_id: String, event_rows: Array) -> int:
	var done: int = 0
	for row: Variant in event_rows:
		if row is Dictionary and is_event_completed(
				chapter_id, String(Dictionary(row).get("maptitle", ""))):
			done += 1
	return done


func has_unlock(unlock_id: int) -> bool:
	for row: Variant in unlocks:
		if row is Dictionary and int(Dictionary(row).get("unlock_id", -1)) == unlock_id:
			return true
	return false


## Records one `unlock` subevent. Returns true when it was newly recorded.
func add_unlock(unlock_id: int, item_type: String, item_id: Variant,
		chapter_id: String, event_name: String, sub_index: int) -> bool:
	if has_unlock(unlock_id):
		return false
	unlocks.append({
		"unlock_id": unlock_id,
		"item_type": item_type,
		"item_id": item_id,
		"chapter": chapter_id,
		"event": event_name,
		"sub_index": sub_index,
	})
	return true


func unlocks_since(start_index: int) -> Array:
	var out: Array = []
	for index: int in range(maxi(0, start_index), unlocks.size()):
		out.append(unlocks[index])
	return out


func add_record(record: Dictionary) -> void:
	records.append(record)


func set_pending(value: Dictionary) -> void:
	pending = value.duplicate(true)


func clear_pending() -> void:
	pending = {}


func has_pending() -> bool:
	return not pending.is_empty()


func advance_chapter(chapter_count: int) -> bool:
	if chapter_index + 1 >= chapter_count:
		return false
	chapter_index += 1
	return true

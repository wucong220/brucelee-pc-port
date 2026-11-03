class_name SaveManager
extends RefCounted

## user:// save schema for the Dragon Warrior progress prototype.
##
## Envelope: a checksummed wrapper around a JSON payload, written atomically.
## Loading fails closed: any schema/version/checksum/shape problem returns {} so
## callers get a clean default state instead of partially-trusted data.

const SAVE_PATH := "user://progress_save.json"
const SCHEMA := "dragonwarrior-progress/1"
const VERSION := 1

const DIFFS := ["easy", "medium", "hard"]


static func default_state() -> Dictionary:
	return {
		"schema": SCHEMA,
		"version": VERSION,
		"story": {
			"exp": 0,
			"events_completed": [],        # ["chapter1/s_master_1", ...]
			"chapters_completed": [],      # ["chapter1", ...]
			"completed_difficulties": [],  # ["easy", ...]
		},
		"unlocks": {
			"unlocked_ids": [],            # sorted list[int] within [0, num_ids)
			"sources": {},                 # "id" -> "story_exp" | "story_event"
		},
		"achievements": {
			"reached": [],                 # sorted list of achievement ids
		},
		"counters": {},                    # name -> int (lifetime totals)
		"mode_clears": {
			"arcade": {"easy": false, "medium": false, "hard": false},
			"time_attack": {"easy": false, "medium": false, "hard": false},
		},
	}


static func _is_int_like(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func _validate_shape(state: Dictionary) -> bool:
	if not state.has("schema") or state.get("schema") != SCHEMA:
		return false
	if int(state.get("version", 0)) != VERSION:
		return false
	for key in ["story", "unlocks", "achievements", "counters", "mode_clears"]:
		if not state.has(key) or typeof(state[key]) != TYPE_DICTIONARY:
			return false
	var story: Dictionary = state["story"]
	if not _is_int_like(story.get("exp", -1)) or int(story["exp"]) < 0:
		return false
	for key in ["events_completed", "chapters_completed", "completed_difficulties"]:
		if typeof(story.get(key)) != TYPE_ARRAY:
			return false
	if typeof(state["unlocks"].get("unlocked_ids")) != TYPE_ARRAY:
		return false
	for id in state["unlocks"]["unlocked_ids"]:
		if not _is_int_like(id) or int(id) < 0:
			return false
	if typeof(state["achievements"].get("reached")) != TYPE_ARRAY:
		return false
	for m in ["arcade", "time_attack"]:
		if typeof(state["mode_clears"].get(m)) != TYPE_DICTIONARY:
			return false
		for d in DIFFS:
			if typeof(state["mode_clears"][m].get(d, null)) != TYPE_BOOL:
				return false
	return true


static func save_state(state: Dictionary, path: String = SAVE_PATH) -> bool:
	if not _validate_shape(state):
		push_error("save_state: state fails schema shape")
		return false
	var payload_json := JSON.stringify(state)
	var envelope := {
		"schema": SCHEMA,
		"version": VERSION,
		"saved_utc": Time.get_datetime_string_from_system(true),
		"checksum": payload_json.sha256_text(),
		"payload_json": payload_json,
	}
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("save_state: cannot open temp file %s" % tmp)
		return false
	f.store_string(JSON.stringify(envelope, "", false))
	f.close()
	# Atomic replace: remove stale target, then rename temp into place.
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("save_state: rename failed (%d)" % err)
		return false
	return true


static func load_state(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var envelope: Dictionary = parsed
	if envelope.get("schema") != SCHEMA:
		return {}
	if int(envelope.get("version", 0)) != VERSION:
		return {}
	var payload_json = envelope.get("payload_json", "")
	if typeof(payload_json) != TYPE_STRING:
		return {}
	if payload_json.sha256_text() != str(envelope.get("checksum", "")):
		return {}   # tampered or corrupt -> fail closed
	var payload := JSON.new()
	if payload.parse(payload_json) != OK:
		return {}
	var state = payload.data
	if typeof(state) != TYPE_DICTIONARY:
		return {}
	if not _validate_shape(state):
		return {}
	return _normalize(state)


static func _normalize(state: Dictionary) -> Dictionary:
	## JSON numbers parse as floats; force the integer fields back to int.
	var story: Dictionary = state["story"]
	story["exp"] = int(story["exp"])
	var ids: Array = state["unlocks"]["unlocked_ids"]
	for i in range(ids.size()):
		ids[i] = int(ids[i])
	var counters: Dictionary = state["counters"]
	for k in counters.keys():
		counters[k] = int(counters[k])
	return state

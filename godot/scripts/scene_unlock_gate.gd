extends RefCounted
## Recovered scenery-unlock gate shared by the text scene submenu and the
## recovered `selectscenery.ui` dock.
##
## Every rule below is read from decoded data; nothing is invented:
##
##   * the ten selectable sceneries, their row order, `port_scene_variant` and
##     `always_available` flag come from `tables.sceneries` (the decode of
##     `adreno_200/sceneries.list`, the same table the story flow launches its
##     battles from);
##   * the scenery -> unlock-id index comes from `tables.unlock_item_names.scenery`
##     (decoded from `unlocks.list`), which maps the scenery item id (0..9) to the
##     `sceneries.list` name -- so a row is matched by name, not by assuming that
##     the list order happens to line up;
##   * each scenery item id has exactly one grant in the recovered unlock table:
##     the nine story-event rows of `unlocks.list` (`item_type == "scenery"`,
##     `item_id` 1..9) decoded into `res://data/progress/unlocks.json`;
##   * the progress save is `user://progress_save.json` (or the path given by
##     `BRUCELEE_SCENE_UNLOCK_SAVE`), read through the recovered `SaveManager`,
##     which already rejects a bad schema/version/checksum/shape;
##   * an unlock id is granted when it appears in `unlocks.unlocked_ids` -- the
##     field the recovered `ProgressService` writes when a story event completes.
##
## Fail-closed rules (no guessing):
##   * no save file            -> every gated row is locked, reason `no_save`;
##   * unreadable save         -> every gated row is locked, reason `save_invalid`;
##   * unlock table missing    -> every gated row is locked, reason
##                                `unlock_data_missing`;
##   * scenery id has no recovered grant or the decoded name does not match the
##     row -> that row is locked, reason `unknown_scenery_id`;
##   * an id is not in `unlocked_ids` -> locked, reason `locked`.
##
## The only row that is not gated is the one the decoded list itself marks
## `always_available` (`market`, sceneries.list[0]); that flag is served as
## recovered data, not assumed from the row index.
##
## `BRUCELEE_SCENE_UNLOCK=0` turns the gate off (the port regression hook); every
## other value, including unset, keeps it on.

const Catalog = preload("res://scripts/scene_catalog.gd")
const UnlockRegistry = preload("res://scripts/unlock_registry.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")

const STORY_DATA_PATH := "res://data/story/story_mode.json"
const DEFAULT_UNLOCKS_PATH := "res://data/progress/unlocks.json"

const ENV_UNLOCK := "BRUCELEE_SCENE_UNLOCK"
const ENV_SAVE := "BRUCELEE_SCENE_UNLOCK_SAVE"
const ENV_UNLOCKS := "BRUCELEE_SCENE_UNLOCK_UNLOCKS"
const ENV_STORY := "BRUCELEE_SCENE_UNLOCK_STORY"

## Port chrome: the recovered text scene menu has no locked-row widget, so the
## text rows carry this suffix.  It is not recovered text and is labelled as port
## chrome in the report.
const LOCKED_SUFFIX := " (LOCKED)"

var error: String = ""
var warning: String = ""
var rows: Array = []                 # one entry per sceneries.list row
var by_command: Dictionary = {}      # menu command -> row state
var save_path: String = ""
var save_present: bool = false
var save_valid: bool = false
var unlocked_ids: Array = []
var unknown_saved_ids: Array = []
var registry_ok: bool = false
var data_ok: bool = false

var _states: Array = []
var _story_rows: Array = []
var _scenery_grants: Dictionary = {}   # scenery item id -> story_event unlock row
var _scenery_names: Dictionary = {}    # scenery item id -> decoded list name
var _duplicate_grants: Dictionary = {} # scenery item id -> true (ambiguous, stays locked)
var _registry = null


## True unless BRUCELEE_SCENE_UNLOCK is exactly "0".
static func enabled() -> bool:
	return OS.get_environment(ENV_UNLOCK) != "0"


func _init() -> void:
	refresh()


## Rebuilds the whole gate from the decoded data and the save.  Safe to call
## every time the scene submenu opens, so a save written during the session is
## picked up without restarting.
## Returns true when the ten sceneries rows were built; a false return still
## leaves the gate usable for fail-closed reporting (`error` explains why).
func refresh() -> bool:
	error = ""
	warning = ""
	rows = []
	by_command = {}
	_states = []
	unlocked_ids = []
	unknown_saved_ids = []
	save_present = false
	save_valid = false
	registry_ok = false
	data_ok = false
	_scenery_grants = {}
	_scenery_names = {}
	_duplicate_grants = {}
	_registry = null

	add_story_data()
	add_unlock_registry()
	read_save()
	_build_rows()
	if rows.is_empty() and error.is_empty():
		error = "no sceneries rows recovered"
	return not rows.is_empty()


# ------------------------------------------------------------------ sources

## Loads `tables.sceneries` + `tables.unlock_item_names.scenery`.  A missing or
## malformed table is recorded as a fail-closed error, never replaced.
func add_story_data() -> void:
	var story_path: String = OS.get_environment(ENV_STORY)
	if story_path.is_empty():
		story_path = STORY_DATA_PATH
	if not FileAccess.file_exists(story_path):
		error = "story data missing: " + story_path
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(story_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		error = "story data is not a JSON object: " + story_path
		return
	var tables: Variant = (parsed as Dictionary).get("tables", {})
	if typeof(tables) != TYPE_DICTIONARY:
		error = "story data has no tables: " + story_path
		return
	var sceneries: Variant = (tables as Dictionary).get("sceneries", [])
	if typeof(sceneries) != TYPE_ARRAY or (sceneries as Array).is_empty():
		error = "story data has no sceneries table: " + story_path
		return
	var names: Variant = (tables as Dictionary).get("unlock_item_names", {})
	if typeof(names) != TYPE_DICTIONARY:
		error = "story data has no unlock_item_names table: " + story_path
		return
	var scenery_names: Variant = (names as Dictionary).get("scenery", {})
	if typeof(scenery_names) != TYPE_DICTIONARY or (scenery_names as Dictionary).is_empty():
		error = "story data has no unlock_item_names.scenery index: " + story_path
		return
	for key: Variant in (scenery_names as Dictionary).keys():
		_scenery_names[str(key)] = String((scenery_names as Dictionary)[key])
	_story_rows = sceneries
	data_ok = true


## Loads the recovered unlock table and indexes the nine scenery grants by item
## id.  The table is the same `unlocks.json` the progress service uses.
func add_unlock_registry() -> void:
	var path: String = OS.get_environment(ENV_UNLOCKS)
	if path.is_empty():
		path = DEFAULT_UNLOCKS_PATH
	_registry = UnlockRegistry.new()
	registry_ok = bool(_registry.load_data(path))
	if not registry_ok:
		if error.is_empty():
			error = "unlock registry unavailable: " + path
		return
	for row: Dictionary in _registry.event_unlocks:
		if String(row.get("item_type", "")) != "scenery":
			continue
		var item_id: int = int(row.get("item_id", -1))
		if _duplicate_grants.has(item_id):
			continue
		if _scenery_grants.has(item_id):
			# Two grants for one scenery id would be an ambiguous rule: keep the
			# gate closed for that id instead of picking one.
			_scenery_grants.erase(item_id)
			_duplicate_grants[item_id] = true
			warning = "duplicate scenery grant for item id %d" % item_id
			continue
		_scenery_grants[item_id] = row


## Reads the progress save through the recovered SaveManager.  A save that is
## absent, unreadable, or rejected by the schema/checksum check leaves
## `save_valid` false so every gated row stays locked.
func read_save() -> void:
	save_path = OS.get_environment(ENV_SAVE)
	if save_path.is_empty():
		save_path = SaveManagerScript.SAVE_PATH
	save_present = FileAccess.file_exists(save_path)
	if not save_present:
		return
	var state: Dictionary = SaveManagerScript.load_state(save_path)
	if state.is_empty():
		return
	save_valid = true
	var ids: Variant = (state.get("unlocks", {}) as Dictionary).get("unlocked_ids", [])
	if typeof(ids) == TYPE_ARRAY:
		for id: Variant in (ids as Array):
			unlocked_ids.append(int(id))
	unlocked_ids.sort()
	# Ids outside the recovered id space cannot grant anything; surface them
	# instead of silently accepting them as a valid unlock.
	if registry_ok:
		for id: int in unlocked_ids:
			if id < 0 or id >= int(_registry.num_ids):
				unknown_saved_ids.append(id)


# -------------------------------------------------------------------- rows

func _build_rows() -> void:
	if not data_ok:
		return
	for index: int in range(_story_rows.size()):
		var row_value: Variant = _story_rows[index]
		if typeof(row_value) != TYPE_DICTIONARY:
			error = "sceneries row %d is not an object" % index
			return
		var row: Dictionary = row_value
		var variant: String = String(row.get("port_scene_variant", ""))
		var command: String = String(Catalog.VARIANT_COMMANDS.get(variant, ""))
		var state: Dictionary = {
			"index": index,
			"item_id": index,
			"name": String(row.get("name", "")),
			"translate_name": String(row.get("translate_name", "")),
			"variant": variant,
			"command": command,
			"always_available": str(row.get("always_available", "")).to_lower() == "true",
			"unlock_id": -1,
			"unlock_source": "",
			"available": false,
			"reason": "",
		}
		var mapped_name: String = String(_scenery_names.get(str(index), ""))
		var named: bool = mapped_name == String(state["name"])
		if state["always_available"]:
			state["available"] = true
			state["reason"] = "always_available"
		elif not registry_ok:
			state["reason"] = "unlock_data_missing"
		elif not named:
			state["reason"] = "unknown_scenery_id"
		elif not _scenery_grants.has(index):
			state["reason"] = "unknown_scenery_id"
		else:
			var grant: Dictionary = _scenery_grants[index]
			var unlock_id: int = int(grant.get("id", -1))
			state["unlock_id"] = unlock_id
			state["unlock_source"] = "%s/%s" % [
				String(grant.get("chapter", "")), String(grant.get("event_maptitle", ""))]
			if not save_valid:
				state["reason"] = "no_save" if not save_present else "save_invalid"
			elif unlocked_ids.has(unlock_id):
				state["available"] = true
				state["reason"] = "unlocked"
			else:
				state["reason"] = "locked"
		_states.append(state)
		rows.append(state.duplicate(true))
		if not command.is_empty():
			by_command[command] = state.duplicate(true)


# ------------------------------------------------------------------ access

func state_for_index(index: int) -> Dictionary:
	if index < 0 or index >= _states.size():
		return {}
	return (_states[index] as Dictionary).duplicate(true)


func state_for_command(command: String) -> Dictionary:
	if not by_command.has(command):
		return {}
	return (by_command[command] as Dictionary).duplicate(true)


## True only for a recovered scenery row whose recovered grant is not satisfied.
## Commands that are not scenery rows (BACK, menus, ...) are never locked here.
func is_locked_command(command: String) -> bool:
	var state: Dictionary = state_for_command(command)
	if state.is_empty():
		return false
	return not bool(state.get("available", false))


func is_available_command(command: String) -> bool:
	var state: Dictionary = state_for_command(command)
	return not state.is_empty() and bool(state.get("available", false))


func locked_count() -> int:
	var total: int = 0
	for state: Dictionary in _states:
		if not bool(state.get("available", false)):
			total += 1
	return total


func unlocked_count() -> int:
	return _states.size() - locked_count()


func locked_indices() -> Array:
	var out: Array = []
	for state: Dictionary in _states:
		if not bool(state.get("available", false)):
			out.append(int(state["index"]))
	return out


## Provenance / test summary.  Every field is either decoded data or a measured
## state of the save; no inferred rule is reported as recovered.
func summary() -> Dictionary:
	return {
		"enabled": enabled(),
		"error": error,
		"warning": warning,
		"data_ok": data_ok,
		"registry_ok": registry_ok,
		"save_path": save_path,
		"save_present": save_present,
		"save_valid": save_valid,
		"unlocked_ids": unlocked_ids.duplicate(),
		"unknown_saved_ids": unknown_saved_ids.duplicate(),
		"rows": rows.size(),
		"locked_count": locked_count(),
		"unlocked_count": unlocked_count(),
		"states": _states.duplicate(true),
	}

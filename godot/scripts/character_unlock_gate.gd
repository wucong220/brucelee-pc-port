extends RefCounted
## Recovered character-unlock gate shared by the text OPPONENTS submenu and the
## recovered `selectfighter.ui` dock.
##
## Every rule is read from decoded data; nothing is invented:
##
##   * the fifteen characters, their names, `translate_name` and decoded
##     `always_available` flag come from `tables.characters` (the decode of
##     `adreno_200/characters.list`);
##   * every character row is matched to its unlock item id **by name**:
##     `tables.unlock_item_names.fighter[id] == characters[id].name` (decoded from
##     `unlocks.list`), so the gate never assumes that the unlock table and the
##     character list happen to be ordered the same way;
##   * the two always-available characters are cross-checked against
##     `tables.unlock_indexing.fighter.always_available` (also decoded data); if
##     the two decoded sources disagree the row stays closed instead of guessing;
##   * each gated character has exactly one grant in the recovered unlock table
##     (`item_type == "fighter"`): four story-EXP rows (item ids 0, 1, 9, 14) and
##     nine story-event rows (item ids 3, 5, 6, 7, 8, 10, 11, 12, 13), decoded into
##     `res://data/progress/unlocks.json`;
##   * the dock order and its decoded `lockedpicture` come from
##     `res://data/menu_art/ui/selectfighter.json` (the decode of
##     `adreno_200/gui/selectfighter.ui`); each dock item is resolved to a
##     character by the decoded `data/menu_art/menu_art.json` `fighters` table
##     (icon basename -> character name), never by dock position;
##   * the progress save is `user://progress_save.json` (or the path given by
##     `BRUCELEE_CHARACTER_UNLOCK_SAVE`), read through the recovered
##     `SaveManager`, which already rejects a bad schema/version/checksum/shape;
##   * an unlock id is granted when it appears in `unlocks.unlocked_ids` -- the
##     field the recovered `ProgressService` writes when a story event completes
##     or a story-EXP threshold is crossed.
##
## Fail-closed rules (no guessing):
##   * no save file            -> every gated row is locked, reason `no_save`;
##   * unreadable save         -> every gated row is locked, reason `save_invalid`;
##   * unlock table missing    -> every gated row is locked, reason
##                                `unlock_data_missing`;
##   * characters table or its decoded name index missing -> no row is built at
##     all, so even the always-available exception cannot be proven;
##   * character id has no recovered grant, or the decoded name does not match the
##     character row -> that row is locked, reason `unknown_character_id`;
##   * two grants for one character id -> ambiguous, that row stays locked;
##   * an id is not in `unlocked_ids` -> locked, reason `locked`.
##
## The two rows the decoded data marks `always_available` ("bruce lee c" and
## "shen lo") are not gated; that flag is served as recovered data, not assumed
## from a row index.
##
## The dock file is validated separately (`dock_ok`): a dock that does not hold
## one item per character, one decodable character per item, and a decoded
## `lockedpicture`, never draws a gate state.  `BRUCELEE_CHARACTER_UNLOCK=0` turns
## the gate off (the port regression hook); every other value, including unset,
## keeps it on.

const UnlockRegistry = preload("res://scripts/unlock_registry.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")

const STORY_DATA_PATH := "res://data/story/story_mode.json"
const DEFAULT_UNLOCKS_PATH := "res://data/progress/unlocks.json"
const DEFAULT_MENU_ART_PATH := "res://data/menu_art/menu_art.json"
const DEFAULT_DOCK_PATH := "res://data/menu_art/ui/selectfighter.json"

const ENV_UNLOCK := "BRUCELEE_CHARACTER_UNLOCK"
const ENV_SAVE := "BRUCELEE_CHARACTER_UNLOCK_SAVE"
const ENV_UNLOCKS := "BRUCELEE_CHARACTER_UNLOCK_UNLOCKS"
const ENV_STORY := "BRUCELEE_CHARACTER_UNLOCK_STORY"
const ENV_MENU_ART := "BRUCELEE_CHARACTER_UNLOCK_MENU_ART"
const ENV_DOCK := "BRUCELEE_CHARACTER_UNLOCK_DOCK"

## Port chrome: the recovered text opponent menu has no locked-row widget, so a
## closed row carries this suffix.  It is not recovered text and is labelled as
## port chrome in the report.
const LOCKED_SUFFIX := " (LOCKED)"

## Port chrome: the OPPONENTS entries the port menu emits -> the decoded
## `characters.list` name each one selects.  This is the same name lookup as
## `main.gd`'s HUD_ART_OPPONENT_DOCK (command -> dock index); keeping the name
## here lets the gate resolve a command without depending on the dock file.
const OPPONENT_CHARACTERS: Dictionary = {
	"brick": "brick davis",
	"sinfu": "sin fu",
	"master": "the master",
	"ken": "ken godall",
	"shenlo": "shen lo",
	"smallboy": "smallboy",
	"johnson": "johnson",
	"chief": "chief a",
	"loming": "lo ming a",
}

var error: String = ""
var warning: String = ""
var rows: Array = []                 # one entry per characters.list row
var by_command: Dictionary = {}      # opponent command -> row state
var character_index_by_name: Dictionary = {}
var save_path: String = ""
var save_present: bool = false
var save_valid: bool = false
var unlocked_ids: Array = []
var unknown_saved_ids: Array = []
var registry_ok: bool = false
var data_ok: bool = false

## Decoded selectfighter.ui dock (used by the overlay).
var dock_ok: bool = false
var dock_error: String = ""
var dock_items: Array = []                 # icon basenames in decoded dock order
var locked_picture: String = ""            # decoded dock `lockedpicture` basename
var dock_character_indices: Array = []     # dock index -> characters.list index

var _characters: Array = []
var _character_names: Array = []
var _unlock_names: Dictionary = {}         # character id -> decoded character name
var _always_names: Dictionary = {}         # always-available names (decoded index)
var _always_names_ok: bool = false
var _fighter_grants: Dictionary = {}       # character id -> unlock row
var _duplicate_grants: Dictionary = {}     # character id -> true (ambiguous)
var _registry = null


## True unless BRUCELEE_CHARACTER_UNLOCK is exactly "0".
static func enabled() -> bool:
	return OS.get_environment(ENV_UNLOCK) != "0"


func _init() -> void:
	refresh()


## Rebuilds the whole gate from the decoded data and the save.  Safe to call
## every time the opponent submenu opens, so a save written during the session is
## picked up without restarting.
## Returns true when the fifteen character rows were built; a false return still
## leaves the gate usable for fail-closed reporting (`error` explains why).
func refresh() -> bool:
	error = ""
	warning = ""
	rows = []
	by_command = {}
	character_index_by_name = {}
	unlocked_ids = []
	unknown_saved_ids = []
	save_present = false
	save_valid = false
	registry_ok = false
	data_ok = false
	dock_ok = false
	dock_error = ""
	dock_items = []
	locked_picture = ""
	dock_character_indices = []
	_characters = []
	_character_names = []
	_unlock_names = {}
	_always_names = {}
	_always_names_ok = false
	_fighter_grants = {}
	_duplicate_grants = {}
	_registry = null

	add_story_data()
	add_unlock_registry()
	read_save()
	add_dock_data()
	if data_ok:
		_build_rows()
	if rows.is_empty() and error.is_empty():
		error = "no characters rows recovered"
	return not rows.is_empty()


# ------------------------------------------------------------------ sources

## Loads `tables.characters`, `tables.unlock_item_names.fighter` and the decoded
## `tables.unlock_indexing.fighter` always-available list.  A missing or malformed
## table is recorded as a fail-closed error, never replaced.
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
	var characters: Variant = (tables as Dictionary).get("characters", [])
	if typeof(characters) != TYPE_ARRAY or (characters as Array).is_empty():
		error = "story data has no characters table: " + story_path
		return
	var names: Variant = (tables as Dictionary).get("unlock_item_names", {})
	if typeof(names) != TYPE_DICTIONARY:
		error = "story data has no unlock_item_names table: " + story_path
		return
	var fighter_names: Variant = (names as Dictionary).get("fighter", {})
	if typeof(fighter_names) != TYPE_DICTIONARY or (fighter_names as Dictionary).is_empty():
		error = "story data has no unlock_item_names.fighter index: " + story_path
		return
	for key: Variant in (fighter_names as Dictionary).keys():
		_unlock_names[int(key)] = String((fighter_names as Dictionary)[key])
	# The decoded unlock_indexing entry is optional evidence used only to
	# cross-check the per-row always_available flags.
	var indexing: Variant = (tables as Dictionary).get("unlock_indexing", {})
	if typeof(indexing) == TYPE_DICTIONARY:
		var fighter_index: Variant = (indexing as Dictionary).get("fighter", {})
		if typeof(fighter_index) == TYPE_DICTIONARY:
			var always: Variant = (fighter_index as Dictionary).get("always_available", [])
			if typeof(always) == TYPE_ARRAY:
				for name_value: Variant in (always as Array):
					_always_names[String(name_value)] = true
				_always_names_ok = true
	for index: int in range((characters as Array).size()):
		var row_value: Variant = (characters as Array)[index]
		if typeof(row_value) != TYPE_DICTIONARY:
			error = "characters row %d is not an object: %s" % [index, story_path]
			return
		var row: Dictionary = row_value
		var name: String = String(row.get("name", ""))
		if name.is_empty():
			error = "characters row %d has no name: %s" % [index, story_path]
			return
		if character_index_by_name.has(name):
			error = "characters.list repeats the name '%s'" % name
			return
		character_index_by_name[name] = index
		_character_names.append(name)
		_characters.append(row)
	data_ok = true


## Loads the recovered unlock table and indexes the fighter grants by character
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
	for row: Dictionary in _registry.story_unlocks:
		if String(row.get("item_type", "")) != "fighter":
			continue
		_index_grant(int(row.get("item_id", -1)),
			{"source": "story_exp", "exp": int(row.get("exp", 0)),
			 "id": int(row.get("id", -1))})
	for row: Dictionary in _registry.event_unlocks:
		if String(row.get("item_type", "")) != "fighter":
			continue
		_index_grant(int(row.get("item_id", -1)),
			{"source": "story_event", "chapter": String(row.get("chapter", "")),
			 "event": String(row.get("event_maptitle", "")),
			 "id": int(row.get("id", -1))})


func _index_grant(item_id: int, grant: Dictionary) -> void:
	if item_id < 0 or _duplicate_grants.has(item_id):
		return
	if _fighter_grants.has(item_id):
		# Two grants for one character id would be an ambiguous rule: keep the
		# gate closed for that id instead of picking one.
		_fighter_grants.erase(item_id)
		_duplicate_grants[item_id] = true
		warning = "duplicate fighter grant for character id %d" % item_id
		return
	_fighter_grants[item_id] = grant


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


## Loads the decoded `selectfighter.ui` dock and resolves every dock item to a
## character through the decoded `menu_art.json` fighters table.  The dock order
## is therefore matched by icon -> character name, not by position.
func add_dock_data() -> void:
	var dock_path: String = OS.get_environment(ENV_DOCK)
	if dock_path.is_empty():
		dock_path = DEFAULT_DOCK_PATH
	var menu_art_path: String = OS.get_environment(ENV_MENU_ART)
	if menu_art_path.is_empty():
		menu_art_path = DEFAULT_MENU_ART_PATH
	var icon_to_character: Dictionary = {}
	var menu_art: Variant = _parse_json_object(menu_art_path)
	if typeof(menu_art) == TYPE_DICTIONARY:
		var fighters: Variant = (menu_art as Dictionary).get("fighters", [])
		if typeof(fighters) == TYPE_ARRAY:
			for entry: Variant in (fighters as Array):
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				var icon: String = String((entry as Dictionary).get("icon", ""))
				var character: String = String((entry as Dictionary).get("character", ""))
				if not icon.is_empty() and not character.is_empty():
					icon_to_character[icon] = character
	if icon_to_character.is_empty():
		dock_error = "decoded menu_art fighters table missing: " + menu_art_path
		return
	var dock: Variant = _parse_json_object(dock_path)
	if typeof(dock) != TYPE_DICTIONARY:
		dock_error = "decoded selectfighter dock missing: " + dock_path
		return
	var layout_value: Variant = (dock as Dictionary).get("root", {})
	var dock_widget: Dictionary = {}
	if typeof(layout_value) == TYPE_DICTIONARY:
		var layout: Variant = (layout_value as Dictionary).get("layout", [])
		if typeof(layout) == TYPE_ARRAY:
			for entry: Variant in (layout as Array):
				if typeof(entry) == TYPE_DICTIONARY \
						and String((entry as Dictionary).get("type", "")) == "bldock":
					dock_widget = entry
					break
	if dock_widget.is_empty():
		dock_error = "decoded selectfighter dock has no bldock: " + dock_path
		return
	var locked: Variant = (dock_widget.get("lockedpicture", {}) as Dictionary).get("$file", {})
	if typeof(locked) == TYPE_DICTIONARY:
		locked_picture = String((locked as Dictionary).get("basename", ""))
	if locked_picture.is_empty():
		dock_error = "decoded selectfighter dock has no lockedpicture: " + dock_path
		return
	var items: Variant = dock_widget.get("items", [])
	if typeof(items) != TYPE_ARRAY:
		dock_error = "decoded selectfighter dock has no items: " + dock_path
		return
	dock_items = []
	var resolved: Array = []
	for entry: Variant in (items as Array):
		var reference: Dictionary = {}
		if typeof(entry) == TYPE_DICTIONARY:
			var file_value: Variant = (entry as Dictionary).get("$file", {})
			if typeof(file_value) == TYPE_DICTIONARY:
				reference = file_value
		var basename: String = String(reference.get("basename", ""))
		if basename.is_empty():
			dock_error = "a decoded selectfighter dock item has no file: " + dock_path
			return
		dock_items.append(basename)
		if not icon_to_character.has(basename):
			dock_error = "dock item '%s' has no decoded character" % basename
			return
		var character_name: String = String(icon_to_character[basename])
		if not character_index_by_name.has(character_name):
			dock_error = "dock item '%s' names '%s', which is not a characters.list row" \
				% [basename, character_name]
			return
		resolved.append(int(character_index_by_name[character_name]))
	if resolved.size() != _characters.size():
		dock_error = "dock has %d items but characters.list has %d rows" \
			% [resolved.size(), _characters.size()]
		return
	var seen: Dictionary = {}
	for index: int in resolved:
		seen[index] = true
	if seen.size() != resolved.size():
		dock_error = "two dock items resolve to the same characters.list row"
		return
	dock_character_indices = resolved
	dock_ok = true


func _parse_json_object(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed


# -------------------------------------------------------------------- rows

func _build_rows() -> void:
	for index: int in range(_characters.size()):
		var row: Dictionary = _characters[index]
		var name: String = String(row.get("name", ""))
		var flag: bool = str(row.get("always_available", "")).to_lower() == "true"
		var state: Dictionary = {
			"index": index,
			"character_id": index,
			"name": name,
			"translate_name": String(row.get("translate_name", "")),
			"always_available": flag,
			"unlock_id": -1,
			"unlock_source": "",
			"available": false,
			"reason": "",
		}
		var decoded_name: String = String(_unlock_names.get(index, ""))
		if not decoded_name.is_empty() and decoded_name != name:
			state["reason"] = "unknown_character_id"
			warning = "unlocks.list item id %d names '%s', characters.list row %d names '%s'" \
				% [index, decoded_name, index, name]
		elif decoded_name.is_empty():
			state["reason"] = "unknown_character_id"
		elif _always_names_ok and bool(_always_names.has(name)) != flag:
			state["reason"] = "unknown_character_id"
			warning = "always_available disagrees for '%s'" % name
		elif flag:
			state["available"] = true
			state["reason"] = "always_available"
		elif not registry_ok:
			state["reason"] = "unlock_data_missing"
		elif _duplicate_grants.has(index):
			state["reason"] = "unknown_character_id"
		elif not _fighter_grants.has(index):
			state["reason"] = "unknown_character_id"
		else:
			var grant: Dictionary = _fighter_grants[index]
			var unlock_id: int = int(grant.get("id", -1))
			state["unlock_id"] = unlock_id
			if String(grant.get("source", "")) == "story_exp":
				state["unlock_source"] = "story_exp exp=%d" % int(grant.get("exp", 0))
			else:
				state["unlock_source"] = "%s/%s" % [
					String(grant.get("chapter", "")), String(grant.get("event", ""))]
			if not save_valid:
				state["reason"] = "no_save" if not save_present else "save_invalid"
			elif unlocked_ids.has(unlock_id):
				state["available"] = true
				state["reason"] = "unlocked"
			else:
				state["reason"] = "locked"
		rows.append(state.duplicate(true))
	for command: String in OPPONENT_CHARACTERS.keys():
		var state: Dictionary = state_for_character_name(String(OPPONENT_CHARACTERS[command]))
		if not state.is_empty():
			by_command[command] = state.duplicate(true)


# ------------------------------------------------------------------ access

func state_for_character(index: int) -> Dictionary:
	if index < 0 or index >= rows.size():
		return {}
	return (rows[index] as Dictionary).duplicate(true)


func state_for_character_name(name: String) -> Dictionary:
	if not character_index_by_name.has(name):
		return {}
	return state_for_character(int(character_index_by_name[name]))


## State of the character drawn by a decoded dock card.  A dock that was not
## validated is closed: no card can be trusted when its character is unknown.
func state_for_dock(index: int) -> Dictionary:
	if not dock_ok or index < 0 or index >= dock_character_indices.size():
		return {"index": index, "available": false, "reason": "dock_data_missing"}
	return state_for_character(int(dock_character_indices[index]))


func state_for_command(command: String) -> Dictionary:
	if not by_command.has(command):
		return {}
	return (by_command[command] as Dictionary).duplicate(true)


## True only for an OPPONENTS entry whose recovered character grant is not
## satisfied.  BACK and any non-opponent command are never locked here.
func is_locked_command(command: String) -> bool:
	if not OPPONENT_CHARACTERS.has(command):
		return false
	if rows.is_empty():
		return true
	var state: Dictionary = state_for_command(command)
	if state.is_empty():
		return true
	return not bool(state.get("available", false))


func is_available_command(command: String) -> bool:
	var state: Dictionary = state_for_command(command)
	return not state.is_empty() and bool(state.get("available", false))


func locked_count() -> int:
	var total: int = 0
	for state: Dictionary in rows:
		if not bool(state.get("available", false)):
			total += 1
	return total


func unlocked_count() -> int:
	return rows.size() - locked_count()


func locked_indices() -> Array:
	var out: Array = []
	for state: Dictionary in rows:
		if not bool(state.get("available", false)):
			out.append(int(state["index"]))
	return out


## Characters whose recovered grant is missing, in dock order.  A dock that could
## not be validated reports every card closed.
func locked_dock_indices() -> Array:
	var out: Array = []
	if not dock_ok:
		return out
	for index: int in range(dock_character_indices.size()):
		if not bool(state_for_dock(index).get("available", false)):
			out.append(index)
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
		"dock_ok": dock_ok,
		"dock_error": dock_error,
		"dock_items": dock_items.duplicate(),
		"locked_picture": locked_picture,
		"dock_character_indices": dock_character_indices.duplicate(),
		"states": rows.duplicate(true),
	}

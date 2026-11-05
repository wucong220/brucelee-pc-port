extends RefCounted
class_name PortLanguageDock
## Recovered 8-item language dock (settingslanguage.ui) + its native language
## index map and the port's clearly-labelled persistence binding.
##
## Recovered (see res://data/menu_art/language_dock.json):
##   * the eight bldock items, in the decoded order, are exactly the first eight
##     `CTranslate::AddLanguageTable(index, Lang*.lang)` registrations in
##     `krm::CApplication::Init` (0 English .. 7 ChineseTrad).  Japanese(8) and
##     Korean(9) tables are registered but are NOT dock items.
##   * `validselectedoption = [option, language]`, `onmoveaction = refresh`
##     -> a move writes the selected option index into the native `language`
##     value and fires `updateapplicationsettingslanguage` (SetLanguage + fonts).
##   * `wraparround = false` -> the cursor clamps at both ends.
##
## NOT RECOVERED (kept explicit, never guessed):
##   * the display NAME of each language (no Lang*.lang name keys);
##   * the Android `GetDefaultDisplayLanguage()` value used as the native default;
##   * the native on-disk persistence format of the CSettings/CHStrMgr `language`
##     value.  The port therefore stores the recovered index in its own save file
##     and labels that binding as PORT, not as the original format.
##
## A missing/invalid artifact fails closed: `available()` is false, `items()` is
## empty and the caller keeps its pre-existing NOT RECOVERED screen.

const DATA_PATH := "res://data/menu_art/language_dock.json"
const SAVE_PATH_ENV := "BRUCELEE_LANGUAGE_SAVE_PATH"
const DEFAULT_SAVE_PATH := "user://ui_gaps_language.json"
const NOT_RECOVERED := "NOT RECOVERED"
const SCHEMA := "brucelee-language-dock/1"
## Port default when neither a save nor a valid session language exists.  The
## native default (GetDefaultDisplayLanguage) is NOT RECOVERED, so this is the
## port's existing fallback (LangEnglish) and is reported as such.
const DEFAULT_INDEX := 0

static var _data: Dictionary = {}
static var _error: String = ""
static var _loaded: bool = false
static var _resolved: String = ""


static func path_used() -> String:
	if _resolved.is_empty():
		var env_path: String = OS.get_environment(SAVE_PATH_ENV)
		_resolved = env_path if not env_path.is_empty() else DEFAULT_SAVE_PATH
	return _resolved


static func available() -> bool:
	return load_data()


static func error() -> String:
	load_data()
	return _error


static func load_data() -> bool:
	if _loaded:
		return _error.is_empty()
	_loaded = true
	_data = {}
	if not FileAccess.file_exists(DATA_PATH):
		_error = "missing artifact: " + DATA_PATH
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		_error = "artifact is not a JSON object: " + DATA_PATH
		return false
	var data: Dictionary = parsed as Dictionary
	if String(data.get("schema", "")) != SCHEMA:
		_error = "unexpected language dock schema"
		return false
	if String(data.get("not_recovered_marker", "")) != NOT_RECOVERED:
		_error = "language dock has no NOT RECOVERED marker"
		return false
	var items: Array = Array(data.get("items", []))
	if items.size() != 8:
		_error = "language dock does not carry its eight decoded items"
		return false
	for index: int in range(items.size()):
		var item: Dictionary = items[index] as Dictionary
		if int(item.get("index", -1)) != index:
			_error = "language dock item order is not the decoded order"
			return false
		if String(item.get("lang_table", "")).is_empty():
			_error = "language dock item has no recovered Lang table"
			return false
	if String(data.get("labels", {}).get("display_names", "")) != NOT_RECOVERED:
		_error = "language display names are not marked NOT RECOVERED"
		return false
	if String(data.get("persistence", {}).get("original_format", "")) != NOT_RECOVERED:
		_error = "native persistence is not marked NOT RECOVERED"
		return false
	_data = data
	return true


static func items() -> Array:
	if not available():
		return []
	return Array(_data.get("items", [])).duplicate(true)


static func widget() -> Dictionary:
	if not available():
		return {}
	return Dictionary(_data.get("source", {}).get("ui_widget", {})).duplicate(true)


static func persistence() -> Dictionary:
	if not available():
		return {}
	return Dictionary(_data.get("persistence", {})).duplicate(true)


static func labels_status() -> String:
	if not available():
		return NOT_RECOVERED
	return String(Dictionary(_data.get("labels", {})).get("display_names", NOT_RECOVERED))


static func lang_table_for_index(index: int) -> String:
	var all: Array = items()
	if index < 0 or index >= all.size():
		return ""
	return String(Dictionary(all[index]).get("lang_table", ""))


static func index_for_lang_table(table: String) -> int:
	var all: Array = items()
	for index: int in range(all.size()):
		if String(Dictionary(all[index]).get("lang_table", "")) == table:
			return index
	return -1


static func save_path() -> String:
	return path_used()


static func load_saved_index() -> int:
	var path: String = path_used()
	if not FileAccess.file_exists(path):
		return -1
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return -1
	var index: int = int(Dictionary(parsed).get("language_index", -1))
	if index < 0 or index >= items().size():
		return -1
	# The saved table must still agree with the recovered item table.
	var saved_table: String = String(Dictionary(parsed).get("lang_table", ""))
	if not saved_table.is_empty() and saved_table != lang_table_for_index(index):
		return -1
	return index


## Exact JSON payload the port would persist for `index`.  Exposed separately so
## a validator can verify the serialized selection even where the harness denies
## the Godot child process any file write.
static func save_payload(index: int) -> String:
	if index < 0 or index >= items().size():
		return ""
	return JSON.stringify({
		"language_index": index,
		"lang_table": lang_table_for_index(index),
		"note": "PORT binding for the recovered CSettings 'language' value; "
				+ "the native on-disk format is NOT RECOVERED",
	})


static func save_index(index: int) -> bool:
	var payload: String = save_payload(index)
	if payload.is_empty():
		return false
	var file: FileAccess = FileAccess.open(path_used(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(payload)
	file.close()
	return true


## Index to show when the dock opens: the persisted one, else the current
## session language's recovered index, else the port default.  Never invents.
static func current_index() -> int:
	var saved: int = load_saved_index()
	if saved >= 0:
		return saved
	var session: int = index_for_lang_table(MenuLang.language())
	return session if session >= 0 else DEFAULT_INDEX


static func current_source() -> String:
	if load_saved_index() >= 0:
		return "saved"
	if index_for_lang_table(MenuLang.language()) >= 0:
		return "session_language"
	return "port_default"


## Apply (and persist) a dock index.  Sets the same `BRUCELEE_LANG` environment
## the rest of the port reads and updates MenuLang's cached language, so every
## recovered `.lang` label re-renders with the selected table.  Returns the
## applied Lang table, or "" when the index is invalid / the artifact is closed.
static func apply_index(index: int) -> String:
	var table: String = lang_table_for_index(index)
	if table.is_empty():
		return ""
	OS.set_environment("BRUCELEE_LANG", table)
	MenuLang.set_language(table)
	return table


## Startup hook: restore and apply the saved language before any label is built.
## Returns the applied Lang table, or "" when no valid save exists.
static func apply_saved() -> String:
	var saved: int = load_saved_index()
	if saved < 0:
		return ""
	return apply_index(saved)

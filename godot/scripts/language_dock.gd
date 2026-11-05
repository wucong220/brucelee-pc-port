extends RefCounted
class_name PortLanguageDock
const NativeStore = preload("res://scripts/native_settings_store.gd")
const MenuLangPre = preload("res://scripts/menu_lang.gd")
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
## RECOVERED (see res://data/menu_art/native_settings_format.json):
##   * the native on-disk format: a "1FDKENONCTX3" krm resource file named
##     `settings.dat` under sal::GetAppWritePath(); the language is the float
##     CSettings TReal keyed "language" in the "option" provider dict.
##   * the native default mapping from the device locale (en/es/de/it/fr/ru/
##     zh-Hans/zh-Hant -> 0/1/2/3/4/5/6/7).
## Still NOT RECOVERED: the display NAME of each language (no Lang*.lang name
## keys), so the dock keeps showing flags + the recovered Lang table ids.
##
## A missing/invalid artifact fails closed: `available()` is false, `items()` is
## empty and the caller keeps its pre-existing NOT RECOVERED screen.

const DATA_PATH := "res://data/menu_art/language_dock.json"
const NATIVE_FORMAT_PATH := "res://data/menu_art/native_settings_format.json"
const SAVE_PATH_ENV := "BRUCELEE_LANGUAGE_SAVE_PATH"
## Native on-disk file, recovered from krm::CApplication::End -> CGameDataManager::Save
## (a "1FDKENONCTX3" resource named settings.dat under sal::GetAppWritePath()).
const DEFAULT_SAVE_PATH := "user://settings.dat"
## Legacy PORT binding (JSON). Read ONLY as an explicit one-way migration when
## no native settings.dat exists; the port never writes this file any more.
const LEGACY_PORT_PATH := "user://ui_gaps_language.json"
const NOT_RECOVERED := "NOT RECOVERED"
const RECOVERED := "RECOVERED"
const SCHEMA := "brucelee-language-dock/1"
const NATIVE_SCHEMA := "brucelee-native-settings/1"
## Port default when neither a save nor a valid session language exists.  The
## native default (GetDefaultDisplayLanguage) is NOT RECOVERED, so this is the
## port's existing fallback (LangEnglish) and is reported as such.
const DEFAULT_INDEX := 0

static var _data: Dictionary = {}
static var _error: String = ""
static var _loaded: bool = false
static var _resolved: String = ""
static var _native: Dictionary = {}
static var _native_error: String = ""
static var _native_loaded: bool = false
static var _last_source: String = "none"


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
	## The native persistence format is now RECOVERED: report it from the
	## dedicated evidence artifact instead of the old NOT RECOVERED stub.
	if not load_native_format():
		return {"original_format": NOT_RECOVERED, "error": _native_error}
	return Dictionary(_native.get("container", {})).duplicate(true)


static func native_format() -> Dictionary:
	if not load_native_format():
		return {}
	return _native.duplicate(true)


static func native_format_status() -> String:
	if not load_native_format():
		return NOT_RECOVERED
	return String(_native.get("status", NOT_RECOVERED))


static func native_file_name() -> String:
	if not load_native_format():
		return ""
	return String(Dictionary(_native.get("file", {})).get("name", ""))


static func load_native_format() -> bool:
	if _native_loaded:
		return _native_error.is_empty()
	_native_loaded = true
	_native = {}
	if not FileAccess.file_exists(NATIVE_FORMAT_PATH):
		_native_error = "missing artifact: " + NATIVE_FORMAT_PATH
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NATIVE_FORMAT_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		_native_error = "artifact is not a JSON object"
		return false
	_native = parsed as Dictionary
	if String(_native.get("schema", "")) != NATIVE_SCHEMA:
		_native_error = "unexpected native settings schema"
		return false
	if String(_native.get("status", "")) != RECOVERED:
		_native_error = "native settings format is not marked RECOVERED"
		return false
	return true


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
	_last_source = "none"
	if FileAccess.file_exists(path):
		# Native file is authoritative. A present-but-unparseable native file is a
		# hard failure: never silently fall back to the legacy PORT json.
		var index: int = NativeStore.read_language(path)
		if index < 0 or index >= items().size():
			_last_source = "native_fail_closed"
			return -1
		_last_source = "native"
		return index
	# No native file: explicit, one-way migration read of the old PORT json.
	var legacy: int = load_legacy_index()
	if legacy >= 0:
		_last_source = "legacy_port_migration"
		return legacy
	return -1


## Read the old PORT JSON binding (migration only; never written back).
static func load_legacy_index() -> int:
	if not FileAccess.file_exists(LEGACY_PORT_PATH):
		return -1
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_PORT_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return -1
	var index: int = int(Dictionary(parsed).get("language_index", -1))
	if index < 0 or index >= items().size():
		return -1
	var saved_table: String = String(Dictionary(parsed).get("lang_table", ""))
	if not saved_table.is_empty() and saved_table != lang_table_for_index(index):
		return -1
	return index


static func last_source() -> String:
	return _last_source


## Human-readable description of what a save would write (kept for the existing
## validators; the bytes themselves are produced by save_bytes()).
static func save_payload(index: int) -> String:
	if index < 0 or index >= items().size():
		return ""
	return JSON.stringify({
		"language_index": index,
		"lang_table": lang_table_for_index(index),
		"format": "native 1FDKENONCTX3 krm resource (settings.dat)",
		"provider": "option",
		"key": "language",
		"status": RECOVERED,
	})


## Native bytes the port persists for `index` (the original on-disk format).
static func save_bytes(index: int) -> PackedByteArray:
	if index < 0 or index >= items().size():
		return PackedByteArray()
	var tree: Dictionary = NativeStore.default_tree(index)
	return NativeStore.encode(tree)


static func save_index(index: int) -> bool:
	if index < 0 or index >= items().size():
		return false
	return NativeStore.write_language(path_used(), index)


## Index to show when the dock opens: the persisted one, else the current
## session language's recovered index, else the port default.  Never invents.
static func current_index() -> int:
	var saved: int = load_saved_index()
	if saved >= 0:
		return saved
	var session: int = index_for_lang_table(MenuLangPre.language())
	return session if session >= 0 else DEFAULT_INDEX


static func current_source() -> String:
	if load_saved_index() >= 0:
		return _last_source
	if index_for_lang_table(MenuLangPre.language()) >= 0:
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
	MenuLangPre.set_language(table)
	return table


## Startup hook: restore and apply the saved language before any label is built.
## Returns the applied Lang table, or "" when no valid save exists.
static func apply_saved() -> String:
	var saved: int = load_saved_index()
	if saved < 0:
		return ""
	return apply_index(saved)

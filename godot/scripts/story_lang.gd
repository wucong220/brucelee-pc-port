extends RefCounted
## Localized story-flow labels recovered from the ten shipped .lang resources.
##
## Data: res://data/story/story_text_by_language.json
##   { "LangEnglish": { key: value, ... }, "LangChineseSimpl": {...}, ... }
## Generated, read-only, by story-lang-20261104/tools/build_lookup.py from the
## decoded .lang CTX3 containers.  No string is synthesised here: a key that is
## absent from the table is returned verbatim so a missing translation is
## visible instead of replaced by invented text.
##
## The story data uses lower-case text keys for chapter 1 (`st_themaster_*`) but
## capitalises the chapter-2..5 text keys (`St_BurningTiger_*`, `St_Changes_*`,
## `St_CriminalBrothers_*`, `St_TheTournament_*`) while the .lang stores them in
## lower case.  `text()` therefore falls back to a case-insensitive match.

const DATA_PATH: String = "res://data/story/story_text_by_language.json"
const DEFAULT_LANG: String = "LangEnglish"

var current_lang: String = DEFAULT_LANG
var error: String = ""
var _by_lang: Dictionary = {}
var _canonical_lower: Dictionary = {}  # lower-case key -> canonical key


func _init(path: String = DATA_PATH, lang: String = DEFAULT_LANG) -> void:
	current_lang = lang
	load_file(path)


func load_file(path: String) -> bool:
	error = ""
	_by_lang = {}
	_canonical_lower = {}
	if not FileAccess.file_exists(path):
		error = "story lang table missing: " + path
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		error = "story lang table is not an object: " + path
		return false
	_by_lang = parsed
	var base: Dictionary = _by_lang.get(DEFAULT_LANG, {})
	for k: Variant in base.keys():
		_canonical_lower[String(k).to_lower()] = String(k)
	return true


func is_loaded() -> bool:
	return not _by_lang.is_empty()


func languages() -> Array:
	return _by_lang.keys()


func has_lang(lang: String) -> bool:
	return _by_lang.has(lang)


## Localized string for a recovered key.  Uses `lang` when given, else the
## instance default.  Falls back to a case-insensitive key match, then returns
## the key unchanged when no value exists (never invents text).
func text(key: String, lang: String = "") -> String:
	if key.is_empty():
		return key
	var use_lang: String = lang if not lang.is_empty() else current_lang
	var table: Dictionary = _by_lang.get(use_lang, {})
	if table.has(key):
		return String(table[key])
	var canon: String = String(_canonical_lower.get(key.to_lower(), ""))
	if not canon.is_empty() and table.has(canon):
		return String(table[canon])
	return key

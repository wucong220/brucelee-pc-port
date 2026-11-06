extends RefCounted
class_name PortCreditsText
## Read-only model for the verbatim DLE / IndiaGames credit-roll text decoded
## from the ten shipped `Lang*.lang` CTX3 tables.
##
## Data asset: `res://data/menu_art/credits_text.json` (verbatim strings; absent
## keys are represented by absence).  The native `CCreditsView::GenerateSprites`
## loops `first_number..last_number`, calls Translate(prefix%03d) and falls back
## to the empty string on a miss, so an absent key is a blank line that still
## occupies a font line height.  `lines()` therefore always returns the full
## first..last sequence.
##
## Fail closed: a missing/invalid artifact, an unknown roll, a mismatch with the
## decoded `.ui` credits widget, or a language with no populated lines for that
## roll all yield an empty PackedStringArray and name the cause in `error()`.

const DATA_PATH := "res://data/menu_art/credits_text.json"
const ENV_PATH := "BRUCELEE_CREDITS_TEXT_PATH"
const SCHEMA := "brucelee-credits-text/1"
const FALLBACK_LANGUAGE := "LangEnglish"
const ROLLS := ["dle", "ig"]

static var _data: Dictionary = {}
static var _error: String = ""
static var _loaded: bool = false
static var _resolved: String = ""


## Test-only: clear the static cache so an env-path change is observed.
static func reset_for_test() -> void:
	_data = {}
	_error = ""
	_loaded = false
	_resolved = ""


static func path_used() -> String:
	if _resolved.is_empty():
		var env_path: String = OS.get_environment(ENV_PATH)
		_resolved = env_path if not env_path.is_empty() else DATA_PATH
	return _resolved


static func available() -> bool:
	if not _loaded:
		load_data()
	return not _data.is_empty()


static func error() -> String:
	load_data()
	return _error


static func load_data() -> bool:
	if _loaded:
		return _error.is_empty()
	_loaded = true
	_data = {}
	_error = ""
	var path: String = path_used()
	if not FileAccess.file_exists(path):
		_error = "missing credits text artifact: " + path
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		_error = "credits text artifact is not a JSON object"
		return false
	var data: Dictionary = parsed as Dictionary
	if String(data.get("schema", "")) != SCHEMA:
		_error = "unexpected credits text schema"
		return false
	var rolls: Dictionary = Dictionary(data.get("rolls", {}))
	for roll: String in ROLLS:
		var spec: Dictionary = Dictionary(rolls.get(roll, {}))
		if String(spec.get("prefix", "")).is_empty() \
				or int(spec.get("last", 0)) < int(spec.get("first", 0)):
			_error = "credits text artifact has no range for roll " + roll
			return false
	if not Dictionary(data.get("languages", {})).has(FALLBACK_LANGUAGE):
		_error = "credits text artifact has no " + FALLBACK_LANGUAGE
		return false
	_data = data
	return true


static func roll_spec(roll: String) -> Dictionary:
	if not available():
		return {}
	return Dictionary(Dictionary(_data.get("rolls", {})).get(roll, {})).duplicate(true)


## True when the decoded `.ui` credits widget names exactly the recovered range.
static func matches_layout(roll: String, prefix_value: String, first_value: int,
		last_value: int) -> bool:
	var spec: Dictionary = roll_spec(roll)
	if spec.is_empty():
		_error = "unknown credit roll " + roll
		return false
	if String(spec.get("prefix", "")) != prefix_value \
			or int(spec.get("first", -1)) != first_value \
			or int(spec.get("last", -1)) != last_value:
		_error = "credits text range does not match the decoded .ui widget for " + roll
		return false
	return true


static func populated_count(roll: String, language: String) -> int:
	if not available():
		return 0
	var table: Dictionary = _language_rolls(language)
	if table.is_empty():
		return 0
	return Dictionary(table.get(roll, {})).size()


static func _language_rolls(language: String) -> Dictionary:
	var languages: Dictionary = Dictionary(_data.get("languages", {}))
	var chosen: Dictionary = {}
	if languages.has(language):
		chosen = Dictionary(languages[language])
	else:
		chosen = Dictionary(languages.get(FALLBACK_LANGUAGE, {}))
	# A language present only as empty tables falls back to English.
	if _roll_population(chosen) == 0 and language != FALLBACK_LANGUAGE:
		chosen = Dictionary(languages.get(FALLBACK_LANGUAGE, {}))
	return chosen


static func _roll_population(language_table: Dictionary) -> int:
	var total: int = 0
	for roll: String in ROLLS:
		total += Dictionary(language_table.get(roll, {})).size()
	return total


## Full first..last line sequence for a roll; "" for an absent key (blank line).
static func lines(roll: String, language: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not available():
		return out
	var spec: Dictionary = roll_spec(roll)
	if spec.is_empty():
		_error = "unknown credit roll " + roll
		return out
	var table: Dictionary = _language_rolls(language)
	if table.is_empty() or Dictionary(table.get(roll, {})).is_empty():
		_error = "no recovered credit lines for %s/%s" % [roll, language]
		return out
	var values: Dictionary = Dictionary(table.get(roll, {}))
	var first: int = int(spec.get("first", 1))
	var last: int = int(spec.get("last", 0))
	for n: int in range(first, last + 1):
		out.append(String(values.get(str(n), "")))
	return out

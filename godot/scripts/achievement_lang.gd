extends RefCounted
## Recovered achievement title / description text (10 shipped `.lang` files).
##
## `res://data/lang/achievement_lang.json` is generated read-only by
## `tools/recover_achievement_text.py` from the resources extracted directly out
## of `data.zpak`:
##   * `description_keys` are the EXACT `description` field values of the 38
##     `adreno_200/achievements.list` rows (they are `achv_*` translation keys);
##   * `screen_title_key` is the EXACT `translate` key the `title` label of
##     `adreno_200/gui/achievementstable.ui` binds to (`achievements`);
##   * every value is copied verbatim from all ten decoded `.lang` tables.
##
## Contract:
##   * `text(key)` returns the decoded value for the active language.
##   * A key with no decoded value returns the literal `NOT RECOVERED`. No text
##     is ever invented, and the raw key is never shown as if it were a label.
##   * The active language follows `BRUCELEE_LANG` (full `LangXxx` name or short
##     alias) via `MenuLang`, with `LangEnglish` as the default.
##
## This helper only supplies display strings. It never feeds achievement logic.

const MenuLangScript = preload("res://scripts/menu_lang.gd")

const DATA_PATH := "res://data/lang/achievement_lang.json"
const ENV_LANG := "BRUCELEE_LANG"
const FALLBACK_LANGUAGE := "LangEnglish"
const NOT_RECOVERED := "NOT RECOVERED"

const FONT_NAMES := {
	"LangChineseSimpl": ["Microsoft YaHei UI", "Microsoft YaHei", "SimSun", "Noto Sans CJK SC"],
	"LangChineseTrad": ["Microsoft JhengHei UI", "Microsoft JhengHei", "Microsoft YaHei", "SimSun"],
	"LangJapanese": ["Yu Gothic UI", "Yu Gothic", "Meiryo", "MS Gothic", "Microsoft YaHei"],
	"LangKorean": ["Malgun Gothic", "Gulim", "Microsoft YaHei"],
}

static var _data: Dictionary = {}
static var _loaded: bool = false
static var _fonts: Dictionary = {}


static func _ensure() -> bool:
	if _loaded:
		return not _data.is_empty()
	_loaded = true
	_data = {}
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("AchievementLang: missing " + DATA_PATH)
		return false
	var raw: String = FileAccess.get_file_as_string(DATA_PATH)
	if raw.is_empty():
		push_warning("AchievementLang: empty " + DATA_PATH)
		return false
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("AchievementLang: invalid JSON in " + DATA_PATH)
		return false
	_data = parsed
	return true


static func is_loaded() -> bool:
	return _ensure()


static func data() -> Dictionary:
	if not _ensure():
		return {}
	return _data


static func languages() -> Array:
	var out: Array = []
	if not _ensure():
		return out
	for value: Variant in _data.get("languages", []):
		out.append(String(value))
	return out


static func description_keys() -> Array:
	var out: Array = []
	if not _ensure():
		return out
	for value: Variant in _data.get("description_keys", []):
		out.append(String(value))
	return out


static func screen_title_key() -> String:
	if not _ensure():
		return ""
	return String(_data.get("screen_title_key", ""))


static func not_recovered() -> Array:
	if not _ensure():
		return []
	return (_data.get("not_recovered", []) as Array).duplicate(true)


static func language() -> String:
	## Resolve the env on every call so BRUCELEE_LANG changes take effect without
	## a restart; fall back to MenuLang's active language (which honours
	## MenuLang.set_language) when the env is empty or unknown.
	var from_env: String = OS.get_environment(ENV_LANG).strip_edges()
	if not from_env.is_empty():
		var normalized: String = MenuLangScript.normalize_language(from_env)
		if not normalized.is_empty() and languages().has(normalized):
			return normalized
	var active: String = MenuLangScript.language()
	return active if languages().has(active) else FALLBACK_LANGUAGE


static func has_value(key: String, lang: String = "") -> bool:
	if key.is_empty() or not _ensure():
		return false
	var active: String = lang.strip_edges()
	if active.is_empty():
		active = language()
	elif not languages().has(active):
		return false
	var row: Variant = (_data.get("keys", {}) as Dictionary).get(key, null)
	if not row is Dictionary:
		return false
	var value: Variant = (row as Dictionary).get(active, null)
	return value != null and not String(value).is_empty()


## Decoded value for `key`, or the literal `NOT RECOVERED` when there is none.
static func text(key: String, lang: String = "") -> String:
	if key.is_empty():
		return ""
	if not _ensure():
		return NOT_RECOVERED
	var active: String = lang.strip_edges()
	if active.is_empty():
		active = language()
	elif not languages().has(active):
		return NOT_RECOVERED
	var row: Variant = (_data.get("keys", {}) as Dictionary).get(key, null)
	if not row is Dictionary:
		return NOT_RECOVERED
	var value: Variant = (row as Dictionary).get(active, null)
	if value == null:
		return NOT_RECOVERED
	var result: String = String(value)
	return NOT_RECOVERED if result.is_empty() else result


## Decoded `.lang` value of the achievements screen title key.
static func screen_title(lang: String = "") -> String:
	return text(screen_title_key(), lang)


static func ui_font() -> Font:
	var active: String = language()
	if not FONT_NAMES.has(active):
		return null
	if _fonts.has(active):
		return _fonts[active]
	var font: SystemFont = SystemFont.new()
	var names: Array[String] = []
	for font_name: Variant in FONT_NAMES[active]:
		names.append(String(font_name))
	font.font_names = PackedStringArray(names)
	font.allow_system_fallback = true
	_fonts[active] = font
	return font


## Apply the active-language font so CJK values render instead of tofu.
static func apply_font(label: Label) -> void:
	var font: Font = ui_font()
	if font != null and label != null:
		label.add_theme_font_override("font_name", font)

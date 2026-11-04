class_name StoryNoticeModel
extends RefCounted

## Pure, headless-testable presentation model for the recovered story-mode
## notices:
##   * LevelUpNotify   (gui/levelup.ui)   - "Level Up!"  /  "Level %d"
##   * ExperienceUnlock(gui/unlock.ui)    - "<item type> unlocked!" + item name
##
## All layout/text comes from res://data/progress/story_notice.json, which is
## generated from the decoded adreno_200/gui/levelup.ui + gui/unlock.ui, the
## shipped .lang translations and the level table inside libdefault.so.
## Nothing here invents text: an unrecovered value is the literal string
## "NOT RECOVERED" (NOT_RECOVERED) and is flagged recovered=false.

const DATA_PATH: String = "res://data/progress/story_notice.json"
const NOT_RECOVERED: String = "NOT RECOVERED"

var data: Dictionary = {}
var error: String = ""
var current_lang: String = "LangEnglish"
var _table: Array = []


func _init(path: String = DATA_PATH, lang: String = "LangEnglish") -> void:
	current_lang = lang
	load_data(path)


func load_data(path: String) -> bool:
	error = ""
	data = {}
	_table = []
	if not FileAccess.file_exists(path):
		error = "story notice data missing: " + path
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		error = "story notice data is not an object: " + path
		return false
	data = parsed
	for v: Variant in (data.get("level_rule", {}) as Dictionary).get("table", []):
		_table.append(int(v))
	if _table.size() != 50:
		error = "level table must have 50 entries (got %d)" % _table.size()
		return false
	return true


func is_loaded() -> bool:
	return not _table.is_empty()


func languages() -> Array:
	var row: Dictionary = (data.get("translations", {}) as Dictionary).get("you_reached_level", {})
	return row.keys()


## Localized recovered text. Falls back to English, then returns the key
## unchanged (never invents a value).
func text(key: String, lang: String = "") -> String:
	if key.is_empty():
		return key
	var table: Dictionary = (data.get("translations", {}) as Dictionary).get(key, {})
	if table.is_empty():
		return key
	var use_lang: String = lang if not lang.is_empty() else current_lang
	if table.has(use_lang):
		return String(table[use_lang])
	if table.has("LangEnglish"):
		return String(table["LangEnglish"])
	return key


func max_level() -> int:
	return int((data.get("level_rule", {}) as Dictionary).get("max_level", 50))


## Recovered level curve: new game level 1; transition L -> L+1 uses table[L]
## (0-based), i.e. exp >= table[level] advances one level. Saturates at 50.
func level_for_exp(exp: int) -> int:
	var level: int = int((data.get("level_rule", {}) as Dictionary).get("new_game_level", 1))
	var top: int = max_level()
	var n: int = _table.size()
	while level < top and level < n and exp >= _table[level]:
		level += 1
	return level


## CBruceLeeStoryMode::StoryLevelUpPending(): exp >= StoryExperienceNeeded(level+1)
## and StoryExperienceNeeded(level+1) == table[level].
func level_up_pending(exp: int, level: int) -> bool:
	if level >= max_level() or level < 0 or level >= _table.size():
		return false
	return exp >= _table[level]


## Ordered notices for an EXP award, matching the native state chain
##   storycheckfirstunlock: new unlock -> ExperienceUnlock
##                          else pending level -> StoryLevelUp + LevelUpNotify
## fresh_unlock_ids are ids newly granted this step (from ProgressService).
func notices_for(before_exp: int, after_exp: int, fresh_unlock_ids: Array,
		registry = null, resolve_item: Callable = Callable(),
		before_level: int = -1, after_level: int = -1) -> Array:
	var out: Array = []
	for id: Variant in fresh_unlock_ids:
		out.append(unlock_notice(int(id), registry, resolve_item))
	var lb: int = before_level if before_level >= 0 else level_for_exp(before_exp)
	var la: int = after_level if after_level >= 0 else level_for_exp(after_exp)
	if la > lb:
		out.append(levelup_notice(la))
	return out


func _screen(name: String) -> Dictionary:
	return (data.get("screens", {}) as Dictionary).get(name, {})


func levelup_notice(level: int) -> Dictionary:
	var scr: Dictionary = _screen("levelup")
	var fmt: String = "Level %d"
	for row: Variant in scr.get("text", []):
		if row is Dictionary and String(Dictionary(row).get("kind", "")) == "format":
			fmt = String(Dictionary(row).get("format", fmt))
	return {
		"kind": "levelupnotify",
		"screen": "levelup",
		"level": int(level),
		"title": text("you_reached_level"),
		"title_recovered": true,
		"body": fmt % int(level),
		"body_recovered": true,
		"menu_label": text("continue"),
		"menu_recovered": true,
		"sound": String(scr.get("sound", "")),
		"start_action": String(scr.get("start_action", "")),
		"ui": String(scr.get("ui", "gui/levelup.ui")),
		"ok_action": String(scr.get("ok_action", "storychecknextunlock")),
		"layout": scr,
		"provenance": {
			"title": "levelup.ui title.datasources.text = translate(you_reached_level)",
			"body": "levelup.ui level.datasources.text = format(%s, gamemodes.storycurrentlevel)" % fmt,
			"level": "libdefault.so StoryLevelUpPending 0x1e4684 / StoryLevelUp 0x1e5abc",
		},
	}


func unlock_notice(unlock_id: int, registry = null, resolve_item: Callable = Callable()) -> Dictionary:
	var scr: Dictionary = _screen("unlock")
	var entry: Dictionary = {}
	if registry != null and registry.has_method("entry_for_id"):
		entry = registry.entry_for_id(int(unlock_id))
	var item_type: String = String(entry.get("item_type", ""))
	var item_id: Variant = entry.get("item_id", null)
	var title_key: String = String((data.get("item_type_title_key", {}) as Dictionary).get(item_type, ""))
	var title: String = NOT_RECOVERED
	var title_recovered: bool = false
	if not title_key.is_empty():
		title = text(title_key)
		title_recovered = true
	var name: String = ""
	var name_proven: bool = false
	if resolve_item.is_valid():
		var r: Variant = resolve_item.call(item_type, item_id)
		if r is Dictionary:
			name = String(Dictionary(r).get("name", ""))
			name_proven = Dictionary(r).get("proven", false) == true
	var item_name: String = NOT_RECOVERED
	var item_recovered: bool = false
	if name_proven and not name.is_empty():
		item_name = name
		item_recovered = true
	return {
		"kind": "experienceunlock",
		"screen": "unlock",
		"unlock_id": int(unlock_id),
		"item_type": item_type,
		"item_id": item_id,
		"title": title,
		"title_recovered": title_recovered,
		"title_key": title_key,
		"item_name": item_name,
		"item_name_recovered": item_recovered,
		"icon_recovered": false,
		"icon_label": NOT_RECOVERED,
		"menu_label": text("ok"),
		"menu_recovered": true,
		"sound": String(scr.get("sound", "")),
		"start_action": String(scr.get("start_action", "")),
		"ui": String(scr.get("ui", "gui/unlock.ui")),
		"ok_action": String(scr.get("ok_action", "storychecknextunlock")),
		"layout": scr,
		"provenance": {
			"title": "unlock.ui title.datasources.text = unlocker.unlocktitle; item_type '%s' -> .lang key '%s'" % [item_type, title_key],
			"item_name": "unlocker.itemname resolved from recovered unlock_item_names (proven=%s)" % str(name_proven),
			"icon": "unlocker.unlockthumbnail (tex not decoded) -> NOT RECOVERED",
			"trigger": "libdefault.so CUnlocker::CheckStoryUnlocks 0x172ad8",
		},
	}


## Human-readable one-line description (used by tests / logs).
func describe(notice: Dictionary) -> String:
	if String(notice.get("kind", "")) == "levelupnotify":
		return "levelupnotify level=%d title=%s body=%s menu=%s" % [
			int(notice.get("level", 0)), String(notice.get("title", "")),
			String(notice.get("body", "")), String(notice.get("menu_label", ""))]
	return "experienceunlock id=%d type=%s title=%s itemname=%s" % [
		int(notice.get("unlock_id", -1)), String(notice.get("item_type", "")),
		String(notice.get("title", "")), String(notice.get("item_name", ""))]

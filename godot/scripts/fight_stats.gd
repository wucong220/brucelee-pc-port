extends RefCounted
## Recovered per-fight result counters (TFightResults +0x04 / +0x08 / +0x0c / +0x10).
##
## Native model (libdefault.so, SHA-256 1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70):
##   * CFighter::SetAnimation 0x1a6e94 walks the category list of the animation
##     it starts (animation descriptor +0x68 count, +0x6c array) and stores every
##     category name in the fighter's record map (+0x1a0 size/+0x1a8, data
##     +0x1ac, stride +0x1b0).  The stored value is written as 1 unconditionally
##     in both the found and the inserted path (0x1a76e0 `mov r3,#1; str r3,[r8]`),
##     so the record is a presence set, not a play count.
##   * CFighter::GetAnmCategory 0x1a6d50 returns that value (0 when absent).
##   * CBeatEmUpGameModes::RegisterLastFightVariables 0x15ca6c fills TFightResults
##     +0x04/+0x08/+0x0c with GetAnmCategory(player fighter, "counter"/"special"/
##     "endmove") and +0x10 with the player fighter record byte +0x174.
##   * CFighter::ResetAnimCategoriesRecord 0x1a1058 clears the record; its only
##     caller is CBeatEmUpGame::SetInitialRoundValues 0x178d44, reached from
##     CBeatEmUpMatch::Restart 0x161df4 <- RestartFight, i.e. once per match.
##
## The action -> category table is copied verbatim from the decoded fighting
## sets (audit-combat-20261103/_evidence/actions_*.json).  No move category is
## invented here: an action with no recovered category stays unclassified.

const TABLE_PATH: String = "res://data/progress/fight_stats_categories.json"

const COUNTER: String = "counter"
const SPECIAL: String = "special"
const ENDMOVE: String = "endmove"
const CATEGORIES: Array[String] = [COUNTER, SPECIAL, ENDMOVE]

static var _table: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file: FileAccess = FileAccess.open(TABLE_PATH, FileAccess.READ)
	if file == null:
		push_error("Fight stat category table is missing: " + TABLE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Fight stat category table is invalid: " + TABLE_PATH)
		return
	var actions: Variant = (parsed as Dictionary).get("actions", {})
	if actions is Dictionary:
		_table = (actions as Dictionary).duplicate(true)


static func is_loaded() -> bool:
	_ensure_loaded()
	return not _table.is_empty()


static func action_count() -> int:
	_ensure_loaded()
	return _table.size()


## The recovered categories carried by a native action name, e.g.
## "parryhigh" -> ["counter"], "endattack1" -> ["endmove"].
static func categories_for_action(action: String) -> Array:
	_ensure_loaded()
	var categories: Variant = _table.get(action, [])
	if categories is Array:
		return (categories as Array).duplicate()
	return []


## The native action name behind one of the port's ATTACKS kinds (the same
## `source_action` the link data uses), falling back to the kind itself.
static func action_for_kind(attacks: Dictionary, kind: String) -> String:
	var row: Variant = attacks.get(kind, {})
	if row is Dictionary:
		var source_action: String = String((row as Dictionary).get("source_action", ""))
		if not source_action.is_empty():
			return source_action
	return kind

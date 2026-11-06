class_name ProgressService
extends RefCounted

## Facade that applies game events to the save state, grants unlocks, and
## re-evaluates achievements. All granting is data-driven; nothing is invented.

var state: Dictionary
var registry: UnlockRegistry
var achievements: AchievementEngine


func _init() -> void:
	registry = UnlockRegistry.new()
	registry.load_data()
	achievements = AchievementEngine.new()
	achievements.load_data()
	state = SaveManager.default_state()


# ---- story ---------------------------------------------------------------

func add_story_exp(amount: int) -> Array:
	## Grant every story_unlocks row whose exp threshold is now <= story EXP.
	if amount < 0:
		return []
	state["story"]["exp"] = int(state["story"]["exp"]) + amount
	var fresh: Array = []
	for id in registry.ids_for_exp(int(state["story"]["exp"])):
		if _grant_unlock(int(id), "story_exp"):
			fresh.append(int(id))
	return fresh


func complete_story_event(chapter: String, maptitle: String) -> Array:
	## Mark a story event complete and grant its authored unlock subevents.
	var key := "%s/%s" % [chapter, maptitle]
	var events: Array = state["story"]["events_completed"]
	if not events.has(key):
		events.append(key)
		state["counters"]["story_events_completed"] = int(state["counters"].get("story_events_completed", 0)) + 1
	var fresh: Array = []
	for id in registry.ids_for_event(chapter, maptitle):
		if _grant_unlock(int(id), "story_event"):
			fresh.append(int(id))
	return fresh


func complete_chapter(chapter: String) -> void:
	var chapters: Array = state["story"]["chapters_completed"]
	if not chapters.has(chapter):
		chapters.append(chapter)
	chapters.sort()
	state["counters"]["story_chapters_completed"] = chapters.size()


func complete_story_difficulty(difficulty: String) -> void:
	var diffs: Array = state["story"]["completed_difficulties"]
	if not diffs.has(difficulty):
		diffs.append(difficulty)
	diffs.sort()


# ---- modes ---------------------------------------------------------------

func record_mode_clear(mode: String, difficulty: String) -> void:
	if state["mode_clears"].has(mode) and state["mode_clears"][mode].has(difficulty):
		state["mode_clears"][mode][difficulty] = true


func record_versus_win() -> void:
	state["counters"]["versus_wins"] = int(state["counters"].get("versus_wins", 0)) + 1


func record_survival_round(rounds_survived: int) -> void:
	var best := int(state["counters"].get("survival_best_round", 0))
	if rounds_survived > best:
		state["counters"]["survival_best_round"] = rounds_survived


# ---- combat counters (from RegisterLastFightVariables) -------------------

func add_counter(name: String, amount: int = 1) -> void:
	state["counters"][name] = int(state["counters"].get(name, 0)) + amount


func set_counter(name: String, value: int) -> void:
	state["counters"][name] = value


# ---- achievements --------------------------------------------------------

func refresh_achievements() -> Array:
	return achievements.grant(state)


# ---- persistence ---------------------------------------------------------

func save(path: String = SaveManager.SAVE_PATH) -> bool:
	return SaveManager.save_state(state, path)


func load_or_default(path: String = SaveManager.SAVE_PATH) -> bool:
	var loaded := SaveManager.load_state(path)
	if loaded.is_empty():
		state = SaveManager.default_state()
		return false
	state = loaded
	return true


# ---- helpers -------------------------------------------------------------

func unlocked_ids() -> Array:
	var ids: Array = state["unlocks"]["unlocked_ids"]
	ids.sort()
	return ids


func _grant_unlock(id: int, source: String) -> bool:
	if id < 0 or id >= registry.num_ids:
		return false
	var ids: Array = state["unlocks"]["unlocked_ids"]
	if ids.has(id):
		return false
	ids.append(id)
	ids.sort()
	state["unlocks"]["sources"][str(id)] = source
	return true

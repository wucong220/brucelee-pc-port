extends Node
## Opt-in bridge between the running game and the recovered progress/save
## subsystem.
##
## This node is created by main.gd ONLY when BRUCELEE_PROGRESS=1, so the shared
## code paths are untouched when the flag is absent. The subsystem scripts
## (save_manager.gd / unlock_registry.gd / achievement_engine.gd /
## progress_service.gd) and data/progress/*.json are copied verbatim from the
## isolated progress prototype; this file only adapts game events to their
## public API and persists the checksummed user:// save.
##
## Every mutation re-evaluates achievements and writes the save atomically, so
## counters/unlocks survive the per-fight scene reloads that the story and
## arcade-mode flows use. Anything whose threshold/trigger was not recovered is
## left to the service's fail-closed evaluation; nothing is invented here.

const ProgressServiceScript = preload("res://scripts/progress_service.gd")
const NativeProgressStoreScript = preload("res://scripts/native_progress_store.gd")

var service = null
var active: bool = false
var save_path: String = SaveManager.SAVE_PATH
var native_store = null
var native_path: String = ""
var native_ok: bool = true
var native_error: String = ""

var _last_grab_seq: int = -1
var _last_endmove_seq: int = -1
var _last_synced_exp: int = 0
var event_log: Array = []


func configure(path: String = SaveManager.SAVE_PATH, native_path_override: String = "") -> void:
	service = ProgressServiceScript.new()
	save_path = path
	var loaded: bool = service.load_or_default(save_path)
	native_store = null
	native_path = native_path_override
	if native_path.is_empty():
		native_path = OS.get_environment("BRUCELEE_NATIVE_SETTINGS")
	native_ok = true
	native_error = ""
	if not native_path.is_empty():
		native_store = NativeProgressStoreScript.new()
		if not native_store.configure(native_path):
			native_ok = false
			native_error = native_store.error
		elif not native_store.load_into(service):
			native_ok = false
			native_error = native_store.error
		elif not service.save(save_path):
			native_ok = false
			native_error = "failed to mirror native state to the JSON save"
	_last_synced_exp = int(service.state["story"]["exp"])
	active = service.registry.loaded and service.achievements.loaded and native_ok
	print("PROGRESS_SERVICE active=%s loaded=%s unlocked=%d achievements=%d native=%s native_ok=%s" % [
		str(active), str(loaded), service.unlocked_ids().size(),
		service.state["achievements"]["reached"].size(), native_path, str(native_ok),
	])
	if not native_ok:
		push_error("NATIVE_PROGRESS_DISABLED: " + native_error)


func is_active() -> bool:
	return active


func _flush(tag: String) -> Array:
	## Refresh achievements, persist, and return the newly reached ids.
	if service == null:
		return []
	var fresh: Array = service.refresh_achievements()
	if native_store != null:
		if not native_store.save_from(service):
			native_ok = false
			native_error = native_store.error
			push_error("NATIVE_PROGRESS_SAVE_FAILED: " + native_error)
			return []
	if not service.save(save_path):
		return []
	event_log.append({"tag": tag, "fresh": fresh.duplicate()})
	if not fresh.is_empty():
		print("PROGRESS_ACHIEVEMENT %s %s" % [tag, JSON.stringify(fresh)])
	return fresh


# ---------------------------------------------------------------------- story

func sync_story_exp(total_exp: int) -> Array:
	## Grant EXP-gated unlocks for any recovered EXP the story flow ever reports.
	## The decoded story subevents carry no EXP reward (only the 40-row
	## unlocks.list table exists), so in normal play total_exp stays 0 and this
	## is a no-op; the path is wired so the recovered table drives grants if EXP
	## becomes available.
	if service == null or total_exp <= _last_synced_exp:
		return []
	var delta: int = total_exp - _last_synced_exp
	var fresh_unlocks: Array = service.add_story_exp(delta)
	_last_synced_exp = total_exp
	var reached: Array = _flush("story_exp+%d" % delta)
	reached.append_array(fresh_unlocks)
	return reached


func note_story_event(chapter: String, maptitle: String) -> Array:
	## Grant the deterministic unlock subevents authored on this story event.
	if service == null:
		return []
	var fresh_unlocks: Array = service.complete_story_event(chapter, maptitle)
	var reached: Array = _flush("story_event:%s/%s" % [chapter, maptitle])
	reached.append_array(fresh_unlocks)
	return reached


func note_story_chapter(chapter: String) -> Array:
	if service == null or chapter.is_empty():
		return []
	service.complete_chapter(chapter)
	return _flush("story_chapter:%s" % chapter)


func note_story_complete(difficulty: String) -> Array:
	if service == null or difficulty.is_empty():
		return []
	service.complete_story_difficulty(difficulty.to_lower())
	return _flush("story_complete:%s" % difficulty.to_lower())


# ---------------------------------------------------------------------- modes

func note_mode_clear(mode: String, difficulty: String) -> Array:
	if service == null or mode.is_empty() or difficulty.is_empty():
		return []
	service.record_mode_clear(mode, difficulty.to_lower())
	return _flush("mode_clear:%s/%s" % [mode, difficulty.to_lower()])


func note_survival_round(rounds_survived: int) -> Array:
	if service == null:
		return []
	service.record_survival_round(maxi(0, rounds_survived))
	return _flush("survival:%d" % rounds_survived)


func note_versus_win() -> Array:
	if service == null:
		return []
	service.record_versus_win()
	return _flush("versus_win")


# --------------------------------------------------------------- combat feats

func note_combat_hit(action: String, defender_state: String,
		attacker_is_player: bool, attack_sequence: int) -> Array:
	## Count player combat feats that have a recovered signal:
	##   * grab   -> GRAB_ATTACKS landing (action name grab1/grab2/..._brick)
	##   * endmove-> the end-attack finisher ("final attack") landing
	## Great/Perfect are handled by note_grade() because their recovered rule is
	## computed at round-result time, not per hit. attack_sequence de-duplicates
	## multi-impact moves that emit more than one combat_hit per swing.
	if service == null or not attacker_is_player:
		return []
	var act: String = action.to_lower()
	if act.begins_with("grab") and not act.contains("_miss"):
		if attack_sequence == _last_grab_seq:
			return []
		_last_grab_seq = attack_sequence
		service.add_counter("number_of_grabs")
		return _flush("grab:%s" % action)
	if act.begins_with("endattack"):
		if attack_sequence == _last_endmove_seq:
			return []
		_last_endmove_seq = attack_sequence
		service.add_counter("number_of_endmoves")
		return _flush("endmove:%s" % action)
	return []


func note_grade(grade: String) -> Array:
	## GREAT / PERFECT are the recovered player round-win grades
	## (CBeatEmUpGame::SetState(7): winner health < 0x14 -> GREAT,
	## winner health == 100 -> PERFECT). Counted once per graded round win.
	if service == null:
		return []
	var g: String = grade.to_lower()
	if g == "great":
		service.add_counter("number_of_greats")
	elif g == "perfect":
		service.add_counter("number_of_perfects")
	else:
		return []
	return _flush("grade:%s" % g)


# ------------------------------------------------------- persistence / introspect

func flush() -> bool:
	if service == null:
		return false
	if native_store != null and not native_store.save_from(service):
		native_ok = false
		native_error = native_store.error
		push_error("NATIVE_PROGRESS_SAVE_FAILED: " + native_error)
		return false
	return service.save(save_path)


func state() -> Dictionary:
	return service.state if service != null else {}


func summary() -> Dictionary:
	if service == null:
		return {"active": false}
	var s: Dictionary = service.state
	return {
		"active": active,
		"exp": int(s["story"]["exp"]),
		"unlocked_ids": service.unlocked_ids(),
		"achievements": (s["achievements"]["reached"] as Array).duplicate(),
		"counters": (s["counters"] as Dictionary).duplicate(true),
		"mode_clears": (s["mode_clears"] as Dictionary).duplicate(true),
		"chapters_completed": (s["story"]["chapters_completed"] as Array).duplicate(),
		"completed_difficulties": (s["story"]["completed_difficulties"] as Array).duplicate(),
		"events_completed": (s["story"]["events_completed"] as Array).size(),
		"native_path": native_path,
		"native_ok": native_ok,
		"native_error": native_error,
	}


func debug_state() -> Dictionary:
	return summary()

extends SceneTree
## Windowed screenshot capture of the opt-in Records / Achievements screen.
##
##   godot --path godot --script res://tests/capture_progress_records.gd -- <shots dir>
##
## Drives the real main menu (synthesized key events through Input.parse_input_event,
## exactly like a player) into the RECORDS row, captures the screen, walks the
## achievement cursor, shows the documented text-only fallback, closes back to the
## menu, then opens a flag-off menu so the missing row is visible in the same run.
##
## The seeded save is written to the project's own user:// save path so the screen
## shows real data; the player's existing file is backed up first and restored at
## the end (also on the failure path). Nothing here is a mock: the numbers come
## from ProgressHooks calls, the icons from ui/achievement/*.png.

const ProgressHooksScript = preload("res://scripts/progress_hooks.gd")
const PrototypeControls = preload("res://scripts/prototype_controls.gd")
const SAVE_PATH := "user://progress_save.json"
const BACKUP_PATH := "user://progress_save.capture_backup.json"

var shots: String = ""
var evidence_save: String = ""
var failures: Array = []
var scene: Node = null
var menu = null
var records = null


func _initialize() -> void:
	call_deferred("_run")


func _shots_dir() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		return String(args[0])
	return "user://progress_records_shots"


func _evidence_path() -> String:
	## Optional second argument: where to copy the seeded save as delivery evidence.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 1:
		return String(args[1])
	return ""


func _copy_evidence() -> void:
	if evidence_save.is_empty() or not FileAccess.file_exists(SAVE_PATH):
		return
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	var file: FileAccess = FileAccess.open(evidence_save, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
		print("EVIDENCE_SAVE " + evidence_save)


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOT_SKIPPED_HEADLESS %s" % name)
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = shots.path_join(name)
	var error: int = image.save_png(path)
	print("SHOT %s %dx%d err=%d" % [name, image.get_width(), image.get_height(), error])
	if error != OK:
		failures.append("capture " + name)


func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event


func _press(keycode: Key) -> void:
	Input.parse_input_event(_key(keycode))
	await process_frame
	await process_frame


func _backup_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var text: String = FileAccess.get_file_as_string(SAVE_PATH)
		var file: FileAccess = FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(text)
			file.close()
		print("BACKUP existing progress save (%d chars)" % text.length())


func _restore_save() -> void:
	if FileAccess.file_exists(BACKUP_PATH):
		var text: String = FileAccess.get_file_as_string(BACKUP_PATH)
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(text)
			file.close()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
		print("RESTORED the original progress save")
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		print("REMOVED the seeded progress save (no original existed)")


func _seed_save() -> void:
	## A plausible mid-story profile so the screen shows a real mix of reached and
	## locked rows. Every number is set through the progress service API.
	var hooks = ProgressHooksScript.new()
	root.add_child(hooks)
	hooks.configure(SAVE_PATH)
	# Counters first: every ProgressHooks mutation re-evaluates achievements, so
	# the event notes below publish a state that already holds these totals.
	hooks.service.set_counter("versus_wins", 6)
	hooks.service.set_counter("number_of_grabs", 18)
	hooks.service.set_counter("number_of_endmoves", 6)
	hooks.service.set_counter("number_of_greats", 6)
	hooks.service.set_counter("number_of_perfects", 3)
	hooks.sync_story_exp(1200)
	hooks.note_story_event("chapter1", "s_master_1")
	hooks.note_story_event("chapter1", "s_master_2")
	hooks.note_story_event("chapter1", "s_master_3")
	hooks.note_story_chapter("chapter1")
	hooks.note_story_chapter("chapter2")
	hooks.note_mode_clear("arcade", "easy")
	hooks.note_mode_clear("time_attack", "medium")
	hooks.note_survival_round(7)
	hooks.flush()
	print("SEEDED save unlocked=%d achievements=%d %s" % [
		hooks.service.unlocked_ids().size(),
		(hooks.service.state["achievements"]["reached"] as Array).size(),
		JSON.stringify(hooks.service.state["achievements"]["reached"])])
	hooks.queue_free()


func _open_scene(progress: bool) -> Node:
	OS.set_environment("BRUCELEE_PROGRESS", "1" if progress else "")
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_MENU_SFX_PATH", "")
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	menu = scene.get("prototype_menu")
	return scene


func _goto_records_row() -> bool:
	var commands: Array = menu.main_commands()
	if not commands.has("records"):
		return false
	var index: int = commands.find("records")
	menu.selected_index = 0
	for _step: int in range(index):
		menu.handle_input_event(_key(KEY_DOWN))
	return menu.selected_command() == "records"


func _run() -> void:
	shots = _shots_dir()
	DirAccess.make_dir_recursive_absolute(shots)
	PrototypeControls.ensure_default_actions()
	evidence_save = _evidence_path()
	_backup_save()
	_seed_save()
	_copy_evidence()

	# ---- flag on: the main menu row
	await _open_scene(true)
	await _capture("01-main-menu-records-row.png")
	var found: bool = _goto_records_row()
	print("RECORDS_ROW_FOUND %s (selected=%s)" % [str(found), menu.selected_command()])
	if not found:
		failures.append("RECORDS row not reachable from the main menu")
	await _capture("02-main-menu-records-selected.png")

	# ---- open the screen through the real command path
	await _press(KEY_ENTER)
	records = scene.get("records_screen")
	if records == null:
		failures.append("records screen did not open")
		print("CAPTURE_FAILURES %d" % failures.size())
		_restore_save()
		quit(1)
		return
	await process_frame
	await _capture("03-records-achievements.png")
	print("RECORDS_STATE paused=%s open=%s rows=%d reached=%d" % [
		str(paused), str(records.is_open()),
		records.debug_state()["rows"].size(),
		records.debug_state()["summary"]["achievement_count"]])

	# ---- walk the cursor onto a reached achievement
	for _step: int in range(14):
		records.handle_input_event(_key(KEY_DOWN))
	await _capture("04-records-cursor-reached.png")
	records.set_cursor(37)
	await _capture("05-records-last-row-versus-50.png")

	# ---- documented text-only fallback (no decoded texture available)
	var saved_table: Array = records._icon_table.duplicate()
	var absent: Array = []
	for index: int in range(76):
		absent.append("bl_gui_achievement_absent_%02d" % index)
	records._icon_table = absent
	records._icon_cache.clear()
	records._icon_missing.clear()
	records._rebuild_grid()
	records._refresh_save()
	records._refresh_selection()
	await process_frame
	await _capture("06-records-text-only-fallback.png")
	print("TEXT_ONLY_MODE " + String(records.icon_status()["mode"]))
	records._icon_table = saved_table
	records._icon_cache.clear()
	records._icon_missing.clear()
	records._rebuild_grid()
	records._refresh_save()
	records._refresh_selection()
	records.set_cursor(0)
	await _capture("07-records-icons-restored.png")

	# ---- close back to the same menu row
	records.handle_input_event(_key(KEY_ESCAPE))
	await process_frame
	await process_frame
	await _capture("08-main-menu-after-records.png")
	print("AFTER_CLOSE records_open=%s menu_state=%s selected=%s" % [
		str(records.is_open()), String(menu.menu_state), menu.selected_command()])

	# ---- fresh profile: no save file yet
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	await _open_scene(true)
	await _press(KEY_DOWN)
	await _press(KEY_DOWN)
	var hint: bool = _goto_records_row()
	if not hint:
		failures.append("RECORDS row not reachable on the fresh profile")
	await _press(KEY_ENTER)
	var fresh = scene.get("records_screen")
	if fresh != null:
		await _capture("09-records-no-save-file.png")
		print("FRESH_SAVE_TEXT " + String(fresh.debug_state()["save"]["text"]))
	root.remove_child(scene)
	scene.queue_free()
	await process_frame

	# ---- flag off: the row does not exist
	await _open_scene(false)
	var flag_off_has: bool = (menu.main_commands() as Array).has("records")
	print("FLAG_OFF_HAS_RECORDS %s" % str(flag_off_has))
	if flag_off_has:
		failures.append("flag-off menu still lists RECORDS")
	await _capture("10-main-menu-no-records-flag-off.png")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame

	_restore_save()
	print("")
	print("CAPTURE_FAILURES %d" % failures.size())
	for failure: Variant in failures:
		print("  FAILED: " + String(failure))
	print("PROGRESS_RECORDS_CAPTURE " + ("OK" if failures.is_empty() else "FAILED"))
	quit(0 if failures.is_empty() else 1)

extends SceneTree
## Headless validation of the recovered Profile sub-pages, About version/
## disclaimer, and the Settings/Training VIDEO-CONTROLS fail-closed proof.
##
## Boots the real main.tscn, drives the art menu with real key events, and per
## gap row asserts the recovered destination state / decoded widgets, the
## explicit NOT RECOVERED page bodies, and that no invented row/input exists.
##
## Modes (last arg): normal | failclosed
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_recovered_pages.gd \
##         --quit-after 12000 -- <player.glb> <opponent.glb> <normal|failclosed>

const MenuArt = preload("res://scripts/menu_art.gd")
const RecoveredPages = preload("res://scripts/recovered_pages.gd")
const MoveTraining = preload("res://scripts/move_training.gd")

const NR := "NOT RECOVERED"
var passed: int = 0
var failed: int = 0
var mode: String = "normal"
var scene: Node = null
var menu: Node = null
var training: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _check(cond: bool, desc: String) -> bool:
	if cond:
		passed += 1
		print("PASS " + desc)
	else:
		failed += 1
		printerr("FAIL " + desc)
	return cond


func _finish() -> void:
	print("RECOVERED_PAGES_VALIDATION=" + JSON.stringify(
		{"mode": mode, "passed": passed, "failed": failed}))
	quit(1 if failed > 0 else 0)


func _any_contains(values: Array, needle: String) -> bool:
	for v: Variant in values:
		if String(v).contains(needle):
			return true
	return false


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Expected <player.glb> <opponent.glb> [normal|failclosed]")
		quit(1)
		return
	mode = args[2] if args.size() > 2 else "normal"
	OS.set_environment("BRUCELEE_MENU_ART", "1")
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
	OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
	for n: String in ["BRUCELEE_STORY_FLOW","BRUCELEE_STORY_LAUNCH","BRUCELEE_GAME_MODE",
		"BRUCELEE_MODE_LAUNCH","BRUCELEE_ATTRACT","BRUCELEE_CONTINUE","BRUCELEE_PROGRESS",
		"BRUCELEE_STYLE_EDITOR","BRUCELEE_SCENE","BRUCELEE_LANG"]:
		OS.set_environment(n, "")
	if mode == "failclosed":
		OS.set_environment("BRUCELEE_RECOVERED_PAGES_PATH",
			"res://data/menu_art/__missing_recovered_pages__.json")
	else:
		OS.set_environment("BRUCELEE_RECOVERED_PAGES_PATH", "")

	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	scene.set_process(false)
	scene.set_physics_process(false)
	var player: Object = scene.get("player")
	var computer: Object = scene.get("computer")
	if player != null: player.set_physics_process(false)
	if computer != null: computer.set_physics_process(false)
	menu = scene.get("prototype_menu")
	if not _check(menu != null and menu is MenuArt, "BRUCELEE_MENU_ART=1 selects PortMenuArt"):
		_finish(); return

	if mode == "failclosed":
		await _check_failclosed()
		_finish(); return

	training = MoveTraining.new()
	training.name = "RecoveredPagesTraining"
	root.add_child(training)
	await process_frame

	_check_artifact()
	await _check_profile()
	await _check_about()
	await _check_settings_failclosed()
	_check_training()
	_finish()


func _open_main_row(index: int) -> void:
	scene.call("_open_main_menu")
	await process_frame
	for _i: int in range(index):
		menu.call("handle_key_event", _key(KEY_DOWN))
		await process_frame
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame


func _confirm() -> void:
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame


func _back() -> void:
	menu.call("handle_key_event", _key(KEY_ESCAPE))
	await process_frame


func _check_artifact() -> void:
	_check(bool(menu.call("recovered_pages_available")), "recovered-pages artifact loads")
	_check(RecoveredPages.error() == "", "recovered-pages artifact has no error")
	var rows: Array = RecoveredPages.profile_rows()
	_check(rows.size() == 4, "four recovered profile rows")
	_check(RecoveredPages.about_background_basename() == "bl_gui_styleeditor",
		"about background is the recovered styleeditorbg (BL_GUI_styleeditor)")
	_check(RecoveredPages.about_version_text("LangEnglish") == "Bruce Lee Dragon Warrior 1.15.26",
		"about version number is the recovered 1.15.26")
	_check(RecoveredPages.about_disclaimer("LangEnglish").begins_with("BRUCE LEE"),
		"about disclaimer is the verbatim recovered .lang text")
	var svc: Dictionary = RecoveredPages.settings_video_controls()
	_check(String(svc.get("reachability", "")) == NR,
		"settings VIDEO/CONTROLS user reachability marked NOT RECOVERED")
	_check(String(Dictionary(svc.get("video", {})).get("state", "")) == "settingsvideo",
		"settings video destination = settingsvideo")
	_check(String(Dictionary(svc.get("controls", {})).get("state", "")) == "settingscontrols",
		"settings controls destination = settingscontrols")


func _open_profile_row(index: int) -> void:
	await _open_main_row(1)
	for _i: int in range(index):
		menu.call("handle_key_event", _key(KEY_DOWN))
		await process_frame
	await _confirm()


func _check_profile() -> void:
	var expect := {
		0: ["achievements", "achievements"],
		1: ["statistics", "statsmain"],
		2: ["art", "artpictures"],
		3: ["fighters", "fightersgallery"],
	}
	for index: int in range(4):
		await _open_profile_row(index)
		var pair: Array = expect[index]
		_check(String(menu.call("profile_page_key")) == String(pair[0]),
			"profile row " + String(pair[0]) + " opens its destination")
		var info: Dictionary = menu.call("profile_page_info")
		_check(String(Dictionary(info.get("destination", {})).get("state", "")) == String(pair[1]),
			"profile row " + String(pair[0]) + " destination = " + String(pair[1]))
		var texts: Array = menu.call("label_texts")
		_check(_any_contains(texts, "NOT RECOVERED"),
			"profile row " + String(pair[0]) + " labels its unrecovered content")
		await _back()
		_check(String(menu.get("screen_id")) == "player_profile",
			"BACK from profile destination returns to Player Profile")
	# statistics subrows are the three real decoded statsmenu.ui options
	await _open_profile_row(1)
	var stexts: Array = menu.call("label_texts")
	for needle: String in ["game_modes -> stats1", "battles -> stats2", "moves -> stats3"]:
		_check(_any_contains(stexts, needle.replace("->", "->")),
			"statistics shows recovered subrow " + needle)
	_check(_any_contains(stexts, "STATS PAGE CONTENT NOT RECOVERED"),
		"statistics page body is explicitly NOT RECOVERED")
	await _back()


func _check_about() -> void:
	await _open_main_row(4)
	_check(String(menu.get("screen_id")) == "about", "main menu row 4 opens About")
	var texts: Array = menu.call("label_texts")
	_check(_any_contains(texts, "BRUCE LEE"),
		"About draws the verbatim recovered disclaimer")
	_check(_any_contains(texts, "www.brucelee.com"),
		"About disclaimer includes the recovered URL")
	_check(not _any_contains(texts, NR),
		"About no longer labels the version as NOT RECOVERED")
	_check(String(menu.call("about_version_display")).contains("1.15.26"),
		"About version hook returns the recovered 1.15.26")
	_check(String(menu.call("about_disclaimer_display")).begins_with("BRUCE LEE"),
		"About disclaimer hook returns the verbatim recovered text")
	_check(not _any_contains(texts, "NOT RECOVERED IN THIS BUILD"),
		"About is no longer wholly unrecovered")
	await _back()


func _check_settings_failclosed() -> void:
	await _open_main_row(2)
	_check(String(menu.get("screen_id")) == "settings", "main menu row 2 opens Settings")
	var labels: Array = menu.call("option_labels")
	_check(labels == ["Audio", "Languages"],
		"settings.ui keeps exactly its two decoded rows: " + str(labels))
	_check(not _any_contains(labels, "Video") and not _any_contains(labels, "Controls"),
		"no invented VIDEO/CONTROLS row is added")
	# The audio destination is out of this task's scope and stays fail-closed.
	await _confirm()
	_check(String(menu.get("status_text")).contains(NR),
		"Audio row stays fail-closed (not in this task)")
	await _back()


func _check_training() -> void:
	# The in-game (training) settings still records its two VIDEO/CONTROLS rows as
	# NOT RECOVERED.  Read the generated artifact directly (a standalone
	# PortMoveTraining instance does not run the game's data-load ready path).
	var raw: String = FileAccess.get_file_as_string("res://data/training_settings.json")
	var parsed: Variant = JSON.parse_string(raw)
	var rows: Array = []
	if typeof(parsed) == TYPE_DICTIONARY:
		rows = Array(Dictionary(Dictionary(parsed).get("flow", {})).get(
			"not_recovered_rows", []))
	_check(rows.size() == 2, "training_settings.json records two NOT RECOVERED rows")
	var by_action: Dictionary = {}
	for row: Variant in rows:
		by_action[String(Dictionary(row).get("action", ""))] = row
	for action: String in ["video", "controls"]:
		var entry: Dictionary = by_action.get(action, {})
		_check(String(entry.get("destination", "")) == "ingamesettings" + action,
			"training " + action + " destination = ingamesettings" + action)
		_check(String(entry.get("status", "")) == NR,
			"training " + action + " row stays NOT RECOVERED")
	if training != null:
		_check(training.has_method("training_video_controls_destinations"),
			"PortMoveTraining exposes the recovered VIDEO/CONTROLS destination hook")


func _check_failclosed() -> void:
	_check(not RecoveredPages.available(), "missing recovered-pages artifact fails closed")
	_check(RecoveredPages.error().contains("missing artifact"), "fail-closed cause is reported")
	_check(RecoveredPages.profile_rows().is_empty(), "profile rows empty when fail closed")
	_check(RecoveredPages.about_disclaimer("LangEnglish") == NR,
		"About disclaimer falls back to NOT RECOVERED")
	_check(RecoveredPages.about_version_text("LangEnglish") == NR,
		"About version falls back to NOT RECOVERED")
	await _open_profile_row(0)
	_check(String(menu.get("screen_id")) == "player_profile",
		"profile row opens no destination when fail closed")
	_check(String(menu.get("status_text")).contains(NR),
		"profile row shows explicit NOT RECOVERED status")
	await _open_main_row(4)
	var texts: Array = menu.call("label_texts")
	_check(_any_contains(texts, "NOT RECOVERED IN THIS BUILD"),
		"About keeps the old whole-area fail-closed marker")

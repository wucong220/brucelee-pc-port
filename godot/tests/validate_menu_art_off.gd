extends SceneTree
## Regression: with BRUCELEE_MENU_ART unset the existing text menu is unchanged,
## and with BRUCELEE_PROGRESS=1 / BRUCELEE_STYLE_EDITOR=1 its opt-in RECORDS and
## STYLE EDITOR rows still open their screens.
##
##   godot --headless --path <project> --script res://tests/validate_menu_art_off.gd \
##         --quit-after 1800 -- <player.glb> <opponent.glb>

const MenuArt = preload("res://scripts/menu_art.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _check(condition: bool, description: String) -> bool:
	if condition:
		passed += 1
		print("PASS " + description)
	else:
		failed += 1
		printerr("FAIL " + description)
	return condition


func _clear_flags() -> void:
	for name: String in [
		"BRUCELEE_MENU_ART", "BRUCELEE_STORY_FLOW", "BRUCELEE_STORY_LAUNCH",
		"BRUCELEE_GAME_MODE", "BRUCELEE_MODE_LAUNCH", "BRUCELEE_PROGRESS",
		"BRUCELEE_STYLE_EDITOR", "BRUCELEE_ATTRACT", "BRUCELEE_CONTINUE",
	]:
		OS.set_environment(name, "")


func _boot(player_glb: String, opponent_glb: String) -> Node:
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_PLAYER_GLB", player_glb)
	OS.set_environment("BRUCELEE_OPPONENT_GLB", opponent_glb)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.get("player").set_physics_process(false)
	scene.get("computer").set_physics_process(false)
	return scene


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Expected <player.glb> <opponent.glb>")
		quit(1)
		return

	# --- A: BRUCELEE_MENU_ART unset ---------------------------------------
	_clear_flags()
	var scene: Node = await _boot(args[0], args[1])
	var menu: Node = scene.get("prototype_menu")
	_check(menu != null, "text path: menu exists")
	_check(not (menu is MenuArt), "text path: BRUCELEE_MENU_ART unset keeps PortPrototypeMenu")
	_check(String(menu.get("menu_state")) == "main", "text path: starts on the text main menu")
	_check(bool(scene.get("main_menu_active")), "text path: main menu active")
	_check(menu.call("selected_command") == "fight", "text path: still starts on VS FIGHT")
	_check(not menu.call("main_commands").has("records")
			and not menu.call("main_commands").has("style_editor"),
		"text path: no opt-in rows while their flags are off")
	menu.call("handle_key_event", _key(KEY_DOWN))
	await process_frame
	_check(menu.call("selected_command") == "arcade",
		"text path: DOWN still reaches ARCADE")
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	await process_frame
	var modes: Node = scene.get("game_modes")
	var state: Dictionary = modes.call("debug_state")
	_check(String(state["screen"]) == "settings" and String(state["mode"]) == "arcade",
		"text path: ARCADE still opens the mode settings")
	modes.call("hide_all")
	scene.queue_free()
	await process_frame

	# --- B: opt-in rows on the text menu -----------------------------------
	_clear_flags()
	OS.set_environment("BRUCELEE_PROGRESS", "1")
	OS.set_environment("BRUCELEE_STYLE_EDITOR", "1")
	scene = await _boot(args[0], args[1])
	menu = scene.get("prototype_menu")
	var commands: Array = menu.call("main_commands")
	_check(commands.has("records"), "text path: RECORDS row exists while BRUCELEE_PROGRESS=1")
	_check(commands.has("style_editor"),
		"text path: STYLE EDITOR row exists while BRUCELEE_STYLE_EDITOR=1")
	_check(commands[-1] == "quit", "text path: QUIT stays last")
	scene.call("_open_main_menu")
	await process_frame
	scene.call("_on_menu_command", "records")
	await process_frame
	var records: Node = scene.get("records_screen")
	_check(records != null and bool(records.call("is_open")),
		"text path: RECORDS still opens the records screen")
	if records != null and bool(records.call("is_open")):
		records.call("close")
		await process_frame
	scene.call("_on_menu_command", "style_editor")
	await process_frame
	var editor: Node = scene.get("style_editor")
	_check(editor != null and bool(editor.call("is_open")),
		"text path: STYLE EDITOR still opens the editor screen")

	print("MENU_ART_OFF_VALIDATION=" + JSON.stringify({"passed": passed, "failed": failed}))
	if failed == 0:
		quit(0)
	else:
		printerr("menu-art off validation failed: %d check(s)" % failed)
		quit(1)

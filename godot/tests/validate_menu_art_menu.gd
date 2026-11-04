extends SceneTree
## Headless validation of the opt-in original-art front menu
## (BRUCELEE_MENU_ART=1).
##
## It boots the real main.tscn, drives the art menu with real key events, and
## asserts that:
##   * the recovered mainmenu.ui / playmenu.ui widgets keep their decoded rects;
##   * the recovered rows are labelled with MenuLang / documented placeholders;
##   * the four main-menu rows with no port screen fail closed with the
##     "NOT RECOVERED IN THIS BUILD" status and never emit a command;
##   * Play opens the recovered play menu;
##   * every play row emits the existing start command and the mode really
##     starts (Arcade / Time Attack / Survival settings, VS Fight, Training,
##     Story Mode through BRUCELEE_STORY_FLOW).
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_menu_art_menu.gd \
##         --quit-after 1200 -- <player.glb> <opponent.glb>
##
## Both GLB arguments are required for the training check (the port fails
## closed without candidate animations).

const MenuArt = preload("res://scripts/menu_art.gd")

var passed: int = 0
var failed: int = 0
var commands: Array = []
var scene: Node = null
var menu: Node = null


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


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Expected <player.glb> <opponent.glb>")
		quit(1)
		return
	OS.set_environment("BRUCELEE_MENU_ART", "1")
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
	OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
	for name: String in [
		"BRUCELEE_STORY_FLOW", "BRUCELEE_STORY_LAUNCH", "BRUCELEE_GAME_MODE",
		"BRUCELEE_MODE_LAUNCH", "BRUCELEE_ATTRACT", "BRUCELEE_CONTINUE",
		"BRUCELEE_PROGRESS", "BRUCELEE_STYLE_EDITOR", "BRUCELEE_SCENE",
	]:
		OS.set_environment(name, "")

	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	scene.set_process(false)
	scene.set_physics_process(false)
	var player: Object = scene.get("player")
	var computer: Object = scene.get("computer")
	player.set_physics_process(false)
	computer.set_physics_process(false)

	menu = scene.get("prototype_menu")
	_check(menu != null, "main scene created a menu")
	_check(menu is MenuArt, "BRUCELEE_MENU_ART=1 selects PortMenuArt")
	if not (menu is MenuArt):
		_finish()
		return
	_check(bool(menu.get("art_ready")), "art resources loaded and decoded")
	_check(bool(scene.get("main_menu_active")), "main menu is active")
	_check(bool(menu.get("visible")), "menu layer is visible")
	_check(String(menu.get("screen_id")) == "mainmenu", "starts on recovered mainmenu")
	menu.command_requested.connect(_on_command)

	_check_mainmenu()
	await _check_playmenu()
	await _check_unrecovered_rows()
	await _check_play_rows()
	await _check_story()
	_finish()


func _on_command(command: String) -> void:
	commands.append(command)


func _last_command() -> String:
	return String(commands[-1]) if not commands.is_empty() else ""


func _rect(rects: Dictionary, name: String) -> Rect2:
	if not rects.has(name):
		return Rect2(-999, -999, -999, -999)
	return rects[name] as Rect2


func _check_mainmenu() -> void:
	var rects: Dictionary = menu.call("built_rects")
	_check(_rect(rects, "logo").is_equal_approx(Rect2(25, 180, 256, 128)),
		"mainmenu/logo keeps the decoded rect")
	_check(_rect(rects, "title").is_equal_approx(Rect2(0, 5, 200, 40)),
		"mainmenu/title keeps the decoded rect")
	_check(_rect(rects, "menu").is_equal_approx(Rect2(130, 50, 350, 220)),
		"mainmenu/menu keeps the decoded rect")
	var labels: Array = menu.call("option_labels")
	_check(labels == ["Play", "Player Profile", "Settings", "Credits", "About", "Quit"],
		"mainmenu rows are the six recovered options: " + str(labels))


func _open_playmenu() -> bool:
	var opened: bool = (String(menu.get("screen_id")) == "playmenu")
	if not opened:
		scene.call("_open_main_menu")
		await process_frame
		menu.call("handle_key_event", _key(KEY_ENTER))
		await process_frame
		opened = (String(menu.get("screen_id")) == "playmenu")
	_check(opened, "Play opens the recovered playmenu")
	return opened


func _check_playmenu() -> void:
	await _open_playmenu()
	var rects: Dictionary = menu.call("built_rects")
	_check(_rect(rects, "title").is_equal_approx(Rect2(0, 5, 200, 40)),
		"playmenu/title keeps the decoded rect")
	_check(_rect(rects, "playmenu").is_equal_approx(Rect2(80, 50, 400, 250)),
		"playmenu/playmenu keeps the decoded rect")
	_check(_rect(rects, "lsk").is_equal_approx(Rect2(2, 270, 48, 48)),
		"playmenu/lsk back button keeps the decoded rect")
	var labels: Array = menu.call("option_labels")
	_check(labels == ["Story Mode", "Arcade", "Time Attack", "Versus", "Survival", "Practice Style"],
		"playmenu rows are the six recovered options: " + str(labels))
	# BACK returns to the recovered main menu.
	menu.call("handle_key_event", _key(KEY_ESCAPE))
	await process_frame
	_check(String(menu.get("screen_id")) == "mainmenu", "BACK from playmenu returns to mainmenu")


func _check_unrecovered_rows() -> void:
	for index: int in [1, 2, 3, 4]:
		scene.call("_open_main_menu")
		await process_frame
		for _step: int in range(index):
			menu.call("handle_key_event", _key(KEY_DOWN))
			await process_frame
		if int(menu.get("selection")) != index:
			_check(false, "mainmenu selection reached row %d" % index)
			continue
		var before: int = commands.size()
		menu.call("handle_key_event", _key(KEY_ENTER))
		await process_frame
		var status: String = String(menu.get("status_text"))
		_check(commands.size() == before,
			"mainmenu row %d emits no start command" % index)
		_check(status.contains("NOT RECOVERED"),
			"mainmenu row %d fails closed with a NOT RECOVERED status" % index)
		_check(String(menu.get("screen_id")) == "mainmenu",
			"mainmenu row %d stays on the recovered screen" % index)


func _select_play_row(index: int) -> void:
	menu.call("handle_key_event", _key(KEY_ENTER))  # Play
	await process_frame
	for _step: int in range(index):
		menu.call("handle_key_event", _key(KEY_DOWN))
		await process_frame


func _check_play_rows() -> void:
	# Arcade
	scene.call("_open_main_menu")
	await process_frame
	await _select_play_row(1)
	var before: int = commands.size()
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	await process_frame
	_check(_last_command() == "arcade" and commands.size() == before + 1,
		"Arcade emits the existing arcade command")
	var modes: Node = scene.get("game_modes")
	var state: Dictionary = modes.call("debug_state")
	_check(String(state["screen"]) == "settings" and String(state["mode"]) == "arcade",
		"Arcade really opens the recovered Arcade settings screen: " + str(state["screen"]))
	modes.call("hide_all")
	await process_frame

	# Time Attack
	scene.call("_open_main_menu")
	await process_frame
	await _select_play_row(2)
	before = commands.size()
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	await process_frame
	_check(_last_command() == "timeattack" and commands.size() == before + 1,
		"Time Attack emits the existing timeattack command")
	state = modes.call("debug_state")
	_check(String(state["screen"]) == "settings" and String(state["mode"]) == "timeattack",
		"Time Attack really opens Time Attack settings")
	modes.call("hide_all")
	await process_frame

	# Versus
	scene.call("_open_main_menu")
	await process_frame
	await _select_play_row(3)
	before = commands.size()
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	await process_frame
	_check(_last_command() == "fight" and commands.size() == before + 1,
		"Versus emits the existing fight command")
	_check(not bool(scene.get("main_menu_active")), "Versus leaves the main menu")
	_check(not bool(scene.get("training_mode")), "Versus does not enter training")
	_check(not bool(menu.get("visible")), "Versus hides the art menu")

	# Survival
	scene.call("_open_main_menu")
	await process_frame
	await _select_play_row(4)
	before = commands.size()
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	await process_frame
	_check(_last_command() == "survival" and commands.size() == before + 1,
		"Survival emits the existing survival command")
	state = modes.call("debug_state")
	_check(String(state["screen"]) == "settings" and String(state["mode"]) == "survival",
		"Survival really opens Survival settings")
	modes.call("hide_all")
	await process_frame

	# Training
	scene.call("_open_main_menu")
	await process_frame
	await _select_play_row(5)
	before = commands.size()
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	await process_frame
	await process_frame
	_check(_last_command() == "training" and commands.size() == before + 1,
		"Practice Style emits the existing training command")
	_check(bool(scene.get("training_mode")), "Practice Style really enters training")


func _check_story() -> void:
	scene.call("_open_main_menu")
	await process_frame
	await _select_play_row(0)
	var before: int = commands.size()
	var old_scene_id: int = scene.get_instance_id()
	menu.call("handle_key_event", _key(KEY_ENTER))
	# Story launches by setting the existing BRUCELEE_STORY_FLOW environment and
	# reloading main.tscn, exactly like the scene/opponent switches.
	_check(OS.get_environment("BRUCELEE_STORY_FLOW") == "1",
		"Story Mode sets the existing BRUCELEE_STORY_FLOW launch")
	_check(OS.get_environment("BRUCELEE_MAIN_MENU") == "0",
		"Story Mode leaves the main menu")
	_check(commands.size() == before, "Story Mode emits no invented command")
	for _frame: int in range(90):
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_scene_id:
			break
	_check(current_scene != null and current_scene.get_instance_id() != old_scene_id,
		"Story Mode reloads main.tscn")
	for _frame: int in range(30):
		await process_frame
	var story: Node = current_scene.get("story_flow") if current_scene != null else null
	_check(story != null, "Story flow was created by the existing launch path")
	if story != null:
		_check(String(story.get("screen")) == "mode",
			"Story flow landed on its mode screen: " + String(story.get("screen")))


func _finish() -> void:
	var summary: Dictionary = {
		"passed": passed,
		"failed": failed,
		"commands": commands,
	}
	print("MENU_ART_MENU_VALIDATION=" + JSON.stringify(summary))
	if failed == 0:
		quit(0)
	else:
		printerr("menu-art validation failed: %d check(s)" % failed)
		quit(1)

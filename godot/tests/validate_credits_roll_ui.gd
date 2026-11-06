extends SceneTree
## Headless validation of the real Credits-page wiring:
##   * creditsdle / creditsindiagames build the verbatim scrolling roll
##   * the roll uses the recovered -height start, 33 ms and +2/+1 rule
##   * line height is measured from the runtime font, never the 72-byte stride
##   * reaching total content height raises END and returns to creditsselect
##   * missing credit text fails closed with the explicit marker
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_credits_roll_ui.gd \
##         -- <player.glb> <opponent.glb> <normal|failclosed>

var passed: int = 0
var failed: int = 0
var mode: String = "normal"
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


func _any_contains(values: Array, needle: String) -> bool:
	for value: Variant in values:
		if String(value).contains(needle):
			return true
	return false


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("Expected <player.glb> <opponent.glb> <normal|failclosed>")
		quit(1)
		return
	mode = String(args[2])
	OS.set_environment("BRUCELEE_MENU_ART", "1")
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
	OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
	OS.set_environment("BRUCELEE_CREDITS_TEXT_PATH",
		"res://data/menu_art/does_not_exist.json" if mode == "failclosed" else "")
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
	if player != null:
		player.set_physics_process(false)
	if computer != null:
		computer.set_physics_process(false)
	menu = scene.get("prototype_menu")

	if mode == "failclosed":
		await _check_failclosed()
	else:
		await _check_normal()
	_finish()


func _open_credits_dle() -> void:
	scene.call("_open_main_menu")
	await process_frame
	for _step: int in range(3):  # Credits is main row 3
		menu.call("handle_key_event", _key(KEY_DOWN))
		await process_frame
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame


func _check_normal() -> void:
	await _open_credits_dle()
	_check(String(menu.get("screen_id")) == "credits_dle",
		"creditsdle opens from the real Credits page")
	menu.call("credits_roll_set_process", false)
	menu.call("credits_roll_reset_timing")
	_check(bool(menu.call("credits_roll_active")), "the real scrolling roll is built")
	_check(int(menu.call("credits_roll_line_count")) == 125,
		"DLE roll is the full 1..125 sequence")
	var line_height: int = int(menu.call("credits_roll_line_height"))
	_check(line_height > 0, "runtime font measured a positive line height")
	_check(line_height != 72, "line height is not the 72-byte TLine struct stride")
	_check(line_height == int(ceil(ThemeDB.fallback_font.get_height(16))),
		"line height equals the runtime fallback font height")
	_check(int(menu.call("credits_roll_view_height")) == 320,
		"roll viewport is the decoded 320 px height")
	_check(int(menu.call("credits_roll_offset")) == -320,
		"roll starts at the recovered -height offset")
	_check(String(menu.call("credits_roll_clean_line", 0)).contains("DIGITAL LEGENDS"),
		"first DLE line is verbatim text without the control code")
	_check(int(menu.call("credits_roll_advance_ms", 1000)) == 0,
		"first 33 ms call only seeds the clock")
	_check(int(menu.call("credits_roll_advance_ms", 1033)) == 1,
		"33 ms later one tick fires")
	_check(int(menu.call("credits_roll_offset")) == -318,
		"first tick advances by the recovered +2")

	# Drive the whole roll to its END condition (Σ line height), then the native
	# END action returns to the creditsselect page.
	menu.call("credits_roll_tick_steps", 4000)
	await process_frame
	await process_frame
	_check(String(menu.get("screen_id")) == "credits",
		"END returns to the creditsselect page")

	# IndiaGames roll on the same real page.
	menu.call("handle_key_event", _key(KEY_RIGHT))
	await process_frame
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	_check(String(menu.get("screen_id")) == "credits_ig",
		"creditsindiagames opens from the real Credits page")
	menu.call("credits_roll_set_process", false)
	menu.call("credits_roll_reset_timing")
	_check(bool(menu.call("credits_roll_active")), "the IG scrolling roll is built")
	_check(int(menu.call("credits_roll_line_count")) == 38,
		"IG roll is the full 1..38 sequence")
	_check(String(menu.call("credits_roll_clean_line", 0)).contains("Indiagames"),
		"first IG line is verbatim text")
	_check(int(menu.call("credits_roll_offset")) == -320,
		"IG roll also starts at -320")


func _check_failclosed() -> void:
	await _open_credits_dle()
	_check(String(menu.get("screen_id")) == "credits_dle",
		"creditsdle still opens when text evidence is missing")
	_check(not bool(menu.call("credits_roll_active")),
		"missing credit text leaves the roll fail-closed")
	var texts: Array = menu.call("label_texts")
	_check(_any_contains(texts, "NOT RECOVERED"),
		"fail-closed page shows the explicit NOT RECOVERED marker")
	_check(String(menu.call("credits_roll_status")).contains("missing credits text artifact"),
		"fail-closed status names the missing text artifact")


func _finish() -> void:
	print("CREDITS_ROLL_UI_VALIDATION=" + JSON.stringify(
		{"mode": mode, "passed": passed, "failed": failed}))
	quit(1 if failed > 0 else 0)

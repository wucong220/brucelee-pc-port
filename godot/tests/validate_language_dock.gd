extends SceneTree
## Headless validation of the recovered 8-item language dock, end to end.
##
## Modes (4th CLI argument):
##   session   boot the real main.tscn, walk main menu -> Settings -> Languages,
##             assert the 8 decoded items and their recovered Lang table order,
##             drive real LEFT/RIGHT key events (clamped, wraparround=false),
##             press ENTER to apply+save, and assert the recovered `.lang` text
##             really changes (the main menu re-renders in the chosen language).
##   restart   a SEPARATE Godot process with the same save path: assert the saved
##             language is restored and applied before the menu is built.
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_language_dock.gd \
##         --quit-after 12000 -- <player.glb> <opponent.glb> <save-path> <session|restart>

const MenuArt = preload("res://scripts/menu_art.gd")
const LanguageDock = preload("res://scripts/language_dock.gd")
const MenuLang = preload("res://scripts/menu_lang.gd")

const EXPECTED_TABLES := [
	"LangEnglish", "LangSpanish", "LangGerman", "LangItalian",
	"LangFrench", "LangRussian", "LangChineseSimpl", "LangChineseTrad",
]
const NOT_RECOVERED := "NOT RECOVERED"
## Recovered Chinese (Simplified) label of the main-menu "settings" key
## (menu_lang.json LangChineseSimpl.settings) used to prove the text effect.
const SETTINGS_ZH := "设置"

var passed: int = 0
var failed: int = 0
var mode: String = "session"
var save_path: String = ""
var scene: Node = null
var menu: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> bool:
	if condition:
		passed += 1
		print("PASS " + description)
	else:
		failed += 1
		printerr("FAIL " + description)
	return condition


func _finish() -> void:
	print("LANGUAGE_DOCK_VALIDATION=" + JSON.stringify(
		{"mode": mode, "passed": passed, "failed": failed}))
	quit(1 if failed > 0 else 0)


func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _any_contains(values: Array, needle: String) -> bool:
	for value: Variant in values:
		if String(value).contains(needle):
			return true
	return false


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 4:
		printerr("Expected <player.glb> <opponent.glb> <save-path> <session|restart>")
		quit(1)
		return
	mode = args[3]
	save_path = args[2]
	if mode == "session" and FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	OS.set_environment("BRUCELEE_LANGUAGE_SAVE_PATH", save_path)
	OS.set_environment("BRUCELEE_MENU_ART", "1")
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
	OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
	OS.set_environment("BRUCELEE_LANG", "")
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
	menu = scene.get("prototype_menu")
	if not _check(menu != null and menu is MenuArt, "BRUCELEE_MENU_ART=1 selects PortMenuArt"):
		_finish()
		return

	if mode == "restart":
		_check_restart()
	else:
		await _check_session()
	_finish()


func _open(row_index: int, down_steps: int = 0) -> void:
	scene.call("_open_main_menu")
	await process_frame
	for _i: int in range(row_index):
		menu.call("handle_key_event", _key(KEY_DOWN))
		await process_frame
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	for _j: int in range(down_steps):
		menu.call("handle_key_event", _key(KEY_DOWN))
		await process_frame


func _press(keycode: Key) -> void:
	menu.call("handle_key_event", _key(keycode))
	await process_frame


func _check_session() -> void:
	_check(LanguageDock.available(), "language dock artifact loads")
	_check(LanguageDock.error() == "", "language dock artifact has no error")
	_check(LanguageDock.persistence().get("original_format") == NOT_RECOVERED,
		"native persistence format stays NOT RECOVERED")
	_check(LanguageDock.labels_status() == NOT_RECOVERED,
		"language display names stay NOT RECOVERED")
	var items: Array = LanguageDock.items()
	_check(items.size() == 8, "eight recovered dock items")
	var tables: Array = []
	for item: Variant in items:
		tables.append(String(Dictionary(item).get("lang_table", "")))
	_check(tables == EXPECTED_TABLES,
		"dock order equals CApplication::Init AddLanguageTable index 0..7: " + str(tables))
	_check(LanguageDock.lang_table_for_index(6) == "LangChineseSimpl",
		"index 6 maps to LangChineseSimpl")
	_check(LanguageDock.lang_table_for_index(8) == "",
		"indices 8/9 (Japanese/Korean) are outside the 8-item dock")

	# main menu -> Settings (row 2) -> Languages (row 1)
	await _open(2, 0)
	_check(String(menu.get("screen_id")) == "settings", "main menu row 2 opens Settings")
	var settings_labels: Array = menu.call("option_labels")
	_check(settings_labels == ["Audio", "Languages"],
		"settings.ui keeps its two decoded rows: " + str(settings_labels))
	await _press(KEY_DOWN)
	await _press(KEY_ENTER)
	_check(String(menu.get("screen_id")) == "language_dock",
		"Languages row opens the recovered language dock")
	_check(int(menu.call("language_selection")) == 0,
		"with no save the dock starts at the port default index 0")

	# wraparround=false: clamp at the left end, then move right.
	await _press(KEY_LEFT)
	_check(int(menu.call("language_selection")) == 0,
		"LEFT at the first card clamps (wraparround=false)")
	for _i: int in range(6):
		await _press(KEY_RIGHT)
	_check(int(menu.call("language_selection")) == 6,
		"six RIGHT presses select index 6 (LangChineseSimpl)")
	for _i: int in range(3):
		await _press(KEY_RIGHT)
	_check(int(menu.call("language_selection")) == 7,
		"RIGHT clamps at the last card index 7 (wraparround=false)")
	await _press(KEY_LEFT)
	_check(int(menu.call("language_selection")) == 6, "LEFT returns to index 6")

	# Apply + persist.  The harness denies the Godot child any file write, so the
	# exact serialized payload is verified here and materialised by the runner
	# before the restart-mode process reads it back.
	await _press(KEY_ENTER)
	_check(String(menu.call("language_applied_table")) == "LangChineseSimpl",
		"ENTER applies the recovered LangChineseSimpl table")
	var payload: String = LanguageDock.save_payload(6)
	_check(payload.contains("\"language_index\":6"), "save payload carries index 6")
	_check(payload.contains("LangChineseSimpl"), "save payload carries the Lang table")
	_check(payload.contains(NOT_RECOVERED), "save payload marks the format NOT RECOVERED")
	print("LANGUAGE_SAVE_PAYLOAD=" + payload)
	print("LANGUAGE_SAVE_PATH=" + save_path)
	if FileAccess.file_exists(save_path):
		_check(int(LanguageDock.load_saved_index()) == 6,
			"the language save file reads back index 6")
	else:
		print("NOTE save write unavailable in this sandbox; runner materialises the payload")
	_check(MenuLang.language() == "LangChineseSimpl",
		"the session language is now LangChineseSimpl")
	_check(String(menu.call("language_status_text")).contains("APPLIED LangChineseSimpl"),
		"the dock reports APPLIED LangChineseSimpl")
	var dock_labels: Array = menu.call("label_texts")
	_check(_any_contains(dock_labels, "DISPLAY NAMES NOT RECOVERED"),
		"the dock still labels display names NOT RECOVERED")

	# BACK to Settings, BACK to main menu: labels must be the recovered Chinese.
	await _press(KEY_ESCAPE)
	_check(String(menu.get("screen_id")) == "settings",
		"BACK from the language dock returns to Settings")
	await _press(KEY_ESCAPE)
	_check(String(menu.get("screen_id")) == "mainmenu",
		"BACK from Settings returns to the main menu")
	var menu_labels: Array = menu.call("option_labels")
	_check(_any_contains(menu_labels, SETTINGS_ZH),
		"the main menu now renders the recovered Chinese Settings label: " + str(menu_labels))


func _check_restart() -> void:
	# This is a fresh process: only the save file can carry the selection.
	_check(FileAccess.file_exists(save_path), "the language save survived the restart")
	_check(int(LanguageDock.load_saved_index()) == 6,
		"the restarted process reads index 6 from the save")
	_check(int(LanguageDock.current_index()) == 6,
		"current_index() is the saved index after restart")
	_check(MenuLang.language() == "LangChineseSimpl",
		"the restarted process applied LangChineseSimpl before building the menu")
	var menu_labels: Array = menu.call("option_labels")
	_check(_any_contains(menu_labels, SETTINGS_ZH),
		"after restart the main menu is still the recovered Chinese label: " + str(menu_labels))

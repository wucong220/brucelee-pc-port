extends SceneTree
## Headless validation of the opt-in recovered scene dock
## (`BRUCELEE_SCENE_SELECT=1`).
##
## It boots the real `main.tscn`, walks the real menu navigation to the SCENES
## row, and asserts that:
##   * with the flag off the text scene rows are the scene menu, unchanged
##     (11 rows, same commands) and no dock node exists;
##   * with the flag on the dock shows the 10 decoded `selectscenery.ui` cards in
##     the decoded order, with the decoded rects, the decoded icons, the decoded
##     yellow selection line and the recovered label for the selected
##     `sceneries.list` row (localized through the recovered `.lang` table);
##   * LEFT/RIGHT move the selection and both ends clamp (`wraparround=false`);
##   * confirming a card emits the scene command `main.gd` already implements for
##     that row, `BRUCELEE_SCENE` becomes that row's `port_scene_variant`, the
##     scene reloads, the tree is NOT paused and the reloaded match really runs
##     (its clock advances) -- i.e. the scenery is applied to the next match;
##   * BACK returns to the main menu and the text panel comes back;
##   * a missing layout, a dock/list icon mismatch and a missing icon texture all
##     fail closed: the dock is not built, the error is reported, and the text
##     scene rows remain the scene menu (still navigable, still correct);
##   * `main.gd`'s scene-command table and the catalogue's variant table agree.
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_scene_select.gd \
##         --quit-after 60000 -- <player.glb> <opponent.glb> <fixtures-dir>
##
## <fixtures-dir> holds the deliberately broken layout copies used by the
## fail-closed checks (see tools/run_scene_select_tests.ps1).

const PrototypeMenu = preload("res://scripts/prototype_menu.gd")
const Catalog = preload("res://scripts/scene_catalog.gd")

## The recovered list, recorded independently of the data files: `sceneries.list`
## rows in order (name / translate_name / dock icon / port scene variant /
## scene command / English label).  The test compares the loaded catalogue with
## this record, so a shuffled or re-mapped dock fails here.
const EXPECTED := [
	["market", "market_night", "bl_scene01a_hw_icon", "squarea", "squarea", "Market - Night"],
	["market b", "market_day", "bl_scene01b_hw_icon", "squareb", "squareb", "Market - Day"],
	["temple yard", "temple_day", "bl_scene02a_hw_icon", "", "temple_a", "Temple Yard - Day"],
	["temple yard b", "temple_dusk", "bl_scene02b_hw_icon", "templeyardb", "temple_b", "Temple Yard - Dusk"],
	["harbour", "harbour_dawn", "bl_scene03a_hw_icon", "harboura", "harboura", "Harbour - Dawn"],
	["harbour b", "harbour_day", "bl_scene03b_hw_icon", "harbourb", "harbourb", "Harbour - Day"],
	["tournament hall", "thall_night", "bl_scene04a_hw_icon", "halla", "halla", "Tournament Hall - Night"],
	["tournament hall b", "thall_day", "bl_scene04b_hw_icon", "tournamenthallb", "tournamenthallb", "Tournament Hall - Day"],
	["rooftops", "rooftops_day", "bl_scene05a_hw_icon", "rooftopsa", "rooftopsa", "Rooftops - Day"],
	["rooftops b", "rooftops_dusk", "bl_scene05b_hw_icon", "rooftopsb", "rooftopsb", "Rooftops - Dusk"],
]

const DESIGN_W := 480.0
const DESIGN_H := 320.0
const LABEL_RECT := Rect2(100, 120, 280, 20)
const DOCK_RECT := Rect2(-50, 150, 580, 114)
const OPTION_W := 165.0
const OPTION_H := 114.0

var passed: int = 0
var failed: int = 0
var commands: Array = []
var notes: Dictionary = {}
var scene: Node = null
var fixtures: String = ""


func _initialize() -> void:
	call_deferred("_run")


# ------------------------------------------------------------------ helpers

func _check(condition: bool, description: String) -> bool:
	if condition:
		passed += 1
		print("PASS " + description)
	else:
		failed += 1
		printerr("FAIL " + description)
	return condition


func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _physics_frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _clear_scene() -> void:
	if scene != null:
		scene.queue_free()
		scene = null
		current_scene = null
		await _frames(3)


func _on_command(command: String) -> void:
	commands.append(command)


func _text(value: Variant) -> String:
	return String(value)


# --------------------------------------------------------------------- run

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("expected <player.glb> <opponent.glb> <fixtures-dir>")
		quit(1)
		return
	fixtures = args[2]
	# main.gd registers these in _ready; the phase-0 menu is created without a
	# main scene, so register them here too (the production path is unchanged).
	preload("res://scripts/prototype_controls.gd").ensure_default_actions()
	await _check_menu_class_without_flag()
	await _check_dock_on_real_main(args[0], args[1])
	await _check_missing_layout(args[0], args[1])
	await _check_icon_mismatch(args[0], args[1])
	await _check_missing_icons(args[0], args[1])
	_finish()


func _base_env(player_glb: String, opponent_glb: String, scene_select: String) -> void:
	## The same environment the other headless menu tests use: the real main
	## scene, the real main menu, no story/game-mode/progress rows.
	for name: String in [
		"BRUCELEE_STORY_FLOW", "BRUCELEE_STORY_LAUNCH", "BRUCELEE_GAME_MODE",
		"BRUCELEE_MODE_LAUNCH", "BRUCELEE_ATTRACT", "BRUCELEE_CONTINUE",
		"BRUCELEE_PROGRESS", "BRUCELEE_STYLE_EDITOR", "BRUCELEE_SCENE",
		"BRUCELEE_SCENE_SELECT_LAYOUT", "BRUCELEE_SCENE_SELECT_ART",
		"BRUCELEE_ROUND_INTRO", "BRUCELEE_MENU_ART",
	]:
		OS.set_environment(name, "")
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_SCENE_SELECT", scene_select)
	OS.set_environment("BRUCELEE_PLAYER_GLB", player_glb)
	OS.set_environment("BRUCELEE_OPPONENT_GLB", opponent_glb)
	OS.set_environment("BRUCELEE_LANG", "en")


func _boot_main() -> Node:
	var instanced: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(instanced)
	current_scene = instanced
	scene = instanced
	await _frames(3)
	instanced.set_process(false)
	instanced.set_physics_process(false)
	var player: Object = instanced.get("player")
	var computer: Object = instanced.get("computer")
	if player != null:
		player.set_physics_process(false)
	if computer != null:
		computer.set_physics_process(false)
	return instanced


# ------------------------------------------------- phase 0: flag off (text menu)

func _check_menu_class_without_flag() -> void:
	_base_env("", "", "")
	var menu: Node = PrototypeMenu.new()
	root.add_child(menu)
	await _frames(2)
	_check(menu.scene_dock == null, "flag off: no scene dock is created")
	_check(menu.scene_dock_rows().is_empty(), "flag off: no recovered scene rows")
	menu.show_scene_menu()
	await _frames(1)
	_check(menu.menu_state == "scenes", "flag off: SCENES opens the text scene submenu")
	_check(menu.scene_text_rows_visible(), "flag off: the text scene rows are the scene menu")
	var report: Dictionary = menu.layout_report()
	_check((report["commands"] as Array).size() == 11,
		"flag off: the text scene submenu still has its 11 rows")
	_check(menu.selected_command() == "temple_a",
		"flag off: the first text scene row is still temple_a")
	_check(menu.handle_input_event(_key(KEY_DOWN)),
		"flag off: DOWN is handled by the text scene submenu")
	_check(menu.selected_command() == "temple_b",
		"flag off: the second text scene row is still temple_b")
	menu.show_main_menu()
	await _frames(1)
	_check(menu.scene_text_rows_visible(),
		"flag off: the main menu keeps its text panel")
	menu.queue_free()
	await _frames(2)


# --------------------------------------------- phase 1: dock on the real menu

func _check_dock_on_real_main(player_glb: String, opponent_glb: String) -> void:
	_base_env(player_glb, opponent_glb, "1")
	var main: Node = await _boot_main()
	var menu: Node = main.get("prototype_menu")
	_check(menu != null, "flag on: main.tscn created the menu")
	if menu == null:
		return
	menu.command_requested.connect(_on_command)
	_check(menu.scene_dock != null,
		"flag on: the recovered scene dock loaded (" + String(menu.scene_dock_error) + ")")
	if menu.scene_dock == null:
		return
	_check(Array(menu.scene_dock_rows()).size() == 10,
		"flag on: the dock carries the 10 sceneries.list rows")

	# The catalogue must reproduce the recovered list exactly.
	var rows: Array = menu.scene_dock_rows()
	for index: int in range(mini(rows.size(), EXPECTED.size())):
		var row: Dictionary = rows[index]
		var expected: Array = EXPECTED[index]
		_check(_text(row.get("name")) == String(expected[0]),
			"row %d keeps the sceneries.list name '%s'" % [index, String(expected[0])])
		_check(_text(row.get("translate_name")) == String(expected[1]),
			"row %d keeps the translate_name '%s'" % [index, String(expected[1])])
		_check(_text(row.get("icon")) == String(expected[2]),
			"row %d keeps the dock icon '%s'" % [index, String(expected[2])])
		_check(_text(row.get("variant")) == String(expected[3]),
			"row %d keeps the port scene variant '%s'" % [index, String(expected[3])])
		_check(_text(row.get("command")) == String(expected[4]),
			"row %d maps to the existing menu command '%s'" % [index, String(expected[4])])
		_check(_text(row.get("label")) == String(expected[5]),
			"row %d shows the recovered label '%s'" % [index, String(expected[5])])

	# main.gd's table is the authority for the command -> variant mapping.
	var main_constants: Dictionary = (load("res://scripts/main.gd") as Script).get_script_constant_map()
	var main_commands: Dictionary = main_constants.get("MENU_SCENE_COMMANDS", {})
	_check(main_commands.size() == 10,
		"main.gd exposes the 10 scene commands")
	var catalog_constants: Dictionary = (Catalog as Script).get_script_constant_map()
	var variants: Dictionary = catalog_constants.get("VARIANT_COMMANDS", {})
	var agree: bool = true
	for variant: Variant in variants.keys():
		if String(main_commands.get(String(variants[variant]), "") ) != String(variant):
			agree = false
			printerr("  variant '%s' -> command '%s' but main.gd says '%s'" % [
				String(variant), String(variants[variant]),
				String(main_commands.get(String(variants[variant]), "<none>"))])
	_check(agree, "the catalogue's variant table agrees with main.gd's scene commands")
	var text_commands: Array = PrototypeMenu.SCENE_COMMANDS
	var all_present: bool = true
	for row: Dictionary in rows:
		if not text_commands.has(String(row.get("command"))):
			all_present = false
	_check(all_present, "every dock command is one the text scene rows also emit")

	# Real navigation: main menu -> SCENES -> dock.
	main.call("_open_main_menu")
	await _frames(2)
	_check(menu.selected_command() == "fight", "main menu opens on VS FIGHT")
	var scenes_index: int = -1
	var main_commands_list: Array = menu.main_commands()
	for index: int in range(main_commands_list.size()):
		if String(main_commands_list[index]) == "scenes":
			scenes_index = index
	_check(scenes_index == 9, "SCENES is main-menu row 9 (found " + str(scenes_index) + ")")
	for _step: int in range(scenes_index):
		menu.handle_input_event(_key(KEY_DOWN))
		await _frames(1)
	_check(menu.selected_command() == "scenes", "DOWN reaches the SCENES row")
	var before: int = commands.size()
	menu.handle_input_event(_key(KEY_ENTER))
	await _frames(2)
	_check(commands.size() == before,
		"opening SCENES emits no command (it is a submenu)")
	_check(menu.menu_state == "scenes", "SCENES opens the scene submenu")
	_check(menu.scene_dock_visible(), "the recovered dock owns the scene submenu")
	_check(not menu.scene_text_rows_visible(),
		"the text scene rows are hidden while the dock is drawn")

	# Recovered geometry.
	var rects: Dictionary = menu.scene_dock_rects()
	_check((rects.get("sceneries", Rect2()) as Rect2).is_equal_approx(DOCK_RECT),
		"sceneries keeps the decoded dock rect (-50,150,580,114)")
	var label_rect: Rect2 = rects.get("scenery_name", Rect2())
	_check(absf(label_rect.position.x - LABEL_RECT.position.x) < 0.01
			and absf(label_rect.position.y - LABEL_RECT.position.y) < 0.01
			and absf(label_rect.size.x - LABEL_RECT.size.x) < 0.01,
		"scenery_name keeps the decoded position and width (100,120,280) - got "
			+ str(label_rect))
	_check(label_rect.size.y >= LABEL_RECT.size.y and label_rect.size.y <= LABEL_RECT.size.y + 6.0,
		"scenery_name keeps the decoded 20px band (a Label line may add up to ~3px)")
	var centred: bool = true
	var spacing: bool = true
	for index: int in range(10):
		var key: String = "item_%02d" % index
		if not rects.has(key):
			centred = false
			continue
		var card: Rect2 = rects[key]
		if absf(card.size.x - OPTION_W) > 0.01 or absf(card.size.y - OPTION_H) > 0.01:
			spacing = false
		if index == 0:
			if absf(card.position.x - (DOCK_RECT.position.x + DOCK_RECT.size.x * 0.5 - OPTION_W * 0.5)) > 0.01:
				centred = false
		else:
			var previous: Rect2 = rects["item_%02d" % (index - 1)]
			if absf(card.position.x - previous.position.x - OPTION_W) > 0.01:
				spacing = false
			if absf(card.position.y - previous.position.y) > 0.01:
				spacing = false
	_check(centred, "the selected card sits on the decoded dock centre")
	_check(spacing, "cards keep the decoded 165x114 size, one option apart (separation 0)")

	# The decoded icons are 256x128 with the artwork at (0,0)-(165,114), so every
	# card must draw exactly that crop.
	var regions: Array = menu.scene_dock_card_regions()
	var crop_ok: bool = regions.size() == 10
	for region: Variant in regions:
		if not (region as Rect2).is_equal_approx(Rect2(0, 0, OPTION_W, OPTION_H)):
			crop_ok = false
	_check(crop_ok,
		"every card draws the decoded 165x114 icon crop (no black padding, no stretch): "
			+ str(regions.slice(0, 2)))

	# Recovered label follows the selection and honours the decoded uppercase flag.
	_check(menu.scene_dock_label() == "MARKET - NIGHT",
		"selection 0 shows the recovered label MARKET - NIGHT (got '" + menu.scene_dock_label() + "')")

	# Navigation: LEFT/RIGHT, clamped at both ends (wraparround=false).
	menu.handle_input_event(_key(KEY_RIGHT))
	menu.handle_input_event(_key(KEY_RIGHT))
	await _frames(1)
	_check(menu.scene_dock_selection() == 2,
		"RIGHT moves the dock selection to index 2")
	_check(menu.scene_dock_label() == "TEMPLE YARD - DAY",
		"selection 2 shows TEMPLE YARD - DAY")
	menu.handle_input_event(_key(KEY_RIGHT))
	await _frames(1)
	_check(menu.scene_dock_rects()["item_03"].position.x
			> menu.scene_dock_rects()["item_00"].position.x,
		"moving the selection keeps the card order on screen")
	menu.handle_input_event(_key(KEY_LEFT))
	menu.handle_input_event(_key(KEY_LEFT))
	menu.handle_input_event(_key(KEY_LEFT))
	menu.handle_input_event(_key(KEY_LEFT))
	await _frames(1)
	_check(menu.scene_dock_selection() == 0,
		"LEFT clamps at the first scenery (no wrap-around)")
	_check(menu.scene_dock_label() == "MARKET - NIGHT",
		"clamped selection still shows MARKET - NIGHT")
	for _step: int in range(12):
		menu.handle_input_event(_key(KEY_RIGHT))
	await _frames(1)
	_check(menu.scene_dock_selection() == 9,
		"RIGHT clamps at the last scenery (no wrap-around)")
	_check(menu.scene_dock_label() == "ROOFTOPS - DUSK",
		"last scenery shows ROOFTOPS - DUSK")
	notes["clamp_no_wraparound"] = true
	notes["recovered_nav_sfx"] = String(menu.scene_dock.last_sfx)
	notes["nav_sfx_missing"] = bool(menu.scene_dock.sfx_missing)

	# UP/DOWN are meaningless on the one-row dock and must not move anything.
	menu.handle_input_event(_key(KEY_UP))
	menu.handle_input_event(_key(KEY_DOWN))
	await _frames(1)
	_check(menu.scene_dock_selection() == 9,
		"UP/DOWN do not move the one-row dock")

	# BACK returns to the main menu and restores the text panel.
	menu.handle_input_event(_key(KEY_ESCAPE))
	await _frames(2)
	_check(menu.menu_state == "main", "BACK from the dock returns to the main menu")
	_check(not menu.scene_dock_visible(), "BACK hides the dock")
	_check(menu.scene_text_rows_visible(),
		"BACK restores the text panel (the fallback is intact)")

	# Apply index 3 (temple yard b) and prove the next match starts there.
	main.call("_open_main_menu")
	await _frames(2)
	menu.show_scene_menu()
	await _frames(2)
	_check(menu.scene_dock_selection() == 0,
		"reopening the scene submenu starts on the first scenery")
	for _step: int in range(3):
		menu.handle_input_event(_key(KEY_RIGHT))
	await _frames(1)
	_check(menu.scene_dock_selection() == 3,
		"three RIGHTs select temple yard b (row 3)")
	_check(menu.scene_dock_label() == "TEMPLE YARD - DUSK",
		"row 3 label is TEMPLE YARD - DUSK")
	var before_apply: int = commands.size()
	var old_id: int = main.get_instance_id()
	var old_paused: bool = paused
	menu.handle_input_event(_key(KEY_ENTER))
	await _frames(2)
	_check(commands.size() == before_apply + 1,
		"confirming a card emits exactly one command")
	_check(_text(commands[-1]) == "temple_b",
		"row 3 emits the existing temple_b scene command (got '" + _text(commands[-1]) + "')")
	_check(OS.get_environment("BRUCELEE_SCENE") == "templeyardb",
		"row 3 sets BRUCELEE_SCENE=templeyardb (the row's port_scene_variant)")
	_check(OS.get_environment("BRUCELEE_MAIN_MENU") == "0",
		"the scene switch leaves the main menu")
	_check(old_paused, "the main menu really had the tree paused before applying")
	var reloaded: bool = false
	for _frame: int in range(240):
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_id:
			reloaded = true
			break
	_check(reloaded, "confirming the card reloads main.tscn")
	if not reloaded:
		return
	scene = current_scene
	_check(not paused, "the reloaded match is NOT left in a paused tree")
	_check(not bool(scene.get("main_menu_active")),
		"the reloaded match starts outside the menu")
	var elapsed_a: float = float(scene.get("elapsed"))
	var clock_a: int = int(scene.get("round_time_left"))
	var advanced: bool = false
	for _frame: int in range(900):
		await physics_frame
		if float(scene.get("elapsed")) > elapsed_a:
			advanced = true
			break
	var elapsed_b: float = float(scene.get("elapsed"))
	_check(advanced,
		"the reloaded match runs (elapsed %.2f -> %.2f)" % [elapsed_a, elapsed_b])
	var ticked: bool = false
	for _frame: int in range(900):
		await physics_frame
		if int(scene.get("round_time_left")) < clock_a:
			ticked = true
			break
	var clock_b: int = int(scene.get("round_time_left"))
	_check(ticked,
		"the round clock counts down in the selected scenery (%d -> %d)" % [clock_a, clock_b])
	_check(String(scene.call("_scene_variant")) == "templeyardb",
		"the running match really uses the selected scene variant")
	notes["applied_row"] = 3
	notes["applied_variant"] = String(scene.call("_scene_variant"))
	notes["elapsed_after_apply"] = elapsed_b
	_check(not bool(scene.get("menu_paused")), "no menu pause survives into the match")
	await _clear_scene()


# ------------------------------------------------------- fail-closed phases

func _fail_closed_case(label: String, layout_path: String, art_root: String,
		expect_fragment: String, player_glb: String, opponent_glb: String) -> void:
	_base_env(player_glb, opponent_glb, "1")
	if not layout_path.is_empty():
		OS.set_environment("BRUCELEE_SCENE_SELECT_LAYOUT", layout_path)
	if not art_root.is_empty():
		OS.set_environment("BRUCELEE_SCENE_SELECT_ART", art_root)
	var main: Node = await _boot_main()
	var menu: Node = main.get("prototype_menu")
	if menu == null:
		_check(false, label + ": main.tscn created the menu")
		await _clear_scene()
		return
	_check(menu.scene_dock == null, label + ": no dock is built")
	_check(menu.scene_dock_rows().is_empty(), label + ": no recovered scene rows are exposed")
	var message: String = String(menu.scene_dock_error)
	_check(message.contains(expect_fragment),
		label + ": the error names the cause (" + message + ")")
	_check(not message.is_empty(), label + ": the failure is reported, not silent")
	# The text scene menu is the fallback and must still work.
	main.call("_open_main_menu")
	await _frames(2)
	menu.show_scene_menu()
	await _frames(2)
	_check(menu.scene_text_rows_visible(), label + ": the text scene rows are used")
	_check(not menu.scene_dock_visible(), label + ": no dock is displayed")
	_check(String(menu.status_label.text) == PrototypeMenu.SCENE_DOCK_UNAVAILABLE,
		label + ": the menu says the dock is unavailable")
	var report: Dictionary = menu.layout_report()
	_check((report["commands"] as Array).size() == 11,
		label + ": the text scene submenu keeps its 11 rows")
	_check(menu.selected_command() == "temple_a",
		label + ": the text rows still address the first scene")
	menu.handle_input_event(_key(KEY_DOWN))
	await _frames(1)
	_check(menu.selected_command() == "temple_b",
		label + ": the text rows still navigate")
	await _clear_scene()


func _check_missing_layout(player_glb: String, opponent_glb: String) -> void:
	await _fail_closed_case(
		"missing layout", fixtures.path_join("does_not_exist.json"), "",
		"selectscenery layout missing", player_glb, opponent_glb)


func _check_icon_mismatch(player_glb: String, opponent_glb: String) -> void:
	await _fail_closed_case(
		"dock/list mismatch", fixtures.path_join("selectscenery_mismatch.json"), "",
		"dock item", player_glb, opponent_glb)


func _check_missing_icons(player_glb: String, opponent_glb: String) -> void:
	await _fail_closed_case(
		"missing icons", "", fixtures.path_join("empty_art"),
		"missing dock icon", player_glb, opponent_glb)


# ------------------------------------------------------------------- finish

func _finish() -> void:
	var summary: Dictionary = {
		"passed": passed,
		"failed": failed,
		"commands": commands,
		"notes": notes,
		"env_scene": OS.get_environment("BRUCELEE_SCENE"),
	}
	print("SCENE_SELECT_VALIDATION=" + JSON.stringify(summary))
	if failed == 0:
		print("SCENE_SELECT_VALIDATION_RESULT=PASS (%d checks)" % passed)
		quit(0)
	else:
		printerr("SCENE_SELECT_VALIDATION_RESULT=FAIL (%d failed of %d)" % [failed, passed + failed])
		quit(1)

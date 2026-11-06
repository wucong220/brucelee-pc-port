extends SceneTree
## Targeted validator: the Chief B / Lo Ming B roster rows.
##
## Native evidence (recorded in the report, not inferred here):
##   * godot/data/menu_art/ui/selectopponent.json : bldock items[8] =
##     bl_thechief01_icon, items[9] = bl_thechief02_icon, items[13] =
##     bl_loming01_icon, items[14] = bl_loming02_icon; datasource
##     validselectedoption = gamemodes.selectedopponent.
##   * profile-bodies/evidence/decoded/characters.list.json : fifteen rows,
##     chief a(id 8) / chief b(id 9) and lo ming a(id 13) / lo ming b(id 14).
##   * credits-about/evidence/ghidra/00168180_CBeatEmUpGameModes_QueryString.c
##     cases 5/6: validselectedoption calls
##     CCharacterList::IsAvailable(selected_index) -- the lock check is per dock
##     card, not per menu command.
##
## Therefore, when BRUCELEE_OPPONENT_SKIN selects chief02_body / loming02_body,
## the dock highlight and the unlock check must use card 9 / 14 and character
## "chief b" / "lo ming b", exactly the character whose model is loaded.
##
## This script fails on the unpatched tree and passes after
## patch/roster_variant_unify.patch.  No unlock table is changed and no menu
## entry is invented.
##
## Run:
##   BRUCELEE_PACKAGE_ROOT=<staged package> <godot> --headless --path <project> \
##     --script res://tests/validate_roster_variant_mapping.gd \
##     -- <fixtures-dir> <report-json>

const PrototypeMenu = preload("res://scripts/prototype_menu.gd")
const Gate = preload("res://scripts/character_unlock_gate.gd")
const Overlay = preload("res://scripts/hud_art_overlay.gd")

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

var _failures: Array[String] = []
var _checks: int = 0
var _fixtures := ""
var _report_path := ""
var _package_root := ""
var _record: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	_failures.append(message)
	push_error("ROSTER_VARIANT_MAPPING: " + message)
	return false


func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame


func _clear_env() -> void:
	for name: String in [
		"BRUCELEE_OPPONENT_GLB", "BRUCELEE_OPPONENT_TEXTURE_ROOT",
		"BRUCELEE_OPPONENT_CLIP_PREFIX", "BRUCELEE_OPPONENT_MASTER",
		"BRUCELEE_OPPONENT_MATERIAL_PROFILE", "BRUCELEE_OPPONENT_ATTACK_CONFIG",
		"BRUCELEE_OPPONENT_SKELETON", "BRUCELEE_OPPONENT_SKIN",
		"BRUCELEE_OPPONENT_NAME_KEY", "BRUCELEE_PLAYER_GLB", "BRUCELEE_PLAYER_SKIN",
		"BRUCELEE_HUD_ART", "BRUCELEE_MENU_ART", "BRUCELEE_PROGRESS",
		"BRUCELEE_STORY_FLOW", "BRUCELEE_GAME_MODE", "BRUCELEE_SCENE_SELECT",
		"BRUCELEE_SCENE_UNLOCK", "BRUCELEE_ROUND_INTRO", "BRUCELEE_ALLOW_PACKAGE_MODELS",
	]:
		OS.set_environment(name, "")
	OS.set_environment("BRUCELEE_PACKAGE_ROOT", _package_root)
	OS.set_environment("BRUCELEE_LANG", "en")
	OS.set_environment("BRUCELEE_ROUND_INTRO", "0")


func _new_menu(save: String, skin: String) -> Node:
	_clear_env()
	OS.set_environment("BRUCELEE_CHARACTER_UNLOCK_SAVE", save)
	OS.set_environment("BRUCELEE_CHARACTER_UNLOCK", "")
	OS.set_environment("BRUCELEE_OPPONENT_SKIN", skin)
	var menu: Node = PrototypeMenu.new()
	root.add_child(menu)
	await _frames(2)
	return menu


func _free_node(node: Node) -> void:
	node.queue_free()
	await _frames(2)


func _dock_highlight(overlay: Node) -> int:
	var frame: Node = overlay.get("_frame")
	if frame == null:
		return -1
	for child: Node in frame.get_children():
		if not (child is Control) or child is Label:
			continue
		var control: Control = child as Control
		if not control.clip_contents or not is_equal_approx(control.size.x, 320.0):
			continue
		var sprites: Array = control.get_children()
		if sprites.size() != 15:
			return -1
		for index: int in sprites.size():
			if is_equal_approx((sprites[index] as Control).position.x, 110.0):
				return index
	return -1


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		_check(false, "expected <fixtures-dir> <report-json>")
		return _finish()
	_fixtures = args[0]
	_report_path = args[1]
	_package_root = OS.get_environment("BRUCELEE_PACKAGE_ROOT").strip_edges()
	if _package_root.is_empty():
		_check(false, "BRUCELEE_PACKAGE_ROOT must be set")
		return _finish()

	# ---- 1. Native row/card mapping (identity, not a policy guess).
	var full = Gate.new()
	_clear_env()
	OS.set_environment("BRUCELEE_CHARACTER_UNLOCK_SAVE",
			_fixtures.path_join("save_full.json"))
	full.refresh()
	_check(bool(full.dock_ok), "decoded opponent dock validates: " + String(full.dock_error))
	_check(full.dock_items.size() == 15, "decoded opponent dock has fifteen cards")
	_check(String(full.dock_items[8]) == "bl_thechief01_icon",
			"card 8 is bl_thechief01_icon (chief a)")
	_check(String(full.dock_items[9]) == "bl_thechief02_icon",
			"card 9 is bl_thechief02_icon (chief b)")
	_check(String(full.dock_items[13]) == "bl_loming01_icon",
			"card 13 is bl_loming01_icon (lo ming a)")
	_check(String(full.dock_items[14]) == "bl_loming02_icon",
			"card 14 is bl_loming02_icon (lo ming b)")
	_check(String(full.state_for_dock(8).get("name", "")) == "chief a",
			"card 8 resolves to characters.list chief a")
	_check(String(full.state_for_dock(9).get("name", "")) == "chief b",
			"card 9 resolves to characters.list chief b")
	_check(String(full.state_for_dock(13).get("name", "")) == "lo ming a",
			"card 13 resolves to characters.list lo ming a")
	_check(String(full.state_for_dock(14).get("name", "")) == "lo ming b",
			"card 14 resolves to characters.list lo ming b")
	_check(int(full.state_for_dock(8).get("unlock_id", -2)) == 8,
			"chief a keeps unlock id 8")
	_check(int(full.state_for_dock(9).get("unlock_id", -2)) == 9,
			"chief b keeps unlock id 9")
	_check(int(full.state_for_dock(13).get("unlock_id", -2)) == 13,
			"lo ming a keeps unlock id 13")
	_check(int(full.state_for_dock(14).get("unlock_id", -2)) == 14,
			"lo ming b keeps unlock id 14")

	# ---- 2. Lock check must follow the SELECTED variant's card.
	# A save that grants only chief a (id 8): chief02_body (chief b) is locked.
	var menu_a: Node = await _new_menu(
			_fixtures.path_join("save_chief_a_only.json"), "chief02_body")
	_record["chief_a_only_skin_chief02_locked"] = bool(
			menu_a.fighter_command_locked("chief"))
	_check(bool(menu_a.fighter_command_locked("chief")),
			"chief02_body with only chief a (id 8) granted must be refused")
	await _free_node(menu_a)
	# A save that grants only chief b (id 9): chief02_body (chief b) is open.
	var menu_b: Node = await _new_menu(
			_fixtures.path_join("save_chief_b_only.json"), "chief02_body")
	_record["chief_b_only_skin_chief02_locked"] = bool(
			menu_b.fighter_command_locked("chief"))
	_check(not bool(menu_b.fighter_command_locked("chief")),
			"chief02_body with chief b (id 9) granted must be selectable")
	await _free_node(menu_b)
	# Default chief (chief a) keeps its own grant.
	var menu_default: Node = await _new_menu(
			_fixtures.path_join("save_chief_b_only.json"), "")
	_check(bool(menu_default.fighter_command_locked("chief")),
			"default chief (chief a) stays refused when only chief b is granted")
	await _free_node(menu_default)
	# Same for Lo Ming.
	var menu_la: Node = await _new_menu(
			_fixtures.path_join("save_loming_a_only.json"), "loming02_body")
	_record["loming_a_only_skin_loming02_locked"] = bool(
			menu_la.fighter_command_locked("loming"))
	_check(bool(menu_la.fighter_command_locked("loming")),
			"loming02_body with only lo ming a (id 13) granted must be refused")
	await _free_node(menu_la)
	var menu_lb: Node = await _new_menu(
			_fixtures.path_join("save_loming_b_only.json"), "loming02_body")
	_record["loming_b_only_skin_loming02_locked"] = bool(
			menu_lb.fighter_command_locked("loming"))
	_check(not bool(menu_lb.fighter_command_locked("loming")),
			"loming02_body with lo ming b (id 14) granted must be selectable")
	await _free_node(menu_lb)

	# ---- 3. The dock highlight must be the variant's own card.
	_clear_env()
	OS.set_environment("BRUCELEE_CHARACTER_UNLOCK_SAVE",
			_fixtures.path_join("save_full.json"))
	OS.set_environment("BRUCELEE_CHARACTER_UNLOCK", "")
	OS.set_environment("BRUCELEE_HUD_ART", "1")
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_OPPONENT_SKIN", "chief02_body")
	var scene: Node = load(MAIN_SCENE_PATH).instantiate()
	scene.scene_file_path = MAIN_SCENE_PATH
	root.add_child(scene)
	current_scene = scene
	await _frames(4)
	var menu: Node = scene.get("prototype_menu")
	var overlay: Node = scene.get("hud_art_menu_overlay")
	if not _check(menu != null and overlay != null,
			"main.tscn did not create the menu + dock overlay"):
		return _finish()
	menu.show_opponent_menu()
	await _frames(2)
	# Move to the chief row through the real input handler.
	var opponent_commands: Array = load("res://scripts/prototype_menu.gd") \
			.get_script_constant_map().get("OPPONENT_COMMANDS", [])
	var chief_index: int = opponent_commands.find("chief")
	for _i: int in chief_index:
		menu.handle_input_event(_key(KEY_DOWN))
	await _frames(3)
	_check(menu.selected_command() == "chief",
			"real DOWN reaches the chief row")
	var highlight: int = _dock_highlight(overlay)
	_record["chief02_dock_highlight"] = highlight
	_check(highlight == 9,
			"chief02_body highlights card 9 (got %d)" % highlight)
	current_scene = null
	scene.free()
	await _frames(2)

	_clear_env()
	OS.set_environment("BRUCELEE_CHARACTER_UNLOCK_SAVE",
			_fixtures.path_join("save_full.json"))
	OS.set_environment("BRUCELEE_CHARACTER_UNLOCK", "")
	OS.set_environment("BRUCELEE_HUD_ART", "1")
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_OPPONENT_SKIN", "loming02_body")
	scene = load(MAIN_SCENE_PATH).instantiate()
	scene.scene_file_path = MAIN_SCENE_PATH
	root.add_child(scene)
	current_scene = scene
	await _frames(4)
	menu = scene.get("prototype_menu")
	overlay = scene.get("hud_art_menu_overlay")
	if _check(menu != null and overlay != null,
			"main.tscn (loming) did not create the menu + dock overlay"):
		menu.show_opponent_menu()
		await _frames(2)
		var loming_index: int = opponent_commands.find("loming")
		for _i: int in loming_index:
			menu.handle_input_event(_key(KEY_DOWN))
		await _frames(3)
		_check(menu.selected_command() == "loming",
				"real DOWN reaches the loming row")
		var loming_highlight: int = _dock_highlight(overlay)
		_record["loming02_dock_highlight"] = loming_highlight
		_check(loming_highlight == 14,
				"loming02_body highlights card 14 (got %d)" % loming_highlight)
	current_scene = null
	scene.free()
	await _frames(2)

	# ---- 4. The actual model selection for the variant (unchanged, reference).
	_clear_env()
	OS.set_environment("BRUCELEE_OPPONENT_SKIN", "chief02_body")
	var resolver: Node = load(MAIN_SCENE_PATH).instantiate()
	var configs: Dictionary = resolver.get_script().get_script_constant_map() \
			.get("MENU_OPPONENT_CONFIG", {})
	var merged: Dictionary = resolver.call("_selected_opponent_config",
			Dictionary(configs["chief"]))
	var resolved: Dictionary = resolver.call("_resolved_opponent_glb", merged)
	_record["chief02_selected_glb"] = String(resolved["glb"])
	_check(String(resolved["glb"]).ends_with("chief02_body.glb"),
			"chief02_body actually selects chief02_body.glb")
	_record["model_vs_highlight_matched"] = (
			String(resolved["glb"]).ends_with("chief02_body.glb")
			and int(_record.get("chief02_dock_highlight", -1)) == 9)
	_check(bool(_record["model_vs_highlight_matched"]),
			"selected model and dock highlight name the same character")
	resolver.free()
	return _finish()


func _finish() -> void:
	var report: Dictionary = {
		"validator": "roster_variant_mapping",
		"package_root": _package_root,
		"checks": _checks,
		"failures": _failures,
		"record": _record,
	}
	if not _report_path.is_empty():
		var file: FileAccess = FileAccess.open(_report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	print("ROSTER_VARIANT_MAPPING=" + JSON.stringify(report))
	if _failures.is_empty():
		print("ROSTER_VARIANT_MAPPING_OK")
		quit(0)
	else:
		print("ROSTER_VARIANT_MAPPING_FAILED=" + str(_failures.size()))
		quit(1)

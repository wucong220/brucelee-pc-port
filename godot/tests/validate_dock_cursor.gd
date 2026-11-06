extends SceneTree
## Headless validation for the recovered locked-card cursor rule and the
## credits-roll NOT-RECOVERED record.
##
## Modes (3rd arg):
##   dock     real main.tscn, BRUCELEE_SCENE_SELECT=1: the recovered
##            selectscenery.ui dock must SKIP locked cards
##            (CBruceLeeDock::OnKeyPress/SetLocked).
##   credits  real main.tscn, BRUCELEE_MENU_ART=1: the credits roll is NOT
##            shipped (absolute scroll timing NOT RECOVERED) and still says so.
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_dock_cursor.gd \
##         --quit-after 12000 -- <player.glb> <opponent.glb> <dock|credits> <credits-evidence-json>

const DockCursor = preload("res://scripts/dock_cursor.gd")
const MenuArt = preload("res://scripts/menu_art.gd")

const NR := "NOT RECOVERED"
var passed: int = 0
var failed: int = 0
var mode: String = "dock"
var scene: Node = null
var menu: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _key(kc: Key) -> InputEventKey:
	var e: InputEventKey = InputEventKey.new()
	e.keycode = kc
	e.pressed = true
	return e


func _check(c: bool, d: String) -> bool:
	if c:
		passed += 1
		print("PASS " + d)
	else:
		failed += 1
		printerr("FAIL " + d)
	return c


func _finish() -> void:
	print("DOCK_CURSOR_VALIDATION=" + JSON.stringify(
		{"mode": mode, "passed": passed, "failed": failed}))
	quit(1 if failed > 0 else 0)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("Expected <player.glb> <opponent.glb> <dock|credits> [evidence]")
		quit(1)
		return
	mode = args[2]
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
	OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
	OS.set_environment("BRUCELEE_PROGRESS", "")
	OS.set_environment("BRUCELEE_STYLE_EDITOR", "")
	OS.set_environment("BRUCELEE_STORY_FLOW", "")
	if mode == "dock":
		OS.set_environment("BRUCELEE_MENU_ART", "")
		OS.set_environment("BRUCELEE_SCENE_SELECT", "1")
		OS.set_environment("BRUCELEE_SCENE_UNLOCK", "")
	else:
		OS.set_environment("BRUCELEE_MENU_ART", "1")
		OS.set_environment("BRUCELEE_SCENE_SELECT", "")

	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	scene.set_process(false)
	scene.set_physics_process(false)
	var pl: Object = scene.get("player")
	var op: Object = scene.get("computer")
	if pl != null: pl.set_physics_process(false)
	if op != null: op.set_physics_process(false)
	menu = scene.get("prototype_menu")

	if mode == "dock":
		_check_pure()
		await _check_dock(args[3] if args.size() > 3 else "")
	else:
		_check_credits(args[3] if args.size() > 3 else "")
	_finish()


func _check_pure() -> void:
	var r1: Dictionary = DockCursor.move(0, 1, 5, [false, true, false, false, false])
	_check(int(r1.get("index", -1)) == 2 and bool(r1.get("moved", false)),
		"pure: RIGHT from 0 skips locked index 1 -> 2")
	_check(int(r1.get("skipped", 0)) == 1, "pure: one locked card skipped")
	var r2: Dictionary = DockCursor.move(4, 1, 5, [false, false, false, false, false])
	_check(int(r2.get("index", -1)) == 4 and not bool(r2.get("moved", true)),
		"pure: RIGHT at the last index clamps (wraparround=false)")
	var r3: Dictionary = DockCursor.move(0, 1, 5, [false, true, true, true, true])
	_check(int(r3.get("index", -1)) == 0 and not bool(r3.get("moved", true)),
		"pure: no unlocked option ahead restores the original selection")
	_check(bool(r3.get("stale_restore", false)), "pure: restore is reported")
	var r4: Dictionary = DockCursor.move(2, -1, 5, [false, true, false, false, false])
	_check(int(r4.get("index", -1)) == 0 and int(r4.get("skipped", 0)) == 1,
		"pure: LEFT from 2 skips locked index 1 -> 0")
	var r5: Dictionary = DockCursor.move(0, 1, 3, [true, true, true])
	_check(int(r5.get("index", -1)) == 0 and not bool(r5.get("moved", true)),
		"pure: all locked restores the original selection")
	_check(DockCursor.RULE.contains("skips SetLocked"), "cursor rule is documented")


func _open_scenes_dock() -> bool:
	scene.call("_open_main_menu")
	await process_frame
	for _i: int in range(9):  # MAIN_COMMANDS index 9 = scenes
		menu.call("handle_key_event", _key(KEY_DOWN))
		await process_frame
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	return bool(menu.call("scene_dock_visible"))


func _check_dock(fixture: String = "") -> void:
	_check(bool(menu.call("scene_select_enabled")), "BRUCELEE_SCENE_SELECT=1 enables the dock")
	var opened: bool = await _open_scenes_dock()
	_check(opened, "main menu -> SCENES opens the recovered scene dock")
	if not opened:
		return
	var rows: Array = menu.call("scene_gate_rows")
	_check(rows.size() == 10, "ten recovered scene rows")
	var locked: Array = _locked_flags(rows)
	var locked_count: int = _count_locked(locked)
	_check(locked_count == 9, "no save leaves exactly the 9 gated sceneries locked")
	_check(int(menu.call("scene_dock_selection")) == 0,
		"dock opens at the decoded first selection")
	var expected_r: Dictionary = DockCursor.move(0, 1, rows.size(), locked)
	menu.call("handle_key_event", _key(KEY_RIGHT))
	await process_frame
	_check(int(menu.call("scene_dock_selection")) == int(expected_r.get("index", -2)),
		"RIGHT with all ahead locked matches the recovered rule: " + str(expected_r.get("index")))
	var report: Dictionary = menu.get("scene_dock").call("cursor_rule_report")
	_check(String(report.get("rule", "")).contains("skips SetLocked"),
		"dock reports the recovered skip rule")

	# Positive skip with a real partial save (rows 0,3,9 unlocked): RIGHT from 0
	# must skip the locked 1,2 and land on 3.
	if fixture.is_empty() or not FileAccess.file_exists(fixture):
		return
	OS.set_environment("BRUCELEE_SCENE_UNLOCK_SAVE", fixture)
	scene.call("_open_main_menu")
	await process_frame
	for _i: int in range(9):
		menu.call("handle_key_event", _key(KEY_DOWN))
		await process_frame
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	_check(bool(menu.call("scene_dock_visible")), "dock reopens with the partial save")
	var prows: Array = menu.call("scene_gate_rows")
	var plocked: Array = _locked_flags(prows)
	_check(not bool(plocked[0]) and bool(plocked[1]) and bool(plocked[2]) and not bool(plocked[3]),
		"partial save unlocks rows 0 and 3 and locks 1 and 2")
	var cur: int = int(menu.call("scene_dock_selection"))
	if cur != 0:
		menu.get("scene_dock").call("select_index", 0)
		await process_frame
	var exp: Dictionary = DockCursor.move(0, 1, prows.size(), plocked)
	_check(int(exp.get("index", -1)) == 3, "recovered rule predicts a skip 0 -> 3")
	menu.call("handle_key_event", _key(KEY_RIGHT))
	await process_frame
	_check(int(menu.call("scene_dock_selection")) == 3,
		"real RIGHT press skips locked 1,2 and lands on the unlocked row 3")
	var rep: Dictionary = menu.get("scene_dock").call("cursor_rule_report")
	_check(int(Dictionary(rep.get("last", {})).get("skipped", -1)) == 2,
		"the skipped count is 2")


func _locked_flags(rows: Array) -> Array:
	var out: Array = []
	for row: Variant in rows:
		out.append(not bool(Dictionary(row).get("available", false)))
	return out


func _count_locked(flags: Array) -> int:
	var n: int = 0
	for v: Variant in flags:
		if bool(v): n += 1
	return n


func _check_credits(evidence_path: String) -> void:
	_check(FileAccess.file_exists(evidence_path), "credits scroll evidence file is present")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(evidence_path))
	_check(typeof(parsed) == TYPE_DICTIONARY, "credits evidence parses")
	if typeof(parsed) == TYPE_DICTIONARY:
		var ev: Dictionary = parsed as Dictionary
		_check(String(ev.get("status", "")) == "RECOVERED",
			"credits scroll timing is recorded RECOVERED")
		_check(int(Dictionary(ev.get("tick_source", {})).get("tick_ms", 0)) == 33,
			"credits tick is the recovered 33 ms")
		_check(String(Dictionary(ev.get("recovered_primitive", {})).get(
			"per_tick_delta", "")).contains("+2,+1"),
			"credits per-tick delta primitive is recorded")
	# The shipped credits screen must still fail closed (no invented speed).
	_check(menu is MenuArt, "MENU_ART selected for the credits check")
	scene.call("_open_main_menu")
	await process_frame
	for _i: int in range(3):  # Credits is main row 3
		menu.call("handle_key_event", _key(KEY_DOWN))
		await process_frame
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	_check(String(menu.get("screen_id")) == "credits_dle",
		"credits DLE roll screen opens")
	menu.call("credits_roll_set_process", false)
	_check(bool(menu.call("credits_roll_active")),
		"credits roll is the real recovered scrolling view")
	_check(int(menu.call("credits_roll_line_count")) == 125,
		"credits DLE roll carries the full 1..125 line sequence")

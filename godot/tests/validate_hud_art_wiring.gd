extends SceneTree
## Validates the opt-in BRUCELEE_HUD_ART menu wiring:
##   * flag off  -> the existing text menu/HUD path is untouched (no art nodes);
##   * flag on   -> the real OPPONENTS submenu drives the decoded
##                   selectfighter.ui dock, confirming an opponent shows the
##                   decoded fightpreview.ui VS screen, and the art is hidden
##                   when the fight starts.
##
## usage:
##   godot --headless --path <project> --script res://tests/validate_hud_art_wiring.gd \
##         --quit-after 4000 -- <player.glb> <opponent.glb>

const HudArtOverlay = preload("res://scripts/hud_art_overlay.gd")
const MATCH_STATE_FIGHT := 4

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
		"BRUCELEE_HUD_ART", "BRUCELEE_MENU_ART", "BRUCELEE_STORY_FLOW",
		"BRUCELEE_STORY_LAUNCH", "BRUCELEE_GAME_MODE", "BRUCELEE_MODE_LAUNCH",
		"BRUCELEE_PROGRESS", "BRUCELEE_STYLE_EDITOR", "BRUCELEE_ATTRACT",
		"BRUCELEE_CONTINUE", "BRUCELEE_SCENE", "BRUCELEE_OPPONENT_NAME_KEY",
		"BRUCELEE_OPPONENT_ATTACK_CONFIG",
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


func _overlay_labels(overlay: Node) -> Array:
	var out: Array = []
	var frame: Node = overlay.get("_frame")
	if frame == null:
		return out
	for child: Node in frame.get_children():
		if child is Label:
			out.append(String((child as Label).text))
	return out


func _frame_rect(overlay: Node) -> Rect2:
	var frame: Node = overlay.get("_frame")
	if frame == null:
		return Rect2()
	return (frame as Control).get_global_rect()


func _go_to_opponents(menu: Node) -> void:
	for _step: int in range(10):
		menu.call("handle_key_event", _key(KEY_DOWN))
	await process_frame
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	await process_frame


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Expected <player.glb> <opponent.glb>")
		quit(1)
		return

	# ---------------------------------------------------------------- flag off
	_clear_flags()
	var scene: Node = await _boot(args[0], args[1])
	var menu: Node = scene.get("prototype_menu")
	var hud: Node = scene.get("hud")
	_check(scene.get("hud_art_menu_overlay") == null,
		"off: no HUD-art menu overlay node exists")
	_check(scene.get("hud_art_menu_layer") == null,
		"off: no HUD-art menu CanvasLayer exists")
	_check(not bool(hud.call("hud_art_enabled")), "off: hud.hud_art_enabled() is false")
	_check(hud.get("_art_overlay") == null,
		"off: PortHUD itself creates no art overlay")
	_check(String(menu.get("menu_state")) == "main", "off: starts on the text main menu")
	var panel: Node = menu.get("panel_box")
	_check(panel != null and bool(panel.get("visible")),
		"off: text menu panel visible")
	await _go_to_opponents(menu)
	_check(String(menu.get("menu_state")) == "opponents",
		"off: OPPONENTS opens the real submenu")
	_check(bool(panel.get("visible")),
		"off: opponent submenu keeps the text panel (no art takeover)")
	_check(scene.get("hud_art_menu_layer") == null,
		"off: still no HUD-art CanvasLayer after navigation")
	_check(menu.has_signal("selection_changed"),
		"off: menu exposes the selection hook (inert without an art listener)")
	scene.queue_free()
	await process_frame
	await process_frame

	# ----------------------------------------------------------------- flag on
	_clear_flags()
	OS.set_environment("BRUCELEE_HUD_ART", "1")
	scene = await _boot(args[0], args[1])
	menu = scene.get("prototype_menu")
	hud = scene.get("hud")
	var overlay: Node = scene.get("hud_art_menu_overlay")
	var layer: CanvasLayer = scene.get("hud_art_menu_layer")
	_check(overlay != null and overlay is HudArtOverlay,
		"on: the existing hud_art_overlay class is instantiated")
	_check(layer != null and layer.layer == 31,
		"on: overlay CanvasLayer is above the menu (layer 31)")
	_check(overlay != null and not bool(overlay.get("visible")),
		"on: overlay starts hidden")
	_check(bool(hud.call("hud_art_enabled")), "on: hud.hud_art_enabled() is true")
	_check(hud.get("_art_overlay") != null,
		"on: PortHUD's own opt-in overlay also exists (hidden)")
	panel = menu.get("panel_box")
	_check(bool(panel.get("visible")), "on: main menu panel visible before OPPONENTS")

	await _go_to_opponents(menu)
	_check(String(menu.get("menu_state")) == "opponents",
		"on: OPPONENTS opens the real submenu")
	_check(not bool(panel.get("visible")),
		"on: the text panel yields to the recovered dock")
	_check(bool(overlay.get("visible")) and String(overlay.call("current_mode")) == "select_fighter",
		"on: recovered selectfighter dock is shown")
	_check(_overlay_labels(overlay) == ["BRICK DAVIS"],
		"on: dock shows the real first opponent name (BRICK DAVIS)")
	_check(bool(menu.call("selected_command") == "brick"),
		"on: menu selection is the real BRICK entry")

	menu.call("handle_key_event", _key(KEY_DOWN))
	await process_frame
	await process_frame
	_check(String(menu.call("selected_command")) == "sinfu",
		"on: DOWN moves the real selection to SIN FU")
	_check(_overlay_labels(overlay) == ["SIN FU"],
		"on: dock follows the real selection (SIN FU)")
	_check(String(overlay.call("current_mode")) == "select_fighter",
		"on: dock stays in selectfighter mode while navigating")

	# ESC/B backs out: the text panel must come back and the dock must hide.
	menu.call("handle_key_event", _key(KEY_ESCAPE))
	await process_frame
	await process_frame
	_check(String(menu.get("menu_state")) == "main" and bool(panel.get("visible")),
		"on: ESC returns to the main menu and restores the text panel")
	_check(not bool(overlay.get("visible")),
		"on: ESC hides the recovered dock")
	# _return_to_main_menu restores the OPPONENTS row, so ENTER re-opens it.
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	await process_frame
	_check(String(menu.get("menu_state")) == "opponents",
		"on: OPPONENTS re-opens after ESC")
	menu.call("handle_key_event", _key(KEY_DOWN))
	await process_frame
	await process_frame
	_check(_overlay_labels(overlay) == ["SIN FU"],
		"on: dock still follows the real selection after re-entering")

	# Geometry: the 480x320 frame must be fully inside the viewport and the
	# recovered dock rect inside the frame, so nothing is clipped by the screen.
	var viewport_size: Vector2 = root.get_visible_rect().size
	var frame_rect: Rect2 = _frame_rect(overlay)
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		_check(frame_rect.position.x >= -0.5 and frame_rect.position.y >= -0.5
				and frame_rect.end.x <= viewport_size.x + 0.5
				and frame_rect.end.y <= viewport_size.y + 0.5,
			"on: overlay 480x320 frame is fully inside the %dx%d viewport" % [
				int(viewport_size.x), int(viewport_size.y)])
		var scale_factor: float = frame_rect.size.x / 480.0
		var dock_rect := Rect2(
			frame_rect.position + Vector2(96.0, 180.0) * scale_factor,
			Vector2(320.0, 70.0) * scale_factor)
		_check(frame_rect.encloses(dock_rect),
			"on: decoded selectfighter dock rect is inside the frame (no clipping)")
	else:
		printerr("SKIP geometry (headless viewport is 0x0)")

	# Confirm SIN FU: the decoded fightpreview VS screen must appear for the
	# actual selected opponent and be hidden again when the fight starts.
	var old_scene_id: int = scene.get_instance_id()
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame
	await process_frame
	_check(bool(overlay.get("visible")) and String(overlay.call("current_mode")) == "vs_preview",
		"on: confirming an opponent shows the fightpreview VS screen")
	_check(_overlay_labels(overlay) == ["BRUCE LEE", "SIN FU"],
		"on: VS screen names the real selected pair (BRUCE LEE vs SIN FU)")

	# The VS screen is held, then the opponent switch reloads the scene.
	await create_timer(2.2, true).timeout
	var reloaded := false
	for _frame: int in range(240):
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_scene_id:
			reloaded = true
			break
	_check(reloaded, "on: confirming the opponent reloads the fight scene")
	if reloaded:
		scene = current_scene
		scene.set_process(false)
		scene.set_physics_process(false)
		var new_overlay: Node = scene.get("hud_art_menu_overlay")
		_check(new_overlay != null and not bool(new_overlay.get("visible")),
			"on: the art overlay is hidden in the reloaded fight scene")
		scene.call("_enter_match_state", MATCH_STATE_FIGHT)
		await process_frame
		_check(new_overlay != null and not bool(new_overlay.get("visible")),
			"on: entering MATCH_STATE_FIGHT keeps the art overlay hidden")

	print("HUD_ART_WIRING_VALIDATION=" + JSON.stringify({
		"passed": passed, "failed": failed,
		"viewport": [int(viewport_size.x), int(viewport_size.y)],
	}))
	if failed == 0:
		quit(0)
	else:
		printerr("hud-art wiring validation failed: %d check(s)" % failed)
		quit(1)

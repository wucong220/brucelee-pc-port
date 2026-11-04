extends SceneTree
## Windowed capture of the BRUCELEE_HUD_ART menu wiring, driven through the real
## menu navigation (no injected overlay state).
##
## usage:
##   godot --path <project> --resolution WxH --rendering-driver opengl3 \
##     --script res://tests/capture_hud_art_wired.gd -- \
##     <out_dir> <off|on|hud> <player.glb> <opponent.glb>
##
## off : flag off. main menu -> OPPONENTS text list -> confirm SIN FU -> fight.
## on  : flag on.  main menu -> OPPONENTS recovered dock -> VS screen -> fight.
## hud : standalone PortHUD off / flag-on-hidden comparison frames.

var _out := ""
var _mode := "off"
var _player := ""
var _opp := ""
var _scene: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _frames(n: int) -> void:
	for _i: int in range(n):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out.path_join(name)
	var err: int = image.save_png(path)
	print("SHOT %s %dx%d err=%d" % [name, image.get_width(), image.get_height(), err])
	if _scene != null and _scene.get("hud_art_menu_overlay") != null:
		var overlay: Node = _scene.get("hud_art_menu_overlay")
		var frame: Control = overlay.get("_frame")
		if frame != null:
			var fr: Rect2 = frame.get_global_rect()
			print("OVERLAY_RECT mode=%s frame=[%.2f,%.2f,%.2f,%.2f] viewport=%s" % [
				String(overlay.call("current_mode")), fr.position.x, fr.position.y,
				fr.size.x, fr.size.y, str(root.get_visible_rect().size)])


func _freeze(scene: Node) -> void:
	scene.set_process(false)
	scene.set_physics_process(false)
	var p: Node = scene.get("player")
	if p != null:
		p.set_physics_process(false)
	var c: Node = scene.get("computer")
	if c != null:
		c.set_physics_process(false)


func _boot() -> Node:
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_HUD_ART", "1" if _mode == "on" else "0")
	OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
	OS.set_environment("BRUCELEE_PLAYER_GLB", _player)
	OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT",
		"D:\\BaiduSyncdisk\\AI项目\\李小龙\\private_assets\\appdata-msix"
		+ "\\BruceLee-PC-Port\\candidate-textures-verified-20261029")
	OS.set_environment("BRUCELEE_OPPONENT_GLB", _opp)
	OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT",
		"D:\\BaiduSyncdisk\\AI项目\\李小龙\\private_assets\\appdata-msix"
		+ "\\BruceLee-PC-Port\\brick-textures-20261030")
	# Menu background and menu SFX deliberately use prototype_menu's default
	# LOCALAPPDATA staging (the same place the shipped launcher fills), so the
	# capture does not depend on a package directory that may be rebuilt.
	OS.set_environment("BRUCELEE_MENU_SFX_ROOT", "")
	OS.set_environment("BRUCELEE_MAINMENU_PATH", "")
	for name: String in ["BRUCELEE_MENU_ART", "BRUCELEE_STORY_FLOW",
			"BRUCELEE_STORY_LAUNCH", "BRUCELEE_GAME_MODE", "BRUCELEE_MODE_LAUNCH",
			"BRUCELEE_PROGRESS", "BRUCELEE_STYLE_EDITOR", "BRUCELEE_ATTRACT",
			"BRUCELEE_CONTINUE", "BRUCELEE_SCENE", "BRUCELEE_OPPONENT_NAME_KEY",
			"BRUCELEE_OPPONENT_ATTACK_CONFIG"]:
		OS.set_environment(name, "")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(18)
	_freeze(scene)
	return scene


func _go_to_opponents(menu: Node) -> void:
	for _step: int in range(10):
		menu.call("handle_key_event", _key(KEY_DOWN))
	await _frames(2)
	menu.call("handle_key_event", _key(KEY_ENTER))
	await _frames(4)


func _wait_reload(old_scene_id: int) -> Node:
	for _frame: int in range(600):
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_scene_id:
			return current_scene
	return null


func _run_flow() -> void:
	var scene: Node = await _boot()
	_scene = scene
	var menu: Node = scene.get("prototype_menu")
	var prefix: String = _mode
	await _frames(2)
	await _shot(prefix + "_01_main.png")
	await _go_to_opponents(menu)
	# index 0 opponent (BRICK) before moving.
	await _frames(2)
	await _shot(prefix + "_02_opponents_brick.png")
	# move to SIN FU so both flows reload the same opponent.
	menu.call("handle_key_event", _key(KEY_DOWN))
	await _frames(3)
	if _mode == "on":
		await _shot("on_03_dock_sinfu.png")
	var old_scene_id: int = scene.get_instance_id()
	menu.call("handle_key_event", _key(KEY_ENTER))
	await _frames(2)
	if _mode == "on":
		# The decoded fightpreview.ui VS screen is held before the reload.
		await _shot("on_04_vs_sinfu.png")
	var reloaded: Node = await _wait_reload(old_scene_id)
	if reloaded == null:
		printerr("capture: scene did not reload after opponent confirm")
		quit(2)
		return
	_scene = reloaded
	await _frames(4)
	_freeze(reloaded)
	await _frames(6)
	await _shot(prefix + "_05_fight.png")
	quit(0)


func _run_hud_compare() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.45, 0.45, 0.45, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	await _frames(2)
	OS.set_environment("BRUCELEE_HUD_ART", "0")
	var off: Node = load("res://scripts/hud.gd").new()
	root.add_child(off)
	await _frames(4)
	await _shot("hud_off.png")
	off.queue_free()
	await _frames(3)
	OS.set_environment("BRUCELEE_HUD_ART", "1")
	var on: Node = load("res://scripts/hud.gd").new()
	root.add_child(on)
	await _frames(4)
	await _shot("hud_on_hidden.png")
	on.queue_free()
	await _frames(2)
	quit(0)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 4:
		printerr("Expected <out_dir> <off|on|hud> <player.glb> <opponent.glb>")
		quit(1)
		return
	_out = args[0]
	_mode = args[1]
	_player = args[2]
	_opp = args[3]
	DirAccess.make_dir_recursive_absolute(_out)
	if _mode == "hud":
		await _run_hud_compare()
	else:
		await _run_flow()

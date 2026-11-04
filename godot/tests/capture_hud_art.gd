extends SceneTree
## Windowed capture of the recovered BRUCELEE_HUD_ART art set.
##
## usage:
##   godot --path <run/godot> --resolution 1280x720 --rendering-driver opengl3 \
##     --script res://tests/capture_hud_art.gd -- <out_dir> <ui_art_root>
##
## Shots:
##   hud_off.png            PortHUD with BRUCELEE_HUD_ART unset (baseline)
##   hud_on_hidden.png      PortHUD with BRUCELEE_HUD_ART=1, no overlay shown
##   hud_plate.png          recovered HUD backdrop/frame + round/time + bar frames
##   select_fighter.png     selectfighter.ui dock (selected 1, all unlocked)
##   select_fighter_locked.png  selectfighter.ui dock (locked tail)
##   vs_preview.png         fightpreview.ui versus screen
##   vs_preview_2.png       fightpreview.ui versus screen (second pair)

var _out_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out_dir.path_join(name).replace("/", "\\")
	var err: int = image.save_png(path)
	print("SHOT %s %dx%d err=%d" % [name, image.get_width(), image.get_height(), err])


func _frames(n: int) -> void:
	for _i: int in range(n):
		await process_frame


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() > 0 else "user://"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	if args.size() > 1 and not String(args[1]).is_empty():
		OS.set_environment("BRUCELEE_HUD_ART_ROOT", String(args[1]))

	# Neutral inspection backdrop (NOT original art; only so transparent sprites
	# are visible in these evidence shots).
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.45, 0.45, 0.45, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	await _frames(2)

	# 1) baseline HUD (flag off)
	OS.set_environment("BRUCELEE_HUD_ART", "0")
	var hud_off: Node = load("res://scripts/hud.gd").new()
	root.add_child(hud_off)
	await _frames(3)
	await _shot("hud_off.png")
	hud_off.queue_free()
	await _frames(3)

	# 2) HUD with flag on, overlay hidden -> must equal baseline
	OS.set_environment("BRUCELEE_HUD_ART", "1")
	var hud_on: Node = load("res://scripts/hud.gd").new()
	root.add_child(hud_on)
	await _frames(3)
	await _shot("hud_on_hidden.png")
	# 3) recovered HUD plate
	hud_on.show_hud_art_plate()
	await _frames(3)
	await _shot("hud_plate.png")
	# 3b) same recovered art driven through the PortHUD opt-in API
	hud_on.show_hud_art_select_fighter(1, 15, "BRUCE LEE")
	await _frames(3)
	await _shot("hud_api_select.png")
	hud_on.show_hud_art_vs_preview("BRUCE LEE", "BRICK DAVIS")
	await _frames(3)
	await _shot("hud_api_vs.png")
	hud_on.hide_hud_art()
	hud_on.queue_free()
	await _frames(3)

	# 4) standalone overlay shots
	var overlay: Control = load("res://scripts/hud_art_overlay.gd").new()
	root.add_child(overlay)
	await _frames(3)
	overlay.show_select_fighter(1, 15, "BRUCE LEE")
	await _frames(3)
	await _shot("select_fighter.png")
	overlay.show_select_fighter(13, 12, "LO MING")
	await _frames(3)
	await _shot("select_fighter_locked.png")
	overlay.show_vs_preview("BRUCE LEE", "BRICK DAVIS")
	await _frames(3)
	await _shot("vs_preview.png")
	overlay.show_vs_preview("THE MASTER", "SMALL BOY")
	await _frames(3)
	await _shot("vs_preview_2.png")
	quit(0)

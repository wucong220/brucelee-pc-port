extends SceneTree
## Windowed gallery: the localized mode menu and Arcade settings screen for
## every one of the 10 recovered languages, one PNG each.
##
##   godot --path godot --script res://tests/menu_lang_gallery.gd -- <shots dir>
##
## Uses the GameModes CanvasLayer directly (no fighters/GLBs needed), so this
## run only exercises the localized text surfaces.

const GameModes = preload("res://scripts/game_modes.gd")
const MenuLang = preload("res://scripts/menu_lang.gd")

var shots: String = ""
var failures: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOT_SKIPPED_HEADLESS %s" % name)
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = shots.path_join(name)
	var error: int = image.save_png(path)
	print("SHOT %s %dx%d err=%d" % [name, image.get_width(), image.get_height(), error])
	if error != OK:
		failures.append("capture " + name)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	shots = String(args[0]) if args.size() > 0 else "user://menu_lang_gallery"
	DirAccess.make_dir_recursive_absolute(shots)
	for lang_value: Variant in MenuLang.languages():
		var lang: String = String(lang_value)
		MenuLang.set_language(lang)
		var gm: Node = GameModes.new()
		root.add_child(gm)
		gm.configure(null, {})
		for _i: int in range(6):
			await process_frame
		gm.call("show_mode_menu")
		for _i: int in range(4):
			await process_frame
		await _capture("10-mode-menu-%s.png" % lang)
		gm.call("open_mode", "arcade")
		for _i: int in range(4):
			await process_frame
		await _capture("11-arcade-settings-%s.png" % lang)
		gm.call("open_mode", "timeattack")
		for _i: int in range(4):
			await process_frame
		await _capture("12-timeattack-settings-%s.png" % lang)
		gm.queue_free()
		for _i: int in range(4):
			await process_frame

	print("")
	print("GALLERY_FAILURES %d" % failures.size())
	print("MENU_LANG_GALLERY " + ("OK" if failures.is_empty() else "FAILED"))
	quit(0 if failures.is_empty() else 1)

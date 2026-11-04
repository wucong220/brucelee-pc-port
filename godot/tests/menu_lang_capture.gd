extends SceneTree
## Windowed screenshot capture of the localized Arcade / Survival / Time Attack
## flow for ONE language, in one real main.tscn run.
##
##   godot --path godot --script res://tests/menu_lang_capture.gd -- <mode> <lang> <shots dir>
##
## `<lang>` is a full .lang name (LangEnglish) or a short alias (en/zh/ja).
## Asset roots come from CAPTURE_PLAYER_GLB / CAPTURE_TEXTURE_ROOT /
## CAPTURE_GAMETEXT_ROOT / CAPTURE_HUD_ROOT so the source stays ASCII.

const MenuLang = preload("res://scripts/menu_lang.gd")

var mode: String = "arcade"
var lang: String = "LangEnglish"
var shots: String = ""
var failures: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _args() -> PackedStringArray:
	return OS.get_cmdline_user_args()


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


func _gm() -> Node:
	if not is_instance_valid(current_scene):
		return null
	return current_scene.get("game_modes")


func _wait_screen(expected: String, max_frames: int = 600, label: String = "") -> bool:
	for _i: int in range(max_frames):
		var gm: Node = _gm()
		if gm != null and String(gm.get("screen")) == expected:
			return true
		await process_frame
	print("TIMEOUT screen=%s %s" % [expected, label])
	return false


func _wait_reload(old_id: int, max_frames: int = 900, label: String = "") -> bool:
	for _i: int in range(max_frames):
		if is_instance_valid(current_scene) and current_scene.get_instance_id() != old_id:
			return true
		await process_frame
	print("TIMEOUT reload " + label)
	return false


func _wait_fight(node: Node, max_frames: int = 2400) -> bool:
	for _i: int in range(max_frames):
		if not is_instance_valid(node):
			return false
		var player: Variant = node.get("player")
		var computer: Variant = node.get("computer")
		if player != null and computer != null and bool(player.candidate_loaded) \
				and bool(computer.candidate_loaded) and int(node.get("match_state")) == 4:
			return true
		await process_frame
	return false


func _force_ko(node: Node, player_wins: bool) -> void:
	for _i: int in range(2400):
		if not is_instance_valid(node):
			return
		if bool(node.get("match_over")):
			return
		if int(node.get("match_state")) == 4:
			break
		await process_frame
	if not is_instance_valid(node):
		return
	node.call("_on_ko", node.get("computer") if player_wins else node.get("player"))
	for _i: int in range(3000):
		if not is_instance_valid(node) or bool(node.get("match_over")):
			return
		await process_frame
	print("FORCE_KO timeout state=%d" % int(node.get("match_state")))


func _boot() -> void:
	OS.set_environment("BRUCELEE_STORY_FLOW", "")
	OS.set_environment("BRUCELEE_GAME_MODE", "")
	OS.set_environment("BRUCELEE_MODE_LAUNCH", "")
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_LANG", lang)
	OS.set_environment("BRUCELEE_PLAYER_GLB", OS.get_environment("CAPTURE_PLAYER_GLB"))
	OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", OS.get_environment("CAPTURE_TEXTURE_ROOT"))
	OS.set_environment("BRUCELEE_GAME_TEXT_ROOT", OS.get_environment("CAPTURE_GAMETEXT_ROOT"))
	OS.set_environment("BRUCELEE_HUD_TEXTURE_ROOT", OS.get_environment("CAPTURE_HUD_ROOT"))


func _run() -> void:
	var args: PackedStringArray = _args()
	if args.size() > 0:
		mode = String(args[0])
	if args.size() > 1:
		lang = String(args[1])
	shots = String(args[2]) if args.size() > 2 else "user://menu_lang_shots"
	DirAccess.make_dir_recursive_absolute(shots)
	MenuLang.set_language(lang)
	_boot()
	var boot_scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(boot_scene)
	current_scene = boot_scene
	for _i: int in range(180):
		await process_frame
	if mode == "arcade":
		await _capture("01-main-menu-%s.png" % lang)

	var gm: Node = _gm()
	current_scene.call("_on_menu_command", mode)
	await process_frame
	await _capture("02-%s-settings-%s.png" % [mode, lang])
	if String(gm.get("screen")) != "settings":
		failures.append("menu command %s did not open settings" % mode)

	var selection: Dictionary = {}
	var win: bool = true
	if mode == "arcade":
		selection = {"rounds": 0, "time": 1, "difficulty": 2}  # 1 bout, 60 s, hard
	elif mode == "survival":
		selection = {"time": 1, "difficulty": 1}  # 60 s, medium
		win = false
	else:
		selection = {"difficulty": 1, "time_limit_preset": 120}  # recovered 120 s preset
		win = false
	gm.set("selection", selection)
	var old_id: int = current_scene.get_instance_id()
	gm.call("begin_run")
	var reloaded: bool = await _wait_reload(old_id, 900, "start " + mode)
	if not reloaded:
		failures.append("reload did not happen for start")
	var scene: Node = current_scene
	await _wait_fight(scene)
	await _capture("03-%s-battle-%s.png" % [mode, lang])
	await _force_ko(scene, win)
	await _wait_screen("results", 1800, mode + " result")
	await _capture("04-%s-result-%s.png" % [mode, lang])

	print("")
	print("CAPTURE_LANG %s mode=%s" % [lang, mode])
	print("CAPTURE_FAILURES %d" % failures.size())
	for failure: Variant in failures:
		print("  FAILED: " + String(failure))
	print("MENU_LANG_CAPTURE " + ("OK" if failures.is_empty() else "FAILED"))
	quit(0 if failures.is_empty() else 1)

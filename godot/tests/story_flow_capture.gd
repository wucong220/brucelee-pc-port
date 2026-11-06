extends SceneTree
## Windowed screenshot capture of the story flow (requires a display).
##
##   godot --path game --script res://tests/story_flow_capture.gd -- <shots dir>
##
## Drives the same screens the player sees and writes one PNG per step.

const StoryStateScript = preload("res://scripts/story_state.gd")

var shots: String = ""
var failures: Array = []
var scene: Node = null
var flow: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _shots_dir() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		return String(args[0])
	return "user://story_flow_shots"


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


func _screen() -> String:
	if not is_instance_valid(current_scene):
		return "<none>"
	var node: Variant = current_scene.get("story_flow")
	if node == null:
		return "<none>"
	return String(node.debug_state().get("screen", "<none>"))


func _wait_until(predicate: Callable, max_frames: int, label: String) -> bool:
	for _index: int in range(max_frames):
		if bool(predicate.call()):
			return true
		await physics_frame
	print("TIMEOUT " + label)
	return false


func _wait_reload(old_instance_id: int, max_frames: int, label: String) -> bool:
	for _index: int in range(max_frames):
		if is_instance_valid(current_scene):
			if (current_scene.get_instance_id() != old_instance_id
					and current_scene.get("story_flow") != null):
				return true
		await physics_frame
	print("TIMEOUT " + label)
	return false


func _wait_candidates(node: Node, max_frames: int = 900) -> void:
	for _index: int in range(max_frames):
		var player: Variant = node.get("player")
		var computer: Variant = node.get("computer")
		if player != null and computer != null \
				and bool(player.candidate_loaded) and bool(computer.candidate_loaded):
			return
		await physics_frame


func _force_result(node: Node, player_wins: bool, max_rounds: int = 4) -> void:
	for _round: int in range(max_rounds):
		if _screen() != "battle" or not is_instance_valid(node):
			return
		if bool(node.get("match_over")):
			return
		var fighting: bool = await _wait_until(
			func() -> bool:
				return (
					is_instance_valid(node)
					and (bool(node.get("match_over"))
						or int(node.get("match_state")) == 4)
				),
			1800,
			"fight state")
		if not fighting or bool(node.get("match_over")) or _screen() != "battle":
			return
		node.call("_on_ko", node.get("computer") if player_wins else node.get("player"))
		await _wait_until(
			func() -> bool:
				return (
					not is_instance_valid(node)
					or _screen() != "battle"
					or int(node.get("match_state")) != 4
				),
			1800,
			"after ko")


func _advance_pictures(max_steps: int = 30) -> bool:
	var guard: int = 0
	while _screen() == "picture" and guard < max_steps:
		flow = current_scene.get("story_flow")
		flow.call("_accept")
		guard += 1
		await process_frame
	return _screen() == "battle"


func _run() -> void:
	shots = _shots_dir()
	DirAccess.make_dir_recursive_absolute(shots)
	for slot: int in range(1, StoryStateScript.SLOT_COUNT + 1):
		if StoryStateScript.slot_exists(slot):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(
				StoryStateScript.slot_path(slot)))

	OS.set_environment("BRUCELEE_STORY_FLOW", "1")
	OS.set_environment("BRUCELEE_STORY_LAUNCH", "")
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")
	OS.set_environment("BRUCELEE_PLAYER_GLB",
		"D:\\BruceLeeWork\\bruce-full-20261103\\out\\bruce_full_121_20261103.glb")
	OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT",
		"D:\\BaiduSyncdisk\\AI项目\\李小龙\\private_assets\\appdata-msix\\BruceLee-PC-Port\\candidate-textures-verified-20261029")
	OS.set_environment("BRUCELEE_GAME_TEXT_ROOT",
		"D:\\BruceLeeWork\\story-flow-20261104\\tools\\ui\\gametext")
	OS.set_environment("BRUCELEE_HUD_TEXTURE_ROOT", "D:\\BruceLeeWork\\ui_hud_png")

	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait_until(func() -> bool: return _screen() == "mode", 600, "mode")
	flow = current_scene.get("story_flow")
	await _capture("01-story-mode.png")

	flow.call("_accept")
	await _capture("02-new-story-slot.png")
	flow.call("_accept")
	flow.call("_move", 1)
	await _capture("03-difficulty-medium.png")
	flow.call("_accept")
	# the first story event carries auto_launch; show the map first for the shot
	flow.set("auto_launch_armed", false)
	flow.call("show_map")
	await _capture("04-map-chapter1.png")

	flow.call("show_detail", 7)
	await _capture("05-event-detail-s_master_1.png")
	flow.call("_accept")
	await _capture("06-story-picture.png")

	var old_id: int = scene.get_instance_id()
	var reached: bool = await _advance_pictures()
	if not reached:
		failures.append("first battle not reached")
	await _capture("07-battle-banner.png")
	var reloaded: bool = await _wait_reload(old_id, 900, "reload")
	if not reloaded:
		failures.append("first reload failed")
	scene = current_scene
	flow = current_scene.get("story_flow")
	await _wait_candidates(scene)
	await _wait_until(func() -> bool: return int(scene.get("match_state")) == 4, 900, "fight")
	await _capture("08-battle-vs-shen-lo.png")
	await _capture("09-battle-vs-shen-lo-b.png")
	await _force_result(scene, true)
	flow = current_scene.get("story_flow")
	guard_reset()
	await _advance_pictures()
	await _capture("10-rewards-s_master_1.png")
	flow.call("_accept")
	await _capture("11-map-after-s_master_1.png")

	# a side event detail shows maximum_fights / health_recovery
	flow.call("show_detail", 2)
	await _capture("12-event-detail-survival.png")
	flow.call("_cancel")

	# second story battle
	flow.call("show_detail", 8)
	await _capture("13-event-detail-s_master_2.png")
	var old2: int = scene.get_instance_id()
	flow.call("_accept")
	var reached2: bool = await _advance_pictures()
	if not reached2:
		failures.append("second battle not reached")
	var reloaded2: bool = await _wait_reload(old2, 900, "reload2")
	if not reloaded2:
		failures.append("second reload failed")
	scene = current_scene
	flow = current_scene.get("story_flow")
	await _wait_candidates(scene)
	await _wait_until(func() -> bool: return int(scene.get("match_state")) == 4, 900, "fight2")
	await _capture("14-battle-s_master_2.png")
	await _force_result(scene, false)
	flow = current_scene.get("story_flow")
	await _advance_pictures()
	await _capture("15-rewards-s_master_2.png")
	flow.call("_accept")
	flow.call("show_records")
	await _capture("16-records.png")

	print("")
	print("CAPTURE_FAILURES %d" % failures.size())
	for failure: Variant in failures:
		print("  FAILED: " + String(failure))
	print("STORY_FLOW_CAPTURE " + ("OK" if failures.is_empty() else "FAILED"))
	quit(0 if failures.is_empty() else 1)


func guard_reset() -> void:
	pass

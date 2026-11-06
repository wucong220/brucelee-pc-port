extends SceneTree
## Windowed capture of the REAL res://scenes/main.tscn with the recovered
## grab / grabbed / end-attack / special action cameras.  Every shot is the live
## Camera3D driven by the decoded JSON; the fighters are animated by the real
## CFighter::_physics_process so the pose matches the camera frame.
##
## usage: --path <proj> --resolution 1280x720 --rendering-driver opengl3 \
##        --script res://tests/capture_action_cameras.gd -- \
##        <player.glb> <opponent.glb> <opponent_attack_config> <gametext_root> <out_dir>

const SCENARIOS: Array = [
	{"label": "grab1", "trigger": "attack", "kind": "grab1",
		"clip": "m01_grab_01", "frames": [1, 45, 120]},
	{"label": "grab2", "trigger": "attack", "kind": "grab2",
		"clip": "m01_grab_02", "frames": [1, 90, 150]},
	{"label": "endattack1", "trigger": "attack", "kind": "endattack1",
		"clip": "m01_end_attack_01", "frames": [1, 64, 120, 250]},
	{"label": "endattack2", "trigger": "attack", "kind": "endattack2",
		"clip": "m01_end_attack_02", "frames": [1, 120]},
	{"label": "grabbed1", "trigger": "victim", "kind": "grab1_brick",
		"clip": "all_grabbed_01_forset02", "frames": [1, 25]},
	{"label": "special_kick_low_hit", "trigger": "attack",
		"kind": "special_kick_low_hit", "clip": "m01_sp_kick_low", "frames": [1, 20]},
]

var _out_dir: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _new_scene(player_glb: String, opponent_glb: String, attack_config: String,
		text_root: String) -> Node:
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")
	OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
	OS.set_environment("BRUCELEE_ROUND_TIME", "60")
	OS.set_environment("BRUCELEE_PLAYER_GLB", player_glb)
	OS.set_environment("BRUCELEE_OPPONENT_GLB", opponent_glb)
	OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", attack_config)
	OS.set_environment("BRUCELEE_GAME_TEXT_ROOT", text_root)
	OS.set_environment("BRUCELEE_GAME_TEXT_FLIP", "1")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	return scene


func _wait_candidates(scene: Node, timeout_frames: int = 1200) -> bool:
	var player: PortFighter = scene.get("player")
	var computer: PortFighter = scene.get("computer")
	for _i: int in range(timeout_frames):
		if player.candidate_loaded and computer.candidate_loaded:
			return true
		await physics_frame
	return player.candidate_loaded and computer.candidate_loaded


func _freeze(scene: Node) -> void:
	scene.set_process(false)
	scene.set_physics_process(false)
	var player: PortFighter = scene.get("player")
	var computer: PortFighter = scene.get("computer")
	player.set_physics_process(false)
	computer.set_physics_process(false)
	player.opponent = computer
	computer.opponent = player


func _reset(scene: Node) -> void:
	var player: PortFighter = scene.get("player")
	var computer: PortFighter = scene.get("computer")
	scene._camera_anm_end()
	scene._action_camera_end()
	player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
	computer.reset_fighter(Vector3(-1.7, 1.20, 0.0))
	player.facing = 1.0
	computer.facing = -1.0
	player.rage = 100.0
	player.opponent = computer
	computer.opponent = player
	scene._restart_fight_camera()
	scene._update_fight_camera(1.0 / 60.0)
	player._physics_process(1.0 / 60.0)
	computer._physics_process(1.0 / 60.0)


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out_dir.path_join(name)
	var err: int = image.save_png(path)
	print("SHOT %s %dx%d err=%d" % [name, image.get_width(), image.get_height(), err])
	if err != OK:
		print("SHOTB64 %s %s" % [name, Marshalls.raw_to_base64(image.save_png_to_buffer())])


func _advance_to(scene: Node, target: int, clip: String) -> bool:
	var player: PortFighter = scene.get("player")
	var computer: PortFighter = scene.get("computer")
	var guard: int = 0
	while guard < 1200:
		guard += 1
		if String(scene.get("_action_camera_clip")) != clip:
			return false
		if int(scene.get("_action_camera_frame")) >= target:
			return true
		player._physics_process(1.0 / 30.0)
		computer._physics_process(1.0 / 30.0)
		scene._update_fight_camera(1.0 / 30.0)
	return false


func _run_scenario(scene: Node, spec: Dictionary) -> bool:
	_reset(scene)
	var player: PortFighter = scene.get("player")
	if String(spec["trigger"]) == "attack":
		player.request_attack(String(spec["kind"]))
	else:
		player.begin_grabbed(String(spec["kind"]))
	# One real fighter update applies the resolved Animations.versions clip (and
	# advances the action frame) before the camera is armed.
	player._physics_process(1.0 / 30.0)
	(scene.get("computer") as PortFighter)._physics_process(1.0 / 30.0)
	scene._update_fight_camera(1.0 / 60.0)
	var player_visual_frame: Dictionary = {}
	for frame: int in spec["frames"]:
		if not _advance_to(scene, frame, String(spec["clip"])):
			push_error("%s could not reach frame %d" % [spec["label"], frame])
			return false
		var camera: Camera3D = scene.get("fight_camera")
		print("%s frame=%d camera_clip=%s fov=%.3f pos=%s anim=%s" % [
			spec["label"], scene.get("_action_camera_frame"),
			scene.get("_action_camera_clip"), camera.fov, camera.global_position,
			player.candidate_animation_clip,
		])
		await _capture("%s_frame%03d.png" % [spec["label"], frame])
		player_visual_frame[frame] = player.candidate_animation_clip
	return true


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 5:
		push_error("Expected <player.glb> <opponent.glb> <attack_config> <gametext_root> <out_dir>")
		quit(2)
		return
	var player_glb: String = args[0]
	var opponent_glb: String = args[1]
	var attack_config: String = args[2]
	var text_root: String = args[3]
	_out_dir = args[4].replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(_out_dir)

	for spec: Dictionary in SCENARIOS:
		var scene: Node = _new_scene(player_glb, opponent_glb, attack_config, text_root)
		if not await _wait_candidates(scene):
			push_error(spec["label"] + " candidates did not load")
			quit(1)
			return
		await process_frame
		_freeze(scene)
		if not await _run_scenario(scene, spec):
			quit(1)
			return
		scene.queue_free()
		await process_frame

	# Recovered Animations.versions large-opponent variant camera: with a large
	# opponent endattack1 plays m01_end_attack_01_forbigguy, whose decoded
	# variant camera is m01_end_attack_01_forbigguy_camera.
	if args.size() >= 7:
		var large_scene: Node = _new_scene(player_glb, args[5], args[6], text_root)
		if not await _wait_candidates(large_scene):
			push_error("large-opponent candidates did not load")
			quit(1)
			return
		await process_frame
		_freeze(large_scene)
		var large_spec: Dictionary = {
			"label": "endattack1_forbigguy", "trigger": "attack",
			"kind": "endattack1", "clip": "m01_end_attack_01_forbigguy",
			"frames": [1, 64],
		}
		if not await _run_scenario(large_scene, large_spec):
			quit(1)
			return
		large_scene.queue_free()
		await process_frame

	# Fail-back: mapped JSON missing -> analytic follow camera.
	var scene: Node = _new_scene(player_glb, opponent_glb, attack_config, text_root)
	if not await _wait_candidates(scene):
		push_error("fallback candidates did not load")
		quit(1)
		return
	await process_frame
	_freeze(scene)
	scene.set("_camera_anm_dir", "res://data/camera_anm_missing/")
	_reset(scene)
	var player: PortFighter = scene.get("player")
	player._physics_process(1.0 / 30.0)
	player.request_attack("grab1")
	player._physics_process(1.0 / 30.0)
	scene._update_fight_camera(1.0 / 60.0)
	var camera: Camera3D = scene.get("fight_camera")
	print("fallback action_camera=%s fov=%.3f pos=%s" % [
		scene.get("_action_camera_clip"), camera.fov, camera.global_position,
	])
	await _capture("fallback_json_missing_frame000.png")
	scene.queue_free()
	await process_frame

	print("ACTION_CAMERA_CAPTURE=done")
	quit(0)

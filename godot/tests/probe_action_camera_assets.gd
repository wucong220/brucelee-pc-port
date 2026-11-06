extends SceneTree
## Asset probe for the action-camera patch (isolated task tool).
##
## Prints, for a given player/opponent candidate pair, the skeleton classes and
## the animation clip names the candidates actually contain, so the camera
## wiring can be validated against the clip the fighter plays (base clip or a
## recovered Animations.versions size variant).
##
## usage: --headless --path <proj> --script res://tests/probe_action_camera_assets.gd -- \
##        <player.glb> <opponent.glb> <opponent_attack_config> [clip names...]

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("Expected <player.glb> <opponent.glb> <opponent_attack_config>")
		quit(2)
		return
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")
	OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
	OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
	OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
	if not args[2].is_empty():
		OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", args[2])
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var player: PortFighter = scene.get("player")
	var computer: PortFighter = scene.get("computer")
	for _i: int in range(1200):
		if player.candidate_loaded and computer.candidate_loaded:
			break
		await physics_frame
	var requested: Array = []
	for index: int in range(3, args.size()):
		requested.append(args[index])
	var clips: Dictionary = player.get("_candidate_clip_paths")
	var names: Array = []
	for key: String in clips:
		names.append(String(clips[key]))
	names.sort()
	var present: Dictionary = {}
	for clip: Variant in requested:
		var name: String = String(clip)
		present[name] = names.has(name)
	print("PROBE=" + JSON.stringify({
		"player_glb": args[0],
		"opponent_glb": args[1],
		"player_loaded": player.candidate_loaded,
		"opponent_loaded": computer.candidate_loaded,
		"player_skeleton": player.skeleton_class,
		"opponent_skeleton": computer.skeleton_class,
		"player_attack_config": player.attack_config_path,
		"opponent_attack_config": computer.attack_config_path,
		"player_clip_count": names.size(),
		"player_clips": names,
		"requested": present,
	}))
	quit(0)

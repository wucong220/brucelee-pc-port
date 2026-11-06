extends SceneTree
## TEMPORARY baseline probe (not part of the deliverable tests).
## Question: when the text scene submenu emits a scene command, does the port
## really start a running match, or does it reload into a paused tree?
##
## Usage:
##   godot --headless --path godot --script res://tests/probe_scene_command.gd \
##         --quit-after 3000 -- <player.glb> <opponent.glb> <command>

var scene: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _wait(frames: int) -> void:
	for _i: int in range(frames):
		await process_frame


func _report(tag: String) -> void:
	if scene == null:
		print("PROBE %s scene=null" % tag)
		return
	print("PROBE %s paused=%s main_menu_active=%s training=%s match_state=%s round_time_active=%s round_number=%s menu_visible=%s" % [
		tag,
		str(paused),
		str(scene.get("main_menu_active")),
		str(scene.get("training_mode")),
		str(scene.get("match_state")),
		str(scene.get("round_time_active")),
		str(scene.get("round_number")),
		str(scene.get("prototype_menu") != null and (scene.get("prototype_menu") as Node).get("visible")),
	])


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("expected <player.glb> <opponent.glb> <command>")
		quit(1)
		return
	var command: String = args[2]
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
	OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
	OS.set_environment("BRUCELEE_SCENE", "")
	OS.set_environment("BRUCELEE_ROUND_INTRO", "1")
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait(3)
	_report("boot")
	var old_id: int = scene.get_instance_id()
	scene.call("_on_menu_command", command)
	await _wait(3)
	if current_scene != null and current_scene.get_instance_id() != old_id:
		scene = current_scene
		print("PROBE reload=ok")
	else:
		print("PROBE reload=NO-NEW-SCENE same=%s" % str(scene.get_instance_id() == old_id))
	await _wait(10)
	_report("after+10")
	await _wait(200)
	_report("after+210")
	print("PROBE env_scene=%s" % OS.get_environment("BRUCELEE_SCENE"))
	quit(0)

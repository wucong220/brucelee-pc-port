extends SceneTree
## Read-only probe: confirm which recovered camera-bearing clips the loaded
## Bruce candidate GLB can actually play.  Used to choose deterministic replay
## records for validate_replay_camera.gd.

func _initialize() -> void:
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")
	OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
	OS.set_environment("BRUCELEE_STORY_FLOW", "0")
	OS.set_environment("BRUCELEE_REPLAY_RECORD", "1")
	OS.set_environment("BRUCELEE_ATTRACT", "")
	OS.set_environment("BRUCELEE_CONTINUE", "")
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	for _i in 4:
		await process_frame
	var player: PortFighter = main.get("player")
	var anim = player.get("_candidate_animation") if player != null else null
	var names: Array = []
	if anim != null:
		for name: StringName in anim.get_animation_list():
			names.append(String(name))
	var wanted: Array[String] = [
		"m01_grab_01", "m01_grab_02", "m01_end_attack_01", "m01_end_attack_02",
		"m01_victory_01", "m01_intro_01", "m01_sp_kick_low", "m01_sp_pnch_low",
		"m01_idle_01", "m01_idle_02",
	]
	for clip: String in wanted:
		print("CLIP_PRESENT %s=%s" % [clip, str(names.has(clip))])
	print("CANDIDATE_CLIP_COUNT=%d" % names.size())
	quit(0)

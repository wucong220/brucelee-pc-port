extends SceneTree
## Read-only probe: print the recovered replay animation table from the real
## scenes/main.tscn. This is an evidence tool, not a validation result.

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
	var computer: PortFighter = main.get("computer")
	var player_table: Array[String] = player.replay_animation_table() if player != null else []
	var computer_table: Array[String] = computer.replay_animation_table() if computer != null else []
	print("REPLAY_TABLE_PLAYER=" + JSON.stringify(player_table))
	print("REPLAY_TABLE_COMPUTER=" + JSON.stringify(computer_table))
	quit(0)

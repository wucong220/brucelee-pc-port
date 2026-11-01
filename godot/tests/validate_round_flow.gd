extends SceneTree

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and Brick candidate GLB paths")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)
    if not player.candidate_loaded or not computer.candidate_loaded:
        push_error("Candidates did not load")
        quit(1)
        return
    scene._reset_match()
    if (scene.round_number != 1 or scene.player_rounds != 0
            or scene.computer_rounds != 0 or scene.match_over):
        push_error("Initial round state is wrong")
        quit(1)
        return
    scene._on_ko(computer)
    if (scene.player_rounds != 1 or scene.round_number != 1
            or scene.done != true or scene.round_reset_timer <= 0.0):
        push_error("First player round win did not schedule the next round")
        quit(1)
        return
    scene._physics_process(2.1)
    if (scene.round_number != 2 or scene.player_rounds != 1
            or scene.computer_rounds != 0 or scene.done or scene.match_over):
        push_error("Next round did not start with score preserved")
        quit(1)
        return
    if (player.health != PortFighter.MAX_HEALTH
            or computer.health != PortFighter.MAX_HEALTH):
        push_error("Next round did not restore health")
        quit(1)
        return
    scene._on_ko(computer)
    if (scene.player_rounds != 2 or not scene.match_over
            or scene.round_reset_timer != -1.0 or not scene.done):
        push_error("Best-of-three player match did not close")
        quit(1)
        return
    scene._reset_match()
    if (scene.round_number != 1 or scene.player_rounds != 0
            or scene.computer_rounds != 0 or scene.match_over or scene.done):
        push_error("Match reset did not clear scores")
        quit(1)
        return
    scene._on_ko(player)
    scene._physics_process(2.1)
    scene._on_ko(player)
    if (scene.computer_rounds != 2 or not scene.match_over):
        push_error("Best-of-three computer match did not close")
        quit(1)
        return
    print("ROUND_FLOW_VALIDATION=" + JSON.stringify({
        "rounds_to_win": scene.ROUNDS_TO_WIN,
        "player_rounds": scene.player_rounds,
        "computer_rounds": scene.computer_rounds,
        "round": scene.round_number,
    }))
    scene.queue_free()
    await process_frame
    quit(0)

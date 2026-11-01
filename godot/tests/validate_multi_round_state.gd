extends SceneTree

func _initialize() -> void:
    call_deferred("_run")


func _ko_with_punch(player: PortFighter, computer: PortFighter, scene: Node) -> bool:
    player.reset_fighter(Vector3(0.0, 1.20, 0.0))
    computer.reset_fighter(Vector3(0.6, 1.20, 0.0))
    computer.health = 1.0
    if not player.request_attack("punch"):
        return false
    player._advance_timed_states(player.ATTACKS["punch"]["startup"] + 0.001)
    player._try_attack_contact()
    return computer.health <= 0.0


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
    scene._reset_match()
    if not _ko_with_punch(player, computer, scene):
        push_error("Round 1 real KO failed")
        quit(1)
        return
    if scene.player_rounds != 1 or scene.done != true:
        push_error("Round 1 did not score")
        quit(1)
        return
    scene._physics_process(2.1)
    if (player.state != "idle" or computer.state != "idle"
            or player.health != PortFighter.MAX_HEALTH
            or computer.health != PortFighter.MAX_HEALTH
            or player.candidate_animation_clip != "m01_idle_01"
            or computer.candidate_animation_clip != "m03_idle_01"
            or not player.last_reaction_animation.is_empty()
            or not computer.last_reaction_animation.is_empty()):
        push_error("Round 2 reset retained combat/reaction state")
        quit(1)
        return
    if not _ko_with_punch(player, computer, scene):
        push_error("Round 2 real KO failed")
        quit(1)
        return
    if scene.player_rounds != 2 or not scene.match_over:
        push_error("Round 2 did not close the match")
        quit(1)
        return
    scene._reset_match()
    if (player.state != "idle" or computer.state != "idle"
            or player.health != PortFighter.MAX_HEALTH
            or computer.health != PortFighter.MAX_HEALTH
            or not scene.round_number == 1 or scene.player_rounds != 0):
        push_error("Match reset retained combat state")
        quit(1)
        return
    print("MULTI_ROUND_VALIDATION=" + JSON.stringify({
        "round": scene.round_number,
        "player_state": player.state,
        "computer_state": computer.state,
        "player_clip": player.candidate_animation_clip,
        "computer_clip": computer.candidate_animation_clip,
    }))
    scene.queue_free()
    await process_frame
    quit(0)

extends SceneTree
## Validate that the Brick candidate resolves and plays the retargeted brutal clip.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected player GLB and Brick candidate GLB")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var computer: PortFighter = scene.get("computer")
    if not computer.candidate_loaded:
        push_error("Brick candidate failed: " + computer.candidate_load_error)
        quit(1)
        return
    if not computer.get("_candidate_clip_paths").has("all_sp_pnch_low_forset04"):
        push_error("Brick candidate lacks all_sp_pnch_low_forset04")
        quit(1)
        return
    computer.reset_fighter(Vector3.ZERO)
    computer.state = "stun"
    computer.health = 10.0
    var reaction: Dictionary = computer.reaction_for_incoming(
        {"strength": "brutal", "height": "medium", "direction": "frontal"}, false
    )
    if String(reaction.get("animation", "")) != "stun_brutal":
        push_error("Brick brutal reaction did not select stun_brutal: " + str(reaction))
        quit(1)
        return
    if not computer.receive_hit(2.0, false, 0.0, 1.0, reaction):
        push_error("Brick brutal receive_hit rejected")
        quit(1)
        return
    if computer.last_reaction_animation != "stun_brutal":
        push_error("Brick last_reaction_animation=" + computer.last_reaction_animation)
        quit(1)
        return
    for _i: int in range(70):
        computer._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if computer.state != "facedownko":
        push_error("Brick brutal did not enter facedownko; state=" + computer.state)
        quit(1)
        return
    print("BRICK_BRUTAL_VALIDATION=" + JSON.stringify({
        "clip": "all_sp_pnch_low_forset04",
        "reaction": reaction.get("source_action", ""),
        "animation": "stun_brutal",
        "end_state": computer.state,
    }))
    quit(0)

extends SceneTree
## Validate the prototype stun state for healthzero impactstun links.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the 48-clip Bruce candidate GLB")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", "")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    player.set_physics_process(false)
    if not player.candidate_loaded:
        push_error("Stun candidate failed: " + player.candidate_load_error)
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    for required: String in ["stun", "stun_fall"]:
        if not clips.has(required):
            push_error("Candidate is missing " + required)
            quit(1)
            return
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 5.0
    var reaction: Dictionary = {
        "source_action": "impactlightfronthigh",
        "animation": "all_impct_light_frnt_high",
        "exit_start_frame": 13,
        "animation_duration_frames": 17,
        "linking_frame": 0,
    }
    if not player.receive_hit(5.0, false, 0.0, 1.0, reaction):
        push_error("receive_hit rejected stun fixture")
        quit(1)
        return
    if player.state != "stun":
        push_error("Lethal normal hit did not enter stun: " + player.state)
        quit(1)
        return
    player._animate_candidate()
    if player.candidate_animation_clip != String(clips["stun"]):
        push_error("stun did not play all_stunned")
        quit(1)
        return
    for _i: int in range(62):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stun2":
        push_error("stun did not advance to stun2: " + player.state)
        quit(1)
        return
    for _i: int in range(62):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stunfall":
        push_error("stun2 did not advance to stunfall: " + player.state)
        quit(1)
        return
    player._animate_candidate()
    if player.candidate_animation_clip != String(clips["stun_fall"]):
        push_error("stunfall did not play all_stunned_fall")
        quit(1)
        return
    for _i: int in range(80):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "ko":
        push_error("stunfall did not finish in ko: " + player.state)
        quit(1)
        return
    # Nonlethal and blocked hits must not enter the stun state.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 100.0
    if not player.receive_hit(5.0, false, 0.0, 1.0, reaction):
        push_error("nonlethal stun fixture rejected")
        quit(1)
        return
    if player.state != "hitstun":
        push_error("nonlethal hit entered " + player.state + " instead of hitstun")
        quit(1)
        return
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 5.0
    if not player.receive_hit(100.0, true, 0.0, 1.0, reaction):
        push_error("blocked stun fixture rejected")
        quit(1)
        return
    if player.state == "stun":
        push_error("blocked lethal hit entered stun")
        quit(1)
        return
    print("STUN_VALIDATION=" + JSON.stringify({
        "state_chain": ["stun", "stun2", "stunfall", "ko"],
        "animation": clips["stun"],
        "scope": "prototype stun path for healthzero normal hits; source impactstun timing is not fully recovered",
    }))
    await process_frame
    scene.queue_free()
    await process_frame
    quit(0)

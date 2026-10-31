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
    for _i: int in range(70):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stunfall":
        push_error("stunfall ended before its 71-79 source window: " + player.state)
        quit(1)
        return
    for _i: int in range(9):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "faceupko":
        push_error("stunfall did not finish in faceupko by frame 79: " + player.state)
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
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.state = "stun"
    player.state_time = 0.1
    player.health = 0.0
    var stun_reaction: Dictionary = {
        "source_action": "impactlightfronthigh",
        "animation": "all_impct_light_frnt_high",
        "exit_start_frame": 13,
        "animation_duration_frames": 17,
        "linking_frame": 0,
    }
    if not player.receive_hit(1.0, false, 0.0, 1.0, stun_reaction):
        push_error("stun impact fixture rejected")
        quit(1)
        return
    if player.state != "stunimpact":
        push_error("stun hit did not enter stunimpact: " + player.state)
        quit(1)
        return
    player._animate_candidate()
    if player.candidate_animation_clip != String(clips["all_impct_light_frnt_high"]):
        push_error("stunimpact did not play all_impct_light_frnt_high")
        quit(1)
        return
    for _i: int in range(14):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stunfall":
        push_error("stunimpact did not return to stunfall: " + player.state)
        quit(1)
        return
    var stun_cases: Array[Dictionary] = [
        {"source": "impactlightfrontlow", "animation": "all_impct_light_frnt_low", "accepted": true},
        {"source": "impactlightfrontmid", "animation": "all_impct_crotch", "accepted": true},
        {"source": "impacthardfrontlow", "animation": "", "accepted": false},
        {"source": "impactbrutallow", "animation": "", "accepted": false},
    ]
    for case: Dictionary in stun_cases:
        player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
        player.state = "stun"
        player.state_time = 0.1
        player.health = 0.0
        var case_reaction: Dictionary = {
            "source_action": String(case["source"]),
            "animation": String(case["animation"]),
            "exit_start_frame": 13,
            "animation_duration_frames": 17,
            "linking_frame": 0,
        }
        var accepted: bool = player.receive_hit(1.0, false, 0.0, 1.0, case_reaction)
        if accepted != bool(case["accepted"]):
            push_error("stunimpact acceptance mismatch for " + String(case["source"]))
            quit(1)
            return
        if accepted:
            if player.state != "stunimpact":
                push_error("accepted stunimpact did not enter stunimpact")
                quit(1)
                return
            player._animate_candidate()
            if player.candidate_animation_clip != String(clips[String(case["animation"])]):
                push_error("stunimpact clip mismatch for " + String(case["source"]))
                quit(1)
                return
        elif player.state != "stun":
            push_error("rejected stunimpact changed state for " + String(case["source"]))
            quit(1)
            return
    # Medium impact must play the full 30-frame all_impct_crotch before stunfall.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.state = "stun"
    player.state_time = 0.1
    player.health = 0.0
    if not player.receive_hit(1.0, false, 0.0, 1.0, {
        "source_action": "impactlightfrontmid",
        "animation": "all_impct_crotch",
        "exit_start_frame": 15,
        "animation_duration_frames": 30,
        "linking_frame": 0,
    }):
        push_error("medium stunimpact fixture rejected")
        quit(1)
        return
    for _i: int in range(29):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stunimpact":
        push_error("medium stunimpact ended before 30 frames")
        quit(1)
        return
    player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stunfall":
        push_error("medium stunimpact did not end in stunfall on frame 30: " + player.state)
        quit(1)
        return
    # Empty reaction source must fail closed from both stun and stun2.
    for source_state: String in ["stun", "stun2"]:
        player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
        player.state = source_state
        player.state_time = 0.1
        player.health = 0.0
        if player.receive_hit(1.0, false, 0.0, 1.0, {}):
            push_error("empty stunimpact reaction was accepted from " + source_state)
            quit(1)
            return
        if player.state != source_state:
            push_error("empty stunimpact reaction changed state from " + source_state)
            quit(1)
            return
    var defender: PortFighter = PortFighter.new()
    defender.configure("Stun endmove defender", false, Color.CYAN)
    defender.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    defender.configure_candidate_asset(args[0], "", PortFighter.CANDIDATE_CLIPS, "body")
    root.add_child(defender)
    await process_frame
    if not defender.candidate_loaded:
        push_error("Stun endmove defender candidate failed")
        quit(1)
        return
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 100.0
    defender.reset_fighter(Vector3(-1.9, 1.20, 0.0))
    defender.health = 5.0
    player.opponent = defender
    if not player.request_attack("punch"):
        push_error("Stun endmove attack did not start")
        quit(1)
        return
    for _i: int in range(6):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if defender.state != "stun":
        push_error("Stun endmove setup did not stun defender: " + defender.state)
        quit(1)
        return
    player.record_standing_combo_press("b", ["up", "in"])
    player.record_standing_combo_press("a")
    player.record_standing_combo_press("a")
    if player.attack_kind != "endattack1":
        push_error("Stun opponent did not accept endattack1: " + player.attack_kind)
        quit(1)
        return
    player._animate_candidate()
    var player_clips: Dictionary = player.get("_candidate_clip_paths")
    if player.candidate_animation_clip != String(player_clips.get("endattack1", "")):
        push_error("Stun endmove did not play the endattack1 candidate clip")
        quit(1)
        return
    print("STUN_VALIDATION=" + JSON.stringify({
        "state_chain": ["stun", "stun2", "stunfall", "faceupko"],
        "animation": clips["stun"],
        "scope": "prototype stun path for healthzero normal hits; source impactstun timing is not fully recovered",
    }))
    await process_frame
    scene.queue_free()
    await process_frame
    quit(0)

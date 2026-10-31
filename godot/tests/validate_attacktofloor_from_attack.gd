extends SceneTree
## Validate attacktofloor can be selected from a current candobasicattacks window.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the Bruce candidate GLB")
        quit(1)
        return
    var player: PortFighter = PortFighter.new()
    var defender: PortFighter = PortFighter.new()
    for fighter: PortFighter in [player, defender]:
        fighter.configure("attacktofloor test", fighter == player, Color.CYAN)
        fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
        fighter.configure_candidate_asset(args[0], "", PortFighter.CANDIDATE_CLIPS, "body")
        root.add_child(fighter)
        await process_frame
        if not fighter.candidate_loaded:
            push_error("Candidate failed: " + fighter.candidate_load_error)
            quit(1)
            return
    player.position = Vector3(-2.0, 1.2, 0.0)
    defender.position = Vector3(2.0, 1.2, 0.0)
    player.facing = 1.0
    player.opponent = defender
    defender._enter_locomotion_state("facedownidle")
    if not player.request_attack("punch"):
        push_error("Could not start punch for attacktofloor test")
        quit(1)
        return
    player._advance_timed_states(22.0 / PortFighter.SOURCE_FRAME_RATE)
    if not player._candobasicattack_window_contains_current_frame():
        push_error("Punch is not inside its candobasicattacks window")
        quit(1)
        return
    var b_result: PortFighter.AttackToFloorInputResult = player.try_attack_to_floor_press("b")
    var c_result: PortFighter.AttackToFloorInputResult = player.try_attack_to_floor_press("c")
    var c2_result: PortFighter.AttackToFloorInputResult = player.try_attack_to_floor_press("c")
    if (b_result != PortFighter.AttackToFloorInputResult.BUFFERED
            or c_result != PortFighter.AttackToFloorInputResult.BUFFERED
            or c2_result != PortFighter.AttackToFloorInputResult.STARTED
            or player.state != "attacktofloor"):
        push_error("attacktofloor did not start from a current attack window")
        quit(1)
        return
    print("ATTACK_TO_FLOOR_FROM_ATTACK_VALIDATION=" + JSON.stringify({
        "source": "candobasicattacks link source_index 32/33",
        "state": player.state,
        "scope": "prototype input path; native deferred priority unverified",
    }))
    # The same buffered sequence must survive active -> recovery.
    player.reset_fighter(Vector3(-2.0, 1.2, 0.0))
    defender.reset_fighter(Vector3(2.0, 1.2, 0.0))
    defender._enter_locomotion_state("facedownidle")
    player.opponent = defender
    if not player.request_attack("grab1"):
        push_error("Could not start grab1 for cross-phase test")
        quit(1)
        return
    player._advance_timed_states(46.0 / PortFighter.SOURCE_FRAME_RATE)
    if not player._candobasicattack_window_contains_current_frame():
        push_error("grab1 is not inside its candobasicattacks window")
        quit(1)
        return
    if player.try_attack_to_floor_press("b") != PortFighter.AttackToFloorInputResult.BUFFERED:
        push_error("grab1 first attacktofloor key was not buffered")
        quit(1)
        return
    player._advance_timed_states(2.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.try_attack_to_floor_press("c") != PortFighter.AttackToFloorInputResult.BUFFERED:
        push_error("grab1 second attacktofloor key was lost across phase")
        quit(1)
        return
    if player.try_attack_to_floor_press("c") != PortFighter.AttackToFloorInputResult.STARTED:
        push_error("grab1 attacktofloor did not start after phase change")
        quit(1)
        return
    quit(0)

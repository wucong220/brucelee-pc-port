extends SceneTree
## Validate the guard+down+toward parry and its parry attack.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the 42-clip Bruce candidate GLB")
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
    var computer: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)
    if not player.candidate_loaded:
        push_error("Parry candidate failed: " + player.candidate_load_error)
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    for required: String in ["parry_high", "parry_attack"]:
        if not clips.has(required):
            push_error("Candidate is missing " + required)
            quit(1)
            return
    var defender: PortFighter = load("res://scripts/fighter.gd").new()
    defender.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(defender)
    await process_frame
    if not _validate_parry(scene, player, computer):
        quit(1)
        return
    if not _validate_parry_attack(player, defender):
        quit(1)
        return
    if not _validate_rejected_parry(scene, player, computer):
        quit(1)
        return
    if not _validate_no_chain_without_attack(player, defender):
        quit(1)
        return
    if not _validate_history_clear(player):
        quit(1)
        return
    if not _validate_release_wiring(scene, player):
        quit(1)
        return
    if not _validate_parry_low(scene, player, computer):
        quit(1)
        return
    print("PARRY_VALIDATION=" + JSON.stringify({
        "parry": "parryhigh -> parryattack",
        "input": "guard + down+toward x3 within 0.5s while opponent attacks",
        "rage_cost": 33.0,
        "damage": 10.0,
        "candidate_bytes": 2727612,
        "candidate_sha256": "7771893136ca4cba7a25284ccd1c0cb95f982b1344ab5ef870574760dadc43cf",
        "scope": "PC prototype direction-only binding",
    }))
    defender.queue_free()
    await create_timer(0.1).timeout
    await process_frame
    scene.queue_free()
    await process_frame
    quit(0)


func _validate_parry(scene: Node, player: PortFighter, computer: PortFighter) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    player.rage = 40.0
    player.guard_held = true
    player.facing = 1.0
    player.global_position = Vector3(-2.0, 1.20, 0.0)
    computer.global_position = Vector3(-1.7, 1.20, 0.0)
    computer.attack_kind = "punch"
    computer.state = "startup"
    for _i: int in range(3):
        Input.action_press("prototype_move_down")
        Input.action_press("prototype_move_right")
        scene._update_parry_input()
        Input.action_release("prototype_move_down")
        Input.action_release("prototype_move_right")
        scene._update_parry_input()
        player._time += 0.1
    if player.attack_kind != "parry_high":
        push_error("Real parry input did not start parry_high: " + player.attack_kind)
        return false
    if absf(player.rage - 7.0) > 0.001:
        push_error("Parry did not cost 33 rage: " + str(player.rage))
        return false
    return true


func _validate_parry_attack(player: PortFighter, defender: PortFighter) -> bool:
    defender.reset_fighter(Vector3(-1.7, 1.20, 0.0))
    defender.attack_kind = "punch"
    defender.state = "active"
    player.opponent = defender
    player.facing = 1.0
    for _i: int in range(20):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        if player.attack_kind == "parry_attack":
            break
    if player.attack_kind != "parry_attack":
        push_error("Parry did not chain to parry_attack: " + player.attack_kind)
        return false
    player._advance_timed_states(
        float(player.ATTACKS["parry_attack"]["startup"]) + 0.001
    )
    if absf(defender.health - 90.0) > 0.001:
        push_error("Parry attack did not deal 10 damage: " + str(defender.health))
        return false
    if defender.last_reaction_source_action != "impacthardfronthigh":
        push_error("Parry attack reaction was " + defender.last_reaction_source_action)
        return false
    return true


func _press_parry(scene: Node) -> void:
    Input.action_press("prototype_move_down")
    Input.action_press("prototype_move_right")
    scene._update_parry_input()
    Input.action_release("prototype_move_down")
    Input.action_release("prototype_move_right")
    scene._update_parry_input()


func _validate_rejected_parry(scene: Node, player: PortFighter, computer: PortFighter) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    player.rage = 40.0
    player.guard_held = true
    player.facing = 1.0
    computer.reset_fighter(Vector3(2.0, 1.20, 0.0))
    computer.attack_kind = "punch"
    computer.state = "startup"
    for _i: int in range(3):
        _press_parry(scene)
        player._time += 0.1
    if player.attack_kind == "parry_high":
        push_error("Parry fired with the attacker out of reach")
        return false
    computer.global_position = Vector3(-1.7, 1.20, 0.0)
    player.state = "hitstun"
    player.rage = 40.0
    for _i: int in range(3):
        _press_parry(scene)
        player._time += 0.1
    if player.attack_kind == "parry_high":
        push_error("Parry fired from hitstun")
        return false
    return true


func _validate_no_chain_without_attack(player: PortFighter, defender: PortFighter) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    player.rage = 40.0
    if not player.record_parry_press():
        pass
    player._time += 0.1
    player.record_parry_press()
    player._time += 0.1
    player.record_parry_press()
    if player.attack_kind != "parry_high":
        push_error("Parry setup failed in the no-chain check")
        return false
    defender.reset_fighter(Vector3(-1.7, 1.20, 0.0))
    defender.state = "idle"
    player.opponent = defender
    for _i: int in range(20):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.attack_kind == "parry_attack":
        push_error("Parry chained even though the opponent was not attacking")
        return false
    if not is_equal_approx(defender.health, 100.0):
        push_error("Parry attack damaged an idle opponent")
        return false
    return true


func _validate_history_clear(player: PortFighter) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.rage = 40.0
    player.record_parry_press()
    player._time += 0.1
    player.record_parry_press()
    player.end_guard()
    var history: Array = player.get("_parry_press_times")
    if not history.is_empty():
        push_error("end_guard did not clear parry history")
        return false
    return true


func _validate_release_wiring(scene: Node, player: PortFighter) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    scene._sync_guard_state(true)
    player.record_parry_press()
    player._time += 0.1
    player.record_parry_press()
    scene._sync_guard_state(false)
    var history: Array = player.get("_parry_press_times")
    if not history.is_empty():
        push_error("Releasing guard through the real input path did not clear history")
        return false
    return true


func _validate_parry_low(scene: Node, player: PortFighter, computer: PortFighter) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    player.rage = 40.0
    player.guard_held = true
    player.facing = 1.0
    computer.reset_fighter(Vector3(-1.7, 1.20, 0.0))
    computer.attack_kind = "kick"
    computer.state = "startup"
    for _i: int in range(3):
        Input.action_press("prototype_move_down")
        Input.action_press("prototype_move_right")
        scene._update_parry_input()
        Input.action_release("prototype_move_down")
        Input.action_release("prototype_move_right")
        scene._update_parry_input()
        player._time += 0.1
    if player.attack_kind != "parry_low":
        push_error("Low incoming attack did not select parry_low: kind=" + player.attack_kind + " low=" + str(scene._incoming_attack_is_low()) + " reach=" + str(computer.attack_reach_world(computer.attack_kind, player)) + " dist=" + str(Vector2(player.position.x - computer.position.x, player.position.z - computer.position.z).length()) + " state=" + player.state + " cstate=" + computer.state)
        return false
    if absf(player.rage - 10.0) > 0.001:
        push_error("parry_low did not cost 30 rage: " + str(player.rage))
        return false
    for _i: int in range(30):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    return true

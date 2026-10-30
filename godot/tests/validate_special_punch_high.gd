extends SceneTree
## Validate the multi-impact special punch high on the 41-clip candidate.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the 41-clip Bruce candidate GLB")
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
        push_error("Special punch high candidate failed: " + player.candidate_load_error)
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    for required: String in ["special_punch_high_miss", "special_punch_high_hit"]:
        if not clips.has(required):
            push_error("Candidate is missing " + required)
            quit(1)
            return
    var defender: PortFighter = load("res://scripts/fighter.gd").new()
    defender.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(defender)
    await process_frame
    if not _validate_rage_gate(player):
        quit(1)
        return
    if not _validate_multi_hit(player, defender):
        quit(1)
        return
    if not _validate_miss_branch(player, defender):
        quit(1)
        return
    if not _validate_all_blocked(player, defender):
        quit(1)
        return
    if not _validate_input_mapping(scene, player):
        quit(1)
        return
    print("SPECIAL_PUNCH_HIGH_VALIDATION=" + JSON.stringify({
        "special": "specialpunchhigh",
        "input": "up+a -> up+a -> up+a (prototype for pressleft+pressright+a)",
        "rage_gate": 66.0,
        "impacts": [4.0, 4.0, 13.0],
        "total_damage": 21.0,
        "candidate_bytes": 2654468,
        "candidate_sha256": "513880b9d1e90fefd6a9e868980a4a30081e5c2cdeec98df7a04184d97eba009",
        "scope": "PC prototype: from level-3 attack; grab distance 0.62 world",
    }))
    defender.queue_free()
    await create_timer(0.1).timeout
    await process_frame
    scene.queue_free()
    await process_frame
    quit(0)


func _start_sequence(player: PortFighter, rage: float) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    player.rage = rage
    if not player.request_attack("high_punch3"):
        push_error("Could not start the level-3 attack")
        return false
    player.record_standing_combo_press("a", ["up"])
    player.record_standing_combo_press("a", ["up"])
    player.record_standing_combo_press("a", ["up"])
    if String(player.get("_standing_combo_pending_attack")) != "special_punch_high_miss":
        push_error("Sequence did not queue special_punch_high_miss")
        return false
    player._advance_timed_states(40.0 / PortFighter.SOURCE_FRAME_RATE)
    return true


func _validate_rage_gate(player: PortFighter) -> bool:
    if not _start_sequence(player, 0.0):
        return false
    if player._try_begin_pending_standing_combo():
        push_error("The special fired below the rage gate")
        return false
    return true


func _validate_multi_hit(player: PortFighter, defender: PortFighter) -> bool:
    if not _start_sequence(player, 70.0):
        return false
    if not player._try_begin_pending_standing_combo():
        push_error("The special did not fire at 70 rage")
        return false
    if player.attack_kind != "special_punch_high_miss":
        push_error("Miss stage selected " + player.attack_kind)
        return false
    if absf(player.rage - 4.0) > 0.001:
        push_error("The special did not consume 66 rage: " + str(player.rage))
        return false
    defender.reset_fighter(Vector3(-1.7, 1.20, 0.0))
    player.facing = 1.0
    player.opponent = defender
    for _i: int in range(20):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.attack_kind != "special_punch_high_hit":
        push_error("The chain did not select the hit: " + player.attack_kind)
        return false
    for _i: int in range(70):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if absf(defender.health - 79.0) > 0.001:
        push_error("The three impacts did not total 21 damage: " + str(defender.health))
        return false
    if defender.last_reaction_source_action != "impacthardfronthigh":
        push_error("The final impact reaction was " + defender.last_reaction_source_action)
        return false
    return true


func _validate_miss_branch(player: PortFighter, defender: PortFighter) -> bool:
    if not _start_sequence(player, 70.0):
        return false
    if not player._try_begin_pending_standing_combo():
        push_error("The miss branch did not fire")
        return false
    defender.reset_fighter(Vector3(2.0, 1.20, 0.0))
    player.opponent = defender
    for _i: int in range(20):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.attack_kind != "special_punch_high_miss":
        push_error("The chain switched without grab distance: " + player.attack_kind)
        return false
    if not is_equal_approx(defender.health, 100.0):
        push_error("The missed special damaged the defender: " + str(defender.health))
        return false
    return true


func _validate_input_mapping(scene: Node, player: PortFighter) -> bool:
    player.facing = 1.0
    Input.action_press("prototype_move_up")
    var up_modifiers: Array = scene._standing_combo_modifiers(player)
    Input.action_release("prototype_move_up")
    if not up_modifiers.has("up"):
        push_error("Real up input did not produce the up token")
        return false
    return true


func _validate_all_blocked(player: PortFighter, defender: PortFighter) -> bool:
    if not _start_sequence(player, 70.0):
        return false
    defender.reset_fighter(Vector3(-1.7, 1.20, 0.0))
    player.facing = 1.0
    player.opponent = defender
    if not player._try_begin_pending_standing_combo():
        push_error("The blocked special did not start")
        return false
    for _i: int in range(20):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        if player.attack_kind == "special_punch_high_hit":
            break
    if player.attack_kind != "special_punch_high_hit":
        push_error("The blocked special did not chain: " + player.attack_kind)
        return false
    defender.guard_held = true
    for _i: int in range(70):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    var expected: float = 100.0 - 21.0 * 0.12
    if absf(defender.health - expected) > 0.01:
        push_error("Blocked multi impacts did not chip all three: " + str(defender.health))
        return false
    if not is_zero_approx(player.rage - 4.0):
        push_error("Blocked multi impacts granted rage: " + str(player.rage))
        return false
    return true

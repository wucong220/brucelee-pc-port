extends SceneTree
## Validate the two-stage special punch low on the 40-clip candidate.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the 40-clip Bruce candidate GLB")
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
        push_error("Special punch low candidate failed: " + player.candidate_load_error)
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    for required: String in ["special_punch_low_miss", "special_punch_low_hit"]:
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
    if not _validate_hit_branch(player, defender):
        quit(1)
        return
    if not _validate_miss_branch(player, defender):
        quit(1)
        return
    print("SPECIAL_PUNCH_LOW_VALIDATION=" + JSON.stringify({
        "special": "specialpunchlow",
        "input": "down+in+a -> out+in+a -> out+in+a",
        "rage_gate": 66.0,
        "hit_damage": 15.0,
        "reaction": "impacthardfronthigh",
        "candidate_bytes": 2453728,
        "candidate_sha256": "77ead1783187b738554a99655cb42cd9f27ca32e47782553dc6e31356c6d58ca",
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
    player.record_standing_combo_press("a", ["down", "in"])
    player.record_standing_combo_press("a", ["out", "in"])
    player.record_standing_combo_press("a", ["out", "in"])
    if String(player.get("_standing_combo_pending_attack")) != "special_punch_low_miss":
        push_error("Sequence did not queue special_punch_low_miss")
        return false
    player._advance_timed_states(40.0 / PortFighter.SOURCE_FRAME_RATE)
    return true


func _validate_rage_gate(player: PortFighter) -> bool:
    if not _start_sequence(player, 0.0):
        return false
    if player._try_begin_pending_standing_combo():
        push_error("The special fired below the rage gate")
        return false
    if player.attack_kind == "special_punch_low_miss":
        push_error("The sealed attack changed kind below the rage gate")
        return false
    return true


func _validate_hit_branch(player: PortFighter, defender: PortFighter) -> bool:
    if not _start_sequence(player, 70.0):
        return false
    if not player._try_begin_pending_standing_combo():
        push_error("The special did not fire at 70 rage")
        return false
    if player.attack_kind != "special_punch_low_miss":
        push_error("Miss stage selected " + player.attack_kind)
        return false
    if absf(player.rage - 4.0) > 0.001:
        push_error("The special did not consume 66 rage: " + str(player.rage))
        return false
    defender.reset_fighter(Vector3(-1.7, 1.20, 0.0))
    player.facing = 1.0
    player.opponent = defender
    player._advance_timed_states(10.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.attack_kind != "special_punch_low_hit":
        push_error("The chain did not select the hit: " + player.attack_kind)
        return false
    player._advance_timed_states(
        float(player.ATTACKS["special_punch_low_hit"]["startup"]) + 0.001
    )
    if absf(defender.health - 85.0) > 0.001:
        push_error("The special damage was not 15: " + str(defender.health))
        return false
    if defender.last_reaction_source_action != "impacthardfronthigh":
        push_error("The special reaction fell to " + defender.last_reaction_source_action)
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
    player._advance_timed_states(15.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.attack_kind != "special_punch_low_miss":
        push_error("The chain switched without grab distance: " + player.attack_kind)
        return false
    if not is_equal_approx(defender.health, 100.0):
        push_error("The missed special damaged the defender: " + str(defender.health))
        return false
    return true

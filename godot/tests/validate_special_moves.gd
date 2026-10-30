extends SceneTree
## Validate the rage-gated special kick high against the 31-clip candidate.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the 31-clip Bruce candidate GLB")
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
    var opponent: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    opponent.set_physics_process(false)
    if not player.candidate_loaded:
        push_error("Special candidate failed to load: " + player.candidate_load_error)
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    if not clips.has("special_kick_high"):
        push_error("Candidate is missing special_kick_high")
        quit(1)
        return
    if not _validate_insufficient_rage(player):
        quit(1)
        return
    if not _validate_backstep_gate(player):
        quit(1)
        return
    if not await _validate_special_hit(player, opponent):
        quit(1)
        return
    print("SPECIAL_MOVE_VALIDATION=" + JSON.stringify({
        "special": "specialkickhigh",
        "input": "back+b -> toward+c -> toward+c",
        "rage_gate": 33.0,
        "damage": 12.0,
        "attack_radius": 115.0,
        "reaction": "fail-closed empty; hard/high/frontal reaction clip unsupported by the converter",
        "scope": "PC prototype rage meter; native rage scale unverified",
    }))
    await create_timer(0.1).timeout
    await process_frame
    scene.queue_free()
    await process_frame
    quit(0)


func _validate_insufficient_rage(player: PortFighter) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    player.rage = 0.0
    if not player.request_attack("punch"):
        push_error("Could not start the low punch before the special check")
        return false
    player.record_standing_combo_press("b", ["out"])
    player.record_standing_combo_press("c", ["in"])
    player.record_standing_combo_press("c", ["in"])
    if String(player.get("_standing_combo_pending_attack")) != "special_kick_high":
        push_error("The special sequence did not queue special_kick_high")
        return false
    player._advance_timed_states(22.0 / PortFighter.SOURCE_FRAME_RATE)
    if player._try_begin_pending_standing_combo():
        push_error("The special fired without enough rage")
        return false
    if player.attack_kind != "punch":
        push_error("The failed special changed the current attack")
        return false
    return true


func _validate_backstep_gate(player: PortFighter) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    player.rage = 40.0
    if not player.request_attack("punch"):
        push_error("Could not start the plain attack for the backstep check")
        return false
    # The same key pattern without the backstep first press must not select the
    # special; b,c,c is the unrelated high kick sequence.
    player.record_standing_combo_press("b")
    player.record_standing_combo_press("c", ["in"])
    player.record_standing_combo_press("c", ["in"])
    if String(player.get("_standing_combo_pending_attack")) == "special_kick_high":
        push_error("The special matched without a backstep first press")
        return false
    player._advance_timed_states(22.0 / PortFighter.SOURCE_FRAME_RATE)
    player._try_begin_pending_standing_combo()
    if player.attack_kind == "special_kick_high":
        push_error("The special fired without a backstep first press")
        return false
    return true


func _validate_special_hit(player: PortFighter, opponent: PortFighter) -> bool:
    var defender: PortFighter = load("res://scripts/fighter.gd").new()
    defender.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(defender)
    await process_frame
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    defender.reset_fighter(Vector3(2.0, 1.20, 0.0))
    player.opponent = defender
    player.facing = 1.0
    player._time = 0.0
    player.rage = 40.0
    if not player.request_attack("punch"):
        push_error("Could not start the low punch before the special")
        return false
    player.record_standing_combo_press("b", ["out"])
    player.record_standing_combo_press("c", ["in"])
    player.record_standing_combo_press("c", ["in"])
    player._advance_timed_states(22.0 / PortFighter.SOURCE_FRAME_RATE)
    if not player._try_begin_pending_standing_combo():
        push_error("The special did not transition with enough rage")
        return false
    if player.attack_kind != "special_kick_high":
        push_error("The special selected " + player.attack_kind)
        return false
    if player.current_source_animation() != "m01_kck_front_step":
        push_error("The special requested " + player.current_source_animation())
        return false
    if absf(player.rage - 7.0) > 0.001:
        push_error("The special did not consume 33 rage: " + str(player.rage))
        return false
    defender.global_position = Vector3(-1.75, 1.20, 0.0)
    player.facing = 1.0
    player._advance_timed_states(
        float(player.ATTACKS["special_kick_high"]["startup"]) + 0.001
    )
    if absf(defender.health - 88.0) > 0.001:
        push_error("The special damage was not 12: " + str(defender.health))
        return false
    # The hard/high/frontal reaction clip cannot be bundled yet, so the native
    # reaction link is fail-closed (empty) rather than silently downgraded.
    if not defender.last_reaction_source_action.is_empty():
        push_error("The special reaction unexpectedly mapped to "
                + defender.last_reaction_source_action)
        return false
    if absf(player.rage - 17.0) > 0.001:
        push_error("A landed special did not grant 10 rage: " + str(player.rage))
        return false
    defender.queue_free()
    return true

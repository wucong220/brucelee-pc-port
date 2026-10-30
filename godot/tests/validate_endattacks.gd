extends SceneTree
## Validate the grab-based endattack1 finisher candidate.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the 46-clip Bruce candidate GLB")
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
        push_error("Endattack candidate failed: " + player.candidate_load_error)
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    for required: String in ["grab1", "endattack1", "endattack2"]:
        if not clips.has(required):
            push_error("Candidate is missing " + required)
            quit(1)
            return
    var defender: PortFighter = load("res://scripts/fighter.gd").new()
    defender.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(defender)
    await process_frame
    if not _validate_endattack1(player, defender):
        quit(1)
        return
    if not _validate_endattack2(player, defender):
        quit(1)
        return
    if not _validate_blocked_grab_rejects_endattack(player, defender):
        quit(1)
        return
    print("ENDATTACK_VALIDATION=" + JSON.stringify({
        "endattack1": "m01_end_attack_01",
        "source_damage": 0.0,
        "candidate_bytes": 3964068,
        "candidate_sha256": "de6819927bf7cb642e2f95e802b283c5ec06a181c37f54f5321c8468802310dd",
        "scope": "PC prototype: grab leaves the opponent controlled; original impact damage is zero",
    }))
    defender.queue_free()
    await create_timer(0.1).timeout
    await process_frame
    scene.queue_free()
    await process_frame
    quit(0)


func _validate_endattack1(player: PortFighter, defender: PortFighter) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    player.rage = 70.0
    player.facing = 1.0
    defender.reset_fighter(Vector3(-1.9, 1.20, 0.0))
    player.opponent = defender
    if not player.request_attack("punch"):
        return false
    player.record_standing_combo_press("a", ["left"])
    player.record_standing_combo_press("a")
    player.record_standing_combo_press("a")
    player._advance_timed_states(40.0 / PortFighter.SOURCE_FRAME_RATE)
    if not player._try_begin_pending_standing_combo():
        push_error("Grab1 did not start")
        return false
    for _i: int in range(47):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    var health_before: float = defender.health
    player.record_standing_combo_press("b", ["up", "in"])
    player.record_standing_combo_press("a")
    player.record_standing_combo_press("a")
    if player.attack_kind != "endattack1":
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        if not player._try_begin_pending_standing_combo():
            push_error("Endattack1 did not start from the grab")
            return false
    if player.attack_kind != "endattack1":
        push_error("Expected endattack1, got " + player.attack_kind)
        return false
    if player.current_source_animation() != "m01_end_attack_01":
        push_error("Endattack1 requested " + player.current_source_animation())
        return false
    for _i: int in range(380):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if absf(defender.health - health_before) > 0.001:
        push_error("Endattack1 invented damage: " + str(defender.health))
        return false
    if not bool(player.get("_grab_connected")):
        push_error("Successful grab did not keep the grab-connected flag")
        return false
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    if bool(player.get("_grab_connected")):
        push_error("reset_fighter did not clear the grab-connected flag")
        return false
    return true


func _validate_endattack2(player: PortFighter, defender: PortFighter) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    player.rage = 70.0
    player.facing = 1.0
    defender.reset_fighter(Vector3(-1.9, 1.20, 0.0))
    player.opponent = defender
    if not player.request_attack("kick"):
        return false
    player.record_standing_combo_press("b", ["left"])
    player.record_standing_combo_press("c")
    player.record_standing_combo_press("c")
    player._advance_timed_states(40.0 / PortFighter.SOURCE_FRAME_RATE)
    if not player._try_begin_pending_standing_combo():
        push_error("Grab2 did not start")
        return false
    for _i: int in range(80):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    var health_before: float = defender.health
    player.record_standing_combo_press("a", ["up", "in"])
    player.record_standing_combo_press("c")
    player.record_standing_combo_press("c")
    if player.attack_kind != "endattack2":
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        if not player._try_begin_pending_standing_combo():
            push_error("Endattack2 did not start from grab2")
            return false
    if player.current_source_animation() != "m01_end_attack_02":
        push_error("Endattack2 requested " + player.current_source_animation())
        return false
    for _i: int in range(240):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if absf(defender.health - health_before) > 0.001:
        push_error("Endattack2 invented damage")
        return false
    return true


func _validate_blocked_grab_rejects_endattack(player: PortFighter, defender: PortFighter) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    player.rage = 70.0
    player.facing = 1.0
    defender.reset_fighter(Vector3(-1.9, 1.20, 0.0))
    player.opponent = defender
    if not player.request_attack("punch"):
        return false
    player.record_standing_combo_press("a", ["left"])
    player.record_standing_combo_press("a")
    player.record_standing_combo_press("a")
    player._advance_timed_states(40.0 / PortFighter.SOURCE_FRAME_RATE)
    if not player._try_begin_pending_standing_combo():
        push_error("Blocked-grab setup did not start grab1")
        return false
    defender.reset_fighter(Vector3(-1.9, 1.20, 0.0))
    defender.guard_held = true
    player.opponent = defender
    for _i: int in range(47):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if bool(player.get("_grab_connected")):
        push_error("A blocked grab set the grab-connected flag")
        return false
    player.record_standing_combo_press("b", ["up", "in"])
    player.record_standing_combo_press("a")
    player.record_standing_combo_press("a")
    if player._try_begin_pending_standing_combo():
        push_error("Endattack started after a blocked grab")
        return false
    if player.attack_kind in ["endattack1", "endattack2"]:
        push_error("Blocked grab changed into an endattack")
        return false
    return true

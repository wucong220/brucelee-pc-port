extends SceneTree
## Headless smoke test for the original placeholder combat scene.
## Run after importing the project with Godot 4:
## godot --headless --path godot --script res://tests/smoke_test.gd

const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")


func _initialize() -> void:
    call_deferred("_run_check")


func _press_key(key: Key) -> void:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = key
    event.pressed = true
    root.push_input(event, true)
    var released: InputEventKey = InputEventKey.new()
    released.keycode = key
    released.pressed = false
    root.push_input(released, true)


func _attack_hits_after_frames(player: PortFighter, opponent: PortFighter, kind: String,
        before_frame: float, advance_frames: float) -> bool:
    player.reset_fighter(Vector3(-1.5, 1.2, 0.0))
    opponent.reset_fighter(Vector3(1.5, 1.2, 0.0))
    if not player.request_attack(kind):
        push_error("Could not start %s boundary test" % kind)
        return false
    var startup_frames: float = (float(PortFighter.ATTACKS[kind]["startup"])
            * PortFighter.SOURCE_FRAME_RATE)
    if before_frame <= startup_frames:
        player._physics_process(before_frame / PortFighter.SOURCE_FRAME_RATE)
    else:
        player._physics_process((startup_frames + 0.001) / PortFighter.SOURCE_FRAME_RATE)
        player._physics_process((before_frame - startup_frames - 0.001)
                / PortFighter.SOURCE_FRAME_RATE)
    opponent.position.x = -0.3
    player._physics_process(advance_frames / PortFighter.SOURCE_FRAME_RATE)
    return opponent.health < PortFighter.MAX_HEALTH


func _run_check() -> void:
    var repository_root: String = CandidatePathGuard.repository_root()
    var outside_path: String = repository_root.get_base_dir().path_join(
        "candidate-outside-fixture.glb"
    )
    if not CandidatePathGuard.external_path_error(
            outside_path, "candidate path").is_empty():
        push_error("Candidate path guard rejected an external fixture path")
        quit(1)
        return
    for repository_path: String in [
            repository_root,
            repository_root.path_join("candidate.glb"),
            repository_root.path_join("godot/candidate.glb")]:
        if CandidatePathGuard.external_path_error(
                repository_path, "candidate path").is_empty():
            push_error("Candidate path guard accepted a repository path")
            quit(1)
            return

    var previous_preview_glb: String = OS.get_environment("BRUCELEE_CANDIDATE_GLB")
    OS.set_environment(
        "BRUCELEE_CANDIDATE_GLB", repository_root.path_join("candidate.glb")
    )
    var preview: Node3D = load("res://scripts/candidate_preview.gd").new()
    root.add_child(preview)
    if not String(preview.get("load_error")).contains("outside the repository"):
        push_error("Candidate preview accepted a repository GLB")
        quit(1)
        return
    preview.queue_free()
    OS.set_environment("BRUCELEE_CANDIDATE_GLB", previous_preview_glb)

    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        push_error("Cannot load the placeholder combat scene")
        quit(1)
        return
    var scene: Node = packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    # Keep the fighters' physics active while excluding random AI decisions.
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var opponent: PortFighter = scene.get("computer")
    if player == null or opponent == null:
        push_error("Fighters are missing after scene initialization")
        quit(1)
        return
    var punch_startup: float = float(PortFighter.ATTACKS["punch"]["startup"])
    var punch_active: float = float(PortFighter.ATTACKS["punch"]["active"])
    var punch_recovery: float = float(PortFighter.ATTACKS["punch"]["recovery"])
    var kick_startup: float = float(PortFighter.ATTACKS["kick"]["startup"])
    if (absf(punch_startup * PortFighter.SOURCE_FRAME_RATE - 5.0) > 0.001
            or absf(punch_active * PortFighter.SOURCE_FRAME_RATE - 4.0) > 0.001
            or absf(punch_recovery * PortFighter.SOURCE_FRAME_RATE - 60.0) > 0.001
            or float(PortFighter.ATTACKS["punch"]["damage"]) != 5.0
            or absf(kick_startup * PortFighter.SOURCE_FRAME_RATE - 7.0) > 0.001
            or absf(float(PortFighter.ATTACKS["kick"]["active"]) * PortFighter.SOURCE_FRAME_RATE - 4.0) > 0.001
            or absf(float(PortFighter.ATTACKS["kick"]["recovery"]) * PortFighter.SOURCE_FRAME_RATE - 75.0) > 0.001
            or float(PortFighter.ATTACKS["kick"]["damage"]) != 5.0):
        push_error("Recovered lowpunch1/lowkick1 timing or damage constants changed")
        quit(1)
        return
    if (PortFighter.ATTACKS["punch"]["source_impact"] != {
                "attack_radius": 70.0, "body_part": "larm", "height": "medium",
                "strength": "normal", "direction": "frontal",
            }
            or PortFighter.ATTACKS["kick"]["source_impact"] != {
                "attack_radius": 70.0, "body_part": "lleg", "height": "low",
                "strength": "normal", "direction": "frontal",
            }):
        push_error("Recovered fighting-set impact metadata changed")
        quit(1)
        return

    player.reset_fighter(Vector3(-0.75, 1.2, 1.0))
    opponent.reset_fighter(Vector3(0.75, 1.2, -1.0))
    scene.set("ai_timer", 0.0)
    scene.call("_think_ai", 0.016)
    if opponent.move_axis.y <= 0.0 or opponent.state != "idle":
        push_error("AI did not pursue a side-stepping player without attacking out of range")
        quit(1)
        return
    var initial_z_gap: float = absf(player.position.z - opponent.position.z)
    for frame in range(20):
        await physics_frame
    if absf(player.position.z - opponent.position.z) >= initial_z_gap - 0.2:
        push_error("AI did not close the lateral gap")
        quit(1)
        return
    opponent.position.z = player.position.z
    scene.set("ai_timer", 0.0)
    scene.call("_think_ai", 0.016)
    if opponent.state != "startup":
        push_error("AI did not attack after aligning with the player")
        quit(1)
        return

    # Drive fixed physics steps to place the opponent into range after startup.
    player.set_physics_process(false)
    opponent.set_physics_process(false)
    player.reset_fighter(Vector3(-0.6, 1.2, 0.0))
    opponent.reset_fighter(Vector3(-0.3, 1.2, 0.0))
    if not player.request_attack("punch"):
        push_error("Could not start the large-delta timing test")
        quit(1)
        return
    player._physics_process(1.0)
    if absf(opponent.health - 95.0) > 0.001 or player.combo_hits != 1:
        push_error("Large-delta update lost or duplicated the attack window")
        quit(1)
        return
    var punch_boundaries: Array[bool] = [
        _attack_hits_after_frames(player, opponent, "punch", 4.0, 0.6),
        _attack_hits_after_frames(player, opponent, "punch", 4.5, 0.6),
        _attack_hits_after_frames(player, opponent, "punch", 7.5, 1.0),
        _attack_hits_after_frames(player, opponent, "punch", 9.0, 0.6),
    ]
    var kick_boundaries: Array[bool] = [
        _attack_hits_after_frames(player, opponent, "kick", 6.0, 0.6),
        _attack_hits_after_frames(player, opponent, "kick", 6.5, 0.6),
        _attack_hits_after_frames(player, opponent, "kick", 9.5, 1.0),
        _attack_hits_after_frames(player, opponent, "kick", 11.0, 0.6),
    ]
    if punch_boundaries != [false, true, true, false]:
        push_error("lowpunch1 hit window does not match frames 5..8: "
                + JSON.stringify(punch_boundaries))
        quit(1)
        return
    if kick_boundaries != [false, true, true, false]:
        push_error("lowkick1 hit window does not match frames 7..10: "
                + JSON.stringify(kick_boundaries))
        quit(1)
        return
    player.reset_fighter(Vector3(-1.5, 1.2, 0.0))
    opponent.reset_fighter(Vector3(1.5, 1.2, 0.0))
    if not player.request_attack("punch"):
        push_error("Could not start the active-window test")
        quit(1)
        return
    player._physics_process(punch_startup + 0.001)
    if player.state != "active" or opponent.health != 100.0:
        push_error("Out-of-range target was hit at the start of the active window")
        quit(1)
        return
    opponent.position.x = -0.3
    player._physics_process(0.016)
    player._physics_process(0.016)
    player._physics_process(0.016)
    if absf(opponent.health - 95.0) > 0.001 or player.combo_hits != 1:
        push_error("Active-window contact did not hit exactly once")
        quit(1)
        return
    player._physics_process(punch_active + 0.01)
    player._physics_process(punch_recovery + 0.01)
    opponent.reset_fighter(Vector3(-0.3, 1.2, 0.0))
    if not player.request_attack("punch"):
        push_error("Could not start a second attack")
        quit(1)
        return
    opponent.guard_held = true
    player._physics_process(punch_startup + 0.001)
    player._physics_process(0.016)
    if absf(opponent.health - 99.4) > 0.001 or player.combo_hits != 2:
        push_error("Second attack did not register exactly one guarded contact")
        quit(1)
        return
    player.reset_fighter(Vector3(-1.5, 1.2, 0.0))
    opponent.reset_fighter(Vector3(1.5, 1.2, 0.0))
    player.request_attack("punch")
    player._physics_process(punch_startup + 0.001)
    player.receive_hit(1.0, false, 0.0, -1.0)
    opponent.position.x = -0.3
    player._physics_process(0.016)
    if opponent.health != 100.0:
        push_error("Interrupted attack registered a contact")
        quit(1)
        return
    player.reset_fighter(Vector3(-1.5, 1.2, 0.0))
    opponent.reset_fighter(Vector3(1.5, 1.2, 0.0))
    player.request_attack("punch")
    player._physics_process(punch_startup + 0.001)
    player.receive_hit(1000.0, false, 0.0, -1.0)
    opponent.position.x = -0.3
    player._physics_process(0.016)
    if player.state != "ko" or opponent.health != 100.0:
        push_error("KO did not stop the active attack")
        quit(1)
        return
    scene.call("_reset_match")
    player.set_physics_process(true)
    opponent.set_physics_process(true)

    player.reset_fighter(Vector3(-0.6, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.6, 1.2, 0.0))
    _press_key(KEY_J)
    await process_frame
    if player.state != "startup" or player.attack_kind != "punch":
        push_error("J did not start a punch")
        quit(1)
        return
    for frame in range(30):
        await physics_frame
    var punch_health: float = opponent.health
    if absf(punch_health - 95.0) > 0.001:
        push_error("Punch did not apply the recovered fighting-set damage")
        quit(1)
        return

    player.reset_fighter(Vector3(-0.6, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.6, 1.2, 0.0))
    opponent.guard_held = true
    _press_key(KEY_K)
    await process_frame
    if player.state != "startup" or player.attack_kind != "kick":
        push_error("K did not start a kick")
        quit(1)
        return
    for frame in range(45):
        await physics_frame
    var blocked_health: float = opponent.health
    if absf(blocked_health - 99.4) > 0.001:
        push_error("Blocked kick did not apply the recovered fighting-set damage")
        quit(1)
        return

    player.set_physics_process(false)
    opponent.set_physics_process(false)
    player.reset_fighter(Vector3(-0.6, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.6, 1.2, 0.0))
    opponent.health = 5.0
    player.request_attack("punch")
    player._physics_process(punch_startup + 0.001)
    var hud: PortHUD = scene.get("hud")
    if not scene.get("done") or not hud.center_message.text.begins_with("YOU WIN"):
        push_error("A finishing hit did not preserve the win message")
        quit(1)
        return
    player.state = "idle"
    _press_key(KEY_J)
    await process_frame
    if player.state != "idle":
        push_error("Attack was accepted after the round ended")
        quit(1)
        return
    _press_key(KEY_R)
    await process_frame
    if scene.get("done") or player.health != 100.0 or opponent.health != 100.0:
        push_error("R did not restart the round")
        quit(1)
        return
    player.reset_fighter(Vector3(-0.6, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.6, 1.2, 0.0))
    player.health = 5.0
    opponent.request_attack("punch")
    opponent._physics_process(kick_startup + 0.001)
    if not scene.get("done") or not hud.center_message.text.begins_with("YOU LOSE"):
        push_error("An opponent finishing hit did not preserve the loss message")
        quit(1)
        return
    print("PROTOTYPE_VALIDATION=" + JSON.stringify({
        "punch_target_health": punch_health,
        "blocked_kick_target_health": blocked_health,
        "ko_and_restart": true,
    }))
    quit(0)

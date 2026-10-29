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
    var startup_frames: float = (float(player.ATTACKS[kind]["startup"])
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


func _raw_attack_entry(action: String) -> Dictionary:
    var is_punch: bool = action == "punch"
    return {
        "source_action": "lowpunch1" if is_punch else "lowkick1",
        "animation": "m01_pnch_low_01" if is_punch else "m01_kick_low_01",
        "animation_frame_count": 69 if is_punch else 86,
        "startup_frames": 5 if is_punch else 7,
        "active_frames": 4,
        "recovery_frames": 60 if is_punch else 75,
        "damage": 5.0,
        "prototype_push": 0.2 if is_punch else 0.35,
        "source_impact": {
            "attack_radius": 70.0,
            "body_part": "larm" if is_punch else "lleg",
            "height": "medium" if is_punch else "low",
            "strength": "normal",
            "direction": "frontal",
        },
    }


func _raw_attack_config() -> Dictionary:
    return {
        "schema_version": 2,
        "source_archive": "brucelee.set",
        "frame_rate": 30.0,
        "source_geometry": {
            "source_height": 173.415954589844,
            "world_height": 1.8,
            "radius_scale": 1.0,
            "action_radii": {
                "idle": 50.0,
                "punch": 40.0,
                "kick": 50.0,
            },
        },
        "attacks": {
            "punch": _raw_attack_entry("punch"),
            "kick": _raw_attack_entry("kick"),
        },
    }


func _config_negative_check(player: PortFighter) -> bool:
    var cases: Array[Dictionary] = []
    var wrong_rate: Dictionary = _raw_attack_config()
    wrong_rate["frame_rate"] = 29.0
    cases.append(wrong_rate)
    var fractional: Dictionary = _raw_attack_config()
    fractional["attacks"]["punch"]["startup_frames"] = 5.5
    cases.append(fractional)
    var invalid_enum: Dictionary = _raw_attack_config()
    invalid_enum["attacks"]["punch"]["source_impact"]["body_part"] = "tail"
    cases.append(invalid_enum)
    var wrong_total: Dictionary = _raw_attack_config()
    wrong_total["attacks"]["punch"]["recovery_frames"] = 59
    cases.append(wrong_total)
    var wrong_source: Dictionary = _raw_attack_config()
    wrong_source["attacks"]["kick"]["source_action"] = "other"
    cases.append(wrong_source)
    var fractional_schema: Dictionary = _raw_attack_config()
    fractional_schema["schema_version"] = 1.5
    cases.append(fractional_schema)
    var wrong_radius: Dictionary = _raw_attack_config()
    wrong_radius["source_geometry"]["action_radii"]["punch"] = 41.0
    cases.append(wrong_radius)
    var wrong_scale: Dictionary = _raw_attack_config()
    wrong_scale["source_geometry"]["radius_scale"] = 0.75
    cases.append(wrong_scale)
    var wrong_height: Dictionary = _raw_attack_config()
    wrong_height["source_geometry"]["source_height"] = 170.0
    cases.append(wrong_height)
    var missing_idle_radius: Dictionary = _raw_attack_config()
    missing_idle_radius["source_geometry"]["action_radii"].erase("idle")
    cases.append(missing_idle_radius)
    var missing_geometry: Dictionary = _raw_attack_config()
    missing_geometry.erase("source_geometry")
    cases.append(missing_geometry)
    for index in range(cases.size()):
        if not player._parse_attack_config(cases[index]).is_empty():
            push_error("Invalid fighting-set config case was accepted: %d" % index)
            return false
    return true


func _path_guard_check() -> bool:
    var repository_root: String = CandidatePathGuard.repository_root()
    var token: String = str(Time.get_ticks_usec())
    var temp_root: String = OS.get_temp_dir().path_join(
        "brucelee-path-guard-" + token
    )
    var external_file: String = temp_root.path_join("candidate-outside-fixture.glb")
    var repository_fixture: String = repository_root.path_join(
        ".path-guard-fixture-" + token
    )
    var repository_file: String = repository_fixture.path_join("candidate.glb")
    var junction_path: String = temp_root.path_join("repository-junction")
    var passed: bool = true

    if DirAccess.make_dir_absolute(temp_root) != OK:
        push_error("Could not create candidate path guard temp directory")
        return false
    if DirAccess.make_dir_absolute(repository_fixture) != OK:
        push_error("Could not create candidate path guard repository fixture")
        DirAccess.remove_absolute(temp_root)
        return false
    var external_handle: FileAccess = FileAccess.open(external_file, FileAccess.WRITE)
    var repository_handle: FileAccess = FileAccess.open(repository_file, FileAccess.WRITE)
    if external_handle == null or repository_handle == null:
        push_error("Could not create candidate path guard fixture files")
        if external_handle != null:
            external_handle.close()
        if repository_handle != null:
            repository_handle.close()
        passed = false
    else:
        external_handle.store_string("external fixture")
        external_handle.close()
        repository_handle.store_string("repository fixture")
        repository_handle.close()

    var external_error: String = CandidatePathGuard.external_path_error(
        external_file, "candidate path"
    )
    if passed and not external_error.is_empty():
        push_error("Candidate path guard rejected an external fixture path: "
                + external_error)
        passed = false

    for repository_path: String in [
            repository_root,
            repository_root.path_join("candidate.glb"),
            repository_root.path_join("godot/candidate.glb")]:
        if CandidatePathGuard.external_path_error(
                repository_path, "candidate path").is_empty():
            push_error("Candidate path guard accepted a repository path")
            passed = false

    var junction_output: Array = []
    var junction_command: String = "mklink /J \"%s\" \"%s\"" % [
        junction_path.replace("/", "\\"),
        repository_fixture.replace("/", "\\"),
    ]
    var junction_exit: int = OS.execute(
        "cmd.exe",
        PackedStringArray(["/d", "/s", "/c", junction_command]),
        junction_output,
        true,
        false,
    )
    if junction_exit != 0:
        push_error("Could not create candidate path guard junction: "
                + "\n".join(PackedStringArray(junction_output)))
        passed = false
    elif CandidatePathGuard.external_path_error(
            junction_path.path_join("candidate.glb"), "candidate path").is_empty():
        push_error("Candidate path guard accepted an external junction into the repository")
        passed = false

    if junction_exit == 0:
        var remove_output: Array = []
        var remove_command: String = "rmdir \"%s\"" % junction_path.replace("/", "\\")
        var remove_exit: int = OS.execute(
            "cmd.exe",
            PackedStringArray(["/d", "/s", "/c", remove_command]),
            remove_output,
            true,
            false,
        )
        if remove_exit != 0:
            push_error("Could not remove candidate path guard junction: "
                    + "\n".join(PackedStringArray(remove_output)))
            passed = false

    if FileAccess.file_exists(repository_file):
        DirAccess.remove_absolute(repository_file)
    if FileAccess.file_exists(external_file):
        DirAccess.remove_absolute(external_file)
    if DirAccess.dir_exists_absolute(repository_fixture):
        DirAccess.remove_absolute(repository_fixture)
    if DirAccess.dir_exists_absolute(temp_root):
        DirAccess.remove_absolute(temp_root)
    return passed


func _run_check() -> void:
    if not _path_guard_check():
        quit(1)
        return

    var previous_preview_glb: String = OS.get_environment("BRUCELEE_CANDIDATE_GLB")
    OS.set_environment(
        "BRUCELEE_CANDIDATE_GLB",
        CandidatePathGuard.repository_root().path_join("candidate.glb"),
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
    var punch_startup: float = float(player.ATTACKS["punch"]["startup"])
    var punch_active: float = float(player.ATTACKS["punch"]["active"])
    var punch_recovery: float = float(player.ATTACKS["punch"]["recovery"])
    var kick_startup: float = float(player.ATTACKS["kick"]["startup"])
    if (absf(punch_startup * PortFighter.SOURCE_FRAME_RATE - 5.0) > 0.001
            or absf(punch_active * PortFighter.SOURCE_FRAME_RATE - 4.0) > 0.001
            or absf(punch_recovery * PortFighter.SOURCE_FRAME_RATE - 60.0) > 0.001
            or float(player.ATTACKS["punch"]["damage"]) != 5.0
            or absf(kick_startup * PortFighter.SOURCE_FRAME_RATE - 7.0) > 0.001
            or absf(float(player.ATTACKS["kick"]["active"]) * PortFighter.SOURCE_FRAME_RATE - 4.0) > 0.001
            or absf(float(player.ATTACKS["kick"]["recovery"]) * PortFighter.SOURCE_FRAME_RATE - 75.0) > 0.001
            or float(player.ATTACKS["kick"]["damage"]) != 5.0):
        push_error("Recovered lowpunch1/lowkick1 timing or damage constants changed")
        quit(1)
        return
    if (player.ATTACKS["punch"]["source_impact"] != {
                "attack_radius": 70.0, "body_part": "larm", "height": "medium",
                "strength": "normal", "direction": "frontal",
            }
            or player.ATTACKS["kick"]["source_impact"] != {
                "attack_radius": 70.0, "body_part": "lleg", "height": "low",
                "strength": "normal", "direction": "frontal",
            }):
        push_error("Recovered fighting-set impact metadata changed")
        quit(1)
        return
    if (String(player.ATTACKS["punch"]["source_action"]) != "lowpunch1"
            or String(player.ATTACKS["kick"]["source_action"]) != "lowkick1"
            or String(player.ATTACKS["punch"]["animation"]) != "m01_pnch_low_01"
            or String(player.ATTACKS["kick"]["animation"]) != "m01_kick_low_01"
            or int(player.ATTACKS["punch"]["animation_frame_count"]) != 69
            or int(player.ATTACKS["kick"]["animation_frame_count"]) != 86):
        push_error("Fighting-set config source identity changed")
        quit(1)
        return
    if (absf(player.radius_scale - 1.0) > 0.001
            or absf(player.source_units_to_world
                    - PortFighter.CANDIDATE_HEIGHT / PortFighter.CANDIDATE_SOURCE_HEIGHT) > 0.000001
            or player.source_action_radii != {"idle": 50.0, "punch": 40.0, "kick": 50.0}):
        push_error("Source geometry scaling does not match the recovered model")
        quit(1)
        return
    var expected_idle_reach: float = (
        (70.0 + 50.0)
        * PortFighter.CANDIDATE_HEIGHT
        / PortFighter.CANDIDATE_SOURCE_HEIGHT
    )
    if absf(player.attack_reach_world("punch", opponent) - expected_idle_reach) > 0.0001:
        push_error("Recovered source reach does not match attack radius plus target radius")
        quit(1)
        return
    if not player._parse_attack_config({}).is_empty():
        push_error("Invalid fighting-set config was accepted")
        quit(1)
        return
    if not _config_negative_check(player):
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
    opponent.position = Vector3(player.position.x - 1.0, 1.2, player.position.z)
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
    var source_reach: float = expected_idle_reach
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    opponent.reset_fighter(Vector3(source_reach + 0.02, 1.2, 0.0))
    player.request_attack("punch")
    player._advance_timed_states(punch_startup + 0.001)
    player._try_attack_contact()
    if opponent.health != PortFighter.MAX_HEALTH:
        push_error("Target outside the recovered source radius was hit")
        quit(1)
        return
    opponent.position = Vector3(0.95, 1.2, 0.95)
    player._try_attack_contact()
    if opponent.health < PortFighter.MAX_HEALTH:
        push_error("Target outside the recovered Euclidean source radius was hit")
        quit(1)
        return
    opponent.position = Vector3(0.85, 1.2, 0.85)
    player._try_attack_contact()
    if absf(opponent.health - 95.0) > 0.001:
        push_error("Target inside the recovered Euclidean source radius was not hit")
        quit(1)
        return
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    opponent.reset_fighter(Vector3(1.2, 1.2, 0.0))
    opponent.state = "startup"
    opponent.attack_kind = "punch"
    opponent.state_time = punch_startup
    player.request_attack("punch")
    player._advance_timed_states(punch_startup + 0.001)
    player._try_attack_contact()
    if opponent.health != PortFighter.MAX_HEALTH:
        push_error("Target radius did not change with the defender's source animation")
        quit(1)
        return
    opponent.position.x = 1.10
    player._try_attack_contact()
    if absf(opponent.health - 95.0) > 0.001:
        push_error("Target inside the defender punch radius was not hit")
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

    player.reset_fighter(Vector3(-0.45, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.45, 1.2, 0.0))
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
        push_error("Punch did not apply the recovered fighting-set damage: "
                + JSON.stringify({
                    "health": punch_health,
                    "reach": player.attack_reach_world("punch", opponent),
                    "player": player.global_position,
                    "opponent": opponent.global_position,
                    "player_state": player.state,
                    "opponent_state": opponent.state,
                }))
        quit(1)
        return

    player.reset_fighter(Vector3(-0.45, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.45, 1.2, 0.0))
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
    player.reset_fighter(Vector3(-0.45, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.45, 1.2, 0.0))
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
    player.reset_fighter(Vector3(-0.45, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.45, 1.2, 0.0))
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

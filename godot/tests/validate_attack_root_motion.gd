extends SceneTree
## Validate the prototype attack-root interpolation path.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var fighter: PortFighter = load("res://scripts/fighter.gd").new()
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    await process_frame
    if not fighter._attack_root_tracks.has("m01_pnch_low_01"):
        push_error("attack root data missing m01_pnch_low_01")
        quit(1)
        return
    fighter.facing = 1.0
    fighter.attack_kind = "punch"
    fighter.attack_sequence = 1
    fighter.state = "startup"
    fighter.state_time = float(fighter.ATTACKS["punch"]["startup"])
    var before: float = fighter.position.x
    fighter._apply_attack_root_motion()
    if not is_equal_approx(fighter.position.x, before):
        push_error("first attack-root sample should only seed the previous value")
        quit(1)
        return
    fighter.state_time -= 1.0 / PortFighter.SOURCE_FRAME_RATE
    fighter._apply_attack_root_motion()
    if fighter.position.x <= before:
        push_error("attack root motion did not advance position")
        quit(1)
        return
    var moved: float = fighter.position.x - before
    fighter.attack_kind = "grab2"
    fighter.attack_sequence = 2
    fighter.state_time = float(fighter.ATTACKS["grab2"]["startup"])
    var grab_before: float = fighter.position.x
    fighter._apply_attack_root_motion()
    if not is_equal_approx(fighter.position.x, grab_before):
        push_error("grab2 without positions should not move")
        quit(1)
        return
    fighter.attack_kind = "special_kick_low_miss"
    fighter.attack_sequence = 10
    fighter.state = "startup"
    fighter.state_time = float(fighter.ATTACKS["special_kick_low_miss"]["startup"])
    fighter._begin_chained_attack("special_kick_low_hit")
    var chain_before_pos: Vector3 = fighter.position
    fighter.state_time -= 1.0 / PortFighter.SOURCE_FRAME_RATE
    fighter._apply_attack_root_motion()
    var chain_track: Array = fighter._attack_root_tracks[
        String(fighter.ATTACKS["special_kick_low_hit"]["animation"])
    ]
    var chain_raw: Vector3 = chain_track[1] - chain_track[0]
    var chain_expected: Vector2 = Vector2(-chain_raw.y, -chain_raw.x) * fighter.source_units_to_world
    var chain_actual: Vector2 = Vector2(
        fighter.position.x - chain_before_pos.x,
        fighter.position.z - chain_before_pos.z
    )
    if chain_actual.distance_to(chain_expected) > 0.0001:
        push_error("chained attack did not use raw source axes")
        quit(1)
        return
    var brick: PortFighter = load("res://scripts/fighter.gd").new()
    brick.configure_attack_config(PortFighter.BRICK_ATTACK_CONFIG_PATH)
    root.add_child(brick)
    await process_frame
    if not brick._attack_root_tracks.has("m03_pnch_low_01"):
        push_error("Brick attack root data missing m03_pnch_low_01")
        quit(1)
        return
    brick.facing = 1.0
    brick.attack_kind = "punch"
    brick.attack_sequence = 1
    brick.state = "startup"
    brick.state_time = float(brick.ATTACKS["punch"]["startup"])
    var brick_before: float = brick.position.x
    brick._apply_attack_root_motion()
    brick.state_time -= 1.0 / PortFighter.SOURCE_FRAME_RATE
    brick._apply_attack_root_motion()
    if brick.position.x <= brick_before:
        push_error("Brick punch did not use its m03 root data")
        quit(1)
        return
    brick.reset_fighter(Vector3.ZERO)
    brick.attack_kind = "kick"
    brick.attack_sequence = 2
    var kick_track: Array = brick._attack_root_tracks["m03_kck_low_01"]
    var max_x: float = 0.0
    var final_x: float = 0.0
    for frame_index: int in range(kick_track.size()):
        _set_attack_frame(brick, frame_index)
        brick._apply_attack_root_motion()
        max_x = maxf(max_x, brick.position.x)
        final_x = brick.position.x
    if final_x >= max_x - 0.001:
        push_error("Brick kick return stroke did not move back")
        quit(1)
        return
    var lateral_z: Array[float] = []
    for direction: float in [1.0, -1.0]:
        fighter.reset_fighter(Vector3.ZERO)
        fighter.facing = direction
        fighter.attack_kind = "punch"
        fighter.attack_sequence = 3
        _set_attack_frame(fighter, 0)
        fighter._apply_attack_root_motion()
        _set_attack_frame(fighter, 1)
        fighter._apply_attack_root_motion()
        lateral_z.append(fighter.position.z)
    if absf(lateral_z[0]) < 0.000001 or not (lateral_z[0] * lateral_z[1] < 0.0):
        push_error("lateral attack root motion did not follow facing")
        quit(1)
        return
    var runtime: PortFighter = load("res://scripts/fighter.gd").new()
    runtime.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(runtime)
    await process_frame
    runtime.reset_fighter(Vector3(-5.0, 0.0, 0.0))
    if not runtime.request_attack("punch"):
        push_error("real physics attack request was rejected")
        quit(1)
        return
    var runtime_before: float = runtime.position.x
    runtime._physics_process(1.0 / PortFighter.SOURCE_FRAME_RATE)
    runtime._physics_process(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if runtime.position.x <= runtime_before:
        push_error("real physics loop did not apply attack root motion")
        quit(1)
        return
    print("ATTACK_ROOT_MOTION_VALIDATION=" + JSON.stringify({
        "source_action": "lowpunch1",
        "frame_delta": 1.0 / PortFighter.SOURCE_FRAME_RATE,
        "world_delta": moved,
        "scope": "source axes verified: movefwd/stepfwd=-Y, moveback/stepback=+Y, steplft=+X, steprht=-X; per-attack status EMPIRICAL/UNVERIFIED",
    }))
    runtime.queue_free()
    brick.queue_free()
    fighter.queue_free()
    await process_frame
    quit(0)


func _set_attack_frame(fighter: PortFighter, frame_index: int) -> void:
    var details: Dictionary = fighter.ATTACKS[fighter.attack_kind]
    fighter.state = "recovery"
    fighter.state_time = (
        float(details["animation_frame_count"]) - float(frame_index)
    ) / PortFighter.SOURCE_FRAME_RATE

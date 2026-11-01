extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _fighter() -> PortFighter:
    var f: PortFighter = load("res://scripts/fighter.gd").new()
    f.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(f)
    f.set_physics_process(false)
    f.collision_layer = 0
    f.collision_mask = 0
    return f

func _run() -> void:
    var small: PortFighter = _fighter()
    var large: PortFighter = _fighter()
    await process_frame
    small.reset_fighter(Vector3.ZERO)
    large.reset_fighter(Vector3.ZERO)
    if not small.request_attack("punch") or not large.request_attack("punch"):
        push_error("attack request failed")
        quit(1)
        return
    var d: Dictionary = small.ATTACKS["punch"]
    var duration: float = float(d.startup) + float(d.active) + float(d.recovery)
    var track: Array = small._attack_root_tracks[String(d.animation)]
    var raw_delta: Vector3 = track[-1] - track[0]
    var step: float = 1.0 / 120.0
    var elapsed: float = 0.0
    while elapsed < duration + step:
        small._physics_process(step)
        elapsed += step
    large._physics_process(duration + step)
    var small_delta: Vector3 = small.position
    var large_delta: Vector3 = large.position
    print("TIMING_REPRO " + JSON.stringify({"duration": duration, "raw_delta": [raw_delta.x, raw_delta.y, raw_delta.z], "small": [small_delta.x, small_delta.z], "large": [large_delta.x, large_delta.z], "small_state": small.state, "large_state": large.state}))
    if small.state != "idle" or large.state != "idle" or Vector2(small_delta.x, small_delta.z).length() < 0.01 or Vector2(small_delta.x - large_delta.x, small_delta.z - large_delta.z).length() > 0.001:
        push_error("attack root displacement depends on time step")
        quit(1)
        return
    # A chain starts from its own frame zero; no old-track delta leaks across it.
    small.reset_fighter(Vector3.ZERO)
    small.request_attack("punch")
    small._physics_process(0.1)
    small._begin_chained_attack("special_kick_low_hit")
    var chain_origin: Vector3 = small.position
    small._physics_process(1.0 / 30.0)
    var chain_track: Array = small._attack_root_tracks[String(small.ATTACKS["special_kick_low_hit"].animation)]
    var chain_raw: Vector3 = chain_track[1] - chain_track[0]
    var sign_value: float = small._attack_root_forward_signs[String(small.ATTACKS["special_kick_low_hit"].animation)]
    var expected: Vector2 = Vector2(chain_raw.y * sign_value, chain_raw.x) * small.source_units_to_world
    var actual: Vector2 = Vector2(small.position.x - chain_origin.x, small.position.z - chain_origin.z)
    if actual.distance_to(expected) > 0.0001:
        push_error("chain inherited another attack's root sample")
        quit(1)
        return
    # Leaving attack state stops sampling; no deferred motion on cancellation.
    small.state = "idle"
    var cancel_origin: Vector3 = small.position
    small._physics_process(0.1)
    if Vector2(small.position.x - cancel_origin.x, small.position.z - cancel_origin.z).length() > 0.0001:
        push_error("cancelled attack applied root motion")
        quit(1)
        return
    small.queue_free()
    large.queue_free()
    quit(0)

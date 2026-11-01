extends SceneTree
## A large physics step must hit all multi-impact windows, like small steps.

func _initialize() -> void:
    call_deferred("_run")


func _make_fighter() -> PortFighter:
    var fighter: PortFighter = load("res://scripts/fighter.gd").new()
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    return fighter


func _run() -> void:
    var small: PortFighter = _make_fighter()
    var large: PortFighter = _make_fighter()
    var small_target: PortFighter = _make_fighter()
    var large_target: PortFighter = _make_fighter()
    await process_frame
    small.reset_fighter(Vector3(-2.0, 1.2, 0.0))
    large.reset_fighter(Vector3(-2.0, 1.2, 0.0))
    small_target.reset_fighter(Vector3(-1.5, 1.2, 0.0))
    large_target.reset_fighter(Vector3(-1.5, 1.2, 0.0))
    small.opponent = small_target
    large.opponent = large_target
    small.facing = 1.0
    large.facing = 1.0
    if not small.request_attack("special_punch_high_hit"):
        push_error("small-step multi-impact request failed")
        quit(1)
        return
    if not large.request_attack("special_punch_high_hit"):
        push_error("large-step multi-impact request failed")
        quit(1)
        return
    var details: Dictionary = small.ATTACKS["special_punch_high_hit"]
    var duration: float = (
        float(details["startup"]) + float(details["active"]) + float(details["recovery"])
    )
    var step: float = 1.0 / PortFighter.SOURCE_FRAME_RATE
    var elapsed: float = 0.0
    while elapsed < duration + step:
        small._advance_timed_states(step)
        elapsed += step
    large._advance_timed_states(duration + step)
    if not is_equal_approx(small_target.health, 79.0):
        push_error("small-step multi-impact damage was "
            + str(100.0 - small_target.health))
        quit(1)
        return
    if not is_equal_approx(large_target.health, 79.0):
        push_error("large-step multi-impact damage was "
            + str(100.0 - large_target.health))
        quit(1)
        return
    if small.state != "idle" or large.state != "idle":
        push_error("multi-impact attack did not return to idle")
        quit(1)
        return
    print("MULTI_IMPACT_LARGE_STEP_VALIDATION=" + JSON.stringify({
        "small_target_health": small_target.health,
        "large_target_health": large_target.health,
        "expected_damage": 21,
    }))
    small.queue_free()
    large.queue_free()
    small_target.queue_free()
    large_target.queue_free()
    await process_frame
    quit(0)

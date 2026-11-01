extends SceneTree
## Validate the recovered specialpunchlowmiss -> idle [22,25] return.

func _initialize() -> void:
    call_deferred("_run")


func _new_fighter() -> PortFighter:
    var fighter: PortFighter = load("res://scripts/fighter.gd").new()
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    return fighter


func _run() -> void:
    var small: PortFighter = _new_fighter()
    var large: PortFighter = _new_fighter()
    await process_frame
    if not small.request_attack("special_punch_low_miss"):
        push_error("special punch low miss request failed")
        quit(1)
        return
    if not large.request_attack("special_punch_low_miss"):
        push_error("special punch low miss large request failed")
        quit(1)
        return
    # Small steps reach the first frame of the recovered [22,25] return window.
    small._advance_timed_states(15.0 / PortFighter.SOURCE_FRAME_RATE)
    small._advance_timed_states(7.0 / PortFighter.SOURCE_FRAME_RATE)
    if small.state != "idle":
        push_error("small-step miss did not return by frame 22: " + small.state)
        quit(1)
        return
    # One large step must not skip the return window and wait for frame 33.
    large._advance_timed_states(24.0 / PortFighter.SOURCE_FRAME_RATE)
    if large.state != "idle":
        push_error("large-step miss did not return by frame 22: " + large.state)
        quit(1)
        return
    print("SPECIAL_PUNCH_LOW_RETURN_VALIDATION=" + JSON.stringify({
        "return_window": [22, 25],
        "candidate_exit_frame": 22.0,
        "small_state": small.state,
        "large_state": large.state,
    }))
    small.queue_free()
    large.queue_free()
    await process_frame
    quit(0)

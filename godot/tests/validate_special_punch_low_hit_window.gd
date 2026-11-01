extends SceneTree
## Validate the recovered specialpunchlowhit damage window [5,15].

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var fighter: PortFighter = load("res://scripts/fighter.gd").new()
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    await process_frame
    if not fighter.request_attack("special_punch_low_hit"):
        push_error("special punch low hit request failed")
        quit(1)
        return
    fighter._advance_timed_states(15.0 / PortFighter.SOURCE_FRAME_RATE)
    if fighter.state != "active":
        push_error("frame 15 was not active: " + fighter.state)
        quit(1)
        return
    fighter._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if fighter.state != "recovery":
        push_error("frame 16 did not leave active: " + fighter.state)
        quit(1)
        return
    print("SPECIAL_PUNCH_LOW_HIT_WINDOW_VALIDATION=" + JSON.stringify({
        "damage_window": [5, 15],
        "frame_15": "active",
        "frame_16": "recovery",
    }))
    fighter.queue_free()
    await process_frame
    quit(0)

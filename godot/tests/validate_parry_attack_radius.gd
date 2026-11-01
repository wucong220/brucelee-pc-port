extends SceneTree
## Action-specific source radii for shared ANMs.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var fighter: PortFighter = load("res://scripts/fighter.gd").new()
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    await process_frame
    for case: Array in [
        ["parry_attack", 25.0],
        ["parry_low", 40.0],
        ["special_punch_low_miss", 45.0],
    ]:
        fighter.reset_fighter(Vector3.ZERO)
        if not fighter.request_attack(String(case[0])):
            push_error("attack request failed: " + String(case[0]))
            quit(1)
            return
        var actual: float = fighter.source_radius_for_current_animation()
        if absf(actual - float(case[1])) > 0.001:
            push_error(String(case[0]) + " radius was not "
                + str(case[1]) + ": " + str(actual))
            quit(1)
            return
    print("ACTION_RADIUS_VALIDATION=" + JSON.stringify({
        "parry_attack": 25.0,
        "parry_low": 40.0,
        "special_punch_low_miss": 45.0,
    }))
    fighter.queue_free()
    await process_frame
    quit(0)

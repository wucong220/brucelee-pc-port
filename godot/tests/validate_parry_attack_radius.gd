extends SceneTree
## parryattack's ANM is shared with m01_pnch_high_03 but its action radius is 25.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var fighter: PortFighter = load("res://scripts/fighter.gd").new()
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    await process_frame
    if not fighter.request_attack("parry_attack"):
        push_error("parry attack request failed")
        quit(1)
        return
    if absf(fighter.source_radius_for_current_animation() - 25.0) > 0.001:
        push_error("parry_attack radius was not 25: "
            + str(fighter.source_radius_for_current_animation()))
        quit(1)
        return
    print("PARRY_ATTACK_RADIUS_VALIDATION=" + JSON.stringify({
        "animation": fighter.current_source_animation(),
        "radius": fighter.source_radius_for_current_animation(),
    }))
    fighter.queue_free()
    await process_frame
    quit(0)

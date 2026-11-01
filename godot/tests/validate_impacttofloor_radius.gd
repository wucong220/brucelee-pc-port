extends SceneTree
## Validate impacttofloor=75 vs stunfall=70 for the shared source ANM.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var fighter: PortFighter = load("res://scripts/fighter.gd").new()
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    await process_frame
    fighter.state = "impacttofloor"
    if absf(fighter.source_radius_for_current_animation() - 75.0) > 0.001:
        push_error("impacttofloor radius was not 75: "
            + str(fighter.source_radius_for_current_animation()))
        quit(1)
        return
    fighter.state = "stunfall"
    if absf(fighter.source_radius_for_current_animation() - 70.0) > 0.001:
        push_error("stunfall radius was not 70: "
            + str(fighter.source_radius_for_current_animation()))
        quit(1)
        return
    print("IMPACTTOFLOOR_RADIUS_VALIDATION=" + JSON.stringify({
        "impacttofloor": 75.0,
        "stunfall": 70.0,
        "animation": PortFighter.FACEUP_IMPACT_TO_FLOOR_CLIP,
    }))
    fighter.queue_free()
    await process_frame
    quit(0)

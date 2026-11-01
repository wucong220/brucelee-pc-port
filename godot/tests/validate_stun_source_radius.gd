extends SceneTree
## Validate stunned defender source animation and radius mapping.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var fighter: PortFighter = load("res://scripts/fighter.gd").new()
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    await process_frame
    fighter.state = "stun"
    fighter.state_time = 0.0
    if fighter.current_source_animation() != PortFighter.STUN_CLIP:
        push_error("stun did not report all_stunned")
        quit(1)
        return
    if absf(fighter.source_radius_for_current_animation() - 40.0) > 0.001:
        push_error("stun radius was not 40: "
            + str(fighter.source_radius_for_current_animation()))
        quit(1)
        return
    fighter.state = "stunfall"
    fighter.state_time = 0.0
    if fighter.current_source_animation() != PortFighter.STUN_FALL_CLIP:
        push_error("stunfall did not report all_stunned_fall")
        quit(1)
        return
    if absf(fighter.source_radius_for_current_animation() - 70.0) > 0.001:
        push_error("stunfall radius was not 70: "
            + str(fighter.source_radius_for_current_animation()))
        quit(1)
        return
    for case: Array in [["stun_hard", 85.0], ["stun_brutal", 25.0]]:
        fighter.state = "stunimpact"
        fighter.last_reaction_animation = String(case[0])
        if absf(fighter.source_radius_for_current_animation() - float(case[1])) > 0.001:
            push_error("stunimpact alias radius was wrong for " + String(case[0]))
            quit(1)
            return
    print("STUN_SOURCE_RADIUS_VALIDATION=" + JSON.stringify({
        "stun": [PortFighter.STUN_CLIP, 40.0],
        "stunfall": [PortFighter.STUN_FALL_CLIP, 70.0],
        "stunimpact": {"stun_hard": 85.0, "stun_brutal": 25.0},
    }))
    fighter.queue_free()
    await process_frame
    quit(0)

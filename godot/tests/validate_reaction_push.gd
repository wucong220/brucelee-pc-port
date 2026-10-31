extends SceneTree
## Validate that the three exported reaction root-motion depth values drive push.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var fighter: PortFighter = load("res://scripts/fighter.gd").new()
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    await process_frame
    fighter.reset_fighter(Vector3.ZERO)
    var expected: float = 18.252197265625 * fighter.source_units_to_world
    var reaction: Dictionary = {
        "source_action": "impactlightfrontlow",
        "exit_start_frame": 13,
        "animation_duration_frames": 17,
        "linking_frame": 0,
    }
    if not fighter.receive_hit(5.0, false, 0.0, 1.0, reaction):
        push_error("receive_hit rejected the reaction fixture")
        quit(1)
        return
    if absf(fighter.global_position.x - expected) > 0.001:
        push_error("reaction root push mismatch: " + str(fighter.global_position.x) + " expected " + str(expected))
        quit(1)
        return
    print("REACTION_PUSH_VALIDATION=" + JSON.stringify({
        "source_action": "impactlightfrontlow",
        "source_depth": 18.252197265625,
        "world_push": expected,
        "scope": "source positions depth mapped to prototype forward push; axis/sign native mapping unverified",
    }))
    fighter.queue_free()
    await process_frame
    quit(0)

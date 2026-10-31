extends SceneTree
## Validate that the exported reaction root-motion depth values drive push.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var fighter: PortFighter = load("res://scripts/fighter.gd").new()
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    await process_frame
    var cases: Array[Dictionary] = [
        {
            "source_action": "impactlightfrontlow",
            "depth": 18.252197265625,
            "exit_frame": 13,
            "duration": 17,
        },
        {
            "source_action": "impactlightfrontmid",
            "depth": 22.845458984375,
            "exit_frame": 14,
            "duration": 16,
        },
        {
            "source_action": "impactlightfronthigh",
            "depth": 36.86962890625,
            "exit_frame": 13,
            "duration": 17,
        },
    ]
    var results: Array = []
    for case: Dictionary in cases:
        fighter.reset_fighter(Vector3.ZERO)
        var expected: float = float(case["depth"]) * fighter.source_units_to_world
        var reaction: Dictionary = {
            "source_action": String(case["source_action"]),
            "exit_start_frame": int(case["exit_frame"]),
            "animation_duration_frames": int(case["duration"]),
            "linking_frame": 0,
        }
        if not fighter.receive_hit(5.0, false, 0.0, 1.0, reaction):
            push_error("receive_hit rejected " + String(case["source_action"]))
            quit(1)
            return
        if absf(fighter.global_position.x - expected) > 0.001:
            push_error(
                "reaction root push mismatch for " + String(case["source_action"])
                + ": " + str(fighter.global_position.x) + " expected " + str(expected)
            )
            quit(1)
            return
        results.append({
            "source_action": case["source_action"],
            "source_depth": case["depth"],
            "world_push": expected,
        })
    print("REACTION_PUSH_VALIDATION=" + JSON.stringify({
        "cases": results,
        "scope": "source positions depth mapped to prototype forward push; axis/sign native mapping unverified",
    }))
    fighter.queue_free()
    await process_frame
    quit(0)

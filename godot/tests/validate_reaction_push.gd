extends SceneTree
## Validate that the configured source position component drives prototype push.

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
            "source_component": 18.252197265625,
            "exit_frame": 13,
            "duration": 17,
        },
        {
            "source_action": "impactlightfrontmid",
            "source_component": 22.845458984375,
            "exit_frame": 14,
            "duration": 16,
        },
        {
            "source_action": "impactlightfronthigh",
            "source_component": 36.86962890625,
            "exit_frame": 13,
            "duration": 17,
        },
        {
            "source_action": "impactlightleftlow",
            "source_component": 7.284912109375,
            "exit_frame": 15,
            "duration": 17,
        },
        {
            "source_action": "impactlightrightlow",
            "source_component": 21.27294921875,
            "exit_frame": 13,
            "duration": 17,
        },
        {
            "source_action": "impactbrutalleft",
            "source_component": 187.198974609375,
            "exit_frame": 39,
            "duration": 45,
        },
        {
            "source_action": "impactbrutalmid",
            "source_component": 181.56494140625,
            "exit_frame": 25,
            "duration": 28,
        },
        {
            "source_action": "impactbrutalright",
            "source_component": 187.095458984375,
            "exit_frame": 41,
            "duration": 45,
        },
        {
            "source_action": "impacthardabove",
            "source_component": 35.1337890625,
            "exit_frame": 17,
            "duration": 17,
        },
        {
            "source_action": "impacthardfronthigh",
            "source_component": 200.7998046875,
            "exit_frame": 23,
            "duration": 35,
        },
        {
            "source_action": "impacthardfrontlow",
            "source_component": 3.348388671875,
            "exit_frame": 20,
            "duration": 23,
        },
        {
            "source_action": "impacthardfrontmid",
            "source_component": 69.15380859375,
            "exit_frame": 27,
            "duration": 30,
        },
        {
            "source_action": "impacthardlefthigh",
            "source_component": 199.577880859375,
            "exit_frame": 26,
            "duration": 29,
        },
        {
            "source_action": "impacthardleftlow",
            "source_component": 37.691650390625,
            "exit_frame": 25,
            "duration": 29,
        },
        {
            "source_action": "impacthardrighthigh",
            "source_component": 194.52294921875,
            "exit_frame": 26,
            "duration": 29,
        },
    ]
    var results: Array = []
    for case: Dictionary in cases:
        fighter.reset_fighter(Vector3.ZERO)
        var expected: float = float(case["source_component"]) * fighter.source_units_to_world
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
            "source_component": case["source_component"],
            "world_push": expected,
        })
    print("REACTION_PUSH_VALIDATION=" + JSON.stringify({
        "cases": results,
        "scope": "raw source position components mapped to prototype forward push; axis/sign native mapping unverified",
    }))
    fighter.queue_free()
    await process_frame
    quit(0)

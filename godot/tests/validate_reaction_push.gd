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
    var impact_fields: Dictionary = {
        "impactlightfrontlow": ["normal", "low", "frontal"],
        "impactlightfrontmid": ["normal", "medium", "frontal"],
        "impactlightfronthigh": ["normal", "high", "frontal"],
        "impactlightleftlow": ["normal", "low", "fromleft"],
        "impactlightrightlow": ["normal", "low", "fromright"],
        "impactbrutalleft": ["brutal", "high", "fromleft"],
        "impactbrutalmid": ["brutal", "medium", "frontal"],
        "impactbrutalright": ["brutal", "high", "fromright"],
        "impacthardabove": ["hard", "high", "fromabove"],
        "impacthardfronthigh": ["hard", "high", "frontal"],
        "impacthardfrontlow": ["hard", "low", "frontal"],
        "impacthardfrontmid": ["hard", "medium", "frontal"],
        "impacthardlefthigh": ["hard", "high", "fromleft"],
        "impacthardleftlow": ["hard", "low", "fromleft"],
        "impacthardrighthigh": ["hard", "high", "fromright"],
    }
    var results: Array = []
    for case: Dictionary in cases:
        fighter.reset_fighter(Vector3.ZERO)
        var source_action: String = String(case["source_action"])
        var fields: Array = impact_fields[source_action]
        var reaction: Dictionary = fighter.reaction_for_incoming({
            "strength": fields[0],
            "height": fields[1],
            "direction": fields[2],
        }, false)
        if String(reaction.get("source_action", "")) != source_action:
            push_error("reaction_for_incoming did not select " + source_action)
            quit(1)
            return
        if (int(reaction.get("exit_start_frame", -1)) != int(case["exit_frame"])
                or int(reaction.get("animation_duration_frames", -1)) != int(case["duration"])):
            push_error("reaction window mismatch for " + source_action)
            quit(1)
            return
        var expected: float = float(case["source_component"]) * fighter.source_units_to_world
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
    var stun_cases: Array[Dictionary] = [
        {
            "state": "stun",
            "impact": {"strength": "hard", "height": "high", "direction": "frontal"},
            "clip": "stun_hard",
            "source_component": 200.7998046875,
        },
        {
            "state": "stun2",
            "impact": {"strength": "hard", "height": "high", "direction": "frontal"},
            "clip": "stun_hard",
            "source_component": 200.7998046875,
        },
        {
            "state": "stun",
            "impact": {"strength": "brutal", "height": "high", "direction": "frontal"},
            "clip": "stun_brutal",
            "source_component": 187.198974609375,
        },
        {
            "state": "stun2",
            "impact": {"strength": "brutal", "height": "high", "direction": "frontal"},
            "clip": "stun_brutal",
            "source_component": 187.198974609375,
        },
    ]
    for case: Dictionary in stun_cases:
        fighter.reset_fighter(Vector3.ZERO)
        fighter.state = String(case["state"])
        fighter.state_time = 0.0
        fighter._candidate_clip_paths[String(case["clip"])] = "synthetic"
        var reaction: Dictionary = fighter.reaction_for_incoming(case["impact"], false)
        var expected: float = float(case["source_component"]) * fighter.source_units_to_world
        if not fighter.receive_hit(5.0, false, 0.0, 1.0, reaction):
            push_error("stun receive_hit rejected " + String(case["state"]))
            quit(1)
            return
        if absf(fighter.global_position.x - expected) > 0.001:
            push_error("stun reaction push mismatch for " + String(case["state"]))
            quit(1)
            return
        results.append({
            "state": case["state"],
            "source_action": reaction.get("source_action", ""),
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

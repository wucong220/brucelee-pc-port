extends SceneTree
## The PC world scale must be the single source-units conversion used by
## attack reach and root motion; no caller may apply a second scale factor.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var p: PortFighter = load("res://scripts/fighter.gd").new()
    p.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(p)
    p.set_physics_process(false)
    var expected: float = p.WORLD_CHARACTER_HEIGHT / p.SOURCE_CHARACTER_HEIGHT
    if absf(p.source_units_to_world - expected) > 0.0000001:
        push_error("source_units_to_world is not the single PC calibration ratio")
        quit(1)
        return
    var target: PortFighter = load("res://scripts/fighter.gd").new()
    target.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(target)
    target.set_physics_process(false)
    var reach: float = p.attack_reach_world("punch", target)
    var expected_reach: float = (
        float(p.ATTACKS["punch"]["source_impact"]["attack_radius"])
        + target.source_radius_for_current_animation()
    ) * expected
    if absf(reach - expected_reach) > 0.0001:
        push_error("attack reach uses a different scale: " + str(reach)
                + " expected " + str(expected_reach))
        quit(1)
        return
    var root_delta: Vector3 = p._root_motion_delta_to_pc_world(
        Vector3(1.0, 2.0, 0.0), "unknown_clip"
    )
    if absf(root_delta.x - (-2.0) * expected) > 0.0001 or absf(root_delta.z - (-1.0) * expected) > 0.0001:
        push_error("root-motion adapter uses a different scale: " + str(root_delta))
        quit(1)
        return
    print("SCALE_CONSISTENCY_VALIDATION=" + JSON.stringify({
        "source_units_to_world": expected,
        "attack_reach": reach,
        "root_delta": [root_delta.x, root_delta.z],
    }))
    quit(0)

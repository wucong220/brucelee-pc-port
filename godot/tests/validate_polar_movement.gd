extends SceneTree
## The player's WASD is opponent-relative: W/S change radius around the
## midpoint, A/D move tangentially around it.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var p: PortFighter = load("res://scripts/fighter.gd").new()
    var o: PortFighter = load("res://scripts/fighter.gd").new()
    p.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    o.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(p)
    root.add_child(o)
    p.set_physics_process(false)
    o.set_physics_process(false)
    p.global_position = Vector3(-1.0, 1.2, 0.5)
    o.global_position = Vector3(1.0, 1.2, -0.5)
    p.opponent = o
    var center: Vector3 = (p.global_position + o.global_position) * 0.5
    var radial: Vector3 = p.global_position - center
    radial.y = 0.0
    radial = radial.normalized()
    p.move_axis = Vector2(0.0, 1.0)
    var away: Vector3 = p._polar_movement(1.0)
    if away.dot(radial) < 0.99:
        push_error("S is not radial movement away from the midpoint: " + str(away))
        quit(1)
        return
    p.move_axis = Vector2(1.0, 0.0)
    var tangent: Vector3 = p._polar_movement(1.0)
    if absf(tangent.dot(radial)) > 0.01 or tangent.length() < 0.99:
        push_error("D is not tangential movement around the midpoint: " + str(tangent))
        quit(1)
        return
    print("POLAR_MOVEMENT_VALIDATION=" + JSON.stringify({
        "away": [away.x, away.z], "tangent": [tangent.x, tangent.z],
    }))
    quit(0)

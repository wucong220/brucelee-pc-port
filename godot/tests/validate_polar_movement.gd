extends SceneTree
## The player's WASD is opponent-relative: A/D change radius along the
## fighter line, W/S orbit around the midpoint.

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
    p.move_axis = Vector2(1.0, 0.0)
    var radial_d: Vector3 = p._polar_movement(1.0)
    if radial_d.dot(radial) > -0.99:
        push_error("D is not radial movement toward the opponent: " + str(radial_d))
        quit(1)
        return
    p.move_axis = Vector2(0.0, 1.0)
    var angular_s: Vector3 = p._polar_movement(1.0)
    if absf(angular_s.dot(radial)) > 0.01 or angular_s.length() <= 0.01:
        push_error("S is not angular movement around the midpoint: " + str(angular_s))
        quit(1)
        return
    print("POLAR_MOVEMENT_VALIDATION=" + JSON.stringify({
        "radial_d": [radial_d.x, radial_d.z],
        "angular_s": [angular_s.x, angular_s.z],
    }))
    quit(0)

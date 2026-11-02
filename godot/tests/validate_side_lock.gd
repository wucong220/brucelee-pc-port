extends SceneTree
## Side lock: player stays screen-left of the opponent, even after a root-motion
## attack would try to carry either fighter across.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var p: PortFighter = load("res://scripts/fighter.gd").new()
    var o: PortFighter = load("res://scripts/fighter.gd").new()
    p.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    o.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    p.is_player = true
    o.is_player = false
    root.add_child(p)
    root.add_child(o)
    p.set_physics_process(false)
    o.set_physics_process(false)
    p.opponent = o
    o.opponent = p
    p.global_position = Vector3(2.0, 1.2, 0.0)
    o.global_position = Vector3(0.0, 1.2, 0.0)
    p._physics_process(1.0 / 60.0)
    if p.global_position.x > o.global_position.x - 0.07:
        push_error("Player crossed the opponent: player=" + str(p.global_position)
                + " opponent=" + str(o.global_position))
        quit(1)
        return
    p.global_position = Vector3(0.0, 1.2, 0.0)
    o.global_position = Vector3(2.0, 1.2, 0.0)
    o._physics_process(1.0 / 60.0)
    if o.global_position.x < p.global_position.x + 0.07:
        push_error("Opponent crossed the player: player=" + str(p.global_position)
                + " opponent=" + str(o.global_position))
        quit(1)
        return
    print("SIDE_LOCK_VALIDATION=passed")
    quit(0)

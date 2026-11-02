extends SceneTree
## Regression for native step -> move visual/root chain in all four directions.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty():
        push_error("candidate GLB path required")
        quit(1)
        return
    var fighter: PortFighter = load("res://scripts/fighter.gd").new()
    fighter.configure_candidate_asset(args[0], "", PortFighter.CANDIDATE_CLIPS, "body_hair")
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    await process_frame
    if not fighter.candidate_loaded:
        push_error("locomotion candidate failed: " + fighter.candidate_load_error)
        quit(1)
        return
    var cases: Array = [
        ["right", {"right": true}, Vector2(1.0, 0.0), "movefwd", "m02_movefwd", Vector3(1.0, 0.0, 0.0)],
        ["left", {"left": true}, Vector2(-1.0, 0.0), "moveback", "m01_movebck", Vector3(-1.0, 0.0, 0.0)],
        ["up", {"up": true}, Vector2(0.0, -1.0), "moveright", "m01_movelft", Vector3(0.0, 0.0, -1.0)],
        ["down", {"down": true}, Vector2(0.0, 1.0), "moveleft", "m01_moverht", Vector3(0.0, 0.0, 1.0)],
    ]
    for item: Array in cases:
        fighter.reset_fighter(Vector3(0.0, 1.2, 0.0))
        fighter.set_held_directions(item[1])
        fighter.move_axis = item[2]
        for _frame: int in range(20):
            fighter._physics_process(1.0 / 60.0)
        if fighter._locomotion_action != String(item[3]):
            push_error("step did not chain into %s: %s" % [item[3], fighter._locomotion_action])
            quit(1)
            return
        if fighter.candidate_animation_clip != String(item[4]):
            push_error("%s visual clip mismatch: %s" % [item[4], fighter.candidate_animation_clip])
            quit(1)
            return
        var direction: Vector3 = item[5]
        var moved: float = (fighter.global_position - Vector3(0.0, 1.2, 0.0)).dot(direction)
        if moved < 0.2:
            push_error("%s root motion too short: %s" % [item[0], fighter.global_position])
            quit(1)
            return
    print("LOCOMOTION_CHAIN_VALIDATION=passed directions=4")
    quit(0)

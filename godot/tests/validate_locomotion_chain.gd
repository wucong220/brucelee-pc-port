extends SceneTree
## Regression for native step -> move visual/root chain.

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
    fighter.reset_fighter(Vector3(0.0, 1.2, 0.0))
    fighter.set_held_directions({"right": true})
    fighter.move_axis = Vector2(1.0, 0.0)
    for _frame: int in range(20):
        fighter._physics_process(1.0 / 60.0)
    if fighter._locomotion_action != "movefwd":
        push_error("step did not chain into movefwd: " + fighter._locomotion_action)
        quit(1)
        return
    if fighter.candidate_animation_clip != "m02_movefwd":
        push_error("movefwd visual clip mismatch: " + fighter.candidate_animation_clip)
        quit(1)
        return
    if fighter.global_position.x < 0.2:
        push_error("root motion did not advance toward opponent: " + str(fighter.global_position))
        quit(1)
        return
    print("LOCOMOTION_CHAIN_VALIDATION=" + JSON.stringify({
        "action": fighter._locomotion_action,
        "clip": fighter.candidate_animation_clip,
        "position": fighter.global_position,
    }))
    quit(0)

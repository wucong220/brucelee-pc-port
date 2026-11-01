extends SceneTree

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty():
        push_error("candidate GLB path required")
        quit(1)
        return
    var fighter: PortFighter = load("res://scripts/fighter.gd").new()
    fighter.configure_candidate_asset(args[0], "", PortFighter.CANDIDATE_CLIPS, "body")
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    await process_frame
    if not fighter.candidate_loaded:
        push_error("candidate did not load: " + fighter.candidate_load_error)
        quit(1)
        return
    var cases: Array[Dictionary] = [
        {"axis": Vector2(-1.0, 0.0), "action": "moveleft", "clip": "m01_moverht"},
        {"axis": Vector2(1.0, 0.0), "action": "moveright", "clip": "m01_movelft"},
        {"axis": Vector2(0.0, -1.0), "action": "stepleft", "clip": "m01_steplft"},
        {"axis": Vector2(0.0, 1.0), "action": "stepright", "clip": "m01_steprht"},
    ]
    for case: Dictionary in cases:
        fighter.move_axis = case["axis"]
        fighter._animate_candidate()
        if fighter.candidate_animation_clip != case["clip"]:
            push_error("movement clip mismatch for %s: %s" % [
                str(case["axis"]), fighter.candidate_animation_clip
            ])
            quit(1)
            return
        var clip: Animation = fighter._candidate_animation.get_animation(
            fighter._candidate_clip_paths[String(case["action"])]
        )
        if clip == null or clip.loop_mode != Animation.LOOP_LINEAR:
            push_error("movement clip is not LOOP_LINEAR: " + String(case["action"]))
            quit(1)
            return
    fighter.state = "idle3"
    fighter.move_axis = Vector2(-1.0, 0.0)
    fighter._animate_candidate()
    if fighter.candidate_animation_clip != "m01_moverht":
        push_error("idle3 movement did not override idle3: " + fighter.candidate_animation_clip)
        quit(1)
        return
    fighter.state = "idle"
    fighter.move_axis = Vector2.ZERO
    fighter._animate_candidate()
    if fighter.candidate_animation_clip != "m01_idle_01":
        push_error("idle clip did not restore: " + fighter.candidate_animation_clip)
        quit(1)
        return
    print("BRUCE_MOVEMENT_VALIDATION=" + JSON.stringify({
        "candidate": args[0],
        "left": "m01_moverht",
        "right": "m01_movelft",
        "side_left": "m01_steplft",
        "side_right": "m01_steprht",
        "idle": "m01_idle_01",
    }))
    fighter.queue_free()
    await process_frame
    quit(0)

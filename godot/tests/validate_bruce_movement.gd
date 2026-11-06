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
        {"axis": Vector2(-1.0, 0.0), "held": {"left": true}, "action": "stepback", "clip": "m01_stepbck"},
        {"axis": Vector2(1.0, 0.0), "held": {"right": true}, "action": "stepfwd", "clip": "m01_stepfwd"},
        {"axis": Vector2(0.0, -1.0), "held": {"up": true}, "action": "stepright", "clip": "m01_steprht"},
        {"axis": Vector2(0.0, 1.0), "held": {"down": true}, "action": "stepleft", "clip": "m01_steplft"},
    ]
    for case: Dictionary in cases:
        fighter.move_axis = case["axis"]
        fighter.set_held_directions(case["held"])
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
    fighter.set_held_directions({"left": true})
    fighter._animate_candidate()
    if fighter.candidate_animation_clip != "m01_stepbck":
        push_error("idle3 movement did not override idle3: " + fighter.candidate_animation_clip)
        quit(1)
        return
    fighter.state = "idle"
    fighter.move_axis = Vector2.ZERO
    fighter.set_held_directions({})
    fighter._animate_candidate()
    if fighter.candidate_animation_clip != "m01_idle_01":
        push_error("idle clip did not restore: " + fighter.candidate_animation_clip)
        quit(1)
        return
    print("BRUCE_MOVEMENT_VALIDATION=" + JSON.stringify({
        "candidate": args[0],
        "left": "m01_moverht",
        "right": "m01_movelft",
        "forward": "m01_stepfwd",
        "back": "m01_stepbck",
        "idle": "m01_idle_01",
    }))
    fighter.queue_free()
    await process_frame
    quit(0)

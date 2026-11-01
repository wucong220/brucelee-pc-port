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
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    fighter.configure_candidate_asset(args[0], "", PortFighter.CANDIDATE_CLIPS, "body")
    root.add_child(fighter)
    await process_frame
    if not fighter.candidate_loaded:
        push_error("candidate did not load: " + fighter.candidate_load_error)
        quit(1)
        return
    if not fighter._candidate_clip_paths.has("heavy"):
        push_error("heavy clip was not registered")
        quit(1)
        return
    if not fighter.request_attack("heavy"):
        push_error("heavy request failed")
        quit(1)
        return
    fighter._animate_candidate()
    if fighter.candidate_animation_clip != "m01_kick_high_01":
        push_error("heavy visual was not high kick: " + fighter.candidate_animation_clip)
        quit(1)
        return
    print("HEAVY_VISUAL_VALIDATION=" + JSON.stringify({
        "clip": fighter.candidate_animation_clip,
        "animation": fighter.current_source_animation(),
    }))
    fighter.queue_free()
    await process_frame
    quit(0)

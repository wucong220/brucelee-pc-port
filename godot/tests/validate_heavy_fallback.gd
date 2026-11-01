extends SceneTree

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty():
        push_error("low-kick-only candidate path required")
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
    if fighter._candidate_clip_paths.has("heavy"):
        push_error("fallback fixture unexpectedly has heavy clip")
        quit(1)
        return
    if not fighter.request_attack("heavy"):
        push_error("heavy request failed")
        quit(1)
        return
    fighter._animate_candidate()
    if fighter.candidate_animation_clip != "m01_kick_low_01":
        push_error("heavy fallback clip was not low kick: " + fighter.candidate_animation_clip)
        quit(1)
        return
    if fighter.current_source_animation() != "m01_kick_low_01":
        push_error("source animation did not fall back: " + fighter.current_source_animation())
        quit(1)
        return
    print("HEAVY_FALLBACK_VALIDATION=" + JSON.stringify({
        "clip": fighter.candidate_animation_clip,
        "source_animation": fighter.current_source_animation(),
        "source_radius": fighter.source_radius_for_current_animation(),
    }))
    fighter.queue_free()
    await process_frame
    quit(0)

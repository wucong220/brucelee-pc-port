extends SceneTree
## Verify a candidate GLB containing m01_idle_03 registers and loops idle3.

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
    if not fighter._candidate_clip_paths.has(PortFighter.IDLE3_CLIP):
        push_error("candidate did not register m01_idle_03")
        quit(1)
        return
    var clip: Animation = fighter._candidate_animation.get_animation(
        fighter._candidate_clip_paths[PortFighter.IDLE3_CLIP]
    )
    if clip == null or clip.loop_mode != Animation.LOOP_LINEAR:
        push_error("m01_idle_03 is not LOOP_LINEAR")
        quit(1)
        return
    if not fighter.request_attack("special_kick_high"):
        push_error("special_kick_high request failed")
        quit(1)
        return
    var details: Dictionary = fighter.ATTACKS["special_kick_high"]
    fighter._advance_timed_states(
        float(details["startup"]) + float(details["active"]) + float(details["recovery"]) + 0.001
    )
    if fighter.state != "idle3" or fighter.current_source_animation() != PortFighter.IDLE3_CLIP:
        push_error("loaded idle3 did not become active: " + fighter.state)
        quit(1)
        return
    print("IDLE3_LOADED_VALIDATION=" + JSON.stringify({
        "candidate": args[0],
        "state": fighter.state,
        "animation": fighter.current_source_animation(),
        "loop_mode": clip.loop_mode,
    }))
    fighter.queue_free()
    await process_frame
    quit(0)

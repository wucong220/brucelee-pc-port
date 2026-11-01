extends SceneTree

const Fighter = preload("res://scripts/fighter.gd")

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty():
        push_error("Brick combat candidate GLB path required")
        quit(1)
        return
    var brick = Fighter.new()
    brick.configure("brick", false, Color.WHITE)
    brick.configure_attack_config(Fighter.BRICK_ATTACK_CONFIG_PATH)
    brick.configure_candidate_asset(args[0], "", Fighter.BRICK_CLIPS, "body")
    root.add_child(brick)
    await process_frame
    if not brick.candidate_loaded:
        push_error("Brick candidate failed: " + brick.candidate_load_error)
        quit(1)
        return
    if not brick._candidate_clip_paths.has("all_impct_hard_frnt_high"):
        push_error("High KO reaction clip was not registered")
        quit(1)
        return
    brick.health = 1.0
    var reaction: Dictionary = {
        "source_action": "impacthardfronthigh",
        "animation": "all_impct_hard_frnt_high",
        "exit_start_frame": 23,
        "animation_duration_frames": 35,
        "linking_frame": 0,
        "return_action": "faceupko",
    }
    brick.receive_hit(5.0, false, 0.0, 1.0, reaction)
    if brick.health > 0.0 or brick.state != "stunimpact":
        push_error("High lethal hit did not enter stunimpact: "
                + brick.state + " health " + str(brick.health))
        quit(1)
        return
    brick._animate_candidate()
    if brick.candidate_animation_clip != "all_impct_hard_frnt_high":
        push_error("High KO clip was not applied: " + brick.candidate_animation_clip)
        quit(1)
        return
    print("BRICK_HIGH_KO_VALIDATION=" + JSON.stringify({
        "state": brick.state,
        "clip": brick.candidate_animation_clip,
        "health": brick.health,
    }))
    brick.queue_free()
    await process_frame
    quit(0)

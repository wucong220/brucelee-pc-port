extends SceneTree

const Fighter = preload("res://scripts/fighter.gd")

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty():
        push_error("Full Brick candidate GLB path required")
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
    var reaction: Dictionary = brick.reaction_for_incoming({
        "strength": "hard",
        "height": "high",
        "body_part": "larm",
        "direction": "frontal",
    }, true)
    print("REACTION=" + JSON.stringify(reaction))
    if String(reaction.get("animation", "")) != "m03_blck_high":
        push_error("Brick high block did not select m03_blck_high")
        quit(1)
        return
    brick.receive_hit(5.0, true, 0.0, 1.0, reaction)
    if brick.state != "blockstun":
        push_error("Brick high block did not enter blockstun")
        quit(1)
        return
    brick._animate_candidate()
    if brick.candidate_animation_clip != "m03_blck_high":
        push_error("Brick high block clip was not applied: "
                + brick.candidate_animation_clip)
        quit(1)
        return
    print("BRICK_BLOCK_VALIDATION=" + JSON.stringify({
        "animation": brick.candidate_animation_clip,
        "health": brick.health,
    }))
    brick.queue_free()
    await process_frame
    quit(0)

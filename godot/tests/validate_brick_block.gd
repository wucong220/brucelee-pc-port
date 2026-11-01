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
    var invalid_clip: Animation = Animation.new()
    invalid_clip.length = 0.5
    var invalid_track: int = invalid_clip.add_track(Animation.TYPE_VALUE)
    invalid_clip.track_set_path(invalid_track, "bad_track")
    if brick._prepare_candidate_reaction(invalid_clip):
        push_error("Invalid reaction track was accepted")
        quit(1)
        return
    var cases: Array[Array] = [
        ["high", "larm", "m03_blck_high"],
        ["low", "lleg", "all_block_low"],
        ["medium", "larm", "all_block_mid"],
    ]
    for block_case: Array in cases:
        brick.reset_fighter(Vector3(0.0, 1.20, 0.0))
        var reaction: Dictionary = brick.reaction_for_incoming({
            "strength": "hard",
            "height": String(block_case[0]),
            "body_part": String(block_case[1]),
            "direction": "frontal",
        }, true)
        if String(reaction.get("animation", "")) != String(block_case[2]):
            push_error("Brick %s block did not select %s"
                    % [block_case[0], block_case[2]])
            quit(1)
            return
        brick.receive_hit(5.0, true, 0.0, 1.0, reaction)
        if brick.state != "blockstun":
            push_error("Brick %s block did not enter blockstun" % block_case[0])
            quit(1)
            return
        brick._animate_candidate()
        if brick.candidate_animation_clip != String(block_case[2]):
            push_error("Brick %s block clip was not applied: %s"
                    % [block_case[0], brick.candidate_animation_clip])
            quit(1)
            return
    print("BRICK_BLOCK_VALIDATION=" + JSON.stringify({
        "high": "m03_blck_high",
        "low": "all_block_low",
        "mid": "all_block_mid",
        "health": brick.health,
    }))
    brick.queue_free()
    await process_frame
    quit(0)

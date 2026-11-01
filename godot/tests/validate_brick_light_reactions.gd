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
    var cases: Array[Array] = [
        ["low", "all_impct_light_frnt_low"],
        ["medium", "all_impct_light_frnt_mid"],
        ["high", "all_impct_light_frnt_high"],
    ]
    for reaction_case: Array in cases:
        brick.reset_fighter(Vector3(0.0, 1.20, 0.0))
        var impact: Dictionary = {
            "strength": "normal",
            "height": String(reaction_case[0]),
            "body_part": "larm",
            "direction": "frontal",
        }
        var reaction: Dictionary = brick.reaction_for_incoming(impact, false)
        if String(reaction.get("animation", "")) != String(reaction_case[1]):
            push_error("Brick light reaction did not select %s" % reaction_case[1])
            quit(1)
            return
        brick.receive_hit(5.0, false, 0.0, 1.0, reaction)
        if brick.state != "hitstun":
            push_error("Brick light reaction did not enter hitstun")
            quit(1)
            return
        brick._animate_candidate()
        if brick.candidate_animation_clip != String(reaction_case[1]):
            push_error("Brick light reaction clip was not applied: "
                    + brick.candidate_animation_clip)
            quit(1)
            return
    print("BRICK_LIGHT_REACTION_VALIDATION=" + JSON.stringify({
        "low": "all_impct_light_frnt_low",
        "medium": "all_impct_light_frnt_mid",
        "high": "all_impct_light_frnt_high",
        "health": brick.health,
    }))
    brick.queue_free()
    await process_frame
    quit(0)

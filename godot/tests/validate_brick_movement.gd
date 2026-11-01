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
    for key: String in [
            "moveleft", "moveright",
            "stepfwd", "stepback", "stepleft", "stepright"]:
        if not brick._candidate_clip_paths.has(key):
            push_error("Brick movement clip was not registered: " + key)
            quit(1)
            return
    brick.reset_fighter(Vector3(0.0, 1.20, 0.0))
    for case: Array in [
        [Vector2(-1.0, 0.0), "moveleft", "m03_movelft"],
        [Vector2(1.0, 0.0), "moveright", "m03_moverht"],
        [Vector2(0.0, -1.0), "stepfwd", "m03_stepfwd"],
        [Vector2(0.0, 1.0), "stepback", "m03_stepbck"],
    ]:
        brick.state = "idle"
        brick.move_axis = case[0]
        brick._animate_candidate()
        if brick._movement_action() != String(case[1]) or (
                brick.candidate_animation_clip != String(case[2])):
            push_error("Brick movement mapping failed for " + String(case[1]))
            quit(1)
            return
    print("BRICK_MOVEMENT_VALIDATION=" + JSON.stringify({
        "left": brick._candidate_clip_paths["moveleft"],
        "right": brick._candidate_clip_paths["moveright"],
        "forward": brick._candidate_clip_paths["stepfwd"],
        "back": brick._candidate_clip_paths["stepback"],
    }))
    brick.queue_free()
    await process_frame
    quit(0)

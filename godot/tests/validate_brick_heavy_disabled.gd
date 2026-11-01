extends SceneTree

const Fighter = preload("res://scripts/fighter.gd")

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty():
        push_error("Brick candidate GLB path required")
        quit(1)
        return
    var brick = Fighter.new()
    brick.configure("brick", false, Color.WHITE)
    brick.configure_attack_config(Fighter.BRICK_ATTACK_CONFIG_PATH)
    brick.configure_candidate_asset(
        args[0], "", Fighter.BRICK_CLIPS, "body"
    )
    root.add_child(brick)
    await process_frame
    if not brick.candidate_loaded:
        push_error("Brick candidate failed to load: " + brick.candidate_load_error)
        quit(1)
        return
    if brick.supports_attack("heavy"):
        push_error("Brick accepted the Bruce-only heavy fallback")
        quit(1)
        return
    if not brick.supports_attack("kick"):
        push_error("Brick lost its own kick attack")
        quit(1)
        return
    print("BRICK_HEAVY_DISABLED_VALIDATION=" + JSON.stringify({
        "heavy": brick.supports_attack("heavy"),
        "kick": brick.supports_attack("kick"),
    }))
    brick.queue_free()
    await process_frame
    quit(0)

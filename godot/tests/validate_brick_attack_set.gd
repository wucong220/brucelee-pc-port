extends SceneTree

const Fighter = preload("res://scripts/fighter.gd")

const EXPECTED: Dictionary = {
    "high_punch": "m03_pnch_high_01",
    "high_punch2": "m03_pnch_high_02",
    "high_punch3": "m03_pnch_high_03",
    "low_punch": "m03_pnch_low_03",
    "low_punch2": "m03_pnch_low_02",
    "low_punch3": "m03_pnch_low_01",
    "high_kick": "m03_kck_high_01",
    "high_kick2": "m03_kck_high_02",
    "high_kick3": "m03_kck_high_03",
    "low_kick": "m03_kck_low_02",
    "low_kick2": "m03_kck_low_03",
    "low_kick3": "m03_kck_low_01",
}

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
    if brick.ATTACKS.size() != 15:
        push_error("Brick attack set did not load 14 config actions plus heavy: "
                + str(brick.ATTACKS.size()))
        quit(1)
        return
    for action: String in EXPECTED:
        brick.reset_fighter(Vector3(0.0, 1.20, 0.0))
        if not brick.supports_attack(action):
            push_error("Brick candidate does not support " + action)
            quit(1)
            return
        if not brick.request_attack(action):
            push_error("Brick request failed for " + action)
            quit(1)
            return
        brick._animate_candidate()
        if brick.candidate_animation_clip != String(EXPECTED[action]):
            push_error("Brick clip mismatch for " + action + ": "
                    + brick.candidate_animation_clip)
            quit(1)
            return
    print("BRICK_ATTACK_SET_VALIDATION=" + JSON.stringify({
        "actions": EXPECTED.keys(),
        "config_attacks": brick.ATTACKS.size(),
    }))
    brick.queue_free()
    await process_frame
    quit(0)

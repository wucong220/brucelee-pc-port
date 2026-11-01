extends SceneTree
## Validate the prototype attack-root interpolation path.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var fighter: PortFighter = load("res://scripts/fighter.gd").new()
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    await process_frame
    if not fighter._attack_root_tracks.has("m01_pnch_low_01"):
        push_error("attack root data missing m01_pnch_low_01")
        quit(1)
        return
    fighter.facing = 1.0
    fighter.attack_kind = "punch"
    fighter.attack_sequence = 1
    fighter.state = "startup"
    fighter.state_time = float(fighter.ATTACKS["punch"]["startup"])
    var before: float = fighter.position.x
    fighter._apply_attack_root_motion()
    if not is_equal_approx(fighter.position.x, before):
        push_error("first attack-root sample should only seed the previous value")
        quit(1)
        return
    fighter.state_time -= 1.0 / PortFighter.SOURCE_FRAME_RATE
    fighter._apply_attack_root_motion()
    if fighter.position.x <= before:
        push_error("attack root motion did not advance position")
        quit(1)
        return
    var moved: float = fighter.position.x - before
    fighter.attack_kind = "grab2"
    fighter.attack_sequence = 2
    fighter.state_time = float(fighter.ATTACKS["grab2"]["startup"])
    var grab_before: float = fighter.position.x
    fighter._apply_attack_root_motion()
    if not is_equal_approx(fighter.position.x, grab_before):
        push_error("grab2 without positions should not move")
        quit(1)
        return
    var brick: PortFighter = load("res://scripts/fighter.gd").new()
    brick.configure_attack_config(PortFighter.BRICK_ATTACK_CONFIG_PATH)
    root.add_child(brick)
    await process_frame
    brick.facing = 1.0
    brick.attack_kind = "punch"
    brick.attack_sequence = 1
    brick.state = "startup"
    brick.state_time = float(brick.ATTACKS["punch"]["startup"])
    var brick_before: float = brick.position.x
    brick._apply_attack_root_motion()
    if not is_equal_approx(brick.position.x, brick_before):
        push_error("Brick punch incorrectly reused Bruce root data")
        quit(1)
        return
    print("ATTACK_ROOT_MOTION_VALIDATION=" + JSON.stringify({
        "source_action": "lowpunch1",
        "frame_delta": 1.0 / PortFighter.SOURCE_FRAME_RATE,
        "world_delta": moved,
        "scope": "raw source component magnitude mapped to prototype forward displacement; native axis/sign unverified",
    }))
    brick.queue_free()
    fighter.queue_free()
    await process_frame
    quit(0)

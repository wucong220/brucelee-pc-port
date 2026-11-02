extends SceneTree
## Regressions for the recovered FollowLink metadata and pose conditions.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and Brick candidate GLB paths")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)

    var checks: Dictionary = {}

    # entry_frame: parry_attack starts at frame 3 when chained from parryhigh.
    player.reset_fighter(Vector3(-0.25, 1.2, 0.0))
    player._begin_chained_attack("parry_attack", 3)
    var entry_frame: float = player._current_attack_source_frame()
    checks["entry_frame"] = entry_frame
    if absf(entry_frame - 3.0) > 0.2:
        push_error("entry_frame not applied: " + str(entry_frame))
        quit(1)
        return

    # Native recovery: lowpunch3 -> idle2 [51,81], entry_frame 5.
    player.reset_fighter(Vector3(-0.25, 1.2, 0.0))
    player.attack_kind = "low_punch3"
    player.state = "recovery"
    player.state_time = 0.0
    var returned: Dictionary = player._native_recovery_return()
    checks["recovery"] = String(returned.get("state", ""))
    checks["recovery_entry"] = int(returned.get("entry_frame", -1))
    if (String(returned.get("state", "")) != "idle2"
            or int(returned.get("entry_frame", -1)) != 5):
        push_error("native recovery link is wrong: " + str(returned))
        quit(1)
        return

    # Pose conditions use the recovered action pose, not the state enum.
    computer.reset_fighter(Vector3(0.25, 1.2, 0.0))
    checks["pose_idle"] = computer._fighter_pose()
    computer.state = "hitstun"
    checks["pose_hitstun"] = computer._fighter_pose()
    computer.state = "faceupidle"
    checks["pose_faceup"] = computer._fighter_pose()
    if checks["pose_idle"] != "stand" or checks["pose_hitstun"] != "stun" or checks["pose_faceup"] != "laying":
        push_error("pose mapping is wrong: " + str(checks))
        quit(1)
        return

    checks["unique_brucelee"] = player._native_link_unique_ok({"unique": ["grababrucelee"]})
    checks["unique_brick_skipped"] = not player._native_link_unique_ok({"unique": ["grababrick"]})
    if not checks["unique_brucelee"] or not checks["unique_brick_skipped"]:
        push_error("unique character tag gate is wrong: " + str(checks))
        quit(1)
        return

    print("P2_RECOVERED_LINK_VALIDATION=" + JSON.stringify(checks))
    quit(0)

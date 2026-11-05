extends SceneTree
## Regressions for the recovered FollowLink metadata and pose conditions.
##
## The unique-tag check below follows the recovered opponent-suffix semantics
## of brucelee.set (SHA-256 860b6dac1ae5043456fbf72b1cd93a5a1c76f036b3b995df5e57ce68b4d3762c):
## the player's `unique` token names the OPPONENT of the matchup, so against a
## Brick opponent `grababrick` passes and the mirror-only `grababrucelee` is
## refused.  The generic (order 6) and Brick-specific (order 8) step links are
## both asserted from the recovered table so link-order regressions stay visible.

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

    # Recovered link-order / unique-tag rows (generic first, then the Brick
    # opponent variant).  These are table facts, independent of runtime state.
    var by_order: Dictionary = {}
    for link: Dictionary in player._native_links:
        by_order[int(link.get("order", -1))] = link
    var expected_rows: Dictionary = {
        6: ["stepright", "grab1miss", "grababrucelee"],
        8: ["stepright", "grab1miss brick", "grababrick"],
        34: ["", "endattack1", ""],
        35: ["", "endattack2", "endbrucelee"],
        36: ["", "endattack brick", "endbrickdavis"],
    }
    for order: int in expected_rows:
        var row: Array = expected_rows[order]
        var link: Dictionary = by_order.get(order, {})
        var unique: Array = Array(link.get("unique", []))
        var tag: String = str(unique[0]) if not unique.is_empty() else ""
        if (link.is_empty()
                or ("" if link.get("from") == null else str(link.get("from"))) != str(row[0])
                or str(link.get("to", "")) != String(row[1])
                or tag != String(row[2])):
            push_error("recovered link order " + str(order) + " drifted: " + str(link))
            quit(1)
            return
        checks["link_" + str(order)] = str(link.get("to", ""))

    # Opponent-token gate: the fixture is a Brick opponent.
    checks["opponent_token"] = player._opponent_suffix_token()
    if checks["opponent_token"] != "brick":
        push_error("expected a Brick opponent token, got " + str(checks["opponent_token"]))
        quit(1)
        return
    checks["unique_brick_tag_ok"] = player._native_link_unique_ok({"unique": ["grababrick"]})
    checks["unique_brucelee_tag_refused"] = not player._native_link_unique_ok({"unique": ["grababrucelee"]})
    checks["unique_endbrickdavis_ok"] = player._native_link_unique_ok({"unique": ["endbrickdavis"]})
    checks["unique_endbrucelee_refused"] = not player._native_link_unique_ok({"unique": ["endbrucelee"]})
    if (not checks["unique_brick_tag_ok"]
            or not checks["unique_brucelee_tag_refused"]
            or not checks["unique_endbrickdavis_ok"]
            or not checks["unique_endbrucelee_refused"]):
        push_error("unique character tag gate is wrong: " + str(checks))
        quit(1)
        return

    print("P2_RECOVERED_LINK_VALIDATION=" + JSON.stringify(checks))
    quit(0)

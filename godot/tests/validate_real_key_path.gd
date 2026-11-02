extends SceneTree
## Regression for the two ChatGPT P1 findings: real key path must not fold
## held directions into the attack event, and empty-sequence follow-ups must
## not index steps[-1].

const Controls = preload("res://scripts/prototype_controls.gd")


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
    player.set_physics_process(false)

    # 1) Holding right, then pressing attack A, must still match the native
    # single-key pressa link (high_punch1).
    var right_event: InputEventAction = InputEventAction.new()
    right_event.action = Controls.MOVE_RIGHT
    right_event.pressed = true
    scene._record_direction_press(right_event)
    var attack_event: InputEventAction = InputEventAction.new()
    attack_event.action = Controls.ATTACK_A
    attack_event.pressed = true
    scene._handle_fighter_attack_input(
        player, attack_event,
        Controls.ATTACK_A, Controls.ATTACK_B,
        "prototype_attack_c", "prototype_attack_d"
    )
    var held_result: String = player.attack_kind
    if held_result != "high_punch":
        push_error("direction+attack did not match single-key link: " + held_result)
        quit(1)
        return

    # 2) An empty-sequence follow-up must consume nothing and must not index -1.
    player.reset_fighter(Vector3(-0.25, 1.2, 0.0))
    player._link_events.clear()
    player._link_events.append({"tokens": ["a"], "consumed": false, "time_ms": int(player._time * 1000.0)})
    player._consume_link_events({"steps": []})
    if bool(player._link_events[0]["consumed"]):
        push_error("empty-sequence consume marked an event consumed")
        quit(1)
        return

    # 3) parryhigh -> parryattack [9,10] with an absorbed hit must auto-chain;
    # the native impactable window starts at 30, so an unabsorbed parry must not
    # be cut short at frame 9.
    player.reset_fighter(Vector3(-0.25, 1.2, 0.0))
    player.attack_kind = "parry_high"
    player.state = "active"
    player.state_time = float(player.ATTACKS["parry_high"]["active"])
    player._parry_absorbed = true
    player._link_events.clear()
    player._link_events.append({"tokens": ["b"], "consumed": false, "time_ms": int(player._time * 1000.0)})
    var followed: bool = player._try_follow_links()
    if not followed or player.attack_kind != "parry_attack":
        push_error("empty-sequence auto link did not chain: " + player.attack_kind)
        quit(1)
        return

    print("REAL_KEY_PATH_VALIDATION=" + JSON.stringify({
        "held_direction_attack": held_result,
        "empty_consume_safe": true,
        "auto_chain": player.attack_kind,
    }))
    quit(0)

extends SceneTree

func _initialize() -> void:
    call_deferred("_run")


func _key(action: String) -> InputEventAction:
    var event: InputEventAction = InputEventAction.new()
    event.action = action
    event.pressed = true
    return event


func _press(scene: Node, player: PortFighter, virtual_key: String) -> bool:
    return scene._handle_fighter_attack_input(
        player,
        _key("prototype_attack_" + virtual_key),
        "prototype_attack_a",
        "prototype_attack_b",
        "prototype_attack_c",
        "prototype_attack_d"
    )


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty():
        push_error("candidate GLB path required")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    player.set_physics_process(false)
    if not player.candidate_loaded:
        push_error("candidate did not load: " + player.candidate_load_error)
        quit(1)
        return
    var cases: Array[Dictionary] = [
        {"start": "a", "keys": ["b", "b"], "advance": 22, "target": "low_punch2"},
        {"start": "b", "keys": ["c", "c"], "advance": 31, "target": "high_kick"},
        {"start": "b", "keys": ["d", "d"], "advance": 31, "target": "low_kick2"},
    ]
    for value: Dictionary in cases:
        player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
        player._time = 0.0
        _press(scene, player, String(value["start"]))
        for key: String in value["keys"]:
            _press(scene, player, key)
        if player._standing_combo_pending_attack != String(value["target"]):
            push_error("early keys did not buffer target " + String(value["target"]))
            quit(1)
            return
        player._advance_timed_states(float(value["advance"]) / PortFighter.SOURCE_FRAME_RATE)
        if not player._try_begin_pending_standing_combo():
            push_error("buffered target did not start: " + String(value["target"]))
            quit(1)
            return
        if player.attack_kind != String(value["target"]):
            push_error("buffered target mismatch: " + player.attack_kind)
            quit(1)
            return
    print("EARLY_SEQUENCE_VALIDATION=" + JSON.stringify({"cases": cases.size()}))
    scene.queue_free()
    await process_frame
    quit(0)

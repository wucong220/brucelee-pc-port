extends SceneTree
## Every recovered standing-combo step must produce an attack. This is the
## regression for the empty middle press (A/A/A previously started only two).

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and opponent GLB paths")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)
    var checked: int = 0
    for entry: Dictionary in player.STANDING_COMBO_SEQUENCES:
        var steps: Array = entry["steps"]
        if steps.size() < 2:
            continue
        player.reset_fighter(Vector3(0.0, 1.2, 0.0))
        computer.reset_fighter(Vector3(0.3, 1.2, 0.0))
        player.health = 9999.0
        computer.health = 9999.0
        player.rage = 100.0
        var started: Array[String] = []
        player.attack_started.connect(func(action: String): started.append(action))
        for step_value: Variant in steps:
            var step: Array = step_value
            var key: String = String(step[-1])
            _press(player, key)
            for _frame: int in range(10):
                player.position = Vector3(0.0, 1.2, 0.0)
                computer.position = Vector3(0.3, 1.2, 0.0)
                player._physics_process(1.0 / 60.0)
        for _frame: int in range(500):
            player.position = Vector3(0.0, 1.2, 0.0)
            computer.position = Vector3(0.3, 1.2, 0.0)
            player._physics_process(1.0 / 60.0)
        if started.size() < steps.size():
            push_error("Combo swallowed a press: " + str(entry["attack"]) + " " + str(steps) + " -> " + str(started))
            quit(1)
            return
        checked += 1
    print("ALL_COMBO_QUEUE_VALIDATION=" + JSON.stringify({"sequences": checked}))
    quit(0)


func _press(player: PortFighter, key: String) -> void:
    var base: String = "punch" if key == "a" else (
        "kick" if key == "b" else ("heavy" if key == "c" else "kick")
    )
    if not player.record_standing_combo_press(key):
        player.request_attack_or_queue(base)

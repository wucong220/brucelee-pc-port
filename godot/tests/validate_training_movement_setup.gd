extends SceneTree
## Regression: a training lesson whose setup is a held movement action must
## actually receive W/A/S/D while the training page is active.

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
    var training = scene.get("move_training")
    player.set_physics_process(false)
    computer.set_physics_process(false)
    training.open()
    training._start_at(12)
    player.position = Vector3(-0.25, 1.2, 0.0)
    computer.position = Vector3(0.25, 1.2, 0.0)
    Input.action_press("prototype_move_down", 1.0)
    for _frame: int in range(20):
        scene._physics_process(1.0 / 60.0)
        player._physics_process(1.0 / 60.0)
    if player._native_movement_action() != "stepback":
        Input.action_release("prototype_move_down")
        push_error("training did not feed the held stepback movement")
        quit(1)
        return
    player.record_standing_combo_press("right")
    player.record_standing_combo_press("c")
    for _frame: int in range(60):
        scene._physics_process(1.0 / 60.0)
        player._physics_process(1.0 / 60.0)
        if player.attack_kind == "special_kick_high":
            break
    Input.action_release("prototype_move_down")
    if player.attack_kind != "special_kick_high":
        push_error("held stepback + D,L did not start SPECIAL HIGH KICK")
        quit(1)
        return
    print("TRAINING_MOVEMENT_SETUP_VALIDATION=" + JSON.stringify({
        "setup": "stepback",
        "attack": player.attack_kind,
    }))
    quit(0)

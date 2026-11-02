extends SceneTree
## Regression: the J that confirms a menu entry (or starts a lesson) must also
## throw a real punch. Otherwise "J J J" loses its first press and produces only
## two attacks even though the in-fight queue itself is correct.

func _initialize() -> void:
    call_deferred("_run")


func _key(keycode: Key) -> InputEventKey:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = keycode
    event.pressed = true
    return event


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and Brick candidate GLB paths")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "1")
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
    var started: Array[String] = []
    player.attack_started.connect(func(kind: String) -> void: started.append(kind))

    # 1. Main menu on VS FIGHT: J confirms and must still punch.
    for _press: int in range(3):
        scene._unhandled_input(_key(KEY_J))
        for _frame: int in range(6):
            player._physics_process(1.0 / 60.0)
    for _frame: int in range(900):
        player._physics_process(1.0 / 60.0)
    # Decompiled link model: the first J is the punch, the remaining two are
    # link events, and high_punch replaces the punch when its window opens.
    if started != ["punch", "high_punch2"]:
        push_error("Menu-confirm J presses produced: " + str(started))
        quit(1)
        return
    var menu_attacks: int = started.size()
    if scene.main_menu_active or scene.prototype_menu.visible:
        push_error("J did not leave the main menu")
        quit(1)
        return

    # 2. Move-training selector: J starts the lesson and must still punch.
    scene._on_menu_command("move_training")
    await process_frame
    var training = scene.get("move_training")
    if training == null or training.state != "select":
        push_error("Move training did not open its selector")
        quit(1)
        return
    started.clear()
    scene._unhandled_input(_key(KEY_J))
    if training.state != "active":
        push_error("J did not start the training lesson")
        quit(1)
        return
    if started != ["punch"]:
        push_error("Training-start J presses produced: " + str(started))
        quit(1)
        return

    print("MENU_CONFIRM_ATTACK_VALIDATION=" + JSON.stringify({
        "menu_attacks": menu_attacks,
        "menu_presses": 3,
        "training_start_punch": true,
    }))
    scene.queue_free()
    await process_frame
    quit(0)

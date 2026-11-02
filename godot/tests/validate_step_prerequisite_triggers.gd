extends SceneTree
## Step-prerequisite commands must start their target action directly.

const C = preload("res://scripts/prototype_controls.gd")


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    var training = scene.get("move_training")
    var player: PortFighter = scene.get("player")
    var cases: Array = [
        ["special_kick_high", C.MOVE_LEFT, C.ATTACK_C, "special_kick_high"],
        ["special_kick_low", C.MOVE_DOWN, C.ATTACK_D, "special_kick_low_hit"],
        ["grab1", C.MOVE_UP, C.ATTACK_A, "grab1"],
        ["grab2", C.MOVE_DOWN, C.ATTACK_C, "grab2"],
    ]
    for item: Array in cases:
        var lesson: String = String(item[0])
        var index: int = -1
        for i: int in range(training.entries.size()):
            if String(training.entries[i].get("id", "")) == lesson:
                index = i
        training._start_at(index)
        Input.action_press(String(item[1]))
        for _frame: int in range(8):
            scene._physics_process(1.0 / 60.0)
            player._physics_process(1.0 / 60.0)
            training._process(1.0 / 60.0)
        var event: InputEventAction = InputEventAction.new()
        event.action = String(item[2])
        event.pressed = true
        scene._handle_fighter_attack_input(
            player, event, C.ATTACK_A, C.ATTACK_B, C.ATTACK_C, C.ATTACK_D
        )
        for _frame: int in range(20):
            scene._physics_process(1.0 / 60.0)
            player._physics_process(1.0 / 60.0)
            training._process(1.0 / 60.0)
        if player.attack_kind != String(item[3]):
            push_error(lesson + " expected " + String(item[3])
                    + " got " + player.attack_kind)
            Input.action_release(String(item[1]))
            quit(1)
            return
        Input.action_release(String(item[1]))
    print("STEP_PREREQUISITE_VALIDATION=passed")
    quit(0)

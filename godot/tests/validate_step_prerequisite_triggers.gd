extends SceneTree
## Step-prerequisite commands must start their target action directly.

const C = preload("res://scripts/prototype_controls.gd")


func _initialize() -> void:
    call_deferred("_run")


func _start_action(training, native_action: String) -> bool:
    for entry_value: Variant in training.selectable_trainings():
        var entry: Dictionary = entry_value
        for step_value: Variant in Array(entry["steps"]):
            var step: Dictionary = step_value
            if native_action in Array(step["success_animations"]):
                training.current_training = entry
                training.steps = entry["steps"]
                training.state = "active"
                training._start_step(int(step["index"]))
                return true
    return false


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
        ["specialkickhigh", C.MOVE_LEFT, C.MOVE_RIGHT, C.ATTACK_C, "special_kick_high"],
        ["specialkicklowhit", C.MOVE_DOWN, C.MOVE_RIGHT, C.ATTACK_D, "special_kick_low_hit"],
        ["grab1", C.MOVE_UP, C.MOVE_LEFT, C.ATTACK_A, "grab1"],
        ["grab2", C.MOVE_DOWN, C.MOVE_LEFT, C.ATTACK_C, "grab2"],
    ]
    for item: Array in cases:
        var native_action: String = String(item[0])
        if not _start_action(training, native_action):
            push_error(native_action + " lesson is missing")
            quit(1)
            return
        Input.action_press(String(item[1]))
        for _frame: int in range(10):
            scene._physics_process(1.0 / 60.0)
            player._physics_process(1.0 / 60.0)
            training._process(1.0 / 60.0)
        Input.action_press(String(item[2]))
        for _frame: int in range(4):
            scene._physics_process(1.0 / 60.0)
            player._physics_process(1.0 / 60.0)
            training._process(1.0 / 60.0)
        player.record_standing_combo_press(
            "right" if String(item[2]) == C.MOVE_RIGHT else "left")
        var event: InputEventAction = InputEventAction.new()
        event.action = String(item[3])
        event.pressed = true
        scene._handle_fighter_attack_input(
            player, event, C.ATTACK_A, C.ATTACK_B, C.ATTACK_C, C.ATTACK_D
        )
        for _frame: int in range(20):
            scene._physics_process(1.0 / 60.0)
            player._physics_process(1.0 / 60.0)
            training._process(1.0 / 60.0)
        if player.attack_kind != String(item[4]):
            push_error(native_action + " expected " + String(item[4])
                    + " got " + player.attack_kind)
            Input.action_release(String(item[1]))
            Input.action_release(String(item[2]))
            quit(1)
            return
        Input.action_release(String(item[1]))
        Input.action_release(String(item[2]))
    print("STEP_PREREQUISITE_VALIDATION=passed")
    quit(0)

extends SceneTree
## Mirror check: when the player is on the opponent's right (facing left),
## hold D (back) then press A + L. The native link tokens are facing-relative.

const Controls = preload("res://scripts/prototype_controls.gd")


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
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
    var training = scene.get("move_training")
    var player: PortFighter = scene.get("player")
    var opponent: PortFighter = scene.get("computer")
    var index: int = -1
    for i: int in range(training.entries.size()):
        if String(training.entries[i].get("id", "")) == "special_kick_high":
            index = i
    training._start_at(index)
    player.position = Vector3(0.25, 1.2, 0.0)
    opponent.position = Vector3(-0.25, 1.2, 0.0)
    Input.action_press(Controls.MOVE_RIGHT)
    scene._physics_process(1.0 / 60.0)
    player._physics_process(1.0 / 60.0)
    if player.facing >= 0.0 or player._native_movement_action() != "stepback":
        push_error("right-side setup did not enter facing-left stepback")
        quit(1)
        return
    var back_event: InputEventAction = InputEventAction.new()
    back_event.action = Controls.MOVE_LEFT
    back_event.pressed = true
    scene._record_direction_press(back_event)
    player.record_standing_combo_press("c")
    var result: String = ""
    for _frame: int in range(120):
        player.position = Vector3(0.25, 1.2, 0.0)
        opponent.position = Vector3(-0.25, 1.2, 0.0)
        scene._physics_process(1.0 / 60.0)
        player._physics_process(1.0 / 60.0)
        training._process(1.0 / 60.0)
        if player.attack_kind != "":
            result = player.attack_kind
            break
    Input.action_release(Controls.MOVE_RIGHT)
    if result != "special_kick_high":
        push_error("mirrored SPECIAL HIGH KICK input produced: " + result)
        quit(1)
        return
    print("SPECIAL_HIGH_KICK_MIRROR_VALIDATION=" + JSON.stringify({
        "facing": -1.0, "hold": "D", "sequence": "A, L", "result": result,
    }))
    quit(0)

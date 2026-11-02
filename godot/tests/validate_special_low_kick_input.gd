extends SceneTree
## SPECIAL LOW KICK: native stepleft (S), then press right + low kick (D + U).

const Controls = preload("res://scripts/prototype_controls.gd")


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
    var index: int = -1
    for i: int in range(training.entries.size()):
        if String(training.entries[i].get("id", "")) == "special_kick_low":
            index = i
    training._start_at(index)
    Input.action_press(Controls.MOVE_DOWN)
    for _hold: int in range(60):
        scene._physics_process(1.0 / 60.0)
        player._physics_process(1.0 / 60.0)
        training._process(1.0 / 60.0)
    Input.action_press(Controls.MOVE_RIGHT)
    player.record_standing_combo_press("right")
    player.record_standing_combo_press("d")
    var result: String = ""
    var success: bool = false
    for _frame: int in range(180):
        scene._physics_process(1.0 / 60.0)
        player._physics_process(1.0 / 60.0)
        training._process(1.0 / 60.0)
        if player.attack_kind != "":
            result = player.attack_kind
        if training.success_timer >= 0.0:
            success = true
            break
    Input.action_release(Controls.MOVE_DOWN)
    Input.action_release(Controls.MOVE_RIGHT)
    if not success or result != "special_kick_low_hit":
        push_error("SPECIAL LOW KICK did not reach hit: " + result)
        quit(1)
        return
    print("SPECIAL_LOW_KICK_VALIDATION=" + JSON.stringify({
        "hold": "S", "sequence": "D, U", "result": result, "success": success,
    }))
    quit(0)

extends SceneTree
## Exercise the move-training catalog, start selector, lock and success path.

const PrototypeControls = preload("res://scripts/prototype_controls.gd")

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
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    var training = scene.get("move_training")
    player.set_physics_process(false)
    computer.set_physics_process(false)
    if training == null or not training.entries is Array:
        push_error("Move training catalog did not load")
        quit(1)
        return
    if training.entries.size() != 25:
        push_error("Move training catalog size is " + str(training.entries.size()))
        quit(1)
        return
    if not scene.prototype_menu.MAIN_LABELS.has("MOVE TRAINING"):
        push_error("Move training is missing from the main menu")
        quit(1)
        return
    scene._on_menu_command("move_training")
    if training.state != "select" or not training.visible:
        push_error("Move training did not open the start selector from the menu")
        quit(1)
        return
    if scene.hud.visible:
        push_error("Move training did not hide the fight HUD")
        quit(1)
        return
    for index: int in range(training.entries.size()):
        training._start_at(index)
        if training.state != "active" or training.current_index != index:
            push_error("Move training setup failed at " + str(index))
            quit(1)
            return
    training._start_at(0)
    if training.state != "active" or training.current_index != 0:
        push_error("Move training did not start at the chosen lesson")
        quit(1)
        return
    var attack_d: InputEventAction = InputEventAction.new()
    attack_d.action = PrototypeControls.ATTACK_D
    attack_d.pressed = true
    if training.handle_input_event(attack_d):
        push_error("Training consumed the B/U attack key as a menu cancel")
        quit(1)
        return
    player.position = Vector3(0.0, 1.2, 0.0)
    computer.position = Vector3(0.3, 1.2, 0.0)
    if not player.request_attack("kick"):
        push_error("Wrong-move setup attack failed")
        quit(1)
        return
    for _frame: int in range(80):
        player.position = Vector3(0.0, 1.2, 0.0)
        computer.position = Vector3(0.3, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
    training._process(1.0)
    if training.current_index != 0:
        push_error("Wrong move advanced the lesson")
        quit(1)
        return
    training._prepare_current()
    player.position = Vector3(0.0, 1.2, 0.0)
    computer.position = Vector3(0.3, 1.2, 0.0)
    if not player.request_attack("punch"):
        push_error("Correct-move setup attack failed")
        quit(1)
        return
    for _frame: int in range(100):
        player.position = Vector3(0.0, 1.2, 0.0)
        computer.position = Vector3(0.3, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
    if training.success_timer < 0.0:
        push_error("Successful hit did not lock in the lesson")
        quit(1)
        return
    training._process(1.0)
    if training.current_index != 1:
        push_error("Successful hit did not advance to the next lesson")
        quit(1)
        return
    training._start_at(2)
    for _press: int in range(3):
        player.record_standing_combo_press("a")
        player.request_attack("punch")
        for _frame: int in range(12):
            player.position = Vector3(0.0, 1.2, 0.0)
            computer.position = Vector3(0.3, 1.2, 0.0)
            player._physics_process(1.0 / 60.0)
    for _frame: int in range(700):
        player.position = Vector3(0.0, 1.2, 0.0)
        computer.position = Vector3(0.3, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
        training._process(1.0 / 60.0)
    if training.current_index != 3:
        push_error("Queued HIGH PUNCH lesson did not advance")
        quit(1)
        return
    training.selected_index = 5
    training._start_at(training.selected_index)
    if training.current_index != 5:
        push_error("Start selector did not jump to the chosen lesson")
        quit(1)
        return
    training._start_at(4)
    player.record_standing_combo_press("a")
    player.record_standing_combo_press("a")
    player.record_standing_combo_press("a")
    if player.attack_kind != "high_punch2" or player.state not in ["startup", "active", "recovery"]:
        push_error("Combo lesson source window did not accept high_punch2")
        quit(1)
        return
    training._start_at(16)
    # Native parry link: down + toward (right) while the opponent attacks.
    player.record_standing_combo_press("down")
    player.record_standing_combo_press("right")
    for _frame: int in range(240):
        player.position = Vector3(0.0, 1.2, 0.0)
        computer.position = Vector3(0.3, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
        training._process(1.0 / 60.0)
        if training.success_timer >= 0.0:
            break
    if training.success_timer < 0.0:
        push_error("Parry training did not observe a real parry")
        quit(1)
        return
    training._start_at(20)
    player.state = "idle"
    if not player.request_attack("endattack1"):
        push_error("Endattack training setup failed")
        quit(1)
        return
    if training.success_timer < 0.0:
        push_error("Endattack training did not observe attack_started")
        quit(1)
        return
    # Exit during the 0.9s success prompt, before _advance()/_prepare_current()
    # can restore player physics for the next lesson.
    training.close()
    scene._on_menu_command("fight")
    if not player.is_physics_processing():
        push_error("Leaving training did not restore player physics")
        quit(1)
        return
    print("MOVE_TRAINING_VALIDATION=" + JSON.stringify({
        "entries": training.entries.size(),
        "start_selector": true,
        "wrong_move_locked": true,
        "success_advanced": true,
    }))
    training.close()
    scene.queue_free()
    await process_frame
    quit(0)

extends SceneTree
## Recovered training integration: data, navigation and success detection.
##
##   godot --headless --path godot --script res://tests/validate_training_native.gd -- <player.glb> <opponent.glb>

const Controls = preload("res://scripts/prototype_controls.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    failures.append(message)
    push_error("TRAINING_NATIVE_FAIL: " + message)


func _check(condition: bool, message: String) -> bool:
    if not condition:
        _fail(message)
    return condition


func _key(code: Key) -> InputEventKey:
    var event := InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    event.pressed = true
    return event


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected player and opponent GLB paths")
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

    var training = scene.get("move_training")
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    if not _check(training != null, "training node missing"):
        _finish()
        return
    if not _check(not bool(training.using_fallback), "recovered data was not used: " + str(training.data_error)):
        _finish()
        return
    _check(training.trainings.size() == 8,
        "expected 8 recovered trainings, got " + str(training.trainings.size()))
    var selectable: Array = training.selectable_trainings()
    _check(selectable.size() == 7,
        "expected 7 menu trainings, got " + str(selectable.size()))
    _check(scene.prototype_menu.main_labels().has("TRAINING"),
        "TRAINING row missing from the main menu")

    training.open()
    _check(training.state == "select" and training.visible, "select did not open")
    _check(training._title_label.text == "Training",
        "select title is " + String(training._title_label.text))
    var expected_titles := [
        "Free Training", "Movements", "Attacks", "Defense", "Grabs",
        "Special Moves", "End Attacks",
    ]
    for i: int in range(expected_titles.size()):
        if i < training._select_items.size():
            _check(training._select_items[i].text == String(expected_titles[i]),
                "menu row %d is %s" % [i, training._select_items[i].text])

    # Arrow navigation wraps through the recovered list.
    training.handle_input_event(_key(KEY_DOWN))
    _check(training.selected_index == 1, "DOWN did not select row 1")
    training.handle_input_event(_key(KEY_UP))
    _check(training.selected_index == 0, "UP did not return to row 0")

    # Every lesson training shows its recovered explanation before starting.
    for i: int in range(1, 7):
        training.selected_index = i
        training._accept_selected()
        var selected: Dictionary = selectable[i]
        _check(training.state == "intro",
            "training %d did not open the introduction" % i)
        _check(training.intro_full_text() == training.explanation_text(selected),
            "training %d introduction text mismatch" % i)
        training.handle_input_event(_key(KEY_ESCAPE))
        _check(training.state == "select", "ESC did not return to the list")

    # Movements lesson: select, read the introduction, start the first step.
    training.selected_index = 1
    training._accept_selected()
    var guard: int = 0
    while training.state == "intro" and guard < 8:
        training._intro_advance()
        guard += 1
    _check(training.state == "active", "movements lesson did not start")
    _check(training.steps.size() == 10,
        "movements step count is " + str(training.steps.size()))
    _check(training.step_title(training.current_step) == "Step Forward",
        "first movement title is " + training.step_title(training.current_step))
    _check(training._input_label.text.contains("RIGHT"),
        "first movement prompt is " + training._input_label.text)
    _check(bool(scene.training_mode), "training_mode is off during the lesson")

    # A wrong move must not advance a movement step.
    player.request_attack("high_punch")
    for _f: int in range(30):
        player._physics_process(1.0 / 60.0)
        training._process(1.0 / 60.0)
    _check(training.success_timer < 0.0 and training.current_step_index == 0,
        "a high punch advanced the Step Forward step")

    # The recovered movement itself advances the step.
    player.state = "idle"
    player.move_axis = Vector2(1.0, 0.0)
    player.set_held_directions({"right": true})
    for _f: int in range(20):
        player._physics_process(1.0 / 60.0)
        training._process(1.0 / 60.0)
        if training.success_timer >= 0.0:
            break
    _check(training.success_timer >= 0.0, "walking forward was not observed")
    training._process(3.0)
    _check(training.current_step_index == 1,
        "movement success did not advance to step 2")

    # ---------------------------------------------------------- data checks
    for t: int in range(1, 7):
        var entry: Dictionary = selectable[t]
        for step: Variant in Array(entry["steps"]):
            var step_dict: Dictionary = step
            if not _check(not Array(step_dict["success_animations"]).is_empty(),
                    "step %s/%d has no success condition" % [entry["title_key"], step_dict["index"]]):
                continue
            var title_key = step_dict.get("input_title_key", null)
            if title_key != null:
                var resolved: String = training.step_title(step_dict)
                _check(resolved != "" and resolved != String(title_key),
                    "input title not resolved for " + String(title_key))

    # -------------------------------------------------- success-condition map
    # Block: a blocked hit satisfies the defense block steps.
    training.current_training = selectable[3]
    training.steps = training.current_training["steps"]
    training._start_step(0)
    training.success_timer = -1.0
    training._on_combat_hit(player, player, "highblock", 0.0, true)
    _check(training.success_timer >= 0.0, "blocked hit was not mapped to highblock")

    # Parry/counter: the auto parry attack satisfies the counter steps.
    training._start_step(2)
    training.success_timer = -1.0
    training._on_attack_started("parry_attack")
    _check(training.success_timer >= 0.0, "parry attack was not mapped to parryattack")

    # Grab: the grab action satisfies the grab steps.
    training.current_training = selectable[4]
    training.steps = training.current_training["steps"]
    training._start_step(0)
    training.success_timer = -1.0
    training._on_attack_started("grab1")
    _check(training.success_timer >= 0.0, "grab1 was not mapped to grab1")

    # End attack: the end attack action satisfies the end-move steps.
    training.current_training = selectable[6]
    training.steps = training.current_training["steps"]
    training._start_step(0)
    training.success_timer = -1.0
    training._on_attack_started("endattack2")
    _check(training.success_timer >= 0.0, "endattack2 was not mapped to endattack2")

    # Fast advance: the recovered double-tap action advances the skip step.
    training.current_training = selectable[1]
    training.steps = training.current_training["steps"]
    training._start_step(8)
    training.success_timer = -1.0
    player.state = "idle"
    _check(player.request_skip("skipfwd"), "skipfwd clip is unavailable")
    for _f: int in range(30):
        player._physics_process(1.0 / 60.0)
        training._process(1.0 / 60.0)
        if training.success_timer >= 0.0:
            break
    _check(training.success_timer >= 0.0, "skipfwd was not observed")

    # The training input path itself turns two right presses into skipfwd.
    training._start_step(8)
    training.success_timer = -1.0
    player.state = "idle"
    var right_event := InputEventKey.new()
    right_event.keycode = KEY_D
    right_event.physical_keycode = KEY_D
    right_event.pressed = true
    training.handle_input_event(right_event)
    training.handle_input_event(right_event)
    _check(player._skip_time > 0.0, "double tap did not request skipfwd")

    # Legacy catalog is a fallback only, and it is intact if ever needed.
    var saved_trainings: Array = training.trainings
    var saved_fallback: bool = training.using_fallback
    training._load_legacy_catalog()
    _check(training.using_fallback and training.trainings.size() == 1,
        "legacy fallback did not load")
    _check(Array(training.trainings[0]["steps"]).size() == 25,
        "legacy fallback is not the 25-entry catalog")
    training.trainings = saved_trainings
    training.using_fallback = saved_fallback

    # Attacks lesson: the real attack signal must satisfy the mapped action.
    training.current_training = selectable[2]
    training.steps = training.current_training["steps"]
    training._start_step(0)
    _check(training.step_title(training.current_step) == "High Punch",
        "attack step 1 title is " + training.step_title(training.current_step))
    _check(bool(player.request_attack("high_punch")), "high_punch did not start")
    for _f: int in range(8):
        player._physics_process(1.0 / 60.0)
    _check(training.success_timer >= 0.0,
        "high_punch attack was not mapped to highpunch1")

    # Completion: the last step advances to the completion screen.
    training.success_timer = -1.0
    training._start_step(training.steps.size() - 1)
    training._success()
    training._process(30.0)
    _check(training.state == "complete",
        "last step did not reach completion (state=%s)" % training.state)
    _check(training._complete_title.text == "Attacks",
        "completion title is " + training._complete_title.text)

    # Pause menu: resume, then select training, then main menu.
    training.state = "active"
    training._open_pause()
    _check(training.state == "pause", "pause did not open")
    _check(paused, "pause did not pause the tree")
    training._pause_index = 0
    training._pause_accept()
    _check(training.state == "active" and not paused,
        "resume did not return to the lesson")
    training._open_pause()
    training._pause_index = 1
    training._pause_accept()
    _check(training.state == "select" and not bool(scene.training_mode),
        "select training did not end the lesson session")

    # Free training starts the sandbox (no lesson steps).
    training.selected_index = 0
    training._accept_selected()
    _check(training.state == "free", "free training did not start")
    training._open_pause()
    training._pause_index = 2
    training._pause_accept()
    _check(training.state == "hidden", "main menu did not close the training screen")

    print("TRAINING_NATIVE_VALIDATION=" + JSON.stringify({
        "trainings": training.trainings.size(),
        "menu_trainings": selectable.size(),
        "movements_steps": 10,
        "fallback": bool(training.using_fallback),
        "failures": failures,
    }))
    _finish()


func _finish() -> void:
    paused = false
    if failures.is_empty():
        quit(0)
    else:
        quit(1)

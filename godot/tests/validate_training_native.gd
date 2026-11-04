extends SceneTree
## Recovered training integration: data, navigation, submenus and success
## detection.
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
    if not _check(training.using_fallback != true,
            "recovered data was not used: " + str(training.data_error)):
        _finish()
        return
    _check(training.trainings.size() == 8,
        "expected 8 recovered trainings, got " + str(training.trainings.size()))
    var selectable: Array = training.selectable_trainings()
    _check(selectable.size() == 7,
        "expected 7 menu trainings, got " + str(selectable.size()))
    var unbound: Array = training.unbound_trainings()
    _check(unbound.size() == 1, "expected exactly one unbound training")
    if unbound.size() == 1:
        _check(String(unbound[0]["title_key"]) == "movements",
            "unbound entry is " + String(unbound[0]["title_key"]))
        _check(int(unbound[0]["index"]) == 7, "unbound entry is not index 7")
        _check(unbound[0].get("menu_option", null) == null,
            "unbound entry has a menu option")
    _check(scene.prototype_menu.main_labels().has("TRAINING"),
        "TRAINING row missing from the main menu")
    # ------------------------------------------------------ practice menu
    training.open()
    _check(training.state == "practice" and training.visible,
        "practice menu did not open")
    _check(training._practice_title.text == "Training Ground",
        "practice title is " + String(training._practice_title.text))
    _check(training._practice_items.size() == 2, "practice menu is not 2 rows")
    _check(training._practice_items[0].text == "Training",
        "practice row 0 is " + training._practice_items[0].text)
    _check(training._practice_items[1].text == "Style Editor",
        "practice row 1 is " + training._practice_items[1].text)

    var style_requests := [0]
    # main.gd connects the real Style Editor; isolate this data/navigation test
    # from opening (and loading) that screen, but assert the connection exists.
    var style_connections: Array = training.style_editor_requested.get_connections()
    _check(not style_connections.is_empty(),
        "main.gd did not connect the practice Style Editor request")
    for connection: Dictionary in style_connections:
        training.style_editor_requested.disconnect(connection["callable"])
    training.style_editor_requested.connect(func() -> void: style_requests[0] += 1)
    training._practice_index = 1
    training._accept_practice()
    _check(style_requests[0] == 1, "practice Style Editor did not emit the request")
    training._practice_index = 0
    training._accept_practice()
    _check(training.state == "select",
        "practice Training did not open the select list")
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
    training.handle_input_event(_key(KEY_UP))
    _check(training.selected_index == 6, "UP did not wrap to row 6")
    training.selected_index = 0

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
    _check(training.prompt_text().contains("RIGHT"),
        "first movement prompt is " + training.prompt_text())
    _check(scene.training_mode == true, "training_mode is off during the lesson")

    # Prompt panel: recovered textbox style, not an invented one.
    _check(training._prompt_label.uppercase, "prompt panel is not uppercase")
    _check(training._prompt_label.get_theme_font_size("font_size") == 16,
        "prompt panel font size is not the recovered text size")
    _check(training._prompt_label.get_theme_color("font_color") == Color.WHITE,
        "prompt panel text is not the recovered white")
    _check(training._prompt_panel.get_theme_stylebox("panel") is StyleBoxFlat,
        "prompt panel has no recovered rect style")
    var multi_step := -1
    for i: int in range(training.steps.size()):
        if Array(training.steps[i].get("input_sequences", [])).size() > 1:
            multi_step = i
            break
    if multi_step >= 0:
        training._start_step(multi_step)
        _check(training._prompt_page_icon.visible,
            "multi-sequence prompt did not show the recovered page icon")
        training._start_step(0)

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
    training.current_training = selectable[3]
    training.steps = training.current_training["steps"]
    training._start_step(0)
    training.success_timer = -1.0
    training._on_combat_hit(player, player, "highblock", 0.0, true)
    _check(training.success_timer >= 0.0, "blocked hit was not mapped to highblock")

    training._start_step(2)
    training.success_timer = -1.0
    training._on_attack_started("parry_attack")
    _check(training.success_timer >= 0.0, "parry attack was not mapped to parryattack")

    training.current_training = selectable[4]
    training.steps = training.current_training["steps"]
    training._start_step(0)
    training.success_timer = -1.0
    training._on_attack_started("grab1")
    _check(training.success_timer >= 0.0, "grab1 was not mapped to grab1")

    training.current_training = selectable[6]
    training.steps = training.current_training["steps"]
    training._start_step(0)
    training.success_timer = -1.0
    training._on_attack_started("endattack2")
    _check(training.success_timer >= 0.0, "endattack2 was not mapped to endattack2")

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

    training.current_training = selectable[2]
    training.steps = training.current_training["steps"]
    training._start_step(0)
    _check(training.step_title(training.current_step) == "High Punch",
        "attack step 1 title is " + training.step_title(training.current_step))
    _check(player.request_attack("high_punch"), "high_punch did not start")
    for _f: int in range(8):
        player._physics_process(1.0 / 60.0)
    _check(training.success_timer >= 0.0,
        "high_punch attack was not mapped to highpunch1")

    training.success_timer = -1.0
    training._start_step(training.steps.size() - 1)
    training._success()
    training._process(30.0)
    _check(training.state == "complete",
        "last step did not reach completion (state=%s)" % training.state)
    _check(training._complete_title.text == "Attacks",
        "completion title is " + training._complete_title.text)
    # ---------------------------------------------------------- pause menu
    training.state = "active"
    training._open_pause()
    _check(training.state == "pause", "pause did not open")
    _check(paused, "pause did not pause the tree")
    var pause_options: Array = training.pause_options()
    _check(pause_options.size() == 6,
        "pause has %d options, expected the six recovered ones" % pause_options.size())
    var pause_labels := []
    for i: int in range(training._pause_items.size()):
        pause_labels.append(String(training._pause_items[i].text))
    _check(pause_labels == [
        "Resume", "Select Training", "Style Editor", "Command list",
        "Settings", "Main Menu"], "pause labels are " + str(pause_labels))

    training._pause_index = 0
    training._pause_accept()
    _check(training.state == "active" and not paused,
        "resume did not return to the lesson")

    training._open_pause()
    training._pause_index = 3
    training._pause_accept()
    _check(training.state == "command_list", "command list did not open")
    _check(training.command_list_lines().size() > 5, "command list is empty")
    training._close_command_list()
    _check(training.state == "pause", "command list did not return to pause")

    training._pause_index = 4
    training._pause_status.text = ""
    training._pause_accept()
    _check(training.state == "settings",
        "settings option did not open the recovered in-game settings (state=%s)"
        % training.state)
    _check(training._settings_items.size() == 2,
        "recovered settings screen is not two rows")
    if training._settings_items.size() == 2:
        _check(training._settings_items[0].text == "Audio"
            and training._settings_items[1].text == "Languages",
            "recovered settings rows are " + str([
                training._settings_items[0].text,
                training._settings_items[1].text]))
    training._settings_close_to_pause()
    _check(training.state == "pause", "settings did not return to pause")

    var pause_style_requests := [0]
    training.style_editor_requested.connect(
        func() -> void: pause_style_requests[0] += 1)
    training._pause_index = 2
    training._pause_accept()
    _check(pause_style_requests[0] == 1,
        "pause Style Editor did not emit the request")

    training._pause_index = 1
    training._pause_accept()
    _check(training.state == "select" and scene.training_mode != true,
        "select training did not end the lesson session")
    # ------------------------------------------------- free training flow
    training.selected_index = 0
    training._accept_selected()
    _check(training.state == "free_config",
        "Free Training did not open the recovered free config")
    _check(training._free_config_title.text == "Free Training",
        "free config title is " + training._free_config_title.text)
    _check(training._free_config_items[0].text == "Select Fighter",
        "free config row is " + training._free_config_items[0].text)
    training._accept_free_config()
    _check(training.state == "select_fighter",
        "Select Fighter did not open the recovered dock")
    var dock: Array = training.fighter_dock_entries()
    _check(dock.size() == 15,
        "fighter dock has %d entries, expected 15" % dock.size())
    _check(String(dock[0]["basename"]) == "bl_brucelee_jacket_icon",
        "fighter dock order changed")
    _check(String(dock[15 - 1]["basename"]) == "bl_loming02_icon",
        "fighter dock last item changed")
    _check(training.current_opponent_key() == "brick",
        "current opponent is " + training.current_opponent_key())
    _check(dock[11]["selectable"] == true, "Brick Davis is not selectable")
    _check(dock[0]["selectable"] != true, "a Bruce skin was selectable as opponent")
    _check(dock[9]["selectable"] != true, "The Chief - B was selectable without a candidate")
    _check(dock[14]["selectable"] != true, "Lo Ming - B was selectable without a candidate")
    _check(training._fighter_name.text == "BRICK DAVIS",
        "default fighter name is " + training._fighter_name.text)
    training._accept_fighter()
    _check(training.state == "free", "free training did not start")
    _check(String(training.current_training["title_key"]) == "free_training",
        "free training is not the recovered free_training entry")

    training._open_pause()
    training._pause_index = 5
    training._pause_accept()
    _check(training.state == "hidden", "main menu did not close the training screen")

    print("TRAINING_NATIVE_VALIDATION=" + JSON.stringify({
        "trainings": training.trainings.size(),
        "menu_trainings": selectable.size(),
        "unbound": unbound.size(),
        "movements_steps": 10,
        "pause_options": pause_options.size(),
        "fighter_dock": dock.size(),
        "fallback": training.using_fallback == true,
        "failures": failures,
    }))
    _finish()


func _finish() -> void:
    paused = false
    if failures.is_empty():
        quit(0)
    else:
        quit(1)

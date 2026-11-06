extends SceneTree

const Controls = preload("res://scripts/prototype_controls.gd")

func _initialize() -> void:
    call_deferred("_run")

func _button(button_index: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
    var event: InputEventJoypadButton = InputEventJoypadButton.new()
    event.device = 0
    event.button_index = button_index
    event.pressed = pressed
    return event

func _press_button(button_index: JoyButton) -> void:
    Input.parse_input_event(_button(button_index, true))
    await process_frame
    Input.parse_input_event(_button(button_index, false))
    await process_frame

func _run() -> void:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", "")
    OS.set_environment("BRUCELEE_OPPONENT_GLB", "")
    Controls.ensure_default_actions()
    if not _validate_action_map():
        quit(1)
        return

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

    Input.action_press(Controls.MOVE_RIGHT, 1.0)
    scene._physics_process(0.016)
    Input.action_release(Controls.MOVE_RIGHT)
    if player.move_axis.x < 0.99:
        push_error("Controller movement action did not reach PortFighter")
        quit(1)
        return
    player.move_axis = Vector2.ZERO

    Input.action_press(Controls.GUARD, 1.0)
    scene._physics_process(0.016)
    Input.action_release(Controls.GUARD)
    if not player.guard_held:
        push_error("Controller guard action did not reach PortFighter")
        quit(1)
        return
    player.guard_held = false

    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    computer.reset_fighter(Vector3(2.0, 1.20, 0.0))
    # A real joypad button event must travel through the InputMap action and the
    # native link selection (record_standing_combo_press -> _try_follow_links).
    # The test never calls request_attack() for this path; the native selector
    # picks the first basic attack, which is the high_punch action.
    var attack_event: InputEventJoypadButton = _button(JOY_BUTTON_A, true)
    Input.parse_input_event(attack_event)
    await process_frame
    var routed_via_action: bool = Input.is_action_pressed(Controls.ATTACK_A)
    await process_frame
    var started_state: String = player.state
    var started_kind: String = player.attack_kind
    Input.parse_input_event(_button(JOY_BUTTON_A, false))
    await process_frame
    if not routed_via_action:
        push_error("Gamepad A did not route through the ATTACK_A action")
        quit(1)
        return
    if started_state != "startup" or started_kind != "high_punch":
        push_error(
            "Gamepad A did not start the native high_punch action "
            + "(state=%s kind=%s)" % [started_state, started_kind]
        )
        quit(1)
        return

    player.health = 50.0
    await _press_button(JOY_BUTTON_BACK)
    if player.health != 100.0 or computer.health != 100.0:
        push_error("Gamepad Back did not restart the match")
        quit(1)
        return

    await _press_button(JOY_BUTTON_START)
    var menu: PortPrototypeMenu = scene.get("prototype_menu")
    if (not paused or not menu.visible or not scene.get("menu_paused")
            or menu.menu_state != "pause"):
        push_error("Gamepad Start did not open and pause the menu")
        quit(1)
        return
    await _press_button(JOY_BUTTON_DPAD_DOWN)
    if menu.selected_command() != "restart":
        push_error("D-pad down did not navigate the pause menu")
        quit(1)
        return
    await _press_button(JOY_BUTTON_DPAD_UP)
    if menu.selected_command() != "resume":
        push_error("D-pad up did not navigate the pause menu")
        quit(1)
        return
    await _press_button(JOY_BUTTON_B)
    if paused or menu.visible or scene.get("menu_paused"):
        push_error("Gamepad B did not resume from the pause menu")
        quit(1)
        return

    scene._open_main_menu()
    await _press_button(JOY_BUTTON_DPAD_DOWN)
    await _press_button(JOY_BUTTON_DPAD_UP)
    if menu.selected_command() != "fight":
        push_error("D-pad navigation did not return to VS FIGHT")
        quit(1)
        return
    await _press_button(JOY_BUTTON_A)
    if paused or menu.visible or scene.get("main_menu_active"):
        push_error("Gamepad A did not confirm VS FIGHT")
        quit(1)
        return

    var training_before: bool = scene.get("training_mode")
    await _press_button(JOY_BUTTON_MISC1)
    var hud: PortHUD = scene.get("hud")
    var center: String = hud.center_message.text
    var training_after: bool = scene.get("training_mode")
    # MISC1 / L3 is the training toggle. With candidates present it enters
    # training (message "TRAINING · ..." and training_mode true); without them
    # it reports "TRAINING NEEDS ...". Both prove the joypad event reached the
    # toggle handler. The old "TRAINING NEEDS" expectation was stale because the
    # read-only package supplies candidate animations.
    if not center.begins_with("TRAINING"):
        push_error("Gamepad Misc1 did not route the training toggle (message=%s)" % center)
        quit(1)
        return
    if training_after == training_before and not center.begins_with("TRAINING NEEDS"):
        push_error("Gamepad Misc1 routed no training toggle side effect")
        quit(1)
        return

    print("CONTROLLER_INPUT_VALIDATION=" + JSON.stringify({
        "actions": Controls.ALL_ACTIONS.size(),
        "gamepad_attack": true,
        "gamepad_attack_kind": "high_punch",
        "gamepad_attack_via_action": true,
        "gamepad_guard": true,
        "gamepad_menu_navigation": true,
        "gamepad_movement_action": true,
        "gamepad_pause_resume": true,
        "gamepad_restart": true,
        "gamepad_training_toggle": true,
    }))
    quit(0)

func _validate_action_map() -> bool:
    for action: String in Controls.ALL_ACTIONS:
        if not InputMap.has_action(action):
            push_error("Missing controller action: " + action)
            return false
    var required_buttons: Dictionary = {
        Controls.ATTACK_A: JOY_BUTTON_A,
        Controls.ATTACK_B: JOY_BUTTON_X,
        Controls.ATTACK_C: JOY_BUTTON_Y,
        Controls.ATTACK_D: JOY_BUTTON_B,
        Controls.GUARD: JOY_BUTTON_LEFT_SHOULDER,
        Controls.RESTART: JOY_BUTTON_BACK,
        Controls.TOGGLE_TRAINING: JOY_BUTTON_MISC1,
        Controls.PAUSE: JOY_BUTTON_START,
        Controls.MENU_UP: JOY_BUTTON_DPAD_UP,
        Controls.MENU_DOWN: JOY_BUTTON_DPAD_DOWN,
        Controls.MENU_ACCEPT: JOY_BUTTON_A,
        Controls.MENU_CANCEL: JOY_BUTTON_B,
    }
    for action: String in required_buttons:
        if not _has_button(action, int(required_buttons[action])):
            push_error("Missing joypad button binding for " + action)
            return false
    if not _has_button(Controls.TOGGLE_TRAINING, JOY_BUTTON_LEFT_STICK):
        push_error("Missing left-stick-click training binding")
        return false
    if not _has_axis(Controls.MOVE_LEFT, JOY_AXIS_LEFT_X, -1.0):
        push_error("Missing left-stick negative X binding")
        return false
    if not _has_axis(Controls.MOVE_RIGHT, JOY_AXIS_LEFT_X, 1.0):
        push_error("Missing left-stick positive X binding")
        return false
    if not _has_axis(Controls.MOVE_UP, JOY_AXIS_LEFT_Y, -1.0):
        push_error("Missing left-stick negative Y binding")
        return false
    if not _has_axis(Controls.MOVE_DOWN, JOY_AXIS_LEFT_Y, 1.0):
        push_error("Missing left-stick positive Y binding")
        return false
    return true

func _has_button(action: String, button_index: int) -> bool:
    for event: InputEvent in InputMap.action_get_events(action):
        if event is InputEventJoypadButton:
            if (event as InputEventJoypadButton).button_index == button_index:
                return true
    return false

func _has_axis(action: String, axis: JoyAxis, value: float) -> bool:
    for event: InputEvent in InputMap.action_get_events(action):
        if event is InputEventJoypadMotion:
            var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
            if motion.axis == axis and is_equal_approx(motion.axis_value, value):
                return true
    return false

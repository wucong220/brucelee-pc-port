extends SceneTree
## Validate the PC-only main/pause menu against real local candidate resources.

const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")

func _initialize() -> void:
    call_deferred("_run")

func _key(keycode: Key) -> InputEventKey:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = keycode
    event.pressed = true
    return event

func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 2 or args.size() > 3:
        push_error("Expected Bruce GLB, Brick GLB, and optional menu PNG")
        quit(1)
        return
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    OS.set_environment("BRUCELEE_MAIN_MENU", "1")
    if args.size() == 3:
        OS.set_environment("BRUCELEE_MAINMENU_PATH", args[2])
        var background_error: String = CandidatePathGuard.external_path_error(
            args[2], "prototype menu background"
        )
        if not background_error.is_empty():
            push_error("Menu background guard failed: " + background_error)
            quit(1)
            return
    else:
        OS.set_environment("BRUCELEE_MAINMENU_PATH", "")
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
    var menu: PortPrototypeMenu = scene.get("prototype_menu")
    if menu == null or not menu.visible or not scene.get("main_menu_active"):
        push_error("Exported-menu override did not open the main menu")
        quit(1)
        return
    if root.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND:
        push_error("Window content scaling does not expand narrow viewports")
        quit(1)
        return
    var menu_screen: Control = menu.get_child(0) as Control
    var default_window_size: Vector2i = root.size
    root.size = Vector2i(480, 900)
    await process_frame
    if (menu_screen == null
            or menu_screen.size.x < 1279.0
            or menu_screen.size.y < 2398.0):
        push_error("Menu canvas did not fill the expanded 480x900 viewport")
        quit(1)
        return
    root.size = default_window_size
    await process_frame
    if menu.selected_command() != "fight" or menu.menu_state != "main":
        push_error("Main menu did not start on VS FIGHT")
        quit(1)
        return
    if args.size() == 3 and not menu.background_loaded:
        push_error("External menu background did not load: " + menu.background_error)
        quit(1)
        return
    Input.parse_input_event(_key(KEY_DOWN))
    await process_frame
    if menu.selected_command() != "training":
        push_error("Main menu did not select ground training")
        quit(1)
        return
    Input.parse_input_event(_key(KEY_UP))
    await process_frame
    Input.parse_input_event(_key(KEY_J))
    await process_frame
    if menu.visible or scene.get("main_menu_active") or scene.get("training_mode"):
        push_error("VS FIGHT did not leave the main menu")
        quit(1)
        return
    if paused:
        push_error("Tree remained paused after VS FIGHT")
        quit(1)
        return
    if player.state != "idle":
        push_error("Menu confirmation leaked into a gameplay attack")
        quit(1)
        return
    if menu.process_mode != Node.PROCESS_MODE_ALWAYS:
        push_error("Menu cannot process input while the tree is paused")
        quit(1)
        return
    player.set_physics_process(true)
    computer.set_physics_process(true)
    if not player.request_attack("punch"):
        push_error("Could not start a punch before pause validation")
        quit(1)
        return
    scene._unhandled_input(_key(KEY_ESCAPE))
    await process_frame
    if not menu.visible or not scene.get("menu_paused") or menu.menu_state != "pause":
        push_error("Escape did not open the pause menu")
        quit(1)
        return
    if not paused:
        push_error("Pause menu did not pause the scene tree")
        quit(1)
        return
    if menu.selected_command() != "resume":
        push_error("Pause menu did not start on resume")
        quit(1)
        return
    var paused_state_time: float = player.state_time
    var paused_position: Vector3 = player.position
    var paused_health: float = computer.health
    for _frame: int in 3:
        await physics_frame
    if (not is_equal_approx(player.state_time, paused_state_time)
            or not player.position.is_equal_approx(paused_position)
            or not is_equal_approx(computer.health, paused_health)):
        push_error("Fighter gameplay advanced while the pause menu was open")
        quit(1)
        return
    menu._input(_key(KEY_ESCAPE))
    await process_frame
    if menu.visible or scene.get("menu_paused"):
        push_error("Escape did not resume from the pause menu")
        quit(1)
        return
    if paused:
        push_error("Resume left the scene tree paused")
        quit(1)
        return
    await physics_frame
    if is_equal_approx(player.state_time, paused_state_time):
        push_error("Fighter gameplay did not resume after closing the pause menu")
        quit(1)
        return
    player.set_physics_process(false)
    computer.set_physics_process(false)
    scene._reset_match()
    scene._unhandled_input(_key(KEY_ESCAPE))
    menu.handle_key_event(_key(KEY_DOWN))
    if menu.selected_command() != "restart":
        push_error("Pause menu did not select restart")
        quit(1)
        return
    menu.handle_key_event(_key(KEY_DOWN))
    if menu.selected_command() != "main_menu":
        push_error("Pause menu did not select main menu")
        quit(1)
        return
    menu.handle_key_event(_key(KEY_ENTER))
    await process_frame
    if not menu.visible or not scene.get("main_menu_active") or menu.menu_state != "main":
        push_error("Pause menu did not return to the main menu")
        quit(1)
        return
    menu.handle_key_event(_key(KEY_DOWN))
    menu.handle_key_event(_key(KEY_ENTER))
    await process_frame
    if menu.visible or not scene.get("training_mode") or scene.get("main_menu_active"):
        push_error("Ground training did not start from the main menu")
        quit(1)
        return
    print("PROTOTYPE_MENU_VALIDATION=" + JSON.stringify({
        "background_loaded": menu.background_loaded,
        "fight_started": true,
        "pause_froze_gameplay": true,
        "pause_resumed": true,
        "training_started": true,
    }))
    quit(0)

extends SceneTree
## Windowed screenshots of the recovered training flow.
##
##   godot --path godot --script res://tests/capture_training_native.gd -- <shots dir>
##
## Drives the real main menu with synthesised key events: TRAINING -> practice
## menu -> select -> free config -> fighter dock -> Movements lesson ->
## introduction -> steps -> pause (six options) -> command list -> completion ->
## free training.  All captures are 1280x720.

const Controls = preload("res://scripts/prototype_controls.gd")

var shots: String = ""
var failures: Array[String] = []
var scene: Node = null
var training = null
var player: PortFighter = null


func _initialize() -> void:
    call_deferred("_run")


func _press(keycode: Key) -> void:
    var down := InputEventKey.new()
    down.keycode = keycode
    down.physical_keycode = keycode
    down.pressed = true
    Input.parse_input_event(down)
    await process_frame
    await process_frame
    var up := InputEventKey.new()
    up.keycode = keycode
    up.physical_keycode = keycode
    up.pressed = false
    Input.parse_input_event(up)
    await process_frame


func _capture(name: String) -> void:
    if DisplayServer.get_name() == "headless":
        print("SHOT_SKIPPED_HEADLESS " + name)
        return
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null:
        failures.append("null image " + name)
        return
    var path: String = shots.path_join(name)
    var error: int = image.save_png(path)
    var size: int = 0
    if FileAccess.file_exists(path):
        size = FileAccess.get_file_as_bytes(path).size()
    print("SHOT %s %dx%d err=%d bytes=%d" % [
        name, image.get_width(), image.get_height(), error, size])
    if error != OK or image.get_width() != 1280 or image.get_height() != 720:
        failures.append("bad capture " + name)
    if size < 10000:
        failures.append("blank capture " + name)


func _expect(good: bool, message: String) -> void:
    if not good:
        failures.append(message)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    shots = String(args[0]) if args.size() > 0 else "user://training_native_shots"
    DirAccess.make_dir_recursive_absolute(shots)

    OS.set_environment("BRUCELEE_MAIN_MENU", "1")
    OS.set_environment("BRUCELEE_LANG", "en")
    OS.set_environment("BRUCELEE_PLAYER_GLB",
        "D:\\BruceLeeWork\\bruce-full-20261103\\out\\bruce_full_121_20261103.glb")
    OS.set_environment("BRUCELEE_OPPONENT_GLB",
        "D:\\BruceLeeWork\\brick-full-20261103\\candidate\\brick_full_94_20261103.glb")
    OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT",
        "D:\\BaiduSyncdisk\\AI项目\\李小龙\\private_assets\\appdata-msix\\BruceLee-PC-Port\\candidate-textures-verified-20261029")
    OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT",
        "D:\\BaiduSyncdisk\\AI项目\\李小龙\\private_assets\\appdata-msix\\BruceLee-PC-Port\\brick-textures-20261030")

    root.size = Vector2i(1280, 720)
    scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame

    var menu = scene.get("prototype_menu")
    training = scene.get("move_training")
    player = scene.get("player")
    _expect(menu != null and menu.visible, "main menu did not open")
    var row: int = menu.main_commands().find("move_training")
    _expect(row >= 0, "TRAINING row missing")
    for _i: int in range(row):
        await _press(KEY_DOWN)
    _expect(String(menu.selected_command()) == "move_training",
        "menu navigation did not reach TRAINING")
    await _capture("00_main_menu_training.png")

    await _press(KEY_ENTER)
    _expect(String(training.state) == "practice", "practice menu did not open")
    _expect(training._practice_items[0].text == "Training",
        "practice menu row is not Training")
    await _capture("01_training_practice_menu.png")

    await _press(KEY_ENTER)
    _expect(String(training.state) == "select", "training select did not open")
    print("STATE select rows=%d" % training.selectable_trainings().size())
    await _capture("02_training_select.png")

    await _press(KEY_DOWN)
    await _press(KEY_DOWN)
    _expect(training.selected_index == 2, "DOWN did not move the selection")
    await _capture("03_training_select_moved.png")

    # Free training: recovered config -> recovered fighter dock.
    training.selected_index = 0
    training._refresh_select()
    await _press(KEY_ENTER)
    _expect(String(training.state) == "free_config", "free config did not open")
    await _capture("04_free_training_config.png")
    await _press(KEY_ENTER)
    _expect(String(training.state) == "select_fighter", "fighter dock did not open")
    print("STATE select_fighter entries=%d name=%s" % [
        training.fighter_dock_entries().size(), training._fighter_name.text])
    await _capture("05_training_select_fighter.png")

    # A recovered dock item with no runtime candidate fails closed.
    training._fighter_index = 0
    training._refresh_select_fighter()
    training._accept_fighter()
    _expect(String(training._fighter_status.text).contains("NOT AVAILABLE"),
        "locked fighter did not fail closed")
    await _capture("06_training_select_fighter_locked.png")

    # Back to the select list.
    await _press(KEY_ESCAPE)
    await _press(KEY_ESCAPE)
    _expect(String(training.state) == "select", "ESC did not return to the list")

    training.selected_index = 1
    training._refresh_select()
    await _press(KEY_ENTER)
    _expect(String(training.state) == "intro", "introduction did not open")
    print("STATE intro text=%s" % training._intro_label.text.substr(0, 40))
    await _capture("07_training_introduction.png")

    # The recovered textbox is paginated; advance every page with ENTER.
    for _page: int in range(8):
        if String(training.state) != "intro":
            break
        await _press(KEY_ENTER)
    _expect(String(training.state) == "active", "Movements lesson did not start")
    print("STATE active step=%s input=%s" % [
        training.step_title(training.current_step),
        training.prompt_text().replace("\n", " / ")])
    await _capture("08_lesson_step_01.png")

    # Real movement input: hold D until the recovered stepfwd action is seen.
    Input.action_press(Controls.MOVE_RIGHT)
    for _f: int in range(40):
        await process_frame
        if training.success_timer >= 0.0:
            break
    await _capture("09_lesson_success.png")
    Input.action_release(Controls.MOVE_RIGHT)
    _expect(training.success_timer >= 0.0, "stepfwd was not observed")

    # Pause: all six recovered options, then the recovered command list.
    await _press(KEY_ESCAPE)
    _expect(String(training.state) == "pause", "pause did not open")
    await _capture("10_training_pause.png")
    training._pause_index = 3
    await _press(KEY_ENTER)
    _expect(String(training.state) == "command_list", "command list did not open")
    await _capture("11_training_command_list.png")
    await _press(KEY_ESCAPE)
    _expect(String(training.state) == "pause", "command list did not return to pause")
    training._pause_index = 0
    await _press(KEY_ENTER)
    _expect(String(training.state) == "active", "resume did not return to the lesson")

    # Completion reached through the normal success path.
    training.success_timer = -1.0
    training._start_step(training.steps.size() - 1)
    training._success()
    training._process(30.0)
    _expect(String(training.state) == "complete", "completion did not open")
    await _capture("12_training_complete.png")

    await _press(KEY_ENTER)
    _expect(String(training.state) == "select", "ENTER did not return to the list")
    await _capture("13_back_to_select.png")

    # Free training with the current opponent (Brick) starts in-session.
    training.selected_index = 0
    training._refresh_select()
    await _press(KEY_ENTER)
    _expect(String(training.state) == "free_config", "free config did not reopen")
    await _press(KEY_ENTER)
    _expect(String(training.state) == "select_fighter",
        "fighter dock did not reopen")
    await _press(KEY_ENTER)
    _expect(String(training.state) == "free", "free training did not open")
    await _capture("14_free_training.png")

    print("TRAINING_NATIVE_CAPTURE=%d failures" % failures.size())
    for failure in failures:
        print("FAILED: " + failure)
    quit(0 if failures.is_empty() else 1)

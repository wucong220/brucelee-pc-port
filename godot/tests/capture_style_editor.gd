extends SceneTree
## Windowed screenshot capture of the opt-in Style Editor.
##
##   godot --path godot --script res://tests/capture_style_editor.gd -- <shots dir>
##
## Drives the real main menu with synthesized key events (same path as a
## player), opens STYLE EDITOR, walks category -> personality -> special ->
## hpunch -> fighter cursor -> save -> reset confirm -> help, and captures each
## step at 1280x720. It also captures the flag-on main menu so the new row is
## visible in the same evidence set.

const PrototypeControls = preload("res://scripts/prototype_controls.gd")

var shots: String = ""
var failures: Array = []
var scene: Node = null
var menu = null
var screen = null
var _backed_up_text: String = ""
var _had_style_file: bool = false


func _initialize() -> void:
    call_deferred("_run")


func _press(keycode: Key) -> void:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = keycode
    event.physical_keycode = keycode
    event.pressed = true
    Input.parse_input_event(event)
    await process_frame
    await process_frame


func _capture(name: String) -> void:
    if DisplayServer.get_name() == "headless":
        print("SHOT_SKIPPED_HEADLESS %s" % name)
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
        name, image.get_width(), image.get_height(), error, size
    ])
    if error != OK or image.get_width() != 1280 or image.get_height() != 720:
        failures.append("capture " + name)
    if size < 12000:
        failures.append("blank capture " + name)


func _backup_style_file() -> void:
    ## The capture saves selection(s); put the isolated project user file back so
    ## repeated runs start from the same state and no evidence run is cumulative.
    const STYLE_PATH := "user://style_selections.json"
    if FileAccess.file_exists(STYLE_PATH):
        _had_style_file = true
        _backed_up_text = FileAccess.get_file_as_string(STYLE_PATH)
        DirAccess.remove_absolute(ProjectSettings.globalize_path(STYLE_PATH))


func _finish(code: int) -> void:
    const STYLE_PATH := "user://style_selections.json"
    if _had_style_file:
        var file: FileAccess = FileAccess.open(STYLE_PATH, FileAccess.WRITE)
        if file != null:
            file.store_string(_backed_up_text)
            file.close()
    elif FileAccess.file_exists(STYLE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(STYLE_PATH))
    quit(code)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    _backup_style_file()
    shots = String(args[0]) if args.size() > 0 else "user://style_editor_shots"
    DirAccess.make_dir_recursive_absolute(shots)
    OS.set_environment("BRUCELEE_MAIN_MENU", "1")
    OS.set_environment("BRUCELEE_STYLE_EDITOR", "1")
    OS.set_environment("BRUCELEE_PROGRESS", "")
    OS.set_environment("BRUCELEE_LANG", "en")
    OS.set_environment("BRUCELEE_PLAYER_GLB", "")
    OS.set_environment("BRUCELEE_OPPONENT_GLB", "")
    PrototypeControls.ensure_default_actions()
    root.size = Vector2i(1280, 720)
    scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame

    menu = scene.get("prototype_menu")
    if menu == null or not menu.visible or menu.menu_state != "main":
        push_error("main menu did not open")
        _finish(1)
        return
    var commands: Array = menu.main_commands()
    var row: int = commands.find("style_editor")
    if row < 0:
        push_error("STYLE EDITOR row missing while BRUCELEE_STYLE_EDITOR=1")
        _finish(1)
        return
    print("MAIN_MENU_ROW style_editor index=%d of %d" % [row, commands.size()])
    await _capture("00_main_menu_row.png")

    for i in range(row):
        await _press(KEY_DOWN)
    if String(menu.selected_command()) != "style_editor":
        push_error("keyboard navigation did not reach STYLE EDITOR")
        _finish(1)
        return
    await _press(KEY_ENTER)
    screen = scene.get("style_editor")
    if screen == null or not screen.is_open() or screen.screen_name() != "category":
        push_error("STYLE EDITOR did not open on the category screen")
        _finish(1)
        return
    await _capture("01_category.png")

    await _press(KEY_ENTER)
    if screen.screen_name() != "fighter" or screen.group_key() != "personality/personality":
        push_error("personality row did not open the personality dock")
        _finish(1)
        return
    await _capture("02_personality_dock.png")

    await _press(KEY_ESCAPE)
    await _press(KEY_DOWN)
    await _press(KEY_ENTER)
    if screen.screen_name() != "special":
        push_error("special row did not open the special submenu")
        _finish(1)
        return
    await _capture("03_special_menu.png")

    await _press(KEY_ENTER)
    if screen.screen_name() != "fighter" or screen.group_key() != "special/hpunch":
        push_error("hpunch row did not open the fighter dock")
        _finish(1)
        return
    await _capture("04_hpunch_dock.png")

    await _press(KEY_RIGHT)
    await _press(KEY_RIGHT)
    if screen.fighter_cursor() != 2:
        push_error("RIGHT did not move the fighter cursor")
        _finish(1)
        return
    await _capture("05_hpunch_master_cursor.png")

    await _press(KEY_ENTER)
    if screen.saved_entry_id() != "hpunchmaster":
        push_error("save did not persist the highlighted entry")
        _finish(1)
        return
    await _capture("06_hpunch_saved.png")

    await _press(KEY_ESCAPE)
    await _press(KEY_ESCAPE)
    for i in range(4):
        await _press(KEY_DOWN)
    await _press(KEY_ENTER)
    if screen.screen_name() != "reset":
        push_error("reset row did not open the confirmation")
        _finish(1)
        return
    await _capture("07_reset_confirm.png")
    await _press(KEY_ESCAPE)

    await _press(KEY_H)
    if screen.screen_name() != "help":
        push_error("H did not open help")
        _finish(1)
        return
    await _capture("08_help.png")
    await _press(KEY_ESCAPE)
    await _press(KEY_ESCAPE)
    if screen.is_open():
        push_error("ESC did not close the editor back to the menu")
        _finish(1)
        return
    await process_frame
    await _capture("09_back_to_main_menu.png")

    print("STYLE EDITOR CAPTURE: %d failures" % failures.size())
    for failure in failures:
        print("FAILED: " + String(failure))
    _finish(0 if failures.is_empty() else 1)



extends SceneTree
## Validate the prototype menu's OPPONENTS submenu on the real main.tscn.
##
## Covers, on a real window and real layout:
##  - the main menu is a 9-item list whose 8th entry opens the OPPONENTS submenu
##  - the submenu lists BRICK (default), SIN FU, MASTER, KEN and BACK
##  - keyboard: DOWN/UP wrap, ENTER/J/A apply, ESC/B cancel back to main
##  - mouse: hover selects only after real mouse motion, left click applies
##  - no item or panel is clipped at 1280x720 (project canvas) or at 868x517
##  - main.gd MENU_OPPONENT_CONFIG matches the menu commands exactly and every
##    configured path exists
##  - applying each opponent writes BRUCELEE_OPPONENT_* and reloads main.tscn,
##    and the reloaded computer loads that candidate GLB + textures + idle clip
##
## Run (windowed, not headless):
##   <godot> --path project --script res://tests/validate_opponent_menu.gd

var _captured: Array[String] = []
var _failures: Array[String] = []
var _layout_samples: Array = []
var _reload_samples: Array = []
var _report: Dictionary = {}
var _menu: PortPrototypeMenu = null

const EXPECTED_BRICK_IDLE := "m03_idle_01"
const EXPECTED_IDLE := {
    "brick": "m03_idle_01",
    "sinfu": "m04_idle_01",
    "master": "m04_e01_idle_01",
    "ken": "m02_idle_01",
    "shenlo": "m04_e03_idle_01",
}

func _initialize() -> void:
    call_deferred("_run")

func _key(keycode: Key) -> InputEventKey:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = keycode
    event.pressed = true
    return event

func _arrow(keycode: Key) -> void:
    Input.parse_input_event(_key(keycode))
    await process_frame
    await process_frame

func _check(condition: bool, message: String) -> bool:
    if condition:
        return true
    _failures.append(message)
    push_error("OPPONENT_MENU: " + message)
    return false

func _on_command(command: String) -> void:
    _captured.append(command)

func _run() -> void:
    for variable: String in [
        "BRUCELEE_OPPONENT_GLB", "BRUCELEE_OPPONENT_TEXTURE_ROOT",
        "BRUCELEE_OPPONENT_CLIP_PREFIX", "BRUCELEE_OPPONENT_MASTER",
        "BRUCELEE_OPPONENT_MATERIAL_PROFILE",
    ]:
        OS.set_environment(variable, "")
    OS.set_environment("BRUCELEE_MAIN_MENU", "1")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    _menu = scene.get("prototype_menu") as PortPrototypeMenu
    if not _check(_menu != null and _menu.visible, "main menu did not open"):
        return _finish()
    _check(_menu.background_loaded,
            "menu background did not load: " + _menu.background_error)
    _report["menu_background"] = {
        "loaded": _menu.background_loaded,
        "path": _menu.background_path,
        "error": _menu.background_error,
        "accept_sfx": _menu.accept_sfx != null,
    }
    _menu.command_requested.disconnect(Callable(scene, "_on_menu_command"))
    _menu.command_requested.connect(_on_command)

    var menu_consts: Dictionary = _menu.get_script().get_script_constant_map()
    var main_consts: Dictionary = scene.get_script().get_script_constant_map()
    var main_commands: Array = menu_consts.get("MAIN_COMMANDS", [])
    var main_labels: Array = menu_consts.get("MAIN_LABELS", [])
    var scene_commands: Array = menu_consts.get("SCENE_COMMANDS", [])
    var opponent_commands: Array = menu_consts.get("OPPONENT_COMMANDS", [])
    var opponent_labels: Array = menu_consts.get("OPPONENT_LABELS", [])
    var configs: Dictionary = main_consts.get("MENU_OPPONENT_CONFIG", {})
    _report["main_commands"] = main_commands
    _report["main_labels"] = main_labels
    _report["scene_commands"] = scene_commands
    _report["opponent_commands"] = opponent_commands
    _report["opponent_labels"] = opponent_labels
    _report["menu_opponent_config"] = configs

    _check(main_commands.size() == 9, "main menu should list 9 commands")
    _check(main_labels.size() == main_commands.size(), "main labels/commands mismatch")
    _check(main_commands.size() > 0 and main_commands[6] == "scenes",
            "7th main entry should stay the SCENES submenu")
    _check(main_commands.size() > 7 and main_commands[7] == "opponents",
            "8th main entry should be the OPPONENTS submenu")
    _check(main_labels[7] == "OPPONENTS", "main menu label should read OPPONENTS")
    _check(scene_commands.size() == 11, "SCENES submenu should stay unchanged")
    _check(opponent_commands.size() == 6 and opponent_labels.size() == 6,
            "OPPONENTS submenu should list 4 opponents plus BACK")
    _check(opponent_commands == ["brick", "sinfu", "master", "ken", "shenlo",
            "opponents_back"],
            "OPPONENTS command order should be BRICK, SIN FU, MASTER, KEN, SHEN LO, BACK")
    _check(opponent_labels == ["BRICK", "SIN FU", "MASTER", "KEN", "SHEN LO", "BACK"],
            "OPPONENTS labels should be BRICK, SIN FU, MASTER, KEN, SHEN LO, BACK")
    _check(String(opponent_commands[0]) == "brick", "BRICK should be the default entry")
    _check(String(opponent_commands[opponent_commands.size() - 1]) == "opponents_back",
            "OPPONENTS submenu should end with BACK")

    # ---- main.gd configuration table.
    for command: String in ["brick", "sinfu", "master", "ken", "shenlo"]:
        _check(configs.has(command), "main.gd has no opponent config for " + command)
    _check(configs.size() == 5, "main.gd should configure exactly 5 opponents")
    for command: Variant in configs:
        var config: Dictionary = configs[command]
        for key: String in ["glb", "texture_root", "clip_prefix", "master",
                "material_profile"]:
            _check(config.has(key), "%s config is missing %s" % [command, key])
        var glb: String = String(config.get("glb", ""))
        var texture_root: String = String(config.get("texture_root", ""))
        _check(not glb.is_empty(), command + " GLB path is empty")
        _check(FileAccess.file_exists(glb), command + " GLB does not exist: " + glb)
        _check(DirAccess.dir_exists_absolute(texture_root),
                command + " texture root does not exist: " + texture_root)
        _check(String(config.get("material_profile", "")) in ["body", "body_hair"],
                command + " material profile is not a loader profile")
    if configs.has("sinfu"):
        var sinfu: Dictionary = configs["sinfu"]
        _check(String(sinfu["glb"]).ends_with("sinfu_hair_two-skin_62_20261103.glb"),
                "SinFu GLB should be the tested 62-clip two-skin candidate")
        _check(String(sinfu["texture_root"]) == "D:\\BruceLeeWork\\sinfu-tex",
                "SinFu texture root should be sinfu-tex")
        _check(String(sinfu["clip_prefix"]) == "m04", "SinFu clip prefix should be m04")
        _check(String(sinfu["master"]) == "", "SinFu must not set MASTER")
    if configs.has("master"):
        var master: Dictionary = configs["master"]
        _check(String(master["glb"]).ends_with(
                "master_hair_two-skin_kungfu13_20261103.glb"),
                "Master GLB should be the tested kungfu13 two-skin candidate")
        _check(String(master["texture_root"]).ends_with(
                "master-candidate-20261103\\textures"),
                "Master texture root should be master-candidate-20261103/textures")
        _check(String(master["clip_prefix"]) == "", "Master must not set a clip prefix")
        _check(String(master["master"]) == "1", "Master must set MASTER=1")
    if configs.has("ken"):
        var ken: Dictionary = configs["ken"]
        _check(String(ken["glb"]).ends_with("ken_hair_two-skin_native45_20261103.glb"),
                "Ken GLB should be the tested native45 two-skin candidate")
        _check(String(ken["texture_root"]).ends_with(
                "character-integration-fixed-20261103\\assets\\ken-textures"),
                "Ken texture root should be the fixed integration ken-textures")
        _check(String(ken["clip_prefix"]) == "m02", "Ken clip prefix should be m02")
        _check(String(ken["master"]) == "", "Ken must not set MASTER")
        _check(String(ken["material_profile"]) == "body_hair",
                "Ken must use the body_hair material profile")
    if configs.has("brick"):
        var brick: Dictionary = configs["brick"]
        _check(String(brick["glb"]).ends_with("brick_candidate_brutal_20261103.glb"),
                "Brick should restore the shipped Brick candidate")
        _check(String(brick["material_profile"]) == "body",
                "Brick must use the body material profile")

    # ---- layout: no clipping at the 1280x720 canvas and at a 868x517 window.
    var shipped_size: Vector2i = root.size
    _report["shipped_window"] = [shipped_size.x, shipped_size.y]
    var sizes: Array[Vector2i] = [
        Vector2i(1280, 720),   # project viewport size
        Vector2i(868, 517),    # requested small window
        Vector2i(1920, 1080),
        Vector2i(1024, 600),
        Vector2i(480, 900),    # narrow window -> taller canvas
    ]
    if shipped_size != Vector2i(1280, 720) and shipped_size != Vector2i(868, 517):
        sizes.append(shipped_size)
    for size: Vector2i in sizes:
        root.size = size
        await process_frame
        await process_frame
        _menu.show_main_menu()
        await process_frame
        _check_layout(size, 9, "main")
        await _capture_layout_pixels(size)
        _menu.show_opponent_menu()
        await process_frame
        _check_layout(size, 6, "opponents")
        await _capture_layout_pixels(size)
    root.size = Vector2i(1280, 720)
    await process_frame
    await process_frame

    # ---- keyboard: main -> OPPONENTS submenu.
    _menu.show_main_menu()
    await process_frame
    _check(_menu.selected_command() == "fight", "main menu should start on VS FIGHT")
    for _i: int in 7:
        await _arrow(KEY_DOWN)
    _check(_menu.selected_command() == "opponents", "DOWN x7 should reach OPPONENTS")
    _captured.clear()
    await _arrow(KEY_ENTER)
    _check(_menu.menu_state == "opponents" and _menu.visible,
            "ENTER on OPPONENTS should open the submenu")
    _check(_captured.is_empty(), "opening the OPPONENTS submenu must not emit a command")
    _check(_menu.selected_command() == "brick",
            "OPPONENTS submenu should start on BRICK")

    # ---- keyboard: wrap in the submenu.
    await _arrow(KEY_UP)
    _check(_menu.selected_command() == "opponents_back",
            "UP from BRICK should wrap to BACK")
    await _arrow(KEY_DOWN)
    _check(_menu.selected_command() == "brick", "DOWN from BACK should wrap to BRICK")

    # ---- keyboard: every opponent is reachable and emits its command.
    var emitted: Array[String] = []
    for index: int in range(5):
        _menu.show_opponent_menu()
        await process_frame
        for _i: int in range(index):
            await _arrow(KEY_DOWN)
        var command: String = _menu.selected_command()
        _captured.clear()
        await _arrow(KEY_J)  # ATTACK_A also confirms the menu
        emitted.append(command)
        _check(_captured == [command], "J on " + command + " should emit exactly that command")
    _check(emitted == ["brick", "sinfu", "master", "ken", "shenlo"],
            "keyboard order mismatch: " + str(emitted))

    # ---- keyboard: BACK and ESC return to the main menu without emitting.
    _menu.show_opponent_menu()
    await process_frame
    for _i: int in 5:
        await _arrow(KEY_DOWN)
    _check(_menu.selected_command() == "opponents_back", "DOWN x5 should reach BACK")
    _captured.clear()
    await _arrow(KEY_ENTER)
    _check(_menu.menu_state == "main" and _menu.selected_command() == "opponents",
            "BACK should return to the OPPONENTS entry of the main menu")
    _check(_captured.is_empty(), "BACK must not emit an opponent command")
    _menu.show_opponent_menu()
    await process_frame
    _captured.clear()
    await _arrow(KEY_ESCAPE)
    _check(_menu.menu_state == "main" and _captured.is_empty(),
            "ESC in the OPPONENTS submenu should return to the main menu")

    # ---- mouse: motion hovers, left click applies.
    _menu.show_main_menu()
    await process_frame
    _check(_menu.selected_index == 0 and _menu.hover_index == -1,
            "a fresh main menu should start on VS FIGHT with no hover applied")
    var hover_row: int = 7
    var hover_pos: Vector2 = _menu.item_labels[hover_row].get_global_rect().get_center()
    await _send_mouse_motion(hover_pos)
    _check(_menu.selected_index == hover_row,
            "hover should select OPPONENTS (got %d)" % _menu.selected_index)
    _check(_menu.hover_index == hover_row, "hover index should record the hovered row")
    _captured.clear()
    await _click(_menu.item_labels[7].get_global_rect().get_center())
    _check(_menu.menu_state == "opponents" and _captured.is_empty(),
            "clicking OPPONENTS should open the submenu")
    var ken_row: int = 3
    await _send_mouse_motion(_menu.item_labels[ken_row].get_global_rect().get_center())
    _check(_menu.selected_command() == "ken",
            "moving the pointer over KEN should select it")
    _captured.clear()
    await _click(_menu.item_labels[2].get_global_rect().get_center())
    _check(_captured == ["master"], "left click should apply the clicked MASTER row")
    _menu.show_opponent_menu()
    await process_frame
    _captured.clear()
    await _click(_menu.item_labels[5].get_global_rect().get_center())
    _check(_menu.menu_state == "main" and _captured.is_empty(),
            "clicking BACK should return to the main menu")

    # ---- apply each opponent for real: env + main.tscn reload + candidate load.
    _menu.command_requested.disconnect(_on_command)
    _menu.command_requested.connect(Callable(scene, "_on_menu_command"))
    for command: String in ["sinfu", "master", "ken", "shenlo", "brick"]:
        scene = current_scene
        if scene == null:
            _check(false, "no current scene before switching to " + command)
            break
        scene._request_opponent_switch(command)
        scene = await _await_reloaded_scene(scene)
        if scene == null:
            _check(false, "opponent switch did not reload main.tscn: " + command)
            break
        _check_reloaded(scene, command, configs.get(command, {}))
    _report["reloads"] = _reload_samples

    return _finish()

func _await_reloaded_scene(previous: Node) -> Node:
    for _i: int in 900:
        await process_frame
        if current_scene != null and current_scene != previous:
            for _j: int in 30:
                await process_frame
            return current_scene
    return null

func _check_reloaded(scene: Node, command: String, config: Dictionary) -> void:
    var computer: PortFighter = scene.get("computer")
    _check(not paused, command + ": scene switch left the scene tree paused")
    _check(not bool(scene.get("main_menu_active")),
            command + ": reloaded scene should start in gameplay, not on the menu")
    _check(OS.get_environment("BRUCELEE_MAIN_MENU") == "0",
            command + ": BRUCELEE_MAIN_MENU should be 0 after applying")
    var env_map: Dictionary = {
        "BRUCELEE_OPPONENT_GLB": "glb",
        "BRUCELEE_OPPONENT_TEXTURE_ROOT": "texture_root",
        "BRUCELEE_OPPONENT_CLIP_PREFIX": "clip_prefix",
        "BRUCELEE_OPPONENT_MASTER": "master",
        "BRUCELEE_OPPONENT_MATERIAL_PROFILE": "material_profile",
    }
    for variable: String in env_map:
        var key: String = String(env_map[variable])
        _check(OS.get_environment(variable) == String(config.get(key, "")),
                "%s: %s was not applied (%s)" % [
                    command, variable, OS.get_environment(variable),
                ])
    if computer == null:
        _check(false, command + ": reloaded scene has no computer fighter")
        return
    computer.set_physics_process(false)
    var expected_idle: String = String(EXPECTED_IDLE[command])
    var actual_idle: String = computer.candidate_animation_clip
    if actual_idle != expected_idle:
        var clip_paths: Dictionary = computer.get("_candidate_clip_paths")
        if String(clip_paths.get("idle", "")) == expected_idle:
            computer.move_axis = Vector2.ZERO
            computer.reset_fighter(Vector3(2.0, 1.20, 0.0))
            computer._animate_candidate()
            actual_idle = computer.candidate_animation_clip
    _check(computer.candidate_loaded,
            command + ": candidate GLB did not load: " + computer.candidate_load_error)
    _check(computer.candidate_textures_loaded,
            command + ": candidate textures did not load: "
            + computer.candidate_texture_error)
    _check(actual_idle == expected_idle,
            "%s: idle clip is %s, expected %s" % [command, actual_idle, expected_idle])
    _check(absf(computer.candidate_visual_height - 1.8) <= 0.01,
            "%s: candidate height %.4f" % [command, computer.candidate_visual_height])
    _reload_samples.append({
        "command": command,
        "glb": OS.get_environment("BRUCELEE_OPPONENT_GLB"),
        "texture_root": OS.get_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT"),
        "clip_prefix": OS.get_environment("BRUCELEE_OPPONENT_CLIP_PREFIX"),
        "master": OS.get_environment("BRUCELEE_OPPONENT_MASTER"),
        "material_profile": OS.get_environment("BRUCELEE_OPPONENT_MATERIAL_PROFILE"),
        "candidate_loaded": computer.candidate_loaded,
        "textures_loaded": computer.candidate_textures_loaded,
        "texture_reason": computer.candidate_texture_reason,
        "idle_clip": computer.candidate_animation_clip,
        "visual_height": computer.candidate_visual_height,
        "load_error": computer.candidate_load_error,
    })

func _check_layout(size: Vector2i, expected_items: int, state: String) -> void:
    var report: Dictionary = _menu.layout_report()
    var screen: Array = report["screen"]
    var clipped: Array = report["clipped_items"]
    var items: Array = report["items"]
    var ctx: String = "%s %dx%d" % [state, size.x, size.y]
    _check(screen[2] >= 1280.0 and screen[3] >= 720.0,
            ctx + ": menu canvas should stay at least 1280x720, got "
            + str(screen[2]) + "x" + str(screen[3]))
    _check(clipped.is_empty(), ctx + ": clipped items " + str(clipped))
    _check(bool(report["panel_inside"]), ctx + ": panel is outside the canvas")
    _check(items.size() == expected_items,
            ctx + ": expected %d visible items, got %d" % [expected_items, items.size()])
    var panel: Array = report["panel"]
    var top_margin: float = float(items[0]["rect"][1]) if not items.is_empty() else 0.0
    var bottom_margin: float = (
        float(screen[3]) - (float(items[items.size() - 1]["rect"][1])
        + float(items[items.size() - 1]["rect"][3]))
    ) if not items.is_empty() else 0.0
    _layout_samples.append({
        "requested": [size.x, size.y],
        "state": state,
        "canvas": [screen[2], screen[3]],
        "panel": panel,
        "panel_min": report["panel_min"],
        "visible_items": items.size(),
        "first_item_top_margin": top_margin,
        "last_item_bottom_margin": bottom_margin,
        "clipped": clipped,
    })
    var previous_bottom: float = -1.0
    for item: Dictionary in items:
        var rect: Array = item["rect"]
        _check(bool(item["inside"]),
                ctx + ": item " + str(item["index"]) + " (" + String(item["text"])
                + ") is clipped")
        _check(rect[1] >= previous_bottom - 0.01,
                ctx + ": item " + str(item["index"]) + " overlaps the previous item")
        previous_bottom = float(rect[1]) + float(rect[3])

func _capture_layout_pixels(size: Vector2i) -> void:
    await RenderingServer.frame_post_draw
    var shot: Image = root.get_texture().get_image()
    if shot == null:
        return
    var report_dir: String = OS.get_executable_path().get_base_dir().path_join(
        "reports"
    )
    DirAccess.make_dir_recursive_absolute(report_dir)
    var path: String = report_dir.path_join(
        "layout_%dx%d_%s.png" % [size.x, size.y, _menu.menu_state]
    )
    var error: Error = shot.save_png(path)
    if not _report.has("pixel_shots"):
        _report["pixel_shots"] = []
    if error == OK:
        _report["pixel_shots"].append({
            "path": path,
            "image": [shot.get_width(), shot.get_height()],
        })

func _send_mouse_motion(position: Vector2) -> void:
    var motion: InputEventMouseMotion = InputEventMouseMotion.new()
    motion.position = position
    motion.global_position = position
    motion.relative = Vector2(1.0, 0.0)
    Input.parse_input_event(motion)
    await process_frame
    await process_frame

func _click(position: Vector2) -> void:
    await _send_mouse_motion(position)
    var press: InputEventMouseButton = InputEventMouseButton.new()
    press.button_index = MOUSE_BUTTON_LEFT
    press.pressed = true
    press.position = position
    press.global_position = position
    Input.parse_input_event(press)
    await process_frame
    var release: InputEventMouseButton = InputEventMouseButton.new()
    release.button_index = MOUSE_BUTTON_LEFT
    release.pressed = false
    release.position = position
    release.global_position = position
    Input.parse_input_event(release)
    await process_frame
    await process_frame

func _finish() -> void:
    _report["layouts"] = _layout_samples
    _report["failures"] = _failures
    _report["final_state"] = (
        _menu.menu_state if _menu != null and is_instance_valid(_menu) else ""
    )
    print("OPPONENT_MENU_VALIDATION=" + JSON.stringify(_report))
    if _failures.is_empty():
        print("OPPONENT_MENU_VALIDATION_OK")
        quit(0)
    else:
        print("OPPONENT_MENU_VALIDATION_FAILED=" + str(_failures.size()))
        quit(1)

extends SceneTree
## Headless validation of the recovered Training Settings destination + rows.
##
##   godot --headless --path godot --script res://tests/validate_training_settings.gd \
##       -- <player.glb> <opponent.glb> [failclosed]
##
## Modes:
##   normal      - training pause -> Settings -> recovered in-game settings
##                 (darkbg + settings.ui), two rows AUDIO / LANGUAGES, their
##                 sub-screens and the recovered +/-0.1 [0,1] volume actions.
##   failclosed  - the settings data path is missing; the pause Settings row
##                 must report NOT RECOVERED and stay in pause.

const Controls = preload("res://scripts/prototype_controls.gd")
const RecoveredSettings = preload("res://scripts/recovered_settings.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    failures.append(message)
    push_error("TRAINING_SETTINGS_FAIL: " + message)


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


func _near(a: float, b: float, tolerance: float = 0.0001) -> bool:
    return absf(a - b) <= tolerance


func _rect_of(widget: Dictionary) -> Array:
    return [int(widget.get("x", -1)), int(widget.get("y", -1)),
            int(widget.get("width", -1)), int(widget.get("height", -1))]


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 2:
        push_error("Expected player and opponent GLB paths")
        quit(1)
        return
    var mode := args[2] if args.size() > 2 else "normal"
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    if mode == "failclosed":
        OS.set_environment("BRUCELEE_TRAINING_SETTINGS_PATH",
            "res://data/training_settings_does_not_exist.json")
    else:
        OS.set_environment("BRUCELEE_TRAINING_SETTINGS_PATH", "")

    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var training = scene.get("move_training")
    if not _check(training != null, "training node missing"):
        _finish()
        return

    if mode == "failclosed":
        _run_fail_closed(training)
        _finish()
        return

    _run_normal(training)
    _finish()


func _run_fail_closed(training) -> void:
    training.open()
    _check(training.state == "practice", "practice did not open")
    training._open_pause()
    _check(training.state == "pause", "pause did not open")
    training._pause_index = 4
    training._pause_status.text = ""
    training._pause_accept()
    _check(training.state == "pause",
        "settings stayed open despite missing layout (state=%s)"
        % training.state)
    _check(training._pause_status.text.contains("NOT RECOVERED"),
        "settings did not report NOT RECOVERED: " + training._pause_status.text)
    _check(training._pause_status.text.contains("missing"),
        "settings error does not name the missing file: "
        + training._pause_status.text)


func _run_normal(training) -> void:
    # ---------------------------------------------------------- data artifact
    _check(training.settings_available(),
        "training_settings.json did not load: " + training._settings_error)
    _check(training._settings_error.is_empty(),
        "settings load error: " + training._settings_error)
    var rows: Array = training.settings_rows()
    _check(rows.size() == 2, "expected 2 recovered settings rows, got %d"
        % rows.size())
    if rows.size() == 2:
        _check(String(rows[0]["label_key"]) == "audio"
            and String(rows[0]["destination"]) == "ingamesettingsaudio",
            "row 0 is not audio -> ingamesettingsaudio")
        _check(String(rows[1]["label_key"]) == "languages"
            and String(rows[1]["destination"]) == "ingamesettingslanguage",
            "row 1 is not languages -> ingamesettingslanguage")
    var nr: Array = training.settings_not_recovered_rows()
    var nr_actions: Array = []
    for item: Variant in nr:
        nr_actions.append(String((item as Dictionary).get("action", "")))
    _check(nr_actions.has("video") and nr_actions.has("controls"),
        "video/controls not marked NOT RECOVERED: " + str(nr_actions))

    # --------------------------------------------------- recovered geometry
    _check(_rect_of(training.settings_widget("settings", "menu"))
        == [80, 2, 400, 180], "settings menu rect changed")
    _check(_rect_of(training.settings_widget("settings", "title"))
        == [0, 5, 200, 40], "settings title rect changed")
    _check(_rect_of(training.settings_first("darkbg", "staticrect"))
        == [0, 0, 480, 320], "darkbg rect changed")
    _check(_rect_of(training.settings_widget("audio", "musicvolume"))
        == [120, 190, 240, 30], "music slider rect changed")
    _check(_rect_of(training.settings_widget("audio", "soundvolume"))
        == [120, 250, 240, 30], "sound slider rect changed")
    _check(_rect_of(training.settings_first("language", "bldock"))
        == [0, 180, 480, 70], "language dock rect changed")

    # --------------------------------------------------------- native defaults
    _check(_near(RecoveredSettings.get_value("music_volume"), 0.5),
        "music_volume default is " + str(RecoveredSettings.get_value("music_volume")))
    _check(_near(RecoveredSettings.get_value("sound_volume"), 0.5),
        "sound_volume default is " + str(RecoveredSettings.get_value("sound_volume")))

    # ------------------------------------------------------------- navigation
    training.open()
    training._open_pause()
    _check(training.state == "pause", "pause did not open")
    _check(training._pause_items[4].text == "Settings",
        "pause row 4 is " + training._pause_items[4].text)
    training._pause_index = 4
    training._pause_status.text = ""
    training._pause_accept()
    _check(training.state == "settings",
        "Settings did not open the recovered in-game settings (state=%s)"
        % training.state)
    _check(training._settings_title.text == "Settings",
        "settings title is " + training._settings_title.text)
    _check(training._settings_items.size() == 2, "settings screen is not 2 rows")
    if training._settings_items.size() == 2:
        _check(training._settings_items[0].text == "Audio"
            and training._settings_items[1].text == "Languages",
            "settings rows are " + str([training._settings_items[0].text,
                training._settings_items[1].text]))
    training.handle_input_event(_key(KEY_DOWN))
    _check(training._settings_index == 1, "DOWN did not move to LANGUAGES")
    training.handle_input_event(_key(KEY_UP))
    _check(training._settings_index == 0, "UP did not return to AUDIO")

    # --------------------------------------------------------- audio sub-screen
    training.handle_input_event(_key(KEY_ENTER))
    _check(training.state == "settings_audio",
        "AUDIO did not open the recovered audio screen (state=%s)" % training.state)
    _check(training._audio_items.size() == 2
        and training._audio_items[0].text == "Music"
        and training._audio_items[1].text == "Sound",
        "audio rows are " + str([training._audio_items[0].text,
            training._audio_items[1].text]))
    RecoveredSettings.set_value("music_volume", 0.5)
    RecoveredSettings.apply_audio()
    training._refresh_audio()
    training.handle_input_event(_key(KEY_RIGHT))
    _check(_near(RecoveredSettings.get_value("music_volume"), 0.6),
        "RIGHT did not add 0.1 (got %f)" % RecoveredSettings.get_value("music_volume"))
    training.handle_input_event(_key(KEY_LEFT))
    _check(_near(RecoveredSettings.get_value("music_volume"), 0.5),
        "LEFT did not subtract 0.1")
    for _i: int in range(12):
        training.handle_input_event(_key(KEY_RIGHT))
    _check(_near(RecoveredSettings.get_value("music_volume"), 1.0),
        "music volume did not clamp at 1.0 (got %f)"
        % RecoveredSettings.get_value("music_volume"))
    for _i: int in range(15):
        training.handle_input_event(_key(KEY_LEFT))
    _check(_near(RecoveredSettings.get_value("music_volume"), 0.0),
        "music volume did not clamp at 0.0 (got %f)"
        % RecoveredSettings.get_value("music_volume"))
    training.handle_input_event(_key(KEY_DOWN))
    _check(training._audio_index == 1, "DOWN did not select SOUND")
    training.handle_input_event(_key(KEY_LEFT))
    _check(_near(RecoveredSettings.get_value("sound_volume"), 0.4),
        "sound LEFT did not subtract 0.1 (got %f)"
        % RecoveredSettings.get_value("sound_volume"))
    var music_bus := AudioServer.get_bus_index("Music")
    var sound_bus := AudioServer.get_bus_index("Sound")
    _check(music_bus != -1 and sound_bus != -1,
        "Music/Sound audio buses were not created")
    if sound_bus != -1:
        _check(_near(AudioServer.get_bus_volume_db(sound_bus),
            linear_to_db(0.4), 0.01),
            "Sound bus volume is not linear_to_db(0.4): %f"
            % AudioServer.get_bus_volume_db(sound_bus))
    training.handle_input_event(_key(KEY_ESCAPE))
    _check(training.state == "settings", "audio ESC did not return to settings")

    # ------------------------------------------------------ language sub-screen
    training._settings_index = 1
    training.handle_input_event(_key(KEY_ENTER))
    _check(training.state == "settings_language",
        "LANGUAGES did not open the recovered language screen (state=%s)"
        % training.state)
    _check(training._language_status.text.contains("NOT RECOVERED"),
        "language dock item list is not marked NOT RECOVERED")
    training.handle_input_event(_key(KEY_ENTER))
    _check(training.state == "settings_language",
        "confirming an unrecovered language list left the screen")
    training.handle_input_event(_key(KEY_ESCAPE))
    _check(training.state == "settings", "language ESC did not return to settings")

    # ------------------------------------------------------------- back to pause
    training.handle_input_event(_key(KEY_ESCAPE))
    _check(training.state == "pause", "settings ESC did not return to pause")


func _finish() -> void:
    paused = false
    if failures.is_empty():
        print("TRAINING_SETTINGS_VALIDATION={\"failures\":[]}")
        quit(0)
    else:
        print("TRAINING_SETTINGS_VALIDATION={\"failures\":%s}" % JSON.stringify(failures))
        quit(1)

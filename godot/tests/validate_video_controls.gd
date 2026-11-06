extends SceneTree
## Headless validation of the recovered Settings / Training VIDEO-CONTROLS facts.
##
## It boots the REAL main.tscn and drives the recovered art menu with real key
## events.  The Training checks use the scene's configured PortMoveTraining and
## drive the real trainingpause.ui menu (pause -> Settings), not a synthetic
## standalone instance.  It proves three things:
##   1. the destination screens, decoded widgets, defaults, persistence keys and
##      native consumers are recorded verbatim;
##   2. no user-reachable VIDEO/CONTROLS row exists in this shipped resource:
##      the Settings page keeps exactly its two decoded rows and no key sequence
##      reaches a video/controls screen;
##   3. a missing recovered artifact fails closed without inventing a row.
##
## Scope: the negative reachability result applies to the shipped v1.15.26
## data.zpak only.  No PC camera visual effect, HUD opacity binding, control
## mapping or on-disk write is implemented here.
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_video_controls.gd \
##         --quit-after 12000 -- <player.glb> <opponent.glb> <normal|failclosed>

const MenuArt = preload("res://scripts/menu_art.gd")
const RecoveredPages = preload("res://scripts/recovered_pages.gd")
const MoveTraining = preload("res://scripts/move_training.gd")

const NR := "NOT RECOVERED"
const MISSING := "res://data/menu_art/__missing_video_controls__.json"

var passed: int = 0
var failed: int = 0
var mode: String = "normal"
var scene: Node = null
var menu: Node = null
var training: Node = null


func _initialize() -> void:
    call_deferred("_run")


func _key(keycode: Key) -> InputEventKey:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = keycode
    event.pressed = true
    return event


func _check(cond: bool, desc: String) -> bool:
    if cond:
        passed += 1
        print("PASS " + desc)
    else:
        failed += 1
        printerr("FAIL " + desc)
    return cond


func _finish() -> void:
    print("VIDEO_CONTROLS_VALIDATION=" + JSON.stringify(
        {"mode": mode, "passed": passed, "failed": failed}))
    quit(1 if failed > 0 else 0)


func _any_contains(values: Array, needle: String) -> bool:
    for v: Variant in values:
        if String(v).contains(needle):
            return true
    return false


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 2:
        printerr("Expected <player.glb> <opponent.glb> [normal|failclosed]")
        quit(1)
        return
    mode = args[2] if args.size() > 2 else "normal"

    # Strict user:// isolation: no native settings.dat or progress mirror is
    # written by this validator (the runner also redirects APPDATA/HOME).
    OS.set_environment("BRUCELEE_NATIVE_PROGRESS", "0")
    OS.set_environment("BRUCELEE_NATIVE_SETTINGS", "")
    OS.set_environment("BRUCELEE_LANGUAGE_SAVE_PATH", "")
    OS.set_environment("BRUCELEE_MENU_ART", "1")
    OS.set_environment("BRUCELEE_MAIN_MENU", "1")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    for n: String in ["BRUCELEE_STORY_FLOW", "BRUCELEE_STORY_LAUNCH",
            "BRUCELEE_GAME_MODE", "BRUCELEE_MODE_LAUNCH", "BRUCELEE_ATTRACT",
            "BRUCELEE_CONTINUE", "BRUCELEE_PROGRESS", "BRUCELEE_STYLE_EDITOR",
            "BRUCELEE_SCENE", "BRUCELEE_LANG", "BRUCELEE_TRAINING_SETTINGS_PATH"]:
        OS.set_environment(n, "")
    if mode == "failclosed":
        OS.set_environment("BRUCELEE_RECOVERED_PAGES_PATH", MISSING)
        OS.set_environment("BRUCELEE_TRAINING_SETTINGS_PATH",
            "res://data/__missing_video_controls_training__.json")
    else:
        OS.set_environment("BRUCELEE_RECOVERED_PAGES_PATH", "")

    scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: Object = scene.get("player")
    var computer: Object = scene.get("computer")
    if player != null:
        player.set_physics_process(false)
    if computer != null:
        computer.set_physics_process(false)
    menu = scene.get("prototype_menu")
    if not _check(menu != null and menu is MenuArt,
            "BRUCELEE_MENU_ART=1 selects PortMenuArt"):
        _finish()
        return

    if mode == "failclosed":
        _check_failclosed_artifact()
        await _check_settings_flow()
        await _check_training_failclosed()
        _finish()
        return

    _check_recovered_pages()
    await _check_settings_flow()
    await _check_training()
    _finish()


func _check_recovered_pages() -> void:
    _check(bool(menu.call("recovered_pages_available")),
        "recovered-pages artifact loads")
    _check(RecoveredPages.error() == "", "artifact has no error")
    var svc: Dictionary = RecoveredPages.settings_video_controls()
    _check(String(svc.get("reachability", "")) == NR,
        "Settings VIDEO/CONTROLS user reachability stays NOT RECOVERED")
    _check(String(svc.get("reachability_scope", "")).contains("v1.15.26")
        and String(svc.get("reachability_scope", "")).contains("Not a claim about other builds"),
        "negative reachability is scoped to the shipped resource only")
    _check(String(Dictionary(svc.get("video", {})).get("state", "")) == "settingsvideo",
        "settings video destination = settingsvideo")
    _check(String(Dictionary(svc.get("controls", {})).get("state", "")) == "settingscontrols",
        "settings controls destination = settingscontrols")

    var vv: Dictionary = Dictionary(Dictionary(svc.get("video", {})).get("values", {}))
    var opacity: Dictionary = Dictionary(vv.get("opacity", {}))
    _check(String(opacity.get("key", "")) == "input_gui_alpha"
        and is_equal_approx(float(opacity.get("default", -1.0)), 0.25)
        and is_equal_approx(float(opacity.get("step", -1.0)), 0.1),
        "opacity recovers key input_gui_alpha, default 0.25, step 0.1")
    _check(String(opacity.get("clamp", "")).contains("0.0")
        and String(opacity.get("clamp", "")).contains("1.0"),
        "opacity recovers the native [0,1] clamp")
    var tilt: Dictionary = Dictionary(vv.get("camera_tilt", {}))
    _check(String(tilt.get("key", "")) == "camera_tilt"
        and is_equal_approx(float(tilt.get("default", -1.0)), 1.0),
        "camera_tilt recovers key camera_tilt, default 1.0")
    var tilt_options: Array = Array(tilt.get("decoded_labels", []))
    var tilt_keys: Array = []
    for o: Variant in tilt_options:
        tilt_keys.append(String(Dictionary(o).get("label_key", "")))
    _check(tilt_keys == ["ct_low", "ct_medium", "ct_high"],
        "camera tilt labelmenu has the three decoded labels")
    _check(String(tilt.get("mapping", "")).contains("NOT PROVEN"),
        "camera_tilt index mapping is explicitly NOT PROVEN / NOT READY")

    var cv: Dictionary = Dictionary(Dictionary(svc.get("controls", {})).get("values", {}))
    var layout: Dictionary = Dictionary(cv.get("input_layout", {}))
    _check(String(layout.get("key", "")) == "input_layout"
        and is_equal_approx(float(layout.get("default", -1.0)), 0.0),
        "input_layout recovers key input_layout, default 0.0")
    var pads: Array = Array(layout.get("decoded_items", []))
    var pad_names: Array = []
    for p: Variant in pads:
        pad_names.append(String(Dictionary(p).get("item_basename", "")))
    _check(pad_names == ["bl_fixed_pad", "bl_floating_pad"],
        "controls dock decoded items are the fixed/floating pads")
    _check(String(layout.get("mapping", "")).contains("NOT PROVEN"),
        "input_layout item-order mapping is explicitly NOT PROVEN / NOT READY")

    var defaults: Dictionary = Dictionary(svc.get("defaults", {}))
    _check(is_equal_approx(float(defaults.get("input_gui_alpha", -1.0)), 0.25)
        and is_equal_approx(float(defaults.get("camera_tilt", -1.0)), 1.0)
        and is_equal_approx(float(defaults.get("input_layout", -1.0)), 0.0),
        "native SetDefaultTReal defaults are recorded verbatim")
    var persistence: Dictionary = Dictionary(svc.get("persistence", {}))
    _check(String(persistence.get("provider", "")) == "option"
        and Array(persistence.get("keys", [])).has("input_gui_alpha")
        and Array(persistence.get("keys", [])).has("camera_tilt")
        and Array(persistence.get("keys", [])).has("input_layout"),
        "settings.dat 'option' provider keys are the three decoded data sources")
    _check(String(persistence.get("write_policy", "")).contains("never replace"),
        "persistence policy forbids overwriting other providers")

    var effects: Dictionary = Dictionary(svc.get("effects", {}))
    _check(String(Dictionary(effects.get("camera_tilt", {})).get(
            "status", "")).contains("PC camera visual effect NOT RECOVERED"),
        "camera_tilt*0.1 is recorded as a native write target, not a proven PC camera effect")
    _check(String(Dictionary(effects.get("input_gui_alpha", {})).get(
            "status", "")).contains("PC HUD opacity binding NOT RECOVERED"),
        "input_gui_alpha consumer is recorded, PC HUD binding is NOT RECOVERED")
    _check(String(Dictionary(effects.get("input_layout", {})).get(
            "status", "")).contains("PC control-scheme binding NOT RECOVERED"),
        "input_layout consumer is recorded, PC control scheme is NOT RECOVERED")


func _open_settings() -> void:
    scene.call("_open_main_menu")
    await process_frame
    for _i: int in range(2):
        menu.call("handle_key_event", _key(KEY_DOWN))
        await process_frame
    menu.call("handle_key_event", _key(KEY_ENTER))
    await process_frame


func _check_settings_flow() -> void:
    await _open_settings()
    _check(String(menu.get("screen_id")) == "settings",
        "main menu row 2 opens the recovered Settings page")
    var labels: Array = menu.call("option_labels")
    _check(labels == ["Audio", "Languages"],
        "settings.ui keeps exactly its two decoded rows: " + str(labels))
    _check(not _any_contains(labels, "Video")
        and not _any_contains(labels, "Controls"),
        "no invented VIDEO/CONTROLS row is rendered")
    for _i: int in range(12):
        menu.call("handle_key_event", _key(KEY_DOWN))
        await process_frame
    labels = menu.call("option_labels")
    _check(labels == ["Audio", "Languages"],
        "DOWN cycling never produces a VIDEO/CONTROLS row")
    for _i: int in range(4):
        menu.call("handle_key_event", _key(KEY_UP))
        await process_frame
    labels = menu.call("option_labels")
    _check(labels == ["Audio", "Languages"],
        "UP cycling never produces a VIDEO/CONTROLS row")
    for i: int in range(2):
        await _open_settings()
        for _j: int in range(i):
            menu.call("handle_key_event", _key(KEY_DOWN))
            await process_frame
        menu.call("handle_key_event", _key(KEY_ENTER))
        await process_frame
        var sid: String = String(menu.get("screen_id"))
        _check(sid != "settings_video" and sid != "settings_controls"
            and not sid.contains("video") and not sid.contains("controls"),
            "ENTER on row " + str(i) + " never opens a video/controls screen")
        _check(not _any_contains(menu.call("option_labels"), "Video")
            and not _any_contains(menu.call("option_labels"), "Controls"),
            "ENTER on row " + str(i) + " invents no VIDEO/CONTROLS row")
    menu.call("handle_key_event", _key(KEY_ESCAPE))
    await process_frame


func _check_training() -> void:
    # REAL main.tscn flow: the scene owns the configured PortMoveTraining; drive
    # its recovered trainingpause.ui menu into the Settings screen.
    training = scene.get("move_training")
    _check(training != null and training is MoveTraining,
        "main.tscn owns a configured PortMoveTraining")
    _check(bool(training.call("settings_available")),
        "training_settings.json loads in the real main.tscn training flow")
    var rows: Array = training.call("settings_rows")
    _check(rows.size() == 2, "training Settings has exactly two decoded rows")
    var actions: Array = []
    for r: Variant in rows:
        actions.append(String(Dictionary(r).get("action", "")))
    _check(actions == ["audio", "lang"], "training rows are audio/lang only")
    _check(not actions.has("video") and not actions.has("controls"),
        "training Settings emits no video/controls action")

    # Drive pause -> Settings with the real trainingpause.ui option order.
    training.call("_open_pause")
    var pause: Array = training.call("pause_options")
    var settings_index: int = -1
    for i: int in range(pause.size()):
        if String(Dictionary(pause[i]).get("action", "")) == "settings":
            settings_index = i
    _check(settings_index >= 0, "trainingpause.ui has a Settings option")
    training.set("_pause_index", settings_index)
    training.call("_pause_accept")
    _check(String(training.get("state")) == "settings",
        "real training pause Settings opens the recovered in-game settings state")
    paused = false

    var missing: Array = training.call("settings_not_recovered_rows")
    _check(missing.size() == 2,
        "training records the two VIDEO/CONTROLS rows as NOT RECOVERED")
    var dest: Dictionary = training.call("training_video_controls_destinations")
    _check(String(Dictionary(dest.get("video", {})).get(
            "destination", "")) == "ingamesettingsvideo"
        and String(Dictionary(dest.get("controls", {})).get(
            "destination", "")) == "ingamesettingscontrols",
        "training destinations are the recovered ingame states")
    for r: Variant in missing:
        _check(String(Dictionary(r).get("status", "")) == NR,
            "training " + String(Dictionary(r).get("action", "")) + " stays NOT RECOVERED")

    var visibility: Dictionary = training.call("settings_widget", "video", "visibility")
    _check(Array(Dictionary(visibility.get("datasources", {})).get(
            "value", [])) == ["option", "input_gui_alpha"],
        "decoded video slider value source = option/input_gui_alpha")
    var preview: Dictionary = training.call("settings_widget", "video", "samplebutton")
    _check(Array(Dictionary(preview.get("datasources", {})).get(
            "alpha", [])) == ["option", "input_gui_alpha"],
        "decoded live preview alpha source = option/input_gui_alpha")
    var labelmenu: Dictionary = training.call("settings_widget", "video", "cameratilt")
    var opts: Array = Array(labelmenu.get("options", []))
    var keys: Array = []
    for o: Variant in opts:
        var pair: Array = o as Array
        keys.append(String(pair[0]) if pair.size() > 0 else "")
    _check(keys == ["ct_low", "ct_medium", "ct_high"],
        "decoded camera tilt labelmenu has exactly the three recovered labels")
    _check(Array(Dictionary(labelmenu.get("datasources", {})).get(
            "selectedoption", [])) == ["option", "camera_tilt"],
        "decoded camera tilt selectedoption = option/camera_tilt")
    var dec: Dictionary = training.call("settings_widget", "video", "visibdec")
    var inc: Dictionary = training.call("settings_widget", "video", "visibinc")
    _check(String(dec.get("action", "")) == "visibilitydec"
        and String(inc.get("action", "")) == "visibilityinc",
        "decoded opacity +/- buttons keep their recovered actions")
    var dock: Dictionary = training.call("settings_widget", "controls", "controls_dock")
    _check(Array(Dictionary(dock.get("datasources", {})).get(
            "validselectedoption", [])) == ["option", "input_layout"],
        "decoded controls dock validselectedoption = option/input_layout")
    var items: Array = Array(dock.get("items", []))
    _check(items.size() == 2, "decoded controls dock has exactly two pad pictures")


func _check_failclosed_artifact() -> void:
    _check(not RecoveredPages.available(),
        "missing recovered-pages artifact fails closed")
    _check(RecoveredPages.error().contains("missing artifact"),
        "fail-closed cause is reported")
    _check(RecoveredPages.settings_video_controls().is_empty(),
        "no recovered VIDEO/CONTROLS record is invented when the artifact is missing")


func _check_training_failclosed() -> void:
    # REAL main.tscn flow with a missing training_settings.json: the pause
    # Settings row must stay in pause and report NOT RECOVERED.
    training = scene.get("move_training")
    _check(training != null and training is MoveTraining,
        "main.tscn owns a configured PortMoveTraining (fail-closed)")
    _check(not bool(training.call("settings_available")),
        "missing training_settings.json fails closed in the real training flow")
    training.call("_open_pause")
    var pause: Array = training.call("pause_options")
    var settings_index: int = -1
    for i: int in range(pause.size()):
        if String(Dictionary(pause[i]).get("action", "")) == "settings":
            settings_index = i
    if settings_index >= 0:
        training.set("_pause_index", settings_index)
        training.call("_pause_accept")
    _check(String(training.get("state")) == "pause",
        "fail-closed Settings stays in the training pause")
    var pause_status: Variant = training.get("_pause_status")
    if pause_status is Label:
        _check((pause_status as Label).text.contains(NR),
            "fail-closed pause reports NOT RECOVERED")
    paused = false
    _check(Array(training.call("settings_rows")).is_empty(),
        "no training Settings rows are invented when the artifact is missing")

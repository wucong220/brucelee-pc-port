extends SceneTree
## Validates that all nine recovered menu SFX files load from the package and that
## the port maps the requested interaction roles to the exact original files.
## "denied" has NO original cue (MenuSfxMap.DENIED == ""), so this test asserts it
## stays silent rather than substituting an invented sound.
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_menu_sfx_full.gd
## Env (set by caller): BRUCELEE_MENU_SFX_ROOT=<package>/audio/menu_sfx

const PrototypeControls = preload("res://scripts/prototype_controls.gd")
const Menu = preload("res://scripts/prototype_menu.gd")
const MenuSfxMap = preload("res://scripts/menu_sfx_map.gd")

func _initialize() -> void:
    call_deferred("_run")

func _press(menu, keycode: Key) -> void:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = keycode
    event.physical_keycode = keycode
    event.pressed = true
    menu.handle_input_event(event)

func _expect(cond: bool, msg: String, failures: Array) -> void:
    if not cond:
        failures.append(msg)

func _run() -> void:
    var failures: Array = []
    PrototypeControls.ensure_default_actions()
    var menu = Menu.new()
    root.add_child(menu)
    await process_frame
    await process_frame

    # 1. Role players resolve to the exact original files.
    var role_expected: Dictionary = {
        "nav": "Menu_Punch_2.wav",
        "accept": "Select_Play_Bl_Shout.wav",
        "back": "Back_BL_Shout_Short.wav",
        "page_flip": "Story_Page_Flip_Short_Version.wav",
    }
    var players: Dictionary = {
        "nav": menu.nav_sfx, "accept": menu.accept_sfx,
        "back": menu.back_sfx, "page_flip": menu.page_flip_sfx,
    }
    for role: String in role_expected:
        var p: AudioStreamPlayer = players[role]
        _expect(p != null, "menu %s player not loaded" % role, failures)
        if p != null:
            _expect(p.stream != null, "menu %s stream null" % role, failures)
            _expect(p.stream is AudioStreamWAV, "menu %s not AudioStreamWAV" % role, failures)
        _expect(MenuSfxMap.file_for_role(role) == role_expected[role],
                "role %s file mismatch: %s" % [role, MenuSfxMap.file_for_role(role)], failures)

    # 2. denied is explicitly unsourced and must not be wired to anything.
    _expect(MenuSfxMap.DENIED == "", "DENIED must be empty (no original cue)", failures)
    _expect(not MenuSfxMap.has_denied_cue(), "has_denied_cue must be false", failures)
    _expect(menu.denied_sfx == null, "denied_sfx must be null (no invented cue)", failures)

    # 3. All nine recovered files load from the package, byte-for-byte by name.
    var loaded: Array[String] = []
    for filename: String in MenuSfxMap.ALL_FILES:
        var stream: AudioStreamWAV = menu.load_menu_sfx_stream(filename)
        _expect(stream != null, "menu sfx failed to load: " + filename, failures)
        if stream != null:
            loaded.append(filename)
    _expect(loaded.size() == 9, "expected 9 menu sfx streams, got %d" % loaded.size(), failures)

    # 4. Trigger paths.
    menu.show_main_menu()
    _press(menu, KEY_DOWN)
    _expect(menu.last_sfx_played == "nav", "nav sfx did not trigger", failures)
    _press(menu, KEY_ENTER)
    _expect(menu.last_sfx_played == "accept", "accept sfx did not trigger", failures)
    menu.show_pause_menu()
    _press(menu, KEY_ESCAPE)
    _expect(menu.last_sfx_played == "back", "back sfx did not trigger", failures)

    var out: Dictionary = {
        "roles": role_expected,
        "denied": MenuSfxMap.DENIED,
        "denied_wired": menu.denied_sfx != null,
        "menu_sfx_loaded": loaded.size(),
        "loaded_files": loaded,
        "errors": menu.menu_sfx_errors,
        "failures": failures,
    }
    print("MENU_SFX_FULL_VALIDATION=" + JSON.stringify(out))
    menu.queue_free()
    await process_frame
    if failures.is_empty():
        quit(0)
    else:
        push_error("MENU_SFX_FULL_VALIDATION FAILED: " + str(failures))
        quit(1)

extends SceneTree

const PrototypeControls = preload("res://scripts/prototype_controls.gd")

func _initialize() -> void:
    call_deferred("_run")


func _press(menu: PortPrototypeMenu, keycode: Key) -> void:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = keycode
    event.physical_keycode = keycode
    event.pressed = true
    menu.handle_input_event(event)


func _run() -> void:
    PrototypeControls.ensure_default_actions()
    var menu: PortPrototypeMenu = PortPrototypeMenu.new()
    root.add_child(menu)
    await process_frame
    for entry: Array in [
        ["nav", menu.nav_sfx],
        ["accept", menu.accept_sfx],
        ["back", menu.back_sfx],
    ]:
        var player: AudioStreamPlayer = entry[1]
        if player == null or player.stream == null:
            push_error("menu %s sfx was not loaded: %s" % [
                String(entry[0]), str(menu.menu_sfx_errors)
            ])
            quit(1)
            return
    if menu.accept_sfx_error != "":
        push_error("menu sfx error: " + menu.accept_sfx_error)
        quit(1)
        return
    menu.show_main_menu()
    _press(menu, KEY_DOWN)
    if menu.last_sfx_played != "nav":
        push_error("menu navigation sfx did not trigger")
        quit(1)
        return
    _press(menu, KEY_ENTER)
    if menu.last_sfx_played != "accept":
        push_error("menu accept sfx did not trigger")
        quit(1)
        return
    menu.show_pause_menu()
    _press(menu, KEY_ESCAPE)
    if menu.last_sfx_played != "back":
        push_error("menu back sfx did not trigger")
        quit(1)
        return
    print("MENU_SFX_VALIDATION=" + JSON.stringify({
        "nav": menu.nav_sfx.stream.get_class(),
        "accept": menu.accept_sfx.stream.get_class(),
        "back": menu.back_sfx.stream.get_class(),
        "errors": menu.menu_sfx_errors,
        "nav_played": menu.nav_sfx.playing,
        "accept_played": menu.accept_sfx.playing,
        "back_played": menu.back_sfx.playing,
    }))
    menu.queue_free()
    await process_frame
    quit(0)

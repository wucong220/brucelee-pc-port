extends SceneTree

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
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
    print("MENU_SFX_VALIDATION=" + JSON.stringify({
        "nav": menu.nav_sfx.stream.get_class(),
        "accept": menu.accept_sfx.stream.get_class(),
        "back": menu.back_sfx.stream.get_class(),
        "errors": menu.menu_sfx_errors,
    }))
    menu.queue_free()
    await process_frame
    quit(0)

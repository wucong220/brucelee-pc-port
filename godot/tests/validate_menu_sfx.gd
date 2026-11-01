extends SceneTree

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var menu: PortPrototypeMenu = PortPrototypeMenu.new()
    root.add_child(menu)
    await process_frame
    if menu.accept_sfx == null or menu.accept_sfx.stream == null:
        push_error("menu accept sfx was not loaded: " + menu.accept_sfx_error)
        quit(1)
        return
    if menu.accept_sfx_error != "":
        push_error("menu sfx error: " + menu.accept_sfx_error)
        quit(1)
        return
    print("MENU_SFX_VALIDATION=" + JSON.stringify({
        "stream": menu.accept_sfx.stream.get_class(),
        "error": menu.accept_sfx_error,
    }))
    menu.queue_free()
    await process_frame
    quit(0)

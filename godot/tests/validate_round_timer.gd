extends SceneTree

const HUD = preload("res://scripts/hud.gd")


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and Brick candidate GLB paths")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_TIME", "60")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)
    var hud: PortHUD = scene.get("hud")
    scene._reset_match()
    await process_frame

    if hud.timer_label == null:
        push_error("HUD has no round timer label")
        quit(1)
        return
    if hud.timer_label.text != "60":
        push_error("Round timer did not start at the round limit: " + hud.timer_label.text)
        quit(1)
        return
    var viewport_size: Vector2 = root.get_visible_rect().size
    var rect: Rect2 = hud.timer_label.get_global_rect()
    if (rect.size.x <= 0.0 or rect.size.y <= 0.0 or rect.position.x < 0.0
            or rect.position.y < 0.0 or rect.end.x > viewport_size.x
            or rect.end.y > viewport_size.y):
        push_error("Round timer label is not inside the viewport: " + str(rect))
        quit(1)
        return

    scene._physics_process(1.05)
    if hud.timer_label.text != "59" or scene.round_time_left != 59:
        push_error("Round timer did not count down: " + hud.timer_label.text)
        quit(1)
        return

    scene._open_pause_menu()
    scene._physics_process(5.0)
    scene._leave_menu()
    if scene.round_time_left != 59:
        push_error("Paused round consumed round time: " + str(scene.round_time_left))
        quit(1)
        return

    scene.elapsed = 59.0
    scene.round_time_left = 1
    hud.set_time(1)
    scene._physics_process(1.1)
    if not scene.done:
        push_error("Time up did not end the round")
        quit(1)
        return
    if hud.timer_label.text != "00":
        push_error("Timer did not clamp to 00: " + hud.timer_label.text)
        quit(1)
        return
    var overlay: Sprite2D = scene.get("_game_text_rect")
    if overlay == null or not overlay.visible:
        push_error("TIME_IS_UP overlay is not visible")
        quit(1)
        return
    if not scene._game_text_textures.has("TIME_IS_UP"):
        push_error("TIME_IS_UP texture was not loaded")
        quit(1)
        return
    if overlay.texture != scene._game_text_textures["TIME_IS_UP"]:
        push_error("Overlay is not showing the TIME_IS_UP image")
        quit(1)
        return

    scene._physics_process(2.1)
    if scene.round_number != 2 or scene.done or hud.timer_label.text != "60":
        push_error("Next round did not restart the clock: " + hud.timer_label.text)
        quit(1)
        return

    hud.set_time(0, false)
    if hud.timer_label.text != "--":
        push_error("Disabled clock did not show the no-time-limit text")
        quit(1)
        return

    print("ROUND_TIMER_VALIDATION=" + JSON.stringify({
        "round_limit": scene.round_time_max,
        "rounds_to_win": scene.ROUNDS_TO_WIN,
        "timer_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
        "viewport": [viewport_size.x, viewport_size.y],
        "round": scene.round_number,
        "game_text_keys": scene._game_text_textures.keys(),
    }))
    scene.queue_free()
    await process_frame
    quit(0)

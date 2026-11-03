extends SceneTree
## Round-clock + time-up regression for the ported CBeatEmUpGame state machine.

const STATE_TIME_UP: int = 5
const STATE_ROUND_END: int = 15
const STATE_FIGHT: int = 4


func _initialize() -> void:
    call_deferred("_run")


func _state(scene: Node) -> int:
    var value: Variant = scene.get("match_state")
    return value if typeof(value) == TYPE_INT else -1


func _tick(scene: Node, seconds: float, step: float = 0.05) -> void:
    var remaining: float = seconds
    while remaining > 0.0:
        var dt: float = minf(remaining, step)
        scene._physics_process(dt)
        remaining -= dt


func _tick_until(scene: Node, target: int, max_seconds: float = 12.0) -> bool:
    var elapsed: float = 0.0
    while elapsed < max_seconds:
        if _state(scene) == target:
            return true
        scene._physics_process(0.02)
        elapsed += 0.02
    return _state(scene) == target


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and Brick candidate GLB paths")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
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
    var failures: Array[String] = []

    if hud.timer_label == null:
        push_error("HUD has no round timer label")
        quit(1)
        return
    if hud.timer_label.text != "60":
        failures.append("Round timer did not start at the round limit: " + hud.timer_label.text)
    var viewport_size: Vector2 = root.get_visible_rect().size
    var rect: Rect2 = hud.timer_label.get_global_rect()
    if (rect.size.x <= 0.0 or rect.size.y <= 0.0 or rect.position.x < 0.0
            or rect.position.y < 0.0 or rect.end.x > viewport_size.x
            or rect.end.y > viewport_size.y):
        failures.append("Round timer label is not inside the viewport: " + str(rect))

    _tick(scene, 1.05)
    if hud.timer_label.text != "59" or scene.round_time_left != 59:
        failures.append("Round timer did not count down: " + hud.timer_label.text)

    scene._open_pause_menu()
    _tick(scene, 5.0)
    scene._leave_menu()
    if scene.round_time_left != 59:
        failures.append("Paused round consumed round time: " + str(scene.round_time_left))

    scene.elapsed = 59.0
    scene.round_time_left = 1
    hud.set_time(1)
    _tick(scene, 1.1)
    if not scene.done or _state(scene) != STATE_TIME_UP:
        failures.append("Time up did not enter state 5")
    if hud.timer_label.text != "00":
        failures.append("Timer did not clamp to 00: " + hud.timer_label.text)
    var overlay: Sprite2D = scene.get("_game_text_rect")
    if overlay == null or not overlay.visible:
        failures.append("TIME_IS_UP overlay is not visible")
    if not scene._game_text_textures.has("TIME_IS_UP"):
        failures.append("TIME_IS_UP texture was not loaded")
    elif overlay.texture != scene._game_text_textures["TIME_IS_UP"]:
        failures.append("Overlay is not showing the TIME_IS_UP image")

    # State 5 waits 3000 ms, then the draw/win path (7/8/11) waits another
    # 3000 ms before state 15 starts the next round.
    if not _tick_until(scene, STATE_ROUND_END):
        failures.append("Time up did not reach state 15")
    _tick(scene, 0.1)
    if not _tick_until(scene, STATE_FIGHT):
        failures.append("Next-round intro did not reach the fight state")
    if scene.round_number != 2 or scene.done or hud.timer_label.text != "60":
        failures.append("Next round did not restart the clock: " + hud.timer_label.text)

    hud.set_time(0, false)
    if hud.timer_label.text != "--":
        failures.append("Disabled clock did not show the no-time-limit text")

    print("ROUND_TIMER_VALIDATION=" + JSON.stringify({
        "failures": failures,
        "round_limit": scene.round_time_max,
        "rounds_to_win": scene.ROUNDS_TO_WIN,
        "timer_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
        "viewport": [viewport_size.x, viewport_size.y],
        "round": scene.round_number,
        "game_text_keys": scene._game_text_textures.keys(),
    }))
    scene.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)

extends SceneTree
const PC = preload("res://scripts/prototype_controls.gd")
## Real-input variant: drive the exact main.gd -> fighter input path with
## InputEventKey presses and Input action state, not direct fighter method calls.

func _initialize() -> void:
    call_deferred("_run")


func _key(code: Key) -> InputEventKey:
    var event := InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    event.pressed = true
    return event


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and Brick candidate GLB paths")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    var match_scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(match_scene)
    current_scene = match_scene
    await process_frame
    await process_frame
    match_scene.set_process(false)
    match_scene.set_physics_process(false)
    var player: PortFighter = match_scene.get("player")
    var victim: PortFighter = match_scene.get("computer")
    player.set_physics_process(false)
    victim.set_physics_process(false)
    player.rage = 100.0

    # Hold W (native stepright) and press J: main.gd maps stepright+J to grab1.
    Input.action_press(PC.MOVE_UP)
    player.set_held_directions({"up": true})
    match_scene._update_player_key_status()
    match_scene._unhandled_input(_key(KEY_W))
    match_scene._update_player_key_status()
    player.position = Vector3(0.0, 1.2, 0.0)
    victim.position = Vector3(0.35, 1.2, 0.0)
    player.facing = 1.0
    match_scene._unhandled_input(_key(KEY_J))
    if player.attack_kind != "grab1":
        push_error("Real input did not start grab1: " + player.attack_kind)
        quit(1)
        return
    var held: bool = false
    for _step: int in range(200):
        player.position = Vector3(0.0, 1.2, 0.0)
        victim.position = Vector3(0.35, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
        victim._physics_process(1.0 / 60.0)
        if victim.state in ["grabbed1", "grabbed2"]:
            held = true
            break
    if not held:
        push_error("Real input grab did not hold the victim")
        quit(1)
        return

    # Release W and hold D (native right): keystatus right pressed required.
    Input.action_release(PC.MOVE_UP)
    Input.action_press(PC.MOVE_RIGHT)
    player.set_held_directions({"right": true})
    match_scene._update_player_key_status()
    match_scene._unhandled_input(_key(KEY_D))
    match_scene._update_player_key_status()

    # Press J again with D held: the documented keyboard endattack1 input.
    player.set_held_directions({"right": true})
    match_scene._update_player_key_status()
    match_scene._unhandled_input(_key(KEY_J))
    if player.attack_kind != "endattack1":
        push_error("Real input endattack1 did not start: " + player.attack_kind)
        quit(1)
        return
    var saw: bool = false
    for _step: int in range(120):
        player.position = Vector3(0.0, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
        if victim.state == "endattackcomp1":
            saw = true
            break
    if not saw:
        push_error("Real input endattack1 did not consume the victim: " + victim.state)
        quit(1)
        return
    print("PASS real input grab1 + J -> endattack1 -> " + victim.state)
    Input.action_release(PC.MOVE_RIGHT)
    quit(0)

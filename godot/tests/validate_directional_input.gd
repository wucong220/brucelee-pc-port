extends SceneTree
## Drive directional sequences through main.gd using real Input actions.

const KEY_FOR: Dictionary = {"a": KEY_J, "b": KEY_K, "c": KEY_L, "d": KEY_U}
const MOVE_ACTIONS: Array[String] = [
    "prototype_move_left", "prototype_move_right",
    "prototype_move_up", "prototype_move_down",
]

const CASES: Array[Dictionary] = [
    {"initial": "punch", "axis": [[0.0, -1.0], [1.0, 0.0], [1.0, 0.0]],
     "keys": ["a", "a", "a"], "target": "high_punch3"},
    {"initial": "punch", "axis": [[0.0, 1.0], [-1.0, 0.0], [-1.0, 0.0]],
     "keys": ["a", "b", "a"], "target": "low_punch3"},
    {"initial": "kick", "axis": [[0.0, 1.0], [-1.0, 0.0], [-1.0, 0.0]],
     "keys": ["b", "d", "d"], "target": "low_kick3"},
    {"initial": "kick", "axis": [[0.0, -1.0], [1.0, 0.0], [1.0, 0.0]],
     "keys": ["b", "c", "c"], "target": "high_kick3"},
]


func _initialize() -> void:
    call_deferred("_run")


func _key(keycode: Key) -> InputEventKey:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = keycode
    event.pressed = true
    return event


func _release_movement() -> void:
    for action: String in MOVE_ACTIONS:
        if Input.is_action_pressed(action):
            Input.action_release(action)


func _press_axis(axis: Array) -> void:
    _release_movement()
    var x: float = float(axis[0])
    var y: float = float(axis[1])
    if y < -0.5:
        Input.action_press("prototype_move_up")
    elif y > 0.5:
        Input.action_press("prototype_move_down")
    if x > 0.5:
        Input.action_press("prototype_move_right")
    elif x < -0.5:
        Input.action_press("prototype_move_left")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the 30-clip Bruce candidate GLB")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", "")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    player.set_physics_process(false)
    if not player.candidate_loaded:
        push_error("Directional candidate failed to load: " + player.candidate_load_error)
        quit(1)
        return
    for entry: Dictionary in CASES:
        if not _validate_case(scene, player, entry):
            quit(1)
            return
    if not _validate_direction_isolation(scene, player):
        quit(1)
        return
    print("DIRECTIONAL_INPUT_VALIDATION=" + JSON.stringify({
        "cases": "four directional sequences routed through main.gd with live Input actions",
        "isolation": "directional press does not complete plain AAA; released direction is not reused",
        "scope": "PC prototype modifiers; native keys unverified",
    }))
    _release_movement()
    await create_timer(0.1).timeout
    await process_frame
    scene.queue_free()
    await process_frame
    quit(0)


func _validate_case(scene: Node, player: PortFighter, entry: Dictionary) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.facing = 1.0
    player._time = 0.0
    var axes: Array = entry["axis"]
    var keys: Array = entry["keys"]
    for index: int in range(keys.size()):
        _press_axis(axes[index])
        scene._unhandled_input(_key(KEY_FOR[String(keys[index])]))
    _release_movement()
    var target: String = String(entry["target"])
    if String(player.get("_standing_combo_pending_attack")) != target:
        push_error("main.gd did not queue " + target + " from the directional keys")
        return false
    var initial: String = String(entry["initial"])
    var window: Array = PortFighter.CANDOBASICATTACK_WINDOWS[initial]
    player._advance_timed_states(float(window[0]) / PortFighter.SOURCE_FRAME_RATE)
    if not player._try_begin_pending_standing_combo() or player.attack_kind != target:
        push_error("main.gd " + target + " did not transition at the source window")
        return false
    return true


func _validate_direction_isolation(scene: Node, player: PortFighter) -> bool:
    # A directional press must not complete AAA.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.facing = 1.0
    player._time = 0.0
    _press_axis([0.0, -1.0])
    scene._unhandled_input(_key(KEY_J))
    _release_movement()
    scene._unhandled_input(_key(KEY_J))
    scene._unhandled_input(_key(KEY_J))
    if not String(player.get("_standing_combo_pending_attack")).is_empty():
        push_error("A directional press still completed the plain AAA sequence")
        return false
    # Releasing a direction before the next physics frame must not reuse it.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    _press_axis([0.0, -1.0])
    _release_movement()
    scene._unhandled_input(_key(KEY_J))
    var history: Array = player.get("_standing_combo_input_history")
    if history.is_empty():
        push_error("The released-direction press did not record any input history")
        return false
    if not history.is_empty():
        var tokens: Array = history[0].get("tokens", [])
        if tokens.has("up"):
            push_error("A released direction was reused for the next attack press")
            return false
    return true

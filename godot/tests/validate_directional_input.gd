extends SceneTree
## Drive the directional sequences through main.gd input handling, not the fighter API.

const KEY_FOR: Dictionary = {"a": KEY_J, "b": KEY_K, "c": KEY_L, "d": KEY_U}

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
        "cases": "four directional sequences routed through main.gd",
        "isolation": "a directional press does not complete the plain AAA sequence",
        "scope": "PC prototype modifiers sampled from the move axis; native keys unverified",
    }))
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
        var axis: Array = axes[index]
        player.move_axis = Vector2(float(axis[0]), float(axis[1]))
        scene._unhandled_input(_key(KEY_FOR[String(keys[index])]))
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
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.facing = 1.0
    player._time = 0.0
    player.move_axis = Vector2(0.0, -1.0)
    scene._unhandled_input(_key(KEY_J))
    player.move_axis = Vector2.ZERO
    scene._unhandled_input(_key(KEY_J))
    scene._unhandled_input(_key(KEY_J))
    if not String(player.get("_standing_combo_pending_attack")).is_empty():
        push_error("A directional press still completed the plain AAA sequence")
        return false
    return true

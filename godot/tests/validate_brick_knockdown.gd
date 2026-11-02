extends SceneTree
## Verify a lethal light Brick hit reaches the recovered stunfall knockdown.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce victim and Brick combat candidate GLB paths")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var brick: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    brick.set_physics_process(false)
    if not player.candidate_loaded or not brick.candidate_loaded:
        push_error("Candidate load failed")
        quit(1)
        return
    player.health = 1.0
    player.position = Vector3(0.0, 1.2, 0.0)
    brick.position = Vector3(0.3, 1.2, 0.0)
    if not brick.request_attack("low_kick"):
        push_error("Knockdown kick request failed")
        quit(1)
        return
    var order: Array[String] = []
    for step: int in range(420):
        player.position = Vector3(0.0, 1.2, 0.0)
        brick.position = Vector3(0.3, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
        brick._physics_process(1.0 / 60.0)
        if order.is_empty() or order[-1] != player.state:
            order.append(player.state)
        if player.state == "faceupko":
            break
    var expected_order: Array[String] = ["impactstun", "stun", "stun2", "stunfall", "faceupko"]
    var cursor: int = 0
    for expected_state: String in expected_order:
        var found_at: int = -1
        for index: int in range(cursor, order.size()):
            if order[index] == expected_state:
                found_at = index
                break
        if found_at < 0:
            push_error("Knockdown order missing " + expected_state + ": " + str(order))
            quit(1)
            return
        cursor = found_at + 1
    if player.state != "faceupko":
        push_error("Knockdown did not terminate in faceupko: " + player.state)
        quit(1)
        return
    print("BRICK_KNOCKDOWN_VALIDATION=" + JSON.stringify({
        "order": order,
        "terminal": player.state,
    }))
    scene.queue_free()
    await process_frame
    quit(0)

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
    var seen: Dictionary = {}
    for step: int in range(420):
        player.position = Vector3(0.0, 1.2, 0.0)
        brick.position = Vector3(0.3, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
        brick._physics_process(1.0 / 60.0)
        seen[player.state] = true
        if player.state == "faceupko":
            break
    if not seen.has("stunfall"):
        push_error("Knockdown did not reach stunfall: " + str(seen.keys()))
        quit(1)
        return
    print("BRICK_KNOCKDOWN_VALIDATION=" + JSON.stringify({
        "states": seen.keys(),
        "terminal": player.state,
    }))
    scene.queue_free()
    await process_frame
    quit(0)

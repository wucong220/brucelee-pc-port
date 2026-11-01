extends SceneTree

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_DEMO_RAGE", "100")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    var player: PortFighter = scene.get("player")
    if player == null:
        push_error("main scene has no player")
        quit(1)
        return
    if not is_equal_approx(player.rage, 100.0):
        push_error("demo rage was not applied: " + str(player.rage))
        quit(1)
        return
    print("DEMO_RAGE_VALIDATION=" + JSON.stringify({"rage": player.rage}))
    scene.queue_free()
    await process_frame
    quit(0)

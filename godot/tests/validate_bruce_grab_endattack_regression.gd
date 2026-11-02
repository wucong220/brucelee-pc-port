extends SceneTree
## Verify Bruce's grab and endattack consume the held victim when the
## opponent candidate contains the universal grabbed/endattack clips.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and Brick candidate GLB paths")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
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
    var victim: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    victim.set_physics_process(false)
    scene._reset_match()
    player.position = Vector3(0.0, 1.2, 0.0)
    victim.position = Vector3(0.3, 1.2, 0.0)
    if not player.request_attack("grab1"):
        push_error("Bruce grab1 request failed")
        quit(1)
        return
    var saw_grab: bool = false
    for _step: int in range(500):
        player.position = Vector3(0.0, 1.2, 0.0)
        victim.position = Vector3(0.3, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
        victim._physics_process(1.0 / 60.0)
        if victim.state == "grabbed1":
            saw_grab = true
            break
    if not saw_grab:
        push_error("Bruce grab1 did not put the victim into grabbed1")
        quit(1)
        return
    player.state = "idle"
    player.state_time = 0.0
    player.attack_kind = ""
    if not player.request_attack("endattack1"):
        push_error("Bruce endattack1 request failed")
        quit(1)
        return
    var saw_comp: bool = false
    for _step: int in range(500):
        player.position = Vector3(0.0, 1.2, 0.0)
        victim.position = Vector3(0.3, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
        victim._physics_process(1.0 / 60.0)
        if victim.state in ["endattackcomp1", "faceupko"]:
            saw_comp = true
            break
    if not saw_comp:
        push_error("Bruce endattack1 did not consume the held victim")
        quit(1)
        return
    print("BRUCE_GRAB_ENDATTACK_VALIDATION=" + JSON.stringify({
        "grab_state": "grabbed1",
        "endattack_state": victim.state,
    }))
    quit(0)

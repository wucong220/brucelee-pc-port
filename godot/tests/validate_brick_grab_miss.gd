extends SceneTree
## Verify the retargeted m02 grab miss chains into the matching Brick grab.

const CASES: Dictionary = {
    "grab1_miss_brick": ["grab1_brick", "grabbed1", 6.0],
    "grab2_miss_brick": ["grab2_brick", "grabbed2", 20.0],
}


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
    var main_consts: Dictionary = scene.get_script().get_script_constant_map()
    var ai_costs: Dictionary = main_consts["AI_SPECIAL_RAGE_COSTS"]
    for miss: String in CASES:
        if not is_equal_approx(float(ai_costs.get(miss, 0.0)), 66.0):
            push_error("Grab miss has no 66 rage cost: " + miss)
            quit(1)
            return
    for miss: String in CASES:
        scene._reset_match()
        player.position = Vector3(0.0, 1.2, 0.0)
        brick.position = Vector3(0.3, 1.2, 0.0)
        if not brick.request_attack(miss):
            push_error("Grab miss request failed: " + miss)
            quit(1)
            return
        var chained: bool = false
        var grabbed: bool = false
        for step: int in range(260):
            player.position = Vector3(0.0, 1.2, 0.0)
            brick.position = Vector3(0.3, 1.2, 0.0)
            player._physics_process(1.0 / 60.0)
            brick._physics_process(1.0 / 60.0)
            if brick.attack_kind == CASES[miss][0]:
                chained = true
            if player.state == CASES[miss][1]:
                grabbed = true
                break
        if not chained:
            push_error("Grab miss did not chain: " + miss)
            quit(1)
            return
        if not grabbed:
            push_error("Grab miss chain did not grab: " + miss)
            quit(1)
            return
        if not is_equal_approx(player.health, PortFighter.MAX_HEALTH - CASES[miss][2]):
            push_error("Grab miss damage mismatch: " + str(player.health))
            quit(1)
            return
    print("BRICK_GRAB_MISS_VALIDATION=" + JSON.stringify({
        "grab1_miss_brick": "grab1_brick -> grabbed1, 6",
        "grab2_miss_brick": "grab2_brick -> grabbed2, 20",
    }))
    scene.queue_free()
    await process_frame
    quit(0)

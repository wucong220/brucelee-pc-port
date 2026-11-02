extends SceneTree
## Verify the 0-damage Brick endattack is a finisher: it consumes the grabbed
## victim and plays the matching endattackcomp clip, ending in faceupko.

const CASES: Dictionary = {
    "grab1_brick": ["grabbed1", "endattackcomp1", "all_end_attack_01_forset03"],
    "grab2_brick": ["grabbed2", "endattackcomp2", "all_end_attack_02_forset03"],
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
    for grab: String in CASES:
        scene._reset_match()
        player.position = Vector3(0.0, 1.2, 0.0)
        brick.position = Vector3(0.3, 1.2, 0.0)
        if not brick.request_attack(grab):
            push_error("Grab request failed: " + grab)
            quit(1)
            return
        var grabbed: bool = false
        for step: int in range(220):
            player.position = Vector3(0.0, 1.2, 0.0)
            brick.position = Vector3(0.3, 1.2, 0.0)
            player._physics_process(1.0 / 60.0)
            brick._physics_process(1.0 / 60.0)
            if player.state == CASES[grab][0]:
                grabbed = true
                break
        if not grabbed:
            push_error("Grab did not enter victim state: " + grab)
            quit(1)
            return
        if not brick.request_attack("endattack_brick"):
            push_error("Endattack request failed after " + grab)
            quit(1)
            return
        var saw_comp: bool = false
        for step: int in range(400):
            player.position = Vector3(0.0, 1.2, 0.0)
            brick.position = Vector3(0.3, 1.2, 0.0)
            player._physics_process(1.0 / 60.0)
            brick._physics_process(1.0 / 60.0)
            if player.state == CASES[grab][1]:
                saw_comp = true
                player._animate_candidate()
                if player.candidate_animation_clip != CASES[grab][2]:
                    push_error("Endattack victim clip mismatch: " + player.candidate_animation_clip)
                    quit(1)
                    return
            if saw_comp and player.state == "faceupko":
                break
        if not saw_comp:
            push_error("Endattack did not trigger victim comp: " + grab)
            quit(1)
            return
        if player.state != "faceupko":
            push_error("Endattack victim did not end in faceupko: " + player.state)
            quit(1)
            return
    print("BRICK_ENDATTACK_VALIDATION=" + JSON.stringify({
        "grab1_brick": "endattackcomp1 -> faceupko",
        "grab2_brick": "endattackcomp2 -> faceupko",
        "damage": 0.0,
    }))
    scene.queue_free()
    await process_frame
    quit(0)


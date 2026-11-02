extends SceneTree
## Verify Brick grab hits put the victim into the merged grabbed clip and
## return to the evidence-backed downed state.

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
    if not player.candidate_loaded:
        push_error("Bruce victim candidate failed: " + player.candidate_load_error)
        quit(1)
        return
    if not brick.candidate_loaded:
        push_error("Brick candidate failed: " + brick.candidate_load_error)
        quit(1)
        return
    var cases: Dictionary = {
        "grab1_brick": ["grabbed1", "all_grabbed_01_forset03", "facedownidle", 6.0],
        "grab2_brick": ["grabbed2", "all_grabbed_02_forset03", "faceupidle", 20.0],
    }
    for attack: String in cases:
        scene._reset_match()
        player.position = Vector3(0.0, 1.2, 0.0)
        brick.position = Vector3(0.3, 1.2, 0.0)
        if not brick.request_attack(attack):
            push_error("Grab request failed: " + attack)
            quit(1)
            return
        var saw_grabbed: bool = false
        for step: int in range(400):
            player.position = Vector3(0.0, 1.2, 0.0)
            brick.position = Vector3(0.3, 1.2, 0.0)
            player._physics_process(1.0 / 60.0)
            brick._physics_process(1.0 / 60.0)
            if player.state == cases[attack][0]:
                saw_grabbed = true
                player._animate_candidate()
                if not player._candidate_clip_paths.has(cases[attack][0]):
                    push_error("Merged grab clip is not loaded: " + attack)
                    quit(1)
                    return
                if player.candidate_animation_clip != cases[attack][1]:
                    push_error("Grab did not play merged clip: " + attack
                            + " clip=" + player.candidate_animation_clip)
                    quit(1)
                    return
            if saw_grabbed and player.state == cases[attack][2]:
                break
        if not saw_grabbed:
            push_error("Grab did not enter grabbed state: " + attack)
            quit(1)
            return
        if player.state != cases[attack][2]:
            push_error("Grab did not return to downed state: " + attack
                    + " state=" + player.state)
            quit(1)
            return
        if not is_equal_approx(player.health, PortFighter.MAX_HEALTH - cases[attack][3]):
            push_error("Grab damage mismatch for " + attack + ": " + str(player.health))
            quit(1)
            return
    var lethal_cases: Dictionary = {
        "grab1_brick": 5.0,
        "grab2_brick": 19.0,
    }
    for attack: String in lethal_cases:
        scene._reset_match()
        player.position = Vector3(0.0, 1.2, 0.0)
        brick.position = Vector3(0.3, 1.2, 0.0)
        player.health = float(lethal_cases[attack])
        if not brick.request_attack(attack):
            push_error("Lethal grab request failed: " + attack)
            quit(1)
            return
        for step: int in range(220):
            player.position = Vector3(0.0, 1.2, 0.0)
            brick.position = Vector3(0.3, 1.2, 0.0)
            player._physics_process(1.0 / 60.0)
            brick._physics_process(1.0 / 60.0)
            if player.state in ["grabbed1", "grabbed2"]:
                push_error("Lethal grab incorrectly entered grabbed state: " + attack)
                quit(1)
                return

    print("BRICK_GRAB_VICTIM_VALIDATION=" + JSON.stringify({
        "grab1_brick": "grabbed1 -> facedownidle",
        "grab2_brick": "grabbed2 -> faceupidle",
        "damage": [6.0, 20.0],
    }))
    scene.queue_free()
    await process_frame
    quit(0)


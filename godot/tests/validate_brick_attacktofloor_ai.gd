extends SceneTree
## Verify Brick AI uses the native m03_attack_to_floor against a downed target.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and Brick combat candidate GLB paths")
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
    if not brick.candidate_loaded:
        push_error("Brick candidate failed: " + brick.candidate_load_error)
        quit(1)
        return
    var rng: RandomNumberGenerator = scene.get("rng")
    for seed_value: int in range(1, 120):
        scene._reset_match()
        player.position = Vector3(0.0, 1.2, 0.0)
        brick.position = Vector3(0.3, 1.2, 0.0)
        player.state = "facedownidle"
        brick.rage = 0.0
        scene.ai_timer = 0.0
        rng.seed = seed_value
        scene._think_ai(0.5)
        if brick.attack_kind != "attack_to_floor_brick":
            continue
        brick._animate_candidate()
        if brick.candidate_animation_clip != "m03_attack_to_floor":
            push_error("Attack-to-floor clip mismatch: " + brick.candidate_animation_clip)
            quit(1)
            return
        # Verify the native hit and damage against the downed target.
        scene._reset_match()
        player.position = Vector3(0.0, 1.2, 0.0)
        brick.position = Vector3(0.3, 1.2, 0.0)
        player.state = "facedownidle"
        if not brick.request_attack("attack_to_floor_brick"):
            push_error("Attack-to-floor request failed")
            quit(1)
            return
        for step: int in range(120):
            player.position = Vector3(0.0, 1.2, 0.0)
            brick.position = Vector3(0.3, 1.2, 0.0)
            player._physics_process(1.0 / 60.0)
            brick._physics_process(1.0 / 60.0)
            if player.health < PortFighter.MAX_HEALTH:
                break
        if not is_equal_approx(player.health, 94.0):
            push_error("Attack-to-floor damage mismatch: " + str(player.health))
            quit(1)
            return
        print("BRICK_ATTACKTOFLOOR_AI_VALIDATION=" + JSON.stringify({
            "attack": "attack_to_floor_brick",
            "clip": "m03_attack_to_floor",
            "damage": 6.0,
        }))
        scene.queue_free()
        await process_frame
        quit(0)
        return
    push_error("Brick AI did not select attack_to_floor_brick")
    quit(1)

extends SceneTree

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
    for seed_value: int in range(1, 200):
        scene._reset_match()
        player.position = Vector3(0.0, 1.2, 0.0)
        brick.position = Vector3(0.7, 1.2, 0.0)
        scene.ai_timer = 0.0
        rng.seed = seed_value
        scene._think_ai(0.5)
        if brick.state != "startup":
            continue
        if not brick.supports_attack(brick.attack_kind):
            push_error("AI selected an unsupported Brick attack: " + brick.attack_kind)
            quit(1)
            return
        brick._animate_candidate()
        var expected_clip: String = String(PortFighter.BRICK_CLIPS[brick.attack_kind])
        if brick.candidate_animation_clip != expected_clip:
            push_error("AI attack clip mismatch for " + brick.attack_kind + ": "
                    + brick.candidate_animation_clip)
            quit(1)
            return
        if brick.attack_kind in ["punch", "kick"]:
            push_error("AI stayed on the old two-attack pool: " + brick.attack_kind)
            quit(1)
            return
        print("BRICK_AI_ATTACK_VALIDATION=" + JSON.stringify({
            "seed": seed_value,
            "attack": brick.attack_kind,
            "clip": brick.candidate_animation_clip,
        }))
        scene.queue_free()
        await process_frame
        quit(0)
        return
    push_error("Brick AI did not start an attack in 199 seeds")
    quit(1)

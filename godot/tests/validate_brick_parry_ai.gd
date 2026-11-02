extends SceneTree
## Verify the prototype Brick AI parry choice and the recovered high-parry chain.

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
    var seen: Dictionary = {}
    for seed_value: int in range(1, 500):
        scene._reset_match()
        player.position = Vector3(0.0, 1.2, 0.0)
        brick.position = Vector3(0.8, 1.2, 0.0)
        player.request_attack("high_punch3" if seed_value % 2 == 1 else "kick")
        brick.rage = 66.0
        scene.ai_timer = 0.0
        rng.seed = seed_value
        scene._think_ai(0.5)
        if brick.attack_kind not in ["parry_high_brick", "parry_low_brick"]:
            continue
        seen[brick.attack_kind] = true
        if brick.attack_kind == "parry_high_brick":
            for step: int in range(80):
                # Keep the incoming attack in a threat state so the recovered
                # 9-10 frame parry chain can fire deterministically.
                player.state = "startup"
                player.state_time = 1.0
                brick._physics_process(1.0 / 60.0)
                if brick.attack_kind == "parry_attack_brick":
                    break
            if brick.attack_kind != "parry_attack_brick":
                push_error("Brick high parry did not chain to parry_attack_brick")
                quit(1)
                return
            for step: int in range(80):
                player.state = "startup"
                player.state_time = 1.0
                brick._physics_process(1.0 / 60.0)
                if player.health < PortFighter.MAX_HEALTH:
                    break
            if not is_equal_approx(player.health, 90.0):
                push_error("Brick parry_attack damage mismatch: " + str(player.health))
                quit(1)
                return
        if seen.size() == 2:
            break
    if seen.size() != 2:
        push_error("Brick AI did not select both parry types: " + JSON.stringify(seen.keys()))
        quit(1)
        return
    print("BRICK_PARRY_AI_VALIDATION=" + JSON.stringify({
        "parries": seen.keys(),
        "chain_damage": 10.0,
    }))
    scene.queue_free()
    await process_frame
    quit(0)

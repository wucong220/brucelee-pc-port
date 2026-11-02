extends SceneTree
## Verify the prototype Brick AI can spend rage on the four evidence-backed
## thai.set specials and cannot select them below their rage gate.

const SPECIALS: Dictionary = {
    "special_kick_high_brick": 33.0,
    "special_kick_low_brick": 33.0,
    "special_punch_high_brick": 66.0,
    "special_punch_low_brick": 66.0,
}


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
    for seed_value: int in range(1, 400):
        scene._reset_match()
        player.position = Vector3(0.0, 1.2, 0.0)
        brick.position = Vector3(0.7, 1.2, 0.0)
        brick.rage = 66.0
        scene.ai_timer = 0.0
        rng.seed = seed_value
        scene._think_ai(0.5)
        if not SPECIALS.has(brick.attack_kind):
            continue
        var cost: float = float(SPECIALS[brick.attack_kind])
        if not is_equal_approx(brick.rage, 66.0 - cost):
            push_error("Brick special did not spend rage: " + brick.attack_kind
                    + " rage=" + str(brick.rage))
            quit(1)
            return
        brick._animate_candidate()
        var expected_clip: String = String(PortFighter.BRICK_CLIPS[brick.attack_kind])
        if brick.candidate_animation_clip != expected_clip:
            push_error("Brick special clip mismatch for " + brick.attack_kind + ": "
                    + brick.candidate_animation_clip)
            quit(1)
            return
        seen[brick.attack_kind] = true
        if seen.size() == SPECIALS.size():
            break
    if seen.size() != SPECIALS.size():
        push_error("Brick AI did not select all four specials: " + JSON.stringify(seen.keys()))
        quit(1)
        return
    var expected_damage: Dictionary = {
        "special_kick_high_brick": 10.0,
        "special_kick_low_brick": 9.0,
        "special_punch_high_brick": 11.0,
        "special_punch_low_brick": 8.0,
    }
    for attack: String in expected_damage:
        scene._reset_match()
        player.position = Vector3(0.0, 1.2, 0.0)
        brick.position = Vector3(0.7, 1.2, 0.0)
        if not brick.request_attack(attack):
            push_error("Brick special request failed: " + attack)
            quit(1)
            return
        for step: int in range(120):
            brick._physics_process(1.0 / 60.0)
            if player.health < PortFighter.MAX_HEALTH:
                break
        if not is_equal_approx(player.health, PortFighter.MAX_HEALTH - expected_damage[attack]):
            push_error("Brick special damage mismatch for " + attack + ": "
                    + str(player.health))
            quit(1)
            return
    # Below ragethird the AI must fall back to the base pool.
    for seed_value: int in range(1, 100):
        scene._reset_match()
        player.position = Vector3(0.0, 1.2, 0.0)
        brick.position = Vector3(0.7, 1.2, 0.0)
        brick.rage = 0.0
        scene.ai_timer = 0.0
        rng.seed = seed_value
        scene._think_ai(0.5)
        if SPECIALS.has(brick.attack_kind):
            push_error("Brick used a special below its rage gate: " + brick.attack_kind)
            quit(1)
            return
    print("BRICK_SPECIAL_AI_VALIDATION=" + JSON.stringify({
        "specials": seen.keys(),
        "rage_gate": "33/66",
    }))
    scene.queue_free()
    await process_frame
    quit(0)

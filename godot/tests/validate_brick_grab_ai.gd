extends SceneTree
## Verify the two recovered native Brick grab attacks selected by the AI.

const GRABS: Dictionary = {
    "grab1_brick": 6.0,
    "grab2_brick": 20.0,
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
        brick.position = Vector3(0.3, 1.2, 0.0)
        brick.rage = 66.0
        scene.ai_timer = 0.0
        rng.seed = seed_value
        scene._think_ai(0.5)
        if not GRABS.has(brick.attack_kind):
            continue
        if not is_equal_approx(brick.rage, 0.0):
            push_error("Brick grab did not spend rage: " + brick.attack_kind)
            quit(1)
            return
        brick._animate_candidate()
        var expected_clip: String = String(PortFighter.BRICK_CLIPS[brick.attack_kind])
        if brick.candidate_animation_clip != expected_clip:
            push_error("Brick grab clip mismatch: " + brick.candidate_animation_clip)
            quit(1)
            return
        var attack: String = brick.attack_kind
        seen[attack] = true
        # Verify the native hit actually lands with the expected damage.
        scene._reset_match()
        player.position = Vector3(0.0, 1.2, 0.0)
        brick.position = Vector3(0.3, 1.2, 0.0)
        if not brick.request_attack(attack):
            push_error("Brick grab request failed: " + attack)
            quit(1)
            return
        for step: int in range(220):
            player.position = Vector3(0.0, 1.2, 0.0)
            brick.position = Vector3(0.3, 1.2, 0.0)
            player._physics_process(1.0 / 60.0)
            brick._physics_process(1.0 / 60.0)
            if player.health < PortFighter.MAX_HEALTH:
                break
        if not is_equal_approx(player.health,
                PortFighter.MAX_HEALTH - float(GRABS[attack])):
            push_error("Brick grab damage mismatch for " + attack
                    + ": " + str(player.health))
            quit(1)
            return
        if seen.size() == GRABS.size():
            break
    if seen.size() != GRABS.size():
        push_error("Brick AI did not select both grabs: " + JSON.stringify(seen.keys()))
        quit(1)
        return
    print("BRICK_GRAB_AI_VALIDATION=" + JSON.stringify({
        "grabs": seen.keys(),
        "damage": GRABS,
    }))
    scene.queue_free()
    await process_frame
    quit(0)

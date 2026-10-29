extends SceneTree
## Prototype AI must decide once per threat and hold guard through active frames.


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var opponent: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    opponent.set_physics_process(false)
    var rng: RandomNumberGenerator = scene.get("rng")
    var guard_seed: int = -1
    for seed_value: int in range(1000):
        rng.seed = seed_value
        if rng.randf() < 0.25:
            guard_seed = seed_value
            break
    if guard_seed < 0:
        push_error("Unable to find deterministic guard seed")
        quit(1)
        return
    for fps: int in [30, 60, 120]:
        scene._reset_match()
        player.position = Vector3(0.0, 1.2, 0.0)
        opponent.position = Vector3(0.6, 1.2, 0.0)
        scene.ai_timer = 1000.0
        rng.seed = guard_seed
        if not player.request_attack("punch"):
            push_error("Could not start player attack")
            quit(1)
            return
        scene._think_ai(1.0 / fps)
        if not opponent.guard_held:
            push_error("AI did not choose seeded guard")
            quit(1)
            return
        var after_decision: int = rng.state
        for tick: int in range(fps / 10 + 2):
            scene._think_ai(1.0 / fps)
            if not opponent.guard_held or rng.state != after_decision:
                push_error("Guard decision changed during startup at %d FPS" % fps)
                quit(1)
                return
        player._advance_state() # startup -> active, without applying contact yet
        scene._think_ai(1.0 / fps)
        if not opponent.guard_held or rng.state != after_decision:
            push_error("Guard did not persist into active frames")
            quit(1)
            return
        player.facing = 1.0
        player._try_attack_contact()
        if opponent.state != "blockstun" or absf(opponent.health - 99.4) > 0.001:
            push_error("Guarded contact did not reach blockstun")
            quit(1)
            return
        player._advance_state() # active -> recovery
        scene._think_ai(1.0 / fps)
        if opponent.guard_held:
            push_error("Guard remained held during recovery")
            quit(1)
            return
        if scene.ai_guard_sequence != -1 or scene.ai_guard_decision:
            push_error("Recovery retained the guard decision cache")
            quit(1)
            return
    # A threat that starts out of reach can be noticed after entering range.
    scene._reset_match()
    player.position = Vector3(0.0, 1.2, 0.0)
    opponent.position = Vector3(3.0, 1.2, 0.0)
    scene.ai_timer = 1000.0
    rng.seed = guard_seed
    player.request_attack("punch")
    scene._think_ai(0.016)
    if opponent.guard_held or scene.ai_guard_sequence == player.attack_sequence:
        push_error("Out-of-range attack consumed the guard decision")
        quit(1)
        return
    player._advance_state()
    opponent.position = Vector3(0.6, 1.2, 0.0)
    scene._think_ai(0.016)
    if not opponent.guard_held:
        push_error("AI failed to decide on an active attack entering range")
        quit(1)
        return
    player.receive_hit(5.0, false, 0.0, 1.0)
    scene._think_ai(0.016)
    if opponent.guard_held:
        push_error("Guard persisted after the attack was interrupted")
        quit(1)
        return
    if scene.ai_guard_sequence != -1 or scene.ai_guard_decision:
        push_error("Interruption retained the guard decision cache")
        quit(1)
        return
    scene._reset_match()
    if opponent.guard_held or scene.ai_guard_sequence != -1:
        push_error("Round reset retained the guard decision")
        quit(1)
        return

    # Replicate the scene's real update order: parent AI decides guard before
    # child fighter contact checks. The opponent starts just outside reach and
    # moves into range only after the active-frame contact check.
    for fps: int in [30, 60, 120]:
        var dt: float = 1.0 / fps
        scene._reset_match()
        player.position = Vector3(0.0, 1.2, 0.0)
        var punch_reach: float = player.attack_reach_world("punch", opponent)
        opponent.position = Vector3(punch_reach + 0.005, 1.2, 0.0)
        scene.ai_timer = 1000.0
        rng.seed = guard_seed
        if not player.request_attack("punch"):
            push_error("Could not start frame-order attack")
            quit(1)
            return
        for startup_frame: int in range(fps):
            scene._physics_process(dt)
            # Keep startup distance fixed so this test isolates active-frame entry.
            opponent.move_axis = Vector2.ZERO
            player._physics_process(dt)
            opponent._physics_process(dt)
            if player.state != "startup":
                break
        if player.state != "active":
            push_error("Frame-order test did not reach active state")
            quit(1)
            return
        var entered_range: bool = false
        var guarded_contact: bool = false
        var minimum_distance: float = INF
        var observed_state: String = ""
        for active_frame: int in range(fps):
            scene._physics_process(dt)
            var before_contact_distance: float = Vector2(
                player.global_position.x - opponent.global_position.x,
                player.global_position.z - opponent.global_position.z
            ).length()
            if before_contact_distance > punch_reach:
                # Simulate another movement source carrying the defender into
                # range after this frame's contact check but before the next AI
                # decision. The AI itself intentionally stops outside player reach.
                opponent.move_axis = Vector2(-1.0, 0.0)
            player._physics_process(dt)
            if player.combo_hits == 1:
                guarded_contact = opponent.state == "blockstun"
                break
            opponent._physics_process(dt)
            var current_distance: float = Vector2(
                player.global_position.x - opponent.global_position.x,
                player.global_position.z - opponent.global_position.z
            ).length()
            minimum_distance = minf(minimum_distance, current_distance)
            observed_state = player.state
            if current_distance <= punch_reach:
                entered_range = true
        if not entered_range or not guarded_contact:
            push_error(
                "Real update order missed guard before contact at %d FPS (range=%s, guarded=%s, min=%.6f, reach=%.6f, state=%s)"
                % [fps, entered_range, guarded_contact, minimum_distance,
                        punch_reach, observed_state]
            )
            quit(1)
            return
        if absf(opponent.health - 99.4) > 0.001:
            push_error("Frame-order guarded contact applied full damage at %d FPS" % fps)
            quit(1)
            return
    print("AI_GUARD_VALIDATION=PASS")
    quit(0)

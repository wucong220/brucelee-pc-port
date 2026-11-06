extends SceneTree
## Native ground-attack links: facedownidle/faceupidle -> facedownattack/faceupattack.


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected the Bruce facedown-attack GLB and the Brick GLB")
        quit(1)
        return
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", "")
    OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", "")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var opponent: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    opponent.set_physics_process(false)
    if not player.candidate_loaded or not opponent.candidate_loaded:
        push_error("Facedown-attack candidates failed to load")
        quit(1)
        return
    if not player._candidate_clip_paths.has(PortFighter.FACEDOWN_ATTACK_CLIP):
        push_error("facedownattack candidate clip is missing")
        quit(1)
        return

    var checks: Dictionary = {}

    player.reset_fighter(Vector3(-0.25, 1.2, 0.0))
    player._enter_locomotion_state("facedownidle")
    player.record_standing_combo_press("a")
    checks["facedown_a"] = player.state
    if player.state != "facedownattack":
        push_error("A did not start facedownattack: " + player.state)
        quit(1)
        return

    player._enter_locomotion_state("faceupidle")
    player.record_standing_combo_press("b")
    checks["faceup_b"] = player.state
    if player.state != "faceupattack":
        push_error("B did not start faceupattack: " + player.state)
        quit(1)
        return

    player._enter_locomotion_state("idle")
    player.record_standing_combo_press("a")
    if player.state == "facedownattack" or player.state == "faceupattack":
        push_error("a ground attack started from idle")
        quit(1)
        return
    checks["idle_a"] = player.state

    opponent.reset_fighter(Vector3(0.25, 1.2, 0.0))
    opponent._enter_locomotion_state("facedownidle")
    # Brick's candidate has no Bruce ground-attack clip, so the link must fail
    # closed instead of playing a missing animation.
    opponent.record_standing_combo_press("a")
    checks["brick_facedown_a"] = opponent.state
    if opponent.state == "facedownattack":
        push_error("Brick started a ground attack without its clip")
        quit(1)
        return

    print("FACEDOWN_ATTACK_VALIDATION=" + JSON.stringify(checks))
    quit(0)

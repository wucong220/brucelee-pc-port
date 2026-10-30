extends SceneTree
## Exercise candidate source-pose selection and the two local candidate clips.


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected the 23-clip Bruce GLB and 5-clip Brick GLB")
        quit(1)
        return
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", "")
    OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", "")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var brick: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    brick.set_physics_process(false)
    if not player.candidate_loaded or not brick.candidate_loaded:
        push_error("Candidate load failed: %s | %s" % [
            player.candidate_load_error, brick.candidate_load_error,
        ])
        quit(1)
        return
    if (not _check_brick(brick) or not _check_bruce(player)
            or not _check_attack_to_floor(scene, player, brick)):
        quit(1)
        return
    print("GROUND_POSE_VALIDATION=" + JSON.stringify({
        "brick_clip": PortFighter.BRICK_FACEDOWN_IDLE_CLIP,
        "brick_pose": "laying",
        "bruce_clip": PortFighter.ATTACK_TO_FLOOR_CLIP,
        "bruce_pose": "stand",
        "scope": "candidate attacktofloor input path; original timing and link priority unverified",
    }))
    quit(0)


func _check_attack_to_floor(scene: Node, player: PortFighter, brick: PortFighter) -> bool:
    if not player._candidate_clip_paths.has(PortFighter.ATTACK_TO_FLOOR_CLIP):
        push_error("attacktofloor candidate clip failed loading")
        return false
    player.reset_fighter(Vector3.ZERO)
    brick.reset_fighter(Vector3(0.25, 1.2, 0.0))
    brick._enter_locomotion_state("facedownidle")
    player.facing = 1.0
    _press_key(scene, KEY_K)
    if player.state != "idle":
        push_error("attacktofloor prefix started an ordinary attack or state")
        return false
    _press_key(scene, KEY_L)
    if player.state != "idle":
        push_error("Incomplete attacktofloor sequence started")
        return false
    _press_key(scene, KEY_L)
    if player.state != "attacktofloor":
        push_error("Complete attacktofloor sequence did not start")
        return false
    player._animate_candidate()
    if player.candidate_animation_clip != player._candidate_clip_paths[PortFighter.ATTACK_TO_FLOOR_CLIP]:
        push_error("attacktofloor clip not selected")
        return false
    var before: float = brick.health
    player._advance_timed_states(18.01 / PortFighter.SOURCE_FRAME_RATE)
    if absf(brick.health - (before - 6.0)) > 0.001:
        push_error("attacktofloor did not apply recovered damage")
        return false
    player._advance_timed_states(5.0 / PortFighter.SOURCE_FRAME_RATE)
    if absf(brick.health - (before - 6.0)) > 0.001:
        push_error("attacktofloor damaged more than once")
        return false
    var before_exit_frame: float = player.state_time * PortFighter.SOURCE_FRAME_RATE
    player._advance_timed_states(
        (PortFighter.ATTACK_TO_FLOOR_EXIT_START_FRAME - before_exit_frame)
                / PortFighter.SOURCE_FRAME_RATE - 0.001
    )
    if player.state != "attacktofloor":
        push_error("attacktofloor exited before its candidate window")
        return false
    player._advance_timed_states(0.002)
    if player.state != "idle2":
        push_error("attacktofloor did not enter its recovered idle2 return")
        return false
    player._animate_candidate()
    if player.candidate_animation_clip != player._candidate_clip_paths[PortFighter.IDLE2_CLIP]:
        push_error("attacktofloor idle2 return did not select m01_idle_02")
        return false
    # Standing opponent keeps the ordinary kick path; the target action is the gate.
    brick._enter_locomotion_state("idle")
    _press_key(scene, KEY_K)
    if player.state != "startup" or player.attack_kind != "kick":
        push_error("attacktofloor started without a laying opponent")
        return false
    # A lone c is not a valid prefix and must keep the ordinary heavy fallback.
    player._enter_locomotion_state("idle")
    brick._enter_locomotion_state("facedownidle")
    _press_key(scene, KEY_L)
    if player.state != "startup" or player.attack_kind != "heavy":
        push_error("a lone c was incorrectly consumed as an attacktofloor prefix")
        return false

    for source_state: String in ["idle", "idle2"]:
        for sequence: Array in PortFighter.ATTACK_TO_FLOOR_SEQUENCES:
            player._enter_locomotion_state(source_state)
            brick._enter_locomotion_state("facedownidle")
            for key_index: int in range(sequence.size()):
                var key_value: Variant = sequence[key_index]
                _press_virtual_key(scene, String(key_value))
                var expected_state: String = (
                    "attacktofloor"
                    if key_index == sequence.size() - 1
                    else source_state
                )
                if player.state != expected_state:
                    push_error("attacktofloor main input produced the wrong state")
                    return false
            if player.state != "attacktofloor":
                push_error("attacktofloor rejected source state or sequence")
                return false
            player._enter_locomotion_state("idle")

    # Crossing the damage window in one large step still performs one contact.
    brick._enter_locomotion_state("facedownidle")
    player._enter_locomotion_state("idle")
    for key_value: Variant in ["b", "c", "c"]:
        player.record_attack_to_floor_press(String(key_value))
    var health: float = brick.health
    player._advance_timed_states(24.01 / PortFighter.SOURCE_FRAME_RATE)
    if absf(brick.health - (health - 6.0)) > 0.001:
        push_error("attacktofloor missed a crossed damage window")
        return false
    player._advance_timed_states(1.0)
    if absf(brick.health - (health - 6.0)) > 0.001:
        push_error("attacktofloor repeated contact")
        return false

    # Range, facing, blocked and lethal cases stay on explicit fallbacks.
    for case_name: String in [
        "far", "backward", "guard", "lethal", "missing_attack", "missing_return",
    ]:
        brick._enter_locomotion_state("facedownidle")
        brick.guard_held = false
        brick.health = 6.0 if case_name == "lethal" else PortFighter.MAX_HEALTH
        player._enter_locomotion_state("idle")
        player.global_position = Vector3(0.25, 1.2, 0.0)
        brick.global_position = Vector3(0.25, 1.2, 0.0)
        player.facing = 1.0
        if case_name == "far":
            brick.global_position = Vector3(10.0, 1.2, 0.0)
        elif case_name == "backward":
            brick.global_position = Vector3(-0.25, 1.2, 0.0)
            player.facing = 1.0
        elif case_name == "guard":
            # A held guard does not turn laying into a standing block.
            brick.guard_held = true
        var saved_clip: String = ""
        if case_name in ["missing_attack", "missing_return"]:
            var missing_key: String = (
                PortFighter.ATTACK_TO_FLOOR_CLIP
                if case_name == "missing_attack"
                else PortFighter.IDLE2_CLIP
            )
            saved_clip = player._candidate_clip_paths[missing_key]
            player._candidate_clip_paths.erase(missing_key)
            if (player.try_attack_to_floor_press("b")
                    != PortFighter.AttackToFloorInputResult.IGNORED):
                push_error("attacktofloor accepted a missing clip")
                return false
            player._candidate_clip_paths[missing_key] = saved_clip
            continue
        for key_value: Variant in ["b", "c", "c"]:
            player.record_attack_to_floor_press(String(key_value))
        health = brick.health
        if case_name == "guard" and brick._can_block_current_hit():
            push_error("facedownidle unexpectedly allowed a standing block")
            return false
        player._advance_timed_states(18.01 / PortFighter.SOURCE_FRAME_RATE)
        if case_name == "lethal" and brick.state != "facedownko":
            push_error("lethal attacktofloor did not preserve KO fallback: health=%s state=%s reaction=%s" % [
                brick.health, brick.state, brick.last_reaction_source_action])
            return false
        # A held guard does not make the lying pose block this attack, so the
        # contact is unguarded and applies full damage.
        var expected_damage: float = 6.0 if case_name in ["guard", "lethal"] else 0.0
        if absf(brick.health - (health - expected_damage)) > 0.001:
            push_error("attacktofloor contact escaped candidate gate: " + case_name)
            return false
    return true


func _press_key(scene: Node, keycode: Key) -> void:
    var event := InputEventKey.new()
    event.pressed = true
    event.keycode = keycode
    scene._unhandled_key_input(event)


func _press_virtual_key(scene: Node, virtual_key: String) -> void:
    match virtual_key:
        "b":
            _press_key(scene, KEY_K)
        "c":
            _press_key(scene, KEY_L)
        "d":
            _press_key(scene, KEY_U)
        _:
            push_error("Unexpected attacktofloor virtual key: " + virtual_key)


func _check_brick(brick: PortFighter) -> bool:
    var clip_name: String = PortFighter.BRICK_FACEDOWN_IDLE_CLIP
    if not brick._candidate_clip_paths.has(clip_name):
        push_error("Brick lying clip failed candidate track validation")
        return false
    brick.reset_fighter(Vector3.ZERO)
    brick._enter_locomotion_state("facedownidle")
    brick._animate_candidate()
    var animation: AnimationPlayer = brick.get("_candidate_animation")
    var clip: Animation = animation.get_animation(brick._candidate_clip_paths[clip_name])
    if (brick.current_source_animation() != clip_name
            or brick.current_source_pose() != "laying"
            or brick.candidate_animation_clip != brick._candidate_clip_paths[clip_name]
            or absf(clip.length - 1.5) > 0.002
            or clip.loop_mode != Animation.LOOP_LINEAR
            or absf(brick.source_radius_for_current_animation() - 75.0) > 0.001):
        push_error("Brick lying candidate did not select the expected clip/pose/radius")
        return false
    var saved: String = brick._candidate_clip_paths[clip_name]
    brick._candidate_clip_paths.erase(clip_name)
    var missing_pose: String = brick.current_source_pose()
    brick._candidate_clip_paths[clip_name] = saved
    if not missing_pose.is_empty():
        push_error("Brick lying pose remained available after clip removal")
        return false
    brick.reset_fighter(Vector3.ZERO)
    if brick.current_source_pose() != "stand":
        push_error("Brick reset did not restore the standing pose")
        return false
    brick.state = "unmapped_action"
    if not brick.current_source_pose().is_empty():
        push_error("An unmapped action was treated as a known pose")
        return false
    return true


func _check_bruce(player: PortFighter) -> bool:
    var clip_name: String = PortFighter.ATTACK_TO_FLOOR_CLIP
    if not player._candidate_clip_paths.has(clip_name):
        push_error("Bruce attack-to-floor clip failed candidate track validation")
        return false
    player.reset_fighter(Vector3.ZERO)
    player.state = "attacktofloor"
    player._animate_candidate()
    var animation: AnimationPlayer = player.get("_candidate_animation")
    var clip: Animation = animation.get_animation(player._candidate_clip_paths[clip_name])
    if (player.current_source_pose() != "stand"
            or player.candidate_animation_clip != player._candidate_clip_paths[clip_name]
            or absf(clip.length - 3.0) > 0.002
            or clip.loop_mode != Animation.LOOP_NONE):
        push_error("Bruce attack-to-floor candidate clip/pose mismatch")
        return false
    animation.seek(9.0 / PortFighter.SOURCE_FRAME_RATE, true)
    if absf(animation.current_animation_position - 0.3) > 0.002:
        push_error("Could not seek the candidate clip to source frame 9")
        return false
    player.reset_fighter(Vector3.ZERO)
    return true

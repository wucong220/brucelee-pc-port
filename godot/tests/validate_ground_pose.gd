extends SceneTree
## Exercise candidate source-pose selection and the two local candidate clips.

var _ground_pose_combat_hit_count: int = 0


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
    if (not _check_contextual_controls(scene, player, brick)
            or not _check_training(scene, player, brick)
            or not _check_brick(brick) or not _check_bruce(player)
            or not _check_attack_to_floor_input_resets(player, brick)
            or not _check_attack_to_floor_repeated_rejection(player, brick)
            or not _check_attack_to_floor_rejected_then_accepted(player, brick)
            or not _check_attack_to_floor_window_boundaries(player, brick)
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


func _check_contextual_controls(scene: Node, player: PortFighter, brick: PortFighter) -> bool:
    player.reset_fighter(Vector3.ZERO)
    brick.reset_fighter(Vector3(0.25, 1.2, 0.0))
    if scene._contextual_controls() != "":
        push_error("Ground controls appeared while both fighters were standing")
        return false
    brick._enter_locomotion_state("facedownidle")
    if not scene._contextual_controls().contains("K L L / K U U"):
        push_error("Downed-opponent controls were not shown")
        return false
    scene._physics_process(0.0)
    var hud: PortHUD = scene.get("hud")
    if not hud.context_hint.text.contains("K L L / K U U"):
        push_error("Downed-opponent controls did not reach the HUD")
        return false
    player._enter_locomotion_state("facedownidle")
    var text: String = scene._contextual_controls()
    if not text.contains("A/D: get up") or not text.contains("J J J"):
        push_error("Face-down controls were not shown")
        return false
    player._enter_locomotion_state("faceupidle")
    text = scene._contextual_controls()
    if not text.contains("A/D: get up") or not text.contains("J J J"):
        push_error("Face-up controls were not shown")
        return false
    var clips: Dictionary = player.get("_candidate_clip_paths")
    var attack_path: Variant = clips[PortFighter.FACEUP_ATTACK_CLIP]
    clips.erase(PortFighter.FACEUP_ATTACK_CLIP)
    text = scene._contextual_controls()
    clips[PortFighter.FACEUP_ATTACK_CLIP] = attack_path
    if text.contains("Ground attack") or not text.contains("A/D: get up"):
        push_error("Controls advertised an unavailable ground attack")
        return false
    scene.set("done", true)
    if scene._contextual_controls() != "":
        push_error("Controls remained visible after the round ended")
        return false
    scene.set("done", false)
    player.reset_fighter(Vector3.ZERO)
    brick.reset_fighter(Vector3(0.25, 1.2, 0.0))
    return true


func _check_training(scene: Node, player: PortFighter, brick: PortFighter) -> bool:
    var clips: Dictionary = brick.get("_candidate_clip_paths")
    var impact_path: Variant = clips[PortFighter.FACEDOWN_IMPACT_CLIP]
    clips.erase(PortFighter.FACEDOWN_IMPACT_CLIP)
    _press_key(scene, KEY_F2)
    clips[PortFighter.FACEDOWN_IMPACT_CLIP] = impact_path
    if scene.get("training_mode"):
        push_error("Training started without the required Brick impact clip")
        return false
    _press_key(scene, KEY_F2)
    if not scene.get("training_mode"):
        push_error("Training did not start with candidate animations available")
        return false
    var hud: PortHUD = scene.get("hud")
    scene._on_hit(player, player, "attacktofloor", 6.0, false)
    scene._on_hit(player, brick, "attacktofloor", 0.0, false)
    scene._on_hit(player, brick, "attacktofloor", 6.0, true)
    scene._on_hit(player, brick, "attacktofloor", 6.0, false)
    if scene.get("training_completed"):
        push_error("Training completed without the required target, damage and reaction")
        return false
    _press_key(scene, KEY_R)
    for attempt: int in range(10):
        if (player.state != "idle" or brick.state != "facedownidle"
                or player.health != 100.0 or brick.health != 100.0
                or scene.get("training_completed")):
            push_error("Training reset retained state on attempt %d" % attempt)
            return false
        player.candidate_visual_blending_enabled = (attempt % 2 == 1)
        for key: int in [KEY_K, KEY_L, KEY_L]:
            _press_key(scene, key)
        if player.state != "attacktofloor":
            push_error("Training attack did not start on attempt %d" % attempt)
            return false
        player._advance_timed_states(18.01 / PortFighter.SOURCE_FRAME_RATE)
        if (absf(brick.health - 94.0) > 0.001 or not scene.get("training_completed")
                or not hud.center_message.text.contains("TRAINING HIT")):
            push_error("Training did not record exactly one hit on attempt %d" % attempt)
            return false
        var completed_message: String = hud.center_message.text
        scene._on_hit(brick, player, "punch", 5.0, false)
        scene._on_ko(player)
        _press_key(scene, KEY_J)
        if hud.center_message.text != completed_message or scene.get("done"):
            push_error("Training completion message was overwritten")
            return false
        player._advance_timed_states(5.0 / PortFighter.SOURCE_FRAME_RATE)
        if absf(brick.health - 94.0) > 0.001:
            push_error("Training applied duplicate damage")
            return false
        _press_key(scene, KEY_R)
    _press_key(scene, KEY_F2)
    if (scene.get("training_mode") or player.state != "idle"
            or brick.state != "idle" or absf(player.position.x + 2.0) > 0.001):
        push_error("Training exit did not restore the normal match")
        return false
    return true


func _check_attack_to_floor(scene: Node, player: PortFighter, brick: PortFighter) -> bool:
    player.candidate_visual_blending_enabled = false
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
    if player.candidate_visual_blend_seconds_last != 0.0:
        push_error("default-off attacktofloor return applied a visual blend")
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

    # Range and facing are contact gates, so they must start the action and miss.
    # Blocked and lethal cases remain separate contact/follow-up checks.
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
        var is_miss_case: bool = case_name in ["far", "backward"]
        var combo_before: int = player.combo_hits
        if is_miss_case:
            _ground_pose_combat_hit_count = 0
            player.combat_hit.connect(_count_ground_pose_combat_hit)
        for key_value: Variant in ["b", "c", "c"]:
            player.record_attack_to_floor_press(String(key_value))
        if player.state != "attacktofloor":
            push_error("attacktofloor did not start before contact missed: " + case_name)
            return false
        health = brick.health
        if case_name == "guard" and brick._can_block_current_hit():
            push_error("facedownidle unexpectedly allowed a standing block")
            return false
        player._advance_timed_states(18.01 / PortFighter.SOURCE_FRAME_RATE)
        if is_miss_case:
            player.combat_hit.disconnect(_count_ground_pose_combat_hit)
            if (player.state != "attacktofloor"
                    or absf(brick.health - health) > 0.001
                    or player._attack_connected
                    or player.combo_hits != combo_before
                    or _ground_pose_combat_hit_count != 0):
                push_error("attacktofloor entry/contact mismatch for " + case_name)
                return false
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
    if not _check_candidate_visual_blending(player, brick):
        return false
    return true


func _check_candidate_visual_blending(player: PortFighter, brick: PortFighter) -> bool:
    player.reset_fighter(Vector3.ZERO)
    brick.reset_fighter(Vector3(0.25, 1.2, 0.0))
    brick._enter_locomotion_state("facedownidle")
    player._animate_candidate()
    player.candidate_visual_blending_enabled = true

    player._begin_attack_to_floor()
    var attack_blend_seconds: float = (
        float(PortFighter.CANDIDATE_ATTACK_TO_FLOOR_BLENDING_FRAMES)
                / PortFighter.SOURCE_FRAME_RATE
    )
    if (not is_finite(player.candidate_visual_blend_pending_seconds)
            or absf(player.candidate_visual_blend_pending_seconds - attack_blend_seconds) > 0.000001):
        push_error("attacktofloor entry did not queue its source blending duration")
        return false
    player._animate_candidate()
    if (absf(player.candidate_visual_blend_seconds_last - attack_blend_seconds) > 0.000001
            or player.candidate_visual_blend_target_action_last
                    != PortFighter.ATTACK_TO_FLOOR_CLIP):
        push_error("attacktofloor entry did not apply its candidate visual blend")
        return false

    player.state_time = (
        (float(PortFighter.ATTACK_TO_FLOOR_EXIT_START_FRAME) - 0.001)
                / PortFighter.SOURCE_FRAME_RATE
    )
    player._advance_timed_states(0.002)
    if player.state != "idle2" or player.state_time != 0.0:
        push_error("candidate visual blending changed the attacktofloor logic exit")
        return false
    var return_blend_seconds: float = (
        float(PortFighter.CANDIDATE_ATTACK_TO_FLOOR_RETURN_BLENDING_FRAMES)
                / PortFighter.SOURCE_FRAME_RATE
    )
    if (not is_finite(player.candidate_visual_blend_pending_seconds)
            or absf(player.candidate_visual_blend_pending_seconds - return_blend_seconds) > 0.000001):
        push_error("attacktofloor idle2 return did not queue its source blending duration")
        return false
    player._animate_candidate()
    if (absf(player.candidate_visual_blend_seconds_last - return_blend_seconds) > 0.000001
            or player.candidate_visual_blend_source_action_last
                    != PortFighter.ATTACK_TO_FLOOR_CLIP
            or player.candidate_visual_blend_target_action_last != PortFighter.IDLE2_CLIP):
        push_error("attacktofloor idle2 return did not apply its candidate visual blend")
        return false
    player.candidate_visual_blending_enabled = false
    return true


func _check_attack_to_floor_input_resets(player: PortFighter, brick: PortFighter) -> bool:
    brick._enter_locomotion_state("facedownidle")
    player._enter_locomotion_state("idle")
    # c/d cannot alias into a later bcc/bdd chain.
    if player.try_attack_to_floor_press("c") != PortFighter.AttackToFloorInputResult.IGNORED:
        push_error("attacktofloor accepted c as an initial prefix")
        return false
    if player.try_attack_to_floor_press("b") != PortFighter.AttackToFloorInputResult.BUFFERED:
        push_error("attacktofloor did not buffer the valid b prefix")
        return false
    if player.try_attack_to_floor_press("c") != PortFighter.AttackToFloorInputResult.BUFFERED:
        push_error("attacktofloor did not buffer the valid bc prefix")
        return false
    # This is the regression from subsequence matching: b,c,d,c must not match b,c,c.
    if player.try_attack_to_floor_press("d") != PortFighter.AttackToFloorInputResult.IGNORED:
        push_error("attacktofloor did not reject d after the bc prefix")
        return false
    if not player._ground_attack_input_history.is_empty():
        push_error("attacktofloor retained history after a non-prefix input")
        return false
    if player.try_attack_to_floor_press("c") != PortFighter.AttackToFloorInputResult.IGNORED:
        push_error("attacktofloor reused history after a non-prefix input")
        return false
    if player.state != "idle":
        push_error("attacktofloor non-prefix input started a state")
        return false

    player._time = 10.0
    if player.try_attack_to_floor_press("b") != PortFighter.AttackToFloorInputResult.BUFFERED:
        push_error("attacktofloor timeout setup did not buffer b")
        return false
    player._time += PortFighter.GROUND_ATTACK_INPUT_PROTOTYPE_WINDOW_SECONDS + 0.001
    if player.try_attack_to_floor_press("c") != PortFighter.AttackToFloorInputResult.IGNORED:
        push_error("attacktofloor reused a timed-out b prefix")
        return false
    if player.try_attack_to_floor_press("b") != PortFighter.AttackToFloorInputResult.BUFFERED:
        push_error("attacktofloor could not restart after a timeout")
        return false
    if player.try_attack_to_floor_press("c") != PortFighter.AttackToFloorInputResult.BUFFERED:
        push_error("attacktofloor lost the restarted bc prefix")
        return false
    if player.try_attack_to_floor_press("c") != PortFighter.AttackToFloorInputResult.STARTED:
        push_error("attacktofloor rejected the complete sequence after a timeout")
        return false

    player._enter_locomotion_state("idle")
    if player.try_attack_to_floor_press("b") != PortFighter.AttackToFloorInputResult.BUFFERED:
        push_error("attacktofloor state-change setup did not buffer b")
        return false
    # Exercise a state change even if a future caller bypasses the conventional
    # _enter_locomotion_state() history clear.
    player.state = "idle2"
    if player.try_attack_to_floor_press("c") != PortFighter.AttackToFloorInputResult.IGNORED:
        push_error("attacktofloor reused history across an idle/idle2 state change")
        return false

    player._enter_locomotion_state("idle")
    if player.try_attack_to_floor_press("b") != PortFighter.AttackToFloorInputResult.BUFFERED:
        push_error("attacktofloor reset setup did not buffer b")
        return false
    player.reset_fighter(Vector3.ZERO)
    if player.try_attack_to_floor_press("c") != PortFighter.AttackToFloorInputResult.IGNORED:
        push_error("attacktofloor reused history across reset_fighter")
        return false
    return true


func _check_attack_to_floor_repeated_rejection(
        player: PortFighter, brick: PortFighter
) -> bool:
    if not _start_attack_to_floor(player, brick):
        return false
    player._advance_timed_states(
        (17.999 - float(PortFighter.ATTACK_TO_FLOOR_ENTRY_FRAME))
                / PortFighter.SOURCE_FRAME_RATE
    )
    brick._enter_locomotion_state("faceupgetup")
    brick.state_time = 0.41
    var health_before: float = brick.health
    var target_state_before: String = brick.state
    var target_state_time_before: float = brick.state_time
    var target_position_before: Vector3 = brick.global_position
    var combo_before: int = player.combo_hits
    player._attack_connected = false
    _ground_pose_combat_hit_count = 0
    player.combat_hit.connect(_count_ground_pose_combat_hit)
    # Repeatedly evaluate the whole inclusive window. A rejection must remain
    # unconsumed so every later sample can still observe the target contract.
    for _sample: int in range(6):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    player.combat_hit.disconnect(_count_ground_pose_combat_hit)
    if (absf(brick.health - health_before) > 0.001
            or brick.state != target_state_before
            or absf(brick.state_time - target_state_time_before) > 0.001
            or not brick.global_position.is_equal_approx(target_position_before)
            or player._attack_connected
            or player.combo_hits != combo_before
            or _ground_pose_combat_hit_count != 0):
        push_error("attacktofloor consumed or recorded a persistently rejected hit")
        return false
    return true


func _check_attack_to_floor_rejected_then_accepted(
        player: PortFighter, brick: PortFighter
) -> bool:
    if not _start_attack_to_floor(player, brick):
        return false
    player._advance_timed_states(
        (17.999 - float(PortFighter.ATTACK_TO_FLOOR_ENTRY_FRAME))
                / PortFighter.SOURCE_FRAME_RATE
    )
    brick._enter_locomotion_state("faceupgetup")
    var health_before: float = brick.health
    var combo_before: int = player.combo_hits
    player._attack_connected = false
    _ground_pose_combat_hit_count = 0
    player.combat_hit.connect(_count_ground_pose_combat_hit)
    # The first inclusive contact sample is frame 18 and is rejected.
    player._advance_timed_states(0.001 / PortFighter.SOURCE_FRAME_RATE)
    if (absf(brick.health - health_before) > 0.001
            or player._attack_connected
            or player.combo_hits != combo_before
            or _ground_pose_combat_hit_count != 0):
        push_error("attacktofloor recorded the frame-18 rejected contact")
        player.combat_hit.disconnect(_count_ground_pose_combat_hit)
        return false
    # The target becomes hittable at frame 19. The unconnected attack must
    # retry and then close the hit after exactly one accepted contact.
    brick._enter_locomotion_state("facedownidle")
    player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    for _sample: int in range(5):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    player.combat_hit.disconnect(_count_ground_pose_combat_hit)
    if (absf(brick.health - (health_before - PortFighter.ATTACK_TO_FLOOR_DAMAGE)) > 0.001
            or not player._attack_connected
            or player.combo_hits != combo_before + 1
            or _ground_pose_combat_hit_count != 1):
        push_error("attacktofloor did not retry once after rejection within the window")
        return false
    return true


func _check_attack_to_floor_window_boundaries(
        player: PortFighter, brick: PortFighter
) -> bool:
    var false_states: Array[String] = [
        "ko", "facedownko", "faceupidle", "faceupgetup", "faceupattack",
        "impactfaceup", "faceupko",
    ]
    for target_state: String in false_states:
        brick.reset_fighter(Vector3(0.25, 1.2, 0.0))
        brick._enter_locomotion_state(target_state)
        brick.health = 73.25
        brick.state_time = 0.4375
        brick.global_position = Vector3(0.15, 1.2, -0.1)
        var health_before: float = brick.health
        var state_time_before: float = brick.state_time
        var position_before: Vector3 = brick.global_position
        if brick.receive_hit(6.0, false, 4.0, 1.0):
            push_error("receive_hit accepted explicit false state " + target_state)
            return false
        if (absf(brick.health - health_before) > 0.001
                or brick.state != target_state
                or absf(brick.state_time - state_time_before) > 0.001
                or not brick.global_position.is_equal_approx(position_before)):
            push_error("receive_hit mutated rejected state " + target_state)
            return false

    var boundary_cases: Array[Dictionary] = [
        {"frame": 22.999, "accepted": true},
        {"frame": 23.0, "accepted": true},
        {"frame": 23.001, "accepted": false},
    ]
    for boundary_case: Dictionary in boundary_cases:
        if not _start_attack_to_floor(player, brick):
            return false
        var frame: float = float(boundary_case["frame"])
        var accepted: bool = bool(boundary_case["accepted"])
        player.state_time = frame / PortFighter.SOURCE_FRAME_RATE
        var health_before: float = brick.health
        var combo_before: int = player.combo_hits
        player._attack_connected = false
        _ground_pose_combat_hit_count = 0
        player.combat_hit.connect(_count_ground_pose_combat_hit)
        player._advance_timed_states(0.001 / PortFighter.SOURCE_FRAME_RATE)
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        player.combat_hit.disconnect(_count_ground_pose_combat_hit)
        var expected_damage: float = PortFighter.ATTACK_TO_FLOOR_DAMAGE if accepted else 0.0
        var expected_combo: int = combo_before + (1 if accepted else 0)
        var expected_events: int = 1 if accepted else 0
        if (absf(brick.health - (health_before - expected_damage)) > 0.001
                or player._attack_connected != accepted
                or player.combo_hits != expected_combo
                or _ground_pose_combat_hit_count != expected_events):
            push_error("attacktofloor window boundary mismatch at frame %s" % frame)
            return false

    for target_state: String in false_states:
        if not _start_attack_to_floor(player, brick):
            return false
        brick._enter_locomotion_state(target_state)
        brick.health = 73.25
        brick.state_time = 0.4375
        brick.global_position = Vector3(0.15, 1.2, -0.1)
        var health_before: float = brick.health
        var state_time_before: float = brick.state_time
        var position_before: Vector3 = brick.global_position
        var combo_before: int = player.combo_hits
        player._attack_connected = false
        _ground_pose_combat_hit_count = 0
        player.combat_hit.connect(_count_ground_pose_combat_hit)
        player.state_time = 22.999 / PortFighter.SOURCE_FRAME_RATE
        player._advance_timed_states(0.001 / PortFighter.SOURCE_FRAME_RATE)
        player.combat_hit.disconnect(_count_ground_pose_combat_hit)
        if (absf(brick.health - health_before) > 0.001
                or brick.state != target_state
                or absf(brick.state_time - state_time_before) > 0.001
                or not brick.global_position.is_equal_approx(position_before)
                or player._attack_connected
                or player.combo_hits != combo_before
                or _ground_pose_combat_hit_count != 0):
            push_error("attacktofloor recorded explicit false target state " + target_state)
            return false
    return true


func _start_attack_to_floor(player: PortFighter, brick: PortFighter) -> bool:
    player.reset_fighter(Vector3.ZERO)
    brick.reset_fighter(Vector3(0.25, 1.2, 0.0))
    brick._enter_locomotion_state("facedownidle")
    player.facing = 1.0
    if (player.try_attack_to_floor_press("b")
            != PortFighter.AttackToFloorInputResult.BUFFERED
            or player.try_attack_to_floor_press("c")
            != PortFighter.AttackToFloorInputResult.BUFFERED
            or player.try_attack_to_floor_press("c")
            != PortFighter.AttackToFloorInputResult.STARTED):
        push_error("attacktofloor validation setup did not start")
        return false
    player._attack_connected = false
    return true


func _count_ground_pose_combat_hit(
        _attacker: PortFighter,
        _defender: PortFighter,
        _action: String,
        _damage: float,
        _blocked: bool
) -> void:
    _ground_pose_combat_hit_count += 1


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

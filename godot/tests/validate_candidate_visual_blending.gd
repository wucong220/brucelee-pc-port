extends SceneTree


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
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
    if (not player.candidate_loaded or not brick.candidate_loaded
            or player._candidate_skeleton == null or brick._candidate_skeleton == null):
        push_error("Candidate visual-blending inputs failed to load")
        quit(1)
        return
    if player._candidate_skeleton == brick._candidate_skeleton:
        push_error("Bruce and Brick unexpectedly share one candidate skeleton")
        quit(1)
        return
    player.candidate_visual_blending_enabled = true
    brick.candidate_visual_blending_enabled = true

    player.reset_fighter(Vector3.ZERO)
    player._animate_candidate()
    await create_timer(0.05).timeout
    var player_skeleton: Skeleton3D = player._candidate_skeleton
    var player_idle: PackedFloat32Array = _snapshot(player_skeleton)
    player._begin_attack_to_floor()
    var entry_blend_seconds: float = (
        6.0 / PortFighter.SOURCE_FRAME_RATE
    )
    if (absf(player.candidate_visual_blend_pending_seconds - entry_blend_seconds) > 0.000001):
        push_error("attacktofloor entry did not queue the configured visual blend")
        quit(1)
        return
    player._animate_candidate()
    var player_entry_immediate: PackedFloat32Array = _snapshot(player_skeleton)
    await create_timer(0.1).timeout
    var player_entry_mid: PackedFloat32Array = _snapshot(player_skeleton)
    await create_timer(0.15).timeout
    var player_entry_end: PackedFloat32Array = _snapshot(player_skeleton)
    var player_entry_target: PackedFloat32Array = _independent_target_snapshot(
        player._candidate_animation,
        player.candidate_visual_blend_target_action_last,
        player._candidate_animation.current_animation_position,
        player_skeleton,
    )
    var player_entry_immediate_difference: float = _difference(
        player_idle, player_entry_immediate
    )
    var player_entry_mid_difference: float = _difference(player_idle, player_entry_mid)
    var player_entry_end_difference: float = _difference(player_idle, player_entry_end)
    var player_entry_target_difference: float = _difference(
        player_entry_end, player_entry_target
    )
    if (player.state != "attacktofloor"
            or player.candidate_visual_blend_source_action_last != "idle"
            or player.candidate_visual_blend_target_action_last
                    != PortFighter.ATTACK_TO_FLOOR_CLIP
            or absf(player.candidate_visual_blend_seconds_last - entry_blend_seconds) > 0.000001
            or not is_finite(player_entry_immediate_difference)
            or not is_finite(player_entry_mid_difference)
            or not is_finite(player_entry_end_difference)
            or not is_finite(player_entry_target_difference)
            or player_entry_immediate_difference > 0.01
            or player_entry_mid_difference <= 0.001
            or player_entry_end_difference <= player_entry_mid_difference
            or player_entry_target_difference > 0.01):
        push_error("Bruce idle -> attacktofloor did not perform the expected visual blend: "
                + JSON.stringify({
                    "state": player.state,
                    "source": player.candidate_visual_blend_source_action_last,
                    "target": player.candidate_visual_blend_target_action_last,
                    "blend": player.candidate_visual_blend_seconds_last,
                    "immediate": player_entry_immediate_difference,
                    "mid": player_entry_mid_difference,
                    "end": player_entry_end_difference,
                    "target_error": player_entry_target_difference,
                }))
        quit(1)
        return

    player.state_time = 79.0 / PortFighter.SOURCE_FRAME_RATE
    player._candidate_animation.seek(
        79.0 / PortFighter.SOURCE_FRAME_RATE,
        true,
    )
    await create_timer(0.05).timeout
    var player_exit_old: PackedFloat32Array = _snapshot(player_skeleton)
    player._advance_timed_states(2.0 / PortFighter.SOURCE_FRAME_RATE)
    player._animate_candidate()
    var player_exit_immediate: PackedFloat32Array = _snapshot(player_skeleton)
    await create_timer(0.15).timeout
    var player_exit_mid: PackedFloat32Array = _snapshot(player_skeleton)
    await create_timer(0.25).timeout
    var player_exit_end: PackedFloat32Array = _snapshot(player_skeleton)
    var player_exit_target: PackedFloat32Array = _independent_target_snapshot(
        player._candidate_animation,
        player.candidate_visual_blend_target_action_last,
        player._candidate_animation.current_animation_position,
        player_skeleton,
    )
    var player_exit_immediate_difference: float = _difference(
        player_exit_old, player_exit_immediate
    )
    var player_exit_mid_difference: float = _difference(player_exit_old, player_exit_mid)
    var player_exit_end_difference: float = _difference(player_exit_old, player_exit_end)
    var player_exit_target_difference: float = _difference(
        player_exit_end, player_exit_target
    )
    if (player.state != "idle2"
            or player.state_time != 0.0
            or player.candidate_visual_blend_source_action_last
                    != PortFighter.ATTACK_TO_FLOOR_CLIP
            or player.candidate_visual_blend_target_action_last != PortFighter.IDLE2_CLIP
            or absf(player.candidate_visual_blend_seconds_last
                - 10.0 / PortFighter.SOURCE_FRAME_RATE) > 0.000001
            or not is_finite(player_exit_immediate_difference)
            or not is_finite(player_exit_mid_difference)
            or not is_finite(player_exit_end_difference)
            or not is_finite(player_exit_target_difference)
            or player_exit_immediate_difference > 0.01
            or player_exit_mid_difference <= 0.5
            or player_exit_end_difference <= player_exit_mid_difference * 0.5
            or player_exit_target_difference > 0.01):
        push_error("Bruce attacktofloor -> idle2 did not perform the expected visual blend")
        quit(1)
        return

    brick.reset_fighter(Vector3.ZERO)
    brick._enter_locomotion_state("facedownidle")
    brick._animate_candidate()
    await create_timer(0.05).timeout
    var brick_skeleton: Skeleton3D = brick._candidate_skeleton
    var brick_old: PackedFloat32Array = _snapshot(brick_skeleton)
    var reaction: Dictionary = brick.reaction_for_incoming({
        "strength": "normal",
        "height": "low",
        "direction": "frontal",
        "body_part": "lleg",
    }, false)
    brick.receive_hit(6.0, false, 0.0, 1.0, reaction)
    brick._animate_candidate()
    var brick_immediate: PackedFloat32Array = _snapshot(brick_skeleton)
    await create_timer(0.1).timeout
    var brick_mid: PackedFloat32Array = _snapshot(brick_skeleton)
    await create_timer(0.15).timeout
    var brick_end: PackedFloat32Array = _snapshot(brick_skeleton)
    var brick_target: PackedFloat32Array = _independent_target_snapshot(
        brick._candidate_animation,
        brick.candidate_visual_blend_target_action_last,
        brick._candidate_animation.current_animation_position,
        brick_skeleton,
    )
    var brick_immediate_difference: float = _difference(brick_old, brick_immediate)
    var brick_mid_difference: float = _difference(brick_old, brick_mid)
    var brick_end_difference: float = _difference(brick_old, brick_end)
    var brick_target_difference: float = _difference(brick_end, brick_target)
    if (brick.state != "impactfacedown"
            or absf(brick.state_time) > 0.000001
            or absf(brick.health - 94.0) > 0.001
            or absf(brick.source_radius_for_current_animation()
                - PortFighter.BRICK_FACEDOWN_IMPACT_RADIUS) > 0.001
            or brick.candidate_visual_blend_source_action_last
                    != PortFighter.BRICK_FACEDOWN_IDLE_CLIP
            or brick.candidate_visual_blend_target_action_last
                    != PortFighter.FACEDOWN_IMPACT_CLIP
            or absf(brick.candidate_visual_blend_seconds_last
                - 6.0 / PortFighter.SOURCE_FRAME_RATE) > 0.000001
            or not is_finite(brick_immediate_difference)
            or not is_finite(brick_mid_difference)
            or not is_finite(brick_end_difference)
            or not is_finite(brick_target_difference)
            or brick_immediate_difference > 0.01
            or brick_mid_difference <= 0.5
            or brick_end_difference <= 0.5
            or brick_target_difference > 0.01):
        push_error("Brick facedownidle -> impactfacedown did not perform the expected visual blend: "
                + JSON.stringify({
                    "state": brick.state,
                    "state_time": brick.state_time,
                    "health": brick.health,
                    "radius": brick.source_radius_for_current_animation(),
                    "source": brick.candidate_visual_blend_source_action_last,
                    "target": brick.candidate_visual_blend_target_action_last,
                    "blend": brick.candidate_visual_blend_seconds_last,
                    "action": brick.candidate_animation_clip,
                    "immediate": brick_immediate_difference,
                    "mid": brick_mid_difference,
                    "end": brick_end_difference,
                    "target_error": brick_target_difference,
                }))
        quit(1)
        return

    # Reset while a blend is still active, then trigger the same reaction again.
    # This covers stale pending metadata and old animation state surviving a
    # fighter reset in addition to ensuring damage is not accumulated twice.
    brick.reset_fighter(Vector3.ZERO)
    brick._enter_locomotion_state("facedownidle")
    brick._animate_candidate()
    await create_timer(0.05).timeout
    brick.receive_hit(6.0, false, 0.0, 1.0, reaction)
    brick._animate_candidate()
    await create_timer(0.05).timeout
    if brick.state != "impactfacedown":
        push_error("Could not enter impactfacedown before reset lifecycle check")
        quit(1)
        return
    brick.reset_fighter(Vector3.ZERO)
    if (brick.state != "idle"
            or absf(brick.health - PortFighter.MAX_HEALTH) > 0.001
            or brick.candidate_visual_blend_pending_seconds != 0.0
            or brick.candidate_visual_blend_seconds_last != 0.0
            or brick.candidate_visual_blend_source_action_last != ""
            or brick.candidate_visual_blend_target_action_last != ""):
        push_error("reset_fighter left candidate visual-blend state behind")
        quit(1)
        return

    brick._enter_locomotion_state("facedownidle")
    brick._animate_candidate()
    await create_timer(0.05).timeout
    var retry_old: PackedFloat32Array = _snapshot(brick_skeleton)
    brick.receive_hit(6.0, false, 0.0, 1.0, reaction)
    brick._animate_candidate()
    var retry_immediate: PackedFloat32Array = _snapshot(brick_skeleton)
    await create_timer(0.1).timeout
    var retry_mid: PackedFloat32Array = _snapshot(brick_skeleton)
    await create_timer(0.15).timeout
    var retry_end: PackedFloat32Array = _snapshot(brick_skeleton)
    var retry_target: PackedFloat32Array = _independent_target_snapshot(
        brick._candidate_animation,
        brick.candidate_visual_blend_target_action_last,
        brick._candidate_animation.current_animation_position,
        brick_skeleton,
    )
    var retry_immediate_difference: float = _difference(
        retry_old, retry_immediate
    )
    var retry_mid_difference: float = _difference(retry_old, retry_mid)
    var retry_end_difference: float = _difference(retry_old, retry_end)
    var retry_target_difference: float = _difference(retry_end, retry_target)
    if (brick.state != "impactfacedown"
            or absf(brick.health - 94.0) > 0.001
            or brick.candidate_visual_blend_source_action_last
                    != PortFighter.BRICK_FACEDOWN_IDLE_CLIP
            or brick.candidate_visual_blend_target_action_last
                    != PortFighter.FACEDOWN_IMPACT_CLIP
            or absf(brick.candidate_visual_blend_seconds_last
                - 6.0 / PortFighter.SOURCE_FRAME_RATE) > 0.000001
            or not is_finite(retry_immediate_difference)
            or not is_finite(retry_mid_difference)
            or not is_finite(retry_end_difference)
            or not is_finite(retry_target_difference)
            or retry_immediate_difference > 0.01
            or retry_mid_difference <= 0.001
            or retry_end_difference <= retry_mid_difference
            or retry_target_difference > 0.01):
        push_error("Reset during an active blend corrupted the next reaction: "
                + JSON.stringify({
                    "state": brick.state,
                    "health": brick.health,
                    "source": brick.candidate_visual_blend_source_action_last,
                    "target": brick.candidate_visual_blend_target_action_last,
                    "immediate": retry_immediate_difference,
                    "mid": retry_mid_difference,
                    "end": retry_end_difference,
                    "target_error": retry_target_difference,
                }))
        quit(1)
        return

    print("CANDIDATE_VISUAL_BLENDING_VALIDATION=" + JSON.stringify({
        "player": {
            "entry_immediate": player_entry_immediate_difference,
            "entry_mid": player_entry_mid_difference,
            "entry_end": player_entry_end_difference,
            "entry_target_error": player_entry_target_difference,
            "exit_immediate": player_exit_immediate_difference,
            "exit_mid": player_exit_mid_difference,
            "exit_end": player_exit_end_difference,
            "exit_target_error": player_exit_target_difference,
            "blend": player.candidate_visual_blend_seconds_last,
            "action": player.candidate_animation_clip,
        },
        "brick": {
            "immediate": brick_immediate_difference,
            "mid": brick_mid_difference,
            "end": brick_end_difference,
            "target_error": brick_target_difference,
            "blend": brick.candidate_visual_blend_seconds_last,
            "action": brick.candidate_animation_clip,
            "reset_retry": {
                "immediate": retry_immediate_difference,
                "mid": retry_mid_difference,
                "end": retry_end_difference,
                "target_error": retry_target_difference,
                "health": brick.health,
            },
        },
        "scope": "candidate visual interpolation; native runtime unverified",
    }))
    quit(0)


func _snapshot(skeleton: Skeleton3D) -> PackedFloat32Array:
    var result := PackedFloat32Array()
    for bone_index: int in range(skeleton.get_bone_count()):
        var position: Vector3 = skeleton.get_bone_pose_position(bone_index)
        var rotation: Quaternion = skeleton.get_bone_pose_rotation(bone_index)
        var scale: Vector3 = skeleton.get_bone_pose_scale(bone_index)
        result.append_array(PackedFloat32Array([
            position.x, position.y, position.z,
            rotation.x, rotation.y, rotation.z, rotation.w,
            scale.x, scale.y, scale.z,
        ]))
    return result


func _independent_target_snapshot(
        animation: AnimationPlayer,
        clip: String,
        position: float,
        skeleton: Skeleton3D
) -> PackedFloat32Array:
    animation.stop()
    animation.play(clip)
    animation.seek(position, true)
    return _snapshot(skeleton)


func _difference(left: PackedFloat32Array, right: PackedFloat32Array) -> float:
    if left.size() != right.size():
        return INF
    var total: float = 0.0
    for index: int in range(left.size()):
        total += absf(left[index] - right[index])
    return total

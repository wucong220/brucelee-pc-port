extends SceneTree
## Exercise the Thai-set direct link from facedownidle to impactfacedown.

var _combat_hit_count: int = 0
var _combat_hit_blocked: bool = false


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected the 23-clip Bruce GLB and 7-clip Brick GLB")
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
    player.combat_hit.connect(_count_combat_hit)
    if not player.candidate_loaded or not brick.candidate_loaded:
        push_error("Candidate load failed: %s | %s" % [
            player.candidate_load_error, brick.candidate_load_error,
        ])
        quit(1)
        return
    brick.candidate_visual_blending_enabled = true
    if (not _check_candidate_clip(brick)
            or not _check_nonlethal_reaction(player, brick)
            or not _check_frame_boundary(player, brick)
            or not _check_guard_does_not_block(player, brick)
            or not _check_lethal_priority(player, brick)
            or not _check_missing_clip_fails_closed(player, brick)
            or not _check_link_condition_matrix(player, brick)):
        quit(1)
        return
    print("BRICK_FACEDOWN_IMPACT_VALIDATION=" + JSON.stringify({
        "clip": PortFighter.FACEDOWN_IMPACT_CLIP,
        "description": "Thai-set candidate direct link; native frame scheduler unverified",
        "exit_frame": PortFighter.FACEDOWN_IMPACT_EXIT_FRAME,
        "radius": PortFighter.BRICK_FACEDOWN_IMPACT_RADIUS,
        "return_action": "facedownidle",
    }))
    quit(0)


func _check_candidate_clip(brick: PortFighter) -> bool:
    if not brick._candidate_clip_paths.has(PortFighter.FACEDOWN_IMPACT_CLIP):
        push_error("all_impct_facedwn did not pass candidate track checks")
        return false
    var animation: AnimationPlayer = brick.get("_candidate_animation")
    var clip: Animation = animation.get_animation(
        brick._candidate_clip_paths[PortFighter.FACEDOWN_IMPACT_CLIP]
    )
    if (clip == null
            or clip.loop_mode != Animation.LOOP_NONE
            or absf(clip.length - 11.0 / PortFighter.SOURCE_FRAME_RATE) > 0.002):
        push_error("all_impct_facedwn has an unexpected loop or duration")
        return false
    return true


func _check_nonlethal_reaction(player: PortFighter, brick: PortFighter) -> bool:
    if not _start_attack(player, brick):
        return false
    var health_before: float = brick.health
    var position_before: Vector3 = brick.global_position
    var combo_before: int = player.combo_hits
    _combat_hit_count = 0
    _combat_hit_blocked = false
    player._advance_timed_states(
        (18.01 - float(PortFighter.ATTACK_TO_FLOOR_ENTRY_FRAME))
                / PortFighter.SOURCE_FRAME_RATE
    )
    if (brick.state != "impactfacedown"
            or absf(brick.health - (health_before - PortFighter.ATTACK_TO_FLOOR_DAMAGE)) > 0.001
            or not player._attack_connected
            or player.combo_hits != combo_before + 1
            or _combat_hit_count != 1
            or not brick.global_position.is_equal_approx(position_before)):
        push_error("attacktofloor did not enter the direct facedown reaction once")
        return false
    if (brick.last_reaction_source_action != "impactfacedown"
            or brick.last_reaction_animation != PortFighter.FACEDOWN_IMPACT_CLIP
            or not brick.last_reaction_clip_implemented
            or absf(brick.source_radius_for_current_animation()
                - PortFighter.BRICK_FACEDOWN_IMPACT_RADIUS) > 0.001):
        push_error("impactfacedown reaction metadata or Thai radius is wrong")
        return false
    brick._animate_candidate()
    if (brick.current_source_pose() != "laying"
            or not _clip_is(
                brick.candidate_animation_clip,
                brick._candidate_clip_paths[PortFighter.FACEDOWN_IMPACT_CLIP]
            )):
        push_error("impactfacedown did not select the loaded reaction clip: " + JSON.stringify({
            "actual": brick.candidate_animation_clip,
            "expected": brick._candidate_clip_paths[PortFighter.FACEDOWN_IMPACT_CLIP],
            "pose": brick.current_source_pose(),
        }))
        return false
    var expected_blend_seconds: float = (
        float(PortFighter.CANDIDATE_BRICK_FACEDOWN_IMPACT_BLENDING_FRAMES)
                / PortFighter.SOURCE_FRAME_RATE
    )
    if (absf(brick.candidate_visual_blend_seconds_last - expected_blend_seconds) > 0.000001
            or brick.candidate_visual_blend_source_action_last
                    != PortFighter.BRICK_FACEDOWN_IDLE_CLIP
            or brick.candidate_visual_blend_target_action_last
                    != PortFighter.FACEDOWN_IMPACT_CLIP):
        push_error("impactfacedown did not apply its Thai-link candidate visual blend")
        return false
    player._advance_timed_states(5.0 / PortFighter.SOURCE_FRAME_RATE)
    if (absf(brick.health - (health_before - PortFighter.ATTACK_TO_FLOOR_DAMAGE)) > 0.001
            or _combat_hit_count != 1):
        push_error("impactfacedown allowed a duplicate hit")
        return false
    return true


func _check_frame_boundary(player: PortFighter, brick: PortFighter) -> bool:
    if not _start_attack(player, brick):
        return false
    player._advance_timed_states(
        (18.01 - float(PortFighter.ATTACK_TO_FLOOR_ENTRY_FRAME))
                / PortFighter.SOURCE_FRAME_RATE
    )
    if brick.state != "impactfacedown":
        push_error("Could not enter impactfacedown for frame-boundary check")
        return false
    brick._advance_timed_states(10.999 / PortFighter.SOURCE_FRAME_RATE)
    if brick.state != "impactfacedown":
        push_error("impactfacedown exited before source frame 11")
        return false
    brick._advance_timed_states(0.002 / PortFighter.SOURCE_FRAME_RATE)
    if (brick.state != "facedownidle"
            or absf(brick.source_radius_for_current_animation() - 75.0) > 0.001):
        push_error("impactfacedown did not return to the Brick facedown idle at frame 11")
        return false
    return true


func _check_guard_does_not_block(player: PortFighter, brick: PortFighter) -> bool:
    if not _start_attack(player, brick):
        return false
    brick.guard_held = true
    _combat_hit_count = 0
    _combat_hit_blocked = false
    player._advance_timed_states(
        (18.01 - float(PortFighter.ATTACK_TO_FLOOR_ENTRY_FRAME))
                / PortFighter.SOURCE_FRAME_RATE
    )
    if (brick.state != "impactfacedown"
            or _combat_hit_count != 1
            or _combat_hit_blocked):
        brick.guard_held = false
        push_error("A held guard key changed the lying low-hit reaction")
        return false
    brick.guard_held = false
    return true


func _check_lethal_priority(player: PortFighter, brick: PortFighter) -> bool:
    if not _start_attack(player, brick):
        return false
    brick.health = PortFighter.ATTACK_TO_FLOOR_DAMAGE
    var position_before: Vector3 = brick.global_position
    _combat_hit_count = 0
    _combat_hit_blocked = false
    player._advance_timed_states(
        (18.01 - float(PortFighter.ATTACK_TO_FLOOR_ENTRY_FRAME))
                / PortFighter.SOURCE_FRAME_RATE
    )
    if (brick.state != "facedownko"
            or brick.health != 0.0
            or absf(brick.source_radius_for_current_animation()
                - PortFighter.FACEDOWN_KO_RADIUS) > 0.001
            or not brick.global_position.is_equal_approx(position_before)
            or _combat_hit_count != 1):
        push_error("healthzero did not take priority over impactfacedown")
        return false
    return true


func _check_missing_clip_fails_closed(player: PortFighter, brick: PortFighter) -> bool:
    if not _start_attack(player, brick):
        return false
    var saved: String = brick._candidate_clip_paths[PortFighter.FACEDOWN_IMPACT_CLIP]
    brick._candidate_clip_paths.erase(PortFighter.FACEDOWN_IMPACT_CLIP)
    var health_before: float = brick.health
    var combo_before: int = player.combo_hits
    _combat_hit_count = 0
    _combat_hit_blocked = false
    player._advance_timed_states(
        (18.01 - float(PortFighter.ATTACK_TO_FLOOR_ENTRY_FRAME))
                / PortFighter.SOURCE_FRAME_RATE
    )
    var failed_closed: bool = (
        brick.state == "facedownidle"
        and absf(brick.health - health_before) <= 0.001
        and not player._attack_connected
        and player.combo_hits == combo_before
        and _combat_hit_count == 0
    )
    brick._candidate_clip_paths[PortFighter.FACEDOWN_IMPACT_CLIP] = saved
    if not failed_closed:
        push_error("Missing all_impct_facedwn did not fail closed")
        return false
    return true


func _check_link_condition_matrix(player: PortFighter, brick: PortFighter) -> bool:
    player.reset_fighter(Vector3.ZERO)
    brick.reset_fighter(Vector3(0.25, 1.2, 0.0))
    brick._enter_locomotion_state("facedownidle")
    var low_reaction: Dictionary = brick.reaction_for_incoming({
        "strength": "hard",
        "height": "low",
        "direction": "fromright",
        "body_part": "rarm",
    }, false)
    var reaction: Dictionary = brick.reaction_for_incoming({
        "strength": "normal",
        "height": "medium",
        "direction": "frontal",
    }, false)
    if (String(low_reaction.get("source_action", "")) != "impactfacedown"
            or String(reaction.get("source_action", "")) == "impactfacedown"):
        push_error("impactfacedown did not use only the impact and low-height conditions")
        return false
    return true


func _start_attack(player: PortFighter, brick: PortFighter) -> bool:
    player.reset_fighter(Vector3.ZERO)
    brick.reset_fighter(Vector3(0.25, 1.2, 0.0))
    brick._enter_locomotion_state("facedownidle")
    brick._animate_candidate()
    player.facing = 1.0
    if (player.try_attack_to_floor_press("b")
            != PortFighter.AttackToFloorInputResult.BUFFERED
            or player.try_attack_to_floor_press("c")
            != PortFighter.AttackToFloorInputResult.BUFFERED
            or player.try_attack_to_floor_press("c")
            != PortFighter.AttackToFloorInputResult.STARTED):
        push_error("Could not start the attacktofloor test sequence")
        return false
    player._attack_connected = false
    return true


func _clip_is(actual: String, expected_path: String) -> bool:
    return actual == expected_path or actual.ends_with("/" + expected_path)


func _count_combat_hit(
        _attacker: PortFighter,
        _defender: PortFighter,
        _action: String,
        _damage: float,
        _blocked: bool
) -> void:
    _combat_hit_count += 1
    _combat_hit_blocked = _blocked

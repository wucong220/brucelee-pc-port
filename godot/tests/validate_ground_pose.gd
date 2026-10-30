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
    if not _check_brick(brick) or not _check_bruce(player):
        quit(1)
        return
    print("GROUND_POSE_VALIDATION=" + JSON.stringify({
        "brick_clip": PortFighter.BRICK_FACEDOWN_IDLE_CLIP,
        "brick_pose": "laying",
        "bruce_clip": PortFighter.ATTACK_TO_FLOOR_CLIP,
        "bruce_pose": "stand",
        "scope": "test-injected states; gameplay trigger is not implemented",
    }))
    quit(0)


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

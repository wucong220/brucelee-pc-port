extends SceneTree
## Requires the external real candidate GLB; no synthetic clips are installed.

func _initialize() -> void:
    call_deferred("_run")

func fail(message: String) -> void:
    push_error("REAL_FRONTLOW: " + message)
    quit(1)

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 1 or not FileAccess.file_exists(args[0]):
        fail("Expected an existing external Bruce GLB")
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", "")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var fighter: PortFighter = scene.get("player")
    fighter.set_physics_process(false)
    if not fighter.candidate_loaded:
        fail("candidate load: " + fighter.candidate_load_error)
        return
    var clips: Dictionary = fighter.get("_candidate_clip_paths")
    var key := "all_impct_hard_frnt_low"
    var anim: AnimationPlayer = fighter.get("_candidate_animation")
    if not clips.has(key) or anim == null or not anim.has_animation(String(clips[key])):
        fail("real frontlow clip is not registered in AnimationPlayer")
        return
    var clip: Animation = anim.get_animation(String(clips[key]))
    if clip == null or clip.get_track_count() == 0:
        fail("registered clip has no tracks")
        return
    if absf(clip.length - 23.0 / 30.0) > 0.035:
        fail("unexpected frontlow duration: " + str(clip.length))
        return
    var skeleton: Skeleton3D = fighter.get("_candidate_skeleton")
    if skeleton == null:
        fail("candidate skeleton missing")
        return
    var valid_bone_track := false
    for track in range(clip.get_track_count()):
        var path: NodePath = clip.track_get_path(track)
        if (clip.track_get_type(track) != Animation.TYPE_ROTATION_3D
                or path.get_subname_count() != 1
                or skeleton.find_bone(String(path.get_subname(0))) < 0
                or not clip.track_is_enabled(track)
                or clip.track_get_key_count(track) < 2):
            continue
        var first: Variant = clip.track_get_key_value(track, 0)
        var last: Variant = clip.track_get_key_value(track, clip.track_get_key_count(track) - 1)
        if (first is Quaternion and last is Quaternion
                and first.is_finite() and last.is_finite()
                and absf(first.length() - 1.0) < 0.01
                and absf(last.length() - 1.0) < 0.01
                and clip.track_get_key_time(track, clip.track_get_key_count(track) - 1) > 0.0):
            valid_bone_track = true
            break
    if not valid_bone_track:
        fail("no enabled skeleton rotation track with valid keyframes")
        return
    anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    var reaction: Dictionary = fighter.reaction_for_incoming(
        {"strength": "hard", "height": "low", "direction": "frontal"}, false)
    if String(reaction.get("animation", "")) != key or int(reaction.get("exit_start_frame", -1)) != 20:
        fail("frontlow reaction dispatch mismatch")
        return
    fighter.reset_fighter(Vector3.ZERO)
    if not fighter.receive_hit(5.0, false, 0.0, 1.0, reaction):
        fail("nonlethal hit rejected")
        return
    fighter._animate_candidate()
    if fighter.state != "hitstun" or not anim.is_playing() or anim.current_animation != String(clips[key]):
        fail("nonlethal hit did not play real clip")
        return
    anim.advance(0.2)
    if anim.current_animation_position < 0.19:
        fail("real clip did not advance")
        return
    if not fighter.receive_hit(5.0, false, 0.0, 1.0, reaction):
        fail("repeated nonlethal hit rejected")
        return
    fighter._animate_candidate()
    if anim.current_animation_position > 0.001:
        fail("repeated nonlethal hit did not restart real clip; position=" + str(anim.current_animation_position))
        return
    anim.advance(19.0 / 30.0)
    fighter._advance_timed_states(19.0 / 30.0)
    if not anim.is_playing() or absf(anim.current_animation_position - 19.0 / 30.0) > 0.002:
        fail("nonlethal clip ended early or is out of sync before frame 20")
        return
    if fighter.state != "hitstun":
        fail("nonlethal transitioned before frame 20")
        return
    anim.advance(1.0 / 30.0)
    if not anim.is_playing() or absf(anim.current_animation_position - 20.0 / 30.0) > 0.002:
        fail("nonlethal clip ended early at frame 20")
        return
    fighter._advance_timed_states(1.0 / 30.0 + 0.00001)
    if fighter.state != "facedownidle":
        fail("nonlethal frame 20 expected facedownidle, got " + fighter.state)
        return
    fighter._animate_candidate()
    if not anim.is_playing() or anim.current_animation != String(clips["all_idle_face_down"]):
        fail("nonlethal return animation not playing")
        return
    for height in ["low", "medium"]:
        fighter.reset_fighter(Vector3.ZERO)
        fighter.health = 5.0
        var lethal: Dictionary = fighter.reaction_for_incoming(
            {"strength": "hard", "height": height, "direction": "frontal"}, false)
        if not fighter.receive_hit(5.0, false, 0.0, 1.0, lethal):
            fail("lethal " + height + " hit rejected")
            return
        fighter._animate_candidate()
        if fighter.state != "stunimpact" or not anim.is_playing() or anim.current_animation != String(clips[key]):
            fail("lethal " + height + " did not play real clip")
            return
        anim.advance(0.2)
        if anim.current_animation_position < 0.19:
            fail("lethal clip did not advance")
            return
        if fighter.receive_hit(1.0, false, 0.0, 1.0, lethal):
            fail("stunimpact unexpectedly accepted repeated hit")
            return
        # 0.2 seconds were already advanced above; advance state by the same
        # amount, then advance both clocks to frame 20.
        fighter._advance_timed_states(0.2)
        anim.advance(14.0 / 30.0)
        fighter._advance_timed_states(14.0 / 30.0)
        if not anim.is_playing() or absf(anim.current_animation_position - 20.0 / 30.0) > 0.002:
            fail("lethal clip ended early or is out of sync before frame 21")
            return
        if fighter.state != "stunimpact":
            fail("lethal transitioned before frame 21")
            return
        anim.advance(1.0 / 30.0)
        if not anim.is_playing() or absf(anim.current_animation_position - 21.0 / 30.0) > 0.002:
            fail("lethal clip ended early at frame 21")
            return
        fighter._advance_timed_states(1.0 / 30.0 + 0.00001)
        if fighter.state != "facedownko":
            fail("lethal frame 21 expected facedownko, got " + fighter.state)
            return
        fighter._animate_candidate()
        if not anim.is_playing() or anim.current_animation != String(clips["all_idle_face_down"]):
            fail("lethal KO animation not playing")
            return
    print("REAL_FRONTLOW_PASS=" + JSON.stringify({"clip": key, "tracks": clip.get_track_count(), "duration": clip.length, "nonlethal_exit": 20, "lethal_exit": 21, "lethal_heights": ["low", "medium"], "repeat": "nonlethal restarts; lethal stunimpact rejects"}))
    scene.queue_free()
    await process_frame
    quit(0)

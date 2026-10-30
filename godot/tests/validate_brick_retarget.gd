extends SceneTree
## Inspect an experimental local cross-skeleton GLB; does not verify original behavior.


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected one experimental Brick GLB")
        quit(1)
        return
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    if document.append_from_file(args[0], state) != OK:
        push_error("Could not read experimental GLB")
        quit(1)
        return
    var instance := document.generate_scene(state)
    if instance == null:
        push_error("Could not instantiate experimental GLB")
        quit(1)
        return
    root.add_child(instance)
    var players := instance.find_children("*", "AnimationPlayer", true, false)
    var skeletons := instance.find_children("*", "Skeleton3D", true, false)
    if players.size() != 1 or skeletons.size() != 1:
        push_error("Expected one animation player and skeleton")
        quit(1)
        return
    var player: AnimationPlayer = players[0]
    var skeleton: Skeleton3D = skeletons[0]
    var clip_name := "all_impct_hard_frnt_low"
    if not player.has_animation(clip_name) or skeleton.get_bone_count() != 69:
        push_error("Missing candidate animation or expected skeleton")
        quit(1)
        return
    var eye := skeleton.find_bone("r eyeball")
    if eye < 0:
        push_error("Target right eye bone is missing")
        quit(1)
        return
    var clip: Animation = player.get_animation(clip_name)
    var eye_tracks := 0
    for i in clip.get_track_count():
        var path := String(clip.track_get_path(i))
        if path.ends_with(":r eyeball") and clip.track_get_type(i) == Animation.TYPE_ROTATION_3D:
            eye_tracks += 1
    if eye_tracks != 1:
        push_error("Expected one right-eye rotation track; found %d" % eye_tracks)
        quit(1)
        return
    player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    player.play(clip_name)
    var poses: Array[Quaternion] = []
    var initial_bones: Array[Transform3D] = []
    var body_moved := false
    for frame in [0, 10, 20, 22]:
        player.seek(clip.length * float(frame) / 22.0, true)
        var q := skeleton.get_bone_pose_rotation(eye)
        if not q.is_finite() or absf(q.length() - 1.0) > 0.001:
            push_error("Invalid sampled right-eye quaternion")
            quit(1)
            return
        poses.append(q)
        for bone in skeleton.get_bone_count():
            var pose := skeleton.get_bone_global_pose(bone)
            if not pose.is_finite():
                push_error("Non-finite sampled skeleton pose")
                quit(1)
                return
            if frame == 0:
                initial_bones.append(pose)
            elif bone != eye and not pose.is_equal_approx(initial_bones[bone]):
                body_moved = true
    if not body_moved:
        push_error("No body bone changed across sampled frames")
        quit(1)
        return
    print("BRICK_RETARGET_CANDIDATE=" + JSON.stringify({
        "bones": skeleton.get_bone_count(), "clip": clip_name,
        "duration": clip.length, "tracks": clip.get_track_count(),
        "right_eye_tracks": eye_tracks, "sample_count": poses.size(),
        "body_moved": body_moved,
        "native_behavior": "unverified",
    }))
    quit(0)

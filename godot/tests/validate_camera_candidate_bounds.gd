extends SceneTree
## Sample local, CPU-skinned candidate bounds. This is not an original-game comparison.

const CandidateBounds = preload("res://scripts/candidate_bounds.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() not in [2, 3] or (args.size() == 3 and args[2] != "--reverse"):
        push_error("Expected Bruce and Brick candidate GLB paths and optional --reverse")
        quit(1)
        return
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", "")
    OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", "")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    scene.set_process(false)
    scene.set_physics_process(false)
    var bruce: PortFighter = scene.get("player")
    var brick: PortFighter = scene.get("computer")
    bruce.set_physics_process(false)
    brick.set_physics_process(false)
    if not bruce.candidate_loaded or not brick.candidate_loaded:
        push_error("Candidate models did not load")
        quit(1)
        return
    var camera: Camera3D = scene.get("fight_camera")
    var samples: int = 0
    var checked_key_frames: Dictionary = {}
    for fighter: PortFighter in [bruce, brick]:
        fighter.reset_fighter(Vector3(0.0, 1.2, 0.0))
        fighter.rotation.y = PI if args.size() == 3 else 0.0
        fighter._animate_candidate()
        var anim: AnimationPlayer = fighter._candidate_animation
        anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
        var clips: Array = (
            ["m01_idle_01", "m01_kick_low_01", "m01_attack_to_floor",
                "all_idle_face_down", "all_getup_facedwn_attack",
                "all_idle_face_up", "all_getup_faceup_attack"]
            if fighter == bruce
            else ["m03_idle_01", "m03_kck_low_01",
                "all_idle_face_down_forbigguy", "all_impct_facedwn"]
        )
        for clip: String in clips:
            if not anim.has_animation(clip):
                push_error("Missing candidate animation: " + clip)
                quit(1)
                return
            var duration: float = anim.get_animation(clip).length
            var sample_times: Array[float] = [0.0, duration * 0.5, duration * 0.99]
            var key_frames: Array = []
            if clip == "m01_attack_to_floor":
                key_frames = [9, 17, 18, 19, 22, 23, 24, 79, 80, 81]
            elif clip == "all_impct_facedwn" and fighter == brick:
                key_frames = range(0, 12)
            for frame: int in key_frames:
                var seconds: float = float(frame) / PortFighter.SOURCE_FRAME_RATE
                if seconds <= duration:
                    sample_times.append(seconds)
                    if not checked_key_frames.has(clip):
                        checked_key_frames[clip] = []
                    checked_key_frames[clip].append(frame)
            for seconds: float in sample_times:
                anim.play(clip)
                anim.seek(seconds, true)
                anim.advance(0.0)
                await process_frame
                await process_frame
                var result: Dictionary = CandidateBounds.scene_bounds(fighter._candidate_root)
                if not String(result.get("error", "")).is_empty() or not result.has("bounds"):
                    push_error("Unable to measure %s: %s" % [clip, result])
                    quit(1)
                    return
                var bounds: AABB = result["bounds"]
                for viewport: Vector2i in [Vector2i(1280, 720), Vector2i(800, 600), Vector2i(480, 900)]:
                    root.size = viewport
                    root.content_scale_size = viewport
                    await process_frame
                    var size: Vector2 = root.get_visible_rect().size
                    for pair: Array in [
                        [Vector3(-0.25, 1.2, 0.0), Vector3(0.25, 1.2, 0.0)],
                        [Vector3(-6.8, 1.2, -3.0), Vector3(6.8, 1.2, 3.0)],
                        [Vector3(6.8, 1.2, -3.0), Vector3(-6.8, 1.2, 3.0)],
                    ]:
                        bruce.global_position = pair[0]
                        brick.global_position = pair[1]
                        scene._update_fight_camera()
                        var target_position: Vector3 = pair[0] if fighter == bruce else pair[1]
                        for x: float in [bounds.position.x, bounds.end.x]:
                            for y: float in [bounds.position.y, bounds.end.y]:
                                for z: float in [bounds.position.z, bounds.end.z]:
                                    var point: Vector3 = Vector3(x, y, z) + Vector3(
                                        target_position.x, 0.0, target_position.z
                                    )
                                    var screen: Vector2 = camera.unproject_position(point)
                                    if (camera.is_position_behind(point)
                                            or screen.x < size.x * 0.05 or screen.x > size.x * 0.95
                                            or screen.y < size.y * 0.10 or screen.y > size.y * 0.90):
                                        push_error("Candidate outside viewport: %s %.3fs %s -> %s in %s"
                                                % [clip, seconds, point, screen, size])
                                        quit(1)
                                        return
                fighter.global_position = Vector3(0.0, 1.2, 0.0)
                samples += 1
    print("CAMERA_CANDIDATE_BOUNDS=passed samples=%d reverse=%s key_frames=%s" % [
        samples, args.size() == 3, JSON.stringify(checked_key_frames),
    ])
    quit(0)

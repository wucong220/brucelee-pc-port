extends SceneTree
## Verify two candidate GLBs use independent clips and animation players.


const CandidateBounds = preload("res://scripts/candidate_bounds.gd")
const EXPECTED_PLAYER_ANIMATED_HEIGHT: float = 1.6010163
const EXPECTED_OPPONENT_ANIMATED_HEIGHT: float = 1.7350644
const EXPECTED_PLAYER_PRETRANSFORMED_HEIGHT: float = 1.6116960
const EXPECTED_OPPONENT_PRETRANSFORMED_HEIGHT: float = 1.7350644
const ANIMATED_HEIGHT_TOLERANCE: float = 0.01


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() not in [2, 3, 4]:
        push_error("Expected player GLB, opponent GLB and optional texture roots")
        quit(1)
        return
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", "")
    if args.size() == 3:
        OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", args[2])
    elif args.size() == 4:
        OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", args[2])
        OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", args[3])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var opponent: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    opponent.set_physics_process(false)
    if not player.candidate_loaded:
        push_error("Player candidate failed: " + player.candidate_load_error)
        quit(1)
        return
    if not opponent.candidate_loaded:
        push_error("Opponent candidate failed: " + opponent.candidate_load_error)
        quit(1)
        return
    if player.candidate_animation_clip != "m01_idle_01":
        push_error("Player did not select Bruce idle")
        quit(1)
        return
    if opponent.candidate_animation_clip != "m03_idle_01":
        push_error("Opponent did not select Brick idle")
        quit(1)
        return
    if (player.get("_candidate_animation") == opponent.get("_candidate_animation")
            or player.get("_candidate_root") == opponent.get("_candidate_root")):
        push_error("Fighters share candidate animation state")
        quit(1)
        return
    var player_animation: AnimationPlayer = player.get("_candidate_animation")
    var opponent_animation: AnimationPlayer = opponent.get("_candidate_animation")
    var player_skeleton: Skeleton3D = player.get("_candidate_skeleton")
    var opponent_skeleton: Skeleton3D = opponent.get("_candidate_skeleton")
    if (player_skeleton == null or opponent_skeleton == null
            or player_skeleton == opponent_skeleton):
        push_error("Fighters do not have independent candidate skeletons")
        quit(1)
        return
    player_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    opponent_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    var player_idle_path: String = player.get("_candidate_clip_paths")["idle"]
    var opponent_idle_path: String = opponent.get("_candidate_clip_paths")["idle"]
    player_animation.play(player_idle_path)
    opponent_animation.play(opponent_idle_path)
    player_animation.seek(0.0, true)
    opponent_animation.seek(0.0, true)
    var player_pose_before: Array[float] = _snapshot_skeleton_pose(player_skeleton)
    var opponent_pose_before: Array[float] = _snapshot_skeleton_pose(opponent_skeleton)
    var advance_seconds: float = minf(
        player_animation.get_animation(player_idle_path).length * 0.5,
        1.0
    )
    player_animation.advance(advance_seconds)
    var player_pose_after: Array[float] = _snapshot_skeleton_pose(player_skeleton)
    var opponent_pose_after: Array[float] = _snapshot_skeleton_pose(opponent_skeleton)
    if _skeleton_pose_delta(player_pose_before, player_pose_after) < 0.000001:
        push_error("Player animation did not change the player skeleton")
        quit(1)
        return
    if _skeleton_pose_delta(opponent_pose_before, opponent_pose_after) > 0.000001:
        push_error("Advancing the player animation changed the opponent skeleton")
        quit(1)
        return
    for fighter: PortFighter in [player, opponent]:
        if absf(fighter.candidate_visual_height - 1.8) > 0.01:
            push_error("Fighter candidate height is not normalized: " + fighter.character_name)
            quit(1)
            return
        for visual: MeshInstance3D in fighter.get("_placeholder_visuals"):
            if visual.visible:
                push_error("Placeholder visual remained visible: " + fighter.character_name)
                quit(1)
                return
    if (String(player.candidate_clips["punch"]) != "m01_pnch_low_01"
            or String(opponent.candidate_clips["punch"]) != "m03_pnch_low_01"):
        push_error("Per-fighter clip mappings are incorrect")
        quit(1)
        return
    player.reset_fighter(Vector3(-2.0, 1.2, 0.0))
    opponent.reset_fighter(Vector3(2.0, 1.2, 0.0))
    var candidate_world_heights: Dictionary = {}
    for fighter: PortFighter in [player, opponent]:
        var fighter_root: Node3D = fighter.get("_candidate_root")
        var fighter_bounds_result: Dictionary = CandidateBounds.scene_bounds(fighter_root)
        if not fighter_bounds_result["error"].is_empty():
            push_error("Candidate bounds failed: " + fighter_bounds_result["error"])
            quit(1)
            return
        var fighter_bounds: AABB = fighter_bounds_result["bounds"]
        candidate_world_heights[fighter.character_name] = fighter_bounds.size.y
        var expected_height: float = (
            EXPECTED_PLAYER_ANIMATED_HEIGHT if fighter.is_player
            else EXPECTED_OPPONENT_ANIMATED_HEIGHT
        )
        if absf(fighter_bounds.size.y - expected_height) > ANIMATED_HEIGHT_TOLERANCE:
            push_error(
                "Candidate animated height is %.6f, expected %.6f: %s"
                % [fighter_bounds.size.y, expected_height, fighter.character_name]
            )
            quit(1)
            return
        if absf(fighter_bounds.position.y) > 0.02:
            push_error("Candidate is not grounded: " + fighter.character_name)
            quit(1)
            return
    var opponent_punch_animation: Animation = opponent_animation.get_animation(
        opponent.get("_candidate_clip_paths")["punch"]
    )
    if player.candidate_scale_attack_timing:
        push_error("Player fighting-set timing was unexpectedly clip-scaled")
        quit(1)
        return
    if opponent.candidate_scale_attack_timing:
        push_error("Brick low-attack timing is still scaled from Bruce clips")
        quit(1)
        return
    var opponent_punch_config: Dictionary = opponent.ATTACKS["punch"]
    if (String(opponent_punch_config["source_action"]) != "lowpunch3"
            or String(opponent_punch_config["animation"]) != "m03_pnch_low_01"
            or int(opponent_punch_config["animation_frame_count"]) != 38
            or absf(float(opponent_punch_config["startup"]) * PortFighter.SOURCE_FRAME_RATE - 8.0) > 0.001
            or absf(float(opponent_punch_config["active"]) * PortFighter.SOURCE_FRAME_RATE - 4.0) > 0.001
            or absf(float(opponent_punch_config["recovery"]) * PortFighter.SOURCE_FRAME_RATE - 26.0) > 0.001
            or absf(float(opponent_punch_config["damage"]) - 7.0) > 0.001):
        push_error("Brick punch does not use verified thai.set lowpunch3 phases")
        quit(1)
        return
    var opponent_punch_state_duration: float = (
        float(opponent_punch_config["startup"])
        + float(opponent_punch_config["active"])
        + float(opponent_punch_config["recovery"])
    )
    if absf(opponent_punch_state_duration - opponent_punch_animation.length) > 0.01:
        push_error("Brick punch state timing does not match its candidate clip")
        quit(1)
        return
    if opponent.supports_attack("heavy"):
        push_error("Brick candidate exposes an unmapped heavy attack")
        quit(1)
        return
    opponent.move_axis = Vector2(1.0, 0.0)
    opponent._animate_candidate()
    if opponent.candidate_animation_clip != "m03_movefwd":
        push_error("Opponent movement did not select the Brick locomotion clip")
        quit(1)
        return
    var move_clip: Animation = opponent_animation.get_animation(
        opponent.get("_candidate_clip_paths")["move"]
    )
    var move_position_tracks_enabled: int = _enabled_character_position_track_count(
        opponent_animation, opponent.get("_candidate_character"), move_clip
    )
    if move_position_tracks_enabled != 0:
        push_error("Brick locomotion retained an unverified character position track")
        quit(1)
        return
    opponent.move_axis = Vector2.ZERO
    opponent._animate_candidate()
    if opponent.candidate_animation_clip != "m03_idle_01":
        push_error("Opponent did not return to Brick idle after movement")
        quit(1)
        return
    if not player.request_attack("punch") or not opponent.request_attack("punch"):
        push_error("Could not start candidate punch previews")
        quit(1)
        return
    player._animate_candidate()
    opponent._animate_candidate()
    if player.candidate_animation_clip != "m01_pnch_low_01":
        push_error("Player punch selected the wrong clip")
        quit(1)
        return
    if opponent.candidate_animation_clip != "m03_pnch_low_01":
        push_error("Opponent punch selected the wrong clip")
        quit(1)
        return
    var opponent_punch_clip: String = opponent.candidate_animation_clip
    var opponent_kick_animation: Animation = opponent_animation.get_animation(
        opponent.get("_candidate_clip_paths")["kick"]
    )
    var opponent_kick_config: Dictionary = opponent.ATTACKS["kick"]
    if (String(opponent_kick_config["source_action"]) != "lowkick3"
            or String(opponent_kick_config["animation"]) != "m03_kck_low_01"
            or int(opponent_kick_config["animation_frame_count"]) != 41
            or absf(float(opponent_kick_config["startup"]) * PortFighter.SOURCE_FRAME_RATE - 9.0) > 0.001
            or absf(float(opponent_kick_config["active"]) * PortFighter.SOURCE_FRAME_RATE - 3.0) > 0.001
            or absf(float(opponent_kick_config["recovery"]) * PortFighter.SOURCE_FRAME_RATE - 29.0) > 0.001
            or absf(float(opponent_kick_config["damage"]) - 7.0) > 0.001):
        push_error("Brick kick does not use verified thai.set lowkick3 phases")
        quit(1)
        return
    var opponent_kick_state_duration: float = (
        float(opponent_kick_config["startup"])
        + float(opponent_kick_config["active"])
        + float(opponent_kick_config["recovery"])
    )
    if absf(opponent_kick_state_duration - opponent_kick_animation.length) > 0.01:
        push_error("Brick kick state timing does not match its candidate clip")
        quit(1)
        return
    if args.size() >= 3 and not player.candidate_textures_loaded:
        push_error("Player textures failed: " + player.candidate_texture_error)
        quit(1)
        return
    if args.size() == 2 and opponent.candidate_textures_loaded:
        push_error("Opponent textures were loaded without an opponent texture root")
        quit(1)
        return
    if args.size() < 4 and not opponent.candidate_texture_reason.contains(
            "not configured"
    ):
        push_error("Missing opponent texture root did not produce an explicit reason")
        quit(1)
        return
    if args.size() == 4 and not opponent.candidate_textures_loaded:
        push_error("Opponent textures failed: " + opponent.candidate_texture_error)
        quit(1)
        return

    var missing_path: String = OS.get_temp_dir().path_join(
        "brucelee-missing-opponent-%d.glb" % Time.get_ticks_usec()
    )
    var missing_error: String = await _check_candidate_fallback(
        missing_path, PortFighter.BRICK_CLIPS, "does not exist"
    )
    if not missing_error.is_empty():
        push_error(missing_error)
        quit(1)
        return
    var invalid_mapping_error: String = await _check_candidate_fallback(
        args[1], {"idle": "m03_idle_01"}, "lacks punch"
    )
    if not invalid_mapping_error.is_empty():
        push_error(invalid_mapping_error)
        quit(1)
        return
    var missing_clip_error: String = await _check_candidate_fallback(
        args[1],
        {
            "idle": "missing_idle",
            "punch": "missing_punch",
            "kick": "missing_kick",
        },
        "missing candidate clips"
    )
    if not missing_clip_error.is_empty():
        push_error(missing_clip_error)
        quit(1)
        return
    var body_texture_error: String = await _check_body_only_textures(args[1])
    if not body_texture_error.is_empty():
        push_error(body_texture_error)
        quit(1)
        return
    var grounding_error: String = await _check_pretransformed_grounding(
        args[0], true, PortFighter.CANDIDATE_CLIPS, "body_hair",
        EXPECTED_PLAYER_PRETRANSFORMED_HEIGHT
    )
    if not grounding_error.is_empty():
        push_error(grounding_error)
        quit(1)
        return
    grounding_error = await _check_pretransformed_grounding(
        args[1], false, PortFighter.BRICK_CLIPS, "body",
        EXPECTED_OPPONENT_PRETRANSFORMED_HEIGHT
    )
    if not grounding_error.is_empty():
        push_error(grounding_error)
        quit(1)
        return
    var bounds_fallback_error: String = await _check_player_bounds_fallback()
    if not bounds_fallback_error.is_empty():
        push_error(bounds_fallback_error)
        quit(1)
        return

    opponent.health = 5.0
    opponent.receive_hit(5.0, false, 0.0, 1.0)
    opponent._animate_candidate()
    if opponent.state != "ko":
        push_error("Opponent did not enter KO with candidate visuals")
        quit(1)
        return
    opponent.reset_fighter(Vector3(2.0, 1.2, 0.0))
    if (opponent.state != "idle"
            or opponent.candidate_animation_clip != "m03_idle_01"):
        push_error("Opponent did not return to Brick idle after reset")
        quit(1)
        return
    print("DUAL_FIGHTER_CANDIDATE_VALIDATION=" + JSON.stringify({
        "player_idle": "m01_idle_01",
        "opponent_idle": "m03_idle_01",
        "player_punch": player.candidate_animation_clip,
        "opponent_punch": opponent_punch_clip,
        "player_textures_loaded": player.candidate_textures_loaded,
        "opponent_textures_loaded": opponent.candidate_textures_loaded,
        "missing_asset_fallback": true,
        "invalid_clip_mapping_fallback": true,
        "missing_clip_fallback": true,
        "body_only_textures": true,
        "player_pretransformed_grounding": true,
        "opponent_pretransformed_grounding": true,
        "player_bounds_fallback": true,
        "skeleton_isolation": true,
        "move_root_tracks_suppressed": true,
        "punch_and_kick_timing_aligned": true,
        "ko_reset_idle": opponent.candidate_animation_clip,
        "candidate_world_heights": candidate_world_heights,
    }))
    quit(0)


func _check_candidate_fallback(
        path: String, clips: Dictionary, expected_error: String
) -> String:
    var fighter: PortFighter = PortFighter.new()
    fighter.configure("Fallback test", false, Color.CYAN)
    fighter.configure_candidate_asset(path, "", clips)
    root.add_child(fighter)
    await process_frame
    if fighter.candidate_loaded:
        fighter.queue_free()
        await process_frame
        return "Invalid opponent asset unexpectedly loaded"
    if (absf(fighter.candidate_visual_height) > 0.000001
            or fighter.candidate_animation_clip != ""
            or fighter.candidate_textures_loaded):
        fighter.queue_free()
        await process_frame
        return "Failed candidate retained derived visual state"
    if not fighter.candidate_load_error.contains(expected_error):
        var actual: String = fighter.candidate_load_error
        fighter.queue_free()
        await process_frame
        return "Unexpected fallback error: " + actual
    for visual: MeshInstance3D in fighter.get("_placeholder_visuals"):
        if not visual.visible:
            fighter.queue_free()
            await process_frame
            return "Fallback placeholder visual was hidden"
    fighter.queue_free()
    await process_frame
    return ""


func _check_body_only_textures(brick_path: String) -> String:
    var texture_root: String = OS.get_temp_dir().path_join(
        "brucelee-brick-body-textures-%d" % Time.get_ticks_usec()
    )
    if DirAccess.make_dir_recursive_absolute(texture_root) != OK:
        return "Could not create synthetic Brick texture directory"
    var texture_paths: Array[String] = []
    for map_name: String in ["diffuse", "normal", "material"]:
        var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
        if map_name == "normal":
            image.fill(Color(0.5, 0.5, 1.0))
        else:
            image.fill(Color(0.8, 0.25, 0.1, 1.0))
        var texture_path: String = texture_root.path_join(
            "body_%s.png" % map_name
        )
        if image.save_png(texture_path) != OK:
            return "Could not write synthetic Brick texture"
        texture_paths.append(texture_path)

    var fighter: PortFighter = PortFighter.new()
    fighter.configure("Brick texture test", false, Color.CYAN)
    fighter.configure_candidate_asset(
        brick_path, texture_root, PortFighter.BRICK_CLIPS, "body"
    )
    fighter.position = Vector3(0.0, 1.2, 0.0)
    root.add_child(fighter)
    await process_frame
    var failure: String = ""
    if not fighter.candidate_loaded:
        failure = "Brick body-only candidate failed: " + fighter.candidate_load_error
    elif not fighter.candidate_textures_loaded:
        failure = "Brick body-only textures failed: " + fighter.candidate_texture_error
    elif fighter.candidate_material_profile != "body":
        failure = "Brick candidate did not retain its body material profile"
    else:
        var material_found: bool = false
        for node: Node in fighter.get("_candidate_root").find_children(
                "*", "MeshInstance3D", true, false
        ):
            var mesh_instance: MeshInstance3D = node as MeshInstance3D
            if (String(mesh_instance.name).to_lower().contains("body")
                    and mesh_instance.material_override is ShaderMaterial):
                material_found = true
                break
        if not material_found:
            failure = "Brick body-only material was not applied"

    fighter.queue_free()
    await process_frame
    for texture_path: String in texture_paths:
        DirAccess.remove_absolute(texture_path)
    DirAccess.remove_absolute(texture_root)
    return failure


func _check_pretransformed_grounding(
        candidate_path: String, is_player: bool, clips: Dictionary, profile: String,
        expected_height: float
) -> String:
    var fighter: PortFighter = PortFighter.new()
    fighter.configure("Grounding test", is_player, Color.CYAN)
    fighter.configure_candidate_asset(
        candidate_path, "", clips, profile
    )
    fighter.position = Vector3(4.0, 3.0, -2.0)
    root.add_child(fighter)
    await process_frame
    var failure: String = ""
    if not fighter.candidate_loaded:
        failure = "Pretransformed candidate failed to load: " + fighter.candidate_load_error
    else:
        fighter._animate_candidate()
        var measured: Dictionary = CandidateBounds.scene_bounds(
            fighter.get("_candidate_root")
        )
        if not measured["error"].is_empty():
            failure = "Pretransformed candidate bounds failed: " + measured["error"]
        else:
            var bounds: AABB = measured["bounds"]
            if absf(bounds.position.y) > 0.02:
                failure = "Pretransformed candidate floor is %.6f" % bounds.position.y
            elif absf(bounds.size.y - expected_height) > ANIMATED_HEIGHT_TOLERANCE:
                failure = (
                    "Pretransformed candidate height is %.6f, expected %.6f"
                    % [bounds.size.y, expected_height]
                )
    fighter.queue_free()
    await process_frame
    return failure


func _check_player_bounds_fallback() -> String:
    var fighter: PortFighter = PortFighter.new()
    fighter.configure("Fallback scale test", true, Color.CYAN)
    root.add_child(fighter)
    await process_frame
    var empty_candidate_root: Node3D = Node3D.new()
    empty_candidate_root.name = "UnmeasurableCandidateFixture"
    fighter.add_child(empty_candidate_root)
    fighter.set("_candidate_root", empty_candidate_root)
    var fitted: bool = fighter.call("_fit_candidate_visual")
    var failure: String = ""
    if not fitted:
        failure = "Player fixed-scale fallback rejected an unmeasurable candidate"
    elif absf(fighter.candidate_visual_height - 1.8) > 0.01:
        failure = "Player fixed-scale fallback did not produce a 1.8-world-height candidate"
    fighter.queue_free()
    await process_frame
    return failure


func _enabled_character_position_track_count(
        animation_player: AnimationPlayer, character: Node3D, clip: Animation
) -> int:
    if character == null:
        return -1
    var animation_root: Node = animation_player.get_node_or_null(
        animation_player.root_node
    )
    if animation_root == null:
        return -1
    var enabled: int = 0
    for track: int in clip.get_track_count():
        if clip.track_get_type(track) != Animation.TYPE_POSITION_3D:
            continue
        var target: Node = animation_root.get_node_or_null(clip.track_get_path(track))
        if target == character and clip.track_is_enabled(track):
            enabled += 1
    return enabled


func _snapshot_skeleton_pose(skeleton: Skeleton3D) -> Array[float]:
    var snapshot: Array[float] = []
    for bone: int in skeleton.get_bone_count():
        var position: Vector3 = skeleton.get_bone_pose_position(bone)
        var rotation: Quaternion = skeleton.get_bone_pose_rotation(bone)
        snapshot.append(position.x)
        snapshot.append(position.y)
        snapshot.append(position.z)
        snapshot.append(rotation.x)
        snapshot.append(rotation.y)
        snapshot.append(rotation.z)
        snapshot.append(rotation.w)
    return snapshot


func _skeleton_pose_delta(before: Array[float], after: Array[float]) -> float:
    if before.size() != after.size():
        return INF
    var largest: float = 0.0
    for index: int in before.size():
        largest = maxf(largest, absf(before[index] - after[index]))
    return largest

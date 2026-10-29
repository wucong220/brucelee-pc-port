extends SceneTree
## Play verified Bruce post-hit return states from the 15-clip candidate.


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected the Bruce return-state GLB and the Brick GLB")
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
    var opponent: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    opponent.set_physics_process(false)
    if not player.candidate_loaded or not opponent.candidate_loaded:
        push_error("Return-state candidates failed to load: %s | %s" % [
            player.candidate_load_error, opponent.candidate_load_error,
        ])
        quit(1)
        return
    if not _static_flags_stay_false(player):
        quit(1)
        return
    if not _check_idle2(player, opponent):
        quit(1)
        return
    if not _check_facedown(player, opponent):
        quit(1)
        return
    if not _check_normal_hard_still_returns_idle(player, opponent):
        quit(1)
        return
    if not _loader_rejects_clip_implemented_true(player):
        quit(1)
        return
    if not _check_missing_hard_clip_returns_idle(player, opponent):
        quit(1)
        return
    print("RETURN_STATE_CANDIDATE_VALIDATION=" + JSON.stringify({
        "idle2": "m01_idle_02",
        "facedownidle": "all_idle_face_down",
        "facedowngetup": "all_getup_facedwn",
        "move_axis": "prototype",
    }))
    quit(0)


func _static_flags_stay_false(player: PortFighter) -> bool:
    var animation: AnimationPlayer = player.get("_candidate_animation")
    var expected: Array[String] = [
        "m01_idle_01", "m01_pnch_low_01", "m01_kick_low_01",
        "all_block_high", "all_block_low", "all_block_mid",
        "all_impct_light_frnt_high", "all_impct_light_frnt_low",
        "all_impct_light_frnt_mid", "all_impct_crotch",
        "all_impct_hard_rht_low", "all_block_high_hard",
        "m01_idle_02", "all_idle_face_down", "all_getup_facedwn",
    ]
    if animation == null or animation.get_animation_list().size() != expected.size():
        push_error("Return-state GLB does not expose exactly 15 clips")
        return false
    for clip_name: String in expected:
        if _find_clip(animation, clip_name).is_empty():
            push_error("Return-state GLB is missing " + clip_name)
            return false
    for listed_name: StringName in animation.get_animation_list():
        var listed: String = String(listed_name)
        if listed.contains("facedownattack") or listed.contains("facedownko"):
            push_error("Return-state GLB includes an out-of-scope clip: " + listed)
            return false
    for group: String in ["hit", "block"]:
        for entry_value: Variant in player.EXACT_REACTIONS[group]:
            var entry: Dictionary = entry_value
            if bool(entry["clip_implemented"]):
                push_error("Exact reaction JSON clip_implemented must stay false")
                return false
    if (bool(player.EXACT_REACTIONS["block"][0]["return_implemented"])
            or bool(player.EXACT_REACTIONS["hit"][1]["return_implemented"])
            or String(player.EXACT_REACTIONS["block"][0]["return_action"]) != "idle2"
            or String(player.EXACT_REACTIONS["hit"][1]["return_action"]) != "facedownidle"):
        push_error("Static return flags changed")
        return false
    return true


func _check_idle2(player: PortFighter, opponent: PortFighter) -> bool:
    if not _contact(player, opponent, "punch", true):
        return false
    if not _reaction_is(player, "blockstun", "highblockhard", "all_block_high_hard", 11, 25.0):
        push_error("Hard block did not start highblockhard")
        return false
    player._advance_timed_states(player.state_time + 0.001)
    player._animate_candidate()
    if not _return_is(player, "idle2", "m01_idle_02", 40.0, true):
        push_error("highblockhard did not enter looping idle2")
        return false
    player._advance_timed_states(float(PortFighter.IDLE2_DURATION_FRAMES) / PortFighter.SOURCE_FRAME_RATE + 0.05)
    player._animate_candidate()
    if (player.state != "idle2"
            or not _clip_is(player.candidate_animation_clip, "m01_idle_02")
            or player.state_time >= float(PortFighter.IDLE2_DURATION_FRAMES) / PortFighter.SOURCE_FRAME_RATE):
        push_error("idle2 did not keep looping")
        return false
    player.guard_held = false
    var start_x: float = player.position.x
    player.move_axis = Vector2(1.0, 0.0)
    player._physics_process(0.2)
    if (player.state != "idle2"
            or player.position.x <= start_x
            or player.velocity.x < 3.0
            or not _clip_is(player.candidate_animation_clip, "m01_idle_02")):
        push_error("Existing movement did not work from idle2: " + JSON.stringify({
            "state": player.state,
            "delta_x": player.position.x - start_x,
            "clip": player.candidate_animation_clip,
            "guard": player.guard_held,
            "velocity_x": player.velocity.x,
        }))
        return false
    player.move_axis = Vector2.ZERO
    player.guard_held = false
    if not player.request_attack("punch"):
        push_error("Existing punch did not work from idle2")
        return false
    player._animate_candidate()
    if not _clip_is(player.candidate_animation_clip, "m01_pnch_low_01"):
        push_error("idle2 punch selected the wrong clip")
        return false
    if not _contact(player, opponent, "punch", true):
        return false
    player._advance_timed_states(player.state_time + 0.001)
    player._animate_candidate()
    player.guard_held = false
    if not player.request_attack("kick"):
        push_error("Existing kick did not work from idle2")
        return false
    player._animate_candidate()
    if not _clip_is(player.candidate_animation_clip, "m01_kick_low_01"):
        push_error("idle2 kick selected the wrong clip")
        return false
    return _character_tracks_disabled(player, "m01_idle_02")


func _check_facedown(player: PortFighter, opponent: PortFighter) -> bool:
    if not _enter_facedown(player, opponent):
        return false
    var origin_x: float = player.position.x
    player.move_axis = Vector2(-1.0, 0.0)
    player._physics_process(9.0 / PortFighter.SOURCE_FRAME_RATE - 0.001)
    if (player.state != "facedownidle"
            or absf(player.velocity.x) > 0.001
            or player.state_time * PortFighter.SOURCE_FRAME_RATE >= float(PortFighter.FACEDOWN_GETUP_WINDOW_START)
            or not _clip_is(player.candidate_animation_clip, "all_idle_face_down")):
        push_error("facedownidle moved or got up before frame 10: " + JSON.stringify({
            "state": player.state,
            "delta_x": player.position.x - origin_x,
            "clip": player.candidate_animation_clip,
            "state_time": player.state_time,
            "velocity_x": player.velocity.x,
        }))
        return false
    player.move_axis = Vector2(0.0, 1.0)
    player.state_time = 20.0 / PortFighter.SOURCE_FRAME_RATE
    player._advance_timed_states(0.0)
    player._animate_candidate()
    if player.state != "facedownidle":
        push_error("Vertical input started facedowngetup")
        return false
    if player.request_attack("punch") or player.request_attack("kick"):
        push_error("facedownidle accepted a normal attack")
        return false
    player._animate_candidate()
    if (not _clip_is(player.candidate_animation_clip, "all_idle_face_down")
            or _clip_is(player.candidate_animation_clip, "m01_pnch_low_01")
            or _clip_is(player.candidate_animation_clip, "m01_kick_low_01")):
        push_error("facedownidle played a normal punch or kick")
        return false
    player._advance_timed_states(
        float(PortFighter.FACEDOWN_IDLE_DURATION_FRAMES) / PortFighter.SOURCE_FRAME_RATE
    )
    player._animate_candidate()
    if (player.state != "facedownidle"
            or not _clip_is(player.candidate_animation_clip, "all_idle_face_down")):
        push_error("facedownidle did not keep looping without horizontal input")
        return false
    if not _getup_from_frame(player, opponent, 10.0, -1.0):
        return false
    if not _getup_exits_at_frame_16(player):
        return false
    if not _getup_from_frame(player, opponent, 10.0, 1.0):
        return false
    if not _getup_from_frame(player, opponent, 45.0, 1.0):
        return false
    if not _enter_facedown(player, opponent):
        return false
    player.move_axis = Vector2.ZERO
    player.state_time = 45.0 / PortFighter.SOURCE_FRAME_RATE
    player._advance_timed_states(0.0)
    if player.state != "facedownidle" or player.state_time > 0.001:
        push_error("facedownidle did not loop at frame 45 without input")
        return false
    return (
        _character_tracks_disabled(player, "all_idle_face_down")
        and _character_tracks_disabled(player, "all_getup_facedwn")
    )


func _check_normal_hard_still_returns_idle(player: PortFighter, opponent: PortFighter) -> bool:
    if not _contact(player, opponent, "punch", false):
        return false
    if not _reaction_is(player, "hitstun", "impacthardfrontmid", "all_impct_crotch", 27, 40.0):
        push_error("Hard frontal punch did not stay on its verified reaction")
        return false
    player._advance_timed_states(player.state_time + 0.001)
    player._animate_candidate()
    if (player.state != "idle"
            or not _clip_is(player.candidate_animation_clip, "m01_idle_01")
            or _clip_is(player.candidate_animation_clip, "m01_idle_02")
            or _clip_is(player.candidate_animation_clip, "all_idle_face_down")):
        push_error("impacthardfrontmid did not return to normal idle")
        return false
    return true


func _getup_from_frame(player: PortFighter, opponent: PortFighter, frame: float, axis_x: float) -> bool:
    if not _enter_facedown(player, opponent):
        return false
    player.state_time = frame / PortFighter.SOURCE_FRAME_RATE
    player.move_axis = Vector2(axis_x, 0.0)
    player._advance_timed_states(0.0)
    player._animate_candidate()
    if not _return_is(player, "facedowngetup", "all_getup_facedwn", 25.0, false):
        push_error("Horizontal input did not start facedowngetup at frame " + str(frame))
        return false
    var started: float = player.state_time
    player._advance_timed_states(5.0 / PortFighter.SOURCE_FRAME_RATE)
    player._animate_candidate()
    if (player.state != "facedowngetup"
            or player.state_time + 0.0001 < started + 4.0 / PortFighter.SOURCE_FRAME_RATE):
        push_error("facedowngetup restarted while the move axis stayed held")
        return false
    return true


func _getup_exits_at_frame_16(player: PortFighter) -> bool:
    var remaining: float = float(PortFighter.FACEDOWN_GETUP_EXIT_FRAME) / PortFighter.SOURCE_FRAME_RATE - player.state_time
    player._advance_timed_states(maxf(remaining - 0.001, 0.0))
    player._animate_candidate()
    if player.state != "facedowngetup" or not _clip_is(player.candidate_animation_clip, "all_getup_facedwn"):
        push_error("facedowngetup ended before frame 16")
        return false
    player._advance_timed_states(0.002)
    player._animate_candidate()
    if (player.state != "idle"
            or not _clip_is(player.candidate_animation_clip, "m01_idle_01")
            or absf(player.source_radius_for_current_animation() - 25.0) > 0.001
            or _clip_is(player.candidate_animation_clip, "all_getup_facedwn")
            or _clip_is(player.candidate_animation_clip, "all_getup_facedwn_attack")):
        push_error("facedowngetup did not return to normal idle at frame 16")
        return false
    return true


func _enter_facedown(player: PortFighter, opponent: PortFighter) -> bool:
    if not _contact(player, opponent, "kick", false):
        return false
    if not _reaction_is(player, "hitstun", "impacthardrightlow", "all_impct_hard_rht_low", 23, 70.0):
        push_error("Hard low kick did not start impacthardrightlow")
        return false
    player._advance_timed_states(player.state_time + 0.001)
    player._animate_candidate()
    player.move_axis = Vector2.ZERO
    if not _return_is(player, "facedownidle", "all_idle_face_down", 75.0, true):
        push_error("impacthardrightlow did not enter looping facedownidle")
        return false
    return true


func _check_missing_hard_clip_returns_idle(player: PortFighter, opponent: PortFighter) -> bool:
    var paths: Dictionary = player._candidate_clip_paths
    var idle2_returns: Array[String] = ["m01_idle_02"]
    if not _drop_hard_clip_keep_returns(paths, "all_block_high_hard", idle2_returns):
        return false
    if not _contact(player, opponent, "punch", true):
        return false
    if not _stun_without_hard_clip(player, "blockstun", "highblockhard", "all_block_high_hard", 11):
        push_error("highblockhard did not run after all_block_high_hard was removed")
        return false
    player._advance_timed_states(player.state_time + 0.001)
    player._animate_candidate()
    if not _normal_idle_not(player, "idle2", "m01_idle_02"):
        push_error("highblockhard entered idle2 without all_block_high_hard")
        return false
    var facedown_returns: Array[String] = ["all_idle_face_down", "all_getup_facedwn"]
    if not _drop_hard_clip_keep_returns(paths, "all_impct_hard_rht_low", facedown_returns):
        return false
    if not _contact(player, opponent, "kick", false):
        return false
    if not _stun_without_hard_clip(player, "hitstun", "impacthardrightlow", "all_impct_hard_rht_low", 23):
        push_error("impacthardrightlow did not run after all_impct_hard_rht_low was removed")
        return false
    player._advance_timed_states(player.state_time + 0.001)
    player._animate_candidate()
    if not _normal_idle_not(player, "facedownidle", "all_idle_face_down"):
        push_error("impacthardrightlow entered facedownidle without all_impct_hard_rht_low")
        return false
    return true


func _drop_hard_clip_keep_returns(paths: Dictionary, hard_clip: String, return_clips: Array[String]) -> bool:
    if not paths.has(hard_clip):
        push_error("Hard reaction clip was not registered before removal: " + hard_clip)
        return false
    for return_clip: String in return_clips:
        if not paths.has(return_clip):
            push_error("Return clip missing before removal: " + return_clip)
            return false
    paths.erase(hard_clip)
    if paths.has(hard_clip):
        push_error("Hard reaction clip stayed registered: " + hard_clip)
        return false
    for return_clip: String in return_clips:
        if not paths.has(return_clip):
            push_error("Return clip was removed with the hard reaction: " + return_clip)
            return false
    return true


func _stun_without_hard_clip(player: PortFighter, expected_state: String, action: String, animation_name: String, exit_frame: int) -> bool:
    return (
        player.state == expected_state
        and player.last_reaction_source_action == action
        and player.last_reaction_animation == animation_name
        and player.last_reaction_exit_frame == exit_frame
        and not player.last_reaction_clip_implemented
        and not player._candidate_clip_paths.has(animation_name)
    )


func _normal_idle_not(player: PortFighter, rejected_state: String, rejected_clip: String) -> bool:
    return (
        player.state == "idle"
        and player.state != rejected_state
        and _clip_is(player.candidate_animation_clip, "m01_idle_01")
        and not _clip_is(player.candidate_animation_clip, rejected_clip)
        and absf(player.source_radius_for_current_animation() - 25.0) <= 0.001
        and not bool(player.EXACT_REACTIONS["block"][0]["return_implemented"])
        and not bool(player.EXACT_REACTIONS["hit"][1]["return_implemented"])
        and not bool(player.EXACT_REACTIONS["block"][0]["clip_implemented"])
        and not bool(player.EXACT_REACTIONS["hit"][1]["clip_implemented"])
    )


func _loader_rejects_clip_implemented_true(player: PortFighter) -> bool:
    var configured: Dictionary = player.EXACT_REACTIONS.duplicate(true)
    var block_entries: Array = configured["block"].duplicate(true)
    var block_entry: Dictionary = (block_entries[0] as Dictionary).duplicate(true)
    block_entry["clip_implemented"] = true
    block_entries[0] = block_entry
    configured["block"] = block_entries
    player.attack_config_error = ""
    var parsed: Dictionary = player._parse_exact_reactions(configured)
    if not parsed.is_empty() or not String(player.attack_config_error).contains("clip"):
        push_error("Loader accepted clip_implemented true")
        return false
    if bool(player.EXACT_REACTIONS["block"][0]["clip_implemented"]):
        push_error("Rejected clip flag was written back")
        return false
    return true


func _contact(player: PortFighter, opponent: PortFighter, kind: String, blocked: bool) -> bool:
    player.reset_fighter(Vector3(0.6, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.0, 1.2, 0.0))
    player.guard_held = blocked
    player.move_axis = Vector2.ZERO
    if not opponent.request_attack(kind):
        push_error("Could not start Brick " + kind)
        return false
    opponent._advance_timed_states(float(opponent.ATTACKS[kind]["startup"]))
    opponent._try_attack_contact()
    player._animate_candidate()
    return true


func _reaction_is(player: PortFighter, expected_state: String, action: String, animation_name: String, exit_frame: int, radius: float) -> bool:
    return (
        player.state == expected_state
        and player.last_reaction_source_action == action
        and player.last_reaction_animation == animation_name
        and player.last_reaction_exit_frame == exit_frame
        and player.last_reaction_clip_implemented
        and _clip_is(player.candidate_animation_clip, animation_name)
        and absf(player.source_radius_for_current_animation() - radius) <= 0.001
    )


func _return_is(player: PortFighter, expected_state: String, animation_name: String, radius: float, looping: bool) -> bool:
    var animation: AnimationPlayer = player.get("_candidate_animation")
    var clip_path: String = _find_clip(animation, animation_name)
    var clip: Animation = animation.get_animation(clip_path) if not clip_path.is_empty() else null
    var loop_ok: bool = clip != null and (
        (looping and clip.loop_mode == Animation.LOOP_LINEAR)
        or (not looping and clip.loop_mode == Animation.LOOP_NONE)
    )
    return (
        player.state == expected_state
        and _clip_is(player.candidate_animation_clip, animation_name)
        and animation != null
        and _clip_is(String(animation.current_animation), animation_name)
        and animation.is_playing()
        and loop_ok
        and absf(player.source_radius_for_current_animation() - radius) <= 0.001
        and not bool(player.EXACT_REACTIONS["block"][0]["return_implemented"])
        and not bool(player.EXACT_REACTIONS["hit"][1]["return_implemented"])
        and not bool(player.EXACT_REACTIONS["block"][0]["clip_implemented"])
        and not bool(player.EXACT_REACTIONS["hit"][1]["clip_implemented"])
    )


func _character_tracks_disabled(player: PortFighter, animation_name: String) -> bool:
    var animation: AnimationPlayer = player.get("_candidate_animation")
    var clip_path: String = _find_clip(animation, animation_name)
    if clip_path.is_empty() or not player._prepare_candidate_reaction(animation.get_animation(clip_path)):
        push_error("Return clip failed the candidate track check: " + animation_name)
        return false
    var clip: Animation = animation.get_animation(clip_path)
    var animation_root: Node = animation.get_node_or_null(animation.root_node)
    var found: bool = false
    for track: int in clip.get_track_count():
        var kind: int = clip.track_get_type(track)
        if kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
            push_error("Return clip has a non-transform track: " + animation_name)
            return false
        var target: Node = animation_root.get_node_or_null(clip.track_get_path(track))
        if target == null or String(target.name) != "character":
            continue
        found = true
        if clip.track_is_enabled(track):
            push_error("Character transform track stayed enabled: " + animation_name)
            return false
    if not found and animation_name == "m01_idle_02":
        push_error("idle2 did not contain a character transform track to disable")
        return false
    return true


func _find_clip(animation: AnimationPlayer, expected: String) -> String:
    if animation == null:
        return ""
    for clip: StringName in animation.get_animation_list():
        var name: String = String(clip)
        if name == expected or name.ends_with("/" + expected):
            return name
    return ""


func _clip_is(actual: String, expected: String) -> bool:
    return actual == expected or actual.ends_with("/" + expected)

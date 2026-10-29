extends SceneTree
## Validate the candidate faceupidle horizontal-input -> faceupgetup -> idle chain.


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected the Bruce face-up GLB and the Brick GLB")
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
        push_error("Face-up getup candidates failed to load: %s | %s" % [
            player.candidate_load_error, opponent.candidate_load_error,
        ])
        quit(1)
        return
    if not _check_clip(player):
        quit(1)
        return
    if not _check_entry_windows(player, opponent):
        quit(1)
        return
    if not _check_missing_clip_keeps_looping(player, opponent):
        quit(1)
        return
    if not _check_getup_and_exit(player, opponent):
        quit(1)
        return
    if not _check_unverified_exits_stay_closed(player, opponent):
        quit(1)
        return
    print("FACEUP_GETUP_VALIDATION=" + JSON.stringify({
        "clip": PortFighter.FACEUP_GETUP_CLIP,
        "duration_frames": PortFighter.FACEUP_GETUP_DURATION_FRAMES,
        "entry_window": [
            PortFighter.FACEUP_GETUP_WINDOW_START,
            PortFighter.FACEUP_GETUP_WINDOW_END,
        ],
        "exit_frame_candidate": PortFighter.FACEUP_GETUP_EXIT_FRAME,
        "source_idle_link_window": [20, 24],
        "input_mapping": "move_axis.x as candidate left/right",
        "unverified_exits": "closed",
    }))
    quit(0)


func _check_clip(player: PortFighter) -> bool:
    if not player._candidate_clip_paths.has(PortFighter.FACEUP_GETUP_CLIP):
        push_error("all_getup_faceup did not pass candidate track validation")
        return false
    var animation: AnimationPlayer = player.get("_candidate_animation")
    var clip_path: String = String(
        player._candidate_clip_paths[PortFighter.FACEUP_GETUP_CLIP]
    )
    var clip: Animation = animation.get_animation(clip_path)
    var expected_seconds: float = (
        float(PortFighter.FACEUP_GETUP_DURATION_FRAMES)
        / PortFighter.SOURCE_FRAME_RATE
    )
    if absf(clip.length - expected_seconds) > 0.002:
        push_error("all_getup_faceup duration is not 24 source frames")
        return false
    if clip.loop_mode != Animation.LOOP_NONE:
        push_error("all_getup_faceup must not loop")
        return false
    if absf(
        float(PortFighter.RETURN_ANIMATION_RADII[PortFighter.FACEUP_GETUP_CLIP])
        - 40.0
    ) > 0.001:
        push_error("all_getup_faceup radius is not 40")
        return false
    return _character_tracks_disabled(player, PortFighter.FACEUP_GETUP_CLIP)


func _check_entry_windows(
        player: PortFighter,
        opponent: PortFighter,
) -> bool:
    if not _entry_is(player, opponent, 9.999, -1.0, false):
        push_error("Horizontal input started faceupgetup before frame 10")
        return false
    if not _entry_is(player, opponent, 10.0, -1.0, true):
        push_error("Left input did not start faceupgetup at frame 10")
        return false
    if not _entry_is(player, opponent, 10.0, 1.0, true):
        push_error("Right input did not start faceupgetup at frame 10")
        return false
    if not _entry_is(player, opponent, 45.0, 1.0, true):
        push_error("Horizontal input did not start faceupgetup at frame 45")
        return false
    if not _entry_is(player, opponent, 20.0, 0.0, false):
        push_error("Zero horizontal input started faceupgetup")
        return false
    _prepare_faceup_idle(player, opponent, 20.0)
    player.move_axis = Vector2(0.0, 1.0)
    player._advance_timed_states(0.0)
    player._animate_candidate()
    if not _faceup_idle_is(player, 20.0):
        push_error("Vertical input did not preserve faceupidle and its source frame")
        return false
    if player._faceup_getup_requested(46.0 / PortFighter.SOURCE_FRAME_RATE,
            46.0 / PortFighter.SOURCE_FRAME_RATE):
        push_error("Direct frame 46 request was accepted outside the source window")
        return false
    return true


func _check_missing_clip_keeps_looping(
        player: PortFighter,
        opponent: PortFighter,
) -> bool:
    _prepare_faceup_idle(player, opponent, 20.0)
    player.move_axis = Vector2(1.0, 0.0)
    var saved: String = String(
        player._candidate_clip_paths[PortFighter.FACEUP_GETUP_CLIP]
    )
    player._candidate_clip_paths.erase(PortFighter.FACEUP_GETUP_CLIP)
    player._advance_timed_states(0.0)
    player._animate_candidate()
    var stayed: bool = (
        player.state == "faceupidle"
        and _clip_is(
            player.candidate_animation_clip,
            PortFighter.FACEUP_IDLE_CLIP,
        )
    )
    player._candidate_clip_paths[PortFighter.FACEUP_GETUP_CLIP] = saved
    if not stayed:
        push_error("Missing all_getup_faceup did not keep faceupidle looping")
        return false
    player.move_axis = Vector2.ZERO
    player.state_time = 45.0 / PortFighter.SOURCE_FRAME_RATE
    player._advance_timed_states(0.0)
    player._animate_candidate()
    return (
        player.state == "faceupidle"
        and player.state_time <= 0.001
        and _clip_is(player.candidate_animation_clip, PortFighter.FACEUP_IDLE_CLIP)
    )


func _check_getup_and_exit(
        player: PortFighter,
        opponent: PortFighter,
) -> bool:
    if not _prepare_faceup_getup(player, opponent, 10.0):
        return false
    if (absf(player.state_time) > 0.001
            or not _return_is(
                player,
                "faceupgetup",
                PortFighter.FACEUP_GETUP_CLIP,
                40.0,
                false,
            )):
        push_error("faceupgetup did not begin at source frame 0")
        return false
    player.state_time = 19.999 / PortFighter.SOURCE_FRAME_RATE
    player._advance_timed_states(0.0)
    player._animate_candidate()
    if player.state != "faceupgetup":
        push_error("faceupgetup exited before source frame 20")
        return false
    player.state_time = 20.0 / PortFighter.SOURCE_FRAME_RATE
    player._advance_timed_states(0.0)
    player._animate_candidate()
    if (player.state != "idle"
            or absf(player.state_time) > 0.001
            or not _clip_is(player.candidate_animation_clip, "m01_idle_01")):
        push_error("faceupgetup did not enter idle at candidate frame 20")
        return false
    return true


func _check_unverified_exits_stay_closed(
        player: PortFighter,
        opponent: PortFighter,
) -> bool:
    if not _prepare_faceup_getup(player, opponent, 10.0):
        return false
    if player.record_virtual_press("a"):
        push_error("faceupgetup accepted a virtual press sequence")
        return false
    if player.request_attack("punch") or player.request_attack("kick"):
        push_error("faceupgetup accepted a standing attack")
        return false
    for health: float in [PortFighter.MAX_HEALTH, 1.0]:
        if not _prepare_faceup_getup(player, opponent, 10.0):
            return false
        player.health = health
        var health_before: float = player.health
        var hits_before: int = opponent.combo_hits
        opponent._attack_connected = false
        if not opponent.request_attack("kick"):
            push_error("Could not start Brick kick against faceupgetup")
            return false
        opponent.state = "active"
        opponent.state_time = float(opponent.ATTACKS["kick"]["active"])
        opponent._try_attack_contact()
        if (player.state != "faceupgetup"
                or absf(player.health - health_before) > 0.001
                or opponent.combo_hits != hits_before
                or opponent._attack_connected):
            push_error("An unverified attack changed faceupgetup")
            return false
    var health_before_direct: float = player.health
    player.receive_hit(100.0, true, 0.0, 1.0)
    if (player.state != "faceupgetup"
            or absf(player.health - health_before_direct) > 0.001):
        push_error("A blocked or lethal direct hit rerouted faceupgetup")
        return false
    return true


func _entry_is(
        player: PortFighter,
        opponent: PortFighter,
        frame: float,
        axis_x: float,
        expected: bool,
) -> bool:
    _prepare_faceup_idle(player, opponent, frame)
    player.move_axis = Vector2(axis_x, 0.0)
    player._advance_timed_states(0.0)
    player._animate_candidate()
    if expected:
        var animation: AnimationPlayer = player.get("_candidate_animation")
        return (
            player.state == "faceupgetup"
            and _clip_is(
                player.candidate_animation_clip,
                PortFighter.FACEUP_GETUP_CLIP,
            )
            and animation != null
            and _clip_is(
                String(animation.current_animation),
                PortFighter.FACEUP_GETUP_CLIP,
            )
            and animation.is_playing()
            and absf(player.state_time) <= 0.001
        )
    return _faceup_idle_is(player, frame)


func _faceup_idle_is(player: PortFighter, frame: float) -> bool:
    var animation: AnimationPlayer = player.get("_candidate_animation")
    return (
        player.state == "faceupidle"
        and _clip_is(player.candidate_animation_clip, PortFighter.FACEUP_IDLE_CLIP)
        and animation != null
        and _clip_is(
            String(animation.current_animation),
            PortFighter.FACEUP_IDLE_CLIP,
        )
        and animation.is_playing()
        and absf(
            player.state_time
            - frame / PortFighter.SOURCE_FRAME_RATE
        ) <= 0.001
    )


func _prepare_faceup_idle(
        player: PortFighter,
        opponent: PortFighter,
        frame: float,
) -> void:
    _reset_pair(player, opponent)
    player.state = "faceupidle"
    player.state_time = frame / PortFighter.SOURCE_FRAME_RATE
    player._animate_candidate()


func _prepare_faceup_getup(
        player: PortFighter,
        opponent: PortFighter,
        frame: float,
) -> bool:
    _prepare_faceup_idle(player, opponent, frame)
    player.move_axis = Vector2(1.0, 0.0)
    player._advance_timed_states(0.0)
    player._animate_candidate()
    if player.state != "faceupgetup":
        push_error("Could not enter faceupgetup at frame " + str(frame))
        return false
    player.move_axis = Vector2.ZERO
    return true


func _reset_pair(player: PortFighter, opponent: PortFighter) -> void:
    player.reset_fighter(Vector3(0.6, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.0, 1.2, 0.0))
    player.facing = -1.0
    opponent.facing = 1.0


func _return_is(
        player: PortFighter,
        expected_state: String,
        animation_name: String,
        radius: float,
        looping: bool,
) -> bool:
    var animation: AnimationPlayer = player.get("_candidate_animation")
    var clip_path: String = String(player._candidate_clip_paths[animation_name])
    var clip: Animation = animation.get_animation(clip_path)
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
    )


func _character_tracks_disabled(
        player: PortFighter,
        animation_name: String,
) -> bool:
    var animation: AnimationPlayer = player.get("_candidate_animation")
    var clip_path: String = String(player._candidate_clip_paths[animation_name])
    var clip: Animation = animation.get_animation(clip_path)
    var animation_root: Node = animation.get_node_or_null(animation.root_node)
    for track: int in clip.get_track_count():
        var kind: int = clip.track_get_type(track)
        if kind not in [
            Animation.TYPE_POSITION_3D,
            Animation.TYPE_ROTATION_3D,
            Animation.TYPE_SCALE_3D,
        ]:
            push_error("Face-up getup clip has a non-transform track")
            return false
        var target: Node = animation_root.get_node_or_null(clip.track_get_path(track))
        if (target != null
                and String(target.name) == "character"
                and clip.track_is_enabled(track)):
            push_error("Face-up getup left a character transform track enabled")
            return false
    return true


func _clip_is(actual: String, expected: String) -> bool:
    return actual == expected or actual.ends_with("/" + expected)

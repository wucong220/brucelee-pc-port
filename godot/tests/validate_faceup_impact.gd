extends SceneTree
## Validate the limited impacttofloor -> faceupidle candidate chain.


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
        push_error("Face-up candidates failed to load: %s | %s" % [
            player.candidate_load_error, opponent.candidate_load_error,
        ])
        quit(1)
        return
    if not _check_clips(player):
        quit(1)
        return
    if not _check_windows(player):
        quit(1)
        return
    if not _check_missing_clips(player):
        quit(1)
        return
    if not _check_hit_routing(player, opponent):
        quit(1)
        return
    if not _check_faceup_idle_ignores_unverified_hits(player, opponent):
        quit(1)
        return
    if not _check_entry_and_return(player):
        quit(1)
        return
    if not _check_faceup_idle_has_no_unverified_exits(player):
        quit(1)
        return
    print("FACEUP_IMPACT_VALIDATION=" + JSON.stringify({
        "impact_clip": PortFighter.FACEUP_IMPACT_TO_FLOOR_CLIP,
        "entry_frame": PortFighter.FACEUP_IMPACT_TO_FLOOR_ENTRY_FRAME,
        "exit_frame": PortFighter.FACEUP_IMPACT_TO_FLOOR_EXIT_FRAME,
        "idle_clip": PortFighter.FACEUP_IDLE_CLIP,
        "idle_duration_frames": PortFighter.FACEUP_IDLE_DURATION_FRAMES,
        "source_windows": {
            "facedowngetup": [5, 11],
            "facedownattack": [24, 31],
        },
        "candidate_scope": (
            "low impact only; faceupidle incoming hits are ignored; "
            + "lethal and missing-clip paths fall back"
        ),
    }))
    quit(0)


func _check_clips(player: PortFighter) -> bool:
    var animation: AnimationPlayer = player.get("_candidate_animation")
    var clip_count: int = animation.get_animation_list().size() if animation != null else 0
    if clip_count not in [19, 20]:
        push_error("Face-up GLB does not expose the 19-clip base or 20-clip extension")
        return false
    if clip_count == 20 and not _has_clip(
        animation, PortFighter.FACEUP_GETUP_CLIP
    ):
        push_error("20-clip face-up extension is missing "
            + PortFighter.FACEUP_GETUP_CLIP)
        return false
    for excluded_name: String in [
        "all_getup_faceup_attack",
        "m01_attack_to_floor",
    ]:
        if _has_clip(animation, excluded_name):
            push_error("Face-up candidate must not include " + excluded_name)
            return false
    if not _check_clip(
        player,
        PortFighter.FACEUP_IMPACT_TO_FLOOR_CLIP,
        PortFighter.FACEUP_IMPACT_TO_FLOOR_DURATION_FRAMES,
        Animation.LOOP_NONE,
    ):
        return false
    return _check_clip(
        player,
        PortFighter.FACEUP_IDLE_CLIP,
        PortFighter.FACEUP_IDLE_DURATION_FRAMES,
        Animation.LOOP_LINEAR,
    )


func _has_clip(animation: AnimationPlayer, clip_name: String) -> bool:
    for candidate: StringName in animation.get_animation_list():
        var candidate_name: String = String(candidate)
        if candidate_name == clip_name or candidate_name.ends_with("/" + clip_name):
            return true
    return false


func _check_clip(
        player: PortFighter,
        clip_name: String,
        duration_frames: int,
        expected_loop: Animation.LoopMode,
) -> bool:
    if not player._candidate_clip_paths.has(clip_name):
        push_error("Clip did not pass candidate track validation: " + clip_name)
        return false
    var animation: AnimationPlayer = player.get("_candidate_animation")
    var clip_path: String = String(player._candidate_clip_paths[clip_name])
    var clip: Animation = animation.get_animation(clip_path)
    var expected_seconds: float = float(duration_frames) / PortFighter.SOURCE_FRAME_RATE
    if absf(clip.length - expected_seconds) > 0.002:
        push_error("Clip duration mismatch for " + clip_name)
        return false
    if clip.loop_mode != expected_loop:
        push_error("Clip loop mode mismatch for " + clip_name)
        return false
    return _character_tracks_disabled(player, clip_name)


func _check_windows(player: PortFighter) -> bool:
    var cases: Array = [
        ["facedowngetup", 5.0, "low", false, 6.0, true],
        ["facedowngetup", 11.0, "low", false, 6.0, true],
        ["facedowngetup", 4.999, "low", false, 6.0, false],
        ["facedowngetup", 11.001, "low", false, 6.0, false],
        ["facedownattack", 24.0, "low", false, 6.0, true],
        ["facedownattack", 31.0, "low", false, 6.0, true],
        ["facedownattack", 23.999, "low", false, 6.0, false],
        ["facedownattack", 31.001, "low", false, 6.0, false],
        ["facedownattack", 24.0, "medium", false, 6.0, false],
        ["facedownattack", 24.0, "low", true, 6.0, false],
        ["facedownattack", 24.0, "low", false, 100.0, false],
    ]
    for case_value: Variant in cases:
        var values: Array = case_value
        player.reset_fighter(Vector3(0.6, 1.2, 0.0))
        player.state = String(values[0])
        player.state_time = float(values[1]) / PortFighter.SOURCE_FRAME_RATE
        var actual: bool = player._accepts_impact_to_floor(
            String(values[2]), bool(values[3]), float(values[4])
        )
        if actual != bool(values[5]):
            push_error("Source impact condition mismatch: " + JSON.stringify({
                "state": values[0],
                "frame": values[1],
                "height": values[2],
                "blocked": values[3],
                "damage": values[4],
                "expected": values[5],
                "actual": actual,
            }))
            return false
    return true


func _check_missing_clips(player: PortFighter) -> bool:
    for clip_name: String in [
        PortFighter.FACEUP_IMPACT_TO_FLOOR_CLIP,
        PortFighter.FACEUP_IDLE_CLIP,
    ]:
        player.reset_fighter(Vector3(0.6, 1.2, 0.0))
        player.state = "facedownattack"
        player.state_time = 24.0 / PortFighter.SOURCE_FRAME_RATE
        var saved: String = String(player._candidate_clip_paths[clip_name])
        player._candidate_clip_paths.erase(clip_name)
        var accepted: bool = player._accepts_impact_to_floor("low", false, 6.0)
        player._candidate_clip_paths[clip_name] = saved
        if accepted:
            push_error("Missing clip still allowed impacttofloor: " + clip_name)
            return false
    return true


func _check_hit_routing(player: PortFighter, opponent: PortFighter) -> bool:
    if not _prepare_ground_hit(player, opponent, "facedowngetup", 5.0):
        return false
    var health_before: float = player.health
    _connect_attacker(opponent)
    if player.state != "impacttofloor":
        push_error("A low hit in facedowngetup did not enter impacttofloor")
        return false
    if absf(health_before - player.health - _attacker_damage(opponent)) > 0.001:
        push_error("impacttofloor did not apply the incoming attack damage once")
        return false
    if absf(
        player.state_time * PortFighter.SOURCE_FRAME_RATE
        - float(PortFighter.FACEUP_IMPACT_TO_FLOOR_ENTRY_FRAME)
    ) > 0.001:
        push_error("impacttofloor did not start at source frame 21")
        return false
    if not _prepare_ground_hit(player, opponent, "facedownattack", 24.0):
        return false
    if not player._accepts_impact_to_floor(
        "low", false, _attacker_damage(opponent)
    ):
        push_error("facedownattack frame 24 did not accept the low impact")
        return false
    if not _prepare_ground_hit(player, opponent, "facedownattack", 24.0):
        return false
    player.health = _attacker_damage(opponent) - 1.0
    player.receive_hit(_attacker_damage(opponent), false, 0.0, 1.0)
    if player.state != "ko":
        push_error("A lethal qualifying hit bypassed KO priority")
        return false
    return true


func _prepare_ground_hit(
        player: PortFighter,
        opponent: PortFighter,
        source_state: String,
        source_frame: float,
) -> bool:
    player.reset_fighter(Vector3(0.6, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.0, 1.2, 0.0))
    player.state = source_state
    player.state_time = source_frame / PortFighter.SOURCE_FRAME_RATE
    player.facing = -1.0
    opponent.facing = 1.0
    return true


func _connect_attacker(opponent: PortFighter) -> void:
    if not opponent.request_attack("kick"):
        push_error("Could not start the Brick low kick for impact routing: "
            + JSON.stringify({
                "state": opponent.state,
                "guard_held": opponent.guard_held,
                "standing_rules": opponent._uses_standing_idle_rules(),
                "has_kick": opponent.ATTACKS.has("kick"),
                "attack_keys": opponent.ATTACKS.keys(),
            }))
        return
    opponent.state = "active"
    opponent.state_time = float(opponent.ATTACKS["kick"]["active"])
    opponent._try_attack_contact()


func _attacker_damage(opponent: PortFighter) -> float:
    return float(opponent.ATTACKS["kick"]["damage"])


func _check_faceup_idle_ignores_unverified_hits(
        player: PortFighter,
        opponent: PortFighter,
) -> bool:
    var cases: Array[Array] = [
        ["ordinary", player.MAX_HEALTH],
        ["lethal", _attacker_damage(opponent) - 1.0],
    ]
    for case_value: Array in cases:
        _prepare_faceup_idle_hit(player, opponent)
        player.health = float(case_value[1])
        var health_before: float = player.health
        var opponent_hits_before: int = opponent.combo_hits
        _connect_attacker(opponent)
        if player.state != "faceupidle":
            push_error("An unverified hit exited faceupidle: " + String(case_value[0]))
            return false
        if absf(player.health - health_before) > 0.001:
            push_error("An unverified hit changed faceupidle health: "
                + String(case_value[0]))
            return false
        if opponent.combo_hits != opponent_hits_before:
            push_error("An ignored faceupidle hit counted as a combo hit: "
                + String(case_value[0]))
            return false
        if opponent._attack_connected:
            push_error("An ignored faceupidle hit marked attack contact: "
                + String(case_value[0]))
            return false
    _prepare_faceup_idle_hit(player, opponent)
    var health_before: float = player.health
    player.receive_hit(1.0, true, 0.0, 1.0)
    if player.state != "faceupidle" or absf(player.health - health_before) > 0.001:
        push_error("A blocked hit rerouted faceupidle through blockstun")
        return false
    return true


func _prepare_faceup_idle_hit(
        player: PortFighter,
        opponent: PortFighter,
) -> void:
    player.reset_fighter(Vector3(0.6, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.0, 1.2, 0.0))
    player.state = "faceupidle"
    player.state_time = 10.0 / PortFighter.SOURCE_FRAME_RATE
    player.facing = -1.0
    opponent.facing = 1.0


func _check_entry_and_return(player: PortFighter) -> bool:
    player.reset_fighter(Vector3(0.6, 1.2, 0.0))
    var health_before: float = player.health
    player.begin_impact_to_floor(6.0)
    if (player.state != "impacttofloor"
            or absf(player.health - (health_before - 6.0)) > 0.001
            or absf(
                player.state_time * PortFighter.SOURCE_FRAME_RATE
                - float(PortFighter.FACEUP_IMPACT_TO_FLOOR_ENTRY_FRAME)
            ) > 0.001):
        push_error("impacttofloor entry state or timing is wrong")
        return false
    player._animate_candidate()
    var animation: AnimationPlayer = player.get("_candidate_animation")
    var entry_seconds: float = (
        float(PortFighter.FACEUP_IMPACT_TO_FLOOR_ENTRY_FRAME)
        / PortFighter.SOURCE_FRAME_RATE
    )
    if (not _clip_is(
            player.candidate_animation_clip,
            PortFighter.FACEUP_IMPACT_TO_FLOOR_CLIP,
        )
            or absf(animation.current_animation_position - entry_seconds) > 0.002
            or absf(player.source_radius_for_current_animation() - 75.0) > 0.001):
        push_error("impacttofloor did not start its clip at frame 21 with radius 75")
        return false
    var before_exit: float = (
        float(PortFighter.FACEUP_IMPACT_TO_FLOOR_EXIT_FRAME - 21) - 0.001
    ) / PortFighter.SOURCE_FRAME_RATE
    player._advance_timed_states(before_exit)
    player._animate_candidate()
    if player.state != "impacttofloor":
        push_error("impacttofloor exited before frame 48")
        return false
    player._advance_timed_states(0.002)
    player._animate_candidate()
    if (player.state != "faceupidle"
            or not _clip_is(player.candidate_animation_clip, PortFighter.FACEUP_IDLE_CLIP)
            or absf(player.source_radius_for_current_animation() - 75.0) > 0.001):
        push_error("impacttofloor did not enter faceupidle at frame 48")
        return false
    player.state_time = 44.0 / PortFighter.SOURCE_FRAME_RATE
    player._advance_timed_states(2.0 / PortFighter.SOURCE_FRAME_RATE)
    player._animate_candidate()
    if (player.state != "faceupidle"
            or player.state_time
                >= float(PortFighter.FACEUP_IDLE_DURATION_FRAMES)
                    / PortFighter.SOURCE_FRAME_RATE):
        push_error("faceupidle did not loop at frame 45")
        return false
    return true


func _check_faceup_idle_has_no_unverified_exits(player: PortFighter) -> bool:
    player.state = "faceupidle"
    player.state_time = 10.0 / PortFighter.SOURCE_FRAME_RATE
    player.move_axis = Vector2(0.0, 1.0)
    if player.record_virtual_press("a"):
        push_error("faceupidle accepted the facedown attack input sequence")
        return false
    if player.request_attack("punch") or player.request_attack("kick"):
        push_error("faceupidle accepted a standing attack")
        return false
    player._advance_timed_states(5.0 / PortFighter.SOURCE_FRAME_RATE)
    player._animate_candidate()
    return (
        player.state == "faceupidle"
        and _clip_is(player.candidate_animation_clip, PortFighter.FACEUP_IDLE_CLIP)
    )


func _character_tracks_disabled(player: PortFighter, animation_name: String) -> bool:
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
            push_error("Face-up clip has a non-transform track: " + animation_name)
            return false
        var target: Node = animation_root.get_node_or_null(clip.track_get_path(track))
        if (target != null
                and String(target.name) == "character"
                and clip.track_is_enabled(track)):
            push_error("Face-up clip left a character transform track enabled: "
                + animation_name)
            return false
    return true


func _clip_is(actual: String, expected: String) -> bool:
    return actual == expected or actual.ends_with("/" + expected)

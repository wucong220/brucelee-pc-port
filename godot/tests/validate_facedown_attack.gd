extends SceneTree
## Validate the recovered facedownattack timing and prototype input sequences.


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected the Bruce facedown-attack GLB and the Brick GLB")
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
        push_error("Facedown-attack candidates failed to load: %s | %s" % [
            player.candidate_load_error, opponent.candidate_load_error,
        ])
        quit(1)
        return
    if not _check_clip(player):
        quit(1)
        return
    if not _check_sequences(player, opponent):
        quit(1)
        return
    if not _check_sequence_skips_unmatched_events(player, opponent):
        quit(1)
        return
    if not _check_sequence_window_expiry(player, opponent):
        quit(1)
        return
    if not _check_reset_clears_input_history(player, opponent):
        quit(1)
        return
    if not _check_wrong_sequence(player, opponent):
        quit(1)
        return
    if not _check_attack_timing_and_return(player, opponent):
        quit(1)
        return
    if not _check_attack_radius_boundary(player, opponent):
        quit(1)
        return
    if not _check_ai_guard_threat(scene, player, opponent):
        quit(1)
        return
    if not _check_missing_clip_fallback(player, opponent):
        quit(1)
        return
    print("FACEDOWN_ATTACK_VALIDATION=" + JSON.stringify({
        "clip": PortFighter.FACEDOWN_ATTACK_CLIP,
        "duration_frames": PortFighter.FACEDOWN_ATTACK_DURATION_FRAMES,
        "damage_frames": [
            PortFighter.FACEDOWN_ATTACK_DAMAGE_START_FRAME,
            PortFighter.FACEDOWN_ATTACK_DAMAGE_END_FRAME,
        ],
        "exit_frame": PortFighter.FACEDOWN_ATTACK_EXIT_FRAME,
        "damage": PortFighter.FACEDOWN_ATTACK_DAMAGE,
        "attack_radius": PortFighter.FACEDOWN_ATTACK_RADIUS,
        "prototype_sequences": ["aaa", "abb", "bcc", "bdd"],
        "prototype_input_window_seconds": (
            PortFighter.FACEDOWN_INPUT_PROTOTYPE_WINDOW_SECONDS
        ),
        "physical_mapping": "prototype-only J/K/L/U",
        "missing_clip_fallback": "facedownidle",
    }))
    quit(0)


func _check_clip(player: PortFighter) -> bool:
    var animation: AnimationPlayer = player.get("_candidate_animation")
    if animation == null or animation.get_animation_list().size() != 17:
        push_error("Facedown-attack GLB does not expose exactly 17 clips")
        return false
    var clip_path: String = _find_clip(animation, PortFighter.FACEDOWN_ATTACK_CLIP)
    if clip_path.is_empty() or not player._candidate_clip_paths.has(
            PortFighter.FACEDOWN_ATTACK_CLIP
    ):
        push_error("all_getup_facedwn_attack did not pass the candidate track check")
        return false
    var clip: Animation = animation.get_animation(clip_path)
    if clip.loop_mode != Animation.LOOP_NONE:
        push_error("all_getup_facedwn_attack is looping")
        return false
    var expected_seconds: float = (
        float(PortFighter.FACEDOWN_ATTACK_DURATION_FRAMES)
        / PortFighter.SOURCE_FRAME_RATE
    )
    if absf(clip.length - expected_seconds) > 0.002:
        push_error("all_getup_facedwn_attack duration differs from 35/30 seconds: "
                + "%s actual vs %s expected" % [clip.length, expected_seconds])
        return false
    return _character_tracks_disabled(player, PortFighter.FACEDOWN_ATTACK_CLIP)


func _check_sequences(player: PortFighter, opponent: PortFighter) -> bool:
    var sequences: Array = [
        ["a", "a", "a"],
        ["a", "b", "b"],
        ["b", "c", "c"],
        ["b", "d", "d"],
    ]
    for sequence_value: Variant in sequences:
        var sequence: Array = sequence_value
        if not _enter_facedown(player, opponent):
            return false
        if player.record_virtual_press(String(sequence[0])):
            push_error("facedownattack started after one input")
            return false
        if player.record_virtual_press(String(sequence[1])):
            push_error("facedownattack started after two inputs")
            return false
        if not player.record_virtual_press(String(sequence[2])):
            push_error("Verified sequence did not start facedownattack: "
                    + "".join(sequence))
            return false
        player._animate_candidate()
        if (player.state != "facedownattack"
                or player.attack_kind != "facedownattack"
                or not _clip_is(
                    player.candidate_animation_clip,
                    PortFighter.FACEDOWN_ATTACK_CLIP,
                )
                or absf(player.source_radius_for_current_animation() - 45.0) > 0.001):
            push_error("facedownattack did not start with its recovered clip and radius")
            return false
    return true


func _check_sequence_skips_unmatched_events(
        player: PortFighter, opponent: PortFighter
) -> bool:
    var cases: Array = [
        ["a", "c", "a", "a"],
        ["a", "c", "b", "b"],
        ["b", "a", "c", "c"],
        ["b", "a", "d", "d"],
    ]
    for case_value: Variant in cases:
        var inputs: Array = case_value
        if not _enter_facedown(player, opponent):
            return false
        for input_index: int in range(inputs.size()):
            var matched: bool = player.record_virtual_press(String(inputs[input_index]))
            if input_index < inputs.size() - 1 and matched:
                push_error("Sequence matched before its final input: "
                        + "".join(inputs))
                return false
            if input_index == inputs.size() - 1 and not matched:
                push_error("Sequence did not skip unmatched events: "
                        + "".join(inputs))
                return false
        if player.state != "facedownattack":
            push_error("Sequence did not enter facedownattack: " + "".join(inputs))
            return false
    return true


func _check_sequence_window_expiry(player: PortFighter, opponent: PortFighter) -> bool:
    if not _enter_facedown(player, opponent):
        return false
    if player.record_virtual_press("a") or player.record_virtual_press("b"):
        push_error("abb started before its final b")
        return false
    player._time += PortFighter.FACEDOWN_INPUT_PROTOTYPE_WINDOW_SECONDS + 0.01
    if player.record_virtual_press("b"):
        push_error("expired abbreviated input matched abb")
        return false
    if player._facedown_input_history.size() != 1:
        push_error("expired input vector was not cleared before the next press")
        return false
    return true


func _check_reset_clears_input_history(
        player: PortFighter, opponent: PortFighter
) -> bool:
    if not _enter_facedown(player, opponent):
        return false
    if (player.record_virtual_press("a")
            or player._facedown_input_history.size() != 1):
        push_error("Facedown input history did not record a partial sequence")
        return false
    player.reset_fighter(Vector3(0.6, 1.2, 0.0))
    if not player._facedown_input_history.is_empty():
        push_error("Fighter reset did not clear facedown input history")
        return false
    return true


func _check_wrong_sequence(player: PortFighter, opponent: PortFighter) -> bool:
    if not _enter_facedown(player, opponent):
        return false
    for virtual_key: String in ["a", "b", "c"]:
        if player.record_virtual_press(virtual_key):
            push_error("Unverified abc input started facedownattack")
            return false
    if player.request_attack("punch") or player.request_attack("kick"):
        push_error("Normal attack started from facedownidle")
        return false
    return player.state == "facedownidle"


func _check_attack_timing_and_return(player: PortFighter, opponent: PortFighter) -> bool:
    if not _enter_facedown(player, opponent):
        return false
    if not _start_attack(player):
        return false
    var target_health: float = opponent.health
    player._advance_timed_states(
        (float(PortFighter.FACEDOWN_ATTACK_DAMAGE_START_FRAME) - 0.001)
        / PortFighter.SOURCE_FRAME_RATE
    )
    if absf(opponent.health - target_health) > 0.001:
        push_error("facedownattack hit before frame 6")
        return false
    player._advance_timed_states(2.0 / PortFighter.SOURCE_FRAME_RATE)
    if absf((target_health - opponent.health) - PortFighter.FACEDOWN_ATTACK_DAMAGE) > 0.001:
        push_error("facedownattack did not deal its recovered damage at frame 6-9: "
                + JSON.stringify({
                    "state": player.state,
                    "state_time_frames": player.state_time * PortFighter.SOURCE_FRAME_RATE,
                    "connected": player._attack_connected,
                    "target_health": opponent.health,
                    "target_state": opponent.state,
                    "distance": Vector2(
                        opponent.global_position.x - player.global_position.x,
                        opponent.global_position.z - player.global_position.z,
                    ).length(),
                    "reach": player.attack_reach_world("facedownattack", opponent),
                    "facing": player.facing,
                }))
        return false
    var health_after_hit: float = opponent.health
    player._advance_timed_states(2.0 / PortFighter.SOURCE_FRAME_RATE)
    if absf(opponent.health - health_after_hit) > 0.001:
        push_error("facedownattack registered more than one contact")
        return false
    var exit_time: float = float(PortFighter.FACEDOWN_ATTACK_EXIT_FRAME) / PortFighter.SOURCE_FRAME_RATE
    player._advance_timed_states(maxf(exit_time - player.state_time - 0.001, 0.0))
    player._animate_candidate()
    if player.state != "facedownattack":
        push_error("facedownattack exited before frame 32")
        return false
    player._advance_timed_states(0.002)
    player._animate_candidate()
    if (player.state != "idle"
            or not _clip_is(player.candidate_animation_clip, "m01_idle_01")):
        push_error("facedownattack did not return to idle at frame 32")
        return false
    return true


func _check_attack_radius_boundary(
        player: PortFighter, opponent: PortFighter
) -> bool:
    if not _enter_facedown(player, opponent):
        return false
    var reach: float = player.attack_reach_world("facedownattack", opponent)
    var expected_reach: float = (
        120.0 * player.radius_scale
        + opponent.source_radius_for_current_animation()
    ) * player.source_units_to_world
    if absf(reach - expected_reach) > 0.001:
        push_error("facedownattack reach does not contain the recovered 120 radius")
        return false
    var hit_events: Array[String] = []
    var on_hit: Callable = func(
        _attacker: PortFighter,
        _defender: PortFighter,
        action: String,
        _damage: float,
        _blocked: bool,
    ) -> void:
        hit_events.append(action)
    player.combat_hit.connect(on_hit)
    var cases: Array = [
        [1.0, expected_reach + 0.01, false, "front outside reach"],
        [1.0, expected_reach - 0.01, true, "front inside reach"],
        [1.0, -0.5, false, "front attack against rear target"],
        [-1.0, -expected_reach + 0.01, true, "left inside reach while facing left"],
        [-1.0, 0.5, false, "left-facing attack against rear target"],
    ]
    for case_data: Variant in cases:
        var case_values: Array = case_data
        if not _check_facedown_attack_direction_case(
            player,
            opponent,
            float(case_values[0]),
            float(case_values[1]),
            bool(case_values[2]),
            String(case_values[3]),
            hit_events,
        ):
            player.combat_hit.disconnect(on_hit)
            return false
    player.combat_hit.disconnect(on_hit)
    return true


func _check_facedown_attack_direction_case(
        player: PortFighter,
        opponent: PortFighter,
        facing: float,
        offset: float,
        expected_hit: bool,
        label: String,
        hit_events: Array[String],
) -> bool:
    if not _enter_facedown(player, opponent) or not _start_attack(player):
        return false
    player.facing = facing
    opponent.guard_held = false
    opponent.global_position = player.global_position + Vector3(offset, 0.0, 0.0)
    var health_before: float = opponent.health
    hit_events.clear()
    player._try_facedown_attack_contact()
    var took_damage: bool = absf(
        health_before - opponent.health - PortFighter.FACEDOWN_ATTACK_DAMAGE
    ) <= 0.001
    if took_damage != expected_hit:
        push_error("facedownattack health result was wrong for " + label)
        return false
    if player._attack_connected != expected_hit:
        push_error("facedownattack connection flag was wrong for " + label)
        return false
    var expected_events: int = 1 if expected_hit else 0
    if hit_events.size() != expected_events:
        push_error("facedownattack combat_hit count was wrong for " + label)
        return false
    if expected_hit and hit_events[0] != "facedownattack":
        push_error("facedownattack emitted the wrong combat action for " + label)
        return false
    return true


func _check_ai_guard_threat(
        scene: Node, player: PortFighter, opponent: PortFighter
) -> bool:
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.6, 1.2, 0.0))
    player.state = "facedownattack"
    player.state_time = 0.0
    player.attack_kind = "facedownattack"
    player.attack_sequence = 77
    player.facing = 1.0
    var rng: RandomNumberGenerator = scene.get("rng")
    var guard_seed: int = -1
    for seed_value: int in range(1000):
        rng.seed = seed_value
        if rng.randf() < 0.25:
            guard_seed = seed_value
            break
    if guard_seed < 0:
        push_error("Unable to find deterministic facedownattack guard seed")
        return false
    rng.seed = guard_seed
    scene.set("ai_timer", 10.0)
    scene.set("ai_guard_sequence", -1)
    scene.set("ai_guard_decision", false)
    scene.call("_think_ai", 0.0)
    if not opponent.guard_held:
        push_error("AI did not guard during facedownattack startup")
        return false
    player._advance_timed_states(
        (float(PortFighter.FACEDOWN_ATTACK_DAMAGE_START_FRAME) + 0.001)
        / PortFighter.SOURCE_FRAME_RATE
    )
    if opponent.state != "blockstun" or not player._attack_connected:
        push_error("AI guard was not applied to the first facedownattack contact: "
                + JSON.stringify({
                    "opponent_state": opponent.state,
                    "opponent_guard": opponent.guard_held,
                    "health": opponent.health,
                    "connected": player._attack_connected,
                    "state": player.state,
                    "state_frame": player.state_time * PortFighter.SOURCE_FRAME_RATE,
                    "opponent_linked": player.opponent == opponent,
                    "facing": player.facing,
                    "distance": Vector2(
                        opponent.global_position.x - player.global_position.x,
                        opponent.global_position.z - player.global_position.z,
                    ).length(),
                    "reach": player.attack_reach_world("facedownattack", opponent),
                }))
        return false
    player.state_time = (
        float(PortFighter.FACEDOWN_ATTACK_DAMAGE_END_FRAME + 1)
        / PortFighter.SOURCE_FRAME_RATE
    )
    scene.call("_think_ai", 0.0)
    if opponent.guard_held:
        push_error("AI kept guarding after the facedownattack active window")
        return false
    return true


func _check_missing_clip_fallback(player: PortFighter, opponent: PortFighter) -> bool:
    if not _enter_facedown(player, opponent):
        return false
    var saved: String = String(
        player._candidate_clip_paths[PortFighter.FACEDOWN_ATTACK_CLIP]
    )
    player._candidate_clip_paths.erase(PortFighter.FACEDOWN_ATTACK_CLIP)
    for virtual_key: String in ["a", "a", "a"]:
        if player.record_virtual_press(virtual_key):
            player._candidate_clip_paths[PortFighter.FACEDOWN_ATTACK_CLIP] = saved
            push_error("Missing attack clip still entered facedownattack")
            return false
    player._candidate_clip_paths[PortFighter.FACEDOWN_ATTACK_CLIP] = saved
    if (player.state != "facedownidle"
            or not _clip_is(player.candidate_animation_clip, "all_idle_face_down")):
        push_error("Missing attack clip did not remain in facedownidle")
        return false
    return true


func _start_attack(player: PortFighter) -> bool:
    for virtual_key: String in ["a", "a", "a"]:
        if player.record_virtual_press(virtual_key):
            player._animate_candidate()
            return true
    push_error("Could not start facedownattack")
    return false


func _enter_facedown(player: PortFighter, opponent: PortFighter) -> bool:
    player.reset_fighter(Vector3(0.6, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.0, 1.2, 0.0))
    if not opponent.request_attack("kick"):
        push_error("Could not start the knockdown kick")
        return false
    opponent._advance_timed_states(float(opponent.ATTACKS["kick"]["startup"]))
    opponent._try_attack_contact()
    player._advance_timed_states(player.state_time + 0.001)
    player._animate_candidate()
    player.move_axis = Vector2.ZERO
    player.facing = -1.0
    if (player.state != "facedownidle"
            or not _clip_is(player.candidate_animation_clip, "all_idle_face_down")):
        push_error("Could not enter facedownidle before the attack")
        return false
    return true


func _character_tracks_disabled(player: PortFighter, animation_name: String) -> bool:
    var animation: AnimationPlayer = player.get("_candidate_animation")
    var clip_path: String = _find_clip(animation, animation_name)
    if clip_path.is_empty():
        push_error("Missing clip for track check: " + animation_name)
        return false
    var clip: Animation = animation.get_animation(clip_path)
    var animation_root: Node = animation.get_node_or_null(animation.root_node)
    for track: int in clip.get_track_count():
        var kind: int = clip.track_get_type(track)
        if kind not in [
            Animation.TYPE_POSITION_3D,
            Animation.TYPE_ROTATION_3D,
            Animation.TYPE_SCALE_3D,
        ]:
            continue
        var target: Node = animation_root.get_node_or_null(clip.track_get_path(track))
        if target != null and String(target.name) == "character" and clip.track_is_enabled(track):
            push_error("Character transform track stayed enabled: " + animation_name)
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

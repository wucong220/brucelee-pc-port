extends SceneTree
## Validate the candidate faceupidle -> faceupattack -> idle state chain.


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected the Bruce face-up attack GLB and the Brick GLB")
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
        push_error("Face-up attack candidates failed to load: %s | %s" % [
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
    if not _check_input_boundaries_and_isolation(player, opponent):
        quit(1)
        return
    if not _check_attack_priority_over_getup(player, opponent):
        quit(1)
        return
    if not _check_attack_timing_and_return(player, opponent):
        quit(1)
        return
    if not _check_attack_radius_and_direction(player, opponent):
        quit(1)
        return
    if not _check_guard(scene, player, opponent):
        quit(1)
        return
    if not _check_ground_impact_boundary(player, opponent):
        quit(1)
        return
    if not _check_unverified_hits_stay_closed(player, opponent):
        quit(1)
        return
    if not _check_missing_clip_fallback(player, opponent):
        quit(1)
        return
    print("FACEUP_ATTACK_VALIDATION=" + JSON.stringify({
        "clip": PortFighter.FACEUP_ATTACK_CLIP,
        "duration_frames": PortFighter.FACEUP_ATTACK_DURATION_FRAMES,
        "framerate": PortFighter.SOURCE_FRAME_RATE,
        "radius": PortFighter.RETURN_ANIMATION_RADII[
            PortFighter.FACEUP_ATTACK_CLIP
        ],
        "damage_frames": [
            PortFighter.FACEUP_ATTACK_DAMAGE_START_FRAME,
            PortFighter.FACEUP_ATTACK_DAMAGE_END_FRAME,
        ],
        "damage": PortFighter.FACEUP_ATTACK_DAMAGE,
        "attack_radius": PortFighter.FACEUP_ATTACK_RADIUS,
        "exit_frame_candidate": PortFighter.FACEUP_ATTACK_EXIT_FRAME,
        "prototype_sequences": ["a", "b", "c", "d"],
        "physical_mapping": "prototype-only J/K/L/U",
        "source_window": [0, 45],
        "unverified_hits": "closed except verified low impact-to-floor path",    }))
    quit(0)


func _check_clip(player: PortFighter) -> bool:
    var animation: AnimationPlayer = player.get("_candidate_animation")
    var clip_count: int = animation.get_animation_list().size() if animation != null else 0
    if clip_count not in [21, 22, 23, 59]:
        push_error("Face-up attack GLB must expose 21, 22, 23, or 59 clips")
        return false
    for required: String in [
        "all_stunned_fall",
        "all_idle_face_up",
        PortFighter.FACEUP_GETUP_CLIP,
        PortFighter.FACEUP_ATTACK_CLIP,
    ]:
        if not _has_clip(animation, required):
            push_error("21-or-later candidate is missing " + required)
            return false
    if clip_count >= 22 and not _has_clip(
        animation, PortFighter.FACEUP_IMPACT_CLIP
    ):
        push_error("22-clip candidate is missing "
            + PortFighter.FACEUP_IMPACT_CLIP)
        return false
    if (clip_count >= 23) != _has_clip(
            animation, PortFighter.ATTACK_TO_FLOOR_CLIP
    ):
        push_error("attacktofloor presence must match the 23-or-later candidate")
        return false
    if not player._candidate_clip_paths.has(PortFighter.FACEUP_ATTACK_CLIP):
        push_error("all_getup_faceup_attack did not pass candidate track validation")
        return false
    var clip_path: String = String(
        player._candidate_clip_paths[PortFighter.FACEUP_ATTACK_CLIP]
    )
    var clip: Animation = animation.get_animation(clip_path)
    var expected_seconds: float = (
        float(PortFighter.FACEUP_ATTACK_DURATION_FRAMES)
        / PortFighter.SOURCE_FRAME_RATE
    )
    if absf(clip.length - expected_seconds) > 0.002:
        push_error("all_getup_faceup_attack duration is not 38 source frames")
        return false
    if clip.loop_mode != Animation.LOOP_NONE:
        push_error("all_getup_faceup_attack must not loop")
        return false
    if absf(
        float(PortFighter.RETURN_ANIMATION_RADII[
            PortFighter.FACEUP_ATTACK_CLIP
        ]) - 45.0
    ) > 0.001:
        push_error("all_getup_faceup_attack radius is not 45")
        return false
    return _character_tracks_disabled(player, PortFighter.FACEUP_ATTACK_CLIP)


func _check_sequences(player: PortFighter, opponent: PortFighter) -> bool:
    # brucelee.set lists four direct faceupidle -> faceupattack rows.  Each row
    # stores three layout alternatives; CLinkDescr::GetKeySequence(index = +0x1c)
    # selects one.  The PC port uses the keyboard layout (index 1), where the
    # four rows are the single presses a, b, c, d.  The old three-press
    # sequences (aaa/abb/bcc/bdd) were a misreading of those alternatives.
    for virtual_key: String in ["a", "b", "c", "d"]:
        if not _enter_faceup_idle(player, opponent, 10.0):
            return false
        if not player.record_standing_combo_press(virtual_key):
            push_error("Recovered single-key face-up attack row did not match: "
                + virtual_key)
            return false
        player._animate_candidate()
        if not _faceup_attack_is(player):
            var animation: AnimationPlayer = player.get("_candidate_animation")
            push_error("faceupattack did not start with its recovered clip and radius: "
                + JSON.stringify({
                    "key": virtual_key,
                    "state": player.state,
                    "attack_kind": player.attack_kind,
                    "candidate_clip": player.candidate_animation_clip,
                    "candidate_action": player.get("_candidate_action"),
                    "has_clip_path": player._candidate_clip_paths.has(
                        PortFighter.FACEUP_ATTACK_CLIP
                    ),
                    "current_animation": (
                        String(animation.current_animation)
                        if animation != null
                        else ""
                    ),
                    "playing": animation.is_playing() if animation != null else false,
                    "radius": player.source_radius_for_current_animation(),
                }))
            return false
    # A direction token outside the four recovered rows must not start the
    # attack, and neither may a standing attack request.
    if not _enter_faceup_idle(player, opponent, 10.0):
        return false
    if player.record_standing_combo_press("up"):
        push_error("Unmapped direction started faceupattack")
        return false
    if not _faceup_idle_is(player, 10.0):
        push_error("Wrong face-up input changed faceupidle")
        return false
    if player.request_attack("punch") or player.request_attack("kick"):
        push_error("A standing attack started directly from faceupidle")
        return false
    # From the standing idle the same press follows the standing link table,
    # never the ground attack.
    player.reset_fighter(Vector3(0.6, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.0, 1.2, 0.0))
    player.state = "idle"
    player.state_time = 0.0
    player.record_standing_combo_press("a")
    if player.state == "faceupattack":
        push_error("A ground attack started from the standing idle")
        return false
    return true


func _check_input_boundaries_and_isolation(
        player: PortFighter,
        opponent: PortFighter,
) -> bool:
    # The recovered row's own window is [0,45]; the port now enforces it for
    # the ground link instead of skipping the window while an idle plays.
    for frame: float in [0.0, 9.999, 10.0, 44.999, 45.0]:
        if not _enter_faceup_idle(player, opponent, frame):
            return false
        if not player.record_standing_combo_press("a"):
            push_error("Face-up attack rejected its recovered window at frame " + str(frame))
            return false
        player._animate_candidate()
        if not _faceup_attack_is(player):
            push_error("Face-up attack did not start at frame " + str(frame))
            return false
    for frame: float in [-0.001, 45.001]:
        if not _enter_faceup_idle(player, opponent, frame):
            return false
        if player.record_standing_combo_press("a"):
            push_error("Face-up attack accepted input outside [0,45] at frame " + str(frame))
            return false
        if not _faceup_idle_is(player, frame):
            push_error("Out-of-window face-up input changed faceupidle at frame " + str(frame))
            return false

    # A state transition discards unconsumed link events (the recovered
    # _enter_locomotion_state clears the queue).
    if not _enter_faceup_idle(player, opponent, 20.0):
        return false
    player._link_events.append({
        "tokens": ["a"], "consumed": false, "time_ms": 0,
    })
    player._enter_locomotion_state("idle2")
    if not player._link_events.is_empty():
        push_error("State transition retained unconsumed link events")
        return false
    player._link_events.append({
        "tokens": ["a"], "consumed": false, "time_ms": 0,
    })
    player.reset_fighter(Vector3(0.6, 1.2, 0.0))
    if not player._link_events.is_empty():
        push_error("Fighter reset retained unconsumed link events")
        return false
    return true


func _check_attack_priority_over_getup(
        player: PortFighter,
        opponent: PortFighter,
) -> bool:
    if not _enter_faceup_idle(player, opponent, 10.0):
        return false
    player.move_axis = Vector2(1.0, 0.0)
    # The ground attack link is evaluated by _try_follow_links before the
    # faceupidle move_axis getup fallback, so the attack wins.
    if not player.record_standing_combo_press("b"):
        push_error("Face-up attack did not win over the horizontal getup input")
        return false
    player._advance_timed_states(0.0)
    player._animate_candidate()
    if not _faceup_attack_is(player):
        push_error("Completing an attack link did not take priority over getup")
        return false
    player.move_axis = Vector2.ZERO
    return true


func _check_attack_timing_and_return(
        player: PortFighter,
        opponent: PortFighter,
) -> bool:
    if not _enter_and_start_attack(player, opponent):
        return false
    var target_health: float = opponent.health
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
    player._advance_timed_states(
        (float(PortFighter.FACEUP_ATTACK_DAMAGE_START_FRAME) - 0.001)
        / PortFighter.SOURCE_FRAME_RATE
    )
    if absf(opponent.health - target_health) > 0.001:
        player.combat_hit.disconnect(on_hit)
        push_error("faceupattack hit before frame 9")
        return false
    player._advance_timed_states(0.002)
    if absf(
        target_health - opponent.health - PortFighter.FACEUP_ATTACK_DAMAGE
    ) > 0.001:
        player.combat_hit.disconnect(on_hit)
        push_error("faceupattack did not deal its recovered damage in frame 9-14")
        return false
    var health_after_hit: float = opponent.health
    var combo_after_hit: int = player.combo_hits
    player._advance_timed_states(6.0 / PortFighter.SOURCE_FRAME_RATE)
    if (absf(opponent.health - health_after_hit) > 0.001
            or player.combo_hits != combo_after_hit
            or hit_events.size() != 1
            or hit_events[0] != "faceupattack"):
        player.combat_hit.disconnect(on_hit)
        push_error("faceupattack registered more than one contact")
        return false
    player.combat_hit.disconnect(on_hit)
    player._attack_connected = false
    player.state_time = 14.001 / PortFighter.SOURCE_FRAME_RATE
    var late_health: float = opponent.health
    player._advance_timed_states(0.5 / PortFighter.SOURCE_FRAME_RATE)
    if (player._attack_connected
            or absf(opponent.health - late_health) > 0.001):
        push_error("faceupattack first contact started after damage frame 14")
        return false
    player.state_time = 36.999 / PortFighter.SOURCE_FRAME_RATE
    player._advance_timed_states(0.0)
    player._animate_candidate()
    if player.state != "faceupattack":
        push_error("faceupattack exited before candidate frame 37")
        return false
    player.state_time = 37.0 / PortFighter.SOURCE_FRAME_RATE
    player._advance_timed_states(0.0)
    player._animate_candidate()
    if (player.state != "idle"
            or not _clip_is(player.candidate_animation_clip, "m01_idle_01")):
        push_error("faceupattack did not return to idle at candidate frame 37")
        return false
    return true


func _check_attack_radius_and_direction(
        player: PortFighter,
        opponent: PortFighter,
) -> bool:
    var reach: float = 0.0
    if not _enter_and_start_attack(player, opponent):
        return false
    reach = player.attack_reach_world("faceupattack", opponent)
    var expected_reach: float = (
        PortFighter.FACEUP_ATTACK_RADIUS * player.radius_scale
        + opponent.source_radius_for_current_animation()
    ) * player.source_units_to_world
    if absf(reach - expected_reach) > 0.001:
        push_error("faceupattack reach does not contain the recovered 90 radius")
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
    for case_value: Variant in [
        [1.0, expected_reach + 0.01, false, "front outside reach"],
        [1.0, expected_reach - 0.01, true, "front inside reach"],
        [1.0, -0.5, false, "front-attack rear target"],
        [-1.0, -expected_reach + 0.01, true, "left inside reach"],
        [-1.0, 0.5, false, "left-attack rear target"],
    ]:
        var values: Array = case_value
        if not _check_direction_case(
            player,
            opponent,
            float(values[0]),
            float(values[1]),
            bool(values[2]),
            String(values[3]),
            hit_events,
        ):
            player.combat_hit.disconnect(on_hit)
            return false
    player.combat_hit.disconnect(on_hit)
    return true


func _check_direction_case(
        player: PortFighter,
        opponent: PortFighter,
        facing: float,
        offset: float,
        expected_hit: bool,
        label: String,
        hit_events: Array[String],
) -> bool:
    if not _enter_and_start_attack(player, opponent):
        return false
    player.facing = facing
    opponent.guard_held = false
    opponent.global_position = player.global_position + Vector3(offset, 0.0, 0.0)
    var health_before: float = opponent.health
    hit_events.clear()
    player._try_faceup_attack_contact()
    var took_damage: bool = absf(
        health_before - opponent.health - PortFighter.FACEUP_ATTACK_DAMAGE
    ) <= 0.001
    if took_damage != expected_hit:
        push_error("faceupattack health result was wrong for " + label)
        return false
    if player._attack_connected != expected_hit:
        push_error("faceupattack connection flag was wrong for " + label)
        return false
    if hit_events.size() != (1 if expected_hit else 0):
        push_error("faceupattack combat_hit count was wrong for " + label)
        return false
    return not expected_hit or hit_events[0] == "faceupattack"


func _check_guard(
        _scene: Node,
        player: PortFighter,
        opponent: PortFighter,
) -> bool:
    if not _enter_and_start_attack(player, opponent):
        return false
    opponent.guard_held = true
    opponent.guard_block_action = ""
    var health_before: float = opponent.health
    var blocked_events: Array[String] = []
    var on_hit: Callable = func(
        _attacker: PortFighter,
        _defender: PortFighter,
        action: String,
        _damage: float,
        blocked: bool,
    ) -> void:
        if blocked:
            blocked_events.append(action)
    player.combat_hit.connect(on_hit)
    player._try_faceup_attack_contact()
    player.combat_hit.disconnect(on_hit)
    if (not player._attack_connected
            or opponent.state != "blockstun"
            or blocked_events.size() != 1
            or blocked_events[0] != "faceupattack"
            or absf(
                health_before
                - opponent.health
                - PortFighter.FACEUP_ATTACK_DAMAGE * 0.12
            ) > 0.001):
        push_error("Guarded faceupattack did not use the recovered impact fields")
        return false

    # Recovered guard actions: begin_block() holds the native high/mid/low (and
    # hard) guard row.  A hard low faceupattack is covered by highblockhard.
    if not _enter_and_start_attack(player, opponent):
        return false
    if not opponent.begin_block("highblockhard"):
        push_error("Recovered highblockhard guard action was rejected")
        return false
    health_before = opponent.health
    player._try_faceup_attack_contact()
    if (opponent.state != "blockstun"
            or absf(
                health_before
                - opponent.health
                - PortFighter.FACEUP_ATTACK_DAMAGE * 0.12
            ) > 0.001):
        push_error("Recovered highblockhard row did not block the faceupattack")
        return false
    return true


func _check_ground_impact_boundary(
        player: PortFighter,
        opponent: PortFighter,
) -> bool:
    for case_value: Variant in [
        [26.999, false],
        [27.0, true],
        [38.0, true],
        [38.001, false],
    ]:
        var canblock_values: Array = case_value
        player.reset_fighter(Vector3(0.6, 1.2, 0.0))
        player.state = "faceupattack"
        player.state_time = (
            float(canblock_values[0]) / PortFighter.SOURCE_FRAME_RATE
        )
        var can_block: bool = player._can_block_current_hit()
        if can_block != bool(canblock_values[1]):
            push_error("faceupattack canblock boundary mismatch at frame "
                + str(canblock_values[0]))
            return false
    for case_value: Variant in [
        [23.999, "low", false, 6.0, false],
        [24.0, "low", false, 6.0, true],
        [31.0, "low", false, 6.0, true],
        [31.001, "low", false, 6.0, false],
        [24.0, "medium", false, 6.0, false],
        [24.0, "low", true, 6.0, false],
        [24.0, "low", false, PortFighter.MAX_HEALTH, false],
    ]:
        var values: Array = case_value
        player.reset_fighter(Vector3(0.6, 1.2, 0.0))
        player.state = "faceupattack"
        player.state_time = float(values[0]) / PortFighter.SOURCE_FRAME_RATE
        var actual: bool = player._accepts_impact_to_floor(
            String(values[1]),
            bool(values[2]),
            float(values[3]),
        )
        if actual != bool(values[4]):
            push_error("faceupattack ground-impact condition mismatch: "
                + JSON.stringify({
                    "frame": values[0],
                    "height": values[1],
                    "blocked": values[2],
                    "damage": values[3],
                    "expected": values[4],
                    "actual": actual,
                }))
            return false

    if not _prepare_ground_hit(player, opponent, 23.999):
        return false
    var ignored_health: float = player.health
    _connect_attacker(opponent)
    if (player.state != "faceupattack"
            or absf(player.health - ignored_health) > 0.001
            or opponent._attack_connected):
        push_error("faceupattack accepted a low hit before ground window 24")
        return false

    if not _prepare_ground_hit(player, opponent, 24.0):
        return false
    var accepted_health: float = player.health
    _connect_attacker(opponent)
    if (player.state != "impacttofloor"
            or absf(
                accepted_health
                - player.health
                - _attacker_damage(opponent)
            ) > 0.001
            or absf(
                player.state_time * PortFighter.SOURCE_FRAME_RATE
                - float(PortFighter.FACEUP_IMPACT_TO_FLOOR_ENTRY_FRAME)
            ) > 0.001):
        push_error("faceupattack frame 24 did not enter the verified impact chain")
        return false

    if not _prepare_ground_hit(player, opponent, 28.0):
        return false
    player.guard_held = true
    ignored_health = player.health
    _connect_attacker(opponent)
    if (player.state != "faceupattack"
            or absf(player.health - ignored_health) > 0.001
            or opponent._attack_connected):
        push_error("Guarded low hit bypassed faceupattack candidate protection")
        return false

    if not _prepare_ground_hit(player, opponent, 24.0):
        return false
    player.health = _attacker_damage(opponent) - 1.0
    ignored_health = player.health
    _connect_attacker(opponent)
    return (
        player.state == "faceupattack"
        and absf(player.health - ignored_health) <= 0.001
        and not opponent._attack_connected
    )


func _check_unverified_hits_stay_closed(
        player: PortFighter,
        opponent: PortFighter,
) -> bool:
    if not _prepare_ground_hit(player, opponent, 20.0):
        return false
    var health_before: float = player.health
    var opponent_hits_before: int = opponent.combo_hits
    opponent._attack_connected = false
    opponent._try_facedown_attack_contact()
    opponent._try_faceup_attack_contact()
    player.receive_hit(1.0, false, 0.0, 1.0)
    player.receive_hit(1.0, true, 0.0, 1.0)
    return (
        player.state == "faceupattack"
        and absf(player.health - health_before) <= 0.001
        and opponent.combo_hits == opponent_hits_before
        and not opponent._attack_connected
    )


func _check_missing_clip_fallback(
        player: PortFighter,
        opponent: PortFighter,
) -> bool:
    var saved: String = String(
        player._candidate_clip_paths[PortFighter.FACEUP_ATTACK_CLIP]
    )
    player._candidate_clip_paths.erase(PortFighter.FACEUP_ATTACK_CLIP)
    for virtual_key: String in ["a", "b", "c", "d"]:
        if not _enter_faceup_idle(player, opponent, 20.0):
            player._candidate_clip_paths[PortFighter.FACEUP_ATTACK_CLIP] = saved
            return false
        if player.record_standing_combo_press(virtual_key):
            player._candidate_clip_paths[PortFighter.FACEUP_ATTACK_CLIP] = saved
            push_error("Missing attack clip still entered faceupattack")
            return false
        if not _faceup_idle_is(player, 20.0):
            player._candidate_clip_paths[PortFighter.FACEUP_ATTACK_CLIP] = saved
            push_error("Missing attack clip did not keep faceupidle")
            return false
    player._candidate_clip_paths[PortFighter.FACEUP_ATTACK_CLIP] = saved
    return true


func _enter_faceup_idle(
        player: PortFighter,
        opponent: PortFighter,
        frame: float,
) -> bool:
    player.reset_fighter(Vector3(0.6, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.0, 1.2, 0.0))
    player.state = "faceupidle"
    player.state_time = frame / PortFighter.SOURCE_FRAME_RATE
    player.move_axis = Vector2.ZERO
    player.facing = -1.0
    opponent.facing = 1.0
    player._animate_candidate()
    if not _faceup_idle_is(player, frame):
        push_error("Could not prepare faceupidle at frame " + str(frame))
        return false
    return true


func _enter_and_start_attack(
        player: PortFighter,
        opponent: PortFighter,
) -> bool:
    if not _enter_faceup_idle(player, opponent, 10.0):
        return false
    if not _press_sequence(player, ["a"]):
        push_error("Could not start faceupattack")
        return false
    return _faceup_attack_is(player)


func _press_sequence(player: PortFighter, inputs: Array) -> bool:
    for virtual_key: Variant in inputs:
        if player.record_standing_combo_press(String(virtual_key)):
            player._animate_candidate()
            return true
    return false


func _prepare_ground_hit(
        player: PortFighter,
        opponent: PortFighter,
        frame: float,
) -> bool:
    player.reset_fighter(Vector3(0.6, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.0, 1.2, 0.0))
    player.state = "faceupattack"
    player.state_time = frame / PortFighter.SOURCE_FRAME_RATE
    player.attack_kind = "faceupattack"
    player.facing = -1.0
    opponent.facing = 1.0
    player._animate_candidate()
    return true


func _connect_attacker(opponent: PortFighter) -> void:
    if not opponent.request_attack("kick"):
        push_error("Could not start the Brick low kick for faceupattack routing")
        return
    opponent.state = "active"
    opponent.state_time = float(opponent.ATTACKS["kick"]["active"])
    opponent._try_attack_contact()


func _attacker_damage(opponent: PortFighter) -> float:
    return float(opponent.ATTACKS["kick"]["damage"])


func _faceup_attack_is(player: PortFighter) -> bool:
    var animation: AnimationPlayer = player.get("_candidate_animation")
    return (
        player.state == "faceupattack"
        and player.attack_kind == "faceupattack"
        and _clip_is(
            player.candidate_animation_clip,
            PortFighter.FACEUP_ATTACK_CLIP,
        )
        and animation != null
        and _clip_is(
            String(animation.current_animation),
            PortFighter.FACEUP_ATTACK_CLIP,
        )
        and animation.is_playing()
        and absf(player.source_radius_for_current_animation() - 45.0) <= 0.001
    )


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
            player.state_time - frame / PortFighter.SOURCE_FRAME_RATE
        ) <= 0.001
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
            push_error("Face-up attack clip has a non-transform track")
            return false
        var target: Node = animation_root.get_node_or_null(clip.track_get_path(track))
        if (target != null
                and String(target.name) == "character"
                and clip.track_is_enabled(track)):
            push_error("Face-up attack left a character transform track enabled")
            return false
    return true


func _has_clip(animation: AnimationPlayer, expected: String) -> bool:
    return not _find_clip(animation, expected).is_empty()


func _find_clip(animation: AnimationPlayer, expected: String) -> String:
    for clip: StringName in animation.get_animation_list():
        var name: String = String(clip)
        if name == expected or name.ends_with("/" + expected):
            return name
    return ""


func _clip_is(actual: String, expected: String) -> bool:
    return actual == expected or actual.ends_with("/" + expected)

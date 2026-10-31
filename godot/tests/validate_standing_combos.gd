extends SceneTree
## Validate the four recovered basic-attack sequences against real candidate clips.

func _initialize() -> void:
    call_deferred("_run")

func _key(keycode: Key) -> InputEventKey:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = keycode
    event.pressed = true
    return event

func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the 25-clip Bruce candidate GLB")
        quit(1)
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
    var player: PortFighter = scene.get("player")
    var opponent: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    opponent.set_physics_process(false)

    if not player.candidate_loaded:
        push_error("Combo candidate failed to load: " + player.candidate_load_error)
        quit(1)
        return
    var clip_paths: Dictionary = player.get("_candidate_clip_paths")
    for action: String in ["high_punch", "high_kick"]:
        if not clip_paths.has(action):
            push_error("Combo candidate is missing the " + action + " clip")
            quit(1)
            return
    var candidate_animation: AnimationPlayer = player.get("_candidate_animation")
    for action: String in ["punch", "kick", "high_punch", "high_kick"]:
        var details: Dictionary = player.ATTACKS[action]
        var clip: Animation = candidate_animation.get_animation(clip_paths[action])
        var expected_seconds: float = (
            float(details["animation_frame_count"]) / PortFighter.SOURCE_FRAME_RATE
        )
        if clip == null or absf(clip.length - expected_seconds) > 0.002:
            push_error("Candidate clip duration differs from the fighting-set metadata: "
                    + action)
            quit(1)
            return
    if not _validate_player_input_route(scene, player, opponent):
        quit(1)
        return

    if not _validate_sequence(player, "a", "punch", "high_punch", 22):
        quit(1)
        return
    if not _validate_sequence(player, "a", "punch", "punch", 22, ["a", "b", "b"]):
        quit(1)
        return
    if not _validate_sequence(player, "b", "kick", "high_kick", 31, ["b", "c", "c"]):
        quit(1)
        return
    if not _validate_sequence(player, "b", "kick", "kick", 31, ["b", "d", "d"]):
        quit(1)
        return

    player.reset_fighter(Vector3(-0.25, 1.20, 0.0))
    opponent.reset_fighter(Vector3(0.25, 1.20, 0.0))
    player.facing = 1.0
    player._time = 0.0
    player.record_standing_combo_press("a")
    if not player.request_attack("punch"):
        push_error("Could not start the initial low punch")
        quit(1)
        return
    player.record_standing_combo_press("a")
    player.record_standing_combo_press("a")
    player._advance_timed_states(22.0 / PortFighter.SOURCE_FRAME_RATE)
    if not player._try_begin_pending_standing_combo():
        push_error("Three A presses did not reach highpunch1 from the frame-22 candobasicattacks window")
        quit(1)
        return
    player._animate_candidate()
    player._advance_timed_states(
        float(player.ATTACKS["high_punch"]["startup"]) + 0.001
    )
    if (absf(opponent.health - 90.0) > 0.001
            or player.combo_hits != 2
            or opponent.last_reaction_source_action != "impactlightfronthigh"):
        push_error(("AAA did not connect the low punch and highpunch1 sources: "
                + "health=%s reaction=%s state=%s attack=%s connected=%s combo_hits=%s"
                + " distance=%s reach=%s guard=%s") % [
                    opponent.health,
                    opponent.last_reaction_source_action,
                    opponent.state,
                    opponent.attack_kind,
                    player.get("_attack_connected"),
                    player.combo_hits,
                    opponent.global_position.distance_to(player.global_position),
                    player.attack_reach_world("high_punch", opponent),
                    opponent.guard_held,
                ])
        quit(1)
        return
    var high_punch_reaction: String = opponent.last_reaction_source_action

    player.reset_fighter(Vector3(-0.25, 1.20, 0.0))
    opponent.reset_fighter(Vector3(0.25, 1.20, 0.0))
    player.facing = 1.0
    player._time = 0.0
    player.record_standing_combo_press("b")
    if not player.request_attack("kick"):
        push_error("Could not start the initial low kick")
        quit(1)
        return
    player.record_standing_combo_press("c")
    player.record_standing_combo_press("c")
    player._advance_timed_states(31.0 / PortFighter.SOURCE_FRAME_RATE)
    if not player._try_begin_pending_standing_combo():
        push_error("BCC did not reach highkick1 from the frame-31 candobasicattacks window")
        quit(1)
        return
    player._animate_candidate()
    player._advance_timed_states(
        float(player.ATTACKS["high_kick"]["startup"]) + 0.001
    )
    if (absf(opponent.health - 89.0) > 0.001
            or player.combo_hits != 2
            or opponent.last_reaction_source_action != "impactlightfronthigh"):
        push_error(("BCC did not connect the low kick and highkick1 sources: "
                + "health=%s reaction=%s state=%s attack=%s combo_hits=%s") % [
                    opponent.health,
                    opponent.last_reaction_source_action,
                    opponent.state,
                    opponent.attack_kind,
                    player.combo_hits,
                ])
        quit(1)
        return
    var high_kick_reaction: String = opponent.last_reaction_source_action

    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    player.record_standing_combo_press("a")
    player.request_attack("punch")
    player._time = 0.3
    player.record_standing_combo_press("b")
    player._time = 0.601
    player.record_standing_combo_press("b")
    if not player.get("_standing_combo_pending_attack").is_empty():
        push_error("Expired combo events still matched a standing combo")
        quit(1)
        return

    if not _validate_heavy_pending_rejected(player, opponent):
        quit(1)
        return
    if not _validate_hit_cancels_pending(player, opponent):
        quit(1)
        return
    if not _validate_pending_replacement(player, opponent):
        quit(1)
        return
    if not _validate_same_action_replay(player, opponent):
        quit(1)
        return
    if not _validate_guard_cancels_combo(player, opponent):
        quit(1)
        return
    if not _validate_blocked_hit_cancels_pending(player, opponent):
        quit(1)
        return
    if not _validate_low_combo_damage(player, opponent):
        quit(1)
        return
    if not _validate_secondary_source(player, opponent):
        quit(1)
        return

    print("STANDING_COMBO_VALIDATION=" + JSON.stringify({
        "aaa": "highpunch1",
        "abb": "lowpunch1",
        "bcc": "highkick1",
        "bdd": "lowkick1",
        "high_punch_damage": 5.0,
        "high_kick_damage": 6.0,
        "high_punch_reaction": high_punch_reaction,
        "high_kick_reaction": high_kick_reaction,
        "standing_combo_hits": 2,
        "input_window_seconds": PortFighter.STANDING_COMBO_INPUT_PROTOTYPE_WINDOW_SECONDS,
        "candobasicattack_windows": PortFighter.CANDOBASICATTACK_WINDOWS,
        "pending_binding": "bound to the matching attack instance; Heavy and hits cancel it",
        "pending_priority": "lowest recovered source_index wins; current overlap fixture selects punch(88) over high_punch(90)",
        "same_action_replay": "ABB/BDD restart the clip even when visual blending is enabled",
        "low_combo_damage": {"abb": 90.0, "bdd": 90.0},
    }))
    await scene._await_combat_audio_idle()
    scene._stop_combat_audio()
    await create_timer(0.1).timeout
    await process_frame
    scene.queue_free()
    await process_frame
    quit(0)

func _validate_heavy_pending_rejected(
        player: PortFighter,
        opponent: PortFighter
) -> bool:
    # Heavy has no recovered source window. Pressing A during it must not queue
    # a standing combo that could fire in a later attack.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    opponent.reset_fighter(Vector3(2.0, 1.20, 0.0))
    player._time = 0.0
    if not player.request_attack("heavy"):
        push_error("Could not start the heavy attack")
        return false
    for _index: int in 3:
        player.record_standing_combo_press("a")
    if not String(player.get("_standing_combo_pending_attack")).is_empty():
        push_error("Heavy attack buffered a standing combo match")
        return false
    player._advance_timed_states(10.0)
    if player.state != "idle":
        push_error("Heavy attack did not return to idle: " + player.state)
        return false
    if not player.request_attack("punch"):
        push_error("Could not start the follow-up low punch")
        return false
    player._advance_timed_states(22.0 / PortFighter.SOURCE_FRAME_RATE)
    if player._try_begin_pending_standing_combo():
        push_error("A stale Heavy-era combo fired in a later attack")
        return false
    if player.attack_kind != "punch":
        push_error("Follow-up attack changed kind without a pending combo")
        return false
    return true


func _validate_hit_cancels_pending(
        player: PortFighter,
        opponent: PortFighter
) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    opponent.reset_fighter(Vector3(2.0, 1.20, 0.0))
    player._time = 0.0
    if not player.request_attack("punch"):
        push_error("Could not start the low punch before the hit interrupt")
        return false
    for _index: int in 3:
        player.record_standing_combo_press("a")
    if String(player.get("_standing_combo_pending_attack")) != "high_punch":
        push_error("AAA did not queue highpunch1 before the hit interrupt")
        return false
    player.receive_hit(5.0, false, 0.0, 1.0)
    if player.state != "hitstun":
        push_error("The defending fighter did not enter hitstun")
        return false
    if not String(player.get("_standing_combo_pending_attack")).is_empty():
        push_error("A hit did not cancel the pending standing combo")
        return false
    return true


func _validate_pending_replacement(
        player: PortFighter,
        opponent: PortFighter
) -> bool:
    # Direct overlap: history a,a,a,b,b matches both highpunch1(90) and
    # lowpunch1(88), so the recovered lower source_index must win without
    # relying on a second independent press sequence.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    opponent.reset_fighter(Vector3(2.0, 1.20, 0.0))
    player.attack_kind = ""
    player.state = "idle"
    var history: Array[Dictionary] = []
    for token: String in ["a", "a", "a", "b", "b"]:
        history.append({"tokens": [token], "time": 0.0})
    player.set("_standing_combo_input_history", history)
    var matched: String = player._matching_standing_combo_attack()
    if matched != "punch":
        push_error("Overlapping history selected %s instead of punch(88)" % matched)
        return false
    return true


func _validate_same_action_replay(
        player: PortFighter,
        opponent: PortFighter
) -> bool:
    # ABB and BDD both re-enter the current action. With visual blending
    # enabled the transition must still restart the clip from frame 0.
    var cases: Array[Dictionary] = [
        {"initial": "punch", "keys": ["a", "b", "b"], "frame": 22, "action": "punch"},
        {"initial": "kick", "keys": ["b", "d", "d"], "frame": 31, "action": "kick"},
    ]
    for entry: Dictionary in cases:
        if not _run_same_action_replay(player, opponent, entry):
            return false
    return true


func _run_same_action_replay(
        player: PortFighter,
        opponent: PortFighter,
        entry: Dictionary
) -> bool:
    var initial: String = String(entry["initial"])
    var keys: Array = entry["keys"]
    var frame: int = int(entry["frame"])
    var expected_action: String = String(entry["action"])
    var label: String = "".join(keys).to_upper()
    player.candidate_visual_blending_enabled = true
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    opponent.reset_fighter(Vector3(2.0, 1.20, 0.0))
    player._time = 0.0
    if not player.request_attack(initial):
        player.candidate_visual_blending_enabled = false
        push_error("Could not start " + initial + " for the blending check")
        return false
    for key: String in keys:
        player.record_standing_combo_press(key)
    if String(player.get("_standing_combo_pending_attack")) != expected_action:
        player.candidate_visual_blending_enabled = false
        push_error(label + " did not queue its same-action target")
        return false
    player._advance_timed_states(float(frame) / PortFighter.SOURCE_FRAME_RATE)
    player._animate_candidate()
    var animation: AnimationPlayer = player.get("_candidate_animation")
    if animation == null or not animation.is_playing():
        player.candidate_visual_blending_enabled = false
        push_error(label + " clip is not playing before the transition")
        return false
    animation.seek(1.0, true)
    var transitioned: bool = player._try_begin_pending_standing_combo()
    player._animate_candidate()
    var position: float = animation.current_animation_position
    var action: String = String(player.get("_candidate_action"))
    player.candidate_visual_blending_enabled = false
    if not transitioned:
        push_error(label + " did not transition inside its source window")
        return false
    if position > 0.05:
        push_error(label + " kept the previous clip position: " + str(position))
        return false
    if action != expected_action:
        push_error(label + " changed the candidate action to " + action)
        return false
    return true


func _validate_guard_cancels_combo(
        player: PortFighter,
        opponent: PortFighter
) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    opponent.reset_fighter(Vector3(2.0, 1.20, 0.0))
    player._time = 0.0
    player.guard_held = true
    if player.record_standing_combo_press("a"):
        push_error("A guarded attack press was accepted as combo input")
        player.guard_held = false
        return false
    player.guard_held = false
    if not player.request_attack("punch"):
        push_error("Could not start the low punch after releasing guard")
        return false
    player.record_standing_combo_press("a")
    player.record_standing_combo_press("a")
    if String(player.get("_standing_combo_pending_attack")) == "high_punch":
        push_error("A guard-era press still completed the AAA sequence")
        return false
    # Guard raised between two presses must also drop a partial history.
    player.record_standing_combo_press("b")
    player.guard_held = true
    player._physics_process(0.0)
    player.guard_held = false
    if not (player.get("_standing_combo_input_history") as Array).is_empty():
        push_error("Raising guard did not clear the partial combo history")
        return false
    # A matched pending combo must also be dropped when guard is raised.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    if not player.request_attack("punch"):
        push_error("Could not start the low punch for the guarded pending check")
        return false
    for _index: int in 3:
        player.record_standing_combo_press("a")
    if String(player.get("_standing_combo_pending_attack")) != "high_punch":
        push_error("AAA did not queue highpunch1 before raising guard")
        return false
    player.guard_held = true
    player._physics_process(0.0)
    player.guard_held = false
    if not String(player.get("_standing_combo_pending_attack")).is_empty():
        push_error("Raising guard did not clear the pending combo")
        return false
    # A guard tap that is pressed and released before the next physics frame
    # must cancel the pending combo immediately, not on a later tick.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    if not player.request_attack("punch"):
        push_error("Could not start the low punch for the guard tap check")
        return false
    for _index: int in 3:
        player.record_standing_combo_press("a")
    if String(player.get("_standing_combo_pending_attack")) != "high_punch":
        push_error("AAA did not queue highpunch1 before the guard tap")
        return false
    player.begin_guard()
    player.end_guard()
    if not String(player.get("_standing_combo_pending_attack")).is_empty():
        push_error("A quick guard tap did not clear the pending combo")
        return false
    player._advance_timed_states(22.0 / PortFighter.SOURCE_FRAME_RATE)
    if player._try_begin_pending_standing_combo():
        push_error("A quick guard tap still allowed the old combo to fire")
        return false
    return true


func _validate_blocked_hit_cancels_pending(
        player: PortFighter,
        opponent: PortFighter
) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    opponent.reset_fighter(Vector3(2.0, 1.20, 0.0))
    player._time = 0.0
    if not player.request_attack("punch"):
        push_error("Could not start the low punch before the block interrupt")
        return false
    for _index: int in 3:
        player.record_standing_combo_press("a")
    if String(player.get("_standing_combo_pending_attack")) != "high_punch":
        push_error("AAA did not queue highpunch1 before the block interrupt")
        return false
    player.receive_hit(5.0, true, 0.0, 1.0)
    if player.state != "blockstun":
        push_error("The defending fighter did not enter blockstun")
        return false
    if not String(player.get("_standing_combo_pending_attack")).is_empty():
        push_error("A blocked hit did not cancel the pending standing combo")
        return false
    return true


func _validate_low_combo_damage(
        player: PortFighter,
        opponent: PortFighter
) -> bool:
    if not _run_low_combo_damage(
        player, opponent, "punch", 22, ["a", "b", "b"],
        "impactlightfrontmid", "ABB -> lowpunch1"
    ):
        return false
    return _run_low_combo_damage(
        player, opponent, "kick", 31, ["b", "d", "d"],
        "impactlightfrontlow", "BDD -> lowkick1"
    )


func _run_low_combo_damage(
        player: PortFighter,
        opponent: PortFighter,
        initial_attack: String,
        transition_frame: int,
        keys: Array,
        expected_reaction: String,
        label: String
) -> bool:
    player.reset_fighter(Vector3(-0.25, 1.20, 0.0))
    opponent.reset_fighter(Vector3(0.25, 1.20, 0.0))
    player.facing = 1.0
    player._time = 0.0
    player.record_standing_combo_press(String(keys[0]))
    if not player.request_attack(initial_attack):
        push_error("Could not start the initial attack for " + label)
        return false
    for index: int in range(1, keys.size()):
        player.record_standing_combo_press(String(keys[index]))
    if String(player.get("_standing_combo_pending_attack")).is_empty():
        push_error(label + " did not queue its follow-up attack")
        return false
    player._advance_timed_states(
        float(player.ATTACKS[initial_attack]["startup"]) + 0.001
    )
    if opponent.health >= 100.0:
        push_error(label + " first attack did not connect")
        return false
    var frame_delta: float = float(transition_frame) - player._current_attack_source_frame()
    if frame_delta > 0.0:
        player._advance_timed_states(frame_delta / PortFighter.SOURCE_FRAME_RATE)
    if not player._try_begin_pending_standing_combo():
        push_error(label + " did not reach its source window")
        return false
    player._advance_timed_states(
        float(player.ATTACKS[player.attack_kind]["startup"]) + 0.001
    )
    if (absf(opponent.health - 90.0) > 0.001
            or player.combo_hits != 2
            or opponent.last_reaction_source_action != expected_reaction):
        push_error(("%s did not connect twice with the expected reaction: health=%s"
                + " reaction=%s combo_hits=%s") % [
                    label,
                    opponent.health,
                    opponent.last_reaction_source_action,
                    player.combo_hits,
                ])
        return false
    return true


func _validate_secondary_source(
        player: PortFighter,
        opponent: PortFighter
) -> bool:
    # highpunch1 and highkick1 are candobasicattacks members themselves, so the
    # same sequences must also start from those attacks and respect their own
    # recovered windows (highpunch 17-101, highkick 33-73).
    var cases: Array[Dictionary] = [
        {"attack": "high_punch", "keys": ["a", "a", "a"], "start": 17},
        {"attack": "high_kick", "keys": ["b", "c", "c"], "start": 33},
    ]
    for entry: Dictionary in cases:
        player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
        opponent.reset_fighter(Vector3(2.0, 1.20, 0.0))
        player._time = 0.0
        var attack: String = String(entry["attack"])
        if not player.request_attack(attack):
            push_error("Could not start " + attack + " as a combo source")
            return false
        for key: String in entry["keys"]:
            player.record_standing_combo_press(key)
        var window: Array = PortFighter.CANDOBASICATTACK_WINDOWS[attack]
        if player._try_begin_pending_standing_combo():
            push_error(attack + " transitioned before its window start")
            return false
        player._advance_timed_states(
            float(window[0] - 1) / PortFighter.SOURCE_FRAME_RATE
        )
        if player._try_begin_pending_standing_combo():
            push_error(attack + " transitioned before its window start")
            return false
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        if not player._try_begin_pending_standing_combo():
            push_error(attack + " did not transition at its window start")
            return false
        if player.attack_kind != attack:
            push_error(attack + " source selected " + player.attack_kind)
            return false
    return true


func _validate_player_input_route(
        scene: Node,
        player: PortFighter,
        opponent: PortFighter
) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    opponent.reset_fighter(Vector3(2.0, 1.20, 0.0))
    player._time = 0.0
    for _index: int in 3:
        scene._unhandled_input(_key(KEY_J))
    if (player.attack_kind != "punch"
            or String(player.get("_standing_combo_pending_attack")) != "high_punch"):
        push_error("Three J key events did not prepare the highpunch1 transition")
        return false
    player._advance_timed_states(22.0 / PortFighter.SOURCE_FRAME_RATE)
    if (not player._try_begin_pending_standing_combo()
            or player.attack_kind != "high_punch"
            or player.current_source_animation() != "m01_pnch_high_01"):
        push_error("J/J/J did not route through the main scene into highpunch1")
        return false
    return true

func _validate_sequence(
        player: PortFighter,
        first_key: String,
        initial_attack: String,
        expected_attack: String,
        transition_frame: int,
        keys: Array = []
) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    var sequence: Array = keys
    if sequence.is_empty():
        sequence = [first_key, first_key, first_key]
    if player.record_standing_combo_press(String(sequence[0])):
        push_error("First combo input unexpectedly transitioned immediately")
        return false
    if not player.request_attack(initial_attack):
        push_error("Could not start initial attack " + initial_attack)
        return false
    for index: int in range(1, sequence.size()):
        player.record_standing_combo_press(String(sequence[index]))
    var pending: String = String(player.get("_standing_combo_pending_attack"))
    if pending != expected_attack:
        push_error("Sequence %s queued %s instead of %s" % [
            "".join(sequence), pending, expected_attack,
        ])
        return false
    player._advance_timed_states(
        float(transition_frame - 1) / PortFighter.SOURCE_FRAME_RATE
    )
    if player._try_begin_pending_standing_combo():
        push_error("Combo transitioned before its candobasicattacks window: "
                + expected_attack)
        return false
    player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player._try_begin_pending_standing_combo():
        if player.attack_kind != expected_attack:
            push_error("Combo selected %s instead of %s" % [
                player.attack_kind, expected_attack,
            ])
            return false
        var expected_animation: String = String(
            player.ATTACKS[expected_attack]["animation"]
        )
        if player.current_source_animation() != expected_animation:
            push_error("Combo selected %s but requested animation %s instead of %s" % [
                expected_attack,
                player.current_source_animation(),
                expected_animation,
            ])
            return false
        return true
    push_error("Combo did not transition at frame %d: %s" % [
        transition_frame, expected_attack,
    ])
    return false

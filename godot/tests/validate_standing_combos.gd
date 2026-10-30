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
    }))
    await scene._await_combat_audio_idle()
    scene._stop_combat_audio()
    await create_timer(0.1).timeout
    await process_frame
    scene.queue_free()
    await process_frame
    quit(0)

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

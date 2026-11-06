extends SceneTree
## Headless check for the recovered CBeatEmUpGame states 1/2/6/9/10/14.
##
## Runs the real scenes/main.tscn so the candidate fighters, their clip lists
## and the match flow are the ones the game ships, then drives the states
## through main.gd.  Every expected value comes from the decompiled functions
## or the decoded archive resources; a state whose data is missing must be
## refused rather than approximated.
##
##   godot --headless --path <godot> --script res://tests/validate_native_states.gd

const NativeMatchStates = preload("res://scripts/native_match_states.gd")

var failures: Array[String] = []


func _initialize() -> void:
    # Deterministic setup: the two new flows are opt-in, and the test drives
    # the intro timing itself instead of waiting for the 3 s live intro.
    OS.set_environment("BRUCELEE_ATTRACT", "1")
    OS.set_environment("BRUCELEE_CONTINUE", "1")
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
    root.add_child(main)
    # Let the candidate GLBs load and the fighters build their clip tables.
    for _i in 90:
        await process_frame
    _check_runtime(main)
    _check_pure_logic()
    main.queue_free()
    if failures.is_empty():
        print("NATIVE_STATES_VALIDATION=PASS")
        quit(0)
    else:
        for failure in failures:
            push_error("NATIVE_STATES_FAIL " + failure)
        print("NATIVE_STATES_VALIDATION=FAIL count=%d" % failures.size())
        quit(1)


func _check_runtime(main: Node) -> void:
    var states = main.get("native_states")
    _expect(states != null, "main.tscn exposes native_states")
    if states == null:
        return
    var player: Node = main.get("player")
    var computer: Node = main.get("computer")
    _expect(player != null and computer != null, "main.tscn builds both fighters")

    # The attract flags must follow the candidate clip lists, not a guess.
    var player_clip: String = main.call("_intro_clip_for", player)
    var computer_clip: String = main.call("_intro_clip_for", computer)
    _expect(player_clip == "m01_intro_01",
        "player intro clip is the first characters.list entry, got %s" % player_clip)
    _expect(computer_clip == "m03_intro_02",
        "brick intro clip is m03_intro_02, got %s" % computer_clip)
    _expect(bool(states.attract_fighter0_available), "fighter 0 attract flag follows its clip")
    _expect(bool(states.attract_fighter1_available), "fighter 1 attract flag follows its clip")

    # The recovered clip length drives the state, so it must be a real length.
    var player_seconds: float = main.call("_intro_clip_seconds", player, player_clip)
    _expect(player_seconds > 4.0 and player_seconds < 4.1,
        "m01_intro_01 length is the archive 4.03 s, got %.3f" % player_seconds)
    var computer_seconds: float = main.call("_intro_clip_seconds", computer, computer_clip)
    _expect(computer_seconds > 5.5 and computer_seconds < 5.7,
        "m03_intro_02 length is the archive 5.57 s, got %.3f" % computer_seconds)

    # SetState(0) routing: state 1 first, state 2 only once state 1 is done.
    _expect(int(states.set_state_zero_target(false)) == NativeMatchStates.STATE_ATTRACT_FIGHTER0,
        "SetState(0) routes to state 1 while fighter 0's flag is set")

    # Entering with no clip must refuse instead of inventing one.
    states.reset()
    var refused: bool = not bool(states.enter(NativeMatchStates.STATE_ATTRACT_FIGHTER0, "", -1.0))
    _expect(refused, "state 1 refuses to start without a candidate intro clip")
    _expect(String(states.fail_reason).begins_with("no-candidate-clip"),
        "refusal names the missing clip, got %s" % states.fail_reason)
    _expect(not bool(states.active), "a refused state is not active")

    # A real clip enters, plays to its own length, then hands to state 2.
    states.reset()
    states.attract_fighter0_available = true
    states.attract_fighter1_available = true
    _expect(bool(states.enter(NativeMatchStates.STATE_ATTRACT_FIGHTER0, player_clip, player_seconds)),
        "state 1 enters with the recovered clip")
    _expect(int(states.advance(player_seconds - 0.05, false)) == -1,
        "state 1 is still playing just before the clip ends")
    _expect(int(states.advance(0.1, false)) == NativeMatchStates.STATE_ATTRACT_FIGHTER1,
        "state 1 hands to state 2 exactly when the clip length is exceeded")
    _expect(not bool(states.attract_fighter0_available),
        "finishing state 1 clears the fighter 0 flag")

    # A skip event ends the intro early, as ConsumeSkipEvent does.
    states.reset()
    states.attract_fighter0_available = true
    states.attract_fighter1_available = false
    _expect(bool(states.enter(NativeMatchStates.STATE_ATTRACT_FIGHTER0, player_clip, player_seconds)),
        "state 1 re-enters for the skip test")
    # Fighter 1's flag is clear, so the skip ends the attract outright instead
    # of chaining into state 2.
    _expect(int(states.advance(0.1, true)) == NativeMatchStates.NO_TARGET_EXIT,
        "a skip event ends state 1 before the clip finishes")
    _expect(not bool(states.active), "the skip leaves the attract state")

    # Replay needs two live buffers; state 10 remains unrecovered.
    for unrecovered in [NativeMatchStates.STATE_REPLAY,
            NativeMatchStates.STATE_CONTINUE_WAIT]:
        states.reset()
        var started: bool = bool(states.enter(unrecovered))
        _expect(not started, "state %d refuses to start" % unrecovered)
        var reason: String = String(states.fail_reason)
        _expect(reason.begins_with("unrecovered")
                or (unrecovered == NativeMatchStates.STATE_REPLAY
                    and reason.begins_with("no-replay-buffer")),
            "state %d reports why it refuses, got %s" % [unrecovered, reason])

    # State 14 is implemented (SetState case 14 @0x1785f8).  It still fails
    # closed when the defeat clip or its recovered camera is missing, and enters
    # once both are supplied.
    states.reset()
    _expect(not bool(states.enter(NativeMatchStates.STATE_COUNTDOWN, "", -1.0, "")),
        "state 14 refuses to start without its defeat clip")
    _expect(String(states.fail_reason).begins_with("no-candidate-clip"),
        "state 14 names the missing defeat clip, got %s" % states.fail_reason)
    states.reset()
    _expect(bool(states.enter(NativeMatchStates.STATE_COUNTDOWN,
            "m01_defeat_01", 3.9, "m01_defeat_01")),
        "state 14 enters with the recovered defeat clip and camera")
    _expect(int(states.state) == 14, "state 14 is the entered state")
    states.reset()

    # State 9 enters, remembers that its countdown is unrecovered, and only
    # leaves through the two actions decoded from game.states.
    states.reset()
    _expect(bool(states.enter(NativeMatchStates.STATE_CONTINUE)), "state 9 enters")
    _expect(not bool(states.describe()["continue_countdown_unrecovered"]),
        "state 9 records that +0x850 is recovered (TrainingSetStep)")
    _expect(int(states.advance(1.0, false)) == -1,
        "state 9 does not expire before the 10 s clock tick")
    _expect(states.choose_continue("maybe") == "",
        "state 9 rejects an action that is not in arcaderetryask")
    states.move_continue_cursor(1)
    _expect(String(states.current_continue_option()) == "no",
        "the continue menu moves to the second gui/continueask.ui option")
    _expect(states.choose_continue("no") == "no", "state 9 accepts the 'no' action")
    _expect(not bool(states.active), "resolving the choice leaves state 9")

    # The replay display budget and the double-speed factor are recovered even
    # though the replay buffer is not.
    _expect(NativeMatchStates.REPLAY_COUNTDOWN_BUDGET_MS == 11000,
        "replay countdown budget is the recovered 11000 ms")
    _expect(NativeMatchStates.REPLAY_SPEED_FACTOR == 2,
        "replay playback is the recovered double speed")
    _expect(NativeMatchStates.COUNTDOWN_ENDED_AFTER_MS == 9999,
        "CountdownEnded threshold is the recovered 9999 ms")

    _check_live_attract(main, player, computer, player_seconds, computer_seconds)
    _check_live_continue(main)

    # And the live scene must still be a playable fight afterwards.
    _expect(bool(player.get("candidate_loaded")), "player candidate stayed loaded")
    _expect(bool(computer.get("candidate_loaded")), "opponent candidate stayed loaded")
    print("NATIVE_STATES_RUNTIME player_intro=%s opponent_intro=%s" % [player_clip, computer_clip])


func _check_live_attract(
        main: Node, player: Node, computer: Node, player_seconds: float, computer_seconds: float
) -> void:
    ## Drive the real state machine on main.tscn, not just the module.
    # The round intro is normally on; enable it here so state 2's recovered
    # follow-up (SetState(3)) is observable instead of the test shortcut.
    OS.set_environment("BRUCELEE_ROUND_INTRO", "1")
    main.set("_attract_played", false)
    main.set("training_mode", false)
    var states = main.get("native_states")
    states.reset()
    main.call("_configure_attract_flags")
    main.call("_start_attract_or_intro")
    _expect(int(main.get("match_state")) == NativeMatchStates.STATE_ATTRACT_FIGHTER0,
        "live SetState(0) enters state 1, got %d" % int(main.get("match_state")))
    _expect(bool(player.visible) and not bool(computer.visible),
        "state 1 shows only fighter 0")
    _expect(bool(player.global_position.is_equal_approx(Vector3(0.0, 1.20, 0.0))),
        "state 1 puts fighter 0 at the origin, got %s" % player.global_position)
    _expect(bool(computer.global_position.is_equal_approx(Vector3(0.0, 1.20, 0.0))),
        "state 1 puts fighter 1 at the origin too")
    var player_animation: AnimationPlayer = player.get("_candidate_animation")
    _expect(player_animation != null and player_animation.is_playing(),
        "state 1 plays the candidate intro clip")
    if player_animation != null:
        _expect(player_animation.current_animation == "m01_intro_01",
            "state 1 plays m01_intro_01, got %s" % player_animation.current_animation)

    # Update case 1 compares the clip duration with the *strict* greater-than,
    # so just short of the length has to stay in state 1.  The module keeps its
    # own state clock, so advance it with real deltas.
    main.call("_update_match_state", player_seconds - 0.05)
    _expect(int(main.get("match_state")) == NativeMatchStates.STATE_ATTRACT_FIGHTER0,
        "live state 1 is still running just before the clip ends")
    main.call("_update_match_state", 0.1)
    _expect(int(main.get("match_state")) == NativeMatchStates.STATE_ATTRACT_FIGHTER1,
        "live state 1 advances to state 2 at the clip length, got %d" % int(main.get("match_state")))
    _expect(not bool(player.visible) and bool(computer.visible),
        "state 2 shows only fighter 1")
    var computer_animation: AnimationPlayer = computer.get("_candidate_animation")
    if computer_animation != null:
        _expect(computer_animation.current_animation == "m03_intro_02",
            "state 2 plays m03_intro_02, got %s" % computer_animation.current_animation)

    main.call("_update_match_state", computer_seconds + 0.01)
    _expect(int(main.get("match_state")) == 3,
        "live state 2 returns to the ordinary round intro, got %d" % int(main.get("match_state")))
    _expect(bool(main.get("_attract_played")), "the played attract counter is set afterwards")
    # Leave the scene in the ordinary fight state for the next check.
    main.call("_enter_match_state", 4)
    main.set("done", false)
    main.set("training_completed", false)
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")


func _check_live_continue(main: Node) -> void:
    var states = main.get("native_states")
    states.reset()
    var entered: bool = bool(main.call("_enter_continue_state"))
    _expect(entered, "live state 9 enters")
    _expect(int(main.get("match_state")) == NativeMatchStates.STATE_CONTINUE,
        "live state 9 sets the match state")
    var layer: CanvasLayer = main.get("_continue_layer")
    _expect(layer != null, "live state 9 builds the continue prompt")
    if layer != null:
        var label: Label = layer.get_node_or_null("ContinuePrompt")
        _expect(label != null and label.text.contains("10"),
            "the continue prompt shows the recovered 10 s countdown")
        _expect(label != null and label.text.contains("YES"),
            "the continue prompt still offers the recovered menu")
        # Two seconds later the recovered QueryString curve shows 9, and the
        # prompt is still open (the integer key 10 fires only at 10 s).
        main.call("_update_continue_prompt", 2.0)
        var counted: Label = layer.get_node_or_null("ContinuePrompt")
        _expect(counted != null and counted.text.contains("9"),
            "the live prompt counts down to 9 after 2 s")
        _expect(not bool(states.continue_resolved),
            "the live prompt is still open after 2 s")
    # The recovered game text launch for SetState(9) is animation 10.
    var launches: Array = main.get("game_text_launch_log")
    var found: bool = false
    for entry in launches:
        if int(Dictionary(entry).get("sequence", -1)) == 10:
            found = true
    _expect(found, "state 9 launched game text sequence 10")
    _expect(String(states.describe()["continue_timeout_action"]) == "#10",
        "state 9 carries the verbatim game.states trigger key #10")
    # The arcaderetryask action 'yes' restarts the match, which must clear the
    # prompt and re-enter the attract/round-intro path.  Keep the round intro
    # on so the restart is observable as state 1/2/3 rather than the test
    # shortcut straight to the fight.
    OS.set_environment("BRUCELEE_ROUND_INTRO", "1")
    main.call("_resolve_continue", NativeMatchStates.CONTINUE_ACTION_YES)
    _expect(main.get("_continue_layer") == null, "resolving the continue prompt removes it")
    _expect(int(main.get("match_state")) in [
        NativeMatchStates.STATE_ATTRACT_FIGHTER0, NativeMatchStates.STATE_ATTRACT_FIGHTER1,
        3],
        "continue 'yes' restarts into the intro path, got %d" % int(main.get("match_state")))


func _check_pure_logic() -> void:
    # The same rules must hold with no scene at all, so a regression in the
    # module cannot hide behind the scene setup.
    var states = NativeMatchStates.new()
    states.attract_fighter0_available = true
    states.attract_fighter1_available = true
    _expect(states.set_state_zero_target(true) == -1,
        "an already-played attract counter skips both intros")
    _expect(states.set_state_zero_target(false) == NativeMatchStates.STATE_ATTRACT_FIGHTER0,
        "flag +0x830 wins over +0x831")
    states.attract_fighter0_available = false
    _expect(states.set_state_zero_target(false) == NativeMatchStates.STATE_ATTRACT_FIGHTER1,
        "flag +0x831 is used when +0x830 is clear")
    states.attract_fighter1_available = false
    _expect(states.set_state_zero_target(false) == -1,
        "no attract flag falls through to the caller's own routing")

    # State 2 never chains back into state 1.
    states.reset()
    states.attract_fighter1_available = true
    states.enter(NativeMatchStates.STATE_ATTRACT_FIGHTER1, "m03_intro_02", 5.567)
    _expect(states.advance(6.0, false) == NativeMatchStates.NO_TARGET_EXIT, "state 2 ends the attract instead of looping")
    _expect(not states.attract_fighter1_available, "state 2 clears its own flag")

    # 'yes' is the other recovered arcaderetryask action.
    states.reset()
    states.enter(NativeMatchStates.STATE_CONTINUE)
    _expect(states.choose_continue(NativeMatchStates.CONTINUE_ACTION_YES)
            == NativeMatchStates.CONTINUE_ACTION_YES,
        "state 9 accepts the 'yes' action")
    print("NATIVE_STATES_LOGIC=PASS")


func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS %s" % description)
    else:
        failures.append(description)
        print("FAIL %s" % description)




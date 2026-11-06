extends SceneTree
## Fail-closed check: a candidate GLB whose character has no characters.list
## intro clip must not be given another character's intro.  Run with an
## opponent whose intro clip is absent from its candidate, e.g. the Master:
##
##   BRUCELEE_OPPONENT_GLB=...master_full_hair_80_result_20261103.glb
##   BRUCELEE_OPPONENT_NAME_KEY=master
##
## Expected: the attract flags for that fighter stay clear, SetState(0)
## refuses state 2, and the match falls back to the ordinary round intro.

const NativeMatchStates = preload("res://scripts/native_match_states.gd")

var failures: Array[String] = []


func _initialize() -> void:
    OS.set_environment("BRUCELEE_ATTRACT", "1")
    OS.set_environment("BRUCELEE_CONTINUE", "1")
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "1")
    var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
    root.add_child(main)
    for _i in 90:
        await process_frame

    var states = main.get("native_states")
    var player: Node = main.get("player")
    var computer: Node = main.get("computer")
    _expect(states != null, "main.tscn exposes native_states")
    if states == null:
        _finish(main)
        return
    # Keep this fixture on the first Bruce intro; the actual-draw coverage lives
    # in validate_remaining_cameras.gd.
    player.select_intro_clip(0)

    var player_clip: String = main.call("_intro_clip_for", player)
    var computer_clip: String = main.call("_intro_clip_for", computer)
    _expect(player_clip == "m01_intro_01",
        "the Bruce player still has its intro, got %s" % player_clip)
    _expect(computer_clip.is_empty(),
        "the opponent has no intro clip in this candidate, got %s" % computer_clip)
    _expect(not bool(states.attract_fighter1_available),
        "the missing opponent intro clears flag +0x831")

    # SetState(0) must route to state 1 only (fighter 0's intro), never state 2.
    _expect(int(states.set_state_zero_target(false)) == NativeMatchStates.STATE_ATTRACT_FIGHTER0,
        "SetState(0) still selects fighter 0's intro")
    # Even if a caller forces state 2, the module refuses.
    var refused: bool = not bool(states.enter(NativeMatchStates.STATE_ATTRACT_FIGHTER1, "", -1.0))
    _expect(refused, "state 2 refuses without an opponent intro clip")
    _expect(String(states.fail_reason).begins_with("no-candidate-clip"),
        "the refusal names the missing clip, got %s" % states.fail_reason)

    # The live attract plays fighter 0's intro and then falls back instead of
    # presenting the opponent with a borrowed animation.
    states.reset()
    main.call("_configure_attract_flags")
    main.set("_attract_played", false)
    main.call("_start_attract_or_intro")
    _expect(int(main.get("match_state")) == NativeMatchStates.STATE_ATTRACT_FIGHTER0,
        "the live attract still starts with fighter 0, got %d" % int(main.get("match_state")))
    var seconds: float = main.call("_intro_clip_seconds", player, player_clip)
    main.call("_update_match_state", seconds + 0.01)
    _expect(int(main.get("match_state")) == 3,
        "fighter 1's missing intro falls back to the round intro, got %d"
        % int(main.get("match_state")))
    _finish(main)


func _finish(main: Node) -> void:
    main.queue_free()
    if failures.is_empty():
        print("NATIVE_STATES_MISSING_INTRO=PASS")
        quit(0)
    else:
        for failure in failures:
            push_error("NATIVE_STATES_MISSING_INTRO_FAIL " + failure)
        print("NATIVE_STATES_MISSING_INTRO=FAIL count=%d" % failures.size())
        quit(1)


func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS %s" % description)
    else:
        failures.append(description)
        print("FAIL %s" % description)

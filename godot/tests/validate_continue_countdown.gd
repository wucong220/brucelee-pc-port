extends SceneTree
## Focused check for the recovered continue/countdown behaviour.
##
## 1. CBeatEmUpGame +0x850 (the native state-9 timeout) is recovered from
##    krm::CBruceLeeTrainingMode::TrainingSetStep: 3000 ms in the
##    no-animation branch (@0x1fa534, movw r3,#0xbb8) and
##    round(duration_seconds * 1000.0) in the other (@0x1faedc).  Unit is ms.
## 2. gui/continueask.ui's "countdown" label reads ["game","continuecountdown"],
##    answered by krm::CBeatEmUpMatch::QueryString @0x161b08:
##    (11000 - GetStateTime()) / 1000 clamped to 10 while the game is in state 6.
## 3. game.states "arcaderetryask" stores its timeout as the INTEGER action key
##    10, and the state manager's per-state clock fires integer keys at that many
##    seconds, so the arcade prompt times out after 10 s.
##
##   godot --headless --path <godot> --script res://tests/validate_continue_countdown.gd

const NativeMatchStates = preload("res://scripts/native_match_states.gd")

var failures: Array[String] = []


func _initialize() -> void:
    _check_constants()
    _check_countdown_curve()
    _check_ui_timeout()
    _check_native_timeout()
    _check_manual_choice()
    if failures.is_empty():
        print("CONTINUE_COUNTDOWN_VALIDATION=PASS")
        quit(0)
    else:
        for failure in failures:
            push_error("CONTINUE_COUNTDOWN_FAIL " + failure)
        print("CONTINUE_COUNTDOWN_VALIDATION=FAIL count=%d" % failures.size())
        quit(1)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _check_constants() -> void:
    _expect(NativeMatchStates.CONTINUE_NATIVE_TIMEOUT_DEFAULT_MS == 3000,
        "+0x850 default is the 0xbb8 (3000 ms) literal of TrainingSetStep")
    _expect(not String(NativeMatchStates.CONTINUE_NATIVE_TIMEOUT_SOURCE).is_empty(),
        "the +0x850 writer is named")
    _expect(NativeMatchStates.CONTINUE_COUNTDOWN_BUDGET_MS == 11000,
        "budget is the 11000 ms literal of CBeatEmUpMatch::QueryString")
    _expect(NativeMatchStates.CONTINUE_COUNTDOWN_CAP_SECONDS == 10,
        "the QueryString clamp is 10 seconds")
    _expect(NativeMatchStates.CONTINUE_TIMEOUT_KEY == 10,
        "game.states arcaderetryask timeout is integer action key 10")
    _expect(NativeMatchStates.CONTINUE_TIMEOUT_MS == 10000,
        "integer key 10 is 10 seconds of the per-state clock")
    _expect(not NativeMatchStates.CONTINUE_COUNTDOWN_UNRECOVERED,
        "+0x850 is no longer reported as unrecovered")


func _check_countdown_curve() -> void:
    var states = NativeMatchStates.new()
    states.reset()
    _expect(int(states.continue_countdown_seconds()) == -1,
        "the countdown is only defined inside state 9")
    _expect(bool(states.enter(NativeMatchStates.STATE_CONTINUE)),
        "state 9 enters")
    _expect(int(states.continue_countdown_seconds()) == 10,
        "t=0 shows 10 ((11000-0)/1000 = 11 clamped to 10), got %d"
        % states.continue_countdown_seconds())
    states.advance(0.999)
    _expect(int(states.continue_countdown_seconds()) == 10,
        "t=999 ms still shows 10")
    states.advance(0.001)
    _expect(int(states.continue_countdown_seconds()) == 10,
        "t=1000 ms shows 10 ((11000-1000)/1000), got %d"
        % states.continue_countdown_seconds())
    states.advance(1.0)
    _expect(int(states.continue_countdown_seconds()) == 9,
        "t=2000 ms shows 9, got %d" % states.continue_countdown_seconds())
    states.advance(7.999)
    _expect(int(states.continue_countdown_seconds()) == 1,
        "t=9999 ms shows 1, got %d" % states.continue_countdown_seconds())
    _expect(not bool(states.continue_resolved),
        "the prompt is still open just before the 10 s clock tick")


func _check_ui_timeout() -> void:
    var states = NativeMatchStates.new()
    states.reset()
    _expect(bool(states.enter(NativeMatchStates.STATE_CONTINUE)),
        "state 9 re-enters for the UI timeout test")
    states.advance(9.999)
    _expect(not bool(states.continue_resolved),
        "the integer key 10 has not fired at 9999 ms")
    states.advance(0.001)
    _expect(bool(states.continue_resolved),
        "the integer key 10 fires at 10000 ms")
    _expect(String(states.continue_choice) == NativeMatchStates.CONTINUE_ACTION_TIMEOUT,
        "the UI timeout resolves with the #10 action, got %s" % states.continue_choice)
    _expect(not bool(states.active), "the resolved prompt leaves state 9")


func _check_native_timeout() -> void:
    # +0x850: default 3000 ms, then a caller-supplied step duration.
    var states = NativeMatchStates.new()
    states.reset()
    _expect(bool(states.enter(NativeMatchStates.STATE_CONTINUE)),
        "state 9 re-enters for the native +0x850 test")
    states.continue_native_timeout_enabled = true
    states.advance(2.999)
    _expect(not bool(states.continue_resolved),
        "the 3000 ms +0x850 timer has not fired at 2999 ms")
    states.advance(0.001)
    _expect(bool(states.continue_resolved),
        "the 3000 ms +0x850 timer fires at 3000 ms")
    _expect(String(states.continue_choice) == NativeMatchStates.CONTINUE_ACTION_NEXT_TRAINING_STEP,
        "the native timeout resolves with nexttrainingstep, got %s"
        % states.continue_choice)

    states.reset()
    _expect(bool(states.enter(NativeMatchStates.STATE_CONTINUE)),
        "state 9 re-enters for the step-duration test")
    states.continue_native_timeout_enabled = true
    states.set_continue_native_timeout_ms(2500)
    _expect(int(states.continue_native_timeout_ms) == 2500,
        "the step-duration setter mirrors TrainingSetStep")
    states.advance(2.5)
    _expect(bool(states.continue_resolved),
        "a 2500 ms step duration fires at 2500 ms")


func _check_manual_choice() -> void:
    var states = NativeMatchStates.new()
    states.reset()
    _expect(bool(states.enter(NativeMatchStates.STATE_CONTINUE)),
        "state 9 re-enters for the manual-choice test")
    states.advance(1.0)
    _expect(states.choose_continue("maybe") == "",
        "an action outside arcaderetryask is rejected")
    states.move_continue_cursor(1)
    _expect(String(states.current_continue_option()) == "no",
        "the menu moves to the second continueask.ui option")
    _expect(states.choose_continue("no") == "no",
        "the 'no' action still resolves the prompt before the clock fires")
    _expect(not bool(states.active), "choosing 'no' leaves state 9")

extends RefCounted
class_name NativeMatchStates
## Recovered CBeatEmUpGame states that the port did not implement:
##   1  ATTRACT_FIGHTER0   SetState(1)  (ghidra-out5/SetState.c case 1,
##                         Update.c case 1)
##   2  ATTRACT_FIGHTER1   SetState(2)  (SetState.c case 2, Update.c case 2)
##   6  REPLAY             SetState(6)  (SetState.c case 6, Update.c case 6)
##   9  CONTINUE           SetState(9)  (SetState.c case 9, Update.c case 9)
##   10 CONTINUE_WAIT      Update.c case 10 falls into the default DummyUpdate
##                         branch; no SetState case exists for it.
##   14 COUNTDOWN          SetState(14) (SetState.c case 14, Update.c case 14
##                         shares the default DummyUpdate branch)
##
## Every constant below is taken from the decompiled functions or from the
## decoded archive resources (adreno_200/game.states, gui/*.ui,
## adreno_200/characters.list).  Where a value could not be recovered the
## state is marked `unrecovered` and the driver refuses to enter it: nothing
## here is invented.
##
## Sources (all read-only):
##   D:\BruceLeeWork\ghidra-out5\SetState.c, Update.c, CountdownEnded.c,
##   ghidra-out9\krm__CBeatEmUpMatch__QueryString.c,
##   libdefault.so (sha256 1da7a30c...) PlayerLost @ 0x190060,
##   adreno_200/game.states, gui/continueask.ui, gui/replaystats.ui.

const STATE_ATTRACT_FIGHTER0: int = 1
const STATE_ATTRACT_FIGHTER1: int = 2
const STATE_REPLAY: int = 6
const STATE_CONTINUE: int = 9
const STATE_CONTINUE_WAIT: int = 10
const STATE_COUNTDOWN: int = 14

const IMPLEMENTED_STATES: Array[int] = [
    STATE_ATTRACT_FIGHTER0, STATE_ATTRACT_FIGHTER1, STATE_CONTINUE,
]
## States whose recovered evidence is not sufficient to drive them.  The
## driver reports them and never enters them.
const UNRECOVERED_STATES: Array[int] = [
    STATE_REPLAY, STATE_CONTINUE_WAIT, STATE_COUNTDOWN,
]

# CBeatEmUpGame::SetState case 1/2 plays the free animation whose hash string
# sits at rodata 0x5b9440 ("Intro"); the same literal is the characters.list
# animation category decoded in character-anim-inventory-20261103/characters.json.
const INTRO_CATEGORY: String = "Intro"
# SetState case 14 plays the free animation at rodata 0x5b9450 ("Defeat") when
# the winner's round count is not strictly greater than the loser's, otherwise
# 0x5b9448 ("Victory").  Both hashes were resolved from the literal pool of
# SetState @ 0x178508 (libdefault.so).
const DEFEAT_CATEGORY: String = "Defeat"
const VICTORY_CATEGORY: String = "Victory"

# CBeatEmUpMatch::QueryString (ghidra-out9, verified against libdefault.so
# @ 0x161b08): while the match is in state 6 the displayed text is
# (11000 - GetStateTime()) / 1000, clamped to 10.  The 11000 ms budget is the
# only recovered countdown length and it belongs to the replay display, not to
# a separate timer resource.
const REPLAY_COUNTDOWN_BUDGET_MS: int = 11000
const REPLAY_COUNTDOWN_CAP_SECONDS: int = 10

# CBeatEmUpGame::Update case 9 leaves the state when
# GetStateTime() > *(this + 0x850).  No writer of +0x850 was recovered (the
# field is never stored in any decompiled function), so the continue length is
# fail-closed and state 9 cannot be timed out on its own.
# What *is* recovered is the UI state that SetState(9) hands control to:
# game.states "arcaderetryask" leaves on action "yes", "no", or on the trigger
# key "#10".  The "#N" action keys are verbatim from game.states, but the unit
# (seconds, ticks or an event id) was NOT recovered, so it is carried as a key
# only and never converted into a timer.
const CONTINUE_ACTIONS: Array[String] = ["yes", "no", "#10"]
const CONTINUE_COUNTDOWN_UNRECOVERED: bool = true

# game.states "arcaderetryask" actions, decoded verbatim.
const CONTINUE_ACTION_YES: String = "yes"
const CONTINUE_ACTION_NO: String = "no"
const CONTINUE_ACTION_TIMEOUT: String = "#10"
# gui/continueask.ui menu options, in archive order: ["yes","yes"], ["no","no"].
const CONTINUE_MENU_OPTIONS: Array[String] = ["yes", "no"]

# CBeatEmUpGame::CountdownEnded: true only while state == 14 and
# GetStateTime() > 9999.  State 14 itself has no recovered exit in Update
# (its case shares the default DummyUpdate branch), so the 9999 ms is an
# observation threshold, not a transition.
const COUNTDOWN_ENDED_AFTER_MS: int = 9999

# Update case 6 plays the replay at double speed:
#   vmov s16, [this+0x838]; vcvt.f32.u32; vadd.f32 s16, s16, s16; vcvt.u32.f32
# i.e. the sample passed to RecordReplayUpdate is GetStateTime() + 2*replay_base,
# so the recording advances twice as fast as real time.  The loop-back
# SetState(6) at the end of the recording is also recovered, but the replay
# buffer itself (RecordReplayUpdate) is not implemented in the port, so state
# 6 stays fail-closed.
const REPLAY_SPEED_FACTOR: int = 2

## advance() returns this when the active state finished and there is no
## follow-up state; -1 stays "still running".
const NO_TARGET_EXIT: int = -2

const REASON_OK: String = "ok"
const REASON_UNRECOVERED: String = "unrecovered"
const REASON_NO_CLIP: String = "no-candidate-clip"
const REASON_ALREADY_PLAYED: String = "intro-already-played"

var state: int = -1
var state_time: float = 0.0
var active: bool = false
var fail_reason: String = ""
## Attract bookkeeping.  SetState(0) picks state 1 when flag +0x830 is set and
## state 2 when +0x831 is set; the port exposes the same two booleans.
var attract_fighter0_available: bool = false
var attract_fighter1_available: bool = false
var attract_side: int = -1
var attract_clip: String = ""
var attract_clip_seconds: float = 0.0
## Continue bookkeeping.
var continue_menu_index: int = 0
var continue_choice: String = ""
var continue_resolved: bool = false
## Countdown observation (state 14).  Only meaningful if the state were
## entered, which the unrecovered gate prevents.
var countdown_ended: bool = false
## Ordered trace of every transition attempt: {state, result, reason, detail}.
var trace: Array = []


func reset() -> void:
    state = -1
    state_time = 0.0
    active = false
    fail_reason = ""
    attract_side = -1
    attract_clip = ""
    attract_clip_seconds = 0.0
    continue_menu_index = 0
    continue_choice = ""
    continue_resolved = false
    countdown_ended = false
    trace.clear()


## SetState(0) routing (SetState.c case 0): with the attract-already-played
## counter at +0x82c still 0, flag +0x830 selects state 1 and +0x831 selects
## state 2.  Returns the state that should be entered, or -1 when neither
## attract intro is available and the caller should keep its own routing.
func set_state_zero_target(attract_already_played: bool) -> int:
    if attract_already_played:
        return -1
    if attract_fighter0_available:
        return STATE_ATTRACT_FIGHTER0
    if attract_fighter1_available:
        return STATE_ATTRACT_FIGHTER1
    return -1


## Try to enter `next_state`.  Returns false (and records the reason) instead
## of entering when the state is unrecovered or its required data is missing.
## `clip_name` / `clip_seconds` describe the recovered free animation for the
## attract intros; pass an empty name when the candidate GLB has no such clip.
func enter(next_state: int, clip_name: String = "", clip_seconds: float = -1.0) -> bool:
    if next_state in UNRECOVERED_STATES:
        _fail(next_state, REASON_UNRECOVERED, _unrecovered_detail(next_state))
        return false
    if next_state == STATE_ATTRACT_FIGHTER0 or next_state == STATE_ATTRACT_FIGHTER1:
        return _enter_attract(next_state, clip_name, clip_seconds)
    if next_state == STATE_CONTINUE:
        return _enter_continue()
    _fail(next_state, REASON_UNRECOVERED, "no recovered entry path")
    return false


func _enter_attract(next_state: int, clip_name: String, clip_seconds: float) -> bool:
    var side: int = 0 if next_state == STATE_ATTRACT_FIGHTER0 else 1
    if clip_name.is_empty():
        # characters.list names the intro clip, but this candidate GLB does not
        # carry it.  Fail closed instead of playing another character's intro.
        _fail(next_state, REASON_NO_CLIP, "candidate GLB has no %s intro clip" % INTRO_CATEGORY)
        return false
    var available: bool = (
        attract_fighter0_available if side == 0 else attract_fighter1_available
    )
    if not available:
        _fail(next_state, REASON_ALREADY_PLAYED, "fighter %d attract flag is clear" % side)
        return false
    if clip_seconds < 0.0:
        _fail(next_state, REASON_NO_CLIP, "intro clip length was not recovered")
        return false
    _begin(next_state)
    attract_side = side
    attract_clip = clip_name
    attract_clip_seconds = clip_seconds
    trace.append({
        "state": next_state, "result": "entered", "reason": REASON_OK,
        "detail": "fighter %d plays %s (%.3f s)" % [side, clip_name, clip_seconds],
    })
    return true


func _enter_continue() -> bool:
    _begin(STATE_CONTINUE)
    continue_menu_index = 0
    continue_choice = ""
    continue_resolved = false
    trace.append({
        "state": STATE_CONTINUE, "result": "entered", "reason": REASON_OK,
        "detail": "arcaderetryask; +0x850 unrecovered, #N trigger unit unrecovered",
    })
    return true


## CBeatEmUpGame::Update for the active state.  `skip_pressed` is the port's
## stand-in for ConsumeSkipEvent(), which the decompiled Update calls in
## states 1 and 2.  Returns the state the machine moved to, or -1 when it
## stayed put.
func advance(delta: float, skip_pressed: bool = false) -> int:
    if not active:
        return -1
    state_time += maxf(delta, 0.0)
    match state:
        STATE_ATTRACT_FIGHTER0, STATE_ATTRACT_FIGHTER1:
            # Update case 1/2: leave when the clip's duration is exceeded or a
            # skip event is consumed.  The comparison is strict (duration <
            # state_time).  The destination depends on the remaining attract
            # flag and is resolved by the caller via attract_exit_target().
            if skip_pressed or state_time > attract_clip_seconds:
                return _complete_attract()
        STATE_CONTINUE:
            # No +0x850 value was recovered, so this state never times out by
            # itself.  The only exits are the two menu actions recovered from
            # game.states, applied through choose_continue().
            pass
    return -1


## Update case 1: after fighter 0's intro, state 2 plays when flag +0x831 is
## set, otherwise the caller returns to its own intro/fight routing.
## Update case 2 always returns to the caller's routing.
func attract_exit_target() -> int:
    if state == STATE_ATTRACT_FIGHTER0 and attract_fighter1_available:
        return STATE_ATTRACT_FIGHTER1
    return -1


func _complete_attract() -> int:
    var side: int = attract_side
    if side == 0:
        attract_fighter0_available = false
    elif side == 1:
        attract_fighter1_available = false
    var target: int = attract_exit_target()
    trace.append({
        "state": state, "result": "completed", "reason": REASON_OK,
        "detail": "fighter %d intro finished -> %s" % [side, str(target)],
    })
    if target == -1:
        _stop()
        return NO_TARGET_EXIT
    return target


## gui/continueask.ui options are ["yes", "no"]; the menu is a two-entry list,
## so only those two indices exist.
func move_continue_cursor(direction: int) -> void:
    if state != STATE_CONTINUE or continue_resolved:
        return
    var count: int = CONTINUE_MENU_OPTIONS.size()
    continue_menu_index = posmod(continue_menu_index + direction, count)


## Apply one of the recovered arcaderetryask actions.  Returns the action that
## was applied, or "" when the state is not the continue prompt.
func choose_continue(action: String) -> String:
    if state != STATE_CONTINUE or continue_resolved:
        return ""
    if action != CONTINUE_ACTION_YES and action != CONTINUE_ACTION_NO \
            and action != CONTINUE_ACTION_TIMEOUT:
        return ""
    continue_choice = action
    continue_resolved = true
    trace.append({
        "state": STATE_CONTINUE, "result": "resolved", "reason": REASON_OK,
        "detail": "arcaderetryask action %s" % action,
    })
    _stop()
    return action


func current_continue_option() -> String:
    if state != STATE_CONTINUE:
        return ""
    return CONTINUE_MENU_OPTIONS[continue_menu_index]


func describe() -> Dictionary:
    return {
        "state": state,
        "active": active,
        "state_time": state_time,
        "fail_reason": fail_reason,
        "attract_side": attract_side,
        "attract_clip": attract_clip,
        "attract_clip_seconds": attract_clip_seconds,
        "attract_fighter0_available": attract_fighter0_available,
        "attract_fighter1_available": attract_fighter1_available,
        "continue_menu_index": continue_menu_index,
        "continue_choice": continue_choice,
        "continue_resolved": continue_resolved,
        "continue_countdown_unrecovered": CONTINUE_COUNTDOWN_UNRECOVERED,
        "continue_timeout_action": CONTINUE_ACTION_TIMEOUT,
        "replay_countdown_budget_ms": REPLAY_COUNTDOWN_BUDGET_MS,
        "replay_speed_factor": REPLAY_SPEED_FACTOR,
        "countdown_ended_after_ms": COUNTDOWN_ENDED_AFTER_MS,
        "unrecovered_states": UNRECOVERED_STATES,
        "trace": trace,
    }


func _begin(next_state: int) -> void:
    state = next_state
    state_time = 0.0
    active = true
    fail_reason = ""


func _stop() -> void:
    active = false


func _fail(next_state: int, reason: String, detail: String) -> void:
    fail_reason = "%s: %s" % [reason, detail]
    trace.append({
        "state": next_state, "result": "refused", "reason": reason, "detail": detail,
    })


func _unrecovered_detail(next_state: int) -> String:
    match next_state:
        STATE_REPLAY:
            return "RecordReplayUpdate buffer is not recovered; only the 2x speed and the %d ms display budget are" % REPLAY_COUNTDOWN_BUDGET_MS
        STATE_CONTINUE_WAIT:
            return "Update case 10 has no body; no entry path writes state 10"
        STATE_COUNTDOWN:
            return "SetState case 14 needs the per-fighter round counters at +0x81c/+0x820, which this port does not keep"
    return "no recovered implementation"

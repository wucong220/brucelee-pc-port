extends RefCounted
class_name NativeMatchStates

const ReplayBufferScript = preload("res://scripts/replay_buffer.gd")
## Recovered CBeatEmUpGame states implemented by this driver, with the
## native evidence for each:
##   1  ATTRACT_FIGHTER0   SetState(1)  (ghidra-out5/SetState.c case 1,
##                         Update.c case 1)
##   2  ATTRACT_FIGHTER1   SetState(2)  (SetState.c case 2, Update.c case 2)
##   6  REPLAY             SetState(6)  (SetState.c case 6, Update.c case 6);
##                         consumes the recovered CFighter 0x2c buffers.
##   9  CONTINUE           SetState(9)  (SetState.c case 9, Update.c case 9)
##   10 CONTINUE_WAIT      SetState(10) has an empty body; Update.c case 10
##                         falls into the default DummyUpdate branch.  No
##                         native call site writes state 10, so this driver
##                         keeps it unrecovered/fail-closed.
##   14 COUNTDOWN          SetState(14) (SetState.c case 14, Update.c case 14
##                         shares the default DummyUpdate branch).  This is the
##                         story-mode DEFEAT presentation, entered from
##                         CBeatEmUpTriggers.cpp PlayerLost() @0x190060 when
##                         CBruceLeeStoryMode::StoryCurrentFightWinOnLose() is
##                         false (0x19022c -> 0x19049c -> SetState(14)).
##                         Its true half enters state 6 (0x19025c) instead.
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
##   libdefault.so (sha256 1da7a30c...): SetState @0x178508 (case 14 @0x1785f8),
##   Update @0x17c2ac (case 14 -> 0x17d334 DummyUpdate), CountdownEnded @0x187e78,
##   CameraUpdate @0x178d88, PlayerLost @0x190060, CBeatEmUpMatch::Update @0x162648,
##   adreno_200/game.states, gui/continueask.ui, gui/replaystats.ui.
##   Verified byte-for-byte by work/setstate14_exact.py, work/cases_12_13.py,
##   work/camera_and_modes.py and work/counters.py in the isolated output.

const STATE_ATTRACT_FIGHTER0: int = 1
const STATE_ATTRACT_FIGHTER1: int = 2
const STATE_REPLAY: int = 6
const STATE_CONTINUE: int = 9
const STATE_CONTINUE_WAIT: int = 10
const STATE_COUNTDOWN: int = 14

const IMPLEMENTED_STATES: Array[int] = [
    STATE_ATTRACT_FIGHTER0, STATE_ATTRACT_FIGHTER1, STATE_REPLAY,
    STATE_CONTINUE, STATE_COUNTDOWN,
]
## States whose recovered evidence is not sufficient to drive them.  The
## driver reports them and never enters them.
const UNRECOVERED_STATES: Array[int] = [
    STATE_CONTINUE_WAIT,
]

# CBeatEmUpGame::SetState case 1/2 plays the free animation whose hash string
# sits at rodata 0x5b9440 ("Intro"); the same literal is the characters.list
# animation category decoded in character-anim-inventory-20261103/characters.json.
const INTRO_CATEGORY: String = "Intro"
# SetState cases 12 (0x178ab0) and 13 (0x178b18) choose the result category by
# comparing the per-fighter round counters with an unsigned compare:
#   case 12 (fighter 0 visible): 0x81c > 0x820 -> "Victory" (0x5b9448),
#                                else          -> "Defeat"  (0x5b9450)
#   case 13 (fighter 1 visible): 0x820 > 0x81c -> "Victory",
#                                else          -> "Defeat"
# SetState case 14 does NOT branch: it always plays "Defeat" (see below).  The
# literals were resolved from the SetState literal pool (work/cases_12_13.py).
const DEFEAT_CATEGORY: String = "Defeat"
const VICTORY_CATEGORY: String = "Victory"

# SetState case 14 (@0x1785f8), the recovered body, in order:
#   f0 = this + 0x24 (fighter 0);  f1 = this + 0x1dc (fighter 1)
#   f0->SetVisible(true);          f1->SetVisible(false)
#   f0->SetPosToOrigin();          f1->SetPosToOrigin()
#   CBeatEmUpGame::StopCameraAnimation()
#   HashString h("Defeat" @0x5b9450)
#   f0->SetAnimation(h, this[0x7f8], 0, 1, 0.0f)   # 0x178634..0x178674
# Update case 14 (@0x17c2ec -> 0x17d334) only DummyUpdates both fighters.
# CountdownEnded() (@0x187e78) is true only in state 14 once GetStateTime() >
# 9999; CBeatEmUpMatch::Update then raises the gui action "COUNTDOWNEND"
# (0x162828..0x16282c) instead of calling CBeatEmUpGame::Update.
const COUNTDOWN_CATEGORY: String = DEFEAT_CATEGORY
const COUNTDOWN_ACTION: String = "COUNTDOWNEND"
## CameraUpdate's state-14 path is the `else` branch: dummy fighter = this[0x7e0]
## (the local player, slot 0) and the swap/mirror flag is 0.
const COUNTDOWN_CAMERA_FIGHTER: int = 0
const COUNTDOWN_CAMERA_SWAP: int = 0

# The per-fighter round-win counters the earlier port claimed state 14 needed.
# They live on CBeatEmUpGame as uint32: +0x81c = fighter 0, +0x820 = fighter 1.
# Reset to 0 by CBeatEmUpMatch::OnEnter (0x161dc4/0x161dcc) and
# CBeatEmUpMatch::Restart (0x161e0c/0x161e14); incremented in
# CBeatEmUpGame::Update case 4 when a fighter is defeated (increment stores at
# 0x17d1a8, 0x17d45c, 0x17d78c, 0x17d880, 0x17d8ac, 0x17d920).  They are read by
# Update case 11, SetState 12/13 and CBeatEmUpMatch::Update -- never by 14.
const ROUND_COUNTER_FIGHTER0_OFFSET: int = 0x81c
const ROUND_COUNTER_FIGHTER1_OFFSET: int = 0x820

# CBeatEmUpMatch::QueryString (ghidra-out9, verified against libdefault.so
# @ 0x161b08): while the match is in state 6 the displayed text is
# (11000 - GetStateTime()) / 1000, clamped to 10.  The 11000 ms budget is the
# only recovered countdown length and it belongs to the replay display, not to
# a separate timer resource.
const REPLAY_COUNTDOWN_BUDGET_MS: int = 11000
const REPLAY_COUNTDOWN_CAP_SECONDS: int = 10

# CBeatEmUpGame::Update case 9 leaves the state when
# GetStateTime() > *(this + 0x850).  The field IS recovered (2026-11-04):
# krm::CBruceLeeTrainingMode::TrainingSetStep(CBeatEmUpMatch *) writes it on the
# CBeatEmUpGame object (match + 0x14):
#   * @0x1fa534  movw r3,#0xbb8 ; str r3,[game,#0x850]      -> 3000 ms
#     (the branch with no step-animation descriptor, r8 == 0);
#   * @0x1faedc  r3 = (uint)(duration_seconds * 1000.0)
#                ; str r3,[game,#0x850]                       -> animation length
#     taken from the step descriptor [sp+0x60]+4; the 1000.0f literal is at
#     0x1fb200.
# Unit: milliseconds (the same clock as GetStateTime()).  On expiry Update case
# 9 calls SetState(15) and RaiseAction("NEXTTRAININGSTEP"): this is the training
# step timer, not the arcade continue prompt.
const CONTINUE_NATIVE_TIMEOUT_DEFAULT_MS: int = 3000
const CONTINUE_NATIVE_TIMEOUT_SOURCE: String = (
    "krm::CBruceLeeTrainingMode::TrainingSetStep @0x1fa534/0x1faedc"
)
const CONTINUE_ACTION_NEXT_TRAINING_STEP: String = "nexttrainingstep"

# The arcade continue prompt is a different mechanism.  gui/continueask.ui binds
# its "countdown" label to the datasource ["game","continuecountdown"], created
# by CBeatEmUpMatch::CreateQuery (@0x162174, "continueCountDown" @0x5b8b18) and
# answered by CBeatEmUpMatch::QueryString (@0x161b08): empty while the query id
# is non-zero, a single space unless the native game is in state 6, and
# (11000 - GetStateTime()) / 1000 clamped to 10 while it is.  PlayerLost
# (@0x1902bc) starts state 6 and the UI state "ArcadeRetryAsk" together.
const CONTINUE_COUNTDOWN_BUDGET_MS: int = 11000
const CONTINUE_COUNTDOWN_CAP_SECONDS: int = 10

# game.states "arcaderetryask" actions.  Its timeout is the INTEGER dictionary
# key 10 (not a "#10" string): the CTX3 action maps mix string keys (named
# events) with integer keys, and the state manager implements integer keys as
# clock ticks.  SetState sets impl->seconds = -1 and clockStart = now
# (@0x484674..0x484684); PreUpdate turns elapsed ms into seconds (/1000,
# @0x4853dc..0x485450) and raises the action "clock" once per second;
# RaiseAction's clock branch fires an entry only when entry->tick ==
# impl->seconds (@0x484da4..0x484dbc).  Integer key 10 therefore fires 10 s
# after the state becomes active (#0 fires on the first update).
const CONTINUE_TIMEOUT_KEY: int = 10
const CONTINUE_TIMEOUT_MS: int = CONTINUE_TIMEOUT_KEY * 1000
const CONTINUE_ACTIONS: Array[String] = ["yes", "no", "#10",
        CONTINUE_ACTION_NEXT_TRAINING_STEP]
const CONTINUE_COUNTDOWN_UNRECOVERED: bool = false

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

# Update case 6 (@0x18d0ac) builds the sample as GetStateTime() + 2*replay_base
# (vmov s16,[this+0x838]; vcvt.f32.u32; vadd.f32 s16,s16,s16; vcvt.u32.f32).
# SetState case 6 also calls SetSpeed(0.5f) (@0x188968, mov r1,#0x3f000000),
# which writes fighter +0x140 = 0.5.  RecordReplayUpdate compares
#   record.time <= sample * fighter[+0x140]
# so the reached record time is 0.5*(elapsed + 2*base) = base + 0.5*elapsed:
# the replay starts at the state-4 fight-start time and advances at HALF speed
# (0.5x).  The literal 2 is a base-offset compensation, NOT a 2x rate multiplier.
const REPLAY_SPEED_FACTOR: int = 2
const REPLAY_STATE_SPEED_SCALE: float = 0.5

## advance() returns this when the active state finished and there is no
## follow-up state; -1 stays "still running".
const NO_TARGET_EXIT: int = -2

const REASON_OK: String = "ok"
const REASON_UNRECOVERED: String = "unrecovered"
const REASON_NO_CLIP: String = "no-candidate-clip"
const REASON_ALREADY_PLAYED: String = "intro-already-played"
const REASON_NO_REPLAY: String = "no-replay-buffer"
const REASON_REPLAY_SCALE: String = "unrecovered-replay-scale"

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
## Time spent in the continue prompt (drives the recovered UI countdown and the
## game.states integer-key timeout).
var continue_elapsed_ms: float = 0.0
## The recovered +0x850 value.  Default 3000 ms mirrors TrainingSetStep's
## no-animation branch; a training flow can pass round(seconds*1000) through
## set_continue_native_timeout_ms().  It is only enforced when
## continue_native_timeout_enabled is true (training step flow).
var continue_native_timeout_ms: int = CONTINUE_NATIVE_TIMEOUT_DEFAULT_MS
var continue_native_timeout_enabled: bool = false
## Countdown (state 14) bookkeeping.  SetState(14) records the defeat clip it
## played and the camera sub-animation that belongs to that clip.  The state has
## no exit of its own; `countdown_ended` mirrors CountdownEnded() (> 9999 ms).
var countdown_clip: String = ""
var countdown_seconds: float = 0.0
var countdown_camera: String = ""
var countdown_ended: bool = false
## Replay (state 6).  `replay_buffers` must hold two ReplayBuffer objects whose
## records were produced by the recovered 0x2c SetAnimation append path.
## `replay_base_ms` is game +0x838 (the +0x7f8 match clock when state 4 was
## entered).  `replay_speed_scale` is fighter +0x140 (0.5 in state 6).
var replay_buffers: Array = []
var replay_base_ms: int = 0
var replay_speed_scale: float = REPLAY_STATE_SPEED_SCALE
var replay_loops: int = 0
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
    countdown_clip = ""
    countdown_seconds = 0.0
    countdown_camera = ""
    replay_buffers.clear()
    replay_base_ms = 0
    replay_speed_scale = REPLAY_STATE_SPEED_SCALE
    replay_loops = 0
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
## `clip_name` / `clip_seconds` describe the recovered free animation: the
## attract intro clip (states 1/2) or the defeat result clip (state 14).
## `camera_clip` is the camera sub-animation the port plays for state 14.
func enter(next_state: int, clip_name: String = "", clip_seconds: float = -1.0,
        camera_clip: String = "") -> bool:
    if next_state in UNRECOVERED_STATES:
        _fail(next_state, REASON_UNRECOVERED, _unrecovered_detail(next_state))
        return false
    if next_state == STATE_ATTRACT_FIGHTER0 or next_state == STATE_ATTRACT_FIGHTER1:
        return _enter_attract(next_state, clip_name, clip_seconds)
    if next_state == STATE_CONTINUE:
        return _enter_continue()
    if next_state == STATE_REPLAY:
        return _enter_replay()
    if next_state == STATE_COUNTDOWN:
        return _enter_countdown(clip_name, clip_seconds, camera_clip)
    _fail(next_state, REASON_UNRECOVERED, "no recovered entry path")
    return false


## SetState(14): fighter 0 plays the "Defeat" free animation; fighter 1 is
## hidden.  The driver keeps the clip and its camera sub-animation; either one
## missing is refused rather than approximated.
func _enter_countdown(defeat_clip: String, defeat_seconds: float,
        camera_clip: String) -> bool:
    if defeat_clip.is_empty() or defeat_seconds <= 0.0:
        _fail(STATE_COUNTDOWN, REASON_NO_CLIP,
            "candidate GLB has no %s result clip" % COUNTDOWN_CATEGORY)
        return false
    if camera_clip.is_empty():
        _fail(STATE_COUNTDOWN, REASON_NO_CLIP,
            "no recovered defeat camera for %s" % defeat_clip)
        return false
    _begin(STATE_COUNTDOWN)
    countdown_clip = defeat_clip
    countdown_seconds = defeat_seconds
    countdown_camera = camera_clip
    countdown_ended = false
    trace.append({
        "state": STATE_COUNTDOWN, "result": "entered", "reason": REASON_OK,
        "detail": ("fighter 0 plays %s (%.3f s), camera %s; CountdownEnded at "
                   + "%d ms, then %s") % [defeat_clip, defeat_seconds,
                   camera_clip, COUNTDOWN_ENDED_AFTER_MS, COUNTDOWN_ACTION],
    })
    return true


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
    continue_elapsed_ms = 0.0
    continue_native_timeout_ms = CONTINUE_NATIVE_TIMEOUT_DEFAULT_MS
    trace.append({
        "state": STATE_CONTINUE, "result": "entered", "reason": REASON_OK,
        "detail": ("arcaderetryask; native +0x850 timeout recovered from "
                   + CONTINUE_NATIVE_TIMEOUT_SOURCE + " (3000 ms default), "
                   + "UI countdown is CBeatEmUpMatch::QueryString (11000 ms, "
                   + "cap 10 s), integer action key 10 fires after 10 s"),
    })
    return true


## The number gui/continueask.ui displays, computed exactly as
## CBeatEmUpMatch::QueryString does while the game is in the replay state:
## (11000 - elapsed) / 1000, clamped to [0, 10].  Returns -1 outside state 9.
func continue_countdown_seconds() -> int:
    if state != STATE_CONTINUE:
        return -1
    var remaining_ms: float = float(CONTINUE_COUNTDOWN_BUDGET_MS) - continue_elapsed_ms
    var seconds: int = int(floor(remaining_ms / 1000.0))
    return clampi(seconds, 0, CONTINUE_COUNTDOWN_CAP_SECONDS)


## Mirrors krm::CBruceLeeTrainingMode::TrainingSetStep: 3000 for the branch with
## no step animation, or round(step_duration_seconds * 1000.0) otherwise.
func set_continue_native_timeout_ms(milliseconds: int) -> void:
    continue_native_timeout_ms = maxi(0, milliseconds)


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
            # Two recovered clocks.  The native +0x850 training-step timer
            # (3000 ms default) is applied when a training flow enables it; the
            # arcade ArcadeRetryAsk prompt uses the integer action key 10 (10 s)
            # of game.states.
            if continue_resolved:
                return -1
            continue_elapsed_ms += maxf(delta, 0.0) * 1000.0
            if (continue_native_timeout_enabled
                    and continue_elapsed_ms >= float(continue_native_timeout_ms)):
                continue_choice = CONTINUE_ACTION_NEXT_TRAINING_STEP
                continue_resolved = true
                trace.append({
                    "state": STATE_CONTINUE, "result": "resolved",
                    "reason": REASON_OK,
                    "detail": "+0x850 (TrainingSetStep) fired at %d ms"
                              % continue_native_timeout_ms,
                })
                _stop()
            elif continue_elapsed_ms >= float(CONTINUE_TIMEOUT_MS):
                continue_choice = CONTINUE_ACTION_TIMEOUT
                continue_resolved = true
                trace.append({
                    "state": STATE_CONTINUE, "result": "resolved",
                    "reason": REASON_OK,
                    "detail": "arcaderetryask integer action key %d fired after %.0f ms"
                              % [CONTINUE_TIMEOUT_KEY, continue_elapsed_ms],
                })
                _stop()
        STATE_REPLAY:
            _advance_replay()
        STATE_COUNTDOWN:
            # Update case 14 is the default DummyUpdate branch: both fighters
            # are dummy-updated and the state never leaves on its own.
            # CountdownEnded() = (state == 14) && GetStateTime() > 9999 ms.
            countdown_ended = int(floor(state_time * 1000.0)) > COUNTDOWN_ENDED_AFTER_MS
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


## Supply the two recorded buffers before entering state 6.  `base_ms` is game
## +0x838: the +0x7f8 match clock captured when state 4 (FIGHT) was entered.
func set_replay_buffers(player_buffer, computer_buffer, base_ms: int) -> void:
    replay_buffers = [player_buffer, computer_buffer]
    replay_base_ms = int(base_ms)
    replay_speed_scale = REPLAY_STATE_SPEED_SCALE


## SetState case 6: SetSpeed(0.5) on both fighters, disable their recording flag,
## SetReplayCurrentTime(fighter, replay_base), SetVisible, SetPosToFightStartPos.
## The port cannot synthesise a native buffer, so a missing/empty buffer fails
## closed instead of inventing one.
func _enter_replay() -> bool:
    if replay_buffers.size() != 2:
        _fail(STATE_REPLAY, REASON_NO_REPLAY, "two recorded fighter buffers are required")
        return false
    for i in 2:
        var buffer = replay_buffers[i]
        if buffer == null:
            _fail(STATE_REPLAY, REASON_NO_REPLAY, "fighter %d buffer is null" % i)
            return false
        if int(buffer.size()) < 1:
            _fail(STATE_REPLAY, REASON_NO_REPLAY, "fighter %d buffer is empty" % i)
            return false
    if not is_equal_approx(replay_speed_scale, REPLAY_STATE_SPEED_SCALE):
        _fail(STATE_REPLAY, REASON_REPLAY_SCALE,
            "fighter +0x140 must be the recovered 0.5, got %.3f" % replay_speed_scale)
        return false
    _begin(STATE_REPLAY)
    for i in 2:
        replay_buffers[i].set_replay_current_time(replay_base_ms)
    replay_loops = 0
    trace.append({
        "state": STATE_REPLAY, "result": "entered", "reason": REASON_OK,
        "detail": "replay_base=%d ms speed_scale=%.3f" % [replay_base_ms, replay_speed_scale],
    })
    return true


## Update case 6: sample = GetStateTime() + 2*replay_base, then one
## RecordReplayUpdate per fighter.  When both ReplayEnded, SetState(6) re-enters
## the same state (native loop); emulate by resetting the state clock and cursor.
func _advance_replay() -> void:
    var elapsed_ms: int = int(round(state_time * 1000.0))
    var sample_ms: int = elapsed_ms + REPLAY_SPEED_FACTOR * replay_base_ms
    var all_ended: bool = true
    for i in 2:
        var buffer = replay_buffers[i]
        buffer.record_replay_update(sample_ms, replay_speed_scale)
        if not bool(buffer.replay_ended()):
            all_ended = false
    if all_ended:
        replay_loops += 1
        state_time = 0.0
        for i in 2:
            replay_buffers[i].set_replay_current_time(replay_base_ms)
        trace.append({
            "state": STATE_REPLAY, "result": "loop", "reason": REASON_OK,
            "detail": "ReplayEnded both fighters -> SetState(6), loop=%d" % replay_loops,
        })


## QueryString state 6 text: (11000 - GetStateTime()) / 1000 capped to 10.
func replay_countdown_seconds() -> int:
    return ReplayBufferScript.replay_countdown_seconds(int(floor(state_time * 1000.0)))


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
        "continue_native_timeout_ms": continue_native_timeout_ms,
        "continue_native_timeout_enabled": continue_native_timeout_enabled,
        "continue_native_timeout_source": CONTINUE_NATIVE_TIMEOUT_SOURCE,
        "continue_countdown_budget_ms": CONTINUE_COUNTDOWN_BUDGET_MS,
        "continue_countdown_cap_seconds": CONTINUE_COUNTDOWN_CAP_SECONDS,
        "continue_elapsed_ms": continue_elapsed_ms,
        "continue_countdown_seconds": continue_countdown_seconds(),
        "continue_timeout_key": CONTINUE_TIMEOUT_KEY,
        "continue_timeout_ms": CONTINUE_TIMEOUT_MS,
        "continue_timeout_action": CONTINUE_ACTION_TIMEOUT,
        "replay_countdown_budget_ms": REPLAY_COUNTDOWN_BUDGET_MS,
        "replay_speed_factor": REPLAY_SPEED_FACTOR,
        "replay_speed_scale": REPLAY_STATE_SPEED_SCALE,
        "replay_buffers": replay_buffers.size(),
        "replay_base_ms": replay_base_ms,
        "replay_loops": replay_loops,
        "replay_countdown_seconds": replay_countdown_seconds() if state == STATE_REPLAY else -1,
        "countdown_clip": countdown_clip,
        "countdown_seconds": countdown_seconds,
        "countdown_camera": countdown_camera,
        "countdown_ended": countdown_ended,
        "countdown_end_after_ms": COUNTDOWN_ENDED_AFTER_MS,
        "countdown_end_action": COUNTDOWN_ACTION,
        "countdown_camera_fighter": COUNTDOWN_CAMERA_FIGHTER,
        "countdown_camera_swap": COUNTDOWN_CAMERA_SWAP,
        "round_counter_fighter0_offset": ROUND_COUNTER_FIGHTER0_OFFSET,
        "round_counter_fighter1_offset": ROUND_COUNTER_FIGHTER1_OFFSET,
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
            return "state 6 requires two recorded buffers; missing buffer data is refused, not invented"
        STATE_CONTINUE_WAIT:
            return "Update case 10 has no body; no entry path writes state 10"
    return "no recovered implementation"

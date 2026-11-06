extends SceneTree
## Headless validation of the recovered TIME_IS_UP -> PlayerLost -> SetState(14)
## path, driven through the real scenes/main.tscn.
##
## Recovered anchors (libdefault.so, SHA-256 1da7a30c...):
##   CBeatEmUpGame::Update @0x17c1bc, dispatch @0x17c2ac, state = game+0x7e8
##     case 4 (FIGHT) @0x17d1b0 -> GetCurrentTimer()==0 -> SetState(5) @0x17d84c
##     case 5 (TIME_IS_UP) @0x17d140: after GetStateTime() > 3000 it compares
##       fighter0 health (game+0x24+0x144) with fighter1 (game+0x1dc+0x144):
##         equal          -> SetState(11) @0x17d998 (DRAW)
##         fighter0 more  -> +0x81c, SetState(7) @0x17d8b0
##         fighter0 less  -> +0x820, SetState(8) @0x17d884
##   CBeatEmUpMatch::Update @0x162648: RoundEnded() @0x177e64 (state == 15)
##     -> compare +0x81c / +0x820 with [match+0x48] (TMatchConfig rounds-to-win)
##     -> RaiseAction("FIGHTER1WON") @0x162bf0 -> trigger Fighter1Won @0x190d5c
##     -> PlayerLost @0x190060, mode 1 -> StoryCurrentFightWinOnLose()==false
##     -> 0x19049c -> GetCurrentTimer -> SetState(14) @0x1904c8
##     win_on_lose true -> SetState(6) @0x19025c -> CurrentGameModeFightWon
##       -> StoryModeSubEventFightHasReplay: replay | StopMusic+StoryFightWon
##
## The +0x81c / +0x820 counters are the same ones state 5 bumps on a time-up,
## so a round-timeout match loss reaches state 14 through the recovered
## match-loss trigger, in the recovered 13 -> 15 -> 14 order.
##
##   godot --headless --path <godot> --script res://tests/validate_timeup_defeat.gd \
##       -- <bruce_candidate.glb> <brick_candidate.glb>

const NativeMatchStates = preload("res://scripts/native_match_states.gd")
const StoryFlowScript = preload("res://scripts/story_flow.gd")
const StoryStateScript = preload("res://scripts/story_state.gd")
const StoryDataScript = preload("res://scripts/story_data.gd")
const StoryLangScript = preload("res://scripts/story_lang.gd")

const STATE_TIME_UP: int = 5
const STATE_KO_LOSE: int = 8
const STATE_MATCH_LOSE: int = 13
const STATE_ROUND_END: int = 15
const STATE_COUNTDOWN: int = 14

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("expected <bruce.glb> <brick.glb>")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    OS.set_environment("BRUCELEE_STORY_FLOW", "0")
    OS.set_environment("BRUCELEE_GAME_MODE", "")
    OS.set_environment("BRUCELEE_REPLAY_RECORD", "")
    OS.set_environment("BRUCELEE_ATTRACT", "")
    OS.set_environment("BRUCELEE_CONTINUE", "")
    await _run()


func _check(condition: bool, label: String, detail: String = "") -> void:
    checks += 1
    if condition:
        print("PASS  " + label)
        return
    var line: String = label + ((" | " + detail) if not detail.is_empty() else "")
    failures.append(line)
    push_error("TIMEUP_DEFEAT_FAIL " + line)


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    _check(packed != null, "real scenes/main.tscn loads")
    if packed == null:
        _finish()
        return
    var main: Node = packed.instantiate()
    root.add_child(main)
    for _i in 6:
        await process_frame
    main.set_physics_process(false)
    main.set_process(false)
    var player: PortFighter = main.get("player")
    var computer: PortFighter = main.get("computer")
    var states = main.get("native_states")
    _check(player != null and computer != null and states != null,
        "main.tscn builds both fighters and the native state module")
    if player == null or computer == null or states == null:
        main.queue_free()
        _finish()
        return
    player.set_physics_process(false)
    computer.set_physics_process(false)
    _check(bool(player.candidate_loaded) and bool(computer.candidate_loaded),
        "both candidate GLBs loaded",
        "player=%s computer=%s" % [player.candidate_loaded, computer.candidate_loaded])

    _check_constants()
    _check_negative_control(main, player, computer, states)
    _check_story_timeup_defeat(main, player, computer, states)
    _check_story_timeup_winonlose_replay_unavailable(main, player, computer, states)
    _check_story_timeup_winonlose_no_replay(main, player, computer, states)
    _check_fail_closed(main, player, computer, states)

    main.queue_free()
    _finish()


func _finish() -> void:
    if failures.is_empty():
        print("TIMEUP_DEFEAT_VALIDATION=PASS checks=%d" % checks)
        quit(0)
        return
    for failure: String in failures:
        push_error("TIMEUP_DEFEAT_FAIL " + failure)
    print("TIMEUP_DEFEAT_VALIDATION=FAIL checks=%d failures=%d" % [
        checks, failures.size(),
    ])
    quit(1)


func _check_constants() -> void:
    _check(int(NativeMatchStates.STATE_COUNTDOWN) == 14, "state 14 constant is 14")
    _check(NativeMatchStates.STATE_COUNTDOWN in NativeMatchStates.IMPLEMENTED_STATES,
        "state 14 is implemented in NativeMatchStates")
    _check(int(NativeMatchStates.COUNTDOWN_ENDED_AFTER_MS) == 9999,
        "CountdownEnded threshold is the recovered 9999 ms")
    _check(NativeMatchStates.COUNTDOWN_ACTION == "COUNTDOWNEND",
        "state 14 hands off with the recovered COUNTDOWNEND action")
    _check(int(NativeMatchStates.ROUND_COUNTER_FIGHTER0_OFFSET) == 0x81c,
        "round counter fighter 0 is +0x81c")
    _check(int(NativeMatchStates.ROUND_COUNTER_FIGHTER1_OFFSET) == 0x820,
        "round counter fighter 1 is +0x820")


# --------------------------------------------------------------- fixtures

func _attach_flow(main: Node, win_on_lose: bool, kind: String = "vsbattle") -> Node:
    var flow = StoryFlowScript.new()
    root.add_child(flow)
    flow.set("main", main)
    var run: Dictionary = {
        "kind": kind, "chapter": "chapter1", "event": "timeup_defeat_test",
        "event_type": kind, "sub_index": 9999, "opponents": ["brick"],
        "opponent_index": 0, "player": "brucelee", "scenery": "",
        "difficulty_slot": 0, "difficulty_value": 0, "fights_done": 0,
        "elapsed_seconds": 0.0, "fight_results": [], "carried_health": -1.0,
        "source": {}, "win_on_lose": "true" if win_on_lose else "false",
    }
    flow.battle_run = run
    flow.battle_spec = {"opponent": "brick"}
    flow.battle_started_msec = Time.get_ticks_msec()
    var story_state = StoryStateScript.new()
    story_state.difficulty_slot = 0
    story_state.save_slot = 0
    story_state.set_pending({
        "run": run, "spec": {"opponent": "brick"},
        "started_msec": Time.get_ticks_msec(), "save_slot": 0,
        "chapter_index": 0, "event_index": 0, "unlock_mark": 0,
    })
    flow.state = story_state
    flow.data = StoryDataScript.new()
    flow.lang = StoryLangScript.new()
    main.set("story_flow", flow)
    OS.set_environment("BRUCELEE_STORY_FLOW", "1")
    return flow


func _detach_flow(main: Node, flow: Node) -> void:
    main.set("story_flow", null)
    OS.set_environment("BRUCELEE_STORY_FLOW", "0")
    if flow != null and is_instance_valid(flow):
        root.remove_child(flow)
        flow.free()


## Reset the port state machine to the exact pre-time-up frame of the native
## Update state 4: round 1, 0-0, both fighters alive, player behind on health.
func _force_time_up_frame(main: Node, player: PortFighter, computer: PortFighter) -> void:
    main.call("_reset_match")
    main.set("rounds_to_win", 1)
    main.set("round_number", 1)
    main.set("player_rounds", 0)
    main.set("computer_rounds", 0)
    main.set("pending_round_winner", 0)
    main.set("match_state", 4)          # MATCH_STATE_FIGHT
    main.set("match_state_time", 0.0)
    main.set("done", false)
    main.set("match_over", false)
    main.set("_round_end_handled", false)
    main.set("_replay_handed_off", false)
    main.set("round_time_active", true)
    main.set("round_time_max", 1)
    main.set("round_time_left", 0)
    var gm: Variant = main.get("game_modes")
    if gm != null:
        gm.set("current_fight_won", false)
    # State 5 compares fighter0 health < fighter1 health -> computer scores.
    player.health = 20.0
    computer.health = 80.0


## Walk states 4 -> 5 -> 8 -> 13 -> 15 the way Update/CBeatEmUpMatch do.
## Returns the state reached after the round-end handler.
func _drive_time_up_to_round_end(main: Node) -> int:
    main.call("_on_time_up")
    if int(main.get("match_state")) != STATE_TIME_UP:
        return int(main.get("match_state"))
    main.call("_update_match_state", 3.1)   # state 5 waits 3000 ms
    if int(main.get("match_state")) != STATE_KO_LOSE:
        return int(main.get("match_state"))
    main.call("_update_match_state", 3.1)   # states 7/8/11 wait 3000 ms
    if int(main.get("match_state")) != STATE_MATCH_LOSE:
        return int(main.get("match_state"))
    main.call("_update_match_state", float(main.get("_result_pose_seconds")) + 0.2)
    if int(main.get("match_state")) != STATE_ROUND_END:
        return int(main.get("match_state"))
    main.call("_update_match_state", 0.1)   # RoundEnded -> CBeatEmUpMatch::Update
    return int(main.get("match_state"))


# --------------------------------------------------------------- checks

func _check_negative_control(main: Node, player: PortFighter, computer: PortFighter,
        states) -> void:
    ## Non-story time-up loss keeps the pre-existing result flow; state 14 is a
    ## story-mode branch and must not be invented for other modes.
    main.set("story_flow", null)
    OS.set_environment("BRUCELEE_STORY_FLOW", "0")
    states.reset()
    _force_time_up_frame(main, player, computer)
    var reached: int = _drive_time_up_to_round_end(main)
    _check(reached != STATE_COUNTDOWN,
        "non-story time-up loss does not enter state 14 (fail closed)",
        "match_state=%d" % reached)
    _check(int(main.get("computer_rounds")) == 1 and int(main.get("player_rounds")) == 0,
        "non-story time-up loss awards the round to fighter 1",
        "player=%d computer=%d" % [int(main.get("player_rounds")), int(main.get("computer_rounds"))])
    _check(bool(main.get("match_over")), "non-story time-up loss still ends the match")


func _check_story_timeup_defeat(main: Node, player: PortFighter, computer: PortFighter,
        states) -> void:
    var flow: Node = _attach_flow(main, false)
    states.reset()
    _force_time_up_frame(main, player, computer)
    var clips: Dictionary = player.get("_candidate_clip_paths")
    _check(clips.has("m01_defeat_01"),
        "player candidate carries m01_defeat_01 (characters.list defeat)")
    _check(String(main.call("_defeat_camera_clip", "m01_defeat_01")) == "m01_defeat_01",
        "defeat_camera_map maps m01_defeat_01 to its camera")

    main.call("_on_time_up")
    _check(int(main.get("match_state")) == STATE_TIME_UP,
        "clock zero enters SetState(5) TIME_IS_UP",
        "match_state=%d" % int(main.get("match_state")))
    main.call("_update_match_state", 3.1)
    _check(int(main.get("match_state")) == STATE_KO_LOSE,
        "time-up health compare enters SetState(8) (fighter 1 scored)",
        "match_state=%d" % int(main.get("match_state")))
    _check(int(main.get("computer_rounds")) == 1 and int(main.get("player_rounds")) == 0,
        "time-up round increments the recovered +0x820 counter",
        "player=%d computer=%d" % [int(main.get("player_rounds")), int(main.get("computer_rounds"))])
    main.call("_update_match_state", 3.1)
    _check(int(main.get("match_state")) == STATE_MATCH_LOSE,
        "round result enters SetState(13) winner-only pose",
        "match_state=%d" % int(main.get("match_state")))
    main.call("_update_match_state", float(main.get("_result_pose_seconds")) + 0.2)
    _check(int(main.get("match_state")) == STATE_ROUND_END,
        "result pose enters SetState(15) RoundEnded",
        "match_state=%d" % int(main.get("match_state")))
    main.call("_update_match_state", 0.1)

    _check(int(main.get("match_state")) == STATE_COUNTDOWN,
        "RoundEnded + FIGHTER1WON + PlayerLost enters SetState(14)",
        "match_state=%d" % int(main.get("match_state")))
    _check(int(states.state) == STATE_COUNTDOWN,
        "NativeMatchStates records the state-14 entry")
    _check(bool(player.visible) and not bool(computer.visible),
        "SetState(14) shows fighter 0 and hides fighter 1")
    _check(String(player.result_clip) == "m01_defeat_01",
        "SetState(14) plays the recovered Defeat clip",
        "clip=%s" % player.result_clip)
    _check(bool(main.get("done")), "SetState(14) marks the match done")

    _check(not bool(main.get("_countdown_handed_off")),
        "no COUNTDOWNEND hand-off before 9.999 s")
    for _i in 19:
        main.call("_update_match_state", 0.5)
    _check(not bool(main.get("_countdown_handed_off")),
        "no COUNTDOWNEND hand-off at 9.5 s")
    for _i in 2:
        main.call("_update_match_state", 0.5)
    _check(bool(main.get("_countdown_handed_off")),
        "COUNTDOWNEND fires past the recovered 9.999 s")
    _check(int(main.get("match_state")) == STATE_COUNTDOWN,
        "state 14 keeps the defeat presentation after the hand-off")
    _detach_flow(main, flow)


func _check_story_timeup_winonlose_replay_unavailable(main: Node, player: PortFighter,
        computer: PortFighter, states) -> void:
    ## win_on_lose == true, vsbattle subevent (has replay) but the opt-in recorder
    ## has no buffers: PlayerLost records CurrentGameModeFightWon, then falls
    ## back to the state-14 presentation (the port fail-closed rule).
    var flow: Node = _attach_flow(main, true, "vsbattle")
    states.reset()
    _force_time_up_frame(main, player, computer)
    if player.replay_recorder != null:
        player.replay_recorder.buffer.clear()
    if computer.replay_recorder != null:
        computer.replay_recorder.buffer.clear()
    var reached: int = _drive_time_up_to_round_end(main)
    var gm: Variant = main.get("game_modes")
    _check(int(main.get("computer_rounds")) == 1, "win_on_lose replay-unavailable: round lost")
    _check(int(reached) == STATE_COUNTDOWN,
        "win_on_lose replay-unavailable falls back to SetState(14)",
        "match_state=%d" % reached)
    _check(gm != null and bool(gm.get("current_fight_won")),
        "CurrentGameModeFightWon ran before the state-14 fallback")
    _detach_flow(main, flow)


func _check_story_timeup_winonlose_no_replay(main: Node, player: PortFighter,
        computer: PortFighter, states) -> void:
    ## win_on_lose == true, non-replay subevent kind: PlayerLost records
    ## CurrentGameModeFightWon, then StopMusic -> StoryFightWon (no state 14).
    var flow: Node = _attach_flow(main, true, "picture")
    states.reset()
    _force_time_up_frame(main, player, computer)
    var reached: int = _drive_time_up_to_round_end(main)
    var gm: Variant = main.get("game_modes")
    _check(int(reached) != STATE_COUNTDOWN,
        "win_on_lose no-replay does not enter state 14",
        "match_state=%d" % reached)
    _check(bool(main.get("match_over")),
        "win_on_lose no-replay StoryFightWon closes the match")
    _check(gm != null and bool(gm.get("current_fight_won")),
        "CurrentGameModeFightWon ran on the no-replay branch")
    # _resolve_story_fight_won_without_replay() begins with
    # `if match_over: return`.  It can only complete the story event when the
    # PlayerLost branch runs before match_over is set.  Reading the story flow's
    # last_advanced is the observable proof that StoryFightWon actually ran.
    var advanced: Dictionary = flow.get("last_advanced")
    _check(String(advanced.get("outcome", "")) == "complete",
        "win_on_lose no-replay StoryFightWon completes the story event",
        "last_advanced=%s" % str(advanced))
    _detach_flow(main, flow)


func _check_fail_closed(main: Node, player: PortFighter, computer: PortFighter,
        states) -> void:
    ## If the recovered defeat presentation cannot be built, the state-14 entry
    ## must refuse and leave the ordinary result flow in charge.
    var flow: Node = _attach_flow(main, false)
    states.reset()
    _force_time_up_frame(main, player, computer)
    main.set("_defeat_camera_map_loaded", false)
    main.set("_defeat_camera_map_path", "res://data/camera_anm/__no_such_defeat_map__.json")
    var entered: bool = bool(main.call("_enter_countdown_state"))
    _check(not entered, "state 14 refuses when the defeat camera map is missing")
    _check(int(main.get("match_state")) != STATE_COUNTDOWN,
        "a refused state 14 leaves match_state outside state 14")
    main.set("_defeat_camera_map_path", "res://data/camera_anm/defeat_camera_map.json")
    main.set("_defeat_camera_map_loaded", false)
    _detach_flow(main, flow)

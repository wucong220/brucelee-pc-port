extends SceneTree
## Headless validation of PlayerLost's story branch on the real scenes/main.tscn:
##   StoryCurrentFightWinOnLose() == false -> SetState(14) defeat
##   StoryCurrentFightWinOnLose() == true  -> SetState(6) recovered replay
##                                            (state 14 only when replay is
##                                            unavailable)
##
## Recovered anchors (libdefault.so, SHA-256 1da7a30c...):
##   PlayerLost @0x190060, story branch 0x19022c (StoryCurrentFightWinOnLose)
##     false: 0x19049c StopMusic -> 0x1904c8 SetState(14)
##     true : 0x19023c GetCurrentMili -> 0x19025c SetState(6)
##            0x190288 SetState("ReplayAndStats"); game.states routes its
##            "continue" option to "replayend"
##   ReplayEnd @0x190540, mode 1 -> StoryFightWon()
##   SetState case 6 @0x188960, Update case 6 @0x18d0ac
##   RecordReplayUpdate @0x1b8db8
##
## Assets: run with BRUCELEE_PLAYER_GLB / BRUCELEE_OPPONENT_GLB pointing at the
## verified candidates, because the defeat branch needs the recovered
## characters.list defeat clip and its camera.
##
##   godot --headless --path <godot> --script res://tests/validate_story_loss_branch.gd

const StoryFlowScript = preload("res://scripts/story_flow.gd")
const StoryStateScript = preload("res://scripts/story_state.gd")
const StoryDataScript = preload("res://scripts/story_data.gd")
const StoryLangScript = preload("res://scripts/story_lang.gd")
const NativeMatchStates = preload("res://scripts/native_match_states.gd")
const ReplayBufferScript = preload("res://scripts/replay_buffer.gd")

const FRAME: float = 1.0 / 60.0
const RECORD_BASE_MS: int = 100000
const RECORD_STEP_MS: int = 16
## Strict replay-camera rule: every recorded clip must own a recovered camera
## ANM.  The live recorder emits idle/movement names in this synthetic harness,
## so the positive branch relabels its samples with one recovered camera clip;
## the separate validate_replay_camera.gd covers strict refusal and authored
## per-clip playback in detail.
const REPLAY_CAMERA_CLIP: String = "m01_grab_01"

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_STORY_FLOW", "0")
    OS.set_environment("BRUCELEE_REPLAY_RECORD", "1")
    OS.set_environment("BRUCELEE_ATTRACT", "")
    OS.set_environment("BRUCELEE_CONTINUE", "")
    for flag: String in ["BRUCELEE_GAME_MODE", "BRUCELEE_STORY_LAUNCH"]:
        OS.set_environment(flag, "")
    await _run()
    if failures.is_empty():
        print("STORY_LOSS_BRANCH_VALIDATION=PASS checks=%d" % checks)
        quit(0)
        return
    for failure: String in failures:
        push_error("STORY_LOSS_BRANCH_FAIL " + failure)
    print("STORY_LOSS_BRANCH_VALIDATION=FAIL checks=%d failures=%d" % [
        checks, failures.size(),
    ])
    quit(1)


func _check(condition: bool, label: String, detail: String = "") -> void:
    checks += 1
    if condition:
        print("PASS  " + label)
        return
    failures.append(label + ((" | " + detail) if not detail.is_empty() else ""))


func _approx(a: float, b: float, eps: float = 0.001) -> bool:
    return absf(a - b) <= eps


func _vector_near(a: Vector3, b: Vector3, eps: float = 0.001) -> bool:
    return _approx(a.x, b.x, eps) and _approx(a.y, b.y, eps) and _approx(a.z, b.z, eps)


func _run() -> void:
    _check_story_env_dispatch()
    var packed: PackedScene = load("res://scenes/main.tscn")
    _check(packed != null, "real scenes/main.tscn loads")
    if packed == null:
        return
    var main: Node = packed.instantiate()
    root.add_child(main)
    for _i in 4:
        await process_frame
    # Keep the port state machine manual and deterministic; the fighters are
    # driven directly below so the recorder timestamps are known.
    main.set_physics_process(false)
    var player: PortFighter = main.get("player")
    var computer: PortFighter = main.get("computer")
    var states = main.get("native_states")
    _check(player != null and computer != null, "main.tscn builds both fighters")
    if player == null or computer == null or states == null:
        return
    player.set_physics_process(false)
    computer.set_physics_process(false)

    _check_module_constants(states)
    _check_defeat_branch(main, player, computer, states)
    await _check_replay_branch(main, player, computer, states)
    _check_replay_fallback(main, player, computer, states)

    main.set("story_flow", null)
    root.remove_child(main)
    main.free()


func _check_story_env_dispatch() -> void:
    var flow = StoryFlowScript.new()
    OS.set_environment("BRUCELEE_REPLAY_RECORD", "")
    flow.battle_run = {"win_on_lose": "false"}
    flow.apply_match_loader_env({})
    _check(OS.get_environment("BRUCELEE_REPLAY_RECORD") == "",
        "a win_on_lose=false story battle leaves the opt-in recorder off")
    flow.battle_run = {"win_on_lose": "true"}
    flow.apply_match_loader_env({})
    _check(OS.get_environment("BRUCELEE_REPLAY_RECORD") == "1",
        "a win_on_lose=true story battle enables the recovered recorder")
    OS.set_environment("BRUCELEE_REPLAY_RECORD", "1")
    flow.free()


func _check_module_constants(states) -> void:
    _check(int(NativeMatchStates.STATE_REPLAY) == 6, "state 6 constant is 6")
    _check(int(NativeMatchStates.STATE_COUNTDOWN) == 14, "state 14 constant is 14")
    _check(NativeMatchStates.STATE_REPLAY in NativeMatchStates.IMPLEMENTED_STATES,
        "state 6 is an implemented NativeMatchStates state")
    _check(not (NativeMatchStates.STATE_REPLAY in NativeMatchStates.UNRECOVERED_STATES),
        "state 6 is not gated as unrecovered")
    _check(_approx(NativeMatchStates.REPLAY_STATE_SPEED_SCALE, 0.5),
        "state 6 playback scale is the recovered 0.5")
    _check(int(NativeMatchStates.REPLAY_SPEED_FACTOR) == 2,
        "state 6 sample uses the recovered +2*base factor")
    # Without buffers the recovered driver still refuses, with its named reason.
    var driver = NativeMatchStates.new()
    _check(not bool(driver.enter(NativeMatchStates.STATE_REPLAY)),
        "state 6 refuses to start without recorded buffers")
    _check(String(driver.fail_reason).begins_with("no-replay-buffer"),
        "the refusal names no-replay-buffer, got %s" % driver.fail_reason)


func _attach_flow(main: Node, win_on_lose: bool) -> Node:
    var flow = StoryFlowScript.new()
    root.add_child(flow)
    flow.set("main", main)
    var run: Dictionary = {
        "kind": "vsbattle", "chapter": "chapter1", "event": "story_loss_test",
        "event_type": "vsbattle", "sub_index": 9999, "opponents": ["brick"],
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


func _force_match_lost_by_player(main: Node) -> void:
    main.set("rounds_to_win", 1)
    main.set("round_number", 1)
    main.set("player_rounds", 0)
    main.set("computer_rounds", 0)
    main.set("pending_round_winner", 0)
    main.set("match_state", 4)
    main.set("match_state_time", 0.0)
    main.set("done", false)
    main.set("match_over", false)
    main.set("_replay_handed_off", false)


func _check_defeat_branch(main: Node, player: PortFighter, computer: PortFighter,
        states) -> void:
    var flow: Node = _attach_flow(main, false)
    _force_match_lost_by_player(main)
    main.call("_on_ko", player)
    _check(int(main.get("match_state")) == 14,
        "win_on_lose=false player loss enters state 14",
        "match_state=%d" % int(main.get("match_state")))
    _check(int(states.state) == 14, "NativeMatchStates records the state-14 entry")
    _check(bool(player.visible) and not bool(computer.visible),
        "state 14 shows fighter 0 and hides fighter 1")
    _check(String(player.result_clip) == "m01_defeat_01",
        "state 14 plays the recovered Defeat clip, got %s" % player.result_clip)
    _check(not bool(main.get("_replay_handed_off")),
        "the defeat branch does not arm the replay hand-off")
    # CountdownEnded / COUNTDOWNEND at the recovered 9999 ms.
    for _i in 21:
        main.call("_update_match_state", 0.5)
    _check(bool(main.get("_countdown_handed_off")),
        "COUNTDOWNEND fires after the recovered 9999 ms")
    _check(int(main.get("match_state")) == 14,
        "state 14 keeps the match in the defeat presentation")
    root.remove_child(flow)
    flow.free()


func _fill_recorders(player: PortFighter, computer: PortFighter, frames: int = 60) -> void:
    for frame: int in frames:
        var clock: int = RECORD_BASE_MS + frame * RECORD_STEP_MS
        player.replay_record_clock_override_ms = clock
        computer.replay_record_clock_override_ms = clock
        player._physics_process(FRAME)
        computer._physics_process(FRAME)


func _check_replay_branch(main: Node, player: PortFighter, computer: PortFighter,
        states) -> void:
    main.call("_reset_match")
    _check(player.replay_recorder != null and computer.replay_recorder != null,
        "the story recorder is attached to both fighters")
    if player.replay_recorder == null or computer.replay_recorder == null:
        return
    _fill_recorders(player, computer)
    var player_records: Array = player.replay_recorder.buffer.records
    var computer_records: Array = computer.replay_recorder.buffer.records
    # The strict state-6 preflight rejects any clip without a recovered camera.
    # Keep the real recorder timestamps/poses but relabel these synthetic
    # samples so the story-loss positive branch can exercise ReplayEnd.
    for record: Dictionary in player_records:
        record["animation"] = REPLAY_CAMERA_CLIP
    for record: Dictionary in computer_records:
        record["animation"] = REPLAY_CAMERA_CLIP
    _check(player_records.size() == 60 and computer_records.size() == 60,
        "the recovered recorder produced 60 frames per fighter",
        "player=%d computer=%d" % [player_records.size(), computer_records.size()])

    var flow: Node = _attach_flow(main, true)
    _force_match_lost_by_player(main)
    main.call("_on_ko", player)
    _check(int(main.get("match_state")) == 6,
        "win_on_lose=true player loss enters the recovered state 6 replay",
        "match_state=%d" % int(main.get("match_state")))
    if int(main.get("match_state")) != 6:
        root.remove_child(flow)
        flow.free()
        return
    _check(int(states.state) == 6, "NativeMatchStates records the state-6 entry")
    _check(int(states.replay_buffers.size()) == 2,
        "state 6 consumed the two live recorded buffers")
    _check(int(states.replay_base_ms) == RECORD_BASE_MS,
        "replay base is the first recorded sample (game+0x838 equivalent)",
        "base=%d" % int(states.replay_base_ms))
    _check(bool(player.visible) and bool(computer.visible),
        "SetState(6) shows both fighters")
    _check(bool(player.replay_pose_lock) and bool(computer.replay_pose_lock),
        "state 6 locks the normal fighter simulation")
    _check(not bool(player.replay_record_enabled)
            and not bool(computer.replay_record_enabled),
        "state 6 clears both +0x16f record gates")
    var start_player: Vector3 = main.get("_fight_start_player")
    var start_computer: Vector3 = main.get("_fight_start_computer")
    _check(_vector_near(player.global_position, start_player),
        "SetPosToFightStartPos restores fighter 0's start position")
    _check(_vector_near(computer.global_position, start_computer),
        "SetPosToFightStartPos restores fighter 1's start position")
    _check(_approx(player.rotation.y, float(main.get("_fight_start_player_yaw"))),
        "fighter 0's recovered start yaw is restored")
    _check(_approx(computer.rotation.y, float(main.get("_fight_start_computer_yaw"))),
        "fighter 1's recovered start yaw is restored")

    # Update case 6: sample = elapsed + 2*base, RecordReplayUpdate at 0.5x and at
    # most one record per fighter per Update.
    var player_buffer = player.replay_recorder.buffer
    var computer_buffer = computer.replay_recorder.buffer
    var steps: int = 10
    for _i in steps:
        main.call("_update_match_state", FRAME)
    var elapsed_ms: int = int(round(float(states.state_time) * 1000.0))
    var sample_ms: int = elapsed_ms + NativeMatchStates.REPLAY_SPEED_FACTOR * int(states.replay_base_ms)
    var threshold: float = float(sample_ms) * NativeMatchStates.REPLAY_STATE_SPEED_SCALE
    var expected: int = 0
    for record: Dictionary in player_records:
        if float(int(record["time_ms"])) <= threshold:
            expected += 1
    _check(int(player_buffer.cursor) == expected,
        "player cursor follows the recovered 0.5x threshold",
        "cursor=%d expected=%d threshold=%.1f" % [
            int(player_buffer.cursor), expected, threshold,
        ])
    _check(int(computer_buffer.cursor) == expected,
        "computer cursor follows the recovered 0.5x threshold")
    _check(expected >= 3 and expected <= steps,
        "the 0.5x threshold consumes fewer records than real-time frames",
        "expected=%d" % expected)
    if expected > 0:
        var applied: Dictionary = player_records[int(player_buffer.cursor) - 1]
        _check(_vector_near(player.global_position, Vector3(applied["position"])),
            "RecordReplayUpdate restores the recorded player position")
        _check(int(player.replay_playback_sample_ms) == sample_ms,
            "the recorded frame carries the recovered replay sample")
        if not player.candidate_animation_clip.is_empty():
            _check(String(player.replay_playback_clip) == String(applied["animation"]),
                "RecordReplayUpdate plays the recorded clip, got %s" % player.replay_playback_clip)

    # Update case 6's both-ReplayEnded path re-enters SetState(6): cursors are
    # re-seeked to base and the fight-start pose is restored.
    var guard: int = 0
    while int(states.replay_loops) == 0 and guard < 600:
        main.call("_update_match_state", FRAME)
        guard += 1
    _check(int(states.replay_loops) >= 1,
        "both ReplayEnded re-enter state 6 (recovered loop)")
    _check(int(player_buffer.cursor) == 0 and int(computer_buffer.cursor) == 0,
        "the loop re-seeks both buffers to the replay base",
        "player=%d computer=%d" % [
            int(player_buffer.cursor), int(computer_buffer.cursor),
        ])
    _check(_vector_near(player.global_position, start_player)
            and _vector_near(computer.global_position, start_computer),
        "the loop restores the fight-start pose")

    # ReplayEnd -> StoryFightWon for story mode.  game.states maps the
    # replayandstats "continue" option to "replayend"; the port's confirm key is
    # the same J used by every recovered single-option menu.
    var enter := InputEventKey.new()
    enter.keycode = KEY_ENTER
    enter.pressed = true
    var handled: bool = bool(main.call("_handle_replay_input", enter))
    _check(handled, "the replay continue input is consumed")
    _check(bool(main.get("_replay_handed_off")), "ReplayEnd hands the fight off")
    _check(bool(main.get("match_over")), "ReplayEnd ends the match")
    var advanced: Dictionary = flow.get("last_advanced")
    _check(String(advanced.get("outcome", "")) == "complete",
        "StoryFightWon completes the win_on_lose event",
        "outcome=%s" % String(advanced.get("outcome", "")))
    var records: Array = flow.get("state").records
    _check(not records.is_empty() and bool(Dictionary(records.back()).get("won", false)),
        "the story record advances as a win")
    root.remove_child(flow)
    flow.free()


func _check_replay_fallback(main: Node, player: PortFighter, computer: PortFighter,
        states) -> void:
    main.call("_reset_match")
    var flow: Node = _attach_flow(main, true)
    _force_match_lost_by_player(main)
    if player.replay_recorder != null:
        player.replay_recorder.buffer.clear()
    if computer.replay_recorder != null:
        computer.replay_recorder.buffer.clear()
    main.call("_on_ko", player)
    _check(int(main.get("match_state")) == 14,
        "an unavailable replay falls back to the state-14 defeat presentation",
        "match_state=%d" % int(main.get("match_state")))
    var refused: bool = false
    for entry: Dictionary in states.trace:
        if int(entry.get("state", -1)) == 6 and String(entry.get("result", "")) == "refused":
            refused = String(entry.get("reason", "")).begins_with("no-replay-buffer")
    _check(refused, "NativeMatchStates records the recovered no-replay-buffer refusal")
    root.remove_child(flow)
    flow.free()

extends SceneTree
## Headless validation of the two StoryModeSubEventFightHasReplay sub-branches
## and the CurrentGameModeFightWon timing on the real main.tscn.
##
## Native anchors:
##   StoryModeSubEventFightHasReplay @0x1e4540 (Ghidra 0x1f4540)
##     GOT relocations: 0x602cc8 gid_vsbattle, 0x602338 gid_arcade,
##                      0x603e5c gid_survival, 0x60352c gid_timeattack
##   PlayerLost @0x190060:
##     win_on_lose false -> StopMusic -> SetState(14)
##     win_on_lose true  -> SetState(6) -> CurrentGameModeFightWon
##                          -> StoryModeSubEventFightHasReplay
##                             true  -> ReplayAndStats -> replayend -> StoryFightWon
##                             false -> StopMusic -> StoryFightWon
##   CurrentGameModeFightWon @0x1571fc -> mode vtable FightWon slot
##     (CBruceLeeStoryMode vtable +0x14 = CBruceLeeStoryMode::FightWon @0x1e73bc)
##   ReplayEnd @0x190540 mode 1 -> StoryFightWon
##
## Run:
##   godot --headless --path <godot> --script res://tests/validate_story_subevent_replay.gd

const StoryFlowScript = preload("res://scripts/story_flow.gd")
const StoryStateScript = preload("res://scripts/story_state.gd")
const StoryDataScript = preload("res://scripts/story_data.gd")
const StoryLangScript = preload("res://scripts/story_lang.gd")
const NativeMatchStates = preload("res://scripts/native_match_states.gd")

const FRAME: float = 1.0 / 60.0
const RECORD_BASE_MS: int = 100000
const RECORD_STEP_MS: int = 16
const PLAYER_HEALTH: float = 37.0

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_STORY_FLOW", "0")
    OS.set_environment("BRUCELEE_REPLAY_RECORD", "1")
    OS.set_environment("BRUCELEE_ATTRACT", "")
    OS.set_environment("BRUCELEE_CONTINUE", "")
    OS.set_environment("BRUCELEE_GAME_MODE", "")
    OS.set_environment("BRUCELEE_STORY_LAUNCH", "")
    OS.set_environment("BRUCELEE_PLAYER_GLB",
        "D:\\BruceLeeWork\\bruce-full-20261103\\out\\bruce_full_121_20261103.glb")
    OS.set_environment("BRUCELEE_OPPONENT_GLB",
        "D:\\BruceLeeWork\\brick-full-20261103\\candidate\\brick_full_94_20261103.glb")
    await _run()
    if failures.is_empty():
        print("STORY_SUBEVENT_REPLAY_VALIDATION=PASS checks=%d" % checks)
        quit(0)
        return
    for failure: String in failures:
        push_error("STORY_SUBEVENT_REPLAY_FAIL " + failure)
    print("STORY_SUBEVENT_REPLAY_VALIDATION=FAIL checks=%d failures=%d" % [
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


func _run() -> void:
    _check_predicate_table()
    await _check_true_branch()
    await _check_false_branch()
    await _check_buffer_unavailable()


func _check_predicate_table() -> void:
    var flow = StoryFlowScript.new()
    for kind: String in ["vsbattle", "arcade", "survival", "timeattack"]:
        flow.battle_run = {"kind": kind}
        _check(bool(flow.current_battle_has_replay()),
            "predicate accepts recovered battle kind %s" % kind)
    for kind: String in ["picture", "unlock", "", "unknown"]:
        flow.battle_run = {"kind": kind}
        _check(not bool(flow.current_battle_has_replay()),
            "predicate rejects non-replay kind %s" % (kind if kind else "<empty>"))
    flow.free()


func _new_main() -> Node:
    var packed: PackedScene = load("res://scenes/main.tscn")
    _check(packed != null, "real scenes/main.tscn loads")
    if packed == null:
        return null
    var main: Node = packed.instantiate()
    root.add_child(main)
    for _i in 4:
        await process_frame
    main.set_physics_process(false)
    return main


func _attach_flow(main: Node, kind: String) -> Node:
    var flow = StoryFlowScript.new()
    root.add_child(flow)
    flow.set("main", main)
    var run: Dictionary = {
        "kind": kind, "chapter": "chapter1", "event": "subevent_replay_test",
        "event_type": "arcade_event" if kind == "arcade" else "story_event",
        "sub_index": 9999, "opponents": ["brick"] if kind != "picture" else [],
        "opponent_index": 0, "player": "brucelee", "scenery": "",
        "difficulty_slot": 0, "difficulty_value": 0, "fights_done": 0,
        "elapsed_seconds": 0.0, "fight_results": [], "carried_health": -1.0,
        "source": {}, "win_on_lose": "true",
    }
    flow.set("battle_run", run)
    flow.set("battle_spec", {"opponent": "brick", "difficulty_value": 0})
    flow.set("battle_started_msec", Time.get_ticks_msec() - 1234)
    var state = StoryStateScript.new()
    state.difficulty_slot = 0
    state.save_slot = 0
    state.set_pending({
        "run": run, "spec": {"opponent": "brick"},
        "started_msec": Time.get_ticks_msec(), "save_slot": 0,
        "chapter_index": 0, "event_index": 0, "unlock_mark": 0,
    })
    flow.set("state", state)
    flow.set("data", StoryDataScript.new())
    flow.set("lang", StoryLangScript.new())
    main.set("story_flow", flow)
    OS.set_environment("BRUCELEE_STORY_FLOW", "1")
    return flow


func _force_player_loss(main: Node, player: PortFighter) -> void:
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
    player.health = PLAYER_HEALTH


func _fill_recorders(player: PortFighter, computer: PortFighter) -> void:
    for frame: int in 60:
        var clock: int = RECORD_BASE_MS + frame * RECORD_STEP_MS
        player.replay_record_clock_override_ms = clock
        computer.replay_record_clock_override_ms = clock
        player._physics_process(FRAME)
        computer._physics_process(FRAME)


func _check_true_branch() -> void:
    var main: Node = await _new_main()
    if main == null:
        return
    var player: PortFighter = main.get("player")
    var computer: PortFighter = main.get("computer")
    var states = main.get("native_states")
    _check(player != null and computer != null, "true branch builds both fighters")
    if player == null or computer == null or states == null:
        root.remove_child(main)
        main.free()
        return
    player.set_physics_process(false)
    computer.set_physics_process(false)
    main.call("_reset_match")
    _fill_recorders(player, computer)
    _check(int(player.replay_recorder.size()) == 60,
        "true branch has a recorded player buffer")
    _check(int(computer.replay_recorder.size()) == 60,
        "true branch has a recorded computer buffer")

    var flow: Node = _attach_flow(main, "arcade")
    var stats: Dictionary = flow.call("_story_exp_move_stats")
    var expected_fight_score: int = StoryFlowScript.story_exp_fight_score(
        "arcade", 0, int(round(PLAYER_HEALTH)), stats, -1
    )
    var expected_bonus: int = StoryFlowScript._story_exp_completion_bonus("arcade", 0)
    _check(expected_fight_score > 0 and expected_bonus > 0,
        "synthetic arcade fight has a nonzero fight score and completion bonus")

    _force_player_loss(main, player)
    main.call("_on_ko", player)

    _check(int(main.get("match_state")) == 6,
        "true predicate enters state 6",
        "match_state=%d" % int(main.get("match_state")))
    _check(int(states.state) == 6, "NativeMatchStates records state 6")
    _check(bool(main.get("game_modes").get("current_fight_won")),
        "CurrentGameModeFightWon runs at replay entry")
    _check(int(main.get("game_modes").get("current_fight_won_msec")) >= 0,
        "CurrentGameModeFightWon records the native +0x04 timestamp")
    var snapshot: Dictionary = main.get("game_modes").get("current_fight_results")
    _check(int(snapshot.get("match_millis", -1)) >= 0,
        "CurrentGameModeFightWon receives the match-millis snapshot")
    _check(bool(flow.get("_fight_won_recorded")),
        "story FightWon is marked as paid at replay entry")
    _check(int(flow.get("state").exp) == expected_fight_score,
        "replay entry pays only the fight score, not the completion bonus",
        "exp=%d expected=%d" % [int(flow.get("state").exp), expected_fight_score])
    _check(flow.get("last_advanced").is_empty(),
        "replay entry does not advance the story event")
    var message: String = String(main.get("hud").center_message.text)
    _check(message.begins_with("REPLAY"),
        "ReplayAndStats prompt is published after CurrentGameModeFightWon",
        message)

    var enter := InputEventKey.new()
    enter.keycode = KEY_ENTER
    enter.pressed = true
    var handled: bool = bool(main.call("_handle_replay_input", enter))
    _check(handled, "replay continue input is consumed")
    _check(bool(main.get("_replay_handed_off")), "ReplayEnd hands off the fight")
    var advanced: Dictionary = flow.get("last_advanced")
    _check(String(advanced.get("outcome", "")) == "complete",
        "ReplayEnd completes the synthetic arcade event",
        "outcome=%s" % String(advanced.get("outcome", "")))
    _check(int(flow.get("state").exp) == expected_fight_score + expected_bonus,
        "ReplayEnd adds only the completion bonus; fight score is not paid twice",
        "exp=%d expected=%d" % [
            int(flow.get("state").exp), expected_fight_score + expected_bonus,
        ])
    var records: Array = flow.get("state").records
    _check(not records.is_empty() and bool(Dictionary(records.back()).get("won", false)),
        "ReplayEnd records the win exactly once")
    root.remove_child(flow)
    flow.free()
    main.set("story_flow", null)
    root.remove_child(main)
    main.free()


func _check_false_branch() -> void:
    var main: Node = await _new_main()
    if main == null:
        return
    var player: PortFighter = main.get("player")
    var computer: PortFighter = main.get("computer")
    var states = main.get("native_states")
    _check(player != null and computer != null, "false branch builds both fighters")
    if player == null or computer == null or states == null:
        root.remove_child(main)
        main.free()
        return
    player.set_physics_process(false)
    computer.set_physics_process(false)
    main.call("_reset_match")
    var flow: Node = _attach_flow(main, "picture")
    _force_player_loss(main, player)
    main.call("_on_ko", player)

    _check(int(main.get("match_state")) != 6,
        "false predicate does not enter state 6",
        "match_state=%d" % int(main.get("match_state")))
    _check(int(states.state) != 6, "NativeMatchStates does not record state 6")
    _check(bool(main.get("game_modes").get("current_fight_won")),
        "CurrentGameModeFightWon still runs before the false branch")
    _check(bool(main.get("match_over")) and bool(main.get("done")),
        "false branch closes the fight immediately")
    var advanced: Dictionary = flow.get("last_advanced")
    _check(String(advanced.get("outcome", "")) == "complete",
        "false branch calls StoryFightWon immediately",
        "outcome=%s" % String(advanced.get("outcome", "")))
    var records: Array = flow.get("state").records
    _check(not records.is_empty() and bool(Dictionary(records.back()).get("won", false)),
        "false branch records the win")
    var message: String = String(main.get("hud").center_message.text)
    _check(message == "STORY CONTINUES",
        "false branch never publishes the ReplayAndStats prompt",
        message)
    _check(int(flow.get("state").exp) == 0,
        "the non-battle false-branch kind has the recovered zero fight score",
        "exp=%d" % int(flow.get("state").exp))
    root.remove_child(flow)
    flow.free()
    main.set("story_flow", null)
    root.remove_child(main)
    main.free()


func _check_buffer_unavailable() -> void:
    var main: Node = await _new_main()
    if main == null:
        return
    var player: PortFighter = main.get("player")
    var computer: PortFighter = main.get("computer")
    var states = main.get("native_states")
    _check(player != null and computer != null, "fallback branch builds both fighters")
    if player == null or computer == null or states == null:
        root.remove_child(main)
        main.free()
        return
    player.set_physics_process(false)
    computer.set_physics_process(false)
    main.call("_reset_match")
    if player.replay_recorder != null:
        player.replay_recorder.buffer.clear()
    if computer.replay_recorder != null:
        computer.replay_recorder.buffer.clear()
    var flow: Node = _attach_flow(main, "vsbattle")
    _force_player_loss(main, player)
    main.call("_on_ko", player)
    _check(int(main.get("match_state")) == 14,
        "empty replay buffer keeps the documented state-14 port fallback")
    var refused: bool = false
    for entry: Dictionary in states.trace:
        if int(entry.get("state", -1)) == 6 \
                and String(entry.get("result", "")) == "refused" \
                and String(entry.get("reason", "")).begins_with("no-replay-buffer"):
            refused = true
    _check(refused, "NativeMatchStates records no-replay-buffer")
    _check(bool(main.get("game_modes").get("current_fight_won")),
        "CurrentGameModeFightWon still runs before the fail-closed fallback")
    root.remove_child(flow)
    flow.free()
    main.set("story_flow", null)
    root.remove_child(main)
    main.free()

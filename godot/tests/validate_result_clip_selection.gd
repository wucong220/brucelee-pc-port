extends SceneTree
## Validates the recovered characters.list result-clip selection and the native
## SetState(12/13) timing on the real main.tscn.
##
## Evidence this test mirrors (libdefault.so, Ghidra base +0x10000):
##   0x1ff418  IBeatEmUpGameMode::SetFighterConfigFromCharacterList
##             version = zmathRandomGet() % GetAnimationNumVersions(char, name)
##             for "victory"; the literal version 0 for "defeat"
##   0x58d820  zmathRandomGet (LCG 0x41C64E6D/0x3039, seed 0x6425AF14,
##             returns bits 16..31)
##   0x188508  CBeatEmUpGame::SetState case 12/13 plays category "Victory" for
##             the visible winner only
##   0x18c1bc  CBeatEmUpGame::Update case 12/13 leaves when
##             GetStateTime() > GetDuration() - 100 (unsigned ms)
##
## Usage:
##   <godot> --headless --path godot --script \
##       res://tests/validate_result_clip_selection.gd -- <bruce.glb> <brick.glb>

const STATE_FIGHT: int = 4
const STATE_MATCH_WIN: int = 12
const STATE_ROUND_END: int = 15

var results: Dictionary = {}
var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _new_scene(
        bruce: String,
        brick: String,
        attack_config: String = "res://data/fighting_set_m03_mapped_attacks.json"
) -> Node:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_TIME", "60")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", bruce)
    OS.set_environment("BRUCELEE_OPPONENT_GLB", brick)
    OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", attack_config)
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    return scene


func _wait_candidates(scene: Node, timeout_frames: int = 900) -> bool:
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    for _i: int in range(timeout_frames):
        if player.candidate_loaded and computer.candidate_loaded:
            return true
        await physics_frame
    return player.candidate_loaded and computer.candidate_loaded


func _freeze(scene: Node) -> void:
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)


func _state(scene: Node) -> int:
    var value: Variant = scene.get("match_state")
    return int(value) if typeof(value) == TYPE_INT else -1


func _fail(message: String) -> void:
    failures.append(message)
    push_error(message)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 2:
        push_error("Expected <bruce.glb> <brick.glb>")
        quit(2)
        return
    var scene: Node = _new_scene(args[0], args[1])
    if not await _wait_candidates(scene):
        push_error("candidate GLBs did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")

    # --- zmathRandomGet: fixed seed, LCG, bits 16..31 ---
    # The native static initializer stores 0x6425AF14 and each match config
    # draws intro then victory for the player, then the same pair for the
    # opponent. _ready() runs exactly one _reset_match(), so the state after
    # four draws must be the reference below.
    results["zmath_state_after_startup"] = scene.get("_zmath_state")
    results["zmath_reference_state"] = 0xE138A880
    if int(scene.get("_zmath_state")) != 0xE138A880:
        _fail("zmathRandomGet port state after four startup draws is not 0xE138A880")
    results["startup_victory_index_player"] = player.result_clip_index_victory
    results["startup_victory_index_computer"] = computer.result_clip_index_victory
    # 40155 % 2 = 1 in the native order would need the intro draw first; the
    # victory draw is the second value (34122) -> 34122 % 2 = 0.
    if player.result_clip_index_victory != 0:
        _fail("player victory index is not the second zmath draw %% 2 (expected 0)")

    # --- characters.list pools reach the port ---
    results["player_victory_pool"] = player.result_clip_pool("victory")
    results["player_defeat_pool"] = player.result_clip_pool("defeat")
    results["computer_victory_pool"] = computer.result_clip_pool("victory")
    results["computer_defeat_pool"] = computer.result_clip_pool("defeat")
    if player.result_clip_pool("victory") != ["m01_victory_01", "m01_victory_02"]:
        _fail("player victory pool is not the characters.list brucelee order")
    if computer.result_clip_pool("victory") != ["m03_victory_02"]:
        _fail("brick victory pool is not characters.list brick davis (m03_victory_02)")
    if player.result_clip_pool("defeat") != ["m01_defeat_01"]:
        _fail("player defeat pool is not characters.list brucelee (m01_defeat_01)")

    # --- victory index = roll % count, on the archive order ---
    var rolls: Dictionary = {0: "m01_victory_01", 1: "m01_victory_02",
        2: "m01_victory_01", 40155: "m01_victory_02", 34122: "m01_victory_01"}
    var observed: Dictionary = {}
    for roll: int in rolls:
        player.clear_result_pose()
        player.select_result_clips(roll)
        var ok: bool = player.enter_result_pose("victory")
        observed[roll] = {"clip": player.result_clip, "ok": ok,
            "index": player.result_clip_index_victory}
        if not ok or player.result_clip != String(rolls[roll]):
            _fail("roll %d selected %s, expected %s"
                % [roll, player.result_clip, String(rolls[roll])])
    results["player_victory_rolls"] = observed

    # --- defeat ignores the roll (native version 0) ---
    var defeat_rolls: Dictionary = {}
    for roll: int in [0, 5, 40155]:
        player.clear_result_pose()
        player.select_result_clips(roll)
        var ok: bool = player.enter_result_pose("defeat")
        defeat_rolls[roll] = {"clip": player.result_clip, "ok": ok,
            "index": player.result_clip_index_defeat}
        if not ok or player.result_clip != "m01_defeat_01":
            _fail("defeat roll %d selected %s, expected m01_defeat_01"
                % [roll, player.result_clip])
    results["player_defeat_rolls"] = defeat_rolls

    # --- the GLB's sorted scan is not the archive pool ---
    results["player_loaded_victory_clips"] = player.result_clip_names("victory")
    results["computer_loaded_victory_clips"] = computer.result_clip_names("victory")
    var computer_scan: Array[String] = computer.result_clip_names("victory")
    results["brick_sorted_first"] = computer_scan[0] if not computer_scan.is_empty() else ""
    computer.clear_result_pose()
    computer.select_result_clips(0)
    var brick_ok: bool = computer.enter_result_pose("victory")
    results["brick_selected_clip"] = computer.result_clip
    if not brick_ok or computer.result_clip != "m03_victory_02":
        _fail("brick victory did not present m03_victory_02")
    if not computer_scan.is_empty() and computer_scan[0] == "m03_victory_01":
        results["brick_sorted_first_is_other_character"] = true
    else:
        _fail("expected the brick GLB to also carry m03_victory_01 (johnson)")

    # --- SetState(12) timing: duration - 100 ms, loser not animated ---
    player.clear_result_pose()
    computer.clear_result_pose()
    scene._reset_match()
    player.select_result_clips(1)
    scene.set("pending_round_winner", 1)
    scene.set("player_rounds", 2)
    scene.set("computer_rounds", 0)
    scene._begin_winner_result_pose()
    var duration: float = player.result_clip_duration()
    var duration_millis: int = int(round(duration * 1000.0))
    var expected: float = float(duration_millis - 100) / 1000.0
    results["pose_clip"] = player.result_clip
    results["pose_clip_seconds"] = duration
    results["pose_state"] = _state(scene)
    results["pose_expected_seconds"] = expected
    results["pose_state_seconds"] = scene.get("_result_pose_seconds")
    results["loser_clip"] = computer.result_clip
    results["loser_state"] = computer.state
    results["loser_visible"] = computer.visible
    results["winner_visible"] = player.visible
    if _state(scene) != STATE_MATCH_WIN:
        _fail("SetState(12) path did not enter state 12")
    if player.result_clip != "m01_victory_02":
        _fail("state 12 did not present the selected m01_victory_02 clip")
    if absf(float(scene.get("_result_pose_seconds")) - expected) > 0.000001:
        _fail("state 12 duration is not GetDuration() - 100 ms")
    if not computer.result_clip.is_empty() or computer.state == "result":
        _fail("hidden loser was given a result clip (native 12/13 does not animate it)")
    if player.visible == computer.visible:
        _fail("state 12 did not hide exactly one fighter")

    # Drive Update() state 12 until it leaves; the exit must sit at
    # GetStateTime() > duration - 100 ms, not at 2.5 s and not at the full clip.
    var elapsed: float = 0.0
    var step: float = 0.01
    var guard: int = 0
    while _state(scene) == STATE_MATCH_WIN and guard < 2000:
        scene._update_match_state(step)
        if _state(scene) == STATE_MATCH_WIN:
            elapsed += step
        guard += 1
    var exit_time: float = elapsed + step
    results["pose_last_tick_seconds"] = elapsed
    results["pose_exit_seconds"] = exit_time
    results["pose_exit_state"] = _state(scene)
    if _state(scene) != STATE_ROUND_END:
        _fail("state 12 did not reach state 15")
    if elapsed > expected + 0.000001:
        _fail("state 12 left at %.3f s, before GetDuration() - 100 ms (%.3f s)"
            % [elapsed, expected])
    if exit_time <= expected or exit_time > expected + step + 0.000001:
        _fail("state 12 exited at %.3f s, expected the first tick past %.3f s"
            % [exit_time, expected])
    if duration_millis >= 2000 and absf(exit_time - 2.5) < 0.02:
        _fail("state 12 still used the old 2.5 s floor")
    if absf(exit_time - duration) < 0.02:
        _fail("state 12 still played the full clip without the 100 ms cut")

    scene.queue_free()
    await process_frame

    # --- documented asset gap: the characters.list clip is not in the GLB ---
    if args.size() >= 3 and FileAccess.file_exists(args[2]):
        var gap_scene: Node = _new_scene(
            args[0], args[2], "res://data/attack_config_master.json"
        )
        var gap_ready: bool = await _wait_candidates(gap_scene)
        if gap_ready:
            await process_frame
            _freeze(gap_scene)
            var master: PortFighter = gap_scene.get("computer")
            results["master_pool"] = master.result_clip_pool("victory")
            results["master_loaded_clips"] = master.result_clip_names("victory")
            master.select_result_clips(0)
            var gap_ok: bool = master.enter_result_pose("victory")
            results["master_gap_ok"] = gap_ok
            results["master_gap_clip"] = master.result_clip
            results["master_gap_message"] = master.result_clip_gap_last
            if master.result_clip_pool("victory") != ["m04_e01_victory_01"]:
                _fail("master victory pool is not characters.list the master")
            if not gap_ok:
                _fail("master asset gap suppressed the result pose entirely")
            if master.result_clip_gap_last.is_empty():
                _fail("master asset gap was not reported")
            if master.result_clip == "m04_e01_victory_01":
                _fail("master presented a clip the GLB does not contain")
        else:
            _fail("master candidate GLB did not load")
        gap_scene.queue_free()
        await process_frame

    results["failures"] = failures
    print("RESULT_CLIP_SELECTION_VALIDATION=" + JSON.stringify(results))
    quit(0 if failures.is_empty() else 1)

extends SceneTree
## Validates that the recovered commentator samples are bound to the recovered
## game-text records and fire exactly once, on the real res://scenes/main.tscn.
##
## Evidence chain (no invented thresholds or offsets):
##   - ingamesprites_animations.json (11 records) carries each record's `sounds`
##     array: {sample: sounds/commentator_voice/<name>.wav, time: seconds}.
##     The same file ships in the package under ui/gametext.
##   - CBeatEmUpGame::SetState launches the records:
##       case 3  -> LaunchGameTextAnimation(0) + (1)   READY / FIGHT
##       case 5  -> (4) TIME_IS_UP
##       case 7  -> winner health < 0x14 -> (9) GREAT else (2) YOU_WIN;
##                  health == 100 -> additionally (6) PERFECT
##       case 8  -> local loss -> (3) YOU_LOSE
##       case 11 -> (5) DRAW
##   - The port launches those same indices in _show_round_result_text /
##     _on_time_up / _resolve_time_up_winner; this test checks the audio that
##     each launch schedules.
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_result_audio.gd \
##       -- <bruce.glb> <brick.glb> <commentator_root> <gametext_root>

const STATE_FIGHT: int = 4
const STATE_TIME_UP: int = 5
const STATE_KO_WIN: int = 7
const STATE_KO_LOSE: int = 8
const STATE_DRAW: int = 11
const STATE_ROUND_END: int = 15

const PACKAGE_COMMENTATOR_FILES := {
    "ready": "Ready_Alt_1.wav",
    "fight": "Fight.wav",
    "win": "You_Win.wav",
    "lose": "You_Lose.wav",
    "time_out": "Time_Out.wav",
    "draw": "Draw.wav",
    "great": "Great.wav",
    "perfect": "Perfect.wav",
}

const RECOVERED_SAMPLES := {
    0: ["ready_alt_1.wav", 0.0],
    1: ["fight.wav", 2.0],
    2: ["you_win.wav", 0.0],
    3: ["you_lose.wav", 0.0],
    4: ["time_out.wav", 0.0],
    5: ["draw.wav", 0.0],
    6: ["perfect.wav", 1.5],
    9: ["great.wav", 0.0],
    10: ["great.wav", 0.0],
}

var commentator_root: String = ""
var failures: Array[String] = []
var results: Dictionary = {}
var _length_cache: Dictionary = {}


func _initialize() -> void:
    call_deferred("_run")


func _new_scene(
        bruce: String, brick: String, round_time: int, text_root: String
) -> Node:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_TIME", str(round_time))
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", bruce)
    OS.set_environment("BRUCELEE_OPPONENT_GLB", brick)
    OS.set_environment("BRUCELEE_GAME_TEXT_ROOT", text_root)
    OS.set_environment("BRUCELEE_GAME_TEXT_FLIP", "1")
    OS.set_environment("BRUCELEE_COMMENTATOR_ROOT", commentator_root)
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


func _advance_overlays(scene: Node, seconds: float) -> void:
    # The frozen scene has _process disabled; step the recovered sample clock
    # the same way the live overlay clock advances (50 ms slices).
    var remaining: float = seconds
    while remaining > 0.0:
        var dt: float = minf(remaining, 0.05)
        scene._update_game_text_sequence(dt)
        remaining -= dt


func _tick(scene: Node, seconds: float, step: float = 0.02) -> void:
    var remaining: float = seconds
    while remaining > 0.0:
        var dt: float = minf(remaining, step)
        scene._physics_process(dt)
        remaining -= dt


func _tick_until(scene: Node, target_state: int, max_seconds: float = 9.0) -> bool:
    var elapsed: float = 0.0
    var step: float = 0.02
    while elapsed < max_seconds:
        if _state(scene) == target_state:
            return true
        scene._physics_process(step)
        elapsed += step
    return _state(scene) == target_state


func _state(scene: Node) -> int:
    var value: Variant = scene.get("match_state")
    return value if typeof(value) == TYPE_INT else -1


func _real_punch_ko_with_winner_health(
        scene: Node,
        attacker: PortFighter,
        defender: PortFighter,
        winner_health: float = -1.0
) -> bool:
    # Same real-contact fixture as validate_game_text_triggers.gd: the
    # defender's health is set to 1 so one real punch is lethal; the winner's
    # health is set only to select the recovered GREAT/PERFECT branch.
    if attacker == scene.get("player"):
        attacker.reset_fighter(Vector3(0.0, 1.20, 0.0))
        defender.reset_fighter(Vector3(0.6, 1.20, 0.0))
    else:
        defender.reset_fighter(Vector3(0.0, 1.20, 0.0))
        attacker.reset_fighter(Vector3(0.6, 1.20, 0.0))
    defender.health = 1.0
    if winner_health >= 0.0:
        attacker.health = winner_health
    attacker.facing = (
            1.0 if defender.global_position.x >= attacker.global_position.x else -1.0
    )
    if not attacker.request_attack("punch"):
        push_error("request_attack(punch) failed")
        return false
    attacker._physics_process(float(attacker.ATTACKS["punch"]["startup"]) + 0.01)
    if defender.health > 0.0:
        return false
    for _i: int in range(150):
        if _state(scene) != STATE_FIGHT:
            break
        defender._physics_process(1.0 / 60.0)
    return _state(scene) != STATE_FIGHT


func _entry_keys(entries: Array) -> Array:
    var keys: Array = []
    for entry: Variant in entries:
        if entry is Dictionary:
            keys.append(String(Dictionary(entry).get("key", "")))
    return keys


func _entry_values(entries: Array, field: String) -> Array:
    var values: Array = []
    for entry: Variant in entries:
        if entry is Dictionary:
            values.append(Dictionary(entry).get(field))
    return values


func _entry_files(entries: Array) -> Array:
    return _entry_values(entries, "file")


func _entry_sequences(entries: Array) -> Array:
    return _entry_values(entries, "sequence")


func _wav_length_ms(path: String) -> int:
    if _length_cache.has(path):
        return int(_length_cache[path])
    var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
    var value: int = -1
    if stream != null:
        value = int(round(stream.get_length() * 1000.0))
    _length_cache[path] = value
    return value


func _check_audio(
        label: String,
        scene: Node,
        expected_keys: Array,
        expected_sequences: Array,
        expected_files: Array
) -> void:
    var log_value: Variant = scene.get("result_audio_play_log")
    var entries: Array = log_value if log_value is Array else []
    var keys: Array = _entry_keys(entries)
    var sequences: Array = _entry_sequences(entries)
    var files: Array = _entry_files(entries)
    results[label + "_keys"] = keys
    results[label + "_sequences"] = sequences
    if keys != expected_keys:
        failures.append("%s keys %s, expected %s" % [label, keys, expected_keys])
    if sequences != expected_sequences:
        failures.append("%s sequences %s, expected %s" % [
            label, sequences, expected_sequences,
        ])
    if files != expected_files:
        failures.append("%s files %s, expected %s" % [label, files, expected_files])
    for entry: Variant in entries:
        if not entry is Dictionary:
            failures.append("%s produced a non-dictionary log entry" % label)
            continue
        var record: Dictionary = entry
        var file: String = String(record.get("file", ""))
        var expected_path: String = commentator_root.path_join(file)
        var actual_path: String = String(record.get("path", "")).replace("\\", "/")
        if actual_path != expected_path:
            failures.append("%s played %s from %s, expected %s" % [
                label, String(record.get("key", "")), actual_path, expected_path,
            ])
        var expected_ms: int = _wav_length_ms(expected_path)
        if int(record.get("length_ms", -1)) != expected_ms:
            failures.append("%s %s length %s ms, expected %s ms" % [
                label, file, record.get("length_ms"), expected_ms,
            ])
    var count_value: Variant = scene.get("result_audio_play_count")
    var play_count: int = int(count_value) if typeof(count_value) == TYPE_INT else -1
    if play_count != entries.size():
        failures.append("%s play_count %d != log size %d" % [
            label, play_count, entries.size(),
        ])


func _check_no_more_audio(label: String, scene: Node, baseline_size: int) -> void:
    var log_value: Variant = scene.get("result_audio_play_log")
    var entries: Array = log_value if log_value is Array else []
    if entries.size() != baseline_size:
        failures.append("%s: %d extra cue(s) after the result state: %s" % [
            label, entries.size() - baseline_size,
            _entry_keys(entries.slice(baseline_size)),
        ])


func _audio_size(scene: Node) -> int:
    var log_value: Variant = scene.get("result_audio_play_log")
    return log_value.size() if log_value is Array else 0


func _dispose_scene(scene: Node) -> void:
    ## Stop any still-playing Dummy-driver result players before freeing.
    var players: Variant = scene.get("_result_players")
    if players is Array:
        for player_value: Variant in players:
            var player: AudioStreamPlayer = player_value
            if player != null:
                player.stop()
    scene.queue_free()
    await process_frame


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 4:
        push_error("Expected <bruce.glb> <brick.glb> <commentator_root> <gametext_root>")
        quit(2)
        return
    var bruce: String = args[0]
    var brick: String = args[1]
    commentator_root = args[2].replace("\\", "/")
    var text_root: String = args[3].replace("\\", "/")
    print("RESULT_AUDIO_STAGE start")

    print("RESULT_AUDIO_STAGE scenario0_begin")
    # ---- Scenario 0: recovered sample table + loaded original assets ----
    var scene: Node = _new_scene(bruce, brick, 60, text_root)
    if not await _wait_candidates(scene):
        push_error("sample-table candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    scene._reset_match()
    var sequences: Dictionary = scene.get("_game_text_sequences")
    results["sequence_count"] = sequences.size()
    if sequences.size() != 11:
        failures.append("expected 11 recovered sequences, got %d" % sequences.size())
    for index_value: Variant in RECOVERED_SAMPLES:
        var index: int = int(index_value)
        var expected: Array = RECOVERED_SAMPLES[index]
        var plan: Array = scene._game_text_sample_plan(index)
        if plan.size() != 1:
            failures.append("sequence %d sample plan has %d entries, expected 1"
                    % [index, plan.size()])
            continue
        var entry: Dictionary = plan[0]
        var sample_file: String = String(entry.get("sample", "")).get_file()
        if sample_file != String(expected[0]):
            failures.append("sequence %d sample %s, expected %s" % [
                index, sample_file, expected[0],
            ])
        if absf(float(entry.get("time", -1.0)) - float(expected[1])) > 0.000001:
            failures.append("sequence %d sample time %s, expected %s" % [
                index, entry.get("time"), expected[1],
            ])
        results["seq%d_sample" % index] = [sample_file, entry.get("time")]
    for index: int in [7, 8]:
        var counter_plan: Array = scene._game_text_sample_plan(index)
        if not counter_plan.is_empty():
            failures.append("COUNTER sequence %d unexpectedly carries a sample" % index)
    # Load the original package commentator files through the patched loader.
    scene._load_result_audio()
    var loaded_value: Variant = scene.get("_result_audio")
    var loaded: Dictionary = loaded_value if loaded_value is Dictionary else {}
    var paths_value: Variant = scene.get("_result_audio_paths")
    var paths: Dictionary = paths_value if paths_value is Dictionary else {}
    results["loaded_result_audio"] = loaded.keys()
    if loaded.size() != PACKAGE_COMMENTATOR_FILES.size():
        failures.append("loaded %d result cues, expected %d" % [
            loaded.size(), PACKAGE_COMMENTATOR_FILES.size(),
        ])
    for key: String in PACKAGE_COMMENTATOR_FILES:
        if not loaded.has(key):
            failures.append("result cue %s was not loaded" % key)
            continue
        var expected_path: String = commentator_root.path_join(
            String(PACKAGE_COMMENTATOR_FILES[key])
        )
        if String(paths.get(key, "")).replace("\\", "/") != expected_path:
            failures.append("result cue %s path %s, expected %s" % [
                key, paths.get(key), expected_path,
            ])
    await _dispose_scene(scene)

    print("RESULT_AUDIO_STAGE scenario1_begin")
    # ---- Scenario 1: player KO at full health -> You_Win + Perfect ----
    scene = _new_scene(bruce, brick, 60, text_root)
    if not await _wait_candidates(scene):
        push_error("perfect candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    scene._reset_match()
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    if not _real_punch_ko_with_winner_health(scene, player, computer):
        failures.append("full-health-winner punch did not KO the computer")
    if _state(scene) != STATE_KO_WIN:
        failures.append("player KO did not enter state 7")
    # YOU_WIN is offset 0, so it must already be logged; PERFECT is at +1.5 s.
    var log_value: Variant = scene.get("result_audio_play_log")
    var immediate: Array = log_value if log_value is Array else []
    results["perfect_immediate_keys"] = _entry_keys(immediate)
    if _entry_keys(immediate) != ["win"]:
        failures.append("YOU_WIN did not fire at launch: %s" % [str(_entry_keys(immediate))])
    _advance_overlays(scene, 2.0)
    _check_audio(
        "perfect_win", scene, ["win", "perfect"], [2, 6],
        ["You_Win.wav", "Perfect.wav"],
    )
    var before_round_end: int = _audio_size(scene)
    if not _tick_until(scene, STATE_ROUND_END, 9.0):
        failures.append("state 7 did not reach state 15")
    _tick(scene, 0.2)
    _check_no_more_audio("perfect_win_round_end", scene, before_round_end)
    print("RESULT_AUDIO_STAGE scenario1_done")
    await _dispose_scene(scene)

    print("RESULT_AUDIO_STAGE scenario2_begin")
    # ---- Scenario 2: player KO at low health -> Great only ----
    scene = _new_scene(bruce, brick, 60, text_root)
    if not await _wait_candidates(scene):
        push_error("great candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    scene._reset_match()
    player = scene.get("player")
    computer = scene.get("computer")
    if not _real_punch_ko_with_winner_health(scene, player, computer, 15.0):
        failures.append("low-health-winner punch did not KO the computer")
    if _state(scene) != STATE_KO_WIN:
        failures.append("low-health player KO did not enter state 7")
    _advance_overlays(scene, 2.0)
    _check_audio("great_win", scene, ["great"], [9], ["Great.wav"])
    print("RESULT_AUDIO_STAGE scenario2_done")
    await _dispose_scene(scene)

    print("RESULT_AUDIO_STAGE scenario3_begin")
    # ---- Scenario 3: player KO loss -> You_Lose only ----
    scene = _new_scene(bruce, brick, 60, text_root)
    if not await _wait_candidates(scene):
        push_error("lose candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    scene._reset_match()
    player = scene.get("player")
    computer = scene.get("computer")
    if not _real_punch_ko_with_winner_health(scene, computer, player):
        failures.append("opponent punch did not KO the player")
    if _state(scene) != STATE_KO_LOSE:
        failures.append("player KO did not enter state 8")
    _advance_overlays(scene, 2.0)
    _check_audio("you_lose", scene, ["lose"], [3], ["You_Lose.wav"])
    print("RESULT_AUDIO_STAGE scenario3_done")
    await _dispose_scene(scene)

    print("RESULT_AUDIO_STAGE scenario4_begin")
    # ---- Scenario 4: time up, equal health -> Time_Out then Draw ----
    scene = _new_scene(bruce, brick, 3, text_root)
    if not await _wait_candidates(scene):
        push_error("draw candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    scene._reset_match()
    player = scene.get("player")
    computer = scene.get("computer")
    player.health = 50.0
    computer.health = 50.0
    if not _tick_until(scene, STATE_TIME_UP):
        failures.append("timer 0 did not enter state 5")
    var time_up_log_value: Variant = scene.get("result_audio_play_log")
    var time_up_log: Array = time_up_log_value if time_up_log_value is Array else []
    results["time_up_keys"] = _entry_keys(time_up_log)
    if _entry_keys(time_up_log) != ["time_out"]:
        failures.append("time-up fired %s, expected Time_Out once" % [str(_entry_keys(time_up_log))])
    if not _tick_until(scene, STATE_DRAW):
        failures.append("equal health time up did not enter state 11")
    _advance_overlays(scene, 2.5)
    _check_audio(
        "draw", scene, ["time_out", "draw"], [4, 5], ["Time_Out.wav", "Draw.wav"],
    )
    print("RESULT_AUDIO_STAGE scenario4_done")
    await _dispose_scene(scene)

    print("RESULT_AUDIO_STAGE scenario5_begin")
    # ---- Scenario 5: time up, player ahead at 100 -> Time_Out/Win/Perfect -
    scene = _new_scene(bruce, brick, 3, text_root)
    if not await _wait_candidates(scene):
        push_error("time-up perfect candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    scene._reset_match()
    player = scene.get("player")
    computer = scene.get("computer")
    player.health = 100.0
    computer.health = 40.0
    if not _tick_until(scene, STATE_TIME_UP):
        failures.append("timer 0 did not enter state 5 (time-up perfect)")
    if not _tick_until(scene, STATE_KO_WIN):
        failures.append("time up did not decide the round for the player")
    _advance_overlays(scene, 2.0)
    _check_audio(
        "time_up_perfect", scene, ["time_out", "win", "perfect"], [4, 2, 6],
        ["Time_Out.wav", "You_Win.wav", "Perfect.wav"],
    )
    print("RESULT_AUDIO_STAGE scenario5_done")
    await _dispose_scene(scene)

    print("RESULT_AUDIO_STAGE scenario6_begin")
    # ---- Scenario 6: final-round match end must not replay You_Win ----
    scene = _new_scene(bruce, brick, 60, text_root)
    if not await _wait_candidates(scene):
        push_error("match-end candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    scene._reset_match()
    scene.set("player_rounds", 1)
    player = scene.get("player")
    computer = scene.get("computer")
    if not _real_punch_ko_with_winner_health(scene, player, computer):
        failures.append("final-round punch did not KO the computer")
    _advance_overlays(scene, 2.0)
    _check_audio(
        "match_end", scene, ["win", "perfect"], [2, 6],
        ["You_Win.wav", "Perfect.wav"],
    )
    var before_match_end: int = _audio_size(scene)
    print("RESULT_AUDIO_STAGE scenario6_before_round_end")
    if not _tick_until(scene, STATE_ROUND_END, 20.0):
        failures.append("final-round result did not reach state 15")
    print("RESULT_AUDIO_STAGE scenario6_reached_state15")
    _tick(scene, 0.5)
    print("RESULT_AUDIO_STAGE scenario6_after_tick")
    results["match_over"] = scene.get("match_over")
    if not bool(scene.get("match_over")):
        failures.append("match did not close at state 15")
    _check_no_more_audio("match_end", scene, before_match_end)
    await _dispose_scene(scene)

    print("RESULT_AUDIO_STAGE scenario7_begin")
    # ---- Scenario 7: a real two-round match: one cue set per round, and the
    # ---- match end adds nothing (the old code replayed You_Win there) ----
    scene = _new_scene(bruce, brick, 60, text_root)
    if not await _wait_candidates(scene):
        push_error("full-match candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    scene._reset_match()
    player = scene.get("player")
    computer = scene.get("computer")
    if not _real_punch_ko_with_winner_health(scene, player, computer):
        failures.append("round 1 punch did not KO the computer")
    _advance_overlays(scene, 2.0)
    var round1_log_value: Variant = scene.get("result_audio_play_log")
    var round1_log: Array = round1_log_value if round1_log_value is Array else []
    results["full_match_round1_keys"] = _entry_keys(round1_log)
    if int(scene.get("player_rounds")) != 1:
        failures.append("round 1 did not score exactly one round")
    if not _tick_until(scene, STATE_ROUND_END, 9.0):
        failures.append("round 1 did not reach state 15")
    _tick(scene, 0.2)
    if _state(scene) != STATE_FIGHT:
        failures.append("round 2 did not start after round 1")
    if int(scene.get("round_number")) != 2:
        failures.append("round number did not advance to 2")
    if not _real_punch_ko_with_winner_health(scene, player, computer):
        failures.append("round 2 punch did not KO the computer")
    _advance_overlays(scene, 2.0)
    _check_audio(
        "full_match", scene,
        ["win", "perfect", "win", "perfect"], [2, 6, 2, 6],
        ["You_Win.wav", "Perfect.wav", "You_Win.wav", "Perfect.wav"],
    )
    var before_full_match_end: int = _audio_size(scene)
    if not _tick_until(scene, STATE_ROUND_END, 20.0):
        failures.append("round 2 did not reach state 15")
    _tick(scene, 0.5)
    results["full_match_over"] = scene.get("match_over")
    results["full_match_score"] = [
        scene.get("player_rounds"), scene.get("computer_rounds"),
    ]
    if not bool(scene.get("match_over")):
        failures.append("two-round match did not close")
    _check_no_more_audio("full_match_end", scene, before_full_match_end)
    await _dispose_scene(scene)

    results["failures"] = failures
    print("RESULT_AUDIO_VALIDATION=" + JSON.stringify(results))
    quit(0 if failures.is_empty() else 1)

extends SceneTree
## Headless validation for the opt-in CFighter replay recorder
## (BRUCELEE_REPLAY_RECORD=1) wired into scripts/fighter.gd.
##
##   godot --headless --path <project> --script res://tests/validate_replay_recorder.gd
##   optional: -- --candidate-glb=<abs path to a .glb>  (asset-backed section)
##
## Every expected constant is the recovered native value already documented in
## scripts/replay_buffer.gd and scripts/replay_recorder.gd.  The test asserts:
##   A. the recorder writes the exact native 0x2c layout (independent byte reads)
##   B. record -> bytes -> record round-trip through the proven handle table
##   C. unknown animation names / handles / times fail closed
##   D. fighter.gd samples one 44-byte record per _physics_process when enabled
##   E. state 6 (NativeMatchStates) consumes the live buffers and advances at
##      the recovered 0.5x rate, identically for the encoded/decoded copy
##   F. the flag being off allocates nothing and does not change behaviour
##
## Exit code 0 = all assertions passed.

const RecorderScript = preload("res://scripts/replay_recorder.gd")
const ReplayBufferScript = preload("res://scripts/replay_buffer.gd")
const NativeStates = preload("res://scripts/native_match_states.gd")
const FighterScript = preload("res://scripts/fighter.gd")

const STRIDE: int = 44
const FPS: float = 60.0
const FRAME_MS: int = 17
const TABLE: Array[String] = [
    "m01_idle_01", "m01_kick_low_01", "m01_pnch_low_01",
]

var failures: Array[String] = []
var candidate_glb: String = ""


func _initialize() -> void:
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--candidate-glb="):
            candidate_glb = argument.trim_prefix("--candidate-glb=")
    call_deferred("_run")


func _run() -> void:
    _check_layout()
    _check_pure_roundtrip()
    _check_fail_closed()
    await _check_fighter_wiring()
    await _check_state6_live()
    await _check_flag_off()
    await _check_asset_backed()
    if failures.is_empty():
        print("REPLAY_RECORDER_VALIDATION=PASS")
        quit(0)
        return
    print("REPLAY_RECORDER_VALIDATION=FAIL count=%d" % failures.size())
    quit(1)


# ---------------------------------------------------------------------------
# A. constants
# ---------------------------------------------------------------------------
func _check_layout() -> void:
    _expect(int(RecorderScript.RECORD_STRIDE) == STRIDE, "recorder stride is 0x2c")
    _expect(int(RecorderScript.OFFSET_POSITION) == 0, "recorder position at +0x00")
    _expect(int(RecorderScript.OFFSET_ROTATION) == 12, "recorder rotation at +0x0c")
    _expect(int(RecorderScript.OFFSET_ANIMATION) == 28, "recorder animation at +0x1c")
    _expect(int(RecorderScript.OFFSET_FLOAT_PARAM) == 32, "recorder float param at +0x20")
    _expect(int(RecorderScript.OFFSET_SET_INDEX) == 36, "recorder set byte at +0x24")
    _expect(int(RecorderScript.OFFSET_TIME_MS) == 40, "recorder time at +0x28")
    _expect(int(RecorderScript.RECORD_STRIDE) == int(ReplayBufferScript.RECORD_STRIDE),
        "recorder stride matches the recovered buffer")
    _expect(int(RecorderScript.OFFSET_POSITION) == int(ReplayBufferScript.OFFSET_POSITION),
        "recorder position matches the recovered buffer")
    _expect(int(RecorderScript.OFFSET_ROTATION) == int(ReplayBufferScript.OFFSET_ROTATION),
        "recorder rotation matches the recovered buffer")
    _expect(int(RecorderScript.OFFSET_ANIMATION) == int(ReplayBufferScript.OFFSET_ANIMATION),
        "recorder animation slot matches the recovered buffer")
    _expect(int(RecorderScript.OFFSET_FLOAT_PARAM) == int(ReplayBufferScript.OFFSET_FLOAT_PARAM),
        "recorder float slot matches the recovered buffer")
    _expect(int(RecorderScript.OFFSET_SET_INDEX) == int(ReplayBufferScript.OFFSET_SET_INDEX),
        "recorder set slot matches the recovered buffer")
    _expect(int(RecorderScript.OFFSET_TIME_MS) == int(ReplayBufferScript.OFFSET_TIME_MS),
        "recorder time slot matches the recovered buffer")


# ---------------------------------------------------------------------------
# B. pure record -> bytes -> record round-trip
# ---------------------------------------------------------------------------
func _check_pure_roundtrip() -> void:
    var recorder = RecorderScript.new()
    recorder.configure(["m01_pnch_low_01", "m01_idle_01", "m01_kick_low_01", "m01_idle_01"])
    _expect(recorder.animation_table == TABLE,
        "handle table is de-duplicated and sorted, got %s" % str(recorder.animation_table))
    _expect(recorder.handle_for("m01_kick_low_01") == 1,
        "handle is the index in the sorted table")
    _expect(recorder.handle_for("all_stunned") == -1, "unknown clip has no handle")

    recorder.enabled = true
    var samples: Array[Dictionary] = [
        {"p": Vector3(1.0, 1.2, -2.0), "q": Quaternion(0.0, sin(0.3), 0.0, cos(0.3)),
            "a": "m01_idle_01", "s": 0, "t": 4000},
        {"p": Vector3(1.5, 1.2, -2.25), "q": Quaternion(0.0, sin(0.4), 0.0, cos(0.4)),
            "a": "m01_pnch_low_01", "s": 0, "t": 4017},
        {"p": Vector3(2.0, 1.3, -2.5), "q": Quaternion(0.0, sin(0.5), 0.0, cos(0.5)),
            "a": "m01_kick_low_01", "s": 1, "t": 4034},
    ]
    for sample: Dictionary in samples:
        _expect(recorder.append_sample(sample["p"], sample["q"], sample["a"],
                int(sample["s"]), int(sample["t"])),
            "append accepted %s" % String(sample["a"]))
    _expect(recorder.size() == samples.size(), "three records stored")
    _expect(recorder.status()["float_param_unrecovered"] == true,
        "the +0x20 blend float stays flagged as unrecovered")

    var bytes: PackedByteArray = recorder.encode()
    _expect(bytes.size() == samples.size() * STRIDE,
        "encode produced %d bytes for %d records" % [bytes.size(), samples.size()])
    if bytes.size() != samples.size() * STRIDE:
        return
    # Independent byte-level read: do not trust the buffer's own decoder.
    for index: int in samples.size():
        var base: int = index * STRIDE
        var sample: Dictionary = samples[index]
        var position: Vector3 = sample["p"]
        var rotation: Quaternion = sample["q"]
        _expect(absf(bytes.decode_float(base + 0) - position.x) < 0.000001,
            "record %d raw x" % index)
        _expect(absf(bytes.decode_float(base + 4) - position.y) < 0.000001,
            "record %d raw y" % index)
        _expect(absf(bytes.decode_float(base + 8) - position.z) < 0.000001,
            "record %d raw z" % index)
        _expect(absf(bytes.decode_float(base + 12) - rotation.x) < 0.000001,
            "record %d raw quat x" % index)
        _expect(absf(bytes.decode_float(base + 24) - rotation.w) < 0.000001,
            "record %d raw quat w" % index)
        _expect(bytes.decode_u32(base + 28) == TABLE.find(String(sample["a"])),
            "record %d raw animation handle" % index)
        _expect(absf(bytes.decode_float(base + 32)) < 0.000001,
            "record %d raw +0x20 is 0.0 (unrecovered)" % index)
        _expect(bytes.decode_u8(base + 36) == int(sample["s"]),
            "record %d raw set byte" % index)
        _expect(bytes.decode_u8(base + 37) == 0 and bytes.decode_u8(base + 38) == 0
                and bytes.decode_u8(base + 39) == 0,
            "record %d padding +0x25..+0x27 is zero" % index)
        _expect(bytes.decode_u32(base + 40) == int(sample["t"]),
            "record %d raw time" % index)

    var decoded = RecorderScript.new()
    _expect(decoded.decode(bytes, TABLE), "record bytes decode through the same table")
    _expect(decoded.size() == samples.size(), "decoded record count")
    if decoded.size() == samples.size():
        for index: int in samples.size():
            var source: Dictionary = samples[index]
            var record: Dictionary = decoded.buffer.records[index]
            _expect(Vector3(record["position"]).is_equal_approx(source["p"]),
                "decoded %d position round-trips" % index)
            _expect(Quaternion(record["rotation"]).is_equal_approx(source["q"]),
                "decoded %d rotation round-trips" % index)
            _expect(String(record["animation"]) == String(source["a"]),
                "decoded %d animation round-trips" % index)
            _expect(int(record["set_index"]) == int(source["s"]),
                "decoded %d set byte round-trips" % index)
            _expect(int(record["time_ms"]) == int(source["t"]),
                "decoded %d time round-trips" % index)
    var reencoded: PackedByteArray = decoded.encode()
    _expect(reencoded == bytes, "decode -> encode reproduces the same 0x2c bytes")


# ---------------------------------------------------------------------------
# C. fail-closed paths
# ---------------------------------------------------------------------------
func _check_fail_closed() -> void:
    var recorder = RecorderScript.new()
    recorder.configure(TABLE)
    recorder.enabled = true
    _expect(not recorder.append_sample(Vector3.ZERO, Quaternion.IDENTITY,
            "all_stunned", 0, 1000),
        "a clip outside the proven table is refused")
    _expect(String(recorder.last_error).begins_with("unknown-animation-handle"),
        "unknown clip names itself, got %s" % recorder.last_error)
    _expect(recorder.size() == 0 and recorder.rejected == 1,
        "refused record is counted, not stored")

    _expect(not recorder.append_sample(Vector3.ZERO, Quaternion.IDENTITY, "", 0, 1000),
        "an empty animation name is refused")
    _expect(String(recorder.last_error).begins_with("no-animation-name"),
        "empty animation names itself, got %s" % recorder.last_error)

    _expect(recorder.append_sample(Vector3.ZERO, Quaternion.IDENTITY,
            "m01_idle_01", 0, 2000), "monotonic record accepted")
    _expect(not recorder.append_sample(Vector3.ZERO, Quaternion.IDENTITY,
            "m01_idle_01", 0, 1999),
        "a regressing time is refused (RecordReplayUpdate assumes non-decreasing)")
    _expect(String(recorder.last_error).begins_with("non-monotonic-time"),
        "time regression names itself, got %s" % recorder.last_error)

    recorder.enabled = false
    _expect(not recorder.append_sample(Vector3.ZERO, Quaternion.IDENTITY,
            "m01_idle_01", 0, 3000), "a disabled recorder refuses samples")
    recorder.enabled = true

    var empty_table = RecorderScript.new()
    empty_table.enabled = true
    _expect(not empty_table.append_sample(Vector3.ZERO, Quaternion.IDENTITY,
            "m01_idle_01", 0, 1000),
        "an empty handle table refuses every sample")
    _expect(String(empty_table.last_error).begins_with("no-animation-table"),
        "empty table names itself, got %s" % empty_table.last_error)

    var encoded: PackedByteArray = recorder.encode()
    var wide = RecorderScript.new()
    wide.configure(TABLE)
    wide.enabled = true
    wide.append_sample(Vector3.ZERO, Quaternion.IDENTITY, "m01_pnch_low_01", 0, 5000)
    var wide_bytes: PackedByteArray = wide.encode()
    var short_table: Array[String] = ["m01_idle_01", "m01_kick_low_01"]
    var decoded = RecorderScript.new()
    _expect(not decoded.decode(wide_bytes, short_table),
        "a handle outside the supplied table is rejected on decode")
    _expect(String(decoded.last_error).begins_with("unknown-animation-handle"),
        "decode rejection names itself, got %s" % decoded.last_error)
    _expect(not decoded.decode(PackedByteArray(), TABLE),
        "an empty byte buffer is rejected on decode")
    _expect(String(decoded.last_error).begins_with("bad-replay-format"),
        "empty byte buffer names itself, got %s" % decoded.last_error)
    _expect(encoded.size() == STRIDE, "the surviving record still encodes")


# ---------------------------------------------------------------------------
# D. fighter.gd wiring: one 0x2c record per physics frame
# ---------------------------------------------------------------------------
func _make_fighter(is_player: bool) -> PortFighter:
    var fighter: PortFighter = FighterScript.new()
    fighter.configure("Replay recorder test", is_player, Color.WHITE)
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    fighter.set_physics_process(false)
    return fighter


func _check_fighter_wiring() -> void:
    _set_env("BRUCELEE_REPLAY_RECORD", "1")
    _set_env("BRUCELEE_PLAYER_GLB", "")
    _set_env("BRUCELEE_OPPONENT_GLB", "")
    var player: PortFighter = _make_fighter(true)
    var computer: PortFighter = _make_fighter(false)
    player.opponent = computer
    computer.opponent = player
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    computer.reset_fighter(Vector3(1.0, 1.2, 0.0))

    _expect(player.replay_record_enabled, "BRUCELEE_REPLAY_RECORD=1 enables the recorder")
    _expect(player.replay_recorder != null, "the fighter owns a recorder")
    _expect(String(player.replay_record_error).is_empty(),
        "no recorder setup error, got %s" % player.replay_record_error)
    if player.replay_recorder == null:
        player.queue_free()
        computer.queue_free()
        await process_frame
        return

    var table: Array[String] = player.replay_animation_table()
    _expect(not table.is_empty(), "the handle table is not empty")
    var clip_count: int = _unique_clip_count(player.candidate_clips)
    _expect(table.size() >= clip_count,
        "handle table covers the recovered clip table (%d entries >= %d clips)"
        % [table.size(), clip_count])
    var missing_clip: String = ""
    for action: Variant in player.candidate_clips:
        var clip: String = String(player.candidate_clips[action])
        if not clip.is_empty() and table.find(clip) < 0:
            missing_clip = clip
    _expect(missing_clip.is_empty(),
        "every recovered slot clip has a handle, missing %s" % missing_clip)
    _expect(table.find("all_impct_light_frnt_high") >= 0,
        "recovered reaction clips (not in CANDIDATE_CLIPS) are in the table")
    var sorted_copy: Array[String] = table.duplicate()
    sorted_copy.sort()
    _expect(table == sorted_copy, "handle table is ascending")
    for index: int in table.size() - 1:
        _expect(table[index] != table[index + 1], "handle table has no duplicate at %d" % index)
    _expect(player.replay_recorder.animation_table == table,
        "the recorder uses the fighter's proven table")

    var clock: int = 50000
    player.replay_record_clock_override_ms = clock
    for frame: int in 5:
        player.replay_record_clock_override_ms = clock + frame * FRAME_MS
        player._physics_process(1.0 / FPS)
    _expect(player.replay_recorder.size() == 5,
        "five _physics_process calls appended five records, got %d"
        % player.replay_recorder.size())
    var records: Array = player.replay_recorder.buffer.records
    if records.size() == 5:
        _expect(int(records[0]["time_ms"]) == 50000, "first record carries the frame clock")
        _expect(int(records[4]["time_ms"]) == 50000 + 4 * FRAME_MS,
            "record times follow the per-frame clock")
        _expect(String(records[0]["animation"]) == "m01_idle_01",
            "idle frame records m01_idle_01, got %s" % records[0]["animation"])
        _expect(Vector3(records[4]["position"]).is_equal_approx(player.global_position),
            "recorded position is the fighter's global position")
        _expect(absf(Quaternion(records[0]["rotation"]).length() - 1.0) < 0.001,
            "recorded rotation is a unit quaternion")
        _expect(int(records[0]["set_index"]) == 0,
            "idle records the clear fighting-set selector")

    # Attack clip recorded from the recovered state table.
    if player.request_attack("punch"):
        player.replay_record_clock_override_ms = 50000 + 10 * FRAME_MS
        player._physics_process(1.0 / FPS)
        var last: Dictionary = player.replay_recorder.buffer.records[
            player.replay_recorder.size() - 1]
        _expect(String(last["animation"]) == "m01_pnch_low_01",
            "attack frame records the recovered punch clip, got %s" % last["animation"])

    # +0x135 selector bridge: victim states are 1, everything else 0.
    for victim_state: String in ["grabbed1", "grabbed2", "endattackcomp1", "endattackcomp2"]:
        player.state = victim_state
        _expect(player.replay_set_selector() == 1,
            "%s records the internal fighting-set selector" % victim_state)
        _expect(player.replay_animation_name()
                == String(player.candidate_clips.get(victim_state, "")),
            "%s records its recovered victim clip" % victim_state)
    for normal_state: String in ["idle", "startup", "active", "recovery", "hitstun"]:
        player.state = normal_state
        _expect(player.replay_set_selector() == 0,
            "%s records the clear fighting-set selector" % normal_state)
    player.state = "idle"

    # A victim record round-trips with the selector set.  _record_replay_frame
    # is the same call _physics_process makes, so the frame is sampled without
    # running the grabbed countdown (state_time would end the state first).
    player.state = "grabbed1"
    player.state_time = 5.0
    player.replay_record_clock_override_ms = 50000 + 20 * FRAME_MS
    player._record_replay_frame()
    var victim_record: Dictionary = player.replay_recorder.buffer.records[
        player.replay_recorder.size() - 1]
    _expect(int(victim_record["set_index"]) == 1,
        "victim frame is stored with +0x24 = 1")
    player.state = "idle"
    player.state_time = 0.0

    # SetState case 6 clears +0x16f: the port stops recording on request.
    var before: int = player.replay_recorder.size()
    player.set_replay_recording(false)
    _expect(not player.replay_record_enabled, "set_replay_recording(false) disables appends")
    player.replay_record_clock_override_ms = 50000 + 30 * FRAME_MS
    player._physics_process(1.0 / FPS)
    _expect(player.replay_recorder.size() == before,
        "no record is appended while recording is off")
    player.set_replay_recording(true)
    player.replay_record_clock_override_ms = 50000 + 31 * FRAME_MS
    player._physics_process(1.0 / FPS)
    _expect(player.replay_recorder.size() == before + 1,
        "re-enabling recording resumes the append path")

    # reset_fighter starts a new recording (the native container is per match).
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    _expect(player.replay_recorder.size() == 0, "reset_fighter clears the recording")

    player.queue_free()
    computer.queue_free()
    await process_frame


func _unique_clip_count(clips: Dictionary) -> int:
    var names: Dictionary = {}
    for action: Variant in clips:
        var clip: String = String(clips[action])
        if not clip.is_empty():
            names[clip] = true
    return names.size()


# ---------------------------------------------------------------------------
# E. state 6 consumes the live buffers at the recovered 0.5x rate
# ---------------------------------------------------------------------------
func _check_state6_live() -> void:
    _set_env("BRUCELEE_REPLAY_RECORD", "1")
    var player: PortFighter = _make_fighter(true)
    var computer: PortFighter = _make_fighter(false)
    player.opponent = computer
    computer.opponent = player
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    computer.reset_fighter(Vector3(1.2, 1.2, 0.0))

    var frames: int = 120
    var base_ms: int = 60000
    for frame: int in frames:
        var now: int = base_ms + frame * FRAME_MS
        player.replay_record_clock_override_ms = now
        computer.replay_record_clock_override_ms = now
        if frame == 5:
            player.request_attack("punch")
        if frame == 8:
            computer.move_axis = Vector2(-1.0, 0.0)
        if frame == 60:
            computer.move_axis = Vector2.ZERO
        player._physics_process(1.0 / FPS)
        computer._physics_process(1.0 / FPS)

    _expect(player.replay_recorder.size() == frames,
        "player recorded %d frames, got %d" % [frames, player.replay_recorder.size()])
    _expect(computer.replay_recorder.size() == frames,
        "computer recorded %d frames, got %d" % [frames, computer.replay_recorder.size()])

    var live_base: int = player.replay_recorder.first_time_ms()
    _expect(live_base == base_ms, "record 0 time is the match clock %d" % base_ms)

    # Encode/decode copy: same table, same record fields, same bytes twice.
    var player_bytes: PackedByteArray = player.replay_recorder.encode()
    var computer_bytes: PackedByteArray = computer.replay_recorder.encode()
    _expect(player_bytes.size() == frames * STRIDE,
        "live player buffer encodes to %d bytes, got %d" % [frames * STRIDE,
            player_bytes.size()])
    var decoded_player = RecorderScript.new()
    var decoded_computer = RecorderScript.new()
    _expect(decoded_player.decode(player_bytes, player.replay_animation_table()),
        "live player recording decodes")
    _expect(decoded_computer.decode(computer_bytes, computer.replay_animation_table()),
        "live computer recording decodes")
    _expect(decoded_player.encode() == player_bytes,
        "player recording survives bytes -> records -> bytes unchanged")
    for index: int in mini(player.replay_recorder.size(), decoded_player.size()):
        var live: Dictionary = player.replay_recorder.buffer.records[index]
        var copy: Dictionary = decoded_player.buffer.records[index]
        if not Vector3(live["position"]).is_equal_approx(copy["position"]) \
                or String(live["animation"]) != String(copy["animation"]) \
                or int(live["time_ms"]) != int(copy["time_ms"]) \
                or int(live["set_index"]) != int(copy["set_index"]):
            _expect(false, "decoded record %d equals the live record" % index)
            break

    var states = NativeStates.new()
    states.set_replay_buffers(player.replay_recorder.buffer,
        computer.replay_recorder.buffer, live_base)
    _expect(states.enter(NativeStates.STATE_REPLAY),
        "state 6 accepts the two live buffers, reason=%s" % states.fail_reason)

    var copy_states = NativeStates.new()
    copy_states.set_replay_buffers(decoded_player.buffer, decoded_computer.buffer,
        live_base)
    _expect(copy_states.enter(NativeStates.STATE_REPLAY),
        "state 6 accepts the decoded copy, reason=%s" % copy_states.fail_reason)

    var steps: int = 0
    while steps < 600 and int(states.replay_loops) == 0:
        var loops_before: int = int(states.replay_loops)
        states.advance(1.0 / FPS)
        copy_states.advance(1.0 / FPS)
        steps += 1
        if int(states.replay_loops) != loops_before:
            break
        var elapsed_ms: int = int(round(states.state_time * 1000.0))
        var threshold: float = float(live_base) + 0.5 * float(elapsed_ms)
        var expected: int = 0
        for record: Dictionary in player.replay_recorder.buffer.records:
            if float(int(record["time_ms"])) <= threshold:
                expected += 1
        var player_cursor: int = int(player.replay_recorder.buffer.cursor)
        if player_cursor != mini(expected, frames):
            _expect(false, "cursor follows base + 0.5*elapsed at step %d: %d != %d"
                % [steps, player_cursor, mini(expected, frames)])
            break
        if int(copy_states.state) != int(states.state) \
                or int(decoded_player.buffer.cursor) != player_cursor \
                or int(copy_states.replay_loops) != int(states.replay_loops):
            _expect(false, "decoded copy replays identically at step %d" % steps)
            break

    _expect(int(states.replay_loops) == 1,
        "state 6 loops SetState(6) once the recorded content is exhausted (steps=%d)"
        % steps)
    _expect(int(states.state) == NativeStates.STATE_REPLAY, "state 6 stays active")
    _expect(states.replay_countdown_seconds() == ReplayBufferScript.replay_countdown_seconds(
            int(floor(states.state_time * 1000.0))),
        "the 11000 ms display countdown follows the recovered formula")
    _expect(states.replay_countdown_seconds() >= 0
            and states.replay_countdown_seconds() <= 10,
        "the display countdown is clamped to 0..10")

    # Half speed, not double: after e ms of replay the reached record offset is
    # 0.5*e, so a 1000 ms replay covers 500 ms of recorded content.
    var half = ReplayBufferScript.new()
    half.append_record(Vector3.ZERO, Quaternion.IDENTITY, "m01_idle_01", 0.0, 0, 7000)
    half.append_record(Vector3.ONE, Quaternion.IDENTITY, "m01_idle_01", 0.0, 0, 7500)
    half.set_replay_current_time(7000)
    half.record_replay_update(999 + 2 * 7000, 0.5)
    _expect(half.cursor == 1, "999 ms of replay still covers only 0.5*999 = 499 ms")
    half.record_replay_update(1000 + 2 * 7000, 0.5)
    _expect(half.cursor == 2, "1000 ms of replay reaches the +500 ms record")

    player.queue_free()
    computer.queue_free()
    await process_frame


# ---------------------------------------------------------------------------
# F. flag off: no recorder, no behaviour change
# ---------------------------------------------------------------------------
func _check_flag_off() -> void:
    _set_env("BRUCELEE_REPLAY_RECORD", "0")
    var fighter: PortFighter = _make_fighter(true)
    _expect(not fighter.replay_record_enabled, "the default path leaves recording off")
    _expect(fighter.replay_recorder == null, "the default path allocates no recorder")
    _expect(String(fighter.replay_record_error).is_empty(), "no error is raised when off")
    fighter.reset_fighter(Vector3.ZERO)
    for frame: int in 10:
        fighter._physics_process(1.0 / FPS)
    _expect(fighter.replay_recorder == null, "a full default-path frame allocates nothing")
    fighter.queue_free()
    await process_frame

    var off_a: Array[String] = await _simulate_trace("0")
    var off_b: Array[String] = await _simulate_trace("0")
    var on: Array[String] = await _simulate_trace("1")
    _expect(off_a == off_b, "the default path is deterministic (%d frames)" % off_a.size())
    if off_a != off_b:
        _report_trace_difference("default-path determinism", off_a, off_b)
    _expect(off_a == on, "enabling the recorder does not change the fight (%d frames)"
        % off_a.size())
    if off_a != on:
        _report_trace_difference("recorder on/off", off_a, on)


func _report_trace_difference(label: String, left: Array[String],
        right: Array[String]) -> void:
    for index: int in mini(left.size(), right.size()):
        if left[index] != right[index]:
            print("TRACE_DIFF[%s] frame %d" % [label, index])
            print("  off: " + left[index])
            print("  on : " + right[index])
            return


## One scripted fight, returning a per-frame trace of every observable the
## recorder could conceivably touch.  Y is deliberately excluded: the port
## applies gravity through move_and_slide(), which integrates with the engine's
## real frame delta; this harness calls _physics_process() by hand, so Y carries
## engine timing noise that predates the recorder and is unrelated to it.  Every
## other field (state, attack, clip, health, X/Z, facing) is comparable exactly.
func _simulate_trace(flag: String) -> Array[String]:
    _set_env("BRUCELEE_REPLAY_RECORD", flag)
    var player: PortFighter = _make_fighter(true)
    var computer: PortFighter = _make_fighter(false)
    player.opponent = computer
    computer.opponent = player
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    computer.reset_fighter(Vector3(0.9, 1.2, 0.0))
    # This comparison is about the recorder, not about physics: the two
    # capsules overlap during the punch, and move_and_slide() resolves that
    # overlap with the engine's real frame delta, which is timing noise in a
    # harness that calls _physics_process() by hand.  Switch collision off so
    # the only position changes left are the deterministic root-motion ones.
    player.collision_layer = 0
    player.collision_mask = 0
    computer.collision_layer = 0
    computer.collision_mask = 0
    player.replay_record_clock_override_ms = 1000
    computer.replay_record_clock_override_ms = 1000
    var trace: Array[String] = []
    for frame: int in 120:
        player.replay_record_clock_override_ms = 1000 + frame * FRAME_MS
        computer.replay_record_clock_override_ms = 1000 + frame * FRAME_MS
        match frame:
            2:
                player.request_attack("punch")
            20:
                player.request_attack("kick")
            40:
                computer.request_attack("punch")
            55:
                player.move_axis = Vector2(0.0, -1.0)
            70:
                player.move_axis = Vector2.ZERO
                player.guard_held = true
            90:
                player.guard_held = false
        player._physics_process(1.0 / FPS)
        computer._physics_process(1.0 / FPS)
        trace.append(JSON.stringify({
            "f": frame,
            "ps": player.state,
            "pa": player.attack_kind,
            "px": player.global_position.x,
            "pz": player.global_position.z,
            "pr": player.rotation.y,
            "ph": player.health,
            "pc": player.candidate_animation_clip,
            "cs": computer.state,
            "ca": computer.attack_kind,
            "cx": computer.global_position.x,
            "cz": computer.global_position.z,
            "ch": computer.health,
        }))
    if flag == "1":
        _expect(player.replay_recorder != null
                and player.replay_recorder.size() == 120,
            "the recorded run captured all 120 frames")
        _expect(computer.replay_recorder != null
                and computer.replay_recorder.size() == 120,
            "both fighters record when the flag is on")
    player.queue_free()
    computer.queue_free()
    await process_frame
    return trace


# ---------------------------------------------------------------------------
# G. optional asset-backed run (real candidate AnimationPlayer clips)
# ---------------------------------------------------------------------------
func _check_asset_backed() -> void:
    if candidate_glb.is_empty():
        print("SKIP asset-backed section (pass -- --candidate-glb=<path>)")
        _expect(true, "asset-backed section was skipped explicitly")
        return
    if not FileAccess.file_exists(candidate_glb):
        _expect(false, "candidate GLB does not exist: " + candidate_glb)
        return
    _set_env("BRUCELEE_REPLAY_RECORD", "1")
    var player: PortFighter = FighterScript.new()
    player.configure("Recorder asset test", true, Color.WHITE)
    player.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    player.configure_candidate_asset(candidate_glb, "")
    root.add_child(player)
    player.set_physics_process(false)
    await process_frame
    if not player.candidate_loaded:
        _expect(false, "candidate GLB loaded, error=%s" % player.candidate_load_error)
        player.queue_free()
        await process_frame
        return
    player.reset_fighter(Vector3.ZERO)
    var clips: Dictionary = {}
    var table: Array[String] = player.replay_animation_table()
    var now: int = 70000
    for frame: int in 90:
        player.replay_record_clock_override_ms = now + frame * FRAME_MS
        if frame == 3:
            player.request_attack("punch")
        player._physics_process(1.0 / FPS)
        var record: Dictionary = player.replay_recorder.buffer.records[
            player.replay_recorder.size() - 1]
        clips[String(record["animation"])] = true
        if table.find(String(record["animation"])) < 0:
            _expect(false, "asset frame %d clip %s is in the proven table"
                % [frame, record["animation"]])
            break
        if String(record["animation"]) != player.candidate_animation_clip:
            _expect(false, "asset frame %d records the playing clip" % frame)
            break
    _expect(player.replay_recorder.rejected == 0,
        "asset run appended every frame without a refusal")
    # A synchronous _physics_process loop cannot finish an attack: the state
    # machine waits for the AnimationPlayer, which only advances on real
    # frames.  Idle + one attack clip is therefore the most this harness can
    # record, and it is exactly what proves the clip -> handle mapping.
    _expect(clips.size() >= 2,
        "asset run recorded idle plus an attack clip, got %s" % str(clips.keys()))
    var bytes: PackedByteArray = player.replay_recorder.encode()
    var decoded = RecorderScript.new()
    _expect(decoded.decode(bytes, table), "asset recording decodes")
    _expect(decoded.encode() == bytes, "asset recording round-trips byte-exactly")
    print("ASSET_BACKED clips=%s records=%d" % [str(clips.keys()),
        player.replay_recorder.size()])
    player.queue_free()
    await process_frame


# ---------------------------------------------------------------------------
func _set_env(name: String, value: String) -> void:
    OS.set_environment(name, value)


func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS " + description)
    else:
        failures.append(description)
        print("FAIL " + description)

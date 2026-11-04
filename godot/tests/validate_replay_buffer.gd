extends SceneTree
## Headless validation for the recovered CFighter replay buffer (state 6).
## Pure logic: no scene, no assets.  Every expected value is the native constant
## recovered from libdefault.so (see scripts/replay_buffer.gd header).
##
##   godot --headless --path <godot-copy> --script res://tests/validate_replay_buffer.gd

const ReplayBufferScript = preload("res://scripts/replay_buffer.gd")
const NativeStates = preload("res://scripts/native_match_states.gd")

var failures: Array[String] = []


func _initialize() -> void:
    _check_layout()
    _check_roundtrip()
    _check_bad_format()
    _check_seek()
    _check_half_speed()
    _check_countdown()
    _check_state_machine()
    if failures.is_empty():
        print("REPLAY_BUFFER_VALIDATION=PASS")
        quit(0)
    else:
        for failure in failures:
            push_error("REPLAY_FAIL " + failure)
        print("REPLAY_BUFFER_VALIDATION=FAIL count=%d" % failures.size())
        quit(1)


func _fixture(times: Array):
    var buffer = ReplayBufferScript.new()
    for i in times.size():
        buffer.append_record(
            Vector3(float(i), 0.5 * float(i), 1.0),
            Quaternion(0.0, 0.0, 0.0, 1.0),
            "m01_idle_01" if i == 0 else "m01_pnch_low_01",
            0.0, i % 2, int(times[i]))
    return buffer


func _check_layout() -> void:
    _expect(int(ReplayBufferScript.RECORD_STRIDE) == 44, "record stride is 0x2c (44 bytes)")
    _expect(int(ReplayBufferScript.OFFSET_POSITION) == 0, "position at +0x00")
    _expect(int(ReplayBufferScript.OFFSET_ROTATION) == 12, "rotation at +0x0c")
    _expect(int(ReplayBufferScript.OFFSET_ANIMATION) == 28, "animation handle at +0x1c")
    _expect(int(ReplayBufferScript.OFFSET_FLOAT_PARAM) == 32, "float param at +0x20")
    _expect(int(ReplayBufferScript.OFFSET_SET_INDEX) == 36, "set index at +0x24")
    _expect(int(ReplayBufferScript.OFFSET_TIME_MS) == 40, "time at +0x28")
    _expect(is_equal_approx(ReplayBufferScript.STATE6_SPEED_SCALE, 0.5),
        "state-6 fighter +0x140 speed scale is 0.5")
    _expect(int(ReplayBufferScript.REPLAY_BASE_FACTOR) == 2, "replay base factor is 2")
    _expect(int(NativeStates.REPLAY_COUNTDOWN_BUDGET_MS) == 11000, "11000 ms display budget")
    _expect(int(NativeStates.REPLAY_SPEED_FACTOR) == 2, "literal base factor constant is 2")


func _check_roundtrip() -> void:
    var buffer = _fixture([10000, 10500])
    var table: Array[String] = ["m01_idle_01", "m01_pnch_low_01"]
    var bytes: PackedByteArray = buffer.encode_records(table)
    _expect(bytes.size() == 2 * 44, "two records encode to 88 bytes, got %d" % bytes.size())
    var decoded = ReplayBufferScript.new()
    _expect(decoded.decode_records(bytes, table), "exact 0x2c bytes decode")
    _expect(decoded.size() == 2, "decoded record count is 2")
    if decoded.size() == 2:
        var first: Dictionary = decoded.records[0]
        var first_position: Vector3 = first["position"]
        _expect(first_position.is_equal_approx(Vector3(0.0, 0.0, 1.0)),
            "decoded position round-trips")
        _expect(int(first["time_ms"]) == 10000, "decoded time round-trips")
        _expect(String(decoded.records[1]["animation"]) == "m01_pnch_low_01",
            "decoded animation handle resolves through the table")


func _check_bad_format() -> void:
    var bad: PackedByteArray = PackedByteArray()
    bad.resize(43)
    var empty_table: Array[String] = []
    var decoded = ReplayBufferScript.new()
    _expect(not decoded.decode_records(bad, empty_table),
        "43-byte buffer is rejected (not a multiple of 0x2c)")
    _expect(String(decoded.last_error).begins_with("bad-replay-format"),
        "bad format names itself, got %s" % decoded.last_error)
    var buffer = _fixture([10000])
    var no_table: Array[String] = []
    var encoded: PackedByteArray = buffer.encode_records(no_table)
    _expect(encoded.is_empty(), "unknown animation handle fails closed on encode")


func _check_seek() -> void:
    var buffer = _fixture([10000, 10500, 11000])
    var at_start: Dictionary = buffer.set_replay_current_time(10000)
    _expect(int(at_start["cursor"]) == 0 and not bool(at_start["applied"]),
        "seek to the first record time leaves cursor 0")
    var exact: Dictionary = buffer.set_replay_current_time(10500)
    _expect(int(exact["cursor"]) == 1,
        "seek to a later record's exact time selects that record")
    _expect(bool(exact["interpolation_unrecovered"]),
        "boundary seek still uses the native frame-interpolation path")
    var mid: Dictionary = buffer.set_replay_current_time(10250)
    _expect(int(mid["cursor"]) == 1 and not bool(mid["applied"]),
        "seek inside an interval selects the next record")
    _expect(bool(mid["interpolation_unrecovered"]),
        "inside-interval seek flags anmRoot::SetToSample as unrecovered")


func _check_half_speed() -> void:
    # base=10000; records every 500 ms absolute.  With +0x140=0.5 and
    # sample = elapsed + 2*base: record at base+delta is reached when
    # delta <= 0.5*elapsed, i.e. elapsed >= 2*delta  ->  0.5x playback.
    var buffer = _fixture([10000, 10500, 11000, 11500, 12000])
    buffer.set_replay_current_time(10000)
    _expect(buffer.cursor == 0, "playback starts at cursor 0")
    # elapsed 0 -> record 0 applies
    buffer.record_replay_update(0 + 2 * 10000, 0.5)
    _expect(buffer.cursor == 1, "elapsed 0 ms applies record 0")
    # elapsed 999 ms -> 500 ms record not yet reached
    buffer.record_replay_update(999 + 2 * 10000, 0.5)
    _expect(buffer.cursor == 1, "elapsed 999 ms still has not reached the +500 ms record")
    # elapsed 1000 ms -> +500 record reached (2x the content offset)
    buffer.record_replay_update(1000 + 2 * 10000, 0.5)
    _expect(buffer.cursor == 2, "elapsed 1000 ms reaches the +500 ms record (0.5x)")

    # Full frame simulation through the state machine.
    var player = _fixture([10000, 10500, 11000, 11500, 12000])
    var computer = _fixture([10000, 12000])
    var states = NativeStates.new()
    states.set_replay_buffers(player, computer, 10000)
    _expect(bool(states.enter(NativeStates.STATE_REPLAY)), "state 6 enters with two buffers")
    for frame in 300:  # 5 s at 60 fps
        states.advance(1.0 / 60.0)
    _expect(int(states.replay_loops) >= 1, "both ReplayEnded loop SetState(6) at least once")
    _expect(int(states.state) == NativeStates.STATE_REPLAY, "state 6 stays active while looping")


func _check_countdown() -> void:
    _expect(ReplayBufferScript.replay_countdown_seconds(0) == 10,
        "countdown at 0 ms caps to 10")
    _expect(ReplayBufferScript.replay_countdown_seconds(1000) == 10,
        "countdown at 1000 ms is 10")
    _expect(ReplayBufferScript.replay_countdown_seconds(1001) == 9,
        "countdown at 1001 ms is 9")
    _expect(ReplayBufferScript.replay_countdown_seconds(10000) == 1,
        "countdown at 10000 ms is 1")
    _expect(ReplayBufferScript.replay_countdown_seconds(11000) == 0,
        "countdown at 11000 ms is 0")
    _expect(ReplayBufferScript.replay_countdown_seconds(11001) == 10,
        "native unsigned underflow past 11000 ms clamps to 10")


func _check_state_machine() -> void:
    var states = NativeStates.new()
    _expect(not bool(states.enter(NativeStates.STATE_REPLAY)),
        "state 6 refuses to start with no buffer")
    _expect(String(states.fail_reason).begins_with("no-replay-buffer"),
        "missing replay data names itself, got %s" % states.fail_reason)

    var empty = ReplayBufferScript.new()
    states.reset()
    states.set_replay_buffers(empty, _fixture([10000]), 10000)
    _expect(not bool(states.enter(NativeStates.STATE_REPLAY)),
        "state 6 refuses an empty fighter buffer")
    _expect(String(states.fail_reason).begins_with("no-replay-buffer"),
        "empty buffer refusal names itself, got %s" % states.fail_reason)

    states.reset()
    states.set_replay_buffers(_fixture([10000]), _fixture([10000]), 10000)
    states.replay_speed_scale = 1.0
    _expect(not bool(states.enter(NativeStates.STATE_REPLAY)),
        "state 6 refuses a non-recovered speed scale")
    _expect(String(states.fail_reason).begins_with("unrecovered-replay-scale"),
        "speed-scale refusal names itself, got %s" % states.fail_reason)


func _expect(condition: bool, description: String) -> void:
    if condition:
        print("PASS " + description)
    else:
        failures.append(description)
        print("FAIL " + description)

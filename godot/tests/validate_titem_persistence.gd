extends SceneTree
## Headless unit / matrix validation of the recovered TItem pointer persistence
## and anmRoot::SetToSample in-interval sampling semantics.
##
##   godot --headless --path <godot-copy> --script res://tests/validate_titem_persistence.gd
##
## Expected values come from an INDEPENDENT Python oracle
## (tools/make_evidence.py -> tests/data/sampling_matrix.json) transcribed
## instruction-by-instruction from the ARM disassembly, and from the native
## CRC tables copied directly out of libdefault.so.

const TItemPoolScript = preload("res://scripts/titem_pool.gd")
const SampleMath = preload("res://scripts/replay_sample_math.gd")
const ReplaySeekScript = preload("res://scripts/replay_seek.gd")
const ReplayBufferScript = preload("res://scripts/replay_buffer.gd")
const FixtureEvaluator = preload("res://tests/fixtures/deterministic_root_evaluator.gd")

const CRC_JSON: String = "res://tests/data/native_crc_tables.json"
const MATRIX_JSON: String = "res://tests/data/sampling_matrix.json"

var passed: int = 0
var failures: Array[String] = []


func _initialize() -> void:
    _check_native_crc_data()
    _check_titem_lifetime()
    _check_titem_interning()
    _check_fail_closed_persistence()
    _check_sampling_oracle()
    _check_seek_composition()
    _check_seek_fail_closed()
    if failures.is_empty():
        print("TITEM_PERSISTENCE_VALIDATION=PASS pass=%d" % passed)
        quit(0)
    else:
        for failure in failures:
            push_error("TITEM_FAIL " + failure)
        print("TITEM_PERSISTENCE_VALIDATION=FAIL pass=%d fail=%d" % [passed, failures.size()])
        quit(1)


func _expect(condition: bool, label: String) -> void:
    if condition:
        passed += 1
    else:
        failures.append(label)


func _approx(a: float, b: float, label: String) -> void:
    _expect(abs(a - b) < 1e-5, "%s (got %s expected %s)" % [label, str(a), str(b)])


func _load_json(path: String) -> Variant:
    var text: String = FileAccess.get_file_as_string(path)
    if text.is_empty():
        failures.append("cannot read " + path)
        return null
    return JSON.parse_string(text)


# ---------------------------------------------------------------------------
# A. Native CRC32 / lowercase tables (direct ELF data)
# ---------------------------------------------------------------------------
func _check_native_crc_data() -> void:
    var data: Variant = _load_json(CRC_JSON)
    if data == null:
        return
    var table: Array = data["crc_table"]
    var lower: Array = data["lower_table"]
    _expect(table.size() == 256, "native gCRC32Table has 256 entries")
    _expect(lower.size() == 128, "native gLowerTable has 128 entries")
    for i in 256:
        _expect(int(TItemPoolScript.crc_table_entry(i)) == int(table[i]),
            "CRC32 table entry %d equals native ELF bytes" % i)
    var mapped: String = ""
    for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
        mapped += char(int(lower[c.to_ascii_buffer()[0]]))
    _expect(mapped == "abcdefghijklmnopqrstuvwxyz",
        "native gLowerTable maps A-Z to a-z")
    var matrix: Variant = _load_json(MATRIX_JSON)
    if matrix == null:
        return
    for case in matrix["cases"]:
        if String(case["kind"]) == "crc":
            var h: int = int(TItemPoolScript.crc32_lower(String(case["name"])))
            _expect(h == int(case["hash"]),
                "CRC32(lower(%s)) == native oracle" % case["name"])
            _expect(int(TItemPoolScript.bucket_of(h)) == int(case["bucket"]),
                "bucket = hash & 0x3ffff for %s" % case["name"])


# ---------------------------------------------------------------------------
# B. TItem lifetime / ownership (refcount matrix)
# ---------------------------------------------------------------------------
func _check_titem_lifetime() -> void:
    var pool = TItemPoolScript.new()
    var id: int = pool.new_hash_string("m01_idle_01")
    _expect(id > 0, "HashString construction returns a live TItem pointer")
    _expect(pool.refs_of(id) == 1, "HashString holds exactly one reference (+0x0c = 1)")
    _expect(pool.record_create_copy(id), "createcopy addrefs the TItem")
    _expect(pool.refs_of(id) == 2, "record copy -> refcount 2")
    _expect(pool.release(id), "caller HashString destructor releases")
    _expect(pool.refs_of(id) == 1, "record still owns one reference after caller dies")
    _expect(pool.is_alive(id), "TItem pointer PERSISTS while the record holds a ref")
    _expect(pool.name_of(id) == "m01_idle_01", "persisting TItem still resolves its string")
    _expect(pool.record_destroy(id), "destroy releases the record's reference")
    _expect(pool.refs_of(id) == -1, "released item is no longer live")
    _expect(not pool.is_alive(id), "refcount 0 -> CHStrMgr::RemoveItem freed the item")
    _expect(pool.freed_count == 1, "exactly one RemoveItem happened")
    _expect(not pool.addref(id), "use-after-free addref fails closed")
    _expect(pool.last_error.begins_with("dangling-titem"), "use-after-free reason is dangling-titem")
    _expect(not pool.release(id), "use-after-free release fails closed")
    _expect(pool.persist_name(id) == "", "freed item cannot be persisted")

    # Static singleton is never freed (RemoveItem returns immediately).
    var empty_id: int = pool.intern("")
    _expect(pool.is_alive(empty_id), "static empty TItem exists")
    for _i in 5:
        pool.release(empty_id)
    _expect(pool.is_alive(empty_id), "static empty TItem is never freed by RemoveItem")

    # Parent chain: case-insensitive collision shares a parent (AddItemAndPointToObj).
    var pool2 = TItemPoolScript.new()
    var base_id: int = pool2.new_hash_string("abc")
    pool2.record_create_copy(base_id)     # record owns it
    pool2.release(base_id)                # caller HashString gone
    var child_id: int = pool2.new_hash_string("ABC")
    _expect(child_id != base_id, "case variants are distinct interned TItems")
    _expect(pool2.hash_of(child_id) == pool2.hash_of(base_id),
        "case variants share the CRC32-lower hash")
    _expect(pool2.parent_of(child_id) == base_id,
        "new TItem points to the case-insensitive parent (+0x14)")
    _expect(pool2.refs_of(base_id) == 2, "parent is addref'd by the child")
    pool2.release(child_id)               # child freed -> parent ref released
    _expect(pool2.refs_of(base_id) == 1, "child removal releases exactly one parent ref")
    _expect(pool2.is_alive(base_id), "parent survives while its record ref remains")


# ---------------------------------------------------------------------------
# C. Interning identity / pointer persistence across records
# ---------------------------------------------------------------------------
func _check_titem_interning() -> void:
    var pool = TItemPoolScript.new()
    var a: int = pool.intern("m01_idle_01")
    var b: int = pool.intern("m01_idle_01")
    var c: int = pool.intern("m01_pnch_low_01")
    _expect(a == b, "same string interns to the same TItem pointer")
    _expect(a != c, "different strings get different TItem pointers")
    _expect(pool.hash_of(a) != pool.hash_of(c), "different strings have different hashes")
    var buffer = ReplayBufferScript.new()
    buffer.append_record(Vector3(1, 2, 3), Quaternion(0.0, 0.0, 0.0, 1.0), "m01_idle_01", 0.0, 0, 1000)
    buffer.append_record(Vector3(4, 5, 6), Quaternion(0.0, 0.0, 0.0, 1.0), "m01_pnch_low_01", 0.0, 1, 2000)
    var table: Array[String] = ["m01_idle_01", "m01_pnch_low_01"]
    var bytes: PackedByteArray = buffer.encode_records(table)
    _expect(bytes.size() == 2 * 44, "encode produces 2 x 0x2c records")
    var decoded = ReplayBufferScript.new()
    _expect(decoded.decode_records(bytes, table), "decode with the same handle table succeeds")
    _expect(String(decoded.records[0]["animation"]) == "m01_idle_01",
        "decoded record resolves the interned STRING, not a native pointer")
    var short_table: Array[String] = ["m01_idle_01"]
    var decoded2 = ReplayBufferScript.new()
    _expect(not decoded2.decode_records(bytes, short_table),
        "unknown animation handle fails closed")
    var bad = ReplayBufferScript.new()
    bad.append_record(Vector3.ZERO, Quaternion.IDENTITY, "not_in_table", 0.0, 0, 1000)
    _expect(bad.encode_records(table).is_empty(), "encoding an unregistered clip fails closed")
    _expect(bad.last_error.begins_with("unknown-animation-handle"),
        "fail-closed reason is unknown-animation-handle")


func _check_fail_closed_persistence() -> void:
    var pool = TItemPoolScript.new()
    var id: int = pool.new_hash_string("all_idle_face_up")
    _expect(pool.persist_name(id) == "all_idle_face_up",
        "persistence uses the interned string")
    _expect(not pool.refuse_pointer_serialization(id),
        "serializing the native pointer value is refused")
    _expect(pool.last_error == "pointer-serialization-refused",
        "pointer serialization reason is explicit")
    _expect(pool.is_alive(id), "refusing serialization leaves the item alive")


# ---------------------------------------------------------------------------
# D. Sampling arithmetic vs independent ARM-transcribed oracle
# ---------------------------------------------------------------------------
func _check_sampling_oracle() -> void:
    var matrix: Variant = _load_json(MATRIX_JSON)
    if matrix == null:
        return
    for case in matrix["cases"]:
        var kind: String = String(case["kind"])
        if kind == "frame":
            var got: int = SampleMath.frame_from_delta(int(case["delta_ms"]), float(case["speed"]))
            _expect(got == int(case["frame"]),
                "frame(delta=%s speed=%s) == %s" % [case["delta_ms"], case["speed"], case["frame"]])
        elif kind == "sample":
            var fields: Dictionary = SampleMath.clip_fields(
                int(case["duration_samples"]), int(case["duration_ms"]),
                int(case["smooth_flag"]))
            var got2: Dictionary = SampleMath.set_to_sample(float(case["f"]), fields)
            _expect(bool(got2["ok"]) == bool(case["ok"]),
                "sample ok for f=%s N=%s A=%s flag=%s" % [case["f"],
                    case["duration_samples"], case["duration_ms"], case["smooth_flag"]])
            if bool(got2["ok"]):
                _expect(int(got2["time_state"]) == int(case["time_state"]),
                    "time_state for f=%s A=%s flag=%s" % [case["f"],
                        case["duration_ms"], case["smooth_flag"]])
                _approx(float(got2["sample_exact"]), float(case["sample_exact"]),
                    "sample_exact for f=%s N=%s A=%s flag=%s" % [case["f"],
                        case["duration_samples"], case["duration_ms"], case["smooth_flag"]])
                _expect(int(got2["sample_index"]) == int(case["sample_index"]),
                    "sample_index for f=%s" % case["f"])
                _expect(bool(got2["fractional"]) == bool(case["fractional"]),
                    "fractional for f=%s flag=%s" % [case["f"], case["smooth_flag"]])
    # Degenerate native fields must fail closed (division by zero in CTimeController::Init).
    var bad1: Dictionary = SampleMath.clip_fields(1, 100, 0)
    _expect(not bool(bad1["ok"]), "duration_samples == 1 fails closed")
    var bad2: Dictionary = SampleMath.clip_fields(101, 0, 0)
    _expect(not bool(bad2["ok"]), "duration_ms == 0 fails closed")
    var r: Dictionary = SampleMath.set_to_sample(1.0, bad1)
    _expect(not bool(r["ok"]), "set_to_sample with degenerate fields fails closed")


# ---------------------------------------------------------------------------
# E. Full SetReplayCurrentTime composition vs oracle
# ---------------------------------------------------------------------------
func _build_seek_fixture() -> Dictionary:
    var buffer = ReplayBufferScript.new()
    var times: Array[int] = [1000, 2000, 3000, 4000]
    for i in 4:
        buffer.append_record(
            Vector3(float(i), 0.5 * float(i), 1.0 + float(i)),
            Quaternion(0.0, 0.0, 0.0, 1.0),
            "m01_idle_01" if i == 0 else "m01_pnch_low_01",
            0.0, i % 2, times[i])
    var fields: Dictionary = SampleMath.clip_fields(101, 100, 0)
    return {"buffer": buffer, "fields": fields}


func _check_seek_composition() -> void:
    var matrix: Variant = _load_json(MATRIX_JSON)
    if matrix == null:
        return
    for case in matrix["cases"]:
        if String(case["kind"]) != "seek":
            continue
        var fixture: Dictionary = _build_seek_fixture()
        var pool = TItemPoolScript.new()
        var seek = ReplaySeekScript.new()
        var evaluator = FixtureEvaluator.new()
        _expect(seek.bind(fixture["buffer"], pool, evaluator, fixture["fields"], 0.5),
            "bind replay buffer with strong TItem refs")
        var result: Dictionary = seek.seek(int(case["t"]))
        _expect(bool(result["ok"]), "seek t=%s succeeds" % case["t"])
        _expect(int(result.get("cursor", -1)) == int(case["cursor"]),
            "seek t=%s cursor == %s" % [case["t"], case["cursor"]])
        _expect(bool(result.get("applied", false)) == bool(case["applied"]),
            "seek t=%s applied == %s" % [case["t"], case["applied"]])
        if not bool(case["applied"]):
            _expect(not bool(result.get("interpolation_unrecovered", false)),
                "t <= record[0] does not hit the unrecovered branch")
        else:
            _expect(int(result["frame"]) == int(case["frame"]),
                "seek t=%s frame == %s" % [case["t"], case["frame"]])
            _approx(float(result["sample_b"]), float(case["sample_b"]),
                "seek t=%s sample_b" % case["t"])
            _expect(int(result["time_state"]) == int(case["time_state"]),
                "seek t=%s time_state" % case["t"])
            var expected: Array = case["position"]
            var pos: Vector3 = result["position"]
            _approx(pos.x, float(expected[0]), "seek t=%s pos.x" % case["t"])
            _approx(pos.y, float(expected[1]), "seek t=%s pos.y" % case["t"])
            _approx(pos.z, float(expected[2]), "seek t=%s pos.z" % case["t"])
            var rot: Quaternion = result["rotation"]
            _expect(rot.is_equal_approx(Quaternion(0.0, 0.0, 0.0, 1.0)),
                "seek t=%s rotation is unchanged (no rotation interpolation)" % case["t"])
            _expect(not bool(result["interpolation_unrecovered"]),
                "inside-interval seek no longer flags SetToSample as unrecovered")
        seek.unbind()
    # The original gap: baseline ReplayBuffer still refuses inside-interval seeks.
    var baseline = _build_seek_fixture()["buffer"]
    var baseline_result: Dictionary = baseline.set_replay_current_time(1500)
    _expect(bool(baseline_result.get("interpolation_unrecovered", false)),
        "baseline port still refuses inside-interval seek (gap reproduced)")
    _expect(baseline.last_seek_interpolation_unrecovered,
        "baseline port sets last_seek_interpolation_unrecovered")


# ---------------------------------------------------------------------------
# F. Fail-closed paths
# ---------------------------------------------------------------------------
func _check_seek_fail_closed() -> void:
    var fixture: Dictionary = _build_seek_fixture()
    var pool = TItemPoolScript.new()
    var seek = ReplaySeekScript.new()
    var evaluator = FixtureEvaluator.new()

    # Fractional (smooth-flag) branch: BuildFrame interpolation unrecovered.
    # A != N-1 makes CAnimState+0x20 (1/A) produce a fractional sample.
    var fractional_fields: Dictionary = SampleMath.clip_fields(101, 3366, 1)
    _expect(seek.bind(fixture["buffer"], pool, evaluator, fractional_fields, 0.5),
        "bind with smooth-flag fields")
    var r1: Dictionary = seek.seek(1500)
    _expect(not bool(r1["ok"]), "fractional sample seek fails closed")
    _expect(bool(r1.get("interpolation_unrecovered", false)),
        "fractional seek reports interpolation_unrecovered")
    _expect(seek.interpolation_unrecovered, "seek flag is set for fractional branch")
    seek.unbind()

    # No root evaluator -> fail closed.
    var fixture2: Dictionary = _build_seek_fixture()
    var pool2 = TItemPoolScript.new()
    var seek2 = ReplaySeekScript.new()
    seek2.bind(fixture2["buffer"], pool2, null, fixture2["fields"], 0.5)
    var r2: Dictionary = seek2.seek(1500)
    _expect(not bool(r2["ok"]) and String(r2["reason"]) == "no-root-evaluator",
        "missing root evaluator fails closed")
    seek2.unbind()

    # No clip timing fields -> fail closed.
    var fixture3: Dictionary = _build_seek_fixture()
    var pool3 = TItemPoolScript.new()
    var seek3 = ReplaySeekScript.new()
    seek3.bind(fixture3["buffer"], pool3, FixtureEvaluator.new(), {}, 0.5)
    var r3: Dictionary = seek3.seek(1500)
    _expect(not bool(r3["ok"]) and String(r3["reason"]) == "no-clip-fields",
        "missing clip fields fails closed")
    seek3.unbind()

    # Empty buffer: native returns without posing.
    var empty = ReplayBufferScript.new()
    var pool4 = TItemPoolScript.new()
    var seek4 = ReplaySeekScript.new()
    seek4.bind(empty, pool4, FixtureEvaluator.new(), SampleMath.clip_fields(101, 100, 0), 0.5)
    var r4: Dictionary = seek4.seek(5000)
    _expect(bool(r4["ok"]) and not bool(r4["applied"]),
        "empty buffer seek returns ok without applying")
    seek4.unbind()

    # Unknown clip in evaluator -> fail closed.
    var fixture5: Dictionary = _build_seek_fixture()
    var pool5 = TItemPoolScript.new()
    var seek5 = ReplaySeekScript.new()
    var strict = FixtureEvaluator.new()
    seek5.bind(fixture5["buffer"], pool5, strict, fixture5["fields"], 0.5)
    # Corrupt one record's item so the dangling check triggers.
    fixture5["buffer"].records[0]["item_id"] = 999999
    var r5: Dictionary = seek5.seek(1500)
    _expect(not bool(r5["ok"]) and String(r5["reason"]) == "dangling-titem",
        "use-after-free TItem in a record fails closed")
    seek5.unbind()

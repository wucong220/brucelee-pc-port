extends SceneTree
## Headless validation of the proven KDF `waveletsample` decoder.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path <isolated-project> \
##     --script res://tests/validate_wavelet_anm.gd --quit-after 900
##
## Fixtures are produced by tools/make_wavelet_fixtures.py from REAL .anm files.
## The oracle (tools/wavelet_ref.py) was verified against the real ARM
## CWaveletDecoder::UpdateToFrame executed under Unicorn on 279 real ANM files.

const WaveletAnmCodecScript = preload("res://scripts/wavelet_anm_codec.gd")
const AnmTrackCodecScript = preload("res://scripts/anm_track_codec.gd")
const NativeRootOutputScript = preload("res://scripts/native_root_output.gd")
const RootEvaluator = preload("res://scripts/root_track_evaluator.gd")

const FIXTURES: String = "res://tests/data/wavelet_fixtures.json"

var passed: int = 0
var failures: Array[String] = []


func _initialize() -> void:
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES))
    _expect(data != null, "wavelet_fixtures.json parses")
    if data == null:
        _finish()
        return
    var samples: Array = data["samples"]
    _expect(samples.size() >= 7, "at least 7 real wavelet fixtures (got %d)" % samples.size())
    for sample in samples:
        _check_sample(sample)
    _check_fail_closed(samples)
    _finish()


func _finish() -> void:
    if failures.is_empty():
        print("WAVELET_ANM_VALIDATION=PASS pass=%d" % passed)
        quit(0)
    else:
        for failure in failures:
            push_error("WAVELET_FAIL " + failure)
        print("WAVELET_ANM_VALIDATION=FAIL pass=%d fail=%d" % [passed, failures.size()])
        quit(1)


func _expect(condition: bool, label: String) -> void:
    if condition:
        passed += 1
    else:
        failures.append(label)


func _close(a: float, b: float, label: String, tol: float = 0.000001) -> void:
    _expect(absf(a - b) <= tol, "%s (got %.9f expected %.9f)" % [label, a, b])


func _nested_close(got: Variant, expected: Variant, label: String) -> void:
    if got is Array and expected is Array:
        if got.size() != expected.size():
            _expect(false, "%s size %d != %d" % [label, got.size(), expected.size()])
            return
        for index in got.size():
            _nested_close(got[index], expected[index], "%s[%d]" % [label, index])
        return
    _close(float(got), float(expected), label, 0.0)


func _array_close(got: Array, expected: Array, label: String, tol: float = 0.000001) -> void:
    if got.size() != expected.size():
        _expect(false, "%s size %d != %d" % [label, got.size(), expected.size()])
        return
    for index in got.size():
        _close(float(got[index]), float(expected[index]), "%s[%d]" % [label, index], tol)


func _track(sample: Dictionary) -> Dictionary:
    return {
        "codec": "waveletsample",
        "kind": String(sample["kind"]),
        "sample_count": int(sample["sample_count"]),
        "approximations": int(sample["approximations"]),
        "channels": int(sample["channels"]),
        "components": int(sample["components"]),
        "element_bytes": int(sample["element_bytes"]),
        "radix": int(sample["radix"]),
        "data_words": sample["data_words"],
        "huffman_entries": sample["huffman_entries"],
        "huffman_symbols": sample["huffman_symbols"],
        "offsets": sample["offsets"],
    }


func _digest(keys: Array) -> String:
    var packed := PackedFloat32Array()
    for frame in keys:
        for vector in frame:
            for component in vector:
                packed.append(float(component))
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(packed.to_byte_array())
    return context.finish().hex_encode()


func _check_sample(sample: Dictionary) -> void:
    var name: String = String(sample["id"])
    var track: Dictionary = _track(sample)
    var decoded: Dictionary = WaveletAnmCodecScript.decode(track)
    _expect(bool(decoded["ok"]), "%s decodes (%s)" % [name, str(decoded.get("reason", ""))])
    if not bool(decoded["ok"]):
        return
    _expect(int(decoded["frames"]) == int(sample["frames"]),
        "%s frame count %d == %d" % [name, int(decoded["frames"]), int(sample["frames"])])
    _expect(int(decoded["channels"]) == int(sample["channels"]), name + " channels")
    _expect(int(decoded["nonzero_padding_streams"]) == 0, name + " zero tail padding")
    _expect(int(decoded["streams"]) == int(sample["streams"]), name + " stream count")
    _expect(_digest(decoded["keys"]) == String(sample["value_sha256"]),
        name + " SHA-256 of every decoded float32 value")
    _nested_close(decoded["keys"][0], sample["first_frame"], name + " first frame")
    _nested_close(decoded["keys"][decoded["keys"].size() - 1], sample["last_frame"],
        name + " last frame")
    # Per-bone interpolation cases (same AnmTrackCodec used by root output).
    for case in sample["interpolation_cases"]:
        var probe: Dictionary = track.duplicate(true)
        probe["vector_index"] = int(case["vector_index"])
        var got: Dictionary = AnmTrackCodecScript.sample(probe, float(case["time"]))
        _expect(bool(got["ok"]), "%s t=%s sample ok" % [name, str(case["time"])])
        if not bool(got["ok"]):
            continue
        _array_close(got["value"], case["expect"],
            "%s t=%s" % [name, str(case["time"])])
    # Root-output integration: a wavelet vec3 track fed through bind_anm +
    # NativeRootOutput must reproduce the same values.
    if sample.has("root_integration_cases"):
        for case in sample["root_integration_cases"]:
            var root_track: Dictionary = track.duplicate(true)
            root_track["vector_index"] = 0
            var fixture: Dictionary = {"tracks": {"positions": root_track}}
            var evaluator = RootEvaluator.new()
            _expect(evaluator.bind_anm(fixture),
                "%s bind_anm accepts waveletsample (%s)" % [name, evaluator.last_error])
            if evaluator.last_error.is_empty():
                var out: Dictionary = evaluator.root_transform(float(case["time"]))
                _expect(bool(out["ok"]), "%s root transform t=%s" % [name, str(case["time"])])
                if bool(out["ok"]):
                    _array_close(out["position"], case["expect"],
                        "%s root pos t=%s" % [name, str(case["time"])])


func _check_fail_closed(samples: Array) -> void:
    var base: Dictionary = _track(samples[0])
    # Wrong root count.
    var bad: Dictionary = base.duplicate(true)
    bad["data_words"] = base["data_words"].duplicate(true)
    bad["data_words"][0] = 2
    _expect(not bool(WaveletAnmCodecScript.decode(bad)["ok"]), "wrong root count fails closed")
    # Truncated words.
    bad = base.duplicate(true)
    bad["data_words"] = base["data_words"].slice(0, base["data_words"].size() - 8)
    _expect(not bool(WaveletAnmCodecScript.decode(bad)["ok"]), "truncated data fails closed")
    # Invalid Huffman length.
    bad = base.duplicate(true)
    bad["huffman_entries"] = base["huffman_entries"].duplicate(true)
    bad["huffman_entries"][0][1] = 0
    _expect(not bool(WaveletAnmCodecScript.decode(bad)["ok"]), "bad Huffman entry fails closed")
    # Unsupported radix.
    bad = base.duplicate(true)
    bad["radix"] = 31
    _expect(not bool(WaveletAnmCodecScript.decode(bad)["ok"]), "bad radix fails closed")
    # Anchored code index past the symbol table.
    bad = base.duplicate(true)
    var symbols: Array = base["huffman_symbols"].duplicate(true)
    bad["huffman_symbols"] = symbols.slice(0, 1)
    _expect(not bool(WaveletAnmCodecScript.decode(bad)["ok"]), "symbol range fails closed")
    # Out-of-range sample through the track evaluator.
    var probe: Dictionary = base.duplicate(true)
    probe["vector_index"] = 0
    var got: Dictionary = AnmTrackCodecScript.sample(
        probe, float(int(base["sample_count"]) + 5))
    _expect(not bool(got["ok"]), "out-of-range sample fails closed")
    _expect(String(got.get("reason", "")) == "sample-out-of-range",
        "out-of-range reason")
    # vector_index out of range.
    var probe2: Dictionary = base.duplicate(true)
    probe2["vector_index"] = 9999
    var got2: Dictionary = AnmTrackCodecScript.sample(probe2, 0.5)
    _expect(not bool(got2["ok"]), "bad vector_index fails closed")
    # Missing data arrays.
    _expect(not bool(WaveletAnmCodecScript.decode({"codec": "waveletsample"})["ok"]),
        "missing arrays fail closed")

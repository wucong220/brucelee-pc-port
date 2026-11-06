extends SceneTree
## Real-animation-path validation of the recovered in-interval seek.
##
##   godot --headless --path <godot-copy> \
##     --script res://tests/validate_real_animation.gd --quit-after 900 \
##     -- --candidate-glb=D:\BruceLeeWork\bruce_candidate_92_movefwd_20261103.glb
##
## Uses a REAL candidate GLB (92 recovered clips) through GLTFDocument ->
## generate_scene -> real AnimationPlayer, and reads REAL position-track
## keyframe values from the asset to check the recovered composition.
##
## The ANM->TTransform decode is still unrecovered; RootTrackEvaluator is a
## documented port bridge that supplies the root transform VALUE at the integer
## sample index produced by the recovered arithmetic.

const TItemPoolScript = preload("res://scripts/titem_pool.gd")
const SampleMath = preload("res://scripts/replay_sample_math.gd")
const ReplaySeekScript = preload("res://scripts/replay_seek.gd")
const ReplayBufferScript = preload("res://scripts/replay_buffer.gd")
const RootEvaluator = preload("res://scripts/root_track_evaluator.gd")

const DEFAULT_GLB: String = "D:/BruceLeeWork/bruce_candidate_92_movefwd_20261103.glb"
const CLIP: String = "m01_idle_01"

var passed: int = 0
var failures: Array[String] = []
var glb_path: String = DEFAULT_GLB
var scene_root: Node = null
var player: AnimationPlayer = null
var track_index: int = -1
var animation: Animation = null


func _initialize() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--candidate-glb="):
            glb_path = a.trim_prefix("--candidate-glb=")
    _check_real_asset()
    _check_real_seek()
    _check_titem_asset_identity()
    _check_fail_closed()
    if scene_root != null:
        scene_root.queue_free()
    if failures.is_empty():
        print("REAL_ANIMATION_VALIDATION=PASS pass=%d glb=%s clip=%s keys=%d"
            % [passed, glb_path, CLIP, animation.track_get_key_count(track_index) if animation != null else 0])
        quit(0)
    else:
        for failure in failures:
            push_error("REAL_FAIL " + failure)
        print("REAL_ANIMATION_VALIDATION=FAIL pass=%d fail=%d" % [passed, failures.size()])
        quit(1)


func _expect(condition: bool, label: String) -> void:
    if condition:
        passed += 1
    else:
        failures.append(label)


func _approx(a: float, b: float, label: String) -> void:
    _expect(abs(a - b) < 1e-4, "%s (got %s expected %s)" % [label, str(a), str(b)])


func _check_real_asset() -> void:
    _expect(FileAccess.file_exists(glb_path), "real candidate GLB exists: " + glb_path)
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    var err: Error = doc.append_from_file(glb_path, state)
    _expect(err == OK, "GLTFDocument.append_from_file succeeds (err=%d)" % err)
    var generated: Node = doc.generate_scene(state)
    _expect(generated != null and generated is Node3D, "GLB generates a real 3D scene")
    if generated == null:
        return
    scene_root = generated
    root.add_child(scene_root)
    var players: Array[Node] = scene_root.find_children("*", "AnimationPlayer", true, false)
    _expect(players.size() >= 1, "generated scene has a real AnimationPlayer")
    if players.is_empty():
        return
    player = players[0] as AnimationPlayer
    var names: PackedStringArray = player.get_animation_list()
    _expect(names.size() >= 90, "real GLB has >= 90 recovered clips (got %d)" % names.size())
    _expect(names.has(CLIP), "real recovered clip %s is present" % CLIP)
    if not player.has_animation(CLIP):
        return
    animation = player.get_animation(CLIP)
    _expect(animation.get_track_count() > 0, "real clip has animation tracks")
    for t in animation.get_track_count():
        if animation.track_get_type(t) == Animation.TYPE_POSITION_3D:
            track_index = t
            break
    _expect(track_index >= 0, "real clip has a POSITION_3D track")
    if track_index >= 0:
        _expect(animation.track_get_key_count(track_index) >= 2,
            "real clip position track has >= 2 real keyframes")


func _build_records():
    var buffer = ReplayBufferScript.new()
    var times: Array[int] = [1000, 2000, 3000, 4000]
    for i in 4:
        buffer.append_record(
            Vector3(float(i), 0.5 * float(i), 1.0 + float(i)),
            Quaternion(0.0, 0.0, 0.0, 1.0),
            CLIP, 0.0, i % 2, times[i])
    return buffer


func _clip_fields() -> Dictionary:
    var keys: int = animation.track_get_key_count(track_index)
    var samples: int = max(2, keys)
    # duration_ms = duration_samples*1000/30, integer division (native CAnimRes+0x40).
    var duration_ms: int = (samples * 1000) / 30
    return SampleMath.clip_fields(samples, duration_ms, 0)


func _real_key(sample: float) -> Vector3:
    ## Independent read of the REAL asset keyframe data (not via the evaluator).
    var count: int = animation.track_get_key_count(track_index)
    var index: int = clampi(int(sample), 0, count - 1)
    return animation.track_get_key_value(track_index, index) as Vector3


func _check_real_seek() -> void:
    if player == null or animation == null or track_index < 0:
        failures.append("real asset not ready for seek")
        return
    var evaluator = RootEvaluator.new(player)
    _expect(evaluator.set_clip(CLIP), "RootTrackEvaluator binds the real clip")
    _expect(evaluator.track_index == track_index,
        "evaluator reads the same real POSITION_3D track")
    _expect(not evaluator.supports_fractional(),
        "fractional native BuildFrame interpolation fails closed")
    var fields: Dictionary = _clip_fields()
    _expect(bool(fields["ok"]), "clip fields derived from real key count")

    for t in [1000, 1500, 2000, 2500, 3000, 3500, 4000, 5000]:
        var buffer = _build_records()
        var pool = TItemPoolScript.new()
        var seek = ReplaySeekScript.new()
        _expect(seek.bind(buffer, pool, evaluator, fields, 0.5),
            "bind real-clip replay buffer (t=%d)" % t)
        var result: Dictionary = seek.seek(t)
        _expect(bool(result["ok"]), "real-clip inside-interval seek succeeds (t=%d)" % t)
        if not bool(result["ok"]):
            seek.unbind()
            continue
        var applied: bool = bool(result.get("applied", false))
        if not applied:
            _expect(t <= 1000, "t=%d is the no-pose branch" % t)
            seek.unbind()
            continue
        var sample_b: float = float(result["sample_b"])
        var sample_a: float = float(result["sample_a"])
        _expect(sample_a == floor(sample_a) and sample_b == floor(sample_b),
            "integer GetOutput branch yields integer samples (t=%d)" % t)
        var expected: Vector3 = (buffer.records[int(result["cursor"]) - 1]["position"] as Vector3) \
            + (_real_key(sample_b) - _real_key(sample_a))
        var got: Vector3 = result["position"]
        _approx(got.x, expected.x, "real t=%d pos.x" % t)
        _approx(got.y, expected.y, "real t=%d pos.y" % t)
        _approx(got.z, expected.z, "real t=%d pos.z" % t)
        _expect((result["rotation"] as Quaternion).is_equal_approx(Quaternion(0.0, 0.0, 0.0, 1.0)),
            "real t=%d rotation is the previous record's rotation" % t)
        _expect(not bool(result["interpolation_unrecovered"]),
            "real t=%d does not flag SetToSample as unrecovered" % t)
        _expect(int(result["frame"]) == SampleMath.frame_from_delta(int(result["delta_ms"]), 0.5),
            "real t=%d frame matches recovered arithmetic" % t)
        seek.unbind()

    # Original gap reproduced on the untouched baseline port buffer.
    var baseline = _build_records()
    var baseline_result: Dictionary = baseline.set_replay_current_time(1500)
    _expect(bool(baseline_result.get("interpolation_unrecovered", false)),
        "baseline port still refuses inside-interval seek")


func _check_titem_asset_identity() -> void:
    var pool = TItemPoolScript.new()
    var id: int = pool.new_hash_string(CLIP)
    _expect(pool.is_alive(id), "real recovered clip name interns into a live TItem")
    _expect(pool.name_of(id) == CLIP, "interned real clip name resolves")
    _expect(pool.refs_of(id) == 1, "real clip HashString holds one ref")
    var matrix_text: String = FileAccess.get_file_as_string("res://tests/data/sampling_matrix.json")
    var matrix: Variant = JSON.parse_string(matrix_text)
    if matrix != null:
        for case in matrix["cases"]:
            if String(case["kind"]) == "crc" and String(case["name"]) == CLIP:
                _expect(int(pool.hash_of(id)) == int(case["hash"]),
                    "real clip TItem hash equals the native CRC32 oracle")
    pool.release(id)
    _expect(not pool.is_alive(id), "releasing the last ref frees the real clip TItem")


func _check_fail_closed() -> void:
    if player == null or animation == null:
        return
    var buffer = _build_records()
    buffer.records[0]["animation"] = "not_a_real_clip"
    buffer.records[1]["animation"] = "not_a_real_clip"
    buffer.records[2]["animation"] = "not_a_real_clip"
    buffer.records[3]["animation"] = "not_a_real_clip"
    var pool = TItemPoolScript.new()
    var seek = ReplaySeekScript.new()
    var evaluator = RootEvaluator.new(player)
    seek.bind(buffer, pool, evaluator, _clip_fields(), 0.5)
    var result: Dictionary = seek.seek(1500)
    _expect(not bool(result["ok"]) and String(result["reason"]) == "clip-not-available",
        "unknown real clip fails closed")
    seek.unbind()

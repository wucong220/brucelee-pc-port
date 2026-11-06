extends SceneTree
## Headless comparison of the recovered ANM->TTransform VALUE against the REAL
## GLB shipped in DragonWarrior-Current213-20261103.
##
##   godot --headless --path <isolated-project> \
##     --script res://tests/validate_root_anm_glb.gd --quit-after 900 \
##     -- --glb=D:/BruceLeeWork/DragonWarrior-Current213-20261103/models/bruce_skin01.glb
##
## The GLB's `character` node translation/rotation tracks are the ANM-derived
## keyframes used by the Godot port (interpolation STEP). The recovered native
## decode must reproduce them exactly at integer samples; the fractional
## (smooth-flag) values are the newly recovered interpolation between them.

const NativeRootOutputScript = preload("res://scripts/native_root_output.gd")
const AnmTrackCodecScript = preload("res://scripts/anm_track_codec.gd")

const DEFAULT_GLB: String = "D:/BruceLeeWork/DragonWarrior-Current213-20261103/models/bruce_skin01.glb"
const CLIPS: Array[String] = ["m02_movefwd", "all_end_attack_01_forset01"]

var passed: int = 0
var failures: Array[String] = []
var glb_path: String = DEFAULT_GLB
var scene_root: Node = null
var player: AnimationPlayer = null
var clips: Dictionary = {}


func _initialize() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--glb="):
            glb_path = a.trim_prefix("--glb=")
    _load_fixtures()
    _load_glb()
    _check_integer_keys()
    _check_fractional_between_real_keys()
    if scene_root != null:
        scene_root.queue_free()
    if failures.is_empty():
        print("ROOT_ANM_GLB_VALIDATION=PASS pass=%d glb=%s" % [passed, glb_path])
        quit(0)
    else:
        for failure in failures:
            push_error("ROOT_ANM_GLB_FAIL " + failure)
        print("ROOT_ANM_GLB_VALIDATION=FAIL pass=%d fail=%d" % [passed, failures.size()])
        quit(1)


func _expect(condition: bool, label: String) -> void:
    if condition:
        passed += 1
    else:
        failures.append(label)


func _close(a: float, b: float, label: String, tol: float = 0.00001) -> void:
    _expect(absf(a - b) <= tol, "%s (got %.9f expected %.9f)" % [label, a, b])


func _load_fixtures() -> void:
    var fx: Variant = JSON.parse_string(
        FileAccess.get_file_as_string("res://tests/data/anm_fixtures.json"))
    _expect(fx != null, "anm_fixtures.json parses")
    if fx == null:
        return
    for clip in fx["clips"]:
        clips[String(clip["name"])] = clip
    _expect(clips.size() >= 2, "real ANM fixtures available")


func _load_glb() -> void:
    _expect(FileAccess.file_exists(glb_path), "real Current213 GLB exists: " + glb_path)
    if not FileAccess.file_exists(glb_path):
        return
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    var err: Error = doc.append_from_file(glb_path, state)
    _expect(err == OK, "GLTFDocument.append_from_file succeeds (err=%d)" % err)
    var generated: Node = doc.generate_scene(state)
    _expect(generated != null and generated is Node3D, "real GLB generates a 3D scene")
    if generated == null:
        return
    scene_root = generated
    root.add_child(scene_root)
    var players: Array[Node] = scene_root.find_children("*", "AnimationPlayer", true, false)
    _expect(players.size() >= 1, "real GLB has an AnimationPlayer")
    if players.is_empty():
        return
    player = players[0] as AnimationPlayer
    var names: PackedStringArray = player.get_animation_list()
    _expect(names.size() >= 90, "real GLB has >= 90 recovered clips (got %d)" % names.size())
    for clip in CLIPS:
        _expect(names.has(clip), "real recovered clip present: " + clip)


## Godot's glTF importer injects ONE duplicate leading key (time 1/30,
## value of key 0) on the `character` node tracks and re-times the remaining
## keys to exactly 1/30 s. The raw GLB stored values (validated byte-exactly by
## tools/native_anim_decode.py --validate-glb) are unchanged. This test maps
## Godot key 0 -> ANM key 0 and Godot key i>=1 -> ANM key i-1.

func _track_for(anim: Animation, type: int) -> int:
    for t in anim.get_track_count():
        var path: String = String(anim.track_get_path(t))
        if path.ends_with("/character") and anim.track_get_type(t) == type:
            return t
    return -1


func _normalise(q: Array) -> Array:
    var len2: float = float(q[0]) * float(q[0]) + float(q[1]) * float(q[1]) \
        + float(q[2]) * float(q[2]) + float(q[3]) * float(q[3])
    var inv: float = 1.0 / sqrt(len2)
    var out: Array = []
    for c in q:
        out.append(AnmTrackCodecScript.f32(inv * float(c)))
    return out


func _check_integer_keys() -> void:
    if player == null or clips.is_empty():
        failures.append("real asset / fixtures not ready")
        return
    for clip in CLIPS:
        if not player.has_animation(clip) or not clips.has(clip):
            continue
        var anim: Animation = player.get_animation(clip)
        var fx: Dictionary = clips[clip]
        var tpos: int = _track_for(anim, Animation.TYPE_POSITION_3D)
        var trot: int = _track_for(anim, Animation.TYPE_ROTATION_3D)
        var tscale: int = _track_for(anim, Animation.TYPE_SCALE_3D)
        _expect(tpos >= 0, "%s has a real character position track" % clip)
        if tpos < 0:
            continue
        var n: int = anim.track_get_key_count(tpos)
        var pos_keys: Array = fx["tracks"]["positions"]["keys"]
        _expect(n == pos_keys.size() + 1,
            "%s Godot key count %d == ANM %d + 1 importer duplicate" % [clip, n, pos_keys.size()])
        var maxerr: float = 0.0
        for i in n:
            var anm_i: int = 0 if i == 0 else i - 1
            if anm_i >= pos_keys.size():
                continue
            var got: Vector3 = anim.track_get_key_value(tpos, i) as Vector3
            var out: Dictionary = NativeRootOutputScript.compose(fx, float(anm_i))
            _expect(bool(out["ok"]), "%s sample %d composes" % [clip, anm_i])
            if not bool(out["ok"]):
                continue
            var p: Array = out["position"]
            maxerr = maxf(maxerr, absf(got.x - float(p[0])))
            maxerr = maxf(maxerr, absf(got.y - float(p[1])))
            maxerr = maxf(maxerr, absf(got.z - float(p[2])))
        _close(maxerr, 0.0, "%s: %d real GLB translation keys == ANM decode" % [clip, n])

        if trot >= 0:
            var rq: int = anim.track_get_key_count(trot)
            var rot_keys: Array = fx["tracks"]["rotations"]["keys"]
            _expect(rq == rot_keys.size() + 1,
                "%s Godot rotation key count %d == ANM %d + 1 duplicate"
                    % [clip, rq, rot_keys.size()])
            var qmaxerr: float = 0.0
            for i in mini(rq, rot_keys.size() + 1):
                var anm_i: int = 0 if i == 0 else i - 1
                if anm_i >= rot_keys.size():
                    continue
                var gq: Quaternion = anim.track_get_key_value(trot, i) as Quaternion
                var outq: Dictionary = NativeRootOutputScript.compose(fx, float(anm_i))
                if not bool(outq["ok"]):
                    _expect(false, "%s rotation sample %d composes" % [clip, anm_i])
                    continue
                # The ANM->GLB pipeline normalised the Q14 quaternion with
                # float32; the native integer GetFrame path does not.
                var qn: Array = _normalise(outq["rotation"])
                qmaxerr = maxf(qmaxerr, absf(gq.x - float(qn[0])))
                qmaxerr = maxf(qmaxerr, absf(gq.y - float(qn[1])))
                qmaxerr = maxf(qmaxerr, absf(gq.z - float(qn[2])))
                qmaxerr = maxf(qmaxerr, absf(gq.w - float(qn[3])))
            _expect(qmaxerr < 0.000002,
                "%s: %d real GLB rotation keys == normalised ANM decode (err=%f)"
                    % [clip, rq, qmaxerr])
        if tscale >= 0:
            var gs: Vector3 = anim.track_get_key_value(tscale, 0) as Vector3
            var out0: Dictionary = NativeRootOutputScript.compose(fx, 0.0)
            if bool(out0["ok"]):
                var s: Array = out0["scale"]
                _close(gs.x, float(s[0]), "%s ANM scale x == real GLB scale" % clip)
                _close(gs.y, float(s[1]), "%s ANM scale y == real GLB scale" % clip)
                _close(gs.z, float(s[2]), "%s ANM scale z == real GLB scale" % clip)


func _check_fractional_between_real_keys() -> void:
    if player == null or not clips.has("m02_movefwd"):
        return
    var anim: Animation = player.get_animation("m02_movefwd")
    var tpos: int = _track_for(anim, Animation.TYPE_POSITION_3D)
    if tpos < 0:
        return
    # Godot key 1 is the injected duplicate; keys 0 and 2 are the real ANM
    # keyframes 0 and 1 from the GLB.
    var k0: Vector3 = anim.track_get_key_value(tpos, 0) as Vector3
    var k1: Vector3 = anim.track_get_key_value(tpos, 2) as Vector3
    var fx: Dictionary = clips["m02_movefwd"]
    var half: Dictionary = NativeRootOutputScript.compose(fx, 0.5)
    _expect(bool(half["ok"]) and String(half["mode"]) == "fractional",
        "real clip fractional sample composes via recovered BuildFrame math")
    if not bool(half["ok"]):
        return
    var p: Array = half["position"]
    _close(float(p[1]), (k0.y + k1.y) * 0.5,
        "fractional position at 0.5 is the proven lerp of the two real GLB keys")
    _expect(float(p[1]) < k0.y and float(p[1]) > k1.y,
        "fractional position is strictly between the two real keys")
    _expect(float(p[1]) != k0.y, "fractional value is not the STEP-port key value")
    # Quaternion fractional branch: nlerp normalises.
    if clips.has("all_end_attack_01_forset01"):
        var fx2: Dictionary = clips["all_end_attack_01_forset01"]
        var qh: Dictionary = NativeRootOutputScript.compose(fx2, 0.5)
        _expect(bool(qh["ok"]) and String(qh["mode"]) == "fractional",
            "real rotation clip fractional sample composes")
        if bool(qh["ok"]):
            var q: Array = qh["rotation"]
            var norm: float = sqrt(float(q[0]) * float(q[0]) + float(q[1]) * float(q[1])
                + float(q[2]) * float(q[2]) + float(q[3]) * float(q[3]))
            _close(norm, 1.0, "real-clip fractional quaternion is nlerp-normalised")

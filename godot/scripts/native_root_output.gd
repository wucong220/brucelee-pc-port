extends RefCounted
class_name NativeRootOutput

## Proven CRootPlayerBase::GetOutput TTransform composition (ELF 0x407a04).
##
## After BuildFrame writes the three decoded tables (positions 3 floats,
## rotations 4 floats, scales 3 floats), GetOutput composes them at
## 0x407ba4..0x407cb4:
##
##   pos_out = M_parent * pos_anim + t_parent       (M at +0x44, t at +0x68)
##   quat_out = q_parent * quat_anim                (Hamilton; x,y,z,w)
##   scale_out = scale_anim                         (copied verbatim, +0x28)
##
## CRootPlayerBase::C1 (0x40777c) sets q_parent=(0,0,0,1), M_parent=identity and
## t_parent=0; CRootPlayer::SetSource (0x406eec) memcpy's the same identity
## block (0x11fd64 memcpy, 0x68 bytes) over +0x0c..+0x73. The root player's
## parent transform is therefore proven identity, and the composition reduces to
## the ANM values themselves. compose() still implements the general parent for
## completeness; callers MUST pass a proven parent or use the identity default.
##
## Cached sample: GetOutput stores the sample at +0x08 and returns the cached
## TTransform unchanged when the sample equals the cached value; the returned
## VALUE is identical, so this module does not need to model the cache.

const AnmTrackCodecScript = preload("res://scripts/anm_track_codec.gd")


static func _affine(m: Array, t: Array, p: Array) -> Array:
    var out: Array = []
    for row in 3:
        var v: float = AnmTrackCodecScript.f32(float(m[row * 3]) * float(p[0]))
        v = AnmTrackCodecScript.f32(v + AnmTrackCodecScript.f32(float(m[row * 3 + 1]) * float(p[1])))
        v = AnmTrackCodecScript.f32(v + AnmTrackCodecScript.f32(float(m[row * 3 + 2]) * float(p[2])))
        out.append(AnmTrackCodecScript.f32(v + float(t[row])))
    return out


static func compose(fixture: Dictionary, sample: float, parent: Dictionary = {}) -> Dictionary:
    ## fixture: {"tracks": {"positions": {...}|null, "rotations": ..., "scales": ...}}
    ## Returns {ok, mode, position: Array[3], rotation: Array[4], scale: Array[3]}
    if fixture == null or fixture.is_empty():
        return {"ok": false, "reason": "anm-clip-required"}
    var tracks: Dictionary = fixture.get("tracks", {})
    var pos_track: Variant = tracks.get("positions", null)
    if pos_track == null:
        return {"ok": false, "reason": "missing-positions"}
    var pos: Dictionary = AnmTrackCodecScript.sample(pos_track, sample)
    if not bool(pos["ok"]):
        return {"ok": false, "reason": String(pos["reason"])}

    var quat: Array = [0.0, 0.0, 0.0, 1.0]
    var rot_track: Variant = tracks.get("rotations", null)
    if rot_track != null:
        var r: Dictionary = AnmTrackCodecScript.sample(rot_track, sample)
        if not bool(r["ok"]):
            return {"ok": false, "reason": String(r["reason"])}
        quat = r["value"]

    var scl: Array = [1.0, 1.0, 1.0]
    var scl_track: Variant = tracks.get("scales", null)
    if scl_track != null:
        var s: Dictionary = AnmTrackCodecScript.sample(scl_track, sample)
        if not bool(s["ok"]):
            return {"ok": false, "reason": String(s["reason"])}
        scl = s["value"]

    var p: Array = pos["value"]
    var out_pos: Array = p
    var out_quat: Array = quat
    if not parent.is_empty():
        var m: Array = parent["matrix"]                 # m00..m22, 9 floats
        var t: Array = parent["origin"]                 # tx,ty,tz
        var pq: Array = parent["quat"]                  # x,y,z,w
        out_pos = _affine(m, t, p)
        var a := Quaternion(float(pq[0]), float(pq[1]), float(pq[2]), float(pq[3]))
        var b := Quaternion(float(quat[0]), float(quat[1]), float(quat[2]), float(quat[3]))
        var mul: Quaternion = a * b
        out_quat = [AnmTrackCodecScript.f32(mul.x), AnmTrackCodecScript.f32(mul.y),
                    AnmTrackCodecScript.f32(mul.z), AnmTrackCodecScript.f32(mul.w)]
    return {"ok": true, "mode": String(pos["mode"]), "position": out_pos,
            "rotation": out_quat, "scale": scl}

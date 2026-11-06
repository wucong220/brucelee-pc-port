extends RefCounted
class_name AnmTrackCodec

## Proven native IAnimCodec::GetFrame math for raw ANM tracks, plus the proven
## `waveletsample` decoder (scripts/wavelet_anm_codec.gd).
##
## Direct ARM evidence (libdefault.so sha256 1da7a30...):
##   CRawCodec<GVec3<TFixedPoint<12,int>>, GVec3<float>>::GetFrame @ 0x40b6cc
##   CRawCodec<TQuaternion<TFixedPoint<14,short>>, TQuaternion<float>>::GetFrame @ 0x40bbbc
##   CRawCodec<GVec3<float>, GVec3<float>>::GetFrame @ 0x40c69c
##   CRawCodec<TQuaternion<float>, TQuaternion<float>>::GetFrame @ 0x40c8e8
##   CRawStaticCodec<...>::GetFrame @ 0x40b57c (single key, ignores time)
##   CWaveletDecoder<int,float>::UpdateToFrame @ 0x00418aa0
##   CWaveletDecoder<short,float>::UpdateToFrame @ 0x0041a914
##
##   i = (u32)time                       (vcvt.u32.f32; negative saturates to 0)
##   frac = time - (float)i
##   frac <= 0 : value = key[i]         (NO interpolation / NO normalisation)
##   frac  > 0 : vec3  = frac*key[i+1] + (1-frac)*key[i]
##               quat  = if dot(A,B) < 0 negate B (hemisphere)
##                       q = frac*B + (1-frac)*A
##                       q = q / sqrt(dot(q,q))   (nlerp)
##
## Stored keys: int32[3] (Q12 x 1/4096) for positions/scales,
## int16[4] (Q14 x 1/16384) for rotations; rawfloatsample stores float32.
## Wavelet tracks carry compressed words; they are decoded to float32 samples
## once by WaveletAnmCodec and then use the same interpolation rules.
## All arithmetic is float32 (ARM vmul/vmla/vmls/vnmla); f32() emulates one
## register round-trip. Anything outside the proven codecs fails closed.

const WaveletAnmCodecScript = preload("res://scripts/wavelet_anm_codec.gd")
const INV_Q12: float = 1.0 / 4096.0
const INV_Q14: float = 1.0 / 16384.0
const REASON_RANGE: String = "sample-out-of-range"
const REASON_CODEC: String = "unsupported-codec"
const REASON_WAVELET: String = "wavelet-decode-failed"


static func f32(value: float) -> float:
    var buf := PackedFloat32Array()
    buf.append(value)
    return float(buf[0])


static func _split_time(time: float) -> Dictionary:
    var t: float = f32(time)
    var i: int = 0
    if t > 0.0:
        i = int(t)                         # vcvt.u32.f32 truncates toward zero
    var frac: float = f32(t - f32(float(i)))
    return {"i": i, "frac": frac}


static func _decode_key(row: Array, codec: String, kind: String,
                        vector_index: int = 0) -> Array:
    if codec == "rawfixedsample":
        var scale: float = INV_Q14 if kind == "quat" else INV_Q12
        var out: Array = []
        for c in row:
            out.append(f32(float(c) * scale))
        return out
    if codec == "waveletsample":
        ## Decoded keys hold one vector per bone offset and frame.
        if vector_index < 0 or vector_index >= row.size():
            return []
        var selected: Array = row[vector_index]
        var selected_out: Array = []
        for c in selected:
            selected_out.append(f32(float(c)))
        return selected_out
    if codec == "rawfloatsample":
        var outf: Array = []
        for c in row:
            outf.append(f32(float(c)))
        return outf
    return []


static func _prepare_wavelet(track: Dictionary) -> Dictionary:
    ## Decode a compressed wavelet track once; cached in the track dictionary.
    if track.has("keys"):
        return {"ok": true}
    var decoded: Dictionary = WaveletAnmCodecScript.decode(track)
    if not bool(decoded.get("ok", false)):
        return {"ok": false, "reason": REASON_WAVELET + ":" +
                String(decoded.get("reason", "unknown"))}
    if int(decoded.get("nonzero_padding_streams", 0)) != 0:
        return {"ok": false, "reason": REASON_WAVELET + ":nonzero-padding"}
    track["keys"] = decoded["keys"]
    track["wavelet_frames"] = int(decoded["frames"])
    track["wavelet_nonzero_padding"] = int(decoded["nonzero_padding_streams"])
    return {"ok": true}


static func _is_supported(codec: String) -> bool:
    return codec == "rawfixedsample" or codec == "rawfloatsample" \
        or codec == "waveletsample"


static func _exact_key(track: Dictionary, index: int) -> Dictionary:
    var codec: String = String(track["codec"])
    if not _is_supported(codec):
        return {"ok": false, "reason": REASON_CODEC + ":" + codec}
    var keys: Array = track["keys"]
    if index >= keys.size():
        return {"ok": false, "reason": REASON_RANGE}
    var v: Array = _decode_key(keys[index], codec, String(track["kind"]),
        int(track.get("vector_index", 0)))
    if v.is_empty():
        return {"ok": false, "reason": REASON_RANGE}
    return {"ok": true, "mode": "integer", "value": v}


static func _lerp(a: Array, b: Array, frac: float) -> Array:
    var om: float = f32(1.0 - frac)
    var out: Array = []
    for c in a.size():
        var t: float = f32(frac * float(b[c]))
        out.append(f32(t + f32(om * float(a[c]))))
    return out


static func _normalise(q: Array) -> Array:
    # ARM order: q1^2, +q0^2, +q2^2, +q3^2, then zlibm_sqrt and 1/x.
    var len2: float = f32(float(q[1]) * float(q[1]))
    len2 = f32(len2 + f32(float(q[0]) * float(q[0])))
    len2 = f32(len2 + f32(float(q[2]) * float(q[2])))
    len2 = f32(len2 + f32(float(q[3]) * float(q[3])))
    var ln: float = sqrt(float(len2))
    var inv: float = f32(1.0 / ln)
    var out: Array = []
    for c in q:
        out.append(f32(inv * float(c)))
    return out


static func sample(track: Dictionary, time: float) -> Dictionary:
    ## Returns {ok, mode, value} where value is an Array of 3 or 4 floats.
    if track == null or track.is_empty():
        return {"ok": false, "reason": "track-required"}
    var codec: String = String(track["codec"])
    if not _is_supported(codec):
        return {"ok": false, "reason": REASON_CODEC + ":" + codec}
    if codec == "waveletsample":
        var prepared: Dictionary = _prepare_wavelet(track)
        if not bool(prepared["ok"]):
            return {"ok": false, "reason": String(prepared["reason"])}
    var keys: Array = track["keys"]
    if keys.is_empty():
        return {"ok": false, "reason": REASON_RANGE}
    var is_static: bool = bool(track.get("static", false)) or keys.size() == 1
    if is_static:
        var s: Dictionary = _exact_key(track, 0)
        if bool(s["ok"]):
            s["mode"] = "static"
        return s
    var sp: Dictionary = _split_time(time)
    var i: int = int(sp["i"])
    var frac: float = float(sp["frac"])
    if frac <= 0.0:
        return _exact_key(track, i)
    if i + 1 >= keys.size():
        return {"ok": false, "reason": REASON_RANGE}
    var vector_index: int = int(track.get("vector_index", 0))
    var a: Array = _decode_key(keys[i], codec, String(track["kind"]), vector_index)
    var b: Array = _decode_key(keys[i + 1], codec, String(track["kind"]), vector_index)
    if a.is_empty() or b.is_empty():
        return {"ok": false, "reason": REASON_CODEC + ":" + codec}
    if String(track["kind"]) == "quat":
        # dot(A,B) in native order: A1*B1, +A0*B0, +A2*B2, +A3*B3
        var dot: float = f32(float(a[1]) * float(b[1]))
        dot = f32(dot + f32(float(a[0]) * float(b[0])))
        dot = f32(dot + f32(float(a[2]) * float(b[2])))
        dot = f32(dot + f32(float(a[3]) * float(b[3])))
        var negated: bool = dot < 0.0
        if negated:
            var nb: Array = []
            for c in b:
                nb.append(f32(-float(c)))
            b = nb
        var q: Array = _lerp(a, b, frac)
        q = _normalise(q)
        return {"ok": true, "mode": "fractional", "value": q,
                "hemisphere_negated": negated}
    return {"ok": true, "mode": "fractional", "value": _lerp(a, b, frac)}

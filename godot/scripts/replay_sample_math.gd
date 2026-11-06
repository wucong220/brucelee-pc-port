extends RefCounted
class_name ReplaySampleMath

## Exact recovered sampling arithmetic for the replay in-interval seek.
##
## Everything below is transcribed from direct ARM disassembly of
## libdefault.so (sha256 1da7a30c...). Project (Ghidra) addresses:
##
## CFighter::SetReplayCurrentTime @ 0x001b4480
##   0x1b44ec  rsb  r0,r0,r1                  ; delta = t - record[prev].time
##   0x1b44f0  vmov s13,r0
##   0x1b44f4  vcvt.f32.u32 s13,s13
##   0x1b44dc  vldr.32 s14,[pc,#0x18c]        ; 0.03f (elf 0x1a4670 = 0x3cf5c28f)
##   0x1b4518  vmul.f32 s14,s13,s14
##   0x1b451c  vmul.f32 s16,s14,s15           ; s15 = fighter[+0x140] speed
##   0x1b4520  vcvt.u32.f32 s16,s16           ; frame = trunc(delta*0.03*speed)
##   0x1b4528  bl SetAnimationFrame(this, item, frame, speed)
##   0x1b4564  bl anmRoot::SetToSample(out=A, this=anmRoot, sample=0.0f)
##   0x1b4588  bl anmRoot::SetToSample(out=B, this=anmRoot, sample=(float)frame)
##   0x1b4594..0x1b45e4  pos = record[prev].pos + (B.xyz - A.xyz)
##   0x1b4628  rot = record[prev].rot
##
## anmRoot::SetToSample(float) @ elf 0x406734 / project 0x416734
##   (hidden sret: r0 = TTransform* out, r1 = anmRoot*, r2 = float sample)
##   t = min(sample, (float)(uint)player[+0xa0]) * player[+0xb0]
##   t = clamp(t, 0.0f, 1.0f)
##   player[+0x98] = (int)((float)(int)player[+0xa8] * t)   ; vcvt.s32.f32
##   out = CRootPlayerBase::GetOutput(player, player+0x8c)   ; 0x28-byte TTransform
##
## CRootPlayer::SetSource @ 0x416eec + CTimeController::Init @ 0x4239c8
##   CAnimState+0x14 = duration_samples - 1             (call it Nlast)
##   CAnimState+0x1c = duration_ms = duration*1000/framerate (integer)  (A)
##   CAnimState+0x18 = 1.0f                              (d)
##   CAnimState+0x20 = 1/A                               (c)
##   CAnimState+0x24 = 1/Nlast                           (k)
##   CAnimState+0x0c = current time state (int)          (set by SetToSample)
##   CAnimState+0x09 = smooth flag byte (ctor = 1)
##
## CRootPlayerBase::GetOutput @ 0x417a04
##   ldrb r3,[r1,#0x9]                      ; flag
##   if time == A   -> sample = (float)Nlast
##   else           -> sample = (float)Nlast * clamp(c * time * |d|, 0, 1)
##   flag == 0      -> sample = floor(sample)   (0x417a90, integer sample index)
##   flag != 0      -> sample stays FRACTIONAL (0x417cc8; BuildFrame then
##                     interpolates). That interpolation is NOT recovered:
##                     this module reports `fractional` and callers must fail
##                     closed unless an explicit proven evaluator is supplied.
##
## => The in-interval "interpolation" is a ROOT-MOTION DELTA between two
##    discrete samples of the same clip, anchored at the previous record:
##      frame  = trunc((t - prev.time) * 0.03 * speed)
##      pos(t) = prev.pos + (root(frame) - root(0))
##      rot(t) = prev.rot                     (no rotation interpolation)
##    There is no linear interpolation of the record positions themselves.

const TIME_TO_FRAME_F32: float = 0.03
const REASON_DEGENERATE: String = "degenerate-clip-fields"
const REASON_FRACTIONAL: String = "fractional-sample-unrecovered"


static func f32(value: float) -> float:
    ## Emulate one ARM single-precision register round-trip.
    var buf := PackedFloat32Array()
    buf.append(value)
    return float(buf[0])


static func frame_from_delta(delta_ms: int, speed: float) -> int:
    ## 0x1b44ec..0x1b4524. vcvt.u32.f32 saturates negative values to zero.
    var d: float = f32(float(delta_ms))
    var a: float = f32(d * f32(TIME_TO_FRAME_F32))
    var b: float = f32(a * f32(speed))
    if b <= 0.0:
        return 0
    return int(b)


static func clip_fields(duration_samples: int, duration_ms: int,
        smooth_flag: int) -> Dictionary:
    ## Derive the CAnimState fields exactly as CTimeController::Init does.
    ## duration_samples = CAnimRes+0x3C (decoded sample count / duration)
    ## duration_ms      = CAnimRes+0x40 (duration*1000/framerate, u32 division)
    var nlast: int = duration_samples - 1
    if nlast <= 0 or duration_ms <= 0:
        return {"ok": false, "reason": REASON_DEGENERATE}
    return {
        "ok": true,
        "duration_samples": duration_samples,
        "nlast": nlast,
        "a": duration_ms,
        "d": f32(1.0),
        "c": f32(f32(1.0) / f32(float(duration_ms))),
        "k": f32(f32(1.0) / f32(float(nlast))),
        "smooth_flag": smooth_flag,
    }


static func set_to_sample(sample: float, fields: Dictionary) -> Dictionary:
    ## Exact SetToSample -> GetOutput arithmetic. Returns time_state,
    ## sample_exact (possibly fractional) and the integer sample index.
    if not bool(fields.get("ok", false)):
        return {"ok": false, "reason": String(fields.get("reason", REASON_DEGENERATE))}
    var nlast: int = int(fields["nlast"])
    var a: int = int(fields["a"])
    var d: float = float(fields["d"])
    var c: float = float(fields["c"])
    var k: float = float(fields["k"])
    var flag: int = int(fields["smooth_flag"])
    var f: float = f32(sample)
    var x: float
    if f < 0.0:
        x = f32(f32(0.0) * k)
    else:
        var n: float = f32(float(nlast))
        x = f32(min(f, n) * k)
    if x < 0.0:
        x = 0.0
    if x > 1.0:
        x = 1.0
    var time_state: int = int(f32(f32(float(a)) * x))   # vcvt.s32.f32
    var exact: float
    if time_state == a:
        exact = f32(float(nlast))
    else:
        var t: float = f32(f32(float(time_state)) * f32(abs(d)))
        t = f32(c * t)
        if t < 0.0:
            t = 0.0
        if t > 1.0:
            t = 1.0
        exact = f32(f32(float(nlast)) * t)
    if flag == 0:
        exact = f32(floor(exact))
    var fractional: bool = exact != floor(exact)
    return {
        "ok": true,
        "time_state": time_state,
        "sample_exact": exact,
        "sample_index": int(floor(exact)),
        "fractional": fractional,
        "smooth_flag": flag,
        "nlast": nlast,
        "a": a,
    }

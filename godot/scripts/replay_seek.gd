extends RefCounted
class_name ReplaySeek

## Recovered CFighter::SetReplayCurrentTime in-interval semantics (state 6 seek).
##
## Native: CFighter::SetReplayCurrentTime @ 0x001b4480.
## This is the "known remaining gap": the baseline port's
## ReplayBuffer.set_replay_current_time() refused every seek that landed
## strictly inside a record interval (`seek-interpolation-unrecovered`)
## because anmRoot::SetToSample was missing.
##
## Recovered behaviour (direct disassembly, no invented math):
##   cursor = 0
##   if count == 0 or t <= record[0].time: stop (no pose change)
##   cursor = first i >= 1 with t <= record[i].time; if none, cursor = count
##   prev   = record[cursor-1]                (also when cursor == count)
##   frame  = trunc((t - prev.time) * 0.03f * fighter[+0x140])
##   SetAnimationFrame(fighter, prev.animation, frame, speed)
##   A = anmRoot::SetToSample(0.0f)           (root transform at sample 0)
##   B = anmRoot::SetToSample((float)frame)   (root transform at sample(frame))
##   pos = prev.position + (B.xyz - A.xyz)
##   rot = prev.rotation                      (no rotation interpolation)
##   the record's TItem* is addref'd before SetAnimationFrame and released
##   after (RemoveItem when the count reaches zero).
##
## The root transform VALUE at a sample (ANM track decode / BuildFrame
## interpolation) is NOT recovered. A caller MUST supply a root evaluator;
## without one this fails closed. Fractional samples (smooth-flag branch)
## also fail closed unless the evaluator explicitly declares support.

const SampleMath = preload("res://scripts/replay_sample_math.gd")
const REASON_NO_BUFFER: String = "no-replay-buffer"
const REASON_NO_EVALUATOR: String = "no-root-evaluator"
const REASON_NO_FIELDS: String = "no-clip-fields"
const REASON_FRACTIONAL: String = "fractional-sample-unrecovered"
const REASON_DANGLING: String = "dangling-titem"
const REASON_BAD_CLIP: String = "clip-not-available"

var buffer = null
var pool = null
var evaluator: Object = null
var speed_scale: float = 0.5
var clip_fields: Dictionary = {}
var last_error: String = ""
var interpolation_unrecovered: bool = false
var last_frame: int = 0
var last_sample_a: float = 0.0
var last_sample_b: float = 0.0


func bind(replay_buffer, item_pool,
        root_evaluator: Object, fields: Dictionary = {}, speed: float = 0.5) -> bool:
    unbind()
    buffer = replay_buffer
    pool = item_pool
    evaluator = root_evaluator
    clip_fields = fields
    speed_scale = speed
    last_error = ""
    if buffer == null:
        last_error = REASON_NO_BUFFER
        return false
    if pool == null:
        last_error = REASON_DANGLING
        return false
    # Each 0x2c record owns one strong TItem reference (createcopy @ 0x188028).
    for record in buffer.records:
        if not record.has("item_id"):
            var id: int = pool.new_hash_string(String(record.get("animation", "")))
            if id < 0:
                last_error = pool.last_error
                return false
            record["item_id"] = id
    return true


func unbind() -> void:
    # destroy @ 0x18b294 releases each record's TItem reference.
    if buffer != null and pool != null:
        for record in buffer.records:
            if record.has("item_id"):
                pool.record_destroy(int(record["item_id"]))
                record.erase("item_id")
    buffer = null
    pool = null
    evaluator = null
    clip_fields = {}
    last_error = ""
    interpolation_unrecovered = false


func _fields_for(clip_name: String) -> Dictionary:
    if bool(clip_fields.get("ok", false)):
        return clip_fields
    if evaluator != null and evaluator.has_method("fields_for_clip"):
        return evaluator.call("fields_for_clip", clip_name)
    return {"ok": false, "reason": REASON_NO_FIELDS}


func seek(time_ms: int) -> Dictionary:
    last_error = ""
    interpolation_unrecovered = false
    last_frame = 0
    last_sample_a = 0.0
    last_sample_b = 0.0
    if buffer == null:
        last_error = REASON_NO_BUFFER
        return {"ok": false, "reason": last_error}
    var records: Array[Dictionary] = buffer.records
    buffer.cursor = 0
    if records.is_empty() or time_ms <= int(records[0]["time_ms"]):
        return {"ok": true, "cursor": 0, "applied": false}
    var count: int = records.size()
    var cursor: int = count
    var i: int = 1
    while i < count:
        if time_ms <= int(records[i]["time_ms"]):
            cursor = i
            break
        i += 1
    buffer.cursor = cursor
    var prev: Dictionary = records[cursor - 1]
    var fields: Dictionary = _fields_for(String(prev.get("animation", "")))
    if not bool(fields.get("ok", false)):
        last_error = String(fields.get("reason", REASON_NO_FIELDS))
        return {"ok": false, "cursor": cursor, "reason": last_error}
    if evaluator == null:
        last_error = REASON_NO_EVALUATOR
        return {"ok": false, "cursor": cursor, "reason": last_error}
    if pool == null or not pool.is_alive(int(prev.get("item_id", -1))):
        last_error = REASON_DANGLING
        return {"ok": false, "cursor": cursor, "reason": last_error}
    var animation: String = String(prev["animation"])
    if evaluator.has_method("set_clip") and not bool(evaluator.call("set_clip", animation)):
        last_error = REASON_BAD_CLIP
        return {"ok": false, "cursor": cursor, "reason": last_error}

    var delta_ms: int = time_ms - int(prev["time_ms"])
    var frame: int = SampleMath.frame_from_delta(delta_ms, speed_scale)
    last_frame = frame
    var a_state: Dictionary = SampleMath.set_to_sample(0.0, fields)
    var b_state: Dictionary = SampleMath.set_to_sample(float(frame), fields)
    if not bool(a_state["ok"]) or not bool(b_state["ok"]):
        last_error = String(a_state.get("reason", b_state.get("reason", REASON_NO_FIELDS)))
        return {"ok": false, "cursor": cursor, "reason": last_error}
    last_sample_a = float(a_state["sample_exact"])
    last_sample_b = float(b_state["sample_exact"])
    if bool(a_state["fractional"]) or bool(b_state["fractional"]):
        var supports: bool = evaluator.has_method("supports_fractional") \
            and bool(evaluator.call("supports_fractional"))
        if not supports:
            interpolation_unrecovered = true
            last_error = REASON_FRACTIONAL
            return {"ok": false, "cursor": cursor, "reason": last_error,
                "interpolation_unrecovered": true}

    # SetReplayCurrentTime borrows the record's TItem: addref before the
    # SetAnimationFrame/SetToSample work, release afterwards (0x1b4504/0x1b4538).
    var item_id: int = int(prev["item_id"])
    if not pool.addref(item_id):
        last_error = pool.last_error
        return {"ok": false, "cursor": cursor, "reason": last_error}
    var a_pos: Variant = evaluator.call("root_position", last_sample_a)
    var b_pos: Variant = evaluator.call("root_position", last_sample_b)
    pool.release(item_id)
    if a_pos == null or b_pos == null or not (a_pos is Vector3) or not (b_pos is Vector3):
        last_error = REASON_BAD_CLIP
        return {"ok": false, "cursor": cursor, "reason": last_error}
    var position: Vector3 = (prev["position"] as Vector3) + ((b_pos as Vector3) - (a_pos as Vector3))
    var rotation: Quaternion = prev["rotation"] as Quaternion
    return {
        "ok": true,
        "cursor": cursor,
        "applied": true,
        "position": position,
        "rotation": rotation,
        "frame": frame,
        "sample_a": last_sample_a,
        "sample_b": last_sample_b,
        "time_state": b_state["time_state"],
        "delta_ms": delta_ms,
        "speed_scale": speed_scale,
        "interpolation_unrecovered": false,
    }

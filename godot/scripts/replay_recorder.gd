extends RefCounted
class_name ReplayRecorder
## Port-side producer for krm::CFighter's recovered 0x2C (44-byte) replay record.
##
## APPEND SITE (native, read-only evidence)
##   krm::CFighter::SetAnimation @ 0x001b6e94, gate at 0x1b77?? reads
##   fighter+0x16f; only when it is non-zero the 0x2c block built at stack
##   -0x118 is copied into the +0x18c scontainer at
##   data + stride*count, then count (+0x194) is incremented:
##     0x1b7800  str  r2,[sp,#0x78]   ; record+0x28 = param_3 (time ms)
##     0x1b780c  ldrb r2,[r4,#0x135]  ; record+0x24 = +0x135 byte
##     0x1b7814  strb r2,[sp,#0x74]
##     0x1b7870  ldr  pc,[r3,#0x4]    ; element copy hook, 0x2c bytes
##   The block starts at aGStack_118 (GVec3 position, TQuaternion rotation,
##   TItem* animation, param_6 float, +0x135 byte, param_3 time).
##
## FIELD BRIDGES (port side, documented; none invented)
##   +0x00 position    native gfxScnFrame::GetPos  -> PortFighter.global_position
##   +0x0c rotation    native gfxScnFrame::GetRot  -> the fighter's global basis
##                     quaternion (the port only yaws, so w=1/axis=Y runs)
##   +0x1c animation   native TItem* of the
##                     krm::krt::HashString passed to SetAnimation
##                     -> clip name the port is playing.  The native interned
##                     string item's pointer/hash value is produced by
##                     CHStrMgr, whose hashing was NOT recovered, so it cannot
##                     be reproduced.  The slot therefore carries an explicit
##                     handle: the index of the clip name in `animation_table`.
##                     That table is built only from native animation names the
##                     port already uses for playback (the recovered clip
##                     tables), so a handle is a proven port handle, never a
##                     claimed native pointer.  Unknown names fail closed.
##   +0x20 param_6     SetAnimation's 5th argument (blend/transition float).
##                     No proven port equivalent exists, so the recorded value
##                     is 0.0 flagged by `float_param_unrecovered`; it is never
##                     presented as a recovered native value.
##   +0x24 +0x135      CFighter+0x135 "internal fighting-set" selector:
##                     GetActiveSetAnimation @ 0x001b00d0 returns
##                     GetInternalFightingSetAnimation(fighter+0x7c) when the
##                     byte is non-zero, otherwise the fighter's own +0xD4
##                     table.  FollowLink @ 0x001b80dc writes 1 on the grabbed
##                     partner right before the victim SetAnimation, and
##                     FollowLink/Restart/Init clear it.  The port plays those
##                     victim clips (grabbed*/endattackcomp*) in the same
##                     states, which is the only selector the port can emit.
##   +0x28 time        native param_3, absolute GetCurrentMili() ms
##                     -> Time.get_ticks_msec() on the port.
##
## CADENCE
##   The native append happens inside SetAnimation, i.e. when an animation is
##   set.  The port integrates position every physics frame and
##   RecordReplayUpdate advances at most ONE record per Update call, so the
##   recorder samples once per physics frame: without per-frame samples the
##   recovered 0.5x playback cannot reproduce the recorded motion.  The record
##   layout, the field meanings above and the comparison formula in
##   replay_buffer.gd are unchanged; only the sampling cadence is the port's.
##
## The table is part of the recording: encode_records()/decode_records() must
## use the same table, and a handle outside it is rejected (fail closed).

const ReplayBufferScript = preload("res://scripts/replay_buffer.gd")

const RECORD_STRIDE: int = 0x2C
const OFFSET_POSITION: int = 0x00
const OFFSET_ROTATION: int = 0x0C
const OFFSET_ANIMATION: int = 0x1C
const OFFSET_FLOAT_PARAM: int = 0x20
const OFFSET_SET_INDEX: int = 0x24
const OFFSET_TIME_MS: int = 0x28

const REASON_OK: String = "ok"
const REASON_DISABLED: String = "recorder-disabled"
const REASON_NO_ANIMATION: String = "no-animation-name"
const REASON_ANIM_UNKNOWN: String = "unknown-animation-handle"
const REASON_NO_TABLE: String = "no-animation-table"
const REASON_TIME_REGRESSION: String = "non-monotonic-time"

var buffer = ReplayBufferScript.new()
## Ordered native animation names; the record's +0x1c handle is the index.
var animation_table: Array[String] = []
var enabled: bool = false
## The native +0x20 blend parameter has no recovered port mapping.
var float_param_unrecovered: bool = true
var float_param_value: float = 0.0
var last_error: String = ""
var appended: int = 0
var rejected: int = 0


## Replace the handle table. Unknown clip names are simply not present, so
## append_sample() fails closed for them instead of inventing a handle.
func configure(table: Array) -> void:
    animation_table = table_from_names(table)
    buffer.clear()
    last_error = ""
    appended = 0
    rejected = 0


## Deterministic handle table: unique, non-empty names in ascending order.
static func table_from_names(names: Array) -> Array[String]:
    var unique: Dictionary = {}
    for raw: Variant in names:
        var name: String = String(raw)
        if not name.is_empty():
            unique[name] = true
    var keys: Array = unique.keys()
    keys.sort()
    var table: Array[String] = []
    for key: Variant in keys:
        table.append(String(key))
    return table


func handle_for(animation_name: String) -> int:
    return animation_table.find(animation_name)


## Append one sampled 0x2c record. Returns true when the record was stored.
## A missing/unknown animation name or a time that would break the native
## non-decreasing record order is refused and counted, never stored.
func append_sample(position: Vector3, rotation: Quaternion, animation_name: String,
        set_selector: int, time_ms: int) -> bool:
    last_error = ""
    if not enabled:
        last_error = REASON_DISABLED
        return false
    if animation_table.is_empty():
        last_error = REASON_NO_TABLE
        rejected += 1
        return false
    if animation_name.is_empty():
        last_error = REASON_NO_ANIMATION
        rejected += 1
        return false
    var handle: int = handle_for(animation_name)
    if handle < 0:
        last_error = "%s: %s" % [REASON_ANIM_UNKNOWN, animation_name]
        rejected += 1
        return false
    if not buffer.records.is_empty():
        var previous: int = int(buffer.records[buffer.records.size() - 1]["time_ms"])
        if time_ms < previous:
            last_error = "%s: %d < %d" % [REASON_TIME_REGRESSION, time_ms, previous]
            rejected += 1
            return false
    buffer.append_record(position, rotation, animation_name,
        float_param_value, set_selector, time_ms)
    appended += 1
    return true


## Exact native 0x2c byte layout. Fails closed (empty array + last_error) when
## any recorded clip is outside the table.
func encode() -> PackedByteArray:
    last_error = ""
    if animation_table.is_empty():
        last_error = REASON_NO_TABLE
        return PackedByteArray()
    var bytes: PackedByteArray = buffer.encode_records(animation_table)
    if bytes.is_empty() and not buffer.records.is_empty():
        last_error = buffer.last_error
    return bytes


## Load records from the exact native layout. The supplied table becomes this
## recorder's table, so a later encode() reproduces the same handles.
func decode(bytes: PackedByteArray, table: Array) -> bool:
    last_error = ""
    var decoded_table: Array[String] = table_from_names(table)
    if decoded_table.is_empty():
        last_error = REASON_NO_TABLE
        return false
    var loaded = ReplayBufferScript.new()
    if not loaded.decode_records(bytes, decoded_table):
        last_error = loaded.last_error
        return false
    animation_table = decoded_table
    buffer = loaded
    appended = buffer.size()
    rejected = 0
    return true


func reset() -> void:
    buffer.clear()
    last_error = ""
    appended = 0
    rejected = 0


func size() -> int:
    return buffer.size()


## Absolute ms of the first record; this is the port's game+0x838 equivalent
## (the match clock captured when state 4 was entered).
func first_time_ms() -> int:
    if buffer.records.is_empty():
        return -1
    return int(buffer.records[0]["time_ms"])


func last_time_ms() -> int:
    if buffer.records.is_empty():
        return -1
    return int(buffer.records[buffer.records.size() - 1]["time_ms"])


func status() -> Dictionary:
    return {
        "enabled": enabled,
        "records": buffer.size(),
        "appended": appended,
        "rejected": rejected,
        "last_error": last_error,
        "table_size": animation_table.size(),
        "table_sha256": String("\n".join(animation_table)).sha256_text(),
        "float_param_unrecovered": float_param_unrecovered,
        "first_time_ms": first_time_ms(),
        "last_time_ms": last_time_ms(),
        "record_stride": RECORD_STRIDE,
    }

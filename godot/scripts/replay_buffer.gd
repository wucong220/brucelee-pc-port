extends RefCounted
class_name ReplayBuffer
## Recovered replay buffer for krm::CFighter (state 6 REPLAY).
##
## EVERY layout constant below comes from the native ARM binary
## (libdefault.so sha256 1da7a30c...), not from guessing:
##
## Container (dtl::scontainer / svector) living in CFighter:
##   +0x18c  element vtable (element destructor @ [0], copy @ [4], size @ [0xc])
##   +0x190  capacity
##   +0x194  element count        (uint)
##   +0x198  data base pointer
##   +0x19c  element stride = 0x2c (written in CFighter ctor @ 0x1b2934/0x1b2d9c
##           and copy ctor @ 0x18e534; confirmed by destructor walking puVar3[3])
##   +0x170  replay cursor        (uint)
##   +0x16f  "record on SetAnimation" byte flag (set to 1 in CFighter ctor;
##           cleared to 0 for both fighters by SetState case 6 @ 0x18895c/0x188984)
##   +0x140  fighter global battle speed multiplier (CBeatEmUpGame::SetSpeed;
##           default 0x3F800000 = 1.0f, state 6 passes 0x3F000000 = 0.5f)
##
## One 0x2c record, built on the stack in CFighter::SetAnimation @ 0x1b6e94
## (aGStack_118 = -0x118, aTStack_10c = -0x10c, local_fc = -0xfc,
##  local_f8 = -0xf8, local_f4 = -0xf4, local_f0 = -0xf0) and copied into the
## container with the element copy hook:
##   +0x00  GVec3 position      (float x,y,z; gfxScnFrame::GetPos)
##   +0x0c  TQuaternion rotation(float x,y,z,w; gfxScnFrame::GetRot)
##   +0x1c  TItem* animation hash handle (4 bytes; port side: animation name)
##   +0x20  float param_6 passed to SetAnimation (5th arg)
##   +0x24  byte +0x135 (active fighting-set selector; ldrb/strb in
##           RecordReplayUpdate @ 0x1b8e6c/0x1b8e84)
##   +0x28  uint param_3 = SetAnimation's time argument (milliseconds)
## The remaining records' times are absolute GetCurrentMili()-derived ms.
##
## Recording gate: SetAnimation only appends when CFighter+0x16f != 0.
## Playback:
##   RecordReplayUpdate(sample) @ 0x1b8db8 applies at most ONE record per call:
##     if cursor < count and float(record.time) <= float(sample) * +0x140:
##         restore position/rotation/+0x135, ref the animation item,
##         SetAnimation(this, anim, sample, 0, 0, record.float_param); cursor++
##   SetReplayCurrentTime(t) @ 0x1b4480 resets cursor and seeks.
##   ReplayEnded() @ 0x1b0168: cursor >= count.
##
## State 6 (CBeatEmUpGame::Update case 6 @ 0x18d0ac):
##   sample = GetStateTime() + 2 * replay_base      (vadd.f32 s16,s16,s16)
##   replay_base (game +0x838) was written from +0x7f8 on entering state 4
##   and passed to SetReplayCurrentTime for both fighters.
##   With +0x140 = 0.5f the effective record time reached is
##     0.5 * (elapsed + 2*base) = base + 0.5*elapsed
##   so the replay starts at the fight-start time and advances at HALF speed
##   (0.5x), not 2x. The literal '2' is a base-offset compensation for the 0.5
##   speed scale, NOT a rate multiplier.
##
## QueryString (krm::CBeatEmUpMatch::QueryString @ 0x171b08) state 6 text:
##   (11000 - GetStateTime()) / 1000, clamped to 10  -> 11000 ms display budget.
##
## Fields whose *layout* is recovered but whose runtime *meaning* is still a
## port-level mapping (documented, never invented): the TItem animation hash ->
## Godot clip name, and the +0x135 fighting-set selector. encode/decode keeps
## the animation as an explicit table handle and fails closed if it is unknown.

const RECORD_STRIDE: int = 0x2C  # 44
const OFFSET_POSITION: int = 0x00
const OFFSET_ROTATION: int = 0x0C
const OFFSET_ANIMATION: int = 0x1C
const OFFSET_FLOAT_PARAM: int = 0x20
const OFFSET_SET_INDEX: int = 0x24
const OFFSET_TIME_MS: int = 0x28

const TIME_TO_FRAME: float = 0.03  # PC-relative 0.03f, SimpleAnimUpdate/SetReplayCurrentTime
const REPLAY_COUNTDOWN_BUDGET_MS: int = 11000
const REPLAY_COUNTDOWN_CAP_SECONDS: int = 10

# State 6 passes 0x3F000000 (0.5f) to CBeatEmUpGame::SetSpeed.
const STATE6_SPEED_SCALE: float = 0.5
# Update case 6 doubles replay_base (+0x838) before adding GetStateTime().
const REPLAY_BASE_FACTOR: int = 2

const REASON_OK: String = "ok"
const REASON_BAD_FORMAT: String = "bad-replay-format"
const REASON_ANIM_UNKNOWN: String = "unknown-animation-handle"
const REASON_INTERP_UNRECOVERED: String = "seek-interpolation-unrecovered"

## Each entry: {position: Vector3, rotation: Quaternion, animation: String,
##              float_param: float, set_index: int, time_ms: int}
var records: Array[Dictionary] = []
var cursor: int = 0
## Set when a seek lands strictly inside a record interval. The native code then
## interpolates root motion through anmRoot::SetToSample, whose exact formula was
## not recovered; we refuse to invent it.
var last_seek_interpolation_unrecovered: bool = false
var last_error: String = ""


func size() -> int:
    return records.size()


func clear() -> void:
    records.clear()
    cursor = 0
    last_seek_interpolation_unrecovered = false
    last_error = ""


func append_record(position: Vector3, rotation: Quaternion, animation: String,
        float_param: float, set_index: int, time_ms: int) -> void:
    records.append({
        "position": position,
        "rotation": rotation,
        "animation": animation,
        "float_param": float_param,
        "set_index": int(set_index),
        "time_ms": int(time_ms),
    })


## Native RecordReplayUpdate: at most one record advances per call.
## Returns true when a record was applied this call.
func record_replay_update(sample_ms: int, speed_scale: float) -> bool:
    if cursor >= records.size():
        return false
    var record: Dictionary = records[cursor]
    var record_time: float = float(int(record["time_ms"]))
    var threshold: float = float(sample_ms) * speed_scale
    if record_time <= threshold:
        cursor += 1
        return true
    return false


## Native SetReplayCurrentTime. Returns a result dictionary. `applied` mirrors
## the native path that immediately poses the previous record; we only fully
## support the exact-record (offset 0) case. Landing inside an interval sets
## last_seek_interpolation_unrecovered because anmRoot::SetToSample is missing.
func set_replay_current_time(time_ms: int) -> Dictionary:
    cursor = 0
    last_seek_interpolation_unrecovered = false
    if records.is_empty():
        return {"ok": true, "cursor": 0, "applied": false}
    if time_ms <= int(records[0]["time_ms"]):
        return {"ok": true, "cursor": 0, "applied": false}
    var index: int = 1
    var found: bool = false
    while index < records.size():
        if time_ms <= int(records[index]["time_ms"]):
            cursor = index
            found = true
            break
        index += 1
    if not found:
        cursor = records.size()
        return {"ok": true, "cursor": cursor, "applied": false}
    if cursor == 0:
        return {"ok": true, "cursor": 0, "applied": false}
    var previous: Dictionary = records[cursor - 1]
    var offset_ms: int = time_ms - int(previous["time_ms"])
    var applied: bool = offset_ms == 0
    if not applied:
        last_seek_interpolation_unrecovered = true
    return {"ok": true, "cursor": cursor, "applied": applied,
        "interpolation_unrecovered": not applied}


func replay_ended() -> bool:
    return cursor >= records.size()


## Encode into the exact native 0x2c record layout. `animation_table` maps the
## port animation name to a 32-bit handle (the native TItem* slot). Unknown
## names fail closed.
func encode_records(animation_table: Array[String]) -> PackedByteArray:
    last_error = ""
    var bytes := PackedByteArray()
    bytes.resize(records.size() * RECORD_STRIDE)
    for i in records.size():
        var record: Dictionary = records[i]
        var base: int = i * RECORD_STRIDE
        var position: Vector3 = record["position"]
        var rotation: Quaternion = record["rotation"]
        bytes.encode_float(base + OFFSET_POSITION + 0, position.x)
        bytes.encode_float(base + OFFSET_POSITION + 4, position.y)
        bytes.encode_float(base + OFFSET_POSITION + 8, position.z)
        bytes.encode_float(base + OFFSET_ROTATION + 0, rotation.x)
        bytes.encode_float(base + OFFSET_ROTATION + 4, rotation.y)
        bytes.encode_float(base + OFFSET_ROTATION + 8, rotation.z)
        bytes.encode_float(base + OFFSET_ROTATION + 12, rotation.w)
        var handle: int = animation_table.find(String(record["animation"]))
        if handle < 0:
            last_error = "%s: %s" % [REASON_ANIM_UNKNOWN, record["animation"]]
            return PackedByteArray()
        bytes.encode_u32(base + OFFSET_ANIMATION, handle)
        bytes.encode_float(base + OFFSET_FLOAT_PARAM, float(record["float_param"]))
        bytes.encode_u8(base + OFFSET_SET_INDEX, int(record["set_index"]) & 0xFF)
        # +0x25..+0x27 stay zero (native padding observed in the stack record)
        bytes.encode_u32(base + OFFSET_TIME_MS, int(record["time_ms"]))
    return bytes


## Decode the exact native 0x2c record layout. `animation_table` maps handle ->
## port animation name. A handle outside the table fails closed.
func decode_records(bytes: PackedByteArray, animation_table: Array[String]) -> bool:
    clear()
    last_error = ""
    if bytes.size() == 0 or bytes.size() % RECORD_STRIDE != 0:
        last_error = "%s: size=%d not a multiple of %d" % [
            REASON_BAD_FORMAT, bytes.size(), RECORD_STRIDE]
        return false
    var count: int = bytes.size() / RECORD_STRIDE
    for i in count:
        var base: int = i * RECORD_STRIDE
        var position := Vector3(
            bytes.decode_float(base + OFFSET_POSITION + 0),
            bytes.decode_float(base + OFFSET_POSITION + 4),
            bytes.decode_float(base + OFFSET_POSITION + 8))
        var rotation := Quaternion(
            bytes.decode_float(base + OFFSET_ROTATION + 0),
            bytes.decode_float(base + OFFSET_ROTATION + 4),
            bytes.decode_float(base + OFFSET_ROTATION + 8),
            bytes.decode_float(base + OFFSET_ROTATION + 12))
        var handle: int = bytes.decode_u32(base + OFFSET_ANIMATION)
        if handle < 0 or handle >= animation_table.size():
            last_error = "%s: handle=%d table=%d" % [
                REASON_ANIM_UNKNOWN, handle, animation_table.size()]
            return false
        append_record(position, rotation, animation_table[handle],
            bytes.decode_float(base + OFFSET_FLOAT_PARAM),
            _signed_byte(bytes.decode_u8(base + OFFSET_SET_INDEX)),
            bytes.decode_u32(base + OFFSET_TIME_MS))
    return true


static func _signed_byte(value: int) -> int:
    return value - 256 if value >= 128 else value


## Native QueryString state 6 text: (11000 - GetStateTime()) / 1000, capped at 10.
## Integer division on unsigned milliseconds; after 11000 ms the native underflow
## is clamped back to 10, which is reproduced here.
static func replay_countdown_seconds(elapsed_ms: int) -> int:
    if elapsed_ms > REPLAY_COUNTDOWN_BUDGET_MS:
        return REPLAY_COUNTDOWN_CAP_SECONDS
    var value: int = int((REPLAY_COUNTDOWN_BUDGET_MS - elapsed_ms) / 1000)
    if value > REPLAY_COUNTDOWN_CAP_SECONDS:
        value = REPLAY_COUNTDOWN_CAP_SECONDS
    return value

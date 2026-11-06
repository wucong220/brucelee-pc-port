class_name OpponentVoiceOverlay
extends RefCounted

const RecoveredSettings = preload("res://scripts/recovered_settings.gd")
## Opt-in opponent voice overlay, scheduled at the recovered source frame.
##
## Data: `res://data/opponent_voice_cues.json` (schema 2), generated only from
## recovered archive evidence:
##   opponent id  -> port attack config  (main.gd MENU_OPPONENT_CONFIG)
##   port slot    -> source_action       (that config's own `attacks` /
##                                        `reaction_profiles` rows)
##   source_action-> set sounds[] row    (adreno_200/set/<set>.set
##                                        animations[].sounds[] with is_voice)
##   sounds[] row -> file/frame/volume/unique  (all five copied verbatim)
##
## Timing: `frame` is the native 30 fps source frame of the action, so a cue at
## f11 starts 11/30 s after the action starts.  A cue without frame data keeps
## the old start-of-action behaviour (delay 0).  `volume` is applied to the
## player, and `unique` (the fighting-set character token) must be empty or one
## the archive itself uses for that voice directory; otherwise the cue is
## filtered out instead of being played for the wrong fighter.
##
## Dedup: within one action instance a cue is identified by
## `lower(file) | frame | unique`; exact duplicates are scheduled once.
## Starting a new action instance invalidates the previous instance's pending
## cues, so a cancelled/retriggered action cannot fire a stale grunt later.
##
## Off by default.  Set BRUCELEE_OPPONENT_VOICE=1 to enable, and point
## BRUCELEE_OPPONENT_VOICE_ROOT at the staging root that contains
## `adreno_200/sounds/voices/<voice_dir>/...`.  The package directory itself is
## never used: the repo's audio policy keeps playable resources outside the
## repository, so the roots here mirror `main.gd _voice_roots()`.
##
## Usage from an existing script (the only wiring needed):
##     var overlay := OpponentVoiceOverlay.new()
##     overlay.configure(self)                       # host node for players
##     overlay.play_attack(opponent_id, action)      # on opponent attack start
##     overlay.play_pain(opponent_id, reaction_action)
##
## `configure()` returns "" on success or a non-fatal error string; the overlay
## then stays inert instead of throwing.

const ENV_ENABLE := "BRUCELEE_OPPONENT_VOICE"
const ENV_ROOT := "BRUCELEE_OPPONENT_VOICE_ROOT"
const DEFAULT_DATA_PATH := "res://data/opponent_voice_cues.json"
const STAGING_DIR := "BruceLee-PC-Port/opponent-voice-frame-20261104"
const MAX_CACHED_STREAMS := 96
const MAX_EVENTS := 512
const FRAME_RATE := 30.0
const TIMING_EPSILON := 0.0001

## Kinds accepted by `cue_for`.
const KIND_ATTACK := "attack"
const KIND_REACTION := "reaction"
const KIND_ACTION := "action"

## Status strings returned by the play helpers.
const STATUS_DISABLED := "disabled"
const STATUS_NOT_READY := "not-ready"
const STATUS_UNKNOWN_OPPONENT := "unknown-opponent"
const STATUS_NO_CUE := "no-cue"
const STATUS_FILTERED := "filtered"
const STATUS_NO_HOST := "no-host"
const STATUS_LOAD_FAILED := "load-failed"
const STATUS_PLAYED := "played"
const STATUS_SCHEDULED := "scheduled"

var _host: Node = null
var _table: Dictionary = {}
var _data_path: String = ""
var _error: String = ""
var _streams: Dictionary = {}
var _load_errors: Dictionary = {}
var _active: AudioStreamPlayer = null

# Scheduler state.  `_sequence` is bumped for every new action instance; any
# timer carrying an older sequence is stale and must not play.
var _sequence: int = 0
var _pending: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _event_id: int = 0

var _plays: int = 0
var _misses: int = 0
var _scheduled_count: int = 0
var _played_count: int = 0
var _deduped_count: int = 0
var _cancelled_count: int = 0
var _filtered_count: int = 0
var _fallback_count: int = 0


static func enabled() -> bool:
    return OS.get_environment(ENV_ENABLE) == "1"


## Roots that may hold `adreno_200/sounds/voices/<voice_dir>/...`.
## Order: explicit env root, then the per-user staging directory.
static func voice_roots() -> Array[String]:
    var roots: Array[String] = []
    var env_root: String = OS.get_environment(ENV_ROOT)
    if not env_root.is_empty():
        roots.append(env_root)
    # Self-contained package: audio/voices/<voice_dir>/<file> beside the exe.
    roots.append(OS.get_executable_path().get_base_dir())
    var local_app_data: String = OS.get_environment("LOCALAPPDATA")
    if not local_app_data.is_empty():
        roots.append(local_app_data.path_join(STAGING_DIR))
    return roots


## True when at least one configured root exists on disk.
static func has_staging() -> bool:
    for root: String in voice_roots():
        if DirAccess.dir_exists_absolute(root.path_join("adreno_200/sounds/voices")):
            return true
    return false


func configure(host: Node = null, data_path: String = DEFAULT_DATA_PATH) -> String:
    _host = host
    _error = ""
    _table = {}
    _data_path = data_path
    if not FileAccess.file_exists(data_path):
        _error = "overlay data missing: " + data_path
        return _error
    var text: String = FileAccess.get_file_as_string(data_path)
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        _error = "overlay data is not a JSON object: " + data_path
        return _error
    var data: Dictionary = parsed
    if String(data.get("kind", "")) != "opponent_voice_overlay":
        _error = "unexpected overlay data kind in " + data_path
        return _error
    if int(data.get("schema_version", 0)) < 2:
        _error = "overlay data schema is older than 2 (no frame/unique fields): " + data_path
        return _error
    if typeof(data.get("characters")) != TYPE_DICTIONARY:
        _error = "overlay data has no characters table"
        return _error
    var rate: float = float(data.get("frame_rate", FRAME_RATE))
    if absf(rate - FRAME_RATE) > 0.0001:
        _error = "unexpected frame rate %f in %s" % [rate, data_path]
        return _error
    _table = data
    return ""


func is_ready() -> bool:
    return _error.is_empty() and not _table.is_empty()


func error() -> String:
    return _error


func frame_rate() -> float:
    return FRAME_RATE


func opponent_ids() -> Array[String]:
    var out: Array[String] = []
    for key: String in (_table.get("characters", {}) as Dictionary).keys():
        out.append(key)
    out.sort()
    return out


## Resolve the opponent id from a config resource path such as
## `res://data/attack_config_ken.json`.
func opponent_id_for_config(config_path: String) -> String:
    var key: String = config_path.replace("res://", "")
    var by_config: Dictionary = _table.get("by_config", {})
    return String(by_config.get(key, ""))


func character(opponent_id: String) -> Dictionary:
    var chars: Dictionary = _table.get("characters", {})
    return chars.get(opponent_id, {})


## Cue list for a port slot.
##   kind = "attack"   -> that opponent config's `attacks[slot]`
##   kind = "reaction" -> that opponent config's `reaction_profiles[kind.slot]`
##   kind = "action"   -> `slot` is a raw set action name (all_action_cues)
func cue_for(opponent_id: String, slot: String, kind: String = KIND_ATTACK) -> Array:
    var row: Dictionary = character(opponent_id)
    if row.is_empty():
        return []
    match kind:
        KIND_ATTACK:
            var attacks: Dictionary = row.get("attack_slots", {})
            return (attacks.get(slot, {}) as Dictionary).get("cues", [])
        KIND_REACTION:
            var reactions: Dictionary = row.get("reaction_slots", {})
            return (reactions.get(slot, {}) as Dictionary).get("cues", [])
        KIND_ACTION:
            var actions: Dictionary = row.get("all_action_cues", {})
            return actions.get(slot, [])
    return []


func source_action_for(opponent_id: String, slot: String, kind: String = KIND_ATTACK) -> String:
    var row: Dictionary = character(opponent_id)
    if row.is_empty():
        return ""
    var bucket: Dictionary = row.get("attack_slots", {}) if kind == KIND_ATTACK else row.get("reaction_slots", {})
    return String((bucket.get(slot, {}) as Dictionary).get("source_action", ""))


## True when the cue belongs to this opponent: its file must live under that
## character's fighting-set voice directory, and its `unique` token (when set)
## must be one the archive uses for that directory.  Empty `unique` is generic.
func cue_matches(opponent_id: String, cue: Dictionary) -> bool:
    if not bool(cue.get("is_voice", true)):
        return false
    var row: Dictionary = character(opponent_id)
    if row.is_empty():
        return false
    var voice_dir: String = String(row.get("voice_dir", ""))
    var file: String = String(cue.get("file", ""))
    if not file.is_empty() and not voice_dir.is_empty():
        if not file.begins_with("sounds/voices/" + voice_dir + "/"):
            return false
    var unique: String = String(cue.get("unique", ""))
    if unique.is_empty():
        return true
    var tokens: Array = row.get("unique_tokens", [])
    return tokens.has(unique)


## Absolute path of the first root that holds this voice file, or "".
func resolve_path(file: String) -> String:
    if file.is_empty():
        return ""
    for root: String in voice_roots():
        var candidate: String = root.path_join("adreno_200").path_join(file)
        if FileAccess.file_exists(candidate):
            return candidate
        # Packaged layout keeps the original set voice tree under audio/voices/.
        var direct: String = root.path_join("audio/voices").path_join(
            file.replace("sounds/voices/", "")
        )
        if FileAccess.file_exists(direct):
            return direct
    return ""


func load_cue(file: String) -> AudioStream:
    if _streams.has(file):
        return _streams[file] as AudioStream
    if _load_errors.has(file):
        return null
    var path: String = resolve_path(file)
    if path.is_empty():
        _load_errors[file] = "not found under any voice root"
        return null
    var stream: AudioStream = AudioStreamWAV.load_from_file(path)
    if stream == null:
        _load_errors[file] = "AudioStreamWAV.load_from_file failed"
        return null
    if _streams.size() >= MAX_CACHED_STREAMS:
        _streams.clear()
    _streams[file] = stream
    return stream


## Schedule every cue of a slot.  Returns
##   "disabled" | "not-ready" | "unknown-opponent" | "no-cue" | "filtered" |
##   "no-host" | "scheduled" | "played"
## "scheduled" means at least one cue waits frame/30 s; "played" means every
## accepted cue started immediately (frame 0 or frame-less fallback).
func play(opponent_id: String, slot: String, kind: String = KIND_ATTACK,
          volume_scale: float = 1.0) -> String:
    var cues: Array = cue_for(opponent_id, slot, kind)
    if cues.is_empty() and not character(opponent_id).is_empty():
        _misses += 1
        return STATUS_NO_CUE
    return play_cues(opponent_id, cues, kind + ":" + slot, volume_scale)


## Schedule an explicit cue list for an opponent (used by the slot helpers and
## by the validator).  All cues share one action instance.
func play_cues(opponent_id: String, cues: Array, label: String = "",
               volume_scale: float = 1.0) -> String:
    if not enabled():
        return STATUS_DISABLED
    if not is_ready():
        return STATUS_NOT_READY
    if character(opponent_id).is_empty():
        return STATUS_UNKNOWN_OPPONENT
    if cues.is_empty():
        _misses += 1
        return STATUS_NO_CUE
    if not is_instance_valid(_host):
        return STATUS_NO_HOST

    var accepted: Array = []
    var seen: Dictionary = {}
    for value: Variant in cues:
        if not value is Dictionary:
            continue
        var cue: Dictionary = value
        if not cue_matches(opponent_id, cue):
            _filtered_count += 1
            continue
        if String(cue.get("file", "")).is_empty():
            continue
        var key: String = _identity(cue)
        if seen.has(key):
            _deduped_count += 1
            continue
        seen[key] = true
        accepted.append(cue)
    if accepted.is_empty():
        _misses += 1
        return STATUS_FILTERED

    var delayed: bool = false
    _sequence += 1
    _cancel_pending()
    for value: Variant in accepted:
        if _schedule_cue(value as Dictionary, label, volume_scale):
            delayed = true
    _plays += 1
    return STATUS_SCHEDULED if delayed else STATUS_PLAYED


func play_attack(opponent_id: String, slot: String, volume_scale: float = 1.0) -> String:
    return play(opponent_id, slot, KIND_ATTACK, volume_scale)


func play_pain(opponent_id: String, reaction_action: String, volume_scale: float = 1.0) -> String:
    return play(opponent_id, reaction_action, KIND_ACTION, volume_scale)


## Play one explicit cue Dictionary ({"file", "frame", "volume", "unique"}).
func play_one(opponent_id: String, cue: Dictionary, volume_scale: float = 1.0) -> String:
    return play_cues(opponent_id, [cue], "one:" + String(cue.get("file", "")), volume_scale)


## Invalidate every pending cue (e.g. on round reset / fighter despawn).
func cancel_all() -> void:
    _sequence += 1
    _cancel_pending()


func _identity(cue: Dictionary) -> String:
    var frame_key: String = "none"
    if cue.has("frame") and cue.get("frame") != null:
        frame_key = "%.6f" % float(cue["frame"])
    return "%s|%s|%s" % [
        String(cue.get("file", "")).to_lower(), frame_key, String(cue.get("unique", ""))
    ]


## Returns true when the cue was deferred to a timer.
func _schedule_cue(cue: Dictionary, label: String, volume_scale: float) -> bool:
    var has_frame: bool = cue.has("frame") and cue.get("frame") != null
    var seconds: float = 0.0
    if has_frame:
        seconds = maxf(float(cue["frame"]), 0.0) / FRAME_RATE
    var fallback: bool = not has_frame
    if fallback:
        _fallback_count += 1
    _event_id += 1
    var event: Dictionary = {
        "id": _event_id,
        "sequence": _sequence,
        "label": label,
        "file": String(cue.get("file", "")),
        "frame": cue.get("frame", null) if has_frame else null,
        "volume": float(cue.get("volume", 1.0)),
        "unique": String(cue.get("unique", "")),
        "delay": seconds,
        "fallback": fallback,
        "status": "load-failed",
        "scheduled_usec": Time.get_ticks_usec(),
        "played_usec": 0,
    }
    var stream: AudioStream = load_cue(String(cue.get("file", "")))
    if stream == null:
        _record(event)
        return false
    # Timestamp after the (synchronous) decode so a cold decode does not look
    # like scheduling drift to the timing validator.
    event["scheduled_usec"] = Time.get_ticks_usec()
    if seconds <= TIMING_EPSILON:
        _spawn_cue(stream, cue, volume_scale, event)
        if event["status"] == "played":
            event["played_usec"] = Time.get_ticks_usec()
        _record(event)
        return false

    event["status"] = "pending"
    _pending.append(event)
    _record(event)
    var tree: SceneTree = _host.get_tree()
    if tree == null:
        # No clock (host outside the tree): keep the old start-of-action
        # behaviour instead of dropping the voice.
        if not fallback:
            _fallback_count += 1
        event["fallback"] = true
        var pending_index: int = _find_pending(int(event.get("id", -1)))
        if pending_index >= 0:
            _pending.remove_at(pending_index)
        _spawn_cue(stream, cue, volume_scale, event)
        if event["status"] == "played":
            event["played_usec"] = Time.get_ticks_usec()
        return false
    tree.create_timer(seconds).timeout.connect(
        _on_cue_timer.bind(event, cue, stream, volume_scale)
    )
    _scheduled_count += 1
    return true


func _on_cue_timer(event: Dictionary, cue: Dictionary, stream: AudioStream,
                   volume_scale: float) -> void:
    var index: int = _find_pending(int(event.get("id", -1)))
    if index < 0:
        # Already invalidated by a newer action instance.
        return
    _pending.remove_at(index)
    if int(event.get("sequence", -1)) != _sequence:
        if String(event.get("status", "")) != "cancelled":
            event["status"] = "cancelled"
            _cancelled_count += 1
        return
    _spawn_cue(stream, cue, volume_scale, event)
    if event["status"] == "played":
        event["played_usec"] = Time.get_ticks_usec()


func _find_pending(event_id: int) -> int:
    for index: int in range(_pending.size()):
        if int(_pending[index].get("id", -1)) == event_id:
            return index
    return -1


func _cancel_pending() -> void:
    for event: Dictionary in _pending:
        event["status"] = "cancelled"
        _cancelled_count += 1
    _pending.clear()


func _spawn_cue(stream: AudioStream, cue: Dictionary, volume_scale: float,
                event: Dictionary) -> void:
    if not is_instance_valid(_host):
        event["status"] = "no-host"
        return
    if is_instance_valid(_active):
        _active.stop()
        if not _active.is_queued_for_deletion():
            _active.queue_free()
    var player: AudioStreamPlayer = AudioStreamPlayer.new()
    player.stream = stream
    var linear: float = clampf(float(cue.get("volume", 1.0)) * volume_scale, 0.001, 1.0)
    player.volume_db = linear_to_db(linear)
    RecoveredSettings.assign_player(player, RecoveredSettings.BUS_SOUND)
    player.finished.connect(player.queue_free)
    _host.add_child(player)
    _active = player
    player.play()
    _played_count += 1
    event["status"] = "played"


func _record(event: Dictionary) -> void:
    _events.append(event)
    if _events.size() > MAX_EVENTS:
        _events.pop_front()


## Deep copy of the schedule/play log, oldest first.
func events() -> Array:
    return _events.duplicate(true)


func pending_count() -> int:
    return _pending.size()


## Native cue frame is the original 30 fps source frame of the action.
static func cue_seconds(cue: Dictionary) -> float:
    if not cue.has("frame") or cue.get("frame") == null:
        return 0.0
    return maxf(float(cue["frame"]), 0.0) / FRAME_RATE


static func has_frame(cue: Dictionary) -> bool:
    return cue.has("frame") and cue.get("frame") != null


func stats() -> Dictionary:
    return {
        "enabled": enabled(),
        "ready": is_ready(),
        "error": _error,
        "data": _data_path,
        "characters": (_table.get("characters", {}) as Dictionary).size(),
        "cached_streams": _streams.size(),
        "load_errors": _load_errors.size(),
        "sequence": _sequence,
        "pending": _pending.size(),
        "plays": _plays,
        "misses": _misses,
        "scheduled": _scheduled_count,
        "played": _played_count,
        "deduped": _deduped_count,
        "cancelled": _cancelled_count,
        "filtered": _filtered_count,
        "fallbacks": _fallback_count,
        "roots": voice_roots(),
    }


func describe_slot(opponent_id: String, slot: String, kind: String = KIND_ATTACK) -> Dictionary:
    var cues: Array = cue_for(opponent_id, slot, kind)
    var first: Dictionary = cues[0] if cues.size() > 0 else {}
    return {
        "opponent": opponent_id,
        "kind": kind,
        "slot": slot,
        "source_action": source_action_for(opponent_id, slot, kind),
        "cue_count": cues.size(),
        "first_file": String(first.get("file", "")),
        "first_frame": first.get("frame", null),
        "first_delay": cue_seconds(first),
        "first_unique": String(first.get("unique", "")),
        "resolved_path": resolve_path(String(first.get("file", ""))),
    }

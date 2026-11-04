class_name OpponentVoiceOverlay
extends RefCounted
## Opt-in opponent voice overlay (additive; no existing script is modified).
##
## Data: `res://data/opponent_voice_cues.json`, generated only from recovered
## archive evidence:
##   opponent id  -> port attack config  (main.gd MENU_OPPONENT_CONFIG)
##   port slot    -> source_action       (that config's own `attacks` /
##                                        `reaction_profiles` rows)
##   source_action-> voice dir           (adreno_200/set/<set>.set
##                                        animations[].sounds[] with is_voice)
##   voice dir    -> WAV path            (adreno_200/sounds/voices/<dir>/...)
##
## Nothing here invents a filename: a cue exists only when the archive's own
## fighting-set `sounds` array attaches that file to that action for that
## character.  Slots without an archive voice resolve to an empty Array.
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
const STAGING_DIR := "BruceLee-PC-Port/opponent-voice-20261104"
const MAX_CACHED_STREAMS := 96

## Kinds accepted by `cue_for`.
const KIND_ATTACK := "attack"
const KIND_REACTION := "reaction"
const KIND_ACTION := "action"

var _host: Node = null
var _table: Dictionary = {}
var _data_path: String = ""
var _error: String = ""
var _streams: Dictionary = {}
var _load_errors: Dictionary = {}
var _active: AudioStreamPlayer = null
var _plays: int = 0
var _misses: int = 0


static func enabled() -> bool:
    return OS.get_environment(ENV_ENABLE) == "1"


## Roots that may hold `adreno_200/sounds/voices/<voice_dir>/...`.
## Order: explicit env root, then the per-user staging directory.
static func voice_roots() -> Array[String]:
    var roots: Array[String] = []
    var env_root: String = OS.get_environment(ENV_ROOT)
    if not env_root.is_empty():
        roots.append(env_root)
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
    if typeof(data.get("characters")) != TYPE_DICTIONARY:
        _error = "overlay data has no characters table"
        return _error
    _table = data
    return ""


func is_ready() -> bool:
    return _error.is_empty() and not _table.is_empty()


func error() -> String:
    return _error


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


## Absolute path of the first root that holds this voice file, or "".
## `file` is the archive-relative path stored in the cue table, e.g.
## `sounds/voices/brick_davies/special/M03_...wav`; roots are the directories
## that contain the recovered `adreno_200/` tree.
func resolve_path(file: String) -> String:
    if file.is_empty():
        return ""
    for root: String in voice_roots():
        var candidate: String = root.path_join("adreno_200").path_join(file)
        if FileAccess.file_exists(candidate):
            return candidate
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


## Play the first cue of a slot.  Returns a status string:
##   "disabled" | "not-ready" | "unknown-opponent" | "no-cue" |
##   "no-host" | "load-failed" | "played"
func play(opponent_id: String, slot: String, kind: String = KIND_ATTACK,
          volume_scale: float = 1.0) -> String:
    if not enabled():
        return "disabled"
    if not is_ready():
        return "not-ready"
    if character(opponent_id).is_empty():
        return "unknown-opponent"
    var cues: Array = cue_for(opponent_id, slot, kind)
    if cues.is_empty():
        _misses += 1
        return "no-cue"
    if not is_instance_valid(_host):
        return "no-host"
    return _play_cue(cues[0], volume_scale)


func play_attack(opponent_id: String, slot: String, volume_scale: float = 1.0) -> String:
    return play(opponent_id, slot, KIND_ATTACK, volume_scale)


func play_pain(opponent_id: String, reaction_action: String, volume_scale: float = 1.0) -> String:
    return play(opponent_id, reaction_action, KIND_ACTION, volume_scale)


## Play an explicit cue Dictionary ({"file", "frame", "volume"}).
func play_cue(cue: Dictionary, volume_scale: float = 1.0) -> String:
    if not enabled():
        return "disabled"
    if cue.is_empty():
        return "no-cue"
    if not is_instance_valid(_host):
        return "no-host"
    return _play_cue(cue, volume_scale)


func _play_cue(cue: Dictionary, volume_scale: float) -> String:
    var file: String = String(cue.get("file", ""))
    var stream: AudioStream = load_cue(file)
    if stream == null:
        return "load-failed"
    if is_instance_valid(_active):
        _active.stop()
        _active.queue_free()
    var player: AudioStreamPlayer = AudioStreamPlayer.new()
    player.stream = stream
    var linear: float = clampf(float(cue.get("volume", 1.0)) * volume_scale, 0.001, 1.0)
    player.volume_db = linear_to_db(linear)
    player.finished.connect(player.queue_free)
    _host.add_child(player)
    _active = player
    player.play()
    _plays += 1
    return "played"


## Native cue frame is the original 30 fps source frame of the action.
static func cue_seconds(cue: Dictionary) -> float:
    return float(cue.get("frame", 0)) / 30.0


func stats() -> Dictionary:
    return {
        "enabled": enabled(),
        "ready": is_ready(),
        "error": _error,
        "data": _data_path,
        "characters": (_table.get("characters", {}) as Dictionary).size(),
        "cached_streams": _streams.size(),
        "load_errors": _load_errors.size(),
        "plays": _plays,
        "misses": _misses,
        "roots": voice_roots(),
    }


func describe_slot(opponent_id: String, slot: String, kind: String = KIND_ATTACK) -> Dictionary:
    var cues: Array = cue_for(opponent_id, slot, kind)
    return {
        "opponent": opponent_id,
        "kind": kind,
        "slot": slot,
        "source_action": source_action_for(opponent_id, slot, kind),
        "cue_count": cues.size(),
        "first_file": String((cues[0] if cues.size() > 0 else {}).get("file", "")),
        "resolved_path": resolve_path(String((cues[0] if cues.size() > 0 else {}).get("file", ""))),
    }

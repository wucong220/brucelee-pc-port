extends SceneTree
## Validates that recovered attack / voice cues start at their original
## `sounds[].frame` offset (frame / 30 s) instead of at action start, that
## volume / unique / is_voice are honoured, that a cue without frame data keeps
## the start-of-action fallback, and that a single event never plays the same
## cue twice.
##
## Everything runs through the real res://scenes/main.tscn scene and a real
## package audio root, exactly like the shipped game boots:
##
##   godot --headless --path <project> --script res://tests/validate_sfx_frame_timing.gd \
##       -- <package_root>
##
## <package_root> must contain audio/{sfx,music,bruce_lee,commentator,menu_sfx}.

const SfxMusicMap = preload("res://scripts/sfx_music_map.gd")
const VoiceCueTiming = preload("res://scripts/voice_cue_timing.gd")

## Tolerance for the observed delay against frame/30.  Headless runs the same
## SceneTree timer path as the game; 80 ms covers frame pacing without hiding a
## flattened (frame-load) cue, which would be 133 ms early for a f4 cue.
const TIMING_TOLERANCE: float = 0.080

var failures: Array[String] = []
var observations: Array = []
var scene: Node = null
var player: PortFighter = null
var computer: PortFighter = null
var log: Array = []


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    failures.append(message)
    push_error(message)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        _fail("expected one argument: <package_root>")
        _finish()
        return
    var package_root: String = args[0].replace("\\", "/").trim_suffix("/")
    for sub: String in ["audio/sfx", "audio/music", "audio/bruce_lee"]:
        if not DirAccess.dir_exists_absolute(package_root.path_join(sub)):
            _fail("missing package audio directory: " + sub)
    if not failures.is_empty():
        _finish()
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_SCENE", "")
    OS.set_environment("BRUCELEE_SFX_ROOT", package_root.path_join("audio/sfx"))
    OS.set_environment("BRUCELEE_MUSIC_ROOT", package_root.path_join("audio/music"))
    OS.set_environment("BRUCELEE_VOICE_ROOT", package_root.path_join("audio/bruce_lee"))

    scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    scene.set_process(false)
    scene.set_physics_process(false)
    await process_frame
    await process_frame

    player = scene.get("player")
    computer = scene.get("computer")
    log = scene.get("_sfx_play_log")
    if player == null or computer == null:
        _fail("fighters were not created")
        _finish()
        return
    player.set_physics_process(false)
    computer.set_physics_process(false)
    if not bool(scene.call("_sfx_ready")):
        _fail("38-file SFX library did not load: " + str(scene.get("_sfx_audio_error")))
        _finish()
        return
    # Let the frame clock settle after the synchronous package load.  The first
    # post-load frame carries the whole load delta, and a SceneTreeTimer created
    # inside that frame would be decremented by it before it ever plays.
    for _settle: int in 8:
        await process_frame

    _check_source_table()
    await _check_frame_honoured()
    await _check_no_duplicates()
    _check_volume()
    _check_unique_filter()
    await _check_frame_absent_fallback()
    await _check_pain_voice_frame()
    _finish()


# --------------------------------------------------------------------------- #
# 1. the data itself: every row carries file/frame/volume/unique/is_voice and
#    the set hash is the verified brucelee.set payload.
# --------------------------------------------------------------------------- #
func _check_source_table() -> void:
    if VoiceCueTiming.SOURCE_SET_SHA256 != \
            "860b6dac1ae5043456fbf72b1cd93a5a1c76f036b3b995df5e57ce68b4d3762c":
        _fail("voice cue table is not built from the verified brucelee.set")
    var punch_cues: Array = VoiceCueTiming.attack_voice_cues("punch")
    if punch_cues.size() != 1:
        _fail("punch should map to exactly one recovered voice cue")
        return
    var cue: Dictionary = punch_cues[0]
    for key: String in ["file", "frame", "volume", "unique", "is_voice"]:
        if not cue.has(key):
            _fail("voice cue missing recovered field %s: %s" % [key, str(cue)])
    if int(cue["frame"]) != 4 or absf(float(cue["volume"]) - 0.45) > 0.001:
        _fail("punch voice cue changed: " + str(cue))
    if not bool(cue["is_voice"]):
        _fail("punch voice cue is not is_voice")
    # endattack1 carries two native voice cues (f44 kick grunt, f206 scream).
    var end_cues: Array = VoiceCueTiming.attack_voice_cues("endattack1")
    if end_cues.size() != 2:
        _fail("endattack1 should carry two recovered voice cues, got %d" % end_cues.size())
    else:
        var frames: Array = [int(end_cues[0]["frame"]), int(end_cues[1]["frame"])]
        if not frames.has(44) or not frames.has(206):
            _fail("endattack1 voice frames changed: " + str(frames))


# --------------------------------------------------------------------------- #
# 2. a real attack start: observe each cue actually start at frame/30.
# --------------------------------------------------------------------------- #
func _check_frame_honoured() -> void:
    await _expect_action_timing("punch", 2.6)
    await _expect_action_timing("high_kick3", 2.0)


func _expect_action_timing(action: String, quiet_seconds: float) -> void:
    log.clear()
    var voice_cues: Array = _voice_cues_for(action)
    var sfx_cues: Array = SfxMusicMap.attack_cues(action)
    if voice_cues.is_empty() and sfx_cues.is_empty():
        _fail("%s has no recovered cue to time" % action)
        return
    var t0: int = Time.get_ticks_msec()
    scene.call("_on_player_attack_started", action)
    await create_timer(quiet_seconds).timeout
    await process_frame

    var voice_label := "attack_voice:" + action
    var sfx_label := "attack:" + action
    for cue_value: Variant in voice_cues:
        if not cue_value is Dictionary:
            continue
        var cue: Dictionary = cue_value
        if not VoiceCueTiming.cue_matches(cue, "brucelee"):
            continue
        var entry: Dictionary = _find(
            log, String(cue["file"]), voice_label, true, int(cue["frame"])
        )
        if entry.is_empty():
            _fail("%s voice cue never played: %s" % [action, str(cue)])
            continue
        _assert_timing(entry, int(cue["frame"]), "%s voice" % action, t0)
        _assert_volume(entry, float(cue["volume"]), "%s voice" % action)
        _note(entry, action, "voice", true, t0)
    for cue_value: Variant in sfx_cues:
        if not cue_value is Dictionary:
            continue
        var cue: Dictionary = cue_value
        var entry: Dictionary = _find(
            log, String(cue["file"]), sfx_label, false, int(cue.get("frame", 0))
        )
        if entry.is_empty():
            _fail("%s sfx cue never played: %s" % [action, str(cue)])
            continue
        _assert_timing(
            entry, int(cue.get("frame", 0)), "%s sfx %s" % [action, cue["file"]],
            t0
        )
        _assert_volume(
            entry, float(cue.get("volume", 1.0)), "%s sfx %s" % [action, cue["file"]]
        )
        _note(entry, action, "sfx", false, t0)


func _note(
        entry: Dictionary, action: String, kind: String, is_voice: bool,
        start_ms: int
) -> void:
    observations.append({
        "action": action,
        "kind": kind,
        "file": String(entry.get("file", "")),
        "frame": int(entry.get("frame", -1)),
        "is_voice": is_voice,
        "unique": String(entry.get("unique", "")),
        "volume": float(entry.get("volume", 0.0)),
        "expected_seconds": float(int(entry.get("frame", 0)))
            / VoiceCueTiming.FRAME_RATE,
        "scheduled_seconds": float(entry.get("delay", 0.0)),
        "observed_timer_seconds": (
            float(int(entry.get("played_ms", 0)) - int(entry.get("scheduled_ms", 0)))
            / 1000.0
        ),
        "observed_from_action_start_seconds": (
            float(int(entry.get("played_ms", 0)) - start_ms) / 1000.0
        ),
    })


func _assert_timing(
        entry: Dictionary, frame: int, label: String, start_ms: int = -1
) -> void:
    var expected: float = float(frame) / VoiceCueTiming.FRAME_RATE
    var observed: float = (
        float(int(entry["played_ms"]) - int(entry["scheduled_ms"])) / 1000.0
    )
    if absf(observed - expected) > TIMING_TOLERANCE:
        _fail("%s expected %.3fs (f%d) after start, observed %.3fs: %s" % [
            label, expected, frame, observed, str(entry)
        ])
    if float(entry.get("delay", -1.0)) < -0.0001:
        _fail("%s has no scheduled delay: %s" % [label, str(entry)])
    if absf(float(entry.get("delay", 0.0)) - expected) > 0.0005:
        _fail("%s scheduled delay %.4f != frame/30 %.4f" % [
            label, float(entry.get("delay", 0.0)), expected
        ])
    # Wall clock from the action start to the actual playback, i.e. the same
    # measurement the player would hear.
    if start_ms >= 0:
        var from_start: float = (
            float(int(entry["played_ms"]) - start_ms) / 1000.0
        )
        if absf(from_start - expected) > TIMING_TOLERANCE + 0.020:
            _fail("%s wall-clock %.3fs != frame/30 %.3fs (f%d)" % [
                label, from_start, expected, frame
            ])
    if frame > 0 and observed < expected * 0.5:
        _fail("%s played at action start (%.3fs) not at f%d" % [label, observed, frame])


func _assert_volume(entry: Dictionary, expected: float, label: String) -> void:
    var actual: float = float(entry.get("volume", -1.0))
    if absf(actual - expected) > 0.001:
        _fail("%s volume %.3f != recovered %.3f" % [label, actual, expected])


# --------------------------------------------------------------------------- #
# 3. no duplicate playback: each recovered row fires exactly once, and the
#    de-duplicator drops an identical repeated row.
# --------------------------------------------------------------------------- #
func _check_no_duplicates() -> void:
    log.clear()
    scene.call("_on_player_attack_started", "punch")
    await create_timer(2.6).timeout
    await process_frame
    var seen: Dictionary = {}
    var total: int = 0
    for value: Variant in log:
        if not value is Dictionary:
            continue
        var entry: Dictionary = value
        var label: String = String(entry.get("label", ""))
        if label != "attack:punch" and label != "attack_voice:punch":
            continue
        total += 1
        var key := "%s|%s|%s" % [
            String(entry.get("file", "")),
            str(int(entry.get("frame", -1))),
            str(bool(entry.get("is_voice", false))),
        ]
        if seen.has(key):
            _fail("duplicate playback for %s: %s" % [key, str(entry)])
        seen[key] = true
    var expected: int = _voice_cues_for("punch").size() \
        + SfxMusicMap.attack_cues("punch").size()
    if total != expected:
        _fail("punch played %d cues, expected %d (no duplicates)" % [total, expected])

    # Explicit de-duplication: two identical non-voice rows -> one playback.
    log.clear()
    var duplicate := {
        "file": "Air_Punch_Light_1.wav", "frame": 3, "volume": 0.5,
        "unique": "", "is_voice": false,
    }
    scene.call("_play_sfx_cues", [duplicate, duplicate.duplicate(true)], "dedupe")
    await create_timer(0.3).timeout
    await process_frame
    var dup_count: int = 0
    for value: Variant in log:
        if value is Dictionary and String(Dictionary(value).get("label", "")) == "dedupe":
            dup_count += 1
    if dup_count != 1:
        _fail("identical cue rows played %d times, expected 1" % dup_count)


# --------------------------------------------------------------------------- #
# 4. volume / is_voice on a low-volume recovered cue (punch voice 0.45).
# --------------------------------------------------------------------------- #
func _check_volume() -> void:
    var cues: Array = _voice_cues_for("punch")
    if cues.is_empty():
        _fail("punch has no voice cue")
        return
    if absf(float(cues[0].get("volume", 0.0)) - 0.45) > 0.001:
        _fail("punch voice volume changed: " + str(cues[0]))


# --------------------------------------------------------------------------- #
# 5. unique: a cue tagged for another fighting-set character never plays for
#    Bruce, while the Bruce tag does.
# --------------------------------------------------------------------------- #
func _check_unique_filter() -> void:
    log.clear()
    var other := [{
        "file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav",
        "frame": 0, "volume": 0.6, "unique": "shenlo", "is_voice": true,
    }]
    var played: int = scene.call("_play_voice_cues", other, "brucelee", "unique_other")
    if played != 0 or not log.is_empty():
        _fail("a shenlo-tagged cue played for brucelee: " + str(log))

    var own := [{
        "file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav",
        "frame": 0, "volume": 0.6, "unique": "brucelee", "is_voice": true,
    }]
    played = scene.call("_play_voice_cues", own, "brucelee", "unique_own")
    if played != 1 or log.size() != 1:
        _fail("brucelee-tagged cue did not play once: " + str(log))


# --------------------------------------------------------------------------- #
# 6. start-of-action fallback when the recovered row has no frame.
# --------------------------------------------------------------------------- #
func _check_frame_absent_fallback() -> void:
    log.clear()
    var no_frame := [{
        "file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav",
        "volume": 0.6, "unique": "", "is_voice": true,
    }]
    var started: int = Time.get_ticks_msec()
    var played: int = scene.call("_play_voice_cues", no_frame, "brucelee", "fallback_voice")
    if played != 1:
        _fail("cue without frame did not use the start-of-action fallback")
        return
    var entry: Dictionary = _find(
        log, String(no_frame[0]["file"]), "fallback_voice", true, -1
    )
    if entry.is_empty():
        _fail("frame-less voice cue was not logged")
        return
    if float(entry.get("delay", -1.0)) != 0.0:
        _fail("frame-less voice cue got a non-zero delay: " + str(entry))
    if Time.get_ticks_msec() - started > 100:
        _fail("frame-less voice cue did not start immediately")

    log.clear()
    var sfx_no_frame := [{
        "file": "Air_Punch_Light_1.wav", "volume": 0.5, "unique": "",
        "is_voice": false,
    }]
    scene.call("_play_sfx_cues", sfx_no_frame, "fallback_sfx")
    await create_timer(0.2).timeout
    await process_frame
    var sfx_entry: Dictionary = _find(
        log, "Air_Punch_Light_1.wav", "fallback_sfx", false, -1
    )
    if sfx_entry.is_empty() or float(sfx_entry.get("delay", -1.0)) != 0.0:
        _fail("frame-less sfx cue did not use the start-of-action fallback: " + str(log))


# --------------------------------------------------------------------------- #
# 7. Bruce pain voice uses the set reaction row (frame / volume / unique).
# --------------------------------------------------------------------------- #
func _check_pain_voice_frame() -> void:
    log.clear()
    player.last_reaction_source_action = "impactbrutalmid"
    player.last_reaction_exit_frame = 30
    var t0: int = Time.get_ticks_msec()
    scene.call("_on_hit", computer, player, "punch", 5.0, false)
    await create_timer(0.6).timeout
    await process_frame

    var pain_cues: Array = VoiceCueTiming.voice_cues("impactbrutalmid")
    var bruce_cue: Dictionary = {}
    for value: Variant in pain_cues:
        if value is Dictionary and String(Dictionary(value).get("unique", "")) == "brucelee":
            bruce_cue = value
    if bruce_cue.is_empty():
        _fail("impactbrutalmid lost its brucelee pain cue")
        return
    var entry: Dictionary = _find(
        log, String(bruce_cue["file"]), "pain_voice:impactbrutalmid", true,
        int(bruce_cue["frame"])
    )
    if entry.is_empty():
        _fail("Bruce pain voice never played: " + str(bruce_cue))
        return
    _assert_timing(entry, int(bruce_cue["frame"]), "impactbrutalmid pain", t0)
    _assert_volume(entry, float(bruce_cue["volume"]), "impactbrutalmid pain")
    _note(entry, "impactbrutalmid", "pain_voice", true, t0)
    if String(entry.get("unique", "")) != "brucelee":
        _fail("pain voice lost its unique tag: " + str(entry))
    # No other character's take may leak into Bruce's playback.
    for value: Variant in log:
        if not value is Dictionary:
            continue
        var other: Dictionary = value
        if not bool(other.get("is_voice", false)):
            continue
        var file: String = String(other.get("file", ""))
        if file.contains("brick_davies") or file.contains("the_cheif") \
                or file.contains("johnson") or file.contains("lo_ming") \
                or file.contains("shen_lo") or file.contains("sin_fu") \
                or file.contains("small_boy") or file.contains("master_"):
            _fail("another character's pain voice played for Bruce: " + file)


func _voice_cues_for(action: String) -> Array:
    var out: Array = []
    for value: Variant in VoiceCueTiming.attack_voice_cues(action):
        if value is Dictionary and VoiceCueTiming.cue_matches(value, "brucelee"):
            out.append(value)
    return out


func _find(
        entries: Array, file: String, label: String, is_voice: bool,
        frame: int = -1
) -> Dictionary:
    for value: Variant in entries:
        if not value is Dictionary:
            continue
        var entry: Dictionary = value
        if String(entry.get("file", "")) == file \
                and String(entry.get("label", "")) == label \
                and bool(entry.get("is_voice", false)) == is_voice \
                and int(entry.get("frame", -1)) == frame:
            return entry
    return {}


func _finish() -> void:
    if not failures.is_empty():
        print("SFX_FRAME_TIMING_VALIDATION=failed")
        print(JSON.stringify({"failures": failures}))
        quit(1)
        return
    var frames_by_action: Dictionary = {}
    for action: String in ["punch", "high_kick3", "impactbrutalmid"]:
        var set_action: String = String(
            VoiceCueTiming.PORT_TO_SET_ACTION.get(action, action)
        )
        var frames: Array = []
        for value: Variant in VoiceCueTiming.voice_cues(set_action):
            if value is Dictionary:
                frames.append(int(Dictionary(value).get("frame", -1)))
        frames_by_action[action] = frames
    print("SFX_FRAME_TIMING_VALIDATION=" + JSON.stringify({
        "timing_tolerance": TIMING_TOLERANCE,
        "voice_actions": VoiceCueTiming.VOICE_ACTIONS.size(),
        "frames": frames_by_action,
        "observations": observations,
    }))
    quit(0)

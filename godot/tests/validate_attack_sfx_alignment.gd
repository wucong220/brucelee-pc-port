extends SceneTree
## Headless acceptance test for recovered non-voice attack / impact SFX timing.
##
## Proves, through the real res://scenes/main.tscn scene and a real package
## audio root, that:
##   1. the SFX tables are the recovered `sounds[]` rows (file / frame /
##      volume) and the frame rate is the native 30 fps one;
##   2. every attack cue starts at `frame / 30` seconds after the action starts
##      (wall clock and scheduled delay), never flattened to action start;
##   3. every impact/reaction cue does the same from the hit moment;
##   4. the recovered `volume` is applied to the player;
##   5. a `unique`-tagged cue only plays for the matching fighting-set
##      character;
##   6. the same cue never plays twice for one action start, and restarting an
##      action cancels its still-pending cues instead of playing them on top of
##      the new instance;
##   7. a cue without recovered frame data keeps the start-of-action fallback.
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_attack_sfx_alignment.gd \
##       -- <package_root>
##
## <package_root> must contain audio/{sfx,music,bruce_lee,commentator,menu_sfx}.

const SfxMusicMap = preload("res://scripts/sfx_music_map.gd")
const VoiceCueTiming = preload("res://scripts/voice_cue_timing.gd")

## Wall-clock tolerance for a scheduled SceneTree timer.  A flattened cue would
## be a whole frame/30 early; the smallest tested frame offset is 1 (33 ms), so
## 80 ms never hides a cue that started at action start.
const TIMING_TOLERANCE: float = 0.080
## Tolerance for the delay value recorded when the cue was scheduled.
const DELAY_EPSILON: float = 0.0005

var failures: Array[String] = []
var scene: Node = null
var player: PortFighter = null
var computer: PortFighter = null
var log: Array = []
var measured: Array = []


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
    for sub: String in [
        "audio/sfx", "audio/music", "audio/bruce_lee",
        "audio/commentator", "audio/menu_sfx",
    ]:
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
    OS.set_environment(
        "BRUCELEE_COMMENTATOR_ROOT", package_root.path_join("audio/commentator")
    )
    OS.set_environment(
        "BRUCELEE_MENU_SFX_ROOT", package_root.path_join("audio/menu_sfx")
    )

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
    # The first post-load frame carries the whole synchronous package-load delta;
    # let the clock settle so the SceneTree timers are measured cleanly.
    for _settle: int in 8:
        await process_frame

    _check_frame_rate()
    _check_recovered_rows()
    await _check_attack_matrix()
    await _check_reaction_matrix()
    await _check_unique_filter()
    await _check_dedup_and_retrigger()
    await _check_frame_absent_fallback()
    _finish()


# --------------------------------------------------------------------------- #
# 1. frame rate: the recovered `frame` is a native 30 fps source frame.
# --------------------------------------------------------------------------- #
func _check_frame_rate() -> void:
    var sfx_rate: float = float(SfxMusicMap.FRAME_RATE)
    var voice_rate: float = float(VoiceCueTiming.FRAME_RATE)
    if absf(sfx_rate - 30.0) > 0.0001:
        _fail("SFX table frame rate is %.3f, expected the native 30 fps" % sfx_rate)
    if absf(sfx_rate - voice_rate) > 0.0001:
        _fail("SFX frame rate %.3f != voice frame rate %.3f" % [sfx_rate, voice_rate])


# --------------------------------------------------------------------------- #
# 2. the data itself: the table rows are the recovered `sounds[]` rows.
#    Anchors below are copied from evidence/recovered_set_sounds.json
#    (brucelee.set) and are checked exactly.
# --------------------------------------------------------------------------- #
const RECOVERED_ANCHORS: Dictionary = {
    "punch": [
        ["Air_Punch_Light_1.wav", 4, 0.63],
        ["Shoe_Foot_L.wav", 8, 0.60],
        ["Shoe_Foot_Short_B.wav", 8, 0.60],
        ["Shoe_Foot_L.wav", 13, 0.60],
        ["Shoe_Foot_L.wav", 16, 0.50],
        ["Shoe_Foot_Short_B.wav", 34, 0.42],
        ["Shoe_Foot_R.wav", 62, 0.60],
    ],
    "attacktofloor": [
        ["Shoe_Foot_L.wav", 6, 0.80],
        ["Shoe_Foot_L.wav", 36, 0.80],
        ["Shoe_Foot_R.wav", 45, 0.80],
        ["Shoe_Foot_L.wav", 65, 0.80],
        ["Shoe_Foot_R.wav", 74, 0.60],
    ],
    "special_punch_low_hit": [
        ["Air_Punch_Heavy_1.wav", 1, 0.50],
        ["Shoe_Foot_L.wav", 3, 0.50],
        ["Punch_Body_Heavy_2.wav", 4, 0.80],
        ["Shoe_Foot_L.wav", 149, 0.50],
        ["Shoe_Foot_R.wav", 169, 0.50],
    ],
}

const REACTION_ANCHORS: Dictionary = {
    "impactfacedown": [
        ["Kick_Head_Light_1.wav", 0, 1.00],
        ["Fall_1_Normal.wav", 7, 0.27],
    ],
    "impactbrutalmid": [
        ["Punch_Body_Heavy_2.wav", 6, 0.50],
        ["Shoe_Foot_L.wav", 17, 0.50],
        ["Fall_2_Normal.wav", 20, 0.50],
    ],
}


func _check_recovered_rows() -> void:
    for action: String in RECOVERED_ANCHORS:
        var expected: Array = RECOVERED_ANCHORS[action]
        var actual: Array = SfxMusicMap.attack_cues(action)
        if actual.size() != expected.size():
            _fail("%s cue count %d != recovered %d" % [
                action, actual.size(), expected.size()
            ])
            continue
        for i: int in expected.size():
            var want: Array = expected[i]
            var got: Dictionary = actual[i]
            if String(got.get("file", "")) != String(want[0]) \
                    or int(got.get("frame", -1)) != int(want[1]) \
                    or absf(float(got.get("volume", -1.0)) - float(want[2])) > 0.001:
                _fail("%s cue %d changed: %s != %s" % [
                    action, i, str(got), str(want)
                ])
    for action: String in REACTION_ANCHORS:
        var expected: Array = REACTION_ANCHORS[action]
        var actual: Array = SfxMusicMap.action_cues(action)
        if actual.size() != expected.size():
            _fail("%s reaction cue count %d != recovered %d" % [
                action, actual.size(), expected.size()
            ])
            continue
        for i: int in expected.size():
            var want: Array = expected[i]
            var got: Dictionary = actual[i]
            if String(got.get("file", "")) != String(want[0]) \
                    or int(got.get("frame", -1)) != int(want[1]) \
                    or absf(float(got.get("volume", -1.0)) - float(want[2])) > 0.001:
                _fail("%s reaction cue %d changed: %s != %s" % [
                    action, i, str(got), str(want)
                ])


# --------------------------------------------------------------------------- #
# 3. a real attack start: every non-voice cue starts at frame/30.
# --------------------------------------------------------------------------- #
const ATTACK_MATRIX: Array[String] = [
    "punch", "low_punch3", "high_kick3", "grab1", "attacktofloor",
    "special_punch_low_hit",
]


func _check_attack_matrix() -> void:
    for action: String in ATTACK_MATRIX:
        var rows: Array = _expected_rows(SfxMusicMap.attack_cues(action))
        if rows.is_empty():
            _fail("%s has no recovered non-voice cue to time" % action)
            continue
        log.clear()
        var start_ms: int = Time.get_ticks_msec()
        scene.call("_on_player_attack_started", action)
        await create_timer(_quiet_for(rows)).timeout
        await process_frame
        _assert_action_played(action, rows, start_ms, "attack:" + action)


func _assert_action_played(
        action: String, rows: Array, start_ms: int, label: String
) -> void:
    var entries: Array = _entries_for(label, false)
    if entries.size() != rows.size():
        _fail("%s played %d non-voice cues, recovered %d: %s" % [
            action, entries.size(), rows.size(), _labels(entries)
        ])
    for row: Dictionary in rows:
        var frame: int = int(row["frame"])
        var file: String = String(row["file"])
        var found: Array = _entries_matching(entries, file, frame)
        if found.size() != 1:
            _fail("%s %s f%d played %d times, expected exactly once" % [
                action, file, frame, found.size()
            ])
            continue
        var entry: Dictionary = found[0]
        _assert_timing(entry, frame, "%s %s" % [action, file], start_ms)
        _assert_volume(entry, float(row["volume"]), "%s %s" % [action, file])
        measured.append({
            "action": action,
            "file": file,
            "frame": frame,
            "expected_seconds": float(frame) / 30.0,
            "delay": float(entry.get("delay", -1.0)),
            "observed_seconds": (
                float(int(entry["played_ms"]) - int(entry["scheduled_ms"])) / 1000.0
            ),
        })
    # A cue that starts at action start instead of frame/30 is the regression
    # this test exists for: report it explicitly even if the tolerance passes.
    for entry: Dictionary in entries:
        var frame: int = int(entry.get("frame", -1))
        if frame > 0 and float(entry.get("delay", 0.0)) <= 0.0001:
            _fail("%s cue %s f%d was flattened to action start" % [
                action, String(entry.get("file", "")), frame
            ])


# --------------------------------------------------------------------------- #
# 4. impact / reaction: cues start at frame/30 after the hit moment.
# --------------------------------------------------------------------------- #
func _check_reaction_matrix() -> void:
    for reaction: String in ["impactfacedown", "impactbrutalmid"]:
        var rows: Array = _expected_rows(SfxMusicMap.action_cues(reaction))
        if rows.is_empty():
            _fail("%s has no recovered reaction cue" % reaction)
            continue
        log.clear()
        computer.last_reaction_source_action = reaction
        computer.last_reaction_exit_frame = 90
        var start_ms: int = Time.get_ticks_msec()
        scene.call("_on_hit", player, computer, "punch", 5.0, false)
        await create_timer(_quiet_for(rows)).timeout
        await process_frame
        _assert_action_played(
            reaction, rows, start_ms, "reaction:" + reaction
        )


# --------------------------------------------------------------------------- #
# 5. volume + unique character tag.
# --------------------------------------------------------------------------- #
func _check_unique_filter() -> void:
    log.clear()
    var other := [{
        "file": "Air_Punch_Light_1.wav", "frame": 3, "volume": 0.5,
        "unique": "loming", "is_voice": false,
    }]
    scene.call("_play_sfx_cues", other, "unique_other", "brucelee")
    await create_timer(0.2).timeout
    await process_frame
    if not _entries_for("unique_other", false).is_empty():
        _fail("a loming-tagged SFX cue played for brucelee: " + str(log))

    log.clear()
    var own := [{
        "file": "Air_Punch_Light_1.wav", "frame": 3, "volume": 0.5,
        "unique": "brucelee", "is_voice": false,
    }]
    scene.call("_play_sfx_cues", own, "unique_own", "brucelee")
    await create_timer(0.2).timeout
    await process_frame
    var own_entries: Array = _entries_for("unique_own", false)
    if own_entries.size() != 1:
        _fail("brucelee-tagged SFX cue did not play once: " + str(log))
    elif float(own_entries[0].get("volume", -1.0)) != 0.5:
        _fail("unique cue lost its recovered volume: " + str(own_entries[0]))

    # The attack path passes the player's set character id, so a row tagged for
    # another character can never leak into Bruce's swing.
    log.clear()
    var foreign := [{
        "file": "Air_Punch_Light_1.wav", "frame": 3, "volume": 0.5,
        "unique": "brickdavis", "is_voice": false,
    }]
    scene.call("_play_sfx_cues", foreign, "unique_foreign", "brucelee")
    await create_timer(0.2).timeout
    await process_frame
    if not _entries_for("unique_foreign", false).is_empty():
        _fail("brickdavis-tagged SFX cue leaked into Bruce's attack")


# --------------------------------------------------------------------------- #
# 6. no duplicate playback: identical rows play once, and a restarted action
#    cancels the previous instance's still-pending cues.
# --------------------------------------------------------------------------- #
func _check_dedup_and_retrigger() -> void:
    # (a) identical rows in one lookup -> one playback.
    log.clear()
    var duplicate := {
        "file": "Air_Punch_Light_1.wav", "frame": 3, "volume": 0.5,
        "unique": "", "is_voice": false,
    }
    scene.call("_play_sfx_cues", [duplicate, duplicate.duplicate(true)], "dedupe")
    await create_timer(0.3).timeout
    await process_frame
    if _entries_for("dedupe", false).size() != 1:
        _fail("identical recovered rows played more than once: " + str(log))

    # (b) the real *_brick table repeats the same cue for several opponent
    #     variants; those repeats must not double-play.
    log.clear()
    var brick_rows: Array = _expected_rows(
        SfxMusicMap.attack_cues("special_kick_low_brick")
    )
    scene.call(
        "_play_sfx_cues", SfxMusicMap.attack_cues("special_kick_low_brick"),
        "dedupe_brick", "brickdavis"
    )
    await create_timer(_quiet_for(brick_rows)).timeout
    await process_frame
    var brick_entries: Array = _entries_for("dedupe_brick", false)
    if brick_entries.size() != brick_rows.size():
        _fail("repeated *_brick rows played %d times, %d distinct cues: %s" % [
            brick_entries.size(), brick_rows.size(), _labels(brick_entries)
        ])

    # (c) restarting punch 0.30 s in must cancel the first instance's pending
    #     f16 / f34 / f62 cues, otherwise the old swing plays over the new one.
    log.clear()
    var t0: int = Time.get_ticks_msec()
    scene.call("_on_player_attack_started", "punch")
    await create_timer(0.30).timeout
    var t1: int = Time.get_ticks_msec()
    scene.call("_on_player_attack_started", "punch")
    var rows: Array = _expected_rows(SfxMusicMap.attack_cues("punch"))
    await create_timer(_quiet_for(rows)).timeout
    await process_frame
    var elapsed: float = float(t1 - t0) / 1000.0
    var stale: Array = []
    var first_instance: int = 0
    var second_instance: int = 0
    for entry: Dictionary in _entries_for("attack:punch", false):
        if int(entry.get("scheduled_ms", 0)) < t1 - 20:
            first_instance += 1
            if float(int(entry.get("frame", 0))) / 30.0 > elapsed + 0.05:
                stale.append(entry)
        else:
            second_instance += 1
    if not stale.is_empty():
        _fail("restarting punch did not cancel %d stale cue(s): %s" % [
            stale.size(), str(stale)
        ])
    if second_instance != rows.size():
        _fail("second punch played %d cues, recovered %d" % [
            second_instance, rows.size()
        ])
    if first_instance < 1:
        _fail("first punch played no cue at all")


# --------------------------------------------------------------------------- #
# 7. start-of-action fallback when the recovered row carries no frame.
# --------------------------------------------------------------------------- #
func _check_frame_absent_fallback() -> void:
    log.clear()
    var no_frame := [{
        "file": "Air_Punch_Light_1.wav", "volume": 0.5, "unique": "",
        "is_voice": false,
    }]
    var started: int = Time.get_ticks_msec()
    scene.call("_play_sfx_cues", no_frame, "fallback_sfx")
    await create_timer(0.2).timeout
    await process_frame
    var entries: Array = _entries_for("fallback_sfx", false)
    if entries.size() != 1:
        _fail("frame-less cue did not use the start-of-action fallback: " + str(log))
        return
    var entry: Dictionary = entries[0]
    if float(entry.get("delay", -1.0)) != 0.0:
        _fail("frame-less cue got a non-zero delay: " + str(entry))
    if int(entry["played_ms"]) - started > 100:
        _fail("frame-less cue did not start immediately: " + str(entry))


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
func _quiet_for(rows: Array) -> float:
    var max_frame: int = 0
    for row: Dictionary in rows:
        max_frame = maxi(max_frame, int(row.get("frame", 0)))
    return float(max_frame) / 30.0 + 0.30


## Collapse identical rows exactly like the runtime does, keeping the recovered
## order, so the expectation is "one playback per distinct row".
func _expected_rows(rows: Array) -> Array:
    var out: Array = []
    var seen: Dictionary = {}
    for value: Variant in rows:
        if not value is Dictionary:
            continue
        var row: Dictionary = value
        if bool(row.get("is_voice", false)):
            continue
        var key := "%s|%s|%.3f|%s" % [
            String(row.get("file", "")), str(row.get("frame", null)),
            float(row.get("volume", 1.0)), String(row.get("unique", "")),
        ]
        if seen.has(key):
            continue
        seen[key] = true
        out.append(row)
    return out


func _entries_for(label: String, is_voice: bool) -> Array:
    var out: Array = []
    for value: Variant in log:
        if not value is Dictionary:
            continue
        var entry: Dictionary = value
        if String(entry.get("label", "")) != label:
            continue
        if bool(entry.get("is_voice", false)) != is_voice:
            continue
        out.append(entry)
    return out


func _entries_matching(entries: Array, file: String, frame: int) -> Array:
    var out: Array = []
    for value: Variant in entries:
        if not value is Dictionary:
            continue
        var entry: Dictionary = value
        if String(entry.get("file", "")) == file \
                and int(entry.get("frame", -1)) == frame:
            out.append(entry)
    return out


func _labels(entries: Array) -> Array:
    var out: Array = []
    for value: Variant in entries:
        if value is Dictionary:
            out.append("%s f%d" % [
                String(Dictionary(value).get("file", "")),
                int(Dictionary(value).get("frame", -1)),
            ])
    return out


func _assert_timing(
        entry: Dictionary, frame: int, label: String, start_ms: int = -1
) -> void:
    var expected: float = float(frame) / float(SfxMusicMap.FRAME_RATE)
    var delay: float = float(entry.get("delay", -1.0))
    if absf(delay - expected) > DELAY_EPSILON:
        _fail("%s scheduled delay %.4f != frame/30 %.4f (f%d)" % [
            label, delay, expected, frame
        ])
    var observed: float = (
        float(int(entry["played_ms"]) - int(entry["scheduled_ms"])) / 1000.0
    )
    if absf(observed - expected) > TIMING_TOLERANCE:
        _fail("%s started %.3fs after scheduling, expected %.3fs (f%d)" % [
            label, observed, expected, frame
        ])
    if start_ms >= 0:
        var wall: float = float(int(entry["played_ms"]) - start_ms) / 1000.0
        if absf(wall - expected) > TIMING_TOLERANCE + 0.030:
            _fail("%s wall clock %.3fs != frame/30 %.3fs (f%d)" % [
                label, wall, expected, frame
            ])
    if frame > 0 and observed < expected * 0.5:
        _fail("%s played at action start (%.3fs) instead of f%d" % [
            label, observed, frame
        ])


func _assert_volume(entry: Dictionary, expected: float, label: String) -> void:
    var actual: float = float(entry.get("volume", -1.0))
    if absf(actual - expected) > 0.001:
        _fail("%s volume %.3f != recovered %.3f" % [label, actual, expected])


func _finish() -> void:
    if not failures.is_empty():
        print("ATTACK_SFX_ALIGNMENT=failed")
        print(JSON.stringify({"failures": failures}))
        quit(1)
        return
    var frames_by_action: Dictionary = {}
    for action: String in ATTACK_MATRIX:
        var frames: Array = []
        for value: Variant in SfxMusicMap.attack_cues(action):
            if value is Dictionary and not bool(Dictionary(value).get("is_voice", false)):
                frames.append(int(Dictionary(value).get("frame", -1)))
        frames_by_action[action] = frames
    print("ATTACK_SFX_ALIGNMENT=" + JSON.stringify({
        "frame_rate": SfxMusicMap.FRAME_RATE,
        "timing_tolerance": TIMING_TOLERANCE,
        "attack_actions_checked": ATTACK_MATRIX.size(),
        "reaction_actions_checked": REACTION_ANCHORS.size(),
        "measured_cues": measured.size(),
        "frames": frames_by_action,
        "measured": measured,
    }))
    quit(0)

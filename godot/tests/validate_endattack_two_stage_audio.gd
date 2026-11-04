extends SceneTree
## Headless acceptance test for the recovered TWO-STAGE endattack audio.
##
## An endattack finisher carries two recovered `sounds[]` stages:
##   1. the attacker's own action -- `endattack1/2` for Bruce, `endattack <set>`
##      for an opponent -- with its impact cues plus (Bruce) the two slow-scream
##      takes, the second of them at f206, i.e. half a clip after the "main" cue;
##   2. the VICTIM's `endattackcomp` action, which has its own impact rows at
##      that clip's frames and (karate comp only) one pain take per fighting-set
##      character at f20.
##
## Through the real `res://scenes/main.tscn`, a real package audio root and real
## candidate GLBs this test proves:
##   * the tables are the recovered rows (file / frame / volume / unique) for
##     every endattackcomp action and for the attacker actions;
##   * every cue of both stages starts at `frame / 30` s counted from ITS stage
##     start (victim stage: from `begin_endattack_victim`), never at t = 0, so a
##     build that flattens the second stage onto the action start fails;
##   * the f206 Bruce scream and the f20 victim pain take are really played, so
##     an "only the main cue" build cannot pass;
##   * a clip with no recovered action (kungfu has no endattackcomp action at
##     all, or an unknown clip) plays nothing and is reported in `_audio_skips`
##     instead of borrowing another action's cue;
##   * repeated rows play once, and a restarted victim stage cancels the
##     previous instance's pending impact cues AND voice (no stale cues).
##
## Usage:
##   godot --headless --path <project> \
##       --script res://tests/validate_endattack_two_stage_audio.gd \
##       -- <package_root> <player_glb> <opponent_glb|-> <opponent_attack_config>
##
## <package_root> must contain audio/{sfx,music,bruce_lee,commentator,menu_sfx}.

const SfxMusicMap = preload("res://scripts/sfx_music_map.gd")
const VoiceCueTiming = preload("res://scripts/voice_cue_timing.gd")

## Wall-clock tolerance for a scheduled SceneTree timer (one 30 fps frame is
## 33 ms; a flattened f20 victim cue would be 667 ms early).
const TIMING_TOLERANCE: float = 0.080
## Tolerance for the delay value recorded when the cue was scheduled.
const DELAY_EPSILON: float = 0.0005

## Opponent attack config -> the recovered finisher this run exercises.
## `source_action` is that config's own endattack `source_action` (the row group
## in the recovered set); `comp_clip`/`comp_action` are what the player victim
## resolves from the brucelee set's native links for that attacker family.
const CASES: Dictionary = {
    "res://data/attack_config_ken.json": {
        "attack_slot": "endattack",
        "source_action": "endattack ken",
        "comp_clip": "all_end_attack_01_forset02",
        "comp_action": "endattackcompkarate 1",
        "comp_voice": true,
    },
    "res://data/fighting_set_m03_mapped_attacks.json": {
        "attack_slot": "endattack_brick",
        "source_action": "endattack brick",
        "comp_clip": "all_end_attack_01_forset03",
        "comp_action": "endattackcompthai 1",
        "comp_voice": false,
    },
    "res://data/attack_config_loming.json": {
        "attack_slot": "endattack",
        "source_action": "endattack loming",
        # kungfu has no endattackcomp action at all: the victim stage must fail
        # closed instead of playing another set's rows.
        "comp_clip": "",
        "comp_action": "",
        "comp_voice": false,
    },
}

## Recovered non-voice `sounds[]` rows (brucelee.set) of the victim stage, in
## set order: [file, frame, volume].  Lower-case file names; the runtime table
## uses the archive's capitalisation, which the checks compare case-insensitively.
const COMP_SFX_ANCHORS: Dictionary = {
    "endattackcomp1": [
        ["kick_head_heavy_1.wav", 64, 0.5],
        ["fall_2_normal.wav", 191, 0.6],
        ["punch_head_heavy_1.wav", 248, 0.5],
        ["fall_3_normal.wav", 333, 0.5],
    ],
    "endattackcomp2": [
        ["punch_head_light_2.wav", 9, 0.8],
        ["punch_body_heavy_2.wav", 63, 0.5],
        ["punch_body_heavy_2.wav", 75, 0.5],
        ["punch_body_heavy_2.wav", 85, 0.5],
        ["punch_body_heavy_1.wav", 97, 0.5],
        ["shoe_foot_l.wav", 191, 0.9],
        ["fall_3_normal.wav", 230, 0.5],
    ],
    "endattackcompkarate 1": [
        ["kick_body_heavy_2.wav", 20, 0.6],
        ["shoe_foot_l.wav", 32, 0.8],
        ["punch_head_heavy_1.wav", 58, 0.65],
        ["shoe_foot_r.wav", 91, 0.6],
        ["fall_2_normal.wav", 105, 0.7],
    ],
    "endattackcompkarate 2": [
        ["punch_head_heavy_2.wav", 59, 0.7],
        ["shoe_foot_short_b.wav", 96, 0.5],
        ["fall_3_normal.wav", 142, 0.6],
        ["shoe_foot_l.wav", 148, 1.0],
    ],
    "endattackcompthai 1": [
        ["shoe_foot_r.wav", 19, 0.5],
        ["punch_head_heavy_2.wav", 42, 0.45],
        ["shoe_foot_r.wav", 58, 0.5],
        ["fall_3_normal.wav", 73, 0.5],
    ],
    "endattackcompthai 2": [
        ["punch_head_heavy_1.wav", 3, 0.5],
        ["kick_body_heavy_2.wav", 19, 0.85],
        ["shoe_foot_l.wav", 35, 0.5],
        ["shoe_foot_r.wav", 41, 0.5],
        ["shoe_foot_l.wav", 48, 0.5],
        ["shoe_foot_r.wav", 55, 0.35],
        ["shoe_foot_l.wav", 66, 0.6],
        ["shoe_foot_l.wav", 84, 0.5],
        ["kick_body_light_2.wav", 85, 0.5],
        ["shoe_foot_r.wav", 89, 0.5],
        ["punch_head_heavy_1.wav", 91, 0.6],
        ["fall_4_normal.wav", 118, 0.65],
    ],
}

## Recovered voice rows of the victim stage: [file, frame, volume, unique].
## Only the karate comp carries pain takes; every other comp action has none,
## so the victim voice must stay silent there (fail closed).
const COMP_VOICE_ANCHORS: Dictionary = {
    "endattackcomp1": [],
    "endattackcomp2": [],
    "endattackcompkarate 1": [
        ["sounds/voices/brick_davies/light_pain/hurt__light_male_ls_g_hurtgrunt02_brick_davies.wav", 20, 0.85, "brickdavis"],
        ["sounds/voices/bruce_lee/pain_light/pain_light_1_bl.wav", 20, 0.85, "brucelee"],
        ["sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt05_the_cheif.wav", 20, 0.85, "chief"],
        ["sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtpunch02_johnson.wav", 20, 0.85, "johnson"],
        ["sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtgrunt04_ken.wav", 20, 0.85, "kengodall"],
        ["sounds/voices/lo_ming/light_pain/hurt_light_male_ls_l_hurtgrunt08_lo_ming.wav", 20, 0.85, "loming"],
        ["sounds/voices/shen_lo/light_pain/male_ls_j_hurtgrunt04_shen_lo.wav", 20, 0.85, "shenlo"],
        ["sounds/voices/sin_fu/light_pain/hurt_light_male_ls_f_sin_fu.wav", 20, 0.85, "sinfu"],
        ["sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtgrunt06_small_boy.wav", 20, 0.85, "smallboy"],
        ["sounds/voices/the_master/pain/master_pain_lt_2.wav", 20, 0.7, "themaster"],
    ],
    "endattackcompkarate 2": [],
    "endattackcompthai 1": [],
    "endattackcompthai 2": [],
}

## Recovered attacker-stage rows: [file, frame, volume].  `endattack1/2` are the
## player's own finishers; the `<slot> <set character>` groups are the opponent
## finishers, selected through the opponent config's `source_action`.
const ATTACK_SFX_ANCHORS: Dictionary = {
    "endattack1": [
        ["shoe_foot_l.wav", 52, 0.5],
        ["air_kick_heavy_1.wav", 53, 0.5],
        ["shoe_foot_l.wav", 104, 0.5],
        ["shoe_foot_short_b.wav", 122, 0.5],
        ["shoe_foot_l.wav", 180, 0.5],
        ["air_punch_heavy_1.wav", 240, 0.49],
        ["shoe_foot_l.wav", 351, 0.5],
        ["shoe_foot_r.wav", 363, 0.5],
    ],
    "endattack2": [
        ["air_punch_light_1.wav", 10, 0.5],
        ["shoe_foot_l.wav", 43, 0.5],
        ["air_kick_heavy_1.wav", 61, 0.5],
        ["air_kick_heavy_1.wav", 73, 0.5],
        ["air_kick_heavy_1.wav", 83, 0.5],
        ["air_kick_heavy_1.wav", 96, 0.5],
    ],
    "endattack brick": [
        ["clothing_3.wav", 16, 0.65],
        ["air_kick_light_1.wav", 40, 0.6],
        ["shoe_foot_l.wav", 63, 0.5],
        ["shoe_foot_r.wav", 68, 0.5],
        ["shoe_foot_l.wav", 82, 0.5],
    ],
    "endattack ken": [
        ["shoe_foot_l.wav", 8, 0.5],
        ["clothing_4.wav", 18, 0.7],
        ["shoe_foot_l.wav", 35, 0.5],
        ["shoe_foot_r.wav", 44, 0.5],
        ["air_punch_heavy_1.wav", 54, 0.5],
        ["shoe_foot_l.wav", 68, 0.5],
        ["shoe_foot_r.wav", 101, 0.5],
        ["shoe_foot_r.wav", 114, 0.5],
        ["shoe_foot_r.wav", 127, 0.5],
    ],
    "endattack loming": [
        ["shoe_foot_l.wav", 2, 0.35],
        ["shoe_foot_r.wav", 8, 0.35],
        ["clothing_3.wav", 14, 1.0],
    ],
}

## Recovered voice rows of the attacker stage: [file, frame, volume].
const ATTACK_VOICE_ANCHORS: Dictionary = {
    "endattack1": [
        ["sounds/voices/bruce_lee/special/m01_sp_kick_high.wav", 44, 0.5],
        ["sounds/voices/bruce_lee/special/m01_end_attack_01.avi _bl_slow_scream_a.wav", 206, 0.5],
    ],
    "endattack2": [
        ["sounds/voices/bruce_lee/special/m01_end_attack_02.avi _bl_slow_scream_b.wav", 11, 0.5],
    ],
}

var failures: Array[String] = []
var skipped: Array[String] = []
var case_name: String = ""
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
    if args.size() != 4:
        _fail("expected: <package_root> <player_glb> <opponent_glb|-> <opponent_attack_config>")
        _finish()
        return
    var package_root: String = args[0].replace("\\", "/").trim_suffix("/")
    var player_glb: String = args[1]
    var opponent_glb: String = args[2]
    if opponent_glb == "-":
        opponent_glb = ""
    var config: String = args[3]
    case_name = config.get_file().get_basename().trim_prefix("attack_config_")
    if not CASES.has(config):
        _fail("unknown opponent attack config: " + config)
        _finish()
        return
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
    OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", config)
    OS.set_environment("BRUCELEE_PLAYER_GLB", player_glb)
    OS.set_environment("BRUCELEE_OPPONENT_GLB", opponent_glb)
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
    if not player.candidate_loaded:
        _fail("player candidate did not load: " + player.candidate_load_error)
        _finish()
        return
    for _settle: int in 8:
        await process_frame

    _check_data(config)
    await _check_attack_stage_one("endattack1")
    await _check_attack_stage_one("endattack2")
    await _check_opponent_stage_one(config)
    await _check_victim_stage(config)
    await _check_opponent_victim_stage()
    await _check_restart_cancels_stale(config)
    await _check_duplicate_rows()
    await _check_unknown_clip_skip()
    _finish()


# --------------------------------------------------------------------------- #
# 1. data: the recovered rows, the clip -> action map, and the fail-closed edges
# --------------------------------------------------------------------------- #
func _check_data(config: String) -> void:
    if absf(float(SfxMusicMap.FRAME_RATE) - 30.0) > 0.0001:
        _fail("SFX frame rate is not the native 30 fps")
    if absf(float(SfxMusicMap.FRAME_RATE) - float(VoiceCueTiming.FRAME_RATE)) > 0.0001:
        _fail("SFX and voice frame rates differ")

    for action: String in COMP_SFX_ANCHORS:
        _check_row_anchors(
            SfxMusicMap.action_cues(action), COMP_SFX_ANCHORS[action],
            "victim stage " + action
        )
    for action: String in COMP_VOICE_ANCHORS:
        _check_row_anchors(
            VoiceCueTiming.voice_cues(action), COMP_VOICE_ANCHORS[action],
            "victim voice " + action, true
        )

    # Every mapped clip resolves to a recovered action whose rows stay inside
    # the clip's recovered 30 fps duration.
    var map: Dictionary = SfxMusicMap.ENDATTACK_COMP_CLIP_ACTIONS
    if map.size() != 6:
        _fail("endattackcomp clip map has %d entries, expected 6" % map.size())
    for clip: String in map:
        var action: String = String(map[clip])
        if not COMP_SFX_ANCHORS.has(action) or not COMP_VOICE_ANCHORS.has(action):
            _fail("clip %s maps to untested action %s" % [clip, action])
            continue
        var frames: int = int(PortFighter.VICTIM_CLIP_FRAMES.get(clip, -1))
        if frames < 0:
            _fail("clip %s has no recovered frame count" % clip)
            continue
        var max_frame: int = 0
        for row: Dictionary in SfxMusicMap.action_cues(action):
            max_frame = maxi(max_frame, int(row.get("frame", 0)))
        for row: Dictionary in VoiceCueTiming.voice_cues(action):
            max_frame = maxi(max_frame, int(row.get("frame", 0)))
        if max_frame > frames:
            _fail("clip %s: cue f%d is beyond its %d recovered frames" % [
                clip, max_frame, frames
            ])
        if SfxMusicMap.endattack_comp_action(clip) != action:
            _fail("endattack_comp_action(%s) != %s" % [clip, action])

    # Fail-closed edges: kungfu has no endattackcomp action and an empty clip
    # must never resolve to a row group.
    if SfxMusicMap.endattack_comp_action("all_end_attack_01_forset04") != "":
        _fail("kungfu victim clip resolved to a cue action")
    if SfxMusicMap.endattack_comp_action("") != "":
        _fail("empty victim clip resolved to a cue action")
    if not SfxMusicMap.action_cues("").is_empty():
        _fail("empty action name returned rows")

    # Attacker stage rows (player and the per-config opponent finisher).
    for action: String in ATTACK_SFX_ANCHORS:
        _check_row_anchors(
            SfxMusicMap.action_cues(action), ATTACK_SFX_ANCHORS[action],
            "attacker stage " + action
        )
    for action: String in ATTACK_VOICE_ANCHORS:
        _check_row_anchors(
            VoiceCueTiming.voice_cues(action), ATTACK_VOICE_ANCHORS[action],
            "attacker voice " + action
        )
    # The player's finisher has two voice stages (f44 and the late f206 scream).
    var endattack1_voice: Array = VoiceCueTiming.attack_voice_cues("endattack1")
    if endattack1_voice.size() != 2:
        _fail("endattack1 has %d voice cues, expected 2" % endattack1_voice.size())
    else:
        var last: Dictionary = endattack1_voice[endattack1_voice.size() - 1]
        if int(last.get("frame", -1)) != 206:
            _fail("endattack1 second voice is f%d, expected f206" % int(last.get("frame", -1)))

    # This run's opponent finisher must resolve to the recovered row group.
    var case: Dictionary = CASES[config]
    var source_action: String = String(case["source_action"])
    if SfxMusicMap.action_cues(source_action).is_empty():
        _fail("opponent finisher %s has no recovered row group" % source_action)
    var comp_clip: String = String(case["comp_clip"])
    if not comp_clip.is_empty():
        if SfxMusicMap.endattack_comp_action(comp_clip) != String(case["comp_action"]):
            _fail("%s does not resolve to %s" % [
                comp_clip, String(case["comp_action"])
            ])


func _check_row_anchors(
        actual: Array, expected: Array, context: String, with_unique: bool = false
) -> void:
    if actual.size() != expected.size():
        _fail("%s cue count %d != recovered %d" % [
            context, actual.size(), expected.size()
        ])
        return
    for index: int in expected.size():
        var want: Array = expected[index]
        var got: Dictionary = actual[index]
        var same: bool = (
            String(got.get("file", "")).to_lower() == String(want[0]).to_lower()
            and int(got.get("frame", -1)) == int(want[1])
            and absf(float(got.get("volume", -1.0)) - float(want[2])) <= 0.001
        )
        if with_unique and String(got.get("unique", "")) != String(want[3]):
            same = false
        if not same:
            _fail("%s cue %d %s != recovered %s" % [
                context, index, str(got), str(want)
            ])


# --------------------------------------------------------------------------- #
# 2. attacker stage: every cue starts at frame/30 from the action start
# --------------------------------------------------------------------------- #
func _check_attack_stage_one(action: String) -> void:
    var sfx_rows: Array = _distinct(SfxMusicMap.attack_cues(action))
    var voice_rows: Array = VoiceCueTiming.attack_voice_cues(action)
    if sfx_rows.is_empty() or voice_rows.is_empty():
        _fail("%s has no recovered two-stage cues" % action)
        return
    log.clear()
    var start_ms: int = Time.get_ticks_msec()
    scene.call("_on_player_attack_started", action)
    await create_timer(_quiet_for(sfx_rows + voice_rows)).timeout
    await process_frame
    _check_playback(action, "attack:" + action, false, sfx_rows, start_ms)
    _check_playback(action, "attack_voice:" + action, true, voice_rows, start_ms)
    if action == "endattack1":
        # The late slow-scream must really play late: this is the "second stage"
        # of the attacker clip, not the main cue repeated at t=0.
        var late: Array = _entries_matching(
            _entries_for("attack_voice:endattack1", true),
            "sounds/voices/bruce_lee/special/m01_end_attack_01.avi _bl_slow_scream_a.wav",
            206
        )
        if late.size() != 1:
            _fail("endattack1 f206 scream played %d times" % late.size())
        elif _observed_seconds(late[0]) < 6.0:
            _fail("endattack1 f206 scream started too early: %s" % str(late[0]))


# --------------------------------------------------------------------------- #
# 3. opponent attacker stage: the config's own source_action row group
# --------------------------------------------------------------------------- #
func _check_opponent_stage_one(config: String) -> void:
    var case: Dictionary = CASES[config]
    var slot: String = String(case["attack_slot"])
    var source_action: String = String(case["source_action"])
    if not bool(SfxMusicMap.ENDATTACK_ATTACK_SLOTS.has(slot)):
        _fail("%s is not a recovered endattack slot" % slot)
        return
    var rows: Array = _distinct(SfxMusicMap.action_cues(source_action))
    if rows.is_empty():
        _fail("%s has no recovered rows" % source_action)
        return
    log.clear()
    var start_ms: int = Time.get_ticks_msec()
    scene.call("_on_opponent_attack_started", slot)
    await create_timer(_quiet_for(rows)).timeout
    await process_frame
    _check_playback(slot, "opponent_attack:" + slot, false, rows, start_ms)
    # The opponent's own voice is the opt-in overlay's job; the shared SFX path
    # must not play the set table's Bruce takes for another character.
    if not _entries_for("opponent_attack:" + slot, true).is_empty():
        _fail("opponent endattack stage leaked a voice cue")


# --------------------------------------------------------------------------- #
# 4. victim stage: the endattackcomp rows start at the victim clip's frames
# --------------------------------------------------------------------------- #
func _check_victim_stage(config: String) -> void:
    var case: Dictionary = CASES[config]
    var comp_action: String = String(case["comp_action"])
    _prepare_victim(player)
    log.clear()
    var start_ms: int = Time.get_ticks_msec()
    var began: bool = player.begin_endattack_victim("endattack")
    if comp_action.is_empty():
        if began:
            _fail("kungfu finisher started a victim stage with no recovered rows")
        await create_timer(0.4).timeout
        await process_frame
        if not _entries_with_prefix("endattack_comp:").is_empty():
            _fail("victim stage played cues although no recovered action exists")
        return
    if not began:
        _fail("victim stage did not start (clip %s)" % String(case["comp_clip"]))
        return
    var clip: String = player.current_victim_animation()
    if clip != String(case["comp_clip"]):
        _fail("victim clip %s != recovered %s" % [clip, String(case["comp_clip"])])
    var sfx_rows: Array = _distinct(SfxMusicMap.action_cues(comp_action))
    var voice_rows: Array = _voice_rows_for(
        VoiceCueTiming.voice_cues(comp_action), "brucelee"
    )
    if bool(case["comp_voice"]) != (not voice_rows.is_empty()):
        _fail("%s victim voice expectation mismatch" % comp_action)
    await create_timer(_quiet_for(sfx_rows + voice_rows)).timeout
    await process_frame
    _check_playback(
        "victim " + case_name, "endattack_comp:endattackcomp1", false,
        sfx_rows, start_ms
    )
    _check_playback(
        "victim " + case_name, "endattack_comp:endattackcomp1", true,
        voice_rows, start_ms
    )
    # Every victim cue is a later stage: none may be flattened to t=0.
    for entry: Dictionary in _entries_for("endattack_comp:endattackcomp1", false):
        if int(entry.get("frame", -1)) > 0 and float(entry.get("delay", 0.0)) <= 0.0001:
            _fail("victim cue %s f%d was flattened to the stage start" % [
                String(entry.get("file", "")), int(entry.get("frame", -1))
            ])


func _check_opponent_victim_stage() -> void:
    ## Other direction: the opponent is consumed by the player's finisher.  Its
    ## clip is the candidate's universal endattackcomp clip; the rows still come
    ## from the recovered per-family action, and the opponent voice root is not
    ## this path's to read.
    if not computer.candidate_loaded:
        skipped.append("opponent victim stage: opponent candidate not loaded")
        return
    _prepare_victim(computer)
    log.clear()
    var start_ms: int = Time.get_ticks_msec()
    if not computer.begin_endattack_victim("endattack"):
        _fail("opponent victim stage did not start")
        return
    var clip: String = computer.current_victim_animation()
    var action: String = SfxMusicMap.endattack_comp_action(clip)
    if action.is_empty():
        _fail("opponent victim clip %s has no recovered action" % clip)
        return
    var rows: Array = _distinct(SfxMusicMap.action_cues(action))
    await create_timer(_quiet_for(rows)).timeout
    await process_frame
    _check_playback("opponent victim", "endattack_comp:endattackcomp1", false, rows, start_ms)
    if not _entries_for("endattack_comp:endattackcomp1", true).is_empty():
        _fail("opponent victim stage used the player voice root")


# --------------------------------------------------------------------------- #
# 5. no stale cues: a restarted victim stage drops its pending SFX AND voice
# --------------------------------------------------------------------------- #
func _check_restart_cancels_stale(config: String) -> void:
    var case: Dictionary = CASES[config]
    var comp_action: String = String(case["comp_action"])
    if comp_action.is_empty():
        skipped.append("stale cancellation: kungfu has no victim stage")
        return
    var sfx_rows: Array = _distinct(SfxMusicMap.action_cues(comp_action))
    var voice_rows: Array = _voice_rows_for(
        VoiceCueTiming.voice_cues(comp_action), "brucelee"
    )
    _prepare_victim(player)
    log.clear()
    var t0: int = Time.get_ticks_msec()
    if not player.begin_endattack_victim("endattack"):
        _fail("restart check: first victim stage did not start")
        return
    await create_timer(0.12).timeout
    var t1: int = Time.get_ticks_msec()
    var elapsed: float = float(t1 - t0) / 1000.0
    _prepare_victim(player)
    if not player.begin_endattack_victim("endattack"):
        _fail("restart check: second victim stage did not start")
        return
    await create_timer(_quiet_for(sfx_rows + voice_rows)).timeout
    await process_frame
    var stale: Array = []
    var second_sfx: int = 0
    var second_voice: int = 0
    for value: Variant in log:
        if not value is Dictionary:
            continue
        var entry: Dictionary = value
        if String(entry.get("label", "")) != "endattack_comp:endattackcomp1":
            continue
        var first_instance: bool = int(entry.get("scheduled_ms", 0)) < t1 - 20
        var frame_time: float = float(int(entry.get("frame", -1))) / 30.0
        if first_instance and frame_time > elapsed + 0.05:
            stale.append(entry)
        elif not first_instance:
            if bool(entry.get("is_voice", false)):
                second_voice += 1
            else:
                second_sfx += 1
    if not stale.is_empty():
        _fail("restarting the victim stage did not cancel %d stale cue(s): %s" % [
            stale.size(), str(stale)
        ])
    if second_sfx != sfx_rows.size():
        _fail("second victim stage played %d impact cues, recovered %d" % [
            second_sfx, sfx_rows.size()
        ])
    if second_voice != voice_rows.size():
        _fail("second victim stage played %d voice cues, recovered %d" % [
            second_voice, voice_rows.size()
        ])


# --------------------------------------------------------------------------- #
# 6. no duplicate playback: a repeated row starts once
# --------------------------------------------------------------------------- #
func _check_duplicate_rows() -> void:
    var rows: Array = SfxMusicMap.action_cues("endattackcompkarate 1").duplicate(true)
    if rows.is_empty():
        _fail("endattackcompkarate 1 has no rows to dedupe")
        return
    rows.append(Dictionary(rows[0]).duplicate(true))
    var distinct: Array = _distinct(rows)
    log.clear()
    scene.call("_play_sfx_cues", rows, "dedupe_comp", "brucelee", "dedupe_comp")
    await create_timer(_quiet_for(rows)).timeout
    await process_frame
    var entries: Array = _entries_for("dedupe_comp", false)
    if entries.size() != distinct.size():
        _fail("repeated victim row played %d times, %d distinct cues: %s" % [
            entries.size(), distinct.size(), _labels(entries)
        ])


# --------------------------------------------------------------------------- #
# 7. fail closed: a clip with no recovered action plays nothing and is reported
# --------------------------------------------------------------------------- #
func _check_unknown_clip_skip() -> void:
    var selected: Dictionary = player.get("_victim_selected_animation")
    var had: bool = selected.has("endattackcomp1")
    var previous: Variant = selected.get("endattackcomp1", null)
    # The kungfu (forset04) victim clip exists in the archive but has no
    # endattackcomp action; the stage must not borrow another set's rows.
    selected["endattackcomp1"] = "all_end_attack_01_forset04"
    player.state = "endattackcomp1"
    log.clear()
    scene.call("_play_endattack_comp_audio", player, "endattackcomp1")
    await create_timer(0.3).timeout
    await process_frame
    if not _entries_for("endattack_comp:endattackcomp1", false).is_empty():
        _fail("unknown victim clip played impact cues")
    var found: bool = false
    var skips: Array = scene.get("_audio_skips")
    for value: Variant in skips:
        if not value is Dictionary:
            continue
        var skip: Dictionary = value
        if (String(skip.get("label", "")) == "endattack_comp:endattackcomp1"
                and String(skip.get("reason", "")) == "no recovered action for clip"):
            found = true
    if not found:
        _fail("unknown victim clip was not reported as a fail-closed skip")
    if had:
        selected["endattackcomp1"] = previous
    else:
        selected.erase("endattackcomp1")
    player.state = "idle"
    player.state_time = 0.0


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
func _prepare_victim(victim: PortFighter) -> void:
    victim.state = "grabbed1"
    victim.state_time = 0.0
    victim.attack_kind = ""


func _check_playback(
        context: String, label: String, is_voice: bool, rows: Array, start_ms: int
) -> void:
    var entries: Array = _entries_for(label, is_voice)
    if entries.size() != rows.size():
        _fail("%s: played %d cues, recovered %d: %s" % [
            context, entries.size(), rows.size(), _labels(entries)
        ])
    for value: Variant in rows:
        if not value is Dictionary:
            continue
        var row: Dictionary = value
        var frame: int = int(row.get("frame", -1))
        var file: String = String(row.get("file", ""))
        var found: Array = _entries_matching(entries, file, frame)
        if found.size() != 1:
            _fail("%s %s f%d played %d times, expected exactly once" % [
                context, file, frame, found.size()
            ])
            continue
        var entry: Dictionary = found[0]
        _assert_timing(entry, frame, "%s %s" % [context, file], start_ms)
        _assert_volume(entry, float(row.get("volume", -1.0)), "%s %s" % [
            context, file
        ])
        measured.append({
            "case": case_name,
            "stage": context,
            "label": label,
            "voice": is_voice,
            "file": file,
            "frame": frame,
            "expected_seconds": float(frame) / 30.0,
            "delay": float(entry.get("delay", -1.0)),
            "observed_seconds": _observed_seconds(entry),
        })


func _observed_seconds(entry: Dictionary) -> float:
    return float(int(entry.get("played_ms", 0)) - int(entry.get("scheduled_ms", 0))) / 1000.0


func _quiet_for(rows: Array) -> float:
    var max_frame: int = 0
    for value: Variant in rows:
        if not value is Dictionary:
            continue
        var frame_value: Variant = Dictionary(value).get("frame", null)
        if frame_value != null:
            max_frame = maxi(max_frame, int(frame_value))
    return float(max_frame) / float(SfxMusicMap.FRAME_RATE) + 0.30


func _distinct(rows: Array) -> Array:
    var out: Array = []
    var seen: Dictionary = {}
    for value: Variant in rows:
        if not value is Dictionary:
            continue
        var row: Dictionary = value
        if bool(row.get("is_voice", false)):
            continue
        var key: String = "%s|%s|%.3f|%s" % [
            String(row.get("file", "")), str(row.get("frame", null)),
            float(row.get("volume", 1.0)), String(row.get("unique", "")),
        ]
        if seen.has(key):
            continue
        seen[key] = true
        out.append(row)
    return out


func _voice_rows_for(rows: Array, character_id: String) -> Array:
    var out: Array = []
    for value: Variant in rows:
        if not value is Dictionary:
            continue
        var row: Dictionary = value
        if not bool(row.get("is_voice", true)):
            continue
        if not VoiceCueTiming.cue_matches(row, character_id):
            continue
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


func _entries_with_prefix(prefix: String) -> Array:
    var out: Array = []
    for value: Variant in log:
        if not value is Dictionary:
            continue
        var entry: Dictionary = value
        if String(entry.get("label", "")).begins_with(prefix):
            out.append(entry)
    return out


func _entries_matching(entries: Array, file: String, frame: int) -> Array:
    var out: Array = []
    for value: Variant in entries:
        if not value is Dictionary:
            continue
        var entry: Dictionary = value
        if (String(entry.get("file", "")).to_lower() == file.to_lower()
                and int(entry.get("frame", -1)) == frame):
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
    var observed: float = _observed_seconds(entry)
    if absf(observed - expected) > TIMING_TOLERANCE:
        _fail("%s started %.3fs after scheduling, expected %.3fs (f%d)" % [
            label, observed, expected, frame
        ])
    if start_ms >= 0:
        var wall: float = (
            float(int(entry.get("played_ms", 0)) - start_ms) / 1000.0
        )
        if absf(wall - expected) > TIMING_TOLERANCE + 0.030:
            _fail("%s wall clock %.3fs != frame/30 %.3fs (f%d)" % [
                label, wall, expected, frame
            ])
    if frame > 0 and observed < expected * 0.5:
        _fail("%s played at the stage start (%.3fs) instead of f%d" % [
            label, observed, frame
        ])


func _assert_volume(entry: Dictionary, expected: float, label: String) -> void:
    var actual: float = float(entry.get("volume", -1.0))
    if absf(actual - expected) > 0.001:
        _fail("%s volume %.3f != recovered %.3f" % [label, actual, expected])


func _finish() -> void:
    if not failures.is_empty():
        print("ENDATTACK_TWO_STAGE_AUDIO=failed")
        print(JSON.stringify({"failures": failures, "case": case_name}))
        quit(1)
        return
    print("ENDATTACK_TWO_STAGE_AUDIO=" + JSON.stringify({
        "case": case_name,
        "opponent_config": String(
            OS.get_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG")
        ),
        "frame_rate": SfxMusicMap.FRAME_RATE,
        "timing_tolerance": TIMING_TOLERANCE,
        "measured_cues": measured.size(),
        "measured": measured,
        "skipped": skipped,
        "audio_skips": scene.get("_audio_skips"),
    }))
    quit(0)

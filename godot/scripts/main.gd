extends Node3D
## Gameplay demonstrator: intentionally original, with placeholder meshes.
## Original character models/animations and exact rules remain unported.

const CandidateBounds = preload("res://scripts/candidate_bounds.gd")
const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")
const PrototypeMenu = preload("res://scripts/prototype_menu.gd")
const PrototypeControls = preload("res://scripts/prototype_controls.gd")
const MoveTraining = preload("res://scripts/move_training.gd")
const MoveGallery = preload("res://scripts/move_gallery.gd")
const FxLanternPulse = preload("res://scripts/fx_lanterns_pulse.gd")
const FxVapourReflector = preload("res://scripts/fx_vapour_reflector.gd")
const AudioCueMap = preload("res://scripts/audio_cue_map.gd")
## Recovered impact/block SFX + 21 music-track library (data-only table).
const SfxMusicMap = preload("res://scripts/sfx_music_map.gd")
const CameraAnm = preload("res://scripts/camera_anm_player.gd")
## Story-mode flow (isolated prototype).  Only instantiated when
## BRUCELEE_STORY_FLOW=1, so the existing prototype paths are untouched.
const StoryFlow = preload("res://scripts/story_flow.gd")
## Opt-in Arcade / Survival / Time Attack modes (recovered game.states / gui).
const GameModes = preload("res://scripts/game_modes.gd")
## Opponent-selection entries emitted by the prototype menu. Each value is the
## BRUCELEE_OPPONENT_* configuration applied before main.tscn is reloaded:
##   glb              candidate GLB path ("" means the built-in placeholder)
##   texture_root     directory holding <kind>_diffuse/normal/material.png
##   clip_prefix      candidate clip prefix, e.g. "m04" ("" means m03/Brick)
##   master           "1" selects the Master m04_e01_* clip table
##   material_profile CandidateMaterialLoader profile ("body" or "body_hair")
##   attack_config    mapped fighting-set config ("" means the Brick default)
## Paths are the locally tested candidates; they are not shipped with the repo.
const MENU_OPPONENT_CONFIG: Dictionary = {
    "brick": {
        "glb": "D:\\BruceLeeWork\\brick-full-20261103\\candidate\\brick_full_94_20261103.glb",
        "texture_root": (
            "D:\\BaiduSyncdisk\\AI项目\\李小龙\\private_assets\\appdata-msix\\"
            + "BruceLee-PC-Port\\brick-textures-20261030"
        ),
        "clip_prefix": "",
        "master": "",
        "material_profile": "body",
        "attack_config": "res://data/fighting_set_m03_mapped_attacks.json",
        "skeleton": "large",
    },
    "sinfu": {
        "glb": (
            "D:\\BruceLeeWork\\result-clip-fixes-20261103\\candidates\\"
            + "sinfu_hair_two-skin_81_result_20261103.glb"
        ),
        "texture_root": "D:\\BruceLeeWork\\sinfu-tex",
        "clip_prefix": "m04",
        "master": "",
        "material_profile": "body",
        "attack_config": "res://data/attack_config_sinfu.json",
        "skeleton": "medium",
    },
    "master": {
        "glb": (
            "D:\\BruceLeeWork\\result-clip-fixes-20261103\\candidates\\"
            + "master_full_hair_80_result_20261103.glb"
        ),
        "texture_root": "D:\\BruceLeeWork\\master-candidate-20261103\\textures",
        "clip_prefix": "",
        "master": "1",
        "material_profile": "body",
        "attack_config": "res://data/attack_config_master.json",
        "skeleton": "small",
    },
    "shenlo": {
        "glb": (
            "D:\\BruceLeeWork\\shenlo-20261103\\candidates\\"
            + "shenlo_full_body_89_all_20261103.glb"
        ),
        "texture_root": "D:\\BruceLeeWork\\shenlo-20261103\\textures",
        "clip_prefix": "m04",
        "master": "",
        "material_profile": "body",
        "attack_config": "res://data/attack_config_shenlo.json",
        "skeleton": "medium",
    },
    "ken": {
        "glb": (
            "D:\\BruceLeeWork\\result-clip-fixes-20261103\\candidates\\"
            + "ken_all26_74_defeat_groundidle_20261103.glb"
        ),
        "texture_root": (
            "D:\\BruceLeeWork\\character-integration-fixed-20261103\\"
            + "assets\\ken-textures"
        ),
        "clip_prefix": "m02",
        "master": "",
        "material_profile": "body_hair",
        "attack_config": "res://data/attack_config_ken.json",
        "skeleton": "medium",
    },
    "smallboy": {
        "glb": "D:\\BruceLeeWork\\remaining-characters-20261103\\candidates\\smallboy_full_body_hair_87_all_20261103.glb",
        "texture_root": "D:\\BruceLeeWork\\remaining-characters-20261103\\textures\\smallboy",
        "clip_prefix": "",
        "master": "",
        "material_profile": "body_hair",
        "attack_config": "res://data/attack_config_smallboy.json",
        "skeleton": "large",
    },
    "johnson": {
        "glb": "D:\\BruceLeeWork\\remaining-characters-20261103\\candidates\\johnson_full_body_88_all_20261103.glb",
        "texture_root": "D:\\BruceLeeWork\\remaining-characters-20261103\\textures\\johnson",
        "clip_prefix": "",
        "master": "",
        "material_profile": "body",
        "attack_config": "res://data/attack_config_johnson.json",
        "skeleton": "large",
    },
    "chief": {
        "glb": "D:\\BruceLeeWork\\result-clip-fixes-20261103\\candidates\\chief01_full_body_hair_86_groundidle_20261103.glb",
        "texture_root": "D:\\BruceLeeWork\\remaining-characters-20261103\\textures\\chief01",
        "clip_prefix": "",
        "master": "",
        "material_profile": "body_hair",
        "attack_config": "res://data/attack_config_chief.json",
        "skeleton": "large",
    },
    "loming": {
        "glb": "D:\\BruceLeeWork\\result-clip-fixes-20261103\\candidates\\loming01_full_body_hair_84_groundidle_20261103.glb",
        "texture_root": "D:\\BruceLeeWork\\remaining-characters-20261103\\textures\\loming01",
        "clip_prefix": "",
        "master": "",
        "material_profile": "body_hair",
        "attack_config": "res://data/attack_config_loming.json",
        "skeleton": "large",
    },
}
# characters.list "skeleton" per fighting set, used for the size-class clip
# versions (adreno_200/Animations.versions). Keyed by the same config path the
# opponent already uses to identify its character, so a launcher that only sets
# BRUCELEE_OPPONENT_ATTACK_CONFIG still gets the right class:
#   brucelee (bruce lee a..d) medium, kungfu (shen lo, sin fu) medium,
#   kungfu (the master) small, kungfu (lo ming a/b) large,
#   karate (ken godall) medium, karate (chief a/b) large,
#   thai (smallboy, brick davis, johnson) large.
const ATTACK_CONFIG_SKELETON: Dictionary = {
    "res://data/fighting_set_m03_mapped_attacks.json": "large",
    "res://data/fighting_set_low_attacks.json": "medium",
    "res://data/attack_config_smallboy.json": "large",
    "res://data/attack_config_johnson.json": "large",
    "res://data/attack_config_chief.json": "large",
    "res://data/attack_config_loming.json": "large",
    "res://data/attack_config_ken.json": "medium",
    "res://data/attack_config_master.json": "small",
    "res://data/attack_config_sinfu.json": "medium",
    "res://data/attack_config_shenlo.json": "medium",
}
const PLAYER_SKELETON_DEFAULT: String = "medium"
const CANDIDATE_HEIGHT_TOLERANCE: float = 0.01
const ROUNDS_TO_WIN: int = 2
# Native CBeatEmUpGame::Update() leaves states 3/5/7/8/11 only when
# GetStateTime() is strictly greater than 3000 ms; keep the same threshold.
const ROUND_PHASE_WAIT_MS: int = 3000
const ROUND_RESET_DELAY: float = float(ROUND_PHASE_WAIT_MS) / 1000.0
# Original round clock: CBeatEmUpGame::SetTimerMax() stores the limit in
# seconds and Update() displays max(0, limit - played_ms / 1000).
const ROUND_TIME_DEFAULT: int = 60

# Ported EGameState subset from krm::CBeatEmUpGame::SetState/Update
# (ghidra-out5/SetState.c, ghidra-out5/Update.c).  States 1/2 (attract intro),
# 6 (replay), 9 (continue), 10, 14 are not implemented because their
# configuration and runtime semantics are not proven for this prototype.
const MATCH_STATE_INTRO: int = 3        # SetState(3): both idle, READY/FIGHT text
const MATCH_STATE_FIGHT: int = 4        # SetState(4): control + round clock
const MATCH_STATE_TIME_UP: int = 5      # SetState(5): LaunchGameTextAnimation(4)
const MATCH_STATE_KO_WIN: int = 7       # SetState(7): player round win text
const MATCH_STATE_KO_LOSE: int = 8      # SetState(8): computer round win text
const MATCH_STATE_DRAW: int = 11        # SetState(11): draw round text
const MATCH_STATE_MATCH_WIN: int = 12   # SetState(12): winner-only victory pose
const MATCH_STATE_MATCH_LOSE: int = 13  # SetState(13): winner-only victory pose
const MATCH_STATE_ROUND_END: int = 15   # SetState(15): RoundEnded() -> NextRound

# Recovered ingamesprites.list game text animation indices
# (gametext-assets-20261103/report/ingamesprites_animations.json, indices are
# the LaunchGameTextAnimation() arguments recovered in CBeatEmUpGame::SetState
# and ::Render):
#   0 READY  1 FIGHT  2 YOU_WIN  3 YOU_LOSE  4 TIME_IS_UP  5 DRAW
#   6 PERFECT  7 COUNTER (left/player)  8 COUNTER (right/opponent)
#   9 GREAT (centre)  10 GREAT (low, SetState(9))
const GAME_TEXT_SEQ_READY := 0
const GAME_TEXT_SEQ_FIGHT := 1
const GAME_TEXT_SEQ_YOU_WIN := 2
const GAME_TEXT_SEQ_YOU_LOSE := 3
const GAME_TEXT_SEQ_TIME_IS_UP := 4
const GAME_TEXT_SEQ_DRAW := 5
const GAME_TEXT_SEQ_PERFECT := 6
const GAME_TEXT_SEQ_COUNTER_PLAYER := 7
const GAME_TEXT_SEQ_COUNTER_OPPONENT := 8
const GAME_TEXT_SEQ_GREAT := 9
const GAME_TEXT_SEQ_GREAT_LOW := 10
const GAME_TEXT_MAX_OVERLAYS := 4
# Every recovered ingamesprites.list record also carries its own commentator
# sample (`sounds`: archive path + time in seconds).  Native
# LaunchGameTextAnimation() starts one CSpriteAnimator per call, each with its
# own sound; YOU_WIN + PERFECT therefore overlap (Perfect.wav is at +1.5 s).
# One player per in-flight sample, bounded and round-robin reused.
const RESULT_AUDIO_MAX_PLAYERS := 8
# Native player-round-win text thresholds (CBeatEmUpGame::SetState 7, local
# flag 0): winner health < 0x14 -> GREAT, winner health == 100 -> PERFECT.
const ROUND_GREAT_HEALTH := 20.0
# krm::CSpriteAnimator::Update draws every step at
# width = step.size * texture_width in *display* pixels (DrawSprite(canvas,
# display_width * x, display_height * y, texture, size * tex_w, size * tex_h));
# no global colour tint is applied.  The native display width is not statically
# recovered; the previously validated overlay used 1.6 on the 1280x720 canvas,
# which is exactly 1280 / 800 (WVGA).  Keep that validated proportion but
# derive it from the live viewport instead of hard-coding 1.6.
const GAME_TEXT_NATIVE_DISPLAY_WIDTH := 800.0

# CBeatEmUpCamera::Update, native Z-up formula ported to Godot axes.
const CAM_SOURCE_UNITS_TO_WORLD: float = (
    PortFighter.WORLD_CHARACTER_HEIGHT / PortFighter.SOURCE_CHARACTER_HEIGHT
)
const CAM_UPDATE_HZ: float = 60.0
const CAM_SMOOTH_OLD: float = 0.8
const CAM_MIN_DISTANCE: float = 275.0
const CAM_TARGET_HEIGHT: float = 112.0
const CAM_ELEVATION: float = 0.0
const CAM_SIDE: int = 0
# Godot Camera3D default vertical FOV, which is what the analytic follow camera
# has always used (the formula carries no fov). It is re-asserted every analytic
# frame so an authored .anm clip's animated fov cannot leak into the fight view.
const CAM_FIGHT_FOV: float = 75.0

var player: PortFighter
var computer: PortFighter
var hud: PortHUD
var prototype_menu: PortPrototypeMenu
var move_training
var move_gallery
var fight_camera: Camera3D
var _cam_smooth_a: Vector3 = Vector3.ZERO
var _cam_smooth_b: Vector3 = Vector3.ZERO
var _cam_zoom: float = 0.0
var _cam_side: int = CAM_SIDE
var _cam_initialized: bool = false
var _scene_origin: Vector3 = Vector3.ZERO
var _far_entry_instances: Dictionary = {}
var _procedural_floor: Node3D = null
var _procedural_arena_lines: Array[MeshInstance3D] = []
var _procedural_arena_hidden: bool = false
var _far_scene_texture_count: int = 0
var _world_environment: WorldEnvironment = null
var combat_audio: Node
var _candidate_audio: Dictionary = {}
var _candidate_audio_error: Dictionary = {}
var _voice_audio: Dictionary = {}
var _voice_audio_error: Dictionary = {}
var _active_voice: AudioStreamPlayer = null
# Recovered adreno_200/sounds/sfx library (38 WAVs).  Distinct from the three
# legacy candidate-audio streams: the package copy is self-contained and is
# read without CandidatePathGuard (music/commentator already use the same
# package-relative convention).
var _sfx_audio: Dictionary = {}
var _sfx_audio_error: Dictionary = {}
var _sfx_play_log: Array = []
var _sfx_play_count: int = 0
var _footstep_accum: Dictionary = {}
var _footstep_index: Dictionary = {}
var _music_player: AudioStreamPlayer = null
var _music_stream: AudioStream = null
var _music_streams: Dictionary = {}
var _music_stream_paths: Dictionary = {}
var _music_key: String = ""
var _result_audio: Dictionary = {}
var _result_audio_paths: Dictionary = {}
var _result_players: Array[AudioStreamPlayer] = []
var _result_player_cursor: int = 0
# First pooled player; kept for existing debug helpers.
var _result_player: AudioStreamPlayer = null
# One entry per commentator playback:
# {key, sequence, sample, file, path, length_ms}.  The recovered
# ingamesprites.list record owns the sample and its offset, so this log is the
# evidence that each result cue fires exactly once per game-text launch.
var result_audio_play_log: Array = []
var result_audio_play_count: int = 0
var _game_text_textures: Dictionary = {}
# Recovered ingamesprites.list animation records, keyed by the record index
# (0..10).  COUNTER (7/8) and GREAT (9/10) share one texture each but carry
# different step scripts, so the key must be the index, not the texture name.
var _game_text_sequences: Dictionary = {}
# Live game text overlays.  Native LaunchGameTextAnimation() starts one
# CSpriteAnimator per call and several can run at once (YOU_WIN + PERFECT,
# COUNTER on both sides), so the port keeps a small pool of Sprite2Ds.
var _game_text_overlays: Array[Dictionary] = []
var _game_text_layer: CanvasLayer = null
# First overlay; kept for the existing tests/debug helpers.
var _game_text_rect: Sprite2D = null
# Launch history for validators/debugging: {key, sequence}.
var game_text_launch_log: Array = []
# CFighter+0x176 "counter" flags: set natively by SetAnimation when the new
# animation carries the recovered "counter" category, consumed by Render.
# The port records the last parry animation per side so a new parry animation
# (including parrylow -> parryhigh) relaunches the text, while one continuous
# parry shows it once.
var _counter_text_last_state: Array = ["", ""]
var ai_timer: float = 0.0
var ai_guard_sequence: int = -1
var ai_guard_decision: bool = false
var done: bool = false
var training_mode: bool = false
var training_completed: bool = false
var main_menu_enabled: bool = false
var main_menu_active: bool = false
var menu_paused: bool = false
var elapsed: float = 0.0
var notice_timer: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Port of zmathRandomGet() (libdefault.so 0x58d820). zmathRandomSetSeed seeds a
# 32-bit LCG whose static initializer stores 0x6425AF14 (_GLOBAL__I_zaprandom.cpp
# 0x58d900), and every call returns bits 16..31 of the advanced state, so the
# native range is 0..65535. IBeatEmUpGameMode::SetFighterConfigFromCharacterList
# uses `zmathRandomGet() % version_count` as the characters.list animation
# version, so the same generator keeps the port's pick reproducible.
var _zmath_state: int = 0x6425AF14
# Recovered native AI (adreno_200/ai/standard.tree + characters.list).
const NativeAI = preload("res://scripts/native_ai.gd")
var native_ai: RefCounted = null
var round_number: int = 1
var player_rounds: int = 0
var computer_rounds: int = 0
var match_over: bool = false
var round_reset_timer: float = -1.0
var round_time_max: int = ROUND_TIME_DEFAULT
var round_time_left: int = ROUND_TIME_DEFAULT
var round_time_active: bool = false
## Story-mode additions: the match config's rounds-to-win comes from the story
## battle `rounds` field, and a story battle may start the player below full
## health (`player_starting_health`).  Both default to the prototype values.
var rounds_to_win: int = ROUNDS_TO_WIN
var player_start_health_override: float = -1.0
var story_flow: Node = null
var game_modes: Node = null
# Local port of the CBeatEmUpGame state machine. match_state is the native
# EGameState value, match_state_time is GetStateTime() in seconds and
# pending_round_winner is 0 (draw), 1 (player) or 2 (computer).
var match_state: int = MATCH_STATE_FIGHT
var match_state_time: float = 0.0
var pending_round_winner: int = 0
var _round_end_handled: bool = false
var _intro_fight_shown: bool = false
var _result_pose_seconds: float = 0.0
var _result_camera_override: bool = false

# ---- Original camera .anm playback for the MATCH_WIN/MATCH_LOSE result state ----
# Decoded from adreno_200/cameras/m01_victory_01_camera.anm by the isolated
# camera-anm-20261104 research. The JSON is shipped next to data/; no keyframe
# is invented here. When the file is missing, _camera_anm_play_authored() returns
# false and the result camera keeps the pre-existing fixed winner shot.
const CAMERA_ANM_DIR: String = "res://data/camera_anm/"
var _camera_anm_dir: String = CAMERA_ANM_DIR
var _camera_anm = null
var _camera_anm_clip: String = ""
var _camera_anm_frame: float = 0.0
var _camera_anm_mirror: bool = false
var _camera_anm_anchor: PortFighter = null
var _camera_anm_a: Vector3 = Vector3.ZERO
var _camera_anm_b: Vector3 = Vector3.ZERO

# ---- Original camera .anm playback for the MATCH_STATE_INTRO (SetState(3)) ----
# Decoded from adreno_200/cameras/m01_intro_01_camera.anm (121 frames @ 30 fps,
# fov 56.35 deg -> 9.0 deg, camera height ~0.63-0.74 m, distance ~1.9-2.1 m).
# The JSON is shipped as data/camera_anm/m01_intro_01.json; no keyframe is
# invented here. Decompiled CBeatEmUpGame::CameraUpdate (@ 0x188d88) picks the
# dummy fighter from the local-player flag (this+0x7e0) and passes mirror = 0
# for every state other than 1/2/12/13; SetState(3) starts the intro animation
# on both fighters, so a single-player build rides fighter 0's intro clip, i.e.
# m01_intro_01 for match 1. When the file is missing the intro keeps the
# pre-existing analytic follow camera.
const INTRO_CAMERA_CLIP: String = "m01_intro_01"

# ---- Original action cameras (grab / grabbed / end-attack / special) ----
# Decoded from adreno_200/cameras/*_camera.anm by the isolated
# camera-anm-20261104 research; the JSONs are shipped as data/camera_anm/.
# CBeatEmUpGame::CameraUpdate (@0x188d88) takes the camera sub-animation from
# CFighter::GetCurrentAnimation(fighter[this+0x7e0]) -- the local player's
# fighter -- with dummy = that fighter and mirror = 0 for every gameplay state.
# data/camera_anm/action_camera_map.json is derived mechanically from the
# decoded keyframes plus the recovered fighting-set action tables (see
# reports/action_camera_map.json in the isolated output for the per-row
# evidence).  When the player's current animation is in that table its
# keyframes are played frame-for-frame; when the clip has no camera, or the
# JSON is missing, the analytic follow camera keeps the view exactly as an
# animation without a camera sub-animation would.
const ACTION_CAMERA_MAP_PATH: String = "res://data/camera_anm/action_camera_map.json"
var _action_camera_map_path: String = ACTION_CAMERA_MAP_PATH
var _action_camera_map: Dictionary = {}
var _action_camera_map_loaded: bool = false
var _action_camera_anm = null
var _action_camera_clip: String = ""
var _action_camera_camera: String = ""
var _action_camera_frame: int = 0
var _action_camera_anchor: PortFighter = null
var _action_camera_mirror: bool = false
var _action_camera_a: Vector3 = Vector3.ZERO
var _action_camera_b: Vector3 = Vector3.ZERO
var _action_camera_missing_json: Array[String] = []

# AI-only prototype costs: the native AI decision is not recovered, so the
# Brick AI uses these thresholds/costs. They are not part of the player action
# layer (the player spends per-action action.rage values).
const AI_SPECIAL_RAGE_COSTS: Dictionary = {
    "special_kick_high": 33.0,
    "special_kick_low_miss": 66.0,
    "special_punch_low_miss": 66.0,
    "special_punch_high_miss": 66.0,
    "grab1": 66.0,
    "grab2": 66.0,
    "grab1_miss_brick": 66.0,
    "grab2_miss_brick": 66.0,
    "grab1_miss": 66.0,
    "grab2_miss": 66.0,
    "special_kick_high_brick": 33.0,
    "special_kick_low_brick": 33.0,
    "special_punch_high_brick": 66.0,
    "special_punch_low_brick": 66.0,
    "parry_high_brick": 33.0,
    "parry_low_brick": 30.0,
    "grab1_brick": 66.0,
    "grab2_brick": 66.0,
    # Mapped set configs (Master/SinFu/Ken) use unsuffixed slot names. The
    # costs mirror the Brick rows because the prototype AI choice is unchanged;
    # the native rage gates themselves are not recovered.
    "special_kick_low": 33.0,
    "special_punch_high": 66.0,
    "special_punch_low": 66.0,
    "parry_high": 33.0,
    "parry_low": 30.0,
}

func _ready() -> void:
    var startup_begin: int = Time.get_ticks_msec()
    PrototypeControls.ensure_default_actions()
    rng.seed = 0xB17E
    _build_environment()
    var startup_environment: int = Time.get_ticks_msec()
    _build_fighters()
    var startup_fighters: int = Time.get_ticks_msec()
    _build_combat_audio()
    var startup_audio: int = Time.get_ticks_msec()
    hud = PortHUD.new()
    add_child(hud)
    hud.set_fighter_names("BRUCE LEE", _opponent_display_name())
    _build_game_text_overlay()

    if not OS.get_environment("BRUCELEE_DEMO_RAGE").is_empty():
        hud.footer.text = (
            "J J J | J K K | K L L | K U U | "
            + "Back+K -> Toward+L -> Toward+L = special (rage 100)"
        )
    prototype_menu = PortPrototypeMenu.new()
    add_child(prototype_menu)
    prototype_menu.command_requested.connect(_on_menu_command)
    move_training = MoveTraining.new()
    add_child(move_training)
    move_training.configure(self, player, computer)
    move_training.exit_requested.connect(_on_move_training_exit)
    move_gallery = MoveGallery.new()
    add_child(move_gallery)
    move_gallery.configure(self, player, computer)
    move_gallery.exit_requested.connect(_on_move_gallery_exit)
    var export_self_test: bool = OS.get_environment("BRUCELEE_EXPORT_SELF_TEST") == "1"
    var story_mode: bool = OS.get_environment("BRUCELEE_STORY_FLOW") == "1"
    var game_mode: bool = not OS.get_environment("BRUCELEE_GAME_MODE").is_empty()
    if story_mode:
        story_flow = StoryFlow.new()
        add_child(story_flow)
        story_flow.configure(self, MENU_OPPONENT_CONFIG)
    game_modes = GameModes.new()
    add_child(game_modes)
    game_modes.configure(self, MENU_OPPONENT_CONFIG)
    main_menu_enabled = (
        false if (export_self_test or story_mode or game_mode)
        else _should_show_main_menu()
    )
    _configure_round_time()
    _configure_match_rounds()
    _reset_match()
    _configure_native_ai()
    print("STARTUP_PROFILE environment=%d fighters=%d audio=%d total=%d" % [
        startup_environment - startup_begin,
        startup_fighters - startup_environment,
        startup_audio - startup_fighters,
        Time.get_ticks_msec() - startup_begin,
    ])
    if main_menu_enabled:
        _open_main_menu()
    if export_self_test:
        call_deferred("_run_export_self_test")
    elif not main_menu_enabled and (
            not story_mode or OS.get_environment("BRUCELEE_STORY_LAUNCH") == "1") and (
            not game_mode or OS.get_environment("BRUCELEE_MODE_LAUNCH") == "1"):
        call_deferred("_start_direct_intro")
    if story_mode:
        story_flow.open_initial()
    if game_mode:
        game_modes.open_initial()


func _start_direct_intro() -> void:
    _play_scene_music()
    if OS.get_environment("BRUCELEE_ROUND_INTRO") == "0":
        return
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw
    _start_round_intro()


func _run_export_self_test() -> void:
    # Freeze gameplay before the readiness wait so autonomous AI input cannot
    # change the candidate animation that this deterministic self-test checks.
    _load_bruce_voice_audio()
    set_physics_process(false)
    player.set_physics_process(false)
    computer.set_physics_process(false)
    var opponent_idle_clip: String = ""
    await get_tree().process_frame
    await get_tree().process_frame
    for _frame: int in 120:
        await get_tree().physics_frame
    if not player.candidate_loaded:
        push_error("EXPORT_SELF_TEST: candidate GLB was not loaded: "
                + player.candidate_load_error)
        get_tree().quit(1)
        return
    if not player.candidate_textures_loaded:
        push_error("EXPORT_SELF_TEST: candidate textures were not loaded: "
                + player.candidate_texture_error)
        get_tree().quit(1)
        return
    var expect_opponent_candidate: bool = not OS.get_environment(
        "BRUCELEE_OPPONENT_GLB"
    ).is_empty()
    if expect_opponent_candidate and not computer.candidate_loaded:
        push_error("EXPORT_SELF_TEST: opponent candidate GLB was not loaded: "
                + computer.candidate_load_error)
        get_tree().quit(1)
        return
    if expect_opponent_candidate:
        computer.reset_fighter(Vector3(2.0, 1.20, 0.0))
        computer._animate_candidate()
        var expected_idle: String = "m03_idle_01"
        if OS.get_environment("BRUCELEE_OPPONENT_MASTER") == "1":
            expected_idle = "m04_e01_idle_01"
        elif not OS.get_environment("BRUCELEE_OPPONENT_CLIP_PREFIX").is_empty():
            expected_idle = OS.get_environment("BRUCELEE_OPPONENT_CLIP_PREFIX") + "_idle_01"
        if computer.candidate_animation_clip != expected_idle:
            push_error("EXPORT_SELF_TEST: opponent candidate idle="
                    + computer.candidate_animation_clip + " expected=" + expected_idle)
            get_tree().quit(1)
            return
        opponent_idle_clip = computer.candidate_animation_clip
        if (not OS.get_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT").is_empty()
                and not computer.candidate_textures_loaded):
            push_error("EXPORT_SELF_TEST: opponent textures were not loaded: "
                    + computer.candidate_texture_error)
            get_tree().quit(1)
            return
    if player.candidate_animation_clip != "m01_idle_01":
        push_error("EXPORT_SELF_TEST: candidate did not start in idle")
        get_tree().quit(1)
        return
    var candidate_root: Node3D = player.get("_candidate_root")
    if candidate_root == null:
        push_error("EXPORT_SELF_TEST: candidate root is unavailable")
        get_tree().quit(1)
        return
    var measured: Dictionary = CandidateBounds.scene_bounds(candidate_root)
    if not measured["error"].is_empty():
        push_error("EXPORT_SELF_TEST: candidate bounds failed: " + measured["error"])
        get_tree().quit(1)
        return
    var bounds: AABB = measured["bounds"]
    var expected_floor_y: float = 0.0
    if (not is_finite(bounds.size.y) or bounds.size.y <= 0.0
            or absf(player.candidate_visual_height - PortFighter.CANDIDATE_HEIGHT)
                    > CANDIDATE_HEIGHT_TOLERANCE):
        push_error("EXPORT_SELF_TEST: candidate visual normalization is invalid")
        get_tree().quit(1)
        return
    if (not is_finite(bounds.position.y)
            or absf(bounds.position.y - expected_floor_y) > 0.02):
        push_error("EXPORT_SELF_TEST: candidate floor is %.6f, expected %.6f" % [
            bounds.position.y, expected_floor_y,
        ])
        get_tree().quit(1)
        return
    var internal_path: String = (
        CandidatePathGuard.repository_root().path_join("internal-candidate.glb")
    )
    if CandidatePathGuard.external_path_error(
            internal_path, "candidate path").is_empty():
        push_error("EXPORT_SELF_TEST: application-internal candidate path was accepted")
        get_tree().quit(1)
        return

    player.reset_fighter(Vector3(-0.25, 1.2, 0.0))
    computer.reset_fighter(Vector3(0.25, 1.2, 0.0))
    if not player.request_attack("punch"):
        push_error("EXPORT_SELF_TEST: could not start punch")
        get_tree().quit(1)
        return
    player._physics_process(0.2)
    if absf(computer.health - 95.0) > 0.001:
        push_error("EXPORT_SELF_TEST: punch target health is %.3f" % computer.health)
        get_tree().quit(1)
        return
    if (computer.last_reaction_source_action != "impactlightfrontmid"
            or computer.last_reaction_exit_frame != 14):
        push_error("EXPORT_SELF_TEST: recovered punch reaction was not applied")
        get_tree().quit(1)
        return
    if player.candidate_animation_clip != "m01_pnch_low_01":
        push_error("EXPORT_SELF_TEST: punch clip was not selected")
        get_tree().quit(1)
        return
    var reaction_available: bool = player.get("_candidate_clip_paths").has("all_impct_light_frnt_mid")
    player.receive_hit(5.0, false, 0.0, 1.0, player.REACTION_PROFILES["hit"]["medium"])
    player._animate_candidate()
    var expected_reaction: String = "all_impct_light_frnt_mid" if reaction_available else "m01_idle_01"
    if player.candidate_animation_clip != expected_reaction:
        push_error("EXPORT_SELF_TEST: reaction clip was not selected")
        get_tree().quit(1)
        return
    print("EXPORT_SELF_TEST=" + JSON.stringify({
        "candidate_world_height": bounds.size.y,
        "candidate_world_min_y": bounds.position.y,
        "candidate_visual_height": player.candidate_visual_height,
        "candidate_textures_loaded": player.candidate_textures_loaded,
        "internal_path_rejected": true,
        "punch_target_health": computer.health,
        "punch_hitstun_frames": computer.last_reaction_exit_frame,
        "reaction_clip": player.candidate_animation_clip,
        "opponent_brutal_clip": (
            computer.get("_candidate_clip_paths").has("all_sp_pnch_low_forset04")
            if computer != null else false
        ),
        "voice_loaded": _voice_audio.size(),
        "voice_errors": _voice_audio_error.size(),
        "music_loaded": _music_player != null,
        "result_audio_loaded": _result_audio.size(),
        "menu_background_loaded": prototype_menu != null and prototype_menu.background_loaded,
        "menu_accept_sfx_loaded": prototype_menu != null and prototype_menu.accept_sfx != null,
        "scene_prop_count": (
            get_node_or_null("OriginalSceneProps").get_child_count()
            if get_node_or_null("OriginalSceneProps") != null else 0
        ),
        "far_scene_prop_count": (
            get_node_or_null("OriginalFarScene").get_child_count()
            if get_node_or_null("OriginalFarScene") != null else 0
        ),
        "procedural_arena_hidden": _procedural_arena_hidden,
        "far_scene_texture_count": _far_scene_texture_count,
        "opponent_candidate_loaded": computer.candidate_loaded,
        "opponent_idle_clip": opponent_idle_clip,
        "opponent_visual_height": computer.candidate_visual_height,
        "opponent_load_error": computer.candidate_load_error,
        "opponent_textures_loaded": computer.candidate_textures_loaded,
        "opponent_texture_reason": computer.candidate_texture_reason,
    }))
    await _await_combat_audio_idle()
    _stop_combat_audio()
    await get_tree().create_timer(0.1).timeout
    await get_tree().process_frame
    get_tree().quit(0)

func _build_environment() -> void:
    var environment: WorldEnvironment = WorldEnvironment.new()
    _world_environment = environment
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(0.07, 0.10, 0.16)
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color = Color(0.62, 0.64, 0.78)
    environment.environment.ambient_light_energy = 0.65
    add_child(environment)
    var light: DirectionalLight3D = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
    light.light_energy = 1.65
    add_child(light)
    fight_camera = Camera3D.new()
    fight_camera.position = Vector3(0.0, 6.0, 12.5)
    fight_camera.current = true
    add_child(fight_camera)
    fight_camera.look_at(Vector3(0.0, 1.1, 0.0), Vector3.UP)
    _make_floor()
    _make_arena_line(-PortFighter.ARENA_HALF_X)
    _make_arena_line(PortFighter.ARENA_HALF_X)
    _build_original_scene_props()
    _build_original_far_scene()
    _build_fx_anim_scene()


func _scene_variant() -> String:
    return OS.get_environment("BRUCELEE_SCENE").to_lower()


func _build_near_manifest(scene_root: String) -> void:
    var base: String = OS.get_executable_path().get_base_dir().path_join(scene_root)
    var manifest_path: String = base.path_join("near_manifest.json")
    if not FileAccess.file_exists(manifest_path):
        return
    var file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Array:
        return
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(0.42, 0.38, 0.30, 1.0)
    material.roughness = 0.9
    var root: Node3D = Node3D.new()
    root.name = "OriginalSceneProps"
    var scale_value: float = PortFighter.WORLD_CHARACTER_HEIGHT / PortFighter.SOURCE_CHARACTER_HEIGHT
    for entry_value: Variant in parsed:
        if not entry_value is Dictionary:
            continue
        var entry: Dictionary = entry_value
        if bool(entry.get("pulse", false)):
            var curves_path: String = base.path_join(
                String(entry.get("pulse_curves", "lantern_pulse_curves.json")))
            var pulse: Node3D = FxLanternPulse.build(base, curves_path, scale_value)
            if pulse.get_child_count() == 0:
                pulse.free()
                continue
            root.add_child(pulse)
            for replaced_name: Variant in entry.get("replaces", []):
                _hide_far_fx_entry(String(replaced_name))
            continue
        if bool(entry.get("reflector", false)):
            var reflector: Node3D = FxVapourReflector.build(base, scale_value)
            if reflector.get_child_count() == 0:
                reflector.free()
                continue
            root.add_child(reflector)
            for replaced_name: Variant in entry.get("replaces", []):
                _hide_far_fx_entry(String(replaced_name))
            continue
        var glb_path: String = base.path_join(String(entry.get("file", "")))
        if not FileAccess.file_exists(glb_path):
            continue
        var document: GLTFDocument = GLTFDocument.new()
        var state: GLTFState = GLTFState.new()
        if document.append_from_file(glb_path, state) != OK:
            continue
        var instance: Node3D = document.generate_scene(state)
        if instance == null:
            continue
        var pos: Array = entry.get("position", [0.0, 0.0, 0.0])
        instance.position = Vector3(float(pos[0]), float(pos[2]), -float(pos[1])) * scale_value
        instance.scale = Vector3.ONE * scale_value
        var entry_material: StandardMaterial3D = material
        var texture_name: String = String(entry.get("texture", ""))
        if not texture_name.is_empty():
            var texture_path: String = base.path_join(texture_name)
            if FileAccess.file_exists(texture_path):
                var image: Image = Image.new()
                if image.load(texture_path) == OK:
                    entry_material = StandardMaterial3D.new()
                    entry_material.albedo_texture = ImageTexture.create_from_image(image)
                    entry_material.albedo_color = Color.WHITE
                    entry_material.roughness = 0.9
        var blend_mode: String = String(
            (entry.get("material", {}) as Dictionary).get("blend_mode", "")
        )
        if blend_mode == "alpha test":
            entry_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
            entry_material.alpha_scissor_threshold = 0.5
        elif blend_mode == "alpha blend":
            entry_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        for mesh_node: Node in instance.find_children("*", "MeshInstance3D", true, false):
            (mesh_node as MeshInstance3D).material_override = entry_material
        root.add_child(instance)
    if root.get_child_count() > 0:
        add_child(root)


func _build_original_scene_props() -> void:
    var variant: String = _scene_variant()
    if not variant.is_empty():
        var near_root: String = "scene/%s/near" % variant
        var near_base: String = OS.get_executable_path().get_base_dir().path_join(near_root)
        if DirAccess.dir_exists_absolute(near_base):
            _build_near_manifest(near_root)
        return
    var base: String = OS.get_executable_path().get_base_dir().path_join("scene")
    if not DirAccess.dir_exists_absolute(base):
        return
    var texture_path: String = base.path_join("scene_prop.png")
    var texture: Texture2D = null
    if FileAccess.file_exists(texture_path):
        var image: Image = Image.new()
        if image.load(texture_path) == OK:
            texture = ImageTexture.create_from_image(image)
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_texture = texture
    material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
    material.roughness = 0.9
    var root: Node3D = Node3D.new()
    root.name = "OriginalSceneProps"
    var scale_value: float = PortFighter.WORLD_CHARACTER_HEIGHT / PortFighter.SOURCE_CHARACTER_HEIGHT
    for filename: String in [
        "bl_scene02a_hw_prop_brick.glb",
        "bl_scene02a_hw_prop_brick_01.glb",
        "bl_scene02a_hw_prop_brick_02.glb",
    ]:
        var path: String = base.path_join(filename)
        if not FileAccess.file_exists(path):
            continue
        var document: GLTFDocument = GLTFDocument.new()
        var state: GLTFState = GLTFState.new()
        if document.append_from_file(path, state) != OK:
            continue
        var instance: Node3D = document.generate_scene(state)
        if instance == null:
            continue
        instance.position = Vector3(3.563, 0.7856, -2.679)
        instance.scale = Vector3.ONE * scale_value
        for mesh_node: Node in instance.find_children("*", "MeshInstance3D", true, false):
            (mesh_node as MeshInstance3D).material_override = material
        root.add_child(instance)
    if root.get_child_count() > 0:
        add_child(root)


func _make_floor() -> void:
    var floor: StaticBody3D = StaticBody3D.new()
    floor.name = "ArenaFloor"
    floor.collision_layer = 1
    floor.collision_mask = 2
    floor.position = Vector3(0.0, -0.22, 0.0)
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(PortFighter.ARENA_HALF_X * 2.0, 0.45, PortFighter.ARENA_HALF_Z * 2.0)
    shape.shape = box
    floor.add_child(shape)
    var visual: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = box.size
    visual.mesh = mesh
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(0.28, 0.28, 0.33)
    visual.material_override = material
    floor.add_child(visual)
    _procedural_floor = floor
    add_child(floor)

func _make_arena_line(x: float) -> void:
    var visual: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(0.05, 0.02, PortFighter.ARENA_HALF_Z * 2.0 - 1.0)
    visual.mesh = mesh
    visual.position = Vector3(x, 0.02, 0.0)
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(0.9, 0.72, 0.42)
    visual.material_override = material
    _procedural_arena_lines.append(visual)
    add_child(visual)

func _build_original_far_scene() -> void:
    _far_entry_instances.clear()
    var scene_root: String = "scene/far"
    var variant: String = _scene_variant()
    if not variant.is_empty():
        var candidate: String = "scene/%s/far" % variant
        var candidate_base: String = OS.get_executable_path().get_base_dir().path_join(candidate)
        if DirAccess.dir_exists_absolute(candidate_base):
            scene_root = candidate
    var base: String = OS.get_executable_path().get_base_dir().path_join(scene_root)
    _scene_origin = Vector3.ZERO
    var manifest_path: String = base.path_join("far_manifest.json")
    if not FileAccess.file_exists(manifest_path):
        return
    var file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Array:
        return
    var fallback_material: StandardMaterial3D = StandardMaterial3D.new()
    fallback_material.albedo_color = Color(0.42, 0.38, 0.30, 1.0)
    fallback_material.roughness = 0.95
    var root: Node3D = Node3D.new()
    root.name = "OriginalFarScene"
    var scale_value: float = PortFighter.WORLD_CHARACTER_HEIGHT / PortFighter.SOURCE_CHARACTER_HEIGHT
    for entry_value: Variant in parsed:
        if not entry_value is Dictionary:
            continue
        var entry: Dictionary = entry_value
        var entry_name: String = String(entry.get("name", ""))
        var is_skydome: bool = _is_skydome_entry(entry)
        var glb_path: String = base.path_join(String(entry.get("file", "")))
        if not FileAccess.file_exists(glb_path):
            continue
        var document: GLTFDocument = GLTFDocument.new()
        var state: GLTFState = GLTFState.new()
        if document.append_from_file(glb_path, state) != OK:
            continue
        var instance: Node3D = document.generate_scene(state)
        if instance == null:
            continue
        var pos: Array = entry.get("position", [0.0, 0.0, 0.0])
        instance.position = Vector3(float(pos[0]), float(pos[2]), -float(pos[1])) * scale_value
        instance.scale = Vector3.ONE * scale_value
        if bool(entry.get("apply_rotation", false)):
            var rot: Array = entry.get("rotation", [0.0, 0.0, 0.0, 1.0])
            if rot.size() >= 4:
                instance.quaternion = Quaternion(
                    float(rot[0]), float(rot[1]), float(rot[2]), float(rot[3])
                )
        if "combatarea" in entry_name:
            _scene_origin = Vector3(float(pos[0]), 0.0, -float(pos[1])) * scale_value
        var material: StandardMaterial3D = fallback_material
        if is_skydome:
            material = _make_skydome_material(entry, base)
        else:
            var texture_name: String = String(entry.get("texture", ""))
            if not texture_name.is_empty():
                var texture_path: String = base.path_join(texture_name)
                if FileAccess.file_exists(texture_path):
                    var image: Image = Image.new()
                    if image.load(texture_path) == OK:
                        material = StandardMaterial3D.new()
                        material.albedo_texture = ImageTexture.create_from_image(image)
                        material.albedo_color = Color.WHITE
                        material.roughness = 0.95
                        _far_scene_texture_count += 1
            var declared_blend: String = String(
                (entry.get("material", {}) as Dictionary).get("blend_mode", "")
            )
            if declared_blend == "alpha test":
                material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
                material.alpha_scissor_threshold = 0.5
            elif declared_blend == "alpha blend":
                material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
            elif declared_blend == "add":
                material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
                material.cull_mode = BaseMaterial3D.CULL_DISABLED
            elif declared_blend.is_empty():
                if "alphagroup" in entry_name:
                    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
                    material.alpha_scissor_threshold = 0.5
                if "fx_" in entry_name or "light" in entry_name:
                    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
                    material.cull_mode = BaseMaterial3D.CULL_DISABLED
                    material.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
        for mesh_node: Node in instance.find_children("*", "MeshInstance3D", true, false):
            var mesh_instance: MeshInstance3D = mesh_node
            mesh_instance.material_override = material
            if is_skydome:
                # A sky dome encloses the arena, so a cast shadow would darken
                # the whole far scene.
                mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _far_entry_instances[entry_name] = instance
        root.add_child(instance)
    if root.get_child_count() > 0:
        root.position = -_scene_origin
        add_child(root)
        _procedural_arena_hidden = true
        if _procedural_floor != null:
            _procedural_floor.visible = false
        for line: MeshInstance3D in _procedural_arena_lines:
            line.visible = false


# Far-scene FX animation playback.
#
# scene/<variant>/fx_anim/fx_anim_manifest.json is an array of entries shaped
# like far-manifest entries plus:
#   replaces               static far-entry names freed while this group plays
#   static_fallback_file   hierarchy without animation, used if `file` is absent
#   animation              {name, loop, autoplay, fps, frames, ...}
# A group GLB carries the authored scene hierarchy, its meshes and one glTF
# animation; Godot's importer turns that into an AnimationPlayer with Animation
# tracks targeting the named nodes.
#
# Fallback order for one entry:
#   1. `file` with an AnimationPlayer and the named clip  -> play it
#   2. `file` without animation                          -> show its frame-0 pose
#   3. `static_fallback_file`                            -> show its static pose
#   4. neither file exists or loads                      -> leave the original
#      static far entries untouched (Rooftops manifests rely on this: their
#      static-pose bake is the shipped far entry, not a second copy)
# Only a group that was actually added frees the far entries it replaces.


func _build_fx_anim_scene() -> void:
    var variant: String = _scene_variant()
    if variant.is_empty():
        return
    var base: String = OS.get_executable_path().get_base_dir().path_join(
        "scene/%s/fx_anim" % variant
    )
    var manifest_path: String = base.path_join("fx_anim_manifest.json")
    if not FileAccess.file_exists(manifest_path):
        return
    var file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Array:
        return
    var scale_value: float = PortFighter.WORLD_CHARACTER_HEIGHT / PortFighter.SOURCE_CHARACTER_HEIGHT
    var fallback_material: StandardMaterial3D = StandardMaterial3D.new()
    fallback_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
    fallback_material.roughness = 0.95
    var root: Node3D = Node3D.new()
    root.name = "FxAnimScene"
    for entry_value: Variant in parsed:
        if not entry_value is Dictionary:
            continue
        var entry: Dictionary = entry_value
        if bool(entry.get("pulse", false)):
            var curves_path: String = base.path_join(
                String(entry.get("pulse_curves", "lantern_pulse_curves.json")))
            var pulse: Node3D = FxLanternPulse.build(base, curves_path, scale_value)
            if pulse.get_child_count() == 0:
                pulse.free()
                continue
            root.add_child(pulse)
            for replaced_name: Variant in entry.get("replaces", []):
                _hide_far_fx_entry(String(replaced_name))
            continue
        if bool(entry.get("reflector", false)):
            var reflector: Node3D = FxVapourReflector.build(base, scale_value)
            if reflector.get_child_count() == 0:
                reflector.free()
                continue
            root.add_child(reflector)
            for replaced_name: Variant in entry.get("replaces", []):
                _hide_far_fx_entry(String(replaced_name))
            continue
        var glb_path: String = base.path_join(String(entry.get("file", "")))
        var used_static_group := false
        if not FileAccess.file_exists(glb_path):
            glb_path = base.path_join(String(entry.get("static_fallback_file", "")))
            used_static_group = true
        if not FileAccess.file_exists(glb_path):
            continue
        var document: GLTFDocument = GLTFDocument.new()
        var state: GLTFState = GLTFState.new()
        if document.append_from_file(glb_path, state) != OK:
            continue
        var instance: Node3D = document.generate_scene(state)
        if instance == null:
            continue
        var animation_info: Dictionary = entry.get("animation", {})
        var player: AnimationPlayer = _find_fx_animation_player(instance)
        var clip_name: String = String(animation_info.get("name", ""))
        var playing: bool = false
        if player != null and not used_static_group and not animation_info.is_empty():
            if not clip_name.is_empty() and player.has_animation(clip_name):
                var animation: Animation = player.get_animation(clip_name)
                animation.loop_mode = (
                    Animation.LOOP_LINEAR
                    if bool(animation_info.get("loop", false))
                    else Animation.LOOP_NONE
                )
                player.play(clip_name)
                if not bool(animation_info.get("autoplay", true)):
                    player.pause()
                playing = true
        # A malformed or missing clip must never overlay the shipped fallback.
        if not playing and not used_static_group:
            instance.free()
            continue
        var pos: Array = entry.get("position", [0.0, 0.0, 0.0])
        instance.position = Vector3(
            float(pos[0]), float(pos[2]), -float(pos[1])
        ) * scale_value
        instance.scale = Vector3.ONE * scale_value
        if bool(entry.get("apply_rotation", false)):
            var rot: Array = entry.get("rotation", [0.0, 0.0, 0.0, 1.0])
            if rot.size() >= 4:
                instance.quaternion = Quaternion(
                    float(rot[0]), float(rot[1]), float(rot[2]), float(rot[3])
                )
        var material: StandardMaterial3D = _fx_anim_material(
            entry, base, fallback_material
        )
        for mesh_node: Node in instance.find_children("*", "MeshInstance3D", true, false):
            var mesh_instance: MeshInstance3D = mesh_node
            mesh_instance.material_override = material
        root.add_child(instance)
        if playing or used_static_group:
            for replaced_name: Variant in entry.get("replaces", []):
                _hide_far_fx_entry(String(replaced_name))
        if not playing:
            print("FX anim: static fallback for ", entry.get("name", glb_path))
    if root.get_child_count() > 0:
        root.position = -_scene_origin
        add_child(root)


func _fx_anim_material(
        entry: Dictionary, base: String, fallback: StandardMaterial3D
        ) -> StandardMaterial3D:
    var material: StandardMaterial3D = fallback
    var texture_name: String = String(entry.get("texture", ""))
    if not texture_name.is_empty():
        var texture_path: String = base.path_join(texture_name)
        if FileAccess.file_exists(texture_path):
            var image: Image = Image.new()
            if image.load(texture_path) == OK:
                material = StandardMaterial3D.new()
                material.albedo_texture = ImageTexture.create_from_image(image)
                material.albedo_color = Color.WHITE
                material.roughness = 0.95
    var declared: String = String(
        (entry.get("material", {}) as Dictionary).get("blend_mode", "")
    )
    match declared:
        "alpha test":
            material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
            material.alpha_scissor_threshold = 0.5
        "alpha blend":
            material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        "add":
            material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
            material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
            material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material


func _find_fx_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node
    for child: Node in node.get_children():
        var found: AnimationPlayer = _find_fx_animation_player(child)
        if found != null:
            return found
    return null


func _hide_far_fx_entry(entry_name: String) -> void:
    # _build_original_far_scene() registers the instance it created for every
    # manifest entry.  Freeing that instance is exact: some static bakes name
    # their only mesh "fx_static" (every Rooftops FX entry does), so matching by
    # node name would be ambiguous, and a missing entry is a harmless no-op.
    var instance: Node = _far_entry_instances.get(entry_name)
    if instance == null or not is_instance_valid(instance):
        return
    _far_entry_instances.erase(entry_name)
    instance.queue_free()


func _is_skydome_entry(entry: Dictionary) -> bool:
    # Manifests may rename the entry to dodge older loaders; the explicit role,
    # the original visual name and the mesh file name all keep this data-driven.
    if String(entry.get("role", "")).to_lower() == "skydome":
        return true
    for key: String in ["name", "file", "source_name", "source_visual"]:
        if "skydome" in String(entry.get(key, "")).to_lower():
            return true
    return false


func _make_skydome_material(entry: Dictionary, base: String) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(0.42, 0.52, 0.66, 1.0)
    material.roughness = 1.0
    var texture_name: String = String(entry.get("texture", ""))
    if not texture_name.is_empty():
        var texture_path: String = base.path_join(texture_name)
        if FileAccess.file_exists(texture_path):
            var image: Image = Image.new()
            if image.load(texture_path) == OK:
                material.albedo_texture = ImageTexture.create_from_image(image)
                material.albedo_color = Color.WHITE
    # The authored sky blend mode is "none": keep the dome opaque.
    material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
    material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
    # A sky is not lit by the arena light and never receives shadows.
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.disable_receive_shadows = true
    var authored_cull: String = ""
    if entry.get("material") is Dictionary:
        authored_cull = String(
            (entry["material"] as Dictionary).get("cull_mode", "")
        ).to_lower()
    match authored_cull:
        "front":
            material.cull_mode = BaseMaterial3D.CULL_FRONT
        "back":
            material.cull_mode = BaseMaterial3D.CULL_BACK
        _:
            # A sky dome is seen from the inside; the manifest does not carry a
            # winding guarantee, so render both sides rather than a black sky.
            material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material


func _apply_original_sky() -> void:
    if _world_environment == null:
        return
    var path: String = OS.get_executable_path().get_base_dir().path_join(
        "scene/far/43065bc82b9e537df7e860c053971940671c739f.png"
    )
    if not FileAccess.file_exists(path):
        return
    var image: Image = Image.new()
    if image.load(path) != OK:
        return
    var texture: ImageTexture = ImageTexture.create_from_image(image)
    var panorama: PanoramaSkyMaterial = PanoramaSkyMaterial.new()
    panorama.panorama = texture
    var sky: Sky = Sky.new()
    sky.sky_material = panorama
    _world_environment.environment.sky = sky
    _world_environment.environment.background_mode = Environment.BG_SKY


func _build_game_text_overlay() -> void:
    _game_text_layer = CanvasLayer.new()
    _game_text_layer.layer = 15
    add_child(_game_text_layer)
    # The archive gametext texels are stored so that the shipped ui/gametext PNG
    # reads mirrored (e.g. "TIME IS UP" appears horizontally reversed and the
    # glyph rows are flipped). A vertical flip makes them read correctly and
    # upright; the four-flip probe confirms flip_v alone is the fix. This is
    # applied by default and can be disabled with BRUCELEE_GAME_TEXT_FLIP=0 for
    # an already-corrected source.  See _game_text_flip_enabled().
    var roots: Array[String] = []
    var env_root: String = OS.get_environment("BRUCELEE_GAME_TEXT_ROOT")
    if not env_root.is_empty():
        roots.append(env_root)
    roots.append(OS.get_executable_path().get_base_dir().path_join("ui/gametext"))
    var local_app_data: String = OS.get_environment("LOCALAPPDATA")
    if not local_app_data.is_empty():
        roots.append(local_app_data.path_join(
            "BruceLee-PC-Port/local-assets/gui/images/gametext"
        ))
    for key: String in ["READY", "FIGHT", "YOU_WIN", "YOU_LOSE", "TIME_IS_UP", "DRAW", "PERFECT", "GREAT", "COUNTER"]:
        var filename: String = "BL_gameText-%s.png" % key
        for root: String in roots:
            var path: String = root.path_join(filename)
            if not FileAccess.file_exists(path):
                continue
            var image: Image = Image.new()
            if image.load(path) == OK:
                _game_text_textures[key] = ImageTexture.create_from_image(image)
                break
    # Original ingamesprites.list: 11 animation records, 9 textures.  The
    # record carries per-step x/y, size and alpha; the renderer below uses the
    # same sequence instead of a single fixed position.  Records are keyed by
    # the recovered index: COUNTER 7/8 and GREAT 9/10 share textures, so a
    # texture-name key silently dropped records 8 and 10.
    for root: String in roots:
        var animations_path: String = root.path_join("ingamesprites_animations.json")
        if not FileAccess.file_exists(animations_path):
            continue
        var parsed_animations: Variant = JSON.parse_string(
            FileAccess.get_file_as_string(animations_path)
        )
        if not parsed_animations is Dictionary:
            continue
        var records: Variant = Dictionary(parsed_animations).get("animations", [])
        if not records is Array:
            continue
        for record_value: Variant in records:
            if not record_value is Dictionary:
                continue
            var record: Dictionary = record_value
            var index: int = int(record.get("index", -1))
            var sprite_path: String = String(record.get("sprite_path", ""))
            var sprite_key: String = sprite_path.get_file().get_basename()
            sprite_key = sprite_key.trim_prefix("bl_gametext-").to_upper()
            var steps: Variant = record.get("steps", [])
            if index < 0 or sprite_key.is_empty() or not steps is Array:
                continue
            _game_text_sequences[index] = {
                "sprite_key": sprite_key,
                "steps": steps,
                # Recovered per-record commentator sample(s): [{sample, time}].
                # The audio is launched with the exact game-text record, not by
                # a separate threshold.
                "sounds": record.get("sounds", []),
            }
        break
    # Keep the first overlay alive so tests/debug helpers can always read
    # `_game_text_rect`.
    if _game_text_overlays.is_empty():
        _acquire_game_text_overlay()
    var hold: String = OS.get_environment("BRUCELEE_HOLD_GAME_TEXT")
    if not hold.is_empty():
        _show_game_text(hold, 30.0)


func _game_text_flip_enabled() -> bool:
    return OS.get_environment("BRUCELEE_GAME_TEXT_FLIP") != "0"


func _game_text_base_scale() -> float:
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    return viewport_size.x / GAME_TEXT_NATIVE_DISPLAY_WIDTH


func _acquire_game_text_overlay() -> Dictionary:
    for overlay in _game_text_overlays:
        if not bool(overlay["active"]):
            return overlay
    if _game_text_overlays.size() < GAME_TEXT_MAX_OVERLAYS:
        var rect: Sprite2D = Sprite2D.new()
        rect.flip_h = false
        rect.flip_v = _game_text_flip_enabled()
        rect.visible = false
        _game_text_layer.add_child(rect)
        var overlay: Dictionary = {
            "rect": rect,
            "active": false,
            "key": "",
            "sequence": -1,
            "steps": [] as Array,
            "step_index": 0,
            "step_time": 0.0,
            "from": {} as Dictionary,
            "to": {} as Dictionary,
            "timer": 0.0,
        }
        _game_text_overlays.append(overlay)
        if _game_text_rect == null:
            _game_text_rect = rect
        return overlay
    # Every overlay is busy: reuse the one closest to finishing (the native
    # animator pool has no such limit, but LaunchGameTextAnimation never runs
    # more than three sequences at once in the recovered call sites).
    var oldest: Dictionary = _game_text_overlays[0]
    for overlay in _game_text_overlays:
        if float(overlay["timer"]) < float(oldest["timer"]):
            oldest = overlay
    return oldest


func _show_game_text(key: String, duration: float, sequence: int = -1) -> void:
    if not _game_text_textures.has(key):
        return
    var steps: Array = []
    var record_matched: bool = false
    if sequence >= 0:
        if _game_text_sequences.has(sequence):
            var record: Dictionary = _game_text_sequences[sequence]
            var record_key: String = String(record.get("sprite_key", ""))
            if record_key == key:
                record_matched = true
                var recovered: Variant = record.get("steps", [])
                if recovered is Array:
                    steps = recovered
            else:
                push_warning(
                    "game text sequence %d is bound to %s, not %s"
                    % [sequence, record_key, key]
                )
        else:
            push_warning("game text sequence %d was not loaded" % sequence)
    else:
        # Legacy callers pass only the texture key; fall back to the first
        # record with that texture.  COUNTER/GREAT callers must pass the
        # recovered index because 7/8 and 9/10 share textures.
        for record_value: Variant in _game_text_sequences.values():
            if record_value is Dictionary and String(record_value.get("sprite_key", "")) == key:
                var fallback: Variant = Dictionary(record_value).get("steps", [])
                if fallback is Array:
                    steps = fallback
                break
    var overlay: Dictionary = _acquire_game_text_overlay()
    var rect: Sprite2D = overlay["rect"]
    rect.texture = _game_text_textures[key]
    rect.visible = true
    overlay["active"] = true
    overlay["key"] = key
    overlay["sequence"] = sequence
    overlay["steps"] = steps
    overlay["step_index"] = 0
    overlay["step_time"] = 0.0
    overlay["timer"] = duration
    if steps.is_empty():
        overlay["from"] = {}
        overlay["to"] = {}
        rect.position = get_viewport().get_visible_rect().size * Vector2(0.5, 0.42)
        rect.scale = Vector2.ONE * _game_text_base_scale()
        rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
    else:
        overlay["from"] = steps[0]
        overlay["to"] = steps[1] if steps.size() > 1 else steps[0]
        var total: float = 0.0
        for step_value: Variant in steps:
            if step_value is Dictionary:
                total += float(Dictionary(step_value).get("duration", 0.0))
        overlay["timer"] = maxf(duration, total + 0.1)
        _apply_game_text_step(overlay, 0.0)
    # The recovered record owns its commentator sample and the offset at which
    # the native animator plays it.  Schedule from this launch only: an
    # unmatched/legacy key (sequence -1) stays silent rather than guessing.
    var sample_plan: Array = []
    if record_matched:
        sample_plan = _game_text_sample_plan(sequence)
    overlay["samples"] = sample_plan
    overlay["sample_elapsed"] = 0.0
    game_text_launch_log.append({"key": key, "sequence": sequence})
    if game_text_launch_log.size() > 64:
        game_text_launch_log.pop_front()
    # Fire zero-offset samples at launch time, exactly once.
    _update_game_text_samples(overlay, 0.0)


func _game_text_sample_plan(sequence: int) -> Array:
    ## Recovered `sounds` array of one ingamesprites.list record, resolved to
    ## AudioCueMap keys.  No thresholds, offsets or filenames are invented: the
    ## record carries `sample` and `time` verbatim.
    var plan: Array = []
    if sequence < 0 or not _game_text_sequences.has(sequence):
        return plan
    var record: Dictionary = _game_text_sequences[sequence]
    var sounds: Variant = record.get("sounds", [])
    if not sounds is Array:
        return plan
    for sound_value: Variant in sounds:
        if not sound_value is Dictionary:
            continue
        var sound: Dictionary = sound_value
        var sample: String = String(sound.get("sample", ""))
        if sample.is_empty():
            continue
        var key: String = _commentator_key_for_sample(sample)
        if key.is_empty():
            push_warning("game text sequence %d sample is not in the cue map: %s"
                    % [sequence, sample])
            continue
        plan.append({
            "key": key,
            "time": float(sound.get("time", 0.0)),
            "sample": sample,
        })
    return plan


func _commentator_key_for_sample(sample: String) -> String:
    ## maps e.g. "sounds/commentator_voice/you_win.wav" to the cue-map key
    ## ("win") by comparing the recovered archive filename with COMMENTATOR.
    var filename: String = sample.get_file()
    for key: String in AudioCueMap.COMMENTATOR:
        if String(AudioCueMap.COMMENTATOR[key]).nocasecmp_to(filename) == 0:
            return key
    return ""


func _update_game_text_samples(overlay: Dictionary, delta: float) -> void:
    ## Advance this launch's recovered sample clock.  Each pending entry plays
    ## once and is removed, so repeated frames cannot double-fire a cue.
    var plan_value: Variant = overlay.get("samples", [])
    if not plan_value is Array:
        return
    var plan: Array = plan_value
    if plan.is_empty():
        return
    overlay["sample_elapsed"] = float(overlay.get("sample_elapsed", 0.0)) + delta
    var elapsed: float = float(overlay["sample_elapsed"])
    while not plan.is_empty():
        var entry: Dictionary = plan[0]
        if float(entry.get("time", 0.0)) > elapsed + 0.0001:
            break
        plan.pop_front()
        var key: String = String(entry.get("key", ""))
        if key.is_empty():
            continue
        _play_result_audio(
            key,
            int(overlay.get("sequence", -1)),
            String(entry.get("sample", "")),
        )


func _apply_game_text_step(overlay: Dictionary, t: float) -> void:
    var from: Dictionary = overlay["from"]
    var to: Dictionary = overlay["to"]
    var x: float = lerpf(float(from.get("x", 0.5)), float(to.get("x", 0.5)), t)
    var y: float = lerpf(float(from.get("y", 0.5)), float(to.get("y", 0.5)), t)
    var size: float = lerpf(float(from.get("size", 1.0)), float(to.get("size", 1.0)), t)
    var alpha: float = lerpf(float(from.get("alpha", 1.0)), float(to.get("alpha", 1.0)), t)
    var rect: Sprite2D = overlay["rect"]
    rect.position = get_viewport().get_visible_rect().size * Vector2(x, y)
    # CSpriteAnimator::Update: drawn width = step size * texture width in
    # display pixels; the texture carries its own colours (no tint).
    rect.scale = Vector2.ONE * (_game_text_base_scale() * size)
    rect.modulate = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))


func _update_game_text_sequence(delta: float) -> void:
    for overlay in _game_text_overlays:
        if not bool(overlay["active"]):
            continue
        _update_game_text_samples(overlay, delta)
        var rect: Sprite2D = overlay["rect"]
        var steps: Array = overlay["steps"]
        if not steps.is_empty():
            var current: Dictionary = steps[int(overlay["step_index"])]
            var step_duration: float = float(current.get("duration", 0.0))
            overlay["step_time"] = float(overlay["step_time"]) + delta
            var t: float = 1.0 if step_duration <= 0.0 else minf(
                1.0, float(overlay["step_time"]) / step_duration
            )
            _apply_game_text_step(overlay, t)
            if t >= 1.0:
                var next_index: int = int(overlay["step_index"]) + 1
                if next_index >= steps.size():
                    overlay["active"] = false
                    rect.visible = false
                    continue
                overlay["step_index"] = next_index
                overlay["from"] = current
                overlay["to"] = steps[next_index]
                overlay["step_time"] = 0.0
        overlay["timer"] = float(overlay["timer"]) - delta
        if float(overlay["timer"]) <= 0.0:
            overlay["active"] = false
            rect.visible = false


func _hide_game_text_overlays() -> void:
    for overlay in _game_text_overlays:
        overlay["active"] = false
        overlay["timer"] = 0.0
        # A stopped animator does not play its remaining sample.
        overlay["samples"] = []
        var rect: Sprite2D = overlay["rect"]
        rect.visible = false


func _build_fighters() -> void:
    player = PortFighter.new()
    player.configure("Bruce (placeholder)", true, Color(0.85, 0.56, 0.18))
    player.polar_movement_enabled = true
    player.configure_candidate_asset(
        OS.get_environment("BRUCELEE_PLAYER_GLB"),
        OS.get_environment("BRUCELEE_PLAYER_TEXTURE_ROOT"),
        PortFighter.CANDIDATE_CLIPS,
        "body_hair"
    )
    player.set_skeleton_class(_player_skeleton_class())
    add_child(player)
    computer = PortFighter.new()
    computer.configure("Opponent (placeholder)", false, Color(0.20, 0.65, 0.76))
    computer.configure_attack_config(_opponent_attack_config())
    var opponent_material_profile: String = OS.get_environment(
        "BRUCELEE_OPPONENT_MATERIAL_PROFILE"
    )
    if opponent_material_profile.is_empty():
        opponent_material_profile = "body"
    computer.configure_candidate_asset(
        OS.get_environment("BRUCELEE_OPPONENT_GLB"),
        OS.get_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT"),
        _opponent_clips(),
        opponent_material_profile,
        false
    )
    computer.set_skeleton_class(_opponent_skeleton_class())
    player.configure_result_clips(_player_result_clips())
    computer.configure_result_clips(_opponent_result_clips())
    add_child(computer)
    player.opponent = computer
    computer.opponent = player
    player.combat_ko.connect(_on_ko)
    computer.combat_ko.connect(_on_ko)
    player.combat_hit.connect(_on_hit)
    computer.combat_hit.connect(_on_hit)
    player.attack_started.connect(_on_player_attack_started)
    computer.attack_started.connect(_on_opponent_attack_started)

func _opponent_attack_config() -> String:
    ## The opponent's fighting set decides the clip table and the move data.
    ## BRUCELEE_OPPONENT_ATTACK_CONFIG is written by the opponent menu; the
    ## clip-prefix / master fallbacks keep the older launchers working.
    var configured: String = OS.get_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG")
    if not configured.is_empty():
        return configured
    if OS.get_environment("BRUCELEE_OPPONENT_MASTER") == "1":
        return PortFighter.MASTER_ATTACK_CONFIG_PATH
    var prefix: String = OS.get_environment("BRUCELEE_OPPONENT_CLIP_PREFIX")
    if prefix == "m04":
        return PortFighter.SINFU_ATTACK_CONFIG_PATH
    if prefix == "m02":
        return PortFighter.KEN_ATTACK_CONFIG_PATH
    return PortFighter.BRICK_ATTACK_CONFIG_PATH


func _opponent_ai_profile_key() -> String:
    match _opponent_attack_config():
        PortFighter.SINFU_ATTACK_CONFIG_PATH:
            return "sin fu"
        PortFighter.MASTER_ATTACK_CONFIG_PATH:
            return "the master"
        PortFighter.KEN_ATTACK_CONFIG_PATH:
            return "ken godall"
        PortFighter.SHENLO_ATTACK_CONFIG_PATH:
            return "shen lo"
        PortFighter.SMALLBOY_ATTACK_CONFIG_PATH:
            return "smallboy"
        PortFighter.JOHNSON_ATTACK_CONFIG_PATH:
            return "johnson"
        PortFighter.CHIEF_ATTACK_CONFIG_PATH:
            return "chief a"
        PortFighter.LOMING_ATTACK_CONFIG_PATH:
            return "lo ming a"
        _:
            return "brick davis"


func _opponent_display_name() -> String:
    ## Opponent menu command = characters.list key for the packaged name
    ## textures. Direct launchers still resolve by their fighting-set config.
    var key: String = OS.get_environment("BRUCELEE_OPPONENT_NAME_KEY")
    if key.is_empty() or key == "opponents_back":
        match _opponent_attack_config():
            PortFighter.SINFU_ATTACK_CONFIG_PATH:
                key = "sinfu"
            PortFighter.MASTER_ATTACK_CONFIG_PATH:
                key = "themaster"
            PortFighter.KEN_ATTACK_CONFIG_PATH:
                key = "kengodall"
            PortFighter.SHENLO_ATTACK_CONFIG_PATH:
                key = "shenlo"
            PortFighter.SMALLBOY_ATTACK_CONFIG_PATH:
                key = "smallboy"
            PortFighter.JOHNSON_ATTACK_CONFIG_PATH:
                key = "johnson"
            PortFighter.CHIEF_ATTACK_CONFIG_PATH:
                key = "chief"
            PortFighter.LOMING_ATTACK_CONFIG_PATH:
                key = "loming"
            _:
                key = "brickdavis"
    match key.to_lower():
        "sinfu": return "SIN FU"
        "themaster", "master": return "THE MASTER"
        "kengodall", "ken": return "KEN GODALL"
        "shenlo": return "SHEN LO"
        "smallboy": return "SMALL BOY"
        "johnson": return "JOHNSON"
        "chief": return "CHIEF"
        "loming": return "LO MING"
        _: return "BRICK DAVIS"
func _player_skeleton_class() -> String:
    ## Bruce Lee's four skins are all "medium" in characters.list. The env
    ## override exists so a test can hold the body fixed and vary the class the
    ## size-variant table keys on.
    var configured: String = OS.get_environment("BRUCELEE_PLAYER_SKELETON")
    if configured.is_empty():
        return PLAYER_SKELETON_DEFAULT
    return configured


func _opponent_skeleton_class() -> String:
    ## characters.list "skeleton" of the selected opponent. An explicit env
    ## value wins; otherwise the fighting-set config identifies the character.
    var configured: String = OS.get_environment("BRUCELEE_OPPONENT_SKELETON")
    if not configured.is_empty():
        return configured
    var table: Dictionary = MENU_OPPONENT_CONFIG
    for key: Variant in table:
        var entry: Variant = table[key]
        if not entry is Dictionary:
            continue
        if String(Dictionary(entry).get("attack_config", "")) == _opponent_attack_config():
            var declared: String = String(Dictionary(entry).get("skeleton", ""))
            if not declared.is_empty():
                return declared
    return String(
        ATTACK_CONFIG_SKELETON.get(_opponent_attack_config(), PLAYER_SKELETON_DEFAULT)
    )


func _opponent_clips() -> Dictionary:
    var config_path: String = _opponent_attack_config()
    if config_path == PortFighter.MASTER_ATTACK_CONFIG_PATH:
        return PortFighter.MASTER_CLIPS
    if config_path == PortFighter.SINFU_ATTACK_CONFIG_PATH:
        return PortFighter.SINFU_CLIPS
    if config_path == PortFighter.SHENLO_ATTACK_CONFIG_PATH:
        return PortFighter.SHENLO_CLIPS
    if config_path == PortFighter.KEN_ATTACK_CONFIG_PATH:
        return PortFighter.KEN_CLIPS
    if config_path == PortFighter.SMALLBOY_ATTACK_CONFIG_PATH:
        return PortFighter.SMALLBOY_CLIPS
    if config_path == PortFighter.JOHNSON_ATTACK_CONFIG_PATH:
        return PortFighter.JOHNSON_CLIPS
    if config_path == PortFighter.CHIEF_ATTACK_CONFIG_PATH:
        return PortFighter.CHIEF_CLIPS
    if config_path == PortFighter.LOMING_ATTACK_CONFIG_PATH:
        return PortFighter.LOMING_CLIPS
    return PortFighter.BRICK_CLIPS


func _player_result_clips() -> Dictionary:
    ## Bruce Lee a..d share one animations table in characters.list:
    ## victory [m01_victory_01, m01_victory_02], defeat [m01_defeat_01].
    return PortFighter.RESULT_CLIPS_BRUCELEE


func _opponent_result_clips() -> Dictionary:
    ## Same character keying as _opponent_clips(): the fighting-set config path
    ## identifies the fighter and characters.list gives its animations.victory /
    ## animations.defeat lists.
    var config_path: String = _opponent_attack_config()
    if config_path == PortFighter.MASTER_ATTACK_CONFIG_PATH:
        return PortFighter.RESULT_CLIPS_MASTER
    if config_path == PortFighter.SINFU_ATTACK_CONFIG_PATH:
        return PortFighter.RESULT_CLIPS_SINFU
    if config_path == PortFighter.SHENLO_ATTACK_CONFIG_PATH:
        return PortFighter.RESULT_CLIPS_SHENLO
    if config_path == PortFighter.KEN_ATTACK_CONFIG_PATH:
        return PortFighter.RESULT_CLIPS_KEN
    if config_path == PortFighter.SMALLBOY_ATTACK_CONFIG_PATH:
        return PortFighter.RESULT_CLIPS_SMALLBOY
    if config_path == PortFighter.JOHNSON_ATTACK_CONFIG_PATH:
        return PortFighter.RESULT_CLIPS_JOHNSON
    if config_path == PortFighter.CHIEF_ATTACK_CONFIG_PATH:
        return PortFighter.RESULT_CLIPS_CHIEF
    if config_path == PortFighter.LOMING_ATTACK_CONFIG_PATH:
        return PortFighter.RESULT_CLIPS_LOMING
    return PortFighter.RESULT_CLIPS_BRICK


func _zmath_random_get() -> int:
    ## zmathRandomGet(): state = state * 0x41C64E6D + 0x3039, return bits 16..31.
    _zmath_state = (_zmath_state * 0x41C64E6D + 0x3039) & 0xFFFFFFFF
    return (_zmath_state >> 16) & 0xFFFF


func _select_match_result_clips() -> void:
    ## StartFight() -> CBeatEmUpGameModes::SetCurrentMatchConfig() ->
    ## IBeatEmUpGameMode::SetFighterConfigFromCharacterList(), which runs once
    ## per match and draws the intro version before the victory version. The
    ## port has no intro animation, but it still consumes that draw so the
    ## victory index follows the native draw order.
    for fighter: PortFighter in [player, computer]:
        if fighter == null:
            continue
        _zmath_random_get()
        fighter.select_result_clips(_zmath_random_get())


func _configure_round_time() -> void:
    # Round length comes from the match config in the original
    # (CBeatEmUpMatch::LoadProcessBegin -> SetTimerMax).  A value of 0 means
    # "no time limit": LoadProcessBegin sets game+0x814/0x628 and the HUD
    # then shows the fixed no-timer text instead of a countdown.
    var setting: String = OS.get_environment("BRUCELEE_ROUND_TIME")
    round_time_max = ROUND_TIME_DEFAULT
    if setting.is_valid_int():
        round_time_max = maxi(0, setting.to_int())


func _reset_match() -> void:
    round_number = 1
    player_rounds = 0
    computer_rounds = 0
    match_over = false
    round_reset_timer = -1.0
    pending_round_winner = 0
    _result_pose_seconds = 0.0
    # StartFight() builds the match configuration once per match, so the
    # result clips are re-drawn here and not in _reset_round().
    _select_match_result_clips()
    _result_camera_override = false
    _reset_round()


func _reset_round() -> void:
    var demo_close: bool = OS.get_environment("BRUCELEE_DEMO_CLOSE") == "1"
    var player_x: float = -0.25 if training_mode else (-0.75 if demo_close else -2.0)
    var computer_x: float = 0.25 if training_mode else (0.75 if demo_close else 2.0)
    player.reset_fighter(Vector3(player_x, 1.20, 0.0))
    computer.reset_fighter(Vector3(computer_x, 1.20, 0.0))
    # `player_starting_health` applies to the start of the fight (round 1); later
    # rounds keep the native RestartValues() behaviour.  The native semantics of
    # this recovered field were not recovered beyond its name.
    if player_start_health_override > 0.0 and round_number == 1:
        player.health = player_start_health_override
    # SetState(12/13) hides the loser; a reset must restore both bodies.
    player.visible = true
    computer.visible = true
    player.clear_result_pose()
    computer.clear_result_pose()
    _camera_anm_end()
    _action_camera_end()
    # Native RestartValues() does not stop running game text animators, so a
    # round reset must not hide the result text either; only the per-side
    # COUNTER animation memory is cleared.
    _counter_text_last_state = ["", ""]
    var demo_rage: String = OS.get_environment("BRUCELEE_DEMO_RAGE")
    if not demo_rage.is_empty() and demo_rage.is_valid_float():
        player.rage = clampf(demo_rage.to_float(), 0.0, PortFighter.RAGE_MAX)
    if training_mode:
        computer._enter_locomotion_state("facedownidle")
        computer._animate_candidate()
    done = false
    training_completed = false
    elapsed = 0.0
    ai_timer = 0.75
    ai_guard_sequence = -1
    ai_guard_decision = false
    notice_timer = 1.2
    round_reset_timer = -1.0
    # CFighter::Restart -> RestartValues -> SetState(0): a fresh round enters
    # the round-intro path, not the result path. _reset_match is also used by
    # the R key and by validators, which expect a controllable fight at once.
    match_state = MATCH_STATE_FIGHT
    match_state_time = 0.0
    pending_round_winner = 0
    _round_end_handled = false
    _intro_fight_shown = false
    _result_pose_seconds = 0.0
    _result_camera_override = false
    hud.set_round(round_number, player_rounds, computer_rounds, training_mode)
    # CFighter::Restart puts the clock back to the round limit every round;
    # training has no match clock.
    round_time_active = (not training_mode) and round_time_max > 0
    round_time_left = round_time_max if round_time_active else 0
    hud.set_time(round_time_left, round_time_active)
    hud.show_message(
        "TRAINING · K L L / K U U" if training_mode
        else "ROUND %d · FIGHT" % round_number
    )
    _restart_fight_camera()
    _update_fight_camera()


func _start_next_round() -> void:
    round_number += 1
    _reset_round()
    _start_round_intro()

func _should_show_main_menu() -> bool:
    var setting: String = OS.get_environment("BRUCELEE_MAIN_MENU")
    if setting == "1":
        return true
    if setting == "0":
        return false
    return not OS.has_feature("editor")

func _open_main_menu() -> void:
    _play_music("menu")
    main_menu_active = true
    menu_paused = false
    player.move_axis = Vector2.ZERO
    computer.move_axis = Vector2.ZERO
    hud.visible = false
    prototype_menu.show_main_menu()
    get_tree().paused = true

func _open_pause_menu() -> void:
    if story_flow != null:
        # The story flow owns pause while a story battle (or a story screen) runs.
        story_flow.show_pause("battle")
        return
    if game_modes != null and String(game_modes.get("screen")) == "battle":
        # The arcade/survival/time-attack flow owns pause during a mode fight.
        game_modes.show_pause("battle")
        return
    menu_paused = true
    player.move_axis = Vector2.ZERO
    computer.move_axis = Vector2.ZERO
    hud.visible = true
    prototype_menu.show_pause_menu()
    get_tree().paused = true

func _leave_menu() -> void:
    main_menu_active = false
    menu_paused = false
    hud.visible = true
    prototype_menu.hide_menu()
    get_tree().paused = false

func _on_menu_command(command: String) -> void:
    var confirm_attack: bool = (
        prototype_menu != null and prototype_menu.last_accept_was_attack
    )
    if prototype_menu != null:
        prototype_menu.last_accept_was_attack = false
    if command in ["fight", "training", "move_training", "gallery"]:
        _play_music("fight")
    match command:
        "fight":
            training_mode = false
            _leave_menu()
            _reset_match()
            _start_round_intro()
        "arcade", "survival", "timeattack":
            training_mode = false
            _leave_menu()
            hud.visible = false
            game_modes.open_mode(command)
        "move_training":
            training_mode = false
            _leave_menu()
            hud.visible = false
            move_training.open()
        "gallery":
            training_mode = false
            _leave_menu()
            hud.visible = false
            move_gallery.open()
        "training":
            if _training_available():
                training_mode = true
                _leave_menu()
                _reset_match()
                _start_round_intro()
            else:
                prototype_menu.show_error("TRAINING NEEDS CANDIDATE ANIMATIONS")
        "resume":
            _leave_menu()
        "restart":
            _leave_menu()
            _reset_match()
        "main_menu":
            _open_main_menu()
        "temple_a":
            OS.set_environment("BRUCELEE_SCENE", "")
            OS.set_environment("BRUCELEE_MAIN_MENU", "0")
            get_tree().reload_current_scene()
        "temple_b":
            OS.set_environment("BRUCELEE_SCENE", "templeyardb")
            OS.set_environment("BRUCELEE_MAIN_MENU", "0")
            get_tree().reload_current_scene()
        "halla":
            OS.set_environment("BRUCELEE_SCENE", "halla")
            OS.set_environment("BRUCELEE_MAIN_MENU", "0")
            get_tree().reload_current_scene()
        "squareb":
            OS.set_environment("BRUCELEE_SCENE", "squareb")
            OS.set_environment("BRUCELEE_MAIN_MENU", "0")
            get_tree().reload_current_scene()
        "harboura":
            OS.set_environment("BRUCELEE_SCENE", "harboura")
            OS.set_environment("BRUCELEE_MAIN_MENU", "0")
            get_tree().reload_current_scene()
        "squarea":
            OS.set_environment("BRUCELEE_SCENE", "squarea")
            OS.set_environment("BRUCELEE_MAIN_MENU", "0")
            get_tree().reload_current_scene()
        "harbourb":
            OS.set_environment("BRUCELEE_SCENE", "harbourb")
            OS.set_environment("BRUCELEE_MAIN_MENU", "0")
            get_tree().reload_current_scene()
        "rooftopsa":
            OS.set_environment("BRUCELEE_SCENE", "rooftopsa")
            OS.set_environment("BRUCELEE_MAIN_MENU", "0")
            get_tree().reload_current_scene()
        "rooftopsb":
            OS.set_environment("BRUCELEE_SCENE", "rooftopsb")
            OS.set_environment("BRUCELEE_MAIN_MENU", "0")
            get_tree().reload_current_scene()
        "tournamenthallb":
            OS.set_environment("BRUCELEE_SCENE", "tournamenthallb")
            OS.set_environment("BRUCELEE_MAIN_MENU", "0")
            get_tree().reload_current_scene()
        "brick", "sinfu", "master", "ken", "shenlo", "smallboy", "johnson", "chief", "loming":
            _request_opponent_switch(command)
        "quit":
            get_tree().quit()

    if confirm_attack and command in ["fight", "training"]:
        call_deferred("_apply_menu_confirm_attack")


func _request_opponent_switch(command: String) -> void:
    ## Opponent entries rebuild the fighters with the selected candidate. Two
    ## things must happen before the reload:
    ##  1. leave the menu, because reloading while SceneTree.paused is set builds
    ##     the new scene inside a paused tree (everything freezes);
    ##  2. defer the reload, because this runs inside the menu's input/signal
    ##     callback and the menu being freed is the node currently dispatching
    ##     the event.
    _leave_menu()
    call_deferred("_apply_opponent_switch", command)


func _apply_opponent_switch(command: String) -> void:
    var config_value: Variant = MENU_OPPONENT_CONFIG.get(command)
    if not config_value is Dictionary:
        return
    var config: Dictionary = config_value
    OS.set_environment("BRUCELEE_OPPONENT_GLB", String(config.get("glb", "")))
    OS.set_environment(
        "BRUCELEE_OPPONENT_TEXTURE_ROOT", String(config.get("texture_root", ""))
    )
    OS.set_environment(
        "BRUCELEE_OPPONENT_CLIP_PREFIX", String(config.get("clip_prefix", ""))
    )
    OS.set_environment(
        "BRUCELEE_OPPONENT_MASTER", String(config.get("master", ""))
    )
    OS.set_environment(
        "BRUCELEE_OPPONENT_MATERIAL_PROFILE",
        String(config.get("material_profile", "body"))
    )
    OS.set_environment(
        "BRUCELEE_OPPONENT_ATTACK_CONFIG", String(config.get("attack_config", ""))
    )
    OS.set_environment(
        "BRUCELEE_OPPONENT_SKELETON", String(config.get("skeleton", ""))
    )
    OS.set_environment("BRUCELEE_OPPONENT_NAME_KEY", command)
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    get_tree().reload_current_scene()


func _apply_menu_confirm_attack() -> void:
    if player == null or not player.is_player:
        return
    var event: InputEventAction = InputEventAction.new()
    event.action = PrototypeControls.ATTACK_A
    event.pressed = true
    _handle_fighter_attack_input(
        player, event,
        PrototypeControls.ATTACK_A, PrototypeControls.ATTACK_B,
        PrototypeControls.ATTACK_C, PrototypeControls.ATTACK_D
    )


func _on_move_training_exit() -> void:
    hud.visible = true
    _open_main_menu()


func _on_move_gallery_exit() -> void:
    hud.visible = true
    _open_main_menu()


func _build_combat_audio() -> void:
    combat_audio = Node.new()
    combat_audio.name = "CombatAudio"
    add_child(combat_audio)
    var audio_root: String = OS.get_environment("BRUCELEE_AUDIO_ROOT")
    if audio_root.is_empty():
        var local_app_data: String = OS.get_environment("LOCALAPPDATA")
        if local_app_data.is_empty():
            return
        audio_root = local_app_data.path_join(
            "BruceLee-PC-Port/candidate-sfx-20261030/adreno_200/sounds/sfx"
        )
    for event: String in ["punch", "kick", "block"]:
        var audio_names: Dictionary = {
            "punch": "Punch_Body_Light_1.wav",
            "kick": "Kick_Body_Light_1.wav",
            "block": "Block_Arms_2.wav",
        }
        var filename: String = String(audio_names[event])
        var path: String = audio_root.path_join(filename)
        var error: String = CandidatePathGuard.external_path_error(
            path, "candidate audio"
        )
        if not error.is_empty():
            _candidate_audio_error[event] = error
            continue
        var stream: AudioStream = AudioStreamWAV.load_from_file(path)
        if stream == null:
            _candidate_audio_error[event] = "candidate audio failed to load: " + path
            continue
        _candidate_audio[event] = stream
    # Recovered 38-file impact/block library (package audio/sfx).  The legacy
    # three-stream candidate set stays as a fallback for the old validator.
    _load_combat_sfx()
    # Restore the original eager Bruce voice load (commit 013b55a): commit
    # 132ff62's whole-file churn moved the only call into the export self
    # test, which left validate_bruce_voice_audio failing at HEAD.
    _load_bruce_voice_audio()
    _load_music_library()


func _load_combat_sfx() -> void:
    ## Loads every original adreno_200/sounds/sfx WAV from the package.  The
    ## package copy is read directly (like audio/music and audio/commentator);
    ## CandidatePathGuard rejects exe-base-directory paths in template builds,
    ## so it is intentionally not used for shipped package assets.
    var roots: Array[String] = []
    var env_root: String = OS.get_environment("BRUCELEE_SFX_ROOT")
    if not env_root.is_empty():
        roots.append(env_root)
    roots.append(OS.get_executable_path().get_base_dir().path_join("audio/sfx"))
    var local_app_data: String = OS.get_environment("LOCALAPPDATA")
    if not local_app_data.is_empty():
        roots.append(local_app_data.path_join(
            "BruceLee-PC-Port/candidate-sfx-20261030/adreno_200/sounds/sfx"
        ))
    _sfx_audio.clear()
    _sfx_audio_error.clear()
    for filename: String in SfxMusicMap.SFX_FILES:
        var loaded: AudioStreamWAV = null
        var last_error: String = ""
        for root: String in roots:
            var path: String = root.path_join(filename)
            if not FileAccess.file_exists(path):
                continue
            var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
            if stream == null:
                last_error = "SFX failed to load: " + path
                continue
            loaded = stream
            break
        if loaded == null:
            if last_error.is_empty():
                last_error = "SFX not found in: " + ", ".join(roots)
            _sfx_audio_error[filename] = last_error
            continue
        _sfx_audio[filename] = loaded


func _sfx_ready() -> bool:
    return _sfx_audio.size() == SfxMusicMap.SFX_FILES.size()


func _music_roots() -> Array[String]:
    var roots: Array[String] = []
    var env_root: String = OS.get_environment("BRUCELEE_MUSIC_ROOT")
    if not env_root.is_empty():
        roots.append(env_root)
    roots.append(OS.get_executable_path().get_base_dir().path_join("audio/music"))
    var local_app_data: String = OS.get_environment("LOCALAPPDATA")
    if not local_app_data.is_empty():
        roots.append(local_app_data.path_join(
            "BruceLee-PC-Port/bruce-music-20261103"
        ))
    return roots


func _load_music_library() -> void:
    ## All 21 recovered tracks.  The archive layout (day/, night/, story/,
    ## misc/) is preserved; a flat <root>/<name>.wav fallback keeps the two
    ## files shipped by Current156 working without re-copying them.
    var roots: Array[String] = _music_roots()
    _music_streams.clear()
    _music_stream_paths.clear()
    for rel: String in SfxMusicMap.MUSIC_FILES:
        var filename: String = rel.get_file()
        for root: String in roots:
            var candidates: Array[String] = [
                root.path_join(rel),
                root.path_join(filename),
            ]
            var chosen: String = ""
            for path: String in candidates:
                if FileAccess.file_exists(path):
                    chosen = path
                    break
            if chosen.is_empty():
                continue
            var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(chosen)
            if stream == null:
                continue
            stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
            stream.loop_end = int(stream.get_length() * float(stream.mix_rate))
            _music_streams[rel] = stream
            _music_stream_paths[rel] = chosen
            break
    if _music_streams.is_empty():
        return
    _music_player = AudioStreamPlayer.new()
    _music_player.volume_db = -12.0
    _music_player.finished.connect(_music_player.play)
    combat_audio.add_child(_music_player)
    _play_music("menu")


func _play_music(key: String) -> void:
    if _music_player == null:
        return
    var rel: String = key
    if key == "menu":
        rel = SfxMusicMap.MENU_MUSIC
    elif key == "fight":
        rel = SfxMusicMap.scene_music(
            OS.get_environment("BRUCELEE_SCENE").to_lower()
        )
    if not _music_streams.has(rel):
        rel = key
    if not _music_streams.has(rel):
        return
    var stream: AudioStream = _music_streams[rel]
    if _music_player.stream == stream and _music_player.playing:
        _music_key = rel
        return
    _music_stream = stream
    _music_key = rel
    _music_player.stream = stream
    _music_player.play()


func _play_scene_music() -> void:
    var scene: String = OS.get_environment("BRUCELEE_SCENE").to_lower()
    var rel: String = SfxMusicMap.scene_music(scene)
    if rel.is_empty():
        rel = SfxMusicMap.MENU_MUSIC
    _play_music(rel)


## Story flow calls this with the recovered subevent `music.file`
## ("sounds/music/story/..."), so the original chapter cue is preserved.
func play_story_music(path: String) -> void:
    var rel: String = SfxMusicMap.story_music(path)
    if not rel.is_empty():
        _play_music(rel)


func play_map_music() -> void:
    _play_music(SfxMusicMap.MAP_MUSIC)


func play_menu_music() -> void:
    _play_music("menu")


func _load_result_audio() -> void:
    var roots: Array[String] = []
    var env_root: String = OS.get_environment("BRUCELEE_COMMENTATOR_ROOT")
    if not env_root.is_empty():
        roots.append(env_root)
    roots.append(OS.get_executable_path().get_base_dir().path_join("audio/commentator"))
    for root: String in roots:
        for key: String in ["win", "lose", "draw", "fight", "ready", "time_out", "great", "perfect"]:
            if _result_audio.has(key):
                continue
            var filename: String = String(AudioCueMap.COMMENTATOR.get(key, ""))
            if filename.is_empty():
                continue
            var path: String = root.path_join(filename)
            if not FileAccess.file_exists(path):
                continue
            var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
            if stream != null:
                _result_audio[key] = stream
                _result_audio_paths[key] = path


func _play_result_audio(key: String, sequence: int = -1, sample: String = "") -> void:
    ## Plays one recovered commentator cue and records the exact stream/asset it
    ## used.  The caller is the game-text sample schedule, so every launch owns
    ## at most one playback per recovered sample (no separate threshold path).
    if _result_audio.is_empty():
        _load_result_audio()
    var stream: AudioStream = _result_audio.get(key)
    if stream == null:
        return
    var player: AudioStreamPlayer = _acquire_result_player()
    if player == null:
        return
    player.stream = stream
    player.play()
    result_audio_play_count += 1
    result_audio_play_log.append({
        "key": key,
        "sequence": sequence,
        "sample": sample,
        "file": String(AudioCueMap.COMMENTATOR.get(key, "")),
        "path": String(_result_audio_paths.get(key, "")),
        "length_ms": int(round(stream.get_length() * 1000.0)),
    })
    if result_audio_play_log.size() > 64:
        result_audio_play_log.pop_front()


func _acquire_result_player() -> AudioStreamPlayer:
    ## Native starts an independent sound per LaunchGameTextAnimation call, so
    ## YOU_WIN (+0 s) and PERFECT (+1.5 s) must not cut each other off.  Grow a
    ## small pool first, then reuse round-robin; the recovered call sites never
    ## run more than three sequences at once.
    if not is_instance_valid(combat_audio):
        return null
    if _result_players.size() < RESULT_AUDIO_MAX_PLAYERS:
        var created: AudioStreamPlayer = AudioStreamPlayer.new()
        created.volume_db = 2.0
        combat_audio.add_child(created)
        _result_players.append(created)
        if _result_player == null:
            _result_player = created
        return created
    var reused: AudioStreamPlayer = _result_players[
        _result_player_cursor % _result_players.size()
    ]
    _result_player_cursor += 1
    reused.stop()
    return reused


func _start_round_intro() -> void:
    # SetState(3): both fighters idle at the fight-start positions, then
    # LaunchGameTextAnimation(0)/(1).  Update() state 3 leaves after 3000 ms.
    if training_mode:
        return
    if OS.get_environment("BRUCELEE_ROUND_INTRO") == "0":
        # Validators need a deterministic fight state without waiting on the
        # real-time intro coroutine; this is a test configuration, not a result
        # state.
        _enter_match_state(MATCH_STATE_FIGHT)
        done = false
        return
    _enter_match_state(MATCH_STATE_INTRO)
    _intro_camera_begin()
    _intro_fight_shown = false
    _show_game_text("READY", 0.8, GAME_TEXT_SEQ_READY)
    # Ready_Alt_1.wav is the recovered sample of game-text record 0 and is
    # scheduled by _show_game_text; do not play it a second time here.


func _load_bruce_voice_audio() -> void:
    var roots: Array[String] = []
    var env_root: String = OS.get_environment("BRUCELEE_VOICE_ROOT")
    if not env_root.is_empty():
        roots.append(env_root)
    var executable_root: String = OS.get_executable_path().get_base_dir().path_join(
        "audio/bruce_lee"
    )
    roots.append(executable_root)
    var local_app_data: String = OS.get_environment("LOCALAPPDATA")
    if not local_app_data.is_empty():
        roots.append(local_app_data.path_join(
            "BruceLee-PC-Port/bruce-voice-20261103/adreno_200/sounds/voices/bruce_lee"
        ))
    var voices: Dictionary = AudioCueMap.voice_files()
    for action: String in voices:
        var filename: String = String(voices[action])
        var loaded: AudioStream = null
        var last_error: String = ""
        for root: String in roots:
            var path: String = root.path_join(filename)
            var error: String = CandidatePathGuard.external_path_error(
                path, "Bruce voice audio"
            )
            if not error.is_empty():
                last_error = error
                continue
            var stream: AudioStream = AudioStreamWAV.load_from_file(path)
            if stream == null:
                last_error = "Bruce voice failed to load: " + path
                continue
            loaded = stream
            break
        if loaded == null:
            _voice_audio_error[action] = last_error
            continue
        _voice_audio[action] = loaded


func _load_voice_for_action(action: String) -> AudioStream:
    if _voice_audio.has(action):
        return _voice_audio[action] as AudioStream
    var voices: Dictionary = AudioCueMap.voice_files()
    if not voices.has(action):
        return null
    var roots: Array[String] = []
    var env_root: String = OS.get_environment("BRUCELEE_VOICE_ROOT")
    if not env_root.is_empty():
        roots.append(env_root)
    roots.append(OS.get_executable_path().get_base_dir().path_join("audio/bruce_lee"))
    var local_app_data: String = OS.get_environment("LOCALAPPDATA")
    if not local_app_data.is_empty():
        roots.append(local_app_data.path_join(
            "BruceLee-PC-Port/bruce-voice-20261103/adreno_200/sounds/voices/bruce_lee"
        ))
    var filename: String = String(voices[action])
    for root: String in roots:
        var path: String = root.path_join(filename)
        var error: String = CandidatePathGuard.external_path_error(path, "Bruce voice audio")
        if not error.is_empty():
            _voice_audio_error[action] = error
            continue
        var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
        if stream != null:
            _voice_audio[action] = stream
            return stream
    return null


func _on_player_attack_started(action: String) -> void:
    # Non-voice swing/step/clothing cues for the same original set action are
    # independent of the Bruce voice table (some actions have SFX but no voice).
    _play_attack_sfx(action)
    # Voice cue comes from the recovered fighting-set table. Actions that have
    # no original voice (parry, grounded attacks, grab misses) stay silent
    # instead of falling back to the punch grunt.
    var cue: Dictionary = AudioCueMap.primary_cue(action)
    if cue.is_empty():
        return
    var stream: AudioStream = _voice_audio.get(action)
    if stream == null:
        stream = _load_voice_for_action(action)
    if stream == null:
        return
    if is_instance_valid(_active_voice):
        _active_voice.stop()
        _active_voice.queue_free()
    var voice: AudioStreamPlayer = AudioStreamPlayer.new()
    voice.stream = stream
    voice.volume_db = linear_to_db(clampf(float(cue.get("volume", 1.0)), 0.001, 1.0))
    voice.finished.connect(voice.queue_free)
    combat_audio.add_child(voice)
    _active_voice = voice
    voice.play()


func _on_opponent_attack_started(action: String) -> void:
    # Only set-specific cues that exist in the opponent's own fighting set are
    # added here (currently KungFu faceupattack -> Clothing_2).  The player's
    # Bruce cue table is not applied to another character's animation.
    if not _sfx_ready():
        return
    var cues: Array = SfxMusicMap.set_cues(_opponent_set_family(), action)
    if cues.is_empty():
        return
    _play_sfx_cues(cues, "opponent_attack:" + action)


func _play_attack_sfx(action: String) -> void:
    if not _sfx_ready():
        return
    var cues: Array = SfxMusicMap.attack_cues(action)
    if cues.is_empty():
        return
    _play_sfx_cues(cues, "attack:" + action)


## Set reaction actions that carry a Bruce pain voice. Recovered from
## adreno_200/set/brucelee.set reaction records (impact*/specialpunchlowimpact
## `sounds` entries with is_voice=true); reactions with no original pain voice
## (impacthard*, low frontal hits, brutal left/right, block profiles) stay
## silent instead of inventing a cue. The defender's recorded
## last_reaction_source_action selects the cue, so the voice plays on the exact
## reaction action the set attaches it to.
const PAIN_VOICE_CUES: Dictionary = {
    "impactlightfrontmid": AudioCueMap.PAIN.light,
    "impactlightlefthigh": AudioCueMap.PAIN.light_high,
    "impactlightrighthigh": AudioCueMap.PAIN.light_high,
    "impactfacedown": AudioCueMap.PAIN.light,
    "impactfaceup": AudioCueMap.PAIN.light,
    "impacthardfrontmid": AudioCueMap.PAIN.heavy,
    "impactbrutalmid": AudioCueMap.PAIN.heavy,
    "specialpunchlowimpact": AudioCueMap.PAIN.heavy_special,
}

func _play_pain_voice(defender: PortFighter, action: String) -> void:
    # Only Bruce (the player fighter) has pain voice takes in the archive.
    if defender != player:
        return
    var reaction_action: String = defender.last_reaction_source_action
    var cue_name: String = ""
    if PAIN_VOICE_CUES.has(reaction_action):
        cue_name = String(PAIN_VOICE_CUES[reaction_action])
    elif action == "special_punch_low_hit":
        # The special punch low impact reaction is not recorded as its own
        # reaction source in the port; the set gives specialpunchlowimpact a
        # heavy pain voice, so map this single attack explicitly.
        cue_name = String(PAIN_VOICE_CUES.get("specialpunchlowimpact", ""))
    if cue_name.is_empty():
        return
    var stream: AudioStream = _voice_audio.get("__pain__" + cue_name)
    if stream == null:
        for root: String in _voice_roots():
            var path: String = root.path_join(cue_name)
            var error: String = CandidatePathGuard.external_path_error(
                path, "Bruce pain voice"
            )
            if not error.is_empty():
                continue
            stream = AudioStreamWAV.load_from_file(path)
            if stream != null:
                _voice_audio["__pain__" + cue_name] = stream
                break
    if stream == null:
        return
    if is_instance_valid(_active_voice):
        _active_voice.stop()
        _active_voice.queue_free()
    var voice: AudioStreamPlayer = AudioStreamPlayer.new()
    voice.stream = stream
    voice.volume_db = 4.0
    voice.finished.connect(voice.queue_free)
    combat_audio.add_child(voice)
    _active_voice = voice
    voice.play()


func _voice_roots() -> Array[String]:
    var roots: Array[String] = []
    var env_root: String = OS.get_environment("BRUCELEE_VOICE_ROOT")
    if not env_root.is_empty():
        roots.append(env_root)
    roots.append(OS.get_executable_path().get_base_dir().path_join("audio/bruce_lee"))
    var local_app_data: String = OS.get_environment("LOCALAPPDATA")
    if not local_app_data.is_empty():
        roots.append(local_app_data.path_join(
            "BruceLee-PC-Port/bruce-voice-20261103/adreno_200/sounds/voices/bruce_lee"
        ))
    return roots


func _play_hit_audio(
        action: String, blocked: bool, defender: PortFighter = null
) -> void:
    ## The defender's last reaction is the exact set action the original
    ## fighting set attaches its impact/block samples to.  Using it (rather
    ## than guessing from the attacker's port action) keeps head/body,
    ## light/heavy and block profiles on their own recovered files.
    if _sfx_ready() and defender != null:
        var reaction: String = defender.last_reaction_source_action
        var cues: Array = SfxMusicMap.action_cues(reaction)
        if cues.is_empty() and blocked:
            cues = SfxMusicMap.action_cues("highblock")
        if not cues.is_empty():
            var exit_frame: int = defender.last_reaction_exit_frame
            var filtered: Array = []
            for value: Variant in cues:
                if not value is Dictionary:
                    continue
                var cue_row: Dictionary = value
                if exit_frame < 0 or int(cue_row.get("frame", 0)) <= exit_frame + 2:
                    filtered.append(cue_row)
            if not filtered.is_empty():
                _play_sfx_cues(filtered, "reaction:" + reaction)
                return
    # Legacy fail-soft path: the three staged candidate WAVs, used only when
    # the 38-file package library is absent (editor runs / old validator).
    var event: String = ""
    if blocked:
        event = "block"
    elif action in [
            "punch", "high_punch", "high_punch2", "high_punch3",
            "low_punch2", "low_punch3", "special_punch_low_hit",
            "special_punch_high_hit", "parry_attack",
        ]:
        event = "punch"
    elif action in [
            "kick", "high_kick", "high_kick2", "high_kick3",
            "low_kick2", "low_kick3", "special_kick_low_hit",
            "special_kick_high",
        ]:
        event = "kick"
    else:
        return
    if not _candidate_audio.has(event):
        return
    var player: AudioStreamPlayer = AudioStreamPlayer.new()
    player.stream = _candidate_audio[event]
    player.finished.connect(player.queue_free)
    combat_audio.add_child(player)
    player.play()


func _play_sfx_cues(cues: Array, label: String) -> void:
    ## Frame values are the original 30 fps source frames, so a cue at f12 is
    ## scheduled 0.4 s after the event instead of being flattened to frame 0.
    for value: Variant in cues:
        if not value is Dictionary:
            continue
        var cue: Dictionary = value
        var file: String = String(cue.get("file", ""))
        if file.is_empty():
            continue
        var stream: AudioStream = _sfx_audio.get(file)
        if stream == null:
            continue
        var volume: float = clampf(float(cue.get("volume", 1.0)), 0.001, 1.0)
        var delay: float = maxf(float(cue.get("frame", 0)), 0.0) / 30.0
        if delay <= 0.0001:
            _spawn_sfx(stream, volume, label, file)
            continue
        get_tree().create_timer(delay).timeout.connect(
            _spawn_sfx.bind(stream, volume, label, file)
        )


func _spawn_sfx(
        stream: AudioStream, volume: float, label: String, file: String
) -> void:
    if not is_instance_valid(combat_audio):
        return
    var player: AudioStreamPlayer = AudioStreamPlayer.new()
    player.stream = stream
    player.volume_db = linear_to_db(volume)
    player.finished.connect(player.queue_free)
    combat_audio.add_child(player)
    player.play()
    _sfx_play_count += 1
    _sfx_play_log.append({
        "label": label,
        "file": file,
        "volume": volume,
    })
    if _sfx_play_log.size() > 128:
        _sfx_play_log.pop_front()


func _opponent_set_family() -> String:
    match _opponent_attack_config():
        PortFighter.ATTACK_CONFIG_PATH:
            return "brucelee"
        PortFighter.KEN_ATTACK_CONFIG_PATH:
            return "karate"
        PortFighter.CHIEF_ATTACK_CONFIG_PATH:
            return "karate"
        PortFighter.JOHNSON_ATTACK_CONFIG_PATH:
            return "thai"
        PortFighter.SMALLBOY_ATTACK_CONFIG_PATH:
            return "thai"
        PortFighter.BRICK_ATTACK_CONFIG_PATH:
            return "thai"
        PortFighter.MASTER_ATTACK_CONFIG_PATH:
            return "kungfu"
        PortFighter.SINFU_ATTACK_CONFIG_PATH:
            return "kungfu"
        PortFighter.SHENLO_ATTACK_CONFIG_PATH:
            return "kungfu"
        PortFighter.LOMING_ATTACK_CONFIG_PATH:
            return "kungfu"
        _:
            return "thai"


func _update_one_footstep(fighter: PortFighter, family: String, delta: float) -> void:
    if fighter == null or not is_instance_valid(fighter):
        return
    var moving: bool = (
        fighter.state == "idle"
        and fighter.move_axis.length() > 0.15
        and not done
    )
    if not moving:
        _footstep_accum[family] = 0.0
        return
    var accum: float = float(_footstep_accum.get(family, 0.0)) + delta
    var interval: float = 0.34
    if accum < interval:
        _footstep_accum[family] = accum
        return
    _footstep_accum[family] = accum - interval
    var cues: Array = SfxMusicMap.move_cues(family)
    if cues.is_empty():
        return
    var index: int = int(_footstep_index.get(family, 0)) % cues.size()
    _footstep_index[family] = index + 1
    var cue: Dictionary = cues[index]
    var file: String = String(cue.get("file", ""))
    var stream: AudioStream = _sfx_audio.get(file)
    if stream == null:
        return
    _spawn_sfx(
        stream, float(cue.get("volume", 0.5)),
        "footstep:" + family, file
    )


func _update_footsteps(delta: float) -> void:
    if not _sfx_ready():
        return
    _update_one_footstep(player, "brucelee", delta)
    _update_one_footstep(computer, _opponent_set_family(), delta)

func _stop_combat_audio() -> void:
    if is_instance_valid(combat_audio):
        for child: Node in combat_audio.get_children():
            var player: AudioStreamPlayer = child as AudioStreamPlayer
            if player != null:
                player.stop()
                player.stream = null
                if not player.is_queued_for_deletion():
                    player.queue_free()
    _candidate_audio.clear()
    _candidate_audio_error.clear()
    _sfx_audio.clear()
    _sfx_audio_error.clear()
    _sfx_play_log.clear()
    _music_streams.clear()
    _music_stream_paths.clear()
    _music_player = null
    _music_key = ""


func _await_combat_audio_idle(timeout_seconds: float = 2.0) -> void:
    if not is_instance_valid(combat_audio):
        return
    var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
    while combat_audio.get_child_count() > 0 and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame


func _exit_tree() -> void:
    _stop_combat_audio()
    combat_audio = null

func _process(_delta: float) -> void:
    _update_game_text_sequence(_delta)
    _update_player_key_status()
    _update_fight_camera(_delta)
    _update_footsteps(_delta)


func _update_player_key_status() -> void:
    # krm::CFighter::InputStatusCheck reads a held-key status vector; feed it
    # from the same PC bindings that produce the press events.
    if player == null:
        return
    var status: Dictionary = {
        "a": Input.is_action_pressed(PrototypeControls.ATTACK_A),
        "b": Input.is_action_pressed(PrototypeControls.ATTACK_B),
        "c": Input.is_action_pressed(PrototypeControls.ATTACK_C),
        "d": Input.is_action_pressed(PrototypeControls.ATTACK_D),
        "left": Input.is_action_pressed(PrototypeControls.MOVE_LEFT),
        "right": Input.is_action_pressed(PrototypeControls.MOVE_RIGHT),
        "up": Input.is_action_pressed(PrototypeControls.MOVE_UP),
        "down": Input.is_action_pressed(PrototypeControls.MOVE_DOWN),
        "guard": Input.is_action_pressed(PrototypeControls.GUARD),
    }
    var horizontal: float = Input.get_axis(
        PrototypeControls.MOVE_LEFT, PrototypeControls.MOVE_RIGHT
    )
    var toward: float = horizontal * player.facing
    status["in"] = toward > 0.5
    status["out"] = toward < -0.5
    player.set_key_status(status)

func _camera_fighter_point(fighter: PortFighter) -> Vector3:
    return Vector3(
        fighter.global_position.x,
        fighter.global_position.y - PortFighter.PLAYER_ORIGIN_HEIGHT,
        fighter.global_position.z
    ) / CAM_SOURCE_UNITS_TO_WORLD


func _camera_aspect_scale() -> float:
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return 1.0
    var aspect: float = viewport_size.x / viewport_size.y
    return maxf(1.0, (4.0 / 3.0) / aspect)


func _native_camera_pose(a: Vector3, b: Vector3, aspect_scale: float) -> Dictionary:
    var d: Vector3 = b - a
    var length: float = d.length()
    var midpoint: Vector3 = (a + b) * 0.5
    var target: Vector3 = midpoint + Vector3(0.0, CAM_TARGET_HEIGHT, 0.0)
    var u: Vector3 = d / maxf(length, 0.0001)
    var lateral: Vector3 = Vector3(-u.z, 0.0, u.x)
    if _cam_side != 0:
        lateral = -lateral
    var distance: float = maxf(length, CAM_MIN_DISTANCE) * aspect_scale
    var position: Vector3 = target + lateral * distance
    position.y += CAM_ELEVATION
    return {"position": position, "target": target}


func _restart_fight_camera() -> void:
    _cam_smooth_a = _camera_fighter_point(player) if is_instance_valid(player) else Vector3(-100, 0, 0)
    _cam_smooth_b = _camera_fighter_point(computer) if is_instance_valid(computer) else Vector3(100, 0, 0)
    _cam_zoom = 0.0
    _cam_initialized = true


func _camera_anm_fighter_point(fighter: PortFighter) -> Vector3:
    # True source Z-up point: (world x, -world z, height above the fighter
    # origin) in .anm source units. The decoded camera data is Z-up, so this
    # differs from _camera_fighter_point() (which is Godot Y-up for the
    # analytic camera).
    var p: Vector3 = fighter.global_position
    return Vector3(p.x, -p.z, p.y - PortFighter.PLAYER_ORIGIN_HEIGHT) / CAM_SOURCE_UNITS_TO_WORLD


func _intro_camera_local_fighter() -> PortFighter:
    ## CBeatEmUpGame::CameraUpdate (@0x188d88) selects the camera dummy with
    ## `CFighter *f = this + (byte)this[0x7e0] * 0x1b8 + 0x24`. The port is a
    ## single-player build whose human always occupies fighter slot 0 (the left
    ## start slot), so this[0x7e0] == 0 and the dummy is `player`.
    return player


func _intro_camera_begin(
        anchor: PortFighter = null, mirror: bool = false
) -> bool:
    ## Arm the authored SetState(3) round-intro camera. Unlike states 12/13,
    ## SetState(3) leaves both fighters at their fight-start positions, so the
    ## anchors are the live fighter points (no rebase). The dummy is the local
    ## player's fighter (decompiled CameraUpdate @0x188d88: uVar4 = this[0x7e0],
    ## mirror = 0 for state 3); the opponent only supplies the yaw direction.
    ## `anchor`/`mirror` are exposed so the same wiring also covers the
    ## opponent-side (player-on-the-right) case without inventing keyframes.
    if _camera_anm == null:
        _camera_anm = CameraAnm.new()
    if not _camera_anm.load_json(_camera_anm_dir + INTRO_CAMERA_CLIP + ".json"):
        _camera_anm_clip = ""
        _camera_anm_anchor = null
        return false
    var dummy: PortFighter = anchor if anchor != null else _intro_camera_local_fighter()
    var other: PortFighter = computer if dummy == player else player
    var a: Vector3 = _camera_anm_fighter_point(dummy)
    var b: Vector3 = _camera_anm_fighter_point(other)
    if (b - a).length() < 0.001:
        b = a + Vector3(dummy.facing, 0.0, 0.0)
    _camera_anm_clip = INTRO_CAMERA_CLIP
    _camera_anm_frame = 0.0
    _camera_anm_anchor = dummy
    _camera_anm_mirror = mirror
    _camera_anm_a = a
    _camera_anm_b = b
    return true


func _camera_anm_begin(
        clip: String, winner: PortFighter, player_pre: Vector3, computer_pre: Vector3
) -> bool:
    ## Start the authored result camera for `winner`. `player_pre`/`computer_pre`
    ## are the two fighters' source points *before* SetState(12/13) moves both to
    ## the origin; they give the dummy yaw (winner -> loser). SetState(12/13)
    ## then renders the winner at the origin, so the anchors are rebased so the
    ## selected dummy lands there. mirror=true selects the computer as the dummy
    ## exactly as CBeatEmUpCamera::StartAnimation swaps A/B for states 12/13.
    if _camera_anm == null:
        _camera_anm = CameraAnm.new()
    if not _camera_anm.load_json(_camera_anm_dir + clip + ".json"):
        _camera_anm_clip = ""
        _camera_anm_anchor = null
        return false
    var mirror: bool = winner == computer
    var winner_pre: Vector3 = computer_pre if mirror else player_pre
    var pose_origin: Vector3 = _camera_anm_fighter_point(winner)  # winner at the origin
    var rebase: Vector3 = pose_origin - winner_pre
    var a: Vector3 = player_pre + rebase
    var b: Vector3 = computer_pre + rebase
    if mirror:
        # Computer (winner) is the dummy at the origin; keep a non-degenerate
        # winner->loser direction using the winner's facing when the two
        # captured points coincide.
        if (a - b).length() < 0.001:
            a = b + Vector3(winner.facing, 0.0, 0.0)
    else:
        if (b - a).length() < 0.001:
            b = a + Vector3(winner.facing, 0.0, 0.0)
    _camera_anm_clip = clip
    _camera_anm_frame = 0.0
    _camera_anm_anchor = winner
    _camera_anm_mirror = mirror
    _camera_anm_a = a
    _camera_anm_b = b
    return true


func _camera_anm_end() -> void:
    _camera_anm_clip = ""
    _camera_anm_frame = 0.0
    _camera_anm_anchor = null


func _camera_anm_play_authored(delta: float) -> bool:
    ## Sample the decoded clip by frame (never interpolate: 34/70 clips contain
    ## real single-frame camera cuts). Holds the last frame until the state
    ## leaves 12/13; returns false only when no clip is loaded (missing JSON).
    if _camera_anm == null or _camera_anm_clip.is_empty() or _camera_anm_anchor == null:
        return false
    var last: int = _camera_anm.frame_count() - 1
    if last < 0:
        return false
    _camera_anm_frame += maxf(delta, 0.0) * 30.0
    var index: int = int(minf(_camera_anm_frame, float(last)))
    var pose: Dictionary = _camera_anm.place_world(
        index, _camera_anm_a, _camera_anm_b, _camera_anm_mirror
    )
    fight_camera.fov = float(pose["fov_degrees"])
    if bool(pose["has_target"]):
        fight_camera.global_position = pose["camera_world"]
        fight_camera.look_at(pose["target_world"], Vector3.UP)
    else:
        _camera_anm.apply_to(
            fight_camera, index, _camera_anm_a, _camera_anm_b, _camera_anm_mirror
        )
    return true


func _intro_camera_play_authored(delta: float) -> bool:
    ## Per-frame playback of the SetState(3) intro clip (30 fps, no
    ## interpolation). Unlike the result camera, this one *finishes*: when the
    ## frame counter passes the last authored frame it ends and returns false so
    ## the analytic follow camera takes over. Native CameraUpdate keeps the
    ## authored camera overriding the analytic one until StopAnimation/timeout
    ## (report E10), and the clip is 4.03 s while SetState(3) lasts 3.0 s, so the
    ## final fov ramp (frames 90-120, 56 deg -> 9 deg) plays over the first
    ## ~1 s of the fight exactly as natively timed.
    if (_camera_anm == null or _camera_anm_clip != INTRO_CAMERA_CLIP
            or _camera_anm_anchor == null):
        return false
    var last: int = _camera_anm.frame_count() - 1
    if last < 0:
        return false
    _camera_anm_frame += maxf(delta, 0.0) * 30.0
    if _camera_anm_frame > float(last):
        _camera_anm_end()
        return false
    var index: int = int(_camera_anm_frame)
    var pose: Dictionary = _camera_anm.place_world(
        index, _camera_anm_a, _camera_anm_b, _camera_anm_mirror
    )
    fight_camera.fov = float(pose["fov_degrees"])
    if bool(pose["has_target"]):
        fight_camera.global_position = pose["camera_world"]
        fight_camera.look_at(pose["target_world"], Vector3.UP)
    else:
        _camera_anm.apply_to(
            fight_camera, index, _camera_anm_a, _camera_anm_b, _camera_anm_mirror
        )
    return true

func _action_camera_load_map() -> void:
    ## Load the derived camera map once.  A missing/invalid map leaves it empty,
    ## which makes every action fall back to the analytic follow camera.
    if _action_camera_map_loaded:
        return
    _action_camera_map_loaded = true
    _action_camera_map = {}
    var file: FileAccess = FileAccess.open(_action_camera_map_path, FileAccess.READ)
    if file == null:
        push_warning("action camera map missing: " + _action_camera_map_path)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("action camera map is not a dictionary")
        return
    var clips: Variant = Dictionary(parsed).get("camera_clips", {})
    if typeof(clips) == TYPE_DICTIONARY:
        _action_camera_map = clips


func _action_camera_begin(clip: String, camera: String) -> bool:
    ## Start the authored camera that belongs to the player's `clip`.  The dummy
    ## reference frame is captured once, exactly like
    ## CBeatEmUpCamera::StartAnimation: dummy position = the local player,
    ## dummy yaw = player -> opponent (source Z-up).  mirror stays false because
    ## CameraUpdate only sets it for states 1/2/12/13.
    if _action_camera_anm == null:
        _action_camera_anm = CameraAnm.new()
    var path: String = _camera_anm_dir + camera + ".json"
    if not FileAccess.file_exists(path) or not _action_camera_anm.load_json(path):
        _action_camera_clip = ""
        _action_camera_camera = ""
        _action_camera_anchor = null
        return false
    var a: Vector3 = _camera_anm_fighter_point(player)
    var b: Vector3 = _camera_anm_fighter_point(computer)
    if (b - a).length() < 0.001:
        b = a + Vector3(player.facing, 0.0, 0.0)
    _action_camera_clip = clip
    _action_camera_camera = camera
    _action_camera_frame = 0
    _action_camera_anchor = player
    _action_camera_mirror = false
    _action_camera_a = a
    _action_camera_b = b
    return true


func _action_camera_end() -> void:
    _action_camera_clip = ""
    _action_camera_camera = ""
    _action_camera_frame = 0
    _action_camera_anchor = null


func _action_camera_tick() -> bool:
    ## Per-frame playback (no interpolation: 34/70 clips contain real one-frame
    ## cuts) of the authored camera owned by the local player's current
    ## animation.  Returns false when no authored camera applies, so the
    ## analytic follow camera keeps the view.
    if (not is_instance_valid(player) or not is_instance_valid(computer)
            or _result_camera_override
            or match_state in [MATCH_STATE_MATCH_WIN, MATCH_STATE_MATCH_LOSE]):
        _action_camera_end()
        return false
    var clip: String = player.current_camera_animation()
    if clip.is_empty():
        _action_camera_end()
        return false
    if clip != _action_camera_clip:
        _action_camera_load_map()
        var row: Variant = _action_camera_map.get(clip, null)
        if row == null:
            _action_camera_end()
            return false
        var camera: String = String(Dictionary(row).get("camera", ""))
        if camera.is_empty() or _action_camera_missing_json.has(camera):
            _action_camera_end()
            return false
        if not _action_camera_begin(clip, camera):
            _action_camera_missing_json.append(camera)
            push_warning("action camera json missing: " + camera)
            _action_camera_end()
            return false
    var frame: float = player.current_camera_frame()
    if frame < 0.0:
        _action_camera_end()
        return false
    var last: int = _action_camera_anm.frame_count() - 1
    if last < 0:
        _action_camera_end()
        return false
    var index: int = int(minf(frame, float(last)))
    if index + 1 < _action_camera_frame:
        # The same animation restarted (source frame rewound): StartAnimation
        # would capture a fresh dummy reference frame.
        if not _action_camera_begin(clip, _action_camera_camera):
            _action_camera_end()
            return false
        index = int(minf(maxf(frame, 0.0), float(last)))
    _action_camera_frame = index
    _action_camera_anm.apply_to(
        fight_camera, index, _action_camera_a, _action_camera_b, _action_camera_mirror
    )
    return true


func _update_fight_camera(delta: float = 1.0 / CAM_UPDATE_HZ) -> void:
    if (not is_instance_valid(fight_camera) or not is_instance_valid(player)
            or not is_instance_valid(computer)):
        return
    if not _cam_initialized:
        _restart_fight_camera()
    if _result_camera_override and match_state in [
            MATCH_STATE_MATCH_WIN, MATCH_STATE_MATCH_LOSE]:
        if _camera_anm_play_authored(delta):
            return
        # Fail-back: keep the pre-existing fixed result camera when the authored
        # clip is missing (JSON absent) or could not be loaded.
        var winner_node: PortFighter = (
            player if pending_round_winner == 1 else computer
        )
        var target: Vector3 = winner_node.global_position + Vector3(0.0, 1.0, 0.0)
        fight_camera.global_position = target + Vector3(0.0, 1.4, 4.2)
        fight_camera.look_at(target, Vector3.UP)
        return
    if _action_camera_tick():
        # The player's current animation owns an authored camera; it overrides
        # both the intro tail and the analytic follow camera while it runs.
        return
    if _camera_anm_clip == INTRO_CAMERA_CLIP and match_state in [
            MATCH_STATE_INTRO, MATCH_STATE_FIGHT]:
        # SetState(3) READY/FIGHT: play the authored m01_intro_01 camera per
        # frame; it deliberately survives the INTRO -> FIGHT transition so the
        # authored fov ramp finishes natively. When the JSON is missing the clip
        # stays empty and the analytic follow camera below keeps the old framing.
        if _intro_camera_play_authored(delta):
            return
    var a: Vector3 = _camera_fighter_point(player)
    var b: Vector3 = _camera_fighter_point(computer)
    var alpha: float = 1.0 - pow(CAM_SMOOTH_OLD, maxf(delta, 0.0) * CAM_UPDATE_HZ)
    _cam_smooth_a = _cam_smooth_a.lerp(a, alpha)
    _cam_smooth_b = _cam_smooth_b.lerp(b, alpha)
    var pose: Dictionary = _native_camera_pose(
        _cam_smooth_a, _cam_smooth_b, _camera_aspect_scale()
    )
    fight_camera.fov = CAM_FIGHT_FOV
    fight_camera.global_position = (pose["position"] as Vector3) * CAM_SOURCE_UNITS_TO_WORLD
    fight_camera.look_at((pose["target"] as Vector3) * CAM_SOURCE_UNITS_TO_WORLD, Vector3.UP)



func _sync_guard_state(pressed: bool) -> void:
    if pressed and not player.guard_held:
        player.begin_guard()
    elif not pressed and player.guard_held:
        player.end_guard()
    player.guard_held = pressed


func _incoming_attack_is_low() -> bool:
    var details: Dictionary = computer.ATTACKS.get(computer.attack_kind, {})
    return str(details.get("source_impact", {}).get("height", "")) == "low"


func _player_attack_is_low() -> bool:
    var details: Dictionary = player.ATTACKS.get(player.attack_kind, {})
    return str(details.get("source_impact", {}).get("height", "")) == "low"


func _held_direction_flags() -> Dictionary:
    return {
        "left": Input.is_action_pressed(PrototypeControls.MOVE_LEFT),
        "right": Input.is_action_pressed(PrototypeControls.MOVE_RIGHT),
        "up": Input.is_action_pressed(PrototypeControls.MOVE_UP),
        "down": Input.is_action_pressed(PrototypeControls.MOVE_DOWN),
    }


func _physics_process(delta: float) -> void:
    if hud == null:
        return
    hud.set_health(player.health, computer.health)
    hud.set_rage(player.rage)
    hud.set_opponent_rage(computer.rage)
    if main_menu_active or menu_paused:
        player.move_axis = Vector2.ZERO
        computer.move_axis = Vector2.ZERO
        return
    if (move_training != null and move_training.is_active()):
        # Training setups such as SPECIAL HIGH KICK are entered by holding
        # S (step back), so keep the live movement axis during lessons instead
        # of zeroing it every physics frame.
        player.move_axis = Input.get_vector(
            PrototypeControls.MOVE_LEFT,
            PrototypeControls.MOVE_RIGHT,
            PrototypeControls.MOVE_UP,
            PrototypeControls.MOVE_DOWN,
            0.2
        )
        player.set_held_directions(_held_direction_flags())
        computer.move_axis = Vector2.ZERO
        _sync_guard_state(Input.is_action_pressed(PrototypeControls.GUARD))
        return
    if (move_gallery != null and move_gallery.is_active()):
        player.move_axis = Vector2.ZERO
        computer.move_axis = Vector2.ZERO
        _sync_guard_state(Input.is_action_pressed(PrototypeControls.GUARD))
        return
    hud.set_context_hint(_contextual_controls())
    if notice_timer > 0.0:
        notice_timer -= delta
        if notice_timer <= 0.0 and not done:
            hud.show_message("")
    # Drive the ported EGameState machine before any input is read. States
    # 3/5/7/8/11/12/13/15 all freeze the fighters, matching the native
    # DummyUpdate path in CBeatEmUpGame::Update().
    _update_counter_text_tracking()
    _update_match_state(delta)
    if match_state != MATCH_STATE_FIGHT:
        player.move_axis = Vector2.ZERO
        computer.move_axis = Vector2.ZERO
        return
    if done or training_completed:
        player.move_axis = Vector2.ZERO
        computer.move_axis = Vector2.ZERO
        return
    elapsed += delta
    _update_round_timer()
    if match_state != MATCH_STATE_FIGHT:
        player.move_axis = Vector2.ZERO
        computer.move_axis = Vector2.ZERO
        return
    player.move_axis = Input.get_vector(
        PrototypeControls.MOVE_LEFT,
        PrototypeControls.MOVE_RIGHT,
        PrototypeControls.MOVE_UP,
        PrototypeControls.MOVE_DOWN,
        0.2
    )
    player.set_held_directions(_held_direction_flags())
    _sync_guard_state(Input.is_action_pressed(PrototypeControls.GUARD))
    if training_mode:
        computer.move_axis = Vector2.ZERO
        computer.guard_held = false
    else:
        _think_ai(delta)


func _update_round_timer() -> void:
    if not round_time_active or hud == null:
        return
    # Original Update() state 4: seconds = timer_max - played_millis / 1000.
    var remaining: int = maxi(0, round_time_max - int(elapsed))
    if remaining == round_time_left:
        return
    round_time_left = remaining
    hud.set_time(round_time_left, true)
    if round_time_left == 0:
        _on_time_up()


# CBeatEmUpGame::Render consumes the per-fighter counter flag (CFighter+0x176,
# seen in Render as this+0x19a for the player and this+0x352 for the opponent)
# and launches game text animation 7 (left) for the player or 8 (right) for the
# opponent.  CFighter::SetAnimation sets the flag when the new animation
# carries the recovered "counter" category -- in every fighting set only
# parryhigh/parrylow have it -- so the port triggers on entering those states,
# once per parry animation, with no thresholds.
func _update_counter_text_tracking() -> void:
    if player == null or computer == null:
        return
    _track_fighter_counter_text(player, 0)
    _track_fighter_counter_text(computer, 1)


func _track_fighter_counter_text(fighter: PortFighter, side: int) -> void:
    var parry_state: String = fighter.state
    if not (parry_state in ["parryhigh", "parrylow"]):
        _counter_text_last_state[side] = ""
        return
    if String(_counter_text_last_state[side]) == parry_state:
        # Same parry animation continues; native consumed the flag on Render.
        return
    _counter_text_last_state[side] = parry_state
    _show_game_text(
        "COUNTER", 0.0,
        GAME_TEXT_SEQ_COUNTER_PLAYER if side == 0 else GAME_TEXT_SEQ_COUNTER_OPPONENT,
    )


func _on_time_up() -> void:
    # Update() state 4 zeroes the clock and enters state 5; SetState(5)
    # launches game text animation 4 (BL_gameText-TIME_IS_UP).  The round is
    # not decided until state 5 has run for more than 3000 ms.
    if done or training_completed or not round_time_active:
        return
    if match_state != MATCH_STATE_FIGHT:
        return
    done = true
    hud.set_time(0, true)
    _show_game_text(
        "TIME_IS_UP", float(ROUND_PHASE_WAIT_MS) / 1000.0, GAME_TEXT_SEQ_TIME_IS_UP
    )
    # Time_Out.wav is record 4's recovered sample and fires from the launch.
    _enter_match_state(MATCH_STATE_TIME_UP)


func _enter_match_state(next_state: int) -> void:
    if next_state not in [MATCH_STATE_MATCH_WIN, MATCH_STATE_MATCH_LOSE]:
        # The authored intro camera is allowed to survive INTRO(3) -> FIGHT(4)
        # so its 4.03 s clip finishes as natively timed (CameraUpdate keeps it
        # until StopAnimation/timeout); every other transition ends it.
        var keep_intro: bool = (
            next_state == MATCH_STATE_FIGHT
            and _camera_anm_clip == INTRO_CAMERA_CLIP
        )
        if not keep_intro:
            _camera_anm_end()
    match_state = next_state
    match_state_time = 0.0
    _round_end_handled = false


func _configure_match_rounds() -> void:
    ## BRUCELEE_MATCH_ROUNDS is the story battle `rounds` value (rounds to win).
    ## BRUCELEE_PLAYER_START_HEALTH is the story battle `player_starting_health`.
    ## Both are ignored when the environment does not set them, so the prototype
    ## match stays ROUNDS_TO_WIN / full health.
    var setting: String = OS.get_environment("BRUCELEE_MATCH_ROUNDS")
    rounds_to_win = ROUNDS_TO_WIN
    if setting.is_valid_int():
        rounds_to_win = maxi(1, setting.to_int())
    player_start_health_override = -1.0
    var health: String = OS.get_environment("BRUCELEE_PLAYER_START_HEALTH")
    if health.is_valid_float():
        var value: float = health.to_float()
        if value > 0.0:
            player_start_health_override = minf(PortFighter.MAX_HEALTH, value)


func _match_target_reached() -> bool:
    return player_rounds >= rounds_to_win or computer_rounds >= rounds_to_win


func _update_match_state(delta: float) -> void:
    ## Port of the CBeatEmUpGame::Update() state switch.  Only the result
    ## path is timed; state 4 runs the normal control/clock code in
    ## _physics_process.
    if match_state == MATCH_STATE_FIGHT:
        return
    match_state_time += delta
    match match_state:
        MATCH_STATE_INTRO:
            _advance_round_intro()
        MATCH_STATE_TIME_UP:
            _advance_time_up()
        MATCH_STATE_KO_WIN, MATCH_STATE_KO_LOSE, MATCH_STATE_DRAW:
            _advance_result_text()
        MATCH_STATE_MATCH_WIN, MATCH_STATE_MATCH_LOSE:
            _advance_winner_result_pose()
        MATCH_STATE_ROUND_END:
            _advance_round_end()


func _advance_round_intro() -> void:
    # LaunchGameTextAnimation(0) is shown by _start_round_intro; (1) follows.
    if not _intro_fight_shown and match_state_time >= 0.8:
        _intro_fight_shown = true
        _show_game_text("FIGHT", 1.2, GAME_TEXT_SEQ_FIGHT)
        # Fight.wav is record 1's recovered sample at +2.0 s; the launch
        # schedule below plays it once at that offset.
    if match_state_time > float(ROUND_PHASE_WAIT_MS) / 1000.0:
        _enter_match_state(MATCH_STATE_FIGHT)
        done = false


func _advance_time_up() -> void:
    if match_state_time > float(ROUND_PHASE_WAIT_MS) / 1000.0:
        _resolve_time_up_winner()


func _resolve_time_up_winner() -> void:
    # Update() state 5: equal health is the draw path (state 11); otherwise the
    # fighter with more health scores the round and enters state 7 or 8.
    var player_health: float = player.health
    var computer_health: float = computer.health
    if is_equal_approx(player_health, computer_health):
        pending_round_winner = 0
        hud.show_message("TIME UP · DRAW · ROUND %d" % round_number)
        _show_game_text("DRAW", float(ROUND_PHASE_WAIT_MS) / 1000.0, GAME_TEXT_SEQ_DRAW)
        # Draw.wav is record 5's recovered sample and fires from the launch.
        _enter_match_state(MATCH_STATE_DRAW)
        return
    if player_health > computer_health:
        player_rounds += 1
        pending_round_winner = 1
        hud.show_message("TIME UP · YOU WIN · ROUND %d" % round_number)
        _show_round_result_text(player, true)
        _enter_match_state(MATCH_STATE_KO_WIN)
    else:
        computer_rounds += 1
        pending_round_winner = 2
        hud.show_message("TIME UP · YOU LOSE · ROUND %d" % round_number)
        _show_round_result_text(computer, false)
        _enter_match_state(MATCH_STATE_KO_LOSE)
    hud.set_round(round_number, player_rounds, computer_rounds, training_mode)


# SetState(7)/(8): the game text follows the *local player's* result.
# SetState(7) fires when fighter 0 (the port's player) scores the round and
# takes its win path only when the local-player flag (this+0x7e0, 0 = fighter
# 0) matches; the port's player is always the local fighter 0, so:
#   player round win:  player health < 0x14 (20) -> GREAT (sequence 9);
#                      otherwise YOU_WIN (2); player health == 100
#                      additionally launches PERFECT (6) as a second,
#                      concurrent animator (native starts one CSpriteAnimator
#                      per LaunchGameTextAnimation call).
#   player round loss: SetState(8) with local flag 0 falls through to
#                      YOU_LOSE (3); the opponent's health is never checked on
#                      the player's loss path.
# Native compares integer health points; the port's health is the same 0..100
# scale and only decreases, so equality with MAX_HEALTH is the same
# "untouched" condition.
func _show_round_result_text(winner: PortFighter, player_won: bool) -> void:
    var wait: float = float(ROUND_PHASE_WAIT_MS) / 1000.0
    if not player_won:
        _show_game_text("YOU_LOSE", wait, GAME_TEXT_SEQ_YOU_LOSE)
        return
    if winner.health < ROUND_GREAT_HEALTH:
        _show_game_text("GREAT", wait, GAME_TEXT_SEQ_GREAT)
    else:
        _show_game_text("YOU_WIN", wait, GAME_TEXT_SEQ_YOU_WIN)
    if is_equal_approx(winner.health, PortFighter.MAX_HEALTH):
        _show_game_text("PERFECT", wait, GAME_TEXT_SEQ_PERFECT)


func _advance_result_text() -> void:
    # Update() states 7/8/11 share LAB_0018d358: after 3000 ms either enter the
    # winner-only match pose (12/13) or end the round (15).
    if match_state_time <= float(ROUND_PHASE_WAIT_MS) / 1000.0:
        return
    if pending_round_winner != 0 and _match_target_reached():
        _begin_winner_result_pose()
    else:
        _enter_match_state(MATCH_STATE_ROUND_END)


func _begin_winner_result_pose() -> void:
    # SetState(12)/(13): both fighters are moved to the origin, the loser is
    # hidden, and only the winner gets a SetAnimation call -- the native code
    # never gives the hidden loser a "Defeat" animation in 12/13.
    var winner_is_player: bool = pending_round_winner == 1
    var winner: PortFighter = player if winner_is_player else computer
    var loser: PortFighter = computer if winner_is_player else player
    # Capture both fighters before SetPosToOrigin: this keeps the authored
    # camera's dummy yaw (winner -> loser) non-degenerate.
    var player_pre: Vector3 = _camera_anm_fighter_point(player)
    var computer_pre: Vector3 = _camera_anm_fighter_point(computer)
    player.global_position = Vector3(0.0, 1.20, 0.0)
    computer.global_position = Vector3(0.0, 1.20, 0.0)
    player.move_axis = Vector2.ZERO
    computer.move_axis = Vector2.ZERO
    player.visible = winner_is_player
    computer.visible = not winner_is_player
    _result_camera_override = true
    _camera_anm_begin("m01_victory_01", winner, player_pre, computer_pre)
    # The KO text from state 7/8 has finished by the time SetState(12/13)
    # begins; clear it so only the victory/defeat clip is presented.
    _hide_game_text_overlays()
    var victory_ok: bool = winner.enter_result_pose("victory")
    loser.clear_result_pose()
    if not winner.result_clip_gap_last.is_empty():
        print("MATCH_RESULT_GAP winner=%s %s" % [
            "player" if winner_is_player else "computer",
            winner.result_clip_gap_last,
        ])
    # Update() state 12/13 leaves when GetStateTime() > GetDuration() - 100 with
    # unsigned milliseconds. A clip shorter than 100 ms makes the native
    # comparison wrap and the state never ends; the port keeps its 2.5 s
    # fallback for that case and for a missing clip so the match can still close.
    var clip_millis: int = int(round(winner.result_clip_duration() * 1000.0))
    _result_pose_seconds = 2.5
    if victory_ok and clip_millis >= 100:
        _result_pose_seconds = float(clip_millis - 100) / 1000.0
    _enter_match_state(MATCH_STATE_MATCH_WIN if winner_is_player else MATCH_STATE_MATCH_LOSE)


func _advance_winner_result_pose() -> void:
    # Update() states 12/13 leave when the victory clip is nearly over
    # (duration - 100 ms) or a skip event is consumed.
    if match_state_time > _result_pose_seconds:
        _enter_match_state(MATCH_STATE_ROUND_END)


func _advance_round_end() -> void:
    # RoundEnded() is true in state 15.  The match module either raises the
    # win/lose result screen or calls NextRound() -> RestartValues().
    if _round_end_handled:
        return
    _round_end_handled = true
    if _match_target_reached():
        match_over = true
        done = true
        var player_won: bool = player_rounds >= rounds_to_win
        hud.show_message(
            "YOU WIN THE MATCH · R TO RESTART" if player_won
            else "YOU LOSE THE MATCH · R TO RESTART"
        )
        # You_Win/You_Lose already fired with the SetState(7)/(8) game text;
        # playing them again here is the duplicate this patch removes.
        if story_flow != null:
            story_flow.match_finished(player_won)
        if game_modes != null and String(game_modes.get("screen")) == "battle":
            game_modes.match_finished(player_won)
    else:
        _start_next_round()


func _contextual_controls() -> String:
    if done or training_completed:
        return ""
    var clips: Dictionary = player.get("_candidate_clip_paths")
    if player.state in ["facedownidle", "faceupidle"]:
        var getup_clip: String = (PortFighter.FACEDOWN_GETUP_CLIP
                if player.state == "facedownidle" else PortFighter.FACEUP_GETUP_CLIP)
        var attack_clip: String = (PortFighter.FACEDOWN_ATTACK_CLIP
                if player.state == "facedownidle" else PortFighter.FACEUP_ATTACK_CLIP)
        var options: Array[String] = []
        if clips.has(getup_clip):
            options.append("A/D: get up when available")
        if clips.has(attack_clip):
            options.append("Ground attack, press in order: J J J / J K K / K L L / K U U")
        return "   |   ".join(options)
    if (player.state in ["idle", "idle2"]
            and is_instance_valid(computer)
            and computer.current_source_pose() == "laying"
            and clips.has(PortFighter.ATTACK_TO_FLOOR_CLIP)
            and clips.has(PortFighter.IDLE2_CLIP)):
        return "Downed opponent: press K L L / K U U in order (close range)"
    return ""

func _configure_native_ai() -> void:
    ## Loads the recovered decision tree and Brick's ai_profile.  Failure is
    ## loud: the prototype thresholds are gone, so a missing tree must not
    ## silently fall back to them.
    native_ai = NativeAI.new()
    if not native_ai.load_data():
        push_error("Native AI data failed to load: " + native_ai.load_error)
        native_ai = null
        return
    var difficulty: int = int(native_ai.tuning.get("difficulty_index", {}).get("value", 2))
    native_ai.set_difficulty(difficulty)
    native_ai.configure(computer, player, _opponent_ai_profile_key(), rng.seed)


func _think_ai(delta: float) -> void:
    ## Original: CFighter::AIUpdate() walks CDecisionTree::MakeDecision() every
    ## update (ELF 0x1a8b2c) and follows the selected link.  The recovered tree
    ## and per-character ai_profile replace the prototype's 0.45-0.95 s timer,
    ## uniform move choice and 1/3 + 2/3 rage gates.
    if native_ai == null:
        return
    # The tree owns locomotion while it is allowed to act; attacks keep
    # move_axis at zero so attack root motion is not fought by input.
    computer.move_axis = Vector2.ZERO
    native_ai.step(delta)

func _ai_move_names(slots: Array[String]) -> Array[String]:
    ## Mapped set configs name their character slots without a suffix
    ## ("special_kick_high"); the shipped Brick file appends "_brick". Return
    ## whichever names the loaded config actually defines.
    var names: Array[String] = []
    for slot: String in slots:
        for candidate: String in [slot, slot + "_brick"]:
            if computer.supports_attack(candidate):
                names.append(candidate)
    return names


func _player_attack_poses_guard_threat() -> bool:
    if player.state in ["startup", "active"]:
        return true
    if player.state not in ["facedownattack", "faceupattack"]:
        return false
    var source_frame: float = player.state_time * PortFighter.SOURCE_FRAME_RATE
    var damage_end_frame: int = (
        PortFighter.FACEDOWN_ATTACK_DAMAGE_END_FRAME
        if player.state == "facedownattack"
        else PortFighter.FACEUP_ATTACK_DAMAGE_END_FRAME
    )
    # These prototype inputs enter the recovery attacks directly, so the
    # AI-visible startup extends until the recovered damage window ends.
    return source_frame <= float(damage_end_frame) + 0.0001


func _input(event: InputEvent) -> void:
    # Training select is a plain list UI without focusable controls; handle its
    # arrow/W/S navigation before GUI focus decides the key is unhandled.
    if (move_training != null and move_training.visible
            and String(move_training.state) == "select"):
        if move_training.handle_input_event(event):
            get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
    if prototype_menu != null:
        # J is both a menu confirm and the punch key. Capture the command
        # before handling, then let the confirming press throw a real punch
        # when it starts a fight. Otherwise the first J is silently eaten by
        # the menu and "J J J" produces only two attacks.
        var menu_command: String = (
            prototype_menu.selected_command() if prototype_menu.visible else ""
        )
        if prototype_menu.handle_input_event(event):
            if (menu_command in ["fight", "training"]
                    and not prototype_menu.visible
                    and event.is_action_pressed(PrototypeControls.ATTACK_A)):
                _handle_fighter_attack_input(
                    player, event,
                    PrototypeControls.ATTACK_A, PrototypeControls.ATTACK_B,
                    PrototypeControls.ATTACK_C, PrototypeControls.ATTACK_D
                )
            get_viewport().set_input_as_handled()
            return
    if move_training != null and move_training.handle_input_event(event):
        get_viewport().set_input_as_handled()
        return
    if move_gallery != null and move_gallery.handle_input_event(event):
        get_viewport().set_input_as_handled()
        return
    if move_gallery != null and move_gallery.is_active():
        return
    if not PrototypeControls.is_press_edge(event):
        return
    if event.is_action_pressed(PrototypeControls.PAUSE):
        _open_pause_menu()
        get_viewport().set_input_as_handled()
        return
    if done and not (
        event.is_action_pressed(PrototypeControls.RESTART)
        or event.is_action_pressed(PrototypeControls.TOGGLE_TRAINING)
    ):
        return
    if training_completed and not (
        event.is_action_pressed(PrototypeControls.RESTART)
        or event.is_action_pressed(PrototypeControls.TOGGLE_TRAINING)
    ):
        return
    # Input events can arrive before the next _process tick updates guard_held.
    # Refresh the guard state here so a press in the same frame as the guard
    # key cannot be accepted from a stale snapshot.
    _sync_guard_state(Input.is_action_pressed(PrototypeControls.GUARD))
    # Guard presses cancel a matched combo in the same input event; a tap that
    # is released before the next physics tick would otherwise keep it alive.
    if event.is_action_pressed(PrototypeControls.GUARD):
        player.begin_guard()
    _record_direction_press(event)
    if _handle_fighter_attack_input(
        player,
        event,
        PrototypeControls.ATTACK_A,
        PrototypeControls.ATTACK_B,
        PrototypeControls.ATTACK_C,
        PrototypeControls.ATTACK_D
    ):
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed(PrototypeControls.RESTART):
        _reset_match()
    elif event.is_action_pressed(PrototypeControls.TOGGLE_TRAINING):
        if training_mode:
            training_mode = false
            _reset_match()
        elif _training_available():
            training_mode = true
            _reset_match()
        else:
            hud.show_message("TRAINING NEEDS CANDIDATE ANIMATIONS")
            notice_timer = 2.0
    else:
        return
    get_viewport().set_input_as_handled()

func _record_direction_press(event: InputEvent) -> void:
    # adreno_200/input.config fixedpad: an up press emits the "up" and "in"
    # virtual keys, a down press emits "down" and "out"; left/right emit one key.
    if player == null or done or training_completed:
        return
    if event.is_action_pressed(PrototypeControls.MOVE_UP):
        player.record_standing_combo_press("up")
        player.record_standing_combo_press("in")
    elif event.is_action_pressed(PrototypeControls.MOVE_DOWN):
        player.record_standing_combo_press("down")
        player.record_standing_combo_press("out")
    elif event.is_action_pressed(PrototypeControls.MOVE_LEFT):
        player.record_standing_combo_press("left")
    elif event.is_action_pressed(PrototypeControls.MOVE_RIGHT):
        player.record_standing_combo_press("right")


func _handle_fighter_attack_input(
        fighter: PortFighter,
        event: InputEvent,
        action_a: String,
        action_b: String,
        action_c: String,
        action_d: String
) -> bool:
    # An attack press records only the virtual key that was pressed. Held
    # directions are separate key presses (see _record_direction_press) and
    # native link conditions read held state via InputStatusCheck, so they must
    # not be folded into the attack event.
    # Move Training may start the documented move directly from its final
    # key.  Normal VS must use the recovered native link tables; the direct
    # step+key path would bypass link sequences and rage gates there.
    if fighter.is_player and fighter.state == "idle" \
            and move_training != null and move_training.is_active():
        var step_action: String = fighter._native_movement_action()
        var direct_target: String = ""
        if step_action == "stepleft" and event.is_action_pressed(action_d):
            direct_target = "special_kick_low_hit"
        elif step_action == "stepleft" and event.is_action_pressed(action_c):
            direct_target = "grab2"
        elif step_action == "stepback" and event.is_action_pressed(action_c):
            direct_target = "special_kick_high"
        elif step_action == "stepright" and event.is_action_pressed(action_a):
            direct_target = "grab1"
        if not direct_target.is_empty() and fighter.request_attack(direct_target):
            return true
    if event.is_action_pressed(action_a):
        fighter.record_standing_combo_press("a")
    elif event.is_action_pressed(action_b):
        fighter.record_standing_combo_press("b")
    elif event.is_action_pressed(action_c):
        fighter.record_standing_combo_press("c")
    elif event.is_action_pressed(action_d):
        fighter.record_standing_combo_press("d")
    elif event.is_action_pressed(PrototypeControls.RESTART):
        return false
    else:
        return false
    return true


func _training_available() -> bool:
    var player_clips: Dictionary = player.get("_candidate_clip_paths")
    var computer_clips: Dictionary = computer.get("_candidate_clip_paths")
    return (player.candidate_loaded and computer.candidate_loaded
            and player_clips.has(PortFighter.ATTACK_TO_FLOOR_CLIP)
            and player_clips.has(PortFighter.IDLE2_CLIP)
            and computer_clips.has(PortFighter.BRICK_FACEDOWN_IDLE_CLIP)
            and computer_clips.has(PortFighter.FACEDOWN_IMPACT_CLIP))

func _on_hit(attacker: PortFighter, defender: PortFighter, action: String, damage: float, blocked: bool) -> void:
    if done or training_completed:
        return
    _play_hit_audio(action, blocked, defender)
    # brucelee.set reaction actions (impact*) carry a Bruce pain voice on the
    # victim; the port never played it. Block reactions have no voice cue, and
    # the defender (not the attacker) is the one screaming.
    if not blocked and attacker != defender:
        _play_pain_voice(defender, action)
    if ((move_training != null and move_training.is_active())
            or (move_gallery != null and move_gallery.is_active())):
        return
    if (training_mode and attacker == player and defender == computer
            and action == "attacktofloor" and damage > 0.0 and not blocked
            and defender.state == "impactfacedown"):
        training_completed = true
        hud.show_message("TRAINING HIT · R RETRY · F2 EXIT")
        notice_timer = 0.0
        return
    if blocked:
        hud.show_message("BLOCK!")
    elif attacker == player:
        hud.show_message("HIT · " + action.to_upper())
    else:
        hud.show_message("TAKE HIT")
    notice_timer = 0.30

func _on_ko(fighter: PortFighter) -> void:
    # Update() state 4 detects CFighter::IsDefeated(), adds the round win and
    # calls SetState(7) when the computer was defeated, SetState(8) when the
    # player was defeated.  The knockout itself must come from a real attack;
    # this signal handler never invents a state.
    if training_completed or done:
        return
    if match_state != MATCH_STATE_FIGHT:
        return
    done = true
    if training_mode:
        hud.show_message("TRAINING KO · R TO RESET")
        return
    if fighter == computer:
        player_rounds += 1
        pending_round_winner = 1
    else:
        computer_rounds += 1
        pending_round_winner = 2
    hud.set_round(round_number, player_rounds, computer_rounds, training_mode)
    var player_won: bool = fighter == computer
    _show_round_result_text(player if player_won else computer, player_won)
    hud.show_message(
        "YOU WIN · ROUND %d" % round_number if fighter == computer
        else "YOU LOSE · ROUND %d" % round_number
    )
    # You_Win/You_Lose are the recovered samples of the game text launched by
    # _show_round_result_text above; this call used to duplicate them.
    _enter_match_state(
        MATCH_STATE_KO_WIN if fighter == computer else MATCH_STATE_KO_LOSE
    )


extends Node3D
## Gameplay demonstrator: intentionally original, with placeholder meshes.
## Original character models/animations and exact rules remain unported.

const CandidateBounds = preload("res://scripts/candidate_bounds.gd")
const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")
const PrototypeMenu = preload("res://scripts/prototype_menu.gd")
## Opt-in original-art front menu (BRUCELEE_MENU_ART=1). It is a subclass of
## PortPrototypeMenu, so with the flag unset the text menu keeps its existing
## path and every pause / records / style-editor hook still works.
const MenuArtMenu = preload("res://scripts/menu_art.gd")
const PrototypeControls = preload("res://scripts/prototype_controls.gd")
const MoveTraining = preload("res://scripts/move_training.gd")
const MoveGallery = preload("res://scripts/move_gallery.gd")
const FxLanternPulse = preload("res://scripts/fx_lanterns_pulse.gd")
const FxVapourReflector = preload("res://scripts/fx_vapour_reflector.gd")
## Decoded per-visual material tracks (colour / UV offset) that glTF cannot
## carry.  Inert unless `fx_material_curves.json` sits beside the FX manifest.
const FxMaterialTracks = preload("res://scripts/fx_material_tracks.gd")
const AudioCueMap = preload("res://scripts/audio_cue_map.gd")
## Recovered impact/block SFX + 21 music-track library (data-only table).
const SfxMusicMap = preload("res://scripts/sfx_music_map.gd")
## Recovered voice cue timing from adreno_200/set/brucelee.set `sounds[]`
## (file / frame / volume / unique / is_voice).  Data-only table; the runtime
## schedules each voice at frame/30 s instead of flattening it to action start.
const VoiceCueTiming = preload("res://scripts/voice_cue_timing.gd")
const CameraAnm = preload("res://scripts/camera_anm_player.gd")
## Story-mode flow (isolated prototype).  Only instantiated when
## BRUCELEE_STORY_FLOW=1, so the existing prototype paths are untouched.
const StoryFlow = preload("res://scripts/story_flow.gd")
## Opt-in Arcade / Survival / Time Attack modes (recovered game.states / gui).
const GameModes = preload("res://scripts/game_modes.gd")
## Recovered CBeatEmUpGame states 1/2 (attract intros), 6 (replay), 9
## (continue), 10 and 14.  States whose data is not recovered refuse to start.
const NativeMatchStates = preload("res://scripts/native_match_states.gd")
## Opt-in progress/save subsystem bridge (inert unless BRUCELEE_PROGRESS=1).
const ProgressHooks = preload("res://scripts/progress_hooks.gd")
## Opt-in Records/Achievements screen. It is only reachable through the RECORDS
## row that prototype_menu.gd adds while BRUCELEE_PROGRESS=1, and it renders the
## live progress service state (38 achievements, unlock list, story EXP/events,
## versus/combat counters, save status). With the flag off it is never created.
const RecordsScreen = preload("res://scripts/progress_records_screen.gd")
## Opt-in Style Editor (BRUCELEE_STYLE_EDITOR=1). The menu row, the decoded
## catalog and the user:// selection file are inert unless the flag is on.
const StyleCatalog = preload("res://scripts/style_catalog.gd")
const StyleSelectionStore = preload("res://scripts/style_selection_store.gd")
const StyleEditorScreen = preload("res://scripts/style_editor_screen.gd")
## Opt-in opponent voice overlay (island opponent-voice-20261104). It is
## inert unless BRUCELEE_OPPONENT_VOICE=1, and it never replaces the Bruce
## cue table; see overlay/opponent_voice_cues.json for the recovered cues.
const OpponentVoiceOverlayScript = preload("res://scripts/opponent_voice_overlay.gd")
## Opt-in recovered character-select art (BRUCELEE_HUD_ART=1). The overlay class
## is the one already shipped as godot/scripts/hud_art_overlay.gd; this file only
## drives its selectfighter.ui dock and fightpreview.ui VS screen from the real
## menu selection. With the flag unset nothing is created and no node changes.
const HudArtOverlayScript = preload("res://scripts/hud_art_overlay.gd")
const HUD_ART_ENV := "BRUCELEE_HUD_ART"
## How long the fightpreview.ui VS screen is held before the opponent reload.
## The recovered layout fixes positions; this duration is only the transition.
const HUD_ART_VS_HOLD_SECONDS := 1.6
const HUD_ART_PLAYER_KEY := "BRUCE LEE"
## opponent-menu command -> selectfighter.ui dock index. The dock order is the
## decoded `items` array of selectfighter.ui (see hud_art_overlay.gd
## SELECT_ITEMS); each index below is the recovered icon whose basename matches
## the opponent's name. Nothing is invented: the mapping is a name lookup.
const HUD_ART_OPPONENT_DOCK: Dictionary = {
    "brick": 11,      # bl_brickdavis_icon
    "sinfu": 7,       # bl_sinfu_icon
    "master": 5,      # bl_themaster_icon
    "ken": 10,        # bl_kengodall_icon
    "shenlo": 4,      # bl_shenlo_icon
    "smallboy": 6,    # bl_smallboy_icon
    "johnson": 12,    # bl_johnson_icon
    "chief": 8,       # bl_thechief01_icon
    "loming": 13,     # bl_loming01_icon
}
## opponent-menu command -> the display name _opponent_display_name() returns
## for that selected set (the keys of hud_art_overlay.gd VS_PORTRAITS).
const HUD_ART_OPPONENT_NAMES: Dictionary = {
    "brick": "BRICK DAVIS",
    "sinfu": "SIN FU",
    "master": "THE MASTER",
    "ken": "KEN GODALL",
    "shenlo": "SHEN LO",
    "smallboy": "SMALL BOY",
    "johnson": "JOHNSON",
    "chief": "CHIEF",
    "loming": "LO MING",
}
## Opponent-selection entries emitted by the prototype menu. Each value is the
## BRUCELEE_OPPONENT_* configuration applied before main.tscn is reloaded:
##   glb              candidate GLB path ("" means the built-in placeholder)
##   glb_package      stable package-relative model (see PACKAGE_MODELS_DIR).
##                    Used when the file exists and its sha256 matches; absent
##                    files fall back to "glb", hash mismatches fail closed.
##   sha256           expected SHA-256 of glb_package (identity pin)
##   skins            optional named variant table for the same character/set,
##                    selected with BRUCELEE_OPPONENT_SKIN
##   texture_root     directory holding <kind>_diffuse/normal/material.png
##   clip_prefix      candidate clip prefix, e.g. "m04" ("" means m03/Brick)
##   master           "1" selects the Master m04_e01_* clip table
##   material_profile CandidateMaterialLoader profile ("body" or "body_hair")
##   attack_config    mapped fighting-set config ("" means the Brick default)
## Paths are the locally tested candidates; they are not shipped with the repo.
## Package models are a local layout next to the app; "glb" keeps the previous
## absolute path so old launchers keep working when the package model is absent.
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
        "glb_package": "models\\sinfu_full_hair_intro.glb",
        "sha256": "c493296417a2e67248699ac7420b47581d29908fe26590bc351453ddd324c58f",
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
        "glb_package": "models\\master_full_hair_intro.glb",
        "sha256": "0a958ee2e56f349a97e01a8febcac6c9c9fd351552e084d212e14a1fa3891b66",
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
        "glb_package": "models\\chief01_body_hair.glb",
        "sha256": "df61ef3e906b5cd91b3fd3425ac57de879cd5e407dc185a2b98eb46a4101aa21",
        "texture_root": "D:\\BruceLeeWork\\remaining-characters-20261103\\textures\\chief01",
        "clip_prefix": "",
        "master": "",
        "material_profile": "body_hair",
        "attack_config": "res://data/attack_config_chief.json",
        "skeleton": "large",
        ## Both Chief variants use characters.list "chief a/b" (karate set) and
        ## the same source skeleton; chief02 is body-only ("body" profile), so it
        ## declares no external texture root rather than borrowing chief01 art.
        "skins": {
            "chief01_body_hair": {
                "glb_package": "models\\chief01_body_hair.glb",
                "sha256": "df61ef3e906b5cd91b3fd3425ac57de879cd5e407dc185a2b98eb46a4101aa21",
                "texture_root": "D:\\BruceLeeWork\\remaining-characters-20261103\\textures\\chief01",
                "material_profile": "body_hair",
            },
            "chief02_body": {
                "glb_package": "models\\chief02_body.glb",
                "sha256": "42070f9299369c92be6cde453246ee43f929adaf3d5f99482113b9a17f1eceee",
                "texture_root": "",
                "material_profile": "body",
            },
        },
    },
    "loming": {
        "glb": "D:\\BruceLeeWork\\result-clip-fixes-20261103\\candidates\\loming01_full_body_hair_84_groundidle_20261103.glb",
        "glb_package": "models\\loming01_body_hair.glb",
        "sha256": "76f13c2a82b55d164d8944396e1dc8f69883e15422df4fa4dae2169f37782117",
        "texture_root": "D:\\BruceLeeWork\\remaining-characters-20261103\\textures\\loming01",
        "clip_prefix": "",
        "master": "",
        "material_profile": "body_hair",
        "attack_config": "res://data/attack_config_loming.json",
        "skeleton": "large",
        ## characters.list "lo ming a/b" (kungfu set), same source skeleton;
        ## loming02 is body-only, so no external texture root is declared.
        "skins": {
            "loming01_body_hair": {
                "glb_package": "models\\loming01_body_hair.glb",
                "sha256": "76f13c2a82b55d164d8944396e1dc8f69883e15422df4fa4dae2169f37782117",
                "texture_root": "D:\\BruceLeeWork\\remaining-characters-20261103\\textures\\loming01",
                "material_profile": "body_hair",
            },
            "loming02_body": {
                "glb_package": "models\\loming02_body.glb",
                "sha256": "402ae5e844673456b2497f81edc97bfe7dc761d59090d0ce5dbe61a109086554",
                "texture_root": "",
                "material_profile": "body",
            },
        },
    },
}
## Stable package model layout.  Values in "glb_package" are relative to this
## directory under the package root (the EXE directory).  BRUCELEE_PACKAGE_ROOT
## overrides the package root so a validator can exercise the same files from
## the editor without copying the app.  The directory sits beside the EXE and is
## never imported into the project or packed into the PCK.
const PACKAGE_MODELS_DIR: String = "models"
## Local packages may opt in to loading their own first-party models/ subtree.
## The default candidate-path guard still rejects every application-internal
## path; only this explicit flag, a path under <package root>/models/ and a
## verified sha256 let a packaged model through (see candidate_path_guard.gd).
const PACKAGE_MODELS_OPT_IN_ENV: String = "BRUCELEE_ALLOW_PACKAGE_MODELS"
## Verified player skins.  Only Bruce Lee's four body+hair variants qualify:
## they share the characters.list "bruce lee a..d" / m01 clip table and one
## source skeleton, and the packaged files are the verified candidates.  An
## opponent id (chief, loming, master, sinfu, ...) is NOT a player skin and is
## rejected: an unknown BRUCELEE_PLAYER_SKIN leaves the placeholder fighter in
## place instead of silently loading a different character.
## A declared skin whose package file is absent or whose sha256 differs also
## fails closed (placeholder fighter).  With no skin requested, the previous
## absolute BRUCELEE_PLAYER_GLB path (launch.ps1's default) is used unchanged.
const PLAYER_SKIN_CONFIG: Dictionary = {
    "skin01": {
        "glb_package": "models\\bruce_skin01.glb",
        "sha256": "128782fa257712972ee2e1f846dff9892af2d945f2e10bda5beb1a908468da06",
        "material_profile": "body_hair",
    },
    "skin02": {
        "glb_package": "models\\bruce_skin02.glb",
        "sha256": "df9ff7b67aef757129c9330bdef0ac9568f242b637a05434eb0d5606a567485e",
        "material_profile": "body_hair",
    },
    "skin03": {
        "glb_package": "models\\bruce_skin03.glb",
        "sha256": "7551a98c23255415bfefc9634693c43afae2d99a8ce679b5e8e62230dd3b4561",
        "material_profile": "body_hair",
    },
    "skin04": {
        "glb_package": "models\\bruce_skin04.glb",
        "sha256": "1db5406f75d0f5759b6111bc130fa7381e485bb70ac53bddb67832ebb970d508",
        "material_profile": "body_hair",
    },
}
## Shared verified texture root for the four Bruce skins (body+hair PNGs).
const PLAYER_SKIN_TEXTURE_ROOT: String = (
    "D:\\BaiduSyncdisk\\AI项目\\李小龙\\private_assets\\appdata-msix\\"
    + "BruceLee-PC-Port\\candidate-textures-verified-20261029"
)
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
# 9 (continue) and 14 (story defeat) live in NativeMatchStates; 6 and 10 stay
# fail-closed there.
const MATCH_STATE_ATTRACT_FIGHTER0: int = 1  # SetState(1): fighter 0 "Intro"
const MATCH_STATE_ATTRACT_FIGHTER1: int = 2  # SetState(2): fighter 1 "Intro"
const MATCH_STATE_INTRO: int = 3        # SetState(3): both idle, READY/FIGHT text
const MATCH_STATE_FIGHT: int = 4        # SetState(4): control + round clock
const MATCH_STATE_TIME_UP: int = 5      # SetState(5): LaunchGameTextAnimation(4)
const MATCH_STATE_KO_WIN: int = 7       # SetState(7): player round win text
const MATCH_STATE_KO_LOSE: int = 8      # SetState(8): computer round win text
const MATCH_STATE_DRAW: int = 11        # SetState(11): draw round text
const MATCH_STATE_CONTINUE: int = 9     # SetState(9): GREAT text + continue
const MATCH_STATE_MATCH_WIN: int = 12   # SetState(12): winner-only victory pose
const MATCH_STATE_MATCH_LOSE: int = 13  # SetState(13): winner-only victory pose
const MATCH_STATE_COUNTDOWN: int = 14   # SetState(14): story defeat presentation
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
## Archive-relative voice file -> AudioStream (or null when the package does not
## hold that character's take).  Attack slots can carry more than one voice cue,
## so the cache is keyed by file, not by action.
var _voice_file_cache: Dictionary = {}
var _active_voice: AudioStreamPlayer = null
## Opponent voice overlay instance (lazily created on the first opponent cue).
var _opponent_voice = null
var _opponent_voice_error: String = ""
## Opted-in recovered selectfighter/fightpreview overlay (BRUCELEE_HUD_ART=1).
## It lives on its own CanvasLayer above the menu so neither the menu nor the
## existing in-fight HUD is modified; both stay null with the flag off.
var hud_art_menu_layer: CanvasLayer = null
var hud_art_menu_overlay = null
# Recovered adreno_200/sounds/sfx library (38 WAVs).  Distinct from the three
# legacy candidate-audio streams: the package copy is self-contained and is
# read without CandidatePathGuard (music/commentator already use the same
# package-relative convention).
var _sfx_audio: Dictionary = {}
var _sfx_audio_error: Dictionary = {}
var _sfx_play_log: Array = []
var _sfx_play_count: int = 0
# Per-action dedup bookkeeping: one generation token per schedule group.  A new
# start of the same action/group bumps its token, so every still-pending cue of
# the previous instance becomes stale and never plays (no duplicate playback).
var _sfx_schedule_token: Dictionary = {}
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
# Recovered TFightResults field names / category keys (scripts/fight_stats.gd).
const FightStats = preload("res://scripts/fight_stats.gd")
# Recovered native AI (adreno_200/ai/standard.tree + characters.list).
const NativeAI = preload("res://scripts/native_ai.gd")
var native_ai: RefCounted = null
var round_number: int = 1
var player_rounds: int = 0
var computer_rounds: int = 0
var match_over: bool = false
# TFightResults +0x10 is the player fighter record byte +0x174: the number of
# rounds this match was won without taking a hit (CBeatEmUpGame::SetState 7/8
# increments it when the round winner's health == 100).  Reset only by
# _reset_match(), which mirrors CBeatEmUpMatch::Restart -> SetInitialRoundValues.
var fight_perfects: int = 0
# TFightResults +0x14: CBeatEmUpMatch::GetMatchTotalMillis at fight registration.
var match_started_msec: int = 0
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
var progress: Node = null
## Records/Achievements screen (CanvasLayer). Created lazily on first open, only
## while BRUCELEE_PROGRESS=1 owns a live progress service.
var records_screen: CanvasLayer = null
## Opt-in Style Editor state. Created only while BRUCELEE_STYLE_EDITOR=1.
var style_catalog: RefCounted = null
var style_store: RefCounted = null
var style_editor: CanvasLayer = null
# Recovered attract/continue states (see native_match_states.gd).  Created in
# _ready; null only before the scene is ready.
var native_states: NativeMatchStates = null
# characters.list intro pools, in archive order, keyed by the same opponent id
# the menu uses.  The player is always a Bruce Lee skin, whose four intros are
# shared by brucelee_jacket/base/tank/kimono.
const INTRO_CLIPS_PLAYER: Array[String] = [
    "m01_intro_01", "m01_intro_02", "m01_intro_03", "m01_intro_04",
]
const INTRO_CLIPS_BY_OPPONENT: Dictionary = {
    "brick": ["m03_intro_02"],
    "johnson": ["m03_intro_01"],
    "smallboy": ["m03_intro_03"],
    "chief": ["m02_e01_intro_01", "m02_e01_intro_02", "m02_intro_01"],
    "ken": ["m02_intro_02", "m02_intro_03"],
    "sinfu": ["m04_e02_intro_01"],
    "shenlo": ["m04_e03_intro_01"],
    "loming": ["m04_intro_01"],
    "master": ["m04_e01_intro_01"],
}
# SetState(0) only plays the attract intros while the +0x82c counter is still
# 0, i.e. once per match.  _reset_match() (a new match, which reaches this
# through _reset_round) clears it; _start_next_round() goes straight to
# _start_round_intro(), so later rounds do not re-enter the attract.
var _attract_played: bool = false
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
## State 14 (SetState(14), story defeat presentation).  The defeat camera is the
## m01_defeat_01 camera sub-animation listed in defeat_camera_map.json for the
## clip characters.list animations.defeat selects; the state itself never leaves
## -- CBeatEmUpMatch::Update raises "COUNTDOWNEND" once GetStateTime() > 9999 ms.
const DEFEAT_CAMERA_MAP_PATH: String = "res://data/camera_anm/defeat_camera_map.json"
var _defeat_camera_map_path: String = DEFEAT_CAMERA_MAP_PATH
var _defeat_camera_map: Dictionary = {}
var _defeat_camera_map_loaded: bool = false
var _countdown_handed_off: bool = false

# ---- Original camera .anm playback for the MATCH_WIN/MATCH_LOSE result state ----
# Decoded from adreno_200/cameras/<clip>_camera.anm by the isolated
# camera-anm-20261104 research.  The camera clip is the one selected by the
# actual characters.list victory pool and zmath draw, not a fixed m01 clip.
# When the JSON is missing, _camera_anm_play_authored() returns false and the
# result camera keeps the pre-existing fixed winner shot.
const CAMERA_ANM_DIR: String = "res://data/camera_anm/"
var _camera_anm_dir: String = CAMERA_ANM_DIR
var _camera_anm = null
var _camera_anm_clip: String = ""
var _camera_anm_frame: float = 0.0
var _camera_anm_mirror: bool = false
var _camera_anm_anchor: PortFighter = null
var _camera_anm_a: Vector3 = Vector3.ZERO
var _camera_anm_b: Vector3 = Vector3.ZERO

# ---- Original camera .anm playback for intro states 1/2/3 ----
# The intro clip is selected by characters.list animations.intro and the
# recovered per-fighter zmathRandomGet() % count draw.  Its camera sub-animation
# is the clip with the same name; the mapping table is data-derived (16/16
# character intro clips have a decoded camera).  No fixed m01_intro_01 fallback
# is used when the selected clip has no camera: the view falls through to the
# analytic camera instead.
const INTRO_CAMERA_MAP_PATH: String = "res://data/camera_anm/intro_camera_map.json"
const VICTORY_CAMERA_MAP_PATH: String = "res://data/camera_anm/victory_camera_map.json"
var _intro_camera_map_path: String = INTRO_CAMERA_MAP_PATH
var _intro_camera_map: Dictionary = {}
var _intro_camera_map_loaded: bool = false
var _victory_camera_map_path: String = VICTORY_CAMERA_MAP_PATH
var _victory_camera_map: Dictionary = {}
var _victory_camera_map_loaded: bool = false
var _intro_camera_clip: String = ""
var _intro_camera_camera: String = ""
var _intro_camera_active: bool = false

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
# Continue prompt drawn by state 9.  Null until the state is entered.
var _continue_layer: CanvasLayer = null

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
    _setup_hud_art_menu()
    _build_game_text_overlay()

    if not OS.get_environment("BRUCELEE_DEMO_RAGE").is_empty():
        hud.footer.text = (
            "J J J | J K K | K L L | K U U | "
            + "Back+K -> Toward+L -> Toward+L = special (rage 100)"
        )
    # BRUCELEE_MENU_ART=1 swaps in the recovered-art front menu; unset keeps the
    # existing text menu. Both are PortPrototypeMenu instances, so the pause /
    # records / style-editor calls below are untouched.
    var menu_art_enabled: bool = OS.get_environment("BRUCELEE_MENU_ART") == "1"
    prototype_menu = MenuArtMenu.new() if menu_art_enabled else PortPrototypeMenu.new()
    add_child(prototype_menu)
    prototype_menu.command_requested.connect(_on_menu_command)
    prototype_menu.selection_changed.connect(_on_menu_selection_changed)
    move_training = MoveTraining.new()
    add_child(move_training)
    move_training.configure(self, player, computer)
    move_training.exit_requested.connect(_on_move_training_exit)
    move_training.style_editor_requested.connect(_on_training_style_editor_requested)
    move_training.free_training_fighter_requested.connect(
        _on_training_free_fighter_requested)
    move_gallery = MoveGallery.new()
    add_child(move_gallery)
    move_gallery.configure(self, player, computer)
    move_gallery.exit_requested.connect(_on_move_gallery_exit)
    var export_self_test: bool = OS.get_environment("BRUCELEE_EXPORT_SELF_TEST") == "1"
    var story_mode: bool = OS.get_environment("BRUCELEE_STORY_FLOW") == "1"
    var game_mode: bool = not OS.get_environment("BRUCELEE_GAME_MODE").is_empty()
    # Opt-in progress/save subsystem: created only when BRUCELEE_PROGRESS=1, so
    # every existing prototype path is untouched when the flag is absent.
    if OS.get_environment("BRUCELEE_PROGRESS") == "1":
        progress = ProgressHooks.new()
        add_child(progress)
        progress.configure()
    if story_mode:
        story_flow = StoryFlow.new()
        add_child(story_flow)
        story_flow.configure(self, MENU_OPPONENT_CONFIG)
        story_flow.progress = progress
    game_modes = GameModes.new()
    add_child(game_modes)
    game_modes.configure(self, MENU_OPPONENT_CONFIG)
    game_modes.progress = progress
    # Opt-in Style Editor: decoded catalog + user:// selection file + screen.
    # With the flag off nothing is created here and the menu has no extra row;
    # the training menus create it lazily when their Style Editor option is
    # selected, so all six recovered pause options work.
    if OS.get_environment("BRUCELEE_STYLE_EDITOR") == "1":
        _ensure_style_editor()
    # Recovered attract/continue states.  The module is always created, but both
    # flows stay opt-in through BRUCELEE_ATTRACT / BRUCELEE_CONTINUE.
    native_states = NativeMatchStates.new()
    _configure_attract_flags()
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
    if OS.get_environment("BRUCELEE_TRAINING_FREE") == "1":
        # The free-training fighter dock changed the opponent through the same
        # env/reload path as the opponent menu.  Consume the flag and reopen the
        # sandbox against the newly loaded candidate.
        OS.set_environment("BRUCELEE_TRAINING_FREE", "")
        call_deferred("_resume_training_free")
    elif export_self_test:
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
    # SetState(0) routing: the opt-in attract intros run before the round intro
    # and fall through to it unchanged when the flag is off or a clip is absent.
    _start_attract_or_intro()


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
    # Temple Yard A is the default scene and keeps its assets in `scene/far`,
    # so its FX groups live in `scene/far/fx_anim`.  An empty BRUCELEE_SCENE
    # must therefore not skip this stage (it used to return here).
    var fx_dir: String = "scene/far/fx_anim"
    if not variant.is_empty():
        fx_dir = "scene/%s/fx_anim" % variant
    var base: String = OS.get_executable_path().get_base_dir().path_join(fx_dir)
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
        # Material (colour / UV offset) tracks cannot live in glTF.  The decoded
        # curves are per visual, so the driver replaces the shared material of
        # every visual the authored track addresses; entries without a decoded
        # track get null and keep the loader material above.
        if not used_static_group:
            var material_tracks: Node = FxMaterialTracks.attach(base, entry)
            if material_tracks != null:
                instance.add_child(material_tracks)
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


func _package_root() -> String:
    ## Directory that holds the stable models/ layout: BRUCELEE_PACKAGE_ROOT for
    ## validators running from the editor, otherwise the EXE directory.
    var configured: String = OS.get_environment("BRUCELEE_PACKAGE_ROOT").strip_edges()
    if not configured.is_empty():
        return CandidatePathGuard.normalize_absolute_path(configured).trim_suffix("/")
    return CandidatePathGuard.normalize_absolute_path(
        OS.get_executable_path().get_base_dir()
    ).trim_suffix("/")


func _sha256_file(path: String) -> String:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return ""
    var hashing: HashingContext = HashingContext.new()
    hashing.start(HashingContext.HASH_SHA256)
    var remaining: int = file.get_length()
    while remaining > 0:
        var chunk: PackedByteArray = file.get_buffer(mini(remaining, 1 << 20))
        if chunk.is_empty():
            break
        hashing.update(chunk)
        remaining -= chunk.size()
    file.close()
    return hashing.finish().hex_encode()


func _resolve_package_model(relative: String, expected_sha256: String) -> Dictionary:
    ## Returns {"path": absolute, "error": ""} only when the declared package
    ## model exists and matches its pinned hash.  An absent file returns an empty
    ## path with no error so the caller keeps the previous absolute fallback; a
    ## present file that does not match returns an error and the caller must fail
    ## closed instead of loading a different character/set.
    var relative_path: String = relative.strip_edges().replace("\\", "/")
    if relative_path.is_empty():
        return {"path": "", "error": ""}
    if (relative_path.is_absolute_path() or relative_path.begins_with("res://")
            or relative_path.begins_with("../") or relative_path.contains("/../")):
        return {"path": "", "error": "package model must be relative: " + relative}
    var absolute: String = _package_root().path_join(relative_path)
    if not FileAccess.file_exists(absolute):
        return {"path": "", "error": ""}
    if expected_sha256.strip_edges().is_empty():
        return {"path": "", "error": "package model has no pinned sha256: " + relative}
    var actual: String = _sha256_file(absolute)
    if actual != expected_sha256.strip_edges().to_lower():
        return {"path": "", "error": (
            "package model sha256 mismatch: " + absolute
            + " actual=" + actual + " expected=" + expected_sha256
        )}
    return {"path": absolute, "error": ""}


func _is_package_model_path(path: String) -> bool:
    var normalized: String = CandidatePathGuard.normalize_absolute_path(path).to_lower()
    var models_root: String = (
        _package_root().path_join(PACKAGE_MODELS_DIR).to_lower()
    )
    if not normalized.begins_with(models_root + "/"):
        return false
    return normalized.get_extension().to_lower() == "glb"


func _player_candidate_glb() -> String:
    ## An explicit, verified BRUCELEE_PLAYER_SKIN wins over the legacy
    ## BRUCELEE_PLAYER_GLB default that launch.ps1 still exports, so a package
    ## launcher can just set the skin name.  An unknown skin, a missing package
    ## model or a sha256 mismatch fails closed (placeholder fighter) instead of
    ## silently loading a different character.  With no skin set, the previous
    ## absolute-BR GLB path is used unchanged.
    var skin_id: String = OS.get_environment("BRUCELEE_PLAYER_SKIN").strip_edges()
    if skin_id.is_empty():
        return OS.get_environment("BRUCELEE_PLAYER_GLB")
    var entry: Variant = PLAYER_SKIN_CONFIG.get(skin_id)
    if not entry is Dictionary:
        push_error("BRUCELEE_PLAYER_SKIN=%s is not a verified player skin" % skin_id)
        return ""
    var resolved: Dictionary = _resolve_package_model(
        String(Dictionary(entry).get("glb_package", "")),
        String(Dictionary(entry).get("sha256", ""))
    )
    if not String(resolved["error"]).is_empty():
        push_error("player skin " + skin_id + ": " + String(resolved["error"]))
        return ""
    var path: String = String(resolved["path"])
    if path.is_empty():
        push_error("player skin " + skin_id + " package model is missing")
        return ""
    OS.set_environment(PACKAGE_MODELS_OPT_IN_ENV, "1" if _is_package_model_path(path) else "")
    return path


func _player_candidate_texture_root() -> String:
    var explicit: String = OS.get_environment("BRUCELEE_PLAYER_TEXTURE_ROOT")
    if not explicit.is_empty():
        return explicit
    if not OS.get_environment("BRUCELEE_PLAYER_SKIN").strip_edges().is_empty():
        return PLAYER_SKIN_TEXTURE_ROOT
    return ""


func _build_fighters() -> void:
    player = PortFighter.new()
    player.configure("Bruce (placeholder)", true, Color(0.85, 0.56, 0.18))
    player.polar_movement_enabled = true
    player.configure_candidate_asset(
        _player_candidate_glb(),
        _player_candidate_texture_root(),
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
    ## per match and draws the intro version before the victory version.  The
    ## intro draw is preserved: it selects the actual characters.list intro clip
    ## whose camera sub-animation is used in states 1/2/3.
    for fighter: PortFighter in [player, computer]:
        if fighter == null:
            continue
        fighter.select_intro_clip(_zmath_random_get())
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
    # CBeatEmUpMatch::Restart 0x161df4 -> CBeatEmUpGame::SetInitialRoundValues
    # 0x178d44: both fighters' animation-category records are cleared and the
    # new match starts.  NextRound -> RestartValues does not clear them, so this
    # is the only per-fight reset.
    fight_perfects = 0
    match_started_msec = Time.get_ticks_msec()
    if player != null:
        player.reset_anim_categories()
    if computer != null:
        computer.reset_anim_categories()
    # StartFight() builds the match configuration once per match, so the
    # result clips are re-drawn here and not in _reset_round().
    _select_match_result_clips()
    _result_camera_override = false
    # Re-apply the opt-in style selections after the fighter's clips/clip table
    # exist; a no-op unless BRUCELEE_STYLE_EDITOR=1 created the screen.
    _apply_style_editor()
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
    # A new match (which reaches this through _reset_match) also re-arms the
    # attract intros: the +0x82c counter restarts at 0.  The per-round path,
    # _start_next_round -> _start_round_intro, never consults the attract flag.
    _attract_played = false
    if native_states != null:
        native_states.reset()
        _configure_attract_flags()
    _hide_continue_prompt()
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
    # RestartValues() increments the +0x82c counter, so later rounds of the
    # same match skip the attract intros and go straight to SetState(3).
    _start_round_intro()

func _should_show_main_menu() -> bool:
    var setting: String = OS.get_environment("BRUCELEE_MAIN_MENU")
    if setting == "1":
        return true
    if setting == "0":
        return false
    return not OS.has_feature("editor")

# ------------------------------------------------ opt-in recovered art menu

func _setup_hud_art_menu() -> void:
    ## BRUCELEE_HUD_ART=1 creates the recovered selectfighter/fightpreview
    ## overlay on its own CanvasLayer (31), above the menu CanvasLayer (30).
    ## It never touches the in-fight HUD, which keeps drawing exactly what it
    ## drew before. With the flag off this function returns immediately and no
    ## extra node exists.
    if hud == null or not hud.hud_art_enabled():
        return
    hud_art_menu_layer = CanvasLayer.new()
    hud_art_menu_layer.name = "HudArtMenuLayer"
    hud_art_menu_layer.layer = 31
    add_child(hud_art_menu_layer)
    hud_art_menu_overlay = HudArtOverlayScript.new()
    hud_art_menu_overlay.name = "HudArtMenuOverlay"
    hud_art_menu_overlay.visible = false
    hud_art_menu_layer.add_child(hud_art_menu_overlay)


func _on_menu_selection_changed(state: String, _index: int, command: String) -> void:
    ## Drives the decoded selectfighter.ui dock from the menu's real OPPONENTS
    ## submenu. While the dock owns the screen the text panel is hidden (the
    ## recovered dock draws its own name label and has no text rows); every
    ## other menu state restores the panel and hides the dock.
    if hud_art_menu_overlay == null:
        return
    var dock_mode: bool = state == "opponents"
    if prototype_menu != null and prototype_menu.panel_box != null:
        prototype_menu.panel_box.visible = not dock_mode
    if not dock_mode:
        hud_art_menu_overlay.visible = false
        return
    # The recovered character-unlock gate also owns the dock: it validates that
    # the decoded selectfighter dock maps item -> character.  When that cannot be
    # proven, keep the text opponent rows (which carry the same lock state) rather
    # than draw a dock whose cards cannot be trusted.
    var gate = prototype_menu.fighter_gate if prototype_menu != null else null
    if gate != null and not bool(gate.dock_ok):
        _fighter_dock_fallback()
        return
    if command == "opponents_back":
        # BACK is not a fighter, so keep the last fighter highlight rather than
        # inventing a dock index for it.
        return
    var dock_index: int = int(HUD_ART_OPPONENT_DOCK.get(command, 0))
    var display_name: String = String(HUD_ART_OPPONENT_NAMES.get(command, ""))
    var drawn: bool = bool(hud_art_menu_overlay.show_select_fighter(
        dock_index, gate, display_name))
    if not drawn:
        _fighter_dock_fallback()
        return
    hud_art_menu_overlay.visible = true


## Fail-closed fallback for the recovered dock: hide the art layer and restore
## the text OPPONENTS panel, whose rows carry the same recovered lock state.
func _fighter_dock_fallback() -> void:
    hud_art_menu_overlay.visible = false
    if prototype_menu == null:
        return
    if prototype_menu.panel_box != null:
        prototype_menu.panel_box.visible = true
    prototype_menu.show_error("FIGHTER DOCK UNAVAILABLE - TEXT MENU")


func _hide_hud_art_menu() -> void:
    if hud_art_menu_overlay != null:
        hud_art_menu_overlay.visible = false


func _open_main_menu() -> void:
    _play_music("menu")
    main_menu_active = true
    menu_paused = false
    player.move_axis = Vector2.ZERO
    computer.move_axis = Vector2.ZERO
    hud.visible = false
    _hide_hud_art_menu()
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
    _hide_hud_art_menu()
    prototype_menu.show_pause_menu()
    get_tree().paused = true

func _leave_menu() -> void:
    main_menu_active = false
    menu_paused = false
    hud.visible = true
    _hide_hud_art_menu()
    if records_screen != null and records_screen.is_open():
        # Defensive: any path that leaves the menu also dismisses the records
        # screen, so its input layer can never survive into a fight.
        records_screen.close()
    if style_editor != null and style_editor.is_open():
        # Same guard for the Style Editor: closing it re-enables the menu's
        # input, and the caller then hides the menu below.
        style_editor.close()
    prototype_menu.hide_menu()
    get_tree().paused = false

func _open_records_screen() -> void:
    ## RECORDS row (only present while BRUCELEE_PROGRESS=1). The screen renders
    ## the live service state; the menu stays alive behind its opaque backdrop so
    ## closing it restores the exact selection and the paused main menu.
    ## Opening it is read-only: it never flushes the save, so browsing RECORDS
    ## cannot rewrite (or "repair") a player's save file.
    if progress == null:
        prototype_menu.show_error("RECORDS NEEDS BRUCELEE_PROGRESS=1")
        return
    if records_screen == null:
        records_screen = RecordsScreen.new()
        records_screen.name = "ProgressRecords"
        add_child(records_screen)
        records_screen.configure(progress)
        records_screen.closed.connect(_on_records_closed)
    records_screen.open()
    if prototype_menu != null:
        # The records layer owns keyboard/joypad input while it is up.
        prototype_menu.set_process_input(false)
    hud.visible = false

func _on_records_closed() -> void:
    if prototype_menu != null:
        prototype_menu.set_process_input(true)
    if main_menu_active:
        hud.visible = false
        get_tree().paused = true

func _ensure_style_editor() -> bool:
    ## The recovered training menus expose Style Editor (practice menu and the
    ## six-option pause), so the screen is created lazily even without the main
    ## menu's BRUCELEE_STYLE_EDITOR row.  Failure is reported, never faked.
    if style_editor != null:
        return true
    style_catalog = StyleCatalog.new()
    if not style_catalog.load_catalog():
        push_warning("Style Editor catalog failed closed: " + style_catalog.error)
        style_catalog = null
        style_store = null
        return false
    style_store = StyleSelectionStore.new()
    style_store.load_selections(style_catalog)
    style_editor = StyleEditorScreen.new()
    add_child(style_editor)
    style_editor.configure(self, player, style_catalog, style_store)
    style_editor.closed.connect(_on_style_editor_closed)
    style_editor.try_requested.connect(_on_style_try)
    style_editor.selection_saved.connect(_on_style_selection_saved)
    return true


func _open_style_editor() -> void:
    ## Main-menu STYLE EDITOR row (only present while BRUCELEE_STYLE_EDITOR=1)
    ## and the recovered training menus both land here.
    if not _ensure_style_editor():
        if prototype_menu != null:
            prototype_menu.show_error("STYLE EDITOR DATA NOT RECOVERED")
        if move_training != null:
            move_training.show_notice("STYLE EDITOR DATA NOT RECOVERED", true)
        return
    _apply_style_editor()
    style_editor.open()
    if prototype_menu != null:
        prototype_menu.set_process_input(false)
        prototype_menu.visible = false
    hud.visible = false
    get_tree().paused = true

func _on_style_editor_closed() -> void:
    ## In-training returns to the screen that opened the editor; the main menu
    ## keeps its existing pause state.
    if move_training != null and move_training.visible:
        move_training.on_style_editor_closed()
        hud.visible = false
        get_tree().paused = String(move_training.state) == "pause"
        return
    if prototype_menu != null:
        prototype_menu.set_process_input(true)
        if main_menu_active:
            prototype_menu.visible = true
    if main_menu_active:
        hud.visible = false
        get_tree().paused = true


func _on_training_style_editor_requested() -> void:
    _open_style_editor()


func _on_training_free_fighter_requested(opponent_key: String) -> void:
    ## Free training fighter choice.  The current candidate starts in-session;
    ## any other recovered fighter uses the opponent-menu env/reload path and is
    ## reopened as free training by _resume_training_free().
    if opponent_key == training_current_opponent_key():
        move_training.enter_free_training()
        return
    if not MENU_OPPONENT_CONFIG.has(opponent_key):
        move_training.show_notice("TRAINING FIGHTER IS NOT RECOVERED", true)
        return
    OS.set_environment("BRUCELEE_TRAINING_FREE", "1")
    _request_opponent_switch(opponent_key)


func _resume_training_free() -> void:
    if not _training_available():
        return
    move_training.open()
    move_training.enter_free_training()


func training_opponent_keys() -> Array[String]:
    var out: Array[String] = []
    for key: Variant in MENU_OPPONENT_CONFIG:
        out.append(String(key))
    return out


func training_current_opponent_key() -> String:
    var configured := OS.get_environment("BRUCELEE_OPPONENT_NAME_KEY")
    if MENU_OPPONENT_CONFIG.has(configured):
        return configured
    var attack_config := _opponent_attack_config()
    for key: Variant in MENU_OPPONENT_CONFIG:
        var entry: Variant = MENU_OPPONENT_CONFIG[key]
        if entry is Dictionary and String(
                Dictionary(entry).get("attack_config", "")) == attack_config:
            return String(key)
    return "brick"

func _on_style_selection_saved(_group_key: String, _entry_id: String) -> void:
    _apply_style_editor()

func _apply_style_editor() -> void:
    ## Push the saved selections into the player. apply_style_selections()
    ## itself fails closed and reports every group it did not apply.
    if style_editor == null or style_store == null or style_catalog == null or player == null:
        return
    var report: Dictionary = player.apply_style_selections(
        style_store.selections, style_catalog
    )
    report["file"] = style_store.save_path
    report["file_loaded"] = style_store.loaded_ok
    report["file_error"] = style_store.last_error
    style_editor.set_apply_report(report)

func _on_style_try() -> void:
    ## try_style is the recovered "training" command: enter training only when
    ## at least one style actually applied a direct clip; otherwise stay in the
    ## editor and explain why nothing can be tried.
    if style_editor == null:
        return
    _apply_style_editor()
    var report: Dictionary = style_editor.apply_report()
    if not bool(report.get("animations_loaded", false)):
        style_editor.show_status("TRY STYLE NEEDS A LOADED FIGHTER CANDIDATE", true)
        return
    var applied: Array = report.get("applied", [])
    if applied.is_empty():
        style_editor.show_status("NO DIRECT CLIP APPLIED · NOTHING TO TRY", true)
        return
    if not _training_available():
        style_editor.show_status("TRAINING NEEDS CANDIDATE ANIMATIONS", true)
        return
    training_mode = true
    _leave_menu()
    _reset_match()
    _start_round_intro()

func _on_menu_command(command: String) -> void:
    var confirm_attack: bool = (
        prototype_menu != null and prototype_menu.last_accept_was_attack
    )
    if prototype_menu != null:
        prototype_menu.last_accept_was_attack = false
    if command in ["fight", "training", "move_training", "gallery"]:
        _play_music("fight")
    if MENU_SCENE_COMMANDS.has(command):
        # Scene entries switch BRUCELEE_SCENE and reload into the selected arena.
        # The text scene rows and the recovered scene dock emit the same
        # commands, so this is the one place a scene is applied.
        _request_scene_switch(command)
        return
    match command:
        "fight":
            training_mode = false
            _leave_menu()
            _reset_match()
            _start_attract_or_intro()
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
        "records":
            _open_records_screen()
        "style_editor":
            _open_style_editor()
        "restart":
            _leave_menu()
            _reset_match()
        "main_menu":
            _open_main_menu()
        "brick", "sinfu", "master", "ken", "shenlo", "smallboy", "johnson", "chief", "loming":
            _request_opponent_switch(command)
        "quit":
            get_tree().quit()

    if confirm_attack and command in ["fight", "training"]:
        call_deferred("_apply_menu_confirm_attack")

## Scene command -> BRUCELEE_SCENE variant.  The ten scene entries are exactly
## the rows of the decoded `sceneries.list` (`port_scene_variant`); "" is the
## default Temple Yard A arena.  `scene_catalog.gd` builds the recovered dock
## from the same table and a test keeps the two in step.
const MENU_SCENE_COMMANDS: Dictionary = {
    "temple_a": "",
    "temple_b": "templeyardb",
    "halla": "halla",
    "squarea": "squarea",
    "squareb": "squareb",
    "harboura": "harboura",
    "harbourb": "harbourb",
    "rooftopsa": "rooftopsa",
    "rooftopsb": "rooftopsb",
    "tournamenthallb": "tournamenthallb",
}

func _request_scene_switch(command: String) -> void:
    ## Two things must happen before a scene reload, for the same reasons as the
    ## opponent switch below:
    ##  1. leave the menu, because the main menu pauses the SceneTree and
    ##     reloading inside a paused tree builds the new match frozen (nothing in
    ##     it processes, so the round intro never finishes);
    ##  2. defer the reload, because this runs inside the menu's input/signal
    ##     callback and the menu being freed is the node dispatching the event.
    _leave_menu()
    call_deferred("_apply_scene_switch", command)

func _apply_scene_switch(command: String) -> void:
    if not MENU_SCENE_COMMANDS.has(command):
        return
    OS.set_environment("BRUCELEE_SCENE", String(MENU_SCENE_COMMANDS[command]))
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    get_tree().reload_current_scene()


func _request_opponent_switch(command: String) -> void:
    ## Opponent entries rebuild the fighters with the selected candidate. Two
    ## things must happen before the reload:
    ##  1. leave the menu, because reloading while SceneTree.paused is set builds
    ##     the new scene inside a paused tree (everything freezes);
    ##  2. defer the reload, because this runs inside the menu's input/signal
    ##     callback and the menu being freed is the node currently dispatching
    ##     the event.
    if hud_art_menu_overlay != null:
        # BRUCELEE_HUD_ART=1: show the decoded fightpreview.ui VS screen for the
        # actual selected opponent. The menu paused the tree, so the fight runs
        # frozen underneath while the screen is held; it is hidden again before
        # the reload enters the fight.
        var display_name: String = String(
            HUD_ART_OPPONENT_NAMES.get(command, "BRICK DAVIS")
        )
        hud_art_menu_overlay.show_vs_preview(HUD_ART_PLAYER_KEY, display_name)
        hud_art_menu_overlay.visible = true
        if prototype_menu != null:
            prototype_menu.hide_menu()
        await get_tree().create_timer(HUD_ART_VS_HOLD_SECONDS, true).timeout
        hud_art_menu_overlay.visible = false
    _leave_menu()
    call_deferred("_apply_opponent_switch", command)


func _selected_opponent_config(config: Dictionary) -> Dictionary:
    ## Applies the optional BRUCELEE_OPPONENT_SKIN variant on top of the entry.
    ## A named variant must exist under "skins" and must belong to the entry's
    ## fighting set; anything else fails closed (empty result) so the current
    ## match keeps its already-loaded candidate instead of switching silently.
    var merged: Dictionary = config.duplicate(true)
    var skin_id: String = OS.get_environment("BRUCELEE_OPPONENT_SKIN").strip_edges()
    if skin_id.is_empty():
        return merged
    var variants: Variant = merged.get("skins")
    if not variants is Dictionary:
        push_error("BRUCELEE_OPPONENT_SKIN=%s but this opponent has no variants" % skin_id)
        return {}
    var variant: Variant = Dictionary(variants).get(skin_id)
    if not variant is Dictionary:
        push_error("BRUCELEE_OPPONENT_SKIN=%s is not a verified variant" % skin_id)
        return {}
    var variant_config: Dictionary = variant
    var variant_set: String = String(
        variant_config.get("attack_config", merged.get("attack_config", ""))
    )
    if variant_set != String(merged.get("attack_config", "")):
        push_error("variant %s does not belong to %s" % [
            skin_id, String(merged.get("attack_config", "")),
        ])
        return {}
    for key: Variant in variant_config:
        merged[key] = variant_config[key]
    merged["skin"] = skin_id
    return merged


func _resolved_opponent_glb(config: Dictionary) -> Dictionary:
    ## Prefers the verified package model, keeps the previous absolute "glb" as
    ## the fallback when the package file is absent, and returns a non-empty
    ## error (fail closed) when a present package model fails its hash pin.
    var packaged: String = String(config.get("glb_package", ""))
    if not packaged.is_empty():
        var resolved: Dictionary = _resolve_package_model(
            packaged, String(config.get("sha256", ""))
        )
        if not String(resolved["error"]).is_empty():
            return {"glb": "", "error": String(resolved["error"])}
        if not String(resolved["path"]).is_empty():
            return {"glb": String(resolved["path"]), "error": ""}
    return {"glb": String(config.get("glb", "")), "error": ""}


func _stage_opponent_environment(command: String, config: Dictionary) -> bool:
    ## Writes the BRUCELEE_OPPONENT_* environment for an already merged config.
    ## Returns false without touching any variable when a present package model
    ## fails its identity pin.  Shared by the menu switch and the load validator
    ## so both use exactly the same resolution path.
    var selection: Dictionary = _resolved_opponent_glb(config)
    if not String(selection["error"]).is_empty():
        push_error("opponent " + command + ": " + String(selection["error"]))
        return false
    var chosen_glb: String = String(selection["glb"])
    OS.set_environment(
        PACKAGE_MODELS_OPT_IN_ENV, "1" if _is_package_model_path(chosen_glb) else ""
    )
    OS.set_environment("BRUCELEE_OPPONENT_GLB", chosen_glb)
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
    return true


func _apply_opponent_switch(command: String) -> void:
    var config_value: Variant = MENU_OPPONENT_CONFIG.get(command)
    if not config_value is Dictionary:
        return
    var config: Dictionary = _selected_opponent_config(Dictionary(config_value))
    if config.is_empty():
        return
    if not _stage_opponent_environment(command, config):
        return
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
    training_mode = false
    hud.visible = true
    _open_main_menu()


## Called by the recovered training screen when a lesson training starts.
## The fight loop is the normal training_mode loop (no AI); the screen drives
## the dummy and observes the player's real native actions.
func begin_training_session() -> void:
    training_mode = true
    _leave_menu()
    _reset_match()
    hud.visible = true
    if player != null:
        player.set_physics_process(true)
    if computer != null:
        computer.set_physics_process(true)


## Called by the training screen when it returns to the select list or leaves.
func end_training_session() -> void:
    training_mode = false
    done = false
    training_completed = false
    hud.visible = false
    if get_tree() != null:
        get_tree().paused = false
    if player != null:
        player.attack_root_motion_enabled = true
        player.set_physics_process(true)
    if computer != null:
        computer.set_physics_process(true)


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


func _configure_attract_flags() -> void:
    ## SetState(0) plays the attract intros only while the per-fighter flags at
    ## +0x830 / +0x831 are set.  The port treats "the candidate GLB carries the
    ## character's characters.list intro clip" as that flag: a character whose
    ## intro clip is absent can never enter state 1 or 2.
    if native_states == null:
        return
    native_states.attract_fighter0_available = not _intro_clip_for(player).is_empty()
    native_states.attract_fighter1_available = not _intro_clip_for(computer).is_empty()


## characters.list animations.intro pool for a fighter, in archive order.  The
## fighter carries the pool configured from characters.list; the static tables
## remain only as a fallback for a fighter constructed outside the normal setup.
func _intro_pool_for(fighter: PortFighter) -> Array[String]:
    if fighter == null:
        return []
    var configured: Array[String] = fighter.intro_clip_pool()
    if not configured.is_empty():
        return configured
    if fighter == player:
        return INTRO_CLIPS_PLAYER
    var opponent_id: String = OS.get_environment("BRUCELEE_OPPONENT_NAME_KEY")
    var pool: Variant = INTRO_CLIPS_BY_OPPONENT.get(opponent_id, [])
    var names: Array[String] = []
    for entry in pool:
        names.append(String(entry))
    return names


## The actual selected characters.list intro clip, but only when the candidate
## GLB contains it.  Empty means the selected clip was not shipped with this
## candidate: fail closed rather than substitute another character's intro.
func _intro_clip_for(fighter: PortFighter) -> String:
    if fighter == null:
        return ""
    var clips: Dictionary = fighter.get("_candidate_clip_paths")
    var selected: String = fighter.selected_intro_clip()
    if not selected.is_empty():
        return selected if clips.has(selected) else ""
    for clip_name in _intro_pool_for(fighter):
        if clips.has(clip_name):
            return clip_name
    return ""


func _intro_clip_seconds(fighter: PortFighter, clip_name: String) -> float:
    var animation: AnimationPlayer = fighter.get("_candidate_animation")
    var clips: Dictionary = fighter.get("_candidate_clip_paths")
    if animation == null or not clips.has(clip_name):
        return -1.0
    var clip: Animation = animation.get_animation(String(clips[clip_name]))
    if clip == null:
        return -1.0
    return clip.length


func _play_intro_clip(fighter: PortFighter, clip_name: String) -> void:
    var other: PortFighter = computer if fighter == player else player
    fighter.visible = true
    other.visible = false
    fighter.global_position = Vector3(0.0, 1.20, 0.0)
    other.global_position = Vector3(0.0, 1.20, 0.0)
    fighter.move_axis = Vector2.ZERO
    other.move_axis = Vector2.ZERO
    # The candidate idle clips are frozen on their first frame; an intro must
    # actually play, so drive the AnimationPlayer directly.
    var animation: AnimationPlayer = fighter.get("_candidate_animation")
    var clips: Dictionary = fighter.get("_candidate_clip_paths")
    if animation == null or not clips.has(clip_name):
        return
    var clip: Animation = animation.get_animation(String(clips[clip_name]))
    if clip != null:
        clip.loop_mode = Animation.LOOP_NONE
    animation.speed_scale = 1.0
    animation.play(String(clips[clip_name]))
    fighter.set("_candidate_action", clip_name)


func _start_attract_or_intro() -> void:
    ## SetState(0) with the +0x82c counter still at 0: state 1, else state 2,
    ## else the round intro.  A missing candidate clip refuses the attract
    ## state and the round intro plays instead.  Opt-in: BRUCELEE_ATTRACT=1,
    ## because the port cannot prove which match configs set +0x830/+0x831.
    if (OS.get_environment("BRUCELEE_ATTRACT") != "1"
            or native_states == null or _attract_played or training_mode
            or OS.get_environment("BRUCELEE_ROUND_INTRO") == "0"):
        _start_round_intro()
        return
    _configure_attract_flags()
    var target: int = native_states.set_state_zero_target(false)
    if target == -1 or not _enter_attract_state(target):
        _start_round_intro()


func _enter_attract_state(target: int) -> bool:
    var fighter: PortFighter = player if target == MATCH_STATE_ATTRACT_FIGHTER0 else computer
    var clip_name: String = _intro_clip_for(fighter)
    var clip_seconds: float = _intro_clip_seconds(fighter, clip_name)
    if not native_states.enter(target, clip_name, clip_seconds):
        print("NATIVE_STATE_REFUSED %s" % native_states.fail_reason)
        return false
    _enter_match_state(target)
    _play_intro_clip(fighter, clip_name)
    # SetState(1)/(2) moves both fighters to the origin before CameraUpdate; the
    # camera dummy is fighter0 for state 1 and fighter1 for state 2, so use the
    # actual fighter anchor and allow the degenerate A==B point (native atan2(0,0)
    # is 0, giving the fixed pi/2 dummy yaw).  Missing camera JSON fails closed
    # to the analytic view.
    _intro_camera_begin(fighter, false, clip_name, true)
    print("NATIVE_STATE_ENTER state=%d clip=%s seconds=%.3f" % [
        target, clip_name, clip_seconds])
    return true


func _advance_attract(delta: float) -> void:
    if native_states == null or not native_states.active:
        _start_round_intro()
        return
    var skip_pressed: bool = Input.is_action_just_pressed(PrototypeControls.ATTACK_A)
    var target: int = native_states.advance(delta, skip_pressed)
    if target == -1:
        return
    _attract_played = true
    if target == NativeMatchStates.NO_TARGET_EXIT:
        _start_round_intro()
        return
    if target == MATCH_STATE_ATTRACT_FIGHTER1 and _enter_attract_state(target):
        return
    _start_round_intro()


func _enter_continue_state() -> bool:
    ## SetState(9): LaunchGameTextAnimation(10) (GREAT, low) and hand the
    ## continue choice to the arcaderetryask UI state.  The countdown length at
    ## +0x850 is unrecovered, so the prompt waits for YES / NO and shows the
    ## gap instead of counting down.
    if native_states == null:
        return false
    if not native_states.enter(MATCH_STATE_CONTINUE):
        print("NATIVE_STATE_REFUSED %s" % native_states.fail_reason)
        return false
    _enter_match_state(MATCH_STATE_CONTINUE)
    _show_game_text("GREAT", 0.0, GAME_TEXT_SEQ_GREAT_LOW)
    _show_continue_prompt()
    print("NATIVE_STATE_ENTER state=%d continue_countdown=UNRECOVERED timeout_action=%s (unit unrecovered)" % [
        MATCH_STATE_CONTINUE, NativeMatchStates.CONTINUE_ACTION_TIMEOUT])
    return true


func _show_continue_prompt() -> void:
    _hide_continue_prompt()
    _continue_layer = CanvasLayer.new()
    _continue_layer.layer = 30
    var panel: ColorRect = ColorRect.new()
    panel.color = Color(0.0, 0.0, 0.0, 0.6)
    panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    _continue_layer.add_child(panel)
    var label: Label = Label.new()
    label.name = "ContinuePrompt"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.set_anchors_preset(Control.PRESET_FULL_RECT)
    label.add_theme_font_size_override("font_size", 28)
    _continue_layer.add_child(label)
    add_child(_continue_layer)
    _refresh_continue_prompt()


func _refresh_continue_prompt() -> void:
    if _continue_layer == null:
        return
    var label: Label = _continue_layer.get_node_or_null("ContinuePrompt")
    if label == null:
        return
    var yes_mark: String = ">" if native_states.continue_menu_index == 0 else " "
    var no_mark: String = ">" if native_states.continue_menu_index == 1 else " "
    # gui/continueask.ui binds this number to the ["game","continuecountdown"]
    # datasource, answered by CBeatEmUpMatch::QueryString:
    # (11000 - GetStateTime()) / 1000 clamped to 10 while the native game runs
    # the replay state, which PlayerLost starts together with ArcadeRetryAsk.
    var seconds: int = native_states.continue_countdown_seconds()
    label.text = "CONTINUE?\n%d\n%s YES      %s NO" % [seconds, yes_mark, no_mark]


## Drives the continue prompt's clock.  game.states "arcaderetryask" holds its
## timeout as the integer action key 10, and the state manager's per-state
## clock fires integer keys at that many seconds, so the prompt resolves 10 s
## after it opens with the "#10" action (the same destination as "no").
func _update_continue_prompt(delta: float) -> void:
    if match_state != MATCH_STATE_CONTINUE or native_states == null:
        return
    if not native_states.active:
        return
    if native_states.continue_resolved:
        _resolve_continue(native_states.continue_choice)
        return
    native_states.advance(delta)
    if native_states.continue_resolved:
        _resolve_continue(native_states.continue_choice)
        return
    _refresh_continue_prompt()


func _hide_continue_prompt() -> void:
    if _continue_layer != null and is_instance_valid(_continue_layer):
        _continue_layer.queue_free()
    _continue_layer = null


func _resolve_continue(action: String) -> void:
    if native_states == null:
        return
    var applied: String = action
    if not native_states.continue_resolved:
        applied = native_states.choose_continue(action)
        if applied.is_empty():
            return
    if applied == NativeMatchStates.CONTINUE_ACTION_NEXT_TRAINING_STEP:
        # +0x850 (TrainingSetStep) expiry: the training driver advances the step
        # itself; do not route to the main menu.
        return
    _hide_continue_prompt()
    _hide_game_text_overlays()
    print("NATIVE_STATE_CONTINUE choice=%s" % applied)
    if applied == NativeMatchStates.CONTINUE_ACTION_YES:
        # arcaderetryask "yes" -> "restartfight" -> "fightrestarted" -> "game":
        # the same match starts again.
        _attract_played = false
        _reset_match()
        _start_attract_or_intro()
        return
    # "no" and the "#10" timeout both leave towards the main menu.
    _open_main_menu()


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
    var intro_clip: String = _intro_clip_for(player)
    if intro_clip.is_empty():
        _intro_camera_end()
    else:
        _intro_camera_begin(player, false, intro_clip)
    _intro_fight_shown = false
    _show_game_text("READY", 0.8, GAME_TEXT_SEQ_READY)
    # Ready_Alt_1.wav is the recovered sample of game-text record 0 and is
    # scheduled by _show_game_text; do not play it a second time here.


func _load_bruce_voice_audio() -> void:
    # Deduplicate by file: several actions share the same WAV, and the original
    # implementation decoded it once per action key.  `_voice_file_cache` keys
    # the decode by archive path so the same file is only read once.
    var voices: Dictionary = AudioCueMap.voice_files()
    for action: String in voices:
        var filename: String = String(voices[action])
        var loaded: AudioStream = _load_voice_archive_file(
            "sounds/voices/bruce_lee/" + filename
        )
        if loaded == null:
            _voice_audio_error[action] = "Bruce voice failed to load: " + filename
            continue
        _voice_audio[action] = loaded
    _preload_voice_cue_files()


func _preload_voice_cue_files() -> void:
    ## Warm every voice cue the runtime can schedule.  AudioStreamWAV decode is
    ## synchronous (over a second per file on this machine), so paying it here
    ## is what lets the attack/hit path honour frame/30 without a hitch.
    var files: Dictionary = {}
    for kind: String in AudioCueMap.CUES:
        for value: Variant in AudioCueMap.CUES[kind]:
            if value is Dictionary:
                files["sounds/voices/bruce_lee/" + String(
                    Dictionary(value).get("file", "")
                )] = true
    for key: String in AudioCueMap.PAIN:
        files["sounds/voices/bruce_lee/" + String(AudioCueMap.PAIN[key])] = true
    for action: String in VoiceCueTiming.VOICE_ACTIONS:
        for value: Variant in VoiceCueTiming.VOICE_ACTIONS[action]:
            if value is Dictionary:
                files[String(Dictionary(value).get("file", ""))] = true
    files.erase("")
    for file: String in files:
        if file.begins_with("sounds/voices/bruce_lee/"):
            _load_voice_archive_file(file)


func _load_voice_for_action(action: String) -> AudioStream:
    if _voice_audio.has(action):
        return _voice_audio[action] as AudioStream
    var voices: Dictionary = AudioCueMap.voice_files()
    if not voices.has(action):
        return null
    var stream: AudioStream = _load_voice_archive_file(
        "sounds/voices/bruce_lee/" + String(voices[action])
    )
    if stream != null:
        _voice_audio[action] = stream
    return stream


func _on_player_attack_started(action: String) -> void:
    # Non-voice swing/step/clothing cues for the same original set action are
    # independent of the Bruce voice table (some actions have SFX but no voice).
    _play_attack_sfx(action)
    # Voice cues keep the recovered `sounds[].frame`: a f4 cue starts 4/30 s
    # after the action starts, not at action start.  volume, unique and
    # is_voice are carried by the table and applied here.
    _play_attack_voice(action)


func _play_attack_voice(action: String) -> void:
    var cues: Array = VoiceCueTiming.attack_voice_cues(action)
    var played: int = _play_voice_cues(cues, "brucelee", "attack_voice:" + action)
    if played > 0:
        return
    # Start-of-action fallback: the legacy voice table carries the same primary
    # cue for this action but no set frame, so play it immediately as before.
    var cue: Dictionary = AudioCueMap.primary_cue(action)
    if cue.is_empty():
        return
    var stream: AudioStream = _voice_audio.get(action)
    if stream == null:
        stream = _load_voice_for_action(action)
    if stream == null:
        return
    _schedule_voice_cue(
        stream, clampf(float(cue.get("volume", 1.0)), 0.001, 1.0),
        "attack_voice:" + action, String(cue.get("file", "")),
        cue.get("frame", null), ""
    )


func _play_voice_cues(cues: Array, character_id: String, label: String) -> int:
    ## Schedules every recovered voice cue at its own frame/30 s offset.
    ## Returns the number of cues actually started (0 when the set has no cue
    ## for this action, for this character, or the package lacks the WAV).
    var played: int = 0
    var seen: Dictionary = {}
    for value: Variant in cues:
        if not value is Dictionary:
            continue
        var cue: Dictionary = value
        if not bool(cue.get("is_voice", true)):
            continue
        if not VoiceCueTiming.cue_matches(cue, character_id):
            continue
        var file: String = String(cue.get("file", ""))
        if file.is_empty():
            continue
        var frame_value: Variant = cue.get("frame", null)
        var volume: float = clampf(float(cue.get("volume", 1.0)), 0.001, 1.0)
        var unique: String = String(cue.get("unique", ""))
        var dedupe: String = "%s|%s|%.3f|%s" % [
            file, str(frame_value), volume, unique
        ]
        if seen.has(dedupe):
            continue
        seen[dedupe] = true
        var stream: AudioStream = _load_voice_archive_file(file)
        if stream == null:
            continue
        _schedule_voice_cue(stream, volume, label, file, frame_value, unique)
        played += 1
    return played


func _schedule_voice_cue(
        stream: AudioStream, volume: float, label: String, file: String,
        frame_value: Variant, unique: String
) -> void:
    var delay: float = 0.0
    if frame_value != null:
        delay = maxf(float(frame_value), 0.0) / VoiceCueTiming.FRAME_RATE
    var scheduled_ms: int = Time.get_ticks_msec()
    if delay <= 0.0001:
        _spawn_voice(
            stream, volume, label, file, frame_value, delay, scheduled_ms, unique
        )
        return
    get_tree().create_timer(delay).timeout.connect(
        _spawn_voice.bind(
            stream, volume, label, file, frame_value, delay, scheduled_ms, unique
        )
    )


func _spawn_voice(
        stream: AudioStream, volume: float, label: String, file: String,
        frame_value: Variant, delay: float, scheduled_ms: int, unique: String
) -> void:
    if not is_instance_valid(combat_audio):
        return
    var voice: AudioStreamPlayer = AudioStreamPlayer.new()
    voice.stream = stream
    voice.volume_db = linear_to_db(volume)
    voice.finished.connect(voice.queue_free)
    # The port has always run one Bruce voice at a time; keep that so a pain
    # grunt can interrupt a swing grunt instead of stacking them.
    if is_instance_valid(_active_voice) and _active_voice != voice:
        _active_voice.stop()
        if not _active_voice.is_queued_for_deletion():
            _active_voice.queue_free()
    combat_audio.add_child(voice)
    _active_voice = voice
    voice.play()
    _record_cue_play(
        label, file, volume, frame_value, delay, scheduled_ms, true, unique
    )


func _load_voice_archive_file(file: String) -> AudioStream:
    ## `file` is the set's archive-relative voice path
    ## (`sounds/voices/bruce_lee/<dir>/<name>.wav`).  Only Bruce's own takes are
    ## resolvable through the player voice root; other characters stay with the
    ## opt-in opponent overlay.
    if file.is_empty():
        return null
    if _voice_file_cache.has(file):
        return _voice_file_cache[file] as AudioStream
    var relative: String = file
    const BRUCE_PREFIX := "sounds/voices/bruce_lee/"
    if relative.begins_with(BRUCE_PREFIX):
        relative = relative.substr(BRUCE_PREFIX.length())
    elif relative.begins_with("sounds/voices/"):
        _voice_file_cache[file] = null
        return null
    var stream: AudioStream = null
    for root: String in _voice_roots():
        var path: String = root.path_join(relative)
        var error: String = CandidatePathGuard.external_path_error(
            path, "Bruce voice timing"
        )
        if not error.is_empty():
            continue
        stream = AudioStreamWAV.load_from_file(path)
        if stream != null:
            break
    _voice_file_cache[file] = stream
    return stream


func _on_opponent_attack_started(action: String) -> void:
    # Only set-specific cues that exist in the opponent's own fighting set are
    # added here (currently KungFu faceupattack -> Clothing_2).  The player's
    # Bruce cue table is not applied to another character's animation.
    _play_opponent_voice(action)
    if not _sfx_ready():
        return
    var cues: Array = SfxMusicMap.set_cues(_opponent_set_family(), action)
    if cues.is_empty():
        return
    # `unique` rows are fighting-set character variants; only this opponent's own
    # take (or a generic row) may play for its animation.
    _play_sfx_cues(cues, "opponent_attack:" + action, _opponent_set_character())


func _play_attack_sfx(action: String) -> void:
    if not _sfx_ready():
        return
    var cues: Array = SfxMusicMap.attack_cues(action)
    if cues.is_empty():
        return
    _play_sfx_cues(cues, "attack:" + action, "brucelee")


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
    # Bruce uses the recovered set table (frame / volume / unique / is_voice);
    # every opponent also has recovered pain takes in its own fighting set,
    # routed through the opt-in overlay so a default build stays silent for
    # non-player fighters exactly as before.
    if defender != player:
        _play_opponent_pain_voice(defender)
        return
    var reaction_action: String = defender.last_reaction_source_action
    var cues: Array = VoiceCueTiming.voice_cues(reaction_action)
    if cues.is_empty() and action == "special_punch_low_hit":
        # The special punch low impact reaction is not recorded as its own
        # reaction source in the port; the set gives specialpunchlowimpact a
        # heavy pain voice, so map this single attack explicitly.
        reaction_action = "specialpunchlowimpact"
        cues = VoiceCueTiming.voice_cues(reaction_action)
    if not cues.is_empty():
        var played: int = _play_voice_cues(
            cues, "brucelee", "pain_voice:" + reaction_action
        )
        if played > 0:
            return
    _play_legacy_pain_voice(reaction_action, action)


func _play_legacy_pain_voice(reaction_action: String, action: String) -> void:
    ## Start-of-action fallback for setups that have no set-derived voice table
    ## (editor runs / stripped package): the legacy fixed cue, unchanged.
    var cue_name: String = ""
    if PAIN_VOICE_CUES.has(reaction_action):
        cue_name = String(PAIN_VOICE_CUES[reaction_action])
    elif action == "special_punch_low_hit":
        cue_name = String(PAIN_VOICE_CUES.get("specialpunchlowimpact", ""))
    if cue_name.is_empty():
        return
    var stream: AudioStream = _load_voice_archive_file(
        "sounds/voices/bruce_lee/" + cue_name
    )
    if stream == null:
        return
    _spawn_voice(
        stream, db_to_linear(4.0), "pain_voice:" + reaction_action,
        cue_name, null, 0.0, Time.get_ticks_msec(), "brucelee"
    )


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


## Opponent voice overlay (opt-in). Resolves
##   opponent id -> port attack slot -> recovered set action -> WAV
## from res://data/opponent_voice_cues.json and stays inert unless
## BRUCELEE_OPPONENT_VOICE is "1".
func _opponent_voice_overlay():
    if _opponent_voice != null:
        return _opponent_voice
    _opponent_voice = OpponentVoiceOverlayScript.new()
    _opponent_voice_error = _opponent_voice.configure(combat_audio)
    if not _opponent_voice_error.is_empty():
        push_warning("opponent voice overlay disabled: " + _opponent_voice_error)
    return _opponent_voice


func _opponent_voice_id() -> String:
    var overlay = _opponent_voice_overlay()
    return String(overlay.opponent_id_for_config(_opponent_attack_config()))


func _play_opponent_voice(action: String) -> void:
    var overlay = _opponent_voice_overlay()
    if not overlay.is_ready():
        return
    var opponent_id: String = _opponent_voice_id()
    if opponent_id.is_empty():
        return
    overlay.play_attack(opponent_id, action)


func _play_opponent_pain_voice(defender: PortFighter) -> void:
    var overlay = _opponent_voice_overlay()
    if not overlay.is_ready():
        return
    var opponent_id: String = _opponent_voice_id()
    if opponent_id.is_empty():
        return
    overlay.play_pain(opponent_id, defender.last_reaction_source_action)


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
                # The defender's own fighting set owns these reaction samples, so
                # its `unique` tag selects the take (Bruce vs. the opponent).  The
                # dedup group is per defender so a simultaneous identical reaction
                # on the other fighter is not cancelled.
                _play_sfx_cues(
                    filtered, "reaction:" + reaction,
                    _fighter_set_character(defender),
                    "reaction:%s:%d" % [reaction, defender.get_instance_id()]
                )
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


func _play_sfx_cues(
        cues: Array, label: String, character_id: String = "", group: String = ""
) -> void:
    ## Frame values are the recovered 30 fps source frames, so a cue at f12 is
    ## scheduled 12/30 s after the event instead of being flattened to frame 0.
    ## `unique` is the fighting-set character variant; empty means generic.
    ## Exact duplicate rows are played once (the _brick mapping rows concatenate
    ## the same cue for several opponent variants).
    ##
    ## Per-action dedup: `group` (defaulting to `label`) identifies this action
    ## instance (``attack:punch``, ``reaction:impactbrutalmid:<defender>``, ...).
    ## Restarting the same action bumps its generation token, so cues still
    ## pending from the previous instance are dropped instead of playing over the
    ## new animation (a cancelled punch must not keep firing its f16/f34/f62
    ## footfalls ~2 s later).
    var schedule_key: String = group if not group.is_empty() else label
    var token: int = int(_sfx_schedule_token.get(schedule_key, 0)) + 1
    _sfx_schedule_token[schedule_key] = token
    var seen: Dictionary = {}
    for value: Variant in cues:
        if not value is Dictionary:
            continue
        var cue: Dictionary = value
        if bool(cue.get("is_voice", false)):
            # Voice cues go through _play_voice_cues so they can be resolved
            # against the voice root and filtered by character.
            continue
        var unique: String = String(cue.get("unique", ""))
        if not unique.is_empty() and unique != character_id:
            continue
        var file: String = String(cue.get("file", ""))
        if file.is_empty():
            continue
        var stream: AudioStream = _sfx_audio.get(file)
        if stream == null:
            continue
        var volume: float = clampf(float(cue.get("volume", 1.0)), 0.001, 1.0)
        var frame_value: Variant = cue.get("frame", null)
        var delay: float = 0.0
        if frame_value != null:
            delay = maxf(float(frame_value), 0.0) / SfxMusicMap.FRAME_RATE
        var dedupe: String = "%s|%s|%.3f|%s" % [
            file, str(frame_value), volume, unique
        ]
        if seen.has(dedupe):
            continue
        seen[dedupe] = true
        var scheduled_ms: int = Time.get_ticks_msec()
        if delay <= 0.0001:
            # No recovered frame data / frame 0: keep the start-of-action fallback.
            _spawn_sfx(
                stream, volume, label, file, frame_value, delay, scheduled_ms,
                false, unique
            )
            continue
        get_tree().create_timer(delay).timeout.connect(
            _spawn_sfx_if_current.bind(
                token, schedule_key, stream, volume, label, file, frame_value,
                delay, scheduled_ms, unique
            )
        )


func _spawn_sfx_if_current(
        token: int, schedule_key: String, stream: AudioStream, volume: float,
        label: String, file: String, frame_value: Variant, delay: float,
        scheduled_ms: int, unique: String
) -> void:
    ## A newer start of the same action supersedes this pending cue.
    if int(_sfx_schedule_token.get(schedule_key, 0)) != token:
        return
    _spawn_sfx(
        stream, volume, label, file, frame_value, delay, scheduled_ms, false, unique
    )


func _spawn_sfx(
        stream: AudioStream, volume: float, label: String, file: String,
        frame_value: Variant = null, delay: float = 0.0, scheduled_ms: int = -1,
        is_voice: bool = false, unique: String = ""
) -> void:
    if not is_instance_valid(combat_audio):
        return
    var player: AudioStreamPlayer = AudioStreamPlayer.new()
    player.stream = stream
    player.volume_db = linear_to_db(volume)
    player.finished.connect(player.queue_free)
    combat_audio.add_child(player)
    player.play()
    _record_cue_play(
        label, file, volume, frame_value, delay, scheduled_ms, is_voice, unique
    )


func _record_cue_play(
        label: String, file: String, volume: float, frame_value: Variant,
        delay: float, scheduled_ms: int, is_voice: bool, unique: String
) -> void:
    ## One append per actual playback.  The timing fields are the evidence that
    ## the cue started at frame/30 s and not at action start.
    _sfx_play_count += 1
    var frame_out: int = -1
    if frame_value != null:
        frame_out = int(frame_value)
    var played_ms: int = Time.get_ticks_msec()
    if scheduled_ms < 0:
        scheduled_ms = played_ms
    _sfx_play_log.append({
        "label": label,
        "file": file,
        "volume": volume,
        "frame": frame_out,
        "delay": delay,
        "scheduled_ms": scheduled_ms,
        "played_ms": played_ms,
        "is_voice": is_voice,
        "unique": unique,
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


func _opponent_set_character() -> String:
    ## Fighting-set `unique` tag of the configured opponent.  Recovered non-voice
    ## rows tag a character-specific take with the set id (brickdavis, kengodall,
    ## themaster, ...), which differs from the opponent-menu id (brick, ken,
    ## master).  Empty means "no known tag", so only generic rows play.
    match _opponent_attack_config():
        PortFighter.ATTACK_CONFIG_PATH:
            return "brucelee"
        PortFighter.KEN_ATTACK_CONFIG_PATH:
            return "kengodall"
        PortFighter.CHIEF_ATTACK_CONFIG_PATH:
            return "chief"
        PortFighter.JOHNSON_ATTACK_CONFIG_PATH:
            return "johnson"
        PortFighter.SMALLBOY_ATTACK_CONFIG_PATH:
            return "smallboy"
        PortFighter.BRICK_ATTACK_CONFIG_PATH:
            return "brickdavis"
        PortFighter.MASTER_ATTACK_CONFIG_PATH:
            return "themaster"
        PortFighter.SINFU_ATTACK_CONFIG_PATH:
            return "sinfu"
        PortFighter.SHENLO_ATTACK_CONFIG_PATH:
            return "shenlo"
        PortFighter.LOMING_ATTACK_CONFIG_PATH:
            return "loming"
        _:
            return ""


func _fighter_set_character(fighter: PortFighter) -> String:
    ## The fighter whose own fighting set owns this cue: the player is Bruce,
    ## anyone else is the configured opponent.
    if fighter == null:
        return ""
    if fighter == player:
        return "brucelee"
    return _opponent_set_character()


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
    # Bumping every group keeps pending frame cues from firing after a stop.
    _sfx_schedule_token.clear()
    _voice_file_cache.clear()
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

func _process(delta: float) -> void:
    _update_game_text_sequence(delta)
    _update_player_key_status()
    _update_fight_camera(delta)
    _update_footsteps(delta)
    _update_continue_prompt(delta)


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


func _camera_map_clip(map: Dictionary, clip: String) -> String:
    if clip.is_empty():
        return ""
    var row: Variant = map.get(clip, {})
    if typeof(row) != TYPE_DICTIONARY:
        return ""
    return String(Dictionary(row).get("camera", ""))


func _intro_camera_load_map() -> void:
    if _intro_camera_map_loaded:
        return
    _intro_camera_map_loaded = true
    _intro_camera_map = {}
    var file: FileAccess = FileAccess.open(_intro_camera_map_path, FileAccess.READ)
    if file == null:
        push_warning("intro camera map missing: " + _intro_camera_map_path)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        var clips: Variant = Dictionary(parsed).get("camera_clips", {})
        if typeof(clips) == TYPE_DICTIONARY:
            _intro_camera_map = clips


func _victory_camera_load_map() -> void:
    if _victory_camera_map_loaded:
        return
    _victory_camera_map_loaded = true
    _victory_camera_map = {}
    var file: FileAccess = FileAccess.open(_victory_camera_map_path, FileAccess.READ)
    if file == null:
        push_warning("victory camera map missing: " + _victory_camera_map_path)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        var clips: Variant = Dictionary(parsed).get("camera_clips", {})
        if typeof(clips) == TYPE_DICTIONARY:
            _victory_camera_map = clips


func _intro_camera_end() -> void:
    var old_camera: String = _intro_camera_camera
    _intro_camera_active = false
    _intro_camera_clip = ""
    _intro_camera_camera = ""
    if not old_camera.is_empty() and _camera_anm_clip == old_camera:
        _camera_anm_end()


func _intro_camera_begin(
        anchor: PortFighter = null, mirror: bool = false,
        clip: String = "", allow_degenerate: bool = false
) -> bool:
    ## Arm the authored camera for an actual intro clip.  The clip comes from the
    ## characters.list intro pool selected by the preserved zmath draw; its
    ## camera sub-animation is looked up in the data-derived intro map.  A
    ## missing map entry or missing JSON is a refusal, never a fallback to a
    ## different intro's camera.  `allow_degenerate` keeps A==B for states 1/2,
    ## where SetState moves both fighters to the origin before CameraUpdate.
    if _camera_anm == null:
        _camera_anm = CameraAnm.new()
    _intro_camera_load_map()
    var dummy: PortFighter = anchor if anchor != null else _intro_camera_local_fighter()
    var wanted_clip: String = clip
    if wanted_clip.is_empty() and dummy != null:
        wanted_clip = dummy.selected_intro_clip()
    var camera_clip: String = _camera_map_clip(_intro_camera_map, wanted_clip)
    if wanted_clip.is_empty() or camera_clip.is_empty():
        _intro_camera_end()
        return false
    if not _camera_anm.load_json(_camera_anm_dir + camera_clip + ".json"):
        _intro_camera_end()
        return false
    var other: PortFighter = computer if dummy == player else player
    var a: Vector3 = _camera_anm_fighter_point(dummy)
    var b: Vector3 = _camera_anm_fighter_point(other)
    if not allow_degenerate and (b - a).length() < 0.001:
        b = a + Vector3(dummy.facing, 0.0, 0.0)
    _camera_anm_clip = camera_clip
    _camera_anm_frame = 0.0
    _camera_anm_anchor = dummy
    _camera_anm_mirror = mirror
    _camera_anm_a = a
    _camera_anm_b = b
    _intro_camera_clip = wanted_clip
    _intro_camera_camera = camera_clip
    _intro_camera_active = true
    return true


func _camera_anm_begin(
        clip: String, winner: PortFighter, player_pre: Vector3, computer_pre: Vector3
) -> bool:
    ## Start the authored result camera for `winner`. `clip` is the camera clip
    ## already resolved from the actual winner clip (characters.list victory
    ## pool + zmath draw). `player_pre`/`computer_pre` are the two fighters'
    ## source points *before* SetState(12/13) moves both to the origin; they give
    ## the dummy yaw (winner -> loser). SetState(12/13) then renders the winner
    ## at the origin, so the anchors are rebased so the selected dummy lands
    ## there. mirror=true selects the computer as the dummy exactly as
    ## CBeatEmUpCamera::StartAnimation swaps A/B for states 12/13.
    _intro_camera_end()
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


func _defeat_camera_load_map() -> void:
    ## Decoded defeat camera pool: characters.list animations.defeat + the
    ## recovered "X_camera.anm belongs to action X" rule (defeat_camera_map.json,
    ## one shared clip m01_defeat_01).  A missing/invalid map leaves it empty so
    ## _enter_countdown_state() refuses instead of inventing a camera.
    if _defeat_camera_map_loaded:
        return
    _defeat_camera_map_loaded = true
    _defeat_camera_map = {}
    var file: FileAccess = FileAccess.open(_defeat_camera_map_path, FileAccess.READ)
    if file == null:
        push_warning("defeat camera map missing: " + _defeat_camera_map_path)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        var clips: Variant = Dictionary(parsed).get("camera_clips", {})
        if typeof(clips) == TYPE_DICTIONARY:
            _defeat_camera_map = clips


func _defeat_camera_clip(clip: String) -> String:
    _defeat_camera_load_map()
    return _camera_map_clip(_defeat_camera_map, clip)


func _countdown_camera_begin(clip: String) -> bool:
    ## Arm the authored defeat camera for state 14.  CBeatEmUpGame::CameraUpdate
    ## (@0x178d88) takes the `else` branch for state 14: the dummy is
    ## this[0x7e0] (the local player, slot 0) and the swap flag is 0.  SetState
    ## (14) has already moved BOTH fighters to the origin, so the dummy
    ## direction is (0,0): C atan2(+0,+0) is +0 and the authored yaw is exactly
    ## PI/2.  Passing both anchors at the origin reproduces that yaw in
    ## CameraAnm.place_world(); mirror is false as native sets it.
    if _camera_anm == null:
        _camera_anm = CameraAnm.new()
    if not _camera_anm.load_json(_camera_anm_dir + clip + ".json"):
        return false
    var origin: Vector3 = _camera_anm_fighter_point(player)
    var other: Vector3 = _camera_anm_fighter_point(computer)
    if (other - origin).length() >= 0.001:
        # The fighters are not both at the origin yet (should not happen: the
        # state body moves them before this call).  Do not silently invent a
        # direction; refuse so the caller keeps the analytic camera.
        return false
    _camera_anm_clip = clip
    _camera_anm_frame = 0.0
    _camera_anm_anchor = player
    _camera_anm_mirror = false
    _camera_anm_a = origin
    _camera_anm_b = origin
    return true


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
    ## Per-frame playback of the actual selected intro camera (30 fps, no
    ## interpolation). Unlike the result camera, this one *finishes*: when the
    ## frame counter passes the last authored frame it ends and returns false so
    ## the analytic follow camera takes over. The clip is the one that belongs to
    ## the fighter's selected characters.list intro, never a hardcoded m01 clip.
    if (not _intro_camera_active or _camera_anm == null
            or _camera_anm_clip.is_empty() or _camera_anm_anchor == null):
        return false
    var last: int = _camera_anm.frame_count() - 1
    if last < 0:
        return false
    _camera_anm_frame += maxf(delta, 0.0) * 30.0
    if _camera_anm_frame > float(last):
        _intro_camera_end()
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
    if match_state == MATCH_STATE_COUNTDOWN:
        # State 14 keeps the authored defeat camera (CameraUpdate reads the
        # movie's camera sub-animation from the playing clip).  Missing JSON was
        # refused when the state was entered, so this normally succeeds.
        if _camera_anm_play_authored(delta):
            return
    if _action_camera_tick():
        # The player's current animation owns an authored camera; it overrides
        # both the intro tail and the analytic follow camera while it runs.
        return
    if _intro_camera_active and match_state in [
            MATCH_STATE_ATTRACT_FIGHTER0, MATCH_STATE_ATTRACT_FIGHTER1,
            MATCH_STATE_INTRO, MATCH_STATE_FIGHT]:
        # The selected characters.list intro's own camera sub-animation.  It
        # deliberately survives INTRO -> FIGHT so a clip longer than the 3 s
        # READY state finishes as natively timed; a missing map/JSON leaves the
        # active flag false and the analytic follow camera below keeps the view.
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
    if (move_training != null and move_training.visible
            and move_training.freezes_world()):
        # The training select / introduction / completion screens own the
        # frame; nothing behind them may run AI or accept movement.
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
    if next_state == MATCH_STATE_FIGHT:
        # The recovered selectfighter/fightpreview art never survives into the
        # fight: entering MATCH_STATE_FIGHT always hides it.
        _hide_hud_art_menu()
    if next_state in [MATCH_STATE_MATCH_WIN, MATCH_STATE_MATCH_LOSE]:
        # Result states own a separate authored camera begun after the state
        # switch; only clear any intro camera that was still active.
        _intro_camera_end()
    else:
        # The authored intro camera is allowed to survive INTRO(3) -> FIGHT(4)
        # so its authored clip finishes as natively timed (CameraUpdate keeps it
        # until StopAnimation/timeout); every other transition ends it.
        var keep_intro: bool = (
            next_state == MATCH_STATE_FIGHT and _intro_camera_active
        )
        if not keep_intro:
            _intro_camera_end()
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
        MATCH_STATE_ATTRACT_FIGHTER0, MATCH_STATE_ATTRACT_FIGHTER1:
            _advance_attract(delta)
        MATCH_STATE_INTRO:
            _advance_round_intro()
        MATCH_STATE_CONTINUE:
            # State 9 waits on the arcaderetryask choice; its countdown length
            # (+0x850) is unrecovered, so nothing here expires it.
            pass
        MATCH_STATE_TIME_UP:
            _advance_time_up()
        MATCH_STATE_KO_WIN, MATCH_STATE_KO_LOSE, MATCH_STATE_DRAW:
            _advance_result_text()
        MATCH_STATE_MATCH_WIN, MATCH_STATE_MATCH_LOSE:
            _advance_winner_result_pose()
        MATCH_STATE_COUNTDOWN:
            _advance_countdown(delta)
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
    # Opt-in progress: count GREAT / PERFECT round wins using the same recovered
    # health rule that selects the game text below (SetState(7): health < 0x14 ->
    # GREAT, health == 100 -> PERFECT).
    if progress != null:
        if winner.health < ROUND_GREAT_HEALTH:
            progress.note_grade("great")
        if is_equal_approx(winner.health, PortFighter.MAX_HEALTH):
            progress.note_grade("perfect")
    # TFightResults +0x10: the player fighter record byte +0x174 counts every
    # round this fighter wins with untouched health (CBeatEmUpGame::SetState 7
    # when the local player scored: `ldrb/add/strb [fighter+0x174]`).  It is the
    # per-match perfect count the story score reads, not a lifetime total.
    if winner == player and is_equal_approx(winner.health, PortFighter.MAX_HEALTH):
        fight_perfects += 1
    if winner.health < ROUND_GREAT_HEALTH:
        _show_game_text("GREAT", wait, GAME_TEXT_SEQ_GREAT)
    else:
        _show_game_text("YOU_WIN", wait, GAME_TEXT_SEQ_YOU_WIN)
    if is_equal_approx(winner.health, PortFighter.MAX_HEALTH):
        _show_game_text("PERFECT", wait, GAME_TEXT_SEQ_PERFECT)


## The recovered TFightResults snapshot for the fight that just ended
## (CBeatEmUpGameModes::RegisterLastFightVariables 0x15ca6c +
## CurrentGameModeFightWon 0x1571fc).  Field names match the native offsets:
##   health_remaining -> +0x00, counters -> +0x04, special_moves -> +0x08,
##   ending_moves -> +0x0c, perfects -> +0x10, match_millis -> +0x14.
func get_fight_results() -> Dictionary:
    var health: float = PortFighter.MAX_HEALTH
    var counters: int = 0
    var special_moves: int = 0
    var ending_moves: int = 0
    if player != null:
        health = player.health
        counters = player.anim_category(FightStats.COUNTER)
        special_moves = player.anim_category(FightStats.SPECIAL)
        ending_moves = player.anim_category(FightStats.ENDMOVE)
    return {
        "health_remaining": int(round(health)),
        "counters": counters,
        "special_moves": special_moves,
        "ending_moves": ending_moves,
        "perfects": fight_perfects,
        "match_millis": maxi(0, Time.get_ticks_msec() - match_started_msec),
    }


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
    # The KO text from state 7/8 has finished by the time SetState(12/13)
    # begins; clear it so only the victory/defeat clip is presented.
    _hide_game_text_overlays()
    var victory_ok: bool = winner.enter_result_pose("victory")
    loser.clear_result_pose()
    # The camera belongs to the clip that is actually played (characters.list
    # victory pool + the preserved zmath draw).  A candidate asset gap may
    # substitute a loaded result clip; the camera follows that actual clip.
    _victory_camera_load_map()
    var result_camera_clip: String = _camera_map_clip(
        _victory_camera_map, winner.result_clip
    )
    if victory_ok and not result_camera_clip.is_empty():
        _camera_anm_begin(result_camera_clip, winner, player_pre, computer_pre)
    else:
        _camera_anm_end()
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


func _story_defeat_state_applies() -> bool:
    ## PlayerLost() @0x190060: for game mode 1 (story) it calls
    ## CBruceLeeStoryMode::StoryCurrentFightWinOnLose() (engine+0x2b8) and, when
    ## that returns 0, enters SetState(14) (0x19022c -> 0x19049c).  The port's
    ## recovered story rules evaluate the same battle `win_on_lose` flag.
    if OS.get_environment("BRUCELEE_STORY_FLOW") != "1":
        return false
    if story_flow == null:
        return false
    if player_rounds >= rounds_to_win or computer_rounds < rounds_to_win:
        return false
    return not bool(story_flow.call("current_battle_win_on_lose"))


func _enter_countdown_state() -> bool:
    ## SetState(14) body (0x1785f8): fighter 0 visible, fighter 1 hidden, both to
    ## the origin, StopCameraAnimation, then fighter 0 plays the "Defeat" free
    ## animation.  Entering requires the candidate defeat clip and its recovered
    ## camera; either missing is a refusal so the normal result flow still runs.
    if native_states == null or not is_instance_valid(player) \
            or not is_instance_valid(computer):
        return false
    if not player.enter_result_pose("defeat") or String(player.result_clip).is_empty():
        player.clear_result_pose()
        print("DEFEAT_STATE_GAP state=14 reason=no-candidate-defeat-clip")
        return false
    var clip: String = String(player.result_clip)
    var camera_clip: String = _defeat_camera_clip(clip)
    if camera_clip.is_empty():
        player.clear_result_pose()
        print("DEFEAT_STATE_GAP state=14 reason=no-defeat-camera clip=%s" % clip)
        return false
    var seconds: float = player.result_clip_duration()
    if seconds <= 0.0:
        player.clear_result_pose()
        print("DEFEAT_STATE_GAP state=14 reason=zero-length-defeat-clip clip=%s" % clip)
        return false
    if not bool(native_states.enter(MATCH_STATE_COUNTDOWN, clip, seconds, camera_clip)):
        player.clear_result_pose()
        print("DEFEAT_STATE_GAP state=14 reason=%s" % native_states.fail_reason)
        return false
    # Native body order: _enter_match_state clears any intro/action camera first,
    # then the countdown camera is started.
    _enter_match_state(MATCH_STATE_COUNTDOWN)
    player.visible = true
    computer.visible = false
    player.global_position = Vector3(0.0, PortFighter.PLAYER_ORIGIN_HEIGHT, 0.0)
    computer.global_position = Vector3(0.0, PortFighter.PLAYER_ORIGIN_HEIGHT, 0.0)
    player.move_axis = Vector2.ZERO
    computer.move_axis = Vector2.ZERO
    _hide_game_text_overlays()
    _countdown_handed_off = false
    done = true
    if not _countdown_camera_begin(camera_clip):
        print("DEFEAT_STATE_GAP state=14 reason=defeat-camera-json-missing clip=%s"
            % camera_clip)
    print("NATIVE_STATE_ENTER state=14 clip=%s seconds=%.3f camera=%s fighter=0 swap=0"
        % [clip, seconds, camera_clip])
    return true


func _advance_countdown(delta: float) -> void:
    ## Update case 14 is the default DummyUpdate branch; the state never leaves.
    ## CountdownEnded() latches at GetStateTime() > 9999 ms, after which
    ## CBeatEmUpMatch::Update raises "COUNTDOWNEND" instead of driving the fight.
    if native_states != null:
        native_states.advance(delta)
    if _countdown_handed_off:
        return
    if native_states == null or not bool(native_states.countdown_ended):
        return
    _countdown_handed_off = true
    match_over = true
    done = true
    print("NATIVE_STATE_COUNTDOWNEND state=14 elapsed_ms=%d action=%s" % [
        int(round(native_states.state_time * 1000.0)), NativeMatchStates.COUNTDOWN_ACTION
    ])
    hud.show_message("YOU LOSE THE MATCH · R TO RESTART")
    if story_flow != null:
        story_flow.match_finished(false)


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
        # SetState(9) is raised from the fight state when the recorded action
        # list matches; the port has no such recording, so the recovered
        # arcaderetryask prompt is offered at the one point the port knows the
        # match is over.  BRUCELEE_CONTINUE unset keeps the plain result screen.
        # Story mode and the arcade flow own their own post-match screens, so
        # the versus continue prompt only applies to a plain match.
        var story_active: bool = OS.get_environment("BRUCELEE_STORY_FLOW") == "1"
        var mode_active: bool = not OS.get_environment("BRUCELEE_GAME_MODE").is_empty()
        if (OS.get_environment("BRUCELEE_CONTINUE") == "1"
                and not player_won and not training_mode and not story_active
                and not mode_active and _enter_continue_state()):
            return
        # Opt-in progress: a standalone 1v1 win (not story / arcade / training)
        # is the port's versus match, so it feeds the versus-win counter.
        if (progress != null and player_won and not training_mode
                and OS.get_environment("BRUCELEE_STORY_FLOW") != "1"
                and OS.get_environment("BRUCELEE_GAME_MODE").is_empty()):
            progress.note_versus_win()
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
    # A chosen guard is a held action in the native tree. Re-walking the tree
    # during the attacker's startup/active frames can randomly replace it with
    # a different branch, so hold the decision until the threat has resolved.
    if (computer.guard_held and player != null
            and player.state in ["startup", "active"]):
        computer.move_axis = Vector2.ZERO
        return
    if computer.guard_held and player != null and player.state == "recovery":
        # The guard decision ends when the attack is no longer a threat; the
        # next tree walk is free to choose movement or a punish.
        computer.end_guard()
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
    # The recovered training screen owns its own input (its CanvasLayer is
    # PROCESS_MODE_ALWAYS so it still receives keys while paused). Everything
    # else is routed through _unhandled_input / the fighter input path.
    if event == null:
        return


func _unhandled_input(event: InputEvent) -> void:
    if match_state == MATCH_STATE_CONTINUE and _handle_continue_input(event):
        get_viewport().set_input_as_handled()
        return
    if records_screen != null and records_screen.is_open():
        # The records screen consumes its own keys in _input(); this guard keeps
        # any straggler press from reaching the menu or a fight behind it.
        records_screen.handle_input_event(event)
        get_viewport().set_input_as_handled()
        return
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

func _handle_continue_input(event: InputEvent) -> bool:
    ## arcaderetryask: UP/DOWN move between the two gui/continueask.ui options,
    ## J confirms the highlighted one.  No countdown key exists because the
    ## countdown length itself is unrecovered.
    if not event is InputEventKey or not event.pressed or event.echo:
        return false
    var key_event: InputEventKey = event
    if key_event.keycode == KEY_UP or key_event.keycode == KEY_W:
        native_states.move_continue_cursor(-1)
        _refresh_continue_prompt()
        return true
    if key_event.keycode == KEY_DOWN or key_event.keycode == KEY_S:
        native_states.move_continue_cursor(1)
        _refresh_continue_prompt()
        return true
    if key_event.keycode == KEY_J or key_event.keycode == KEY_ENTER:
        var option: String = native_states.current_continue_option()
        _resolve_continue(option)
        return true
    return false


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
    if player == null or computer == null:
        return false
    var player_clips: Dictionary = player.get("_candidate_clip_paths")
    var computer_clips: Dictionary = computer.get("_candidate_clip_paths")
    # The player-side clips are the same Bruce set for every opponent.  The
    # opponent clips are character-specific: Brick's recovery needs its
    # facedown idle/impact rows, while the other recovered candidates only need
    # their own non-empty clip table to stand/attack as the training dummy.
    var base_ok: bool = (player.candidate_loaded and computer.candidate_loaded
            and player_clips.has(PortFighter.ATTACK_TO_FLOOR_CLIP)
            and player_clips.has(PortFighter.IDLE2_CLIP))
    if not base_ok:
        return false
    if training_current_opponent_key() == "brick":
        return (computer_clips.has(PortFighter.BRICK_FACEDOWN_IDLE_CLIP)
                and computer_clips.has(PortFighter.FACEDOWN_IMPACT_CLIP))
    return not computer_clips.is_empty()

func _on_hit(attacker: PortFighter, defender: PortFighter, action: String, damage: float, blocked: bool) -> void:
    if done or training_completed:
        return
    # Opt-in progress: count the player's grab / final-attack feats from landed
    # hits only (combat_hit is emitted on contact). No-op when the flag is off.
    if (progress != null and attacker == player and not training_mode
            and not (move_training != null and move_training.is_active())
            and not (move_gallery != null and move_gallery.is_active())):
        progress.note_combat_hit(action, String(defender.state), true, attacker.attack_sequence)
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
    # SetState(14): a story-mode fight lost when the battle cannot be won by
    # losing shows the defeat presentation instead of the KO result chain
    # (PlayerLost -> mode 1 -> StoryCurrentFightWinOnLose()==false -> state 14).
    if fighter == player and _story_defeat_state_applies():
        if _enter_countdown_state():
            return
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


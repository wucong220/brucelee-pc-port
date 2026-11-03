extends Node3D
## Gameplay demonstrator: intentionally original, with placeholder meshes.
## Original character models/animations and exact rules remain unported.

const CandidateBounds = preload("res://scripts/candidate_bounds.gd")
const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")
const PrototypeMenu = preload("res://scripts/prototype_menu.gd")
const PrototypeControls = preload("res://scripts/prototype_controls.gd")
const MoveTraining = preload("res://scripts/move_training.gd")
const MoveGallery = preload("res://scripts/move_gallery.gd")
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
            "D:\\BruceLeeWork\\character-extras-20261103\\candidates\\"
            + "sinfu_hair_two-skin_79_all_20261103.glb"
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
            "D:\\BruceLeeWork\\character-extras-20261103\\candidates\\"
            + "master_full_hair_76_all_20261103.glb"
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
            "D:\\BruceLeeWork\\ken-all26-20261103\\candidate\\"
            + "ken_all26_4306ch.glb"
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
        "glb": "D:\\BruceLeeWork\\chief-loming-fix-20261103\\candidates\\chief01_full_body_hair_84_bindfix_20261103.glb",
        "texture_root": "D:\\BruceLeeWork\\remaining-characters-20261103\\textures\\chief01",
        "clip_prefix": "",
        "master": "",
        "material_profile": "body_hair",
        "attack_config": "res://data/attack_config_chief.json",
        "skeleton": "large",
    },
    "loming": {
        "glb": "D:\\BruceLeeWork\\chief-loming-fix-20261103\\candidates\\loming01_full_body_hair_82_bindfix_20261103.glb",
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
const ROUND_RESET_DELAY: float = 2.0
# Original round clock: CBeatEmUpGame::SetTimerMax() stores the limit in
# seconds and Update() displays max(0, limit - played_ms / 1000).
const ROUND_TIME_DEFAULT: int = 60

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
var _music_player: AudioStreamPlayer = null
var _music_stream: AudioStream = null
var _music_streams: Dictionary = {}
var _result_audio: Dictionary = {}
var _result_player: AudioStreamPlayer = null
var _game_text_textures: Dictionary = {}
var _game_text_rect: Sprite2D = null
var _game_text_timer: float = 0.0
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
    _build_game_text_overlay()
    if not OS.get_environment("BRUCELEE_HOLD_GAME_TEXT").is_empty():
        _show_game_text(OS.get_environment("BRUCELEE_HOLD_GAME_TEXT"), 30.0)
    if not OS.get_environment("BRUCELEE_HOLD_GAME_TEXT").is_empty():
        _show_game_text(OS.get_environment("BRUCELEE_HOLD_GAME_TEXT"), 30.0)

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
    main_menu_enabled = false if export_self_test else _should_show_main_menu()
    _configure_round_time()
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
    elif not main_menu_enabled:
        call_deferred("_start_direct_intro")


func _start_direct_intro() -> void:
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
    var layer: CanvasLayer = CanvasLayer.new()
    layer.layer = 15
    add_child(layer)
    _game_text_rect = Sprite2D.new()
    _game_text_rect.position = (
        get_viewport().get_visible_rect().size * Vector2(0.5, 0.42)
    )
    _game_text_rect.scale = Vector2(1.6, 1.6)
    _game_text_rect.modulate = Color(1.0, 0.86, 0.35, 1.0)
    _game_text_rect.flip_h = false
    _game_text_rect.visible = false
    layer.add_child(_game_text_rect)
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
    for key: String in ["READY", "FIGHT", "YOU_WIN", "YOU_LOSE", "TIME_IS_UP"]:
        var filename: String = "BL_gameText-%s.png" % key
        for root: String in roots:
            var path: String = root.path_join(filename)
            if not FileAccess.file_exists(path):
                continue
            var image: Image = Image.new()
            if image.load(path) == OK:
                _game_text_textures[key] = ImageTexture.create_from_image(image)
                break


func _show_game_text(key: String, duration: float) -> void:
    if _game_text_rect == null or not _game_text_textures.has(key):
        return
    _game_text_rect.position = (
        get_viewport().get_visible_rect().size * Vector2(0.5, 0.42)
    )
    _game_text_rect.texture = _game_text_textures[key]
    _game_text_rect.flip_h = false
    _game_text_rect.visible = true
    _game_text_timer = duration


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
    add_child(computer)
    player.opponent = computer
    computer.opponent = player
    player.combat_ko.connect(_on_ko)
    computer.combat_ko.connect(_on_ko)
    player.combat_hit.connect(_on_hit)
    computer.combat_hit.connect(_on_hit)
    player.attack_started.connect(_on_player_attack_started)

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
    _reset_round()


func _reset_round() -> void:
    var demo_close: bool = OS.get_environment("BRUCELEE_DEMO_CLOSE") == "1"
    var player_x: float = -0.25 if training_mode else (-0.75 if demo_close else -2.0)
    var computer_x: float = 0.25 if training_mode else (0.75 if demo_close else 2.0)
    player.reset_fighter(Vector3(player_x, 1.20, 0.0))
    computer.reset_fighter(Vector3(computer_x, 1.20, 0.0))
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
    hud.set_round(round_number, player_rounds, computer_rounds, training_mode)
    # CFighter::Restart puts the clock back to the round limit every round;
    # training has no match clock.
    round_time_active = (not training_mode) and round_time_max > 0
    round_time_left = round_time_max if round_time_active else 0
    hud.set_time(round_time_left, round_time_active)
    hud.show_message(
        "TRAINING 路 K L L / K U U" if training_mode
        else "ROUND %d 路 FIGHT" % round_number
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
    _load_menu_music()


func _load_menu_music() -> void:
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
    _music_streams.clear()
    for root: String in roots:
        for key: String in ["menu", "fight"]:
            var filename: String = (
                "Main_Theme_BL.wav" if key == "menu" else "Tournament_Day_BL.wav"
            )
            var path: String = root.path_join(filename)
            if not FileAccess.file_exists(path):
                continue
            var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
            if stream == null:
                continue
            stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
            stream.loop_end = int(stream.get_length() * float(stream.mix_rate))
            _music_streams[key] = stream
    if _music_streams.is_empty():
        return
    _music_player = AudioStreamPlayer.new()
    _music_player.volume_db = -12.0
    _music_player.finished.connect(_music_player.play)
    combat_audio.add_child(_music_player)
    _play_music("menu")


func _play_music(key: String) -> void:
    if _music_player == null or not _music_streams.has(key):
        return
    var stream: AudioStream = _music_streams[key]
    if _music_player.stream == stream and _music_player.playing:
        return
    _music_stream = stream
    _music_player.stream = stream
    _music_player.play()


func _load_result_audio() -> void:
    var roots: Array[String] = []
    var env_root: String = OS.get_environment("BRUCELEE_COMMENTATOR_ROOT")
    if not env_root.is_empty():
        roots.append(env_root)
    roots.append(OS.get_executable_path().get_base_dir().path_join("audio/commentator"))
    for root: String in roots:
        for key: String in ["win", "lose", "draw", "fight", "ready"]:
            var filename: String = {
                "win": "You_Win.wav", "lose": "You_Lose.wav", "draw": "Draw.wav",
                "fight": "Fight.wav", "ready": "Ready_Alt_1.wav",
            }[key]
            var path: String = root.path_join(filename)
            if not FileAccess.file_exists(path):
                continue
            var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
            if stream != null:
                _result_audio[key] = stream
    if _result_audio.is_empty():
        return
    _result_player = AudioStreamPlayer.new()
    _result_player.volume_db = 2.0
    combat_audio.add_child(_result_player)


func _play_result_audio(key: String) -> void:
    if _result_audio.is_empty():
        _load_result_audio()
    if _result_player == null:
        return
    var stream: AudioStream = _result_audio.get(key)
    if stream == null:
        return
    _result_player.stream = stream
    _result_player.play()


func _start_round_intro() -> void:
    _show_game_text("READY", 0.8)
    _play_result_audio("ready")
    await get_tree().create_timer(0.8).timeout
    if not done:
        _show_game_text("FIGHT", 1.2)
        _play_result_audio("fight")


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
    var voices: Dictionary = {
        "punch": "attack_light/Hit_Light_1_BL.wav",
        "kick": "attack_light/Hit_Light_2_BL.wav",
        "high_punch": "attack_light/Hit_Light_3_BL.wav",
        "high_kick": "attack_light/Hit_Light_4_BL.wav",
        "high_punch2": "attack_light/Hit_Light_5_BL.wav",
        "low_punch2": "attack_light/Hit_Light_6_BL.wav",
        "high_kick2": "attack_light/Hit_Light_8_BL.wav",
        "low_kick2": "attack_light/Hit_Light_9_BL.wav",
        "high_punch3": "attack_light/Hit_Light_3_BL.wav",
        "low_punch3": "attack_light/Hit_Light_6_BL.wav",
        "low_kick3": "attack_light/Hit_Light_9_BL.wav",
        "high_kick3": "attack_light/Hit_Light_4_BL.wav",
        "parry_high": "attack_light/Hit_Light_5_BL.wav",
        "parry_attack": "attack_light/Hit_Light_1_BL.wav",
        "facedownattack": "attack_light/Hit_Light_8_BL.wav",
        "faceupattack": "attack_light/Hit_Light_9_BL.wav",
        "attacktofloor": "attack_light/Hit_Light_9_BL.wav",
        "special_kick_high": "special/m01_sp_kick_high.wav",
        "special_kick_low_miss": "attack_light/Hit_Light_9_BL.wav",
        "special_kick_low_hit": "attack_light/Hit_Light_9_BL.wav",
        "special_punch_low_miss": "special/m01_sp_pnch_low.wav",
        "special_punch_low_hit": "special/m01_sp_pnch_low.wav",
        "special_punch_high_miss": "special/M01_SP_Pnch_High.avi_OPTION_2.wav",
        "special_punch_high_hit": "special/M01_SP_Pnch_High.avi_OPTION_2.wav",
        "grab1": "special/m01_grab_01.wav",
        "grab1_miss": "special/m01_grab_01.wav",
        "grab2": "special/M01_Grab_02_Back_Breaker.wav",
        "grab2_miss": "special/M01_Grab_02_Back_Breaker.wav",
        "endattack1": "special/M01_End_Attack_01.avi _BL_Slow_Scream_A.wav",
        "endattack2": "special/M01_End_Attack_02.avi _BL_Slow_Scream_B.wav",
    }
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
    var voices: Dictionary = {
        "punch": "attack_light/Hit_Light_1_BL.wav",
        "kick": "attack_light/Hit_Light_2_BL.wav",
        "high_punch": "attack_light/Hit_Light_3_BL.wav",
        "high_kick": "attack_light/Hit_Light_4_BL.wav",
        "high_punch2": "attack_light/Hit_Light_5_BL.wav",
        "low_punch2": "attack_light/Hit_Light_6_BL.wav",
        "high_kick2": "attack_light/Hit_Light_8_BL.wav",
        "low_kick2": "attack_light/Hit_Light_9_BL.wav",
        "high_punch3": "attack_light/Hit_Light_3_BL.wav",
        "low_punch3": "attack_light/Hit_Light_6_BL.wav",
        "low_kick3": "attack_light/Hit_Light_9_BL.wav",
        "high_kick3": "attack_light/Hit_Light_4_BL.wav",
        "parry_high": "attack_light/Hit_Light_5_BL.wav",
        "parry_attack": "attack_light/Hit_Light_1_BL.wav",
        "facedownattack": "attack_light/Hit_Light_8_BL.wav",
        "faceupattack": "attack_light/Hit_Light_9_BL.wav",
        "attacktofloor": "attack_light/Hit_Light_9_BL.wav",
        "special_kick_high": "special/m01_sp_kick_high.wav",
        "special_kick_low_miss": "attack_light/Hit_Light_9_BL.wav",
        "special_kick_low_hit": "attack_light/Hit_Light_9_BL.wav",
        "special_punch_low_miss": "special/m01_sp_pnch_low.wav",
        "special_punch_low_hit": "special/m01_sp_pnch_low.wav",
        "special_punch_high_miss": "special/M01_SP_Pnch_High.avi_OPTION_2.wav",
        "special_punch_high_hit": "special/M01_SP_Pnch_High.avi_OPTION_2.wav",
        "grab1": "special/m01_grab_01.wav",
        "grab1_miss": "special/m01_grab_01.wav",
        "grab2": "special/M01_Grab_02_Back_Breaker.wav",
        "grab2_miss": "special/M01_Grab_02_Back_Breaker.wav",
        "endattack1": "special/M01_End_Attack_01.avi _BL_Slow_Scream_A.wav",
        "endattack2": "special/M01_End_Attack_02.avi _BL_Slow_Scream_B.wav",
    }
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
    var stream: AudioStream = _voice_audio.get(action)
    if stream == null:
        stream = _load_voice_for_action(action)
    if stream == null:
        stream = _voice_audio.get("punch")
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


func _play_hit_audio(action: String, blocked: bool) -> void:
    var event: String = ""
    if blocked:
        event = "block"
    elif action in [
            "punch", "high_punch", "high_punch2", "high_punch3",
            "low_punch2", "low_punch3", "special_punch_low_hit",
            "special_punch_high_hit", "parry_attack",
        ]:
        # Only generic punch/kick body-light samples are available in the
        # candidate audio set; use them as prototype hit sounds.
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
    if _game_text_timer > 0.0:
        _game_text_timer -= _delta
        if _game_text_timer <= 0.0 and _game_text_rect != null:
            _game_text_rect.visible = false
    _update_player_key_status()
    _update_fight_camera(_delta)


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


func _update_fight_camera(delta: float = 1.0 / CAM_UPDATE_HZ) -> void:
    if (not is_instance_valid(fight_camera) or not is_instance_valid(player)
            or not is_instance_valid(computer)):
        return
    if not _cam_initialized:
        _restart_fight_camera()
    var a: Vector3 = _camera_fighter_point(player)
    var b: Vector3 = _camera_fighter_point(computer)
    var alpha: float = 1.0 - pow(CAM_SMOOTH_OLD, maxf(delta, 0.0) * CAM_UPDATE_HZ)
    _cam_smooth_a = _cam_smooth_a.lerp(a, alpha)
    _cam_smooth_b = _cam_smooth_b.lerp(b, alpha)
    var pose: Dictionary = _native_camera_pose(
        _cam_smooth_a, _cam_smooth_b, _camera_aspect_scale()
    )
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
    if round_reset_timer > 0.0:
        player.move_axis = Vector2.ZERO
        computer.move_axis = Vector2.ZERO
        round_reset_timer -= delta
        if round_reset_timer <= 0.0 and not match_over:
            _start_next_round()
        return
    if notice_timer > 0.0:
        notice_timer -= delta
        if notice_timer <= 0.0 and not done:
            hud.show_message("")
    if done or training_completed:
        player.move_axis = Vector2.ZERO
        computer.move_axis = Vector2.ZERO
        return
    elapsed += delta
    _update_round_timer()
    if done:
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


func _on_time_up() -> void:
    # Update() state 4 zeroes the clock and leaves state 4; SetState(5)
    # launches game text animation 4 (BL_gameText-TIME_IS_UP) and 3000 ms
    # later the round is decided by remaining health (CFighter+0x144):
    # higher health wins, equal health is the draw path.
    if done or training_completed or not round_time_active:
        return
    done = true
    hud.set_time(0, true)
    _show_game_text("TIME_IS_UP", 2.0)
    if training_mode:
        hud.show_message("TIME UP  路  R TO RESET")
        return
    var player_health: float = player.health
    var computer_health: float = computer.health
    if is_equal_approx(player_health, computer_health):
        hud.show_message("TIME UP  路  DRAW  路  ROUND %d" % round_number)
    elif player_health > computer_health:
        player_rounds += 1
        hud.show_message("TIME UP  路  YOU WIN  路  ROUND %d" % round_number)
    else:
        computer_rounds += 1
        hud.show_message("TIME UP  路  YOU LOSE  路  ROUND %d" % round_number)
    hud.set_round(round_number, player_rounds, computer_rounds, training_mode)
    if player_rounds >= ROUNDS_TO_WIN or computer_rounds >= ROUNDS_TO_WIN:
        match_over = true
        round_reset_timer = -1.0
        hud.show_message(
            "YOU WIN THE MATCH  路  R TO RESTART" if player_rounds >= ROUNDS_TO_WIN
            else "YOU LOSE THE MATCH  路  R TO RESTART"
        )
        _play_result_audio("win" if player_rounds >= ROUNDS_TO_WIN else "lose")
        return
    round_reset_timer = ROUND_RESET_DELAY


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
    native_ai.configure(computer, player, "brick davis", rng.seed)


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
    # Step-prerequisite specials/grab: accept the final attack press directly
    # while the corresponding step action is held, so a transient miss/link
    # window cannot swallow the move.
    if fighter.is_player and fighter.state == "idle":
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
    _play_hit_audio(action, blocked)
    if ((move_training != null and move_training.is_active())
            or (move_gallery != null and move_gallery.is_active())):
        return
    if (training_mode and attacker == player and defender == computer
            and action == "attacktofloor" and damage > 0.0 and not blocked
            and defender.state == "impactfacedown"):
        training_completed = true
        hud.show_message("TRAINING HIT 路 R RETRY 路 F2 EXIT")
        notice_timer = 0.0
        return
    if blocked:
        hud.show_message("BLOCK!")
    elif attacker == player:
        hud.show_message("HIT 路 " + action.to_upper())
    else:
        hud.show_message("TAKE HIT")
    notice_timer = 0.30

func _on_ko(fighter: PortFighter) -> void:
    if training_completed or done:
        return
    done = true
    if training_mode:
        hud.show_message("TRAINING KO  路  R TO RESET")
        return
    if fighter == computer:
        player_rounds += 1
    else:
        computer_rounds += 1
    hud.set_round(round_number, player_rounds, computer_rounds)
    if player_rounds >= ROUNDS_TO_WIN or computer_rounds >= ROUNDS_TO_WIN:
        match_over = true
        round_reset_timer = -1.0
        _show_game_text(
            "YOU_WIN" if player_rounds >= ROUNDS_TO_WIN else "YOU_LOSE", 2.5
        )
        hud.show_message(
            "YOU WIN THE MATCH  路  R TO RESTART" if player_rounds >= ROUNDS_TO_WIN
            else "YOU LOSE THE MATCH  路  R TO RESTART"
        )
        _play_result_audio("win" if player_rounds >= ROUNDS_TO_WIN else "lose")
        return
    round_reset_timer = ROUND_RESET_DELAY
    _show_game_text("YOU_WIN" if fighter == computer else "YOU_LOSE", 2.0)
    hud.show_message(
        "YOU WIN 路 ROUND %d" % round_number if fighter == computer
        else "YOU LOSE 路 ROUND %d" % round_number
    )


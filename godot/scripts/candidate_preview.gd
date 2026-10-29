extends Node3D
## Local candidate animation preview; the original game's behavior is unverified.

const SOURCE_MIN_Y: float = -0.09393310546875
const SOURCE_HEIGHT: float = 173.415954589844
const PREVIEW_HEIGHT: float = 1.8
const CLIP_NAMES: Dictionary = {
    "idle": "m01_idle_01",
    "punch": "m01_pnch_low_01",
    "kick": "m01_kick_low_01",
}
const CLIP_LABELS: Dictionary = {
    "idle": "待机",
    "punch": "出拳",
    "kick": "踢腿",
}
const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")
const CandidateMaterialLoader = preload("res://scripts/candidate_material_loader.gd")

var status_label: Label
var model_container: Node3D
var animation_player: AnimationPlayer
var clip_paths: Dictionary = {}
var current_action: String = ""
var load_error: String = ""
var candidate_textures_loaded: bool = false
var candidate_texture_error: String = ""


func _ready() -> void:
    _build_environment()
    _build_hud()
    var path_result: Dictionary = _candidate_path()
    if not path_result["error"].is_empty():
        _show_error(path_result["error"])
        return
    _load_candidate(path_result["path"])


func _candidate_path() -> Dictionary:
    var chosen: String = OS.get_environment("BRUCELEE_CANDIDATE_GLB")
    var args: PackedStringArray = OS.get_cmdline_user_args()
    var index: int = 0
    var specified: bool = false
    while index < args.size():
        var value: String = args[index]
        if value == "--candidate-glb" or value.begins_with("--candidate-glb="):
            if specified:
                return {"error": "启动参数 --candidate-glb 只能指定一次。"}
            specified = true
            if value == "--candidate-glb":
                if index + 1 >= args.size() or args[index + 1].begins_with("--"):
                    return {"error": "启动参数 --candidate-glb 缺少文件路径。"}
                index += 1
                chosen = args[index]
            else:
                chosen = value.trim_prefix("--candidate-glb=")
        index += 1
    if chosen.is_empty():
        return {
            "error": "请用 --candidate-glb 指定本地 GLB，或设置 BRUCELEE_CANDIDATE_GLB。"
        }
    var path_error: String = CandidatePathGuard.external_path_error(
        chosen, "candidate path"
    )
    if not path_error.is_empty():
        return {"error": path_error}
    var normalized: String = CandidatePathGuard.normalize_absolute_path(chosen)
    if chosen.get_extension().to_lower() != "glb":
        return {"error": "请指定本地 .glb 文件的绝对路径。"}
    if not FileAccess.file_exists(normalized):
        return {"error": "找不到指定的 GLB 文件：" + normalized}
    return {"path": normalized, "error": ""}


func _load_candidate(path: String) -> void:
    var document: GLTFDocument = GLTFDocument.new()
    var state: GLTFState = GLTFState.new()
    var result: Error = document.append_from_file(path, state)
    if result != OK:
        _show_error("GLB 读取失败（错误码 %d）：" % result + path)
        return
    var model: Node = document.generate_scene(state)
    if model == null or not model is Node3D:
        if model != null:
            model.free()
        _show_error("GLB 未生成可预览的 3D 场景。")
        return
    model_container.add_child(model)
    animation_player = _find_animation_player(model)
    if animation_player == null:
        _show_error("GLB 中没有找到动画播放器。")
        return
    var missing: Array[String] = []
    for action: String in CLIP_NAMES:
        var matched: String = _find_clip(animation_player, CLIP_NAMES[action])
        if matched.is_empty():
            missing.append(CLIP_LABELS[action])
        else:
            clip_paths[action] = matched
    if not missing.is_empty():
        _show_error("GLB 缺少候选动作：" + "、".join(missing))
        return
    var material_result: Dictionary = CandidateMaterialLoader.new().apply_to(
        model, OS.get_environment("BRUCELEE_CANDIDATE_TEXTURE_ROOT")
    )
    candidate_textures_loaded = material_result["loaded"]
    candidate_texture_error = material_result["error"]
    if not candidate_texture_error.is_empty():
        push_warning("候选纹理已禁用：" + candidate_texture_error)
    var idle: Animation = animation_player.get_animation(clip_paths["idle"])
    idle.loop_mode = Animation.LOOP_LINEAR
    animation_player.animation_finished.connect(_on_animation_finished)
    _play_action("idle")


func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child: Node in node.get_children():
        var found: AnimationPlayer = _find_animation_player(child)
        if found != null:
            return found
    return null


func _find_clip(player: AnimationPlayer, expected: String) -> String:
    for clip: StringName in player.get_animation_list():
        var name: String = String(clip)
        if name == expected or name.ends_with("/" + expected):
            return name
    return ""


func _play_action(action: String) -> void:
    if animation_player == null or not clip_paths.has(action):
        return
    current_action = action
    animation_player.play(clip_paths[action])
    status_label.text = "当前动作：" + CLIP_LABELS[action] + "  ·  候选效果，尚未与原版对照"


func _on_animation_finished(_clip: StringName) -> void:
    if current_action != "idle":
        _play_action("idle")


func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    var key: InputEventKey = event as InputEventKey
    if not key.pressed or key.echo:
        return
    match key.keycode:
        KEY_1, KEY_KP_1:
            _play_action("idle")
        KEY_2, KEY_KP_2:
            _play_action("punch")
        KEY_3, KEY_KP_3:
            _play_action("kick")
        KEY_ESCAPE:
            get_tree().quit()


func _show_error(message: String) -> void:
    load_error = message
    status_label.text = message
    status_label.modulate = Color(1.0, 0.55, 0.52)
    printerr("候选动作预览：", message)


func _build_environment() -> void:
    var world: WorldEnvironment = WorldEnvironment.new()
    world.environment = Environment.new()
    world.environment.background_mode = Environment.BG_COLOR
    world.environment.background_color = Color(0.055, 0.07, 0.10)
    world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    world.environment.ambient_light_color = Color(0.8, 0.84, 0.92)
    world.environment.ambient_light_energy = 0.8
    add_child(world)
    var light: DirectionalLight3D = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
    light.light_energy = 1.7
    add_child(light)
    var camera: Camera3D = Camera3D.new()
    camera.position = Vector3(2.4, 1.6, 3.6)
    camera.fov = 40.0
    camera.current = true
    add_child(camera)
    camera.look_at(Vector3(0.0, PREVIEW_HEIGHT * 0.5, 0.0), Vector3.UP)
    var floor: MeshInstance3D = MeshInstance3D.new()
    var floor_mesh: PlaneMesh = PlaneMesh.new()
    floor_mesh.size = Vector2(8.0, 8.0)
    floor.mesh = floor_mesh
    floor.position.y = -0.02
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(0.18, 0.21, 0.25)
    material.roughness = 0.9
    floor.material_override = material
    add_child(floor)
    model_container = Node3D.new()
    model_container.name = "CandidateModelScale"
    var factor: float = PREVIEW_HEIGHT / SOURCE_HEIGHT
    model_container.scale = Vector3.ONE * factor
    model_container.position.y = -SOURCE_MIN_Y * factor
    add_child(model_container)


func _build_hud() -> void:
    var layer: CanvasLayer = CanvasLayer.new()
    add_child(layer)
    var panel: PanelContainer = PanelContainer.new()
    panel.position = Vector2(20.0, 20.0)
    panel.custom_minimum_size = Vector2(660.0, 90.0)
    layer.add_child(panel)
    var margin: MarginContainer = MarginContainer.new()
    for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
        margin.add_theme_constant_override(side, 12)
    panel.add_child(margin)
    var column: VBoxContainer = VBoxContainer.new()
    margin.add_child(column)
    var title: Label = Label.new()
    title.text = "候选角色动作预览  ·  1 待机  2 出拳  3 踢腿  Esc 退出"
    column.add_child(title)
    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(status_label)

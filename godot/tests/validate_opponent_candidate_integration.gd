extends SceneTree
## Validate one opponent candidate GLB through the real main.tscn fighter path.
## Usage:
##   godot --headless --path godot --script res://tests/validate_opponent_candidate_integration.gd -- \
##       <opponent.glb> <texture_root> <prefix|MASTER|NONE>

const CandidateBounds = preload("res://scripts/candidate_bounds.gd")


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("OPPONENT_CANDIDATE_FAIL: " + message)
    quit(1)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 3:
        _fail("expected <glb> <texture_root> <prefix|MASTER|NONE>")
        return
    var glb: String = args[0]
    var texture_root: String = args[1]
    var mode: String = args[2]
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", "")
    OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", "")
    OS.set_environment("BRUCELEE_OPPONENT_GLB", glb)
    OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", texture_root)
    var expected_idle: String = ""
    if mode == "MASTER":
        OS.set_environment("BRUCELEE_OPPONENT_MASTER", "1")
        OS.set_environment("BRUCELEE_OPPONENT_CLIP_PREFIX", "")
        expected_idle = "m04_e01_idle_01"
    elif mode == "NONE":
        OS.set_environment("BRUCELEE_OPPONENT_MASTER", "")
        OS.set_environment("BRUCELEE_OPPONENT_CLIP_PREFIX", "")
        expected_idle = "m03_idle_01"
    else:
        OS.set_environment("BRUCELEE_OPPONENT_MASTER", "")
        OS.set_environment("BRUCELEE_OPPONENT_CLIP_PREFIX", mode)
        expected_idle = mode + "_idle_01"

    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_physics_process(false)
    var opponent: PortFighter = scene.get("computer")
    opponent.set_physics_process(false)
    if not opponent.candidate_loaded:
        _fail("candidate_loaded=false error=" + opponent.candidate_load_error)
        return
    if absf(opponent.candidate_visual_height - 1.8) > 0.01:
        _fail("candidate_visual_height=%.4f" % opponent.candidate_visual_height)
        return
    if opponent.candidate_animation_clip != expected_idle:
        var clip_paths: Dictionary = opponent.get("_candidate_clip_paths")
        if String(clip_paths.get("idle", "")) != expected_idle:
            _fail("idle=%s expected=%s" % [
                String(clip_paths.get("idle", "")), expected_idle,
            ])
            return
        opponent.move_axis = Vector2.ZERO
        opponent.reset_fighter(Vector3(2.0, 1.20, 0.0))
        opponent._animate_candidate()
        if opponent.candidate_animation_clip != expected_idle:
            _fail("idle after reset=%s expected=%s" % [
                opponent.candidate_animation_clip, expected_idle,
            ])
            return
    var candidate_root: Node3D = opponent.get("_candidate_root")
    if candidate_root == null:
        _fail("candidate_root is null")
        return
    var measured: Dictionary = CandidateBounds.scene_bounds(candidate_root)
    if not String(measured.get("error", "")).is_empty():
        _fail("scene_bounds: " + String(measured["error"]))
        return
    var bounds: AABB = measured["bounds"]
    if absf(bounds.position.y) > 0.05:
        _fail("candidate floor=%.4f" % bounds.position.y)
        return
    if bounds.size.y < 1.5 or bounds.size.y > 2.1:
        _fail("candidate world height=%.4f" % bounds.size.y)
        return
    var visible_meshes: int = 0
    for node: Node in candidate_root.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance: MeshInstance3D = node as MeshInstance3D
        if mesh_instance.mesh != null and mesh_instance.is_visible_in_tree():
            visible_meshes += 1
    if visible_meshes == 0:
        _fail("candidate has no visible mesh")
        return
    print("OPPONENT_CANDIDATE_OK=" + JSON.stringify({
        "glb": glb,
        "mode": mode,
        "idle": opponent.candidate_animation_clip,
        "visual_height": opponent.candidate_visual_height,
        "world_height": bounds.size.y,
        "floor": bounds.position.y,
        "visible_meshes": visible_meshes,
        "textures_loaded": opponent.candidate_textures_loaded,
        "texture_error": opponent.candidate_texture_error,
    }))
    quit(0)

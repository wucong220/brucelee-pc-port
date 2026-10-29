extends SceneTree
## Verify repository-external candidate textures on both skinned body and hair.


func _initialize() -> void:
    call_deferred("_run_check")


func _run_check() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected exactly one local candidate GLB path")
        quit(1)
        return
    var texture_root: String = OS.get_temp_dir().path_join(
        "brucelee-candidate-texture-test-%d" % Time.get_ticks_usec()
    )
    if DirAccess.make_dir_recursive_absolute(texture_root) != OK:
        push_error("Could not create temporary candidate texture directory")
        quit(2)
        return
    var texture_paths: Array[String] = []
    for kind: String in ["body", "hair"]:
        var diffuse: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
        diffuse.fill(Color(0.9, 0.2, 0.1) if kind == "body" else Color(0.1, 0.8, 0.3))
        var normal: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
        normal.fill(Color(0.5, 0.5, 1.0))
        var material: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
        material.fill(Color(0.8, 0.3, 0.2, 0.6))
        for entry: Array in [
            ["diffuse", diffuse],
            ["normal", normal],
            ["material", material],
        ]:
            var path: String = texture_root.path_join("%s_%s.png" % [kind, entry[0]])
            if entry[1].save_png(path) != OK:
                push_error("Could not write synthetic candidate texture")
                quit(3)
                return
            texture_paths.append(path)

    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", texture_root)
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await physics_frame
    await physics_frame
    var player: PortFighter = scene.get("player")
    if player == null or not player.candidate_loaded:
        push_error("Candidate model did not load for texture validation")
        quit(4)
        return
    if not player.candidate_textures_loaded:
        push_error("Candidate textures did not load: " + player.candidate_texture_error)
        quit(5)
        return
    var candidate_root: Node3D = player.get("_candidate_root")
    var body_material: ShaderMaterial
    var hair_material: ShaderMaterial
    for node: Node in candidate_root.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance: MeshInstance3D = node as MeshInstance3D
        var mesh_name: String = String(mesh_instance.name).to_lower()
        if mesh_name.contains("body"):
            body_material = mesh_instance.material_override as ShaderMaterial
        elif mesh_name.contains("hair"):
            hair_material = mesh_instance.material_override as ShaderMaterial
    if body_material == null or hair_material == null:
        push_error("Body or hair did not receive the candidate material")
        quit(6)
        return
    if body_material.shader.resource_path.get_file() != (
            "character_candidate_opaque.gdshader"):
        push_error("Body did not receive the opaque candidate shader")
        quit(7)
        return
    if hair_material.shader.resource_path.get_file() != "character_candidate.gdshader":
        push_error("Hair did not receive the blend candidate shader")
        quit(7)
        return
    for material: ShaderMaterial in [body_material, hair_material]:
        for parameter: String in [
            "diffuse_texture", "normal_texture", "material_texture",
        ]:
            if material.get_shader_parameter(parameter) == null:
                push_error("Candidate material is missing shader parameter: " + parameter)
                quit(7)
                return
    print("CANDIDATE_TEXTURE_VALIDATION=" + JSON.stringify({
        "body_loaded": true,
        "hair_loaded": true,
        "body_shader": body_material.shader.resource_path.get_file(),
        "hair_shader": hair_material.shader.resource_path.get_file(),
    }))
    scene.queue_free()
    await process_frame
    for path: String in texture_paths:
        DirAccess.remove_absolute(path)
    DirAccess.remove_absolute(texture_root)
    quit(0)

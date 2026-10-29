extends SceneTree
## Verify synthetic texture parameters on both skinned body and hair.
## Real texture decoding is exercised by validate_combat_candidate.gd; final
## pixel/lighting parity with the original renderer is not verified here.

const CandidateMaterialLoader = preload("res://scripts/candidate_material_loader.gd")


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
    var atomic_failure_error: String = _check_atomic_failure(args[0], texture_root)
    if not atomic_failure_error.is_empty():
        push_error(atomic_failure_error)
        quit(8)
        return
    var invalid_profile_root: Node = Node.new()
    var invalid_profile_result: Dictionary = CandidateMaterialLoader.new().apply_to(
        invalid_profile_root, "", "invalid-profile"
    )
    invalid_profile_root.free()
    if not String(invalid_profile_result["error"]).contains(
            "unknown candidate material profile"
    ):
        push_error("An invalid material profile was hidden by an empty texture root")
        quit(9)
        return
    print("CANDIDATE_TEXTURE_VALIDATION=" + JSON.stringify({
        "body_loaded": true,
        "hair_loaded": true,
        "body_shader": body_material.shader.resource_path.get_file(),
        "hair_shader": hair_material.shader.resource_path.get_file(),
        "failed_profile_remained_unapplied": true,
        "invalid_empty_profile_rejected": true,
    }))
    scene.queue_free()
    await process_frame
    for path: String in texture_paths:
        DirAccess.remove_absolute(path)
    DirAccess.remove_absolute(texture_root)
    quit(0)


func _check_atomic_failure(candidate_path: String, valid_texture_root: String) -> String:
    var partial_root: String = OS.get_temp_dir().path_join(
        "brucelee-candidate-partial-texture-test-%d" % Time.get_ticks_usec()
    )
    if DirAccess.make_dir_recursive_absolute(partial_root) != OK:
        return "Could not create partial candidate texture directory"
    var copied_paths: Array[String] = []
    for map_name: String in ["diffuse", "normal", "material"]:
        var source: String = valid_texture_root.path_join("body_%s.png" % map_name)
        var target: String = partial_root.path_join("body_%s.png" % map_name)
        var copy_error: Error = DirAccess.copy_absolute(source, target)
        if copy_error != OK:
            _remove_texture_files(copied_paths, partial_root)
            return "Could not prepare partial candidate texture set (%d)" % copy_error
        copied_paths.append(target)

    var document: GLTFDocument = GLTFDocument.new()
    var state: GLTFState = GLTFState.new()
    var read_error: Error = document.append_from_file(candidate_path, state)
    if read_error != OK:
        _remove_texture_files(copied_paths, partial_root)
        return "Could not reload candidate for atomic texture test (%d)" % read_error
    var generated: Node = document.generate_scene(state)
    if generated == null:
        _remove_texture_files(copied_paths, partial_root)
        return "Candidate reload produced no scene for atomic texture test"

    var failure: String = ""
    var body_material_before: Material = null
    var body_found: bool = false
    for node: Node in generated.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance: MeshInstance3D = node as MeshInstance3D
        if String(mesh_instance.name).to_lower().contains("body"):
            body_found = true
            body_material_before = mesh_instance.material_override
            break
    if not body_found:
        failure = "Candidate has no body mesh for atomic texture test"
    else:
        var result: Dictionary = CandidateMaterialLoader.new().apply_to(
            generated, partial_root, "body_hair"
        )
        if result["loaded"]:
            failure = "Incomplete candidate texture profile unexpectedly succeeded"
        else:
            for node: Node in generated.find_children(
                    "*", "MeshInstance3D", true, false
            ):
                var mesh_instance: MeshInstance3D = node as MeshInstance3D
                if (String(mesh_instance.name).to_lower().contains("body")
                        and mesh_instance.material_override != body_material_before):
                    failure = "Failed candidate texture profile partially changed the body"
                    break

    generated.free()
    _remove_texture_files(copied_paths, partial_root)
    return failure


func _remove_texture_files(paths: Array[String], directory: String) -> void:
    for path: String in paths:
        DirAccess.remove_absolute(path)
    DirAccess.remove_absolute(directory)

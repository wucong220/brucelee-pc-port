extends RefCounted
## Apply repository-external candidate textures to a generated character model.

const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")
const BODY_CHARACTER_SHADER: Shader = preload(
    "res://shaders/character_candidate_opaque.gdshader"
)
const HAIR_CHARACTER_SHADER: Shader = preload(
    "res://shaders/character_candidate.gdshader"
)
const TEXTURE_NAMES: Dictionary = {
    "diffuse": "diffuse_texture",
    "normal": "normal_texture",
    "material": "material_texture",
}
const PROFILES: Dictionary = {
    "body_hair": [
        {"kind": "body", "node_match": "body", "shader": "body"},
        {"kind": "hair", "node_match": "hair", "shader": "hair"},
    ],
    "body": [
        {"kind": "body", "node_match": "body", "shader": "body"},
    ],
}


func apply_to(root: Node, texture_root: String, profile: String = "body_hair") -> Dictionary:
    var result: Dictionary = {
        "loaded": false,
        "body_loaded": false,
        "hair_loaded": false,
        "body_shader": "character_candidate_opaque.gdshader",
        "hair_shader": "character_candidate.gdshader",
        "profile": profile,
        "reason": "",
        "error": "",
    }
    if texture_root.is_empty():
        result["reason"] = "candidate texture root is not configured"
        return result
    if not PROFILES.has(profile):
        result["error"] = "unknown candidate material profile: " + profile
        return result
    var path_error: String = CandidatePathGuard.external_path_error(
        texture_root, "candidate texture root"
    )
    if not path_error.is_empty():
        result["error"] = path_error
        return result
    var normalized_root: String = CandidatePathGuard.normalize_absolute_path(texture_root)
    if not DirAccess.dir_exists_absolute(normalized_root):
        result["error"] = "candidate texture root must be an absolute local directory"
        return result

    var prepared_groups: Array[Dictionary] = []
    for group_value: Variant in PROFILES[profile]:
        var group: Dictionary = group_value
        var kind: String = String(group["kind"])
        var textures: Dictionary = _load_texture_set(normalized_root, kind, result)
        if textures.is_empty():
            return result
        var shader: Shader = (
            BODY_CHARACTER_SHADER if group["shader"] == "body"
            else HAIR_CHARACTER_SHADER
        )
        var material: ShaderMaterial = _make_material(textures, shader)
        var targets: Array[MeshInstance3D] = []
        for node: Node in root.find_children("*", "MeshInstance3D", true, false):
            var mesh_instance: MeshInstance3D = node as MeshInstance3D
            if String(mesh_instance.name).to_lower().contains(
                    String(group["node_match"])
            ):
                targets.append(mesh_instance)
        if targets.is_empty():
            result["error"] = (
                "candidate model is missing a %s MeshInstance3D" % kind
            )
            return result
        prepared_groups.append({
            "kind": kind,
            "material": material,
            "targets": targets,
        })

    for prepared: Dictionary in prepared_groups:
        var kind: String = String(prepared["kind"])
        var material: ShaderMaterial = prepared["material"]
        for mesh_instance: MeshInstance3D in prepared["targets"]:
            mesh_instance.material_override = material
        result[kind + "_loaded"] = true
    result["loaded"] = true
    return result


func _load_texture_set(texture_root: String, kind: String, result: Dictionary) -> Dictionary:
    var textures: Dictionary = {}
    for map_name: String in TEXTURE_NAMES:
        var path: String = texture_root.path_join("%s_%s.png" % [kind, map_name])
        if not FileAccess.file_exists(path):
            result["error"] = "missing candidate texture: " + path
            return {}
        var image: Image = Image.new()
        var error: Error = image.load(path)
        if error != OK:
            result["error"] = "candidate texture load failed (%d): %s" % [error, path]
            return {}
        image.generate_mipmaps()
        textures[TEXTURE_NAMES[map_name]] = ImageTexture.create_from_image(image)
    return textures


func _make_material(textures: Dictionary, shader: Shader) -> ShaderMaterial:
    var material: ShaderMaterial = ShaderMaterial.new()
    material.shader = shader
    for parameter: String in textures:
        material.set_shader_parameter(parameter, textures[parameter])
    return material

extends RefCounted
## Apply repository-external candidate textures to a generated character model.

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


func apply_to(root: Node, texture_root: String) -> Dictionary:
    var result: Dictionary = {
        "loaded": false,
        "body_loaded": false,
        "hair_loaded": false,
        "body_shader": "character_candidate_opaque.gdshader",
        "hair_shader": "character_candidate.gdshader",
        "error": "",
    }
    if texture_root.is_empty():
        return result
    var normalized_root: String = texture_root.replace("\\", "/")
    if (not texture_root.is_absolute_path()
            or normalized_root.begins_with("//")
            or normalized_root.contains("://")
            or not DirAccess.dir_exists_absolute(texture_root)):
        result["error"] = "candidate texture root must be an absolute local directory"
        return result

    var body_textures: Dictionary = _load_texture_set(texture_root, "body", result)
    if body_textures.is_empty():
        return result
    var body_material: ShaderMaterial = _make_material(body_textures, BODY_CHARACTER_SHADER)
    var hair_textures: Dictionary = _load_texture_set(texture_root, "hair", result)
    if hair_textures.is_empty():
        return result
    var hair_material: ShaderMaterial = _make_material(hair_textures, HAIR_CHARACTER_SHADER)

    var body_applied: bool = false
    var hair_applied: bool = false
    for node: Node in root.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance: MeshInstance3D = node as MeshInstance3D
        var mesh_name: String = String(mesh_instance.name).to_lower()
        if mesh_name.contains("body"):
            mesh_instance.material_override = body_material
            body_applied = true
        elif mesh_name.contains("hair"):
            mesh_instance.material_override = hair_material
            hair_applied = true

    if not body_applied or not hair_applied:
        result["error"] = "candidate model is missing a body or hair MeshInstance3D"
        return result
    result["loaded"] = true
    result["body_loaded"] = true
    result["hair_loaded"] = true
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

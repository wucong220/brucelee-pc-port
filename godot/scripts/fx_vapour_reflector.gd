extends Node3D
class_name FxVapourReflector
## Rooftops A fx_vapour_trail `reflector` resource.
##
## Native evidence (libdefault.so, SHA-256 1da7a30c…):
##   * the scene node type is `reflector`; CScnReflector::Init @0x380fe0 reads
##     normal/point/tangent/bitangent/center + width/height and builds a plane;
##   * CReflectorsPhase::RenderReflector @0x3e8b30 renders the scene into a
##     render target from a camera mirrored across that plane, then draws the
##     reflector's visual with the target texture (CBinder::Update @0x3e6b80).
## So the strip is a planar reflection surface, not a plain texture.
##
## This Godot resource reproduces that: a SubViewport whose Camera3D is the
## main camera mirrored across the strip plane, and a shader that projects each
## strip vertex into the mirror camera and multiplies the reflection by the
## authored vapour texture's alpha.  The GLB keeps its authored node scale
## animation (x 0.0983 -> 8.3055 over 6001 frames).
##
## The shader is embedded so the module is drop-in; vapour_reflector.gdshader is
## the same source kept beside it for review.

const STRIP_LAYER := 19  # 1 << 19; the mirror camera must not see the strip

const SHADER_CODE := """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D vapour_tex : filter_linear, repeat_disable;
uniform sampler2D reflection_tex : filter_linear, repeat_disable;
uniform mat4 reflection_matrix;
uniform float strength = 1.0;
uniform float force_alpha = -1.0;

varying vec4 v_reflect_clip;
varying vec2 v_uv;

void vertex() {
	v_uv = UV;
	vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
	v_reflect_clip = reflection_matrix * world;
}

void fragment() {
	vec4 vapour = texture(vapour_tex, v_uv);
	vec2 uv = v_reflect_clip.xy / max(v_reflect_clip.w, 1e-4);
	uv = uv * 0.5 + 0.5;
	vec3 reflected = texture(reflection_tex, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	ALBEDO = reflected;
	ALPHA = force_alpha >= 0.0 ? force_alpha : vapour.a * strength;
}
"""

var base_dir := ""
var world_scale := 1.0
var plain_mode := false
var force_alpha := -1.0

var mesh_instance: MeshInstance3D
var mirror_camera: Camera3D
var reflection_viewport: SubViewport
var material: ShaderMaterial
var strip_plane_point := Vector3.ZERO
var strip_plane_normal := Vector3.UP
var frame_count := 0


static func build(base_dir_path: String, world_scale_value: float,
		plain: bool = false, force_alpha_value: float = -1.0) -> Node3D:
	var node := FxVapourReflector.new()
	node.name = "FxVapourReflector"
	node.base_dir = base_dir_path
	node.world_scale = world_scale_value
	node.plain_mode = plain
	node.force_alpha = force_alpha_value
	return node


func _ready() -> void:
	var instance := _instantiate(base_dir.path_join("bl_fx_vapour_anim.glb"))
	if instance == null:
		push_error("FxVapourReflector: missing GLB")
		return
	instance.scale = Vector3.ONE * world_scale
	add_child(instance)
	for node: Node in instance.find_children("*", "MeshInstance3D", true, false):
		mesh_instance = node
		break
	if mesh_instance == null:
		push_error("FxVapourReflector: no mesh")
		return
	mesh_instance.layers = 1 << STRIP_LAYER

	var texture := _load_texture(base_dir.path_join(
		"c16b1416e8ea81ca78632ec9442ca339c811dd50.png"))
	if plain_mode:
		var flat := StandardMaterial3D.new()
		flat.albedo_texture = texture
		flat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		flat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		flat.cull_mode = BaseMaterial3D.CULL_DISABLED
		flat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mesh_instance.material_override = flat
	else:
		material = ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = SHADER_CODE
		material.shader = shader
		material.set_shader_parameter("vapour_tex", texture)
		material.set_shader_parameter("strength", 1.0)
		material.set_shader_parameter("force_alpha", force_alpha)
		mesh_instance.material_override = material

	# Play the authored 200 s strip growth.
	for node: Node in instance.find_children("*", "AnimationPlayer", true, false):
		var player: AnimationPlayer = node
		for clip: String in player.get_animation_list():
			player.get_animation(clip).loop_mode = Animation.LOOP_NONE
			player.play(clip)

	if not plain_mode:
		reflection_viewport = SubViewport.new()
		reflection_viewport.name = "ReflectionViewport"
		reflection_viewport.size = Vector2i(get_viewport().get_visible_rect().size)
		reflection_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		reflection_viewport.transparent_bg = false
		reflection_viewport.handle_input_locally = false
		mirror_camera = Camera3D.new()
		mirror_camera.name = "ReflectionCamera"
		mirror_camera.fov = 60.0
		mirror_camera.near = 0.05
		mirror_camera.far = 4000.0
		mirror_camera.current = true
		mirror_camera.cull_mask = 0xFFFFF & ~(1 << STRIP_LAYER)
		reflection_viewport.add_child(mirror_camera)
		add_child(reflection_viewport)
		reflection_viewport.world_3d = get_world_3d()
		# A SubViewport has its own viewport environment; copy the scene's so the
		# reflection sees the same sky/background instead of the black default.
		for node: Node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			var world_environment: WorldEnvironment = node
			if world_environment.environment != null:
				var sub_environment := WorldEnvironment.new()
				sub_environment.environment = world_environment.environment
				reflection_viewport.add_child(sub_environment)
				break
		material.set_shader_parameter("reflection_tex", reflection_viewport.get_texture())


func _process(_delta: float) -> void:
	frame_count += 1
	if plain_mode or material == null or mesh_instance == null or mirror_camera == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var xform := mesh_instance.global_transform
	strip_plane_point = xform * Vector3(0.0, 0.0, 0.021048)
	strip_plane_normal = (xform.basis * Vector3(0.0, 0.0, 1.0)).normalized()
	var view := camera.global_transform
	var distance := strip_plane_normal.dot(view.origin - strip_plane_point)
	var mirrored_position := view.origin - 2.0 * distance * strip_plane_normal
	var forward := -view.basis.z
	var up := view.basis.y
	var mirrored_forward := (forward - 2.0 * strip_plane_normal.dot(forward) * strip_plane_normal)
	# Sampling uses the ray from the mirrored camera through each strip vertex, so
	# the camera's roll does not change the sampled colour.  Keeping the main
	# camera's up avoids a needlessly rolled render target.
	var mirrored_up := up
	mirror_camera.global_position = mirrored_position
	if mirrored_forward.length() > 1e-5:
		mirror_camera.look_at(mirrored_position + mirrored_forward, mirrored_up)
	mirror_camera.fov = camera.fov
	mirror_camera.near = camera.near
	mirror_camera.far = camera.far
	mirror_camera.projection = camera.projection
	var projection := mirror_camera.get_camera_projection()
	var vp := projection * Projection(mirror_camera.global_transform.affine_inverse())
	material.set_shader_parameter("reflection_matrix", vp)


func _instantiate(path: String) -> Node3D:
	if not FileAccess.file_exists(path):
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	return document.generate_scene(state)


func _load_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)

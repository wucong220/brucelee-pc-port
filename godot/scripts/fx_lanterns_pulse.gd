extends Node3D
class_name FxLanternPulse
## Rooftops B lantern colour-pulse layer (authored g_vColor material animation).
##
## The source `fx_lanterns.anm` animates three per-visual RGB multipliers over
## 81 frames at 30 fps (2.7 s loop).  glTF cannot carry material animation, so
## this node loads the two shipped animated lantern GLBs, gives each visual its
## own StandardMaterial3D and plays a Godot Animation that keys
## `material_override:albedo_color` with the exact authored per-frame values.
##
## Usage (drop-in, no repo edit):
##   var fx := FxLanternPulse.build(base_dir, curves_path, WORLD_SCALE)
##   add_child(fx)
## base_dir holds the two GLBs + PNGs (`scene/rooftopsb/fx_anim`), curves_path
## is the delivered `lantern_pulse_curves.json`.

const DEFAULT_CURVES := "lantern_pulse_curves.json"


static func build(base_dir: String, curves_path: String, world_scale: float) -> Node3D:
	var root := Node3D.new()
	root.name = "FxLanternPulse"
	var curves: Variant = _read_json(curves_path)
	if not curves is Dictionary:
		push_error("FxLanternPulse: missing curves " + curves_path)
		return root
	var fps: float = float((curves as Dictionary).get("fps", 30))
	var frames: int = int((curves as Dictionary).get("frames", 81))

	var player := AnimationPlayer.new()
	player.name = "LanternPulsePlayer"
	var animation := Animation.new()
	animation.resource_name = "lantern_pulse"
	animation.length = float(frames - 1) / fps
	animation.loop_mode = Animation.LOOP_LINEAR

	var loaded: Dictionary = {}
	for track_value: Variant in (curves as Dictionary).get("tracks", []):
		if not track_value is Dictionary:
			continue
		var track: Dictionary = track_value
		var glb_path: String = base_dir.path_join(String(track.get("glb", "")))
		var instance: Node3D = loaded.get(glb_path)
		if instance == null:
			instance = _instantiate(glb_path)
			if instance == null:
				continue
			instance.scale = Vector3.ONE * world_scale
			root.add_child(instance)
			loaded[glb_path] = instance
		var prefix := String(track.get("mesh_node_prefix", ""))
		var mesh_node: MeshInstance3D = null
		for node: Node in instance.find_children("*", "MeshInstance3D", true, false):
			if String(node.name).begins_with(prefix):
				mesh_node = node
				break
		if mesh_node == null:
			push_warning("FxLanternPulse: mesh node %s not found" % prefix)
			continue
		var material := StandardMaterial3D.new()
		material.albedo_texture = _load_texture(base_dir.path_join(String(track.get("texture", ""))))
		material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		material.roughness = 0.95
		mesh_node.material_override = material

		var track_index := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_index, NodePath(
			String(root.get_path_to(mesh_node)) + ":material_override:albedo_color"))
		animation.value_track_set_update_mode(track_index, Animation.UPDATE_CONTINUOUS)
		animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
		var rgb: Array = track.get("rgb", [])
		var alpha: Array = track.get("alpha", [])
		for frame in range(rgb.size()):
			var value := float(rgb[frame])
			var a := float(alpha[frame]) if frame < alpha.size() else 1.0
			animation.track_insert_key(track_index, float(frame) / fps,
				Color(value, value, value, a))

	var library := AnimationLibrary.new()
	library.add_animation("lantern_pulse", animation)
	player.add_animation_library("", library)
	player.root_node = NodePath("..")
	root.add_child(player)
	player.play("lantern_pulse")

	# The GLB keeps its authored bone animation; play that too (2.7 s loop).
	for instance_value: Variant in loaded.values():
		for node: Node in (instance_value as Node).find_children("*", "AnimationPlayer", true, false):
			var bone_player: AnimationPlayer = node
			for clip: String in bone_player.get_animation_list():
				bone_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				bone_player.play(clip)
	return root


static func _instantiate(glb_path: String) -> Node3D:
	if not FileAccess.file_exists(glb_path):
		push_error("FxLanternPulse: missing GLB " + glb_path)
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(glb_path, state) != OK:
		return null
	return document.generate_scene(state)


static func _load_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())

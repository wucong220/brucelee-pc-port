extends Node
class_name FxMaterialTracks
## Per-material tracks of the decoded FX groups (colour + UV offset).
##
## The FX-groups delivery decodes the authored `anmobjects` material blocks into
## `reports/material_tracks.json` and notes that **glTF has no material-animation
## channel**, so the delivered `*_anim.glb` files carry only the node TRS clips.
## This node replays those tracks on the GLB the normal FX loader instantiated:
##
##   * `color`             -> `albedo_color`  (the engine's per-visual
##                            `g_vColor` multiplier; the extracted scene base
##                            program declares exactly `uniform vec4 g_vColor;`
##                            and samples `g_sDiffuse` with it),
##   * `uoffset`/`voffset` -> `uv1_offset`    (additive UV offset - the literal
##                            reading of the two properties; see REPORT.md),
##   * a single sample     -> constant: applied once, no keys.
##
## A slot addresses a *material subset* of a visual: the ANM material block is
## anchored to a visual node and declares one index per subset of that visual's
## `.Mesh`.  The GLB carries one primitive per visual, so a visual with several
## addressed subsets is split here into one MeshInstance3D per subset (same
## vertices, sliced index range, shared skin/skeleton) and each gets its own
## animated material.  Visuals without an addressed subset keep the loader
## material untouched.
##
## Playback: a second AnimationPlayer inside the loaded GLB instance, keyed at
## `frame / fps` with the same length and loop mode as the GLB clip, so the
## authored node animation and the material animation stay in step.
##
## Usage (drop-in; one loader line):
##   var driver := FxMaterialTracks.attach(base_dir, entry)
##   if driver != null:
##       instance.add_child(driver)

const DEFAULT_CURVES := "fx_material_curves.json"
const TRACK_NAME := "material_tracks"

static var _curves_cache: Dictionary = {}

var base_dir := ""
var entry_name := ""
var curves_path := ""
var clip_loop := false
var clip_fps := 30.0
var clip_frames := 0

var player: AnimationPlayer
## One record per animated layer: {visual, layer, node, material, original}
var driven: Array[Dictionary] = []
## One record per split visual: {node, children}
var splits: Array[Dictionary] = []
var problems: Array[String] = []
var track_count := 0
var key_count := 0
var enabled := true


static func attach(base: String, entry: Dictionary) -> Node:
	## Returns a driver for this fx_anim entry, or null when the entry's group
	## has no decoded material track (most entries do not).
	var node := FxMaterialTracks.new()
	node.name = "FxMaterialTracks"
	node.base_dir = base
	node.entry_name = String(entry.get("name", ""))
	var configured: Variant = entry.get("material_tracks", {})
	var curves_name := DEFAULT_CURVES
	if configured is Dictionary:
		curves_name = String((configured as Dictionary).get("curves", DEFAULT_CURVES))
	node.curves_path = base.path_join(curves_name)
	var animation: Dictionary = entry.get("animation", {})
	node.clip_loop = bool(animation.get("loop", false))
	node.clip_fps = float(animation.get("fps", 30))
	node.clip_frames = int(animation.get("frames", 0))
	var document: Variant = _read_curves(node.curves_path)
	if not document is Dictionary:
		return null
	var entries: Variant = (document as Dictionary).get("entries", {})
	if not entries is Dictionary or not (entries as Dictionary).has(node.entry_name):
		return null
	return node


func _ready() -> void:
	var document: Variant = _read_curves(curves_path)
	if not document is Dictionary:
		_problem("missing curves " + curves_path)
		return
	var entries: Variant = (document as Dictionary).get("entries", {})
	if not entries is Dictionary or not (entries as Dictionary).has(entry_name):
		return
	var data: Dictionary = (entries as Dictionary)[entry_name]
	var instance: Node3D = get_parent() as Node3D
	if instance == null:
		_problem("driver has no Node3D parent")
		return

	var fps: float = float(data.get("fps", clip_fps))
	if fps > 0.0:
		clip_fps = fps
	var frames: int = int(data.get("frames", clip_frames))
	if frames <= 0:
		frames = clip_frames
	clip_frames = frames

	var animation := Animation.new()
	animation.resource_name = TRACK_NAME
	animation.length = maxf(0.0, float(frames - 1) / clip_fps)
	animation.loop_mode = Animation.LOOP_LINEAR if clip_loop else Animation.LOOP_NONE

	for visual_value: Variant in data.get("visuals", []):
		if not visual_value is Dictionary:
			continue
		var visual: Dictionary = visual_value
		var mesh_node := _find_mesh(instance, visual)
		if mesh_node == null:
			_problem("mesh node not found: " + String(visual.get("mesh_node", "")))
			continue
		var layers: Array = visual.get("layers", [])
		# One layer covering the whole mesh needs no split; several material
		# subsets of one GLB primitive do.
		var targets: Array = []
		if layers.size() == 1:
			targets.append({"layer": layers[0], "node": mesh_node})
		else:
			var parts := _split_visual(instance, mesh_node, layers)
			if parts.size() != layers.size():
				continue
			for index in range(layers.size()):
				targets.append({"layer": layers[index], "node": parts[index]})

		for target: Dictionary in targets:
			var node: MeshInstance3D = target["node"]
			var layer: Dictionary = target["layer"]
			var original: Material = mesh_node.material_override
			var material := _make_material(original)
			# The authored offsets are whole-tile neutral values (1.0 / 0.0) and
			# only mean "no offset" because the sampler repeats, so repeat must
			# stay on (`BaseMaterial3D.texture_repeat` is a bool, default true).
			material.texture_repeat = true
			node.material_override = material
			driven.append({
				"visual": String(visual.get("visual", "")),
				"layer": int(layer.get("subset", 0)),
				"slot": int(layer.get("slot", -1)),
				"node": node,
				"material": material,
				"original": original,
			})
			_build_tracks(animation, instance, node, material, layer, frames)

	if animation.get_track_count() > 0:
		var library := AnimationLibrary.new()
		library.add_animation(TRACK_NAME, animation)
		player = AnimationPlayer.new()
		player.name = "MaterialTracksPlayer"
		# Child of the driver, so paths resolve from the GLB root
		# (driver -> "../.." = instance).  Adding to the instance itself would
		# fail while the instance is still setting up its children.
		player.root_node = NodePath("../..")
		player.add_animation_library("", library)
		add_child(player)
		player.play(TRACK_NAME)
	print("FX material tracks: %s layers=%d split=%d tracks=%d keys=%d" % [
		entry_name, driven.size(), splits.size(), track_count, key_count])


func _build_tracks(animation: Animation, instance: Node, node: MeshInstance3D,
		material: StandardMaterial3D, layer: Dictionary, frames: int) -> void:
	if layer.has("uoffset") or layer.has("voffset"):
		material.uv1_offset = Vector3(
			_series_value(layer, "uoffset", 0, 0.0),
			_series_value(layer, "voffset", 0, 0.0),
			0.0)
	if layer.has("color"):
		material.albedo_color = _color_at(layer, 0)

	var path := String(instance.get_path_to(node)) + ":material_override:"
	if _is_animated(layer, "uoffset") or _is_animated(layer, "voffset"):
		var index := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(index, NodePath(path + "uv1_offset"))
		animation.value_track_set_update_mode(index, Animation.UPDATE_CONTINUOUS)
		animation.track_set_interpolation_type(index, Animation.INTERPOLATION_LINEAR)
		for frame in range(frames):
			animation.track_insert_key(index, float(frame) / clip_fps, Vector3(
				_series_value(layer, "uoffset", frame, 0.0),
				_series_value(layer, "voffset", frame, 0.0),
				0.0))
		track_count += 1
		key_count += frames
	if _is_animated(layer, "color"):
		var index := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(index, NodePath(path + "albedo_color"))
		animation.value_track_set_update_mode(index, Animation.UPDATE_CONTINUOUS)
		animation.track_set_interpolation_type(index, Animation.INTERPOLATION_LINEAR)
		for frame in range(frames):
			animation.track_insert_key(index, float(frame) / clip_fps, _color_at(layer, frame))
		track_count += 1
		key_count += frames


func _split_visual(instance: Node3D, mesh_node: MeshInstance3D, layers: Array) -> Array:
	## Split the single GLB primitive into one MeshInstance3D per material
	## subset, using the authored index ranges.  Same vertices, sliced indices,
	## same skin/skeleton/transform, siblings of the original.
	var result: Array = []
	var source: Mesh = mesh_node.mesh
	if source == null or source.get_surface_count() != 1:
		_problem("cannot split %s: %d surfaces" % [
			mesh_node.name, source.get_surface_count() if source != null else -1])
		return result
	var arrays: Array = source.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var total := indices.size()
	var parent := mesh_node.get_parent()
	if parent == null:
		return result
	for layer: Dictionary in layers:
		var index_range: Array = layer.get("index_range", [])
		if index_range.size() != 2:
			_problem("layer without index_range on " + mesh_node.name)
			return []
		var start := int(index_range[0])
		var end := int(index_range[1])
		if start < 0 or end > total or start >= end:
			_problem("index_range %d..%d outside %d on %s"
				% [start, end, total, mesh_node.name])
			return []
		var part := arrays.duplicate()
		part[Mesh.ARRAY_INDEX] = indices.slice(start, end)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part)
		var child := MeshInstance3D.new()
		child.name = "%s_subset%d" % [mesh_node.name, int(layer.get("subset", 0))]
		child.mesh = mesh
		child.transform = mesh_node.transform
		child.layers = mesh_node.layers
		child.skin = mesh_node.skin
		child.skeleton = mesh_node.skeleton
		child.visible = mesh_node.visible
		parent.add_child(child)
		result.append(child)
	if not result.is_empty():
		mesh_node.visible = false
		splits.append({"node": mesh_node, "children": result})
	return result


func set_enabled(value: bool) -> void:
	## Debug / proof aid: `false` restores the loader's own material (and the
	## unsplit mesh) and stops the material player, so a capture can be compared
	## against the exact package behaviour without the material tracks.
	var saved := 0.0
	if player != null and player.has_animation(TRACK_NAME):
		saved = player.current_animation_position
	enabled = value
	if player != null:
		if value:
			player.play(TRACK_NAME)
			player.seek(saved, true)
		else:
			player.stop()
	for record: Dictionary in driven:
		(record["node"] as MeshInstance3D).material_override = (
			record["material"] if value else record["original"])
	for split: Dictionary in splits:
		var original: MeshInstance3D = split["node"]
		original.visible = not value
		for child: MeshInstance3D in split["children"]:
			child.visible = value


func status() -> Dictionary:
	var length := 0.0
	if player != null and player.has_animation(TRACK_NAME):
		length = player.get_animation(TRACK_NAME).length
	return {
		"entry": entry_name,
		"curves": curves_path,
		"layers": driven.size(),
		"split_visuals": splits.size(),
		"tracks": track_count,
		"keys": key_count,
		"length": length,
		"fps": clip_fps,
		"frames": clip_frames,
		"loop": clip_loop,
		"enabled": enabled,
		"problems": problems.duplicate(),
	}


func _series_value(layer: Dictionary, property: String, frame: int,
		fallback: float) -> float:
	if not layer.has(property):
		return fallback
	var series: Array = layer[property]
	if series.is_empty():
		return fallback
	return float(series[clampi(frame, 0, series.size() - 1)])


func _color_at(layer: Dictionary, frame: int) -> Color:
	if not layer.has("color"):
		return Color(1.0, 1.0, 1.0, 1.0)
	var series: Array = layer["color"]
	if series.is_empty():
		return Color(1.0, 1.0, 1.0, 1.0)
	var sample: Array = series[clampi(frame, 0, series.size() - 1)]
	var alpha := float(sample[3]) if sample.size() > 3 else 1.0
	return Color(float(sample[0]), float(sample[1]), float(sample[2]), alpha)


func _is_animated(layer: Dictionary, property: String) -> bool:
	if not layer.has(property):
		return false
	var series: Array = layer[property]
	return series.size() > 1


func _find_mesh(instance: Node, visual: Dictionary) -> MeshInstance3D:
	for candidate in [String(visual.get("mesh_node", "")), String(visual.get("visual", ""))]:
		if candidate.is_empty():
			continue
		for node: Node in instance.find_children(candidate, "MeshInstance3D", true, false):
			return node as MeshInstance3D
	return null


func _make_material(original: Material) -> StandardMaterial3D:
	if original is StandardMaterial3D:
		return (original as StandardMaterial3D).duplicate() as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	material.roughness = 0.95
	return material


func _problem(message: String) -> void:
	problems.append(message)
	push_error("FxMaterialTracks(%s): %s" % [entry_name, message])


static func _read_curves(path: String) -> Variant:
	if _curves_cache.has(path):
		return _curves_cache[path]
	var document: Variant = null
	if FileAccess.file_exists(path):
		var text := FileAccess.get_file_as_string(path)
		if not text.is_empty():
			document = JSON.parse_string(text)
	_curves_cache[path] = document
	return document

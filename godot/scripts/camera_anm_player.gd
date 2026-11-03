## Camera ANM playback prototype.
##
## Decoded camera .anm keyframes (see tools/camera_anm.py) are shipped as JSON.
## This player samples them and places the authored local camera in the world
## using the decompiled CBeatEmUpCamera::StartAnimation reference frame:
##   dummy position = acting fighter
##   dummy yaw      = atan2(to_opponent.y, to_opponent.x) + PI/2
##   world          = dummy_pos + Rz(dummy_yaw) * local      (source Z-up)
## The whole pose is then converted to Godot Y-up with orig_to_godot().
class_name CameraAnmPlayer
extends RefCounted

const SOURCE_UNITS_TO_WORLD: float = 1.8 / 173.415954589844

var _frames: Array = []
var _fps: float = 30.0
var _duration: int = 0


func load_json(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("cannot open camera anm json: " + path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("camera anm json is not a dictionary")
		return false
	var data: Dictionary = parsed
	var frames: Variant = data.get("keyframes", [])
	if typeof(frames) != TYPE_ARRAY or (frames as Array).is_empty():
		push_error("camera anm json has no keyframes")
		return false
	_frames = frames
	_fps = float(data.get("format", {}).get("framerate", 30))
	_duration = _frames.size()
	return true


func frame_count() -> int:
	return _duration


func duration_seconds() -> float:
	return float(_duration) / maxf(_fps, 0.001)


## Source (Z-up) -> Godot (Y-up) and source units -> metres.
static func orig_to_godot(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, -v.y) * SOURCE_UNITS_TO_WORLD


func sample_local(index: int) -> Dictionary:
	var i := clampi(index, 0, _duration - 1)
	var row: Dictionary = _frames[i]
	var c: Array = row.get("camera", [0, 0, 0])
	var result := {
		"frame": i,
		"camera_local": Vector3(float(c[0]), float(c[1]), float(c[2])),
		"has_target": row.get("target") != null,
		"target_local": Vector3.ZERO,
		"rotation": Quaternion(0, 0, 0, 1),
		"fov_degrees": float(row.get("fov_degrees", 45.0)),
	}
	if result["has_target"]:
		var t: Array = row["target"]
		result["target_local"] = Vector3(float(t[0]), float(t[1]), float(t[2]))
	var q: Array = row.get("rotation", [0, 0, 0, 1])
	result["rotation"] = Quaternion(float(q[0]), float(q[1]), float(q[2]), float(q[3]))
	return result


## Place a local keyframe in source world space via the fighter reference frame.
func place_world(index: int, anchor_a: Vector3, anchor_b: Vector3, mirror: bool) -> Dictionary:
	var local := sample_local(index)
	var origin := anchor_b if mirror else anchor_a
	var to_other := (anchor_a - anchor_b) if mirror else (anchor_b - anchor_a)
	var yaw := atan2(to_other.y, to_other.x) + PI * 0.5
	var c: Vector3 = local["camera_local"]
	var cam := Vector3(c.x * cos(yaw) - c.y * sin(yaw), c.x * sin(yaw) + c.y * cos(yaw), c.z) + origin
	var target := Vector3.ZERO
	if local["has_target"]:
		var t: Vector3 = local["target_local"]
		target = Vector3(t.x * cos(yaw) - t.y * sin(yaw), t.x * sin(yaw) + t.y * cos(yaw), t.z) + origin
	return {
		"camera_source": cam,
		"target_source": target,
		"has_target": local["has_target"],
		"camera_world": orig_to_godot(cam),
		"target_world": orig_to_godot(target),
		"fov_degrees": local["fov_degrees"],
		"rotation": local["rotation"],
		"yaw": yaw,
	}


## Apply to a real Camera3D.  If the clip has a look-at target we use look_at
## (the authoring intent, verified to match the rotation quaternion exactly on
## all 70 clips); otherwise we build the basis from the quaternion.
func apply_to(camera: Camera3D, index: int, anchor_a: Vector3, anchor_b: Vector3, mirror: bool) -> Dictionary:
	var pose := place_world(index, anchor_a, anchor_b, mirror)
	camera.global_position = pose["camera_world"]
	camera.fov = pose["fov_degrees"]
	if pose["has_target"]:
		camera.look_at(pose["target_world"], Vector3.UP)
	else:
		var q: Quaternion = pose["rotation"]
		var yaw: float = pose["yaw"]
		# Source camera local axes: forward = -Z, up = +Y.  Compose the dummy
		# yaw (source frame) then convert to Godot Y-up.
		var fwd_src := q * Vector3(0, 0, -1)
		var up_src := q * Vector3(0, 1, 0)
		var cf := cos(yaw)
		var sf := sin(yaw)
		var fwd_world := Vector3(fwd_src.x * cf - fwd_src.y * sf,
				fwd_src.x * sf + fwd_src.y * cf, fwd_src.z)
		var up_world := Vector3(up_src.x * cf - up_src.y * sf,
				up_src.x * sf + up_src.y * cf, up_src.z)
		var fwd := orig_to_godot(fwd_world).normalized()
		var up := orig_to_godot(up_world).normalized()
		camera.look_at(camera.global_position + fwd, up)
	return pose


## Analytic combat camera (godot/scripts/main.gd _native_camera_pose), source units.
static func analytic_pose(a: Vector3, b: Vector3, side: int = 0) -> Dictionary:
	var d := b - a
	var length := d.length()
	var midpoint := (a + b) * 0.5
	var target := midpoint + Vector3(0.0, 0.0, 112.0)
	var u := d / maxf(length, 0.0001)
	var lateral := Vector3(u.y, -u.x, 0.0)
	if side != 0:
		lateral = -lateral
	var distance := maxf(length, 275.0)
	return {"position": target + lateral * distance, "target": target, "fov_degrees": 75.0}

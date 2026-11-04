extends SceneTree
## Headless acceptance test for the recovered grab / grabbed / end-attack /
## special action cameras on the REAL res://scenes/main.tscn.
##
## It drives the real action entry points (request_attack / begin_grabbed /
## begin_endattack_victim), samples the live Camera3D frame by frame and checks
## every frame against CameraAnmPlayer.place_world() of the decoded JSON, so the
## test cannot pass with invented keyframes or a drifting clock.  It covers:
##   * grab1, grab2, endattack1, endattack2, special_kick_low_hit,
##     special_punch_high_hit, special_punch_low_hit (local player attacker)
##   * grabbed1, grabbed2 and the endattackcomp1 victim finisher (local player
##     victim, clips resolved from the opponent's recovered set)
##   * dummy = player / mirror = false (the camera side follows the player slot)
##   * mirror = true placement (CameraAnmPlayer dummy/mirror math)
##   * analytic fall-back when a mapped JSON is missing, when the map itself is
##     missing, and when an action has no authored camera at all
##
## usage: --headless --path <proj> --script res://tests/validate_action_cameras.gd -- \
##        <player.glb> <opponent.glb> <opponent_attack_config> <gametext_root>

const Player = preload("res://scripts/camera_anm_player.gd")
const CAMERA_DIR := "res://data/camera_anm/"
const MISSING_DIR := "res://data/camera_anm_missing/"
const CAM_SOURCE_UNITS_TO_WORLD: float = (
	PortFighter.WORLD_CHARACTER_HEIGHT / PortFighter.SOURCE_CHARACTER_HEIGHT
)

# clip -> set action kind whose recovered animation it is (attacker side)
const ATTACKER_CASES: Array = [
	{"kind": "grab1", "clip": "m01_grab_01", "frames": 150, "exact_end": true},
	{"kind": "grab2", "clip": "m01_grab_02", "frames": 180, "exact_end": true},
	{"kind": "endattack1", "clip": "m01_end_attack_01", "frames": 377, "exact_end": true},
	{"kind": "endattack2", "clip": "m01_end_attack_02", "frames": 235, "exact_end": true},
	{"kind": "special_kick_low_hit", "clip": "m01_sp_kick_low", "frames": 39,
		"exact_end": true},
	{"kind": "special_punch_high_hit", "clip": "m01_sp_pnch_high", "frames": 80,
		"exact_end": true},
	{"kind": "special_punch_low_hit", "clip": "m01_sp_pnch_low", "frames": 178,
		"exact_end": true},
]
# victim cases: kind is the grab attack that put the local player in the state
const VICTIM_CASES: Array = [
	{"kind": "grab1_brick", "state": "grabbed1", "clip": "all_grabbed_01_forset02",
		"frames": 47},
	{"kind": "grab2_brick", "state": "grabbed2", "clip": "all_grabbed_02_forset02",
		"frames": 98},
]
const VICTIM_COMP: Dictionary = {
	"grab_kind": "grab1_brick", "attacker_kind": "endattack1",
	"state": "endattackcomp1", "clip": "all_end_attack_01_forset02", "frames": 132,
}

var _failures: Array[String] = []
var _results: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS ", label, " ", detail)
	else:
		_failures.append(label + " " + detail)
		push_error("FAIL " + label + " " + detail)
		print("FAIL ", label, " ", detail)


func _new_scene(player_glb: String, opponent_glb: String, attack_config: String,
		text_root: String) -> Node:
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")
	OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
	OS.set_environment("BRUCELEE_ROUND_TIME", "60")
	OS.set_environment("BRUCELEE_PLAYER_GLB", player_glb)
	OS.set_environment("BRUCELEE_OPPONENT_GLB", opponent_glb)
	OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", attack_config)
	OS.set_environment("BRUCELEE_GAME_TEXT_ROOT", text_root)
	OS.set_environment("BRUCELEE_GAME_TEXT_FLIP", "1")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	return scene


func _wait_candidates(scene: Node, timeout_frames: int = 1200) -> bool:
	var player: PortFighter = scene.get("player")
	var computer: PortFighter = scene.get("computer")
	for _i: int in range(timeout_frames):
		if player.candidate_loaded and computer.candidate_loaded:
			return true
		await physics_frame
	return player.candidate_loaded and computer.candidate_loaded


func _freeze(scene: Node) -> void:
	scene.set_process(false)
	scene.set_physics_process(false)
	var player: PortFighter = scene.get("player")
	var computer: PortFighter = scene.get("computer")
	player.set_physics_process(false)
	computer.set_physics_process(false)
	player.opponent = computer
	computer.opponent = player


func _reset(scene: Node, player_on_right: bool = false) -> void:
	var player: PortFighter = scene.get("player")
	var computer: PortFighter = scene.get("computer")
	scene._camera_anm_end()
	scene._action_camera_end()
	if player_on_right:
		player.reset_fighter(Vector3(2.0, 1.20, 0.0))
		computer.reset_fighter(Vector3(1.7, 1.20, 0.0))
		player.facing = -1.0
		computer.facing = 1.0
	else:
		player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
		computer.reset_fighter(Vector3(-1.7, 1.20, 0.0))
		player.facing = 1.0
		computer.facing = -1.0
	player.rage = 100.0
	player.opponent = computer
	computer.opponent = player
	scene._restart_fight_camera()
	scene._update_fight_camera(1.0 / 60.0)


func _reference(clip: String) -> RefCounted:
	var ref = Player.new()
	if not ref.load_json(CAMERA_DIR + clip + ".json"):
		return null
	return ref


func _torso_world(fighter: PortFighter, height: float) -> Vector3:
	var ground: float = fighter.global_position.y - PortFighter.PLAYER_ORIGIN_HEIGHT
	return Vector3(fighter.global_position.x, ground + height, fighter.global_position.z)


func _inside(viewport: Vector2, screen: Vector2) -> bool:
	return (screen.x >= -0.05 * viewport.x and screen.x <= 1.05 * viewport.x
			and screen.y >= -0.05 * viewport.y and screen.y <= 1.05 * viewport.y)


func _analytic_expected(scene: Node) -> Vector3:
	var pose: Dictionary = scene._native_camera_pose(
		scene.get("_cam_smooth_a"), scene.get("_cam_smooth_b"),
		scene._camera_aspect_scale()
	)
	return (pose["position"] as Vector3) * CAM_SOURCE_UNITS_TO_WORLD


func _sample(scene: Node, clip: String, frames: int) -> Dictionary:
	## Tick the real camera per action frame and compare with place_world().
	var player: PortFighter = scene.get("player")
	var computer: PortFighter = scene.get("computer")
	var camera: Camera3D = scene.get("fight_camera")
	var ref = _reference(clip)
	if ref == null:
		return {"error": "reference json missing: " + clip}
	var max_err: float = 0.0
	var max_fov_err: float = 0.0
	var max_index_err: int = 0
	var max_cut: float = 0.0
	var min_look_dot: float = 1.0
	var first_index: int = -1
	var last_index: int = -1
	var anchor_ok: bool = true
	var clip_seen: String = ""
	var camera_seen: String = ""
	var mirror_seen: bool = true
	var anchor_seen: String = "none"
	var previous_camera := Vector3.ZERO
	var sample_count: int = 0
	var step: int = 0
	while step < frames + 8:
		step += 1
		scene._update_fight_camera(1.0 / 60.0)
		if String(scene.get("_action_camera_clip")) != clip:
			break
		var index: int = int(scene.get("_action_camera_frame"))
		var player_frame: float = player.current_camera_frame()
		var a: Vector3 = scene.get("_action_camera_a")
		var b: Vector3 = scene.get("_action_camera_b")
		var mirror: bool = scene.get("_action_camera_mirror")
		var expected: Dictionary = ref.place_world(index, a, b, mirror)
		var err: float = camera.global_position.distance_to(expected["camera_world"])
		var fov_err: float = absf(camera.fov - float(expected["fov_degrees"]))
		max_err = maxf(max_err, err)
		max_fov_err = maxf(max_fov_err, fov_err)
		max_index_err = maxi(max_index_err, absi(index - int(player_frame)))
		if first_index < 0:
			first_index = index
			clip_seen = String(scene.get("_action_camera_clip"))
			camera_seen = String(scene.get("_action_camera_camera"))
			mirror_seen = bool(scene.get("_action_camera_mirror"))
			anchor_seen = "player" if scene.get("_action_camera_anchor") == player else "other"
			var viewport: Vector2 = root.get_visible_rect().size
			var anchor: Vector2 = camera.unproject_position(_torso_world(player, 1.1))
			anchor_ok = _inside(viewport, anchor)
		if bool(expected["has_target"]):
			var forward: Vector3 = -camera.global_transform.basis.z
			min_look_dot = minf(min_look_dot, forward.normalized().dot(
				((expected["target_world"] as Vector3) - camera.global_position).normalized()))
		if sample_count > 0:
			max_cut = maxf(max_cut, camera.global_position.distance_to(previous_camera))
		previous_camera = camera.global_position
		last_index = index
		sample_count += 1
		player._advance_timed_states(1.0 / 30.0)
		computer._advance_timed_states(1.0 / 30.0)
	return {
		"samples": sample_count,
		"first_index": first_index,
		"last_index": last_index,
		"frames": frames,
		"max_place_world_err": max_err,
		"max_fov_err": max_fov_err,
		"max_index_err": max_index_err,
		"max_camera_step": max_cut,
		"min_look_dot": min_look_dot,
		"clip": clip_seen,
		"camera": camera_seen,
		"mirror": mirror_seen,
		"anchor": anchor_seen,
		"anchor_on_screen": anchor_ok,
	}


func _check_sampled(label: String, spec: Dictionary, bundle: Dictionary) -> void:
	var clip: String = String(spec["clip"])
	var frames: int = int(spec["frames"])
	var expected_last: int = int(bundle.get("expected_last", frames - 1))
	var exact_end: bool = bool(spec.get("exact_end", false))
	_check(label + " plays the recovered clip",
		String(bundle.get("clip", "")) == clip
		and String(bundle.get("camera", "")) == clip,
		"%s / %s" % [bundle.get("clip", ""), bundle.get("camera", "")])
	_check(label + " camera index follows the action frame",
		int(bundle.get("max_index_err", 99)) == 0,
		str(bundle.get("max_index_err", 99)))
	_check(label + " every frame matches place_world of the decoded JSON",
		float(bundle.get("max_place_world_err", 99.0)) < 0.002,
		str(bundle.get("max_place_world_err", 99.0)))
	_check(label + " fov matches the decoded animation",
		float(bundle.get("max_fov_err", 99.0)) < 0.01,
		str(bundle.get("max_fov_err", 99.0)))
	var end_ok: bool = (
		int(bundle.get("last_index", -1)) == expected_last
		if exact_end else
		int(bundle.get("last_index", -1)) >= expected_last - 2
	)
	_check(label + " plays the action timeline frame by frame",
		int(bundle.get("first_index", -1)) == 0
		and int(bundle.get("samples", 0)) >= int(bundle.get("last_index", -2)) + 1
		and int(bundle.get("samples", 0)) <= int(bundle.get("last_index", -2)) + 4
		and end_ok,
		"samples=%s first=%s last=%s expected_last=%s" % [
			bundle.get("samples", -1), bundle.get("first_index", -1),
			bundle.get("last_index", -1), expected_last])
	_check(label + " dummy is the local player, mirror false",
		String(bundle.get("anchor", "")) == "player" and not bool(bundle.get("mirror", true)),
		"anchor=%s mirror=%s" % [bundle.get("anchor", ""), bundle.get("mirror", "")])
	_check(label + " camera aims at the authored look-at target",
		float(bundle.get("min_look_dot", 0.0)) > 0.99,
		str(bundle.get("min_look_dot", 0.0)))
	_check(label + " dummy fighter is on screen",
		bool(bundle.get("anchor_on_screen", false)),
		str(bundle.get("anchor_on_screen", false)))


func _settle_to_analytic(scene: Node) -> Dictionary:
	## Let the action end and confirm the analytic follow camera comes back.
	var camera: Camera3D = scene.get("fight_camera")
	scene._update_fight_camera(1.0 / 60.0)
	var expected: Vector3 = _analytic_expected(scene)
	return {
		"clip": scene.get("_action_camera_clip"),
		"fov": camera.fov,
		"err": camera.global_position.distance_to(expected),
		"camera": [camera.global_position.x, camera.global_position.y,
			camera.global_position.z],
		"expected": [expected.x, expected.y, expected.z],
	}


func _recovered_return_frame(player: PortFighter) -> int:
	## Frame at which the recovered set returns this action to idle/idle2/idle3.
	## The port ends the attack there (CFighter::_native_recovery_return), and
	## the camera animation ends with the action animation, so the last played
	## camera frame is this frame - 1.  -1 means "no return link": the action
	## runs to its recovered animation_frame_count.
	var action: String = player._current_action_name()
	if action.is_empty():
		return -1
	var links: Array = player.get("_native_links")
	var best: int = -1
	for link: Dictionary in links:
		if str(link.get("from", "")) != action:
			continue
		if str(link.get("to", "")) not in ["idle", "idle2", "idle3"]:
			continue
		var window: Array = Array(link.get("time", []))
		if window.size() < 2:
			continue
		var start_frame: int = int(window[0])
		if best < 0 or start_frame < best:
			best = start_frame
	return best


func _run_attacker(scene: Node, spec: Dictionary) -> Dictionary:
	_reset(scene)
	var player: PortFighter = scene.get("player")
	var started: bool = player.request_attack(String(spec["kind"]))
	var clip: String = String(spec["clip"])
	var frames: int = int(spec["frames"])
	var return_frame: int = _recovered_return_frame(player)
	var expected_last: int = (
		mini(return_frame, frames) if return_frame > 0 else frames) - 1
	scene._update_fight_camera(1.0 / 60.0)
	var bundle: Dictionary = _sample(scene, clip, frames)
	bundle["started"] = started
	bundle["action_kind"] = player.attack_kind
	var attacks: Dictionary = player.get("ATTACKS")
	var attack_row: Dictionary = attacks.get(String(spec["kind"]), {})
	bundle["animation_frame_count"] = int(attack_row.get("animation_frame_count", -1))
	bundle["recovered_return_frame"] = return_frame
	bundle["expected_last"] = expected_last
	bundle["after"] = _settle_to_analytic(scene)
	return bundle


func _run_victim(scene: Node, spec: Dictionary) -> Dictionary:
	_reset(scene)
	var player: PortFighter = scene.get("player")
	var began: bool = player.begin_grabbed(String(spec["kind"]))
	var clip: String = String(spec["clip"])
	var frames: int = int(spec["frames"])
	scene._update_fight_camera(1.0 / 60.0)
	var bundle: Dictionary = _sample(scene, clip, frames)
	bundle["started"] = began
	bundle["state"] = player.state
	bundle["expected_last"] = frames - 1
	bundle["after"] = _settle_to_analytic(scene)
	return bundle


func _run_victim_comp(scene: Node) -> Dictionary:
	_reset(scene)
	var player: PortFighter = scene.get("player")
	var grabbed: bool = player.begin_grabbed(String(VICTIM_COMP["grab_kind"]))
	var began: bool = player.begin_endattack_victim(String(VICTIM_COMP["attacker_kind"]))
	var clip: String = String(VICTIM_COMP["clip"])
	scene._update_fight_camera(1.0 / 60.0)
	var bundle: Dictionary = _sample(scene, clip, int(VICTIM_COMP["frames"]))
	bundle["started"] = grabbed and began
	bundle["state"] = player.state
	bundle["expected_last"] = int(VICTIM_COMP["frames"]) - 1
	bundle["after"] = _settle_to_analytic(scene)
	return bundle


func _check_map_table() -> void:
	## Structural checks on the shipped map + JSONs (no engine state involved).
	var file: FileAccess = FileAccess.open(CAMERA_DIR + "action_camera_map.json",
		FileAccess.READ)
	_check("runtime map exists", file != null, CAMERA_DIR + "action_camera_map.json")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check("runtime map parses", typeof(parsed) == TYPE_DICTIONARY)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var clips: Dictionary = Dictionary(parsed).get("camera_clips", {})
	var expected: Dictionary = {
		"m01_grab_01": 150, "m01_grab_02": 180,
		"m01_end_attack_01": 377, "m01_end_attack_01_forbigguy": 377,
		"m01_end_attack_02": 235,
		"m01_sp_kick_low": 39, "m01_sp_pnch_high": 80, "m01_sp_pnch_low": 178,
		"all_grabbed_01_forset02": 47, "all_grabbed_02_forset02": 98,
		"all_grabbed_01_forset03": 90, "all_grabbed_02_forset03": 78,
		"all_grabbed_01_forset04": 103,
		"all_sp_pnch_low_forset04": 28, "all_sp_kck_low_forset04": 55,
		"all_end_attack_01_forset02": 132, "all_end_attack_02_forset02": 155,
		"all_end_attack_01_forset03": 93, "all_end_attack_02_forset03": 130,
		"m02_grab_01": 47,
	}
	_check("runtime map covers the local-player action cameras",
		clips.size() >= expected.size(),
		"%s entries, expected at least %s" % [clips.size(), expected.size()])
	for clip: String in expected:
		if not clips.has(clip):
			_check("map has " + clip, false)
			continue
		var row: Dictionary = clips[clip]
		_check("map " + clip + " frame count", int(row.get("frames", -1)) == int(expected[clip]),
			"%s vs %s" % [row.get("frames", -1), expected[clip]])
		var path: String = CAMERA_DIR + String(row.get("file", ""))
		_check("map " + clip + " JSON exists", FileAccess.file_exists(path), path)
		var ref = _reference(clip)
		_check("map " + clip + " JSON frame count matches",
			ref != null and ref.frame_count() == int(expected[clip]),
			str(ref.frame_count() if ref != null else -1))
	# Every shipped JSON must be in the action map or in one of the cinematic
	# maps (intro/victory/defeat).  The remaining-camera work ships all decoded
	# cinematic cameras next to the action cameras, so treat those as owned too.
	var cinematic: Dictionary = {}
	for map_name: String in ["intro_camera_map", "victory_camera_map",
			"defeat_camera_map"]:
		var map_file: FileAccess = FileAccess.open(
			CAMERA_DIR + map_name + ".json", FileAccess.READ)
		if map_file == null:
			continue
		var parsed_map: Variant = JSON.parse_string(map_file.get_as_text())
		if typeof(parsed_map) == TYPE_DICTIONARY:
			var map_clips: Variant = Dictionary(parsed_map).get("camera_clips", {})
			if typeof(map_clips) == TYPE_DICTIONARY:
				for key: Variant in Dictionary(map_clips):
					cinematic[String(key)] = true
	var catalog_clips: Dictionary = {}
	var catalog_file: FileAccess = FileAccess.open(
		CAMERA_DIR + "camera_catalog.json", FileAccess.READ)
	if catalog_file != null:
		var parsed_catalog: Variant = JSON.parse_string(catalog_file.get_as_text())
		if typeof(parsed_catalog) == TYPE_DICTIONARY:
			var catalog_rows: Variant = Dictionary(parsed_catalog).get("camera_clips", {})
			if typeof(catalog_rows) == TYPE_DICTIONARY:
				for key: Variant in Dictionary(catalog_rows):
					catalog_clips[String(key)] = true
	var dir: DirAccess = DirAccess.open(CAMERA_DIR)
	var orphans: Array[String] = []
	if dir != null:
		for name: String in dir.get_files():
			if not name.ends_with(".json"):
				continue
			var clip: String = name.trim_suffix(".json")
			if clip == "action_camera_map" or clip == "camera_catalog" \
					or clip.ends_with("_camera_map") or cinematic.has(clip) \
					or catalog_clips.has(clip):
				continue
			if not clips.has(clip):
				orphans.append(clip)
	_check("no orphan camera JSON in data/camera_anm", orphans.is_empty(), str(orphans))


func _check_mirror_math() -> void:
	## CameraAnmPlayer dummy/mirror placement: mirroring the dummy swaps origin
	## and flips the source lateral offset, and apply_to() lands on that pose.
	var ref = _reference("m01_grab_01")
	if ref == null:
		_check("mirror reference json", false)
		return
	var a := Vector3(-100.0, 0.0, 0.0)
	var b := Vector3(-60.0, 0.0, 0.0)
	var left: Dictionary = ref.place_world(20, a, b, false)
	var right: Dictionary = ref.place_world(20, a, b, true)
	var dl: Vector3 = (left["camera_source"] as Vector3) - a
	var dr: Vector3 = (right["camera_source"] as Vector3) - b
	_check("mirror swaps the dummy origin", (right["camera_source"] as Vector3).is_equal_approx(
		b + Vector3(-dl.x, -dl.y, dl.z)))
	_check("mirror flips the lateral side",
		signf(left["camera_world"].x) != signf(right["camera_world"].x)
		and absf(dl.x + dr.x) < 0.001)
	var camera := Camera3D.new()
	root.add_child(camera)
	ref.apply_to(camera, 20, a, b, true)
	var err: float = camera.global_position.distance_to(right["camera_world"])
	_check("apply_to honours mirror=true", err < 0.002, str(err))
	camera.queue_free()


func _check_dummy_slot(scene: Node) -> void:
	## The authored cut belongs to the local player's animation: moving the
	## player to the right slot must mirror the camera to the other side.
	_reset(scene, false)
	var player: PortFighter = scene.get("player")
	player.request_attack("grab1")
	scene._update_fight_camera(1.0 / 60.0)
	var left_x: float = (scene.get("fight_camera") as Camera3D).global_position.x
	var left_anchor: bool = scene.get("_action_camera_anchor") == player
	_reset(scene, true)
	player.request_attack("grab1")
	scene._update_fight_camera(1.0 / 60.0)
	var right_x: float = (scene.get("fight_camera") as Camera3D).global_position.x
	var right_anchor: bool = scene.get("_action_camera_anchor") == player
	_check("grab1 camera dummy is the player in both slots",
		left_anchor and right_anchor)
	_check("grab1 camera side follows the player slot",
		signf(left_x) != signf(right_x) and absf(absf(left_x) - absf(right_x)) < 0.05,
		"left_x=%s right_x=%s" % [left_x, right_x])
	_results["dummy_slot"] = {"left_x": left_x, "right_x": right_x}


func _check_missing_json(player_glb: String, opponent_glb: String,
		attack_config: String, text_root: String) -> void:
	var scene: Node = _new_scene(player_glb, opponent_glb, attack_config, text_root)
	if not await _wait_candidates(scene):
		_check("missing-json candidates load", false)
		return
	await process_frame
	_freeze(scene)
	scene.set("_camera_anm_dir", MISSING_DIR)
	_reset(scene)
	var player: PortFighter = scene.get("player")
	player.request_attack("grab1")
	scene._update_fight_camera(1.0 / 60.0)
	var analytic: Vector3 = _analytic_expected(scene)
	var camera: Camera3D = scene.get("fight_camera")
	_check("missing JSON: no authored clip", String(scene.get("_action_camera_clip")).is_empty(),
		str(scene.get("_action_camera_clip")))
	_check("missing JSON: analytic fov 75", absf(camera.fov - 75.0) < 0.001, str(camera.fov))
	_check("missing JSON: analytic follow camera",
		camera.global_position.distance_to(analytic) < 0.002,
		"%s vs %s" % [camera.global_position, analytic])
	_check("missing JSON is recorded once",
		(scene.get("_action_camera_missing_json") as Array).has("m01_grab_01"),
		str(scene.get("_action_camera_missing_json")))
	_results["fallback_missing_json"] = {
		"clip": scene.get("_action_camera_clip"), "fov": camera.fov,
		"err": camera.global_position.distance_to(analytic),
		"missing": scene.get("_action_camera_missing_json"),
	}
	scene.queue_free()
	await process_frame


func _check_missing_map(player_glb: String, opponent_glb: String,
		attack_config: String, text_root: String) -> void:
	var scene: Node = _new_scene(player_glb, opponent_glb, attack_config, text_root)
	if not await _wait_candidates(scene):
		_check("missing-map candidates load", false)
		return
	await process_frame
	_freeze(scene)
	scene.set("_action_camera_map_path", MISSING_DIR + "action_camera_map.json")
	scene.set("_action_camera_map", {})
	scene.set("_action_camera_map_loaded", false)
	_reset(scene)
	var player: PortFighter = scene.get("player")
	player.request_attack("grab1")
	scene._update_fight_camera(1.0 / 60.0)
	var analytic: Vector3 = _analytic_expected(scene)
	var camera: Camera3D = scene.get("fight_camera")
	_check("missing map: no authored clip",
		String(scene.get("_action_camera_clip")).is_empty(),
		str(scene.get("_action_camera_clip")))
	_check("missing map: analytic follow camera",
		camera.global_position.distance_to(analytic) < 0.002
		and absf(camera.fov - 75.0) < 0.001,
		"fov=%s err=%s" % [camera.fov, camera.global_position.distance_to(analytic)])
	_results["fallback_missing_map"] = {
		"clip": scene.get("_action_camera_clip"), "fov": camera.fov,
		"err": camera.global_position.distance_to(analytic),
	}
	scene.queue_free()
	await process_frame


func _check_no_camera_action(scene: Node) -> void:
	## An action whose animation has no camera (special_kick_low_miss uses
	## m01_sp_kick_low_fail: no decoded camera) must keep the analytic camera.
	_reset(scene)
	var player: PortFighter = scene.get("player")
	player.request_attack("special_kick_low_miss")
	scene._update_fight_camera(1.0 / 60.0)
	var analytic: Vector3 = _analytic_expected(scene)
	var camera: Camera3D = scene.get("fight_camera")
	_check("action without a camera: no authored clip",
		String(scene.get("_action_camera_clip")).is_empty(),
		str(scene.get("_action_camera_clip")))
	_check("action without a camera: analytic follow camera",
		camera.global_position.distance_to(analytic) < 0.002
		and absf(camera.fov - 75.0) < 0.001,
		"fov=%s err=%s" % [camera.fov, camera.global_position.distance_to(analytic)])
	_results["fallback_no_camera_action"] = {
		"clip": player.current_camera_animation(),
		"action_camera": scene.get("_action_camera_clip"),
		"fov": camera.fov,
	}


func _check_large_opponent(player_glb: String, opponent_glb: String,
		attack_config: String, text_root: String) -> void:
	## Animations.versions can replace a base clip with the large-opponent
	## version.  The camera belongs to the played clip, so:
	##   * endattack1's recovered variant has a decoded variant camera -> it must
	##     play (m01_end_attack_01_forbigguy_camera);
	##   * grab1's recovered variant has no decoded camera -> analytic fall-back.
	var scene: Node = _new_scene(player_glb, opponent_glb, attack_config, text_root)
	if not await _wait_candidates(scene):
		_check("large-opponent candidates load", false)
		return
	await process_frame
	_freeze(scene)
	var player: PortFighter = scene.get("player")
	var computer: PortFighter = scene.get("computer")
	_check("large opponent skeleton class",
		computer.skeleton_class == "large", computer.skeleton_class)
	_reset(scene)
	player.request_attack("endattack1")
	# The real fighter applies the resolved size version in _animate_visuals,
	# i.e. inside _physics_process; drive one update so the played clip is the
	# recovered variant before the camera is sampled.
	player._physics_process(1.0 / 60.0)
	scene._update_fight_camera(1.0 / 60.0)
	var played: String = player.candidate_animation_clip
	var camera_clip: String = String(scene.get("_action_camera_clip"))
	_check("large opponent endattack1 plays the recovered variant clip",
		played == "m01_end_attack_01_forbigguy", played)
	_check("large opponent endattack1 plays the decoded variant camera",
		camera_clip == "m01_end_attack_01_forbigguy", camera_clip)
	var ref = _reference("m01_end_attack_01_forbigguy")
	var max_err: float = 0.0
	var samples: int = 0
	if ref != null:
		for _i: int in range(60):
			scene._update_fight_camera(1.0 / 60.0)
			if String(scene.get("_action_camera_clip")) != camera_clip:
				break
			var index: int = int(scene.get("_action_camera_frame"))
			var expected: Dictionary = ref.place_world(
				index, scene.get("_action_camera_a"), scene.get("_action_camera_b"),
				scene.get("_action_camera_mirror"))
			var camera: Camera3D = scene.get("fight_camera")
			max_err = maxf(max_err,
				camera.global_position.distance_to(expected["camera_world"]))
			samples += 1
			player._physics_process(1.0 / 30.0)
			computer._physics_process(1.0 / 30.0)
	_check("large opponent variant camera matches the decoded JSON",
		samples > 0 and max_err < 0.002, "samples=%s max_err=%s" % [samples, max_err])
	_reset(scene)
	player.request_attack("grab1")
	player._physics_process(1.0 / 60.0)
	scene._update_fight_camera(1.0 / 60.0)
	var grab_played: String = player.candidate_animation_clip
	var grab_camera: String = String(scene.get("_action_camera_clip"))
	var analytic: Vector3 = _analytic_expected(scene)
	var live: Camera3D = scene.get("fight_camera")
	_check("large opponent grab1 plays the recovered variant clip",
		grab_played == "m01_grab_01_forbigguy", grab_played)
	_check("large opponent grab1 variant has no decoded camera -> analytic",
		grab_camera.is_empty() and absf(live.fov - 75.0) < 0.001
		and live.global_position.distance_to(analytic) < 0.002,
		"cam=%s fov=%s err=%s" % [grab_camera, live.fov,
			live.global_position.distance_to(analytic)])
	_results["large_opponent"] = {
		"skeleton": computer.skeleton_class,
		"endattack1_played": played,
		"endattack1_camera": camera_clip,
		"endattack1_samples": samples,
		"endattack1_max_err": max_err,
		"grab1_played": grab_played,
		"grab1_camera": grab_camera,
		"grab1_fov": live.fov,
	}
	scene.queue_free()
	await process_frame


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 4:
		push_error("Expected <player.glb> <opponent.glb> <opponent_attack_config> <gametext_root>")
		quit(2)
		return
	var player_glb: String = args[0]
	var opponent_glb: String = args[1]
	var attack_config: String = args[2]
	var text_root: String = args[3]

	_check_map_table()
	_check_mirror_math()

	var scene: Node = _new_scene(player_glb, opponent_glb, attack_config, text_root)
	if not await _wait_candidates(scene):
		push_error("action camera candidates did not load")
		quit(1)
		return
	await process_frame
	_freeze(scene)
	_results["assets"] = {
		"player_loaded": (scene.get("player") as PortFighter).candidate_loaded,
		"opponent_loaded": (scene.get("computer") as PortFighter).candidate_loaded,
		"player_skeleton": (scene.get("player") as PortFighter).skeleton_class,
		"opponent_skeleton": (scene.get("computer") as PortFighter).skeleton_class,
		"opponent_attack_config": (scene.get("computer") as PortFighter).attack_config_path,
		"match_state": scene.get("match_state"),
	}
	for spec: Dictionary in ATTACKER_CASES:
		var bundle: Dictionary = _run_attacker(scene, spec)
		var label: String = String(spec["kind"])
		_check("attacker " + label + " starts", bool(bundle.get("started", false)))
		_check("attacker " + label + " camera frames equal the recovered action frames",
			int(bundle.get("animation_frame_count", -1)) == int(spec["frames"]),
			"%s vs %s" % [bundle.get("animation_frame_count", -1), spec["frames"]])
		_check_sampled("attacker " + label, spec, bundle)
		var after: Dictionary = bundle["after"]
		_check("attacker " + label + " hands the view back to the analytic camera",
			String(after["clip"]).is_empty() and absf(float(after["fov"]) - 75.0) < 0.001
			and float(after["err"]) < 0.002,
			"clip=%s fov=%s err=%s" % [after["clip"], after["fov"], after["err"]])
		_results["attacker_" + label] = bundle
	for spec: Dictionary in VICTIM_CASES:
		var bundle: Dictionary = _run_victim(scene, spec)
		var label: String = String(spec["state"])
		_check("victim " + label + " starts", bool(bundle.get("started", false)))
		_check_sampled("victim " + label, spec, bundle)
		_results["victim_" + label] = bundle
	var comp_bundle: Dictionary = _run_victim_comp(scene)
	_check("victim endattackcomp1 starts", bool(comp_bundle.get("started", false)))
	_check_sampled("victim endattackcomp1", VICTIM_COMP, comp_bundle)
	_results["victim_endattackcomp1"] = comp_bundle

	# The two long end-attack clips contain real one-frame camera cuts: prove
	# the playback is per frame (a large one-frame step) and not interpolated.
	for clip: String in ["m01_end_attack_01", "m01_end_attack_02"]:
		var key: String = "attacker_" + ("endattack1" if clip == "m01_end_attack_01"
			else "endattack2")
		var cut: float = float((_results[key] as Dictionary).get("max_camera_step", 0.0))
		_check(clip + " keeps its one-frame cuts (per-frame playback)",
			cut > 0.5, str(cut))

	_check_dummy_slot(scene)

	# No-camera action + a clean analytic view at the end of the scene.
	_check_no_camera_action(scene)
	scene.queue_free()
	await process_frame

	await _check_missing_json(player_glb, opponent_glb, attack_config, text_root)
	await _check_missing_map(player_glb, opponent_glb, attack_config, text_root)
	if args.size() >= 6:
		await _check_large_opponent(player_glb, args[4], args[5], text_root)

	_results["failures"] = _failures
	print("ACTION_CAMERA_VALIDATION=" + JSON.stringify(_results))
	quit(0 if _failures.is_empty() else 1)

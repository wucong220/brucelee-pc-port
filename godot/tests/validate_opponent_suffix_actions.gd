extends SceneTree
## Headless proof on the REAL res://scenes/main.tscn that the recovered
## opponent-suffix attack variants of brucelee.set are implemented only where
## native set/link data and existing candidate clips prove them, that the player
## can enter them through their native links, that the opponent action cameras
## arm only for those proven animations, and that everything else fails closed.
##
## usage: --headless --path <proj> --script res://tests/validate_opponent_suffix_actions.gd -- \
##   <player.glb> <opponent.glb> <opponent_attack_config> <gametext_root> <suffix>

const DATA_PATH := "res://data/opponent_suffix_variants.json"
const CAMERA_DIR := "res://data/camera_anm/"
const ANALYTIC_FOV := 75.0
const KNOWN_SUFFIXES := ["brick", "smallboy", "johnson", "chief", "loming",
	"ken", "master", "sinfu", "shenlo"]
const EXPECTED_ATTACK_KINDS := 82
const EXPECTED_CAMERA_MAP := 45
const EXPECTED_ROWS := 101

const SCENARIOS := {
	"ken": {
		"stepback": ["specialpunchhigh ken", ""],
		"group": ["endattack ken", "m02_end_attack_01"],
		"chain": ["grab1 ken", "m02_grab_01"],
		"chain_start": "grab1miss ken",
		"chain_input": "up",
		"victim": "all_grabbed_01_forset02",
	},
	"brick": {
		"stepback": ["specialpunchhigh brick", ""],
		"group": ["endattack brick", "m03_end_attack_01"],
		"chain": ["grab1 brick", "m03_grab_01"],
		"chain_start": "grab1miss brick",
		"chain_input": "up",
		"victim": "all_grabbed_01_forset03",
	},
	"sinfu": {
		"group": ["specialpunchhighhit sinfu", "m04_sp_pnch_high"],
		"group_entry": "specialpunchhighmiss sinfu",
		"chain": ["specialpunchhighhit sinfu", "m04_sp_pnch_high"],
		"chain_start": "specialpunchhighmiss sinfu",
		"chain_input": "",
		"victim": "all_grabbed_01_forset04",
	},
}

var _failures: Array[String] = []
var _checks: int = 0
var _results: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("PASS ", label, " ", detail)
	else:
		_failures.append(label + " " + detail)
		push_error("FAIL " + label + " " + detail)
		print("FAIL ", label, " ", detail)


func _new_scene(player_glb: String, opponent_glb: String, config: String,
		text_root: String) -> Node:
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")
	OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
	OS.set_environment("BRUCELEE_ROUND_TIME", "60")
	OS.set_environment("BRUCELEE_PLAYER_GLB", player_glb)
	OS.set_environment("BRUCELEE_OPPONENT_GLB", opponent_glb)
	OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", config)
	OS.set_environment("BRUCELEE_GAME_TEXT_ROOT", text_root)
	OS.set_environment("BRUCELEE_GAME_TEXT_FLIP", "1")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	return scene


func _wait_candidates(scene: Node) -> bool:
	var player = scene.get("player")
	var computer = scene.get("computer")
	for _i: int in range(1800):
		if player.candidate_loaded and computer.candidate_loaded:
			return true
		await physics_frame
	return player.candidate_loaded and computer.candidate_loaded


func _freeze(scene: Node) -> void:
	scene.set_process(false)
	scene.set_physics_process(false)
	var player = scene.get("player")
	var computer = scene.get("computer")
	player.set_physics_process(false)
	computer.set_physics_process(false)


func _reset(scene: Node) -> void:
	var player = scene.get("player")
	var computer = scene.get("computer")
	scene._action_camera_end()
	player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
	computer.reset_fighter(Vector3(-1.0, 1.20, 0.0))
	player.facing = 1.0
	computer.facing = -1.0
	player.held_directions = {}
	player.set_key_status({})
	player.rage = 100.0
	player.opponent = computer
	computer.opponent = player
	scene._restart_fight_camera()
	scene._update_fight_camera(1.0 / 60.0)


func _tick(scene: Node, frames: int) -> void:
	for _i: int in range(frames):
		scene._update_fight_camera(1.0 / 60.0)


func _camera_state(scene: Node) -> Dictionary:
	return {
		"clip": String(scene.get("_action_camera_clip")),
		"camera": String(scene.get("_action_camera_camera")),
		"anchor_player": scene.get("_action_camera_anchor") == scene.get("player"),
		"mirror": bool(scene.get("_action_camera_mirror")),
		"fov": (scene.get("fight_camera") as Camera3D).fov,
	}


func _check_camera_return(scene: Node, player, label: String) -> void:
	var returned: bool = false
	for _i: int in range(400):
		player._advance_timed_states(1.0 / 30.0)
		scene._update_fight_camera(1.0 / 60.0)
		if String(scene.get("_action_camera_clip")).is_empty():
			returned = true
			break
	_check(label + " camera hands back to the analytic camera",
		returned and absf((scene.get("fight_camera") as Camera3D).fov - ANALYTIC_FOV) < 0.001,
		"returned=%s fov=%s" % [returned, (scene.get("fight_camera") as Camera3D).fov])


func _set_movement(player, direction: String) -> void:
	player.state = "idle"
	player.state_time = 0.0
	player.attack_kind = ""
	player.move_axis = Vector2.ZERO
	player.held_directions = {direction: true}


func _set_attack_frame(player, kind: String, frame: int) -> void:
	player.attack_kind = kind
	player.state = "active"
	player.state_time = 0.0
	player._attack_clock_active = true
	player._attack_clock_start_frame = frame
	player._attack_clock_ms = 0.0
	player._attack_connected = false
	player._multi_impact_applied.clear()


func _advance_until(scene: Node, player, target_kind: String, max_frames: int = 240) -> bool:
	for _i: int in range(max_frames):
		player._advance_timed_states(1.0 / 30.0)
		scene._update_fight_camera(1.0 / 60.0)
		player._try_follow_links()
		if player.attack_kind == target_kind:
			return true
	return player.attack_kind == target_kind


func _row_proven(rows: Array, kind: String) -> bool:
	for row_value: Variant in rows:
		var row: Dictionary = Dictionary(row_value)
		if String(row.get("name", "")) == kind:
			return bool(row.get("entry_proven", false))
	return false


func _check_assets(scene: Node, suffix: String, config: String) -> void:
	var player = scene.get("player")
	var computer = scene.get("computer")
	_check("real main.tscn built the player", player != null and player.is_player, "")
	_check("real main.tscn built the computer", computer != null and not computer.is_player, "")
	_check("player is fighter0 and loads brucelee.set",
		player.attack_config_path.ends_with("fighting_set_low_attacks.json"),
		str(player.attack_config_path))
	_check("computer loads the requested opponent set",
		computer.attack_config_path == config,
		"computer=%s expected=%s" % [computer.attack_config_path, config])
	_check("opponent token resolves to the requested suffix",
		player._opponent_suffix_token() == suffix,
		"token=%s" % player._opponent_suffix_token())


func _check_table_and_invariants(scene: Node, suffix: String) -> void:
	var player = scene.get("player")
	var table: Dictionary = {}
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	_check("recovered variant table exists", file != null, DATA_PATH)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			table = Dictionary(parsed)
	var rows: Array = Array(table.get("variants", []))
	_check("recovered table has 101 suffix rows", rows.size() == EXPECTED_ROWS, str(rows.size()))
	var variant_map: Dictionary = Dictionary(player.get("_opponent_suffix_variants"))
	_check("player exposes 82 proven attack kinds",
		variant_map.size() == EXPECTED_ATTACK_KINDS, str(variant_map.size()))
	var bad_kind: Array = []
	for kind: Variant in variant_map.keys():
		var row: Dictionary = Dictionary(variant_map[kind])
		if not KNOWN_SUFFIXES.has(String(row.get("variant_suffix", ""))):
			bad_kind.append(kind)
		if String(row.get("variant_family", "")) == "victim":
			bad_kind.append(kind)
		if not _row_proven(rows, String(kind)):
			bad_kind.append(kind)
	_check("every loaded kind is a proven, non-victim native variant",
		bad_kind.is_empty(), str(bad_kind))
	var foreign_started: Array = []
	var foreign_supported: Array = []
	for row_value: Variant in rows:
		var row: Dictionary = Dictionary(row_value)
		if String(row.get("family", "")) == "victim":
			continue
		if String(row.get("suffix", "")) == suffix:
			continue
		var kind: String = String(row.get("name", ""))
		if player.supports_attack(kind):
			foreign_supported.append(kind)
		if player.request_attack(kind):
			foreign_started.append(kind)
	_check("no variant of a different opponent is supported",
		foreign_supported.is_empty(), str(foreign_supported))
	_check("no variant of a different opponent can start",
		foreign_started.is_empty(), str(foreign_started))
	var wrong: Array = []
	for kind: Variant in variant_map.keys():
		if not player.supports_attack(String(kind)):
			continue
		var row: Dictionary = Dictionary(player._opponent_suffix_variants[kind])
		if String(row.get("variant_suffix", "")) != suffix:
			wrong.append(kind)
		elif not _row_proven(rows, String(kind)):
			wrong.append(kind)
	_check("supported variants are exactly this opponent's proven rows",
		wrong.is_empty(), str(wrong))
	_check("action without a native entry link is not an attack kind",
		not player.ATTACKS.has("specialpunchhighimpact sinfu"), "")


func _check_camera_map(scene: Node) -> void:
	scene._action_camera_load_map()
	var map: Dictionary = Dictionary(scene.get("_action_camera_map"))
	_check("action camera map has the 20 base + 25 proven entries",
		map.size() == EXPECTED_CAMERA_MAP, str(map.size()))
	var bad: Array = []
	for key: Variant in map.keys():
		var name: String = String(key)
		if not name.begins_with("variant_action:"):
			continue
		var kind: String = name.substr("variant_action:".length())
		if not scene.get("player").ATTACKS.has(kind):
			bad.append(name)
			continue
		var row: Dictionary = Dictionary(scene.get("player").ATTACKS[kind])
		var camera: String = String(Dictionary(map[key]).get("camera", ""))
		if camera.is_empty() or camera != String(row.get("variant_camera", "")):
			bad.append(name)
		if not FileAccess.file_exists(CAMERA_DIR + camera + ".json"):
			bad.append(name + ":json")
	_check("every variant_action camera row matches a proven action camera",
		bad.is_empty(), str(bad))
	var leaked: Array = []
	for kind: Variant in scene.get("player")._opponent_suffix_variants.keys():
		var row: Dictionary = Dictionary(scene.get("player")._opponent_suffix_variants[kind])
		if String(row.get("variant_camera", "")).is_empty() \
				and map.has("variant_action:" + String(kind)):
			leaked.append(kind)
	_check("no camera is invented for a camera-less variant", leaked.is_empty(), str(leaked))


func _check_stepback_scenario(scene: Node, kind: String, camera: String) -> void:
	_reset(scene)
	var player = scene.get("player")
	_set_movement(player, "left")  # native left = stepback
	player.set_key_status({"right": true})  # recovered keystatus of the link
	player.rage = 100.0
	_check("stepback is the current native action", player._current_action_name() == "stepback",
		player._current_action_name())
	var started: bool = player.record_standing_combo_press("a")
	_check("native stepback+a link starts " + kind,
		started and player.attack_kind == kind, str(player.attack_kind))
	player._animate_candidate()
	var status: Dictionary = player.variant_clip_status(kind)
	_check(kind + " plays an existing candidate clip",
		bool(status.get("ok", false)) and player._candidate_clip_paths.has(kind)
		and player.candidate_animation_clip == String(status.get("clip", "")),
		"%s / %s" % [status.get("clip", ""), player.candidate_animation_clip])
	_tick(scene, 1)
	var cam: Dictionary = _camera_state(scene)
	if camera.is_empty():
		_check(kind + " has no recovered camera; no authored camera arms",
			String(cam["clip"]).is_empty()
			and absf(float(cam["fov"]) - ANALYTIC_FOV) < 0.001,
			"%s fov=%s" % [cam["clip"], cam["fov"]])
	else:
		_check(kind + " arms its recovered camera " + camera,
			cam["clip"] == "variant_action:" + kind and cam["camera"] == camera,
			"%s/%s" % [cam["clip"], cam["camera"]])
		_check(kind + " camera uses the player dummy, mirror false",
			bool(cam["anchor_player"]) and not bool(cam["mirror"]),
			"anchor=%s mirror=%s" % [cam["anchor_player"], cam["mirror"]])
		_check_camera_return(scene, player, kind)
	_results["stepback_" + kind] = {"clip": player.candidate_animation_clip}


func _check_group_scenario(scene: Node, kind: String, camera: String,
		start_kind: String = "") -> void:
	_reset(scene)
	var player = scene.get("player")
	var computer = scene.get("computer")
	computer.state = "stun" if start_kind.is_empty() else "idle"
	computer.state_time = 0.0
	computer.global_position = Vector3(-1.25, 1.20, 0.0)
	_set_attack_frame(player, "high_punch2", 35 if start_kind.is_empty() else 20)
	player.set_key_status({"right": true})
	player.rage = 100.0
	var started: bool = player.record_standing_combo_press("a")
	if not start_kind.is_empty():
		_check("recovered group link starts " + start_kind,
			started and player.attack_kind == start_kind, str(player.attack_kind))
		var converted: bool = _advance_until(scene, player, kind)
		_check("native follow-up link reaches " + kind,
			converted and player.attack_kind == kind, str(player.attack_kind))
	else:
		_check("recovered group link starts " + kind,
			started and player.attack_kind == kind, str(player.attack_kind))
	player._animate_candidate()
	var status: Dictionary = player.variant_clip_status(kind)
	_check("clip for " + kind + " is an existing candidate animation",
		bool(status.get("ok", false)) and player._candidate_clip_paths.has(kind)
		and player.candidate_animation_clip == String(status.get("clip", "")),
		"%s / %s" % [status.get("clip", ""), player.candidate_animation_clip])
	_tick(scene, 1)
	var cam: Dictionary = _camera_state(scene)
	_check(kind + " arms its recovered camera " + camera,
		cam["clip"] == "variant_action:" + kind and cam["camera"] == camera,
		"%s/%s" % [cam["clip"], cam["camera"]])
	_check(kind + " camera uses the player dummy, mirror false",
		bool(cam["anchor_player"]) and not bool(cam["mirror"]),
		"anchor=%s mirror=%s" % [cam["anchor_player"], cam["mirror"]])
	_results["group_" + kind] = {
		"clip": player.candidate_animation_clip, "camera": cam["camera"],
	}
	_check_camera_return(scene, player, kind)


func _check_chain_scenario(scene: Node, start_kind: String, kind: String,
		camera: String, direction: String) -> void:
	_reset(scene)
	var player = scene.get("player")
	var computer = scene.get("computer")
	if direction.is_empty():
		_set_attack_frame(player, "high_punch2", 20)
		player.set_key_status({"right": true})
	else:
		_set_movement(player, direction)
	player.rage = 100.0
	computer.state = "idle"
	computer.state_time = 0.0
	computer.global_position = Vector3(-1.25, 1.20, 0.0)
	var started: bool = player.record_standing_combo_press("a")
	_check("native link starts " + start_kind,
		started and player.attack_kind == start_kind, str(player.attack_kind))
	var converted: bool = _advance_until(scene, player, kind)
	_check("automatic hit link converts " + start_kind + " -> " + kind,
		converted and player.attack_kind == kind, str(player.attack_kind))
	player._animate_candidate()
	var status: Dictionary = player.variant_clip_status(kind)
	_check("clip for " + kind + " is an existing candidate animation",
		bool(status.get("ok", false)) and player._candidate_clip_paths.has(kind)
		and player.candidate_animation_clip == String(status.get("clip", "")),
		"%s / %s" % [status.get("clip", ""), player.candidate_animation_clip])
	_tick(scene, 1)
	var cam: Dictionary = _camera_state(scene)
	_check(kind + " arms its recovered camera " + camera,
		cam["clip"] == "variant_action:" + kind and cam["camera"] == camera,
		"%s/%s" % [cam["clip"], cam["camera"]])
	_check(kind + " camera uses the player dummy, mirror false",
		bool(cam["anchor_player"]) and not bool(cam["mirror"]),
		"anchor=%s mirror=%s" % [cam["anchor_player"], cam["mirror"]])
	_results["chain_" + kind] = {
		"clip": player.candidate_animation_clip, "camera": cam["camera"],
	}
	_check_camera_return(scene, player, kind)


func _check_victim_scenario(scene: Node, suffix: String, victim_clip: String) -> void:
	_reset(scene)
	var player = scene.get("player")
	var started: bool = player.begin_grabbed("grab1")
	_check("player victim grab selects the per-attacker clip",
		started and player.state == "grabbed1", str(player.state))
	var selected: String = String(player._victim_selected_animation.get("grabbed1", ""))
	_check("victim clip is the recovered " + suffix + " variant",
		selected == victim_clip, selected)
	_tick(scene, 1)
	var cam: Dictionary = _camera_state(scene)
	_check("victim animation arms its recovered camera " + victim_clip,
		cam["clip"] == victim_clip and cam["camera"] == victim_clip,
		"%s/%s" % [cam["clip"], cam["camera"]])
	_results["victim_" + suffix] = {"clip": cam["clip"]}


func _check_fail_closed(scene: Node, suffix: String, scenario: Dictionary) -> void:
	var player = scene.get("player")
	var computer = scene.get("computer")
	var gate_kind: String = ""
	var gate_direction: String = ""
	if scenario.has("stepback"):
		gate_kind = String(scenario["stepback"][0])
		gate_direction = "left"
	elif scenario.has("chain_start"):
		gate_kind = String(scenario["chain_start"])
		gate_direction = "up"
	if not gate_kind.is_empty():
		_reset(scene)
		if gate_direction == "left":
			_set_movement(player, "left")
			player.set_key_status({"right": true})
		else:
			_set_movement(player, gate_direction)
		player.rage = 0.0
		player.record_standing_combo_press("a")
		_check("rage gate refuses " + gate_kind + " below the recovered threshold",
			player.attack_kind != gate_kind, str(player.attack_kind))
	var group_kind: String = ""
	if scenario.has("group"):
		group_kind = String(scenario["group"][0])
	if not group_kind.is_empty():
		_reset(scene)
		computer.state = "idle"  # pose stand, not stun
		_set_attack_frame(player, "high_punch2", 35)
		player.set_key_status({"right": true})
		player.rage = 100.0
		player.record_standing_combo_press("a")
		_check("oppposestun gate refuses " + group_kind + " against a standing opponent",
			player.attack_kind != group_kind, str(player.attack_kind))
	var probe_kind: String = String(scenario.get("group", scenario.get("chain", ["", ""]))[0])
	if not probe_kind.is_empty():
		_reset(scene)
		var saved_anim = computer._candidate_animation
		computer._candidate_animation = null
		player._variant_clip_status.erase(probe_kind)
		player._candidate_clip_paths.erase(probe_kind)
		var refused: bool = not player.request_attack(probe_kind)
		var status: Dictionary = player.variant_clip_status(probe_kind)
		computer._candidate_animation = saved_anim
		_check("missing candidate clip refuses " + probe_kind,
			refused and not bool(status.get("ok", false)), str(status.get("reason", "")))
		_check("refused variant reports no clip source",
			String(status.get("source", "")) == "", str(status.get("source", "")))


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 5:
		push_error("Expected <player.glb> <opponent.glb> <config> <gametext_root> <suffix>")
		quit(2)
		return
	var suffix: String = args[4]
	if not SCENARIOS.has(suffix):
		push_error("Unknown suffix " + suffix)
		quit(2)
		return
	var scenario: Dictionary = SCENARIOS[suffix]
	var scene: Node = _new_scene(args[0], args[1], args[2], args[3])
	if not await _wait_candidates(scene):
		push_error("candidates did not load")
		quit(1)
		return
	await process_frame
	_freeze(scene)
	_check_assets(scene, suffix, args[2])
	_check_table_and_invariants(scene, suffix)
	_check_camera_map(scene)
	if scenario.has("stepback"):
		_check_stepback_scenario(scene, String(scenario["stepback"][0]),
			String(scenario["stepback"][1]))
	if scenario.has("group"):
		_check_group_scenario(scene, String(scenario["group"][0]),
			String(scenario["group"][1]), String(scenario.get("group_entry", "")))
	if scenario.has("chain_start"):
		_check_chain_scenario(scene, String(scenario["chain_start"]),
			String(scenario["chain"][0]), String(scenario["chain"][1]),
			String(scenario.get("chain_input", "")))
	if scenario.has("victim"):
		_check_victim_scenario(scene, suffix, String(scenario["victim"]))
	_check_fail_closed(scene, suffix, scenario)
	_results["checks"] = _checks
	_results["failures"] = _failures
	_results["suffix"] = suffix
	print("OPPONENT_SUFFIX_ACTIONS_VALIDATION=" + JSON.stringify(_results))
	quit(0 if _failures.is_empty() else 1)

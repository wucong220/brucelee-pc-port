extends SceneTree
## Before/after probe: does the project expose the recovered opponent-suffix
## attack kinds and can the local player enter them on the REAL main.tscn?
## Safe on a pristine project: every field is reported false instead of erroring.
##
## usage: --headless --path <proj> --script res://tests/probe_variants.gd -- \
##   <player.glb> <opponent.glb> <opponent_attack_config> <gametext_root> \
##   <suffix-token> <native action name|...>

var _kinds: Array[String] = ["endattack ken", "grab1 brick", "specialpunchhighhit sinfu"]


func _initialize() -> void:
	call_deferred("_run")


func _load_table() -> Array:
	var path: String = "res://data/opponent_suffix_variants.json"
	if not FileAccess.file_exists(path):
		return []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return []
	var rows: Variant = Dictionary(parsed).get("variants", [])
	return Array(rows) if rows is Array else []


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 6:
		_kinds.clear()
		for token: String in args[5].split("|", false):
			_kinds.append(token)
	var player_glb: String = args[0] if args.size() > 0 else ""
	var opponent_glb: String = args[1] if args.size() > 1 else ""
	var config: String = args[2] if args.size() > 2 else ""
	var text_root: String = args[3] if args.size() > 3 else ""
	var suffix: String = args[4] if args.size() > 4 else ""

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
	var player = scene.get("player")
	var computer = scene.get("computer")
	for _i: int in range(1800):
		if player.candidate_loaded and computer.candidate_loaded:
			break
		await physics_frame
	await process_frame
	scene.set_process(false)
	scene.set_physics_process(false)
	player.set_physics_process(false)
	computer.set_physics_process(false)
	player.opponent = computer
	computer.opponent = player

	var table: Array = _load_table()
	var has_variant_map: bool = player.get("_opponent_suffix_variants") != null
	var variant_count: int = 0
	if has_variant_map:
		variant_count = int(Dictionary(player.get("_opponent_suffix_variants")).size())

	var kinds_report: Dictionary = {}
	for kind: String in _kinds:
		var entry: Dictionary = {"kind": kind}
		entry["attack_kind_exists"] = player.ATTACKS.has(kind)
		entry["opponent_ok"] = (
			bool(player._variant_opponent_ok(kind)) if has_variant_map else false
		)
		entry["supports"] = bool(player.supports_attack(kind))
		entry["clip_status"] = (
			player.variant_clip_status(kind) if has_variant_map else {}
		)
		player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
		computer.reset_fighter(Vector3(-1.0, 1.20, 0.0))
		player.facing = 1.0
		computer.facing = -1.0
		player.opponent = computer
		computer.opponent = player
		player.rage = 100.0
		scene._action_camera_end()
		var started: bool = bool(player.request_attack(kind))
		entry["request_started"] = started
		var armed_clip: String = ""
		var armed_camera: String = ""
		if started:
			scene._update_fight_camera(1.0 / 60.0)
			armed_clip = String(scene.get("_action_camera_clip"))
			armed_camera = String(scene.get("_action_camera_camera"))
		entry["camera_clip"] = armed_clip
		entry["camera"] = armed_camera
		kinds_report[kind] = entry

	var report: Dictionary = {
		"label": suffix,
		"suffix": suffix,
		"table_present": FileAccess.file_exists("res://data/opponent_suffix_variants.json"),
		"table_rows": table.size(),
		"player_variant_map_present": has_variant_map,
		"player_variant_kinds": variant_count,
		"opponent_config": config,
		"kinds": kinds_report,
	}
	print("PROBE_VARIANTS=" + JSON.stringify(report))
	quit(0)

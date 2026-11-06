extends SceneTree
## Fast loader probe (no candidate GLBs): checks the recovered sequence table,
## untinted draw and the collision fix without loading fighter assets.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")
	OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 1:
		push_error("Expected <gametext_root>")
		quit(2)
		return
	var text_root: String = args[0].replace("\\", "/")
	OS.set_environment("BRUCELEE_GAME_TEXT_ROOT", text_root)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var failures: Array[String] = []
	var sequences: Dictionary = scene.get("_game_text_sequences")
	if sequences.size() != 11:
		failures.append("sequences=%d" % sequences.size())
	for index: int in range(11):
		if not sequences.has(index):
			failures.append("missing %d" % index)
	var s7: Dictionary = sequences.get(7, {})
	var s8: Dictionary = sequences.get(8, {})
	var s9: Dictionary = sequences.get(9, {})
	var s10: Dictionary = sequences.get(10, {})
	var distinct_counters: bool = (
		String(s7.get("sprite_key", "")) == "COUNTER"
		and String(s8.get("sprite_key", "")) == "COUNTER"
		and (s7.get("steps", []) as Array) != (s8.get("steps", []) as Array)
	)
	var distinct_greats: bool = (
		String(s9.get("sprite_key", "")) == "GREAT"
		and String(s10.get("sprite_key", "")) == "GREAT"
		and (s9.get("steps", []) as Array) != (s10.get("steps", []) as Array)
	)
	var textures: Dictionary = scene.get("_game_text_textures")
	var overlay: Sprite2D = scene.get("_game_text_rect")
	scene._show_game_text("PERFECT", 2.0, 6)
	var mod: Color = overlay.modulate if overlay != null else Color()
	var base_scale: float = scene._game_text_base_scale()
	var viewport_width: float = root.get_visible_rect().size.x
	var expected_scale: float = base_scale * float(
		(sequences.get(6, {}).get("steps", [{}]) as Array)[0].get("size", 1.0)
	)
	var report: Dictionary = {
		"env_root": OS.get_environment("BRUCELEE_GAME_TEXT_ROOT"),
		"env_root_exists": FileAccess.file_exists(
			text_root.path_join("BL_gameText-READY.png")
		),
		"sequence_count": sequences.size(),
		"distinct_counters": distinct_counters,
		"distinct_greats": distinct_greats,
		"texture_count": textures.size(),
		"modulate": [mod.r, mod.g, mod.b, mod.a],
		"base_scale": base_scale,
		"viewport_width": viewport_width,
		"scale_matches_base_times_step": (
			overlay != null and overlay.scale.is_equal_approx(Vector2.ONE * expected_scale)
		),
		"flip": [overlay.flip_h, overlay.flip_v] if overlay != null else null,
		"launch_log": scene.get("game_text_launch_log"),
		"failures": failures,
	}
	if sequences.size() != 11 or not distinct_counters or not distinct_greats:
		failures.append("loader key collision or missing records")
	if textures.size() != 9:
		failures.append("textures=%d" % textures.size())
	if not is_equal_approx(mod.r, 1.0) or not is_equal_approx(mod.g, 1.0) \
			or not is_equal_approx(mod.b, 1.0):
		failures.append("tinted modulate %s" % mod)
	if overlay == null or not overlay.scale.is_equal_approx(Vector2.ONE * expected_scale):
		failures.append("scale not base*step size")
	report["failures"] = failures
	print("GAME_TEXT_LOADER_PROBE=" + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

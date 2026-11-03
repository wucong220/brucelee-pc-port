extends SceneTree
## End-to-end story-flow test on the real main.tscn (headless).
##
##   godot --headless --fixed-fps 60 --path game --script res://tests/story_flow_e2e.gd
##
## Walks the whole required flow exactly as a player would drive it:
##   NEW STORY -> slot -> difficulty -> chapter map -> event detail
##   -> picture playback -> battle launch (VS) -> win -> rewards/unlock records
##   -> back to the map -> next auto_launch event -> battle -> loss with
##   win_on_lose -> rewards -> map
## The fight results are forced through main.gd's own `_on_ko` handler (the same
## entry point the fighter's `combat_ko` signal calls); nothing in the product
## code is test-aware.

const ENV_FLOW: String = "BRUCELEE_STORY_FLOW"
const ENV_LAUNCH: String = "BRUCELEE_STORY_LAUNCH"
const StoryStateScript = preload("res://scripts/story_state.gd")

var failures: Array = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(name: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if condition:
		print("PASS %s" % name)
		return
	failures.append(name + (" · " + detail if not detail.is_empty() else ""))
	print("FAIL %s %s" % [name, detail])


func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await physics_frame


func _wait_until(predicate: Callable, max_frames: int, label: String) -> bool:
	for _index: int in range(max_frames):
		if bool(predicate.call()):
			return true
		await physics_frame
	var result: bool = bool(predicate.call())
	if not result:
		print("TIMEOUT " + label)
	return result


func _wait_reload(old_instance_id: int, max_frames: int, label: String) -> bool:
	## Waits for reload_current_scene(): the old scene is freed before the new one
	## becomes current_scene, so only valid instances may be touched.
	for _index: int in range(max_frames):
		if is_instance_valid(current_scene):
			if (current_scene.get_instance_id() != old_instance_id
					and current_scene.get("story_flow") != null):
				return true
		await physics_frame
	return false


func _quiet_stage(scene_node: Node) -> void:
	## Removes the AI and stops the opponent's physics so a headless test decides
	## every fight result deterministically.  Test-only; the product code is not
	## aware of this.
	if scene_node == null or not is_instance_valid(scene_node):
		return
	scene_node.set("native_ai", null)
	var computer: Variant = scene_node.get("computer")
	if computer != null:
		computer.set_physics_process(false)


func _force_result(scene_node: Node, player_wins: bool, max_rounds: int = 4) -> void:
	## Drives real KOs through main.gd's own `_on_ko` handler (the same entry the
	## fighter's combat_ko signal calls) until the match closes.
	for _round: int in range(max_rounds):
		if _screen() != "battle" or not is_instance_valid(scene_node):
			return
		if bool(scene_node.get("match_over")):
			return
		var fighting: bool = await _wait_until(
			func() -> bool:
				return (
					is_instance_valid(scene_node)
					and (bool(scene_node.get("match_over"))
						or int(scene_node.get("match_state")) == 4)
				),
			1800,
			"fight state")
		if not fighting:
			return
		if bool(scene_node.get("match_over")) or _screen() != "battle":
			return
		scene_node.call("_on_ko",
			scene_node.get("computer") if player_wins else scene_node.get("player"))
		await _wait_until(
			func() -> bool:
				return (
					not is_instance_valid(scene_node)
					or _screen() != "battle"
					or int(scene_node.get("match_state")) != 4
				),
			1800, "after ko")


func _flow() -> Node:
	if not is_instance_valid(current_scene):
		return null
	return current_scene.get("story_flow")


func _screen() -> String:
	var flow: Node = _flow()
	if flow == null:
		return "<none>"
	return String(flow.debug_state().get("screen", "<none>"))


func _run() -> void:
	# Isolated user:// slot files only; the project name is unique to this copy.
	for slot: int in range(1, StoryStateScript.SLOT_COUNT + 1):
		var path: String = StoryStateScript.slot_path(slot)
		if StoryStateScript.slot_exists(slot):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	OS.set_environment(ENV_FLOW, "1")
	OS.set_environment(ENV_LAUNCH, "")
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")
	OS.set_environment("BRUCELEE_PLAYER_GLB", "")
	OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", "")
	OS.set_environment("BRUCELEE_OPPONENT_GLB", "")
	OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", "")
	OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", "")
	OS.set_environment("BRUCELEE_GAME_TEXT_ROOT", "X:/story-flow-none")
	OS.set_environment("BRUCELEE_MENU_SFX_ROOT", "X:/story-flow-none")
	OS.set_environment("BRUCELEE_AUDIO_ROOT", "X:/story-flow-none")
	OS.set_environment("BRUCELEE_MUSIC_ROOT", "X:/story-flow-none")
	OS.set_environment("BRUCELEE_VOICE_ROOT", "X:/story-flow-none")

	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait_until(func() -> bool: return _flow() != null and _screen() == "mode", 600,
		"mode screen")
	check("boot lands on STORY MODE", _screen() == "mode", _screen())
	var flow: Node = _flow()
	check("story data loaded", flow != null and bool(flow.get("data").is_loaded()),
		str(flow.get("error_text") if flow != null else ""))
	check("story flow forced the main menu off", scene.get("main_menu_enabled") == false)

	# NEW STORY -> slot 1 -> MEDIUM
	flow.call("_accept")
	check("NEW STORY opens slot select", _screen() == "slot", _screen())
	flow.call("_accept")
	check("slot select opens difficulty", _screen() == "difficulty", _screen())
	flow.call("_move", 1)
	flow.call("_accept")
	check("difficulty starts the story on the chapter map",
		_screen() == "detail" or _screen() == "map", _screen())
	var save: Dictionary = StoryStateScript.read_slot(1)
	check("slot 1 saved with medium difficulty",
		String(save.get("difficulty_name", "")) == "medium", str(save.get("difficulty_slot", "")))
	check("difficulty slot stored as 1", int(save.get("difficulty_slot", -1)) == 1)

	# auto_launch takes the first story event straight to its detail screen
	check("auto_launch opens s_master_1 detail", _screen() == "detail", _screen())
	var detail: Dictionary = flow.debug_state()
	check("detail points at s_master_1", int(detail.get("detail_event", -1)) == 7,
		str(detail.get("detail_event", -1)))
	var header: Dictionary = flow.call("header_lines")
	check("detail header shows the recovered maptitle",
		String(header.get("title", "")).begins_with("s_master_1")
				or String(header.get("title", "")).contains("The Master 1"),
		String(header.get("title", "")))
	var detail_rows: Array = flow.call("body_lines")
	var detail_text: String = "\n".join(PackedStringArray(detail_rows))
	check("detail shows opponent and candidate",
		detail_text.contains("shen lo") and detail_text.contains("candidate shenlo"), "")
	check("detail shows the scenery mapping",
		detail_text.contains("market") and detail_text.contains("squarea"), "")
	check("detail shows the difficulty array selection",
		detail_text.contains("difficulty") and detail_text.contains("selected value 1"), "")
	check("detail shows rounds 1", detail_text.contains("rounds     1"), "")
	check("detail lists the 2 unlock subevents", detail_text.contains("unlock 108")
		and detail_text.contains("unlock 40"), "")

	# playback: six picture subevents, then the VS battle
	var old_scene_id: int = scene.get_instance_id()
	flow.call("_accept")
	check("playback starts on the first picture", _screen() == "picture", _screen())
	var picture_rows: Array = flow.call("body_lines")
	check("picture screen lists recovered layers",
		"\n".join(PackedStringArray(picture_rows)).contains("layers"), "")
	var guard: int = 0
	while _screen() == "picture" and guard < 12:
		flow.call("_accept")
		guard += 1
		await process_frame
	check("playback reaches the battle", _screen() == "battle", _screen())
	check("battle launch sets BRUCELEE_STORY_LAUNCH",
		OS.get_environment(ENV_LAUNCH) == "1", OS.get_environment(ENV_LAUNCH))
	check("battle launch writes the pending fight",
		not (StoryStateScript.read_slot(1).get("pending", {}) as Dictionary).is_empty())
	check("battle launch sets the opponent candidate env",
		OS.get_environment("BRUCELEE_OPPONENT_NAME_KEY") == "shenlo",
		OS.get_environment("BRUCELEE_OPPONENT_NAME_KEY"))
	check("battle launch sets the scenery env",
		OS.get_environment("BRUCELEE_SCENE") == "squarea", OS.get_environment("BRUCELEE_SCENE"))
	check("battle launch sets rounds 1",
		OS.get_environment("BRUCELEE_MATCH_ROUNDS") == "1",
		OS.get_environment("BRUCELEE_MATCH_ROUNDS"))
	check("battle launch sets no round clock",
		OS.get_environment("BRUCELEE_ROUND_TIME") == "0",
		OS.get_environment("BRUCELEE_ROUND_TIME"))
	check("battle launch sets the AI difficulty value",
		OS.get_environment("BRUCELEE_AI_DIFFICULTY") == "1",
		OS.get_environment("BRUCELEE_AI_DIFFICULTY"))

	# the scene reloads with the match loader configuration (the reload can be
	# triggered by the last picture advance above, so the old id is captured first)
	var reloaded: bool = await _wait_reload(old_scene_id, 900, "scene reload")
	check("main.tscn reloads for the story battle", reloaded)
	if not reloaded:
		_finish()
		return
	scene = current_scene
	flow = _flow()
	await _wait_until(func() -> bool: return _screen() == "battle", 300, "battle banner")
	check("resumed flow is in the battle screen", _screen() == "battle", _screen())
	check("match loader got rounds 1", int(scene.get("rounds_to_win")) == 1,
		str(scene.get("rounds_to_win")))
	check("match loader got no round clock", int(scene.get("round_time_max")) == 0,
		str(scene.get("round_time_max")))
	check("match loader re-applied the scene variant",
		String(scene.call("_scene_variant")) == "squarea", String(scene.call("_scene_variant")))
	check("match loader re-applied the opponent",
		String(scene.call("_opponent_display_name")) == "SHEN LO",
		String(scene.call("_opponent_display_name")))
	var ai: Variant = scene.get("native_ai")
	check("match loader re-applied the AI difficulty",
		ai != null and int(ai.difficulty_index) == 1,
		str(ai.difficulty_index) if ai != null else "native_ai missing")
	_quiet_stage(scene)

	# wait for the round to be fightable, then force the KO through _on_ko
	var fighting: bool = await _wait_until(
		func() -> bool: return int(scene.get("match_state")) == 4, 900, "round fight state")
	check("round reaches the fight state", fighting)
	await _force_result(scene, true)
	var resolved: bool = await _wait_until(
		func() -> bool:
			return (
				_screen() == "picture"
				or _screen() == "rewards"
				or _screen() == "defeat"
			),
		2400,
		"match result")
	check("match result returns to the story flow", resolved, _screen())
	flow = _flow()
	guard = 0
	while _screen() == "picture" and guard < 12:
		flow.call("_accept")
		guard += 1
		await process_frame
	check("win completes the event and shows the rewards screen",
		_screen() == "rewards", _screen())
	var rewards_rows: Array = flow.call("body_lines")
	var rewards_text: String = "\n".join(PackedStringArray(rewards_rows))
	check("rewards list the two unlock records",
		rewards_text.contains("unlock 108") and rewards_text.contains("unlock 40"), rewards_text)
	check("rewards resolve the scenery/profile names",
		rewards_text.contains("market") or rewards_text.contains("shenlo"), "")
	var saved: Dictionary = StoryStateScript.read_slot(1)
	check("two unlocks saved", (saved.get("unlocks", []) as Array).size() == 2,
		str((saved.get("unlocks", []) as Array).size()))
	check("s_master_1 recorded as completed",
		(saved.get("completed", {}) as Dictionary).get("chapter1", []).has("s_master_1"),
		str(saved.get("completed", {})))
	check("fight record saved", (saved.get("records", []) as Array).size() == 1,
		str((saved.get("records", []) as Array).size()))
	check("pending cleared after the event", (saved.get("pending", {}) as Dictionary).is_empty())

	# back to the map: s_master_1 is done and no further auto_launch fires until
	# the chapter is re-entered (the recovered flag is a chapter-entry trigger).
	flow.call("_accept")
	check("rewards return to the map", _screen() == "map", _screen())
	var map_text: String = "\n".join(PackedStringArray(flow.call("body_lines")))
	check("map shows s_master_1 completed",
		map_text.contains("[x] s_master_1")
				or map_text.contains("[x] The Master 1"), map_text)
	check("map shows s_master_2 available",
		map_text.contains("s_master_2") or map_text.contains("The Master 2"), "")
	check("map still locks s_master_3 behind s_master_2",
		not map_text.contains("> s_master_3"), "")

	# second battle: s_master_2 (difficulty [4,4,4], win_on_lose true, time 30)
	flow.call("show_detail", 8)
	check("map opens the s_master_2 detail screen", _screen() == "detail", _screen())
	check("detail points at s_master_2 (event index 8)",
		int(flow.debug_state().get("detail_event", -1)) == 8,
		str(flow.debug_state().get("detail_event", -1)))
	if _screen() == "detail":
		var old2: int = scene.get_instance_id()
		flow.call("_accept")
		guard = 0
		while _screen() == "picture" and guard < 24:
			flow.call("_accept")
			guard += 1
			await process_frame
		check("s_master_2 reaches its battle", _screen() == "battle", _screen())
		check("s_master_2 difficulty 4 handed to the AI",
			OS.get_environment("BRUCELEE_AI_DIFFICULTY") == "4",
			OS.get_environment("BRUCELEE_AI_DIFFICULTY"))
		check("s_master_2 time 30 handed to the round clock",
			OS.get_environment("BRUCELEE_ROUND_TIME") == "30",
			OS.get_environment("BRUCELEE_ROUND_TIME"))
		var reloaded2: bool = await _wait_reload(old2, 900, "second reload")
		check("second battle reloads the match", reloaded2)
		if reloaded2:
			scene = current_scene
			flow = _flow()
			await _wait_until(func() -> bool: return _screen() == "battle", 300, "second banner")
			check("second match uses time 30", int(scene.get("round_time_max")) == 30,
				str(scene.get("round_time_max")))
			check("second match uses rounds 1", int(scene.get("rounds_to_win")) == 1,
				str(scene.get("rounds_to_win")))
			var ai2: Variant = scene.get("native_ai")
			check("second match uses AI difficulty 4",
				ai2 != null and int(ai2.difficulty_index) == 4,
				str(ai2.difficulty_index) if ai2 != null else "native_ai missing")
			_quiet_stage(scene)
			await _force_result(scene, false)
			var resolved2: bool = await _wait_until(
				func() -> bool:
					return (
						_screen() == "picture"
						or _screen() == "rewards"
						or _screen() == "defeat"
					),
				2400,
				"second result")
			check("second match result reaches the story flow", resolved2, _screen())
			flow = _flow()
			guard = 0
			while _screen() == "picture" and guard < 24:
				flow.call("_accept")
				guard += 1
				await process_frame
			check("win_on_lose completes s_master_2 after a loss",
				_screen() == "rewards", _screen())
			var saved2: Dictionary = StoryStateScript.read_slot(1)
			check("s_master_2 recorded as completed",
				(saved2.get("completed", {}) as Dictionary).get("chapter1", []).has("s_master_2"),
				str(saved2.get("completed", {})))
			flow.call("_accept")
			check("returns to the map after the second event",
				_screen() == "map" or _screen() == "detail", _screen())

	# records screen
	if _screen() == "map" or _screen() == "detail":
		if _screen() == "detail":
			flow.call("_cancel")
		flow.call("show_records")
		check("records screen opens", _screen() == "records", _screen())
		var records_text: String = "\n".join(
			PackedStringArray(flow.call("body_lines")))
		check("records list the saved unlocks", records_text.contains("UNLOCK RECORDS (2)"),
			records_text.substr(0, 200))
		check("records list the saved fights", records_text.contains("FIGHT RECORDS (2)"), "")
		flow.call("_cancel")

	_finish()


func _finish() -> void:
	print("")
	print("CHECKS %d · FAILURES %d" % [checks, failures.size()])
	for failure: Variant in failures:
		print("  FAILED: " + String(failure))
	print("STORY_FLOW_E2E " + ("OK" if failures.is_empty() else "FAILED"))
	for slot: int in range(1, StoryStateScript.SLOT_COUNT + 1):
		if StoryStateScript.slot_exists(slot):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(
				StoryStateScript.slot_path(slot)))
	quit(0 if failures.is_empty() else 1)

extends SceneTree
## Validates the recovered PERFECT/GREAT/COUNTER/DRAW/WIN/LOSE game text
## routing and the ingamesprites.list sequence loader on the real main.tscn.
##
## Native evidence (libdefault.so):
##   - CBeatEmUpGame::SetState(3): LaunchGameTextAnimation(0) + (1)
##   - SetState(5): (4) TIME_IS_UP; state 5 decides 7/8/11 by health
##   - SetState(7) (fighter 0 scored, local flag 0): winner health < 0x14 ->
##     (9) GREAT, else (2) YOU_WIN; winner health == 100 -> additionally (6)
##     PERFECT.  SetState(8) with local flag 0 -> (3) YOU_LOSE.
##   - SetState(11): (5) DRAW
##   - CBeatEmUpGame::Render consumes CFighter+0x176 (set by CFighter::
##     SetAnimation when the animation carries the "counter" category, i.e.
##     parryhigh/parrylow) -> (7) left / (8) right COUNTER.
##   - CSpriteAnimator::Update draws each step at size * texture pixels in
##     display coordinates with no colour tint.

const STATE_FIGHT: int = 4
const STATE_TIME_UP: int = 5
const STATE_KO_WIN: int = 7
const STATE_KO_LOSE: int = 8
const STATE_DRAW: int = 11
const STATE_ROUND_END: int = 15
const STATE_MATCH_WIN: int = 12

var shots: String = ""
var results: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _advance_overlays(scene: Node, seconds: float) -> void:
	# The frozen scene has _process disabled; step the overlay sequences explicitly so
	# the capture matches the native sequence time instead of its alpha-0 first step.
	var remaining: float = seconds
	while remaining > 0.0:
		var dt: float = minf(remaining, 0.05)
		scene._update_game_text_sequence(dt)
		remaining -= dt


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOT_SKIPPED_HEADLESS %s" % name)
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = shots.path_join(name)
	var err: int = image.save_png(path)
	print("SHOT %s %dx%d err=%d" % [name, image.get_width(), image.get_height(), err])
	if err != OK:
		print("SHOTB64 %s %s" % [name, Marshalls.raw_to_base64(image.save_png_to_buffer())])


func _new_scene(
		bruce: String,
		brick: String,
		round_time: int,
		text_root: String,
		attack_config: String = "res://data/fighting_set_m03_mapped_attacks.json"
) -> Node:
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")
	OS.set_environment("BRUCELEE_ROUND_TIME", str(round_time))
	OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
	OS.set_environment("BRUCELEE_PLAYER_GLB", bruce)
	OS.set_environment("BRUCELEE_OPPONENT_GLB", brick)
	OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", attack_config)
	OS.set_environment("BRUCELEE_GAME_TEXT_ROOT", text_root)
	OS.set_environment("BRUCELEE_GAME_TEXT_FLIP", "1")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	return scene


func _wait_candidates(scene: Node, timeout_frames: int = 900) -> bool:
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


func _tick(scene: Node, seconds: float, step: float = 0.05) -> void:
	var remaining: float = seconds
	while remaining > 0.0:
		var dt: float = minf(remaining, step)
		scene._physics_process(dt)
		remaining -= dt


func _tick_until(scene: Node, target_state: int, max_seconds: float = 9.0) -> bool:
	var elapsed: float = 0.0
	var step: float = 0.02
	while elapsed < max_seconds:
		if _state(scene) == target_state:
			return true
		scene._physics_process(step)
		elapsed += step
	return _state(scene) == target_state


func _state(scene: Node) -> int:
	var value: Variant = scene.get("match_state")
	if typeof(value) == TYPE_INT:
		return value
	return -1


func _launch_log(scene: Node) -> Array:
	return scene.get("game_text_launch_log")


func _log_since(scene: Node, previous_size: int) -> Array:
	var log: Array = _launch_log(scene)
	return log.slice(mini(previous_size, log.size()))


func _seq_names(entries: Array) -> Array:
	var names: Array = []
	for entry: Variant in entries:
		if entry is Dictionary:
			names.append("%s#%d" % [entry.get("key"), entry.get("sequence")])
	return names


func _real_punch_ko(scene: Node, attacker: PortFighter, defender: PortFighter) -> bool:
	return _real_punch_ko_with_winner_health(scene, attacker, defender, -1.0)


## Same fixture as validate_match_result but also sets the *winner's* health
## after the resets (a non-negative value) so GREAT/PERFECT paths can be
## exercised without touching the defender side of the damage chain.
func _real_punch_ko_with_winner_health(
		scene: Node,
		attacker: PortFighter,
		defender: PortFighter,
		winner_health: float
) -> bool:
	if attacker == scene.get("player"):
		attacker.reset_fighter(Vector3(0.0, 1.20, 0.0))
		defender.reset_fighter(Vector3(0.6, 1.20, 0.0))
	else:
		defender.reset_fighter(Vector3(0.0, 1.20, 0.0))
		attacker.reset_fighter(Vector3(0.6, 1.20, 0.0))
	defender.health = 1.0
	if winner_health >= 0.0:
		attacker.health = winner_health
	attacker.facing = (
		1.0 if defender.global_position.x >= attacker.global_position.x else -1.0
	)
	if not attacker.request_attack("punch"):
		push_error("request_attack(punch) failed")
		return false
	attacker._physics_process(float(attacker.ATTACKS["punch"]["startup"]) + 0.01)
	if defender.health > 0.0:
		return false
	for _i: int in range(150):
		if _state(scene) != STATE_FIGHT:
			break
		defender._physics_process(1.0 / 60.0)
	return _state(scene) != STATE_FIGHT


func _active_overlays(scene: Node) -> int:
	var count: int = 0
	for overlay: Variant in scene.get("_game_text_overlays"):
		if overlay is Dictionary and bool(overlay["active"]):
			count += 1
	return count


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 4:
		push_error("Expected <bruce.glb> <brick.glb> <screenshot_dir> <gametext_root>")
		quit(2)
		return
	var bruce: String = args[0]
	var brick: String = args[1]
	shots = args[2].replace("\\", "/")
	var text_root: String = args[3].replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(shots)
	var failures: Array[String] = []

	# ---- Scenario 1: loader sequence keys, colour and scale ----
	var scene: Node = _new_scene(bruce, brick, 60, text_root)
	if not await _wait_candidates(scene):
		push_error("loader candidates did not load")
		quit(1)
		return
	await process_frame
	_freeze(scene)
	scene._reset_match()
	var sequences: Dictionary = scene.get("_game_text_sequences")
	results["sequence_count"] = sequences.size()
	if sequences.size() != 11:
		failures.append("expected 11 recovered sequences, got %d" % sequences.size())
	for index: int in range(11):
		if not sequences.has(index):
			failures.append("sequence %d missing" % index)
	var seq7: Dictionary = sequences.get(7, {})
	var seq8: Dictionary = sequences.get(8, {})
	var seq9: Dictionary = sequences.get(9, {})
	var seq10: Dictionary = sequences.get(10, {})
	results["seq7"] = [seq7.get("sprite_key"), (seq7.get("steps", []) as Array).size()]
	results["seq8"] = [seq8.get("sprite_key"), (seq8.get("steps", []) as Array).size()]
	results["seq9"] = [seq9.get("sprite_key"), (seq9.get("steps", []) as Array).size()]
	results["seq10"] = [seq10.get("sprite_key"), (seq10.get("steps", []) as Array).size()]
	if String(seq7.get("sprite_key", "")) != "COUNTER" or String(seq8.get("sprite_key", "")) != "COUNTER":
		failures.append("sequences 7/8 are not both COUNTER")
	else:
		var seq7_steps: Array = seq7["steps"]
		var seq8_steps: Array = seq8["steps"]
		if absf(float(seq7_steps[0]["x"]) - 0.15) > 0.001:
			failures.append("sequence 7 first x is %s, expected 0.15" % seq7_steps[0]["x"])
		if absf(float(seq8_steps[0]["x"]) - 1.3) > 0.001:
			failures.append("sequence 8 first x is %s, expected 1.3" % seq8_steps[0]["x"])
		if seq7_steps == seq8_steps:
			failures.append("COUNTER sequences 7 and 8 collapsed to one record")
	if String(seq9.get("sprite_key", "")) != "GREAT" or String(seq10.get("sprite_key", "")) != "GREAT":
		failures.append("sequences 9/10 are not both GREAT")
	else:
		var seq9_steps: Array = seq9["steps"]
		var seq10_steps: Array = seq10["steps"]
		if seq9_steps.size() != 7 or seq10_steps.size() != 4:
			failures.append("GREAT step counts are %d/%d, expected 7/4" % [
				seq9_steps.size(), seq10_steps.size(),
			])
		if absf(float(seq10_steps[0]["y"]) - 0.8) > 0.001:
			failures.append("sequence 10 first y is %s, expected 0.8" % seq10_steps[0]["y"])
		if seq9_steps == seq10_steps:
			failures.append("GREAT sequences 9 and 10 collapsed to one record")
	var textures: Dictionary = scene.get("_game_text_textures")
	results["textures"] = textures.keys()
	if textures.size() != 9:
		failures.append("expected 9 textures, got %d" % textures.size())
	var overlay: Sprite2D = scene.get("_game_text_rect")
	if overlay == null:
		failures.append("primary game text overlay missing")
	else:
		if overlay.flip_h or not overlay.flip_v:
			failures.append("game text flip is not the verified flip_v-only orientation")
		var base_scale: float = scene._game_text_base_scale()
		results["base_scale"] = base_scale
		var viewport_width: float = scene.get_viewport().get_visible_rect().size.x
		if absf(base_scale - viewport_width / 800.0) > 0.0001:
			failures.append("base scale %s does not follow viewport/800" % base_scale)
		var before: int = _launch_log(scene).size()
		scene._show_game_text("YOU_WIN", 3.0, 2)
		var mod: Color = overlay.modulate
		results["you_win_modulate"] = [mod.r, mod.g, mod.b, mod.a]
		if not is_equal_approx(mod.r, 1.0) or not is_equal_approx(mod.g, 1.0) \
				or not is_equal_approx(mod.b, 1.0):
			failures.append("game text is tinted (modulate %s), native draws untinted" % mod)
		if mod.a >= 1.0:
			failures.append("YOU_WIN first step alpha should come from the recovered sequence")
		var expected_scale: float = base_scale * float(
			(sequences[2]["steps"] as Array)[0].get("size", 1.0)
		)
		if not overlay.scale.is_equal_approx(Vector2.ONE * expected_scale):
			failures.append("YOU_WIN scale %s != base*step size %s" % [
				overlay.scale, expected_scale,
			])
		var tail: Array = _log_since(scene, before)
		if _seq_names(tail) != ["YOU_WIN#2"]:
			failures.append("YOU_WIN launch log is %s" % _seq_names(tail))
		# Sequences 7/8/9/10 must play their own steps, not the collapsed ones.
		scene._show_game_text("COUNTER", 0.0, 8)
		var counter_overlay: Sprite2D = null
		for overlay_value: Variant in scene.get("_game_text_overlays"):
			if overlay_value is Dictionary and String(overlay_value["key"]) == "COUNTER":
				counter_overlay = overlay_value["rect"]
		if counter_overlay == null:
			failures.append("COUNTER#8 overlay missing")
		else:
			var counter_pos: Vector2 = counter_overlay.position
			var viewport_size: Vector2 = scene.get_viewport().get_visible_rect().size
			if absf(counter_pos.x - viewport_size.x * 1.3) > 1.0:
				failures.append("COUNTER#8 first x %s is not the right-side record" % counter_pos.x)
		scene._hide_game_text_overlays()
	_advance_overlays(scene, 2.0)
	await _capture("01_loader_hold_you_win.png")

	# ---- Scenario 2: player KO at full health -> YOU_WIN + PERFECT ----
	scene = _new_scene(bruce, brick, 60, text_root)
	if not await _wait_candidates(scene):
		push_error("perfect candidates did not load")
		quit(1)
		return
	await process_frame
	_freeze(scene)
	scene._reset_match()
	var player: PortFighter = scene.get("player")
	var computer: PortFighter = scene.get("computer")
	var before: int = _launch_log(scene).size()
	if not _real_punch_ko(scene, player, computer):
		failures.append("full-health-winner punch did not KO the computer")
	if _state(scene) != STATE_KO_WIN:
		failures.append("player KO did not enter state 7")
	var winner_log: Array = _log_since(scene, before)
	results["perfect_win_log"] = _seq_names(winner_log)
	if _seq_names(winner_log) != ["YOU_WIN#2", "PERFECT#6"]:
		failures.append("full-health win text is %s, expected YOU_WIN#2+PERFECT#6" % _seq_names(winner_log))
	if _active_overlays(scene) < 2:
		failures.append("PERFECT did not run as a second concurrent overlay")
	results["perfect_overlays_active"] = _active_overlays(scene)
	_advance_overlays(scene, 2.0)
	await _capture("02_ko_you_win_perfect.png")
	if not _tick_until(scene, STATE_ROUND_END):
		failures.append("state 7 did not reach state 15")
	scene.queue_free()
	await process_frame

	# ---- Scenario 3: player KO at low health -> GREAT only ----
	scene = _new_scene(bruce, brick, 60, text_root)
	if not await _wait_candidates(scene):
		push_error("great candidates did not load")
		quit(1)
		return
	await process_frame
	_freeze(scene)
	scene._reset_match()
	player = scene.get("player")
	computer = scene.get("computer")
	before = _launch_log(scene).size()
	if not _real_punch_ko_with_winner_health(scene, player, computer, 15.0):
		failures.append("low-health-winner punch did not KO the computer")
	if _state(scene) != STATE_KO_WIN:
		failures.append("low-health player KO did not enter state 7")
	var great_log: Array = _log_since(scene, before)
	results["great_win_log"] = _seq_names(great_log)
	if _seq_names(great_log) != ["GREAT#9"]:
		failures.append("low-health win text is %s, expected GREAT#9 only" % _seq_names(great_log))
	_advance_overlays(scene, 2.0)
	await _capture("03_ko_great.png")
	scene.queue_free()
	await process_frame

	# ---- Scenario 4: player loses the KO -> YOU_LOSE regardless of ----
	# ---- the opponent's health (SetState(8) local-flag fall-through) ----
	scene = _new_scene(bruce, brick, 60, text_root)
	if not await _wait_candidates(scene):
		push_error("you-lose candidates did not load")
		quit(1)
		return
	await process_frame
	_freeze(scene)
	scene._reset_match()
	player = scene.get("player")
	computer = scene.get("computer")
	before = _launch_log(scene).size()
	if not _real_punch_ko(scene, computer, player):
		failures.append("opponent punch did not KO the player")
	if _state(scene) != STATE_KO_LOSE:
		failures.append("player KO did not enter state 8")
	var lose_log: Array = _log_since(scene, before)
	results["you_lose_log"] = _seq_names(lose_log)
	if _seq_names(lose_log) != ["YOU_LOSE#3"]:
		failures.append("player-loss text is %s, expected YOU_LOSE#3 only" % _seq_names(lose_log))
	_advance_overlays(scene, 2.0)
	await _capture("04_ko_you_lose.png")
	scene.queue_free()
	await process_frame

	# ---- Scenario 5: time up with equal health -> DRAW ----
	scene = _new_scene(bruce, brick, 3, text_root)
	if not await _wait_candidates(scene):
		push_error("draw candidates did not load")
		quit(1)
		return
	await process_frame
	_freeze(scene)
	scene._reset_match()
	player = scene.get("player")
	computer = scene.get("computer")
	player.health = 50.0
	computer.health = 50.0
	before = _launch_log(scene).size()
	if not _tick_until(scene, STATE_TIME_UP):
		failures.append("timer 0 did not enter state 5")
	if not _tick_until(scene, STATE_DRAW):
		failures.append("equal health time up did not enter state 11")
	var draw_log: Array = _log_since(scene, before)
	results["draw_log"] = _seq_names(draw_log)
	if _seq_names(draw_log) != ["TIME_IS_UP#4", "DRAW#5"]:
		failures.append("draw text is %s, expected TIME_IS_UP#4+DRAW#5" % _seq_names(draw_log))
	_advance_overlays(scene, 2.4)
	await _capture("05_time_up_draw.png")
	scene.queue_free()
	await process_frame

	# ---- Scenario 6: time up, player ahead at full health -> PERFECT ----
	scene = _new_scene(bruce, brick, 3, text_root)
	if not await _wait_candidates(scene):
		push_error("time-up perfect candidates did not load")
		quit(1)
		return
	await process_frame
	_freeze(scene)
	scene._reset_match()
	player = scene.get("player")
	computer = scene.get("computer")
	player.health = 100.0
	computer.health = 40.0
	before = _launch_log(scene).size()
	if not _tick_until(scene, STATE_TIME_UP):
		failures.append("timer 0 did not enter state 5 (perfect case)")
	if not _tick_until(scene, STATE_KO_WIN):
		failures.append("time up did not decide the round for the player")
	var timeup_log: Array = _log_since(scene, before)
	results["time_up_perfect_log"] = _seq_names(timeup_log)
	if _seq_names(timeup_log) != ["TIME_IS_UP#4", "YOU_WIN#2", "PERFECT#6"]:
		failures.append("time-up win text is %s, expected TIME_IS_UP+YOU_WIN+PERFECT" % _seq_names(timeup_log))
	_advance_overlays(scene, 2.0)
	await _capture("06_time_up_perfect.png")
	scene.queue_free()
	await process_frame

	# ---- Scenario 7: parry states trigger COUNTER 7 (player) / 8 (computer) --
	# One continuous parry launches once; each *new* parry animation
	# (parrylow -> parryhigh is a new SetAnimation) relaunches it.
	scene = _new_scene(bruce, brick, 60, text_root)
	if not await _wait_candidates(scene):
		push_error("counter candidates did not load")
		quit(1)
		return
	await process_frame
	_freeze(scene)
	scene.set("done", true)
	scene._reset_match()
	player = scene.get("player")
	computer = scene.get("computer")
	before = _launch_log(scene).size()
	player.state = "parryhigh"
	_tick(scene, 0.02)
	var counter_log: Array = _log_since(scene, before)
	results["counter_player_log"] = _seq_names(counter_log)
	if _seq_names(counter_log) != ["COUNTER#7"]:
		failures.append("player parry text is %s, expected COUNTER#7" % _seq_names(counter_log))
	_advance_overlays(scene, 0.3)
	await _capture("07_counter_player.png")
	# Holding the same parry animation must not retrigger.
	_tick(scene, 0.2)
	if _log_since(scene, before + 1).size() != 0:
		failures.append("holding the same parry animation relaunched COUNTER")
	# The opponent's parry uses sequence 8.
	player.state = "idle"
	computer.state = "parrylow"
	_tick(scene, 0.02)
	var counter_log2: Array = _log_since(scene, before + 1)
	results["counter_opponent_log"] = _seq_names(counter_log2)
	if _seq_names(counter_log2) != ["COUNTER#8"]:
		failures.append("opponent parry text is %s, expected COUNTER#8" % _seq_names(counter_log2))
	# A new parry animation relaunches the player-side text once per animation.
	player.state = "parrylow"
	_tick(scene, 0.02)
	player.state = "parryhigh"
	_tick(scene, 0.02)
	var repeat_log: Array = _log_since(scene, before + 2)
	results["counter_retrigger_log"] = _seq_names(repeat_log)
	if _seq_names(repeat_log) != ["COUNTER#7", "COUNTER#7"]:
		failures.append("parrylow->parryhigh should relaunch COUNTER#7 once per animation, got %s" % _seq_names(repeat_log))
	scene.queue_free()
	await process_frame

	results["failures"] = failures
	print("GAME_TEXT_TRIGGER_VALIDATION=" + JSON.stringify(results))
	quit(0 if failures.is_empty() else 1)

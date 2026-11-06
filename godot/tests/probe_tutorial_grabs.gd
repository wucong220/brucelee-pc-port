extends SceneTree
## Measure the port's real main.tscn behaviour under a reconstructed native
## active-unique set.  Two scenarios:
##   default  - Bruce style defaults (order-0 entry of each of the seven groups)
##   brick    - one explicit Brick style selection per available group
##              (hkickbrick and grababrick replace Bruce's hkick/grabA entries)
## The scenario is passed as BRUCELEE_ACTIVE_UNIQUES before the scene is built,
## so this probe measures the runtime rule, not a hardcoded special case.
##
## usage: --headless --path <proj> --script res://tests/probe_active_uniques.gd -- \
##   <player.glb> <opponent.glb> <default|brick>

const Controls = preload("res://scripts/prototype_controls.gd")
const DEFAULT_SET := "brucelee|hpunchbrucelee|lpunchbrucelee|hkickbrucelee|lkickbrucelee|grababrucelee|grabbbrucelee|endbrucelee"
const BRICK_SET := "brucelee|hpunchbrick|lpunchbrucelee|hkickbrick|lkickbrucelee|grababrick|grabbbrucelee|endbrucelee"

var _scene: Node
var _player: PortFighter
var _foe: PortFighter
var _training


func _initialize() -> void:
	call_deferred("_run")


func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	_scene._unhandled_input(event)


func _tick(n: int) -> void:
	for _i: int in range(n):
		_scene._process(1.0 / 60.0)
		_scene._physics_process(1.0 / 60.0)
		_player._physics_process(1.0 / 60.0)
		_foe._physics_process(1.0 / 60.0)


func _pin(distance: float) -> void:
	_player.position = Vector3(0.0, 1.2, 0.0)
	_foe.position = Vector3(distance, 1.2, 0.0)


func _step_pinned(frames: int, distance: float) -> void:
	for _i: int in range(frames):
		_pin(distance)
		_player._physics_process(1.0 / 60.0)
		_foe._physics_process(1.0 / 60.0)


func _start_lesson(native_action: String) -> int:
	for entry_value: Variant in _training.selectable_trainings():
		var entry: Dictionary = entry_value
		for step_value: Variant in Array(entry["steps"]):
			var step: Dictionary = step_value
			if native_action in Array(step["success_animations"]):
				_training.current_training = entry
				_training.steps = entry["steps"]
				_training.state = "active"
				_training._start_step(int(step["index"]))
				return int(step["index"])
	return -1


func _reset(rage: float, distance: float = 0.3) -> void:
	_scene._reset_match()
	_player.state = "idle"
	_player.state_time = 0.0
	_player.attack_kind = ""
	_player._attack_clock_active = false
	_player.held_directions = {}
	_player.set_key_status({})
	_player.move_axis = Vector2.ZERO
	_player.rage = rage
	_foe.state = "idle"
	_foe.state_time = 0.0
	_foe.attack_kind = ""
	_foe.held_directions = {}
	_foe.set_key_status({})
	_foe.health = 100.0
	_pin(distance)
	_player.opponent = _foe
	_foe.opponent = _player


func _special(low: bool, rage: float) -> Dictionary:
	var lesson: int = _start_lesson("specialkicklowhit" if low else "specialkickhigh")
	_reset(rage)
	var start_action: String = Controls.MOVE_DOWN if low else Controls.MOVE_LEFT
	var start_key: Key = KEY_S if low else KEY_A
	Input.action_press(start_action)
	_key(start_key)
	_tick(15)
	var prior: String = _player._current_action_name()
	Input.action_press(Controls.MOVE_RIGHT)
	_key(KEY_D)
	_tick(3)
	_key(KEY_U if low else KEY_L)
	var kind: String = ""
	var success: float = -1.0
	for _i: int in range(120):
		_tick(1)
		if kind.is_empty() and not _player.attack_kind.is_empty():
			kind = _player.attack_kind
		_training._process(1.0 / 60.0)
		if _training.success_timer >= 0.0:
			success = _training.success_timer
			break
	Input.action_release(start_action)
	Input.action_release(Controls.MOVE_RIGHT)
	_tick(1)
	return {"kgroup": "special", "low": low, "rage": rage, "prior": prior,
		"kind": kind, "clip": _player.candidate_animation_clip,
		"lesson": lesson, "success": success}


func _grab(step: String, key: String, finisher: bool) -> Dictionary:
	var lesson_index := _start_lesson("grab1" if step == "up" else "grab2")
	print("TUTORIAL_GRAB_SETUP=" + JSON.stringify({"index":lesson_index,"active":_player.tutorial_default_uniques,"training":_training.current_training.get("name", "")}))
	_reset(70.0, 0.3)
	_player.set_held_directions({step: true})
	var before: String = _player._current_action_name()
	var started: bool = _player.record_standing_combo_press(key)
	var miss: String = _player.attack_kind
	var miss_clip: String = ""
	_step_pinned(2, 0.3)
	_player._animate_candidate()
	miss_clip = _player.candidate_animation_clip
	var grab_kind: String = ""
	var grab_clip: String = ""
	var victim_clip: String = ""
	var victim_state: String = ""
	var health_before: float = _foe.health
	var saw_grab: bool = false
	for _i: int in range(160):
		_step_pinned(2, 0.3)
		if grab_kind.is_empty() and _player.attack_kind != miss and not _player.attack_kind.is_empty():
			grab_kind = _player.attack_kind
			_player._animate_candidate()
			grab_clip = _player.candidate_animation_clip
			saw_grab = true
		if victim_state.is_empty() and _foe.state in ["grabbed1", "grabbed2"]:
			victim_state = _foe.state
			_foe._animate_candidate()
			victim_clip = _foe.candidate_animation_clip
			if finisher:
				break
	var damage: float = health_before - _foe.health
	var finisher_kind: String = ""
	var finisher_clip: String = ""
	var finisher_started: bool = false
	var end_state: String = _foe.state
	if finisher and saw_grab and victim_state != "":
		_player.set_held_directions({"right": true})
		_player.set_key_status({"right": true, "a": true})
		finisher_started = _player.record_standing_combo_press("a")
		finisher_kind = _player.attack_kind
		if finisher_started:
			_player._animate_candidate()
			finisher_clip = _player.candidate_animation_clip
		for _i: int in range(400):
			_step_pinned(2, 0.3)
			if _foe.state == "faceupko":
				break
		end_state = _foe.state
	return {"kgroup": "grab", "step": step, "key": key, "prior": before,
		"started": started, "miss": miss, "miss_clip": miss_clip,
		"grab_kind": grab_kind, "grab_clip": grab_clip,
		"victim_state": victim_state, "victim_clip": victim_clip,
		"damage": damage, "finisher_started": finisher_started,
		"finisher_kind": finisher_kind, "finisher_clip": finisher_clip,
		"end_state": end_state}


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("Expected <player.glb> <opponent.glb> <default|brick>")
		quit(2)
		return
	var scenario: String = args[2]
	OS.set_environment("BRUCELEE_ACTIVE_UNIQUES",
		DEFAULT_SET if scenario == "default" else BRICK_SET)
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")
	OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
	OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
	OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	for _i: int in range(1800):
		if _scene.get("player").candidate_loaded and _scene.get("computer").candidate_loaded:
			break
		await physics_frame
	await process_frame
	_scene.set_process(false)
	_scene.set_physics_process(false)
	_player = _scene.get("player")
	_foe = _scene.get("computer")
	_training = _scene.get("move_training")
	_training.set_process(false)
	_player.set_physics_process(false)
	_foe.set_physics_process(false)
	print("ACTIVE_SET=" + JSON.stringify({
		"scenario": scenario,
		"tags": _player.get("_active_unique_tags"),
		"token": _player.active_uniques(),
	}))
	var rows: Array = []
	rows.append(_special(false, 32.0))
	rows.append(_special(false, 33.0))
	rows.append(_special(true, 65.0))
	rows.append(_special(true, 66.0))
	rows.append(_grab("up", "a", false))
	rows.append(_grab("up", "a", true))
	rows.append(_grab("down", "c", false))
	for row: Dictionary in rows:
		row["scenario"] = scenario
		print("ACTIVE_RESULT=" + JSON.stringify(row))
	quit(0)



extends SceneTree
## Tutorial-only style isolation lifecycle probe on the real main.tscn.
## 1. apply a NON-default saved style (Brick hkick + grabA)
## 2. enter a use_custom_style=false lesson -> Bruce default clips/unique gate
## 3. run the special gesture and check lesson success
## 4. close the training -> saved style clips restored
## 5. re-enter / interrupt -> default again, then restored again
## 6. switch to free training -> saved style, not tutorial defaults
##
## usage: --headless --path <proj> --script res://tests/probe_tutorial_lifecycle.gd -- \
##   <player.glb> <opponent.glb>

const StyleCatalog = preload("res://scripts/style_catalog.gd")
const Controls = preload("res://scripts/prototype_controls.gd")

var _scene: Node
var _player: PortFighter
var _foe: PortFighter
var _training
var _failures: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures.append(label + " " + detail)
	print("LIFE_CHECK=" + JSON.stringify({"label": label, "ok": ok, "detail": detail}))


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


func _clips() -> Dictionary:
	return {
		"hkick": String(_player._candidate_clip_paths.get("special_kick_high", "")),
		"grab1": String(_player._candidate_clip_paths.get("grab1", "")),
		"endattack2": String(_player._candidate_clip_paths.get("endattack2", "")),
	}


func _lesson(index_hint: String) -> int:
	for entry_value: Variant in _training.selectable_trainings():
		var entry: Dictionary = entry_value
		for step_value: Variant in Array(entry["steps"]):
			var step: Dictionary = step_value
			if index_hint in Array(step["success_animations"]):
				_training.current_training = entry
				_training.steps = entry["steps"]
				_training.state = "active"
				_training._start_step(int(step["index"]))
				return int(step["index"])
	return -1


func _special_gesture() -> Dictionary:
	_scene._reset_match()
	_player.state = "idle"
	_player.state_time = 0.0
	_player.attack_kind = ""
	_player.held_directions = {}
	_player.set_key_status({})
	_player.rage = 33.0
	_player.position = Vector3(-2.0, 1.2, 0.0)
	_foe.position = Vector3(-1.1, 1.2, 0.0)
	Input.action_press(Controls.MOVE_LEFT)
	_key(KEY_A)
	_tick(15)
	Input.action_press(Controls.MOVE_RIGHT)
	_key(KEY_D)
	_tick(3)
	_key(KEY_L)
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
	Input.action_release(Controls.MOVE_LEFT)
	Input.action_release(Controls.MOVE_RIGHT)
	_tick(1)
	return {"kind": kind, "success": success, "clip": _player.candidate_animation_clip}


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Expected <player.glb> <opponent.glb>")
		quit(2)
		return
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
	var catalog = StyleCatalog.new()
	_check("style catalog loads", catalog.load_catalog(), catalog.error)
	# The decoded catalog has no non-default BRUCE entry whose clip exists in the
	# player candidate: every other row maps to m02/m03/m04 clips the player does
	# not load, so apply_style_selections fails closed for them.  Emulate the
	# state a successful saved style would leave (a non-default clip in the two
	# tested slots) using clips the player candidate does provide.
	var report: Dictionary = _player.apply_style_selections({}, catalog)
	_check("base clip snapshot seeded", _player._style_base_clips.has("special_kick_high"), str(report.get("error", "")))
	_player._candidate_clip_paths["special_kick_high"] = "m01_kick_high_01"
	_player._candidate_clip_paths["grab1"] = "m01_grab_02"
	var styled: Dictionary = _clips()
	print("LIFE_STYLED=" + JSON.stringify({"applied": report.get("applied"), "clips": styled}))
	_check("non-default saved state changes the hkick clip", styled["hkick"] != "m01_kck_front_step", styled["hkick"])
	_check("non-default saved state changes the grab1 clip", styled["grab1"] != "m01_grab_01", styled["grab1"])

	# Enter tutorial lesson (use_custom_style=false in training_native.json).
	var index: int = _lesson("specialkickhigh")
	_check("tutorial lesson starts", index >= 0, str(index))
	_check("tutorial lesson disables custom style", bool(_training.current_training.get("use_custom_style", true)) == false, "")
	_check("enter sets tutorial default uniques", _player.tutorial_default_uniques, "")
	var tutorial: Dictionary = _clips()
	_check("tutorial uses Bruce default hkick clip", tutorial["hkick"] == "m01_kck_front_step", tutorial["hkick"])
	_check("tutorial uses Bruce default grab1 clip", tutorial["grab1"] == "m01_grab_01", tutorial["grab1"])
	_check("tutorial default IDs are the native eight",
		_player.TUTORIAL_DEFAULT_UNIQUES.size() == 8
		and _player.TUTORIAL_DEFAULT_UNIQUES.has("hkickbrucelee")
		and _player.TUTORIAL_DEFAULT_UNIQUES.has("grababrucelee")
		and _player.TUTORIAL_DEFAULT_UNIQUES.has("endbrucelee"), "")
	var special: Dictionary = _special_gesture()
	_check("tutorial special high reaches special_kick_high", String(special["kind"]) == "special_kick_high", String(special["kind"]))
	_check("tutorial special high registers lesson success", float(special["success"]) >= 0.0, str(special["success"]))

	# Exit -> saved style and clips restored.
	_training.close()
	_check("close clears tutorial gate", not _player.tutorial_default_uniques, "")
	var restored: Dictionary = _clips()
	_check("close restores saved hkick clip", restored["hkick"] == styled["hkick"], restored["hkick"])
	_check("close restores saved grab1 clip", restored["grab1"] == styled["grab1"], restored["grab1"])

	# Interrupt/re-enter.
	index = _lesson("specialkickhigh")
	_check("re-enter sets tutorial gate", _player.tutorial_default_uniques and _clips()["hkick"] == "m01_kck_front_step", _clips()["hkick"])
	_training.close()
	_check("second close restores saved clips", _clips()["hkick"] == styled["hkick"], _clips()["hkick"])

	# Free training switches away from tutorial defaults.
	_training.enter_free_training()
	_check("free training clears tutorial gate", not _player.tutorial_default_uniques, "")
	var free_clips: Dictionary = _clips()
	_check("free training keeps saved hkick clip", free_clips["hkick"] == styled["hkick"], free_clips["hkick"])
	_check("free training keeps saved grab1 clip", free_clips["grab1"] == styled["grab1"], free_clips["grab1"])
	_training.close()
	print("LIFE_RESULT=" + JSON.stringify({"failures": _failures, "styled": styled,
		"tutorial": tutorial, "restored": restored, "free": free_clips,
		"special": special}))
	quit(0 if _failures.is_empty() else 1)

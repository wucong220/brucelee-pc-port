extends SceneTree
## Real main.tscn progress save/restart validation through the native providers.
##
## Save phase: load res://scenes/main.tscn with BRUCELEE_PROGRESS=1 and
## BRUCELEE_NATIVE_SETTINGS set, drive real main.gd progress hooks, flush.
## Restart phase (separate process): delete the JSON progress save, load the same
## native settings.dat, and verify the recovered state comes back from native.

const DIR := "user://native_provider_runtime"
const NATIVE := "user://native_provider_runtime/settings.dat"
const JSON_SAVE := "user://progress_save.json"
const CharacterUnlockGate = preload("res://scripts/character_unlock_gate.gd")
const SceneUnlockGate = preload("res://scripts/scene_unlock_gate.gd")

var checks := 0
var failures := 0
var mode := ""


func _check(ok: bool, label: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label, "  ", detail)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _initialize() -> void:
	call_deferred("_run")


func _load_main() -> Node:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		return null
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	return scene


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	mode = String(args[0]) if not args.is_empty() else "save"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	if mode == "save":
		await _save_phase()
	elif mode == "restart":
		await _restart_phase()
	else:
		print("unknown mode: ", mode)
		quit(2)
		return
	print("=== NATIVE MAIN RESULT[%s]: %d checks, %d failures ===" % [mode, checks, failures])
	quit(0 if failures == 0 else 1)


func _save_phase() -> void:
	_remove(NATIVE)
	_remove(JSON_SAVE)
	OS.set_environment("BRUCELEE_PROGRESS", "1")
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")
	OS.set_environment("BRUCELEE_NATIVE_SETTINGS", NATIVE)
	var scene: Node = await _load_main()
	_check(scene != null, "main.tscn loads")
	if scene == null:
		return
	var p = scene.get("progress")
	_check(p != null, "main created progress node")
	if p == null:
		return
	_check(p.native_ok, "native provider store active", String(p.native_error))
	_check(bool(p.active), "progress active")

	var player = scene.get("player")
	var computer = scene.get("computer")
	_check(player != null and computer != null, "main created fighters")
	if player == null or computer == null:
		return

	# Recovered story EXP + deterministic event unlock rows.
	p.sync_story_exp(1700)
	p.note_story_event("chapter1", "s_master_6")
	p.note_story_event("chapter1", "s_master_1")

	# Real main.gd combat hooks: five distinct grabs -> achv_grabs_5.
	for i in range(5):
		player.attack_sequence = 100 + i
		scene._on_hit(player, computer, "grab1", 5.0, false)
	# Real round-result hook: perfect round -> native Stats number_of_perfects.
	player.health = 100.0
	scene._show_round_result_text(player, true)
	# Real versus-win hook.
	scene.player_rounds = scene.rounds_to_win
	scene._round_end_handled = false
	scene._advance_round_end()

	_check(p.flush(), "main progress flush writes native + JSON", String(p.native_error))
	_check(FileAccess.file_exists(NATIVE), "native settings.dat exists")
	_check(FileAccess.file_exists(JSON_SAVE), "JSON save exists")
	var flags: Dictionary = p.native_store.read_flags()
	var expected_ids := [7, 17, 24, 35, 40, 60, 69, 84, 90, 97, 100, 108, 110]
	var ids_ok := true
	for id in expected_ids:
		if int(flags["Unlocker.unlocked"][id]) != 1:
			ids_ok = false
	_check(ids_ok, "native unlocked flags contain recovered grants")
	_check(int(flags["CharacterList.available"][7]) == 1, "native CharacterList fighter 7")
	_check(int(flags["CharacterList.profile_available"][1]) == 1, "native profile 1")
	_check(int(flags["CharacterList.profile_available"][4]) == 1, "native profile 4")
	_check(int(flags["SceneryList.available"][3]) == 1, "native scenery 3")
	_check(int(flags["Unlocker.art_pictures"][10]) == 1, "native art 10")
	_check(int(flags["Unlocker.art_pictures"][7]) == 1, "native art 7")
	_check(int(flags["Unlocker.art_pictures"][15]) == 1, "native art 15")
	var achievement_id := ""
	for row in p.service.achievements.rows:
		if String(row["id"]) == "achv_grabs_5":
			achievement_id = String(row["id"])
			_check(int(flags["Unlocker.achievements"][int(row["index"])]) == 1,
					"native achievement flag achv_grabs_5")
	if achievement_id.is_empty():
		_check(false, "achv_grabs_5 row exists")
	_check(absf(float(flags["Stats.data"].get("number_of_perfects", -1)) - 1.0) < 0.0001,
			"native Stats number_of_perfects = 1")
	print("NATIVE_RUNTIME_SAVE_OK ids=", str(p.service.unlocked_ids()))
	root.remove_child(scene)
	scene.free()


func _restart_phase() -> void:
	# Prove native alone: remove the JSON progress save before loading main.
	_remove(JSON_SAVE)
	OS.set_environment("BRUCELEE_PROGRESS", "1")
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")
	OS.set_environment("BRUCELEE_NATIVE_SETTINGS", NATIVE)
	var scene: Node = await _load_main()
	_check(scene != null, "restart main.tscn loads")
	if scene == null:
		return
	var p = scene.get("progress")
	_check(p != null, "restart progress node")
	if p == null:
		return
	_check(p.native_ok, "restart native store active", String(p.native_error))
	_check(bool(p.active), "restart progress active")
	var ids: Array = p.service.unlocked_ids()
	var expected_ids := [7, 17, 24, 35, 40, 60, 69, 84, 90, 97, 100, 108, 110]
	_check(ids == expected_ids, "restart restores native unlocked ids", str(ids))
	var reached: Array = p.service.state["achievements"]["reached"]
	_check(reached.has("achv_grabs_5"), "restart restores native achievement")
	_check(int(p.service.state["counters"].get("number_of_perfects", -1)) == 1,
			"restart restores native stat")
	var flags: Dictionary = p.native_store.read_flags()
	_check(int(flags["CharacterList.available"][7]) == 1, "restart CharacterList flag")
	_check(int(flags["SceneryList.available"][3]) == 1, "restart SceneryList flag")
	_check(int(flags["Unlocker.art_pictures"][15]) == 1, "restart art flag")
	var cg = CharacterUnlockGate.new()
	cg.refresh()
	var cstate: Dictionary = cg.state_for_character(7)
	_check(bool(cstate.get("available", false)), "character gate sees native fighter 7", str(cstate))
	var sg = SceneUnlockGate.new()
	sg.refresh()
	var sstate: Dictionary = sg.state_for_index(3)
	_check(bool(sstate.get("available", false)), "scene gate sees native scenery 3", str(sstate))
	print("NATIVE_RUNTIME_RESTART_OK ids=", str(ids))
	root.remove_child(scene)
	scene.free()

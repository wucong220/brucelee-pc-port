extends SceneTree
## Real main.tscn default-on / migration / opt-out validation.
##
## Modes (separate processes where restart matters):
##   default_save      no BRUCELEE_NATIVE_SETTINGS: normal startup creates
##                     user://settings.dat, drives hooks, flushes native+JSON.
##   default_restart   JSON deleted, native default path restored.
##   migration_save    old user://progress_save.json exists; native absent.
##                     First startup migrates it read-only into native.
##   migration_restart JSON deleted after migration; native is authoritative.
##   language_seed     existing language-only user://settings.dat with language 6
##                     is refused as incomplete: progress is inactive, save is
##                     rejected, and the language-only bytes remain unchanged.
##   opt_out           BRUCELEE_NATIVE_PROGRESS=0 keeps JSON-only behavior.

const DEFAULT_NATIVE := "user://settings.dat"
const JSON_SAVE := "user://progress_save.json"
const NativeStore = preload("res://scripts/native_settings_store.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")

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


func _clear_env() -> void:
	OS.set_environment("BRUCELEE_NATIVE_SETTINGS", "")
	OS.set_environment("BRUCELEE_LANGUAGE_SAVE_PATH", "")
	OS.set_environment("BRUCELEE_NATIVE_PROGRESS", "")
	OS.set_environment("BRUCELEE_PROGRESS", "")
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")


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


func _drive_progress(scene: Node) -> void:
	var p = scene.get("progress")
	var player = scene.get("player")
	var computer = scene.get("computer")
	p.sync_story_exp(1700)
	p.note_story_event("chapter1", "s_master_6")
	p.note_story_event("chapter1", "s_master_1")
	for i in range(5):
		player.attack_sequence = 200 + i
		scene._on_hit(player, computer, "grab1", 5.0, false)
	player.health = 100.0
	scene._show_round_result_text(player, true)
	scene.player_rounds = scene.rounds_to_win
	scene._round_end_handled = false
	scene._advance_round_end()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	mode = String(args[0]) if not args.is_empty() else "default_save"
	match mode:
		"default_save": await _default_save()
		"default_restart": await _default_restart()
		"migration_save": await _migration_save()
		"migration_restart": await _migration_restart()
		"language_seed": await _language_seed()
		"opt_out": await _opt_out()
		_:
			print("unknown mode: ", mode)
			quit(2)
			return
	print("=== NATIVE DEFAULT RESULT[%s]: %d checks, %d failures ===" % [mode, checks, failures])
	quit(0 if failures == 0 else 1)


func _default_save() -> void:
	_remove(DEFAULT_NATIVE)
	_remove(JSON_SAVE)
	_clear_env()
	var scene: Node = await _load_main()
	_check(scene != null, "default-on main.tscn loads")
	if scene == null:
		return
	var p = scene.get("progress")
	_check(p != null, "default-on progress node")
	if p == null:
		return
	_check(String(p.native_path) == DEFAULT_NATIVE, "default-on path is user://settings.dat",
			String(p.native_path))
	_check(bool(p.native_ok), "default-on native ok", String(p.native_error))
	_check(bool(p.native_created_default), "default-on created default native tree")
	_check(FileAccess.file_exists(DEFAULT_NATIVE), "default-on native file created")
	_drive_progress(scene)
	_check(p.flush(), "default-on flush writes native + JSON mirror", String(p.native_error))
	_check(FileAccess.file_exists(JSON_SAVE), "default-on JSON mirror exists")
	var flags: Dictionary = p.native_store.read_flags()
	_check(int(flags["Unlocker.unlocked"][17]) == 1, "default-on unlock flag 17")
	_check(int(flags["CharacterList.available"][7]) == 1, "default-on CharacterList flag")
	_check(NativeStore.read_language(DEFAULT_NATIVE) == 0, "default-on language stays valid")
	print("NATIVE_DEFAULT_SAVE_OK")
	root.remove_child(scene)
	scene.free()


func _default_restart() -> void:
	# Deliberately stale mirror must not add unlocks over native authority.
	var stale: Dictionary = SaveManagerScript.default_state()
	stale["unlocks"]["unlocked_ids"] = [0]
	stale["achievements"]["reached"] = ["achv_arcade_easy"]
	_check(SaveManagerScript.save_state(stale, JSON_SAVE), "stale JSON fixture written")
	_clear_env()
	var scene: Node = await _load_main()
	_check(scene != null, "default restart main.tscn loads")
	if scene == null:
		return
	var p = scene.get("progress")
	_check(p != null, "default restart progress node")
	if p == null:
		return
	_check(String(p.native_path) == DEFAULT_NATIVE, "restart uses default native path")
	_check(bool(p.native_ok) and bool(p.active), "default restart active", String(p.native_error))
	var ids: Array = p.service.unlocked_ids()
	var expected := [7, 17, 24, 35, 40, 60, 69, 84, 90, 97, 100, 108, 110]
	_check(ids == expected, "default restart restores native ids", str(ids))
	_check(int(p.service.state["counters"].get("number_of_perfects", -1)) == 1,
			"default restart restores native stat")
	_check(p.service.state["achievements"]["reached"].has("achv_grabs_5"),
			"default restart restores native achievement")
	print("NATIVE_DEFAULT_RESTART_OK ids=", str(ids))
	root.remove_child(scene)
	scene.free()


func _migration_save() -> void:
	_remove(DEFAULT_NATIVE)
	_remove(JSON_SAVE)
	var st: Dictionary = SaveManagerScript.default_state()
	st["unlocks"]["unlocked_ids"] = [7, 17]
	st["achievements"]["reached"] = ["achv_grabs_5"]
	st["counters"]["number_of_perfects"] = 2
	_check(SaveManagerScript.save_state(st, JSON_SAVE), "legacy JSON save written")
	_clear_env()
	var scene: Node = await _load_main()
	_check(scene != null, "migration main.tscn loads")
	if scene == null:
		return
	var p = scene.get("progress")
	_check(p != null, "migration progress node")
	if p == null:
		return
	_check(bool(p.native_ok), "migration native ok", String(p.native_error))
	_check(bool(p.native_migrated), "first startup migrated old JSON")
	_check(FileAccess.file_exists(DEFAULT_NATIVE), "migration created native file")
	_check(FileAccess.file_exists(JSON_SAVE), "legacy JSON retained as mirror")
	var flags: Dictionary = p.native_store.read_flags()
	_check(int(flags["Unlocker.unlocked"][7]) == 1 and int(flags["Unlocker.unlocked"][17]) == 1,
			"migration carried unlock flags")
	_check(p.service.state["achievements"]["reached"].has("achv_grabs_5"),
			"migration carried achievement")
	_check(int(p.service.state["counters"].get("number_of_perfects", -1)) == 2,
			"migration carried stat")
	print("NATIVE_MIGRATION_SAVE_OK")
	root.remove_child(scene)
	scene.free()


func _migration_restart() -> void:
	_remove(JSON_SAVE)
	_clear_env()
	var scene: Node = await _load_main()
	_check(scene != null, "migration restart main.tscn loads")
	if scene == null:
		return
	var p = scene.get("progress")
	_check(p != null, "migration restart progress node")
	if p == null:
		return
	_check(bool(p.native_ok) and bool(p.active), "migration restart active", String(p.native_error))
	_check(not bool(p.native_migrated), "migration restart did not re-migrate JSON")
	_check(p.service.unlocked_ids() == [7, 17], "migration restart restores migrated ids",
			str(p.service.unlocked_ids()))
	_check(int(p.service.state["counters"].get("number_of_perfects", -1)) == 2,
			"migration restart restores stat")
	print("NATIVE_MIGRATION_RESTART_OK")
	root.remove_child(scene)
	scene.free()


func _language_seed() -> void:
	_remove(DEFAULT_NATIVE)
	_remove(JSON_SAVE)
	_check(NativeStore.write_language(DEFAULT_NATIVE, 6), "language-only seed written")
	_clear_env()
	var scene: Node = await _load_main()
	_check(scene != null, "language seed main.tscn loads")
	if scene == null:
		return
	var p = scene.get("progress")
	_check(p != null, "language seed progress node")
	if p == null:
		return
	_check(not bool(p.native_ok) and not bool(p.active), "missing providers fail closed",
			String(p.native_error))
	_check(NativeStore.read_language(DEFAULT_NATIVE) == 6, "language seed preserves language 6")
	_check(not p.flush(), "language seed flush refused", String(p.native_error))
	_check(NativeStore.read_language(DEFAULT_NATIVE) == 6, "language remains 6 after refused save")
	print("NATIVE_LANGUAGE_SEED_OK")
	root.remove_child(scene)
	scene.free()


func _opt_out() -> void:
	_remove(DEFAULT_NATIVE)
	_remove(JSON_SAVE)
	_clear_env()
	OS.set_environment("BRUCELEE_NATIVE_PROGRESS", "0")
	var scene: Node = await _load_main()
	_check(scene != null, "opt-out main.tscn loads")
	if scene == null:
		return
	var p = scene.get("progress")
	_check(p != null, "opt-out progress node")
	if p == null:
		return
	_check(p.native_store == null and String(p.native_path) == "",
			"opt-out disables native store")
	_check(bool(p.native_ok) and bool(p.active), "opt-out keeps JSON-only progress active")
	p.sync_story_exp(1100)
	_check(p.flush(), "opt-out JSON flush")
	_check(not FileAccess.file_exists(DEFAULT_NATIVE), "opt-out did not create native settings.dat")
	_check(FileAccess.file_exists(JSON_SAVE), "opt-out writes JSON save")
	print("NATIVE_OPT_OUT_OK")
	root.remove_child(scene)
	scene.free()

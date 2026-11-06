extends SceneTree
## Headless validation of the main.gd hook call sites.
##
## Loads the real `res://scenes/main.tscn`, attaches an isolated ProgressHooks
## bridge, and calls the same methods the game uses:
##   * _on_hit(player, ..., "grab1"/"endattack1", ...)  -> grab / endmove counters
##   * _show_round_result_text(player, true)           -> great / perfect counters
##   * _advance_round_end() on a reached match target   -> versus win counter
##
## Run: godot --headless --path godot --script res://tests/validate_progress_main_hooks.gd

const ProgressHooksScript = preload("res://scripts/progress_hooks.gd")

const TEST_SAVE := "user://progress_main_hooks_test.json"

var failures := 0
var checks := 0


func check(ok: bool, label: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label, ("  | " + detail) if detail != "" else "")


func check_eq(actual, expected, label: String) -> void:
	check(actual == expected, label, "actual=%s expected=%s" % [str(actual), str(expected)])


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Progress main.gd hook validation ===")
	_remove(TEST_SAVE)
	var p = ProgressHooksScript.new()
	p.configure(TEST_SAVE)

	var previous_menu: String = OS.get_environment("BRUCELEE_MAIN_MENU")
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")
	var packed: PackedScene = load("res://scenes/main.tscn")
	check(packed != null, "main.tscn loads")
	if packed == null:
		quit(1)
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	OS.set_environment("BRUCELEE_MAIN_MENU", previous_menu)
	scene.set_physics_process(false)

	var player: PortFighter = scene.get("player")
	var computer: PortFighter = scene.get("computer")
	check(player != null and computer != null, "main scene created both fighters")
	scene.progress = p

	# grab: player grab lands -> number_of_grabs
	scene._on_hit(player, computer, "grab1", 5.0, false)
	check_eq(int(p.state()["counters"].get("number_of_grabs", 0)), 1,
		"main._on_hit counts a landed player grab")
	# opponent grab must not count
	scene._on_hit(computer, player, "grab1_brick", 5.0, false)
	check_eq(int(p.state()["counters"].get("number_of_grabs", 0)), 1,
		"main._on_hit ignores an opponent grab")
	# end-attack / final attack
	scene._on_hit(player, computer, "endattack1", 5.0, false)
	check_eq(int(p.state()["counters"].get("number_of_endmoves", 0)), 1,
		"main._on_hit counts a landed final attack (endmove)")

	# GREAT / PERFECT round-win grades (recovered SetState(7) health rule)
	player.health = 100.0
	scene._show_round_result_text(player, true)
	check_eq(int(p.state()["counters"].get("number_of_perfects", 0)), 1,
		"main._show_round_result_text counts a perfect round win")
	player.health = 10.0
	scene._show_round_result_text(player, true)
	check_eq(int(p.state()["counters"].get("number_of_greats", 0)), 1,
		"main._show_round_result_text counts a great round win")

	# versus win: standalone match target reached, no story/mode flags set
	scene.player_rounds = scene.rounds_to_win
	scene._round_end_handled = false
	scene._advance_round_end()
	check_eq(int(p.state()["counters"].get("versus_wins", 0)), 1,
		"main._advance_round_end counts a standalone versus win")
	# a second call is guarded by match_over/_round_end_handled -> no double count
	scene._advance_round_end()
	check_eq(int(p.state()["counters"].get("versus_wins", 0)), 1,
		"versus win is not double-counted on a repeated round-end call")

	check(p.flush(), "main-hook save flushes")
	check(FileAccess.file_exists(TEST_SAVE), "main-hook save file exists")

	root.remove_child(scene)
	scene.free()
	p.free()
	_remove(TEST_SAVE)

	print("")
	print("=== RESULT: %d checks, %d failures ===" % [checks, failures])
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED")
		quit(1)

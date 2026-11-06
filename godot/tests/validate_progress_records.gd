extends SceneTree
## Headless validation of the opt-in Records / Achievements screen.
##
## Covers:
##   * menu gating: the RECORDS row exists ONLY while BRUCELEE_PROGRESS=1, at a
##     stable position, and disappears again when the flag is cleared;
##   * the screen's data binding against the real progress service: 38
##     achievements, unlock list/count, story EXP/events, versus/combat
##     counters, mode clears and the real save envelope status;
##   * original icon binding (76 decoded textures), the missing-texture path and
##     the fail-closed time-attack beginner row;
##   * keyboard/joypad navigation, close signal and input ownership;
##   * a save round-trip (UI -> checksummed save -> reload from disk) plus the
##     tampered-save fail-closed display;
##   * the real main.tscn path: menu -> RECORDS -> close -> menu, paused tree,
##     and no RECORDS row / no screen with the flag off.
##
## Run:  godot --headless --path godot --script res://tests/validate_progress_records.gd
## Exit 0 = all checks pass.

const ProgressHooksScript = preload("res://scripts/progress_hooks.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")
const MenuScript = preload("res://scripts/prototype_menu.gd")
const RecordsScript = preload("res://scripts/progress_records_screen.gd")
const PrototypeControls = preload("res://scripts/prototype_controls.gd")

const TEST_SAVE := "user://progress_records_test.json"
const CORRUPT_SAVE := "user://progress_records_corrupt.json"
const TEXT_ONLY_PROBE := "user://progress_records_no_icons"

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
	check(actual == expected, label,
		"actual=%s expected=%s" % [str(actual), str(expected)])


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event


func _note_label_text(screen) -> String:
	## The screen's honesty note under the footer (icons + label provenance).
	return String(screen._note_label.text) if screen._note_label != null else ""


func _payload_text(path: String) -> String:
	## Raw inner payload of the checksummed envelope ("" when unreadable).
	if not FileAccess.file_exists(path):
		return ""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return ""
	return String((parsed as Dictionary).get("payload_json", ""))


func _snapshot_default_save() -> Dictionary:
	## The default user:// save belongs to the shipped package on this machine.
	## The main-scene checks only READ it, but snapshot it anyway so a stray hook
	## write during the fight-start check cannot touch the player's real save.
	var path: String = "user://progress_save.json"
	var snapshot: Dictionary = {"path": path, "exists": false, "bytes": PackedByteArray()}
	if FileAccess.file_exists(path):
		snapshot["exists"] = true
		snapshot["bytes"] = FileAccess.get_file_as_bytes(path)
	return snapshot


func _restore_default_save(snapshot: Dictionary) -> void:
	var path: String = String(snapshot["path"])
	if not bool(snapshot["exists"]):
		_remove(path)
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(snapshot["bytes"])
		file.close()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Progress records / achievements screen validation ===")
	print("user:// = ", ProjectSettings.globalize_path("user://"))
	PrototypeControls.ensure_default_actions()
	_remove(TEST_SAVE)
	_remove(CORRUPT_SAVE)

	OS.set_environment("BRUCELEE_PROGRESS", "")

	await _menu_gating()
	await _screen_data()
	await _screen_navigation()
	await _save_round_trip()
	await _corrupt_save()
	await _fresh_save_display()
	await _main_scene()

	print("")
	print("PROGRESS_RECORDS checks=%d failures=%d" % [checks, failures])
	print("PROGRESS_RECORDS_VALIDATION " + ("OK" if failures == 0 else "FAILED"))
	quit(0 if failures == 0 else 1)


# ------------------------------------------------------------------ 1. gating

func _menu_gating() -> void:
	OS.set_environment("BRUCELEE_PROGRESS", "")
	var menu = MenuScript.new()
	root.add_child(menu)
	await process_frame
	menu.show_main_menu()
	var off_commands: Array = menu.main_commands()
	var off_labels: Array = menu.main_labels()
	check_eq(off_commands, Array(MenuScript.MAIN_COMMANDS),
		"flag off: main rows are the untouched baseline")
	check_eq(off_labels, Array(MenuScript.MAIN_LABELS),
		"flag off: main labels are the untouched baseline")
	check(not off_commands.has("records"), "flag off: no RECORDS command")
	check(not off_labels.has("RECORDS"), "flag off: no RECORDS label")
	check(not MenuScript.progress_enabled(), "flag off: progress_enabled() is false")
	var visible_off: Array = []
	for index: int in range(menu.item_labels.size()):
		if menu.item_labels[index].visible:
			visible_off.append(String(menu.item_labels[index].text))
	check(not visible_off.has("RECORDS"), "flag off: no RECORDS row is drawn")
	menu.queue_free()
	await process_frame

	OS.set_environment("BRUCELEE_PROGRESS", "1")
	check(MenuScript.progress_enabled(), "flag on: progress_enabled() is true")
	menu = MenuScript.new()
	root.add_child(menu)
	await process_frame
	menu.show_main_menu()
	var on_commands: Array = menu.main_commands()
	var on_labels: Array = menu.main_labels()
	check_eq(on_commands.size(), off_commands.size() + 1,
		"flag on: exactly one extra main row")
	check_eq(on_commands[on_commands.size() - 1], "quit",
		"flag on: QUIT GAME stays the last row")
	check_eq(on_commands[on_commands.size() - 2], "records",
		"flag on: RECORDS sits directly before QUIT GAME")
	check_eq(on_labels[on_labels.size() - 2], "RECORDS",
		"flag on: RECORDS label text")
	var index_after_change := on_commands.size() - 2
	check_eq(on_commands[index_after_change], "records",
		"flag on: RECORDS index matches the label index")
	# Every row before RECORDS keeps its baseline command, so no existing binding
	# silently moves.
	var prefix_ok := true
	for index: int in range(off_commands.size() - 1):
		if on_commands[index] != off_commands[index]:
			prefix_ok = false
	check(prefix_ok, "flag on: no existing main row moved")
	# Layout: the extra row must not drop or clip the last one.
	await process_frame
	var layout: Dictionary = menu.layout_report()
	check_eq((layout["items"] as Array).size(), on_commands.size(),
		"flag on: one drawn row per command (nothing dropped)")
	check_eq((layout["clipped_items"] as Array).size(), 0,
		"flag on: no menu row is clipped")
	check(bool(layout["panel_inside"]), "flag on: the menu panel stays on screen")
	var drawn_text: Array = []
	for item: Variant in layout["items"]:
		drawn_text.append(String(Dictionary(item)["text"]))
	check(drawn_text.has("QUIT GAME"), "flag on: QUIT GAME is still drawn")
	check(drawn_text.has("RECORDS"), "flag on: RECORDS is drawn")
	# Keyboard ring includes the new row.
	menu.selected_index = 0
	var ring: Array = []
	for step: int in range(on_commands.size()):
		ring.append(menu.selected_command())
		menu.handle_input_event(_key(KEY_DOWN))
	check_eq(ring.size(), on_commands.size(), "flag on: DOWN visits every row")
	check(ring.has("records"), "flag on: keyboard ring reaches RECORDS")
	# Entering RECORDS emits the command and does not open a submenu here.
	var captured: Array = []
	menu.command_requested.connect(func(command: String) -> void: captured.append(command))
	menu.selected_index = index_after_change
	menu.handle_input_event(_key(KEY_ENTER))
	check_eq(captured, ["records"], "flag on: ENTER on RECORDS emits 'records'")
	check_eq(menu.menu_state, "main", "flag on: RECORDS stays a plain command row")
	menu.queue_free()
	await process_frame
	OS.set_environment("BRUCELEE_PROGRESS", "")


# ------------------------------------------------------------- 2. screen data

func _seeded_hooks():
	var hooks = ProgressHooksScript.new()
	root.add_child(hooks)
	hooks.configure(TEST_SAVE)
	# Seed with the same recovered events/thresholds the progress tests use.
	hooks.sync_story_exp(1700)
	hooks.note_story_event("chapter1", "s_master_1")
	hooks.note_story_event("chapter1", "s_master_6")
	hooks.note_story_chapter("chapter1")
	hooks.note_versus_win()
	hooks.note_versus_win()
	for _i: int in range(7):
		hooks.note_combat_hit("grab1_brick", "grabbed", true, _i + 1)
	hooks.note_combat_hit("endattack1", "endattack", true, 50)
	for _i: int in range(3):
		hooks.note_grade("great")
	hooks.note_grade("perfect")
	hooks.note_survival_round(5)
	hooks.note_mode_clear("arcade", "easy")
	hooks.flush()
	return hooks


func _screen_data() -> void:
	OS.set_environment("BRUCELEE_PROGRESS", "1")
	var hooks = _seeded_hooks()
	var screen = RecordsScript.new()
	root.add_child(screen)
	screen.configure(hooks)
	screen.open()
	await process_frame
	var state: Dictionary = screen.debug_state()

	# -- achievements: 38 rows, decoded order, live reached flags
	var rows: Array = state["rows"]
	check_eq(rows.size(), 38, "screen lists all 38 achievements")
	var ids_ok := true
	for index: int in range(38):
		if String(rows[index]["id"]) != String(hooks.service.achievements.rows[index]["id"]):
			ids_ok = false
		if int(rows[index]["index"]) != index:
			ids_ok = false
	check(ids_ok, "achievement rows keep the decoded order and ids")
	var reached: Array = hooks.service.state["achievements"]["reached"]
	var reached_matches := true
	for row: Variant in rows:
		if bool(Dictionary(row)["reached"]) != reached.has(String(Dictionary(row)["id"])):
			reached_matches = false
	check(reached_matches, "reached flags match the live save state")
	var by_id := {}
	for row: Variant in rows:
		by_id[String(Dictionary(row)["id"])] = Dictionary(row)
	check(bool(by_id["achv_versus_1"]["reached"]),
		"2 versus wins reaches achv_versus_1")
	check(not bool(by_id["achv_versus_5"]["reached"]),
		"2 versus wins does not reach achv_versus_5")
	check(bool(by_id["achv_grabs_5"]["reached"]), "7 grabs reaches achv_grabs_5")
	check(not bool(by_id["achv_grabs_15"]["reached"]),
		"7 grabs does not reach achv_grabs_15")
	check(bool(by_id["achv_survival_5"]["reached"]),
		"survival best round 5 reaches achv_survival_5")
	check(bool(by_id["achv_arcade_easy"]["reached"]),
		"arcade easy clear reaches achv_arcade_easy")
	check(not bool(by_id["achv_events_5"]["reached"]),
		"2 story events do not reach achv_events_5")
	check_eq(String(by_id["achv_events_5"]["condition_text"]),
		"story_events_completed ≥ 5 (now 2)",
		"the events row shows the recovered threshold and the live counter")
	# fail-closed row: the beginner tier has no recovered difficulty value
	var beginner: Dictionary = by_id["achv_time_attack_beginner"]
	check(bool(beginner["fail_closed"]), "time-attack beginner is fail-closed")
	check(not bool(beginner["reached"]), "time-attack beginner is never reached")
	check_eq(String(beginner["state_text"]), "NOT RECOVERED",
		"time-attack beginner is labelled NOT RECOVERED")
	check_eq(String(beginner["status"]), "unrecovered",
		"time-attack beginner keeps status=unrecovered")

	# -- summary: achievements/unlocks/exp/events/counters/mode clears
	var summary: Dictionary = state["summary"]
	check_eq(int(summary["achievement_total"]), 38, "summary achievement total is 38")
	check_eq(int(summary["achievement_count"]), reached.size(),
		"summary achievement count matches the save")
	check_eq(int(summary["unlock_total"]), 117, "summary unlock total is the 117-id space")
	check_eq(int(summary["unlock_count"]),
		(hooks.service.unlocked_ids() as Array).size(),
		"summary unlock count matches the save")
	check_eq(int(summary["exp"]), 1700, "summary shows story EXP 1700")
	check_eq(int(summary["events_completed"]), 2, "summary shows 2 story events")
	check_eq(int(summary["counters"].get("versus_wins", 0)), 2,
		"summary shows 2 versus wins")
	check_eq(int(summary["counters"].get("number_of_grabs", 0)), 7,
		"summary shows 7 grabs")
	check_eq(int(summary["counters"].get("number_of_endmoves", 0)), 1,
		"summary shows 1 final attack")
	check_eq(int(summary["counters"].get("number_of_greats", 0)), 3,
		"summary shows 3 greats")
	check_eq(int(summary["counters"].get("number_of_perfects", 0)), 1,
		"summary shows 1 perfect")
	var mode_text := " ".join(summary["mode_clear_rows"])
	check(mode_text.contains("arcade") and mode_text.contains("EAS:yes"),
		"summary marks the arcade easy clear", mode_text)
	check(mode_text.contains("time attack"), "summary lists time attack", mode_text)

	# -- unlocks: EXP-gated ids are listed with their recovered source
	var unlocks: Array = state["unlocks"]
	var unlock_ids: Array = []
	for row: Variant in unlocks:
		unlock_ids.append(int(Dictionary(row)["id"]))
	for want: int in [17, 35, 60, 69, 97, 100]:
		check(unlock_ids.has(want), "unlock list contains EXP-gated id %d" % want)
	var sources_ok := true
	for row: Variant in unlocks:
		var entry: Dictionary = row
		if int(entry["id"]) in [17, 35, 60, 69, 97, 100]:
			if String(entry["source"]) != "story_exp":
				sources_ok = false
	check(sources_ok, "EXP-gated unlock rows report the story_exp source")
	var event_ids_ok := unlock_ids.has(40) and unlock_ids.has(108)
	check(event_ids_ok, "story-event unlocks are listed (ids 40 and 108)")
	check_eq(int(state["coverage"]["num_ids"]), 117, "unlock coverage reports 117 ids")
	check_eq(int(state["coverage"]["story_exp_rows"]), 40, "40 EXP unlock rows covered")
	check_eq(int(state["coverage"]["story_event_rows"]), 49,
		"49 story-event unlock rows covered")
	check(int(state["coverage"]["uncovered"]) > 0,
		"unlock coverage counts the ids with no recovered source")

	# -- save status of the real envelope
	var save: Dictionary = state["save"]
	check(bool(save["exists"]), "save status sees the written file")
	check(int(save["bytes"]) > 0, "save status reports a non-zero size")
	check(bool(save["checksum_ok"]), "save status verifies the SHA-256 checksum")
	check(bool(save["loads"]), "save status loads through SaveManager")
	check(not String(save["saved_utc"]).is_empty(), "save status shows saved_utc")
	check(not String(save["modified_utc"]).is_empty(), "save status shows the file time")
	check_eq(String(save["schema"]), "dragonwarrior-progress/1", "save status schema")
	check_eq(int(save["version"]), 1, "save status version")
	check(String(save["text"]).begins_with("OK"),
		"save status text reports OK", String(save["text"]))

	# -- icons: 76 original textures decoded; missing probe degrades to text-only
	var icons: Dictionary = state["icons"]
	check_eq(int(icons["table_entries"]), 76, "the recovered icon table holds 76 entries")
	check_eq(String(icons["table_error"]), "", "the icon table parses without error")
	# 38 rendered rows only touch their own 38 textures, so load the whole table.
	var loaded_all: int = 0
	for stem: Variant in screen._icon_table:
		if screen._texture(String(stem)) != null:
			loaded_all += 1
	check_eq(loaded_all, 76, "all 76 achievement icon textures decode and load")
	icons = screen.icon_status()
	check_eq((icons["missing"] as Array).size(), 0, "no achievement icon is missing")
	check_eq(String(icons["mode"]), "icons", "icon mode reports 'icons'")
	check(int(icons["loaded"]) >= 38,
		"every rendered achievement row resolved an icon texture")
	check(screen._texture("bl_gui_achievement_does_not_exist") == null,
		"a missing texture returns null (row degrades to text only)")
	check(screen._icon_for({"reached": false, "pending_icon": 999}) == null,
		"an out-of-range icon index returns null instead of guessing")
	# reached rows resolve the ON texture, locked rows the OFF texture
	var reached_stem := String(screen._icon_table[by_id["achv_grabs_5"]["reached_icon"]])
	var locked_stem := String(screen._icon_table[by_id["achv_grabs_15"]["pending_icon"]])
	check(reached_stem.contains("_on"), "reached rows use the _ON texture", reached_stem)
	check(locked_stem.contains("_off"), "locked rows use the _OFF texture", locked_stem)
	check(screen._texture(reached_stem) != null, "the _ON texture decodes and loads")
	check(screen._texture(locked_stem) != null, "the _OFF texture decodes and loads")

	# -- honest text-only fallback: rebuild every row against absent textures.
	# This is the exact code path taken when the PNGs are not present (a patch
	# applied to the repo ships the .import stubs only), so the screen must still
	# list all 38 achievements, keep navigation working and say so in its note.
	var saved_table: Array = screen._icon_table.duplicate()
	var absent: Array = []
	for index: int in range(76):
		absent.append("bl_gui_achievement_absent_%02d" % index)
	screen._icon_table = absent
	screen._icon_cache.clear()
	screen._icon_missing.clear()
	screen._rebuild_grid()
	var text_only: Dictionary = screen.icon_status()
	check_eq(String(text_only["mode"]), "text-only",
		"absent textures switch the screen to text-only mode")
	check_eq(int(text_only["row_icons"]), 0, "no row binds an icon when none exist")
	check_eq(screen._grid.get_child_count(), 38,
		"all 38 achievement rows still render without icons")
	screen._refresh_save()
	check((_note_label_text(screen)).contains("TEXT-ONLY"),
		"the note states text-only explicitly", _note_label_text(screen))
	screen._refresh_selection()
	check(screen.debug_state()["rows"].size() == 38,
		"text-only mode keeps the full achievement list")
	screen._icon_table = saved_table
	screen._icon_cache.clear()
	screen._icon_missing.clear()
	screen._rebuild_grid()
	screen._refresh_save()
	check_eq(String(screen.icon_status()["mode"]), "icons",
		"restoring the table returns to icon mode")
	check((_note_label_text(screen)).contains("rows bound"),
		"the note reports how many rows bound original textures",
		_note_label_text(screen))

	# every recovered filename must exist as a decoded PNG on disk
	var absent_files: Array = []
	for stem: Variant in screen._icon_table:
		if not FileAccess.file_exists(
				"res://ui/achievement/" + String(stem) + ".png"):
			absent_files.append(String(stem))
	check_eq(absent_files.size(), 0,
		"all 76 decoded achievement PNGs exist under res://ui/achievement/")

	# external icon directory override (BRUCELEE_ACHIEVEMENT_ICON_DIR), the same
	# escape hatch story_picture_view.gd offers for art that stays outside git.
	var temp_icons := "user://progress_records_icons"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_icons))
	var source_image: Image = Image.load_from_file(ProjectSettings.globalize_path(
		"res://ui/achievement/bl_gui_achievement_vs_1_on.png"))
	check(source_image != null, "the fixture icon decodes for the override test")
	if source_image != null:
		source_image.save_png(temp_icons.path_join("external_probe.png"))
	OS.set_environment("BRUCELEE_ACHIEVEMENT_ICON_DIR",
		ProjectSettings.globalize_path(temp_icons))
	check(screen._texture("external_probe") != null,
		"BRUCELEE_ACHIEVEMENT_ICON_DIR supplies an icon the project does not hold")
	OS.set_environment("BRUCELEE_ACHIEVEMENT_ICON_DIR", "")
	screen._icon_cache.erase("external_probe")

	print("SCREEN_NOTE ", String(state["note"]))
	screen.close()
	check(not screen.is_open(), "close() clears the open state")
	await process_frame
	screen.queue_free()
	hooks.queue_free()
	await process_frame
	OS.set_environment("BRUCELEE_PROGRESS", "")


# ------------------------------------------------------------- 3. navigation

func _screen_navigation() -> void:
	OS.set_environment("BRUCELEE_PROGRESS", "1")
	var hooks = ProgressHooksScript.new()
	root.add_child(hooks)
	hooks.configure(TEST_SAVE)
	var screen = RecordsScript.new()
	root.add_child(screen)
	screen.configure(hooks)
	screen.open()
	await process_frame
	check(screen.is_open(), "open() marks the screen open")
	check(screen.visible, "open() makes the screen visible")
	check_eq(screen.process_mode, Node.PROCESS_MODE_ALWAYS,
		"screen keeps processing while the tree is paused")
	check_eq(screen.layer, 40, "screen draws above the menu layer (30)")
	var closed_count: Array = []
	screen.closed.connect(func() -> void: closed_count.append(1))

	check_eq(screen.selected_index(), 0, "cursor starts on the first achievement")
	screen.move_cursor(1)
	check_eq(screen.selected_index(), 1, "move_cursor(+1) advances")
	screen.handle_input_event(_key(KEY_DOWN))
	check_eq(screen.selected_index(), 2, "DOWN advances through _input handling")
	screen.handle_input_event(_key(KEY_UP))
	check_eq(screen.selected_index(), 1, "UP moves back")
	screen.handle_input_event(_key(KEY_END))
	check_eq(screen.selected_index(), 37, "END jumps to the last achievement")
	screen.handle_input_event(_key(KEY_DOWN))
	check_eq(screen.selected_index(), 0, "DOWN at the last row wraps around")
	screen.handle_input_event(_key(KEY_HOME))
	check_eq(screen.selected_index(), 0, "HOME jumps to the first achievement")
	screen.handle_input_event(_key(KEY_PAGEDOWN))
	check_eq(screen.selected_index(), 2, "PAGEDOWN steps two rows")
	screen.set_cursor(11)
	check_eq(String(screen.debug_state()["selected"]["id"]),
		String(hooks.service.achievements.rows[11]["id"]),
		"the selected row detail follows the cursor")
	check(screen.handle_input_event(_key(KEY_F2)) == false,
		"an unmapped key is not consumed by the screen")
	screen.handle_input_event(_key(KEY_ESCAPE))
	check(not screen.is_open(), "ESC closes the screen")
	check_eq(closed_count.size(), 1, "close() emits the closed signal once")
	screen.handle_input_event(_key(KEY_ESCAPE))
	check_eq(closed_count.size(), 1, "a second ESC does not re-emit closed")
	screen.open()
	await process_frame
	screen.handle_input_event(_key(KEY_J))
	check(not screen.is_open(), "J (menu accept) also closes the screen")
	check_eq(closed_count.size(), 2, "reopening and closing emits closed again")
	screen.queue_free()
	hooks.queue_free()
	await process_frame
	OS.set_environment("BRUCELEE_PROGRESS", "")


# --------------------------------------------------------- 4. save round-trip

func _save_round_trip() -> void:
	OS.set_environment("BRUCELEE_PROGRESS", "1")
	var hooks = ProgressHooksScript.new()
	root.add_child(hooks)
	hooks.configure(TEST_SAVE)
	var screen = RecordsScript.new()
	root.add_child(screen)
	screen.configure(hooks)
	screen.open()
	await process_frame
	var before: Dictionary = screen.debug_state()["summary"]
	var before_payload: String = _payload_text(TEST_SAVE)

	# A real gameplay hook mutation, exactly as main.gd would call it.
	hooks.note_versus_win()
	screen.refresh()
	var after: Dictionary = screen.debug_state()["summary"]
	check_eq(int(after["counters"]["versus_wins"]),
		int(before["counters"]["versus_wins"]) + 1,
		"the screen shows the incremented versus counter after refresh")
	# The on-disk envelope must now carry the new value...
	var disk: Dictionary = SaveManagerScript.load_state(TEST_SAVE)
	check(not disk.is_empty(), "the save reloads from disk")
	check_eq(int(disk["counters"]["versus_wins"]),
		int(after["counters"]["versus_wins"]),
		"the on-disk counter matches the screen")
	var after_payload: String = _payload_text(TEST_SAVE)
	check(not after_payload.is_empty() and after_payload != before_payload,
		"the save payload is rewritten on mutation")
	check(bool(screen.debug_state()["save"]["checksum_ok"]),
		"the rewritten save still verifies its checksum")

	# ...and a fresh service that only reads the file agrees with the screen.
	var reloaded = ProgressHooksScript.new()
	root.add_child(reloaded)
	reloaded.configure(TEST_SAVE)
	var reload_screen = RecordsScript.new()
	root.add_child(reload_screen)
	reload_screen.configure(reloaded)
	reload_screen.open()
	await process_frame
	var reloaded_summary: Dictionary = reload_screen.debug_state()["summary"]
	check_eq(int(reloaded_summary["counters"]["versus_wins"]),
		int(after["counters"]["versus_wins"]),
		"a fresh service reads the same versus counter from disk")
	check_eq((reloaded_summary["achievements"] as Array).size(),
		(after["achievements"] as Array).size(),
		"a fresh service reads the same achievement set from disk")
	check_eq((reloaded_summary["unlocked_ids"] as Array).size(),
		(after["unlocked_ids"] as Array).size(),
		"a fresh service reads the same unlock set from disk")
	check_eq(int(reloaded_summary["exp"]), int(after["exp"]),
		"a fresh service reads the same story EXP from disk")
	reload_screen.queue_free()
	reloaded.queue_free()
	screen.queue_free()
	hooks.queue_free()
	await process_frame
	OS.set_environment("BRUCELEE_PROGRESS", "")


# ------------------------------------------------------- 5. corrupt/fail-closed

func _corrupt_save() -> void:
	OS.set_environment("BRUCELEE_PROGRESS", "1")
	# Start from a valid save, then break the envelope checksum (same shape the
	# real corruption path sees) and confirm the screen reports fail-closed.
	var hooks = ProgressHooksScript.new()
	root.add_child(hooks)
	hooks.configure(CORRUPT_SAVE)
	hooks.note_versus_win()
	hooks.flush()
	var text: String = FileAccess.get_file_as_string(CORRUPT_SAVE)
	var envelope: Variant = JSON.parse_string(text)
	check(envelope is Dictionary, "the corrupt-save fixture parses as an envelope")
	if envelope is Dictionary:
		var tampered: Dictionary = envelope
		tampered["checksum"] = "0".repeat(64)
		var file: FileAccess = FileAccess.open(CORRUPT_SAVE, FileAccess.WRITE)
		file.store_string(JSON.stringify(tampered))
		file.close()
	var screen = RecordsScript.new()
	root.add_child(screen)
	screen.configure(hooks, CORRUPT_SAVE)
	screen.open()
	await process_frame
	var save: Dictionary = screen.debug_state()["save"]
	check(bool(save["exists"]), "the tampered save still exists on disk")
	check(not bool(save["checksum_ok"]), "the tampered save fails the checksum check")
	check(not bool(save["loads"]), "the tampered save fails closed in SaveManager")
	check(String(save["text"]).contains("FAIL CLOSED"),
		"the screen reports the fail-closed state", String(save["text"]))
	var summary: Dictionary = screen.debug_state()["summary"]
	check_eq(int(summary["counters"].get("versus_wins", -1)), 1,
		"the screen keeps the last in-memory state, not the tampered file")
	screen.queue_free()
	hooks.queue_free()
	await process_frame
	_remove(CORRUPT_SAVE)
	OS.set_environment("BRUCELEE_PROGRESS", "")


# ------------------------------------------------------- 5b. fresh profile

func _fresh_save_display() -> void:
	OS.set_environment("BRUCELEE_PROGRESS", "1")
	var path := "user://progress_records_fresh.json"
	_remove(path)
	var hooks = ProgressHooksScript.new()
	root.add_child(hooks)
	hooks.configure(path)
	var screen = RecordsScript.new()
	root.add_child(screen)
	screen.configure(hooks, path)
	screen.open()
	await process_frame
	var save: Dictionary = screen.debug_state()["save"]
	check(not bool(save["exists"]), "fresh profile: no save file is reported")
	check_eq(String(save["text"]), "NO SAVE FILE", "fresh profile: save status text")
	var label: String = String(screen._save_label.text)
	check(label.contains("no save file yet"),
		"fresh profile: the save block says no file yet", label)
	check(not label.contains("mismatch"),
		"fresh profile: no bogus checksum mismatch is shown", label)
	check(screen.debug_state()["summary"]["active"],
		"fresh profile: the service is still active with default state")
	check_eq(int(screen.debug_state()["summary"]["unlock_count"]), 0,
		"fresh profile: the unlock list is empty")
	check(not FileAccess.file_exists(path),
		"opening records never writes a save file (read-only viewer)")
	screen.queue_free()
	hooks.queue_free()
	await process_frame
	_remove(path)
	OS.set_environment("BRUCELEE_PROGRESS", "")


# ------------------------------------------------------------ 6. main.tscn path

func _main_scene() -> void:
	var default_save: Dictionary = _snapshot_default_save()
	# -- flag off: no row, and the command is refused without a screen.
	OS.set_environment("BRUCELEE_PROGRESS", "")
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var menu = scene.get("prototype_menu")
	check(menu != null and menu.visible, "main scene opens the menu with the flag off")
	check(not (menu.main_commands() as Array).has("records"),
		"flag off: the live main menu has no RECORDS row")
	check(scene.get("progress") == null, "flag off: no progress service exists")
	check(scene.get("records_screen") == null, "flag off: no records screen exists")
	scene.call("_on_menu_command", "records")
	check(scene.get("records_screen") == null,
		"flag off: the records command cannot create a screen")
	check(String(menu.status_label.text).contains("BRUCELEE_PROGRESS"),
		"flag off: the menu explains the gate", String(menu.status_label.text))
	root.remove_child(scene)
	scene.queue_free()
	await process_frame

	# -- flag on: RECORDS row -> screen -> back to the same menu row.
	OS.set_environment("BRUCELEE_PROGRESS", "1")
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	menu = scene.get("prototype_menu")
	check(menu != null and menu.visible, "flag on: main scene opens the menu")
	check(scene.get("progress") != null, "flag on: the progress service is created")
	check(paused, "the main menu pauses the tree")
	var commands: Array = menu.main_commands()
	check(commands.has("records"), "flag on: the live main menu has the RECORDS row")
	var records_index: int = commands.find("records")
	check_eq(records_index, commands.size() - 2, "RECORDS sits before QUIT GAME")
	# Walk the real keyboard ring from VS FIGHT to RECORDS.
	menu.selected_index = 0
	for _step: int in range(records_index):
		menu.handle_input_event(_key(KEY_DOWN))
	check_eq(menu.selected_command(), "records",
		"keyboard navigation reaches RECORDS")
	menu.handle_input_event(_key(KEY_ENTER))
	await process_frame
	await process_frame
	var records = scene.get("records_screen")
	check(records != null, "ENTER on RECORDS creates the screen")
	if records == null:
		return
	check(records.is_open(), "the records screen is open")
	check(records.visible, "the records screen is visible")
	check(paused, "the tree stays paused on the records screen")
	check(not menu.is_processing_input(),
		"the menu stops taking input while records is open")
	check(records.debug_state()["rows"].size() == 38,
		"the integrated screen shows all 38 achievements")
	var save_block: Dictionary = records.debug_state()["save"]
	check(String(save_block["path"]).contains("progress_save.json"),
		"the integrated screen reads the service save path",
		String(save_block["path"]))
	# Navigation inside the integrated screen.
	records.handle_input_event(_key(KEY_DOWN))
	check_eq(records.selected_index(), 1, "the integrated screen navigates")
	# ESC closes and returns to the exact menu row.
	records.handle_input_event(_key(KEY_ESCAPE))
	await process_frame
	check(not records.is_open(), "ESC closes the integrated records screen")
	check(menu.is_processing_input(), "the menu takes input again after closing")
	check(menu.visible and String(menu.menu_state) == "main",
		"the main menu is still up behind the records screen")
	check_eq(menu.selected_command(), "records",
		"closing records restores the RECORDS row selection")
	check(menu.selected_index == records_index,
		"closing records restores the same row index")
	# Reopen: the same instance is reused, no duplicate layer.
	var first_id: int = records.get_instance_id()
	menu.handle_input_event(_key(KEY_ENTER))
	await process_frame
	check_eq(scene.get("records_screen").get_instance_id(), first_id,
		"reopening records reuses the existing screen instance")
	check(scene.get("records_screen").is_open(), "records reopens")
	# Leaving the menu dismisses the screen defensively.
	scene.call("_on_menu_command", "fight")
	await process_frame
	check(not records.is_open(), "leaving the menu closes the records screen")
	check(not paused, "starting a fight unpauses the tree")
	check(not menu.visible, "starting a fight hides the menu")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	OS.set_environment("BRUCELEE_PROGRESS", "")
	_remove(TEST_SAVE)
	_restore_default_save(default_save)

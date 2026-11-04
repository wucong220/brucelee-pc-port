extends CanvasLayer
## Opt-in Arcade / Survival / Time Attack modes for the isolated prototype.
##
## Recovered resources used (all read-only evidence on this machine):
##   game.states -> gamemodes / startarcade / starttimeattack / startsurvival
##   gui/arcadesettings.ui      -> rounds / time / difficulty
##   gui/survivalsettings.ui    -> time / difficulty
##   gui/timeattacksettings.ui  -> difficulty only
##   CBeatEmUpGameModes::StartArcade/StartSurvival/StartTimeAttack (mode ids 2/4/3)
##   libdefault.so rule functions (see game_modes_rules.gd)
##
## The mode flow does NOT duplicate the match: it writes the same BRUCELEE_*
## environment the opponent/scene menus already use, stores the pending fight in
## user:// and reloads main.tscn, exactly like story_flow.gd. main.gd reports the
## end of a match back through match_finished().
##
## Unrecovered rule values are never invented: the mode fails closed and names
## the missing field instead of guessing it.

const Rules = preload("res://scripts/game_modes_rules.gd")
const PrototypeControls = preload("res://scripts/prototype_controls.gd")
## Recovered .lang localization (display strings only; logic never reads it).
const Lang = preload("res://scripts/menu_lang.gd")

const ENV_GAME_MODE := "BRUCELEE_GAME_MODE"
const ENV_MODE_LAUNCH := "BRUCELEE_MODE_LAUNCH"
const ENV_MAIN_MENU := "BRUCELEE_MAIN_MENU"
const PENDING_PATH := "user://game_modes_pending.json"

const COLOR_BG := Color(0.035, 0.045, 0.065, 0.975)
const COLOR_TEXT := Color(0.86, 0.88, 0.92)
const COLOR_DIM := Color(0.60, 0.63, 0.68)
const COLOR_ACCENT := Color(0.98, 0.78, 0.32)
const COLOR_OK := Color(0.45, 0.85, 0.55)
const COLOR_BAD := Color(0.90, 0.42, 0.38)

var main: Node = null
var progress: Node = null
var opponent_config: Dictionary = {}
var data: Dictionary = {}
var rules_error: String = ""

var screen: String = "hidden"
var current_mode: String = "arcade"
var selection: Dictionary = {}
var settings_cursor: int = 0
var menu_cursor: int = 0
var result_cursor: int = 0
var run: Dictionary = {}
var battle_spec: Dictionary = {}
var battle_started_msec: int = 0
var last_result: Dictionary = {}
## Native CBeatEmUpGameModes::CurrentGameModeFightWon (0x1571fc) postconditions:
## game-modes byte +0x840 becomes 1 and game-modes +0x04 receives GetCurrentMili.
## The same call also passes the TFightResults snapshot to the current mode's
## virtual FightWon slot; StoryFlow owns that recovered story-mode score split.
var current_fight_won: bool = false
var current_fight_won_msec: int = -1
var current_fight_results: Dictionary = {}


var root: Control
var dim: ColorRect
var title_label: Label
var subtitle_label: Label
var body: Control
var footer_label: Label
var banner: Label
var banner_background: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 27
	_build_chrome()
	hide_all()


func configure(main_node: Node, configs: Dictionary) -> void:
	main = main_node
	opponent_config = configs


func _ensure_data() -> bool:
	if not data.is_empty():
		return true
	data = Rules.load_rules()
	if data.is_empty():
		rules_error = "game_modes.json missing or invalid"
		return false
	return true


# ----------------------------------------------------------------- entry points

## Called by main.gd once the match scene is ready.
func open_initial() -> void:
	if not _ensure_data():
		_show_error("MODE DATA ERROR", rules_error)
		return
	var mode_env: String = OS.get_environment(ENV_GAME_MODE)
	if mode_env.is_empty():
		show_mode_menu()
		return
	if OS.get_environment(ENV_MODE_LAUNCH) == "1":
		if _resume_pending():
			return
		OS.set_environment(ENV_MODE_LAUNCH, "")
	if data.get("modes", {}).has(mode_env):
		open_mode(mode_env)
	else:
		show_mode_menu()


## Entry used by the prototype menu (ARCADE / SURVIVAL / TIME ATTACK rows).
func open_mode(mode: String) -> void:
	if not _ensure_data():
		_show_error("MODE DATA ERROR", rules_error)
		return
	current_mode = mode
	selection = _default_selection(mode)
	settings_cursor = 0
	show_settings()


func _default_selection(mode: String) -> Dictionary:
	var out: Dictionary = {}
	var schema: Array = _schema(mode)
	for entry: Variant in schema:
		var row: Dictionary = entry
		out[String(row.get("key", ""))] = int(row.get("default", 0))
	return out


func _int_options(row: Dictionary) -> Array:
	var raw: Array = row.get("options", [])
	var out: Array = []
	for value: Variant in raw:
		out.append(int(value))
	return out


func _schema(mode: String) -> Array:
	var modes: Dictionary = data.get("modes", {})
	var mode_data: Dictionary = modes.get(mode, {})
	return mode_data.get("settings_schema", [])


func _mode_data(mode: String) -> Dictionary:
	return Dictionary(data.get("modes", {})).get(mode, {})


# --------------------------------------------------------------------- screens

func show_mode_menu() -> void:
	_clear_body()
	show_screen("mode")
	_set_header(Lang.text("game_modes"), "game.states: arcade / survival / timeattack", "UP/DOWN choose · J select · ESC quit")
	var rows: Array = [Lang.text("arcade"), Lang.text("survival"), Lang.text("time_attack")]
	menu_cursor = clampi(menu_cursor, 0, rows.size() - 1)
	_show_rows(rows, menu_cursor)


func show_settings() -> void:
	_clear_body()
	show_screen("settings")
	var mode_data: Dictionary = _mode_data(current_mode)
	var label: String = Lang.mode_label(current_mode)
	_set_header(label + " · " + Lang.text("settings"), "recovered gui/" + String(mode_data.get("gui_settings", "")), "UP/DOWN · LEFT/RIGHT change · J start · ESC back")
	var schema: Array = _schema(current_mode)
	var rows: Array = []
	for entry: Variant in schema:
		var row: Dictionary = entry
		var key: String = String(row.get("key", ""))
		var options: Array = _int_options(row)
		var labels: Array = row.get("labels", [])
		var value: int = int(selection.get(key, int(row.get("default", 0))))
		var idx: int = options.find(value)
		if idx < 0:
			idx = 0
		var shown: String = Lang.option_label(String(labels[idx])) if idx < labels.size() else str(value)
		rows.append("%s   < %s >" % [Lang.setting_label(String(row.get("label", key))), shown])
	rows.append("START")
	rows.append(Lang.text("back"))
	settings_cursor = clampi(settings_cursor, 0, rows.size() - 1)
	_show_rows(rows, settings_cursor)
	# Fail-closed disclosure under the choices.
	var extra: Array = []
	var resolved: Dictionary = Rules.resolve(current_mode, selection)
	for field: Variant in resolved.get("fail_closed", []):
		extra.append("FAIL CLOSED (unrecovered): " + String(field))
	if not bool(resolved.get("ok", true)):
		extra.append("CANNOT START: " + ", ".join(resolved.get("blocked", [])))
	if not extra.is_empty():
		_append_note(extra)


func show_results(outcome: String) -> void:
	_clear_body()
	show_screen("results")
	var label: String = Lang.mode_label(current_mode)
	if outcome == "complete":
		_set_header(label + " · RESULTS", "run complete", "UP/DOWN · J select · ESC main menu")
	else:
		_set_header(label + " · DEFEAT", String(last_result.get("reason", "match lost")), "UP/DOWN · J select · ESC main menu")
	var rows: Array = _summary_rows()
	rows.append("")
	rows.append(Lang.text("play"))
	rows.append(Lang.text("settings"))
	rows.append(Lang.text("main_menu"))
	result_cursor = clampi(result_cursor, 0, 2)
	var base: int = rows.size() - 3
	_show_rows(rows, -1)
	# Highlight only the three action rows.
	_highlight_action_rows(base, result_cursor)


func _summary_rows() -> Array:
	var rows: Array = []
	var resolved: Dictionary = run.get("resolved", {})
	if current_mode == "arcade":
		rows.append(_kv(Lang.text("total_score"), str(int(run.get("score", 0)))))
		rows.append(_kv(Lang.text("wins"), "%d / %d" % [
			int(run.get("fights_done", 0)), int(run.get("opponent_count", 0))]))
		rows.append(_kv("score per fight", "%d (100 + 25*%d)" % [
			int(resolved.get("score_per_fight", 0)), int(run.get("difficulty_index", 0))]))
		rows.append(_kv(Lang.text("round_number") + " / " + Lang.text("round_time"),
			"%d · %s" % [int(resolved.get("rounds", 0)),
			_time_text(int(run.get("time_limit", 0)))]))
	elif current_mode == "survival":
		rows.append(_kv("fights survived", str(int(run.get("fights_done", 0)))))
		rows.append(_kv("time per fight", _time_text(int(run.get("time_limit", 0)))))
		rows.append(_kv("max_fights", "FAIL CLOSED (unrecovered standalone)"))
		rows.append(_kv("health_recovery", "FAIL CLOSED (unrecovered standalone)"))
	else:
		rows.append(_kv(Lang.text("your_victories"), str(int(run.get("fights_done", 0)))))
		rows.append(_kv("total time limit", _time_text(int(run.get("run_time_limit", -1)))))
		rows.append(_kv(Lang.text("your_time"),
			"%.1f s" % float(run.get("elapsed_seconds", 0.0))))
	rows.append(_kv(Lang.text("difficulty_level"), "%s (ai slot %d)" % [
		_difficulty_text(int(run.get("difficulty_index", 1))),
		int(run.get("difficulty_slot", 2))]))
	return rows


## Localized difficulty word for a recovered difficulty index (0/1/2).
func _difficulty_text(index: int) -> String:
	var labels: Array = ["EASY", "MEDIUM", "HARD"]
	return Lang.option_label(String(labels[clampi(index, 0, 2)]))


## Aligned "label   value" row; the label may come from the .lang table.
func _kv(label: String, value: String) -> String:
	return "%s   %s" % [label, value]


func _time_text(seconds: int) -> String:
	if seconds <= 0:
		return Lang.text("inf")
	return str(seconds) + " s"


func show_next_fight() -> void:
	_clear_body()
	show_screen("next")
	_set_header("NEXT FIGHT", Lang.mode_label(current_mode), "J = NEXT FIGHT · ESC = PAUSE")
	var spec: Dictionary = Rules.next_fight_spec(run, opponent_config)
	var rows: Array = [
		_kv("opponent", Lang.character(String(spec.get("opponent", "")))),
		_kv("scene", String(spec.get("scene_variant", ""))),
		_kv(Lang.text("round_time"), _time_text(int(spec.get("time", 0)))),
		_kv(Lang.text("difficulty_level"), "%s (ai slot %d)" % [
			_difficulty_text(int(spec.get("difficulty_index", 1))),
			int(spec.get("difficulty_slot", 2))]),
	]
	if current_mode == "arcade":
		rows.append(_kv(Lang.text("your_score"), str(int(spec.get("score", 0)))))
	_show_rows(rows, -1)


func show_pause(return_screen: String = "battle") -> void:
	_clear_body()
	show_screen("pause")
	_set_header(Lang.text("pause"), Lang.mode_label(current_mode), "UP/DOWN · J select · ESC resume")
	var rows: Array = [Lang.text("resume"), Lang.text("main_menu")]
	result_cursor = 0
	_show_rows(rows, -1)
	_highlight_action_rows(0, result_cursor)


func hide_all() -> void:
	screen = "hidden"
	dim.visible = false
	title_label.visible = false
	subtitle_label.visible = false
	body.visible = false
	footer_label.visible = false
	banner.visible = false
	banner_background.visible = false
	if main != null and is_instance_valid(main):
		get_tree().paused = false


# ----------------------------------------------------------------- battle flow

func begin_run() -> void:
	var built: Dictionary = Rules.build_run(current_mode, selection, data)
	if not bool(built.get("ok", true)):
		_show_error("MODE BLOCKED (fail closed)",
			"unrecovered: " + ", ".join(built.get("blocked", [])))
		return
	# build_run returns the run dictionary itself (its "ok" key is part of it).
	run = built
	print("GAME_MODES_BEGIN mode=%s opponents=%d" % [current_mode, (run.get("opponents", []) as Array).size()])
	_launch_fight()


func _launch_fight() -> void:
	battle_spec = Rules.next_fight_spec(run, opponent_config)
	var opponent: String = String(battle_spec.get("opponent", ""))
	if opponent.is_empty() or not opponent_config.has(opponent):
		_show_error("MODE CONFIG ERROR", "no port candidate for opponent: " + opponent)
		return
	_apply_match_loader_env(battle_spec)
	_write_pending({"mode": current_mode, "settings": selection, "run": run})
	battle_started_msec = Time.get_ticks_msec()
	OS.set_environment(ENV_GAME_MODE, current_mode)
	OS.set_environment(ENV_MODE_LAUNCH, "1")
	show_battle_banner(battle_spec)
	get_tree().paused = false
	print("GAME_MODES_LAUNCH mode=%s opponent=%s scene=%s" % [
		current_mode, String(battle_spec.get("opponent", "")), String(battle_spec.get("scene_variant", ""))])
	call_deferred("_reload_scene")


func show_battle_banner(spec: Dictionary) -> void:
	show_screen("battle")
	var label: String = Lang.mode_label(current_mode)
	var line1: Array = [label]
	if current_mode == "arcade":
		line1.append("FIGHT %d/%d" % [int(spec.get("opponent_index", 0)) + 1, int(spec.get("opponent_count", 1))])
		line1.append("%s %d" % [Lang.text("your_score"), int(spec.get("score", 0))])
	elif current_mode == "survival":
		line1.append("fight %d" % (int(spec.get("opponent_index", 0)) + 1))
	else:
		line1.append("opponent %d" % (int(spec.get("opponent_index", 0)) + 1))
	line1.append("VS " + Lang.character(String(spec.get("opponent", ""))))
	var line2: Array = [
		String(spec.get("scene_variant", "")),
		_time_text(int(spec.get("time", 0))),
		Lang.text("difficulty_level") + " " + _difficulty_text(int(spec.get("difficulty_index", 1))),
	]
	banner.text = " · ".join(_pack(line1)) + "\n" + " · ".join(_pack(line2))


func _pack(parts: Array) -> PackedStringArray:
	var packed: PackedStringArray = PackedStringArray()
	for part: Variant in parts:
		packed.append(String(part))
	return packed


func _apply_match_loader_env(spec: Dictionary) -> void:
	OS.set_environment(ENV_GAME_MODE, current_mode)
	OS.set_environment(ENV_MAIN_MENU, "0")
	var opponent: String = String(spec.get("opponent", ""))
	var config: Dictionary = opponent_config.get(opponent, {})
	OS.set_environment("BRUCELEE_OPPONENT_GLB", String(config.get("glb", "")))
	OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", String(config.get("texture_root", "")))
	OS.set_environment("BRUCELEE_OPPONENT_CLIP_PREFIX", String(config.get("clip_prefix", "")))
	OS.set_environment("BRUCELEE_OPPONENT_MASTER", String(config.get("master", "")))
	OS.set_environment("BRUCELEE_OPPONENT_MATERIAL_PROFILE", String(config.get("material_profile", "body")))
	OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", String(config.get("attack_config", "")))
	OS.set_environment("BRUCELEE_OPPONENT_SKELETON", String(config.get("skeleton", "")))
	OS.set_environment("BRUCELEE_OPPONENT_NAME_KEY", opponent)
	OS.set_environment("BRUCELEE_SCENE", String(spec.get("scene_variant", "")))
	OS.set_environment("BRUCELEE_ROUND_TIME", str(int(spec.get("time", 0))))
	OS.set_environment("BRUCELEE_AI_DIFFICULTY", str(int(spec.get("difficulty_slot", 2))))
	OS.set_environment("BRUCELEE_MATCH_ROUNDS", str(maxi(1, int(spec.get("rounds_to_win", 1)))))
	var start_health: float = float(spec.get("start_health", -1.0))
	OS.set_environment("BRUCELEE_PLAYER_START_HEALTH", str(int(start_health)) if start_health > 0.0 else "")


func _reload_scene() -> void:
	get_tree().reload_current_scene()


## CBeatEmUpGameModes::CurrentGameModeFightWon 0x1571fc.  The native routine
## captures the current TFightResults fields and match millis, dispatches the
## mode-object vtable FightWon slot (for story: CBruceLeeStoryMode::FightWon
## 0x1e73bc), then sets +0x840 = 1 and +0x04 = GetCurrentMili().  This port
## stores the proven snapshot/timestamp and leaves the recovered story-score
## split to StoryFlow; it does not invent a replacement stats side effect.
func current_game_mode_fight_won(results: Dictionary, mode: String = "") -> void:
	current_fight_won = true
	current_fight_won_msec = Time.get_ticks_msec()
	current_fight_results = results.duplicate(true)
	var active_mode: String = mode if not mode.is_empty() else current_mode
	print("GAME_MODES_FIGHT_WON mode=%s health=%d counters=%d specials=%d endmoves=%d perfects=%d match_millis=%d" % [
		active_mode,
		int(results.get("health_remaining", -1)),
		int(results.get("counters", -1)),
		int(results.get("special_moves", -1)),
		int(results.get("ending_moves", -1)),
		int(results.get("perfects", -1)),
		int(results.get("match_millis", -1)),
	])


## main.gd calls this once a match ends.
func match_finished(won: bool) -> void:
	if run.is_empty():
		return
	var health: float = 100.0
	if main != null and is_instance_valid(main):
		var player_node: Variant = main.get("player")
		if player_node != null:
			health = float(player_node.health)
	var elapsed: float = float(Time.get_ticks_msec() - battle_started_msec) / 1000.0
	var advanced: Dictionary = Rules.apply_result(run, {"won": won, "health": health, "fight_seconds": elapsed})
	run = advanced.get("run", run)
	last_result = advanced
	# Opt-in progress hooks (no-op when BRUCELEE_PROGRESS is off): record a
	# completed arcade/time-attack run and the survival rounds survived. Only
	# recovered outcomes are granted; nothing is invented.
	if progress != null:
		_record_progress(advanced, won)
	print("GAME_MODES_RESULT mode=%s outcome=%s won=%s score=%d fights=%d" % [
		current_mode, String(advanced.get("outcome", "")), str(won),
		int(run.get("score", 0)), int(run.get("fights_done", 0))])
	if String(advanced.get("outcome", "failed")) == "next":
		_write_pending({"mode": current_mode, "settings": selection, "run": run})
		OS.set_environment(ENV_MODE_LAUNCH, "")
		show_next_fight()
	elif String(advanced.get("outcome", "failed")) == "complete":
		_clear_pending()
		OS.set_environment(ENV_MODE_LAUNCH, "")
		OS.set_environment(ENV_GAME_MODE, "")
		show_results("complete")
	else:
		_clear_pending()
		OS.set_environment(ENV_MODE_LAUNCH, "")
		OS.set_environment(ENV_GAME_MODE, "")
		show_results("failed")


func _difficulty_name() -> String:
	return ["easy", "medium", "hard"][clampi(int(run.get("difficulty_index", 1)), 0, 2)]


## Map a finished run to the recovered progress triggers.
##   arcade     : clear -> achv_arcade_{easy,medium,hard}
##   time_attack: clear -> achv_time_attack_{easy,medium,hard} (pool cleared
##                within the run time limit; time-attack is endless in the
##                recovered rules, so "clear" = every recovered opponent beaten)
##   survival   : survival_best_round = fights won (loss ends the run)
func _record_progress(advanced: Dictionary, won: bool) -> void:
	var outcome: String = String(advanced.get("outcome", "failed"))
	var difficulty: String = _difficulty_name()
	if current_mode == "survival":
		var wins: int = 0
		for row in run.get("fight_results", []):
			if bool(Dictionary(row).get("won", false)):
				wins += 1
		progress.note_survival_round(wins)
	elif current_mode == "arcade":
		if outcome == "complete":
			progress.note_mode_clear("arcade", difficulty)
	elif current_mode == "timeattack":
		if outcome == "complete":
			progress.note_mode_clear("time_attack", difficulty)
		elif outcome == "next" and won:
			var count: int = int(run.get("opponent_count", 0))
			if count > 0 and int(run.get("fights_done", 0)) >= count:
				progress.note_mode_clear("time_attack", difficulty)


func _resume_pending() -> bool:
	var pending: Dictionary = _read_pending()
	if pending.is_empty() or not pending.has("run"):
		return false
	current_mode = String(pending.get("mode", "arcade"))
	selection = pending.get("settings", _default_selection(current_mode))
	run = pending.get("run", {})
	battle_spec = Rules.next_fight_spec(run, opponent_config)
	battle_started_msec = int(pending.get("started_msec", Time.get_ticks_msec()))
	show_battle_banner(battle_spec)
	get_tree().paused = false
	print("GAME_MODES_RESUME mode=%s opponent=%s" % [current_mode, String(battle_spec.get("opponent", ""))])
	return true


# --------------------------------------------------------------------- storage

func _write_pending(payload: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(PENDING_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(payload))
	f.close()


func _read_pending() -> Dictionary:
	if not FileAccess.file_exists(PENDING_PATH):
		return {}
	var f: FileAccess = FileAccess.open(PENDING_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _clear_pending() -> void:
	if FileAccess.file_exists(PENDING_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PENDING_PATH))


# ------------------------------------------------------------------------- UI

func _build_chrome() -> void:
	root = Control.new()
	root.name = "GameModesRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	dim = ColorRect.new()
	dim.color = COLOR_BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	title_label = _make_label("", 30, COLOR_ACCENT)
	subtitle_label = _make_label("", 15, COLOR_DIM)
	column.add_child(title_label)
	column.add_child(subtitle_label)

	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)

	footer_label = _make_label("", 15, COLOR_DIM)
	column.add_child(footer_label)

	banner_background = ColorRect.new()
	banner_background.color = Color(0.02, 0.025, 0.035, 0.82)
	banner_background.position = Vector2(10, 86)
	banner_background.size = Vector2(720, 60)
	banner_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_background.visible = false
	root.add_child(banner_background)

	banner = _make_label("", 14, COLOR_ACCENT)
	banner.position = Vector2(20, 92)
	banner.visible = false
	root.add_child(banner)


func _make_label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Lang.apply_font(label)
	return label


func _clear_body() -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()


func _set_header(title: String, subtitle: String, footer: String) -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	footer_label.text = footer


func _update_footer(text: String) -> void:
	footer_label.text = text


func _append_note(lines: Array) -> void:
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(list)
	for line: Variant in lines:
		list.add_child(_make_label("  " + String(line), 13, COLOR_BAD))


var _row_nodes: Array = []

func _show_rows(rows: Array, selected: int) -> void:
	_row_nodes.clear()
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "Rows"
	list.add_theme_constant_override("separation", 3)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(list)
	for index: int in range(rows.size()):
		var text: String = String(rows[index])
		var color: Color = COLOR_DIM
		var display: String = "  " + text
		if index == selected:
			display = "> " + text
			color = COLOR_ACCENT
		elif text.begins_with("FAIL CLOSED") or text.begins_with("CANNOT START"):
			color = COLOR_BAD
		elif text == "START":
			color = COLOR_OK
		var label: Label = _make_label(display, 16, color)
		list.add_child(label)
		_row_nodes.append(label)


func _highlight_action_rows(base: int, cursor: int) -> void:
	var list: Node = body.get_node_or_null("Rows")
	if list == null:
		return
	var actions: Array = _row_nodes.slice(base)
	for i: int in range(actions.size()):
		var label: Label = actions[i]
		var text: String = String(label.text).strip_edges()
		if text == "" :
			continue
		if i == cursor:
			label.text = "> " + text
			label.add_theme_color_override("font_color", COLOR_ACCENT)
		else:
			label.text = "  " + text
			label.add_theme_color_override("font_color", COLOR_TEXT)


func show_screen(screen_name: String) -> void:
	screen = screen_name
	var visible_now: bool = screen_name != "hidden" and screen_name != "battle"
	dim.visible = visible_now
	title_label.visible = visible_now
	subtitle_label.visible = visible_now
	body.visible = visible_now
	footer_label.visible = visible_now
	banner.visible = screen_name == "battle"
	banner_background.visible = screen_name == "battle"
	if main != null and is_instance_valid(main):
		var hud_node: Variant = main.get("hud")
		if hud_node != null:
			hud_node.visible = not visible_now
	if screen_name == "battle":
		get_tree().paused = false
	else:
		get_tree().paused = visible_now


func _show_error(title: String, message: String) -> void:
	_clear_body()
	show_screen("error")
	_set_header(title, message, "J / ESC = BACK")
	_show_rows([Lang.text("back")], 0)


# ----------------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if screen == "battle" or screen == "hidden":
		return
	if not PrototypeControls.is_press_edge(event):
		return
	if event.is_action_pressed(PrototypeControls.MENU_UP):
		_move(-1)
	elif event.is_action_pressed(PrototypeControls.MENU_DOWN):
		_move(1)
	elif event.is_action_pressed(PrototypeControls.MENU_ACCEPT):
		_accept()
	elif event.is_action_pressed(PrototypeControls.MENU_CANCEL):
		_cancel()
	else:
		return
	get_viewport().set_input_as_handled()


func _move(step: int) -> void:
	match screen:
		"mode":
			menu_cursor = wrapi(menu_cursor + step, 0, 3)
			show_mode_menu()
		"settings":
			var total: int = _schema(current_mode).size() + 2
			settings_cursor = wrapi(settings_cursor + step, 0, total)
			show_settings()
		"results":
			result_cursor = wrapi(result_cursor + step, 0, 3)
			show_results(String(last_result.get("outcome", "failed")))
		"pause":
			result_cursor = wrapi(result_cursor + step, 0, 2)
			show_pause()


func _accept() -> void:
	match screen:
		"mode":
			open_mode(["arcade", "survival", "timeattack"][menu_cursor])
		"settings":
			_accept_settings()
		"results":
			_accept_results()
		"pause":
			if result_cursor == 0:
				OS.set_environment(ENV_MODE_LAUNCH, "1")
				_run_pending_or_battle()
			else:
				_return_to_main_menu()
		"next":
			OS.set_environment(ENV_MODE_LAUNCH, "1")
			_run_pending_or_battle()
		"error":
			show_mode_menu()


func _accept_settings() -> void:
	var schema: Array = _schema(current_mode)
	if settings_cursor < schema.size():
		var row: Dictionary = schema[settings_cursor]
		var key: String = String(row.get("key", ""))
		var options: Array = _int_options(row)
		if options.is_empty():
			return
		var value: int = int(selection.get(key, int(row.get("default", 0))))
		var idx: int = options.find(value)
		idx = (idx + 1) % options.size()
		selection[key] = int(options[idx])
		show_settings()
	elif settings_cursor == schema.size():
		begin_run()
	else:
		_return_to_main_menu()


func _accept_results() -> void:
	if result_cursor == 0:
		begin_run()
	elif result_cursor == 1:
		show_settings()
	else:
		_return_to_main_menu()


func _cancel() -> void:
	match screen:
		"settings", "mode":
			_return_to_main_menu()
		"results":
			_return_to_main_menu()
		"pause":
			# Resume the fight that is paused.
			OS.set_environment(ENV_MODE_LAUNCH, "1")
			_run_pending_or_battle()
		"error":
			show_mode_menu()


func _run_pending_or_battle() -> void:
	var pending: Dictionary = _read_pending()
	if pending.is_empty():
		begin_run()
		return
	OS.set_environment(ENV_GAME_MODE, current_mode)
	get_tree().reload_current_scene()


func _return_to_main_menu() -> void:
	OS.set_environment(ENV_GAME_MODE, "")
	OS.set_environment(ENV_MODE_LAUNCH, "")
	OS.set_environment(ENV_MAIN_MENU, "1")
	_clear_pending()
	get_tree().reload_current_scene()


# ------------------------------------------------------------------- debug hooks

func debug_state() -> Dictionary:
	return {
		"screen": screen,
		"mode": current_mode,
		"settings": selection.duplicate(true),
		"score": int(run.get("score", 0)),
		"fights_done": int(run.get("fights_done", 0)),
		"opponent": String(battle_spec.get("opponent", "")),
	}


func body_lines() -> Array:
	var out: Array = []
	var list: Node = body.get_node_or_null("Rows")
	if list != null:
		for child: Node in list.get_children():
			out.append(String(child.text))
	return out

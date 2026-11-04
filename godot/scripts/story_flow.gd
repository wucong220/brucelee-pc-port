extends CanvasLayer
## Minimal, faithful Story-mode flow for the isolated prototype.
##
## Screens follow the recovered story UI resources:
##   storycontinue.ui      -> NEW STORY / CONTINUE STORY
##   storynewselect.ui     -> save slot + difficulty (easy / medium / hard)
##   storymap.ui           -> chapter map, event nodes at recovered (mapx, mapy)
##   storyeventdetails.ui  -> event title, scenery, FIGHT
##   storypicture.ui       -> recovered picture subevent (text key + layers)
##   storypause.ui         -> resume / back_to_map / main_menu
##
## Battles go through the *existing* match loader in `main.gd`: this script
## writes the same BRUCELEE_* environment the opponent/scene menus write, adds
## the two match inputs the story data needs (rounds, starting health), stores
## the pending fight in the save slot and reloads main.tscn.  No fighter or
## match code is duplicated here.
##
## Localized strings (.lang) were not recovered, so every label shows the
## recovered key verbatim (e.g. `s_master_title`, `versus`).

const StoryDataScript = preload("res://scripts/story_data.gd")
const StoryStateScript = preload("res://scripts/story_state.gd")
const StoryRules = preload("res://scripts/story_rules.gd")
const PrototypeControls = preload("res://scripts/prototype_controls.gd")
const StoryLangScript = preload("res://scripts/story_lang.gd")
const StoryPictureView = preload("res://scripts/story_picture_view.gd")

const ENV_STORY_FLOW: String = "BRUCELEE_STORY_FLOW"
const ENV_STORY_LAUNCH: String = "BRUCELEE_STORY_LAUNCH"
const ENV_MAIN_MENU: String = "BRUCELEE_MAIN_MENU"

const COLOR_BG := Color(0.035, 0.045, 0.065, 0.975)
const COLOR_TEXT := Color(0.86, 0.88, 0.92)
const COLOR_DIM := Color(0.60, 0.63, 0.68)
const COLOR_ACCENT := Color(0.98, 0.78, 0.32)
const COLOR_DONE := Color(0.45, 0.85, 0.55)
const COLOR_LOCKED := Color(0.62, 0.36, 0.36)

var main: Node = null
var progress: Node = null
var opponent_config: Dictionary = {}
var data = null
var state = null
var lang = null

var screen: String = "hidden"
var error_text: String = ""

var root: Control
var dim: ColorRect
var title_label: Label
var subtitle_label: Label
var body: Control
var footer_label: Label
var banner: Label
var banner_background: ColorRect
## Draws the decoded original story/*.tex artwork for picture subevents.
var picture_view: Control

var mode_cursor: int = 0
var slot_cursor: int = 0
var difficulty_cursor: int = 0
var slot_mode: String = "new"
var map_cursor: int = 0
var map_node_rows: Array = []
var detail_event: int = 0
var playback_cursor: int = 0
var unlock_mark: int = 0
var battle_run: Dictionary = {}
var battle_spec: Dictionary = {}
var battle_started_msec: int = 0
var pause_cursor: int = 0
var pause_return: String = "battle"
var last_reward_rows: Array = []
var last_reward_already: bool = false
var last_reward_map: String = ""
var last_advanced: Dictionary = {}
var chapter_completed_now: bool = false
var story_finished: bool = false
var auto_launch_armed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 26
	_build_chrome()
	hide_all()


func configure(main_node: Node, configs: Dictionary) -> void:
	main = main_node
	opponent_config = configs


## Called by main.gd once the match scene is ready.
func open_initial(force_menu: bool = false) -> void:
	if data == null:
		data = StoryDataScript.new()
	if not data.is_loaded():
		error_text = data.error
		_show_error("STORY DATA ERROR", error_text)
		return
	if lang == null:
		lang = StoryLangScript.new()
	if state == null:
		state = StoryStateScript.new()
	if OS.get_environment(ENV_STORY_LAUNCH) == "1" and not force_menu:
		if _resume_pending_from_disk():
			return
		OS.set_environment(ENV_STORY_LAUNCH, "")
	_load_most_recent_slot()
	show_mode()


func _build_chrome() -> void:
	root = Control.new()
	root.name = "StoryFlowRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	dim = ColorRect.new()
	dim.color = COLOR_BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	picture_view = StoryPictureView.new()
	picture_view.name = "StoryPictureView"
	picture_view.visible = false
	root.add_child(picture_view)
	picture_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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

	body = Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)

	footer_label = _make_label("", 15, COLOR_DIM)
	column.add_child(footer_label)

	banner_background = ColorRect.new()
	banner_background.color = Color(0.02, 0.025, 0.035, 0.82)
	banner_background.position = Vector2(10, 86)
	banner_background.size = Vector2(640, 74)
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
	return label


func _join(parts: Array, separator: String = " · ") -> String:
	var packed: PackedStringArray = PackedStringArray()
	for part: Variant in parts:
		packed.append(String(part))
	return separator.join(packed)


func _clear_body() -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	map_node_rows.clear()


func _set_header(title: String, subtitle: String, footer: String) -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	footer_label.text = footer


func _show_rows(rows: Array, selected: int) -> void:
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(list)
	for index: int in range(rows.size()):
		var text: String = String(rows[index])
		var color: Color = COLOR_DIM
		if index == selected:
			text = "> " + text
			color = COLOR_ACCENT
		else:
			if text.begins_with("    "):
				text = "    " + text.strip_edges()
			else:
				text = "  " + text
			if text.contains("LOCKED") or text.contains("requires "):
				color = COLOR_LOCKED
			elif text.contains("[x]"):
				color = COLOR_DONE
			elif text.begins_with("  BATTLE") or text.begins_with("  REWARDS") \
					or text.begins_with("  UNLOCK") or text.begins_with("  FIGHT"):
				color = COLOR_TEXT
		list.add_child(_make_label(text, 16, color))


## Compact layer listing drawn as a faint overlay above the decoded artwork.
func _show_rows_compact(rows: Array) -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.01, 0.015, 0.025, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.size = Vector2(770, rows.size() * 15 + 10)
	body.add_child(backdrop)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.modulate = Color(1, 1, 1, 0.92)
	body.add_child(list)
	for index: int in range(rows.size()):
		var label: Label = _make_label(String(rows[index]), 11,
			COLOR_TEXT if index == 0 else COLOR_DIM)
		list.add_child(label)


func show_screen(screen_name: String) -> void:
	screen = screen_name
	var visible_now: bool = screen_name != "hidden" and screen_name != "battle"
	var picture_now: bool = screen_name == "picture"
	if picture_view != null:
		picture_view.visible = picture_now
		if not picture_now:
			picture_view.call("hide_caption")
	# The picture screen lets the decoded artwork own the background; the dark
	# story chrome dim is suppressed so the original art is not tinted.
	dim.visible = visible_now and not picture_now
	title_label.visible = visible_now
	subtitle_label.visible = visible_now
	body.visible = visible_now
	footer_label.visible = visible_now
	banner.visible = screen_name == "battle"
	banner_background.visible = screen_name == "battle"
	# The fight HUD belongs to the match; story screens cover it completely.
	if main != null:
		var hud_node: Variant = main.get("hud")
		if hud_node != null:
			hud_node.visible = not visible_now
	get_tree().paused = visible_now


func hide_all() -> void:
	screen = "hidden"
	dim.visible = false
	if picture_view != null:
		picture_view.visible = false
		picture_view.call("hide_caption")
	title_label.visible = false
	subtitle_label.visible = false
	body.visible = false
	footer_label.visible = false
	banner.visible = false
	banner_background.visible = false
	get_tree().paused = false


func _show_error(title: String, message: String) -> void:
	_clear_body()
	show_screen("error")
	_set_header(title, message, "J / ESC = BACK")
	_show_rows(["story data: res://data/story/story_mode.json"], 0)


# ---------------------------------------------------------------- title screens


func show_mode() -> void:
	_clear_body()
	show_screen("mode")
	_set_header("STORY MODE", "storycontinue.ui · story_mode", "J = SELECT · ESC = QUIT")
	var rows: Array = ["NEW STORY", "CONTINUE STORY"]
	var overview: Array = StoryStateScript.slots_overview(data.difficulty_slot_names())
	var any_save: bool = false
	for row: Variant in overview:
		if bool(Dictionary(row).get("exists", false)):
			any_save = true
	if not any_save:
		rows.append("(no save slot recorded yet)")
	mode_cursor = clampi(mode_cursor, 0, 1)
	_show_rows(rows, mode_cursor)


func show_slot_select(mode: String) -> void:
	_clear_body()
	slot_mode = mode
	show_screen("slot")
	var names: Array = data.difficulty_slot_names()
	var overview: Array = StoryStateScript.slots_overview(names)
	var rows: Array = []
	for row: Variant in overview:
		var entry: Dictionary = row
		var slot: int = int(entry.get("slot", 1))
		if bool(entry.get("exists", false)):
			rows.append("slot_%d  chapter %d · %s · exp %d · %d events · %d unlocks" % [
				slot,
				int(entry.get("chapter_index", 0)) + 1,
				String(entry.get("difficulty_name", "?")).to_upper(),
				int(entry.get("exp", 0)),
				int(entry.get("completed", 0)),
				int(entry.get("unlocks", 0)),
			])
		else:
			if mode == "continue":
				rows.append("slot_%d  (empty)" % slot)
			else:
				rows.append("slot_%d  (empty · new game starts here)" % slot)
	_set_header(
		"NEW STORY" if mode == "new" else "CONTINUE STORY",
		"storynewselect.ui · select_save_slot · 3 slots",
		"J = SELECT · ESC = BACK"
	)
	slot_cursor = clampi(slot_cursor, 0, StoryStateScript.SLOT_COUNT - 1)
	_show_rows(rows, slot_cursor)


func show_difficulty() -> void:
	_clear_body()
	show_screen("difficulty")
	var names: Array = data.difficulty_slot_names()
	var rows: Array = []
	for index: int in range(names.size()):
		rows.append("%s   (difficulty[%d] of every battle)" % [
			String(names[index]).to_upper(), index,
		])
	_set_header(
		"NEW STORY · SLOT %d" % (slot_cursor + 1),
		"storynewselect.ui · difficulty_level → easy / medium / hard",
		"J = START · ESC = BACK"
	)
	difficulty_cursor = clampi(difficulty_cursor, 0, maxi(0, names.size() - 1))
	_show_rows(rows, difficulty_cursor)


# ------------------------------------------------------------------- story map


func show_map() -> void:
	print("STORY_FLOW_MAP")
	if main != null and main.has_method("play_map_music"):
		main.play_map_music()
	_clear_body()
	show_screen("map")
	if state == null:
		return
	var chapter_index: int = clampi(state.chapter_index, 0, data.chapter_count() - 1)
	var chapter_id: String = data.chapter_id(chapter_index)
	var event_rows: Array = data.events(chapter_index)
	var completed: Array = state.completed_list(chapter_id)
	var done: int = state.chapter_completed_count(chapter_id, event_rows)
	_set_header(
		lang.text(data.chapter_title_key(chapter_index)),
		"CHAPTER %d/%d · %d/%d EVENTS · EXP %d · %s" % [
			chapter_index + 1, data.chapter_count(), done, event_rows.size(),
			state.exp, String(state.difficulty_name).to_upper(),
		],
		"ARROWS = MOVE · J = EVENT DETAILS · TAB = RECORDS · ESC = MODE"
	)
	var canvas: Control = Control.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(canvas)
	# mapx/mapy are drawn in the decoded 480x320 space (the exact original
	# on-screen scale was not recovered) fitted into the 1188x470 panel.
	var scale_x: float = 900.0 / 480.0
	var scale_y: float = 460.0 / 320.0
	var label_width: float = 205.0
	var used_positions: Array = []
	for index: int in range(event_rows.size()):
		var event_row: Dictionary = event_rows[index]
		var gate: Dictionary = StoryRules.event_gate(event_row, completed, state.exp)
		var is_done: bool = state.is_event_completed(chapter_id, String(event_row.get("maptitle", "")))
		var prefix: String = "  "
		var color: Color = COLOR_DIM
		if is_done:
			prefix = "[x] "
			color = COLOR_DONE
		elif not bool(gate.get("available", true)):
			prefix = "LOCKED "
			color = COLOR_LOCKED
		var marker: String = ""
		if String(event_row.get("auto_launch", "")).to_lower() == "true":
			marker = " ·AUTO"
		if String(event_row.get("chapter_end", "")).to_lower() == "true":
			marker += " ·END"
		var base_text: String = "%s%s%s" % [
			prefix, lang.text(String(event_row.get("maptitle", ""))), marker,
		]
		var label: Label = _make_label(base_text, 14, color)
		# Several recovered events share one (mapx, mapy); stack the labels so the
		# decoded positions stay unchanged but every node stays readable.
		var slot_position: Vector2 = Vector2(
			float(int(event_row.get("mapx", 0))) * scale_x,
			float(int(event_row.get("mapy", 0))) * scale_y
		)
		# Several recovered events share one (mapx, mapy); stack the labels so the
		# decoded positions stay unchanged but every node stays readable.
		var candidates: Array = [
			Vector2(0, 0), Vector2(0, 24), Vector2(0, 48), Vector2(0, 72),
			Vector2(210, 0), Vector2(-210, 0), Vector2(210, 24), Vector2(-210, 24),
		]
		var final_position: Vector2 = slot_position
		for candidate: Variant in candidates:
			var proposed: Vector2 = slot_position + Vector2(candidate)
			proposed.x = clampf(proposed.x, 0.0, 1188.0 - label_width)
			if not _map_position_used(used_positions, proposed):
				final_position = proposed
				break
		used_positions.append(final_position)
		label.position = final_position
		label.size = Vector2(label_width, 24)
		canvas.add_child(label)
		map_node_rows.append({
			"index": index,
			"position": final_position + Vector2(0, 12),
			"label": label,
			"base_text": base_text,
			"available": bool(gate.get("available", true)),
			"completed": is_done,
		})
	if map_node_rows.is_empty():
		return
	map_cursor = clampi(map_cursor, 0, map_node_rows.size() - 1)
	_refresh_map_selection()
	if not auto_launch_armed:
		return
	auto_launch_armed = false
	for row: Variant in map_node_rows:
		var entry: Dictionary = row
		var event_row: Dictionary = event_rows[int(entry.get("index", 0))]
		if (not bool(entry.get("completed", false))
				and bool(entry.get("available", true))
				and String(event_row.get("auto_launch", "")).to_lower() == "true"):
			map_cursor = int(entry.get("index", 0))
			_refresh_map_selection()
			print("STORY_FLOW_AUTOLAUNCH %s" % String(event_row.get("maptitle", "")))
			show_detail(map_cursor)
			return


func _map_position_used(used: Array, position: Vector2) -> bool:
	for entry: Variant in used:
		var other: Vector2 = Vector2(entry)
		if absf(other.x - position.x) < 200.0 and absf(other.y - position.y) < 20.0:
			return true
	return false


func _refresh_map_selection() -> void:
	for row: Variant in map_node_rows:
		var entry: Dictionary = row
		var label: Label = entry.get("label") as Label
		if label == null:
			continue
		var base_text: String = String(entry.get("base_text", ""))
		if int(entry.get("index", -1)) == map_cursor:
			label.text = "> " + base_text
			label.add_theme_color_override("font_color",
				COLOR_ACCENT if bool(entry.get("available", true)) else COLOR_LOCKED)
		else:
			label.text = base_text
			label.add_theme_color_override("font_color",
				COLOR_DONE if bool(entry.get("completed", false))
				else (COLOR_DIM if bool(entry.get("available", true)) else COLOR_LOCKED))


func _map_move(direction: Vector2) -> void:
	if map_node_rows.is_empty():
		return
	var current: Vector2 = map_node_rows[map_cursor]["position"]
	var best: int = -1
	var best_distance: float = INF
	for index: int in range(map_node_rows.size()):
		if index == map_cursor:
			continue
		var delta: Vector2 = Vector2(map_node_rows[index]["position"]) - current
		if delta.length() < 0.001 or delta.normalized().dot(direction) < 0.35:
			continue
		if delta.length() < best_distance:
			best_distance = delta.length()
			best = index
	if best >= 0:
		map_cursor = best
		_refresh_map_selection()


# --------------------------------------------------------------- event details


func show_detail(event_index: int) -> void:
	if state == null:
		return
	_clear_body()
	show_screen("detail")
	detail_event = clampi(event_index, 0, data.events(state.chapter_index).size() - 1)
	var chapter_id: String = data.chapter_id(state.chapter_index)
	var event_row: Dictionary = data.event(state.chapter_index, detail_event)
	var completed: Array = state.completed_list(chapter_id)
	var gate: Dictionary = StoryRules.event_gate(event_row, completed, state.exp)
	var battle_rows: Array = data.battle_subs(event_row)
	var unlock_rows: Array = data.unlock_subs(event_row)
	var picture_rows: Array = data.picture_subs(event_row)
	var gate_bits: Array = ["required_exp %d" % int(gate.get("required_exp", 0))]
	var missing: Array = gate.get("missing", [])
	if not missing.is_empty():
		gate_bits.append("after " + _join(missing, ", "))
	if event_row.has("auto_launch"):
		gate_bits.append("auto_launch " + String(event_row["auto_launch"]))
	if event_row.has("chapter_end"):
		gate_bits.append("chapter_end " + String(event_row["chapter_end"]))
	_set_header(
		"%s   [%s]" % [lang.text(String(event_row.get("maptitle", ""))), String(event_row.get("type", ""))],
		"mapx %d · mapy %d · %s · %d subevents: %d picture · %d battle · %d unlock" % [
			int(event_row.get("mapx", 0)), int(event_row.get("mapy", 0)),
			_join(gate_bits), data.subevents(event_row).size(),
			picture_rows.size(), battle_rows.size(), unlock_rows.size(),
		],
		"J = BEGIN PLAYBACK · ESC = MAP"
	)
	var rows: Array = []
	if not bool(gate.get("available", true)):
		rows.append("LOCKED · " + String(gate.get("reason", "")))
	for index: int in range(battle_rows.size()):
		var sub: Dictionary = battle_rows[index]
		var scenery: Dictionary = data.scenery_row(String(sub.get("scenery", "")))
		var variant: String = String(scenery.get("port_scene_variant", ""))
		rows.append("BATTLE %d · %s" % [index + 1, String(sub.get("type", "")).to_upper()])
		if sub.has("opponent"):
			var opponent: String = String(sub["opponent"])
			rows.append("    opponent   %s → candidate %s" % [
				opponent,
				String(data.character_row(opponent).get("port_candidate", "?")),
			])
		if sub.has("opponents"):
			var parts: Array = []
			for name: Variant in sub["opponents"]:
				parts.append("%s → %s" % [
					String(name),
					String(data.character_row(String(name)).get("port_candidate", "?")),
				])
			rows.append("    opponents  " + _join(parts, ", "))
		rows.append("    player     %s (single port candidate)" % String(sub.get("player", "")))
		rows.append("    scenery    %s [%s] → BRUCELEE_SCENE '%s'" % [
			String(sub.get("scenery", "")),
			lang.text(String(scenery.get("translate_name", ""))),
			variant if not variant.is_empty() else "(default)",
		])
		if sub.has("rounds"):
			rows.append("    rounds     %d" % int(sub["rounds"]))
		if sub.has("time"):
			rows.append("    time       %d s" % int(sub["time"]))
		if sub.has("time_limit"):
			rows.append("    time_limit %d s" % int(sub["time_limit"]))
		if sub.has("maximum_fights"):
			rows.append("    max_fights %d" % int(sub["maximum_fights"]))
		if sub.has("health_recovery"):
			rows.append("    health_recovery %d" % int(sub["health_recovery"]))
		if sub.has("player_starting_health"):
			rows.append("    player_starting_health %d" % int(sub["player_starting_health"]))
		var difficulty: Array = data.difficulty_values(sub)
		var names: Array = data.difficulty_slot_names()
		var picked: Array = []
		for slot: int in range(difficulty.size()):
			var mark: String = "*" if slot == state.difficulty_slot else ""
			picked.append("%s %d%s" % [
				String(names[slot]).substr(0, 1).to_upper(), int(difficulty[slot]), mark,
			])
		rows.append("    difficulty %s → selected value %d" % [
			_join(picked, " "), data.difficulty_value(sub, state.difficulty_slot),
		])
		if sub.has("advice"):
			rows.append("    advice     " + lang.text(String(sub["advice"])))
		if sub.has("aitree"):
			rows.append("    aitree     " + String(Dictionary(sub["aitree"]).get("file", "")))
		var flags: Array = []
		for flag: String in ["win_on_lose", "player_infinite_rage", "opponent_infinite_rage"]:
			if sub.has(flag):
				flags.append("%s %s" % [flag, String(sub[flag])])
		if not flags.is_empty():
			rows.append("    flags      " + _join(flags, ", "))
	if not unlock_rows.is_empty():
		rows.append("REWARDS · %d unlock subevents" % unlock_rows.size())
		for sub: Variant in unlock_rows:
			rows.append("    unlock %s · %s %s" % [
				str(Dictionary(sub).get("id", "")),
				String(Dictionary(sub).get("item_type", "")),
				str(Dictionary(sub).get("item_id", "")),
			])
	_show_rows(rows, -1)


# ------------------------------------------------------------------- playback


func begin_playback() -> void:
	if state == null:
		return
	unlock_mark = state.unlocks.size()
	playback_cursor = 0
	chapter_completed_now = false
	print("STORY_FLOW_PLAYBACK %s/%s" % [
		data.chapter_id(state.chapter_index),
		String(data.event(state.chapter_index, detail_event).get("maptitle", "")),
	])
	_play_from(0)


func _play_from(start_index: int) -> void:
	var event_row: Dictionary = data.event(state.chapter_index, detail_event)
	var subs: Array = data.subevents(event_row)
	var index: int = start_index
	while index < subs.size():
		var sub: Dictionary = subs[index]
		var kind: String = String(sub.get("type", ""))
		if kind == "picture":
			show_picture(index)
			return
		if kind == "unlock":
			state.add_unlock(
				int(sub.get("id", -1)),
				String(sub.get("item_type", "")),
				sub.get("item_id", 0),
				data.chapter_id(state.chapter_index),
				String(event_row.get("maptitle", "")),
				index
			)
			index += 1
			continue
		if kind in StoryRules.BATTLE_TYPES:
			_start_battle(sub, index)
			return
		index += 1
	_finish_event()


func show_picture(sub_index: int) -> void:
	_clear_body()
	show_screen("picture")
	var event_row: Dictionary = data.event(state.chapter_index, detail_event)
	var subs: Array = data.subevents(event_row)
	var index: int = clampi(sub_index, 0, subs.size() - 1)
	var sub: Dictionary = subs[index]
	playback_cursor = index
	if sub.has("music") and main != null and main.has_method("play_story_music"):
		var story_track: String = String(Dictionary(sub["music"]).get("file", ""))
		if not story_track.is_empty():
			main.play_story_music(story_track)
	_set_header(
		"%s · picture %d/%d" % [
			lang.text(String(event_row.get("maptitle", ""))), index + 1, subs.size(),
		],
		"storypicture.ui · text '%s'" % lang.text(String(sub.get("text", ""))),
		"J = NEXT · ESC = PAUSE"
	)
	var rows: Array = []
	if sub.has("music"):
		rows.append("music   " + String(Dictionary(sub["music"]).get("file", "")))
	var layers: Array = sub.get("layers", [])
	var render_report: Dictionary = {}
	if picture_view != null:
		render_report = picture_view.call("render", sub)
	rows.append("layers  %d  ·  bound %d  ·  missing %d" % [
		layers.size(), int(render_report.get("loaded", 0)),
		(render_report.get("missing", []) as Array).size(),
	])
	for layer_index: int in range(layers.size()):
		var layer: Dictionary = layers[layer_index]
		var picture_file: String = String(Dictionary(layer.get("picture", {})).get("file", ""))
		var bits: Array = [picture_file]
		for key: String in ["x", "y", "scale", "color", "alpha"]:
			if layer.has(key):
				bits.append("%s %s" % [key, str(layer[key])])
		rows.append("    layer %d  %s" % [layer_index, _join(bits, " · ")])
	_show_rows_compact(rows)


func _advance_picture() -> void:
	_play_from(playback_cursor + 1)


func _start_battle(sub: Dictionary, sub_index: int) -> void:
	var event_row: Dictionary = data.event(state.chapter_index, detail_event)
	battle_run = StoryRules.build_run(
		data.chapter_id(state.chapter_index), event_row, sub, sub_index,
		state.difficulty_slot, data.difficulty_value(sub, state.difficulty_slot)
	)
	_launch_fight()


func _launch_fight() -> void:
	var spec: Dictionary = StoryRules.next_fight_spec(data, battle_run)
	battle_spec = spec
	if String(spec.get("opponent", "")).is_empty() \
			or String(spec.get("port_candidate", "")).is_empty():
		_show_error("BATTLE CONFIG ERROR",
			"no recovered port candidate for opponent: " + String(spec.get("opponent", "")))
		return
	apply_match_loader_env(spec)
	battle_started_msec = Time.get_ticks_msec()
	state.set_pending({
		"run": battle_run,
		"spec": spec,
		"started_msec": battle_started_msec,
		"save_slot": state.save_slot,
		"chapter_index": state.chapter_index,
		"event_index": detail_event,
		"unlock_mark": unlock_mark,
	})
	if not state.save():
		_show_error("SAVE ERROR", state.error_msg)
		return
	OS.set_environment(ENV_STORY_LAUNCH, "1")
	show_screen("battle")
	banner.text = _battle_banner(spec)
	get_tree().paused = false
	print("STORY_FLOW_LAUNCH " + JSON.stringify(spec))
	call_deferred("_reload_scene")


func _battle_banner(spec: Dictionary) -> String:
	var line1: Array = [
		String(spec.get("event", "")),
		String(spec.get("kind", "")).to_upper(),
	]
	var fight: String = ""
	if int(spec.get("opponent_count", 1)) > 1:
		fight = " %d/%d" % [
			int(spec.get("opponent_index", 0)) + 1, int(spec.get("opponent_count", 1)),
		]
	line1.append("VS " + String(spec.get("opponent", "")).to_upper() + fight)
	var line2: Array = [String(spec.get("scenery", ""))]
	if int(spec.get("rounds", -1)) > 0:
		line2.append("rounds %d" % int(spec["rounds"]))
	line2.append("time %d s" % int(spec["time"]) if int(spec.get("time", 0)) > 0 else "time none")
	line2.append("difficulty[%d]=%d" % [
		int(spec.get("difficulty_slot", 0)), int(spec.get("difficulty_value", -1)),
	])
	if float(spec.get("start_health", -1.0)) > 0.0:
		line2.append("start health %d" % int(spec["start_health"]))
	var line3: Array = [
		"BRUCELEE_SCENE '" + String(spec.get("scene_variant", "")) + "'",
		"candidate " + String(spec.get("port_candidate", "")),
	]
	return _join(line1) + "\n" + _join(line2) + "\n" + _join(line3)


func apply_match_loader_env(spec: Dictionary) -> void:
	## Public so tests can check the exact environment handoff.
	OS.set_environment(ENV_STORY_FLOW, "1")
	OS.set_environment(ENV_MAIN_MENU, "0")
	var candidate: String = String(spec.get("port_candidate", ""))
	var config: Dictionary = opponent_config.get(candidate, {})
	OS.set_environment("BRUCELEE_OPPONENT_GLB", String(config.get("glb", "")))
	OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", String(config.get("texture_root", "")))
	OS.set_environment("BRUCELEE_OPPONENT_CLIP_PREFIX", String(config.get("clip_prefix", "")))
	OS.set_environment("BRUCELEE_OPPONENT_MASTER", String(config.get("master", "")))
	OS.set_environment("BRUCELEE_OPPONENT_MATERIAL_PROFILE",
		String(config.get("material_profile", "body")))
	OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", String(config.get("attack_config", "")))
	OS.set_environment("BRUCELEE_OPPONENT_SKELETON", String(config.get("skeleton", "")))
	OS.set_environment("BRUCELEE_OPPONENT_NAME_KEY", candidate)
	OS.set_environment("BRUCELEE_SCENE", String(spec.get("scene_variant", "")))
	OS.set_environment("BRUCELEE_ROUND_TIME", str(int(spec.get("time", 0))))
	OS.set_environment("BRUCELEE_AI_DIFFICULTY", str(int(spec.get("difficulty_value", 2))))
	var rounds: int = int(spec.get("rounds", -1))
	OS.set_environment("BRUCELEE_MATCH_ROUNDS",
		str(rounds) if rounds > 0 else str(StoryRules.DEFAULT_ROUNDS_TO_WIN))
	var start_health: float = float(spec.get("start_health", -1.0))
	OS.set_environment("BRUCELEE_PLAYER_START_HEALTH",
		str(int(start_health)) if start_health > 0.0 else "")


func _reload_scene() -> void:
	get_tree().reload_current_scene()


func _resume_pending_from_disk() -> bool:
	for slot: int in range(1, StoryStateScript.SLOT_COUNT + 1):
		var raw: Dictionary = StoryStateScript.read_slot(slot)
		if raw.is_empty():
			continue
		var pending: Variant = raw.get("pending", {})
		if not pending is Dictionary or (pending as Dictionary).is_empty():
			continue
		if not state.load_slot(slot):
			continue
		if not _resume_pending_battle():
			continue
		print("STORY_FLOW_RESUME slot=%d %s" % [slot, String(state.pending.get("spec", {}).get("event", ""))])
		return true
	return false


func _resume_pending_battle() -> bool:
	var pending: Dictionary = state.pending
	if pending.is_empty() or not pending.has("run") or not pending.has("spec"):
		return false
	battle_run = pending.get("run", {})
	battle_spec = pending.get("spec", {})
	battle_started_msec = int(pending.get("started_msec", Time.get_ticks_msec()))
	detail_event = int(pending.get("event_index", 0))
	unlock_mark = int(pending.get("unlock_mark", 0))
	show_screen("battle")
	banner.text = _battle_banner(battle_spec)
	return true


# --------------------------------------------------------------- story EXP
# Exact native model: FightBaseScore 0x1e46b4, FightWon 0x1e73bc,
# StoryEventCompletionBonus 0x1e47a8.  D = 0 easy / 1 medium / 2 hard.


static func _story_exp_fight_base(kind: String, difficulty: int) -> int:
	match kind:
		"vsbattle", "timeattack":
			return 25 * difficulty + 100
		"survival":
			return 15 * difficulty + 125
		"arcade":
			return 25 * difficulty + 75
		_:
			return 0


static func _story_exp_completion_bonus(kind: String, difficulty: int) -> int:
	# Native HasStoryModeSubEventScoreSummary 0x1e45c0 returns false for
	# vsbattle, so only these three kinds reach StorySubEventComplete.
	match kind:
		"survival":
			return 25 * difficulty + 150
		"timeattack":
			return 25 * difficulty + 125
		"arcade":
			return 25 * difficulty + 250
		_:
			return 0


func _story_exp_move_stats() -> Dictionary:
	# Native TFightResults +0x04..+0x10 (counter / special / endmove presence
	# flags and the player's perfect-round count).  They are read back from the
	# live fighter's recovered animation-category record
	# (CFighter::GetAnmCategory 0x1a6d50), which only main.gd can observe; an
	# absent match means the values were not measured and the award stays partial.
	if main == null or not main.has_method("get_fight_results"):
		return {}
	var results: Dictionary = main.get_fight_results()
	return {
		"counters": int(results.get("counters", 0)),
		"special_moves": int(results.get("special_moves", 0)),
		"ending_moves": int(results.get("ending_moves", 0)),
		"perfects": int(results.get("perfects", 0)),
	}


static func story_exp_fight_score(
		kind: String, difficulty: int, health: int,
		move_stats: Dictionary, remaining_seconds: int = -1) -> int:
	## CBruceLeeStoryMode::FightWon 0x1e73bc, verbatim:
	##   vsbattle / arcade: base + (D+1)*health + 10*(counters+specials)
	##                      + 15*endmoves + 20*perfects
	##   survival:          base + (D+1)*health
	##   timeattack:        base + (D+2) * remaining seconds
	##   any other kind:    0
	var base: int = _story_exp_fight_base(kind, difficulty)
	match kind:
		"vsbattle", "arcade":
			return base + (difficulty + 1) * health \
				+ 10 * (int(move_stats.get("counters", 0))
					+ int(move_stats.get("special_moves", 0))) \
				+ 15 * int(move_stats.get("ending_moves", 0)) \
				+ 20 * int(move_stats.get("perfects", 0))
		"survival":
			return base + (difficulty + 1) * health
		"timeattack":
			return base + (difficulty + 2) * maxi(0, remaining_seconds)
		_:
			return 0


func _award_story_exp(won: bool, health: float, elapsed: float, outcome: String) -> void:
	if state == null:
		return
	var kind: String = String(battle_run.get("kind", ""))
	var win_on_lose: bool = String(battle_run.get("win_on_lose", "")).to_lower() == "true"
	var difficulty: int = clampi(int(state.difficulty_slot), 0, 2)
	if not (won or win_on_lose):
		return
	var stats: Dictionary = _story_exp_move_stats()
	var partial: bool = kind in ["vsbattle", "arcade"] and stats.is_empty()
	var remaining: int = -1
	if kind == "timeattack":
		var limit: int = int(battle_run.get("time_limit", 0))
		remaining = maxi(0, limit - int(round(elapsed)))
	var amount: int = story_exp_fight_score(
		kind, difficulty, int(round(health)), stats, remaining
	)
	if outcome == "complete":
		amount += _story_exp_completion_bonus(kind, difficulty)
	if amount <= 0:
		return
	var total: int = state.add_exp(amount)
	print("STORY_FLOW_EXP +%d kind=%s difficulty=%d health=%d outcome=%s total=%d counters=%d specials=%d endmoves=%d perfects=%d partial=%s" % [
		amount, kind, difficulty, int(round(health)), outcome, total,
		int(stats.get("counters", 0)), int(stats.get("special_moves", 0)),
		int(stats.get("ending_moves", 0)), int(stats.get("perfects", 0)),
		str(partial),
	])


func current_battle_win_on_lose() -> bool:
	## The recovered krm::CBruceLeeStoryMode::StoryCurrentFightWinOnLose() flag
	## for the battle that is running.  story_rules.gd reads the same
	## `win_on_lose` field; main.gd uses this to decide whether a lost story
	## fight enters SetState(14) (false) or keeps its win-on-lose advance (true).
	return String(battle_run.get("win_on_lose", "")).to_lower() == "true"


func match_finished(won: bool) -> void:
	if state == null or not state.has_pending():
		return
	var elapsed: float = float(Time.get_ticks_msec() - battle_started_msec) / 1000.0
	var health: float = 100.0
	if main != null:
		var player_node: Variant = main.get("player")
		if player_node != null:
			health = float(player_node.health)
	var advanced: Dictionary = StoryRules.apply_result(battle_run, {
		"won": won, "health": health, "fight_seconds": elapsed,
	})
	battle_run = advanced.get("run", battle_run)
	last_advanced = advanced
	state.add_record({
		"chapter": data.chapter_id(state.chapter_index),
		"event": String(battle_run.get("event", "")),
		"kind": String(battle_run.get("kind", "")),
		"opponent": String(battle_spec.get("opponent", "")),
		"won": won,
		"health": health,
		"seconds": elapsed,
		"difficulty_value": int(battle_spec.get("difficulty_value", -1)),
	})
	var outcome: String = String(advanced.get("outcome", "failed"))
	print("STORY_FLOW_RESULT outcome=%s won=%s event=%s" % [
		outcome, str(won), String(battle_run.get("event", "")),
	])
	_award_story_exp(won, health, elapsed, outcome)
	if outcome == "next":
		state.set_pending({
			"run": battle_run,
			"spec": battle_spec,
			"started_msec": Time.get_ticks_msec(),
			"save_slot": state.save_slot,
			"chapter_index": state.chapter_index,
			"event_index": detail_event,
			"unlock_mark": unlock_mark,
		})
		state.save()
		show_next_fight(advanced)
		return
	state.clear_pending()
	state.save()
	if outcome == "complete":
		_play_from(int(battle_run.get("sub_index", 0)) + 1)
		return
	show_defeat(advanced)


func show_next_fight(advanced: Dictionary) -> void:
	_clear_body()
	show_screen("next_fight")
	pause_return = "next_fight"
	var run: Dictionary = advanced.get("run", {})
	var spec: Dictionary = StoryRules.next_fight_spec(data, run)
	var reason: String = String(advanced.get("reason", ""))
	_set_header(
		"%s · FIGHT %d/%d" % [
			String(spec.get("event", "")),
			int(spec.get("opponent_index", 0)) + 1,
			int(spec.get("opponent_count", 1)),
		],
		"%s · %s · carried health %s%s" % [
			String(spec.get("kind", "")).to_upper(),
			String(spec.get("scenery", "")),
			("full" if float(spec.get("start_health", -1.0)) < 0.0
				else str(int(spec["start_health"]))),
			(" · " + reason) if not reason.is_empty() else "",
		],
		"J = NEXT FIGHT · ESC = PAUSE"
	)
	var rows: Array = []
	rows.append("next opponent  %s → candidate %s" % [
		String(spec.get("opponent", "")), String(spec.get("port_candidate", "")),
	])
	if int(spec.get("health_recovery", -1)) > 0:
		rows.append("health_recovery %d applied between fights" % int(spec["health_recovery"]))
	rows.append("difficulty value %d · rounds %s · time %s" % [
		int(spec.get("difficulty_value", -1)),
		("none" if int(spec.get("rounds", -1)) < 0 else str(int(spec["rounds"]))),
		("none" if int(spec.get("time", 0)) <= 0 else str(int(spec["time"])) + " s"),
	])
	_show_rows(rows, -1)


func show_defeat(advanced: Dictionary) -> void:
	_clear_body()
	show_screen("defeat")
	pause_return = "defeat"
	var run: Dictionary = advanced.get("run", {})
	_set_header(
		"DEFEAT · " + String(run.get("event", "")),
		String(advanced.get("reason", "match lost")),
		"J = BACK TO MAP"
	)
	_show_rows([
		"the event is not completed; no unlock of this event was recorded",
		"fights done %d · carried health %s" % [
			int(run.get("fights_done", 0)),
			("full" if float(run.get("carried_health", -1.0)) < 0.0
				else str(int(run["carried_health"]))),
		],
	], -1)


func _finish_event() -> void:
	var event_row: Dictionary = data.event(state.chapter_index, detail_event)
	var chapter_id: String = data.chapter_id(state.chapter_index)
	var maptitle: String = String(event_row.get("maptitle", ""))
	var already: bool = state.is_event_completed(chapter_id, maptitle)
	state.mark_completed(chapter_id, maptitle)
	chapter_completed_now = false
	story_finished = false
	if String(event_row.get("chapter_end", "")).to_lower() == "true":
		chapter_completed_now = state.advance_chapter(data.chapter_count())
		story_finished = not chapter_completed_now
		auto_launch_armed = true
	# Opt-in progress hooks (no-op when BRUCELEE_PROGRESS is off): grant the
	# recovered event unlocks, count the chapter on its chapter_end event, and
	# record full-story difficulty completion on the final chapter. EXP is synced
	# after the per-fight accrual above, which is also where the native engine
	# runs the EXP unlock table (CBruceLeeStoryMode::StoryCurrentEventComplete
	# 0x1f4c24 -> CUnlocker::CheckStoryUnlocks(slot exp)). All calls are
	# idempotent for replayed events.
	if progress != null:
		progress.sync_story_exp(int(state.exp))
		progress.note_story_event(chapter_id, maptitle)
		if chapter_completed_now or story_finished:
			progress.note_story_chapter(chapter_id)
		if story_finished:
			progress.note_story_complete(String(state.difficulty_name))
	state.save()
	print("STORY_FLOW_EVENT_DONE %s/%s chapter_complete=%s story_complete=%s" % [
		chapter_id, maptitle, str(chapter_completed_now), str(story_finished),
	])
	show_rewards(_events_unlock_rows(), already, maptitle)


func _events_unlock_rows() -> Array:
	var rows: Array = []
	for row: Variant in state.unlocks_since(unlock_mark):
		rows.append(row)
	return rows


func show_rewards(rows_in: Array, already_completed: bool, maptitle: String) -> void:
	_clear_body()
	show_screen("rewards")
	pause_return = "rewards"
	last_reward_rows = rows_in
	last_reward_already = already_completed
	last_reward_map = maptitle
	var subtitle: String = "event %s · %d unlocks recorded" % [lang.text(maptitle), rows_in.size()]
	if already_completed:
		subtitle += " · (already completed)"
	if chapter_completed_now:
		subtitle += " · CHAPTER COMPLETE"
	if story_finished:
		subtitle += " · STORY COMPLETE"
	_set_header("REWARDS", subtitle, "J = BACK TO MAP")
	var rows: Array = []
	for row: Variant in rows_in:
		var entry: Dictionary = row
		var resolved: Dictionary = data.resolve_unlock(
			String(entry.get("item_type", "")), entry.get("item_id", 0))
		var name: String = String(resolved.get("name", ""))
		var suffix: String = ""
		if not name.is_empty():
			suffix = "  → " + name
			if not bool(resolved.get("proven", false)):
				suffix += " (list index)"
		rows.append("unlock %s · %s %s%s" % [
			str(entry.get("unlock_id", "")),
			String(entry.get("item_type", "")),
			str(entry.get("item_id", "")),
			suffix,
		])
	if rows.is_empty():
		rows.append("no unlock subevent in this event")
	if chapter_completed_now or story_finished:
		rows.append("")
		rows.append("chapter_end '%s' completed" % maptitle)
	_show_rows(rows, -1)


# -------------------------------------------------------------------- records


func show_records() -> void:
	_clear_body()
	show_screen("records")
	_set_header(
		"RECORDS",
		"storyplayerprofile.ui · slot %d · %s · exp %d" % [
			state.save_slot, String(state.difficulty_name).to_upper(), state.exp,
		],
		"J / ESC = MAP"
	)
	var rows: Array = []
	for index: int in range(data.chapter_count()):
		var chapter_id: String = data.chapter_id(index)
		var event_rows: Array = data.events(index)
		rows.append("chapter %d/%d  %s  %d/%d events" % [
			index + 1, data.chapter_count(), lang.text(data.chapter_title_key(index)),
			state.chapter_completed_count(chapter_id, event_rows), event_rows.size(),
		])
	rows.append("")
	rows.append("UNLOCK RECORDS (%d)" % state.unlocks.size())
	for row: Variant in state.unlocks:
		var entry: Dictionary = row
		var resolved: Dictionary = data.resolve_unlock(
			String(entry.get("item_type", "")), entry.get("item_id", 0))
		var name: String = String(resolved.get("name", ""))
		var suffix: String = ""
		if not name.is_empty():
			suffix = " → " + name
			if not bool(resolved.get("proven", false)):
				suffix += " (list index)"
		rows.append("  %s · %s %s%s   ← %s/%s" % [
			str(entry.get("unlock_id", "")),
			String(entry.get("item_type", "")),
			str(entry.get("item_id", "")),
			suffix,
			String(entry.get("chapter", "")),
			String(entry.get("event", "")),
		])
	rows.append("")
	rows.append("FIGHT RECORDS (%d)" % state.records.size())
	for row: Variant in state.records:
		var entry: Dictionary = row
		rows.append("  %s/%s vs %s · %s · %d s · difficulty %d" % [
			String(entry.get("chapter", "")),
			String(entry.get("event", "")),
			String(entry.get("opponent", "")),
			"WIN" if bool(entry.get("won", false)) else "LOSE",
			int(float(entry.get("seconds", 0.0))),
			int(entry.get("difficulty_value", -1)),
		])
	rows.append("")
	rows.append("exp %d · native accrual: FightWon per won fight + StorySubEventComplete" % state.exp)
	_show_rows(rows, -1)


# ---------------------------------------------------------------------- pause


func show_pause(return_screen: String = "battle") -> void:
	_clear_body()
	show_screen("pause")
	pause_return = return_screen
	pause_cursor = clampi(pause_cursor, 0, 2)
	if return_screen == "battle":
		_set_header("PAUSE", "storypause.ui · story battle", "J = SELECT · ESC = RESUME")
	else:
		_set_header("PAUSE", "storypause.ui · " + return_screen, "J = SELECT · ESC = RESUME")
	_show_rows(["resume", "back_to_map", "main_menu"], pause_cursor)


func _accept_pause() -> void:
	match pause_cursor:
		0:
			_resume_from_pause()
		1:
			_abandon_to_map()
		2:
			_abandon_to_mode()


func _resume_from_pause() -> void:
	match pause_return:
		"picture":
			show_picture(playback_cursor)
		"next_fight":
			show_next_fight(last_advanced)
		"defeat":
			show_defeat(last_advanced)
		"rewards":
			show_rewards(last_reward_rows, last_reward_already, last_reward_map)
		"records":
			show_records()
		_:
			hide_all()


func _abandon_to_map() -> void:
	if state != null:
		state.clear_pending()
		state.save()
	OS.set_environment(ENV_STORY_LAUNCH, "")
	hide_all()
	show_map()


func _abandon_to_mode() -> void:
	if state != null:
		state.clear_pending()
		state.save()
	OS.set_environment(ENV_STORY_LAUNCH, "")
	show_mode()


# ---------------------------------------------------------------------- input


func _input(event: InputEvent) -> void:
	if screen == "hidden" or screen == "battle":
		# ESC during a story fight is routed to show_pause() by main.gd.
		return
	if not PrototypeControls.is_press_edge(event):
		return
	var handled: bool = true
	var left: bool = false
	var right: bool = false
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.echo:
			left = key_event.keycode == KEY_LEFT or key_event.keycode == KEY_A
			right = key_event.keycode == KEY_RIGHT or key_event.keycode == KEY_D
			if screen == "map" and key_event.keycode == KEY_TAB:
				show_records()
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed(PrototypeControls.MENU_UP):
		_move(-1)
	elif event.is_action_pressed(PrototypeControls.MENU_DOWN):
		_move(1)
	elif left:
		_move_axis(-1)
	elif right:
		_move_axis(1)
	elif event.is_action_pressed(PrototypeControls.MENU_ACCEPT):
		_accept()
	elif event.is_action_pressed(PrototypeControls.MENU_CANCEL):
		_cancel()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _move(step: int) -> void:
	match screen:
		"mode":
			mode_cursor = wrapi(mode_cursor + step, 0, 2)
			show_mode()
		"slot":
			slot_cursor = wrapi(slot_cursor + step, 0, StoryStateScript.SLOT_COUNT)
			show_slot_select(slot_mode)
		"difficulty":
			difficulty_cursor = wrapi(
				difficulty_cursor + step, 0, data.difficulty_slot_names().size())
			show_difficulty()
		"pause":
			pause_cursor = wrapi(pause_cursor + step, 0, 3)
			show_pause(pause_return)
		"map":
			_map_move(Vector2(0, 1) if step > 0 else Vector2(0, -1))


func _move_axis(direction: int) -> void:
	match screen:
		"map":
			_map_move(Vector2(direction, 0))
		"difficulty":
			_move(direction)


func _accept() -> void:
	match screen:
		"mode":
			if mode_cursor == 0:
				show_slot_select("new")
			else:
				show_slot_select("continue")
		"slot":
			if slot_mode == "new":
				show_difficulty()
			else:
				_continue_from_slot(slot_cursor + 1)
		"difficulty":
			_start_new_story(slot_cursor + 1, difficulty_cursor)
		"map":
			if map_cursor >= 0 and map_cursor < data.events(state.chapter_index).size():
				show_detail(map_cursor)
		"detail":
			begin_playback()
		"picture":
			_advance_picture()
		"next_fight":
			_launch_fight()
		"defeat", "rewards":
			OS.set_environment(ENV_STORY_LAUNCH, "")
			hide_all()
			show_map()
		"records":
			hide_all()
			show_map()
		"pause":
			_accept_pause()
		"error":
			hide_all()
			show_mode()


func _cancel() -> void:
	match screen:
		"mode":
			get_tree().quit()
		"slot":
			show_mode()
		"difficulty":
			show_slot_select("new")
		"map":
			show_mode()
		"detail":
			show_map()
		"picture":
			show_pause("picture")
		"records":
			hide_all()
			show_map()
		"pause":
			_resume_from_pause()
		"next_fight":
			show_pause("next_fight")
		"defeat":
			show_pause("defeat")
		"rewards":
			show_pause("rewards")
		"error":
			hide_all()
			show_mode()


func _start_new_story(slot: int, difficulty_index: int) -> void:
	var names: Array = data.difficulty_slot_names()
	var label: String = String(names[clampi(difficulty_index, 0, names.size() - 1)])
	state = StoryStateScript.new()
	if not state.new_story(slot, difficulty_index, label):
		_show_error("SAVE ERROR", state.error_msg)
		return
	map_cursor = 0
	detail_cursor_reset()
	auto_launch_armed = true
	print("STORY_FLOW_NEW slot=%d difficulty=%s(%d)" % [slot, label, difficulty_index])
	show_map()


func detail_cursor_reset() -> void:
	detail_event = 0
	playback_cursor = 0
	unlock_mark = 0


func _continue_from_slot(slot: int) -> void:
	state = StoryStateScript.new()
	if not state.load_slot(slot):
		_show_error("LOAD ERROR", state.error_msg)
		return
	if state.has_pending():
		if _resume_pending_battle():
			return
		state.clear_pending()
		state.save()
	auto_launch_armed = true
	show_map()


func _load_most_recent_slot() -> void:
	var best_slot: int = 0
	var best_time: int = -1
	for slot: int in range(1, StoryStateScript.SLOT_COUNT + 1):
		if not StoryStateScript.slot_exists(slot):
			continue
		var modified: int = int(FileAccess.get_modified_time(
			StoryStateScript.slot_path(slot)))
		if modified > best_time:
			best_time = modified
			best_slot = slot
	if best_slot > 0:
		var loaded = StoryStateScript.new()
		if loaded.load_slot(best_slot):
			state = loaded


# --------------------------------------------------------------- test helpers


func debug_state() -> Dictionary:
	return {
		"screen": screen,
		"save_slot": state.save_slot if state != null else 0,
		"chapter_index": state.chapter_index if state != null else -1,
		"chapter_count": data.chapter_count() if data != null else 0,
		"difficulty_slot": state.difficulty_slot if state != null else -1,
		"map_cursor": map_cursor,
		"detail_event": detail_event,
		"playback_cursor": playback_cursor,
		"unlocks": state.unlocks.size() if state != null else 0,
		"pending": state.has_pending() if state != null else false,
		"battle_spec": battle_spec,
		"error": error_text,
	}


func body_lines() -> Array:
	var lines: Array = []
	for child: Node in body.get_children():
		if child is Label:
			lines.append((child as Label).text)
			continue
		for row: Node in child.get_children():
			if row is Label:
				lines.append((row as Label).text)
	return lines


func header_lines() -> Dictionary:
	return {
		"title": title_label.text,
		"subtitle": subtitle_label.text,
		"footer": footer_label.text,
	}

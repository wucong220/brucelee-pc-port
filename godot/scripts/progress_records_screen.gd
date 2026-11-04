extends CanvasLayer
class_name ProgressRecordsScreen

## Opt-in Records / Achievements screen for the PC prototype.
##
## Reachable from the main menu ONLY while `BRUCELEE_PROGRESS=1` (the row is
## added by prototype_menu.gd under that same gate). It renders the existing
## progress service state -- nothing here invents gameplay data:
##
##   * 38 achievements  <- data/progress/achievements.json (decoded
##     adreno_200/achievements.list: pending_icon, reached_icon, description)
##   * unlock list/count <- data/progress/unlocks.json via UnlockRegistry
##     (117-id space, 40 EXP rows, 49 story-event rows)
##   * story EXP/events, versus/combat counters, mode clears <- the live save
##     state owned by ProgressService
##   * save status       <- the real user:// save envelope (existence, size,
##     saved timestamp, SHA-256 checksum recomputation, fail-closed load)
##
## Achievement rows display the recovered `description` literal verbatim (the
## original object stores the translation key there; the ten shipped .lang files
## contain no `achv_*` entries, so no localized achievement text exists to show).
## The condition column uses only fields present in the recovered condition
## descriptor; `unrecovered` rows are labelled NOT RECOVERED and can never be
## awarded by AchievementEngine (fail-closed).
##
## Icons: the 76 original `gui/images/menu/BL_GUI_achievement_*` textures were
## decoded to 64x64 PNGs (ui/achievement/, local-only art like the story art).
## When a PNG is absent the row falls back to text only, exactly like
## story_picture_view.gd does for story art -- see icon_status().

signal closed

const PrototypeControls = preload("res://scripts/prototype_controls.gd")

const ACHIEVEMENTS_PATH := "res://data/progress/achievements.json"
const ICON_DIR := "res://ui/achievement/"
const ENV_ICON_DIR := "BRUCELEE_ACHIEVEMENT_ICON_DIR"

const COLOR_BG := Color(0.030, 0.038, 0.055, 0.985)
const COLOR_BAND := Color(0.070, 0.082, 0.110, 0.960)
const COLOR_TEXT := Color(0.86, 0.88, 0.92)
const COLOR_DIM := Color(0.60, 0.63, 0.68)
const COLOR_FAINT := Color(0.44, 0.47, 0.52)
const COLOR_ACCENT := Color(0.98, 0.78, 0.32)
const COLOR_OK := Color(0.45, 0.85, 0.55)
const COLOR_BAD := Color(0.90, 0.42, 0.38)
const COLOR_WARN := Color(0.92, 0.66, 0.30)

const ROW_HEIGHT := 26
const ICON_SIZE := Vector2(22, 22)

var hooks: Node = null
var save_path: String = "user://progress_save.json"

var _open: bool = false
var _built: bool = false
var _cursor: int = 0
var _rows: Array = []
var _icon_table: Array = []
var _icon_cache: Dictionary = {}
var _icon_table_error: String = ""
var _icon_missing: Array = []
var _row_icons: int = 0
var _last_state: Dictionary = {}

var _root: Control
var _header_title: Label
var _header_detail: Label
var _save_chip: Label
var _grid: GridContainer
var _row_nodes: Array = []
var _summary_label: Label
var _unlock_label: Label
var _save_label: Label
var _detail_label: Label
var _note_label: Label


func configure(hooks_node: Node, path: String = "") -> void:
	hooks = hooks_node
	if hooks_node != null and String(hooks_node.get("save_path")) != "":
		save_path = String(hooks_node.get("save_path"))
	if not path.is_empty():
		save_path = path
	_load_icon_table()


# ------------------------------------------------------------------ public

func open() -> void:
	_ensure_built()
	_open = true
	visible = true
	_cursor = clampi(_cursor, 0, maxi(0, _rows.size() - 1))
	refresh()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func is_open() -> bool:
	return _open


func selected_index() -> int:
	return _cursor


func move_cursor(step: int) -> void:
	if _rows.is_empty():
		return
	_cursor = wrapi(_cursor + step, 0, _rows.size())
	_refresh_selection()


func set_cursor(index: int) -> void:
	if _rows.is_empty():
		return
	_cursor = clampi(index, 0, _rows.size() - 1)
	_refresh_selection()


# -------------------------------------------------------------------- data

func achievement_rows() -> Array:
	## Display model for the 38 recovered achievements, in decoded order.
	if hooks == null:
		return []
	var service: Variant = hooks.get("service")
	if service == null:
		return []
	var engine: Variant = service.achievements
	if engine == null:
		return []
	var state: Dictionary = service.state
	var reached: Array = state["achievements"]["reached"]
	var counters: Dictionary = state.get("counters", {})
	var rows: Array = []
	for row: Variant in engine.rows:
		var entry: Dictionary = row
		var cond: Dictionary = entry["condition"]
		var id: String = String(entry["id"])
		var is_reached: bool = reached.has(id)
		var fail_closed: bool = bool(cond.get("fail_closed", false))
		rows.append({
			"index": int(entry["index"]),
			"id": id,
			"reached": is_reached,
			"fail_closed": fail_closed,
			"status": String(cond.get("status", "unrecovered")),
			"condition": cond.duplicate(true),
			"condition_text": _condition_text(cond, counters),
			"evidence": String(cond.get("evidence", "")),
			"pending_icon": int(entry["pending_icon_index"]),
			"reached_icon": int(entry["reached_icon_index"]),
			"state_text": (
				"REACHED" if is_reached
				else ("NOT RECOVERED" if fail_closed else "LOCKED")
			),
		})
	return rows


func summary_values() -> Dictionary:
	var base: Dictionary = {"active": false}
	if hooks == null:
		return base
	var summary: Dictionary = hooks.summary()
	base = summary.duplicate(true)
	base["achievement_total"] = 38 if hooks.service != null else 0
	base["achievement_count"] = (base.get("achievements", []) as Array).size()
	base["unlock_total"] = 0
	base["unlock_count"] = (base.get("unlocked_ids", []) as Array).size()
	if hooks.service != null:
		base["unlock_total"] = int(hooks.service.registry.num_ids)
	base["counter_rows"] = _counter_rows(base.get("counters", {}))
	base["mode_clear_rows"] = _mode_clear_rows(base.get("mode_clears", {}))
	return base


func unlock_rows() -> Array:
	## Recovered unlock entries for the ids already granted, plus the id-space
	## coverage that stays permanently locked because no source was recovered.
	if hooks == null or hooks.service == null:
		return []
	var out: Array = []
	var registry: Variant = hooks.service.registry
	var granted: Array = hooks.service.unlocked_ids()
	for id: Variant in granted:
		var entry: Dictionary = registry.entry_for_id(int(id))
		out.append({
			"id": int(id),
			"source": String(entry.get("source", "")),
			"item_type": String(entry.get("item_type", "")),
			"item_id": str(entry.get("item_id", "")),
		})
	return out


func unlock_coverage() -> Dictionary:
	## How many ids of the recovered 117-id space have a recovered grant source.
	if hooks == null or hooks.service == null:
		return {}
	var registry: Variant = hooks.service.registry
	var covered: Dictionary = {}
	for row: Variant in registry.story_unlocks:
		covered[int(Dictionary(row)["id"])] = "story_exp"
	for row: Variant in registry.event_unlocks:
		covered[int(Dictionary(row)["id"])] = "story_event"
	return {
		"num_ids": int(registry.num_ids),
		"covered": covered.size(),
		"uncovered": int(registry.num_ids) - covered.size(),
		"story_exp_rows": (registry.story_unlocks as Array).size(),
		"story_event_rows": (registry.event_unlocks as Array).size(),
	}


func save_status() -> Dictionary:
	## Status of the real user:// save envelope written by SaveManager.
	var out: Dictionary = {
		"path": save_path,
		"exists": false,
		"bytes": 0,
		"modified_utc": "",
		"saved_utc": "",
		"checksum_ok": false,
		"loads": false,
		"schema": "",
		"version": 0,
		"text": "NO SAVE FILE",
	}
	if not FileAccess.file_exists(save_path):
		return out
	out["exists"] = true
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		out["text"] = "UNREADABLE"
		return out
	out["bytes"] = file.get_length()
	var text := file.get_as_text()
	file.close()
	out["modified_utc"] = Time.get_datetime_string_from_unix_time(
		int(FileAccess.get_modified_time(save_path)), true)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		out["text"] = "CORRUPT · FAIL CLOSED"
		return out
	var envelope: Dictionary = parsed
	out["schema"] = String(envelope.get("schema", ""))
	out["version"] = int(envelope.get("version", 0))
	out["saved_utc"] = String(envelope.get("saved_utc", ""))
	var payload: Variant = envelope.get("payload_json", "")
	var checksum := ""
	if payload is String:
		checksum = String(payload).sha256_text()
	out["checksum_ok"] = (
		payload is String and checksum == String(envelope.get("checksum", ""))
	)
	out["loads"] = not SaveManager.load_state(save_path).is_empty()
	if out["checksum_ok"] and out["loads"]:
		out["text"] = "OK · CHECKSUM VERIFIED"
	elif not out["checksum_ok"]:
		out["text"] = "CHECKSUM MISMATCH · FAIL CLOSED"
	else:
		out["text"] = "SHAPE INVALID · FAIL CLOSED"
	return out


func icon_status() -> Dictionary:
	## "text-only" is the honest fallback: no rendered row bound an original
	## texture, so the screen is purely textual (never a placeholder icon).
	return {
		"table_entries": _icon_table.size(),
		"table_error": _icon_table_error,
		"loaded": _icon_cache.size(),
		"row_icons": _row_icons,
		"row_count": _rows.size(),
		"missing": _icon_missing.duplicate(),
		"mode": (
			"text-only" if _row_icons == 0
			else ("icons" if _icon_missing.is_empty() else "partial")
		),
	}


func debug_state() -> Dictionary:
	## Everything the screen displays, for tests and the delivery report.
	return {
		"open": _open,
		"cursor": _cursor,
		"rows": _rows.duplicate(true),
		"selected": _rows[_cursor] if _rows.size() > _cursor else {},
		"summary": summary_values(),
		"unlocks": unlock_rows(),
		"coverage": unlock_coverage(),
		"save": save_status(),
		"icons": icon_status(),
		"note": _note_label.text if _note_label != null else "",
	}


# ------------------------------------------------------------------ build

func _ensure_built() -> void:
	if not _built:
		_build()
		_built = true


func _build() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	_root = Control.new()
	_root.name = "RecordsRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = COLOR_BG
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(margin)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	# ---- header
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_header_title = _label("RECORDS · ACHIEVEMENTS", 24, COLOR_ACCENT)
	titles.add_child(_header_title)
	_header_detail = _label("", 11, COLOR_DIM)
	titles.add_child(_header_detail)
	_save_chip = _label("", 11, COLOR_DIM)
	_save_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_save_chip.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_save_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_save_chip)

	# ---- body: achievement grid (2 x 19) + scrollable summary/unlock/save column
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)

	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(left)
	left.add_child(_label("38 RECOVERED ACHIEVEMENTS  ·  gold icon = reached", 10, COLOR_DIM))
	_grid = GridContainer.new()
	_grid.name = "AchievementGrid"
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 0)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_grid)

	# The right column is text-only reference material: if a long unlock list ever
	# exceeds the frame it scrolls inside its own region instead of pushing the
	# footer off screen. Mouse wheel works; the achievement cursor is UP/DOWN.
	var right_scroll: ScrollContainer = ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(420, 0)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(right_scroll)
	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_scroll.add_child(right)
	right.add_child(_label("SUMMARY", 11, COLOR_ACCENT))
	_summary_label = _label("", 11, COLOR_TEXT)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_summary_label)
	right.add_child(_label("UNLOCK RECORDS", 11, COLOR_ACCENT))
	_unlock_label = _label("", 10, COLOR_TEXT)
	_unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_unlock_label)
	right.add_child(_label("SAVE STATUS", 11, COLOR_ACCENT))
	_save_label = _label("", 10, COLOR_TEXT)
	_save_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_save_label)

	# ---- footer: selected-achievement detail + honesty note + controls
	_detail_label = _label("", 11, COLOR_TEXT)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail_label)
	_note_label = _label("", 9, COLOR_FAINT)
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note_label)
	column.add_child(_label(
		"UP/DOWN or D-PAD select   HOME/END jump   ESC / B / J = CLOSE",
		10, COLOR_DIM))


func _label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# ---------------------------------------------------------------- refresh

func refresh() -> void:
	_ensure_built()
	_rows = achievement_rows()
	_cursor = clampi(_cursor, 0, maxi(0, _rows.size() - 1))
	_rebuild_grid()
	_refresh_summary()
	_refresh_save()
	_refresh_selection()
	_last_state = debug_state()


func _rebuild_grid() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_row_nodes.clear()
	if _rows.is_empty():
		_grid.columns = 1
		_grid.add_child(_label("PROGRESS SERVICE NOT ACTIVE", 14, COLOR_BAD))
		return
	_grid.columns = 2
	_row_icons = 0
	for row: Variant in _rows:
		var entry: Dictionary = row
		var cell: HBoxContainer = HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.custom_minimum_size = ICON_SIZE
		icon_rect.size = ICON_SIZE
		# The decoded PNGs are 64x64; without EXPAND_IGNORE_SIZE their texture size
		# becomes the cell's minimum height and 19 rows overflow the frame.
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.texture = _icon_for(entry)
		if icon_rect.texture != null:
			_row_icons += 1
		cell.add_child(icon_rect)
		var text: VBoxContainer = VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(text)
		var title: Label = _label("", 11, COLOR_TEXT)
		title.text = "%02d  %s" % [int(entry["index"]), String(entry["id"])]
		text.add_child(title)
		var sub: Label = _label("", 8, COLOR_FAINT)
		sub.text = String(entry["condition_text"])
		text.add_child(sub)
		var state: Label = _label("", 9, COLOR_DIM)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		state.text = String(entry["state_text"])
		cell.add_child(state)
		_grid.add_child(cell)
		_row_nodes.append({"cell": cell, "icon": icon_rect, "title": title,
			"sub": sub, "state": state})


func _refresh_summary() -> void:
	var summary: Dictionary = summary_values()
	if not bool(summary.get("active", false)):
		_summary_label.text = "progress service inactive (BRUCELEE_PROGRESS is not 1)"
		_unlock_label.text = "—"
		return
	var counters: Array = summary.get("counter_rows", [])
	var lines: Array = []
	lines.append("achievements   %d / %d" % [
		int(summary.get("achievement_count", 0)),
		int(summary.get("achievement_total", 0))])
	lines.append("unlocks        %d / %d" % [
		int(summary.get("unlock_count", 0)),
		int(summary.get("unlock_total", 0))])
	lines.append("story exp      %d" % int(summary.get("exp", 0)))
	lines.append("story events   %d" % int(summary.get("events_completed", 0)))
	lines.append("chapters       %s" % _list_text(summary.get("chapters_completed", [])))
	lines.append("story clears   %s" % _list_text(summary.get("completed_difficulties", [])))
	var mode_rows: Array = summary.get("mode_clear_rows", [])
	for row: Variant in mode_rows:
		lines.append(String(row))
	for row: Variant in counters:
		lines.append(String(row))
	_summary_label.text = "\n".join(lines)

	var unlocks: Array = unlock_rows()
	var coverage: Dictionary = unlock_coverage()
	var unlock_lines: Array = []
	if unlocks.is_empty():
		unlock_lines.append("none granted yet")
	else:
		for row: Variant in unlocks:
			var entry: Dictionary = row
			unlock_lines.append("  #%03d %s %s  ← %s" % [
				int(entry["id"]), String(entry["item_type"]),
				String(entry["item_id"]), String(entry["source"])])
	if not coverage.is_empty():
		unlock_lines.append("%d/%d ids carry a recovered grant source; %d stay locked (%s rows: %d exp, %d event)" % [
			int(coverage.get("covered", 0)), int(coverage.get("num_ids", 0)),
			int(coverage.get("uncovered", 0)), "see report",
			int(coverage.get("story_exp_rows", 0)),
			int(coverage.get("story_event_rows", 0))])
	_unlock_label.text = "\n".join(unlock_lines)


func _refresh_save() -> void:
	var status: Dictionary = save_status()
	_header_detail.text = (
		"opt-in progress service · BRUCELEE_PROGRESS=1 · %s" % save_path
	)
	var chip: String = String(status.get("text", ""))
	if bool(status.get("exists", false)) and bool(status.get("loads", false)):
		_save_chip.add_theme_color_override("font_color", COLOR_OK)
	elif not bool(status.get("exists", false)):
		_save_chip.add_theme_color_override("font_color", COLOR_WARN)
	else:
		_save_chip.add_theme_color_override("font_color", COLOR_BAD)
	_save_chip.text = "SAVE · " + chip
	var lines: Array = []
	lines.append("path   %s" % String(status.get("path", "")))
	if not bool(status.get("exists", false)):
		# No file is not a failure: the service creates it on the first recorded
		# event. Say that instead of reporting a bogus checksum mismatch.
		lines.append("file   no save file yet")
		lines.append("envelope written on the first recorded progress event")
		lines.append("checksum n/a · load defaults")
		lines.append("state  %s" % chip)
		_save_label.text = "\n".join(lines)
		_note_label.text = _footer_note()
		return
	lines.append("file   %d bytes · modified %s" % [
		int(status.get("bytes", 0)), String(status.get("modified_utc", ""))])
	lines.append("envelope %s v%d · saved_utc %s" % [
		String(status.get("schema", "—")), int(status.get("version", 0)),
		String(status.get("saved_utc", "—"))])
	lines.append("checksum %s · load %s" % [
		"verified" if bool(status.get("checksum_ok", false)) else "mismatch",
		"ok" if bool(status.get("loads", false)) else "fail-closed default"])
	lines.append("state  %s" % chip)
	_save_label.text = "\n".join(lines)
	_note_label.text = _footer_note()


func _footer_note() -> String:
	var icons: Dictionary = icon_status()
	var rows_count: int = int(icons.get("row_count", 0))
	var bound: int = int(icons.get("row_icons", 0))
	var icon_text: String = (
		"icons: %d/%d rows bound to original achievement textures "
		% [bound, rows_count]
	)
	if String(icons.get("mode", "")) == "text-only":
		icon_text = (
			"icons: TEXT-ONLY — no decoded achievement texture loaded for any row "
			+ "(decode gui/images/menu/BL_GUI_achievement_* into "
			+ "res://ui/achievement/ or set BRUCELEE_ACHIEVEMENT_ICON_DIR)"
		)
	elif bound < rows_count:
		icon_text += "· %d row(s) text-only" % (rows_count - bound)
	return (
		icon_text
		+ "  ·  row labels are the recovered achievements.list description keys"
		+ "  ·  the 10 shipped .lang files contain no achv_* text"
	)


func _refresh_selection() -> void:
	for index: int in range(_row_nodes.size()):
		var node: Dictionary = _row_nodes[index]
		var entry: Dictionary = _rows[index]
		var cell: HBoxContainer = node["cell"]
		var title: Label = node["title"]
		var sub: Label = node["sub"]
		var state: Label = node["state"]
		var selected: bool = index == _cursor
		var prefix: String = "> " if selected else "   "
		title.text = prefix + "%02d  %s" % [int(entry["index"]), String(entry["id"])]
		title.add_theme_color_override("font_color", (
			COLOR_ACCENT if selected
			else (COLOR_TEXT if bool(entry["reached"]) else COLOR_FAINT)))
		sub.add_theme_color_override("font_color", (
			COLOR_DIM if selected else COLOR_FAINT))
		if bool(entry["reached"]):
			state.add_theme_color_override("font_color", COLOR_OK)
		elif bool(entry["fail_closed"]):
			state.add_theme_color_override("font_color", COLOR_BAD)
		else:
			state.add_theme_color_override("font_color", COLOR_DIM)
		cell.modulate = Color(1, 1, 1, 1) if selected else Color(1, 1, 1, 0.92)
	if _rows.size() > _cursor:
		var entry: Dictionary = _rows[_cursor]
		var lines: Array = ["selected  %02d  %s  ·  %s" % [
			int(entry["index"]), String(entry["id"]),
			String(entry["state_text"])]]
		lines.append("condition %s  (%s)" % [
			String(entry["condition_text"]), String(entry["status"])])
		if not String(entry["evidence"]).is_empty():
			lines.append("evidence  " + String(entry["evidence"]))
		_detail_label.text = "\n".join(lines)


# ---------------------------------------------------------------- helpers

func _condition_text(cond: Dictionary, counters: Dictionary) -> String:
	match String(cond.get("kind", "")):
		"counter_threshold":
			var counter: String = String(cond.get("counter", "?"))
			var have: int = int(counters.get(counter, 0))
			return "%s ≥ %d (now %d)" % [
				counter, int(cond.get("threshold", 0)), have]
		"mode_clear":
			return "clear %s %s" % [
				String(cond.get("mode", "?")), String(cond.get("difficulty", "?"))]
		"story_complete":
			return "complete story %s (%s)" % [
				String(cond.get("difficulty", "?")),
				String(cond.get("status", "unrecovered"))]
		_:
			return String(cond.get("status", "unrecovered"))


func _counter_rows(counters: Dictionary) -> Array:
	## Only counters this build actually writes, in a stable display order and
	## packed into two lines so SAVE STATUS keeps the screen without scrolling.
	var combat: Array = [
		["versus_wins", "versus"],
		["number_of_grabs", "grabs"],
		["number_of_endmoves", "final attacks"],
		["number_of_greats", "greats"],
		["number_of_perfects", "perfects"],
	]
	var story: Array = [
		["survival_best_round", "survival best"],
		["story_events_completed", "events"],
		["story_chapters_completed", "chapters"],
	]
	var first: Array = []
	var second: Array = []
	for pair: Variant in combat:
		first.append("%s %d" % [
			String((pair as Array)[1]), int(counters.get(String((pair as Array)[0]), 0))])
	for pair: Variant in story:
		second.append("%s %d" % [
			String((pair as Array)[1]), int(counters.get(String((pair as Array)[0]), 0))])
	for key: Variant in counters.keys():
		if _known_counter(String(key)):
			continue
		second.append("%s %d" % [String(key), int(counters[key])])
	var rows: Array = []
	if not first.is_empty():
		rows.append("  ·  ".join(first))
	if not second.is_empty():
		rows.append("  ·  ".join(second))
	return rows


func _known_counter(key: String) -> bool:
	return key in [
		"versus_wins", "number_of_grabs", "number_of_endmoves",
		"number_of_greats", "number_of_perfects", "story_events_completed",
		"story_chapters_completed", "survival_best_round",
	]


func _mode_clear_rows(mode_clears: Dictionary) -> Array:
	var rows: Array = []
	for mode: String in ["arcade", "time_attack", "survival"]:
		var value: Variant = mode_clears.get(mode)
		var marks: Array = []
		if value is Dictionary:
			for difficulty: String in ["beginner", "easy", "medium", "hard"]:
				if (value as Dictionary).has(difficulty):
					marks.append(("%s:" % difficulty.substr(0, 3).to_upper())
						+ ("yes" if bool((value as Dictionary)[difficulty]) else "no"))
		rows.append("%s  ·  %s" % [
			("arcade" if mode == "arcade" else mode.replace("_", " ")),
			" ".join(marks) if not marks.is_empty() else "not recorded"])
	return rows


func _list_text(value: Variant) -> String:
	if value is Array and not (value as Array).is_empty():
		var parts: Array = []
		for item: Variant in value:
			parts.append(str(item))
		return ", ".join(parts)
	return "—"


func _load_icon_table() -> void:
	_icon_table.clear()
	_icon_table_error = ""
	if not FileAccess.file_exists(ACHIEVEMENTS_PATH):
		_icon_table_error = "achievements.json missing"
		return
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(ACHIEVEMENTS_PATH))
	if not parsed is Dictionary:
		_icon_table_error = "achievements.json is not an object"
		return
	var table: Variant = (parsed as Dictionary).get("icon_table", [])
	if not table is Array or (table as Array).size() != 76:
		_icon_table_error = "icon_table is not the recovered 76-entry table"
		return
	for entry: Variant in table:
		_icon_table.append(_icon_stem(String(entry)))


func _icon_stem(entry: String) -> String:
	var name: String = entry.strip_edges()
	if name.to_lower().ends_with(".tex"):
		name = name.substr(0, name.length() - 4)
	return name.to_lower()


func _icon_for(entry: Dictionary) -> Texture2D:
	var index: int = (
		int(entry["reached_icon"]) if bool(entry["reached"])
		else int(entry["pending_icon"]))
	if index < 0 or index >= _icon_table.size():
		return null
	return _texture(String(_icon_table[index]))


func _texture(stem: String) -> Texture2D:
	if stem.is_empty():
		return null
	if _icon_cache.has(stem):
		return _icon_cache[stem]
	var texture: Texture2D = null
	var resource_path: String = ICON_DIR + stem + ".png"
	# Gate on the PNG itself, not on ResourceLoader.exists(): an orphan .import
	# stub (what a patch-applied checkout has, because the decoded PNGs are local
	# art assets) still makes ResourceLoader.exists() true and then fails noisily
	# on load. FileAccess sees the real file, so a missing PNG is silent.
	if FileAccess.file_exists(resource_path):
		if ResourceLoader.exists(resource_path):
			var resource: Resource = load(resource_path)
			if resource is Texture2D:
				texture = resource
		if texture == null:
			var image: Image = Image.load_from_file(
				ProjectSettings.globalize_path(resource_path))
			if image != null:
				texture = ImageTexture.create_from_image(image)
	if texture == null:
		var external_root: String = OS.get_environment(ENV_ICON_DIR)
		if not external_root.is_empty():
			var absolute: String = external_root.path_join(stem + ".png")
			if FileAccess.file_exists(absolute):
				var image: Image = Image.load_from_file(absolute)
				if image != null:
					texture = ImageTexture.create_from_image(image)
	if texture == null:
		if not _icon_missing.has(stem):
			_icon_missing.append(stem)
		return null
	_icon_cache[stem] = texture
	return texture


# ------------------------------------------------------------------ input

func handle_input_event(event: InputEvent) -> bool:
	if not _open:
		return false
	if not PrototypeControls.is_press_edge(event):
		return false
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		match key.keycode:
			KEY_HOME:
				set_cursor(0)
				return true
			KEY_END:
				set_cursor(maxi(0, _rows.size() - 1))
				return true
			KEY_PAGEUP:
				move_cursor(-2)
				return true
			KEY_PAGEDOWN:
				move_cursor(2)
				return true
	if event.is_action_pressed(PrototypeControls.MENU_UP):
		move_cursor(-1)
		return true
	if event.is_action_pressed(PrototypeControls.MENU_DOWN):
		move_cursor(1)
		return true
	if (event.is_action_pressed(PrototypeControls.MENU_CANCEL)
			or event.is_action_pressed(PrototypeControls.MENU_ACCEPT)):
		close()
		return true
	return false


func _input(event: InputEvent) -> void:
	if not _open:
		return
	# The screen owns input while it is up: consume every press edge, even the
	# ones it does not map, so a menu/gameplay binding behind it cannot fire.
	if handle_input_event(event):
		get_viewport().set_input_as_handled()
		return
	if PrototypeControls.is_press_edge(event):
		get_viewport().set_input_as_handled()

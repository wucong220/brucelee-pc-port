extends "res://scripts/prototype_menu.gd"
class_name PortMenuArt
## Opt-in original-art front menu (BRUCELEE_MENU_ART=1).
##
## The text menu (prototype_menu.gd) stays in the inheritance chain unchanged:
## this subclass only replaces the MAIN and PLAY screens with the recovered
## 480x320 artwork, and keeps the base class for the pause / records / style
## editor hooks main.gd already calls.
##
## Everything drawn comes from the recovered archive resources decoded by the
## isolated menu-art-20261104 run:
##   * widget positions/sizes/types : adreno_200/gui/<screen>.ui (CTX3), decoded
##     into res://data/menu_art/ui/<screen>.json;
##   * pictures                     : adreno_200/gui/images/... .tex, decoded
##     into res://ui/menu_art/menu/... and .../background/...;
##   * dock order and names         : characters.list / sceneries.list, checked
##     into res://data/menu_art/menu_art.json (shipped for provenance; the two
##     rendered menus have no dock).
##
## Text labels stay the existing MenuLang overlay. A key the table does not
## cover is shown as a readable placeholder, never as invented game text.
##
## The layout coordinate space is 480x320. That size is not assumed: title.ui
## and universal.ui both place a full-screen touch button at (0,0,480,320), and
## every decoded menu background stores its visible art exactly in a 480x320
## rectangle at (0,0) of a 512x512 texture.
##
## Commands are the ones the text menu already emits (fight / arcade / survival /
## timeattack / training / quit), so no mode start logic is duplicated here. The
## one exception is STORY MODE: the port has no menu command for it, so this
## screen sets the same BRUCELEE_STORY_FLOW environment the story flow already
## uses and reloads the scene, exactly like the opponent/scene menu switches.
##
## A missing layout, a missing referenced texture or a geometry/name mismatch
## fails closed (the overlay never draws a guessed substitute; it reports the
## error and stays hidden).

const UI_DIR := "res://data/menu_art/ui/"
const ART_ROOT := "res://ui/menu_art/"
const ART_DIRS := ["menu", "menu_zdk", "mini", "background"]
const Controls = preload("res://scripts/prototype_controls.gd")

const DESIGN_W := 480.0
const DESIGN_H := 320.0

const COLOR_SELECTED := Color(1.0, 1.0, 0.0, 1.0)
const COLOR_IDLE := Color(1.0, 1.0, 1.0, 1.0)
const STATUS_NOT_RECOVERED := "NOT RECOVERED IN THIS BUILD"

## screen id -> layout file, background texture, required widget names
const SCREENS := {
	"mainmenu": {
		"layout": "mainmenu",
		"background": "bl_gui_backgrond_mainmenu",
		"required": ["logo", "title", "menu"],
	},
	"playmenu": {
		"layout": "playmenu",
		"background": "bl_gui_backgrond_playmenu",
		"required": ["title", "playmenu", "lsk"],
	},
}

## Recovered mainmenu.ui options, in decoded order. Play opens the recovered
## play menu; Quit is the current quit command. The other four recovered rows
## stay visible but fail closed with an explicit status: the port has no
## player-profile / settings / credits / about screen, and pretending otherwise
## would invent behaviour.
const MAIN_ROWS := [
	{"key": "play", "action": "play"},
	{"key": "player_profile", "action": "unavailable"},
	{"key": "settings", "action": "unavailable"},
	{"key": "credits", "action": "unavailable"},
	{"key": "about", "action": "unavailable"},
	{"key": "quit", "action": "command", "command": "quit"},
]

## Recovered playmenu.ui options, in decoded order. Every option is wired to the
## start the current port already has; STORY MODE goes through the existing
## BRUCELEE_STORY_FLOW launch because no menu command exists for it.
const PLAY_ROWS := [
	{"key": "story_mode", "action": "story"},
	{"key": "arcade", "action": "command", "command": "arcade"},
	{"key": "time_attack", "action": "command", "command": "timeattack"},
	{"key": "versus", "action": "command", "command": "fight"},
	{"key": "survival", "action": "command", "command": "survival"},
	{"key": "practice_style", "action": "command", "command": "training"},
]

## Readable placeholders for recovered keys the MenuLang table does not cover.
## These are labels, never game behaviour; the recovered translation wins the
## moment the table gains the key.
const PLACEHOLDER_LABELS := {
	"player_profile": "Player Profile",
	"credits": "Credits",
	"about": "About",
	"story_mode": "Story Mode",
	"practice_style": "Practice Style",
	"play_menu": "Play Menu",
}

var screen_id: String = ""
var selection: int = 0
var status_text: String = ""
var last_error: String = ""
var art_ready: bool = false

var _art_root: Control
var _ui_space: Control
var _stage: Control
var _status_label: Label
var _screens: Dictionary = {}
var _texture_paths: Dictionary = {}
var _textures: Dictionary = {}
var _built_rects: Dictionary = {}


class RectOutline extends Control:
	var line_color: Color = Color(1.0, 1.0, 0.0, 1.0)
	var line_width: float = 2.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), line_color, false, line_width)


# The base _ready builds the text menu (kept for pause / errors); the art
# overlay is built afterwards and shown only while an art screen owns the menu.
func _ready() -> void:
	super._ready()
	_texture_paths = _index_textures()
	if _texture_paths.is_empty():
		_fail("no decoded textures found under " + ART_ROOT)
		return
	if not _load_screens():
		return
	_build_art()
	art_ready = true
	hide_menu()


# ------------------------------------------------------------ base overrides

func show_main_menu() -> void:
	menu_state = "art_main"
	selected_index = 0
	selection = 0
	status_text = ""
	visible = true
	_art_visible(true)
	_show_art_screen("mainmenu")


func show_pause_menu() -> void:
	# Pause is not part of the recovered main-menu art; keep the existing text
	# pause menu exactly as it is.
	super.show_pause_menu()
	_art_visible(false)
	screen_id = ""


func hide_menu() -> void:
	super.hide_menu()
	if _art_root != null:
		_art_root.visible = false
	screen_id = ""


func show_error(value: String) -> void:
	super.show_error(value)
	if menu_state == "art_main" or menu_state == "art_play":
		status_text = value
		_refresh_status()


func selected_command() -> String:
	if menu_state == "art_main" or menu_state == "art_play":
		var row: Dictionary = _selected_row()
		if row.is_empty():
			return ""
		if String(row.get("action", "")) == "command":
			return String(row.get("command", ""))
		return ""
	return super.selected_command()


func handle_input_event(event: InputEvent) -> bool:
	if not visible:
		return false
	if menu_state == "art_main" or menu_state == "art_play":
		return _handle_art_input(event)
	return super.handle_input_event(event)


# ---------------------------------------------------------------- art input

func _handle_art_input(event: InputEvent) -> bool:
	if not Controls.is_press_edge(event):
		return false
	var was_attack: bool = event.is_action_pressed(Controls.ATTACK_A)
	if event.is_action_pressed(Controls.MENU_UP):
		_move_art_selection(-1)
	elif event.is_action_pressed(Controls.MENU_DOWN):
		_move_art_selection(1)
	elif event.is_action_pressed(Controls.MENU_ACCEPT) or _is_space(event):
		_confirm_art(was_attack)
	elif event.is_action_pressed(Controls.MENU_CANCEL) or _is_backspace(event):
		_back_art()
	else:
		return false
	return true


func _is_space(event: InputEvent) -> bool:
	return event is InputEventKey and (event as InputEventKey).keycode == KEY_SPACE


func _is_backspace(event: InputEvent) -> bool:
	return event is InputEventKey and (event as InputEventKey).keycode == KEY_BACKSPACE


func _move_art_selection(delta: int) -> void:
	var rows: Array = _rows_for(screen_id)
	if rows.is_empty():
		return
	status_text = ""
	selection = clampi(selection + delta, 0, rows.size() - 1)
	_show_art_screen(screen_id)


func _confirm_art(was_attack: bool) -> void:
	var row: Dictionary = _selected_row()
	if row.is_empty():
		return
	match String(row.get("action", "")):
		"play":
			status_text = ""
			selection = 0
			menu_state = "art_play"
			_show_art_screen("playmenu")
		"command":
			last_accept_was_attack = was_attack
			command_requested.emit(String(row.get("command", "")))
		"story":
			_launch_story()
		"unavailable":
			status_text = STATUS_NOT_RECOVERED
			_refresh_status()


func _back_art() -> void:
	status_text = ""
	if screen_id == "playmenu":
		selection = 0
		menu_state = "art_main"
		_show_art_screen("mainmenu")
	# At the recovered main menu BACK is a no-op, matching the text menu.


func _launch_story() -> void:
	## The port has no "story" menu command. The story flow is already an
	## opt-in launch selected by BRUCELEE_STORY_FLOW=1, so set that same
	## environment (and leave the main menu) and reload the scene. This mirrors
	## the opponent/scene switch paths in main.gd; it does not start a mode here.
	OS.set_environment("BRUCELEE_STORY_FLOW", "1")
	OS.set_environment("BRUCELEE_MAIN_MENU", "0")
	hide_menu()
	get_tree().paused = false
	get_tree().call_deferred("reload_current_scene")


func _selected_row() -> Dictionary:
	var rows: Array = _rows_for(screen_id)
	if selection < 0 or selection >= rows.size():
		return {}
	return rows[selection]


func _rows_for(key: String) -> Array:
	match key:
		"mainmenu":
			return MAIN_ROWS
		"playmenu":
			return PLAY_ROWS
		_:
			return []


# ---------------------------------------------------------------- art build

func _index_textures() -> Dictionary:
	var index: Dictionary = {}
	for directory: Variant in ART_DIRS:
		var folder: String = String(directory)
		var path: String = ART_ROOT + folder
		var names: PackedStringArray = DirAccess.get_files_at(path)
		for name: String in names:
			if not name.to_lower().ends_with(".png"):
				continue
			var stem: String = name.get_basename().to_lower()
			index[folder + "/" + stem] = path.path_join(name)
	return index


## Texture key for a recovered file reference:
## {'directory': 'gui/images/menu/', 'basename': 'bl_gui_logo_little', ...}
func _file_key(reference: Dictionary) -> String:
	var directory: String = String(reference.get("directory", ""))
	var folder: String = ""
	match directory:
		"gui/images/menu/":
			folder = "menu"
		"gui/images/menu/zdk/":
			folder = "menu_zdk"
		"gui/images/mini/":
			folder = "mini"
		"gui/images/background/":
			folder = "background"
		_:
			_fail("unmapped texture directory '" + directory + "'")
			return ""
	return folder + "/" + String(reference.get("basename", "")).to_lower()


func _texture(key: String) -> Texture2D:
	if _textures.has(key):
		return _textures[key] as Texture2D
	if not _texture_paths.has(key):
		_fail("missing texture " + key + " (referenced by a recovered layout)")
		return null
	var image: Image = Image.load_from_file(String(_texture_paths[key]))
	if image == null or image.is_empty():
		_fail("cannot decode texture " + key)
		return null
	var texture: Texture2D = ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture


func _load_screens() -> bool:
	for screen: Variant in SCREENS:
		var path: String = UI_DIR + String(SCREENS[screen]["layout"]) + ".json"
		if not FileAccess.file_exists(path):
			_fail("missing layout " + path)
			return false
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			_fail("layout is not a JSON object: " + path)
			return false
		var layout: Variant = (parsed as Dictionary).get("layout")
		if typeof(layout) != TYPE_ARRAY or (layout as Array).is_empty():
			_fail("layout has no widgets: " + path)
			return false
		var names: Dictionary = {}
		for node: Variant in layout:
			if typeof(node) != TYPE_DICTIONARY:
				_fail("layout widget is not an object: " + path)
				return false
			for field: String in ["name", "type", "x", "y", "width", "height"]:
				if not (node as Dictionary).has(field):
					_fail("layout widget misses " + field + ": " + path)
					return false
				var value_type: int = typeof((node as Dictionary)[field])
				if field != "name" and field != "type" \
						and value_type != TYPE_INT and value_type != TYPE_FLOAT:
					_fail("layout widget has non-numeric " + field + ": " + path)
					return false
			if names.has(String(node["name"])):
				_fail("duplicate widget name in " + path)
				return false
			names[String(node["name"])] = true
		for required: Variant in SCREENS[screen]["required"]:
			if not names.has(String(required)):
				_fail("layout " + path + " misses required widget " + String(required))
				return false
		_screens[screen] = parsed
	return true


func _build_art() -> void:
	_art_root = Control.new()
	_art_root.name = "MenuArt"
	_art_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_root)

	var letterbox: ColorRect = ColorRect.new()
	letterbox.name = "Letterbox"
	letterbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	letterbox.color = Color(0, 0, 0, 1)
	letterbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_root.add_child(letterbox)

	_ui_space = Control.new()
	_ui_space.name = "UISpace"
	_ui_space.size = Vector2(DESIGN_W, DESIGN_H)
	_ui_space.clip_contents = true
	_ui_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_root.add_child(_ui_space)

	_stage = Control.new()
	_stage.name = "Stage"
	_stage.size = Vector2(DESIGN_W, DESIGN_H)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_space.add_child(_stage)

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.visible = false
	_status_label.position = Vector2(8, DESIGN_H - 20)
	_status_label.size = Vector2(DESIGN_W - 16, 18)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	Lang.apply_font(_status_label)
	_ui_space.add_child(_status_label)

	get_viewport().size_changed.connect(_layout_ui_space)
	_layout_ui_space()


func _art_visible(value: bool) -> void:
	if _art_root != null:
		_art_root.visible = value
	if screen_root != null:
		screen_root.visible = not value


func _layout_ui_space() -> void:
	if _ui_space == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var scale_factor: float = minf(viewport_size.x / DESIGN_W, viewport_size.y / DESIGN_H)
	_ui_space.scale = Vector2(scale_factor, scale_factor)
	_ui_space.position = Vector2(
		(viewport_size.x - DESIGN_W * scale_factor) * 0.5,
		(viewport_size.y - DESIGN_H * scale_factor) * 0.5)


func _fail(message: String) -> void:
	last_error = message
	push_error("menu_art: " + message)
	printerr("menu_art: FAIL CLOSED: " + message)
	_art_visible(false)


func _refresh_status() -> void:
	if _status_label == null:
		return
	_status_label.text = status_text
	_status_label.visible = not status_text.is_empty()


# ---------------------------------------------------------------- art widgets

func _rect_of(node: Dictionary) -> Rect2:
	return Rect2(float(node["x"]), float(node["y"]),
		float(node["width"]), float(node["height"]))


## Recovered translation when the table has the key, else a readable
## placeholder. Never an invented game string.
func _text_for(key: String) -> String:
	if Lang.has_key(key):
		return Lang.text(key)
	if PLACEHOLDER_LABELS.has(key):
		return String(PLACEHOLDER_LABELS[key])
	return key.replace("_", " ").capitalize()


func _make_label(text: String, rect: Rect2, font_size: int,
		color: Color, centered: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Lang.apply_font(label)
	return label


func _make_texture_rect(texture: Texture2D, rect: Rect2, keep_aspect: bool) -> TextureRect:
	var node: TextureRect = TextureRect.new()
	node.texture = texture
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = (TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep_aspect
		else TextureRect.STRETCH_SCALE)
	return node


func _clear_stage() -> void:
	for child: Node in _stage.get_children():
		_stage.remove_child(child)
		child.queue_free()
	_built_rects.clear()


func _background_texture(screen: String) -> Texture2D:
	var basename: String = String(SCREENS[screen]["background"])
	var texture: Texture2D = _texture("background/" + basename.to_lower())
	if texture == null:
		return null
	if texture.get_width() < int(DESIGN_W) or texture.get_height() < int(DESIGN_H):
		_fail("background " + basename + " is smaller than the 480x320 art rectangle")
		return null
	# Every decoded menu background stores its visible art exactly at (0,0) in a
	# 480x320 rectangle (verified over all 10 backgrounds).
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, DESIGN_W, DESIGN_H)
	return atlas


func _show_art_screen(screen: String) -> void:
	if not SCREENS.has(screen):
		_fail("unknown screen " + screen)
		return
	screen_id = screen
	_clear_stage()
	var background: Texture2D = _background_texture(screen)
	if background == null:
		return
	var backdrop: TextureRect = _make_texture_rect(
		background, Rect2(0, 0, DESIGN_W, DESIGN_H), false)
	backdrop.name = "Background"
	_stage.add_child(backdrop)

	for node: Variant in (_screens[screen]["layout"] as Array):
		_build_art_widget(screen, node as Dictionary)

	_refresh_status()


func _build_art_widget(screen: String, node: Dictionary) -> void:
	var rect: Rect2 = _rect_of(node)
	var type: String = String(node["type"])
	var widget_name: String = String(node["name"])
	match type:
		"picture":
			var texture: Texture2D = _texture(
				_file_key(_file_reference(node["file"] as Dictionary)))
			if texture == null:
				return
			var picture: TextureRect = _make_texture_rect(texture, rect,
				String(node.get("mantainaspectratio", "false")) == "true")
			picture.name = "Picture_" + widget_name
			_stage.add_child(picture)
			_built_rects[widget_name] = rect
		"blbutton":
			var file_node: Dictionary = node["file"]
			var reference: Dictionary = file_node["file"]
			var texture: Texture2D = _texture(_file_key(_file_reference(reference)))
			if texture == null:
				return
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			if file_node.has("subrect_width"):
				atlas.region = Rect2(
					float(file_node.get("subrect_x", 0)),
					float(file_node.get("subrect_y", 0)),
					float(file_node["subrect_width"]),
					float(file_node["subrect_height"]))
			else:
				atlas.region = Rect2(0, 0, texture.get_width(), texture.get_height())
			var button: TextureRect = _make_texture_rect(atlas, rect, false)
			button.name = "Button_" + widget_name
			_stage.add_child(button)
			_built_rects[widget_name] = rect
		"bllabel", "label":
			var text: String = _label_text_for(screen, node)
			var color: Color = Color(1, 1, 1, 1)
			if node.has("textcolor"):
				var rgb: Array = node["textcolor"]
				color = Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))
			if String(node.get("uppercase", "false")) == "true":
				text = text.to_upper()
			var font_size: int = clampi(int(round(rect.size.y * 0.55)), 8, 28)
			var label: Label = _make_label(text, rect, font_size, color,
				String(node.get("align", "")) == "center")
			label.name = "Label_" + widget_name
			_stage.add_child(label)
			_built_rects[widget_name] = rect
		"blmenu":
			_build_art_menu(screen, node, rect)
			_built_rects[widget_name] = rect
		_:
			_fail("unsupported widget type '" + type + "' in " + screen)


func _file_reference(reference: Dictionary) -> Dictionary:
	return reference["$file"] as Dictionary


func _label_text_for(screen: String, node: Dictionary) -> String:
	var sources: Dictionary = node.get("datasources", {})
	var text_source: Variant = sources.get("text")
	if typeof(text_source) == TYPE_ARRAY and (text_source as Array).size() == 2:
		var kind: String = String((text_source as Array)[0])
		var value: String = String((text_source as Array)[1])
		if kind == "translate":
			return _text_for(value)
		_fail("unsupported label datasource '" + kind + "' in " + screen)
		return ""
	_fail("label " + String(node.get("name", "?")) + " has no text datasource")
	return ""


func _build_art_menu(screen: String, node: Dictionary, rect: Rect2) -> void:
	var rows: Array = _rows_for(screen)
	if rows.is_empty():
		_fail("blmenu without rows in " + screen)
		return
	var count: int = rows.size()
	var row_height: float = minf(rect.size.y / float(count), 40.0)
	var font_size: int = clampi(int(round(row_height * 0.45)), 10, 20)
	var start_y: float = rect.position.y
	if String(node.get("valign", "")) == "middle":
		start_y += (rect.size.y - row_height * float(count)) * 0.5
	var text_left: float = 0.0
	var text_width: float = rect.size.x
	if String(node.get("align", "")) != "center":
		# The list's text column is anchored to the menu rect's left edge with a
		# fixed inset, so the highlight never changes a row's position.
		text_left = 12.0
		text_width = rect.size.x - 24.0
	selection = clampi(selection, 0, count - 1)
	for index: int in range(count):
		var row_data: Dictionary = rows[index]
		var key: String = String(row_data["key"])
		var row: Rect2 = Rect2(
			rect.position.x + text_left, start_y + row_height * float(index),
			text_width, row_height)
		var color: Color = COLOR_SELECTED if index == selection else COLOR_IDLE
		var label: Label = _make_label(_text_for(key), row, font_size, color, false)
		label.name = "Option_" + key
		_stage.add_child(label)


# ------------------------------------------------------------------- report

## Geometry of every built widget for the current screen, keyed by recovered
## widget name. Used by tests/validate_menu_art_menu.gd.
func built_rects() -> Dictionary:
	return _built_rects.duplicate()


## Labels currently drawn, in order, so a test can check the recovered text
## without reading pixels.
func option_labels() -> Array:
	var out: Array = []
	for child: Node in _stage.get_children():
		if String(child.name).begins_with("Option_"):
			out.append((child as Label).text)
	return out

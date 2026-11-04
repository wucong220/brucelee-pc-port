extends Control
## Opt-in recovered scene dock (`BRUCELEE_SCENE_SELECT=1`).
##
## Draws the `selectscenery.ui` dock decoded from `data.zpak` instead of the
## text scene rows: ten 165x114 icon cards in the recovered order, the recovered
## `scenery_name` label above the dock, the recovered yellow selection line and
## the recovered page-flip navigation sound.  The geometry is used exactly as
## decoded (480x320 layout space, letterboxed and scaled to the window the same
## way the art menu does it).
##
## What this node does NOT do:
##   * it never invents a scenery.  The rows, their order, icons, names and the
##     port scene variant all come from `scene_catalog.gd` (decoded
##     `sceneries.list` + `selectscenery.ui` + the recovered `.lang` table);
##   * it never draws a fallback layout.  A missing/invalid layout, a dock that
##     does not match the list, or a missing icon texture fails closed: the dock
##     reports the error, stays hidden, and the caller keeps the text menu;
##   * it starts no match.  Confirming emits the command `main.gd` already
##     implements for that scene variant, so the scene switch itself stays in
##     one place (`main.gd`), shared with the text scene rows.
##
## The only port chrome is a one-line control hint under the dock (the recovered
## layout has no such widget); it is labelled as port chrome in the report.

const Catalog = preload("res://scripts/scene_catalog.gd")
const Lang = preload("res://scripts/menu_lang.gd")

const DESIGN_W := 480.0
const DESIGN_H := 320.0
## Recovered label: colour and uppercase flag are read from the decoded widget;
## these are the decoded fallbacks if a layout ever omits them.
const DEFAULT_LABEL_COLOR := Color(1.0, 1.0, 0.0, 1.0)
## Port chrome (not recovered): controls line under the dock.
const PORT_HINT_TEXT := "LEFT/RIGHT choose   ENTER apply   ESC back"
const PORT_HINT_SIZE := 9

const SFX_ROOT_ENV := "BRUCELEE_MENU_SFX_ROOT"
const ART_ROOT_ENV := "BRUCELEE_SCENE_SELECT_ART"

var ready_ok: bool = false
var error: String = ""
var selection: int = 0
var last_sfx: String = ""
var sfx_missing: bool = false

var catalog = null
var _root: Control = null
var _ui_space: Control = null
var _stage: Control = null
var _label: Label = null
var _hint: Label = null
var _textures: Dictionary = {}
var _icon_paths: Dictionary = {}
var _built_rects: Dictionary = {}
var _sfx_player: AudioStreamPlayer = null


class RectOutline extends Control:
	var line_color: Color = Color(1.0, 1.0, 0.0, 1.0)
	var line_width: float = 2.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), line_color, false, line_width)


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	catalog = Catalog.new()


## Loads the decoded layout + list and builds the canvas.  Returns false with
## `error` set when the dock cannot be drawn from recovered data.
func configure(language: String = "") -> bool:
	ready_ok = false
	error = ""
	if not catalog.load_catalog(language, OS.get_environment(ART_ROOT_ENV)):
		error = String(catalog.error)
		return false
	_icon_paths = {}
	_textures = {}
	for row: Dictionary in catalog.rows():
		_icon_paths[String(row.get("icon", ""))] = String(row.get("icon_path", ""))
	_build()
	_load_menu_sfx()
	ready_ok = true
	visible = false
	return true


# ------------------------------------------------------------------ build

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root = Control.new()
	_root.name = "DockRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_ui_space = Control.new()
	_ui_space.name = "UISpace"
	_ui_space.size = Vector2(DESIGN_W, DESIGN_H)
	_ui_space.clip_contents = true
	_ui_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ui_space)

	_stage = Control.new()
	_stage.name = "Stage"
	_stage.size = Vector2(DESIGN_W, DESIGN_H)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_space.add_child(_stage)

	var label_rect: Rect2 = _rect_of(catalog.label_widget())
	var color: Color = _color_of(catalog.label_widget().get("textcolor", []))
	_label = _make_label("", label_rect,
		clampi(int(round(label_rect.size.y * 0.55)), 8, 28), color,
		String(catalog.label_widget().get("align", "")) == "center")
	_label.name = "Label_scenery_name"
	_stage.add_child(_label)

	_hint = _make_label(PORT_HINT_TEXT,
		Rect2(0.0, DESIGN_H - 24.0, DESIGN_W, 20.0), PORT_HINT_SIZE,
		Color(0.78, 0.81, 0.86, 1.0), true)
	_hint.name = "PortHint"
	_stage.add_child(_hint)

	get_viewport().size_changed.connect(_layout_ui_space)
	_layout_ui_space()
	_rebuild()


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


# ------------------------------------------------------------------ render

func _rebuild() -> void:
	if _stage == null:
		return
	for child: Node in _stage.get_children():
		if child == _label or child == _hint:
			continue
		_stage.remove_child(child)
		child.queue_free()
	_built_rects.clear()
	var dock: Dictionary = catalog.dock_widget()
	var dock_rect: Rect2 = _rect_of(dock)
	_built_rects["sceneries"] = dock_rect
	# The label keeps the decoded position/width; a Label cannot be shorter than
	# its font line height, so its height may grow by a couple of pixels.
	_built_rects["scenery_name"] = (_label.get_rect() if _label != null
		else _rect_of(catalog.label_widget()))
	var option_w: float = float(dock.get("optionwidth", 165.0))
	var option_h: float = float(dock.get("optionheight", 114.0))
	var separation: float = float(dock.get("separation", 0.0))
	var cell: float = option_w + separation
	var centre_x: float = dock_rect.position.x + dock_rect.size.x * 0.5
	var outline_color: Color = _color_of(dock.get("linerectcolor", []))
	var line: bool = String(dock.get("linerect", "false")) == "true"
	var total: int = catalog.size()
	if total <= 0:
		_fail("catalogue has no scenes")
		return
	selection = clampi(selection, 0, total - 1)
	# The decoded dock rectangle is the visible window: the selected card sits on
	# the dock's horizontal centre and neighbours are one `cell` apart, so the
	# recovered optionwidth/optionheight/separation are preserved exactly while
	# both ends of the list stay reachable and the outer cards bleed past the
	# screen edge (selectscenery.ui declares x=-50, width=580 on a 480x320
	# canvas, so that bleed is part of the recovered layout and is clipped here).
	for index: int in range(total):
		var row: Dictionary = catalog.row(index)
		var item_rect := Rect2(
			centre_x + (float(index) - float(selection)) * cell - option_w * 0.5,
			dock_rect.position.y + (dock_rect.size.y - option_h) * 0.5,
			option_w, option_h)
		var texture: Texture2D = _texture(String(row.get("icon", "")))
		if texture == null:
			return
		# The card is the decoded option rect drawn 1:1 with the cropped artwork
		# texture, so no distortion and no black padding can appear.
		var card: TextureRect = _make_texture_rect(texture, item_rect, false)
		card.name = "Item_%02d" % index
		_stage.add_child(card)
		# Record the rect the node really has, not the rect that was requested:
		# an inherited minimum size would silently change what is drawn, and the
		# geometry test must be able to see that.
		_built_rects["item_%02d" % index] = card.get_rect()
		if index == selection and line:
			var outline: RectOutline = RectOutline.new()
			outline.name = "Selection"
			outline.position = item_rect.position
			outline.size = item_rect.size
			outline.line_color = outline_color
			outline.line_width = 2.0
			outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_stage.add_child(outline)
	_label.text = _selected_text()


func _selected_text() -> String:
	var row: Dictionary = catalog.row(selection)
	if row.is_empty():
		return ""
	var text: String = String(row.get("label", row.get("name", "")))
	if String(catalog.label_widget().get("uppercase", "false")) == "true":
		text = text.to_upper()
	return text


func _texture(icon: String) -> Texture2D:
	## The decoded dock icons are 256x128 textures whose visible artwork is
	## exactly the top-left `optionwidth x optionheight` rectangle (165x114 for
	## all ten icons, verified over the decoded set); the rest is opaque black
	## padding.  The recovered option size is therefore the artwork crop, not a
	## scale target: the card draws that region 1:1, which is also why the decoded
	## separation is 0.
	if _textures.has(icon):
		return _textures[icon] as Texture2D
	if not _icon_paths.has(icon):
		_fail("dock icon '%s' is not in the catalogue" % icon)
		return null
	var path: String = String(_icon_paths[icon])
	if not FileAccess.file_exists(path):
		_fail("missing dock icon texture: " + path)
		return null
	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty():
		_fail("cannot decode dock icon texture: " + path)
		return null
	var option: Vector2 = _option_size()
	if float(image.get_width()) < option.x or float(image.get_height()) < option.y:
		_fail("dock icon %s is %dx%d, smaller than the decoded %dx%d option" % [
			icon, image.get_width(), image.get_height(), int(option.x), int(option.y)])
		return null
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(image)
	atlas.region = Rect2(0, 0, option.x, option.y)
	_textures[icon] = atlas
	return atlas


func _option_size() -> Vector2:
	var dock: Dictionary = catalog.dock_widget()
	return Vector2(float(dock.get("optionwidth", 165.0)),
		float(dock.get("optionheight", 114.0)))


# ------------------------------------------------------------------- input

func show_dock() -> void:
	if not ready_ok:
		return
	selection = clampi(selection, 0, maxi(catalog.size() - 1, 0))
	visible = true
	_layout_ui_space()
	_rebuild()


## Selects `index` (clamped) and redraws; used by the menu when the scene
## submenu opens.
func select_index(index: int) -> void:
	if not ready_ok or catalog.size() <= 0:
		return
	selection = clampi(index, 0, catalog.size() - 1)
	_rebuild()


## Replaces the port-chrome hint line (used for fail-closed explanations).
func set_hint(text: String) -> void:
	if _hint != null:
		_hint.text = text


func hide_dock() -> void:
	visible = false


## Moves the selection by `delta` inside the recovered list.  The decoded dock
## declares `wraparround=false`, so both ends clamp; returns true when the
## selection changed (the caller then plays the navigation sound).
func move(delta: int) -> bool:
	if not ready_ok or catalog.size() <= 0:
		return false
	var next_index: int = clampi(selection + delta, 0, catalog.size() - 1)
	if next_index == selection:
		return false
	selection = next_index
	_rebuild()
	_play_sfx()
	return true


func selected_row() -> Dictionary:
	return catalog.row(selection)


## True while this node owns the screen (drawn, valid data).
func is_active() -> bool:
	return ready_ok and visible


# ------------------------------------------------------------------- sfx

func _load_menu_sfx() -> void:
	## The decoded dock's `sound` is sounds/menu_sfx/story_page_flip_short_version
	## .wav.  When the staging root does not carry it the dock stays silent and
	## the menu keeps its existing navigation sound (no invented substitute).
	var dock: Dictionary = catalog.dock_widget()
	var sound: Variant = dock.get("sound", {})
	if typeof(sound) != TYPE_DICTIONARY:
		sfx_missing = true
		return
	var reference: Variant = (sound as Dictionary).get("$file", {})
	if typeof(reference) != TYPE_DICTIONARY:
		sfx_missing = true
		return
	var basename: String = String((reference as Dictionary).get("basename", "")).to_lower()
	var extension: String = String((reference as Dictionary).get("extension", "wav"))
	var root: String = OS.get_environment(SFX_ROOT_ENV)
	if root.is_empty():
		var local_app_data: String = OS.get_environment("LOCALAPPDATA")
		if local_app_data.is_empty():
			sfx_missing = true
			return
		root = local_app_data.path_join(
			"BruceLee-PC-Port/p5-menu-assets-20261030/adreno_200/sounds/menu_sfx")
	var path: String = ""
	for name: String in DirAccess.get_files_at(root):
		if name.get_basename().to_lower() == basename and name.get_extension().to_lower() == extension:
			path = root.path_join(name)
			break
	if path.is_empty():
		sfx_missing = true
		return
	var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
	if stream == null:
		sfx_missing = true
		return
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "PageFlip"
	_sfx_player.stream = stream
	add_child(_sfx_player)


func _play_sfx() -> void:
	if _sfx_player == null:
		return
	last_sfx = "story_page_flip_short_version"
	_sfx_player.play()


# ----------------------------------------------------------------- helpers

func _rect_of(node: Dictionary) -> Rect2:
	return Rect2(float(node.get("x", 0.0)), float(node.get("y", 0.0)),
		float(node.get("width", 0.0)), float(node.get("height", 0.0)))


func _color_of(rgb: Variant) -> Color:
	if typeof(rgb) == TYPE_ARRAY and (rgb as Array).size() >= 3:
		return Color8(int((rgb as Array)[0]), int((rgb as Array)[1]), int((rgb as Array)[2]))
	return DEFAULT_LABEL_COLOR


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


func _make_texture_rect(texture: Texture2D, rect: Rect2,
		keep_aspect: bool) -> TextureRect:
	var node: TextureRect = TextureRect.new()
	node.texture = texture
	# The expansion/stretch mode is set BEFORE the rect: a TextureRect whose
	# expand_mode still defaults to EXPAND_KEEP_SIZE reports the texture size as
	# its minimum, which would silently clamp the recovered 165x114 option rect to
	# the 256x128 icon size.
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = (TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep_aspect
		else TextureRect.STRETCH_SCALE)
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


func _fail(message: String) -> void:
	ready_ok = false
	error = message
	visible = false
	push_error("scene_select_dock: " + message)
	printerr("scene_select_dock: FAIL CLOSED: " + message)


# -------------------------------------------------------------- test hooks

## Geometry of every built widget in the 480x320 layout space, keyed by the
## recovered widget name (the dock and the label) or `item_NN`.
func built_rects() -> Dictionary:
	return _built_rects.duplicate()


## Text currently drawn in the recovered `scenery_name` label.
func label_text() -> String:
	return _label.text if _label != null else ""


func label_color() -> Color:
	return _label.get_theme_color("font_color") if _label != null else Color(0, 0, 0, 0)


func row_labels() -> Array:
	var out: Array = []
	for row: Dictionary in catalog.rows():
		out.append(String(row.get("label", "")))
	return out


## Texture region drawn for each card, in dock order.  The decoded icons are
## 256x128 with their artwork at (0,0)-(optionwidth,optionheight), so every
## region must be that crop.
func card_regions() -> Array:
	var out: Array = []
	if _stage == null:
		return out
	for child: Node in _stage.get_children():
		if not (child is TextureRect) or not String(child.name).begins_with("Item_"):
			continue
		var texture: Texture2D = (child as TextureRect).texture
		if texture is AtlasTexture:
			out.append((texture as AtlasTexture).region)
		elif texture != null:
			out.append(Rect2(0, 0, texture.get_width(), texture.get_height()))
		else:
			out.append(Rect2())
	return out

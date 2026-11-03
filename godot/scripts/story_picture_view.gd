extends Control
## Full-frame renderer for a recovered story `picture` subevent.
##
## The original screen (`adreno_200/gui/storypicture.ui`) defines a 480x320
## `frame` with up to four `picture` layers whose `file/x/y/color_r/g/b/alpha`
## are data-bound to the story picture layer fields, plus a bottom `storytext`
## box (x=20 y=250 w=440 h=60, centred, uppercase).  The isolated prototype maps
## that frame onto the live viewport and draws the base-mip artworks decoded from
## the original `story/*.tex` textures (`res://data/story/art/<stem>.png`).
##
## Playback decisions (documented in REPORT.md) for a still frame:
##   * position = (x, y) normalised centre of the frame (default 0.5, 0.5);
##   * background (layer 0) is stretched to cover the frame;
##   * character layers fit ~80% of the frame height, then multiply by `scale`;
##   * `color` of three floats is an RGB tint; a one/two float `color` is a grey
##     brightness taken from its last value (0..255); `alpha` uses its last value.
## These are presentation choices; the raw decoded values are preserved in
## mapping/picture_texture_map.json alongside the derived display values.

const ART_DIR: String = "res://data/story/art/"
const TEXT_PATH: String = "res://data/story/story_picture_text.json"
const MAX_LAYERS: int = 4

const COLOR_TEXT: Color = Color(0.95, 0.96, 0.98)
const COLOR_DIM: Color = Color(0.72, 0.75, 0.80)
const COLOR_CAPTION_BG: Color = Color(0.015, 0.02, 0.03, 0.72)

var _text: Dictionary = {}
var _caption_bg: ColorRect
var _caption_en: Label
var _caption_meta: Label
var _last_report: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_text()
	_build_caption()


func _load_text() -> void:
	if not FileAccess.file_exists(TEXT_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXT_PATH))
	if parsed is Dictionary:
		_text = parsed


func _build_caption() -> void:
	_caption_bg = ColorRect.new()
	_caption_bg.color = COLOR_CAPTION_BG
	_caption_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_bg.z_index = 10
	_caption_bg.visible = false
	add_child(_caption_bg)

	_caption_en = Label.new()
	_caption_en.add_theme_font_size_override("font_size", 22)
	_caption_en.add_theme_color_override("font_color", COLOR_TEXT)
	_caption_en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_en.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_en.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_en.z_index = 11
	_caption_en.visible = false
	add_child(_caption_en)

	_caption_meta = Label.new()
	_caption_meta.add_theme_font_size_override("font_size", 12)
	_caption_meta.add_theme_color_override("font_color", COLOR_DIM)
	_caption_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_meta.z_index = 12
	_caption_meta.visible = false
	add_child(_caption_meta)


func clear_layers() -> void:
	for child: Node in get_children():
		if child == _caption_bg or child == _caption_en or child == _caption_meta:
			continue
		remove_child(child)
		child.queue_free()


## Build the visible stack for one picture subevent.  Returns a small report so
## the flow (and tests) can assert how many textures bound and which are missing.
func render(sub: Dictionary) -> Dictionary:
	clear_layers()
	var stage: Vector2 = get_viewport_rect().size
	if stage.x <= 0.0 or stage.y <= 0.0:
		stage = Vector2(1280, 720)
	var layers: Array = sub.get("layers", [])
	var loaded: int = 0
	var missing: Array = []
	for index: int in range(mini(layers.size(), MAX_LAYERS)):
		var layer: Dictionary = layers[index]
		var ref: String = String(Dictionary(layer.get("picture", {})).get("file", ""))
		var texture: Texture2D = _load_texture(ref)
		if texture == null:
			missing.append(ref)
			continue
		var display: Dictionary = _display(layer)
		var is_background: bool = index == 0
		var rect: TextureRect = TextureRect.new()
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var size: Vector2 = _layer_size(texture.get_size(), is_background,
			float(display["scale"]), stage)
		rect.size = size
		var center: Vector2 = Vector2(
			float(display["x"]) * stage.x, float(display["y"]) * stage.y)
		rect.position = center - size * 0.5
		if is_background:
			rect.position.x = clampf(rect.position.x, stage.x - size.x, 0.0)
			rect.position.y = clampf(rect.position.y, stage.y - size.y, 0.0)
		var tint: Array = display["tint"]
		rect.modulate = Color(float(tint[0]), float(tint[1]), float(tint[2]),
			float(display["alpha"]))
		add_child(rect)
		loaded += 1
	_update_caption(sub, stage)
	_last_report = {
		"loaded": loaded,
		"missing": missing,
		"layers": layers.size(),
		"stage": stage,
	}
	return _last_report


func last_report() -> Dictionary:
	return _last_report


func _update_caption(sub: Dictionary, stage: Vector2) -> void:
	var key: String = String(sub.get("text", ""))
	var entry: Dictionary = {}
	if _text.has(key):
		entry = _text[key]
	var en: String = String(entry.get("en", ""))
	var zh: String = String(entry.get("zh", ""))
	if en.is_empty():
		en = key
	# storypicture.ui storytext box: x=20 y=250 w=440 h=60 in a 480x320 frame.
	var box_x: float = stage.x * (20.0 / 480.0)
	var box_w: float = stage.x * (440.0 / 480.0)
	var box_y: float = stage.y * (250.0 / 320.0)
	var box_h: float = stage.y * (60.0 / 320.0)
	_caption_bg.position = Vector2(box_x - 12.0, box_y - 6.0)
	_caption_bg.size = Vector2(box_w + 24.0, box_h + 12.0)
	_caption_bg.visible = true
	_caption_en.position = Vector2(box_x, box_y - 4.0)
	_caption_en.size = Vector2(box_w, box_h - 14.0)
	_caption_en.text = en.to_upper()
	_caption_en.visible = true
	_caption_meta.position = Vector2(box_x, box_y + box_h - 18.0)
	_caption_meta.size = Vector2(box_w, 18.0)
	var meta: String = key
	if not zh.is_empty():
		meta = "%s   ·   %s" % [key, zh]
	_caption_meta.text = meta
	_caption_meta.visible = true


func hide_caption() -> void:
	_caption_bg.visible = false
	_caption_en.visible = false
	_caption_meta.visible = false


func _load_texture(ref: String) -> Texture2D:
	if ref.is_empty():
		return null
	var stem: String = ref.get_file().get_basename().to_lower()
	var resource_path: String = ART_DIR + stem + ".png"
	if ResourceLoader.exists(resource_path):
		var resource: Resource = load(resource_path)
		if resource is Texture2D:
			return resource
	var alt_root: String = OS.get_environment("BRUCELEE_STORY_ART_DIR")
	if not alt_root.is_empty():
		var absolute: String = alt_root.path_join(stem + ".png")
		if FileAccess.file_exists(absolute):
			var image: Image = Image.load_from_file(absolute)
			if image != null:
				return ImageTexture.create_from_image(image)
	return null


func _layer_size(texture_size: Vector2, is_background: bool, scale: float,
		stage: Vector2) -> Vector2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return stage
	if is_background:
		var cover: float = maxf(stage.x / texture_size.x, stage.y / texture_size.y)
		return texture_size * cover * maxf(scale, 0.01) * 1.05
	var fit: float = (stage.y * 0.8) / texture_size.y
	return texture_size * fit * maxf(scale, 0.01)


func _last(value: Variant) -> Variant:
	if value == null:
		return null
	if value is Array:
		var arr: Array = value
		return null if arr.is_empty() else arr[arr.size() - 1]
	return value


func _display(layer: Dictionary) -> Dictionary:
	var tint: Array = [1.0, 1.0, 1.0]
	var tint_mode: String = "default"
	var color: Variant = layer.get("color")
	if color is Array and (color as Array).size() == 3:
		var c: Array = color
		tint = [float(c[0]) / 255.0, float(c[1]) / 255.0, float(c[2]) / 255.0]
		tint_mode = "rgb"
	elif color is Array and (color as Array).size() > 0:
		var c2: Array = color
		var grey: float = float(c2[c2.size() - 1]) / 255.0
		tint = [grey, grey, grey]
		tint_mode = "grey"
	var alpha_value: Variant = _last(layer.get("alpha"))
	var alpha: float = 1.0 if alpha_value == null else clampf(float(alpha_value), 0.0, 1.0)
	var scale_value: Variant = _last(layer.get("scale"))
	var scale: float = 1.0 if scale_value == null else float(scale_value)
	var x_value: Variant = _last(layer.get("x"))
	var y_value: Variant = _last(layer.get("y"))
	var x: float = 0.5 if x_value == null else float(x_value)
	var y: float = 0.5 if y_value == null else float(y_value)
	return {
		"x": x, "y": y, "scale": scale, "tint": tint,
		"tint_mode": tint_mode, "alpha": alpha,
	}

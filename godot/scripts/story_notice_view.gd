class_name StoryNoticeView
extends Control

## Renders one recovered notice (LevelUpNotify / ExperienceUnlock) using the
## widget rectangles and text sources decoded from adreno_200/gui/*.ui.
##
## The layout is data-driven: story_notice.json carries the widgets (x, y,
## width, height, colours) recovered from levelup.ui / unlock.ui. This view only
## translates those into Godot Controls. It is safe to instantiate in a headless
## SceneTree (no drawing is required for the model tests) and emits `dismissed`
## when the single "Continue"/"OK" option is activated.

signal dismissed

const BASE_CANVAS := Vector2(480, 360)

var _content: Control = null
var _notice: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func hide_notice() -> void:
	if _content != null:
		_content.queue_free()
		_content = null
	visible = false


func present(notice: Dictionary) -> void:
	hide_notice()
	_notice = notice
	_content = Control.new()
	_content.name = "NoticeContent"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	var scale: float = 1.0
	if size.x > 1.0 and size.y > 1.0:
		scale = minf(size.x / BASE_CANVAS.x, size.y / BASE_CANVAS.y)
	var scr: Dictionary = notice.get("layout", {})
	var widgets: Array = scr.get("widgets", [])
	for w: Variant in widgets:
		if w is Dictionary:
			_build_widget(Dictionary(w), notice, scale)
	visible = true


func _text_for(widget: Dictionary, notice: Dictionary) -> String:
	var name: String = String(widget.get("name", ""))
	var kind: String = String(notice.get("kind", ""))
	if name == "level":
		return String(notice.get("body", ""))
	if name == "title":
		# unlock.ui has two "title" widgets: the heading (y=80) and the item
		# name (y=210). The heading is the unlock title, the lower one is itemname.
		if kind == "experienceunlock" and int(widget.get("y", 0)) >= 200:
			return String(notice.get("item_name", ""))
		return String(notice.get("title", ""))
	if name == "menu":
		return String(notice.get("menu_label", ""))
	return ""


func _build_widget(widget: Dictionary, notice: Dictionary, scale: float) -> void:
	var type: String = String(widget.get("type", ""))
	var x: float = float(widget.get("x", 0)) * scale
	var y: float = float(widget.get("y", 0)) * scale
	var w: float = float(widget.get("width", 0)) * scale
	var h: float = float(widget.get("height", 0)) * scale
	match type:
		"staticrect":
			var rect: ColorRect = ColorRect.new()
			rect.position = Vector2(x, y)
			rect.size = Vector2(maxf(w, 1.0), maxf(h, 1.0))
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.color = _color(widget.get("bordercolor", [255, 255, 0, 255]))
			_content.add_child(rect)
		"label":
			var label: Label = Label.new()
			label.position = Vector2(x, y)
			label.size = Vector2(maxf(w, 1.0), maxf(h, 1.0))
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_color_override("font_color", _color(widget.get("textcolor", [255, 255, 255, 255])))
			label.add_theme_font_size_override("font_size", int(round(24.0 * scale)) if int(widget.get("font", 1)) >= 2 else int(round(16.0 * scale)))
			var t: String = _text_for(widget, notice)
			var upper: Variant = widget.get("uppercase", false)
			if (upper is bool and upper) or String(upper).to_lower() == "true":
				t = t.to_upper()
			label.text = t
			_content.add_child(label)
		"blpicture":
			# Unlock thumbnail: width/height/file come from unlocker.unlockthumbnail*,
			# which this recovery does not decode. Draw a NOT RECOVERED placeholder
			# so nothing is fabricated.
			var box: ColorRect = ColorRect.new()
			var side: float = 96.0 * scale
			box.position = Vector2(x - side * 0.5, y - side * 0.5)
			box.size = Vector2(side, side)
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.color = Color(0.15, 0.15, 0.12, 0.9)
			_content.add_child(box)
			if notice.get("icon_recovered", false) != true:
				var lbl: Label = Label.new()
				lbl.position = box.position
				lbl.size = box.size
				lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.add_theme_font_size_override("font_size", int(round(11.0 * scale)))
				lbl.add_theme_color_override("font_color", Color(0.85, 0.6, 0.3))
				lbl.text = String(notice.get("icon_label", "NOT RECOVERED"))
				_content.add_child(lbl)
		"blmenu":
			var button: Button = Button.new()
			button.position = Vector2(x, y)
			button.size = Vector2(maxf(w, 1.0), maxf(h, 1.0))
			button.text = String(notice.get("menu_label", ""))
			button.add_theme_font_size_override("font_size", int(round(20.0 * scale)))
			button.pressed.connect(_on_option_pressed)
			_content.add_child(button)


func _color(rgba: Variant) -> Color:
	if rgba is Array and (rgba as Array).size() >= 3:
		var a: Array = rgba
		var alpha: float = float(a[3]) / 255.0 if a.size() > 3 else 1.0
		return Color(float(a[0]) / 255.0, float(a[1]) / 255.0, float(a[2]) / 255.0, alpha)
	return Color(1, 1, 1, 1)


func _on_option_pressed() -> void:
	dismissed.emit()

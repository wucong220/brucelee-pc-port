extends Control
class_name PortCreditsRollView
## Real UI view for one recovered credit roll.
##
## It draws CCreditsView::TLine-equivalent lines scrolled by the recovered rule
## (`credits_roll.gd`) and measures every line height from the runtime font.
## The 72-byte TLine struct stride is never used as a pixel height.

signal finished

const Roll = preload("res://scripts/credits_roll.gd")

var _roll = null
var _lines: PackedStringArray = PackedStringArray()
var _heights: PackedInt32Array = PackedInt32Array()
var _font: Font = null
var _font_size: int = 16
var _text_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _finished_emitted: bool = false
var _configure_error: String = ""


func configure(lines: PackedStringArray, view_height: int, font: Font,
		font_size: int = 16) -> bool:
	_configure_error = ""
	_lines = lines.duplicate()
	_font = font
	_font_size = font_size
	_finished_emitted = false
	if _lines.is_empty():
		_configure_error = "no credit lines"
		return false
	if _font == null:
		_configure_error = "no runtime font for credit roll"
		return false
	var line_height: int = _measure_line_height()
	if line_height <= 0:
		_configure_error = "runtime font reported a non-positive line height"
		return false
	_heights = PackedInt32Array()
	for _i: int in range(_lines.size()):
		_heights.append(line_height)
	_roll = Roll.new(_heights, view_height)
	clip_contents = true
	set_process(true)
	queue_redraw()
	return true


## Runtime font measurement (never the 72-byte struct stride).
func _measure_line_height() -> int:
	if _font == null:
		return 0
	return maxi(1, int(ceil(_font.get_height(_font_size))))


func _clean_control_codes(value: String) -> String:
	# Engine strings start with 0x00AC 'C<n>' palette-colour control codes.
	# Strip the control sequence; the text itself stays verbatim and no palette
	# colour is invented.
	var out: String = ""
	var i: int = 0
	while i < value.length():
		var ch: String = value.substr(i, 1)
		if ch == "\u00ac" and i + 2 < value.length() and value.substr(i + 1, 1) == "C":
			i += 3
			continue
		if ch == "\u00ac":
			i += 2 if i + 1 < value.length() else 1
			continue
		out += ch
		i += 1
	return out


func _process(_delta: float) -> void:
	if _roll == null:
		return
	advance_ms(Time.get_ticks_msec())


func advance_ms(now_ms: int) -> int:
	if _roll == null:
		return 0
	var fired: int = _roll.advance_ms(now_ms)
	if _roll.ended and not _finished_emitted:
		_finished_emitted = true
		call_deferred("_emit_finished")
	queue_redraw()
	return fired


func _emit_finished() -> void:
	finished.emit()


## Test-only: restore the Init state (-view_height) and clear the 33 ms clock.
func reset_timing() -> void:
	if _roll == null:
		return
	_roll.configure(_roll.line_heights, _roll.view_height)
	_finished_emitted = false
	queue_redraw()


func tick_steps(count: int) -> void:
	if _roll == null:
		return
	for _i: int in range(maxi(count, 0)):
		_roll.tick()
	if _roll.ended and not _finished_emitted:
		_finished_emitted = true
		call_deferred("_emit_finished")
	queue_redraw()


func _draw() -> void:
	if _roll == null or _font == null:
		return
	var width: float = maxf(size.x, 0.0)
	for i: int in range(_lines.size()):
		if not _roll.line_visible(i):
			continue
		var text: String = _clean_control_codes(_lines[i])
		if text.is_empty():
			continue  # blank TLine still consumes its measured height
		var baseline: float = float(_roll.line_y(i)) + _font.get_ascent(_font_size)
		draw_string(_font, Vector2(0.0, baseline), text,
			HORIZONTAL_ALIGNMENT_CENTER, width, _font_size, _text_color)


# ---------------------------------------------------------------- test hooks
func line_count() -> int:
	return _lines.size()


func line_height_px() -> int:
	return _measure_line_height()


func view_height_px() -> int:
	return _roll.view_height if _roll != null else 0


func offset_px() -> int:
	return _roll.offset if _roll != null else 0


func tick_count() -> int:
	return _roll.tick_count if _roll != null else 0


func ended() -> bool:
	return _roll != null and _roll.ended


func raw_line(index: int) -> String:
	if index < 0 or index >= _lines.size():
		return ""
	return _lines[index]


func clean_line(index: int) -> String:
	return _clean_control_codes(raw_line(index))


func configure_error() -> String:
	return _configure_error

extends RefCounted
class_name PortCreditsRoll
## Recovered CCreditsView credit-roll model.
##
## Native facts (see evidence/credits_scroll.json):
##   * CGuiSystem::Update (ELF 0x004693e4) advances the GUI in fixed 33 ms
##     (0x21) steps, gated at last+32 ms, with a 198 ms (0xc6) backlog clamp and
##     catch-up while last+32 ms < now; each step calls CLayout::OnTick, which
##     calls the control virtual at vptr+0x14 -> CCreditsView::OnTick
##     (vtable word 0x005f67f4).  Render FPS never changes this 33 ms cadence.
##   * CCreditsView::OnTick adds +1 to the scroll offset (+0xb4), flips a
##     zero-initialised .bss byte (0x80f69c), and adds +1 more when the new value
##     is 1: +2, +1, +2, +1, ...
##   * CCreditsView::Init sets offset = -(int)GetPropertyTReal(5); property 5 is
##     `height` (CControl property order name,type,x,y,width,height,...), so the
##     creditsdle/creditsindiagames credits widget height 320 gives offset -320.
##   * Lines are TLine records; y at +0x40 (cumulative), height at +0x44.  Redraw
##     skips a line once offset >= y+height and raises the action "END" when every
##     line has been skipped (all scrolled above the viewport).
##
## This class models only those proven values; line heights are supplied by the
## caller from the port's own text metrics.  No scroll speed or end text is
## invented.

const TICK_MS: int = 33
const GATE_MS: int = 32
const MAX_BACKLOG_MS: int = 198
const END_ACTION: String = "END"

var view_height: int = 320
var line_heights: PackedInt32Array = PackedInt32Array()
var offset: int = 0
var flip: bool = false
var ended: bool = false
var tick_count: int = 0

var _last_ms: int = -1


func _init(heights: PackedInt32Array = PackedInt32Array(), view_h: int = 320) -> void:
	configure(heights, view_h)


## Reset to CCreditsView::Init state: offset = -height.
func configure(heights: PackedInt32Array, view_h: int = 320) -> void:
	line_heights = heights.duplicate()
	view_height = view_h
	offset = -view_h
	flip = false
	tick_count = 0
	ended = line_heights.is_empty()
	_last_ms = -1


func content_height() -> int:
	var total: int = 0
	for h: int in line_heights:
		total += h
	return total


## Cumulative top (TLine +0x40) of line `index`.
func line_top(index: int) -> int:
	var y: int = 0
	var stop: int = mini(index, line_heights.size())
	for i: int in range(maxi(stop, 0)):
		y += line_heights[i]
	return y


## Screen y of line `index`: TLine.y - offset (CCreditsView::Redraw).
func line_y(index: int) -> int:
	return line_top(index) - offset


## Redraw culling: offset < y + h AND offset + view_height > y.
func line_visible(index: int) -> bool:
	if index < 0 or index >= line_heights.size():
		return false
	var y: int = line_top(index)
	return offset < y + line_heights[index] and offset + view_height > y


## One CCreditsView::OnTick update (called once per recovered 33 ms tick).
func tick() -> void:
	offset += 1
	flip = not flip
	if flip:
		offset += 1
	tick_count += 1
	if offset >= content_height():
		ended = true


## Reproduce CGuiSystem::Update's fixed-step dispatch for one Update() call at
## `now_ms`.  Returns the number of 33 ms ticks executed (0..6).
func advance_ms(now_ms: int) -> int:
	if _last_ms < 0:
		_last_ms = now_ms
		return 0
	var now: int = now_ms
	var last: int = _last_ms
	if now - last > MAX_BACKLOG_MS:
		last = now - MAX_BACKLOG_MS
	if now <= last + GATE_MS:
		_last_ms = last
		return 0
	var fired: int = 0
	while true:
		tick()
		fired += 1
		last += TICK_MS
		if not (last + GATE_MS < now):
			break
	_last_ms = last
	return fired


## True once every line has scrolled above the viewport (Redraw raises "END").
func end_reached() -> bool:
	return ended


func end_action() -> String:
	return END_ACTION if ended else ""

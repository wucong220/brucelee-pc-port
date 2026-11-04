extends SceneTree
## Windowed capture of the recovered character-unlock gate on the OPPONENTS
## submenu (`BRUCELEE_HUD_ART=1`, so the decoded selectfighter.ui dock is shown)
## or on its text rows (`BRUCELEE_HUD_ART` unset).
##
## The DSH sandbox denies file writes to the Godot process, so every screenshot
## and report leaves the process through a framed localhost TCP stream; the
## runner (`tools/run_character_lock_capture.py`) owns the receiver and writes
## the PNGs.  Frame: u32 little-endian length, a UTF-8 JSON header line, then
## the body.
##
## Modes (`CHARACTER_LOCK_CAPTURE`):
##   dock_off      gate off, dock: every card draws its character icon
##   dock_none     gate on, no save: locked cards draw the decoded lockedpicture
##   dock_partial  gate on, save with sin fu + lo ming a: mixed cards
##   dock_full     gate on, every grant: all cards open
##   dock_missing  gate on, a dock the gate cannot map: text rows fallback
##   text_none     gate on, text rows, no save: (LOCKED) rows + blocked confirm
##   text_full     gate on, text rows, every grant: no suffix
##
## Usage (through the runner):
##   python -X utf8 tools\run_character_lock_capture.py --out screenshots

const PORT_ENV := "CHARACTER_LOCK_CAPTURE_PORT"
const MODE_ENV := "CHARACTER_LOCK_CAPTURE"

var _peer: StreamPeerTCP = null
var _net_ready: bool = false
var _mode: String = ""
var _report: Dictionary = {}
var _shots: Array = []
var _scene: Node = null
var _menu: Node = null
var _overlay: Node = null
var _commands: Array = []


func _on_command(command: String) -> void:
	_commands.append(command)


func _initialize() -> void:
	call_deferred("_run")


func _open_socket() -> void:
	var port_text: String = OS.get_environment(PORT_ENV)
	if port_text.is_empty():
		printerr("capture: " + PORT_ENV + " is not set")
		return
	_peer = StreamPeerTCP.new()
	if _peer.connect_to_host("127.0.0.1", int(port_text)) != OK:
		printerr("capture: cannot connect to the report port " + port_text)
		return
	for _attempt: int in range(300):
		_peer.poll()
		if _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			_net_ready = true
			print("capture: report socket connected on " + port_text)
			return
		OS.delay_msec(20)
	printerr("capture: report socket did not connect on " + port_text)


func _send_frame(header: Dictionary, body: PackedByteArray) -> void:
	if not _net_ready:
		printerr("capture: dropped frame " + String(header.get("name", "?")))
		return
	var head: PackedByteArray = (JSON.stringify(header) + "\n").to_utf8_buffer()
	var payload: PackedByteArray = head + body
	var packet: PackedByteArray = PackedByteArray()
	packet.resize(4)
	# PackedByteArray.encode_u32() is little-endian; the runner reads the same.
	packet.encode_u32(0, payload.size())
	packet.append_array(payload)
	var offset: int = 0
	while offset < packet.size():
		_peer.poll()
		var chunk: PackedByteArray = packet.slice(offset, mini(offset + 65536, packet.size()))
		if _peer.put_data(chunk) != OK:
			printerr("capture: report socket write failed")
			return
		offset += chunk.size()
	for _attempt: int in range(8):
		_peer.poll()
		OS.delay_msec(5)


func _send_json(name: String, data: Dictionary) -> void:
	_send_frame({"type": "report", "name": name, "extension": "json"},
		JSON.stringify(data, "  ").to_utf8_buffer())


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("capture: " + name + " produced no pixels")
		return
	var png: PackedByteArray = image.save_png_to_buffer()
	if png.is_empty():
		printerr("capture: " + name + " did not encode")
		return
	_send_frame({"type": "screenshot", "name": name + ".png", "extension": "png",
		"width": image.get_width(), "height": image.get_height()}, png)
	_shots.append({"name": name, "bytes": png.size(),
		"width": image.get_width(), "height": image.get_height()})
	print("capture: %s %dx%d %d bytes" % [name, image.get_width(),
		image.get_height(), png.size()])


func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _boot() -> bool:
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	await _frames(6)
	_menu = _scene.get("prototype_menu")
	if _menu == null:
		printerr("capture: main.tscn has no menu")
		return false
	_overlay = _scene.get("hud_art_menu_overlay")
	# The capture owns the command sink so confirming an open opponent does not
	# reload the scene (main.gd's opponent switch reloads main.tscn).
	if _menu.command_requested.is_connected(Callable(_scene, "_on_menu_command")):
		_menu.command_requested.disconnect(Callable(_scene, "_on_menu_command"))
	_menu.command_requested.connect(_on_command)
	return true


func _open_opponents() -> void:
	_scene.call("_open_main_menu")
	await _frames(2)
	var index: int = 0
	var commands: Array = _menu.main_commands()
	for i: int in range(commands.size()):
		if String(commands[i]) == "opponents":
			index = i
	for _step: int in range(index):
		_menu.handle_input_event(_key(KEY_DOWN))
		await _frames(1)
	_menu.handle_input_event(_key(KEY_ENTER))
	await _frames(4)


func _overlay_labels() -> Array:
	var out: Array = []
	if _overlay == null:
		return out
	var frame: Node = _overlay.get("_frame")
	if frame == null:
		return out
	for child: Node in frame.get_children():
		if child is Label:
			out.append(String((child as Label).text))
	return out


func _record_dock() -> void:
	_report["mode"] = _mode
	_report["hud_art"] = String(OS.get_environment("BRUCELEE_HUD_ART"))
	_report["character_unlock"] = String(OS.get_environment("BRUCELEE_CHARACTER_UNLOCK"))
	_report["character_unlock_save"] = String(OS.get_environment("BRUCELEE_CHARACTER_UNLOCK_SAVE"))
	_report["character_unlock_dock"] = String(OS.get_environment("BRUCELEE_CHARACTER_UNLOCK_DOCK"))
	_report["gate"] = _menu.fighter_gate_summary()
	_report["menu_state"] = String(_menu.menu_state)
	_report["selected_command"] = String(_menu.selected_command())
	_report["panel_visible"] = bool(_menu.panel_box.visible)
	_report["overlay_present"] = _overlay != null
	if _overlay != null:
		_report["overlay_visible"] = bool(_overlay.get("visible"))
		_report["overlay_mode"] = String(_overlay.call("current_mode"))
		_report["overlay_sources"] = _overlay.call("select_fighter_sources")
		_report["overlay_locked"] = _overlay.call("select_fighter_locked_flags")
		_report["overlay_error"] = String(_overlay.call("select_fighter_error"))
	_report["overlay_labels"] = _overlay_labels()
	_report["status"] = String(_menu.status_label.text)
	_report["commands"] = _commands.duplicate()


func _record_text() -> void:
	_report["mode"] = _mode
	_report["hud_art"] = String(OS.get_environment("BRUCELEE_HUD_ART"))
	_report["character_unlock"] = String(OS.get_environment("BRUCELEE_CHARACTER_UNLOCK"))
	_report["character_unlock_save"] = String(OS.get_environment("BRUCELEE_CHARACTER_UNLOCK_SAVE"))
	_report["gate"] = _menu.fighter_gate_summary()
	_report["menu_state"] = String(_menu.menu_state)
	_report["selected_command"] = String(_menu.selected_command())
	_report["panel_visible"] = bool(_menu.panel_box.visible)
	_report["overlay_present"] = _overlay != null
	var texts: Array = []
	var locked: int = 0
	for item: Dictionary in (_menu.layout_report()["items"] as Array):
		var text: String = String(item.get("text", ""))
		texts.append(text)
		if text.ends_with(" (LOCKED)"):
			locked += 1
	_report["text_rows"] = texts
	_report["locked_labels"] = locked
	_report["panel"] = (_menu.layout_report()["panel"] as Array)
	_report["status"] = String(_menu.status_label.text)
	_report["commands"] = _commands.duplicate()


func _run() -> void:
	_open_socket()
	_mode = OS.get_environment(MODE_ENV)
	if _mode.is_empty():
		_mode = "dock_none"
	var booted: bool = await _boot()
	if not booted:
		_send_json("character_lock_capture_" + _mode, {"ok": false, "mode": _mode,
			"error": "main.tscn has no menu", "shots": _shots})
		quit(1)
		return
	match _mode:
		"dock_off":
			await _capture_dock_off()
		"dock_none":
			await _capture_dock_none()
		"dock_partial":
			await _capture_dock_partial()
		"dock_full":
			await _capture_dock_full()
		"dock_missing":
			await _capture_dock_missing()
		"text_none":
			await _capture_text_none()
		"text_full":
			await _capture_text_full()
		_:
			printerr("capture: unknown mode " + _mode)
			quit(2)
			return
	_send_json("character_lock_capture_" + _mode, {
		"ok": true,
		"mode": _mode,
		"shots": _shots,
		"report": _report,
	})
	quit(0)


## Gate off (ungated regression): the dock is the pre-gating one, every card open.
func _capture_dock_off() -> void:
	await _open_opponents()
	_record_dock()
	await _capture("01_dock_gate_off_brick")


## No save: only the two always-available characters are open.
func _capture_dock_none() -> void:
	await _open_opponents()
	_record_dock()
	await _capture("02_dock_nosave_brick_locked")
	_menu.handle_input_event(_key(KEY_ENTER))
	await _frames(2)
	_report["locked_confirm_commands"] = _commands.duplicate()
	for _step: int in range(4):
		_menu.handle_input_event(_key(KEY_DOWN))
	await _frames(2)
	_report["selection_shenlo_command"] = String(_menu.selected_command())
	_record_dock()
	await _capture("03_dock_nosave_shenlo_open")
	_menu.handle_input_event(_key(KEY_ENTER))
	await _frames(2)
	_report["open_confirm_commands"] = _commands.duplicate()


## Partial save (sin fu id 7, lo ming a id 13): mixed open/locked cards.
func _capture_dock_partial() -> void:
	await _open_opponents()
	_menu.handle_input_event(_key(KEY_DOWN))
	await _frames(2)
	_record_dock()
	await _capture("04_dock_partial_sinfu_open")
	_menu.handle_input_event(_key(KEY_ENTER))
	await _frames(2)
	_report["open_confirm_commands"] = _commands.duplicate()
	_menu.handle_input_event(_key(KEY_DOWN))
	await _frames(2)
	_record_dock()
	await _capture("05_dock_partial_master_locked")
	_menu.handle_input_event(_key(KEY_ENTER))
	await _frames(2)
	_report["locked_confirm_commands"] = _commands.duplicate()


## Full save: every card draws its character icon.
func _capture_dock_full() -> void:
	await _open_opponents()
	_record_dock()
	await _capture("06_dock_full_brick_open")
	_menu.handle_input_event(_key(KEY_ENTER))
	await _frames(2)
	_report["open_confirm_commands"] = _commands.duplicate()


## The decoded dock cannot be mapped to characters: main.gd falls back to the text
## opponent rows, which keep the same lock state.
func _capture_dock_missing() -> void:
	await _open_opponents()
	_record_dock()
	# Also record the text panel the fallback restored (rows + panel rect).
	_record_text()
	_report["overlay_visible"] = bool(_overlay.get("visible")) if _overlay != null else false
	await _capture("07_dock_fallback_missing_layout")


## Text OPPONENTS rows, no save: eight (LOCKED) rows and a blocked confirm.
func _capture_text_none() -> void:
	await _open_opponents()
	_record_text()
	await _capture("08_text_nosave_locked_rows")
	_menu.handle_input_event(_key(KEY_ENTER))
	await _frames(2)
	_record_text()
	_report["locked_confirm_commands"] = _commands.duplicate()
	await _capture("09_text_nosave_confirm_blocked")


## Text OPPONENTS rows, full save: no suffix, first row applies.
func _capture_text_full() -> void:
	await _open_opponents()
	_record_text()
	await _capture("10_text_full_rows")
	_menu.handle_input_event(_key(KEY_ENTER))
	await _frames(2)
	_report["open_confirm_commands"] = _commands.duplicate()

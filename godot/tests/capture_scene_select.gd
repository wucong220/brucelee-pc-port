extends SceneTree
## Windowed capture of the opt-in recovered scene dock (`BRUCELEE_SCENE_SELECT=1`).
##
## The DSH sandbox denies file writes to the Godot process, so every screenshot
## and report leaves the process through a framed localhost TCP stream; the
## runner (`tools/run_scene_select_capture.py`) owns the receiver and writes the
## PNGs.  Frame: u32 big-endian length, a UTF-8 JSON header line, then the body.
##
## Modes (`SCENE_SELECT_CAPTURE`):
##   dock      dock at index 0 / 3 / 9, then the match started in the selected
##             scenery (this run also prints the applied variant)
##   fallback  text scene rows while the decoded layout is missing (fail closed)
##   off       text scene rows with the flag unset (regression capture)
##   zh        the dock with BRUCELEE_LANG=zh (recovered Chinese labels)
##
## Usage (through the runner):
##   python -X utf8 tools\run_scene_select_capture.py --out screenshots

const PORT_ENV := "SCENE_SELECT_CAPTURE_PORT"
const MODE_ENV := "SCENE_SELECT_CAPTURE"

var _peer: StreamPeerTCP = null
var _net_ready: bool = false
var _mode: String = ""
var _report: Dictionary = {}
var _shots: Array = []
var _scene: Node = null
var _menu: Node = null


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
	# PackedByteArray.encode_u32() is little-endian; tools/run_scene_select_capture.py
	# reads the same order.
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
	# Flush the last chunk before the caller moves on.
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
	# This is a SceneTree script, so the captured viewport is the root Window.
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
	await _frames(4)
	_menu = _scene.get("prototype_menu")
	if _menu == null:
		printerr("capture: main.tscn has no menu")
		return false
	return true


func _open_scene_menu_from_main() -> void:
	_scene.call("_open_main_menu")
	await _frames(2)
	var index: int = 0
	var commands: Array = _menu.main_commands()
	for i: int in range(commands.size()):
		if String(commands[i]) == "scenes":
			index = i
	for _step: int in range(index):
		_menu.handle_input_event(_key(KEY_DOWN))
		await _frames(1)
	_menu.handle_input_event(_key(KEY_ENTER))
	await _frames(3)


func _run() -> void:
	_open_socket()
	_mode = OS.get_environment(MODE_ENV)
	if _mode.is_empty():
		_mode = "dock"
	var booted: bool = await _boot()
	if not booted:
		_send_json("scene_select_capture_" + _mode, {"ok": false, "mode": _mode,
			"error": "main.tscn has no menu", "shots": _shots})
		quit(1)
		return
	match _mode:
		"dock":
			await _capture_dock()
		"zh":
			await _capture_zh()
		"fallback", "off":
			await _capture_text_rows()
		_:
			printerr("capture: unknown mode " + _mode)
			quit(2)
			return
	_send_json("scene_select_capture_" + _mode, {
		"ok": true,
		"mode": _mode,
		"shots": _shots,
		"report": _report,
	})
	quit(0)


func _capture_dock() -> void:
	await _open_scene_menu_from_main()
	_report["dock_visible"] = bool(_menu.scene_dock_visible())
	_report["rows"] = Array(_menu.scene_dock_rows()).size()
	_report["label_index0"] = String(_menu.scene_dock_label())
	await _capture("01_scene_dock_index0")
	_menu.handle_input_event(_key(KEY_RIGHT))
	_menu.handle_input_event(_key(KEY_RIGHT))
	_menu.handle_input_event(_key(KEY_RIGHT))
	await _frames(2)
	_report["label_index3"] = String(_menu.scene_dock_label())
	await _capture("02_scene_dock_index3_temple_yard_b")
	for _step: int in range(8):
		_menu.handle_input_event(_key(KEY_RIGHT))
	await _frames(2)
	_report["label_index9"] = String(_menu.scene_dock_label())
	await _capture("03_scene_dock_index9_rooftops_b")
	# Apply index 3 and photograph the match that starts in that scenery.
	for _step: int in range(6):
		_menu.handle_input_event(_key(KEY_LEFT))
	await _frames(2)
	_report["apply_index"] = int(_menu.scene_dock_selection())
	var old_id: int = _scene.get_instance_id()
	_menu.handle_input_event(_key(KEY_ENTER))
	var reloaded: bool = false
	for _frame: int in range(300):
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_id:
			reloaded = true
			break
	_report["reloaded"] = reloaded
	_report["env_scene"] = OS.get_environment("BRUCELEE_SCENE")
	_report["paused_after_reload"] = paused
	if not reloaded:
		return
	_scene = current_scene
	# Let the round intro run into the fight state before the shot.
	for _frame: int in range(240):
		await process_frame
		if int(_scene.get("match_state")) == 4:
			break
	await _frames(20)
	_report["match_state"] = int(_scene.get("match_state"))
	_report["scene_variant"] = String(_scene.call("_scene_variant"))
	_report["round_time_left"] = int(_scene.get("round_time_left"))
	_report["elapsed"] = float(_scene.get("elapsed"))
	await _capture("04_match_started_temple_yard_b")


func _capture_zh() -> void:
	await _open_scene_menu_from_main()
	_report["language"] = String(OS.get_environment("BRUCELEE_LANG"))
	_report["label_index0"] = String(_menu.scene_dock_label())
	_menu.handle_input_event(_key(KEY_RIGHT))
	_menu.handle_input_event(_key(KEY_RIGHT))
	await _frames(2)
	_report["label_index2"] = String(_menu.scene_dock_label())
	await _capture("07_scene_dock_zh_index2")


func _capture_text_rows() -> void:
	await _open_scene_menu_from_main()
	_report["dock_present"] = _menu.scene_dock != null
	_report["dock_error"] = String(_menu.scene_dock_error)
	_report["text_rows_visible"] = bool(_menu.scene_text_rows_visible())
	_report["status"] = String(_menu.status_label.text)
	_menu.handle_input_event(_key(KEY_DOWN))
	await _frames(2)
	_report["selected"] = String(_menu.selected_command())
	if _mode == "fallback":
		await _capture("05_fail_closed_text_fallback")
	else:
		await _capture("06_text_scene_rows_flag_off")

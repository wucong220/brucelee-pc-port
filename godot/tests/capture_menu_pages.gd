extends SceneTree
## Windowed capture of the recovered main-menu sub-pages
## (BRUCELEE_MENU_ART=1): Player Profile, Settings, Credits and About.
##
## The DSH sandbox denies file writes to the Godot process, so each screenshot
## leaves the process over a framed localhost TCP stream (4-byte little-endian
## length + JSON header line + PNG body). tools/run_menu_pages_capture.py runs
## the receiver and writes the files.
##
##   python -X utf8 tools\run_menu_pages_capture.py --out <dir> \
##          --player <player.glb> --opponent <opponent.glb>
##
## Every capture records the screen id / selection it came from in the report;
## the runner re-checks the PNG files on disk.

const EXPECTED := [
	"01_mainmenu.png",
	"02_player_profile.png",
	"03_player_profile_not_recovered.png",
	"04_settings.png",
	"05_credits.png",
	"06_credits_dle_not_recovered.png",
	"07_credits_ig_not_recovered.png",
	"08_about.png",
	"09_back_mainmenu.png",
]

const ENV_PORT := "MENU_ART_PORT"

var scene: Node = null
var menu: Node = null
var sent: Array = []
var steps: Array = []
var _peer: StreamPeerTCP
var _net_ready: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _open_socket() -> void:
	var port_text: String = OS.get_environment(ENV_PORT)
	if port_text.is_empty():
		printerr("menu_pages capture: no MENU_ART_PORT; screenshots cannot leave the process")
		return
	_peer = StreamPeerTCP.new()
	var error: int = _peer.connect_to_host("127.0.0.1", int(port_text))
	if error != OK:
		printerr("menu_pages capture: connect failed " + str(error))
		return
	for _attempt: int in range(150):
		_peer.poll()
		if _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			_net_ready = true
			print("menu_pages capture: socket connected")
			return
		OS.delay_msec(20)
	printerr("menu_pages capture: socket did not connect")


func _send_frame(header: Dictionary, body: PackedByteArray) -> void:
	if not _net_ready:
		return
	var head: PackedByteArray = (JSON.stringify(header) + "\n").to_utf8_buffer()
	var payload: PackedByteArray = head + body
	var packet: PackedByteArray = PackedByteArray()
	packet.resize(4)
	packet.encode_u32(0, payload.size())
	packet.append_array(payload)
	var offset: int = 0
	while offset < packet.size():
		_peer.poll()
		var chunk: PackedByteArray = packet.slice(offset, mini(offset + 65536, packet.size()))
		var error: int = _peer.put_data(chunk)
		if error != OK:
			printerr("menu_pages capture: write failed " + str(error))
			return
		offset += chunk.size()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Expected <player.glb> <opponent.glb>")
		quit(1)
		return
	_open_socket()
	OS.set_environment("BRUCELEE_MENU_ART", "1")
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
	OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
	for name: String in [
		"BRUCELEE_STORY_FLOW", "BRUCELEE_STORY_LAUNCH", "BRUCELEE_GAME_MODE",
		"BRUCELEE_MODE_LAUNCH", "BRUCELEE_ATTRACT", "BRUCELEE_CONTINUE",
		"BRUCELEE_PROGRESS", "BRUCELEE_STYLE_EDITOR", "BRUCELEE_SCENE",
	]:
		OS.set_environment(name, "")

	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.get("player").set_physics_process(false)
	scene.get("computer").set_physics_process(false)
	menu = scene.get("prototype_menu")

	await _frames(6)
	await _capture("01_mainmenu.png")

	await _open_row(1)
	await _capture("02_player_profile.png")
	menu.call("handle_key_event", _key(KEY_ENTER))
	await _frames(3)
	await _capture("03_player_profile_not_recovered.png")

	await _open_row(2)
	await _capture("04_settings.png")

	await _open_row(3)
	await _capture("05_credits.png")
	menu.call("handle_key_event", _key(KEY_ENTER))
	await _frames(3)
	await _capture("06_credits_dle_not_recovered.png")
	menu.call("handle_key_event", _key(KEY_ESCAPE))
	await _frames(2)
	menu.call("handle_key_event", _key(KEY_RIGHT))
	await _frames(2)
	menu.call("handle_key_event", _key(KEY_ENTER))
	await _frames(3)
	await _capture("07_credits_ig_not_recovered.png")
	menu.call("handle_key_event", _key(KEY_ESCAPE))
	await _frames(2)

	await _open_row(4)
	await _capture("08_about.png")
	menu.call("handle_key_event", _key(KEY_ESCAPE))
	await _frames(3)
	await _capture("09_back_mainmenu.png")

	_report()


func _open_row(index: int) -> void:
	scene.call("_open_main_menu")
	await _frames(2)
	for _step: int in range(index):
		menu.call("handle_key_event", _key(KEY_DOWN))
		await _frames(1)
	menu.call("handle_key_event", _key(KEY_ENTER))
	await _frames(4)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("SHOT FAILED " + name)
		return
	var png: PackedByteArray = image.save_png_to_buffer()
	if png.is_empty():
		printerr("SHOT ENCODE FAILED " + name)
		return
	_send_frame({"type": "screenshot", "name": name, "extension": "png",
		"width": image.get_width(), "height": image.get_height()}, png)
	sent.append(name)
	steps.append({"screenshot": name, "screen": String(menu.get("screen_id")),
		"selection": int(menu.get("selection"))})
	print("SHOT " + name + " %dx%d %d bytes" % [image.get_width(), image.get_height(), png.size()])


func _report() -> void:
	_send_frame({"type": "report", "name": "menu_pages_capture_report", "extension": "json"},
		JSON.stringify({"sent": sent, "expected": EXPECTED, "steps": steps}).to_utf8_buffer())
	print("MENU_PAGES_CAPTURE=" + JSON.stringify({"sent": sent}))
	if _peer != null:
		_peer.poll()
	quit(0)

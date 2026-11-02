extends CanvasLayer
class_name PortMoveGallery

## Move gallery: plays every recovered Bruce move automatically, with its
## prerequisite state, and needs no input. It deliberately calls the low-level
## attack entry points instead of replaying key sequences, so a missing move
## shows up as a missing animation rather than as an input failure.

signal exit_requested

const CatalogPath = "res://data/move_training_catalog.json"
const PrototypeControls = preload("res://scripts/prototype_controls.gd")
const DISPLAY_HOLD_SECONDS: float = 0.9

var main: Node
var player: PortFighter
var computer: PortFighter
var entries: Array = []
var index: int = 0
var state: String = "hidden"
var timer: float = 0.0
var play_error: String = ""

var root: Control
var panel: PanelContainer
var title_label: Label
var counter_label: Label
var move_label: Label
var setup_label: Label
var input_label: Label
var status_label: Label
var hint_label: Label


func configure(main_node: Node, player_node: PortFighter, computer_node: PortFighter) -> void:
    main = main_node
    player = player_node
    computer = computer_node
    _load_catalog()
    _build_ui()


func _load_catalog() -> void:
    var file: FileAccess = FileAccess.open(CatalogPath, FileAccess.READ)
    if file == null:
        push_error("Move gallery catalog is missing")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary or not parsed.get("entries", null) is Array:
        push_error("Move gallery catalog is invalid")
        return
    entries = parsed["entries"]


func _build_ui() -> void:
    layer = 23
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    var top: VBoxContainer = VBoxContainer.new()
    top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top.offset_left = 24.0
    top.offset_right = -24.0
    top.offset_top = 16.0
    top.add_theme_constant_override("separation", 2)
    root.add_child(top)

    panel = PanelContainer.new()
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.02, 0.03, 0.05, 0.72)
    style.set_corner_radius_all(8)
    style.content_margin_left = 18.0
    style.content_margin_right = 18.0
    style.content_margin_top = 10.0
    style.content_margin_bottom = 10.0
    panel.add_theme_stylebox_override("panel", style)
    panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    top.add_child(panel)

    var box: VBoxContainer = VBoxContainer.new()
    box.add_theme_constant_override("separation", 2)
    panel.add_child(box)

    var header: HBoxContainer = HBoxContainer.new()
    header.add_theme_constant_override("separation", 24)
    box.add_child(header)
    title_label = _label("MOVE GALLERY", 18, Color(1.0, 0.78, 0.30))
    counter_label = _label("", 16, Color(0.72, 0.80, 0.92))
    counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    header.add_child(title_label)
    header.add_child(counter_label)

    move_label = _label("", 30, Color(1.0, 0.86, 0.55))
    box.add_child(move_label)
    setup_label = _label("", 15, Color(0.72, 0.84, 0.72))
    box.add_child(setup_label)
    input_label = _label("", 15, Color(0.80, 0.82, 0.90))
    box.add_child(input_label)
    status_label = _label("", 16, Color(0.62, 0.90, 1.0))
    box.add_child(status_label)

    hint_label = _label("AUTO PLAY · ← → 切换招式 · ESC 退出", 14, Color(0.68, 0.72, 0.80))
    hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    hint_label.offset_top = -34.0
    hint_label.offset_bottom = -8.0
    root.add_child(hint_label)


func _label(text: String, size: int, color: Color) -> Label:
    var label: Label = Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label


func open() -> void:
    if entries.is_empty():
        return
    state = "active"
    index = 0
    visible = true
    _play_current()


func close() -> void:
    state = "hidden"
    visible = false
    if player != null:
        player.set_physics_process(true)
        player.reset_fighter(Vector3(-0.75, 1.20, 0.0))
    if computer != null:
        computer.set_physics_process(true)


func is_active() -> bool:
    return state == "active"


func handle_input_event(event: InputEvent) -> bool:
    if not visible or not PrototypeControls.is_press_edge(event):
        return false
    if event.is_action_pressed(PrototypeControls.MENU_CANCEL) or event.is_action_pressed(PrototypeControls.PAUSE):
        close()
        exit_requested.emit()
        return true
    if event.is_action_pressed(PrototypeControls.MOVE_LEFT) or event.is_action_pressed(PrototypeControls.MENU_UP):
        _step(-1)
        return true
    if event.is_action_pressed(PrototypeControls.MOVE_RIGHT) or event.is_action_pressed(PrototypeControls.MENU_DOWN):
        _step(1)
        return true
    # Swallow attack keys while the gallery is open so the demo keeps playing
    # instead of the fighter punching behind the panel.
    return PrototypeControls.is_press_edge(event)


func _step(direction: int) -> void:
    if entries.is_empty():
        return
    index = wrapi(index + direction, 0, entries.size())
    _play_current()


func _play_current() -> void:
    if entries.is_empty():
        return
    play_error = ""
    timer = 0.0
    var entry: Dictionary = entries[index]
    player.set_physics_process(true)
    player.reset_fighter(Vector3(-0.25, 1.20, 0.0))
    player.health = 9999.0
    player.rage = 100.0
    computer.set_physics_process(false)
    computer.reset_fighter(Vector3(0.25, 1.20, 0.0))
    computer.health = 9999.0
    computer.state = "idle"
    computer.attack_kind = ""
    computer._animate_candidate()

    var setup: String = String(entry.get("setup", "idle"))
    if setup == "target_down":
        computer.state = "facedownidle"
        computer._animate_candidate()
    elif setup == "endattack1" or setup == "endattack2":
        computer.state = "hitstun"
        computer.state_time = 1.0
        computer._animate_candidate()
    elif setup == "player_down":
        player.state = "facedownidle"
        player.state_time = 0.0
        player._animate_candidate()
    elif setup == "player_faceup":
        player.state = "faceupidle"
        player.state_time = 0.0
        player._animate_candidate()

    var actions: Array = entry.get("actions", [])
    var action: String = String(actions[0]) if not actions.is_empty() else ""
    var started: bool = _start_action(action)
    if not started:
        for alternate: Variant in actions:
            if String(alternate) != action and _start_action(String(alternate)):
                action = String(alternate)
                started = true
                break
    if not started:
        play_error = "NO ANIMATION FOR: " + action
    timer = _duration(action) + DISPLAY_HOLD_SECONDS
    _refresh_labels(entry, action, started)


func _start_action(action: String) -> bool:
    if action.is_empty():
        return false
    if action == "attacktofloor":
        player._begin_attack_to_floor()
        return player.state == "attacktofloor"
    if action == "facedownattack" or action == "faceupattack":
        if action == "facedownattack":
            player.state = "facedownidle"
        else:
            player.state = "faceupidle"
        player.state_time = 0.0
        player.attack_kind = ""
        player._animate_candidate()
        for _press: int in range(3):
            player.record_virtual_press("a")
        return player.state == action
    if not player.ATTACKS.has(action):
        return false
    return player.request_attack(action)


func _duration(action: String) -> float:
    if player.ATTACKS.has(action):
        var details: Dictionary = player.ATTACKS[action]
        return (float(details.get("startup", 0.0))
                + float(details.get("active", 0.0))
                + float(details.get("recovery", 0.0)))
    if action == "attacktofloor" or action == "facedownattack" or action == "faceupattack":
        return 2.6
    return 1.6


func _refresh_labels(entry: Dictionary, action: String, started: bool) -> void:
    move_label.text = String(entry.get("label", ""))
    counter_label.text = "%02d / %02d" % [index + 1, entries.size()]
    var setup: String = String(entry.get("setup", "idle"))
    setup_label.text = "PREREQUISITE: " + _setup_text(setup)
    input_label.text = "INPUT (reference): " + String(entry.get("input", ""))
    if started:
        status_label.text = "PLAYING: " + action
        status_label.add_theme_color_override("font_color", Color(0.62, 0.90, 1.0))
    else:
        status_label.text = play_error
        status_label.add_theme_color_override("font_color", Color(1.0, 0.50, 0.45))


func _setup_text(setup: String) -> String:
    if setup == "idle":
        return "none (standing)"
    if setup.begins_with("source_"):
        return "after " + setup.trim_prefix("source_").replace("_", " ").to_upper()
    if setup == "target_down":
        return "target lying face-down"
    if setup == "player_down":
        return "player face-down"
    if setup == "player_faceup":
        return "player face-up"
    if setup == "parry_high":
        return "dummy high attack"
    if setup == "parry_low":
        return "dummy low attack"
    if setup == "parry_attack":
        return "parry then counter"
    if setup.begins_with("endattack"):
        return "target in hitstun"
    return setup.to_upper()


func _process(delta: float) -> void:
    if state != "active":
        return
    # Keep the dummy still so every clip plays against a stable target.
    if computer != null and computer.state != "hitstun" and computer.state != "facedownidle":
        computer.state = "idle"
    timer -= delta
    if timer > 0.0:
        return
    index = wrapi(index + 1, 0, entries.size())
    _play_current()

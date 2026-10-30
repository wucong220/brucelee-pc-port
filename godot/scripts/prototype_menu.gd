extends CanvasLayer
class_name PortPrototypeMenu

## PC-only prototype menu. This does not claim parity with the Android game's UI.

signal command_requested(command: String)

const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")
const PrototypeControls = preload("res://scripts/prototype_controls.gd")
const MAIN_COMMANDS: Array[String] = ["fight", "training", "quit"]
const MAIN_LABELS: Array[String] = ["VS FIGHT", "GROUND TRAINING", "QUIT GAME"]
const PAUSE_COMMANDS: Array[String] = ["resume", "restart", "main_menu", "quit"]
const PAUSE_LABELS: Array[String] = [
    "RESUME",
    "RESTART MATCH",
    "MAIN MENU",
    "QUIT GAME",
]

var menu_state: String = "hidden"
var selected_index: int = 0
var background_loaded: bool = false
var background_error: String = ""
var background_path: String = ""
var item_labels: Array[Label] = []
var background: TextureRect
var mode_label: Label
var status_label: Label
var controls_label: Label

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 30
    _build_ui()
    _load_background()
    hide_menu()

func _build_ui() -> void:
    var screen: Control = Control.new()
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(screen)
    var fallback: ColorRect = ColorRect.new()
    fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    fallback.color = Color(0.035, 0.045, 0.065, 1.0)
    fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
    screen.add_child(fallback)
    background = TextureRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    screen.add_child(background)
    var shade: ColorRect = ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.015, 0.02, 0.035, 0.58)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    screen.add_child(shade)

    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    screen.add_child(center)
    var panel: VBoxContainer = VBoxContainer.new()
    panel.custom_minimum_size = Vector2(380.0, 0.0)
    panel.add_theme_constant_override("separation", 10)
    center.add_child(panel)
    var title: Label = Label.new()
    title.text = "DRAGON WARRIOR"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 38)
    title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
    panel.add_child(title)
    var subtitle: Label = Label.new()
    subtitle.text = "PC COMBAT PROTOTYPE"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 18)
    subtitle.add_theme_color_override("font_color", Color(0.86, 0.88, 0.92))
    panel.add_child(subtitle)
    var spacer: Control = Control.new()
    spacer.custom_minimum_size = Vector2(0.0, 18.0)
    panel.add_child(spacer)
    mode_label = Label.new()
    mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mode_label.add_theme_font_size_override("font_size", 20)
    mode_label.add_theme_color_override("font_color", Color(0.70, 0.78, 0.90))
    panel.add_child(mode_label)
    for index: int in range(PAUSE_LABELS.size()):
        var label: Label = Label.new()
        label.custom_minimum_size = Vector2(0.0, 42.0)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 25)
        panel.add_child(label)
        item_labels.append(label)
    status_label = Label.new()
    status_label.custom_minimum_size = Vector2(0.0, 30.0)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_font_size_override("font_size", 17)
    status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.40))
    panel.add_child(status_label)
    controls_label = Label.new()
    controls_label.text = "UP/DOWN or D-PAD select   ENTER/J/A confirm   ESC/B/START resume"
    controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    controls_label.add_theme_font_size_override("font_size", 16)
    controls_label.add_theme_color_override("font_color", Color(0.78, 0.81, 0.86))
    panel.add_child(controls_label)
    var disclaimer: Label = Label.new()
    disclaimer.text = "Prototype menu · original UI, timing and input rules are not recovered"
    disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    disclaimer.add_theme_font_size_override("font_size", 14)
    disclaimer.add_theme_color_override("font_color", Color(0.64, 0.67, 0.74))
    panel.add_child(disclaimer)

func _load_background() -> void:
    background_path = OS.get_environment("BRUCELEE_MAINMENU_PATH")
    if background_path.is_empty():
        var local_app_data: String = OS.get_environment("LOCALAPPDATA")
        if local_app_data.is_empty():
            background_error = "LOCALAPPDATA is unavailable"
            return
        background_path = local_app_data.path_join(
            "BruceLee-PC-Port/p5-menu-assets-20261030/mainmenu_default.png"
        )
    background_error = CandidatePathGuard.external_path_error(
        background_path, "prototype menu background"
    )
    if not background_error.is_empty():
        return
    var image: Image = Image.new()
    if image.load(background_path) != OK:
        background_error = "prototype menu background failed to load: " + background_path
        return
    background.texture = ImageTexture.create_from_image(image)
    background_loaded = true

func show_main_menu() -> void:
    menu_state = "main"
    selected_index = 0
    visible = true
    mode_label.text = "MAIN MENU"
    status_label.text = ""
    controls_label.text = "UP/DOWN or D-PAD choose   ENTER/J/A confirm"
    _refresh_items(MAIN_LABELS)

func show_pause_menu() -> void:
    menu_state = "pause"
    selected_index = 0
    visible = true
    mode_label.text = "PAUSED"
    status_label.text = ""
    controls_label.text = "UP/DOWN or D-PAD choose   ENTER/J/A confirm   ESC/B/START resume"
    _refresh_items(PAUSE_LABELS)

func hide_menu() -> void:
    menu_state = "hidden"
    visible = false

func show_error(value: String) -> void:
    status_label.text = value

func selected_command() -> String:
    var commands: Array[String] = (
        MAIN_COMMANDS if menu_state == "main" else PAUSE_COMMANDS
    )
    if selected_index < 0 or selected_index >= commands.size():
        return ""
    return commands[selected_index]

func handle_key_event(event: InputEventKey) -> bool:
    return handle_input_event(event)

func handle_input_event(event: InputEvent) -> bool:
    if not visible:
        return false
    if not PrototypeControls.is_press_edge(event):
        return false
    var commands: Array[String] = _commands()
    if event.is_action_pressed(PrototypeControls.MENU_UP):
        selected_index = wrapi(selected_index - 1, 0, commands.size())
        _refresh_selection()
    elif event.is_action_pressed(PrototypeControls.MENU_DOWN):
        selected_index = wrapi(selected_index + 1, 0, commands.size())
        _refresh_selection()
    elif event.is_action_pressed(PrototypeControls.MENU_ACCEPT):
        var command: String = selected_command()
        if not command.is_empty():
            command_requested.emit(command)
    elif event.is_action_pressed(PrototypeControls.MENU_CANCEL):
        if menu_state == "pause":
            command_requested.emit("resume")
    else:
        return false
    return true

func _commands() -> Array[String]:
    if menu_state == "main":
        return MAIN_COMMANDS
    return PAUSE_COMMANDS

func _input(event: InputEvent) -> void:
    if handle_input_event(event):
        get_viewport().set_input_as_handled()

func _refresh_items(labels: Array[String]) -> void:
    for index: int in range(item_labels.size()):
        item_labels[index].visible = index < labels.size()
        if index < labels.size():
            item_labels[index].set_meta("base_text", labels[index])
    _refresh_selection()

func _refresh_selection() -> void:
    for index: int in range(item_labels.size()):
        var label: Label = item_labels[index]
        if not label.visible:
            continue
        var base_text: String = String(label.get_meta("base_text", label.text))
        var selected: bool = index == selected_index
        label.text = ("> " + base_text + " <" if selected else base_text)
        label.add_theme_color_override(
            "font_color",
            Color(1.0, 0.82, 0.36) if selected else Color(0.84, 0.86, 0.90)
        )

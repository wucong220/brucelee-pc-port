extends CanvasLayer
class_name PortPrototypeMenu

## PC-only prototype menu. This does not claim parity with the Android game's UI.

signal command_requested(command: String)

const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")
const PrototypeControls = preload("res://scripts/prototype_controls.gd")
## Scene entries are handled by main.gd, which reloads main.tscn with a different
## BRUCELEE_SCENE variant. "scenes_back" and "scenes" never leave this script.
const SCENE_COMMANDS: Array[String] = [
    "temple_a", "temple_b", "halla", "squarea", "squareb",
    "harboura", "harbourb", "rooftopsa", "rooftopsb", "tournamenthallb",
    "scenes_back",
]
const SCENE_LABELS: Array[String] = [
    "TEMPLE YARD A", "TEMPLE YARD B", "TOURNAMENT HALL A",
    "SQUARE A", "SQUARE B", "HARBOUR A", "HARBOUR B",
    "ROOFTOPS A", "ROOFTOPS B", "TOURNAMENT HALL B", "BACK",
]
## Opponent entries are handled by main.gd, which writes the
## BRUCELEE_OPPONENT_* environment (candidate GLB, texture root, clip prefix or
## MASTER, material profile) and reloads main.tscn. "brick" restores the shipped
## Brick candidate; "opponents_back" and "opponents" never leave this script.
const OPPONENT_COMMANDS: Array[String] = [
    "brick", "sinfu", "master", "ken", "shenlo", "smallboy", "johnson", "chief", "loming", "opponents_back",
]
const OPPONENT_LABELS: Array[String] = [
    "BRICK", "SIN FU", "MASTER", "KEN", "SHEN LO",
    "SMALL BOY", "JOHNSON", "THE CHIEF", "LO MING", "BACK",
]
const MAIN_COMMANDS: Array[String] = [
    "fight", "arcade", "survival", "timeattack",
    "training", "move_training", "gallery",
    "temple_a", "temple_b", "scenes", "opponents", "quit",
]
const MAIN_LABELS: Array[String] = [
    "VS FIGHT", "ARCADE", "SURVIVAL", "TIME ATTACK",
    "GROUND TRAINING", "MOVE TRAINING", "MOVE GALLERY",
    "TEMPLE YARD A", "TEMPLE YARD B", "SCENES", "OPPONENTS", "QUIT GAME",
]
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
var screen_root: Control
var panel_box: VBoxContainer
var background: TextureRect
var background_main_texture: Texture2D
var background_practice_texture: Texture2D
var mode_label: Label
var status_label: Label
var controls_label: Label
var nav_sfx: AudioStreamPlayer
var accept_sfx: AudioStreamPlayer
var back_sfx: AudioStreamPlayer
var accept_sfx_error: String = ""
var menu_sfx_errors: Dictionary = {}
var last_sfx_played: String = ""
var last_accept_was_attack: bool = false
## Last item index that mouse motion selected; -1 until the pointer moves.
## Hover is driven by real motion events only, so a cursor resting over an item
## when the menu opens cannot hijack the default keyboard focus.
var hover_index: int = -1
## Main-menu row that opened the current submenu, so BACK/ESC can restore it.
var main_index_before_submenu: int = 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 30
    _build_ui()
    _load_background()
    _load_menu_sfx()
    hide_menu()

func _load_menu_sfx() -> void:
    nav_sfx = _load_sfx("Menu_Punch_2.wav", "nav")
    accept_sfx = _load_sfx("Select_Play_Bl_Shout.wav", "accept")
    back_sfx = _load_sfx("Back_BL_Shout_Short.wav", "back")
    accept_sfx_error = String(menu_sfx_errors.get("accept", ""))

func _load_sfx(filename: String, label: String) -> AudioStreamPlayer:
    var sfx_path: String = OS.get_environment("BRUCELEE_MENU_SFX_PATH")
    if label != "accept" or sfx_path.is_empty():
        var root: String = OS.get_environment("BRUCELEE_MENU_SFX_ROOT")
        if root.is_empty():
            var local_app_data: String = OS.get_environment("LOCALAPPDATA")
            if local_app_data.is_empty():
                menu_sfx_errors[label] = "LOCALAPPDATA is unavailable"
                return null
            root = local_app_data.path_join(
                "BruceLee-PC-Port/p5-menu-assets-20261030/"
                + "adreno_200/sounds/menu_sfx"
            )
        sfx_path = root.path_join(filename)
    var error: String = CandidatePathGuard.external_path_error(
        sfx_path, "prototype menu sfx"
    )
    if not error.is_empty():
        menu_sfx_errors[label] = error
        return null
    var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(sfx_path)
    if stream == null:
        menu_sfx_errors[label] = "prototype menu sfx failed to load: " + sfx_path
        return null
    var player: AudioStreamPlayer = AudioStreamPlayer.new()
    player.stream = stream
    add_child(player)
    return player

func _build_ui() -> void:
    var screen: Control = Control.new()
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(screen)
    screen_root = screen
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
    panel.add_theme_constant_override("separation", 4)
    center.add_child(panel)
    panel_box = panel
    var title: Label = Label.new()
    title.text = "DRAGON WARRIOR"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 28)
    title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
    panel.add_child(title)
    var subtitle: Label = Label.new()
    subtitle.text = "PC COMBAT PROTOTYPE"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 14)
    subtitle.add_theme_color_override("font_color", Color(0.86, 0.88, 0.92))
    panel.add_child(subtitle)
    var spacer: Control = Control.new()
    spacer.custom_minimum_size = Vector2(0.0, 6.0)
    panel.add_child(spacer)
    mode_label = Label.new()
    mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mode_label.add_theme_font_size_override("font_size", 16)
    mode_label.add_theme_color_override("font_color", Color(0.70, 0.78, 0.90))
    panel.add_child(mode_label)
    for index: int in range(maxi(MAIN_LABELS.size(), PAUSE_LABELS.size())):
        var label: Label = Label.new()
        label.custom_minimum_size = Vector2(0.0, 26.0)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 18)
        label.mouse_filter = Control.MOUSE_FILTER_STOP
        label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        label.gui_input.connect(_on_item_gui_input.bind(index))
        panel.add_child(label)
        item_labels.append(label)
    status_label = Label.new()
    status_label.custom_minimum_size = Vector2(0.0, 20.0)
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
    controls_label.add_theme_font_size_override("font_size", 12)
    controls_label.add_theme_color_override("font_color", Color(0.78, 0.81, 0.86))
    panel.add_child(controls_label)
    var disclaimer: Label = Label.new()
    disclaimer.text = "Prototype menu · original UI, timing and input rules are not recovered"
    disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    disclaimer.add_theme_font_size_override("font_size", 10)
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
    background_main_texture = ImageTexture.create_from_image(image)
    background.texture = background_main_texture
    background_loaded = true
    var practice_path: String = background_path.get_base_dir().path_join(
        "practice_default.png"
    )
    if FileAccess.file_exists(practice_path):
        var practice_image: Image = Image.new()
        if practice_image.load(practice_path) == OK:
            background_practice_texture = ImageTexture.create_from_image(practice_image)
    _refresh_background_preview()

func _refresh_background_preview() -> void:
    if not background_loaded or background == null:
        return
    var show_practice: bool = (
        menu_state == "main"
        and selected_command() == "training"
        and background_practice_texture != null
    )
    background.texture = (
        background_practice_texture if show_practice else background_main_texture
    )

func show_main_menu() -> void:
    menu_state = "main"
    selected_index = 0
    visible = true
    mode_label.text = "MAIN MENU"
    status_label.text = ""
    controls_label.text = "UP/DOWN or D-PAD choose   ENTER/J/A confirm"
    hover_index = -1
    _refresh_items(MAIN_LABELS)
    _refresh_selection()

func show_scene_menu() -> void:
    ## Scene selection submenu. Reached through the SCENES entry only.
    if menu_state == "main":
        main_index_before_submenu = selected_index
    menu_state = "scenes"
    selected_index = 0
    visible = true
    mode_label.text = "SELECT SCENE"
    status_label.text = ""
    controls_label.text = (
        "UP/DOWN or D-PAD   ENTER/J/A load   ESC/B/START back"
    )
    hover_index = -1
    _refresh_items(SCENE_LABELS)
    _refresh_selection()

func show_opponent_menu() -> void:
    ## Opponent selection submenu. Reached through the OPPONENTS entry only.
    ## The command itself is applied by main.gd (environment + scene reload).
    if menu_state == "main":
        main_index_before_submenu = selected_index
    menu_state = "opponents"
    selected_index = 0
    visible = true
    mode_label.text = "SELECT OPPONENT"
    status_label.text = ""
    controls_label.text = (
        "UP/DOWN or D-PAD   ENTER/J/A apply   ESC/B/START back"
    )
    hover_index = -1
    _refresh_items(OPPONENT_LABELS)
    _refresh_selection()

func show_pause_menu() -> void:
    menu_state = "pause"
    selected_index = 0
    visible = true
    mode_label.text = "PAUSED"
    status_label.text = ""
    controls_label.text = "UP/DOWN or D-PAD choose   ENTER/J/A confirm   ESC/B/START resume"
    hover_index = -1
    _refresh_items(PAUSE_LABELS)
    _refresh_selection()

func hide_menu() -> void:
    menu_state = "hidden"
    visible = false
    hover_index = -1

func show_error(value: String) -> void:
    status_label.text = value

func selected_command() -> String:
    var commands: Array[String] = _commands()
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
    if event.is_action_pressed(PrototypeControls.MENU_UP):
        _move_selection(-1)
    elif event.is_action_pressed(PrototypeControls.MENU_DOWN):
        _move_selection(1)
    elif event.is_action_pressed(PrototypeControls.MENU_ACCEPT):
        _accept_selected(event.is_action_pressed(PrototypeControls.ATTACK_A))
    elif event.is_action_pressed(PrototypeControls.MENU_CANCEL):
        _cancel()
    else:
        return false
    return true

func _commands() -> Array[String]:
    match menu_state:
        "main":
            return MAIN_COMMANDS
        "scenes":
            return SCENE_COMMANDS
        "opponents":
            return OPPONENT_COMMANDS
        _:
            return PAUSE_COMMANDS

func _input(event: InputEvent) -> void:
    if handle_input_event(event):
        get_viewport().set_input_as_handled()

func _move_selection(step: int) -> void:
    var commands: Array[String] = _commands()
    if commands.is_empty():
        return
    selected_index = wrapi(selected_index + step, 0, commands.size())
    _refresh_selection()
    _play_sfx(nav_sfx, "nav")

func _accept_selected(was_attack: bool) -> void:
    var command: String = selected_command()
    if command.is_empty():
        return
    _play_sfx(accept_sfx, "accept")
    last_accept_was_attack = was_attack
    if menu_state == "scenes":
        if command == "scenes_back":
            last_accept_was_attack = false
            _return_to_main_menu()
            return
        command_requested.emit(command)
        return
    if menu_state == "opponents":
        if command == "opponents_back":
            last_accept_was_attack = false
            _return_to_main_menu()
            return
        command_requested.emit(command)
        return
    if command == "scenes":
        last_accept_was_attack = false
        show_scene_menu()
        return
    if command == "opponents":
        last_accept_was_attack = false
        show_opponent_menu()
        return
    command_requested.emit(command)

func _cancel() -> void:
    if menu_state == "scenes" or menu_state == "opponents":
        _play_sfx(back_sfx, "back")
        _return_to_main_menu()
    elif menu_state == "pause":
        _play_sfx(back_sfx, "back")
        command_requested.emit("resume")

func _return_to_main_menu() -> void:
    menu_state = "main"
    selected_index = clampi(main_index_before_submenu, 0, MAIN_COMMANDS.size() - 1)
    mode_label.text = "MAIN MENU"
    status_label.text = ""
    controls_label.text = "UP/DOWN or D-PAD choose   ENTER/J/A confirm"
    hover_index = -1
    _refresh_items(MAIN_LABELS)
    _refresh_selection()

func _play_sfx(player: AudioStreamPlayer, label: String) -> void:
    if player == null:
        return
    last_sfx_played = label
    player.play()

func _on_item_gui_input(event: InputEvent, index: int) -> void:
    if not visible:
        return
    var commands: Array[String] = _commands()
    if index < 0 or index >= commands.size():
        return
    if event is InputEventMouseMotion:
        # Real pointer motion over the row selects it. A stationary cursor never
        # produces a motion event, so opening a menu cannot steal the default
        # keyboard selection.
        if index != selected_index:
            hover_index = index
            selected_index = index
            _refresh_selection()
            _play_sfx(nav_sfx, "nav")
        return
    var mouse_button: InputEventMouseButton = event as InputEventMouseButton
    if mouse_button == null or not mouse_button.pressed:
        return
    if mouse_button.button_index != MOUSE_BUTTON_LEFT:
        return
    selected_index = index
    _refresh_selection()
    _accept_selected(false)
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
    _refresh_background_preview()

## Measurement hook used by tests and by the scene-menu regression check.
## Returns the real Control geometry after layout, plus any visible item that
## falls outside the menu canvas.
func layout_report() -> Dictionary:
    var screen_rect: Rect2 = (
        screen_root.get_global_rect() if screen_root != null else Rect2()
    )
    var inner: Rect2 = screen_rect.grow(-2.0)
    var panel_rect: Rect2 = (
        panel_box.get_global_rect() if panel_box != null else Rect2()
    )
    var items: Array = []
    var clipped: Array = []
    for index: int in range(item_labels.size()):
        var label: Label = item_labels[index]
        if not label.visible:
            continue
        var rect: Rect2 = label.get_global_rect()
        var inside: bool = inner.encloses(rect)
        items.append({
            "index": index,
            "text": String(label.get_meta("base_text", label.text)),
            "rect": _rect_array(rect),
            "inside": inside,
        })
        if not inside:
            clipped.append(index)
    return {
        "state": menu_state,
        "selected_index": selected_index,
        "selected_command": selected_command(),
        "commands": _commands().duplicate(),
        "screen": _rect_array(screen_rect),
        "panel": _rect_array(panel_rect),
        "panel_min": (
            [panel_box.get_combined_minimum_size().x,
             panel_box.get_combined_minimum_size().y]
            if panel_box != null else []
        ),
        "items": items,
        "clipped_items": clipped,
        "panel_inside": inner.encloses(panel_rect),
        "hover_index": hover_index,
    }

func _rect_array(rect: Rect2) -> Array:
    return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

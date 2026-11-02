extends CanvasLayer
class_name PortMoveTraining

## Sequential Bruce move lessons. A lesson only advances after its real attack
## event (and, where applicable, an unblocked hit) is observed.

signal exit_requested

const CatalogPath = "res://data/move_training_catalog.json"
const PrototypeControls = preload("res://scripts/prototype_controls.gd")

var main: Node
var player: PortFighter
var computer: PortFighter
var entries: Array = []
var state: String = "hidden"
var selected_index: int = 0
var current_index: int = 0
var success_timer: float = -1.0
var dummy_restart_timer: float = -1.0
var last_status: String = ""

var root: Control
var title_label: Label
var list_label: Label
var list_hint: Label
var lesson_label: Label
var progress_label: Label
var group_label: Label
var input_label: Label
var status_label: Label


func configure(main_node: Node, player_node: PortFighter, computer_node: PortFighter) -> void:
    main = main_node
    player = player_node
    computer = computer_node
    _load_catalog()
    _build_ui()
    player.combat_hit.connect(_on_combat_hit)
    player.parry_succeeded.connect(_on_parry_succeeded)
    player.attack_started.connect(_on_attack_started)


func _load_catalog() -> void:
    var file: FileAccess = FileAccess.open(CatalogPath, FileAccess.READ)
    if file == null:
        push_error("Move training catalog is missing")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary or not parsed.get("entries", null) is Array:
        push_error("Move training catalog is invalid")
        return
    entries = parsed["entries"]


func _build_ui() -> void:
    layer = 24
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    var shade: ColorRect = ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.015, 0.02, 0.035, 0.55)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(shade)
    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(center)
    var panel: VBoxContainer = VBoxContainer.new()
    panel.custom_minimum_size = Vector2(720.0, 0.0)
    panel.add_theme_constant_override("separation", 10)
    center.add_child(panel)

    title_label = Label.new()
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 34)
    title_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
    panel.add_child(title_label)

    list_label = Label.new()
    list_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    list_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    list_label.custom_minimum_size = Vector2(720.0, 390.0)
    list_label.add_theme_font_size_override("font_size", 20)
    list_label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.92))
    panel.add_child(list_label)
    list_hint = Label.new()
    list_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    list_hint.add_theme_font_size_override("font_size", 17)
    list_hint.add_theme_color_override("font_color", Color(0.70, 0.78, 0.90))
    panel.add_child(list_hint)

    lesson_label = Label.new()
    lesson_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lesson_label.add_theme_font_size_override("font_size", 34)
    lesson_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
    panel.add_child(lesson_label)
    progress_label = Label.new()
    progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    progress_label.add_theme_font_size_override("font_size", 18)
    progress_label.add_theme_color_override("font_color", Color(0.70, 0.78, 0.90))
    panel.add_child(progress_label)
    group_label = Label.new()
    group_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    group_label.add_theme_font_size_override("font_size", 17)
    group_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.72))
    panel.add_child(group_label)
    input_label = Label.new()
    input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    input_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    input_label.add_theme_font_size_override("font_size", 22)
    input_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
    panel.add_child(input_label)
    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.custom_minimum_size = Vector2(720.0, 42.0)
    status_label.add_theme_font_size_override("font_size", 20)
    status_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
    panel.add_child(status_label)

    var controls: Label = Label.new()
    controls.text = "UP/DOWN choose   ENTER/J/A start   ESC/B return   R retry current move"
    controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    controls.add_theme_font_size_override("font_size", 15)
    controls.add_theme_color_override("font_color", Color(0.64, 0.67, 0.74))
    panel.add_child(controls)


func open() -> void:
    if entries.is_empty():
        return
    state = "select"
    selected_index = 0
    visible = true
    title_label.visible = true
    title_label.text = "MOVE TRAINING"
    _show_select()


func close() -> void:
    state = "hidden"
    visible = false
    if computer != null:
        computer.set_physics_process(true)


func is_active() -> bool:
    return state == "active" or state == "select" or state == "complete"


func is_lesson_active() -> bool:
    return state == "active"


func handle_input_event(event: InputEvent) -> bool:
    if not visible or not PrototypeControls.is_press_edge(event):
        return false
    if state == "select":
        if event.is_action_pressed(PrototypeControls.MENU_UP):
            selected_index = wrapi(selected_index - 1, 0, entries.size())
            _refresh_select_list()
            return true
        if event.is_action_pressed(PrototypeControls.MENU_DOWN):
            selected_index = wrapi(selected_index + 1, 0, entries.size())
            _refresh_select_list()
            return true
        if event.is_action_pressed(PrototypeControls.MENU_ACCEPT):
            _start_at(selected_index)
            return true
        if event.is_action_pressed(PrototypeControls.MENU_CANCEL) or event.is_action_pressed(PrototypeControls.PAUSE):
            close()
            exit_requested.emit()
            return true
        return false
    if state == "active":
        if event.is_action_pressed(PrototypeControls.RESTART):
            _prepare_current()
            return true
        if event.is_action_pressed(PrototypeControls.MENU_CANCEL) or event.is_action_pressed(PrototypeControls.PAUSE):
            close()
            exit_requested.emit()
            return true
        return false
    if state == "complete":
        if event.is_action_pressed(PrototypeControls.RESTART):
            current_index = 0
            _start_at(0)
            return true
        if event.is_action_pressed(PrototypeControls.MENU_ACCEPT):
            state = "select"
            selected_index = 0
            _show_select()
            return true
        if event.is_action_pressed(PrototypeControls.MENU_CANCEL) or event.is_action_pressed(PrototypeControls.PAUSE):
            close()
            exit_requested.emit()
            return true
    return false


func _show_select() -> void:
    title_label.visible = true
    list_label.visible = true
    list_hint.visible = true
    lesson_label.visible = false
    progress_label.visible = false
    group_label.visible = false
    input_label.visible = false
    status_label.visible = true
    status_label.text = "Choose a starting move. Progress is not saved."
    list_hint.text = "UP/DOWN choose   ENTER start   ESC return"
    _refresh_select_list()


func _refresh_select_list() -> void:
    var lines: Array[String] = []
    var first: int = maxi(0, selected_index - 5)
    var last: int = mini(entries.size() - 1, first + 10)
    if last - first < 10:
        first = maxi(0, last - 10)
    for index: int in range(first, last + 1):
        var entry: Dictionary = entries[index]
        var marker: String = ">" if index == selected_index else " "
        lines.append("%s %02d  %-20s  %s" % [
            marker, index + 1, String(entry.get("label", "")),
            String(entry.get("input", ""))
        ])
    list_label.text = "\n".join(lines)


func _start_at(index: int) -> void:
    current_index = clampi(index, 0, entries.size() - 1)
    state = "active"
    title_label.visible = false
    list_label.visible = false
    list_hint.visible = false
    lesson_label.visible = true
    progress_label.visible = true
    group_label.visible = true
    input_label.visible = true
    status_label.visible = true
    _prepare_current()


func _prepare_current() -> void:
    if state != "active" or entries.is_empty():
        return
    success_timer = -1.0
    dummy_restart_timer = -1.0
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
    var entry: Dictionary = entries[current_index]
    var setup: String = String(entry.get("setup", "idle"))
    if setup.begins_with("source_"):
        _prime_source_attack(setup.trim_prefix("source_"))
    elif setup == "parry_high":
        _begin_dummy_attack("high_punch")
    elif setup == "parry_low":
        _begin_dummy_attack("low_kick")
    elif setup == "parry_attack":
        _begin_dummy_attack("high_punch")
    elif setup == "endattack1" or setup == "endattack2":
        _prime_source_attack("high_punch")
        computer.state = "hitstun"
        computer.state_time = 1.0
    elif setup == "target_down":
        computer.state = "facedownidle"
        computer._animate_candidate()
    elif setup == "player_down":
        player.state = "facedownidle"
        player._animate_candidate()
    _refresh_lesson(entry)
    status_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
    status_label.text = "WAITING FOR " + String(entry.get("label", "")) + " ..."
    last_status = ""


func _prime_source_attack(kind: String) -> void:
    if not player.ATTACKS.has(kind):
        return
    player.attack_kind = kind
    player.state = "recovery"
    player.state_time = 0.01
    player._attack_hit_landed = true
    player._attack_connected = true
    player._animate_candidate()


func _begin_dummy_attack(kind: String) -> void:
    if computer.request_attack(kind):
        dummy_restart_timer = 2.0


func _refresh_lesson(entry: Dictionary) -> void:
    lesson_label.text = String(entry.get("label", ""))
    progress_label.text = "%02d / %02d" % [current_index + 1, entries.size()]
    group_label.text = String(entry.get("group", ""))
    input_label.text = "INPUT\n" + String(entry.get("input", ""))


func _process(delta: float) -> void:
    if state != "active":
        return
    if success_timer >= 0.0:
        success_timer -= delta
        if success_timer <= 0.0:
            _advance()
        return
    if dummy_restart_timer >= 0.0:
        dummy_restart_timer -= delta
        if computer.state in ["startup", "active", "recovery"]:
            computer._physics_process(delta)
        elif dummy_restart_timer <= 0.0:
            var entry: Dictionary = entries[current_index]
            var setup: String = String(entry.get("setup", ""))
            if setup == "parry_high" or setup == "parry_low" or setup == "parry_attack":
                computer.state = "idle"
                _begin_dummy_attack("high_punch" if setup == "parry_high" else "low_kick")


func _advance() -> void:
    success_timer = -1.0
    if current_index + 1 >= entries.size():
        state = "complete"
        lesson_label.visible = true
        progress_label.visible = true
        group_label.visible = false
        input_label.visible = false
        lesson_label.text = "TRAINING COMPLETE"
        progress_label.text = "%02d / %02d" % [entries.size(), entries.size()]
        status_label.text = "ENTER choose start   R replay all   ESC return"
        player.set_physics_process(true)
        computer.set_physics_process(false)
        return
    current_index += 1
    _prepare_current()


func _success() -> void:
    if state != "active" or success_timer >= 0.0:
        return
    success_timer = 0.9
    player.set_physics_process(false)
    computer.set_physics_process(false)
    status_label.text = "OK · NEXT: " + (
        String(entries[current_index + 1].get("label", ""))
        if current_index + 1 < entries.size() else "COMPLETE"
    )
    status_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))


func _wrong(action: String) -> void:
    if state != "active" or success_timer >= 0.0:
        return
    status_label.text = "GOT " + action + " · TRY " + String(entries[current_index].get("label", ""))
    status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.40))


func _on_combat_hit(
        attacker: PortFighter, _defender: PortFighter, action: String,
        _damage: float, blocked: bool
) -> void:
    if attacker != player or blocked or success_timer >= 0.0:
        return
    var entry: Dictionary = entries[current_index]
    if String(entry.get("success", "")) != "hit":
        return
    var actions: Array = entry.get("actions", [])
    if action in actions:
        _success()
    elif action in ["punch", "kick", "high_punch", "high_kick", "heavy"]:
        return


func _on_parry_succeeded(action: String) -> void:
    if success_timer >= 0.0:
        return
    var entry: Dictionary = entries[current_index]
    if String(entry.get("success", "")) == "parry" and action in entry.get("actions", []):
        _success()


func _on_attack_started(action: String) -> void:
    if success_timer >= 0.0:
        return
    var entry: Dictionary = entries[current_index]
    if String(entry.get("success", "")) == "started" and action in entry.get("actions", []):
        _success()

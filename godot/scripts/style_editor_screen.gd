extends CanvasLayer
class_name StyleEditorScreen

## Opt-in Style Editor reachable from the main menu ONLY while
## BRUCELEE_STYLE_EDITOR=1 (the row is added by prototype_menu.gd under the
## same gate).
##
## Layout comes from the decoded adreno_200 .ui records: every widget position
## is read from data/styleeditor_runtime.json (styleeditor.ui / stylespecial.ui
## / stylegrabs.ui / styleselectfighter*.ui / styleeditorhelp.ui /
## confirmresetstyle.ui), not hand-guessed. The 480x320 recovered canvas is
## drawn at 2x inside the 1280x720 window.
##
## Flow:
##   category -> special/hpunch,lpunch,hkick,lkick
##              grabs/graba,grabb
##              personality (decoded category; styleeditor.ui itself has no row)
##              endmove
##              reset confirmation
##              try_style -> the training command
##   each category -> fighter dock (one screen per group) -> pick + save
##
## A saved style changes gameplay only through StyleClipMap: an exact,
## unambiguous source_action clip for the selected character's own attack table
## AND that clip is present in the active fighter. Everything else shows the
## key/name and is NOT applied.

signal closed
signal try_requested
signal selection_saved(group_key: String, entry_id: String)

const PrototypeControls = preload("res://scripts/prototype_controls.gd")
const StyleClipMap = preload("res://scripts/style_clip_map.gd")
const StyleUnlockGate = preload("res://scripts/style_unlock_gate.gd")
const Lang = preload("res://scripts/menu_lang.gd")

const LOGICAL_SIZE: Vector2 = Vector2(480.0, 320.0)
const SCALE: float = 2.0
const FRAME_SIZE: Vector2 = Vector2(960.0, 640.0)
const SAVE_PATH_LABEL: String = "user://style_selections.json"

const COLOR_BACKDROP := Color(0.02, 0.03, 0.045, 1.0)
const COLOR_PANEL := Color(0.055, 0.075, 0.10, 0.94)
const COLOR_PANEL_2 := Color(0.08, 0.10, 0.135, 0.96)
const COLOR_BORDER := Color(0.30, 0.35, 0.42, 0.85)
const COLOR_TEXT := Color(0.86, 0.88, 0.92)
const COLOR_DIM := Color(0.58, 0.62, 0.68)
const COLOR_FAINT := Color(0.40, 0.44, 0.50)
const COLOR_GOLD := Color(0.98, 0.78, 0.30)
const COLOR_GREEN := Color(0.45, 0.88, 0.55)
const COLOR_WARN := Color(0.95, 0.62, 0.28)
const COLOR_RED := Color(0.92, 0.42, 0.38)

var player: Node = null
var catalog = null
var store = null
## Live unlock provider check (always_available, or the entry's recovered
## style_anim unlock id present in user://progress_save.json).  A locked entry
## is never written to the selection store.
var unlock_gate = null

var _open: bool = false
var _screen: String = "closed"
var _cursor: int = 0
var _fighter_cursor: int = 0
var _group_key: String = ""
var _parent_screen: String = "category"
var _return_screen: String = "category"
var _status: String = ""
var _status_is_error: bool = false
var _apply_report: Dictionary = {}

var _root: Control
var _frame: Control
var _canvas: Control
var _content: Control
var _status_label: Label
var _hint_label: Label


func _ready() -> void:
    PrototypeControls.ensure_default_actions()
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 40
    visible = false
    _build_base()


func _input(event: InputEvent) -> void:
    ## The screen runs with PROCESS_MODE_ALWAYS and consumes its own keys, so it
    ## keeps working while the tree is paused behind the main menu.
    if handle_input_event(event):
        get_viewport().set_input_as_handled()


func configure(main_node: Node, player_node: Node, catalog_obj, store_obj) -> void:
    ## main_node is accepted for symmetry with the other screens and future
    ## hooks; the editor only needs the player, the catalog and the store.
    player = player_node
    catalog = catalog_obj
    store = store_obj
    if unlock_gate == null:
        unlock_gate = StyleUnlockGate.new()
    else:
        unlock_gate.refresh()
    unlock_gate.progress = main_node.get("progress") if main_node != null else null
    if not is_inside_tree():
        return
    _refresh()


# ------------------------------------------------------------------ public

func open() -> void:
    if not is_inside_tree():
        return
    # A story event / EXP threshold may have been granted since the last open.
    if unlock_gate != null:
        unlock_gate.refresh()
    _open = true
    visible = true
    _screen = "category"
    _cursor = 0
    _group_key = ""
    _status = ""
    _status_is_error = false
    _refresh()


func close() -> void:
    if not _open:
        return
    _open = false
    visible = false
    _screen = "closed"
    closed.emit()


func is_open() -> bool:
    return _open


func screen_name() -> String:
    return _screen


func group_key() -> String:
    return _group_key


func cursor() -> int:
    return _cursor


func fighter_cursor() -> int:
    return _fighter_cursor


func current_entry() -> Dictionary:
    if catalog == null or _group_key.is_empty():
        return {}
    var list: Array = catalog.entries(_group_key)
    if _fighter_cursor < 0 or _fighter_cursor >= list.size():
        return {}
    return list[_fighter_cursor]


func saved_entry_id() -> String:
    if catalog == null or _group_key.is_empty() or store == null:
        return ""
    return String(store.selections.get(_group_key, ""))


func saved_entry() -> Dictionary:
    if catalog == null or _group_key.is_empty():
        return {}
    return catalog.entry(_group_key, saved_entry_id())


func set_apply_report(report: Dictionary) -> void:
    _apply_report = report
    if _screen == "fighter" and _open:
        _refresh()


func apply_report() -> Dictionary:
    return _apply_report


func show_status(value: String, is_error: bool = false) -> void:
    _status = value
    _status_is_error = is_error
    _update_status()


func current_options() -> Array:
    if _screen == "category":
        return catalog.category_options() if catalog != null else []
    if _screen == "special":
        return catalog.special_options() if catalog != null else []
    if _screen == "grabs":
        return catalog.grabs_options() if catalog != null else []
    if _screen == "reset":
        return [["no", "no"], ["yes", "yes"]]
    return []


func layout_report() -> Dictionary:
    var rects: Dictionary = {}
    if catalog != null:
        var screen: String = _layout_screen()
        for widget in catalog.widgets(screen):
            var name: String = String(widget.get("name", ""))
            if name.is_empty():
                continue
            rects[name] = [
                float(widget.get("x", 0)),
                float(widget.get("y", 0)),
                float(widget.get("width", 0)),
                float(widget.get("height", 0)),
            ]
    return {
        "screen": _screen,
        "open": _open,
        "cursor": _cursor,
        "fighter_cursor": _fighter_cursor,
        "group": _group_key,
        "options": current_options().duplicate(true),
        "saved_id": saved_entry_id(),
        "current_id": String(current_entry().get("id", "")),
        "widgets": rects,
        "status": _status,
    }


# ------------------------------------------------------------------ input

func handle_input_event(event: InputEvent) -> bool:
    if not _open:
        return false
    if not PrototypeControls.is_press_edge(event):
        return false
    if event is InputEventKey:
        var key_event: InputEventKey = event as InputEventKey
        if (key_event.keycode == KEY_H or key_event.keycode == KEY_F1) and key_event.pressed and not key_event.echo:
            if _screen != "help":
                _return_screen = _screen
                _screen = "help"
                _rebuild()
            return true
    if _screen == "help":
        if (event.is_action_pressed(PrototypeControls.MENU_ACCEPT)
                or event.is_action_pressed(PrototypeControls.MENU_CANCEL)):
            _screen = _return_screen
            _rebuild()
            return true
        return false
    if _screen == "fighter":
        if event.is_action_pressed(PrototypeControls.MOVE_LEFT):
            _move_fighter(-1)
            return true
        if event.is_action_pressed(PrototypeControls.MOVE_RIGHT):
            _move_fighter(1)
            return true
        if event.is_action_pressed(PrototypeControls.MENU_UP):
            _move_fighter(-1)
            return true
        if event.is_action_pressed(PrototypeControls.MENU_DOWN):
            _move_fighter(1)
            return true
        if event.is_action_pressed(PrototypeControls.MENU_ACCEPT):
            _save_current()
            return true
        if event.is_action_pressed(PrototypeControls.MENU_CANCEL):
            _back()
            return true
        return false
    if event.is_action_pressed(PrototypeControls.MENU_UP):
        _move(-1)
        return true
    if event.is_action_pressed(PrototypeControls.MENU_DOWN):
        _move(1)
        return true
    if event.is_action_pressed(PrototypeControls.MENU_ACCEPT):
        _accept_menu()
        return true
    if event.is_action_pressed(PrototypeControls.MENU_CANCEL):
        _back()
        return true
    return false


func _move(step: int) -> void:
    var options: Array = current_options()
    if options.is_empty():
        return
    _cursor = wrapi(_cursor + step, 0, options.size())
    _rebuild()


func entry_unlock_state(entry: Dictionary) -> Dictionary:
    ## Public read-only view for the editor status line and the unlock tests.
    if unlock_gate == null:
        return {"available": false, "reason": "unlock_gate_unavailable"}
    return unlock_gate.state_for(entry)


func unlock_gate_summary() -> Dictionary:
    if unlock_gate == null:
        return {"available": false, "reason": "unlock_gate_unavailable"}
    return unlock_gate.summary()


func _locked_status(entry: Dictionary) -> String:
    var state: Dictionary = entry_unlock_state(entry)
    var label: String = String(entry.get("alias", entry.get("id", "")))
    var detail: String = String(state.get("reason", "locked"))
    var unlock_id: int = int(state.get("unlock_id", -1))
    if unlock_id >= 0:
        detail += " id %d exp %d" % [unlock_id, int(state.get("exp", 0))]
    return "LOCKED | %s (%s)" % [label, detail]


func _move_fighter(step: int) -> void:
    if catalog == null or _group_key.is_empty():
        return
    var count: int = catalog.entries(_group_key).size()
    if count <= 0:
        return
    _fighter_cursor = wrapi(_fighter_cursor + step, 0, count)
    var entry: Dictionary = current_entry()
    if entry.is_empty():
        _status = ""
        _status_is_error = false
    elif entry_unlock_state(entry).get("available", false):
        _status = ""
        _status_is_error = false
    else:
        _status = _locked_status(entry)
        _status_is_error = true
    _rebuild()


func _accept_menu() -> void:
    var options: Array = current_options()
    if options.is_empty():
        return
    _cursor = clampi(_cursor, 0, options.size() - 1)
    var option: Array = options[_cursor]
    var command: String = String(option[1]) if option.size() > 1 else ""
    match _screen:
        "category":
            match command:
                "special":
                    _parent_screen = "category"
                    _screen = "special"
                    _cursor = 0
                    _rebuild()
                "grabs":
                    _parent_screen = "category"
                    _screen = "grabs"
                    _cursor = 0
                    _rebuild()
                "personality", "endmove":
                    _show_fighter(catalog.group_for_command(command))
                "reset":
                    _parent_screen = "category"
                    _screen = "reset"
                    _cursor = 0
                    _status = ""
                    _rebuild()
                "training":
                    try_requested.emit()
        "special", "grabs":
            _show_fighter(catalog.group_for_command(command))
        "reset":
            if command == "yes":
                _reset_to_defaults()
            else:
                _back()


func _show_fighter(group_key: String) -> void:
    if catalog == null or catalog.group(group_key).is_empty():
        show_status("NO DECODED ENTRIES FOR " + group_key, true)
        return
    _group_key = group_key
    _parent_screen = _screen if _screen in ["special", "grabs"] else "category"
    _screen = "fighter"
    var saved_id: String = String(store.selections.get(group_key, "")) if store != null else ""
    _fighter_cursor = maxi(0, catalog.entry_index(group_key, saved_id))
    _status = ""
    _rebuild()


func _save_current() -> void:
    var entry: Dictionary = current_entry()
    if entry.is_empty() or store == null or catalog == null:
        return
    if not bool(entry_unlock_state(entry).get("available", false)):
        show_status(_locked_status(entry), true)
        return
    if not store.set_selection(catalog, _group_key, String(entry.get("id", ""))):
        show_status(String(store.last_error), true)
        return
    if not store.save():
        show_status(String(store.last_error), true)
        return
    _status = "SAVED | " + String(entry.get("alias", entry.get("id", "")))
    _status_is_error = false
    selection_saved.emit(_group_key, String(entry.get("id", "")))
    _rebuild()


func _reset_to_defaults() -> void:
    if store == null or catalog == null:
        return
    store.reset(catalog)
    store.save()
    _status = "RESET TO DECODED DEFAULTS"
    _status_is_error = false
    selection_saved.emit("__reset__", "")
    _screen = "category"
    _cursor = 0
    _group_key = ""
    _rebuild()


func _back() -> void:
    match _screen:
        "category":
            close()
        "special", "grabs", "reset":
            _screen = "category"
            _cursor = 0
            _rebuild()
        "fighter":
            _screen = _parent_screen
            _cursor = 0
            _rebuild()
        "help":
            _screen = _return_screen
            _rebuild()
        _:
            close()


# ------------------------------------------------------------------ UI

func _build_base() -> void:
    _root = Control.new()
    _root.name = "StyleEditorRoot"
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_root)

    var backdrop: ColorRect = ColorRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.color = COLOR_BACKDROP
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(backdrop)

    var bg: TextureRect = TextureRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bg.modulate = Color(1.0, 1.0, 1.0, 0.34)
    var bg_path: String = "res://ui/styleeditor/styleeditor_bg.png"
    if ResourceLoader.exists(bg_path):
        var texture: Texture2D = load(bg_path) as Texture2D
        if texture != null:
            bg.texture = texture
    _root.add_child(bg)

    var shade: ColorRect = ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.01, 0.015, 0.025, 0.52)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(shade)

    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(center)

    _frame = Control.new()
    _frame.name = "StyleEditorFrame"
    _frame.custom_minimum_size = FRAME_SIZE
    _frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.add_child(_frame)

    _canvas = Control.new()
    _canvas.name = "StyleEditorCanvas"
    _canvas.size = LOGICAL_SIZE
    _canvas.scale = Vector2(SCALE, SCALE)
    _canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _frame.add_child(_canvas)

    _content = Control.new()
    _content.name = "Content"
    _content.size = LOGICAL_SIZE
    _content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _canvas.add_child(_content)

    _status_label = _make_label(
        Rect2(58, 280, 364, 18), "", 9, COLOR_GOLD,
        HORIZONTAL_ALIGNMENT_CENTER
    )
    _canvas.add_child(_status_label)
    _hint_label = _make_label(
        Rect2(58, 298, 364, 16),
        "UP/DOWN choose   LEFT/RIGHT fighter   ENTER save   ESC back   H help",
        8, COLOR_FAINT, HORIZONTAL_ALIGNMENT_CENTER
    )
    _canvas.add_child(_hint_label)
    _hint_label.text = "UP/DOWN choose   LEFT/RIGHT fighter   ENTER save   ESC back   H help"


func _clear_content() -> void:
    for child in _content.get_children():
        child.visible = false
        child.queue_free()


func _refresh() -> void:
    if not _open:
        return
    _rebuild()


func _rebuild() -> void:
    if _canvas == null:
        return
    _clear_content()
    var screen: String = _layout_screen()
    if catalog != null:
        var layout: Dictionary = catalog.layout(screen)
        if layout.is_empty():
            _build_missing_layout(screen)
        else:
            for widget in catalog.widgets(screen):
                _build_widget(screen, widget)
    else:
        _build_missing_layout(screen)
    _status_label.text = _status
    _status_label.add_theme_color_override(
        "font_color", COLOR_RED if _status_is_error else COLOR_GOLD
    )
    _hint_label.visible = _screen != "help"


func _layout_screen() -> String:
    match _screen:
        "special":
            return "stylespecial.ui"
        "grabs":
            return "stylegrabs.ui"
        "fighter":
            if catalog != null and not _group_key.is_empty():
                return String(catalog.group(_group_key).get("screen", ""))
            return "styleselectfighter.ui"
        "help":
            return "styleeditorhelp.ui"
        "reset":
            return "confirmresetstyle.ui"
        _:
            return "styleeditor.ui"


func _build_missing_layout(screen: String) -> void:
    var label: Label = _make_label(
        Rect2(40, 120, 400, 60), "STYLE EDITOR DATA UNAVAILABLE\n" + screen,
        14, COLOR_RED, HORIZONTAL_ALIGNMENT_CENTER
    )
    _content.add_child(label)


func _build_widget(screen: String, widget: Dictionary) -> void:
    var kind: String = String(widget.get("type", ""))
    var widget_name: String = String(widget.get("name", ""))
    var rect: Rect2 = Rect2(
        float(widget.get("x", 0)),
        float(widget.get("y", 0)),
        float(widget.get("width", 0)),
        float(widget.get("height", 0)),
    )
    match kind:
        "bllabel":
            _build_title(screen, widget_name, rect)
        "label":
            _build_label_widget(screen, widget_name, rect)
        "blmenu":
            _build_menu(widget, rect)
        "bldock":
            _build_dock(widget, rect)
        "blbutton":
            _build_button(widget_name, rect)
        "picture":
            _build_picture(rect)
        "staticrect":
            var panel: Panel = _make_panel(rect, COLOR_PANEL, COLOR_BORDER)
            _content.add_child(panel)
        "textbox":
            _build_help_text(rect)
        _:
            pass


func _build_title(screen: String, widget_name: String, rect: Rect2) -> void:
    var text: String = ""
    if widget_name == "title":
        if screen == "styleeditor.ui":
            text = Lang.text("style_editor")
        elif screen == "stylespecial.ui":
            text = Lang.text("special_moves")
        elif screen == "stylegrabs.ui":
            text = Lang.text("grabs")
        elif screen == "confirmresetstyle.ui":
            text = Lang.text("reset_style")
            if text == "reset_style" or text.is_empty():
                text = "RESET STYLE"
        elif _screen == "fighter":
            text = _fighter_title()
        else:
            text = "STYLE EDITOR"
        if text == "style_editor" or text.is_empty():
            text = "STYLE EDITOR"
    else:
        text = _upper(widget_name)
    var label: Label = _make_label(rect, text, 17, COLOR_GOLD, HORIZONTAL_ALIGNMENT_LEFT)
    Lang.apply_font(label)
    _content.add_child(label)
    if widget_name == "title":
        var source: Label = _make_label(
            Rect2(272, 10, 200, 16), "styleeditor.list | 205 strings | 60 entries",
            8, COLOR_FAINT, HORIZONTAL_ALIGNMENT_RIGHT
        )
        _content.add_child(source)


func _build_label_widget(screen: String, widget_name: String, rect: Rect2) -> void:
    var text: String = ""
    if widget_name == "movename":
        var entry: Dictionary = current_entry()
        if not entry.is_empty():
            var nametag: String = String(entry.get("nametag", ""))
            text = _upper(nametag if not nametag.is_empty() else String(entry.get("animation", "")))
        if text.is_empty():
            text = _fighter_group_label()
    elif widget_name == "slotempty":
        text = Lang.text("reset_style_confirm")
        if text == "reset_style_confirm":
            text = "Reset every style selection to the decoded defaults?"
    else:
        text = _upper(widget_name)
    var label: Label = _make_label(rect, text, 11, COLOR_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    Lang.apply_font(label)
    _content.add_child(label)


func _fighter_title() -> String:
    var category: String = String(_group_key.split("/")[0])
    var group_name: String = String(_group_key.split("/")[1]) if _group_key.contains("/") else ""
    var head: String = "STYLE EDITOR"
    match category:
        "special":
            head = Lang.text("special_moves")
            if head == "special_moves":
                head = "SPECIAL MOVES"
        "grabs":
            head = Lang.text("grabs")
            if head == "grabs":
                head = "GRABS"
        "endmove":
            head = "END MOVES"
        "personality":
            head = "PERSONALITY"
    var tail: String = group_name.to_upper()
    if category == "personality":
        tail = ""
    return (head + (" | " + tail if not tail.is_empty() else "")).to_upper()


func _fighter_group_label() -> String:
    if _group_key.is_empty():
        return ""
    var parts: Array = _group_key.split("/")
    return _upper(String(parts[parts.size() - 1]))


func _build_menu(widget: Dictionary, rect: Rect2) -> void:
    var options: Array = current_options()
    if options.is_empty():
        options = widget.get("options", [])
    var panel: Panel = _make_panel(rect, COLOR_PANEL, COLOR_BORDER)
    _content.add_child(panel)
    if options.is_empty():
        return
    var row_height: float = minf(30.0, rect.size.y / float(options.size()))
    var top: float = rect.position.y + (rect.size.y - row_height * float(options.size())) * 0.5
    for index in range(options.size()):
        var option: Array = options[index]
        var label_text: String = _option_text(String(option[0])) if option.size() > 0 else ""
        if _screen == "reset":
            label_text = String(option[0]).to_upper()
        var selected: bool = index == _cursor
        var label: Label = _make_label(
            Rect2(rect.position.x + 10, top + row_height * float(index), rect.size.x - 20, row_height),
            ("> " + label_text + " <" if selected else label_text),
            13, COLOR_GOLD if selected else COLOR_TEXT,
            HORIZONTAL_ALIGNMENT_CENTER
        )
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        Lang.apply_font(label)
        _content.add_child(label)
        label.mouse_filter = Control.MOUSE_FILTER_STOP
        label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        label.gui_input.connect(_on_option_gui_input.bind(index))
        if selected:
            var underline: ColorRect = ColorRect.new()
            underline.position = Vector2(rect.position.x + rect.size.x * 0.18, top + row_height * float(index + 1) - 2)
            underline.size = Vector2(rect.size.x * 0.64, 1)
            underline.color = COLOR_GOLD
            underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
            _content.add_child(underline)


func _option_text(key: String) -> String:
    var text: String = Lang.text(key)
    if text == key or text.is_empty():
        return _upper(key.replace("_", " "))
    return _upper(text)


func _on_option_gui_input(event: InputEvent, index: int) -> void:
    if event is InputEventMouseMotion:
        if index != _cursor:
            _cursor = index
            _rebuild()
        return
    var button: InputEventMouseButton = event as InputEventMouseButton
    if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
        return
    _cursor = index
    _accept_menu()


func _build_dock(widget: Dictionary, rect: Rect2) -> void:
    if catalog == null or _group_key.is_empty():
        return
    var entries: Array = catalog.entries(_group_key)
    if entries.is_empty():
        return
    var count: int = entries.size()
    var gap: float = 4.0
    var cell_width: float = minf(52.0, (rect.size.x - gap * float(count - 1)) / float(count))
    var cell_height: float = minf(56.0, rect.size.y)
    var total: float = cell_width * float(count) + gap * float(count - 1)
    var start_x: float = rect.position.x + (rect.size.x - total) * 0.5
    var top: float = rect.position.y + (rect.size.y - cell_height) * 0.5
    var saved_id: String = saved_entry_id()
    for index in range(count):
        var entry: Dictionary = entries[index]
        var entry_id: String = String(entry.get("id", ""))
        var is_saved: bool = entry_id == saved_id and not saved_id.is_empty()
        var is_cursor: bool = index == _fighter_cursor
        var x: float = start_x + float(index) * (cell_width + gap)
        var border_color: Color = COLOR_GOLD if is_saved else (
            Color(0.92, 0.94, 1.0) if is_cursor else COLOR_BORDER
        )
        var fill: Color = Color(0.18, 0.22, 0.28, 1.0) if is_cursor else Color(0.07, 0.09, 0.12, 1.0)
        var panel: Panel = _make_panel(
            Rect2(x, top, cell_width, cell_height), fill, border_color,
            2 if (is_saved or is_cursor) else 1
        )
        _content.add_child(panel)
        panel.mouse_filter = Control.MOUSE_FILTER_STOP
        panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        panel.gui_input.connect(_on_cell_gui_input.bind(index))
        var short: String = _short_name(String(entry.get("character", "")))
        var tag: Label = _make_label(
            Rect2(x + 1, top + 4, cell_width - 2, 18), short, 8,
            COLOR_GOLD if is_saved else COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER
        )
        tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _content.add_child(tag)
        var mark: Label = _make_label(
            Rect2(x + 1, top + 22, cell_width - 2, 14),
            "S" if is_saved else (">" if is_cursor else ""), 8,
            COLOR_GOLD if is_saved else Color(0.92, 0.94, 1.0),
            HORIZONTAL_ALIGNMENT_CENTER
        )
        mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _content.add_child(mark)
        var order: Label = _make_label(
            Rect2(x + 1, top + cell_height - 16, cell_width - 2, 12), "%02d" % (index + 1),
            7, COLOR_FAINT, HORIZONTAL_ALIGNMENT_CENTER
        )
        order.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _content.add_child(order)
    _build_fighter_details(rect, entries)


func _short_name(character: String) -> String:
    match character:
        "kengodall":
            return "KEN"
        "themaster":
            return "MAS"
        "brucelee":
            return "BRU"
        "smallboy":
            return "SMB"
        "johnson":
            return "JOH"
        "brickdavis":
            return "BRI"
        "loming":
            return "LOM"
        "shenlo":
            return "SHE"
        "sinfu":
            return "SIN"
        "chief":
            return "CHI"
        _:
            return character.substr(0, 3).to_upper()


func _build_fighter_details(rect: Rect2, entries: Array) -> void:
    var entry: Dictionary = current_entry()
    if entry.is_empty():
        return
    var alias: String = String(entry.get("alias", entry.get("character", ""))).to_upper()
    var alias_label: Label = _make_label(
        Rect2(16, 140, 190, 22), alias, 18, COLOR_GOLD, HORIZONTAL_ALIGNMENT_LEFT
    )
    Lang.apply_font(alias_label)
    _content.add_child(alias_label)
    var lines: String = (
        "UNIQUE  " + String(entry.get("id", "")) + "\n"
        + "ANIM    " + String(entry.get("animation", "")) + "\n"
        + "CLIP    " + (String(entry.get("clip", "")) if not String(entry.get("clip", "")).is_empty() else "-")
    )
    var detail: Label = _make_label(
        Rect2(16, 162, 178, 34), lines, 8, COLOR_DIM, HORIZONTAL_ALIGNMENT_LEFT
    )
    detail.autowrap_mode = TextServer.AUTOWRAP_OFF
    detail.clip_text = true
    _content.add_child(detail)
    var header: Label = _make_label(
        Rect2(210, 142, 254, 12), "CURRENT SELECTION", 8, COLOR_FAINT, HORIZONTAL_ALIGNMENT_RIGHT
    )
    _content.add_child(header)
    var saved_id: String = saved_entry_id()
    var saved_text: String = "-"
    if not saved_id.is_empty():
        var saved: Dictionary = catalog.entry(_group_key, saved_id)
        saved_text = String(saved.get("alias", saved_id)).to_upper()
    var current: Label = _make_label(
        Rect2(210, 156, 254, 16),
        saved_text if not saved_id.is_empty() else "NOT SAVED",
        12, COLOR_GOLD if not saved_id.is_empty() else COLOR_WARN,
        HORIZONTAL_ALIGNMENT_RIGHT
    )
    Lang.apply_font(current)
    _content.add_child(current)
    var index_text: String = "%02d/%02d" % [_fighter_cursor + 1, entries.size()]
    var counter: Label = _make_label(
        Rect2(210, 172, 254, 12), index_text, 8, COLOR_FAINT, HORIZONTAL_ALIGNMENT_RIGHT
    )
    _content.add_child(counter)
    var preview: Dictionary = _preview_entry(entry)
    var preview_label: Label = _make_label(
        Rect2(210, 185, 254, 12), _preview_text(preview), 7,
        COLOR_GREEN if bool(preview.get("applied", false)) else COLOR_WARN,
        HORIZONTAL_ALIGNMENT_RIGHT
    )
    preview_label.clip_text = true
    Lang.apply_font(preview_label)
    _content.add_child(preview_label)


func _preview_entry(entry: Dictionary) -> Dictionary:
    if player != null and player.has_method("style_runtime_snapshot"):
        var snapshot: Dictionary = player.style_runtime_snapshot()
        if bool(snapshot.get("loaded", false)):
            return StyleClipMap.resolve(entry, snapshot.get("slots", {}), snapshot.get("animations", {}))
    # No visible fighter (editor reached without a scene): report the decoded
    # mapping itself, never a runtime claim.
    if String(entry.get("category", "")) == "personality":
        return {"status": "no_combat_slot", "applied": false, "named_clips": entry.get("named_clips", [])}
    if String(entry.get("clip", "")).is_empty():
        return {"status": "no_direct_clip", "applied": false}
    return {"status": "mapping_only", "applied": false, "clip": String(entry.get("clip", ""))}


func _preview_text(preview: Dictionary) -> String:
    var status: String = String(preview.get("status", ""))
    if status == "mapping_only":
        return "MAPPING ONLY | " + String(preview.get("clip", ""))
    if status == "no_combat_slot":
        var named: Array = preview.get("named_clips", [])
        if named.is_empty():
            return "NO COMBAT SLOT | not applied"
        return "NO COMBAT SLOT | %d named clips" % named.size()
    return StyleClipMap.status_text(preview)


func _on_cell_gui_input(event: InputEvent, index: int) -> void:
    if event is InputEventMouseMotion:
        if index != _fighter_cursor:
            _fighter_cursor = index
            _rebuild()
        return
    var button: InputEventMouseButton = event as InputEventMouseButton
    if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
        return
    if index == _fighter_cursor and button.double_click:
        _save_current()
        return
    _fighter_cursor = index
    _rebuild()


func _build_button(widget_name: String, rect: Rect2) -> void:
    var text: String = ""
    var action: String = ""
    match widget_name:
        "back":
            text = "<"
            action = "back"
        "help":
            text = "?"
            action = "help"
        "lsk":
            text = "<"
            action = "left"
        "rsk":
            text = ">" if _screen != "help" else "X"
            action = "right" if _screen != "help" else "help_close"
    var button: Button = Button.new()
    button.text = text
    button.position = rect.position
    button.size = rect.size
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", 18)
    button.add_theme_color_override("font_color", COLOR_TEXT)
    button.add_theme_color_override("font_hover_color", COLOR_GOLD)
    var normal: StyleBoxFlat = StyleBoxFlat.new()
    normal.bg_color = Color(0.10, 0.13, 0.17, 0.96)
    normal.border_color = COLOR_BORDER
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(4)
    button.add_theme_stylebox_override("normal", normal)
    var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.18, 0.22, 0.28, 0.98)
    hover.border_color = COLOR_GOLD
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    _content.add_child(button)
    match action:
        "back":
            button.pressed.connect(_back)
        "help":
            button.pressed.connect(_open_help)
        "left":
            button.pressed.connect(_move_fighter.bind(-1))
        "right":
            button.pressed.connect(_move_fighter.bind(1))
        "help_close":
            button.pressed.connect(_close_help)



func _open_help() -> void:
    if _screen == "help":
        return
    _status = ""
    _return_screen = _screen
    _screen = "help"
    _rebuild()


func _close_help() -> void:
    _screen = _return_screen
    _rebuild()


func _build_picture(rect: Rect2) -> void:
    var picture: Panel = _make_panel(rect, COLOR_PANEL_2, COLOR_BORDER)
    _content.add_child(picture)


func _build_help_text(rect: Rect2) -> void:
    # The recovered staticrect (40,80,400,160) / textbox (80,100,320,120) is too
    # small for the controls + fail-closed explanation. The panel keeps the
    # recovered left edge and grows to a readable height; the text is shorter
    # than the raw key would be.
    var panel: Panel = _make_panel(Rect2(40, 64, 400, 232), COLOR_PANEL, COLOR_BORDER)
    _content.add_child(panel)
    var recovered: String = Lang.text("style_editor_help")
    var text: String = recovered
    if recovered == "style_editor_help" or recovered.is_empty():
        text = (
            "STYLE EDITOR\n\n"
            + "Gold frame = saved selection. White frame = cursor.\n"
            + "Saved to user://style_selections.json.\n\n"
            + "A style changes gameplay only when its animation has one exact "
            + "clip in that fighter's attack table AND the loaded fighter has "
            + "that clip. Otherwise the key/name is shown and the style is NOT "
            + "applied (fail closed).\n\n"
            + "Personality clips are named but this prototype has no "
            + "personality animation state."
        )
    var label: Label = _make_label(Rect2(58, 78, 364, 206), text, 8, COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    Lang.apply_font(label)
    _content.add_child(label)


func _update_status() -> void:
    if _status_label == null:
        return
    _status_label.text = _status
    _status_label.add_theme_color_override(
        "font_color", COLOR_RED if _status_is_error else COLOR_GOLD
    )


func _make_label(
    rect: Rect2,
    text: String,
    font_size: int,
    color: Color,
    alignment: HorizontalAlignment
) -> Label:
    var label: Label = Label.new()
    label.position = rect.position
    label.size = rect.size
    label.text = text
    label.horizontal_alignment = alignment
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label


func _make_panel(
    rect: Rect2,
    fill: Color,
    border: Color,
    border_width: int = 1
) -> Panel:
    var panel: Panel = Panel.new()
    panel.position = rect.position
    panel.size = rect.size
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(5)
    panel.add_theme_stylebox_override("panel", style)
    return panel


func _upper(value: String) -> String:
    return value.to_upper()


extends CanvasLayer
class_name PortHUD

var player_bar: ProgressBar
var opponent_bar: ProgressBar
var hint: Label
var center_message: Label
var footer: Label

func _ready() -> void:
    var screen: Control = Control.new()
    screen.set_anchors_preset(Control.PRESET_FULL_RECT)
    screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(screen)
    var top: HBoxContainer = HBoxContainer.new()
    top.anchor_right = 1.0
    top.offset_left = 24.0
    top.offset_top = 18.0
    top.offset_right = -24.0
    top.offset_bottom = 78.0
    top.add_theme_constant_override("separation", 40)
    screen.add_child(top)
    var p: VBoxContainer = VBoxContainer.new()
    p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(p)
    _add_label(p, "BRUCE | PLAYER", 20)
    player_bar = _make_bar(p)
    var o: VBoxContainer = VBoxContainer.new()
    o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(o)
    _add_label(o, "OPPONENT | CPU", 20)
    opponent_bar = _make_bar(o)
    hint = Label.new()
    hint.anchor_left = 0.5
    hint.anchor_right = 0.5
    hint.anchor_top = 0.50
    hint.anchor_bottom = 0.50
    hint.offset_left = -420
    hint.offset_right = 420
    hint.offset_top = -50
    hint.offset_bottom = 20
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 29)
    screen.add_child(hint)
    footer = Label.new()
    footer.anchor_top = 1.0
    footer.anchor_bottom = 1.0
    footer.anchor_right = 1.0
    footer.offset_left = 15
    footer.offset_right = -15
    footer.offset_top = -62
    footer.offset_bottom = -12
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_font_size_override("font_size", 17)
    footer.text = "A/D move  W/S sidestep   J punch   K kick   L heavy   SHIFT guard   R restart"
    screen.add_child(footer)
    center_message = hint

func _add_label(parent: Node, value: String, font_size: int) -> void:
    var label: Label = Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", font_size)
    parent.add_child(label)

func _make_bar(parent: Node) -> ProgressBar:
    var bar: ProgressBar = ProgressBar.new()
    bar.custom_minimum_size = Vector2(0.0, 24.0)
    bar.max_value = 100.0
    bar.value = 100.0
    bar.show_percentage = false
    parent.add_child(bar)
    return bar

func set_health(player_health: float, enemy_health: float) -> void:
    player_bar.value = player_health
    opponent_bar.value = enemy_health

func show_message(value: String) -> void:
    center_message.text = value

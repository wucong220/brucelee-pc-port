extends CanvasLayer
class_name PortHUD
## Original HUD reconstruction.
##
## Replaces the placeholder progress bars with the original HUD sprites from
## the package's `ui/hud` folder and the layout recovered from
## krm::CBruceLeeHUD::Render (0x1959e0, decompiled at 0x1a59e0 in the Ghidra
## listing, image base 0x10000) plus krm::CBruceLeeHUD::LoadSprites
## (0x194538) and ::Update (0x193d98) in libdefault.so.
##
## Recovered layout (480x320 reference frame, the frame Render centres with
## (displayWidth - 480) * 0.5):
##   Inkbar            512x64 art drawn at (0, 0), clipped to the 480 wide frame
##   life bar row      y = 22   (0x41b00000)
##   chi bar row       y = 32   (0x42000000)
##   left life bar     x = 15 + (1 - value) * 194, 256x8 art, 32px transparent
##                     margin each side -> 192 solid px, inner end at 15+223=238
##   right life bar    drawn at the fixed x = 269 (0x43868000) -> solid pixels
##                     start at 269+32 = 301 and run off the right edge
##   left chi bar      drawn at the fixed x = 13 (0x41500000), 128x8 art whose
##                     solid span is columns 15..102 -> 28..115
##   right chi bar     x = 467 - 102 * (chi / 100), i.e. the right end stays at
##                     467 and the bar recedes to the right as chi drops
##   round wins        y = 32, 16x8 yellow/red dots, left player at
##                     x = 185 - 20 * i, right player at x = 280 + 20 * i
##   round clock       "%02d", centred on (242, 26)  (0x43720000, 0x41d00000)
##   name plates       left player centred on (242, 26), right player flush to
##                     470 (0x43eb0000), y = 0
##
## Bar values are eased exactly like CBruceLeeHUD::Update: the filled bar moves
## at 50 units/s (DAT_001a4010 / 0x194010), the orange damage ghost holds for
## 1000 ms (DAT_001a4008) then drains at 25 units/s (DAT_001a4018), chi moves
## at 50 units/s. The reference frame is scaled to fit the viewport so the HUD
## stays readable at 1280x720 and at 868x517.

const REFERENCE_WIDTH := 480.0
const REFERENCE_HEIGHT := 320.0

# Row / anchor constants from CBruceLeeHUD::Render.
const LIFE_ROW_Y := 22.0
const CHI_ROW_Y := 32.0
const LIFE_ART_HEIGHT := 8.0
const LIFE_ART_SOLID := 192.0          # solid columns 32..223 of the 256x8 art
const LIFE_ART_SOLID_START := 32.0
const LIFE_LEFT_INNER_END := 238.0     # x = 15 + 223, inner end of the left bar
const LIFE_RIGHT_INNER_START := 301.0  # x = 269 + 32, first solid pixel
const LIFE_RIGHT_SOLID := 179.0        # 269 + 32 .. 480 (clipped by the frame)
const CHI_ART_SOLID_START := 15.0      # solid columns 15..102 of the 128x8 art
const CHI_ART_SOLID := 88.0
const CHI_LEFT_X := 28.0               # 13 + 15
const CHI_RIGHT_END := 467.0           # x = 467 - 102 * frac
const CHI_RIGHT_SOLID := 87.0
const DOT_ROW_Y := 32.0
const DOT_STEP := 20.0
const DOT_LEFT_X := 185.0
const DOT_RIGHT_X := 280.0
const DOT_SIZE := Vector2(16.0, 8.0)
const TIMER_CENTER := Vector2(242.0, 26.0)
const INKBAR_HEIGHT := 64.0
const INKBAR_ART_WIDTH := 512.0

# CBruceLeeHUD::Update easing values.
const LIFE_RATE := 50.0
const GHOST_HOLD := 1.0
const GHOST_RATE := 25.0
const CHI_RATE := 50.0

const HUD_TEXTURE_ROOT_ENV := "BRUCELEE_HUD_TEXTURE_ROOT"

# The bar widgets are data holders for the existing test/API contract; the
# visible bars are the original sprites below.
class ValueState extends RefCounted:
    var value: float = 100.0
    var max_value: float = 100.0


var player_bar: ValueState = ValueState.new()
var opponent_bar: ValueState = ValueState.new()
var rage_bar: ValueState = ValueState.new()
var hint: Label
var center_message: Label
var footer: Label
var context_hint: Label
var round_label: Label
var timer_label: Label

var _timer_text: int = -2
var _textures: Dictionary = {}
var _assets_bottom_up: bool = false

var _frame: Control
var _inkbar: TextureRect
var _life_rects: Array[TextureRect] = []
var _ghost_rects: Array[TextureRect] = []
var _chi_rects: Array[TextureRect] = []
var _dot_rects: Array[TextureRect] = []
var _bar_atlases: Dictionary = {}
var _name_labels: Array[Label] = []

var _life_target: Array[float] = [100.0, 100.0]
var _life_display: Array[float] = [100.0, 100.0]
var _life_ghost: Array[float] = [100.0, 100.0]
var _ghost_hold: Array[float] = [0.0, 0.0]
var _chi_target: Array[float] = [0.0, 0.0]
var _chi_display: Array[float] = [0.0, 0.0]
var _wins: Array[int] = [0, 0]
var _dots_per_side: int = 2


func _ready() -> void:
    _load_textures()
    _build()
    _apply_layout()
    if not get_viewport().size_changed.is_connected(_apply_layout):
        get_viewport().size_changed.connect(_apply_layout)
    set_process(true)


func _process(delta: float) -> void:
    _tick_values(delta)
    _refresh_bars()


# ---------------------------------------------------------------- construction

func _build() -> void:
    var screen: Control = Control.new()
    screen.set_anchors_preset(Control.PRESET_FULL_RECT)
    screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(screen)

    _frame = Control.new()
    _frame.size = Vector2(REFERENCE_WIDTH, REFERENCE_HEIGHT)
    _frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _frame.clip_contents = true
    screen.add_child(_frame)

    # The original draws the 512x64 Inkbar at (0, 0) without scaling; the HUD
    # section clips it to the 480 wide frame.
    _inkbar = _make_sprite("BL_HUD_Inkbar.png", Vector2(INKBAR_ART_WIDTH, INKBAR_HEIGHT))
    _inkbar.position = Vector2.ZERO
    _frame.add_child(_inkbar)

    # Damage ghosts sit behind the filled bars.
    _ghost_rects.append(_make_bar_sprite("BL_HUD_Lifebar_Orange_left.png"))
    _ghost_rects.append(_make_bar_sprite("BL_HUD_Lifebar_Orange_right.png"))
    _life_rects.append(_make_bar_sprite("BL_HUD_Lifebar_left.png"))
    _life_rects.append(_make_bar_sprite("BL_HUD_Lifebar_right.png"))
    for rect: TextureRect in _ghost_rects:
        _frame.add_child(rect)
    for rect: TextureRect in _life_rects:
        _frame.add_child(rect)

    _chi_rects.append(_make_bar_sprite("BL_HUD_ChiBar_left.png"))
    _chi_rects.append(_make_bar_sprite("BL_HUD_ChiBar_right.png"))
    for rect: TextureRect in _chi_rects:
        _frame.add_child(rect)

    for _index: int in range(_dots_per_side * 2):
        var dot: TextureRect = _make_bar_sprite("BL_HUD_Round_red_left.png")
        dot.size = DOT_SIZE
        _dot_rects.append(dot)
        _frame.add_child(dot)

    # Round clock: "%02d" centred on (242, 26). Render() creates this text in
    # its own section before the bars; the label is kept above the art here so
    # the digits stay legible when a bar reaches the centre gap.
    timer_label = Label.new()
    timer_label.text = "--"
    timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    timer_label.position = TIMER_CENTER - Vector2(60.0, 16.0)
    timer_label.size = Vector2(120.0, 32.0)
    timer_label.add_theme_font_size_override("font_size", 22)
    timer_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
    timer_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.0, 0.95))
    timer_label.add_theme_constant_override("outline_size", 6)
    _frame.add_child(timer_label)

    if _assets_bottom_up:
        # The local ui/hud copies are stored bottom-up; flip every sprite so the
        # Inkbar's built-in red channel and blue notches land on the bar rows.
        for node: Node in [_inkbar] + _ghost_rects + _life_rects + _chi_rects \
                + _dot_rects:
            (node as TextureRect).flip_v = true


    # Round counter must stay inside a box container (validate_round_flow).
    var round_box: VBoxContainer = VBoxContainer.new()
    round_box.position = Vector2(0.0, 44.0)
    round_box.size = Vector2(REFERENCE_WIDTH, 18.0)
    round_box.alignment = BoxContainer.ALIGNMENT_CENTER
    round_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _frame.add_child(round_box)
    round_label = Label.new()
    round_label.text = ""
    round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    round_label.add_theme_font_size_override("font_size", 13)
    round_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36))
    round_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
    round_label.add_theme_constant_override("outline_size", 4)
    round_box.add_child(round_label)

    _name_labels.append(_make_small_label("BRUCE", Vector2(47.0, 8.0),
            HORIZONTAL_ALIGNMENT_LEFT))
    _name_labels.append(_make_small_label("OPPONENT", Vector2(317.0, 8.0),
            HORIZONTAL_ALIGNMENT_RIGHT))
    var chi_label: Label = _make_small_label("CHI", Vector2(13.0, 40.0),
            HORIZONTAL_ALIGNMENT_LEFT)
    chi_label.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0, 0.9))

    hint = Label.new()
    hint.anchor_left = 0.5
    hint.anchor_right = 0.5
    hint.anchor_top = 0.16
    hint.anchor_bottom = 0.16
    hint.offset_left = -420
    hint.offset_right = 420
    hint.offset_top = 0
    hint.offset_bottom = 50
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
    footer.text = "A/D move  W/S sidestep  J/K/L/U = a/b/c/d  SHIFT guard  R restart  F2 training"
    screen.add_child(footer)

    context_hint = Label.new()
    context_hint.anchor_top = 1.0
    context_hint.anchor_bottom = 1.0
    context_hint.anchor_right = 1.0
    context_hint.offset_left = 15
    context_hint.offset_right = -15
    context_hint.offset_top = -94
    context_hint.offset_bottom = -65
    context_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    context_hint.add_theme_font_size_override("font_size", 18)
    context_hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
    screen.add_child(context_hint)
    center_message = hint

    _refresh_bars()


func _make_small_label(value: String, pos: Vector2, align: int) -> Label:
    var label: Label = Label.new()
    label.text = value
    label.position = pos
    label.size = Vector2(150.0, 12.0)
    label.horizontal_alignment = align
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 10)
    label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82, 0.95))
    label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
    label.add_theme_constant_override("outline_size", 4)
    _frame.add_child(label)
    return label


func _make_sprite(filename: String, size_value: Vector2) -> TextureRect:
    var rect: TextureRect = TextureRect.new()
    rect.texture = _textures.get(filename)
    rect.size = size_value
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_SCALE
    rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return rect


## The Inkbar art carries a dark red "empty" channel over the life row
## (rows 22..28) and blue notches over the chi row (rows 33..36). Some staged
## local copies of ui/hud store the texture bottom-up, which moves both
## features onto the wrong row; detect that and flip so the washes line up
## with the bars drawn on top of them.
func _inkbar_requires_flip(texture: Texture2D) -> bool:
    if texture == null:
        return false
    var image: Image = texture.get_image()
    if image == null:
        return false
    if image.is_compressed():
        image.decompress()
    if image.get_width() < 64 or image.get_height() < 40:
        return false
    var life_red: int = 0
    var chi_blue: int = 0
    for y: int in range(22, 29):
        for x: int in range(0, image.get_width(), 4):
            var color: Color = image.get_pixel(x, y)
            if color.a > 0.8 and color.r > 0.32 and color.r > color.g * 2.0:
                life_red += 1
    for y: int in range(33, 37):
        for x: int in range(0, image.get_width(), 4):
            var color: Color = image.get_pixel(x, y)
            if color.a > 0.8 and color.b > 0.3 and color.b > color.r * 1.5:
                chi_blue += 1
    return life_red == 0 and chi_blue == 0


func _make_bar_sprite(filename: String) -> TextureRect:
    var rect: TextureRect = TextureRect.new()
    var source: Texture2D = _textures.get(filename)
    if source != null:
        var atlas: AtlasTexture = AtlasTexture.new()
        atlas.atlas = source
        atlas.region = Rect2(0.0, 0.0, source.get_width(), LIFE_ART_HEIGHT)
        atlas.filter_clip = true
        rect.texture = atlas
        _bar_atlases[rect] = atlas
    rect.size = Vector2(1.0, LIFE_ART_HEIGHT)
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_SCALE
    rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return rect


# ---------------------------------------------------------------- value model

func _tick_values(delta: float) -> void:
    for index: int in range(2):
        var target: float = _life_target[index]
        # Filled bar: CBruceLeeHUD::Update eases it at 50 units per second.
        _life_display[index] = move_toward(_life_display[index], target, LIFE_RATE * delta)
        if target > _life_ghost[index]:
            _life_ghost[index] = target
            _ghost_hold[index] = 0.0
        elif target < _life_display[index] - 0.001:
            _ghost_hold[index] = GHOST_HOLD
        if _ghost_hold[index] > 0.0:
            _ghost_hold[index] = maxf(0.0, _ghost_hold[index] - delta)
        elif _life_ghost[index] > _life_display[index]:
            _life_ghost[index] = maxf(_life_display[index],
                    _life_ghost[index] - GHOST_RATE * delta)
        _chi_display[index] = move_toward(_chi_display[index], _chi_target[index],
                CHI_RATE * delta)


func _refresh_bars() -> void:
    if _life_rects.is_empty():
        return
    _apply_life_bar(0, _life_display[0], _life_ghost[0])
    _apply_life_bar(1, _life_display[1], _life_ghost[1])
    _apply_chi_bar(0, _chi_display[0])
    _apply_chi_bar(1, _chi_display[1])
    _refresh_dots()


func _apply_life_bar(side: int, value: float, ghost: float) -> void:
    var fraction: float = clampf(value / 100.0, 0.0, 1.0)
    var ghost_fraction: float = clampf(ghost / 100.0, 0.0, 1.0)
    if side == 0:
        # Left player: the inner (right) end stays at 238 and the stroke
        # recedes towards the centre, matching x = 15 + (1 - value) * 194.
        _place_bar(_life_rects[0], LIFE_ART_SOLID_START, LIFE_ART_SOLID,
                LIFE_LEFT_INNER_END, fraction, true)
        _place_bar(_ghost_rects[0], LIFE_ART_SOLID_START, LIFE_ART_SOLID,
                LIFE_LEFT_INNER_END, ghost_fraction, true)
    else:
        # Right player: mirrored. The inner (left) end stays at 301 and the
        # stroke recedes to the right, clipped by the frame at 480.
        _place_bar(_life_rects[1], LIFE_ART_SOLID_START, LIFE_ART_SOLID,
                LIFE_RIGHT_INNER_START, fraction, false, LIFE_RIGHT_SOLID)
        _place_bar(_ghost_rects[1], LIFE_ART_SOLID_START, LIFE_ART_SOLID,
                LIFE_RIGHT_INNER_START, ghost_fraction, false, LIFE_RIGHT_SOLID)
    _life_rects[side].position.y = LIFE_ROW_Y
    _ghost_rects[side].position.y = LIFE_ROW_Y


func _apply_chi_bar(side: int, value: float) -> void:
    var fraction: float = clampf(value / 100.0, 0.0, 1.0)
    if side == 0:
        # Left chi bar: drawn at the fixed x = 13 in the original, filled from
        # its left edge (28) to the right.
        _place_bar(_chi_rects[0], CHI_ART_SOLID_START, CHI_ART_SOLID, CHI_LEFT_X,
                fraction, false)
    else:
        # Right chi bar: x = 467 - 102 * frac, right end fixed at 467.
        _place_bar(_chi_rects[1], CHI_ART_SOLID_START, CHI_ART_SOLID,
                CHI_RIGHT_END, fraction, true, CHI_RIGHT_SOLID)
    _chi_rects[side].position.y = CHI_ROW_Y


## Crop `art_solid` columns of the bar texture and anchor the visible stroke at
## `anchor`. `hug_right` keeps the right end fixed (bar recedes from the left),
## otherwise the left end stays fixed.
func _place_bar(rect: TextureRect, art_start: float, art_solid: float,
        anchor: float, fraction: float, hug_right: bool, limit: float = -1.0) -> void:
    var max_width: float = art_solid if limit <= 0.0 else minf(art_solid, limit)
    var width: float = max_width * clampf(fraction, 0.0, 1.0)
    if width <= 0.5:
        rect.visible = false
        return
    rect.visible = true
    rect.size = Vector2(width, LIFE_ART_HEIGHT)
    var atlas: AtlasTexture = _bar_atlases.get(rect)
    if hug_right:
        rect.position.x = anchor - width
        var crop_start: float = art_start + (max_width - width)
        if atlas != null:
            atlas.region = Rect2(crop_start, 0.0, width, LIFE_ART_HEIGHT)
    else:
        rect.position.x = anchor
        if atlas != null:
            atlas.region = Rect2(art_start, 0.0, width, LIFE_ART_HEIGHT)


func _refresh_dots() -> void:
    var yellow: Texture2D = _textures.get("BL_HUD_Round_yellow_left.png")
    var red: Texture2D = _textures.get("BL_HUD_Round_red_left.png")
    for side: int in range(2):
        for index: int in range(_dots_per_side):
            var dot: TextureRect = _dot_rects[side * _dots_per_side + index]
            var won: bool = index < _wins[side]
            dot.texture = yellow if won else red
            dot.size = DOT_SIZE
            dot.visible = true
            dot.position = Vector2(
                (DOT_LEFT_X - DOT_STEP * index) if side == 0
                else (DOT_RIGHT_X + DOT_STEP * index),
                DOT_ROW_Y)


# ---------------------------------------------------------------- layout scale

func _apply_layout() -> void:
    if _frame == null:
        return
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return
    var scale_factor: float = minf(viewport_size.x / REFERENCE_WIDTH,
            viewport_size.y / REFERENCE_HEIGHT)
    _frame.scale = Vector2(scale_factor, scale_factor)
    _frame.position = Vector2(
            (viewport_size.x - REFERENCE_WIDTH * scale_factor) * 0.5, 0.0)


# ---------------------------------------------------------------- texture load

func _load_textures() -> void:
    var names: Array[String] = [
        "BL_HUD_Inkbar.png",
        "BL_HUD_Lifebar_left.png",
        "BL_HUD_Lifebar_right.png",
        "BL_HUD_Lifebar_Orange_left.png",
        "BL_HUD_Lifebar_Orange_right.png",
        "BL_HUD_ChiBar_left.png",
        "BL_HUD_ChiBar_right.png",
        "BL_HUD_Round_red_left.png",
        "BL_HUD_Round_yellow_left.png",
    ]
    for name: String in names:
        var texture: Texture2D = _try_load_hud_texture(name)
        if texture != null:
            _textures[name] = texture
    _assets_bottom_up = _inkbar_requires_flip(_textures.get("BL_HUD_Inkbar.png"))


func _hud_texture_roots() -> Array[String]:
    var roots: Array[String] = []
    var override: String = OS.get_environment(HUD_TEXTURE_ROOT_ENV)
    if not override.is_empty():
        roots.append(override)
    roots.append(OS.get_executable_path().get_base_dir().path_join("ui/hud"))
    roots.append("res://ui/hud")
    var local_app_data: String = OS.get_environment("LOCALAPPDATA")
    if not local_app_data.is_empty():
        roots.append(local_app_data.path_join(
            "BruceLee-PC-Port/local-assets/gui/images/hud"))
    return roots


func _try_load_hud_texture(filename: String) -> Texture2D:
    var candidates: Array[String] = [filename, filename.to_lower()]
    for root: String in _hud_texture_roots():
        for candidate: String in candidates:
            var path: String = root.path_join(candidate)
            if not FileAccess.file_exists(path):
                continue
            var image: Image = Image.new()
            if image.load(path) == OK:
                return ImageTexture.create_from_image(image)
    return null


# ------------------------------------------------------------------- public API

func set_health(player_health: float, enemy_health: float) -> void:
    player_bar.value = clampf(player_health, 0.0, 100.0)
    opponent_bar.value = clampf(enemy_health, 0.0, 100.0)
    _life_target[0] = player_bar.value
    _life_target[1] = opponent_bar.value


func set_round(round_number: int, player_wins: int, computer_wins: int,
        training: bool = false) -> void:
    _wins[0] = maxi(player_wins, 0)
    _wins[1] = maxi(computer_wins, 0)
    round_label.text = (
        "TRAINING" if training
        else "ROUND %d  ·  %d — %d" % [round_number, player_wins, computer_wins]
    )
    _refresh_dots()


func set_time(seconds_left: int, active: bool = true) -> void:
    if timer_label == null:
        return
    if not active:
        timer_label.text = "--"
        _timer_text = -2
        return
    var clamped: int = clampi(seconds_left, 0, 99)
    if clamped == _timer_text:
        return
    _timer_text = clamped
    timer_label.text = "%02d" % clamped


func set_rage(value: float) -> void:
    rage_bar.value = clampf(value, 0.0, 100.0)
    _chi_target[0] = rage_bar.value


## Opponent chi is not tracked by the port yet; kept so the right-hand chi bar
## can be driven when the opponent gains a chi resource.
func set_opponent_rage(value: float) -> void:
    _chi_target[1] = clampf(value, 0.0, 100.0)


func show_message(value: String) -> void:
    center_message.text = value


func set_context_hint(value: String) -> void:
    context_hint.text = value

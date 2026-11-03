extends CanvasLayer
class_name PortHUD
## Original HUD reconstruction.
##
## Layout recovered from krm::CBruceLeeHUD::Render (0x1959e0, decompiled at
## 0x1a59e0 in the Ghidra listing, image base 0x10000), LoadSprites (0x194538),
## Update (0x193d98) and the packaged art itself.
##
## Recovered 480x320 reference frame (Render centres it with
## (displayWidth - 480) * 0.5):
##   Inkbar            512x64 art drawn at (0, 0), clipped to the 480 wide frame
##   life bar row      y = 22
##   chi bar row       y = 32
##   left life bar     right end fixed, source window x = 15 + (1 - f) * 194,
##                     width 194 * f, y = 22
##   right life bar    left end fixed, source window x = 269, width 194 * f,
##                     y = 22
##   left chi bar      x = 13, three baked segments in one 101 px window
##   right chi bar     right end fixed at 465, x = 465 - 101 * g
##   round wins        y = 32, 16x8 yellow/red dots, left player at
##                     x = 185 - 20 * i, right player at x = 280 + 20 * i
##   round clock       "%02d", centred on (242, 26)
##   names             BLE_Name_*.png (candara16 glyphs baked at 4x) drawn at
##                     (10, 0) for the left fighter and (470 - advance, 0) for
##                     the right one, scaled back down 4x
##
## Exact source rectangles (measured from the packaged PNGs, verified against
## the Inkbar troughs; see evidence/png_measure.json and geometry_check.json):
##   life bars         Rect2(31, 0, 194, 8)   -> trough red rows 22..28
##   chi bars          Rect2(14|13, 1, 101, 6) -> trough blue rows 33..36
##
## Bar values are eased exactly like CBruceLeeHUD::Update: the filled bar moves
## at 50 units/s, the orange damage ghost holds for 1000 ms then drains at
## 25 units/s, chi moves at 50 units/s. The reference frame is scaled to fit the
## viewport so the HUD stays readable at 1280x720 and at 868x517.
##
## Text that the original HUD never draws (CHI, ROUND, centre message, footer,
## context hint) is kept only as a hidden data API for the regression tests; it
## is not rendered.

const REFERENCE_WIDTH := 480.0
const REFERENCE_HEIGHT := 320.0

# Row / anchor constants from CBruceLeeHUD::Render plus the packaged art's
# opaque spans.
const LIFE_ROW_Y := 22.0
const CHI_ROW_Y := 32.0
const LIFE_SRC_RECT := Rect2(31.0, 0.0, 194.0, 8.0)
const LIFE_TROUGH_WIDTH := 194.0
const LIFE_LEFT_RIGHT_EDGE := 15.0 + LIFE_TROUGH_WIDTH   # trough x 15..208
const LIFE_RIGHT_LEFT_EDGE := 269.0                      # trough x 269..462
const LIFE_DST_HEIGHT := 8.0
const CHI_LEFT_SRC_RECT := Rect2(14.0, 1.0, 101.0, 6.0)
const CHI_RIGHT_SRC_RECT := Rect2(13.0, 1.0, 101.0, 6.0)
const CHI_LEFT_X := 13.0            # Render 0x41500000
const CHI_RIGHT_END := 465.0        # right end of the trough (464 inclusive)
const CHI_DST_HEIGHT := 6.0
const DOT_ROW_Y := 32.0
const DOT_STEP := 20.0
const DOT_LEFT_X := 185.0
const DOT_RIGHT_X := 280.0
const DOT_SIZE := Vector2(16.0, 8.0)
const TIMER_CENTER := Vector2(242.0, 26.0)
const INKBAR_HEIGHT := 64.0
const INKBAR_ART_WIDTH := 512.0

# Name layout: advance width of the upper-cased name in candara16 and the
# bearing of the ink inside the generated texture (name_layout.json). The PNGs
# are the generated textures at 4x, so the draw size is png_size / 4.
const NAME_RIGHT_EDGE := 470.0
const NAME_TOP := 0.0
const NAME_TEXTURE_SCALE := 0.25

const NAME_LAYOUT := {
    "BRUCE LEE": {"file": "BLE_Name_brucelee.png", "advance": 74.0, "bearing": Vector2(1, 0)},
    "BRICK DAVIS": {"file": "BLE_Name_brickdavis.png", "advance": 91.0, "bearing": Vector2(1, 0)},
    "SMALL BOY": {"file": "BLE_Name_smallboy.png", "advance": 85.0, "bearing": Vector2(0, 0)},
    "JOHNSON": {"file": "BLE_Name_johnson.png", "advance": 69.0, "bearing": Vector2(-1, 0)},
    "KEN GODALL": {"file": "BLE_Name_kengodall.png", "advance": 92.0, "bearing": Vector2(1, 0)},
    "CHIEF": {"file": "BLE_Name_chief.png", "advance": 39.0, "bearing": Vector2(1, 0)},
    "THE MASTER": {"file": "BLE_Name_themaster.png", "advance": 93.0, "bearing": Vector2(1, 0)},
    "LO MING": {"file": "BLE_Name_loming.png", "advance": 62.0, "bearing": Vector2(1, 0)},
    "SHEN LO": {"file": "BLE_Name_shenlo.png", "advance": 60.0, "bearing": Vector2(0, 0)},
    "SIN FU": {"file": "BLE_Name_sinfu.png", "advance": 45.0, "bearing": Vector2(0, 0)},
}

# Alternate spellings the menus/tests may pass.
const NAME_ALIASES := {
    "BRUCE": "BRUCE LEE",
    "BRICK": "BRICK DAVIS",
    "MASTER": "THE MASTER",
    "THE CHIEF": "CHIEF",
    "KEN": "KEN GODALL",
    "SMALLBOY": "SMALL BOY",
    "LOMING": "LO MING",
    "SHENLO": "SHEN LO",
    "SINFU": "SIN FU",
    "BRUCELEE": "BRUCE LEE",
    "BRICKDAVIS": "BRICK DAVIS",
    "KENGODALL": "KEN GODALL",
}

# CBruceLeeHUD::Update easing values.
const LIFE_RATE := 50.0
const GHOST_HOLD := 1.0
const GHOST_RATE := 25.0
const CHI_RATE := 50.0

const HUD_TEXTURE_ROOT_ENV := "BRUCELEE_HUD_TEXTURE_ROOT"
const HUD_NAME_ROOT_ENV := "BRUCELEE_HUD_NAME_ROOT"

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
var _name_textures: Dictionary = {}
var _assets_bottom_up: bool = false

var _frame: Control
var _inkbar: TextureRect
var _life_rects: Array[TextureRect] = []
var _ghost_rects: Array[TextureRect] = []
var _chi_rects: Array[TextureRect] = []
var _dot_rects: Array[TextureRect] = []
var _bar_atlases: Dictionary = {}
var _name_sprites: Array[TextureRect] = []

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

    # Round clock: "%02d" centred on (242, 26). This is the one text element
    # the original HUD draws; it stays above the art so it is legible when a
    # bar reaches the centre gap.
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

    # Fighter names: the original renders the player name at (10, 0) and the
    # opponent at (470 - advance, 0) with the candara16 glyphs. The packaged
    # BLE_Name_*.png are those glyphs at 4x.
    _name_sprites.append(_make_name_sprite())
    _name_sprites.append(_make_name_sprite())
    for sprite: TextureRect in _name_sprites:
        _frame.add_child(sprite)

    # Round counter must stay inside a box container (validate_round_flow).
    # It is a data-only node: the original HUD has no round text label.
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
    round_label.visible = false
    round_box.add_child(round_label)

    # Non-original overlays: kept for the tests' text contract, never drawn.
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
    hint.visible = false
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
    footer.visible = false
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
    context_hint.visible = false
    screen.add_child(context_hint)
    center_message = hint

    _refresh_bars()


func _make_name_sprite() -> TextureRect:
    var rect: TextureRect = TextureRect.new()
    rect.size = Vector2.ZERO
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_SCALE
    rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    rect.visible = false
    return rect


func _make_sprite(filename: String, size_value: Vector2) -> TextureRect:
    var rect: TextureRect = TextureRect.new()
    rect.texture = _textures.get(filename)
    rect.size = size_value
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_SCALE
    rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return rect


## The packaged ui/hud PNGs are stored bottom-up: file row 41 of the Inkbar
## carries the red trough that Render expects at screen row 22. Detect that
## orientation from the source pixels and flip the loaded images once, so every
## AtlasTexture region below is addressed in top-down Render coordinates.
func _inkbar_requires_flip(image: Image) -> bool:
    if image == null:
        return false
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
        atlas.region = Rect2(0.0, 0.0, source.get_width(), LIFE_DST_HEIGHT)
        atlas.filter_clip = true
        rect.texture = atlas
        _bar_atlases[rect] = atlas
    rect.size = Vector2(1.0, LIFE_DST_HEIGHT)
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
        # Left fighter: the inner (right) end stays on the trough's inner end
        # and the visible source window shrinks towards it as health drops.
        _place_source(_life_rects[0], LIFE_SRC_RECT, LIFE_LEFT_RIGHT_EDGE,
                LIFE_ROW_Y, fraction, true, LIFE_DST_HEIGHT)
        _place_source(_ghost_rects[0], LIFE_SRC_RECT, LIFE_LEFT_RIGHT_EDGE,
                LIFE_ROW_Y, ghost_fraction, true, LIFE_DST_HEIGHT)
    else:
        # Right fighter: the inner (left) end stays on the trough and the outer
        # end recedes.
        _place_source(_life_rects[1], LIFE_SRC_RECT, LIFE_RIGHT_LEFT_EDGE,
                LIFE_ROW_Y, fraction, false, LIFE_DST_HEIGHT)
        _place_source(_ghost_rects[1], LIFE_SRC_RECT, LIFE_RIGHT_LEFT_EDGE,
                LIFE_ROW_Y, ghost_fraction, false, LIFE_DST_HEIGHT)


func _apply_chi_bar(side: int, value: float) -> void:
    var fraction: float = clampf(value / 100.0, 0.0, 1.0)
    if side == 0:
        # Left fighter: fixed x = 13; the 101 px window holds the three baked
        # segments and grows from the left.
        _place_source(_chi_rects[0], CHI_LEFT_SRC_RECT, CHI_LEFT_X,
                CHI_ROW_Y, fraction, false, CHI_DST_HEIGHT)
    else:
        # Right fighter: right end fixed at 465, x = 465 - 101 * fraction.
        _place_source(_chi_rects[1], CHI_RIGHT_SRC_RECT, CHI_RIGHT_END,
                CHI_ROW_Y, fraction, true, CHI_DST_HEIGHT)


## Draw `src` (a rectangle in the flipped, top-down texture) at `anchor`.
## `hug_right` keeps the destination's right edge on `anchor`; otherwise the
## left edge stays on it. Only the fraction of the source window is shown, so
## the baked 3-segment chi gaps and the slanted life ends survive.
func _place_source(rect: TextureRect, src: Rect2, anchor: float, dst_y: float,
        fraction: float, hug_right: bool, dst_height: float) -> void:
    var visible_width: float = src.size.x * clampf(fraction, 0.0, 1.0)
    if visible_width <= 0.5:
        rect.visible = false
        return
    rect.visible = true
    rect.size = Vector2(visible_width, dst_height)
    var atlas: AtlasTexture = _bar_atlases.get(rect)
    if hug_right:
        rect.position = Vector2(anchor - visible_width, dst_y)
        if atlas != null:
            atlas.region = Rect2(src.position.x + src.size.x - visible_width,
                    src.position.y, visible_width, src.size.y)
    else:
        rect.position = Vector2(anchor, dst_y)
        if atlas != null:
            atlas.region = Rect2(src.position.x, src.position.y,
                    visible_width, src.size.y)


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


# ---------------------------------------------------------------- names

func _resolve_name(value: String) -> String:
    var key: String = value.strip_edges().to_upper()
    if NAME_LAYOUT.has(key):
        return key
    if NAME_ALIASES.has(key):
        return NAME_ALIASES[key]
    # "BRUCE LEE A/B/C/D" and similar skin suffixes.
    var shortened: String = key
    var cut: int = shortened.rfind(" ")
    while cut > 0:
        shortened = shortened.substr(0, cut)
        if NAME_LAYOUT.has(shortened):
            return shortened
        if NAME_ALIASES.has(shortened):
            return NAME_ALIASES[shortened]
        cut = shortened.rfind(" ")
    return ""


func set_fighter_name(side: int, value: String) -> void:
    if side < 0 or side >= _name_sprites.size():
        return
    var sprite: TextureRect = _name_sprites[side]
    var key: String = _resolve_name(value)
    if not NAME_LAYOUT.has(key) or not _name_textures.has(key):
        sprite.visible = false
        return
    var entry: Dictionary = NAME_LAYOUT[key]
    var texture: Texture2D = _name_textures[key]
    var draw_size: Vector2 = Vector2(texture.get_width(), texture.get_height()) \
            * NAME_TEXTURE_SCALE
    var pen_x: float = 10.0 if side == 0 else NAME_RIGHT_EDGE - float(entry["advance"])
    var bearing: Vector2 = entry["bearing"]
    sprite.texture = texture
    sprite.size = draw_size
    sprite.position = Vector2(pen_x + bearing.x, NAME_TOP + bearing.y)
    sprite.visible = true


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
    var images: Dictionary = {}
    for name: String in names:
        var image: Image = _load_hud_image(name)
        if image != null:
            images[name] = image
    var inkbar: Image = images.get("BL_HUD_Inkbar.png")
    _assets_bottom_up = _inkbar_requires_flip(inkbar)
    for name: String in images:
        var image: Image = images[name]
        if _assets_bottom_up:
            image.flip_y()
        _textures[name] = ImageTexture.create_from_image(image)
    for key: String in NAME_LAYOUT:
        var file: String = NAME_LAYOUT[key]["file"]
        var image: Image = _load_name_image(file)
        if image == null:
            continue
        if image.get_width() % 4 != 0 or image.get_height() % 4 != 0:
            continue
        image.convert(Image.FORMAT_RGBA8)
        _name_textures[key] = ImageTexture.create_from_image(image)


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


func _name_texture_roots() -> Array[String]:
    var roots: Array[String] = []
    var override: String = OS.get_environment(HUD_NAME_ROOT_ENV)
    if not override.is_empty():
        roots.append(override)
    var hud_override: String = OS.get_environment(HUD_TEXTURE_ROOT_ENV)
    if not hud_override.is_empty():
        roots.append(hud_override.path_join("..").path_join("hud_names"))
    roots.append(OS.get_executable_path().get_base_dir().path_join("ui/hud_names"))
    roots.append("res://ui/hud_names")
    var local_app_data: String = OS.get_environment("LOCALAPPDATA")
    if not local_app_data.is_empty():
        roots.append(local_app_data.path_join(
            "BruceLee-PC-Port/local-assets/gui/images/hud_names"))
    return roots


func _load_hud_image(filename: String) -> Image:
    return _load_image_from(filename, _hud_texture_roots())


func _load_name_image(filename: String) -> Image:
    return _load_image_from(filename, _name_texture_roots())


func _load_image_from(filename: String, roots: Array[String]) -> Image:
    var candidates: Array[String] = [filename, filename.to_lower()]
    for root: String in roots:
        for candidate: String in candidates:
            var path: String = root.path_join(candidate)
            if not FileAccess.file_exists(path):
                continue
            var image: Image = Image.new()
            if image.load(path) == OK:
                return image
    return null


# ------------------------------------------------------------------- public API

func set_health(player_health: float, enemy_health: float) -> void:
    player_bar.value = clampf(player_health, 0.0, 100.0)
    opponent_bar.value = clampf(enemy_health, 0.0, 100.0)
    _life_target[0] = player_bar.value
    _life_target[1] = opponent_bar.value


func set_fighter_names(player_name: String, opponent_name: String) -> void:
    set_fighter_name(0, player_name)
    set_fighter_name(1, opponent_name)


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


## Drive the original right-hand chi sprite from the opponent's rage value.
func set_opponent_rage(value: float) -> void:
    _chi_target[1] = clampf(value, 0.0, 100.0)


func show_message(value: String) -> void:
    center_message.text = value


func set_context_hint(value: String) -> void:
    context_hint.text = value

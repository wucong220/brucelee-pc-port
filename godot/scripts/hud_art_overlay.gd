extends Control
class_name HudArtOverlay
## Recovered original UI art, rendered ONLY when BRUCELEE_HUD_ART is set.
##
## Every rectangle below is copied verbatim from a decoded .ui layout in
## data.zpak (`assets/layout_selectfighter.json`, `assets/layout_fightpreview.json`)
## and every sprite is a decoded .tex (see assets/ui_art/manifest.json).  No
## coordinate or image is invented.
##
## Modes
##   show_hud_plate()                      in-fight HUD backdrop/frame, round +
##                                         time panel and life/chi bar frames,
##                                         composited from the 9 HUD sprites.
##   show_select_fighter(index, unlocked)  selectfighter.ui icon dock + name.
##   show_vs_preview(left_key, right)      fightpreview.ui versus screen.
##
## The widget lives in a 480x320 reference frame (the original canvas).  It is
## scaled uniformly to the viewport, exactly like the in-fight HUD.

const REF_W := 480.0
const REF_H := 320.0

# --- in-fight HUD (from CBruceLeeHUD::Render, matching godot/scripts/hud.gd) ---
const INKBAR_SIZE := Vector2(512.0, 64.0)
const LIFE_Y := 22.0
const LIFE_SRC := Rect2(31.0, 0.0, 194.0, 8.0)
const LIFE_LEFT_X := 15.0
const LIFE_RIGHT_X := 269.0
const CHI_Y := 32.0
const CHI_LEFT_SRC := Rect2(14.0, 1.0, 101.0, 6.0)
const CHI_RIGHT_SRC := Rect2(13.0, 1.0, 101.0, 6.0)
const CHI_LEFT_X := 13.0
const CHI_RIGHT_X := 364.0
const DOT_STEP := 20.0
const DOT_LEFT_X := 185.0
const DOT_RIGHT_X := 280.0
const DOT_SIZE := Vector2(16.0, 8.0)
const TIMER_CENTER := Vector2(242.0, 26.0)

# --- selectfighter.ui (decoded) ---
const SEL_DOCK := Rect2(96.0, 180.0, 320.0, 70.0)
const SEL_OPTION_W := 100.0
const SEL_OPTION_H := 70.0
const SEL_SEP := -16.0
const SEL_NAME := Rect2(100.0, 155.0, 280.0, 20.0)

# --- fightpreview.ui (decoded) ---
const VS_BG := Rect2(0.0, 0.0, 480.0, 320.0)
const VS_LEFT_INK := Rect2(0.0, 32.0, 256.0, 256.0)
const VS_RIGHT_INK := Rect2(224.0, 32.0, 256.0, 256.0)
const VS_TEXT := Rect2(176.0, 80.0, 128.0, 128.0)
const VS_P0 := Rect2(-80.0, 0.0, 384.0, 384.0)
const VS_P1 := Rect2(176.0, 0.0, 384.0, 384.0)
const VS_NAME0 := Rect2(0.0, 112.0, 200.0, 64.0)
const VS_NAME1 := Rect2(280.0, 112.0, 200.0, 64.0)

# The dock item order is the `items` array of selectfighter.ui; the source
# strings are gui/images/mini/<name>.tex in that exact order.
const SELECT_ITEMS := [
    "bl_brucelee_jacket_icon", "bl_brucelee_base_icon", "bl_brucelee_tank_icon",
    "bl_brucelee_kimono_icon", "bl_shenlo_icon", "bl_themaster_icon",
    "bl_smallboy_icon", "bl_sinfu_icon", "bl_thechief01_icon",
    "bl_thechief02_icon", "bl_kengodall_icon", "bl_brickdavis_icon",
    "bl_johnson_icon", "bl_loming01_icon", "bl_loming02_icon",
]
const SELECT_LOCKED := "bl_fighterlocked_icon"

# Fighter key -> versus portrait basename (left player uses _A, right uses _B).
const VS_PORTRAITS := {
    "BRUCE LEE": "bl_versus_brucelee_03",
    "BRICK DAVIS": "bl_versus_brickdavis",
    "SMALL BOY": "bl_versus_smallboy",
    "JOHNSON": "bl_versus_johnson",
    "KEN GODALL": "bl_versus_kengoodall",
    "CHIEF": "bl_versus_thechief",
    "THE CHIEF 2": "bl_versus_thechief_02",
    "THE MASTER": "bl_versus_themaster",
    "LO MING": "bl_versus_loming",
    "LO MING 2": "bl_versus_loming_02",
    "SHEN LO": "bl_versus_shenlo",
    "SIN FU": "bl_versus_sinfu",
}

const ART_ROOT_ENV := "BRUCELEE_HUD_ART_ROOT"

var _frame: Control
var _border_layer: BorderRect
var _hud_textures: Dictionary = {}
var _art_textures: Dictionary = {}
var _assets_bottom_up := false
var _mode := ""


class BorderRect extends Control:
    var border_rect := Rect2()
    var border_color := Color(1, 1, 0, 0.9)
    var border_width := 2.0

    func _draw() -> void:
        if border_rect.size.x > 0.0 and border_rect.size.y > 0.0:
            draw_rect(border_rect, border_color, false, border_width)


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _frame = Control.new()
    _frame.size = Vector2(REF_W, REF_H)
    _frame.clip_contents = true
    _frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_frame)
    _border_layer = BorderRect.new()
    _border_layer.size = Vector2(REF_W, REF_H)
    _border_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _frame.add_child(_border_layer)
    _load_assets()
    _apply_layout()
    if not get_viewport().size_changed.is_connected(_apply_layout):
        get_viewport().size_changed.connect(_apply_layout)


func _apply_layout() -> void:
    if _frame == null:
        return
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return
    var scale_factor: float = minf(viewport_size.x / REF_W, viewport_size.y / REF_H)
    _frame.scale = Vector2(scale_factor, scale_factor)
    _frame.position = Vector2((viewport_size.x - REF_W * scale_factor) * 0.5, 0.0)


# ------------------------------------------------------------------ assets

func _art_roots() -> Array[String]:
    var roots: Array[String] = []
    var override: String = OS.get_environment(ART_ROOT_ENV)
    if not override.is_empty():
        roots.append(override)
    roots.append(OS.get_executable_path().get_base_dir().path_join("ui_art"))
    roots.append("res://ui_art")
    var local_app_data: String = OS.get_environment("LOCALAPPDATA")
    if not local_app_data.is_empty():
        roots.append(local_app_data.path_join(
            "BruceLee-PC-Port/local-assets/gui/images/ui_art"))
    return roots


func _load_asset(sub: String, stem: String) -> Image:
    for root: String in _art_roots():
        for ext: String in [".png", ".PNG"]:
            var path: String = root.path_join(sub).path_join(stem + ext)
            if not FileAccess.file_exists(path):
                continue
            var image: Image = Image.new()
            if image.load(path) == OK:
                return image
    return null


func _inkbar_requires_flip(image: Image) -> bool:
    if image == null or image.get_width() < 64 or image.get_height() < 40:
        return false
    var life_red := 0
    var chi_blue := 0
    for y: int in range(22, 29):
        for x: int in range(0, image.get_width(), 4):
            var c: Color = image.get_pixel(x, y)
            if c.a > 0.8 and c.r > 0.32 and c.r > c.g * 2.0:
                life_red += 1
    for y: int in range(33, 37):
        for x: int in range(0, image.get_width(), 4):
            var c: Color = image.get_pixel(x, y)
            if c.a > 0.8 and c.b > 0.3 and c.b > c.r * 1.5:
                chi_blue += 1
    return life_red == 0 and chi_blue == 0


func _load_assets() -> void:
    var hud_names := [
        "bl_hud_inkbar", "bl_hud_lifebar_left", "bl_hud_lifebar_right",
        "bl_hud_lifebar_orange_left", "bl_hud_lifebar_orange_right",
        "bl_hud_chibar_left", "bl_hud_chibar_right", "bl_hud_round_red_left",
        "bl_hud_round_yellow_left",
    ]
    var images: Dictionary = {}
    for stem: String in hud_names:
        var image: Image = _load_asset("hud", stem)
        if image != null:
            image.convert(Image.FORMAT_RGBA8)
            images[stem] = image
    var ink: Image = images.get("bl_hud_inkbar")
    _assets_bottom_up = _inkbar_requires_flip(ink)
    for stem: String in images:
        var image: Image = images[stem]
        if _assets_bottom_up:
            image.flip_y()
        _hud_textures[stem] = ImageTexture.create_from_image(image)


func _art_texture(sub: String, stem: String) -> Texture2D:
    var key: String = sub + "/" + stem
    if _art_textures.has(key):
        return _art_textures[key]
    var image: Image = _load_asset(sub, stem)
    if image == null:
        _art_textures[key] = null
        return null
    image.convert(Image.FORMAT_RGBA8)
    var texture: ImageTexture = ImageTexture.create_from_image(image)
    _art_textures[key] = texture
    return texture


# ------------------------------------------------------------------ sprites

func _sprite(texture: Texture2D, rect: Rect2, linear: bool = false) -> TextureRect:
    var node: TextureRect = TextureRect.new()
    node.texture = texture
    node.position = rect.position
    node.size = rect.size
    node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    node.stretch_mode = TextureRect.STRETCH_SCALE
    node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if linear else CanvasItem.TEXTURE_FILTER_NEAREST
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return node


func _region_sprite(texture: Texture2D, region: Rect2, dst: Rect2) -> TextureRect:
    var node: TextureRect = TextureRect.new()
    if texture != null:
        var atlas: AtlasTexture = AtlasTexture.new()
        atlas.atlas = texture
        atlas.region = region
        atlas.filter_clip = true
        node.texture = atlas
    node.position = dst.position
    node.size = dst.size
    node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    node.stretch_mode = TextureRect.STRETCH_SCALE
    node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return node


func _label(text: String, rect: Rect2, font_size: int, color: Color) -> Label:
    var node: Label = Label.new()
    node.text = text
    node.position = rect.position
    node.size = rect.size
    node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    node.add_theme_font_size_override("font_size", font_size)
    node.add_theme_color_override("font_color", color)
    node.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.0, 0.95))
    node.add_theme_constant_override("outline_size", 4)
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return node


func _clear() -> void:
    for child: Node in _frame.get_children():
        if child == _border_layer:
            continue
        child.queue_free()
    _border_layer.border_rect = Rect2()
    _border_layer.queue_redraw()


# ------------------------------------------------------------------ modes

func show_hud_plate() -> void:
    _mode = "hud_plate"
    _clear()
    var ink: Texture2D = _hud_textures.get("bl_hud_inkbar")
    _frame.add_child(_sprite(ink, Rect2(0.0, 0.0, INKBAR_SIZE.x, INKBAR_SIZE.y)))
    _add_bar("bl_hud_lifebar_orange_left", LIFE_SRC, LIFE_LEFT_X, LIFE_Y, 1.0, 194.0, 8.0)
    _add_bar("bl_hud_lifebar_orange_right", LIFE_SRC, LIFE_RIGHT_X, LIFE_Y, 1.0, 194.0, 8.0)
    _add_bar("bl_hud_lifebar_left", LIFE_SRC, LIFE_LEFT_X, LIFE_Y, 1.0, 194.0, 8.0)
    _add_bar("bl_hud_lifebar_right", LIFE_SRC, LIFE_RIGHT_X, LIFE_Y, 1.0, 194.0, 8.0)
    _add_bar("bl_hud_chibar_left", CHI_LEFT_SRC, CHI_LEFT_X, CHI_Y, 1.0, 101.0, 6.0)
    _add_bar("bl_hud_chibar_right", CHI_RIGHT_SRC, CHI_RIGHT_X, CHI_Y, 1.0, 101.0, 6.0)
    var red: Texture2D = _hud_textures.get("bl_hud_round_red_left")
    for side: int in range(2):
        for index: int in range(2):
            var x: float = DOT_LEFT_X - DOT_STEP * index if side == 0 else DOT_RIGHT_X + DOT_STEP * index
            _frame.add_child(_sprite(red, Rect2(x, 32.0, DOT_SIZE.x, DOT_SIZE.y)))
    _frame.add_child(_label("30", Rect2(TIMER_CENTER.x - 60.0, TIMER_CENTER.y - 16.0, 120.0, 32.0),
            22, Color(1.0, 0.96, 0.86)))
    _border_layer.move_to_front()


func _add_bar(stem: String, src: Rect2, x: float, y: float, fraction: float,
        width: float, height: float) -> void:
    var texture: Texture2D = _hud_textures.get(stem)
    var visible_w: float = width * clampf(fraction, 0.0, 1.0)
    var region := Rect2(src.position.x, src.position.y, visible_w, src.size.y)
    _frame.add_child(_region_sprite(texture, region, Rect2(x, y, visible_w, height)))


func show_select_fighter(selected_index: int, unlocked: int, name_hint: String = "") -> void:
    _mode = "select_fighter"
    _clear()
    var dock: Control = Control.new()
    dock.position = SEL_DOCK.position
    dock.size = SEL_DOCK.size
    dock.clip_contents = true
    dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _frame.add_child(dock)
    var step: float = SEL_OPTION_W + SEL_SEP
    var count: int = SELECT_ITEMS.size()
    var sel: int = clampi(selected_index, 0, count - 1)
    var scroll: float = SEL_DOCK.size.x * 0.5 - (float(sel) * step + SEL_OPTION_W * 0.5)
    var locked: Texture2D = _art_texture("mini", SELECT_LOCKED)
    for i: int in range(count):
        var tex: Texture2D = locked if i >= unlocked else _art_texture("mini", SELECT_ITEMS[i])
        if tex == null:
            continue
        var rect := Rect2(float(i) * step + scroll, 0.0, SEL_OPTION_W, SEL_OPTION_H)
        dock.add_child(_sprite(tex, rect, true))
    _border_layer.border_rect = Rect2(SEL_DOCK.position.x + float(sel) * step + scroll, SEL_DOCK.position.y,
            SEL_OPTION_W, SEL_OPTION_H)
    _border_layer.border_color = Color(1.0, 0.85, 0.1, 0.95)
    _border_layer.queue_redraw()
    _border_layer.move_to_front()
    var text: String = name_hint if not name_hint.is_empty() else SELECT_ITEMS[sel]
    _frame.add_child(_label(text.to_upper(), SEL_NAME, 15, Color(1.0, 1.0, 0.0)))


func show_vs_preview(left_key: String, right_key: String) -> void:
    _mode = "vs_preview"
    _clear()
    var bg: Texture2D = _art_texture("versus", "bl_versusscreen_background")
    _frame.add_child(_sprite(bg, VS_BG, true))
    _frame.add_child(_sprite(_art_texture("versus", "bl_versusscreen_stains_left"), VS_LEFT_INK, true))
    _frame.add_child(_sprite(_art_texture("versus", "bl_versusscreen_stains_right"), VS_RIGHT_INK, true))
    var left_base: String = VS_PORTRAITS.get(left_key.to_upper(), "bl_versus_brucelee_03")
    var right_base: String = VS_PORTRAITS.get(right_key.to_upper(), "bl_versus_brickdavis")
    _frame.add_child(_sprite(_art_texture("versus", left_base + "_a"), VS_P0, true))
    _frame.add_child(_sprite(_art_texture("versus", right_base + "_b"), VS_P1, true))
    _frame.add_child(_sprite(_art_texture("versus", "bl_versusscreen_vstext"), VS_TEXT, true))
    _frame.add_child(_label(left_key.to_upper(), VS_NAME0, 22, Color(1.0, 1.0, 0.0)))
    _frame.add_child(_label(right_key.to_upper(), VS_NAME1, 22, Color(1.0, 1.0, 0.0)))


func clear_mode() -> void:
    _mode = ""
    _clear()


func current_mode() -> String:
    return _mode

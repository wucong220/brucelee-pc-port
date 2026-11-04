extends CanvasLayer
class_name PortPrototypeMenu

## PC-only prototype menu. This does not claim parity with the Android game's UI.

signal command_requested(command: String)
## Emitted from _refresh_selection(), i.e. on every visible selection change and
## whenever a menu screen opens. The opt-in HUD-art integration uses it to drive
## the recovered selectfighter.ui dock from the real opponent selection; with
## BRUCELEE_HUD_ART unset no listener does anything.
signal selection_changed(state: String, index: int, command: String)

const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")
const PrototypeControls = preload("res://scripts/prototype_controls.gd")
## Canonical map of the nine recovered menu SFX and the original trigger roles.
const MenuSfxMap = preload("res://scripts/menu_sfx_map.gd")
## Recovered .lang localization for the shared main/pause/scene/opponent menus.
const Lang = preload("res://scripts/menu_lang.gd")
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
    "GROUND TRAINING", "TRAINING", "MOVE GALLERY",
    "TEMPLE YARD A", "TEMPLE YARD B", "SCENES", "OPPONENTS", "QUIT GAME",
]
const PAUSE_COMMANDS: Array[String] = ["resume", "restart", "main_menu", "quit"]
const PAUSE_LABELS: Array[String] = [
    "RESUME",
    "RESTART MATCH",
    "MAIN MENU",
    "QUIT GAME",
]
## Opt-in Records/Achievements row. It exists ONLY while BRUCELEE_PROGRESS=1 --
## the same gate main.gd uses to create the progress service. The const baseline
## above is untouched, so the flag-off menu and every index-based binding stay
## exactly as they were; RECORDS is inserted just before QUIT GAME and main.gd
## opens the screen (the row is a plain command, never a submenu of this script).
const ENV_PROGRESS: String = "BRUCELEE_PROGRESS"
const RECORDS_COMMAND: String = "records"
const RECORDS_LABEL: String = "RECORDS"
## Opt-in Style Editor row. It exists ONLY while BRUCELEE_STYLE_EDITOR=1 and is
## inserted just before QUIT GAME (after RECORDS when that row is also on), so
## the flag-off command list and every index-based binding stay identical.
const ENV_STYLE_EDITOR: String = "BRUCELEE_STYLE_EDITOR"
const STYLE_EDITOR_COMMAND: String = "style_editor"
const STYLE_EDITOR_LABEL: String = "STYLE EDITOR"
## Opt-in recovered scene dock (BRUCELEE_SCENE_SELECT=1).  The scene submenu is
## then drawn from the decoded selectscenery.ui dock (10 icon cards in the
## recovered order, with the recovered icons and labels) instead of the text
## rows below.  The text rows stay the scene menu whenever the flag is off or
## the dock fails closed (missing layout, dock/list mismatch, missing icon), so
## no screen is ever half-drawn.  Confirming a card emits the same scene command
## the text rows emit, so the scene switch itself stays in main.gd.
const ENV_SCENE_SELECT: String = "BRUCELEE_SCENE_SELECT"
const SceneSelectDock = preload("res://scripts/scene_select_dock.gd")
const SCENE_DOCK_UNAVAILABLE: String = "SCENE DOCK UNAVAILABLE - TEXT MENU"
## Recovered scenery-unlock gate (scene_unlock_gate.gd).  It is ON unless
## BRUCELEE_SCENE_UNLOCK is exactly "0"; when on, the SCENES submenu -- both the
## text rows and the recovered dock -- reads the progress save and refuses the
## nine story-gated sceneries while their recovered unlock id is missing.  With
## no save (or an unreadable one, or a scenery id the recovered table cannot
## resolve) the gate stays closed.  The always-available row keeps its decoded
## `always_available` flag.  BRUCELEE_SCENE_UNLOCK=0 restores the pre-gating
## scene menu unchanged and exists for the regression checks.
const ENV_SCENE_UNLOCK: String = "BRUCELEE_SCENE_UNLOCK"
const SceneUnlockGate = preload("res://scripts/scene_unlock_gate.gd")
const SCENE_LOCKED: String = "SCENE LOCKED"
const SCENE_UNLOCK_UNAVAILABLE: String = "SCENE UNLOCK UNAVAILABLE"
## Recovered character-unlock gate (character_unlock_gate.gd).  It is ON unless
## BRUCELEE_CHARACTER_UNLOCK is exactly "0"; when on, the OPPONENTS submenu and
## the recovered selectfighter.ui dock both read the progress save and refuse a
## character while its recovered unlock id is missing.  With no save (or an
## unreadable one, or a character id the recovered table cannot resolve) the gate
## stays closed.  The two always-available characters keep their decoded flag.
## BRUCELEE_CHARACTER_UNLOCK=0 restores the pre-gating opponent menu unchanged and
## exists for the regression checks.
const ENV_CHARACTER_UNLOCK: String = "BRUCELEE_CHARACTER_UNLOCK"
const CharacterUnlockGate = preload("res://scripts/character_unlock_gate.gd")
const FIGHTER_LOCKED: String = "FIGHTER LOCKED"
const FIGHTER_UNLOCK_UNAVAILABLE: String = "FIGHTER UNLOCK UNAVAILABLE"

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
var page_flip_sfx: AudioStreamPlayer
## Only populated when the original data carries a deny cue; MenuSfxMap.DENIED is
## empty today, so this stays null (locked/denied actions are silent, not invented).
var denied_sfx: AudioStreamPlayer
var accept_sfx_error: String = ""
var menu_sfx_errors: Dictionary = {}
var last_sfx_played: String = ""
var last_accept_was_attack: bool = false
## Opt-in recovered scene dock; null unless BRUCELEE_SCENE_SELECT=1 and the
## decoded layout, the sceneries.list rows and every icon all loaded.
var scene_dock = null
var scene_dock_error: String = ""
## Recovered scenery-unlock gate shared by the text rows and the dock; null when
## BRUCELEE_SCENE_UNLOCK=0.  It is kept even when its data failed to load so the
## scene rows stay closed instead of silently becoming playable.
var scene_gate = null
var scene_gate_error: String = ""
## Recovered character-unlock gate shared by the text opponent rows and the
## recovered selectfighter dock; null when BRUCELEE_CHARACTER_UNLOCK=0.  It is
## kept even when its data failed to load so the opponent rows stay closed
## instead of silently becoming playable.
var fighter_gate = null
var fighter_gate_error: String = ""
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
    _build_scene_gate()
    _build_scene_dock()
    _build_fighter_gate()
    hide_menu()

## True unless BRUCELEE_SCENE_UNLOCK is exactly "0".  Static and side-effect
## free so a test can read the flag without a running tree.
static func scene_unlock_enabled() -> bool:
    return OS.get_environment(ENV_SCENE_UNLOCK) != "0"

## Builds the recovered scenery-unlock gate.  A gate whose decoded data or save
## cannot be read is still created with its error recorded: both the text rows
## and the dock then treat every gated scenery as locked (fail closed).
func _build_scene_gate() -> void:
    scene_gate = null
    scene_gate_error = ""
    if not scene_unlock_enabled():
        return
    var gate = SceneUnlockGate.new()
    scene_gate = gate
    if not gate.refresh():
        scene_gate_error = String(gate.error)
        push_error("prototype_menu: scene unlock gate failed closed: " + scene_gate_error)
        printerr("prototype_menu: scene unlock gate FAIL CLOSED: " + scene_gate_error)

## Re-reads the save when the scene submenu opens, so a progress save written
## during this session is honoured without restarting the game.
func _refresh_scene_gate() -> void:
    if scene_gate == null:
        return
    if not scene_gate.refresh():
        scene_gate_error = String(scene_gate.error)

## True only for the recovered scenery rows whose grant is unsatisfied.  BACK and
## every non-scenery command are never gated here.  If the gate could not build
## its ten rows at all, every recovered scene command is closed: without the
## decoded table the always_available exception cannot be proven either.
func scene_command_locked(command: String) -> bool:
    if scene_gate == null:
        return false
    if command == "scenes_back" or not SCENE_COMMANDS.has(command):
        return false
    if Array(scene_gate.rows).is_empty():
        return true
    return scene_gate.is_locked_command(command)

## True unless BRUCELEE_CHARACTER_UNLOCK is exactly "0".  Static and side-effect
## free so a test can read the flag without a running tree.
static func character_unlock_enabled() -> bool:
    return OS.get_environment(ENV_CHARACTER_UNLOCK) != "0"

## Builds the recovered character-unlock gate.  A gate whose decoded data or save
## cannot be read is still created with its error recorded: the text opponent rows
## and the dock then treat every gated character as locked (fail closed).
func _build_fighter_gate() -> void:
    fighter_gate = null
    fighter_gate_error = ""
    if not character_unlock_enabled():
        return
    var gate = CharacterUnlockGate.new()
    fighter_gate = gate
    if not gate.refresh():
        fighter_gate_error = String(gate.error)
        push_error("prototype_menu: character unlock gate failed closed: " + fighter_gate_error)
        printerr("prototype_menu: character unlock gate FAIL CLOSED: " + fighter_gate_error)

## Re-reads the save when the opponent submenu opens, so a progress save written
## during this session is honoured without restarting the game.
func _refresh_fighter_gate() -> void:
    if fighter_gate == null:
        return
    if not fighter_gate.refresh():
        fighter_gate_error = String(fighter_gate.error)

## True only for the nine OPPONENTS entries whose recovered character grant is
## unsatisfied.  BACK and non-opponent commands are never gated here.  If the
## gate could not build its fifteen rows at all, every opponent entry is closed:
## without the decoded tables the always-available exception cannot be proven.
func fighter_command_locked(command: String) -> bool:
    if fighter_gate == null:
        return false
    if command == "opponents_back" or not OPPONENT_COMMANDS.has(command):
        return false
    if Array(fighter_gate.rows).is_empty():
        return true
    return fighter_gate.is_locked_command(command)

## The text OPPONENTS labels with the port-chrome (LOCKED) suffix on closed rows.
## The recovered screen has no text variant of the locked state (the dock draws the
## decoded `lockedpicture` instead).
func opponent_labels() -> Array[String]:
    var out: Array[String] = OPPONENT_LABELS.duplicate()
    if fighter_gate != null:
        for index: int in range(out.size()):
            var command: String = OPPONENT_COMMANDS[index] if index < OPPONENT_COMMANDS.size() else ""
            if fighter_command_locked(command):
                out[index] = out[index] + CharacterUnlockGate.LOCKED_SUFFIX
    return out

## True only while the opt-in recovered scene dock is enabled. Static and
## side-effect free so a test can read the flag without a running tree.
static func scene_select_enabled() -> bool:
    return OS.get_environment(ENV_SCENE_SELECT) == "1"

## Creates the recovered scene dock when BRUCELEE_SCENE_SELECT=1.  A dock that
## cannot be built from the decoded layout/list/icons is dropped here (fail
## closed) and the text scene rows stay the scene menu.
func _build_scene_dock() -> void:
    scene_dock = null
    scene_dock_error = ""
    if not scene_select_enabled():
        return
    var dock = SceneSelectDock.new()
    dock.name = "SceneSelectDock"
    add_child(dock)
    if not dock.configure(Lang.language(), scene_gate):
        scene_dock_error = String(dock.error)
        push_error("prototype_menu: scene dock failed closed: " + scene_dock_error)
        printerr("prototype_menu: scene dock FAIL CLOSED: " + scene_dock_error)
        remove_child(dock)
        dock.queue_free()
        return
    scene_dock = dock

func _load_menu_sfx() -> void:
    nav_sfx = _load_sfx(MenuSfxMap.NAV, "nav")
    accept_sfx = _load_sfx(MenuSfxMap.ACCEPT, "accept")
    back_sfx = _load_sfx(MenuSfxMap.BACK, "back")
    page_flip_sfx = _load_sfx(MenuSfxMap.PAGE_FLIP, "page_flip")
    if MenuSfxMap.has_denied_cue():
        denied_sfx = _load_sfx(MenuSfxMap.DENIED, "denied")
    accept_sfx_error = String(menu_sfx_errors.get("accept", ""))

## Resolves a menu SFX file to an on-disk path following the prototype's root
## rules.  Returns "" when LOCALAPPDATA is unavailable.
func _resolve_menu_sfx_path(filename: String, label: String) -> String:
    var sfx_path: String = OS.get_environment("BRUCELEE_MENU_SFX_PATH")
    if label != "accept" or sfx_path.is_empty():
        var root: String = OS.get_environment("BRUCELEE_MENU_SFX_ROOT")
        if root.is_empty():
            var local_app_data: String = OS.get_environment("LOCALAPPDATA")
            if local_app_data.is_empty():
                return ""
            root = local_app_data.path_join(
                "BruceLee-PC-Port/p5-menu-assets-20261030/"
                + "adreno_200/sounds/menu_sfx"
            )
        sfx_path = root.path_join(filename)
    return sfx_path

## Loads one menu SFX stream by exact archive filename.  Public so any recovered
## menu screen (or the validator) can load an original file on demand; records
## errors under the filename so a missing file is visible instead of silent.
func load_menu_sfx_stream(filename: String) -> AudioStreamWAV:
    var sfx_path: String = _resolve_menu_sfx_path(filename, "inventory")
    if sfx_path.is_empty():
        menu_sfx_errors[filename] = "LOCALAPPDATA is unavailable"
        return null
    var error: String = CandidatePathGuard.external_path_error(
        sfx_path, "prototype menu sfx"
    )
    if not error.is_empty():
        menu_sfx_errors[filename] = error
        return null
    var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(sfx_path)
    if stream == null:
        menu_sfx_errors[filename] = "prototype menu sfx failed to load: " + sfx_path
    return stream

func _load_sfx(filename: String, label: String) -> AudioStreamPlayer:
    var sfx_path: String = _resolve_menu_sfx_path(filename, label)
    if sfx_path.is_empty():
        menu_sfx_errors[label] = "LOCALAPPDATA is unavailable"
        return null
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
    # Size the row pool from the rows actually shown: main_labels() is one row
    # longer than the const baseline while BRUCELEE_PROGRESS=1, and a fixed pool
    # would silently drop QUIT GAME.
    for index: int in range(maxi(main_labels().size(), PAUSE_LABELS.size())):
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
    # Recovered-language font for CJK scripts (no-op for Latin/Cyrillic).
    for label: Label in [title, subtitle, mode_label, status_label, controls_label, disclaimer]:
        Lang.apply_font(label)
    for label: Label in item_labels:
        Lang.apply_font(label)

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
    _hide_scene_dock()
    menu_state = "main"
    selected_index = 0
    visible = true
    mode_label.text = Lang.text("main_menu")
    status_label.text = ""
    controls_label.text = "UP/DOWN or D-PAD choose   ENTER/J/A confirm"
    hover_index = -1
    _refresh_items(main_labels())
    _refresh_selection()

func show_scene_menu() -> void:
    ## Scene selection submenu. Reached through the SCENES entry only.
    if menu_state == "main":
        main_index_before_submenu = selected_index
    menu_state = "scenes"
    selected_index = 0
    visible = true
    mode_label.text = Lang.text("select_scenery")
    status_label.text = ""
    controls_label.text = (
        "UP/DOWN or D-PAD   ENTER/J/A load   ESC/B/START back"
    )
    hover_index = -1
    _refresh_scene_gate()
    _refresh_items(SCENE_LABELS)
    _refresh_selection()
    _show_scene_dock()

## Shows the recovered dock for the scene submenu when it is available.  With
## the flag off, or after a fail-closed load, this is a no-op and the text rows
## just refreshed above stay the scene menu.
func _show_scene_dock() -> void:
    if scene_dock == null:
        if scene_select_enabled() and not scene_dock_error.is_empty():
            status_label.text = SCENE_DOCK_UNAVAILABLE
        elif scene_gate != null and Array(scene_gate.rows).is_empty():
            status_label.text = SCENE_UNLOCK_UNAVAILABLE
        return
    scene_dock.select_index(0)
    scene_dock.show_dock()
    panel_box.visible = false
    status_label.text = ""

func _hide_scene_dock() -> void:
    if scene_dock != null:
        scene_dock.hide_dock()
    if panel_box != null:
        panel_box.visible = true

## True while the dock owns the scene submenu (loaded, shown, and the submenu
## is the current state).
func _scene_dock_active() -> bool:
    return scene_dock != null and menu_state == "scenes" and bool(scene_dock.visible)

func _move_scene_dock(delta: int) -> void:
    if scene_dock == null:
        return
    if scene_dock.move(delta):
        if bool(scene_dock.sfx_missing):
            # The dock's own decoded page-flip stream is missing; fall back to the
            # recovered page-flip file this menu loaded, then to nav. Never invent.
            if page_flip_sfx != null:
                _play_sfx(page_flip_sfx, "page_flip")
            else:
                _play_sfx(nav_sfx, "nav")
    _refresh_selection()

func _confirm_scene_dock() -> void:
    ## Emits the scene command main.gd already implements, exactly like the text
    ## scene rows; main.gd applies BRUCELEE_SCENE and reloads into that scene.
    ## A card whose recovered story grant is unsatisfied is not applied: the
    ## decoded dock declares a `lockedpicture` for exactly this state.
    if scene_dock == null:
        return
    if scene_dock.selected_locked():
        scene_dock.set_hint(SCENE_LOCKED)
        _play_denied()
        return
    var row: Dictionary = scene_dock.selected_row()
    if row.is_empty():
        return
    var command: String = String(row.get("command", ""))
    if command.is_empty():
        scene_dock.set_hint("NO MENU COMMAND FOR SCENE VARIANT")
        return
    _play_sfx(accept_sfx, "accept")
    last_accept_was_attack = false
    _hide_scene_dock()
    command_requested.emit(command)

func show_opponent_menu() -> void:
    ## Opponent selection submenu. Reached through the OPPONENTS entry only.
    ## The command itself is applied by main.gd (environment + scene reload).
    _hide_scene_dock()
    if menu_state == "main":
        main_index_before_submenu = selected_index
    menu_state = "opponents"
    selected_index = 0
    visible = true
    mode_label.text = Lang.text("select_fighter")
    status_label.text = ""
    controls_label.text = (
        "UP/DOWN or D-PAD   ENTER/J/A apply   ESC/B/START back"
    )
    hover_index = -1
    _refresh_fighter_gate()
    _refresh_items(opponent_labels())
    if fighter_gate != null and Array(fighter_gate.rows).is_empty():
        status_label.text = FIGHTER_UNLOCK_UNAVAILABLE
    _refresh_selection()

func show_pause_menu() -> void:
    _hide_scene_dock()
    menu_state = "pause"
    selected_index = 0
    visible = true
    mode_label.text = Lang.text("pause")
    status_label.text = ""
    controls_label.text = "UP/DOWN or D-PAD choose   ENTER/J/A confirm   ESC/B/START resume"
    hover_index = -1
    _refresh_items(PAUSE_LABELS)
    _refresh_selection()

func hide_menu() -> void:
    _hide_scene_dock()
    menu_state = "hidden"
    visible = false
    hover_index = -1

func show_error(value: String) -> void:
    status_label.text = value
    # While the recovered dock owns the scene submenu the text panel is hidden,
    # so the message goes to the dock's own line instead of a hidden label.
    if _scene_dock_active():
        scene_dock.set_hint(value)

func selected_command() -> String:
    if _scene_dock_active():
        return String(scene_dock.selected_row().get("command", ""))
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
    if _scene_dock_active():
        return _handle_scene_dock_input(event)
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

## Dock input.  The recovered dock is a single horizontal row with
## `wraparround=false`, so LEFT/RIGHT move the selection and both ends clamp;
## ENTER / SPACE / J / pad-A apply the card, ESC / BACKSPACE / pad-B return to
## the main menu (the same BACK the text scene rows use).  UP/DOWN have no
## meaning on a one-row dock and are ignored instead of moving a hidden list.
func _handle_scene_dock_input(event: InputEvent) -> bool:
    if event.is_action_pressed(PrototypeControls.MOVE_LEFT):
        _move_scene_dock(-1)
        return true
    if event.is_action_pressed(PrototypeControls.MOVE_RIGHT):
        _move_scene_dock(1)
        return true
    if event.is_action_pressed(PrototypeControls.MENU_ACCEPT) or _is_space(event):
        _confirm_scene_dock()
        return true
    if event.is_action_pressed(PrototypeControls.MENU_CANCEL) or _is_backspace(event):
        _play_sfx(back_sfx, "back")
        _return_to_main_menu()
        return true
    return false

func _is_space(event: InputEvent) -> bool:
    return event is InputEventKey and (event as InputEventKey).keycode == KEY_SPACE

func _is_backspace(event: InputEvent) -> bool:
    return event is InputEventKey and (event as InputEventKey).keycode == KEY_BACKSPACE

## True only while the opt-in progress service is enabled. Kept static and
## side-effect free so the flag can be read from tests without a running tree.
static func progress_enabled() -> bool:
    return OS.get_environment(ENV_PROGRESS) == "1"

## True only while the opt-in Style Editor is enabled. Static and side-effect
## free so the flag can be read from tests without a running tree.
static func style_editor_enabled() -> bool:
    return OS.get_environment(ENV_STYLE_EDITOR) == "1"

## Main-menu rows actually shown. With the flags off this is exactly the const
## baseline; with them on, RECORDS and/or STYLE EDITOR are inserted before
## QUIT GAME, in that order.
func main_commands() -> Array[String]:
    var out: Array[String] = MAIN_COMMANDS.duplicate()
    if progress_enabled():
        out.insert(maxi(out.size() - 1, 0), RECORDS_COMMAND)
    if style_editor_enabled():
        out.insert(maxi(out.size() - 1, 0), STYLE_EDITOR_COMMAND)
    return out

func main_labels() -> Array[String]:
    var out: Array[String] = MAIN_LABELS.duplicate()
    if progress_enabled():
        out.insert(maxi(out.size() - 1, 0), RECORDS_LABEL)
    if style_editor_enabled():
        out.insert(maxi(out.size() - 1, 0), STYLE_EDITOR_LABEL)
    return out

func _commands() -> Array[String]:
    match menu_state:
        "main":
            return main_commands()
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
    if menu_state == "scenes" and scene_command_locked(command):
        # Fail closed: a story-gated scenery whose recovered unlock id is not in
        # the progress save emits no command and says so.  The text submenu has
        # no recovered locked-row widget, so the message is port chrome.
        status_label.text = SCENE_LOCKED
        _play_denied()
        last_accept_was_attack = false
        return
    if menu_state == "opponents" and fighter_command_locked(command):
        # Same rule for a recovered character: the text row and the dock card
        # cannot select a fighter whose unlock id is absent from the save.  The
        # message is port chrome for the text menu; the dock already carries the
        # decoded lockedpicture on the card.
        status_label.text = FIGHTER_LOCKED
        last_accept_was_attack = false
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
    _hide_scene_dock()
    menu_state = "main"
    var commands: Array[String] = main_commands()
    selected_index = clampi(main_index_before_submenu, 0, maxi(commands.size() - 1, 0))
    mode_label.text = Lang.text("main_menu")
    status_label.text = ""
    controls_label.text = "UP/DOWN or D-PAD choose   ENTER/J/A confirm"
    hover_index = -1
    _refresh_items(main_labels())
    _refresh_selection()

func _play_sfx(player: AudioStreamPlayer, label: String) -> void:
    if player == null:
        return
    last_sfx_played = label
    player.play()

## Plays the "denied" cue only when the original data provides one. MenuSfxMap.DENIED
## is empty because the original UI/engine has no deny cue; locked/denied actions
## therefore stay silent rather than substituting an invented file.
func _play_denied() -> void:
    if denied_sfx != null:
        _play_sfx(denied_sfx, "denied")

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
    var shown: Array[String] = _localized_labels(labels)
    for index: int in range(item_labels.size()):
        item_labels[index].visible = index < shown.size()
        if index < shown.size():
            item_labels[index].set_meta("base_text", shown[index])
    _refresh_selection()


## Recovered .lang labels for the current command list. A command with no
## recovered key keeps its original label (fallback, never invented text).
## On the scene submenu a locked scenery row appends the port-chrome
## `SceneUnlockGate.LOCKED_SUFFIX`; the recovered screen has no text variant of
## the locked state (the dock uses the decoded `lockedpicture` instead).
func _localized_labels(labels: Array[String]) -> Array[String]:
    var commands: Array[String] = _commands()
    var out: Array[String] = []
    for index: int in range(labels.size()):
        var command: String = commands[index] if index < commands.size() else ""
        out.append(Lang.command_label(command, labels[index]))
    if menu_state == "scenes" and scene_gate != null:
        for index: int in range(out.size()):
            var command: String = commands[index] if index < commands.size() else ""
            if scene_command_locked(command):
                out[index] = out[index] + SceneUnlockGate.LOCKED_SUFFIX
    if menu_state == "opponents" and fighter_gate != null:
        for index: int in range(out.size()):
            var command: String = commands[index] if index < commands.size() else ""
            if fighter_command_locked(command):
                out[index] = out[index] + CharacterUnlockGate.LOCKED_SUFFIX
    return out

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
    selection_changed.emit(menu_state, selected_index, selected_command())

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

## ------------------------------------------------- recovered scene dock hooks
## Read-only accessors used by tests/validate_scene_select.gd; they never
## change menu behaviour.

## Recovered scenes exactly as the dock shows them (empty when the dock is off
## or failed closed).
func scene_dock_rows() -> Array:
    if scene_dock == null:
        return []
    return scene_dock.catalog.rows()

## Dock geometry in the 480x320 layout space (empty when the dock is off).
func scene_dock_rects() -> Dictionary:
    if scene_dock == null:
        return {}
    return scene_dock.built_rects()

func scene_dock_label() -> String:
    if scene_dock == null:
        return ""
    return scene_dock.label_text()

## Texture regions drawn for the cards (the decoded option crop).
func scene_dock_card_regions() -> Array:
    if scene_dock == null:
        return []
    return scene_dock.card_regions()

func scene_dock_selection() -> int:
    if scene_dock == null:
        return -1
    return int(scene_dock.selection)

## True while the dock is loaded, shown and the scene submenu is the state.
func scene_dock_visible() -> bool:
    return _scene_dock_active()

## The text scene rows are still laid out under the dock (the fallback); this
## reports whether the text panel is currently the visible scene menu.
func scene_text_rows_visible() -> bool:
    return panel_box != null and panel_box.visible

## ------------------------------------------------- scene unlock test hooks
## Read-only accessors used by tests/validate_scene_unlock.gd.

## Recovered unlock states for the ten sceneries rows (empty with the gate off).
func scene_gate_rows() -> Array:
    if scene_gate == null:
        return []
    return scene_gate.rows.duplicate(true)

## Full gate summary: data/save status, grant ids, per-row reason.
func scene_gate_summary() -> Dictionary:
    if scene_gate == null:
        return {"enabled": false}
    return scene_gate.summary()

## Docks rows whose decoded story grant is unsatisfied.
func scene_dock_locked_rows() -> Array:
    if scene_dock == null:
        return []
    return scene_dock.locked_rows()

## Picture basename drawn for each dock card ("locked" rows draw the decoded
## `lockedpicture` basename).
func scene_dock_card_sources() -> Array:
    if scene_dock == null:
        return []
    return scene_dock.card_sources()

## ---------------------------------------------- character unlock test hooks
## Read-only accessors used by tests/validate_character_locks.gd.

## Recovered unlock states for the fifteen characters rows (empty with the gate
## off).
func fighter_gate_rows() -> Array:
    if fighter_gate == null:
        return []
    return fighter_gate.rows.duplicate(true)

## Full gate summary: data/save status, decoded dock mapping, per-row reason.
func fighter_gate_summary() -> Dictionary:
    if fighter_gate == null:
        return {"enabled": false}
    return fighter_gate.summary()

## True only while the gate's decoded selectfighter dock validated.
func fighter_dock_ok() -> bool:
    return fighter_gate != null and bool(fighter_gate.dock_ok)

## The text OPPONENTS labels as currently shown (with the port-chrome suffix on
## closed rows).
func opponent_row_labels() -> Array:
    var out: Array = []
    for item: Dictionary in (layout_report()["items"] as Array):
        out.append(String(item.get("text", "")))
    return out

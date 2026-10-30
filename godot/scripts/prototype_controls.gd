extends RefCounted
class_name PortPrototypeControls

## PC prototype bindings. These do not claim parity with the Android input map.

const MOVE_LEFT: String = "prototype_move_left"
const MOVE_RIGHT: String = "prototype_move_right"
const MOVE_UP: String = "prototype_move_up"
const MOVE_DOWN: String = "prototype_move_down"
const ATTACK_A: String = "prototype_attack_a"
const ATTACK_B: String = "prototype_attack_b"
const ATTACK_C: String = "prototype_attack_c"
const ATTACK_D: String = "prototype_attack_d"
const GUARD: String = "prototype_guard"
const RESTART: String = "prototype_restart"
const TOGGLE_TRAINING: String = "prototype_toggle_training"
const PAUSE: String = "prototype_pause"
const MENU_UP: String = "prototype_menu_up"
const MENU_DOWN: String = "prototype_menu_down"
const MENU_ACCEPT: String = "prototype_menu_accept"
const MENU_CANCEL: String = "prototype_menu_cancel"

const ALL_ACTIONS: Array[String] = [
    MOVE_LEFT,
    MOVE_RIGHT,
    MOVE_UP,
    MOVE_DOWN,
    ATTACK_A,
    ATTACK_B,
    ATTACK_C,
    ATTACK_D,
    GUARD,
    RESTART,
    TOGGLE_TRAINING,
    PAUSE,
    MENU_UP,
    MENU_DOWN,
    MENU_ACCEPT,
    MENU_CANCEL,
]

static var _defaults_registered: bool = false

## Register prototype defaults once per process. Project-specific action names
## avoid silently replacing engine or future user bindings.
static func ensure_default_actions() -> void:
    if _defaults_registered:
        return
    _register(MOVE_LEFT, 0.2, [
        _key(KEY_A),
        _axis(JOY_AXIS_LEFT_X, -1.0),
        _button(JOY_BUTTON_DPAD_LEFT),
    ])
    _register(MOVE_RIGHT, 0.2, [
        _key(KEY_D),
        _axis(JOY_AXIS_LEFT_X, 1.0),
        _button(JOY_BUTTON_DPAD_RIGHT),
    ])
    _register(MOVE_UP, 0.2, [
        _key(KEY_W),
        _axis(JOY_AXIS_LEFT_Y, -1.0),
        _button(JOY_BUTTON_DPAD_UP),
    ])
    _register(MOVE_DOWN, 0.2, [
        _key(KEY_S),
        _axis(JOY_AXIS_LEFT_Y, 1.0),
        _button(JOY_BUTTON_DPAD_DOWN),
    ])
    _register(ATTACK_A, 0.5, [_key(KEY_J), _button(JOY_BUTTON_A)])
    _register(ATTACK_B, 0.5, [_key(KEY_K), _button(JOY_BUTTON_X)])
    _register(ATTACK_C, 0.5, [_key(KEY_L), _button(JOY_BUTTON_Y)])
    _register(ATTACK_D, 0.5, [_key(KEY_U), _button(JOY_BUTTON_B)])
    _register(GUARD, 0.5, [
        _key(KEY_SHIFT),
        _button(JOY_BUTTON_LEFT_SHOULDER),
        _button(JOY_BUTTON_RIGHT_SHOULDER),
    ])
    _register(RESTART, 0.5, [_key(KEY_R), _button(JOY_BUTTON_BACK)])
    _register(TOGGLE_TRAINING, 0.5, [
        _key(KEY_F2),
        _button(JOY_BUTTON_MISC1),
        _button(JOY_BUTTON_LEFT_STICK),
    ])
    _register(PAUSE, 0.5, [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)])
    _register(MENU_UP, 0.5, [
        _key(KEY_UP),
        _key(KEY_W),
        _button(JOY_BUTTON_DPAD_UP),
    ])
    _register(MENU_DOWN, 0.5, [
        _key(KEY_DOWN),
        _key(KEY_S),
        _button(JOY_BUTTON_DPAD_DOWN),
    ])
    _register(MENU_ACCEPT, 0.5, [
        _key(KEY_ENTER),
        _key(KEY_KP_ENTER),
        _key(KEY_J),
        _button(JOY_BUTTON_A),
    ])
    _register(MENU_CANCEL, 0.5, [
        _key(KEY_ESCAPE),
        _button(JOY_BUTTON_B),
        _button(JOY_BUTTON_START),
    ])
    _defaults_registered = true

static func is_press_edge(event: InputEvent) -> bool:
    if event is InputEventKey:
        var key_event: InputEventKey = event as InputEventKey
        return key_event.pressed and not key_event.echo
    if event is InputEventJoypadButton:
        return (event as InputEventJoypadButton).pressed
    return false

static func _register(
    action: String,
    deadzone: float,
    defaults: Array[InputEvent]
) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action, deadzone)
    if not InputMap.action_get_events(action).is_empty():
        return
    for event: InputEvent in defaults:
        InputMap.action_add_event(action, event)

static func _key(keycode: Key) -> InputEventKey:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = keycode
    return event

static func _button(button_index: JoyButton) -> InputEventJoypadButton:
    var event: InputEventJoypadButton = InputEventJoypadButton.new()
    event.device = -1
    event.button_index = button_index
    return event

static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
    var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
    event.device = -1
    event.axis = axis
    event.axis_value = value
    return event

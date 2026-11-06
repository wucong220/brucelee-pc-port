extends SceneTree
## Negative control for the canblock window model: prove the windows come from
## the exported JSON and not from constants baked into the port.
##
## The shipped brucelee.set highblock window is [6,14].  This probe builds the
## model from the parsed export, then rewrites that one group to [7,15] in
## memory and rebuilds: the model must follow the mutated data while the
## original still reports [6,14].  A model with hardcoded [6,14] would fail.
## The validation test separately proves CanBlockWindows.load_set() reads the
## same bytes from data/native_links.json.
##
## Usage: godot --headless --path <project> \
##        --script res://tests/verify_canblock_windows_mutation.gd

const CanBlockWindows = preload("res://scripts/canblock_windows.gd")
const SOURCE_PATH: String = "res://data/native_links.json"

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _key(windows: Array[Dictionary]) -> Array[String]:
    var keys: Array[String] = []
    for window: Dictionary in windows:
        keys.append("%s|%d|%d" % [
            String(window.get("group", "")),
            int(window.get("start", -1)),
            int(window.get("end", -1)),
        ])
    return keys


func _run() -> void:
    var text: String = FileAccess.get_file_as_string(SOURCE_PATH)
    var parsed: Variant = JSON.parse_string(text)
    if not parsed is Dictionary:
        push_error("source JSON is not an object: " + SOURCE_PATH)
        quit(1)
        return
    var original: CanBlockWindows = CanBlockWindows.new()
    if not original.build(Dictionary(parsed), SOURCE_PATH):
        push_error("cannot build original model: " + original.load_error)
        quit(1)
        return

    # Mutate one in-memory action; the file on disk is never touched.
    var data: Dictionary = parsed
    var actions: Array = Array(data.get("actions", []))
    var mutated: bool = false
    for action_value: Variant in actions:
        if not action_value is Dictionary:
            continue
        var action: Dictionary = action_value
        if String(action.get("name", "")) != "highblock":
            continue
        var groups: Dictionary = action.get("groups", {})
        groups["canblock"] = [7, 15, 0]
        action["groups"] = groups
        mutated = true
    if not mutated:
        push_error("highblock action not found in " + SOURCE_PATH)
        quit(1)
        return
    var model: CanBlockWindows = CanBlockWindows.new()
    if not model.build(data, "in-memory mutation of " + SOURCE_PATH):
        push_error("cannot build mutated model: " + model.load_error)
        quit(1)
        return

    var original_keys: Array[String] = _key(original.windows_for("highblock"))
    var mutated_keys: Array[String] = _key(model.windows_for("highblock"))
    if original_keys != ["canblock|6|14"]:
        failures.append("original highblock window = %s" % str(original_keys))
    if mutated_keys != ["canblock|7|15"]:
        failures.append("mutated highblock window = %s" % str(mutated_keys))
    if original.open("highblock", 6.0) != true or original.open("highblock", 15.0) != false:
        failures.append("original [6,14] boundaries drifted")
    if model.open("highblock", 6.0) != false or model.open("highblock", 7.0) != true:
        failures.append("mutated [7,15] lower boundary not followed")
    if model.open("highblock", 15.0) != true or model.open("highblock", 15.5) != false:
        failures.append("mutated [7,15] upper boundary not followed")

    print("CANBLOCK_WINDOW_MUTATION original=highblock %s mutated=highblock %s"
            % [str(original_keys), str(mutated_keys)])
    if failures.is_empty():
        print("CANBLOCK_WINDOW_MUTATION=PASS")
        quit(0)
    else:
        print("CANBLOCK_WINDOW_MUTATION=FAIL")
        for failure: String in failures:
            print("  - " + failure)
        quit(1)

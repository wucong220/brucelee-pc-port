extends SceneTree
## Truth-table for the strict no-eligible path.
## No scene/fighter is needed: this checks the pure selector and the default-off
## compatibility switch.

const Selector = preload("res://scripts/native_action_selector.gd")
const NativeAIScript = preload("res://scripts/native_ai.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _link(action: String, window: bool = true, key_seq: bool = false, key_status: bool = false, conditions: bool = true) -> Dictionary:
    return {
        "action": action,
        "time_window_open": window,
        "has_key_sequence": key_seq,
        "has_key_status": key_status,
        "conditions_pass": conditions,
    }


func _check(label: String, ok: bool) -> void:
    if not ok:
        failures.append(label)
        push_error("NATIVE_NO_ELIGIBLE_FAIL: " + label)


func _check_no_eligible(label: String, result: Dictionary) -> void:
    _check(label + ":ok", bool(result.get("ok", false)))
    _check(label + ":not_selected", not bool(result.get("selected", true)))
    _check(label + ":reason", String(result.get("reason", "")) == "no_eligible_link")


func _run() -> void:
    # 1. Window closed for the only candidate.
    _check_no_eligible("closed_window", Selector.select_first_eligible(
        [_link("A", false)], ["A"]))
    # 2. Unlisted candidate with a key requirement.
    _check_no_eligible("unlisted_key_requirement", Selector.select_first_eligible(
        [_link("A", true, false, true, true)], []))
    # 3. Listed candidate with failed conditions.
    _check_no_eligible("failed_conditions", Selector.select_first_eligible(
        [_link("A", true, false, false, false)], ["A"]))
    # 4. Empty candidate list.
    _check_no_eligible("empty_candidates", Selector.select_first_eligible([], ["A"]))
    # 5. Missing native field is invalid data, not "no eligible".
    var missing: Dictionary = _link("A")
    missing.erase("time_window_open")
    var invalid: Dictionary = Selector.select_first_eligible([missing], ["A"])
    _check("missing_field:ok_false", not bool(invalid.get("ok", true)))
    _check("missing_field:not_selected", not bool(invalid.get("selected", true)))

    # 6. Compatibility picker is default-off.
    var ai: RefCounted = NativeAIScript.new()
    _check("legacy_picker_default_off", not bool(ai.legacy_picker_opt_in))
    _check("legacy_picker_default_disabled", not bool(ai._legacy_picker_enabled()))
    ai.set_legacy_picker_opt_in(true)
    _check("legacy_picker_opt_in_set", bool(ai.legacy_picker_opt_in))
    ai.set_legacy_picker_opt_in(false)

    if failures.is_empty():
        print("NATIVE_NO_ELIGIBLE_TEST=PASS")
        quit(0)
    else:
        print("NATIVE_NO_ELIGIBLE_TEST=FAIL count=%d" % failures.size())
        quit(1)

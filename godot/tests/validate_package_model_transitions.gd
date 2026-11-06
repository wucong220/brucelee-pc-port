extends SceneTree
## Corrupted / missing packaged-model transitions must fail closed.
##
## For a valid, a byte-corrupted and a missing package model this drives the REAL
## main.tscn resolver and the REAL game_modes / story_flow transition prechecks:
##   * only the valid model resolves to a path;
##   * a corrupted model is rejected on its SHA-256 (not on existence);
##   * a declared-but-missing model is rejected;
##   * the mode/story transitions return a non-empty error and stage no GLB.
##
## Fixture (created by run_hardened_tests.ps1 under HARDENED_FIXTURE):
##   pkg_valid/models/brick_full_94_20261103.glb   (exact copy)
##   pkg_bad/models/brick_full_94_20261103.glb     (same bytes + 1 appended)
##   pkg_missing/models/                           (empty dir)
##
##   HARDENED_FIXTURE=<fixture> <godot> --headless --path godot \
##       --script res://tests/validate_package_model_transitions.gd

const GameModes = preload("res://scripts/game_modes.gd")
const StoryFlow = preload("res://scripts/story_flow.gd")
const Guard = preload("res://scripts/candidate_path_guard.gd")

const MANIFEST_PATH: String = "res://data/candidate_package_models.json"
const MODEL_NAME: String = "brick_full_94_20261103.glb"

var _failures: Array[String] = []
var _records: Array = []
var _resolver: Node = null


func _initialize() -> void:
    call_deferred("_run")


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures.append(message)
    push_error("MODEL_TRANSITION: " + message)


func _pin() -> String:
    var parsed: Variant = JSON.parse_string(
        FileAccess.get_file_as_string(MANIFEST_PATH)
    )
    if not parsed is Dictionary:
        return ""
    for row_value: Variant in Dictionary(parsed).get("candidates", []):
        var row: Dictionary = row_value
        if String(row.get("package", "")) == MODEL_NAME:
            return String(row.get("sha256", "")).to_lower()
    return ""


func _with_root(pkg: String) -> void:
    OS.set_environment("BRUCELEE_PACKAGE_ROOT", pkg)
    Guard._canonical_cache.clear()
    Guard._canonical_dir_cache.clear()


func _resolved(pkg: String, pin: String) -> Dictionary:
    _with_root(pkg)
    return _resolver.call("_verified_package_model", {
        "glb_package": "models/" + MODEL_NAME,
        "sha256": pin,
    })


func _mode_probe(pkg: String, pin: String) -> Dictionary:
    _with_root(pkg)
    var modes = GameModes.new()
    modes.configure(_resolver, {"brick": {
        "glb_package": "models/" + MODEL_NAME, "sha256": pin,
    }})
    var error: String = String(modes.call(
        "_package_model_error", {"opponent": "brick"}
    ))
    var glb: String = String(modes.call("_package_candidate_glb", {
        "glb_package": "models/" + MODEL_NAME, "sha256": pin,
    }))
    modes.free()
    return {"error": error, "glb": glb}


func _story_probe(pkg: String, pin: String) -> Dictionary:
    _with_root(pkg)
    var flow = StoryFlow.new()
    flow.configure(_resolver, {"brick": {
        "glb_package": "models/" + MODEL_NAME, "sha256": pin,
    }})
    var error: String = String(flow.call(
        "_package_model_error", {"port_candidate": "brick"}
    ))
    var glb: String = String(flow.call("_package_candidate_glb", {
        "glb_package": "models/" + MODEL_NAME, "sha256": pin,
    }))
    flow.free()
    return {"error": error, "glb": glb}


func _run() -> void:
    var fixture: String = OS.get_environment("HARDENED_FIXTURE").strip_edges()
    if fixture.is_empty():
        _check(false, "HARDENED_FIXTURE is not set")
        return _finish()
    var pin: String = _pin()
    if pin.is_empty():
        _check(false, "no manifest pin for " + MODEL_NAME)
        return _finish()
    _resolver = load("res://scenes/main.tscn").instantiate()

    var valid_pkg: String = fixture.path_join("pkg_valid")
    var bad_pkg: String = fixture.path_join("pkg_bad")
    var missing_pkg: String = fixture.path_join("pkg_missing")

    var valid: Dictionary = _resolved(valid_pkg, pin)
    _records.append({"case": "valid", "resolved": valid})
    _check(String(valid["error"]).is_empty() and not String(valid["glb"]).is_empty(),
            "valid model must resolve to a path")
    _check(String(valid["glb"]).replace("\\", "/").contains("/models/"),
            "valid model path must be in models/")

    var bad: Dictionary = _resolved(bad_pkg, pin)
    _records.append({"case": "corrupted", "resolved": bad})
    _check(String(bad["glb"]).is_empty(), "corrupted model must not return a path")
    _check(String(bad["error"]).contains("sha256 mismatch"),
            "corrupted model must fail on its sha256: " + String(bad["error"]))

    var missing: Dictionary = _resolved(missing_pkg, pin)
    _records.append({"case": "missing", "resolved": missing})
    _check(String(missing["glb"]).is_empty(), "missing model must not return a path")
    _check(String(missing["error"]).contains("missing"),
            "missing model must fail as missing: " + String(missing["error"]))

    # A declared model with no pin is also rejected (never accepted on existence).
    _with_root(valid_pkg)
    var unpinned: Dictionary = _resolver.call("_verified_package_model", {
        "glb_package": "models/" + MODEL_NAME, "sha256": "",
    })
    _records.append({"case": "unpinned", "resolved": unpinned})
    _check(String(unpinned["glb"]).is_empty() and not String(unpinned["error"]).is_empty(),
            "a declared model with no sha256 pin must fail closed")

    var valid_mode: Dictionary = _mode_probe(valid_pkg, pin)
    var bad_mode: Dictionary = _mode_probe(bad_pkg, pin)
    var missing_mode: Dictionary = _mode_probe(missing_pkg, pin)
    _records.append({"case": "game_modes", "valid": valid_mode, "corrupt": bad_mode,
                     "missing": missing_mode})
    _check(String(valid_mode["error"]).is_empty(), "valid mode transition must have no error")
    _check(String(bad_mode["error"]).contains("sha256"),
            "corrupted mode transition must fail closed on sha256")
    _check(String(bad_mode["glb"]).is_empty(), "corrupted mode transition must stage no GLB")
    _check(String(missing_mode["error"]).contains("missing"),
            "missing mode transition must fail closed as missing")
    _check(String(missing_mode["glb"]).is_empty(), "missing mode transition must stage no GLB")

    var valid_story: Dictionary = _story_probe(valid_pkg, pin)
    var bad_story: Dictionary = _story_probe(bad_pkg, pin)
    var missing_story: Dictionary = _story_probe(missing_pkg, pin)
    _records.append({"case": "story_flow", "valid": valid_story, "corrupt": bad_story,
                     "missing": missing_story})
    _check(String(valid_story["error"]).is_empty(), "valid story transition must have no error")
    _check(String(bad_story["error"]).contains("sha256"),
            "corrupted story transition must fail closed on sha256")
    _check(String(bad_story["glb"]).is_empty(), "corrupted story transition must stage no GLB")
    _check(String(missing_story["error"]).contains("missing"),
            "missing story transition must fail closed as missing")
    _check(String(missing_story["glb"]).is_empty(), "missing story transition must stage no GLB")

    return _finish()


func _finish() -> void:
    OS.set_environment("BRUCELEE_PACKAGE_ROOT", "")
    if _resolver != null and is_instance_valid(_resolver):
        _resolver.free()
    print("PACKAGE_MODEL_TRANSITIONS=" + JSON.stringify({
        "records": _records,
        "failures": _failures,
    }))
    if _failures.is_empty():
        print("PACKAGE_MODEL_TRANSITIONS_OK")
        quit(0)
    else:
        print("PACKAGE_MODEL_TRANSITIONS_FAILED=" + str(_failures.size()))
        quit(1)

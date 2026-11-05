extends SceneTree
## Drives the ACTUAL _launch_fight() transitions with corrupted / missing
## package models.  The transition must stop on the error screen, must not
## stage a GLB and must not set the "launch pending" environment flags.
##
## Fixture: HARDENED_FIXTURE/pkg_valid, pkg_bad, pkg_missing (see runner).
##   HARDENED_FIXTURE=<fixture> <godot> --headless --path godot \
##       --script res://tests/validate_package_model_launch_abort.gd

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
    push_error("LAUNCH_ABORT: " + message)


func _pin() -> String:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
    if not parsed is Dictionary:
        return ""
    for row_value: Variant in Dictionary(parsed).get("candidates", []):
        var row: Dictionary = row_value
        if String(row.get("package", "")) == MODEL_NAME:
            return String(row.get("sha256", "")).to_lower()
    return ""


func _stub_data() -> Object:
    var script: GDScript = GDScript.new()
    script.source_code = (
        "extends RefCounted\n"
        + "func character_row(id):\n\treturn {\"port_candidate\": id, \"unique\": id}\n"
        + "func scenery_row(n):\n\treturn {\"port_scene_variant\": \"templeyardb\"}\n"
    )
    var err: Error = script.reload()
    if err != OK:
        return null
    return script.new()


func _set_root(pkg: String) -> void:
    OS.set_environment("BRUCELEE_PACKAGE_ROOT", pkg)
    Guard._canonical_cache.clear()
    Guard._canonical_dir_cache.clear()


func _mode_launch(pkg: String, pin: String) -> Dictionary:
    _set_root(pkg)
    var config: Dictionary = {"brick": {
        "glb_package": "models/" + MODEL_NAME, "sha256": pin,
    }}
    var gm = GameModes.new()
    gm.configure(_resolver, config)
    root.add_child(gm)
    gm.set("current_mode", "arcade")
    gm.set("run", {"opponents": ["brick"], "scenes": ["templeyardb"],
                   "opponent_index": 0, "mode": "arcade"})
    OS.set_environment("BRUCELEE_MODE_LAUNCH", "")
    OS.set_environment("BRUCELEE_GAME_MODE", "")
    gm.call("_launch_fight")
    var result: Dictionary = {
        "screen": String(gm.get("screen")),
        "title": String(gm.title_label.text) if gm.title_label != null else "",
        "subtitle": String(gm.subtitle_label.text) if gm.subtitle_label != null else "",
        "launch_flag": OS.get_environment("BRUCELEE_MODE_LAUNCH"),
        "game_mode_env": OS.get_environment("BRUCELEE_GAME_MODE"),
        "opponent_glb": OS.get_environment("BRUCELEE_OPPONENT_GLB"),
    }
    paused = false
    gm.free()
    return result


func _story_launch(pkg: String, pin: String) -> Dictionary:
    _set_root(pkg)
    var config: Dictionary = {"brick": {
        "glb_package": "models/" + MODEL_NAME, "sha256": pin,
    }}
    var flow = StoryFlow.new()
    flow.configure(_resolver, config)
    root.add_child(flow)
    flow.set("data", _stub_data())
    flow.set("battle_run", {"opponents": ["brick"], "scenery": "x",
                            "opponent_index": 0, "source": {}, "kind": "story"})
    OS.set_environment("BRUCELEE_STORY_LAUNCH", "")
    OS.set_environment("BRUCELEE_STORY_FLOW", "")
    OS.set_environment("BRUCELEE_OPPONENT_GLB", "")
    flow.call("_launch_fight")
    var result: Dictionary = {
        "screen": String(flow.get("screen")),
        "title": String(flow.title_label.text) if flow.title_label != null else "",
        "subtitle": String(flow.subtitle_label.text) if flow.subtitle_label != null else "",
        "launch_flag": OS.get_environment("BRUCELEE_STORY_LAUNCH"),
        "story_env": OS.get_environment("BRUCELEE_STORY_FLOW"),
        "opponent_glb": OS.get_environment("BRUCELEE_OPPONENT_GLB"),
    }
    paused = false
    flow.free()
    return result


func _assert_abort(label: String, result: Dictionary, title: String, reason: String) -> void:
    _records.append({"case": label, "result": result})
    _check(result["screen"] == "error",
            label + ": transition must stop on the error screen, got " + result["screen"])
    _check(String(result["title"]).contains(title),
            label + ": expected title " + title + ", got " + String(result["title"]))
    _check(String(result["subtitle"]).contains(reason),
            label + ": error text should name " + reason + ": " + String(result["subtitle"]))
    _check(String(result["launch_flag"]) != "1",
            label + ": must not arm the scene-reload launch flag")
    _check(String(result["opponent_glb"]).is_empty(),
            label + ": must not stage an opponent GLB")


func _run() -> void:
    var fixture: String = OS.get_environment("HARDENED_FIXTURE").strip_edges()
    var pin: String = _pin()
    if fixture.is_empty() or pin.is_empty():
        _check(false, "HARDENED_FIXTURE and the manifest pin are required")
        return _finish()
    _resolver = load("res://scenes/main.tscn").instantiate()
    var bad_pkg: String = fixture.path_join("pkg_bad")
    var missing_pkg: String = fixture.path_join("pkg_missing")
    var valid_pkg: String = fixture.path_join("pkg_valid")

    var mode_bad: Dictionary = _mode_launch(bad_pkg, pin)
    _assert_abort("game_modes corrupt", mode_bad, "MODE CONFIG ERROR", "sha256 mismatch")
    var mode_missing: Dictionary = _mode_launch(missing_pkg, pin)
    _assert_abort("game_modes missing", mode_missing, "MODE CONFIG ERROR", "missing")

    var story_bad: Dictionary = _story_launch(bad_pkg, pin)
    _assert_abort("story_flow corrupt", story_bad, "BATTLE CONFIG ERROR", "sha256 mismatch")
    var story_missing: Dictionary = _story_launch(missing_pkg, pin)
    _assert_abort("story_flow missing", story_missing, "BATTLE CONFIG ERROR", "missing")

    # Control: a valid model reaches the launch path (launch flag armed), proving
    # the aborts above were caused by the model check, not by a broken fixture.
    var mode_ok: Dictionary = _mode_launch(valid_pkg, pin)
    _records.append({"case": "game_modes valid control", "result": mode_ok})
    _check(String(mode_ok["launch_flag"]) == "1",
            "valid model must still arm the launch flag")
    _check(not String(mode_ok["opponent_glb"]).is_empty(),
            "valid model must stage a GLB")
    return _finish()


func _finish() -> void:
    OS.set_environment("BRUCELEE_PACKAGE_ROOT", "")
    OS.set_environment("BRUCELEE_MODE_LAUNCH", "")
    paused = false
    if _resolver != null and is_instance_valid(_resolver):
        _resolver.free()
    print("PACKAGE_MODEL_LAUNCH_ABORT=" + JSON.stringify({
        "records": _records, "failures": _failures,
    }))
    if _failures.is_empty():
        print("PACKAGE_MODEL_LAUNCH_ABORT_OK")
        quit(0)
    else:
        print("PACKAGE_MODEL_LAUNCH_ABORT_FAILED=" + str(_failures.size()))
        quit(1)

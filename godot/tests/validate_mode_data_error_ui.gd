extends SceneTree
## MODE DATA ERROR UI behaviour when BOTH data sources are absent.
##
## The rules live in res://data/game_modes.json (packed) with an exe-directory
## sidecar fallback.  This test temporarily renames the packed file (the sidecar
## is absent in this environment), so Rules.load_rules() returns empty, and then
## drives the real game_modes UI:
##   * open_initial()  -> MODE DATA ERROR screen, not the mode menu
##   * open_mode(...)  -> MODE DATA ERROR screen, not the settings screen
## The packed file is restored in _finish() and its restore is verified.
##
##   <godot> --headless --path godot --script res://tests/validate_mode_data_error_ui.gd

const GameModes = preload("res://scripts/game_modes.gd")
const Rules = preload("res://scripts/game_modes_rules.gd")

var _failures: Array[String] = []
var _records: Array = []
var _packed_abs: String = ""
var _backup_abs: String = ""


func _initialize() -> void:
    call_deferred("_run")


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures.append(message)
    push_error("MODE_DATA_ERROR: " + message)


func _error_snapshot(gm) -> Dictionary:
    return {
        "screen": String(gm.get("screen")),
        "title": String(gm.title_label.text) if gm.title_label != null else "",
        "subtitle": String(gm.subtitle_label.text) if gm.subtitle_label != null else "",
        "rules_error": String(gm.get("rules_error")),
        "visible": bool(gm.visible),
        "paused": paused,
    }


func _run() -> void:
    _packed_abs = ProjectSettings.globalize_path("res://data/game_modes.json")
    _backup_abs = _packed_abs + ".hardened_test_bak"
    if not FileAccess.file_exists(_packed_abs):
        _check(false, "packed game_modes.json not found: " + _packed_abs)
        return _finish()
    _check(not Rules.load_rules().is_empty(), "baseline rules should load")

    var directory: DirAccess = DirAccess.open(_packed_abs.get_base_dir())
    if directory == null:
        _check(false, "cannot open data directory")
        return _finish()
    var move_error: Error = directory.rename(
        _packed_abs.get_file(), _backup_abs.get_file()
    )
    if move_error != OK:
        _check(false, "could not move game_modes.json aside: %d" % move_error)
        return _finish()
    _check(FileAccess.file_exists(_backup_abs), "backup file must exist")
    _check(not FileAccess.file_exists(_packed_abs), "packed file must be gone")
    _check(Rules.load_rules().is_empty(),
            "Rules.load_rules() must be empty with packed + sidecar absent")

    var initial = GameModes.new()
    initial.configure(null, {})
    root.add_child(initial)
    _check(initial.data.is_empty(), "fresh mode UI starts with empty data")
    initial.open_initial()
    var snapshot: Dictionary = _error_snapshot(initial)
    _records.append({"entry": "open_initial", "state": snapshot})
    _check(snapshot["screen"] == "error",
            "open_initial must show the error screen, got " + snapshot["screen"])
    _check(String(snapshot["title"]).contains("MODE DATA ERROR"),
            "title must be MODE DATA ERROR, got: " + String(snapshot["title"]))
    _check(String(snapshot["rules_error"]).contains("missing or invalid"),
            "rules_error must name the absent data: " + String(snapshot["rules_error"]))
    _check(bool(snapshot["paused"]) == true,
            "the error screen must pause input so the menu cannot be entered")

    var open_mode_ui = GameModes.new()
    open_mode_ui.configure(null, {})
    root.add_child(open_mode_ui)
    open_mode_ui.open_mode("arcade")
    var mode_snapshot: Dictionary = _error_snapshot(open_mode_ui)
    _records.append({"entry": "open_mode(arcade)", "state": mode_snapshot})
    _check(mode_snapshot["screen"] == "error",
            "open_mode must show the error screen, got " + mode_snapshot["screen"])
    _check(String(mode_snapshot["title"]).contains("MODE DATA ERROR"),
            "open_mode title must be MODE DATA ERROR")
    return _finish()


func _finish() -> void:
    var restored: bool = false
    if not _backup_abs.is_empty() and FileAccess.file_exists(_backup_abs):
        var directory: DirAccess = DirAccess.open(_backup_abs.get_base_dir())
        if directory != null:
            restored = directory.rename(
                _backup_abs.get_file(), _packed_abs.get_file()
            ) == OK
    var packed_present: bool = FileAccess.file_exists(_packed_abs)
    var rules_after: int = Rules.load_rules().size()
    print("MODE_DATA_ERROR_UI=" + JSON.stringify({
        "records": _records,
        "failures": _failures,
        "restored": restored,
        "packed_present_after": packed_present,
        "rules_keys_after": rules_after,
    }))
    if not restored or not packed_present or rules_after == 0:
        print("MODE_DATA_ERROR_UI_RESTORE_FAILED")
        quit(1)
        return
    if _failures.is_empty():
        print("MODE_DATA_ERROR_UI_OK")
        quit(0)
    else:
        print("MODE_DATA_ERROR_UI_FAILED=" + str(_failures.size()))
        quit(1)

extends SceneTree
## Prove the packaged-models opt-in is narrow and still fail-closed by default.
##
##   <godot> --headless --path godot \
##       --script res://tests/validate_package_models_opt_in.gd
##
## The test creates <repository root>/models/_opt_in_probe.glb (a tiny placeholder
## that only has to exist with the .glb extension), then removes it again.  It
## checks that:
##  - without BRUCELEE_ALLOW_PACKAGE_MODELS=1 the path is still rejected as
##    "outside the repository" (the previous behavior, unchanged)
##  - with the flag, exactly <root>/models/*.glb is accepted
##  - a non-.glb file, a file outside models/, and a missing file stay rejected
##    even with the flag on

const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")

var _failures: Array[String] = []
var _checks: Array = []
var _probe_path: String = ""
var _text_path: String = ""
var _models_dir: String = ""


func _initialize() -> void:
    call_deferred("_run")


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures.append(message)
    push_error("PACKAGE_MODELS_OPT_IN: " + message)


func _write_probe(path: String) -> bool:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_buffer(PackedByteArray([0x67, 0x6C, 0x54, 0x46]))
    file.close()
    return true


func _record(label: String, path: String, error: String) -> void:
    _checks.append({"check": label, "path": path, "error": error})


func _run() -> void:
    var root: String = CandidatePathGuard.repository_root()
    _models_dir = root.path_join("models")
    _probe_path = _models_dir.path_join("_opt_in_probe.glb")
    _text_path = _models_dir.path_join("_opt_in_probe.txt")
    DirAccess.make_dir_recursive_absolute(_models_dir)
    if not _check_probe(_probe_path) or not _check_probe(_text_path):
        return _finish()

    OS.set_environment("BRUCELEE_ALLOW_PACKAGE_MODELS", "")
    var default_error: String = CandidatePathGuard.external_path_error(
        _probe_path, "candidate path"
    )
    _record("default guard rejects models/ without the opt-in", _probe_path, default_error)
    _check(not default_error.is_empty(),
            "default guard must reject <root>/models/*.glb: " + default_error)
    _check(default_error.contains("outside the repository"),
            "default rejection should be the repository rule: " + default_error)

    OS.set_environment("BRUCELEE_ALLOW_PACKAGE_MODELS", "1")
    var opt_in_error: String = CandidatePathGuard.external_path_error(
        _probe_path, "candidate path"
    )
    _record("opt-in accepts <root>/models/*.glb", _probe_path, opt_in_error)
    _check(opt_in_error.is_empty(), "opt-in should accept the probe: " + opt_in_error)

    var text_error: String = CandidatePathGuard.external_path_error(
        _text_path, "candidate path"
    )
    _record("opt-in rejects a non-.glb file", _text_path, text_error)
    _check(not text_error.is_empty(), "a non-.glb file must stay rejected")

    var outside_path: String = root.path_join("_opt_in_probe.glb")
    if _check_probe(outside_path):
        var outside_error: String = CandidatePathGuard.external_path_error(
            outside_path, "candidate path"
        )
        _record("opt-in rejects a file outside models/", outside_path, outside_error)
        _check(not outside_error.is_empty(),
                "a .glb outside models/ must stay rejected")
        DirAccess.remove_absolute(outside_path)

    var missing_path: String = _models_dir.path_join("_missing_probe.glb")
    var missing_error: String = CandidatePathGuard.external_path_error(
        missing_path, "candidate path"
    )
    _record("opt-in rejects a missing file", missing_path, missing_error)
    _check(not missing_error.is_empty(), "a missing file must stay rejected")

    return _finish()


func _check_probe(path: String) -> bool:
    if _write_probe(path):
        return true
    _check(false, "could not create probe file: " + path)
    return false


func _finish() -> void:
    OS.set_environment("BRUCELEE_ALLOW_PACKAGE_MODELS", "")
    if not _probe_path.is_empty() and FileAccess.file_exists(_probe_path):
        DirAccess.remove_absolute(_probe_path)
    if not _text_path.is_empty() and FileAccess.file_exists(_text_path):
        DirAccess.remove_absolute(_text_path)
    if not _models_dir.is_empty() and DirAccess.dir_exists_absolute(_models_dir):
        # Only remove the directory if this test left it empty.
        var entries: PackedStringArray = DirAccess.get_files_at(_models_dir)
        var dirs: PackedStringArray = DirAccess.get_directories_at(_models_dir)
        if entries.is_empty() and dirs.is_empty():
            DirAccess.remove_absolute(_models_dir)
    print("PACKAGE_MODELS_OPT_IN=" + JSON.stringify({
        "repository_root": CandidatePathGuard.repository_root(),
        "checks": _checks,
        "failures": _failures,
    }))
    if _failures.is_empty():
        print("PACKAGE_MODELS_OPT_IN_OK")
        quit(0)
    else:
        print("PACKAGE_MODELS_OPT_IN_FAILED=" + str(_failures.size()))
        quit(1)

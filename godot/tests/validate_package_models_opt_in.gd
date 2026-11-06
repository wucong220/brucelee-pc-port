extends SceneTree
## Prove the packaged-models opt-in is narrow, SHA-pinned and fail-closed.
##
## The opt-in no longer accepts "a .glb that exists": it requires the file's
## SHA-256 to equal a pin declared in the packed candidate manifest.  This test
## copies a real pinned model into <repository root>/models, checks the paths,
## and removes it again.
##
##   HARDENED_REAL_MODEL=<package>/models/brick_full_94_20261103.glb \
##   <godot> --headless --path godot \
##       --script res://tests/validate_package_models_opt_in.gd
##
## Checks:
##  - without BRUCELEE_ALLOW_PACKAGE_MODELS=1 the pinned model is still rejected
##    as "outside the repository" (previous behavior, unchanged)
##  - with the flag, the pinned model under <root>/models/*.glb is accepted
##  - with the flag, an existing but UNPINNED .glb is rejected (not existence-only)
##  - a non-.glb file, a file outside models/, and a missing file stay rejected

const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")

var _failures: Array[String] = []
var _checks: Array = []
var _models_dir: String = ""
var _copied: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures.append(message)
    push_error("PACKAGE_MODELS_OPT_IN: " + message)


func _record(label: String, path: String, error: String) -> void:
    _checks.append({"check": label, "path": path, "error": error})


func _copy(source: String, target: String) -> bool:
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(source)
    if bytes.is_empty():
        return false
    var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
    if file == null:
        return false
    file.store_buffer(bytes)
    file.close()
    _copied.append(target)
    return true


func _write_probe(path: String, bytes: PackedByteArray) -> bool:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_buffer(bytes)
    file.close()
    _copied.append(path)
    return true


func _run() -> void:
    var root: String = CandidatePathGuard.repository_root()
    _models_dir = root.path_join("models")
    DirAccess.make_dir_recursive_absolute(_models_dir)
    var real_model: String = OS.get_environment("HARDENED_REAL_MODEL").strip_edges()
    if real_model.is_empty() or not FileAccess.file_exists(real_model):
        _check(false, "HARDENED_REAL_MODEL must point at a real pinned GLB")
        return _finish()
    var name: String = real_model.get_file()
    var pinned_path: String = _models_dir.path_join(name)
    if not _copy(real_model, pinned_path):
        _check(false, "could not stage the pinned model")
        return _finish()

    OS.set_environment("BRUCELEE_ALLOW_PACKAGE_MODELS", "")
    var default_error: String = CandidatePathGuard.external_path_error(pinned_path, "candidate path")
    _record("default guard rejects models/ without the opt-in", pinned_path, default_error)
    _check(not default_error.is_empty(), "default guard must reject <root>/models/*.glb")
    _check(default_error.contains("outside the repository"),
            "default rejection should be the repository rule: " + default_error)

    OS.set_environment("BRUCELEE_ALLOW_PACKAGE_MODELS", "1")
    var opt_in_error: String = CandidatePathGuard.external_path_error(pinned_path, "candidate path")
    _record("opt-in accepts a SHA-pinned <root>/models/*.glb", pinned_path, opt_in_error)
    _check(opt_in_error.is_empty(), "opt-in should accept the pinned model: " + opt_in_error)

    # Existing but not in the manifest -> no pin -> must be rejected.
    var unpinned_path: String = _models_dir.path_join("_opt_in_unpinned.glb")
    if _write_probe(unpinned_path, PackedByteArray([0x67, 0x6C, 0x54, 0x46])):
        var unpinned_error: String = CandidatePathGuard.external_path_error(
            unpinned_path, "candidate path")
        _record("opt-in rejects an existing but unpinned .glb", unpinned_path, unpinned_error)
        _check(not unpinned_error.is_empty(),
                "an existing .glb with no manifest pin must stay rejected")

    # Non-.glb stays rejected.
    var text_path: String = _models_dir.path_join("_opt_in_probe.txt")
    if _write_probe(text_path, PackedByteArray([0x78])):
        var text_error: String = CandidatePathGuard.external_path_error(text_path, "candidate path")
        _record("opt-in rejects a non-.glb file", text_path, text_error)
        _check(not text_error.is_empty(), "a non-.glb file must stay rejected")

    # A pinned-named file OUTSIDE models/ stays rejected by the opt-in.
    var outside_path: String = root.path_join(name)
    if _copy(real_model, outside_path):
        var outside_error: String = CandidatePathGuard.external_path_error(outside_path, "candidate path")
        _record("opt-in rejects the model outside models/", outside_path, outside_error)
        _check(not outside_error.is_empty(), "a .glb outside models/ must stay rejected")

    # Missing file stays rejected.
    var missing_path: String = _models_dir.path_join("_missing_.glb")
    var missing_error: String = CandidatePathGuard.external_path_error(missing_path, "candidate path")
    _record("opt-in rejects a missing file", missing_path, missing_error)
    _check(not missing_error.is_empty(), "a missing file must stay rejected")

    return _finish()


func _finish() -> void:
    OS.set_environment("BRUCELEE_ALLOW_PACKAGE_MODELS", "")
    for path: String in _copied:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)
    if not _models_dir.is_empty() and DirAccess.dir_exists_absolute(_models_dir):
        var files: PackedStringArray = DirAccess.get_files_at(_models_dir)
        var dirs: PackedStringArray = DirAccess.get_directories_at(_models_dir)
        if files.is_empty() and dirs.is_empty():
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

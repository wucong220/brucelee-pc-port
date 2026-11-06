extends SceneTree
## Fail-closed proof for the hardened candidate path guard.
##
## A path SPELLED under the package root is accepted only when its RESOLVED
## location (junctions/symlinks followed by the OS) stays inside the package
## root.  A directory junction that escapes is rejected; a missing file is
## rejected.  A local file that is genuinely outside the root AND outside the
## repository remains a permitted external asset.
##
## Fixture (created by run_hardened_tests.ps1 under HARDENED_FIXTURE):
##   <fixture>/pkg/content/ok.txt
##   <fixture>/pkg/escape_dir      (junction -> <fixture>/outside)
##   <fixture>/outside/secret.txt
## The fixture root deliberately lives OUTSIDE the Godot project's repository
## root, so the "external asset" case is not confused with "inside repo".
##
##   HARDENED_FIXTURE=<fixture> <godot> --headless --path godot \
##       --script res://tests/validate_hardened_path_guard.gd

const Guard = preload("res://scripts/candidate_path_guard.gd")

var _failures: Array[String] = []
var _records: Array = []


func _initialize() -> void:
    call_deferred("_run")


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures.append(message)
    push_error("PATH_GUARD: " + message)


func _record(label: String, path: String, error: String) -> void:
    _records.append({"check": label, "path": path, "error": error})


func _run() -> void:
    var fixture: String = OS.get_environment("HARDENED_FIXTURE").strip_edges()
    if fixture.is_empty():
        _check(false, "HARDENED_FIXTURE is not set")
        return _finish()
    var pkg: String = fixture.path_join("pkg")
    OS.set_environment("BRUCELEE_PACKAGE_ROOT", pkg)
    Guard._canonical_cache.clear()
    Guard._canonical_dir_cache.clear()
    Guard._model_pins_cache.clear()

    var ok_path: String = pkg.path_join("content/ok.txt")
    var escape_path: String = pkg.path_join("escape_dir/secret.txt")
    var missing_path: String = pkg.path_join("nope.txt")
    var outside_path: String = fixture.path_join("outside/secret.txt")
    var root_itself: String = pkg

    var ok_error: String = Guard.external_path_error(ok_path, "candidate")
    _record("file under package root accepted", ok_path, ok_error)
    _check(ok_error.is_empty(), "real file under package root must be accepted: " + ok_error)

    var escape_error: String = Guard.external_path_error(escape_path, "candidate")
    _record("junction escaping package root rejected", escape_path, escape_error)
    _check(not escape_error.is_empty(), "junction escape must be rejected")
    _check(escape_error.contains("package path rejected"),
            "junction escape must fail closed as a package-path rejection: " + escape_error)

    var missing_error: String = Guard.external_path_error(missing_path, "candidate")
    _record("missing file under package root rejected", missing_path, missing_error)
    _check(not missing_error.is_empty(), "missing file under package root must be rejected")

    var outside_error: String = Guard.external_path_error(outside_path, "candidate")
    _record("external asset outside root and repo accepted", outside_path, outside_error)
    _check(outside_error.is_empty(),
            "an existing external asset outside root+repo must stay accepted: " + outside_error)

    var root_error: String = Guard.package_asset_error(root_itself)
    _record("package root itself is not a package asset", root_itself, root_error)
    _check(not root_error.is_empty(),
            "the package root path itself must not be classified as a package asset")

    # Directly prove the resolver follows the junction (this is the difference
    # between a lexical prefix check and a real canonical-containment check).
    var pkg_canonical: Dictionary = Guard.canonical_path(pkg)
    var escape_canonical: Dictionary = Guard.canonical_path(escape_path)
    var resolver_ok: bool = (
        String(pkg_canonical["error"]).is_empty()
        and String(escape_canonical["error"]).is_empty()
    )
    var escape_resolved_outside: bool = false
    var escape_canonical_text: String = ""
    if resolver_ok:
        var root_text: String = String(pkg_canonical["path"]).to_lower().trim_suffix("/")
        escape_canonical_text = String(escape_canonical["path"]).to_lower()
        escape_resolved_outside = not escape_canonical_text.begins_with(root_text + "/")
    _records.append({
        "check": "resolver follows the junction",
        "package_canonical": String(pkg_canonical["path"]),
        "escape_canonical": escape_canonical_text,
        "resolver_ok": resolver_ok,
        "escape_resolved_outside": escape_resolved_outside,
    })
    _check(resolver_ok, "canonical resolver must succeed on both paths")
    _check(escape_resolved_outside,
            "canonical resolver must report the junction target outside the root")

    # With no package root designated the same path stops being a package asset.
    OS.set_environment("BRUCELEE_PACKAGE_ROOT", "")
    _check(not Guard.is_package_asset(ok_path),
            "without a designated package root nothing is a package asset")
    return _finish()


func _finish() -> void:
    OS.set_environment("BRUCELEE_PACKAGE_ROOT", "")
    print("HARDENED_PATH_GUARD=" + JSON.stringify({
        "records": _records,
        "failures": _failures,
    }))
    if _failures.is_empty():
        print("HARDENED_PATH_GUARD_OK")
        quit(0)
    else:
        print("HARDENED_PATH_GUARD_FAILED=" + str(_failures.size()))
        quit(1)

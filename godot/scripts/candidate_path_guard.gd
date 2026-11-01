extends RefCounted
## Validate local candidate inputs without allowing packaged copies.


const RESOLVER_RESOURCE: String = "res://tools/resolve_candidate_path.ps1"

static var _runtime_resolver_path: String = ""
static var _runtime_resolver_error: String = ""


static func normalize_absolute_path(path: String) -> String:
    return path.replace("\\", "/").simplify_path()


static func repository_root() -> String:
    if OS.has_feature("template"):
        return normalize_absolute_path(
            OS.get_executable_path().get_base_dir()
        ).trim_suffix("/")
    var project_directory: String = normalize_absolute_path(
        ProjectSettings.globalize_path("res://")
    ).trim_suffix("/")
    if (project_directory.is_empty()
            or not project_directory.is_absolute_path()):
        return normalize_absolute_path(
            OS.get_executable_path().get_base_dir()
        ).trim_suffix("/")
    return normalize_absolute_path(project_directory.get_base_dir())


static func windows_resolver_path() -> Dictionary:
    if not _runtime_resolver_error.is_empty():
        return {"path": "", "error": _runtime_resolver_error}
    if not _runtime_resolver_path.is_empty():
        return {"path": _runtime_resolver_path, "error": ""}
    var source: FileAccess = FileAccess.open(RESOLVER_RESOURCE, FileAccess.READ)
    if source == null:
        _runtime_resolver_error = (
            "packed candidate path resolver is missing: " + RESOLVER_RESOURCE
        )
        return {"path": "", "error": _runtime_resolver_error}
    var source_text: String = source.get_as_text()
    source.close()
    if source_text.is_empty():
        _runtime_resolver_error = "packed candidate path resolver is empty"
        return {"path": "", "error": _runtime_resolver_error}
    var resolver_path: String = normalize_absolute_path(
        ProjectSettings.globalize_path("user://candidate_path_resolver.ps1")
    )
    var target: FileAccess = FileAccess.open(resolver_path, FileAccess.WRITE)
    if target == null:
        _runtime_resolver_error = (
            "could not materialize candidate path resolver: " + resolver_path
        )
        return {"path": "", "error": _runtime_resolver_error}
    target.store_string(source_text)
    target.close()
    if not FileAccess.file_exists(resolver_path):
        _runtime_resolver_error = (
            "candidate path resolver was not materialized: " + resolver_path
        )
        return {"path": "", "error": _runtime_resolver_error}
    _runtime_resolver_path = resolver_path
    return {"path": resolver_path, "error": ""}


static func canonical_path(path: String) -> Dictionary:
    var normalized_path: String = normalize_absolute_path(path)
    var output: Array = []
    var exit_code: int
    if OS.get_name() == "Windows":
        var resolver_result: Dictionary = windows_resolver_path()
        if not resolver_result["error"].is_empty():
            return resolver_result
        var resolver_path: String = String(resolver_result["path"])
        exit_code = OS.execute(
            "powershell.exe",
            PackedStringArray([
                "-NoLogo",
                "-NoProfile",
                "-NonInteractive",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                resolver_path,
                "-LiteralPath",
                normalized_path,
            ]),
            output,
            true,
            false,
        )
    else:
        exit_code = OS.execute(
            "python3",
            PackedStringArray([
                "-c",
                "import os, sys; print(os.path.realpath(sys.argv[1]))",
                normalized_path,
            ]),
            output,
            true,
            false,
        )
    var lines: PackedStringArray = PackedStringArray(output)
    if exit_code != 0:
        var detail: String = "\n".join(lines).strip_edges()
        if detail.is_empty():
            detail = "path resolver exited with code %d" % exit_code
        return {"path": "", "error": detail}
    var resolved_line: String = ""
    for line: String in lines:
        var candidate: String = line.strip_edges()
        if not candidate.is_empty():
            resolved_line = candidate
    if resolved_line.is_empty():
        return {"path": "", "error": "path resolver returned an empty result"}
    var resolved_path: String = normalize_absolute_path(resolved_line)
    if (not resolved_path.is_absolute_path()
            or resolved_path.begins_with("//")
            or resolved_path.contains("://")):
        return {"path": "", "error": "path resolver returned a non-local path"}
    return {"path": resolved_path, "error": ""}


static func external_path_error(path: String, label: String) -> String:
    var normalized_path: String = normalize_absolute_path(path)
    if (not normalized_path.is_absolute_path()
            or normalized_path.begins_with("//")
            or normalized_path.contains("://")):
        return label + " must be an absolute local path"
    var lexical_root: String = repository_root().to_lower()
    var lexical_path: String = normalized_path.to_lower()
    if (lexical_path == lexical_root
            or lexical_path.begins_with(lexical_root + "/")):
        return label + " must remain outside the repository"
    var root_result: Dictionary = canonical_path(repository_root())
    if not root_result["error"].is_empty():
        return label + " repository root could not be resolved: " + root_result["error"]
    var path_result: Dictionary = canonical_path(normalized_path)
    if not path_result["error"].is_empty():
        return label + " could not be resolved: " + path_result["error"]
    var root: String = String(root_result["path"]).to_lower()
    var compared_path: String = String(path_result["path"]).to_lower()
    if compared_path == root or compared_path.begins_with(root + "/"):
        return label + " must remain outside the repository"
    return ""

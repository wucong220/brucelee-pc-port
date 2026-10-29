extends RefCounted
## Validate local candidate inputs without allowing repository copies.


static func normalize_absolute_path(path: String) -> String:
    return path.replace("\\", "/").simplify_path()


static func repository_root() -> String:
    var project_directory: String = normalize_absolute_path(
        ProjectSettings.globalize_path("res://")
    ).trim_suffix("/")
    return normalize_absolute_path(project_directory.get_base_dir())


static func canonical_path(path: String) -> Dictionary:
    var normalized_path: String = normalize_absolute_path(path)
    var output: Array = []
    var exit_code: int
    if OS.get_name() == "Windows":
        var resolver_path: String = repository_root().path_join(
            "tools/resolve_candidate_path.ps1"
        )
        if not FileAccess.file_exists(resolver_path):
            return {
                "path": "",
                "error": "candidate path resolver is missing: " + resolver_path,
            }
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

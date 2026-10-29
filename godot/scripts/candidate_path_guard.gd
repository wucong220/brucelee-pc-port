extends RefCounted
## Validate local candidate inputs without allowing repository copies.


static func normalize_absolute_path(path: String) -> String:
    return path.replace("\\", "/").simplify_path()


static func repository_root() -> String:
    var project_directory: String = normalize_absolute_path(
        ProjectSettings.globalize_path("res://")
    ).trim_suffix("/")
    return normalize_absolute_path(project_directory.get_base_dir())


static func external_path_error(path: String, label: String) -> String:
    var normalized_path: String = normalize_absolute_path(path)
    if (not normalized_path.is_absolute_path()
            or normalized_path.begins_with("//")
            or normalized_path.contains("://")):
        return label + " must be an absolute local path"
    var root: String = repository_root().to_lower()
    var compared_path: String = normalized_path.to_lower()
    if compared_path == root or compared_path.begins_with(root + "/"):
        return label + " must remain outside the repository"
    return ""

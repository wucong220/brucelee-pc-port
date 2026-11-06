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
    var exit_code: int = -1
    if OS.get_name() == "Windows":
        var resolver_result: Dictionary = windows_resolver_path()
        if resolver_result["error"].is_empty():
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
        if exit_code != 0:
            # Strict realpath retains the normal resolver's fail-closed
            # canonicalization when PowerShell/Add-Type is unavailable.
            output.clear()
            exit_code = OS.execute(
                "python",
                PackedStringArray([
                    "-c",
                    "import os, sys; print(os.path.realpath(sys.argv[1], strict=True))",
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


## Canonical (real-path) forms, cached by input.  Failures are NOT cached so a
## transient resolver problem can recover.
static var _canonical_cache: Dictionary = {}       # full path -> resolved
static var _canonical_dir_cache: Dictionary = {}    # directory -> resolved
## basename(lower) -> pinned sha256(lower) read from the packed manifest.
static var _model_pins_cache: Dictionary = {}


static func canonical_path_cached(path: String) -> Dictionary:
    var key: String = normalize_absolute_path(path).to_lower()
    if _canonical_cache.has(key):
        return Dictionary(_canonical_cache[key])
    var result: Dictionary = canonical_path(path)
    if String(result["error"]).is_empty():
        _canonical_cache[key] = result
    return result


static func _canonical_dir_cached(path: String) -> Dictionary:
    ## Resolving a DIRECTORY follows junctions/symlinks for every component.
    ## Cached per directory so a run that validates many files in the same
    ## folder pays one resolver call, not one per file.
    var key: String = normalize_absolute_path(path).trim_suffix("/").to_lower()
    if _canonical_dir_cache.has(key):
        return Dictionary(_canonical_dir_cache[key])
    var result: Dictionary = canonical_path(path)
    if String(result["error"]).is_empty():
        _canonical_dir_cache[key] = result
    return result


static func canonical_containment_error(candidate: String, root: String) -> String:
    ## Strict RESOLVED containment.  The package root and the candidate's
    ## DIRECTORY are resolved through the OS (GetFinalPathNameByHandleW via
    ## tools/resolve_candidate_path.ps1), which follows directory junctions.
    ## The resolved location must stay strictly inside the resolved root: a
    ## lexical prefix or "the file exists" is explicitly NOT sufficient.
    ## .glb model files are additionally resolved in full (a file-level reparse
    ## point is thereby caught for models).  Non-model files inherit their
    ## directory's resolution; see the limitations matrix for that boundary.
    var root_result: Dictionary = _canonical_dir_cached(root)
    if not String(root_result["error"]).is_empty():
        return "root could not be resolved: " + String(root_result["error"])
    var root_canonical: String = String(root_result["path"]).trim_suffix("/").to_lower()
    if root_canonical.is_empty():
        return "root did not resolve"

    var is_dir: bool = DirAccess.dir_exists_absolute(candidate)
    var leaf: String = "" if is_dir else candidate.get_file()
    var directory: String = candidate if is_dir else candidate.get_base_dir()
    var dir_result: Dictionary = _canonical_dir_cached(directory)
    if not String(dir_result["error"]).is_empty():
        return "candidate directory could not be resolved: " + String(dir_result["error"])
    var resolved: String = String(dir_result["path"]).trim_suffix("/")
    if not leaf.is_empty():
        resolved = resolved.path_join(leaf)

    if not is_dir and candidate.get_extension().to_lower() == "glb":
        var file_result: Dictionary = canonical_path_cached(candidate)
        if not String(file_result["error"]).is_empty():
            return "candidate could not be resolved: " + String(file_result["error"])
        resolved = String(file_result["path"])

    var candidate_canonical: String = resolved.trim_suffix("/").to_lower()
    if candidate_canonical.is_empty():
        return "candidate did not resolve"
    if candidate_canonical == root_canonical:
        return "candidate is the package root itself"
    if not candidate_canonical.begins_with(root_canonical + "/"):
        return "candidate resolves outside the package root"
    return ""


static func _sha256_file(path: String) -> String:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return ""
    var hashing: HashingContext = HashingContext.new()
    hashing.start(HashingContext.HASH_SHA256)
    var remaining: int = file.get_length()
    while remaining > 0:
        var chunk: PackedByteArray = file.get_buffer(mini(remaining, 1 << 20))
        if chunk.is_empty():
            break
        hashing.update(chunk)
        remaining -= chunk.size()
    file.close()
    return hashing.finish().hex_encode()


static func _packed_model_pins() -> Dictionary:
    ## basename -> sha256 for every candidate row declared in the packed
    ## manifest.  Used to reject a packaged GLB whose bytes were swapped or
    ## corrupted, instead of accepting it for merely existing.
    if not _model_pins_cache.is_empty():
        return _model_pins_cache
    var file: FileAccess = FileAccess.open(
        "res://data/candidate_package_models.json", FileAccess.READ
    )
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not parsed is Dictionary:
        return {}
    var out: Dictionary = {}
    for row_value: Variant in Dictionary(parsed).get("candidates", []):
        if not row_value is Dictionary:
            continue
        var row: Dictionary = row_value
        var package_path: String = String(row.get("package", "")).replace("\\", "/")
        var sha: String = String(row.get("sha256", "")).strip_edges().to_lower()
        if package_path.is_empty() or sha.is_empty():
            continue
        out[package_path.get_file().to_lower()] = sha
    _model_pins_cache = out
    return out


static func packaged_models_opt_in(path: String) -> bool:
    ## Narrow, explicit exception for a package that ships a first-party
    ## models/ directory next to the executable (needed by editor/CI where the
    ## package root is not the executable directory).  Beyond the flag,
    ## extension and existence it REQUIRES the GLB SHA-256 to equal a pin in the
    ## packed manifest, and the resolved path to stay inside <root>/models.
    if OS.get_environment("BRUCELEE_ALLOW_PACKAGE_MODELS") != "1":
        return false
    var normalized: String = normalize_absolute_path(path)
    if normalized.get_extension().to_lower() != "glb":
        return false
    var models_root: String = repository_root().path_join("models")
    if not normalized.to_lower().begins_with(models_root.to_lower() + "/"):
        return false
    if not FileAccess.file_exists(normalized):
        return false
    if not canonical_containment_error(normalized, models_root).is_empty():
        return false
    var pins: Dictionary = _packed_model_pins()
    var name: String = normalized.get_file().to_lower()
    if not pins.has(name):
        return false
    var actual: String = _sha256_file(normalized)
    return not actual.is_empty() and actual == String(pins[name]).to_lower()


static func executable_root() -> String:
    return normalize_absolute_path(
        OS.get_executable_path().get_base_dir()
    ).trim_suffix("/")


static func package_asset_root() -> String:
    ## Explicit package root first: BRUCELEE_PACKAGE_ROOT is how a validator
    ## designates the staged package.  Otherwise an exported build uses the
    ## executable directory (which IS the package root there).  Editor/CI runs
    ## without BRUCELEE_PACKAGE_ROOT return "" so the original fail-closed
    ## candidate rules still apply unchanged.
    var configured: String = OS.get_environment("BRUCELEE_PACKAGE_ROOT").strip_edges()
    if not configured.is_empty():
        return normalize_absolute_path(configured).trim_suffix("/")
    if OS.has_feature("template"):
        return executable_root()
    return ""


static func package_asset_error(path: String) -> String:
    ## "" only when `path` is an existing file/dir whose RESOLVED location is
    ## strictly inside the designated package root.  This replaces the previous
    ## "any existing path under the root is accepted" shortcut.
    var root: String = package_asset_root()
    if root.is_empty():
        return "no package root is designated"
    var normalized: String = normalize_absolute_path(path)
    if (not normalized.is_absolute_path()
            or normalized.begins_with("//")
            or normalized.contains("://")):
        return "candidate must be an absolute local path"
    if not normalized.to_lower().begins_with(root.to_lower() + "/"):
        return "candidate is lexically outside the package root"
    if (not FileAccess.file_exists(normalized)
            and not DirAccess.dir_exists_absolute(normalized)):
        return "candidate does not exist under the package root"
    return canonical_containment_error(normalized, root)


static func is_package_asset(path: String) -> bool:
    return package_asset_error(path).is_empty()


static func external_path_error(path: String, label: String) -> String:
    var normalized_path: String = normalize_absolute_path(path)
    if (not normalized_path.is_absolute_path()
            or normalized_path.begins_with("//")
            or normalized_path.contains("://")):
        return label + " must be an absolute local path"
    if packaged_models_opt_in(normalized_path):
        return ""
    var package_error: String = package_asset_error(normalized_path)
    if package_error.is_empty():
        return ""
    # A path spelled under the package root but failing resolved containment
    # (junction/symlink escape, missing file, non-canonical form) MUST fail
    # closed here; it must never fall through to the "exists outside the
    # repository" branch, which would otherwise re-admit an escaping junction.
    var package_root: String = package_asset_root()
    if (not package_root.is_empty()
            and normalized_path.to_lower().begins_with(
                package_root.to_lower() + "/")):
        return label + " package path rejected: " + package_error
    var lexical_root: String = repository_root().to_lower()
    var lexical_path: String = normalized_path.to_lower()
    if (lexical_path == lexical_root
            or lexical_path.begins_with(lexical_root + "/")):
        return label + " must remain outside the repository"
    if (not FileAccess.file_exists(normalized_path)
            and not DirAccess.dir_exists_absolute(normalized_path)):
        return label + " does not exist: " + normalized_path
    var root_result: Dictionary = canonical_path_cached(repository_root())
    if not root_result["error"].is_empty():
        return label + " repository root could not be resolved: " + root_result["error"]
    var path_result: Dictionary = canonical_path_cached(normalized_path)
    if not path_result["error"].is_empty():
        return label + " could not be resolved: " + path_result["error"]
    var root: String = String(root_result["path"]).to_lower()
    var compared_path: String = String(path_result["path"]).to_lower()
    if compared_path == root or compared_path.begins_with(root + "/"):
        return label + " must remain outside the repository"
    return ""

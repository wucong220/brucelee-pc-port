extends SceneTree
## Validate the stable package model layout and its wiring in main.gd.
##
## Pure data check (headless): reads godot/data/candidate_package_models.json,
## re-derives every identity field from the GLB itself and compares it with
## MENU_OPPONENT_CONFIG / PLAYER_SKIN_CONFIG.  It never instantiates a scene.
##
##   set BRUCELEE_PACKAGE_ROOT=<dir holding models/>
##   <godot> --headless --path godot \
##       --script res://tests/validate_candidate_package_manifest.gd
##
## Checks:
##  - the manifest lists exactly the ten candidates and every package file
##    exists with the pinned byte size + SHA-256
##  - GLB JSON agrees with the manifest: skeleton SHA-256, mesh names, animation
##    count, embedded textures, and the expected idle clip is present
##  - each opponent candidate is declared by the same MENU_OPPONENT_CONFIG entry
##    (glb_package, sha256, attack_config, clip_prefix, master, material_profile)
##  - the Chief/Lo Ming variants live under that entry's "skins" table
##  - only the four Bruce Lee skins appear in PLAYER_SKIN_CONFIG and no opponent
##    model is offered as a player skin (fail closed on character/set mismatch)
##  - the previous absolute "glb" fallback is preserved in the config

const MANIFEST_PATH: String = "res://data/candidate_package_models.json"
const MAIN_SCRIPT_PATH: String = "res://scripts/main.gd"

var _failures: Array[String] = []
var _cases: Array = []
var _config: Dictionary = {}
var _player_skins: Dictionary = {}


func _initialize() -> void:
    call_deferred("_run")


func _check(condition: bool, message: String) -> bool:
    if condition:
        return true
    _failures.append(message)
    push_error("CANDIDATE_PACKAGE_MANIFEST: " + message)
    return false


func _package_root() -> String:
    var configured: String = OS.get_environment("BRUCELEE_PACKAGE_ROOT").strip_edges()
    if configured.is_empty():
        return OS.get_executable_path().get_base_dir().replace("\\", "/").trim_suffix("/")
    return configured.replace("\\", "/").trim_suffix("/")


func _sha256_file(path: String) -> String:
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


func _glb_json(path: String) -> Dictionary:
    ## Reads the JSON chunk of a binary glTF container without importing it.
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var header: PackedByteArray = file.get_buffer(12)
    if header.size() < 12 or header.decode_u32(0) != 0x46546C67:
        file.close()
        return {}
    var chunk_header: PackedByteArray = file.get_buffer(8)
    if chunk_header.size() < 8 or chunk_header.decode_u32(4) != 0x4E4F534A:
        file.close()
        return {}
    var chunk: PackedByteArray = file.get_buffer(chunk_header.decode_u32(0))
    file.close()
    var parsed: Variant = JSON.parse_string(chunk.get_string_from_utf8())
    return parsed if parsed is Dictionary else {}


func _run() -> void:
    var manifest_text: String = FileAccess.get_file_as_string(MANIFEST_PATH)
    var manifest: Variant = JSON.parse_string(manifest_text)
    if not manifest is Dictionary:
        _check(false, "manifest is missing or not JSON: " + MANIFEST_PATH)
        return _finish()
    var data: Dictionary = manifest
    var main_script: Script = load(MAIN_SCRIPT_PATH)
    var consts: Dictionary = main_script.get_script_constant_map()
    _config = consts.get("MENU_OPPONENT_CONFIG", {})
    _player_skins = consts.get("PLAYER_SKIN_CONFIG", {})
    _cases = data.get("candidates", [])
    var models_dir: String = String(consts.get("PACKAGE_MODELS_DIR", "models"))
    var root: String = _package_root()

    _check(int(data.get("schema", 0)) == 1, "manifest schema should be 1")
    _check(String(data.get("package_models_dir", "")) == models_dir,
            "manifest package_models_dir should match PACKAGE_MODELS_DIR")
    _check(_cases.size() == 10, "manifest should list 10 candidates, got %d" % _cases.size())
    _check(_config is Dictionary and _config.size() == 9,
            "MENU_OPPONENT_CONFIG should keep its 9 opponents")
    _check(_player_skins is Dictionary and _player_skins.size() == 4,
            "PLAYER_SKIN_CONFIG should list exactly the four Bruce skins")

    var seen_ids: Dictionary = {}
    var seen_packages: Dictionary = {}
    var opponent_packages: Dictionary = {}
    var player_packages: Dictionary = {}
    for raw: Variant in _cases:
        if not raw is Dictionary:
            _check(false, "manifest candidate is not an object")
            continue
        var case: Dictionary = raw
        var case_id: String = String(case.get("id", ""))
        var package: String = String(case.get("package", ""))
        var role: String = String(case.get("role", ""))
        var label: String = case_id if not case_id.is_empty() else package
        _check(not case_id.is_empty(), "candidate without id")
        _check(not seen_ids.has(case_id), "duplicate candidate id " + case_id)
        _check(not seen_packages.has(package), "duplicate package file " + package)
        seen_ids[case_id] = true
        seen_packages[package] = true
        _check(role in ["player", "opponent"], label + ": role should be player/opponent")
        if role == "player":
            player_packages[package] = true
            _check(String(case.get("character", "")) == "bruce lee",
                    label + ": the only verified player character is bruce lee")
        else:
            opponent_packages[package] = true

        # ---- file identity.
        var path: String = root.path_join(models_dir).path_join(package)
        var exists: bool = FileAccess.file_exists(path)
        _check(exists, label + ": package model is missing: " + path)
        if not exists:
            continue
        var bytes: int = int(FileAccess.open(path, FileAccess.READ).get_length())
        _check(bytes == int(case.get("bytes", -1)),
                label + ": byte size %d != manifest %s" % [bytes, str(case.get("bytes"))])
        _check(_sha256_file(path) == String(case.get("sha256", "")).to_lower(),
                label + ": sha256 does not match the manifest pin")

        # ---- identity re-derived from the GLB JSON chunk.
        var glb: Dictionary = _glb_json(path)
        _check(not glb.is_empty(), label + ": GLB JSON chunk is unreadable")
        if glb.is_empty():
            continue
        var asset: Dictionary = glb.get("asset", {})
        var extras: Dictionary = asset.get("extras", {})
        var animations: Array = glb.get("animations", [])
        var names: Array = []
        for animation: Variant in animations:
            if animation is Dictionary:
                names.append(String(Dictionary(animation).get("name", "")))
        var meshes: Array = []
        for mesh: Variant in glb.get("meshes", []):
            if mesh is Dictionary:
                meshes.append(String(Dictionary(mesh).get("name", "")))
        var expected_idle: String = String(case.get("expected_idle", ""))
        _check(expected_idle in names,
                label + ": GLB has no idle clip " + expected_idle)
        _check(names.size() == int(case.get("animations", -1)),
                label + ": animation count %d != manifest %s" % [
                    names.size(), str(case.get("animations")),
                ])
        _check(String(extras.get("skeletonSha256", "")) == String(
                case.get("skeleton_sha256", "")),
                label + ": skeletonSha256 does not match the manifest")
        _check(_mesh_names_equal(meshes, case.get("mesh_names", [])),
                label + ": mesh names do not match the manifest: " + str(meshes))
        var embedded: bool = not Array(glb.get("images", [])).is_empty()
        _check(embedded == bool(case.get("textures_embedded", false)),
                label + ": embedded-texture flag differs from the GLB")
        var mesh_prefix: String = String(case.get("mesh_prefix", ""))
        if not mesh_prefix.is_empty():
            _check(meshes.size() > 0 and String(meshes[0]).begins_with(mesh_prefix),
                    label + ": mesh prefix mismatch")

        # ---- config wiring.
        var expected_rel: String = models_dir + "\\" + package
        if role == "opponent":
            var menu_entry: String = String(case.get("menu_entry", ""))
            _check(_config.has(menu_entry),
                    label + ": no MENU_OPPONENT_CONFIG entry " + menu_entry)
            if not _config.has(menu_entry):
                continue
            var entry: Dictionary = _config[menu_entry]
            var skin: String = String(case.get("skin", ""))
            if skin.is_empty():
                # Only the entry's default candidate owns the preserved legacy
                # absolute fallback; named variants intentionally have none.
                _check(String(entry.get("glb", ""))
                        == String(case.get("fallback_glb", "")),
                        label + ": previous absolute glb fallback was not preserved")
                _check(FileAccess.file_exists(String(entry.get("glb", "")))
                        == bool(case.get("fallback_exists", false)),
                        label + ": fallback_exists flag differs from the filesystem")
            var source: Dictionary = entry
            if not skin.is_empty():
                var skins: Variant = entry.get("skins")
                _check(skins is Dictionary, label + ": entry has no skins table")
                if not skins is Dictionary:
                    continue
                _check(Dictionary(skins).has(skin),
                        label + ": skins table has no variant " + skin)
                if not Dictionary(skins).has(skin):
                    continue
                source = Dictionary(skins)[skin]
            _check(String(source.get("glb_package", "")) == expected_rel,
                    label + ": glb_package should be " + expected_rel)
            _check(String(source.get("sha256", "")).to_lower()
                    == String(case.get("sha256", "")).to_lower(),
                    label + ": config sha256 pin differs from the manifest")
            _check(String(entry.get("attack_config", ""))
                    == String(case.get("attack_config", "")),
                    label + ": attack_config (fighting set) differs")
            _check(String(source.get("material_profile", ""))
                    == String(case.get("material_profile", "")),
                    label + ": material_profile differs")
            _check(String(entry.get("clip_prefix", ""))
                    == String(case.get("clip_prefix", "")),
                    label + ": clip_prefix differs")
            _check(String(entry.get("master", "")) == String(case.get("master", "")),
                    label + ": master flag differs")
        else:
            var skin_id: String = String(case.get("skin", ""))
            _check(_player_skins.has(skin_id),
                    label + ": PLAYER_SKIN_CONFIG has no " + skin_id)
            if not _player_skins.has(skin_id):
                continue
            var skin_entry: Dictionary = _player_skins[skin_id]
            _check(String(skin_entry.get("glb_package", "")) == expected_rel,
                    label + ": player skin glb_package should be " + expected_rel)
            _check(String(skin_entry.get("sha256", "")).to_lower()
                    == String(case.get("sha256", "")).to_lower(),
                    label + ": player skin sha256 pin differs")
            _check(String(skin_entry.get("material_profile", "")) == "body_hair",
                    label + ": every Bruce skin is body+hair")

    # ---- fail closed: no opponent model may be offered as a player skin.
    for package: Variant in _player_skins:
        var rel: String = String(Dictionary(_player_skins[package]).get(
            "glb_package", ""
        )).replace("/", "\\")
        var base: String = rel.get_file()
        _check(not opponent_packages.has(base),
                "opponent model offered as a player skin: " + base)
        _check(player_packages.has(base),
                "player skin uses an undeclared model: " + base)
    _check(_player_skins.has("skin01") and _player_skins.has("skin04"),
            "the four named Bruce skins should stay skin01..skin04")
    return _finish()


func _mesh_names_equal(actual: Array, declared: Variant) -> bool:
    if not declared is Array:
        return false
    var expected: Array = declared
    if actual.size() != expected.size():
        return false
    for index: int in range(actual.size()):
        if String(actual[index]) != String(expected[index]):
            return false
    return true


func _finish() -> void:
    print("CANDIDATE_PACKAGE_MANIFEST=" + JSON.stringify({
        "package_root": _package_root(),
        "candidates": _cases.size(),
        "opponents": _config.size(),
        "player_skins": _player_skins.size(),
        "failures": _failures,
    }))
    if _failures.is_empty():
        print("CANDIDATE_PACKAGE_MANIFEST_OK")
        quit(0)
    else:
        print("CANDIDATE_PACKAGE_MANIFEST_FAILED=" + str(_failures.size()))
        quit(1)

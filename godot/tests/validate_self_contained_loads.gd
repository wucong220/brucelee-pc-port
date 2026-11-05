extends SceneTree
## Headless proof that every roster candidate loads through the REAL main.tscn
## using only package-local assets (no BRUCELEE_PLAYER_GLB / BRUCELEE_OPPONENT_GLB
## host overrides).  Each case is staged through main.gd's own
## _selected_opponent_config()/_stage_opponent_environment() path, i.e. the same
## resolution the menu switch uses, and a fresh main.tscn is spawned per case.
##
##   set BRUCELEE_PACKAGE_ROOT=<dir holding models/>
##   <godot> --headless --path godot --script res://tests/validate_self_contained_loads.gd

const MANIFEST_PATH: String = "res://data/candidate_package_models.json"

var _failures: Array[String] = []
var _results: Array = []


func _initialize() -> void:
    call_deferred("_run")


func _check(condition: bool, message: String) -> bool:
    if condition:
        return true
    _failures.append(message)
    push_error("SELF_CONTAINED_LOAD: " + message)
    return false


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


func _clear_fighter_environment() -> void:
    for variable: String in [
        "BRUCELEE_PLAYER_GLB", "BRUCELEE_PLAYER_TEXTURE_ROOT", "BRUCELEE_PLAYER_SKIN",
        "BRUCELEE_OPPONENT_GLB", "BRUCELEE_OPPONENT_TEXTURE_ROOT",
        "BRUCELEE_OPPONENT_CLIP_PREFIX", "BRUCELEE_OPPONENT_MASTER",
        "BRUCELEE_OPPONENT_MATERIAL_PROFILE", "BRUCELEE_OPPONENT_ATTACK_CONFIG",
        "BRUCELEE_OPPONENT_SKELETON", "BRUCELEE_OPPONENT_SKIN",
        "BRUCELEE_ALLOW_PACKAGE_MODELS",
    ]:
        OS.set_environment(variable, "")


func _run() -> void:
    var manifest: Variant = JSON.parse_string(
        FileAccess.get_file_as_string(MANIFEST_PATH)
    )
    if not manifest is Dictionary:
        _check(false, "manifest missing: " + MANIFEST_PATH)
        return _finish()
    var cases: Array = Dictionary(manifest).get("candidates", [])
    _check(cases.size() == 15, "manifest should list 15 candidates, got %d" % cases.size())
    var resolver: Node = load("res://scenes/main.tscn").instantiate()
    var consts: Dictionary = resolver.get_script().get_script_constant_map()
    var configs: Dictionary = consts.get("MENU_OPPONENT_CONFIG", {})
    _check(configs.size() == 9, "MENU_OPPONENT_CONFIG should keep its 9 opponents")
    _clear_fighter_environment()
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    var previous: Node = null
    for raw: Variant in cases:
        if not raw is Dictionary:
            continue
        var case: Dictionary = raw
        if previous != null and is_instance_valid(previous):
            current_scene = null
            previous.free()
            await process_frame
            await process_frame
        previous = null
        _clear_fighter_environment()
        OS.set_environment("BRUCELEE_MAIN_MENU", "0")
        var case_id: String = String(case.get("id", ""))
        var role: String = String(case.get("role", "opponent"))
        if role == "player":
            OS.set_environment("BRUCELEE_PLAYER_SKIN", String(case.get("skin", "")))
        else:
            var menu_entry: String = String(case.get("menu_entry", ""))
            if not configs.has(menu_entry):
                _check(false, case_id + ": unknown menu entry " + menu_entry)
                continue
            OS.set_environment("BRUCELEE_OPPONENT_SKIN", String(case.get("skin", "")))
            var merged: Dictionary = resolver.call(
                "_selected_opponent_config", Dictionary(configs[menu_entry])
            )
            OS.set_environment("BRUCELEE_OPPONENT_SKIN", "")
            if merged.is_empty():
                _check(false, case_id + ": opponent config failed closed")
                continue
            if not bool(resolver.call("_stage_opponent_environment", menu_entry, merged)):
                _check(false, case_id + ": opponent environment failed closed")
                continue
        var scene: Node = load("res://scenes/main.tscn").instantiate()
        root.add_child(scene)
        current_scene = scene
        previous = scene
        for _i: int in 12:
            await process_frame
        var fighter: PortFighter = scene.get("player" if role == "player" else "computer")
        if fighter == null:
            _check(false, case_id + ": no fighter instance")
            continue
        for _i: int in 400:
            if fighter.candidate_loaded or not fighter.candidate_load_error.is_empty():
                break
            await process_frame
        var expected_idle: String = String(case.get("expected_idle", ""))
        var expect_textures: bool = not String(case.get("texture_root", "")).is_empty()
        var entry: Dictionary = {
            "id": case_id,
            "loaded": fighter.candidate_loaded,
            "idle": fighter.candidate_animation_clip,
            "expected_idle": expected_idle,
            "glb": fighter.candidate_glb_path,
            "load_error": fighter.candidate_load_error,
            "textures_loaded": fighter.candidate_textures_loaded,
            "texture_error": fighter.candidate_texture_error,
            "height": fighter.candidate_visual_height,
        }
        _results.append(entry)
        _check(fighter.candidate_loaded, case_id + ": candidate did not load: "
                + fighter.candidate_load_error)
        if fighter.candidate_loaded:
            # Re-hash the file that was actually loaded and require it to equal
            # the manifest pin: "loaded" is not enough, the bytes must be pinned.
            var expected_sha: String = String(case.get("sha256", "")).to_lower()
            var actual_sha: String = _sha256_file(String(fighter.candidate_glb_path))
            entry["sha256"] = actual_sha
            entry["sha_pinned"] = (not expected_sha.is_empty()
                    and actual_sha == expected_sha)
            _check(not expected_sha.is_empty(),
                    case_id + ": manifest row carries no sha256 pin")
            _check(actual_sha == expected_sha,
                    "%s: loaded GLB sha %s != pin %s" % [
                        case_id, actual_sha, expected_sha,
                    ])
            # The AI may already have stepped out of idle during the settle
            # frames; assert the recovered idle mapping instead of the transient
            # current clip (exactly like capture_candidate_package_loads.gd).
            var idle_map: Dictionary = fighter.get("_candidate_clip_paths")
            _check(String(idle_map.get("idle", "")) == expected_idle,
                    "%s: idle mapping %s != %s" % [
                        case_id, String(idle_map.get("idle", "")), expected_idle,
                    ])
            _check(absf(fighter.candidate_visual_height - 1.8) <= 0.01,
                    "%s: height %.4f != 1.8" % [case_id, fighter.candidate_visual_height])
            _check(String(fighter.candidate_glb_path).replace("\\", "/").contains(
                    "/models/"), case_id + ": not loaded from package models/")
            if expect_textures:
                _check(fighter.candidate_textures_loaded,
                        case_id + ": package textures did not load: "
                        + fighter.candidate_texture_error)
    if previous != null and is_instance_valid(previous):
        current_scene = null
        previous.free()
        await process_frame
    resolver.free()
    return _finish()


func _finish() -> void:
    print("SELF_CONTAINED_LOADS=" + JSON.stringify({
        "cases": _results.size(),
        "failures": _failures,
        "results": _results,
    }))
    if _failures.is_empty():
        print("SELF_CONTAINED_LOADS_OK")
        quit(0)
    else:
        print("SELF_CONTAINED_LOADS_FAILED=" + str(_failures.size()))
        quit(1)


extends SceneTree
## Package-only headless start.
##
## Clears every absolute BRUCELEE_* host override; only BRUCELEE_PACKAGE_ROOT is
## set (to the staged package).  A real main.tscn must then boot with the default
## player skin and default opponent resolved from <package>/models/ — no host
## path, no windowed rendering.
##
##   BRUCELEE_PACKAGE_ROOT=<pkg> <godot> --headless --path godot \
##       --script res://tests/validate_package_only_headless_boot.gd

var _failures: Array[String] = []
var _record: Dictionary = {}


func _initialize() -> void:
    call_deferred("_run")


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures.append(message)
    push_error("PACKAGE_ONLY_BOOT: " + message)


func _clear_absolute_overrides() -> void:
    for variable: String in [
        "BRUCELEE_PLAYER_GLB", "BRUCELEE_PLAYER_TEXTURE_ROOT", "BRUCELEE_PLAYER_SKIN",
        "BRUCELEE_OPPONENT_GLB", "BRUCELEE_OPPONENT_TEXTURE_ROOT",
        "BRUCELEE_OPPONENT_CLIP_PREFIX", "BRUCELEE_OPPONENT_MASTER",
        "BRUCELEE_OPPONENT_MATERIAL_PROFILE", "BRUCELEE_OPPONENT_ATTACK_CONFIG",
        "BRUCELEE_OPPONENT_SKELETON", "BRUCELEE_OPPONENT_SKIN",
        "BRUCELEE_OPPONENT_NAME_KEY", "BRUCELEE_ALLOW_PACKAGE_MODELS",
        "BRUCELEE_AUDIO_ROOT", "BRUCELEE_VOICE_ROOT", "BRUCELEE_MENU_SFX_ROOT",
        "BRUCELEE_MENU_SFX_PATH", "BRUCELEE_MAINMENU_PATH", "BRUCELEE_MENU_ART_ROOT",
        "BRUCELEE_BACKGROUND_PATH", "BRUCELEE_STORY_FLOW", "BRUCELEE_GAME_MODE",
        "BRUCELEE_PROGRESS",
    ]:
        OS.set_environment(variable, "")


func _under_models(path: String, package_root: String) -> bool:
    var normalized: String = path.replace("\\", "/").to_lower()
    var root: String = package_root.replace("\\", "/").to_lower().trim_suffix("/")
    return normalized.begins_with(root + "/models/")


func _run() -> void:
    var package_root: String = OS.get_environment("BRUCELEE_PACKAGE_ROOT").strip_edges()
    if package_root.is_empty():
        _check(false, "BRUCELEE_PACKAGE_ROOT must be set for this test")
        return _finish()
    _clear_absolute_overrides()
    OS.set_environment("BRUCELEE_PACKAGE_ROOT", package_root)
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")

    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    for _i: int in 12:
        await process_frame
    var player: Node = scene.get("player")
    var opponent: Node = scene.get("computer")
    if player == null or opponent == null:
        _check(false, "main.tscn did not create both fighters")
        return _finish()
    for _i: int in 900:
        var settled: bool = (
            (player.candidate_loaded or not player.candidate_load_error.is_empty())
            and (opponent.candidate_loaded or not opponent.candidate_load_error.is_empty())
        )
        if settled:
            break
        await process_frame

    _record = {
        "package_root": package_root,
        "models_present": DirAccess.dir_exists_absolute(package_root.path_join("models")),
        "player_skin_env": OS.get_environment("BRUCELEE_PLAYER_SKIN"),
        "player_glb_override": OS.get_environment("BRUCELEE_PLAYER_GLB"),
        "opponent_glb_override": OS.get_environment("BRUCELEE_OPPONENT_GLB"),
        "player_loaded": player.candidate_loaded,
        "player_error": player.candidate_load_error,
        "player_glb": player.candidate_glb_path,
        "player_idle": player.candidate_animation_clip,
        "opponent_loaded": opponent.candidate_loaded,
        "opponent_error": opponent.candidate_load_error,
        "opponent_glb": opponent.candidate_glb_path,
        "opponent_idle": opponent.candidate_animation_clip,
    }
    _check(bool(_record["models_present"]), "package models/ directory must exist")
    _check(String(_record["player_glb_override"]).is_empty(),
            "the boot must not need a BRUCELEE_PLAYER_GLB override")
    _check(String(_record["opponent_glb_override"]).is_empty()
            or _under_models(String(_record["opponent_glb_override"]), package_root),
            "any staged opponent GLB must be inside <package>/models")
    _check(bool(_record["player_loaded"]),
            "default player skin must load from the package: " + String(_record["player_error"]))
    _check(bool(_record["opponent_loaded"]),
            "default opponent must load from the package: " + String(_record["opponent_error"]))
    _check(_under_models(String(_record["player_glb"]), package_root),
            "player GLB must come from <package>/models")
    _check(_under_models(String(_record["opponent_glb"]), package_root),
            "opponent GLB must come from <package>/models")

    current_scene = null
    scene.free()
    return _finish()


func _finish() -> void:
    print("PACKAGE_ONLY_HEADLESS_BOOT=" + JSON.stringify({
        "record": _record,
        "failures": _failures,
    }))
    if _failures.is_empty():
        print("PACKAGE_ONLY_HEADLESS_BOOT_OK")
        quit(0)
    else:
        print("PACKAGE_ONLY_HEADLESS_BOOT_FAILED=" + str(_failures.size()))
        quit(1)

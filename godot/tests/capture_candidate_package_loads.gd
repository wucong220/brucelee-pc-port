extends SceneTree
## Load every verified package candidate through the real main.tscn path and
## save one screenshot per candidate.
##
## Usage (windowed, not headless -- it renders and saves PNGs):
##   set BRUCELEE_PACKAGE_ROOT=<dir holding models/>
##   <godot> --path godot --script res://tests/capture_candidate_package_loads.gd \
##       -- <output dir>
##
## Opponent cases call main.gd _selected_opponent_config() and
## _stage_opponent_environment(), i.e. the same resolution the menu switch uses
## (glb_package -> sha256 pin -> legacy fallback, and the BRUCELEE_OPPONENT_SKIN
## variant table).  Each case then spawns a fresh main.tscn because the fighters
## read the environment once in _ready.  Player cases set BRUCELEE_PLAYER_SKIN and
## spawn the same way, so the player skin table and its fail-closed rules run.
##
## Per candidate it asserts: the candidate loaded, the idle clip is the clip the
## character's table expects, the visual height is the 1.8 m candidate height,
## the feet sit on the floor, a visible mesh exists, and body+hair candidates
## with a texture root loaded their textures.  Body-only candidates deliberately
## have no external texture root (see the manifest), so they must load without
## applying another character's art.

const CandidateBounds = preload("res://scripts/candidate_bounds.gd")
const MANIFEST_PATH: String = "res://data/candidate_package_models.json"

var _out_dir: String = ""
var _shot_dir: String = ""
var _log_dir: String = ""
var _failures: Array[String] = []
var _results: Array = []
var _guard_results: Array = []
var _configs: Dictionary = {}
var _only_case: String = ""


func _initialize() -> void:
    call_deferred("_run")


func _check(condition: bool, message: String) -> bool:
    if condition:
        return true
    _failures.append(message)
    push_error("CANDIDATE_PACKAGE_LOAD: " + message)
    return false


func _clear_fighter_environment() -> void:
    for variable: String in [
        "BRUCELEE_PLAYER_GLB", "BRUCELEE_PLAYER_TEXTURE_ROOT",
        "BRUCELEE_PLAYER_SKIN", "BRUCELEE_OPPONENT_GLB",
        "BRUCELEE_OPPONENT_TEXTURE_ROOT", "BRUCELEE_OPPONENT_CLIP_PREFIX",
        "BRUCELEE_OPPONENT_MASTER", "BRUCELEE_OPPONENT_MATERIAL_PROFILE",
        "BRUCELEE_OPPONENT_ATTACK_CONFIG", "BRUCELEE_OPPONENT_SKELETON",
        "BRUCELEE_OPPONENT_SKIN", "BRUCELEE_ALLOW_PACKAGE_MODELS",
    ]:
        OS.set_environment(variable, "")


func _spawn_scene() -> Node:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    # Let the round camera and the candidate settle before any measurement or
    # screenshot; no other main.tscn instance is alive at this point.
    for _i: int in 12:
        await process_frame
    return scene


func _run() -> void:
    print("CAPTURE_BOOT")
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 1:
        _check(false, "expected an output directory argument")
        return _finish()
    _out_dir = args[0].replace("\\", "/").trim_suffix("/")
    _shot_dir = _out_dir.path_join("screenshots")
    _log_dir = _out_dir.path_join("logs")
    DirAccess.make_dir_recursive_absolute(_shot_dir)
    DirAccess.make_dir_recursive_absolute(_log_dir)
    var manifest: Variant = JSON.parse_string(
        FileAccess.get_file_as_string(MANIFEST_PATH)
    )
    if not manifest is Dictionary:
        _check(false, "manifest is missing: " + MANIFEST_PATH)
        return _finish()
    var cases: Array = Dictionary(manifest).get("candidates", [])
    _check(cases.size() == 10, "manifest should list 10 candidates")
    print("CAPTURE_MANIFEST cases=%d" % cases.size())
    # Optional filter.  A candidate id runs exactly that one case (the test
    # driver uses one process per candidate: repeatedly importing ten 6-9 MB
    # skinned GLBs in a single window is not reliable on this GPU).  A positive
    # integer keeps the first N cases (quick diagnostic).
    _only_case = ""
    if args.size() > 1 and not args[1].strip_edges().is_empty():
        var selector: String = args[1].strip_edges()
        if selector.is_valid_int() and int(selector) > 0:
            cases = cases.slice(0, mini(int(selector), cases.size()))
        else:
            _only_case = selector
            cases = cases.filter(func(entry: Variant) -> bool:
                return String(Dictionary(entry).get("id", "")) == selector)
            _check(cases.size() == 1, "unknown candidate id: " + selector)
    print("CAPTURE_CASES cases=%d" % cases.size())

    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_EXPORT_SELF_TEST", "")
    _clear_fighter_environment()
    # A bare instance (never added to the tree) only supplies the
    # config-resolution methods: no fighters, camera or _ready side effects, so
    # it cannot leak into a screenshot.
    var resolver: Node = load("res://scenes/main.tscn").instantiate()
    _configs = resolver.get_script().get_script_constant_map().get(
        "MENU_OPPONENT_CONFIG", {}
    )
    _check(_configs is Dictionary and _configs.size() == 9,
            "MENU_OPPONENT_CONFIG should keep its 9 opponents")
    if args.size() > 1 and int(args[1]) > 0:
        # Diagnostic shortcut: load only the first N candidates.
        cases = cases.slice(0, mini(int(args[1]), cases.size()))

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
        if not _prepare_case_environment(resolver, case):
            _results.append({"id": String(case.get("id", "")),
                    "error": "environment could not be staged"})
            continue
        var scene: Node = await _spawn_scene()
        previous = scene
        await _measure_case(scene, case)
    if previous != null and is_instance_valid(previous):
        current_scene = null
        previous.free()
        await process_frame
    _check_fail_closed(resolver)
    resolver.free()
    return _finish()


func _prepare_case_environment(resolver: Node, case: Dictionary) -> bool:
    _clear_fighter_environment()
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    var case_id: String = String(case.get("id", ""))
    if String(case.get("role", "opponent")) == "player":
        OS.set_environment("BRUCELEE_PLAYER_SKIN", String(case.get("skin", "")))
        return true
    var menu_entry: String = String(case.get("menu_entry", ""))
    if not _configs.has(menu_entry):
        _check(false, case_id + ": unknown menu entry " + menu_entry)
        return false
    OS.set_environment("BRUCELEE_OPPONENT_SKIN", String(case.get("skin", "")))
    var merged: Dictionary = resolver.call(
        "_selected_opponent_config", Dictionary(_configs[menu_entry])
    )
    OS.set_environment("BRUCELEE_OPPONENT_SKIN", "")
    if merged.is_empty():
        _check(false, case_id + ": opponent config failed closed")
        return false
    var staged: bool = bool(resolver.call(
        "_stage_opponent_environment", menu_entry, merged
    ))
    _check(staged, case_id + ": opponent environment failed closed")
    return staged


func _measure_case(scene: Node, case: Dictionary) -> void:
    var case_id: String = String(case.get("id", ""))
    var role: String = String(case.get("role", "opponent"))
    var expected_idle: String = String(case.get("expected_idle", ""))
    var fighter: PortFighter = scene.get("player" if role == "player" else "computer")
    if fighter == null:
        _check(false, case_id + ": no fighter instance")
        return
    for _i: int in 300:
        if fighter.candidate_loaded or not fighter.candidate_load_error.is_empty():
            break
        await process_frame
    scene.set_physics_process(false)
    fighter.set_physics_process(false)
    var result: Dictionary = {
        "id": case_id,
        "role": role,
        "skin": String(case.get("skin", "")),
        "expected_idle": expected_idle,
        "candidate_loaded": fighter.candidate_loaded,
        "candidate_glb_path": fighter.candidate_glb_path,
        "load_error": fighter.candidate_load_error,
        "idle": fighter.candidate_animation_clip,
        "visual_height": fighter.candidate_visual_height,
        "textures_loaded": fighter.candidate_textures_loaded,
        "texture_error": fighter.candidate_texture_error,
        "expected_textures": not String(case.get("texture_root", "")).is_empty(),
    }
    if fighter.candidate_loaded and fighter.candidate_animation_clip != expected_idle:
        var clip_paths: Dictionary = fighter.get("_candidate_clip_paths")
        if String(clip_paths.get("idle", "")) == expected_idle:
            fighter.move_axis = Vector2.ZERO
            fighter.reset_fighter(
                Vector3(2.0, 1.20, 0.0) if role == "opponent"
                else Vector3(-0.25, 1.20, 0.0)
            )
            fighter._animate_candidate()
            for _i: int in 4:
                await process_frame
            result["idle_after_reset"] = fighter.candidate_animation_clip
    result["idle"] = fighter.candidate_animation_clip

    _check(fighter.candidate_loaded, case_id + ": candidate did not load: "
            + fighter.candidate_load_error)
    if fighter.candidate_loaded:
        _check(absf(fighter.candidate_visual_height - 1.8) <= 0.01,
                "%s: visual height %.4f != 1.8" % [
                    case_id, fighter.candidate_visual_height,
                ])
        _check(fighter.candidate_animation_clip == expected_idle,
                "%s: idle %s != %s" % [
                    case_id, fighter.candidate_animation_clip, expected_idle,
                ])
        var candidate_root: Node3D = fighter.get("_candidate_root")
        if candidate_root == null:
            _check(false, case_id + ": candidate root is null")
        else:
            var measured: Dictionary = CandidateBounds.scene_bounds(candidate_root)
            if not String(measured.get("error", "")).is_empty():
                _check(false, case_id + ": bounds: " + String(measured["error"]))
            else:
                var bounds: AABB = measured["bounds"]
                result["world_height"] = bounds.size.y
                result["floor"] = bounds.position.y
                _check(absf(bounds.position.y) <= 0.05,
                        "%s: feet floor %.4f" % [case_id, bounds.position.y])
                # The idle stance is not always fully upright: a wide kung-fu
                # crouch measures ~1.49 m even though the model is normalised to
                # the 1.8 m candidate height (asserted above).  Keep the window
                # wide enough for a crouched idle but still catch a wrong or
                # unscaled model.
                _check(bounds.size.y >= 1.4 and bounds.size.y <= 2.1,
                        "%s: world height %.4f" % [case_id, bounds.size.y])
            var visible: int = 0
            for node: Node in candidate_root.find_children("*", "MeshInstance3D", true, false):
                var mesh_instance: MeshInstance3D = node as MeshInstance3D
                if mesh_instance.mesh != null and mesh_instance.is_visible_in_tree():
                    visible += 1
            result["visible_meshes"] = visible
            _check(visible > 0, case_id + ": no visible mesh")
        if bool(result["expected_textures"]):
            _check(fighter.candidate_textures_loaded,
                    case_id + ": textures did not load: " + fighter.candidate_texture_error)
        else:
            result["textures_note"] = (
                "no external texture root: the GLB carries its own images and no "
                + "other character's art is applied"
            )
    var shot_path: String = _shot_dir.path_join("candidate_" + case_id + ".png")
    var shot: Dictionary = await _save_screenshot(shot_path)
    result["screenshot"] = shot_path
    result["screenshot_ok"] = bool(shot.get("ok", false))
    result["screenshot_error"] = String(shot.get("error", ""))
    _results.append(result)
    print("CANDIDATE_CASE=" + JSON.stringify({
        "id": case_id, "loaded": fighter.candidate_loaded,
        "idle": result["idle"], "screenshot_ok": result["screenshot_ok"],
    }))


func _save_screenshot(path: String) -> Dictionary:
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null:
        return {"ok": false, "error": "viewport image is null"}
    var error: Error = image.save_png(path)
    return {"ok": error == OK, "error": "" if error == OK else "save_png error %d" % error}


func _check_fail_closed(scene: Node) -> void:
    ## Unit-level proof of the fail-closed rules, on the live main.tscn script.
    var pin: String = "0".repeat(64)
    var mismatch: Dictionary = scene.call(
        "_resolve_package_model", "models/chief02_body.glb", pin
    )
    _guard_results.append({
        "check": "sha256 mismatch fails closed",
        "path": String(mismatch.get("path", "")),
        "error": String(mismatch.get("error", "")),
    })
    _check(String(mismatch.get("path", "")).is_empty()
            and not String(mismatch.get("error", "")).is_empty(),
            "a present package model with a wrong sha256 must fail closed")

    var absent: Dictionary = scene.call(
        "_resolve_package_model", "models/not_a_candidate.glb", pin
    )
    _guard_results.append({
        "check": "absent package model keeps the legacy fallback",
        "path": String(absent.get("path", "")),
        "error": String(absent.get("error", "")),
    })
    _check(String(absent.get("path", "")).is_empty()
            and String(absent.get("error", "")).is_empty(),
            "an absent package model must report no path and no error")

    OS.set_environment("BRUCELEE_OPPONENT_SKIN", "chief02_body")
    var chief_variant: Dictionary = scene.call(
        "_selected_opponent_config", _configs.get("chief", {})
    )
    var loming_wrong_variant: Dictionary = scene.call(
        "_selected_opponent_config", _configs.get("loming", {})
    )
    OS.set_environment("BRUCELEE_OPPONENT_SKIN", "")
    _guard_results.append({
        "check": "variant must exist under the selected character",
        "chief_ok": String(chief_variant.get("glb_package", "")),
        "loming_rejected": loming_wrong_variant.is_empty(),
    })
    _check(not chief_variant.is_empty()
            and String(chief_variant.get("glb_package", "")).ends_with(
                "chief02_body.glb"),
            "the chief variant table should resolve chief02_body")
    _check(loming_wrong_variant.is_empty(),
            "a chief variant must be rejected for the loming entry")

    OS.set_environment("BRUCELEE_PACKAGE_ROOT", String(scene.call("_package_root")))
    var package_path: String = _out_dir.path_join("models/chief02_body.glb")
    _guard_results.append({
        "check": "package model path classification",
        "package_model": bool(scene.call("_is_package_model_path", package_path)),
        "outside": bool(scene.call("_is_package_model_path", package_path + ".txt")),
        "outside_models": bool(scene.call(
            "_is_package_model_path", _out_dir.path_join("other/chief02_body.glb")
        )),
    })
    _check(bool(scene.call("_is_package_model_path", package_path)),
            "the stable models/ path should classify as a package model")
    _check(not bool(scene.call("_is_package_model_path", package_path + ".txt")),
            "a non-.glb path must not classify as a package model")
    _check(not bool(scene.call(
                "_is_package_model_path", _out_dir.path_join("other/x.glb")
            )), "a path outside models/ must not classify as a package model")


func _finish() -> void:
    var report: Dictionary = {
        "package_root": OS.get_environment("BRUCELEE_PACKAGE_ROOT"),
        "output_dir": _out_dir,
        "cases": _results,
        "fail_closed_checks": _guard_results,
        "failures": _failures,
    }
    var report_name: String = "candidate_load_report.json"
    if not _only_case.is_empty():
        # One process per candidate (the driver's mode): keep a per-case report
        # so the driver can merge them into candidate_load_report.json.
        report_name = "candidate_load_report_" + _only_case + ".json"
    var report_path: String = _log_dir.path_join(report_name)
    var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(report, "  ") + "\n")
        file.close()
    var screenshots: int = 0
    for case: Variant in _results:
        if bool(Dictionary(case).get("screenshot_ok", false)):
            screenshots += 1
    print("CANDIDATE_PACKAGE_LOAD=" + JSON.stringify({
        "cases": _results.size(),
        "screenshots": screenshots,
        "failures": _failures,
        "report": report_path,
    }))
    if _failures.is_empty():
        print("CANDIDATE_PACKAGE_LOAD_OK")
        quit(0)
    else:
        print("CANDIDATE_PACKAGE_LOAD_FAILED=" + str(_failures.size()))
        quit(1)

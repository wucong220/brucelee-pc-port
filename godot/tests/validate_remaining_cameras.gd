extends SceneTree
## Acceptance test for the remaining cinematic cameras:
##   * characters.list intro pools (m01_intro_01..04, m02/m03/m04 opponent
##     intros) drive the actual selected intro camera per fighter per match;
##   * characters.list victory pools drive the result camera selected by the
##     preserved zmath draw (including the m01_victory_02 and opponent variants);
##   * every mapped camera JSON is played frame-for-frame against the decoded
##     keyframes, not an invented sequence;
##   * missing map / missing JSON / unknown clip fail closed to the analytic
##     follow camera.
##
## usage: --headless --path <proj> --script res://tests/validate_remaining_cameras.gd -- \
##        <player.glb> <opponent.glb> <gametext_root>

const CameraAnm = preload("res://scripts/camera_anm_player.gd")
const CAMERA_DIR := "res://data/camera_anm/"
const CAMERA_MISSING_DIR := "res://data/camera_anm_missing/"
var _failures: Array[String] = []
var _results: Dictionary = {}
var _checks: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _check(label: String, ok: bool, detail: String = "") -> void:
    _checks += 1
    if ok:
        print("PASS ", label, " ", detail)
    else:
        _failures.append(label + " " + detail)
        push_error("FAIL " + label + " " + detail)
        print("FAIL ", label, " ", detail)


func _new_scene(player_glb: String, opponent_glb: String, text_root: String) -> Node:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_ROUND_TIME", "60")
    OS.set_environment("BRUCELEE_PLAYER_GLB", player_glb)
    OS.set_environment("BRUCELEE_OPPONENT_GLB", opponent_glb)
    OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG",
        "res://data/fighting_set_m03_mapped_attacks.json")
    OS.set_environment("BRUCELEE_GAME_TEXT_ROOT", text_root)
    OS.set_environment("BRUCELEE_GAME_TEXT_FLIP", "1")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    return scene


func _wait_candidates(scene: Node, timeout_frames: int = 1200) -> bool:
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    for _i: int in range(timeout_frames):
        if player.candidate_loaded and computer.candidate_loaded:
            return true
        await physics_frame
    return player.candidate_loaded and computer.candidate_loaded


func _freeze(scene: Node) -> void:
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)
    player.opponent = computer
    computer.opponent = player


func _load_json(path: String) -> Dictionary:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return Dictionary(parsed) if typeof(parsed) == TYPE_DICTIONARY else {}


func _map_clips(path: String) -> Dictionary:
    var data: Dictionary = _load_json(path)
    var clips: Variant = data.get("camera_clips", {})
    return Dictionary(clips) if typeof(clips) == TYPE_DICTIONARY else {}


func _ref_for(clip: String) -> RefCounted:
    var ref = CameraAnm.new()
    if not ref.load_json(CAMERA_DIR + clip + ".json"):
        return null
    return ref


func _place(scene: Node, player_on_right: bool = false) -> void:
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    if player_on_right:
        player.reset_fighter(Vector3(2.0, 1.20, 0.0))
        computer.reset_fighter(Vector3(-2.0, 1.20, 0.0))
        player.facing = -1.0
        computer.facing = 1.0
    else:
        player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
        computer.reset_fighter(Vector3(2.0, 1.20, 0.0))
        player.facing = 1.0
        computer.facing = -1.0


func _check_map_structure() -> void:
    var intro: Dictionary = _map_clips(CAMERA_DIR + "intro_camera_map.json")
    var victory: Dictionary = _map_clips(CAMERA_DIR + "victory_camera_map.json")
    var defeat: Dictionary = _map_clips(CAMERA_DIR + "defeat_camera_map.json")
    _check("intro map has 16 characters.list intro clips", intro.size() == 16, str(intro.size()))
    _check("victory map has 12 characters.list victory clips", victory.size() == 12,
        str(victory.size()))
    _check("defeat map has the single shared defeat clip", defeat.size() == 1, str(defeat.size()))
    for clip: String in ["m01_intro_01", "m01_intro_02", "m01_intro_03", "m01_intro_04",
            "m02_e01_intro_01", "m02_e01_intro_02", "m02_intro_01", "m02_intro_02",
            "m02_intro_03", "m03_intro_01", "m03_intro_02", "m03_intro_03",
            "m04_e01_intro_01", "m04_e02_intro_01", "m04_e03_intro_01", "m04_intro_01"]:
        _check("intro map has " + clip, intro.has(clip), clip)
    for clip: String in ["m01_victory_01", "m01_victory_02", "m02_e01_victory_01",
            "m02_victory_01", "m03_victory_01", "m03_victory_02", "m03_victory_03",
            "m04_e01_victory_01", "m04_e02_victory_01", "m04_e03_victory_01",
            "m04_victory_01", "m04_victory_02"]:
        _check("victory map has " + clip, victory.has(clip), clip)
    _check("defeat map has m01_defeat_01", defeat.has("m01_defeat_01"))

    for group_name: String in ["intro_camera_map.json", "victory_camera_map.json",
            "defeat_camera_map.json"]:
        var path: String = CAMERA_DIR + group_name
        var map: Dictionary = _map_clips(path)
        for clip: String in map:
            var row: Dictionary = map[clip]
            var camera: String = String(row.get("camera", ""))
            _check(group_name + " " + clip + " camera equals clip",
                camera == clip, camera)
            var ref = _ref_for(camera)
            _check(group_name + " " + clip + " JSON loads", ref != null, camera)
            if ref != null:
                _check(group_name + " " + clip + " frame count matches",
                    int(row.get("frames", -1)) == ref.frame_count(),
                    "%s vs %s" % [row.get("frames", -1), ref.frame_count()])
                _check(group_name + " " + clip + " fps 30",
                    absf(float(row.get("fps", 0.0)) - 30.0) < 0.001,
                    str(row.get("fps", 0.0)))

    # The existing action-camera map must keep the only decoded size-variant
    # camera and must not invent cameras for clips that have no decoded JSON.
    var actions: Dictionary = _map_clips(CAMERA_DIR + "action_camera_map.json")
    _check("action map keeps m01_end_attack_01_forbigguy",
        actions.has("m01_end_attack_01_forbigguy"))
    _check("action map does not invent m01_grab_01_forbigguy",
        not actions.has("m01_grab_01_forbigguy"))


func _check_pool_selection(scene: Node) -> void:
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    var expected_player: Array[String] = [
        "m01_intro_01", "m01_intro_02", "m01_intro_03", "m01_intro_04",
    ]
    for index: int in range(expected_player.size()):
        player.select_intro_clip(index)
        _check("player intro index %d selects %s" % [index, expected_player[index]],
            player.selected_intro_clip() == expected_player[index],
            player.selected_intro_clip())
        _place(scene)
        _check("player intro %s arms camera %s" % [
                expected_player[index], expected_player[index]],
            scene._intro_camera_begin(player, false, expected_player[index])
            and String(scene.get("_camera_anm_clip")) == expected_player[index],
            String(scene.get("_camera_anm_clip")))
        scene._intro_camera_end()

    computer.select_intro_clip(0)
    _check("brick intro pool selects m03_intro_02",
        computer.selected_intro_clip() == "m03_intro_02", computer.selected_intro_clip())
    _place(scene)
    _check("opponent intro arms m03_intro_02 camera",
        scene._intro_camera_begin(computer, false, "m03_intro_02", true)
        and String(scene.get("_camera_anm_clip")) == "m03_intro_02",
        String(scene.get("_camera_anm_clip")))
    scene._intro_camera_end()

    # Preserve the native draw order and verify the exact first-match result:
    # player draw 40155 % 4 = 3 -> m01_intro_04; player victory 34122 % 2 = 0.
    scene.set("_zmath_state", 0x6425AF14)
    scene._select_match_result_clips()
    _check("native draw selects player m01_intro_04",
        player.selected_intro_clip() == "m01_intro_04", player.selected_intro_clip())
    _check("native draw selects player m01_victory_01",
        player.get("result_clip_index_victory") == 0,
        str(player.get("result_clip_index_victory")))
    _check("native draw selects brick m03_intro_02",
        computer.selected_intro_clip() == "m03_intro_02", computer.selected_intro_clip())
    _check("native draw selects brick m03_victory_02",
        computer.get("result_clip_index_victory") == 0,
        str(computer.get("result_clip_index_victory")))
    _place(scene)
    _check("actual selected player intro arms m01_intro_04 camera",
        scene._intro_camera_begin(player, false,
            player.selected_intro_clip())
        and String(scene.get("_camera_anm_clip")) == "m01_intro_04",
        String(scene.get("_camera_anm_clip")))
    scene._intro_camera_end()


func _check_intro_frames(scene: Node) -> void:
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    var camera: Camera3D = scene.get("fight_camera")
    var clips: Array[String] = []
    var intro_map: Dictionary = _map_clips(CAMERA_DIR + "intro_camera_map.json")
    for clip: String in intro_map:
        clips.append(clip)
    clips.sort()
    for clip: String in clips:
        _place(scene)
        if not scene._intro_camera_begin(player, false, clip):
            _check("per-frame " + clip + " arms", false, "begin failed")
            continue
        var ref = _ref_for(clip)
        if ref == null:
            _check("per-frame " + clip + " reference", false)
            continue
        var a: Vector3 = scene.get("_camera_anm_a")
        var b: Vector3 = scene.get("_camera_anm_b")
        var mirror: bool = scene.get("_camera_anm_mirror")
        var max_err: float = 0.0
        var max_fov_err: float = 0.0
        var max_look_err: float = 1.0
        for frame: int in range(ref.frame_count()):
            scene.set("_camera_anm_frame", float(frame))
            if not scene._intro_camera_play_authored(0.0):
                _check("per-frame " + clip + " plays frame %d" % frame, false)
                break
            var expected: Dictionary = ref.place_world(frame, a, b, mirror)
            max_err = maxf(max_err,
                camera.global_position.distance_to(expected["camera_world"]))
            max_fov_err = maxf(max_fov_err,
                absf(camera.fov - float(expected["fov_degrees"])))
            if bool(expected["has_target"]):
                var forward: Vector3 = -camera.global_transform.basis.z
                var aim: float = forward.normalized().dot(
                    ((expected["target_world"] as Vector3) - camera.global_position).normalized())
                max_look_err = minf(max_look_err, aim)
        _check("per-frame " + clip + " matches place_world",
            max_err < 0.002, str(max_err))
        _check("per-frame " + clip + " matches fov",
            max_fov_err < 0.01, str(max_fov_err))
        if bool(ref.sample_local(0).get("has_target", false)):
            _check("per-frame " + clip + " looks at authored target",
                max_look_err > 0.99, str(max_look_err))
        var last: int = ref.frame_count() - 1
        scene.set("_camera_anm_frame", float(last))
        var advanced_past_end: bool = scene._intro_camera_play_authored(1.0 / 30.0)
        var ends: bool = not bool(scene.get("_intro_camera_active"))
        _check("per-frame " + clip + " finishes after last frame",
            not advanced_past_end and ends,
            "active=%s" % str(scene.get("_intro_camera_active")))
        scene._intro_camera_end()


func _check_victory_frames(scene: Node) -> void:
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    var camera: Camera3D = scene.get("fight_camera")
    var victory_map: Dictionary = _map_clips(CAMERA_DIR + "victory_camera_map.json")
    var clips: Array[String] = []
    for clip: String in victory_map:
        clips.append(clip)
    clips.sort()
    for clip: String in clips:
        _place(scene)
        var player_pre: Vector3 = scene._camera_anm_fighter_point(player)
        var computer_pre: Vector3 = scene._camera_anm_fighter_point(computer)
        player.global_position = Vector3(0.0, 1.20, 0.0)
        computer.global_position = Vector3(0.0, 1.20, 0.0)
        if not scene._camera_anm_begin(clip, player, player_pre, computer_pre):
            _check("victory per-frame " + clip + " arms", false)
            continue
        var ref = _ref_for(clip)
        if ref == null:
            _check("victory per-frame " + clip + " reference", false)
            continue
        var a: Vector3 = scene.get("_camera_anm_a")
        var b: Vector3 = scene.get("_camera_anm_b")
        var mirror: bool = scene.get("_camera_anm_mirror")
        var max_err: float = 0.0
        var max_fov_err: float = 0.0
        for frame: int in range(ref.frame_count()):
            scene.set("_camera_anm_frame", float(frame))
            if not scene._camera_anm_play_authored(0.0):
                _check("victory per-frame " + clip + " plays frame %d" % frame, false)
                break
            var expected: Dictionary = ref.place_world(frame, a, b, mirror)
            max_err = maxf(max_err,
                camera.global_position.distance_to(expected["camera_world"]))
            max_fov_err = maxf(max_fov_err,
                absf(camera.fov - float(expected["fov_degrees"])))
        _check("victory per-frame " + clip + " matches place_world",
            max_err < 0.002, str(max_err))
        _check("victory per-frame " + clip + " matches fov",
            max_fov_err < 0.01, str(max_fov_err))
        scene._camera_anm_end()


func _check_result_selection(scene: Node) -> void:
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.select_result_clips(1)
    _check("player victory roll 1 selects m01_victory_02",
        player._selected_result_clip("victory") == "m01_victory_02",
        player._selected_result_clip("victory"))
    player.select_result_clips(0)
    _check("player victory roll 0 selects m01_victory_01",
        player._selected_result_clip("victory") == "m01_victory_01",
        player._selected_result_clip("victory"))
    computer.select_result_clips(0)
    _check("brick victory roll 0 selects m03_victory_02",
        computer._selected_result_clip("victory") == "m03_victory_02",
        computer._selected_result_clip("victory"))

    scene._reset_match()
    scene.set("pending_round_winner", 1)
    scene.set("player_rounds", scene.get("rounds_to_win"))
    scene.set("computer_rounds", 0)
    _place(scene)
    player.select_result_clips(1)
    scene._begin_winner_result_pose()
    _check("player result plays m01_victory_02", player.result_clip == "m01_victory_02",
        player.result_clip)
    _check("player result arms m01_victory_02 camera",
        String(scene.get("_camera_anm_clip")) == "m01_victory_02",
        String(scene.get("_camera_anm_clip")))
    _check("player result enters MATCH_WIN", int(scene.get("match_state")) == 12,
        str(scene.get("match_state")))

    scene._enter_match_state(4)
    scene.set("pending_round_winner", 2)
    scene.set("player_rounds", 0)
    scene.set("computer_rounds", scene.get("rounds_to_win"))
    _place(scene)
    computer._selected_result_clip("victory")
    computer.select_result_clips(0)
    scene._begin_winner_result_pose()
    _check("opponent result plays m03_victory_02", computer.result_clip == "m03_victory_02",
        computer.result_clip)
    _check("opponent result arms m03_victory_02 camera",
        String(scene.get("_camera_anm_clip")) == "m03_victory_02",
        String(scene.get("_camera_anm_clip")))
    _check("opponent result enters MATCH_LOSE", int(scene.get("match_state")) == 13,
        str(scene.get("match_state")))


func _check_fail_closed(scene: Node) -> void:
    var player: PortFighter = scene.get("player")
    scene._camera_anm_end()
    scene.set("_intro_camera_active", false)
    _place(scene)
    # Unknown clip name: no map entry -> no camera.
    _check("unknown intro clip fails closed",
        not scene._intro_camera_begin(player, false, "no_such_intro_camera")
        and not bool(scene.get("_intro_camera_active"))
        and String(scene.get("_camera_anm_clip")).is_empty(),
        String(scene.get("_camera_anm_clip")))
    # Missing JSON: map row exists but the camera file is absent.
    scene.set("_camera_anm_dir", CAMERA_MISSING_DIR)
    _check("missing intro camera JSON fails closed",
        not scene._intro_camera_begin(player, false, "m01_intro_02")
        and not bool(scene.get("_intro_camera_active"))
        and String(scene.get("_camera_anm_clip")).is_empty(),
        String(scene.get("_camera_anm_clip")))
    scene.set("_camera_anm_dir", CAMERA_DIR)
    # Missing intro map: no mapping -> no camera.
    scene.set("_intro_camera_map_path", CAMERA_MISSING_DIR + "intro_camera_map.json")
    scene.set("_intro_camera_map_loaded", false)
    scene.set("_intro_camera_map", {})
    _check("missing intro map fails closed",
        not scene._intro_camera_begin(player, false, "m01_intro_02")
        and not bool(scene.get("_intro_camera_active")),
        String(scene.get("_camera_anm_clip")))
    scene.set("_intro_camera_map_path", "res://data/camera_anm/intro_camera_map.json")
    scene.set("_intro_camera_map_loaded", false)
    scene.set("_intro_camera_map", {})


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 3:
        push_error("Expected <player.glb> <opponent.glb> <gametext_root>")
        quit(2)
        return
    var player_glb: String = args[0]
    var opponent_glb: String = args[1]
    var text_root: String = args[2]

    _check_map_structure()
    var scene: Node = _new_scene(player_glb, opponent_glb, text_root)
    if not await _wait_candidates(scene):
        push_error("remaining-camera candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    _check_pool_selection(scene)
    _check_intro_frames(scene)
    _check_victory_frames(scene)
    _check_result_selection(scene)
    _check_fail_closed(scene)

    _results["checks"] = _checks
    _results["failures"] = _failures
    _results["player_intro_pool"] = PortFighter.RESULT_CLIPS_BRUCELEE.get("intro", [])
    print("REMAINING_CAMERA_VALIDATION=" + JSON.stringify(_results))
    quit(0 if _failures.is_empty() else 1)

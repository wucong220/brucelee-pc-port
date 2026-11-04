extends SceneTree
## Headless acceptance test for the original m01_intro_01 camera on the REAL
## res://scenes/main.tscn MATCH_STATE_INTRO (SetState(3), READY/FIGHT) state.
##
## It drives the real ported round-intro path (_reset_match -> _start_round_intro
## -> _update_fight_camera), samples the live Camera3D frame by frame and checks
## it against place_world() of the decoded JSON, so the test cannot pass with
## invented keyframes. It covers:
##   * player on the LEFT  (default single-player slot 0)      anchor = player
##   * player on the RIGHT (same fighter moved to the right)   anchor = player
##   * opponent-anchored intro (dummy = computer)               anchor = computer
##     -> the authored camera must land on the opposite lateral side, proving the
##        dummy / mirror wiring works for the "matching opponent intro" case.
##   * a missing JSON must fall back to the pre-existing analytic follow camera.
##
## usage: --script res://tests/validate_intro_camera.gd -- <bruce.glb> <brick.glb> <gametext_root>

const Player = preload("res://scripts/camera_anm_player.gd")
const CLIP_JSON := "res://data/camera_anm/m01_intro_01.json"
const CLIP_NAME := "m01_intro_01"
var CAM_SOURCE_UNITS_TO_WORLD: float = (
    PortFighter.WORLD_CHARACTER_HEIGHT / PortFighter.SOURCE_CHARACTER_HEIGHT
)

var _failures: Array[String] = []
var _results: Dictionary = {}


func _initialize() -> void:
    call_deferred("_run")


func _check(label: String, ok: bool, detail: String = "") -> void:
    if ok:
        print("PASS ", label, " ", detail)
    else:
        _failures.append(label + " " + detail)
        push_error("FAIL " + label + " " + detail)
        print("FAIL ", label, " ", detail)


func _near(a: float, b: float, tol: float) -> bool:
    return absf(a - b) <= tol


func _new_scene(bruce: String, brick: String, text_root: String) -> Node:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_TIME", "60")
    # Start with the intro suppressed so the deferred _start_direct_intro() does
    # not race the explicit _start_round_intro() call, then flip it to "1" in
    # _setup_intro() right before entering the state.
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", bruce)
    OS.set_environment("BRUCELEE_OPPONENT_GLB", brick)
    OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", "res://data/fighting_set_m03_mapped_attacks.json")
    OS.set_environment("BRUCELEE_GAME_TEXT_ROOT", text_root)
    OS.set_environment("BRUCELEE_GAME_TEXT_FLIP", "1")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    return scene


func _wait_candidates(scene: Node, timeout_frames: int = 900) -> bool:
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


func _place(scene: Node, player_on_right: bool) -> void:
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    if player_on_right:
        player.global_position = Vector3(2.0, 1.20, 0.0)
        computer.global_position = Vector3(-2.0, 1.20, 0.0)
        player.facing = -1.0
        computer.facing = 1.0
    else:
        player.global_position = Vector3(-2.0, 1.20, 0.0)
        computer.global_position = Vector3(2.0, 1.20, 0.0)
        player.facing = 1.0
        computer.facing = -1.0


func _setup_intro(scene: Node, scenario: String) -> void:
    ## Real path: reset the match, place the fighters, then enter SetState(3)
    ## through _start_round_intro(), which arms the authored intro camera.
    scene._reset_match()
    # This regression keeps the original m01_intro_01 fixture stable; the new
    # validate_remaining_cameras.gd covers all other pool choices.
    var player: PortFighter = scene.get("player")
    player.select_intro_clip(0)
    var player_on_right: bool = scenario == "player_right"
    _place(scene, player_on_right)
    OS.set_environment("BRUCELEE_ROUND_INTRO", "1")
    scene._start_round_intro()
    if scenario == "opponent_anchor":
        # Re-arm with the opponent as the dummy (the "matching opponent intro"
        # branch). Same clip, same JSON, only the reference fighter changes.
        scene._intro_camera_begin(scene.get("computer"), false, CLIP_NAME)


func _torso_world(fighter: PortFighter, height: float) -> Vector3:
    var ground: float = fighter.global_position.y - PortFighter.PLAYER_ORIGIN_HEIGHT
    return Vector3(fighter.global_position.x, ground + height, fighter.global_position.z)


func _anchor_framed(bundle: Dictionary, anchor_is_player: bool) -> bool:
    ## The authored clip is a dummy-relative close-up: the anchor fighter (the
    ## camera dummy) must be on screen with the camera aimed straight at the
    ## authored look-at target. The other fighter sits behind the camera plane at
    ## the port's wide 4 m fight-start spacing (documented in the report).
    if bundle.is_empty() or bundle["samples"].is_empty():
        return false
    var s: Dictionary = bundle["samples"][0]
    var v: Vector2 = Vector2(s["viewport"][0], s["viewport"][1])
    var p: Vector2 = (
        Vector2(s["player_screen"][0], s["player_screen"][1]) if anchor_is_player
        else Vector2(s["computer_screen"][0], s["computer_screen"][1])
    )
    if float(s["look_dot"]) < 0.99:
        return false
    return _inside(v, p)


func _sample_scene(scene: Node, steps: int) -> Dictionary:
    var ref = Player.new()
    if not ref.load_json(CLIP_JSON):
        _check("reference json load", false, CLIP_JSON)
        return {}
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    var camera: Camera3D = scene.get("fight_camera")
    var a: Vector3 = scene.get("_camera_anm_a")
    var b: Vector3 = scene.get("_camera_anm_b")
    var mirror: bool = scene.get("_camera_anm_mirror")
    var samples: Array = []
    var frame_accum: float = 0.0
    var max_err: float = 0.0
    var max_fov_err: float = 0.0
    for step: int in range(steps):
        scene._update_fight_camera(1.0 / 60.0)
        frame_accum += 0.5  # 30 fps clip sampled at 60 fps updates
        if step % 10 == 0 or step == steps - 1:
            var index: int = int(minf(frame_accum, float(ref.frame_count() - 1)))
            var expected: Dictionary = ref.place_world(index, a, b, mirror)
            var err: float = camera.global_position.distance_to(expected["camera_world"])
            max_err = maxf(max_err, err)
            var fov_err: float = absf(camera.fov - float(expected["fov_degrees"]))
            max_fov_err = maxf(max_fov_err, fov_err)
            var p_screen: Vector2 = camera.unproject_position(_torso_world(player, 1.1))
            var c_screen: Vector2 = camera.unproject_position(_torso_world(computer, 1.1))
            var fwd: Vector3 = -camera.global_transform.basis.z
            var look_dot: float = fwd.normalized().dot(
                (expected["target_world"] - camera.global_position).normalized()
            )
            samples.append({
                "frame_index": index,
                "camera": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
                "target": [expected["target_world"].x, expected["target_world"].y, expected["target_world"].z],
                "fov": camera.fov,
                "fov_expected": expected["fov_degrees"],
                "player_screen": [p_screen.x, p_screen.y],
                "computer_screen": [c_screen.x, c_screen.y],
                "look_dot": look_dot,
                "viewport": [root.get_visible_rect().size.x, root.get_visible_rect().size.y],
                "place_world_err": err,
            })
    return {
        "samples": samples,
        "max_place_world_err": max_err,
        "max_fov_err": max_fov_err,
        "mirror": mirror,
        "a": [a.x, a.y, a.z],
        "b": [b.x, b.y, b.z],
        "a_b_len": (b - a).length(),
        "clip": scene.get("_camera_anm_clip"),
        "state": scene.get("match_state"),
        "player_x": player.global_position.x,
        "computer_x": computer.global_position.x,
        "last_frame_camera": [
            camera.global_position.x, camera.global_position.y, camera.global_position.z
        ],
    }


func _inside(v: Vector2, screen: Vector2, x_lo: float = -0.05, x_hi: float = 1.05) -> bool:
    return (screen.x >= v.x * x_lo and screen.x <= v.x * x_hi
            and screen.y >= -0.05 * v.y and screen.y <= 1.05 * v.y)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 3:
        push_error("Expected <bruce.glb> <brick.glb> <gametext_root>")
        quit(2)
        return
    var bruce: String = args[0]
    var brick: String = args[1]
    var text_root: String = args[2]

    var scenarios: Array = [
        {"name": "player_left", "steps": 240, "anchor_is_player": true},
        {"name": "player_right", "steps": 240, "anchor_is_player": true},
        {"name": "opponent_anchor", "steps": 240, "anchor_is_player": false},
    ]
    for spec: Dictionary in scenarios:
        var name: String = spec["name"]
        var scene: Node = _new_scene(bruce, brick, text_root)
        if not await _wait_candidates(scene):
            push_error(name + " candidates did not load")
            quit(1)
            return
        await process_frame
        _freeze(scene)
        _setup_intro(scene, name)
        var bundle: Dictionary = _sample_scene(scene, int(spec["steps"]))
        _check(name + " enters MATCH_STATE_INTRO", int(bundle.get("state", -1)) == 3,
                str(bundle.get("state", -1)))
        _check(name + " clip loaded", str(bundle.get("clip", "")) == CLIP_NAME,
                str(bundle.get("clip", "")))
        _check(name + " mirror false", not bool(bundle.get("mirror", true)),
                str(bundle.get("mirror", true)))
        _check(name + " frames match place_world",
                float(bundle.get("max_place_world_err", 99.0)) < 0.002,
                str(bundle.get("max_place_world_err", 99.0)))
        _check(name + " fov follows the decoded animation",
                float(bundle.get("max_fov_err", 99.0)) < 0.01,
                str(bundle.get("max_fov_err", 99.0)))
        _check(name + " camera dummy framed at READY",
                _anchor_framed(bundle, bool(spec["anchor_is_player"])))
        # Camera side proves the dummy/opponent wiring: player-anchored shoots
        # from +x when the player is on the left and from -x when on the right;
        # the opponent-anchored variant sits on the opposite side of player_left.
        var first_cam_x: float = float(bundle["samples"][0]["camera"][0])
        if name == "player_left":
            _check(name + " camera on the opponent (+x) side", first_cam_x > 0.5, str(first_cam_x))
        elif name == "player_right":
            _check(name + " camera on the opponent (-x) side", first_cam_x < -0.5, str(first_cam_x))
        else:
            _check(name + " opponent dummy mirrors the camera (-x)", first_cam_x < -0.5, str(first_cam_x))
        # Per-frame playback reaches the last authored frame (120) with no
        # invented tail; then the clip finishes and hands the view back to the
        # analytic camera (native timing: the 4.03 s clip outlives SetState(3)).
        _check(name + " reaches the last authored frame",
                float(bundle["samples"][-1]["frame_index"]) == 120,
                "last_index=%s" % bundle["samples"][-1]["frame_index"])
        var finished: bool = false
        for _f: int in range(12):
            scene._update_fight_camera(1.0 / 60.0)
            if str(scene.get("_camera_anm_clip")).is_empty():
                finished = true
                break
        _check(name + " clip finishes and clears after frame 120", finished)
        _results[name] = bundle
        scene.queue_free()
        await process_frame

    # ---- Fail-back: JSON missing -> pre-existing analytic follow camera ----
    var scene: Node = _new_scene(bruce, brick, text_root)
    if not await _wait_candidates(scene):
        push_error("fallback candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    scene.set("_camera_anm_dir", "res://data/camera_anm_missing/")
    _setup_intro(scene, "player_left")
    var fb_clip: String = scene.get("_camera_anm_clip")
    var played: bool = scene._camera_anm_play_authored(1.0 / 60.0)
    scene._update_fight_camera(1.0 / 60.0)
    var camera: Camera3D = scene.get("fight_camera")
    var sm_a: Vector3 = scene.get("_cam_smooth_a")
    var sm_b: Vector3 = scene.get("_cam_smooth_b")
    var expected_pose: Dictionary = scene._native_camera_pose(sm_a, sm_b, scene._camera_aspect_scale())
    var expected_pos: Vector3 = (expected_pose["position"] as Vector3) * CAM_SOURCE_UNITS_TO_WORLD
    _check("fallback clip stays empty", fb_clip.is_empty(), fb_clip)
    _check("fallback play_authored false", not played)
    _check("fallback keeps the analytic fov 75", _near(camera.fov, 75.0, 0.001), str(camera.fov))
    _check("fallback uses the analytic follow camera",
            camera.global_position.distance_to(expected_pos) < 0.002,
            "%s vs %s" % [camera.global_position, expected_pos])
    _results["fallback"] = {
        "clip": fb_clip,
        "played": played,
        "fov": camera.fov,
        "camera": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
        "expected": [expected_pos.x, expected_pos.y, expected_pos.z],
        "state": scene.get("match_state"),
    }
    scene.queue_free()
    await process_frame

    # ---- Intro camera lifetime across the state machine ----
    scene = _new_scene(bruce, brick, text_root)
    if not await _wait_candidates(scene):
        push_error("camera-end candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    _setup_intro(scene, "player_left")
    var ce_clip_after_begin: String = scene.get("_camera_anm_clip")
    scene._enter_match_state(4)  # FIGHT: the authored intro must survive here
    var ce_clip_after_fight: String = scene.get("_camera_anm_clip")
    scene._enter_match_state(5)  # TIME_UP: any other state change ends it
    var ce_clip_after_timeup: String = scene.get("_camera_anm_clip")
    var ce_anchor_after_timeup = scene.get("_camera_anm_anchor")
    _check("intro camera active on SetState(3) begin", ce_clip_after_begin == CLIP_NAME,
            ce_clip_after_begin)
    _check("intro camera survives INTRO -> FIGHT (native clip runs past 3 s)",
            ce_clip_after_fight == CLIP_NAME, ce_clip_after_fight)
    _check("intro camera ends on a non-intro state change",
            ce_clip_after_timeup.is_empty() and ce_anchor_after_timeup == null,
            "clip=%s anchor=%s" % [ce_clip_after_timeup, ce_anchor_after_timeup])
    _results["camera_end"] = {
        "clip_after_begin": ce_clip_after_begin,
        "clip_after_fight": ce_clip_after_fight,
        "clip_after_timeup": ce_clip_after_timeup,
    }
    scene.queue_free()
    await process_frame

    _results["failures"] = _failures
    print("INTRO_CAMERA_VALIDATION=" + JSON.stringify(_results))
    quit(0 if _failures.is_empty() else 1)

extends SceneTree
## Headless acceptance test for the original m01_victory_01 camera on the REAL
## res://scenes/main.tscn MATCH_WIN (state 12) / MATCH_LOSE (state 13) result
## pose. It drives the real ported result path, samples the live Camera3D frame
## by frame, and checks it against place_world() of the decoded JSON (so the
## test cannot pass with invented keyframes). It also checks the winner is
## framed for both a left-side and a right-side winner, and that a missing JSON
## falls back to the pre-existing fixed result camera.
##
## usage: --script res://tests/validate_victory_camera.gd -- <bruce.glb> <brick.glb> <gametext_root>

const Player = preload("res://scripts/camera_anm_player.gd")
const CLIP_JSON := "res://data/camera_anm/m01_victory_01.json"

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


func _setup_result_pose(
        scene: Node, winner_is_player: bool
) -> void:
    ## Real result path: both fighters set to the origin by SetState(12/13),
    ## winner keeps a victory pose, loser hidden. Positions are set first so the
    ## captured winner->loser yaw is representative.
    scene._reset_match()
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.global_position = Vector3(-2.0, 1.20, 0.0)
    computer.global_position = Vector3(2.0, 1.20, 0.0)
    player.facing = 1.0
    computer.facing = -1.0
    scene.pending_round_winner = 1 if winner_is_player else 2
    scene.player_rounds = 2 if winner_is_player else 0
    scene.computer_rounds = 0 if winner_is_player else 2
    scene._begin_winner_result_pose()


func _sample_scenario(scene: Node, winner_is_player: bool, steps: int) -> Dictionary:
    ## Step _update_fight_camera (the real per-frame camera entry point) and
    ## record live camera data, cross-checking every sample against place_world.
    var clip: String = String(scene.get("_camera_anm_clip"))
    var ref = Player.new()
    if clip.is_empty() or not ref.load_json("res://data/camera_anm/" + clip + ".json"):
        _check("reference json load", false, clip)
        return {}
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    var winner: PortFighter = player if winner_is_player else computer
    var camera: Camera3D = scene.get("fight_camera")
    var a: Vector3 = scene.get("_camera_anm_a")
    var b: Vector3 = scene.get("_camera_anm_b")
    var mirror: bool = scene.get("_camera_anm_mirror")
    var samples: Array = []
    var frame_accum: float = 0.0
    var max_err: float = 0.0
    var start_cam: Vector3 = Vector3.ZERO
    for step: int in range(steps):
        scene._update_fight_camera(1.0 / 60.0)
        frame_accum += 0.5  # 30 fps clip at 60 fps updates
        if step % 10 == 0:
            var index: int = int(minf(frame_accum, float(ref.frame_count() - 1)))
            var expected: Dictionary = ref.place_world(index, a, b, mirror)
            var err: float = camera.global_position.distance_to(expected["camera_world"])
            max_err = maxf(max_err, err)
            var ground_y: float = winner.global_position.y - PortFighter.PLAYER_ORIGIN_HEIGHT
            var screen: Vector2 = camera.unproject_position(
                Vector3(winner.global_position.x, ground_y + 1.35, winner.global_position.z)
            )
            var head: Vector3 = Vector3(
                winner.global_position.x, ground_y + 1.75, winner.global_position.z
            )
            var head_screen: Vector2 = camera.unproject_position(head)
            var fwd: Vector3 = -camera.global_transform.basis.z
            var look_dot: float = fwd.normalized().dot((head - camera.global_position).normalized())
            var view: Vector2 = root.get_visible_rect().size
            samples.append({
                "frame_index": index,
                "camera": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
                "target": [expected["target_world"].x, expected["target_world"].y, expected["target_world"].z],
                "fov": camera.fov,
                "winner_screen": [screen.x, screen.y],
                "head_screen": [head_screen.x, head_screen.y],
                "look_dot": look_dot,
                "viewport": [view.x, view.y],
                "place_world_err": err,
            })
            if step == 0:
                start_cam = camera.global_position
    return {
        "samples": samples,
        "max_place_world_err": max_err,
        "start_cam": start_cam,
        "mirror": mirror,
        "a": [a.x, a.y, a.z],
        "b": [b.x, b.y, b.z],
        "a_b_len": (b - a).length(),
        "winner_visible": winner.visible,
        "loser_visible": (computer if winner_is_player else player).visible,
        "clip": scene.get("_camera_anm_clip"),
    }


func _winner_framed(bundle: Dictionary) -> bool:
    if bundle.is_empty():
        return false
    for s: Dictionary in bundle["samples"]:
        var v: Vector2 = Vector2(s["viewport"][0], s["viewport"][1])
        var p: Vector2 = Vector2(s["head_screen"][0], s["head_screen"][1])
        if float(s["look_dot"]) < 0.9:
            return false
        if p.x < v.x * 0.02 or p.x > v.x * 0.98:
            return false
        if p.y < 0.0 or p.y > v.y:
            return false
    return true


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 3:
        push_error("Expected <bruce.glb> <brick.glb> <gametext_root>")
        quit(2)
        return
    var bruce: String = args[0]
    var brick: String = args[1]
    var text_root: String = args[2]

    # ---- Winner LEFT (player, MATCH_WIN state 12) ----
    var scene: Node = _new_scene(bruce, brick, text_root)
    if not await _wait_candidates(scene):
        push_error("winner-left candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    _setup_result_pose(scene, true)
    var left_state: int = scene.get("match_state")
    var left_bundle: Dictionary = _sample_scenario(scene, true, 130)
    _check("winner-left enters MATCH_WIN", left_state == 12, str(left_state))
    _check("winner-left clip loaded", str(left_bundle.get("clip", "")) == "m01_victory_01",
            str(left_bundle.get("clip", "")))
    _check("winner-left winner visible", bool(left_bundle.get("winner_visible", false)))
    _check("winner-left loser hidden", not bool(left_bundle.get("loser_visible", true)))
    _check("winner-left mirror false", not bool(left_bundle.get("mirror", true)))
    _check("winner-left frames match place_world", float(left_bundle.get("max_place_world_err", 99.0)) < 0.002,
            str(left_bundle.get("max_place_world_err", 99.0)))
    _check("winner-left winner framed", _winner_framed(left_bundle))
    _results["winner_left"] = left_bundle
    _results["winner_left_state"] = left_state
    _results["winner_left_winner"] = "player"
    scene.queue_free()
    await process_frame

    # ---- Winner RIGHT (computer, MATCH_LOSE state 13) ----
    scene = _new_scene(bruce, brick, text_root)
    if not await _wait_candidates(scene):
        push_error("winner-right candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    _setup_result_pose(scene, false)
    var right_state: int = scene.get("match_state")
    var right_bundle: Dictionary = _sample_scenario(scene, false, 200)
    _check("winner-right enters MATCH_LOSE", right_state == 13, str(right_state))
    _check("winner-right clip loaded",
            str(right_bundle.get("clip", "")) == "m03_victory_02",
            str(right_bundle.get("clip", "")))
    _check("winner-right uses the opponent characters.list victory camera",
            str(right_bundle.get("clip", "")) == "m03_victory_02",
            str(right_bundle.get("clip", "")))
    _check("winner-right winner visible", bool(right_bundle.get("winner_visible", false)))
    _check("winner-right loser hidden", not bool(right_bundle.get("loser_visible", true)))
    _check("winner-right mirror true", bool(right_bundle.get("mirror", false)))
    _check("winner-right frames match place_world", float(right_bundle.get("max_place_world_err", 99.0)) < 0.002,
            str(right_bundle.get("max_place_world_err", 99.0)))
    _check("winner-right winner framed", _winner_framed(right_bundle))
    _results["winner_right"] = right_bundle
    _results["winner_right_state"] = right_state
    _results["winner_right_winner"] = "computer"
    scene.queue_free()
    await process_frame

    # ---- Fail-back: JSON missing -> pre-existing fixed result camera ----
    scene = _new_scene(bruce, brick, text_root)
    if not await _wait_candidates(scene):
        push_error("fallback candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    scene.set("_camera_anm_dir", "res://data/camera_anm_missing/")
    _setup_result_pose(scene, true)
    var fb_clip: String = scene.get("_camera_anm_clip")
    var played: bool = scene._camera_anm_play_authored(1.0 / 60.0)
    # Advance the camera via the real entry point to the fallback branch.
    scene._update_fight_camera(1.0 / 60.0)
    var camera: Camera3D = scene.get("fight_camera")
    var winner: PortFighter = scene.get("player")
    var target: Vector3 = winner.global_position + Vector3(0.0, 1.0, 0.0)
    var expected: Vector3 = target + Vector3(0.0, 1.4, 4.2)
    _check("fallback clip stays empty", fb_clip.is_empty(), fb_clip)
    _check("fallback play_authored false", not played)
    _check("fallback uses fixed winner shot",
            camera.global_position.distance_to(expected) < 0.001,
            "%s vs %s" % [camera.global_position, expected])
    _results["fallback"] = {
        "clip": fb_clip,
        "played": played,
        "camera": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
        "expected": [expected.x, expected.y, expected.z],
    }
    scene.queue_free()
    await process_frame

    # ---- Camera must end when the match state leaves 12/13, and on reset ----
    scene = _new_scene(bruce, brick, text_root)
    if not await _wait_candidates(scene):
        push_error("camera-end candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    _setup_result_pose(scene, true)
    var ce_clip_after_begin: String = scene.get("_camera_anm_clip")
    scene._enter_match_state(15)  # MATCH_STATE_ROUND_END is not a result state
    var ce_clip_after_exit: String = scene.get("_camera_anm_clip")
    var ce_anchor_after_exit = scene.get("_camera_anm_anchor")
    _check("camera-end clip active on begin", ce_clip_after_begin == "m01_victory_01", ce_clip_after_begin)
    _check("camera ends on match-state exit",
            ce_clip_after_exit.is_empty() and ce_anchor_after_exit == null,
            "clip=%s anchor=%s" % [ce_clip_after_exit, ce_anchor_after_exit])
    # Re-arm the result pose, then reset the round: the camera must end and the
    # fixed result override must be cleared so the analytic fight camera returns.
    _setup_result_pose(scene, true)
    var ce_clip_rebegin: String = scene.get("_camera_anm_clip")
    scene._reset_round()
    var ce_clip_after_reset: String = scene.get("_camera_anm_clip")
    var ce_anchor_after_reset = scene.get("_camera_anm_anchor")
    var ce_override_after_reset: bool = scene.get("_result_camera_override")
    var ce_state_after_reset: int = scene.get("match_state")
    _check("camera-end clip re-armed before reset", ce_clip_rebegin == "m01_victory_01", ce_clip_rebegin)
    _check("camera ends on round reset",
            ce_clip_after_reset.is_empty() and ce_anchor_after_reset == null,
            "clip=%s anchor=%s" % [ce_clip_after_reset, ce_anchor_after_reset])
    _check("reset clears the fixed result-camera override", not ce_override_after_reset)
    _check("reset returns to MATCH_STATE_FIGHT", ce_state_after_reset == 4, str(ce_state_after_reset))
    _results["camera_end"] = {
        "clip_after_begin": ce_clip_after_begin,
        "clip_after_exit": ce_clip_after_exit,
        "clip_rebegin": ce_clip_rebegin,
        "clip_after_reset": ce_clip_after_reset,
        "override_after_reset": ce_override_after_reset,
        "state_after_reset": ce_state_after_reset,
    }
    scene.queue_free()
    await process_frame

    _results["failures"] = _failures
    print("VICTORY_CAMERA_VALIDATION=" + JSON.stringify(_results))
    quit(0 if _failures.is_empty() else 1)

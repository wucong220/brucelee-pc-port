extends SceneTree
## Headless validation of the per-clip authored replay camera on the real
## res://scenes/main.tscn.  This script deliberately drives the actual state-6
## entry / Update case-6 paths rather than a standalone camera prototype.
##
## Recovered rules under test:
##   SetState(6) @0x188960: StopCameraAnimation + CBeatEmUpCamera::Restart
##   CameraUpdate @0x188d88: state 6 uses dummy=fighter[0x7e0], mirror=0
##   Update case 6 @0x18d0ac: sample=elapsed+2*base, 0.5x, ReplayEnded loops
##   camera_anm: 30 fps, X_camera.anm belongs to action clip X, no interpolation
##   CBeatEmUpCamera::Update @0x244230: analytic branch (camera+0x0c==0) with
##     param_9=(state==6) adds DAT_002444a0 = +100.0 source Z to camZ only
##   A recorded clip with no "camera" KDF sub-animation does not arm
##     StartAnimation, so it uses that analytic branch instead of state 14.
##
## Run with BRUCELEE_PLAYER_GLB / BRUCELEE_OPPONENT_GLB pointing at the verified
## local candidates; this script also sets them to those paths when absent.

const CameraAnm = preload("res://scripts/camera_anm_player.gd")
const NativeMatchStates = preload("res://scripts/native_match_states.gd")
const StoryFlowScript = preload("res://scripts/story_flow.gd")
const StoryStateScript = preload("res://scripts/story_state.gd")
const StoryDataScript = preload("res://scripts/story_data.gd")
const StoryLangScript = preload("res://scripts/story_lang.gd")

const FRAME: float = 1.0 / 60.0
const BASE_MS: int = 100000
const RECORD_STEP_MS: int = 8
const FIRST_CLIP: String = "m01_grab_01"
const SECOND_CLIP: String = "m01_end_attack_01"
const NO_CAMERA_CLIP: String = "m01_idle_01"
const SWITCH_AT: int = 20
const RECORD_COUNT: int = 40
const ANALYTIC_FOV: float = 75.0
## CBeatEmUpCamera::Update param_9 (state==6) offset, DAT_002444a0, source Z units.
const LIFT_SOURCE: float = 100.0
const CAM_SCALE: float = (
    PortFighter.WORLD_CHARACTER_HEIGHT / PortFighter.SOURCE_CHARACTER_HEIGHT
)

var failures: Array[String] = []
var checks: int = 0
var main: Node = null
var flow: Node = null


func _initialize() -> void:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_STORY_FLOW", "1")
    OS.set_environment("BRUCELEE_REPLAY_RECORD", "1")
    OS.set_environment("BRUCELEE_ATTRACT", "")
    OS.set_environment("BRUCELEE_CONTINUE", "")
    for flag: String in ["BRUCELEE_GAME_MODE", "BRUCELEE_STORY_LAUNCH"]:
        OS.set_environment(flag, "")
    if OS.get_environment("BRUCELEE_PLAYER_GLB").is_empty():
        OS.set_environment(
            "BRUCELEE_PLAYER_GLB",
            "D:\\BruceLeeWork\\bruce-full-20261103\\out\\bruce_full_121_20261103.glb"
        )
    if OS.get_environment("BRUCELEE_OPPONENT_GLB").is_empty():
        OS.set_environment(
            "BRUCELEE_OPPONENT_GLB",
            "D:\\BruceLeeWork\\brick-full-20261103\\candidate\\brick_full_94_20261103.glb"
        )
    await _run()
    if failures.is_empty():
        print("REPLAY_CAMERA_VALIDATION=PASS checks=%d" % checks)
        quit(0)
        return
    for failure: String in failures:
        push_error("REPLAY_CAMERA_VALIDATION_FAIL " + failure)
    print("REPLAY_CAMERA_VALIDATION=FAIL checks=%d failures=%d" % [
        checks, failures.size(),
    ])
    quit(1)


func _check(condition: bool, label: String, detail: String = "") -> void:
    checks += 1
    if condition:
        print("PASS  " + label)
        return
    failures.append(label + ((" | " + detail) if not detail.is_empty() else ""))


func _approx(a: float, b: float, eps: float = 0.001) -> bool:
    return absf(a - b) <= eps


func _vector_near(a: Vector3, b: Vector3, eps: float = 0.001) -> bool:
    return _approx(a.x, b.x, eps) and _approx(a.y, b.y, eps) and _approx(a.z, b.z, eps)


func _load_replay_map() -> Dictionary:
    var file: FileAccess = FileAccess.open(
        "res://data/camera_anm/replay_camera_map.json", FileAccess.READ
    )
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    var clips: Variant = Dictionary(parsed).get("camera_clips", {})
    if typeof(clips) != TYPE_DICTIONARY:
        return {}
    return Dictionary(clips)


func _check_map() -> void:
    var rows: Dictionary = _load_replay_map()
    _check(rows.size() == 70, "strict replay map has exactly 70 recovered cameras",
        "count=%d" % rows.size())
    var catalog: FileAccess = FileAccess.open(
        "res://data/camera_anm/camera_catalog.json", FileAccess.READ
    )
    _check(catalog != null, "source camera_catalog.json is present")
    var all_exact: bool = true
    var all_files: bool = true
    for clip: String in rows:
        var row: Dictionary = Dictionary(rows[clip])
        if String(row.get("camera_anm", "")) != clip + "_camera.anm":
            all_exact = false
        if String(row.get("file", "")) != clip + ".json":
            all_exact = false
        if int(row.get("frames", 0)) <= 0 or not _approx(float(row.get("fps", 0.0)), 30.0):
            all_exact = false
        if not FileAccess.file_exists("res://data/camera_anm/" + String(row.get("file", ""))):
            all_files = false
    _check(all_exact, "every map row uses only the recovered ANM name and 30 fps metadata")
    _check(all_files, "every mapped camera JSON exists")
    _check(not rows.has(NO_CAMERA_CLIP), "idle clip has no invented camera")
    _check(not rows.has("m01_grab_01_forbigguy"),
        "an unrecovered size variant is not aliased to a base camera")
    _check(rows.has(FIRST_CLIP) and rows.has(SECOND_CLIP),
        "both deterministic test clips have recovered cameras")


func _setup_main() -> Node:
    var packed: PackedScene = load("res://scenes/main.tscn")
    _check(packed != null, "real scenes/main.tscn loads")
    if packed == null:
        return null
    var node: Node = packed.instantiate()
    root.add_child(node)
    for _i in 4:
        await process_frame
    node.set_physics_process(false)
    node.set_process(false)
    var player: PortFighter = node.get("player")
    var computer: PortFighter = node.get("computer")
    if player != null:
        player.set_physics_process(false)
    if computer != null:
        computer.set_physics_process(false)
    return node


func _attach_flow(node: Node) -> Node:
    flow = StoryFlowScript.new()
    root.add_child(flow)
    flow.set("main", node)
    var run: Dictionary = {
        "kind": "vsbattle", "chapter": "chapter1", "event": "replay_camera_test",
        "event_type": "vsbattle", "sub_index": 9998, "opponents": ["brick"],
        "opponent_index": 0, "player": "brucelee", "scenery": "",
        "difficulty_slot": 0, "difficulty_value": 0, "fights_done": 0,
        "elapsed_seconds": 0.0, "fight_results": [], "carried_health": -1.0,
        "source": {}, "win_on_lose": "true",
    }
    flow.battle_run = run
    flow.battle_spec = {"opponent": "brick"}
    flow.battle_started_msec = Time.get_ticks_msec()
    var story_state = StoryStateScript.new()
    story_state.difficulty_slot = 0
    story_state.save_slot = 0
    story_state.set_pending({
        "run": run, "spec": {"opponent": "brick"},
        "started_msec": Time.get_ticks_msec(), "save_slot": 0,
        "chapter_index": 0, "event_index": 0, "unlock_mark": 0,
    })
    flow.state = story_state
    flow.data = StoryDataScript.new()
    flow.lang = StoryLangScript.new()
    node.set("story_flow", flow)
    OS.set_environment("BRUCELEE_STORY_FLOW", "1")
    return flow


func _force_match_lost_by_player(node: Node) -> void:
    node.set("rounds_to_win", 1)
    node.set("round_number", 1)
    node.set("player_rounds", 0)
    node.set("computer_rounds", 0)
    node.set("pending_round_winner", 0)
    node.set("match_state", 4)
    node.set("match_state_time", 0.0)
    node.set("done", false)
    node.set("match_over", false)
    node.set("_replay_handed_off", false)
    node.set("_countdown_handed_off", false)


func _fill_buffers(node: Node, first_clip: String, second_clip: String) -> void:
    var player: PortFighter = node.get("player")
    var computer: PortFighter = node.get("computer")
    _check(player != null and computer != null, "main.tscn builds both fighters")
    if player == null or computer == null:
        return
    _check(player.replay_recorder != null and computer.replay_recorder != null,
        "both recovered recorders are attached")
    if player.replay_recorder == null or computer.replay_recorder == null:
        return
    var pb = player.replay_recorder.buffer
    var cb = computer.replay_recorder.buffer
    pb.clear()
    cb.clear()
    var p0: Vector3 = node.get("_fight_start_player")
    var c0: Vector3 = node.get("_fight_start_computer")
    var q := Quaternion(0.0, 0.0, 0.0, 1.0)
    for i: int in RECORD_COUNT:
        var clip: String = first_clip if i < SWITCH_AT else second_clip
        var t: int = BASE_MS + i * RECORD_STEP_MS
        pb.append_record(p0, q, clip, 0.0, 0, t)
        cb.append_record(c0, q, clip, 0.0, 0, t)
    _check(pb.size() == RECORD_COUNT and cb.size() == RECORD_COUNT,
        "deterministic replay buffers were filled",
        "player=%d computer=%d" % [pb.size(), cb.size()])


func _analytic_world(node: Node) -> Vector3:
    var a: Vector3 = node.get("_replay_camera_a")
    var b: Vector3 = node.get("_replay_camera_b")
    var pose: Dictionary = CameraAnm.analytic_pose(a, b, 0)
    return CameraAnm.orig_to_godot(pose["position"] as Vector3)


func _check_no_analytic(node: Node, label: String) -> void:
    var cam = node.get("fight_camera")
    _check(not _approx(float(cam.fov), ANALYTIC_FOV, 0.001),
        label + ": FOV is not the analytic 75 degrees",
        "fov=%.3f" % float(cam.fov))
    var analytic: Vector3 = _analytic_world(node)
    _check(cam.global_position.distance_to(analytic) > 0.01,
        label + ": camera position is not the analytic follow pose",
        "distance=%.4f" % cam.global_position.distance_to(analytic))


func _check_analytic_pose(node: Node, player: PortFighter, computer: PortFighter,
        label: String) -> void:
    ## Verify the recovered state-6 analytic branch: the exact follow pose from
    ## _native_camera_pose(a, b, 1.0), plus DAT_002444a0 = +100.0 source Z on
    ## the CAMERA only.  The look-at target and up are unchanged.
    var cam = node.get("fight_camera")
    _check(_approx(float(cam.fov), ANALYTIC_FOV, 0.001),
        label + ": FOV is the analytic 75 degrees",
        "fov=%.3f" % float(cam.fov))
    var a: Vector3 = node.call("_camera_fighter_point", player)
    var b: Vector3 = node.call("_camera_fighter_point", computer)
    var pose: Dictionary = node.call("_native_camera_pose", a, b, 1.0)
    var base_position: Vector3 = pose["position"] as Vector3
    var expected: Vector3 = base_position + Vector3(0.0, LIFT_SOURCE, 0.0)
    expected *= CAM_SCALE
    var unlifted: Vector3 = base_position * CAM_SCALE
    _check(_vector_near(cam.global_position, expected, 0.005),
        label + ": camera is the analytic follow pose + 100 source-Z",
        "live=%s expected=%s" % [str(cam.global_position), str(expected)])
    _check(_approx(cam.global_position.y - unlifted.y, LIFT_SOURCE * CAM_SCALE, 0.005),
        label + ": camera height lift is exactly DAT_002444a0 = 100.0 source units",
        "lift=%.6f expected=%.6f" % [
            cam.global_position.y - unlifted.y, LIFT_SOURCE * CAM_SCALE,
        ])
    var target_world: Vector3 = (pose["target"] as Vector3) * CAM_SCALE
    var to_target: Vector3 = (target_world - cam.global_position).normalized()
    var forward: Vector3 = -cam.global_transform.basis.z.normalized()
    _check(forward.dot(to_target) > 0.9999,
        label + ": look-at target is unchanged (no lift on the target)",
        "dot=%.8f" % forward.dot(to_target))


func _expected_frame(node: Node, clip: String) -> int:
    var rows: Dictionary = _load_replay_map()
    var row: Dictionary = Dictionary(rows.get(clip, {}))
    var anm = CameraAnm.new()
    if not anm.load_json("res://data/camera_anm/" + String(row.get("file", ""))):
        return -1
    var last: int = anm.frame_count() - 1
    var sample: int = int(node.get("_replay_camera_sample_ms"))
    return int(node.call("_replay_camera_frame_from_sample", sample, last))


func _camera_matches(node: Node, clip: String, label: String) -> void:
    var rows: Dictionary = _load_replay_map()
    var row: Dictionary = Dictionary(rows.get(clip, {}))
    _check(not row.is_empty(), label + ": clip is in the strict map", "clip=%s" % clip)
    if row.is_empty():
        return
    _check(String(node.get("_replay_camera_camera")) == String(row.get("camera_anm", "")),
        label + ": runtime uses the recovered camera ANM name",
        "got=%s expected=%s" % [
            String(node.get("_replay_camera_camera")),
            String(row.get("camera_anm", "")),
        ])
    var anm = CameraAnm.new()
    var loaded: bool = anm.load_json(
        "res://data/camera_anm/" + String(row.get("file", ""))
    )
    _check(loaded, label + ": decoded camera JSON loads")
    if not loaded:
        return
    _check(anm.frame_count() == int(row.get("frames", 0)),
        label + ": decoded frame count matches the catalog",
        "json=%d catalog=%d" % [anm.frame_count(), int(row.get("frames", 0))])
    var last: int = anm.frame_count() - 1
    var expected: int = _expected_frame(node, clip)
    var actual: int = int(node.get("_replay_camera_frame"))
    _check(expected >= 0 and expected == actual,
        label + ": camera frame follows the recovered 0.5x replay sample",
        "expected=%d actual=%d sample=%d clip_start=%d" % [
            expected, actual, int(node.get("_replay_camera_sample_ms")),
            int(node.get("_replay_camera_clip_start_ms")),
        ])
    if expected < 0:
        return
    var index: int = clampi(expected, 0, last)
    var a: Vector3 = node.get("_replay_camera_a")
    var b: Vector3 = node.get("_replay_camera_b")
    var pose: Dictionary = anm.place_world(index, a, b, false)
    var cam = node.get("fight_camera")
    _check(_approx(float(cam.fov), float(pose["fov_degrees"]), 0.001),
        label + ": live FOV equals decoded keyframe",
        "live=%.6f expected=%.6f" % [
            float(cam.fov), float(pose["fov_degrees"]),
        ])
    var expected_pos: Vector3 = pose["camera_world"] as Vector3
    _check(_vector_near(cam.global_position, expected_pos, 0.001),
        label + ": live position equals decoded keyframe",
        "live=%s expected=%s" % [str(cam.global_position), str(expected_pos)])
    if bool(pose["has_target"]):
        var target: Vector3 = pose["target_world"] as Vector3
        var expected_back: Vector3 = (expected_pos - target).normalized()
        var actual_back: Vector3 = cam.global_transform.basis.z.normalized()
        _check(actual_back.dot(expected_back) > 0.9999,
            label + ": live orientation equals decoded look-at",
            "dot=%.8f" % actual_back.dot(expected_back))
    _check_no_analytic(node, label)


func _drive(node: Node, steps: int) -> void:
    for _i in steps:
        node.call("_update_match_state", FRAME)
        node.call("_update_fight_camera", FRAME)


func _reset_for_scenario(node: Node) -> void:
    node.set("_replay_camera_map_path", "res://data/camera_anm/replay_camera_map.json")
    node.set("_replay_camera_map_loaded", false)
    node.set("_replay_camera_map", {})
    node.set("_replay_camera_anms", {})
    node.set("_replay_camera_fail_reason", "")
    node.set("_replay_camera_analytic", false)
    node.call("_reset_match")
    _force_match_lost_by_player(node)
    if flow == null:
        _attach_flow(node)
    else:
        node.set("story_flow", flow)


func _run() -> void:
    _check_map()
    main = await _setup_main()
    if main == null:
        return
    var player: PortFighter = main.get("player")
    var computer: PortFighter = main.get("computer")
    var states = main.get("native_states")
    _check(player != null and computer != null and states != null,
        "main.tscn builds fighters and NativeMatchStates")
    if player == null or computer == null or states == null:
        return

    # ---- Positive path: all recorded clips own recovered cameras ----
    _reset_for_scenario(main)
    _fill_buffers(main, FIRST_CLIP, SECOND_CLIP)
    main.call("_on_ko", player)
    _check(int(main.get("match_state")) == 6,
        "win_on_lose=true enters recovered state 6",
        "match_state=%d" % int(main.get("match_state")))
    if int(main.get("match_state")) != 6:
        return
    _check(int(states.state) == 6, "NativeMatchStates records the state-6 entry")
    _check(bool(main.get("_replay_camera_active")),
        "SetState(6) Restart arms an authored replay camera")
    _check(String(main.get("_replay_camera_clip")) == FIRST_CLIP,
        "state 6 starts from the player's first recorded clip",
        "clip=%s" % String(main.get("_replay_camera_clip")))
    main.call("_update_fight_camera", FRAME)
    _camera_matches(main, FIRST_CLIP, "state 6 frame 0")

    # 0.5x clock: four 60 Hz updates advance one 30 fps authored frame.
    _drive(main, 4)
    _check(int(main.get("_replay_camera_frame")) == 1,
        "four 60 Hz replay updates advance exactly one 30 fps authored frame",
        "frame=%d" % int(main.get("_replay_camera_frame")))
    _camera_matches(main, FIRST_CLIP, "state 6 frame 1")

    # Clip switch: the player dummy's recorded clip changes to SECOND_CLIP.
    var guard: int = 0
    while String(main.get("_replay_camera_clip")) != SECOND_CLIP and guard < 120:
        _drive(main, 1)
        guard += 1
    _check(String(main.get("_replay_camera_clip")) == SECOND_CLIP,
        "the authored camera switches with the player's recorded clip",
        "clip=%s" % String(main.get("_replay_camera_clip")))
    _check(String(player.get("replay_playback_clip")) == SECOND_CLIP,
        "RecordReplayUpdate plays the second recovered clip",
        "clip=%s" % String(player.get("replay_playback_clip")))
    _check(int(main.get("_replay_camera_clip_start_ms")) == BASE_MS + SWITCH_AT * RECORD_STEP_MS,
        "clip switch re-bases the camera clock to that clip's first record",
        "clip_start=%d" % int(main.get("_replay_camera_clip_start_ms")))
    _camera_matches(main, SECOND_CLIP, "state 6 after clip switch")

    # Loop Restart: both ReplayEnded -> SetState(6) -> camera Restart.
    guard = 0
    while int(states.replay_loops) == 0 and guard < 240:
        _drive(main, 1)
        guard += 1
    _check(int(states.replay_loops) >= 1,
        "both ReplayEnded re-enter SetState(6)")
    _check(String(main.get("_replay_camera_clip")) == FIRST_CLIP,
        "loop Restart returns to the first clip's authored camera",
        "clip=%s" % String(main.get("_replay_camera_clip")))
    _check(int(main.get("_replay_camera_frame")) == 0,
        "loop Restart rewinds the authored camera to frame 0",
        "frame=%d" % int(main.get("_replay_camera_frame")))
    main.call("_update_fight_camera", FRAME)
    _camera_matches(main, FIRST_CLIP, "state 6 after loop Restart")

    # ---- Recovered analytic fallback: a clip with no recovered camera ----
    # Direct disassembly proves such a clip does not arm StartAnimation, so
    # CBeatEmUpCamera::Update's analytic branch (param_9 = state==6, +100 Z)
    # runs.  It must NOT fall back to state 14.
    _reset_for_scenario(main)
    _fill_buffers(main, NO_CAMERA_CLIP, NO_CAMERA_CLIP)
    main.call("_on_ko", player)
    _check(int(main.get("match_state")) == 6,
        "a clip without a camera stays in state 6 (no state-14 fallback)",
        "match_state=%d" % int(main.get("match_state")))
    _check(int(states.state) == 6, "NativeMatchStates records the state-6 entry")
    _check(not bool(main.get("_replay_camera_active")),
        "no authored replay camera is armed for a no-camera clip")
    _check(bool(main.get("_replay_camera_analytic")),
        "the recovered analytic branch is armed for a no-camera clip")
    _check(String(main.get("_replay_camera_clip")) == NO_CAMERA_CLIP,
        "the analytic branch tracks the player's recorded clip",
        "clip=%s" % String(main.get("_replay_camera_clip")))
    var trace_refused: bool = false
    for entry: Dictionary in states.trace:
        if (int(entry.get("state", -1)) == 6
                and String(entry.get("result", "")) == "refused"
                and String(entry.get("reason", "")).contains("no-recovered-camera")):
            trace_refused = true
    _check(not trace_refused,
        "NativeMatchStates.trace has no no-camera refusal",
        "trace=%s" % str(states.trace))
    _check(String(states.fail_reason).is_empty(),
        "the state-6 entry leaves fail_reason clear",
        "reason=%s" % String(states.fail_reason))
    main.call("_update_fight_camera", FRAME)
    _check_analytic_pose(main, player, computer, "no-camera clip")

    # ---- Per-clip switch: authored camera -> analytic branch ----
    _reset_for_scenario(main)
    _fill_buffers(main, FIRST_CLIP, NO_CAMERA_CLIP)
    main.call("_on_ko", player)
    _check(int(main.get("match_state")) == 6,
        "mixed authored/no-camera buffers still enter state 6",
        "match_state=%d" % int(main.get("match_state")))
    _check(bool(main.get("_replay_camera_active")),
        "the authored first clip keeps its recovered camera")
    main.call("_update_fight_camera", FRAME)
    _camera_matches(main, FIRST_CLIP, "mixed: authored first clip")
    var mixed_guard: int = 0
    while String(main.get("_replay_camera_clip")) != NO_CAMERA_CLIP and mixed_guard < 160:
        _drive(main, 1)
        mixed_guard += 1
    _check(String(main.get("_replay_camera_clip")) == NO_CAMERA_CLIP,
        "the recorded clip switch reaches the no-camera clip",
        "clip=%s" % String(main.get("_replay_camera_clip")))
    _check(not bool(main.get("_replay_camera_active")),
        "the authored camera is released on switch to a no-camera clip")
    _check(bool(main.get("_replay_camera_analytic")),
        "the analytic branch is armed on switch to a no-camera clip")
    main.call("_update_fight_camera", FRAME)
    _check_analytic_pose(main, player, computer, "mixed: switched no-camera clip")

    # ---- Named fail closed: strict map missing ----
    _reset_for_scenario(main)
    _fill_buffers(main, FIRST_CLIP, SECOND_CLIP)
    main.set("_replay_camera_map_path", "res://data/camera_anm/this_map_does_not_exist.json")
    main.set("_replay_camera_map_loaded", false)
    main.call("_on_ko", player)
    _check(int(main.get("match_state")) == 14,
        "a missing strict map refuses state 6 and falls back to state 14",
        "match_state=%d" % int(main.get("match_state")))
    _check(String(main.get("_replay_camera_fail_reason")) == "replay-camera-map-missing",
        "the missing map is reported explicitly",
        "reason=%s" % String(main.get("_replay_camera_fail_reason")))
    _check(not bool(main.get("_replay_camera_active")),
        "no authored replay camera is active when the map is missing")

    main.set("story_flow", null)
    if flow != null:
        root.remove_child(flow)
        flow.free()
        flow = null
    root.remove_child(main)
    main.free()
    main = null

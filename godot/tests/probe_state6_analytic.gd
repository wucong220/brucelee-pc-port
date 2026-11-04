extends SceneTree
## Headless real-main.tscn probe for the state-6 replay camera.
##
## Deliberately uses only properties/probes that exist on BOTH the clean 3ff0d0f
## baseline and the state6-analytic patch, so the same file can be run twice and
## the STATE6_PROBE lines compared before/after:
##   case=authored    clip=m01_grab_01   -> must keep the authored camera
##   case=no-camera   clip=m01_idle_01   -> before: state 14; after: state 6
##                                          analytic follow pose + 100 source-Z
##
## It prints numbers only; it never asserts, so it is safe on either tree.

const CameraAnm = preload("res://scripts/camera_anm_player.gd")
const StoryFlowScript = preload("res://scripts/story_flow.gd")
const StoryStateScript = preload("res://scripts/story_state.gd")
const StoryDataScript = preload("res://scripts/story_data.gd")
const StoryLangScript = preload("res://scripts/story_lang.gd")

const FRAME: float = 1.0 / 60.0
const BASE_MS: int = 100000
const RECORD_STEP_MS: int = 8
const RECORD_COUNT: int = 40
const LIFT_SOURCE: float = 100.0
const CAM_SCALE: float = (
    PortFighter.WORLD_CHARACTER_HEIGHT / PortFighter.SOURCE_CHARACTER_HEIGHT
)

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
    quit(0)


func _attach_flow(node: Node) -> Node:
    flow = StoryFlowScript.new()
    root.add_child(flow)
    flow.set("main", node)
    var run: Dictionary = {
        "kind": "vsbattle", "chapter": "chapter1", "event": "state6_probe",
        "event_type": "vsbattle", "sub_index": 9997, "opponents": ["brick"],
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


func _force_match_lost(node: Node) -> void:
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


func _reset(node: Node) -> void:
    node.call("_reset_match")
    _force_match_lost(node)
    if flow == null:
        _attach_flow(node)
    else:
        node.set("story_flow", flow)


func _fill(node: Node, clip: String) -> void:
    var player: PortFighter = node.get("player")
    var computer: PortFighter = node.get("computer")
    var pb = player.replay_recorder.buffer
    var cb = computer.replay_recorder.buffer
    pb.clear()
    cb.clear()
    var p0: Vector3 = node.get("_fight_start_player")
    var c0: Vector3 = node.get("_fight_start_computer")
    var q := Quaternion(0.0, 0.0, 0.0, 1.0)
    for i: int in RECORD_COUNT:
        var t: int = BASE_MS + i * RECORD_STEP_MS
        pb.append_record(p0, q, clip, 0.0, 0, t)
        cb.append_record(c0, q, clip, 0.0, 0, t)


func _camera_line(tag: String, case_name: String, node: Node) -> void:
    var cam = node.get("fight_camera")
    var active: Variant = node.get("_replay_camera_active")
    var analytic: Variant = node.get("_replay_camera_analytic")
    print("STATE6_PROBE tag=%s case=%s match_state=%d state_active=%s authored=%s analytic=%s fov=%.4f cam=(%.6f,%.6f,%.6f)" % [
        tag, case_name, int(node.get("match_state")),
        str(node.get("native_states").active), str(active), str(analytic),
        float(cam.fov), cam.global_position.x, cam.global_position.y,
        cam.global_position.z,
    ])


func _expected_line(case_name: String, node: Node) -> void:
    var player: PortFighter = node.get("player")
    var computer: PortFighter = node.get("computer")
    var a: Vector3 = node.call("_camera_fighter_point", player)
    var b: Vector3 = node.call("_camera_fighter_point", computer)
    var pose: Dictionary = node.call("_native_camera_pose", a, b, 1.0)
    var base: Vector3 = pose["position"] as Vector3
    var unlifted: Vector3 = base * CAM_SCALE
    var lifted: Vector3 = (base + Vector3(0.0, LIFT_SOURCE, 0.0)) * CAM_SCALE
    print("STATE6_PROBE_EXPECT case=%s lift_source=%.1f lift_world=%.7f unlifted=(%.6f,%.6f,%.6f) lifted=(%.6f,%.6f,%.6f) target=(%.6f,%.6f,%.6f)" % [
        case_name, LIFT_SOURCE, LIFT_SOURCE * CAM_SCALE,
        unlifted.x, unlifted.y, unlifted.z,
        lifted.x, lifted.y, lifted.z,
        (pose["target"] as Vector3).x * CAM_SCALE,
        (pose["target"] as Vector3).y * CAM_SCALE,
        (pose["target"] as Vector3).z * CAM_SCALE,
    ])


func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        print("STATE6_PROBE_ERROR main.tscn failed to load")
        return
    main = packed.instantiate()
    root.add_child(main)
    for _i in 4:
        await process_frame
    main.set_physics_process(false)
    main.set_process(false)
    var player: PortFighter = main.get("player")
    var computer: PortFighter = main.get("computer")
    if player != null:
        player.set_physics_process(false)
    if computer != null:
        computer.set_physics_process(false)

    for row: Array in [["authored", "m01_grab_01"], ["no-camera", "m01_idle_01"]]:
        var case_name: String = row[0]
        var clip: String = row[1]
        _reset(main)
        _fill(main, clip)
        main.call("_on_ko", player)
        _expected_line(case_name, main)
        main.call("_update_fight_camera", FRAME)
        _camera_line("after_on_ko", case_name, main)
        main.call("_update_fight_camera", FRAME)
        _camera_line("after_2frames", case_name, main)

    main.set("story_flow", null)
    if flow != null:
        root.remove_child(flow)
        flow.free()
        flow = null
    root.remove_child(main)
    main.free()
    main = null

extends SceneTree
## Headless validation of the recovered SetState(14) defeat presentation.
##
## Runs the real scenes/main.tscn (real fighters, real clip tables, the real
## decoded camera JSON) and drives state 14 through main.gd.  Every expected
## value comes from libdefault.so, from the decoded camera frame 0, or from the
## recovered defeat_camera_map.json -- nothing is approximated.
##
##   godot --headless --path <godot> --script res://tests/validate_defeat_state.gd

const NativeMatchStates = preload("res://scripts/native_match_states.gd")
const CameraAnmScript = preload("res://scripts/camera_anm_player.gd")

var failures: Array[String] = []


func _initialize() -> void:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    # Deliberately leave BRUCELEE_STORY_FLOW unset: the state is driven directly
    # so the check does not depend on the story data pack.
    OS.set_environment("BRUCELEE_STORY_FLOW", "0")
    var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
    root.add_child(main)
    for _i in 90:
        await process_frame
    _check_constants()
    _check_module_logic()
    _check_runtime_state(main)
    _check_fail_closed(main)
    main.queue_free()
    if failures.is_empty():
        print("DEFEAT_STATE_VALIDATION=PASS")
        quit(0)
    else:
        for failure in failures:
            push_error("DEFEAT_STATE_FAIL " + failure)
        print("DEFEAT_STATE_VALIDATION=FAIL count=%d" % failures.size())
        quit(1)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _approx(a: float, b: float, eps: float) -> bool:
    return absf(a - b) <= eps


func _check_constants() -> void:
    _expect(NativeMatchStates.STATE_COUNTDOWN == 14, "state 14 constant is 14")
    _expect(NativeMatchStates.STATE_COUNTDOWN in NativeMatchStates.IMPLEMENTED_STATES,
        "state 14 is in IMPLEMENTED_STATES")
    _expect(not (NativeMatchStates.STATE_COUNTDOWN in NativeMatchStates.UNRECOVERED_STATES),
        "state 14 is no longer gated as unrecovered")
    _expect(NativeMatchStates.COUNTDOWN_ENDED_AFTER_MS == 9999,
        "CountdownEnded threshold is the recovered 9999 ms")
    _expect(NativeMatchStates.COUNTDOWN_ACTION == "COUNTDOWNEND",
        "CountdownEnded raises the recovered COUNTDOWNEND action")
    _expect(NativeMatchStates.COUNTDOWN_CATEGORY == "Defeat",
        "state 14 plays the Defeat category")
    _expect(NativeMatchStates.COUNTDOWN_CAMERA_FIGHTER == 0,
        "state 14 camera dummy is fighter slot 0 (this[0x7e0])")
    _expect(NativeMatchStates.COUNTDOWN_CAMERA_SWAP == 0,
        "state 14 camera swap flag is 0")
    _expect(NativeMatchStates.ROUND_COUNTER_FIGHTER0_OFFSET == 0x81c,
        "round counter fighter 0 offset is +0x81c")
    _expect(NativeMatchStates.ROUND_COUNTER_FIGHTER1_OFFSET == 0x820,
        "round counter fighter 1 offset is +0x820")


func _check_module_logic() -> void:
    var states = NativeMatchStates.new()
    # A missing defeat clip must be refused, not approximated.
    var refused: bool = not bool(states.enter(NativeMatchStates.STATE_COUNTDOWN, "", -1.0, ""))
    _expect(refused, "state 14 refuses an empty defeat clip")
    _expect(String(states.fail_reason).begins_with("no-candidate-clip"),
        "refusal names the missing clip, got %s" % states.fail_reason)
    # A missing camera must be refused too.
    refused = not bool(states.enter(NativeMatchStates.STATE_COUNTDOWN, "m01_defeat_01", 3.9, ""))
    _expect(refused, "state 14 refuses a missing defeat camera")
    # With both the clip and its camera it enters and observes CountdownEnded.
    var ok: bool = bool(states.enter(NativeMatchStates.STATE_COUNTDOWN,
        "m01_defeat_01", 3.9, "m01_defeat_01"))
    _expect(ok, "state 14 enters with the recovered clip and camera")
    _expect(int(states.state) == 14 and bool(states.active), "state 14 is active after enter")
    for _i in 19:
        states.advance(0.5)
    _expect(not bool(states.countdown_ended),
        "CountdownEnded is false at %.1f s" % states.state_time)
    states.advance(2.0)
    _expect(bool(states.countdown_ended),
        "CountdownEnded is true past 9.999 s, at %.1f s" % states.state_time)
    var d: Dictionary = states.describe()
    _expect(String(d.get("countdown_clip", "")) == "m01_defeat_01",
        "describe() carries the defeat clip")
    _expect(String(d.get("countdown_end_action", "")) == "COUNTDOWNEND",
        "describe() carries the COUNTDOWNEND action")


func _check_runtime_state(main: Node) -> void:
    var states = main.get("native_states")
    var player: Node = main.get("player")
    var computer: Node = main.get("computer")
    _expect(states != null, "main.tscn exposes native_states")
    _expect(player != null and computer != null, "main.tscn builds both fighters")
    if states == null or player == null or computer == null:
        return

    # The candidate Bruce GLB must carry characters.list animations.defeat.
    var clips: Dictionary = player.get("_candidate_clip_paths")
    _expect(clips.has("m01_defeat_01"),
        "player candidate GLB carries m01_defeat_01 (characters.list defeat)")
    _expect(String(main.call("_defeat_camera_clip", "m01_defeat_01")) == "m01_defeat_01",
        "defeat_camera_map resolves m01_defeat_01 -> its camera clip")

    # Enter state 14 through main.gd.
    var entered: bool = bool(main.call("_enter_countdown_state"))
    _expect(entered, "main.gd enters state 14 with the real candidate + camera")
    if not entered:
        return
    _expect(int(main.get("match_state")) == 14, "match_state becomes 14")
    _expect(int(states.state) == 14, "NativeMatchStates records state 14")
    _expect(String(player.result_clip) == "m01_defeat_01",
        "fighter 0 plays the Defeat clip, got %s" % player.result_clip)

    # SetState(14): fighter 0 visible at the origin, fighter 1 hidden at the origin.
    _expect(bool(player.visible), "fighter 0 stays visible")
    _expect(not bool(computer.visible), "fighter 1 is hidden")
    var origin_y: float = PortFighter.PLAYER_ORIGIN_HEIGHT
    _expect(_approx(player.global_position.x, 0.0, 0.001)
        and _approx(player.global_position.z, 0.0, 0.001)
        and _approx(player.global_position.y, origin_y, 0.001),
        "fighter 0 moved to the origin, got %s" % str(player.global_position))
    _expect(_approx(computer.global_position.x, 0.0, 0.001)
        and _approx(computer.global_position.z, 0.0, 0.001),
        "fighter 1 moved to the origin, got %s" % str(computer.global_position))

    # The authored m01_defeat_01 camera must be what drives fight_camera.
    main.call("_update_fight_camera", 1.0 / 60.0)
    var expected = CameraAnmScript.new()
    var loaded: bool = expected.load_json("res://data/camera_anm/m01_defeat_01.json")
    _expect(loaded, "m01_defeat_01 camera JSON decodes")
    if loaded:
        var pose: Dictionary = expected.place_world(
            0, Vector3.ZERO, Vector3.ZERO, false)
        var cam: Camera3D = main.get("fight_camera")
        var expected_pos: Vector3 = pose["camera_world"]
        var distance: float = cam.global_position.distance_to(expected_pos)
        _expect(distance < 0.01,
            "fight_camera matches the authored frame 0 (d=%.3f, got %s want %s)"
            % [distance, str(cam.global_position), str(expected_pos)])
        _expect(_approx(cam.fov, float(pose["fov_degrees"]), 0.01),
            "fight_camera fov is the authored %.2f, got %.2f"
            % [float(pose["fov_degrees"]), cam.fov])
        _expect(not _approx(cam.fov, 75.0, 0.5),
            "fight_camera fov is the authored clip, not the analytic 75.0")

    # CountdownEnded gating: no hand-off before 9.999 s, then COUNTDOWNEND.
    for _i in 19:
        main.call("_update_match_state", 0.5)
    _expect(not bool(main.get("_countdown_handed_off")),
        "no COUNTDOWNEND hand-off before 9.999 s")
    for _i in 3:
        main.call("_update_match_state", 0.5)
    _expect(bool(main.get("_countdown_handed_off")),
        "COUNTDOWNEND hand-off fires after 9.999 s")


func _check_fail_closed(main: Node) -> void:
    var states = main.get("native_states")
    if states == null:
        return
    # Put the machine back to a non-countdown state.
    main.set("match_state", 4)
    states.reset()
    main.set("_defeat_camera_map_loaded", false)
    main.set("_defeat_camera_map_path", "res://data/camera_anm/__no_such_defeat_map__.json")
    var entered: bool = bool(main.call("_enter_countdown_state"))
    _expect(not entered, "state 14 fails closed when the defeat camera map is missing")
    _expect(int(main.get("match_state")) == 4,
        "a refused state 14 leaves match_state unchanged")
    main.set("_defeat_camera_map_path", "res://data/camera_anm/defeat_camera_map.json")
    main.set("_defeat_camera_map_loaded", false)

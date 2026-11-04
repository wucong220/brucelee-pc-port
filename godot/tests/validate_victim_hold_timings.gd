extends SceneTree
## Headless validation of the recovered non-player victim hold/finisher timing.
##
## Real res://scenes/main.tscn, real PortFighter attack/hold path. For each
## opponent set (Ken/Brick/Master/SinFu) it asserts:
##   * grab1/grab2 hold the victim for the recovered per-set clip length
##     (state_time == clip_frames / 30), select the exact archived clip, exit to
##     the recovered destination state, and still deal the full recovered grab
##     damage (all multi-impacts, no truncation);
##   * endattack1/2 hold for the recovered clip length, select the clip and exit
##     to the recovered destination (facedownko/faceupko);
##   * a set with no endattackcomp clip (kungfu) fails closed;
##   * the shipped Ken candidate without victim clips fails closed (negative
##     control), so the pass is caused by the clips, not a looser harness.
##
## Run:
##   godot --headless --path <proj> --script res://tests/validate_victim_hold_timings.gd -- <player.glb>
##
## Exit 0 only when every assertion passes.

const FPS: float = 30.0
const STEP: float = 1.0 / 60.0
const FRAME_TOL: float = 0.75           # one 1/60 step is 0.5 source frames
const PLAYER_POS: Vector3 = Vector3(0.0, 1.2, 0.0)
const VICTIM_POS: Vector3 = Vector3(0.35, 1.2, 0.0)
const MAX_STEPS: int = 700

const CASES: Array = [
    {
        "id": "ken",
        "glb": "D:\\BruceLeeWork\\ken-grab-victim-20261104\\candidate\\ken_all26_74_victim4_78_20261104.glb",
        "config": "res://data/attack_config_ken.json",
        "skeleton": "medium", "profile": "body_hair", "prefix": "m02",
        "grab1": {"clip": "all_grabbed_01_forset02", "frames": 47, "exit": "faceupidle", "damage": 20.0},
        "grab2": {"clip": "all_grabbed_02_forset02", "frames": 98, "exit": "faceupidle", "damage": 20.0},
        "endattack1": {"clip": "all_end_attack_01_forset02", "frames": 132, "exit": "facedownko", "has": true},
        "endattack2": {"clip": "all_end_attack_02_forset02", "frames": 155, "exit": "faceupko", "has": true},
    },
    {
        "id": "brick",
        "glb": "D:\\BruceLeeWork\\brick-full-20261103\\candidate\\brick_full_94_20261103.glb",
        "config": "res://data/fighting_set_m03_mapped_attacks.json",
        "skeleton": "large", "profile": "body", "prefix": "",
        "grab1": {"clip": "all_grabbed_01_forset03", "frames": 90, "exit": "facedownidle", "damage": 20.0},
        "grab2": {"clip": "all_grabbed_02_forset03", "frames": 78, "exit": "faceupidle", "damage": 20.0},
        "endattack1": {"clip": "all_end_attack_01_forset03", "frames": 93, "exit": "faceupko", "has": true},
        "endattack2": {"clip": "all_end_attack_02_forset03", "frames": 130, "exit": "faceupko", "has": true},
    },
    {
        "id": "master",
        "glb": "D:\\BruceLeeWork\\result-clip-fixes-20261103\\candidates\\master_full_hair_80_result_20261103.glb",
        "config": "res://data/attack_config_master.json",
        "skeleton": "small", "profile": "body", "prefix": "",
        "grab1": {"clip": "all_sp_pnch_low_forset04", "frames": 28, "exit": "facedownidle", "damage": 20.0},
        "grab2": {"clip": "all_sp_kck_low_forset04", "frames": 55, "exit": "facedownidle", "damage": 20.0},
        "endattack1": {"clip": "all_end_attack_01_forset04", "frames": 0, "exit": "fail_closed", "has": false},
        "endattack2": {"clip": "all_end_attack_02_forset04", "frames": 0, "exit": "fail_closed", "has": false},
    },
    {
        "id": "sinfu",
        "glb": "D:\\BruceLeeWork\\result-clip-fixes-20261103\\candidates\\sinfu_hair_two-skin_81_result_20261103.glb",
        "config": "res://data/attack_config_sinfu.json",
        "skeleton": "medium", "profile": "body", "prefix": "m04",
        "grab1": {"clip": "all_grabbed_01_forset04", "frames": 103, "exit": "faceupidle", "damage": 20.0},
        "grab2": {"clip": "all_sp_kck_low_forset04", "frames": 55, "exit": "facedownidle", "damage": 20.0},
        "endattack1": {"clip": "all_end_attack_01_forset04", "frames": 0, "exit": "fail_closed", "has": false},
        "endattack2": {"clip": "all_end_attack_02_forset04", "frames": 0, "exit": "fail_closed", "has": false},
    },
    {
        # Negative control: the shipped Ken candidate has no forset02 victim
        # clips, so both grabs must fail closed (the victim is never held).
        "id": "ken_shipped_control",
        "glb": "D:\\BruceLeeWork\\result-clip-fixes-20261103\\candidates\\ken_all26_74_defeat_groundidle_20261103.glb",
        "config": "res://data/attack_config_ken.json",
        "skeleton": "medium", "profile": "body_hair", "prefix": "m02",
        "negative_control": true,
        "grab1": {"clip": "all_grabbed_01_forset02", "frames": 47, "exit": "fail_closed", "damage": 20.0},
        "grab2": {"clip": "all_grabbed_02_forset02", "frames": 98, "exit": "fail_closed", "damage": 20.0},
        "endattack1": {"clip": "all_end_attack_01_forset02", "frames": 0, "exit": "fail_closed", "has": false},
        "endattack2": {"clip": "all_end_attack_02_forset02", "frames": 0, "exit": "fail_closed", "has": false},
    },
]

var _player_glb: String = ""
var _failures: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _pin(player: PortFighter, victim: PortFighter) -> void:
    player.position = PLAYER_POS
    victim.position = VICTIM_POS
    player.facing = 1.0


func _apply_env(case: Dictionary) -> void:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", _player_glb)
    OS.set_environment("BRUCELEE_OPPONENT_GLB", String(case["glb"]))
    OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", String(case["config"]))
    OS.set_environment("BRUCELEE_OPPONENT_SKELETON", String(case["skeleton"]))
    OS.set_environment("BRUCELEE_OPPONENT_MATERIAL_PROFILE", String(case["profile"]))
    OS.set_environment("BRUCELEE_OPPONENT_CLIP_PREFIX", String(case["prefix"]))


func _fail(msg: String) -> void:
    _failures += 1
    push_error("FAIL: " + msg)


func _check(cond: bool, msg: String) -> void:
    if not cond:
        _fail(msg)


func _measure_grab(scene: Node, kind: String) -> Dictionary:
    scene.call("_reset_match")
    var player: PortFighter = scene.get("player")
    var victim: PortFighter = scene.get("computer")
    player.rage = 100.0
    _pin(player, victim)
    var health0: float = victim.health
    var started: bool = player.request_attack(kind)
    var entry: Dictionary = {}
    var held_during: bool = false
    var steps: int = 0
    while steps < MAX_STEPS:
        _pin(player, victim)
        player._physics_process(STEP)
        victim._physics_process(STEP)
        if victim.state in ["grabbed1", "grabbed2"]:
            held_during = true
            if entry.is_empty():
                entry = {
                    "state": victim.state,
                    "state_time": victim.state_time,
                    "frames_from_state_time": victim.state_time * FPS,
                    "clip": victim.current_victim_animation(),
                }
        if steps > 10 and player.attack_kind != kind:
            break
        steps += 1
    var exit_state: String = victim.state
    for i: int in range(400):
        _pin(player, victim)
        player._physics_process(STEP)
        victim._physics_process(STEP)
        if victim.state not in ["grabbed1", "grabbed2"]:
            exit_state = victim.state
            break
    return {
        "kind": kind, "started": started, "result": "measured" if held_during else "not_held",
        "entry": entry, "damage_dealt": health0 - victim.health,
        "health_after": victim.health, "exit_state": exit_state,
    }


func _measure_endattack(scene: Node, grab_kind: String, finisher: String, slot: String) -> Dictionary:
    scene.call("_reset_match")
    var player: PortFighter = scene.get("player")
    var victim: PortFighter = scene.get("computer")
    player.rage = 100.0
    _pin(player, victim)
    player.request_attack(grab_kind)
    var held: bool = false
    for i: int in range(400):
        _pin(player, victim)
        player._physics_process(STEP)
        victim._physics_process(STEP)
        if victim.state in ["grabbed1", "grabbed2"]:
            held = true
            break
    if not held:
        return {"finisher": finisher, "held": false, "returned": false}
    var ok: bool = victim.begin_endattack_victim(finisher)
    var detail: Dictionary = {
        "finisher": finisher, "held": true, "returned": ok,
        "state": victim.state, "state_time": victim.state_time,
        "frames_from_state_time": victim.state_time * FPS,
        "clip": victim.current_victim_animation(),
    }
    if ok:
        var exit_state: String = victim.state
        for i: int in range(700):
            victim._physics_process(STEP)
            if victim.state != slot:
                exit_state = victim.state
                break
            exit_state = victim.state
        detail["exit_state"] = exit_state
    return detail


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected one player GLB path")
        quit(1)
        return
    _player_glb = args[0]
    var results: Array = []
    for case: Dictionary in CASES:
        var cid: String = String(case["id"])
        var negative: bool = bool(case.get("negative_control", false))
        _apply_env(case)
        var scene: Node = load("res://scenes/main.tscn").instantiate()
        root.add_child(scene)
        current_scene = scene
        await process_frame
        await process_frame
        scene.set_process(false)
        scene.set_physics_process(false)
        var player: PortFighter = scene.get("player")
        var victim: PortFighter = scene.get("computer")
        player.set_physics_process(false)
        victim.set_physics_process(false)
        var rec: Dictionary = {"id": cid, "negative_control": negative}
        _check(player.candidate_loaded, cid + ": player candidate failed")
        _check(victim.candidate_loaded, cid + ": victim candidate failed: " + victim.candidate_load_error)
        if victim.candidate_loaded:
            for kind: String in ["grab1", "grab2"]:
                var exp: Dictionary = case[kind]
                var m: Dictionary = _measure_grab(scene, kind)
                rec[kind] = m
                if negative:
                    _check(m["result"] == "not_held",
                            cid + " " + kind + ": expected fail-closed (never held), got " + String(m["result"]))
                    continue
                _check(m["result"] == "measured", cid + " " + kind + ": victim was not held")
                if m["result"] == "measured":
                    var e: Dictionary = m["entry"]
                    var want_state: String = "grabbed1" if kind == "grab1" else "grabbed2"
                    _check(String(e["state"]) == want_state,
                            cid + " " + kind + ": wrong state " + String(e["state"]))
                    _check(String(e["clip"]) == String(exp["clip"]),
                            cid + " " + kind + ": clip " + String(e["clip"]) + " != " + String(exp["clip"]))
                    _check(absf(float(e["frames_from_state_time"]) - float(exp["frames"])) <= FRAME_TOL,
                            cid + " " + kind + ": hold frames " + str(e["frames_from_state_time"])
                            + " != " + str(exp["frames"]))
                    _check(absf(float(m["damage_dealt"]) - float(exp["damage"])) < 0.001,
                            cid + " " + kind + ": damage " + str(m["damage_dealt"]) + " != " + str(exp["damage"]))
                    _check(String(m["exit_state"]) == String(exp["exit"]),
                            cid + " " + kind + ": exit " + String(m["exit_state"]) + " != " + String(exp["exit"]))
            for idx: int in range(1, 3):
                var fin: String = "endattack" + str(idx)
                var slot: String = "endattackcomp" + str(idx)
                var exp2: Dictionary = case[fin]
                var m2: Dictionary = _measure_endattack(scene, "grab" + str(idx), fin, slot)
                rec[fin] = m2
                if negative or not bool(exp2["has"]):
                    _check(not bool(m2.get("returned", false)),
                            cid + " " + fin + ": expected fail-closed, returned true")
                    continue
                _check(bool(m2.get("returned", false)), cid + " " + fin + ": begin_endattack_victim refused")
                _check(String(m2.get("state", "")) == slot,
                        cid + " " + fin + ": state " + String(m2.get("state", "")) + " != " + slot)
                _check(String(m2.get("clip", "")) == String(exp2["clip"]),
                        cid + " " + fin + ": clip " + String(m2.get("clip", "")) + " != " + String(exp2["clip"]))
                _check(absf(float(m2.get("frames_from_state_time", 0.0)) - float(exp2["frames"])) <= FRAME_TOL,
                        cid + " " + fin + ": frames " + str(m2.get("frames_from_state_time", 0.0))
                        + " != " + str(exp2["frames"]))
                _check(String(m2.get("exit_state", "")) == String(exp2["exit"]),
                        cid + " " + fin + ": exit " + String(m2.get("exit_state", "")) + " != " + String(exp2["exit"]))
        results.append(rec)
        scene.queue_free()
        await process_frame
    var summary: Dictionary = {"baseline": "a6f8afb", "failures": _failures, "cases": results}
    print("VICTIM_HOLD_TIMINGS_VALIDATION=" + JSON.stringify(summary))
    quit(0 if _failures == 0 else 1)

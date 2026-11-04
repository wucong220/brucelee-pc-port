extends SceneTree
## Real res://scenes/main.tscn proof for the ShenLo -> player victim path.
##
## For every shipped Current223 player skin this drives ShenLo's real grab1 /
## grab2 attacks (computer.request_attack) against the player and asserts:
##   * the player enters grabbed1/grabbed2 (the baseline fails closed and never
##     holds the player);
##   * the exact archived player-set clip is played:
##       grabbed1 -> all_grabbed_01_forset04, 103 source frames, exit faceupidle
##       grabbed2 -> all_grabbed_02_forset04,  45 source frames, exit facedownidle
##   * the recovered grab damage is dealt (values passed by the caller);
##   * ShenLo's endattack cannot consume the player: no native endattackcomp
##     ShenLo row and no forset04 endattack clip exist, so the victim hook must
##     fail closed and leave the player in the hold.
##
## Run:
##   godot --headless --path <proj> --script res://tests/validate_shenlo_victim.gd \
##     -- [<expected_grab1_damage> <expected_grab2_damage>]
##   The recovered values are 20.0 and 5.0; passing them is optional.

const FPS: float = 30.0
const STEP: float = 1.0 / 60.0
const FRAME_TOL: float = 1.0
const PLAYER_POS: Vector3 = Vector3(0.0, 1.2, 0.0)
const ATTACKER_POS: Vector3 = Vector3(0.35, 1.2, 0.0)
const MAX_STEPS: int = 1400
const SHENLO_GLB: String = (
    "D:\\BruceLeeWork\\shenlo-victim-20261104\\shenlo\\"
    + "shenlo_full_body_89_all_20261103.glb"
)
const SHENLO_TEXTURES: String = "D:\\BruceLeeWork\\shenlo-victim-20261104\\shenlo\\textures"

const SKINS: Array = [
    {
        "id": "skin01",
        "glb": "D:\\BruceLeeWork\\shenlo-victim-20261104\\models\\bruce_skin01.glb",
    },
    {
        "id": "skin02",
        "glb": "D:\\BruceLeeWork\\shenlo-victim-20261104\\models\\bruce_skin02.glb",
    },
    {
        "id": "skin03",
        "glb": "D:\\BruceLeeWork\\shenlo-victim-20261104\\models\\bruce_skin03.glb",
    },
    {
        "id": "skin04",
        "glb": "D:\\BruceLeeWork\\shenlo-victim-20261104\\models\\bruce_skin04.glb",
    },
]

const EXPECTED: Dictionary = {
    "grab1": {
        "state": "grabbed1",
        "clip": "all_grabbed_01_forset04",
        "frames": 103,
        "exit": "faceupidle",
    },
    "grab2": {
        "state": "grabbed2",
        "clip": "all_grabbed_02_forset04",
        "frames": 45,
        "exit": "facedownidle",
    },
}

var _expected_damage: Dictionary = {}
var _out_path: String = ""
var _failures: Array[String] = []
var _checks: int = 0
var _results: Array = []


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


func _apply_env(skin: Dictionary) -> void:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_ROUND_TIME", "60")
    OS.set_environment("BRUCELEE_ATTENDANT", "0")
    OS.set_environment("BRUCELEE_PLAYER_SKIN", "")
    OS.set_environment("BRUCELEE_PLAYER_GLB", String(skin["glb"]))
    OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", "")
    OS.set_environment("BRUCELEE_OPPONENT_GLB", SHENLO_GLB)
    OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", SHENLO_TEXTURES)
    OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", "res://data/attack_config_shenlo.json")
    OS.set_environment("BRUCELEE_OPPONENT_SKELETON", "medium")
    OS.set_environment("BRUCELEE_OPPONENT_MATERIAL_PROFILE", "body")
    OS.set_environment("BRUCELEE_OPPONENT_CLIP_PREFIX", "m04")
    OS.set_environment("BRUCELEE_ALLOW_PACKAGE_MODELS", "1")


func _pin(player, attacker) -> void:
    player.position = PLAYER_POS
    attacker.position = ATTACKER_POS
    player.facing = 1.0
    attacker.facing = -1.0


func _prepare(scene: Node) -> void:
    scene.call("_reset_match")
    var player = scene.get("player")
    var attacker = scene.get("computer")
    _pin(player, attacker)
    player.guard_held = false
    player.set_key_status({})
    player.held_directions = {}
    attacker.rage = 100.0


func _measure_grab(scene: Node, kind: String) -> Dictionary:
    _prepare(scene)
    var player = scene.get("player")
    var attacker = scene.get("computer")
    var health_before: float = player.health
    var started: bool = attacker.request_attack(kind)
    var entry: Dictionary = {}
    var held: bool = false
    var steps: int = 0
    while steps < MAX_STEPS:
        _pin(player, attacker)
        player._physics_process(STEP)
        attacker._physics_process(STEP)
        if player.state in ["grabbed1", "grabbed2"]:
            held = true
            if entry.is_empty():
                entry = {
                    "state": player.state,
                    "state_time": player.state_time,
                    "frames_from_state_time": player.state_time * FPS,
                    "clip": player.current_victim_animation(),
                    "selected": String(player._victim_selected_animation.get(
                            player.state, "")),
                    "candidate_clip": String(player._candidate_clip_paths.get(
                            player.state, "")),
                }
        if steps > 20 and player.state not in ["grabbed1", "grabbed2"] and (
                attacker.attack_kind != kind or attacker.state == "idle"
                or attacker.state == "idle2" or attacker.state == "idle3"):
            break
        steps += 1
    var exit_state: String = player.state
    for i: int in range(400):
        _pin(player, attacker)
        player._physics_process(STEP)
        attacker._physics_process(STEP)
        if held and player.state not in ["grabbed1", "grabbed2"]:
            exit_state = player.state
            break
        exit_state = player.state
    return {
        "kind": kind,
        "started": started,
        "result": "measured" if held else "not_held",
        "entry": entry,
        "damage_dealt": health_before - player.health,
        "health_after": player.health,
        "exit_state": exit_state,
    }


func _measure_endattack(scene: Node, kind: String) -> Dictionary:
    _prepare(scene)
    var player = scene.get("player")
    var attacker = scene.get("computer")
    var started: bool = attacker.request_attack(kind)
    var held: bool = false
    for i: int in range(600):
        _pin(player, attacker)
        player._physics_process(STEP)
        attacker._physics_process(STEP)
        if player.state in ["grabbed1", "grabbed2"]:
            held = true
            break
    if not held:
        return {
            "started": started,
            "held": false,
            "returned": false,
            "reason": "grab did not hold the player",
        }
    var held_state: String = player.state
    var clip_before: String = player.current_victim_animation()
    var returned: bool = player.begin_endattack_victim("endattack")
    # The real attacker path calls the same hook while its endattack is active.
    # A second call must also be refused; the player must stay in the hold.
    var returned_again: bool = player.begin_endattack_victim("endattack")
    return {
        "started": started,
        "held": true,
        "held_state": held_state,
        "clip_before": clip_before,
        "returned": returned,
        "returned_again": returned_again,
        "state_after": player.state,
        "clip_after": player.current_victim_animation(),
        "native_endattackcomp_row": bool(
            player._native_actions.has("endattackcomp shenlo")
            or player._native_actions.has("endattackcompkungfu 1")
            or player._native_actions.has("endattackcompkungfu 2")
        ),
        "candidate_endattack_clip": bool(
            player._candidate_clip_paths.has("all_end_attack_01_forset04")
            or player._candidate_clip_paths.has("all_end_attack_02_forset04")
        ),
    }


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    var grab1_damage: float = 20.0
    var grab2_damage: float = 5.0
    if args.size() == 2:
        grab1_damage = float(args[0])
        grab2_damage = float(args[1])
    elif args.size() != 0:
        push_error("Expected optional <grab1_damage> <grab2_damage>")
        quit(2)
        return
    _expected_damage = {
        "grab1": grab1_damage,
        "grab2": grab2_damage,
    }
    for skin: Dictionary in SKINS:
        _apply_env(skin)
        var scene: Node = load("res://scenes/main.tscn").instantiate()
        root.add_child(scene)
        current_scene = scene
        await process_frame
        await process_frame
        scene.set_process(false)
        scene.set_physics_process(false)
        var player = scene.get("player")
        var attacker = scene.get("computer")
        player.set_physics_process(false)
        attacker.set_physics_process(false)
        var rec: Dictionary = {
            "skin": String(skin["id"]),
            "player_glb": String(skin["glb"]),
            "player_loaded": player.candidate_loaded,
            "player_error": player.candidate_load_error,
            "attacker_loaded": attacker.candidate_loaded,
            "attacker_error": attacker.candidate_load_error,
            "grab_tables": {
                "grabcompl1_shenlo": player._native_actions.get(
                        "grabcompl1 shenlo", null),
                "grabcompl2_shenlo": player._native_actions.get(
                        "grabcompl2 shenlo", null),
            },
        }
        _check(String(skin["id"]) + ": player candidate loaded",
                player.candidate_loaded, player.candidate_load_error)
        _check(String(skin["id"]) + ": ShenLo candidate loaded",
                attacker.candidate_loaded, attacker.candidate_load_error)
        if player.candidate_loaded and attacker.candidate_loaded:
            for kind: String in ["grab1", "grab2"]:
                var exp: Dictionary = EXPECTED[kind]
                var m: Dictionary = _measure_grab(scene, kind)
                rec[kind] = m
                _check(String(skin["id"]) + " " + kind + ": player was held",
                        String(m["result"]) == "measured", String(m["result"]))
                if String(m["result"]) == "measured":
                    var entry: Dictionary = m["entry"]
                    _check(String(skin["id"]) + " " + kind + ": state ",
                            String(entry["state"]) == String(exp["state"]),
                            String(entry["state"]))
                    _check(String(skin["id"]) + " " + kind + ": clip",
                            String(entry["clip"]) == String(exp["clip"]),
                            String(entry["clip"]))
                    _check(String(skin["id"]) + " " + kind + ": selected clip",
                            String(entry["selected"]) == String(exp["clip"]),
                            String(entry["selected"]))
                    _check(String(skin["id"]) + " " + kind + ": candidate clip",
                            String(entry["candidate_clip"]) == String(exp["clip"]),
                            String(entry["candidate_clip"]))
                    _check(String(skin["id"]) + " " + kind + ": hold frames",
                            absf(float(entry["frames_from_state_time"])
                                    - float(exp["frames"])) <= FRAME_TOL,
                            str(entry["frames_from_state_time"]))
                    _check(String(skin["id"]) + " " + kind + ": damage",
                            absf(float(m["damage_dealt"])
                                    - float(_expected_damage[kind])) < 0.001,
                            str(m["damage_dealt"]))
                    _check(String(skin["id"]) + " " + kind + ": exit",
                            String(m["exit_state"]) == String(exp["exit"]),
                            String(m["exit_state"]))
            var fin: Dictionary = _measure_endattack(scene, "grab1")
            rec["endattack"] = fin
            if bool(fin.get("held", false)):
                _check(String(skin["id"]) + " endattack: refused",
                        not bool(fin["returned"]), str(fin["returned"]))
                _check(String(skin["id"]) + " endattack: refused again",
                        not bool(fin["returned_again"]), str(fin["returned_again"]))
                _check(String(skin["id"]) + " endattack: player still held",
                        String(fin["state_after"]) == String(fin["held_state"]),
                        String(fin["state_after"]))
                _check(String(skin["id"]) + " endattack: no native ShenLo row",
                        not bool(fin["native_endattackcomp_row"]), "row present")
                _check(String(skin["id"]) + " endattack: no candidate clip",
                        not bool(fin["candidate_endattack_clip"]), "clip present")
            else:
                _check(String(skin["id"]) + " endattack: grab prerequisite",
                        false, String(fin.get("reason", "")))
        _results.append(rec)
        scene.queue_free()
        await process_frame

    var summary: Dictionary = {
        "baseline": "965f19e47c2cb60003db9cfab124f3077a91cd3c",
        "engine": Engine.get_version_info(),
        "expected_damage": _expected_damage,
        "checks": _checks,
        "failures": _failures,
        "skins": _results,
    }
    print("SHENLO_VICTIM_RESULT=" + JSON.stringify(summary))
    quit(0 if _failures.is_empty() else 1)

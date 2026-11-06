extends SceneTree
## Strict validation: real main.tscn, one Bruce skin vs large Brick.
##   * request_attack base path: grab1 -> endattack1 -> endattackcomp1 (93f)
##                              grab2 -> endattack2 -> endattackcomp2 (130f)
##   * raw native link route (record_standing_combo_press): stepright+A ->
##       grab1miss -> grab1 -> (right+A) endattack1 -> endattackcomp1 (93f),
##       then faceupko
##   * real keyboard route (Input actions + main.gd._unhandled_input): same
##   * explicit {grabs/graba=grababrick, endmove=endsmallboy}: the raw route
##       becomes grab1miss brick -> grab1 brick -> endattack smallboy (93f),
##       the recovered big-skeleton finisher, only because the style selection
##       put those IDs in the active unique list.
## CFighter::IsLinkAllowed is an exact membership test: the Brick opponent does
## not select any row on the default 8-ID Bruce list.
## Exit 0 only if every assertion passes; prints RAW_FINISHER_VALIDATION={...}

const FPS: float = 30.0
const STEP: float = 1.0 / 60.0
const FR_TOL: float = 1.25
const PP: Vector3 = Vector3(0.0, 1.2, 0.0)
const VP: Vector3 = Vector3(0.35, 1.2, 0.0)
const PC = preload("res://scripts/prototype_controls.gd")
const BRICK_STYLE: Dictionary = {
    "grabs/graba": "grababrick",
    "endmove/endmove": "endsmallboy",
}

var scene: Node
var player: PortFighter
var victim: PortFighter
var failures: Array[String] = []
var checks: Array = []


func _initialize() -> void:
    call_deferred("_run")


func _key(code: Key) -> InputEventKey:
    var e := InputEventKey.new()
    e.keycode = code
    e.physical_keycode = code
    e.pressed = true
    return e


func _pin() -> void:
    player.position = PP
    victim.position = VP
    player.facing = 1.0


func _step() -> void:
    _pin()
    player._physics_process(STEP)
    victim._physics_process(STEP)


func _sync() -> void:
    player.set_held_directions(scene._held_direction_flags())
    scene._update_player_key_status()


func _release_all() -> void:
    for a: String in [PC.MOVE_UP, PC.MOVE_DOWN, PC.MOVE_LEFT, PC.MOVE_RIGHT,
            PC.ATTACK_A, PC.ATTACK_B, PC.ATTACK_C, PC.ATTACK_D]:
        Input.action_release(a)


func _reset() -> void:
    _release_all()
    scene._reset_match()
    player = scene.get("player")
    victim = scene.get("computer")
    player.set_physics_process(false)
    victim.set_physics_process(false)
    player.rage = 100.0
    player.set_key_status({})
    player.set_held_directions({})
    _pin()


func _set_style(groups: Dictionary) -> bool:
    var catalog = StyleCatalog.new()
    if not catalog.load_catalog():
        push_error("style catalog failed closed: " + catalog.error)
        return false
    var store = scene.get("style_store")
    if store == null:
        push_error("main did not create the saved style store")
        return false
    store.selections = catalog.defaults()
    for group_key: String in groups:
        store.selections[group_key] = groups[group_key]
    scene._apply_style_editor()
    return true


func _check(ok: bool, msg: String) -> void:
    checks.append({"ok": ok, "msg": msg})
    if not ok:
        failures.append(msg)
        push_error("FAIL: " + msg)


func _hold_until(comp_state: String, max_steps: int = 700) -> Dictionary:
    for i: int in range(max_steps):
        _step()
        if victim.state == comp_state:
            var entry: Dictionary = {
                "frames": victim.state_time * FPS,
                "clip": victim.current_victim_animation(),
            }
            var end_state: String = victim.state
            for _j: int in range(900):
                _step()
                if victim.state != comp_state:
                    end_state = victim.state
                    break
            entry["end_state"] = end_state
            return entry
    return {}


func _run_base(grab: String, fin: String, comp: String, want_frames: int) -> Dictionary:
    _reset()
    var rec: Dictionary = {"path": "base", "grab": grab, "fin": fin}
    _check(player.request_attack(grab), "base %s request refused" % grab)
    var grab_state: String = "grabbed1" if grab == "grab1" else "grabbed2"
    var grabbed: bool = false
    for _i: int in range(400):
        _step()
        if victim.state == grab_state:
            grabbed = true
            break
    _check(grabbed, "base %s did not grab" % grab)
    if not grabbed:
        return rec
    player.state = "idle"
    player.state_time = 0.0
    player.attack_kind = ""
    _check(player.request_attack(fin), "base %s refused" % fin)
    var e: Dictionary = _hold_until(comp)
    rec.merge(e)
    _check(not e.is_empty(), "base %s: victim never reached %s" % [fin, comp])
    if not e.is_empty():
        _check(String(e["clip"]) == ("all_end_attack_01_forset03" if comp == "endattackcomp1" else "all_end_attack_02_forset03"),
                "base %s clip %s" % [fin, e["clip"]])
        _check(absf(float(e["frames"]) - float(want_frames)) <= FR_TOL,
                "base %s frames %s != %d" % [fin, e["frames"], want_frames])
        _check(String(e["end_state"]) == "faceupko",
                "base %s end %s != faceupko" % [fin, e["end_state"]])
    return rec


func _run_raw(mode: String, grab_state: String, want_finisher: String,
        want_finisher_clip: String, comp: String, want_frames: int,
        real_keys: bool) -> Dictionary:
    _reset()
    var rec: Dictionary = {"path": mode, "grab_state": grab_state}
    var brick: bool = want_finisher.begins_with("endattack smallboy")
    var grab2: bool = grab_state == "grabbed2"
    var miss_kind: String = ("grab2_miss" if grab2 else "grab1_miss")
    var grab_kind: String = "grab2" if grab2 else "grab1"
    var want_grab_clip: String = ("m01_grab_02_forbigguy" if grab2
            else "m01_grab_01_forbigguy")
    var step_action: String = PC.MOVE_DOWN if grab2 else PC.MOVE_UP
    var step_direction: String = "down" if grab2 else "up"
    var step_key: Key = KEY_S if grab2 else KEY_W
    var attack_key: Key = KEY_L if grab2 else KEY_J
    if brick:
        miss_kind = "grab1miss brick"
        grab_kind = "grab1 brick"
        want_grab_clip = "m03_grab_01_forbigguy"
    if real_keys:
        # hold the step and press the mapped attack key.
        Input.action_press(step_action)
        _sync()
        scene._unhandled_input(_key(step_key))
        _sync()
        _pin()
        scene._unhandled_input(_key(attack_key))
    else:
        player.set_held_directions({step_direction: true})
        _check(player.record_standing_combo_press("c" if grab2 else "a"),
                "%s grab press refused" % mode)
    rec["grab_kind_after_press"] = player.attack_kind
    _check(player.attack_kind == miss_kind,
            "%s miss kind %s != %s" % [mode, player.attack_kind, miss_kind])
    var grabbed: bool = false
    for _i: int in range(400):
        _step()
        if victim.state == grab_state:
            grabbed = true
            break
    rec["grab_kind_final"] = player.attack_kind
    player._animate_candidate()
    rec["grab_clip"] = player.candidate_animation_clip
    rec["grab_hold_frames"] = victim.state_time * FPS
    _check(grabbed, "%s: victim not held in %s (state=%s kind=%s)"
            % [mode, grab_state, victim.state, player.attack_kind])
    if not grabbed:
        return rec
    # finisher: hold right (native keystatus right=pressed) + attack key
    if real_keys:
        Input.action_release(step_action)
        Input.action_press(PC.MOVE_RIGHT)
        _sync()
        scene._unhandled_input(_key(KEY_D))
        _sync()
        scene._unhandled_input(_key(attack_key))
    else:
        player.set_held_directions({"right": true})
        player.set_key_status({"right": true, "c": grab2, "a": not grab2})
        _check(player.record_standing_combo_press("c" if grab2 else "a"),
                "%s finisher press refused" % mode)
    rec["fin_kind"] = player.attack_kind
    player._animate_candidate()
    rec["fin_clip"] = player.candidate_animation_clip
    _check(String(rec["fin_kind"]) == want_finisher,
            "%s finisher kind %s != %s" % [mode, rec["fin_kind"], want_finisher])
    _check(String(rec["fin_clip"]) == want_finisher_clip,
            "%s finisher clip %s != %s" % [mode, rec["fin_clip"], want_finisher_clip])
    _check(String(rec["grab_clip"]) == want_grab_clip,
            "%s grab clip %s != %s" % [mode, rec["grab_clip"], want_grab_clip])
    var e: Dictionary = _hold_until(comp)
    rec.merge(e)
    _check(not e.is_empty(), "%s: victim never reached %s" % [mode, comp])
    if not e.is_empty():
        _check(String(e["clip"]) == ("all_end_attack_01_forset03" if comp == "endattackcomp1" else "all_end_attack_02_forset03"),
                "%s comp clip %s" % [mode, e["clip"]])
        _check(absf(float(e["frames"]) - float(want_frames)) <= FR_TOL,
                "%s comp frames %s != %d" % [mode, e["frames"], want_frames])
        _check(String(e["end_state"]) == "faceupko",
                "%s end %s != faceupko" % [mode, e["end_state"]])
    return rec


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 3:
        push_error("Expected <player.glb> <brick.glb> <skin_label>")
        quit(2)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    player = scene.get("player")
    victim = scene.get("computer")
    player.set_physics_process(false)
    victim.set_physics_process(false)
    var info: Dictionary = {
        "skin": args[2], "player_glb": args[0], "brick_glb": args[1],
        "player_loaded": player.candidate_loaded,
        "victim_loaded": victim.candidate_loaded,
        "player_clips": (player._candidate_animation.get_animation_list().size()
                if player._candidate_animation != null else -1),
        "victim_class": victim.skeleton_class_name(),
        "player_class": player.skeleton_class_name(),
        "default_uniques": player.active_uniques(),
    }
    _check(player.candidate_loaded, "player candidate failed: " + player.candidate_load_error)
    _check(victim.candidate_loaded, "victim candidate failed: " + victim.candidate_load_error)
    _check(victim.skeleton_class_name() == "large", "victim skeleton class is not large")
    var default_expected: Array = PortFighter.DEFAULT_BRUCE_UNIQUES.duplicate()
    default_expected.sort()
    _check(player.active_uniques() == default_expected,
            "default active uniques are not native: " + str(player.active_uniques()))
    var recs: Dictionary = {}
    recs["base_grab1_endattack1"] = _run_base("grab1", "endattack1", "endattackcomp1", 93)
    recs["base_grab2_endattack2"] = _run_base("grab2", "endattack2", "endattackcomp2", 130)
    recs["rawcombo_grab1"] = _run_raw("rawcombo", "grabbed1", "endattack1",
            "m01_end_attack_01_forbigguy", "endattackcomp1", 93, false)
    recs["rawcombo_grab2"] = _run_raw("rawcombo", "grabbed2", "endattack2",
            "m01_end_attack_02_forbigguy", "endattackcomp2", 130, false)
    recs["rawkeys_grab1"] = _run_raw("rawkeys", "grabbed1", "endattack1",
            "m01_end_attack_01_forbigguy", "endattackcomp1", 93, true)
    recs["rawkeys_grab2"] = _run_raw("rawkeys", "grabbed2", "endattack2",
            "m01_end_attack_02_forbigguy", "endattackcomp2", 130, true)
    # Explicit Brick / big finisher style: same raw route, only now enabled.
    _reset()
    if not _set_style(BRICK_STYLE):
        failures.append("brick style selection failed")
    else:
        recs["brick_style_grab1"] = _run_raw("brick_style", "grabbed1",
                "endattack smallboy", "m03_end_attack_01_forbigguy",
                "endattackcomp1", 93, false)
    var result: Dictionary = {
        "info": info, "checks": checks, "records": recs,
        "failures": failures, "RESULT": "PASS" if failures.is_empty() else "FAIL",
    }
    print("RAW_FINISHER_VALIDATION=" + JSON.stringify(result))
    scene.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)

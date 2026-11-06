extends SceneTree
## Verify the recovered per-opponent-set victim grab/endattack timings.
##
## Uses the real main.tscn with a Bruce victim candidate that carries every
## forset victim clip (forset01..04 grabbed, forset01..03 end_attack). For each
## opponent attack_config it drives PortFighter.begin_grabbed /
## begin_endattack_victim directly and checks:
##   * the selected archived clip equals the set's recovered clip name,
##   * state_time equals the recovered frame count / 30 fps,
##   * a set whose action or clip is absent fails closed (returns false).
##
## Run:
##   godot --headless --path <proj> --script res://tests/validate_victim_grab_timings.gd -- <candidate.glb>

# Recovered values from adreno_200/set/*.set ANM headers; mirrors
# VICTIM_CLIP_FRAMES but restated so the test pins the numbers independently.
const GRAB_CASES: Array = [
    # config, attack_kind, victim_state, clip, frames
    ["res://data/fighting_set_m03_mapped_attacks.json", "grab1", "grabbed1", "all_grabbed_01_forset03", 90],
    ["res://data/fighting_set_m03_mapped_attacks.json", "grab2", "grabbed2", "all_grabbed_02_forset03", 78],
    ["res://data/attack_config_ken.json", "grab1", "grabbed1", "all_grabbed_01_forset02", 47],
    ["res://data/attack_config_ken.json", "grab2", "grabbed2", "all_grabbed_02_forset02", 98],
    ["res://data/attack_config_chief.json", "grab1", "grabbed1", "all_grabbed_01_forset02", 47],
    ["res://data/attack_config_chief.json", "grab2", "grabbed2", "all_grabbed_02_forset02", 98],
    ["res://data/attack_config_sinfu.json", "grab1", "grabbed1", "all_grabbed_01_forset04", 103],
    # sinfu's own grabcompl2 row uses the special-kick victim clip (55), not the
    # universal all_grabbed_02_forset04 (45); resolved per the set's action row.
    ["res://data/attack_config_sinfu.json", "grab2", "grabbed2", "all_sp_kck_low_forset04", 55],
    ["res://data/attack_config_master.json", "grab1", "grabbed1", "all_sp_pnch_low_forset04", 28],
    ["res://data/attack_config_master.json", "grab2", "grabbed2", "all_sp_kck_low_forset04", 55],
]
const ENDATTACK_CASES: Array = [
    # config, victim state, slot, clip, frames, set_has_endattack_action
    ["res://data/fighting_set_m03_mapped_attacks.json", "grabbed1", "endattackcomp1", "all_end_attack_01_forset03", 93, true],
    ["res://data/fighting_set_m03_mapped_attacks.json", "grabbed2", "endattackcomp2", "all_end_attack_02_forset03", 130, true],
    ["res://data/attack_config_ken.json", "grabbed1", "endattackcomp1", "all_end_attack_01_forset02", 132, true],
    ["res://data/attack_config_ken.json", "grabbed2", "endattackcomp2", "all_end_attack_02_forset02", 155, true],
    # kungfu has no endattackcomp action at all -> fail closed
    ["res://data/attack_config_sinfu.json", "grabbed1", "endattackcomp1", "all_end_attack_01_forset04", 0, false],
    ["res://data/attack_config_master.json", "grabbed2", "endattackcomp2", "all_end_attack_02_forset04", 0, false],
]
const FPS: float = 30.0


func _initialize() -> void:
    call_deferred("_run")


func _make_defender(config: String) -> PortFighter:
    var defender: PortFighter = load("res://scripts/fighter.gd").new()
    defender.configure_attack_config(config)
    root.add_child(defender)
    return defender


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected one Bruce victim candidate GLB path")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", "")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    player.set_physics_process(false)
    if not player.candidate_loaded:
        push_error("Bruce victim candidate failed: " + player.candidate_load_error)
        quit(1)
        return
    if not player.is_player:
        push_error("Expected the scene player to be the human fighter")
        quit(1)
        return
    var pristine: Dictionary = (player.get("_candidate_clip_paths") as Dictionary).duplicate()
    var results: Array = []
    var failures: int = 0

    for case: Array in GRAB_CASES:
        var config: String = case[0]
        var attack: String = case[1]
        var slot: String = case[2]
        var clip: String = case[3]
        var frames: int = case[4]
        var defender: PortFighter = _make_defender(config)
        await process_frame
        _reset_victim(player, pristine)
        player.opponent = defender
        var matched: String = String(player.call("_victim_clip_available", clip))
        var expected_ok: bool = not matched.is_empty()
        var ok: bool = player.begin_grabbed(attack)
        var detail := {
            "mode": "grab", "config": config, "attack": attack, "slot": slot,
            "clip": clip, "frames": frames, "candidate_has_clip": not matched.is_empty(),
            "returned": ok,
        }
        if expected_ok:
            var anim: String = String(player.get("_victim_selected_animation").get(slot, ""))
            var st: float = player.state_time
            var good: bool = ok and player.state == slot and anim == clip \
                    and absf(st - float(frames) / FPS) < 0.0001
            detail["selected_animation"] = anim
            detail["state"] = player.state
            detail["state_time"] = st
            detail["expected_state_time"] = float(frames) / FPS
            detail["ok"] = good
            if not good:
                failures += 1
                push_error("grab case failed: " + JSON.stringify(detail))
        else:
            # Missing clip for this set must fail closed.
            var good := not ok
            detail["ok"] = good
            if not good:
                failures += 1
                push_error("grab case did not fail closed: " + JSON.stringify(detail))
        results.append(detail)
        defender.queue_free()
        await process_frame

    for case: Array in ENDATTACK_CASES:
        var config: String = case[0]
        var victim_state: String = case[1]
        var slot: String = case[2]
        var clip: String = case[3]
        var frames: int = case[4]
        var has_action: bool = case[5]
        var defender: PortFighter = _make_defender(config)
        await process_frame
        _reset_victim(player, pristine)
        player.state = victim_state
        player.state_time = 0.0
        player.opponent = defender
        var matched: String = String(player.call("_victim_clip_available", clip))
        var expected_ok: bool = has_action and not matched.is_empty()
        var ok: bool = player.begin_endattack_victim("")
        var detail := {
            "mode": "endattack", "config": config, "victim_state": victim_state,
            "slot": slot, "clip": clip, "frames": frames, "set_has_action": has_action,
            "candidate_has_clip": not matched.is_empty(), "returned": ok,
        }
        if expected_ok:
            var anim: String = String(player.get("_victim_selected_animation").get(slot, ""))
            var st: float = player.state_time
            var good: bool = ok and player.state == slot and anim == clip \
                    and absf(st - float(frames) / FPS) < 0.0001
            detail["selected_animation"] = anim
            detail["state"] = player.state
            detail["state_time"] = st
            detail["expected_state_time"] = float(frames) / FPS
            detail["ok"] = good
            if not good:
                failures += 1
                push_error("endattack case failed: " + JSON.stringify(detail))
        else:
            var good := not ok
            detail["ok"] = good
            if not good:
                failures += 1
                push_error("endattack case did not fail closed: " + JSON.stringify(detail))
        results.append(detail)
        defender.queue_free()
        await process_frame

    var summary := {
        "candidate": args[0],
        "case_count": results.size(),
        "failures": failures,
        "cases": results,
    }
    print("VICTIM_GRAB_TIMINGS_VALIDATION=" + JSON.stringify(summary))
    scene.queue_free()
    await process_frame
    quit(0 if failures == 0 else 1)


func _reset_victim(player: PortFighter, pristine: Dictionary) -> void:
    player.state = "idle"
    player.state_time = 0.0
    player.attack_kind = ""
    player.set("_candidate_clip_paths", pristine.duplicate())
    player.set("_victim_selected_animation", {})
    player.set("_victim_selected_frames", {})

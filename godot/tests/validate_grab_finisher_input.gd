extends SceneTree
## Verify the recovered brucelee.set candobasicattacks -> endattack1/endattack2
## links end to end on the real main.tscn, and that everything else fails
## closed.
##
## Native facts being exercised (adreno_200/set/brucelee.set, links order
## 34/35, keyboard variant 1):
##   endattack1  sequence [pressa]          keystatus right pressed
##   endattack2  sequence [pressc]          keystatus right pressed
##   conditions  oppposestun + grabdistance (endattack1 = 150, endattack2 = 90)
##   entry_frame 0, no time window; the window is the current action's
##   candobasicattacks group membership.
##
## Successful path: grab1/grab2 puts the victim in grabbed1/2 (its pose reads
## stun), the attacker returns to a candobasicattacks action, and the
## documented attack key while holding toward starts endattack1/2 and turns the
## victim into endattackcomp1/2.

const BRUCE_ACTIONS: Array[String] = ["endattack1", "endattack2"]
const FAILURE_MARK: String = "FAIL"

var match_scene: Node = null


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(FAILURE_MARK + ": " + message)
    quit(1)


func _grab_victim(player: PortFighter, victim: PortFighter, kind: String,
        distance: float) -> bool:
    match_scene._reset_match()
    player._clear_link_state()
    player.position = Vector3(0.0, 1.2, 0.0)
    victim.position = Vector3(distance, 1.2, 0.0)
    player.facing = 1.0
    if not player.request_attack(kind):
        push_error("request_attack(" + kind + ") refused: " + player.size_variant_error)
        return false
    for step: int in range(200):
        player.position = Vector3(0.0, 1.2, 0.0)
        victim.position = Vector3(distance, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
        victim._physics_process(1.0 / 60.0)
        if victim.state in ["grabbed1", "grabbed2"]:
            return true
    push_error(kind + " never grabbed the victim; victim=" + victim.state)
    return false


func _press_finisher(player: PortFighter, victim: PortFighter, key: String,
        finisher: String, victim_state: String) -> bool:
    # The documented key must fire while the victim is held, without waiting
    # for the grab animation to finish.
    if victim.state not in ["grabbed1", "grabbed2"]:
        push_error("Victim was not held before the finisher press; state=" + victim.state)
        return false
    if player.state not in ["startup", "active", "recovery", "idle"]:
        push_error("Attacker was not in a grab/idle action; state=" + player.state)
        return false
    player.set_key_status({"right": true, key: true})
    player.set_held_directions({"right": true})
    if player.record_standing_combo_press(key) == false:
        push_error("record_standing_combo_press(" + key + ") did not start " + finisher)
        return false
    if player.attack_kind != finisher:
        push_error("Expected " + finisher + ", got " + player.attack_kind)
        return false
    var saw_victim: bool = false
    for _step: int in range(120):
        player.position = Vector3(0.0, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
        if victim.state in [victim_state]:
            saw_victim = true
            break
    if not saw_victim:
        push_error("Victim never entered " + victim_state + "; state=" + victim.state)
        return false
    return true


func _press_after_grab_idle(player: PortFighter, victim: PortFighter, key: String,
        finisher: String) -> bool:
    # The same native link must also fire from the idle action once the grab
    # animation has finished, as long as the victim is still held.
    for _step: int in range(400):
        player.position = Vector3(0.0, 1.2, 0.0)
        victim.position = Vector3(0.35, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
        victim._physics_process(1.0 / 60.0)
        if player.state == "idle" and victim.state in ["grabbed1", "grabbed2"]:
            break
    if player.state != "idle" or victim.state not in ["grabbed1", "grabbed2"]:
        push_error("No idle+held window after grab: player=" + player.state
                + " victim=" + victim.state)
        return false
    player.set_key_status({"right": true, key: true})
    player.set_held_directions({"right": true})
    player.record_standing_combo_press(key)
    if player.attack_kind != finisher:
        push_error("Idle press expected " + finisher + ", got " + player.attack_kind)
        return false
    return true


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and Brick candidate GLB paths")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    match_scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(match_scene)
    await process_frame
    await process_frame
    match_scene.set_process(false)
    match_scene.set_physics_process(false)
    var player: PortFighter = match_scene.get("player")
    var victim: PortFighter = match_scene.get("computer")
    player.set_physics_process(false)
    victim.set_physics_process(false)
    player.rage = 100.0

    # 1. Native link sanity: the two finisher links keep their recovered
    #    keysequences, keystatus and conditions.
    var wanted: Dictionary = {
        "endattack1": {"step": "a", "conditions": ["oppposestun", "grabdistance"]},
        "endattack2": {"step": "c", "conditions": ["oppposestun", "grabdistance"]},
    }
    for finisher: String in BRUCE_ACTIONS:
        var link: Dictionary = {}
        for candidate: Dictionary in player._native_links:
            if (String(candidate.get("to", "")) == finisher
                    and String(candidate.get("from_group", "")) == "candobasicattacks"):
                link = candidate
                break
        if link.is_empty():
            _fail("native_links.json lost the " + finisher + " link")
            return
        var steps: Array = Array(link.get("steps", []))
        if steps.size() != 1 or Array(steps[0]) != [wanted[finisher]["step"]]:
            _fail(finisher + " sequence drifted: " + JSON.stringify(steps))
            return
        var status: Array = Array(link.get("status", []))
        var held_ok: bool = false
        for pair_value: Variant in status:
            var pair: Array = pair_value
            if pair.size() == 2 and str(pair[0]) == "right" and str(pair[1]) == "pressed":
                held_ok = true
        if not held_ok:
            _fail(finisher + " lost keystatus right pressed: " + JSON.stringify(status))
            return
        var conditions: Array = Array(link.get("conditions", []))
        for condition: String in wanted[finisher]["conditions"]:
            if not conditions.has(condition):
                _fail(finisher + " lost condition " + condition)
                return

    # 2. grab1 -> endattack1 by the documented key while holding toward.
    if not _grab_victim(player, victim, "grab1", 0.35):
        _fail("grab1 chain setup")
        return
    if not _press_finisher(player, victim, "a", "endattack1", "endattackcomp1"):
        _fail("endattack1 via grab1")
        return
    print("PASS endattack1 from grab1: victim=" + victim.state)

    # 2b. Same link from the idle action after the grab animation finished.
    if not _grab_victim(player, victim, "grab1", 0.35):
        _fail("grab1 idle-path setup")
        return
    if not _press_after_grab_idle(player, victim, "a", "endattack1"):
        _fail("endattack1 from idle after grab")
        return
    print("PASS endattack1 from idle after grab1")

    # 3. grab2 -> endattack2 by the documented key while holding toward.
    #    The previous victim is down (faceupko after endattackcomp), so reset
    #    into a fresh round first; the reset also rebuilds both fighters.
    if not _grab_victim(player, victim, "grab2", 0.35):
        _fail("grab2 chain setup")
        return
    if not _press_finisher(player, victim, "c", "endattack2", "endattackcomp2"):
        _fail("endattack2 via grab2")
        return
    print("PASS endattack2 from grab2: victim=" + victim.state)

    # 4. Fail closed: the same A press without the held toward key must not
    #    fire the finisher (keystatus right pressed is required).
    if not _grab_victim(player, victim, "grab1", 0.35):
        _fail("grab1 chain setup (no-held)")
        return
    # The previous scenario's downed victim must be standing again before this
    # press: reset the round and grab a fresh victim (done by _grab_victim).
    player.set_key_status({"a": true})
    player.set_held_directions({})
    player.record_standing_combo_press("a")
    if player.attack_kind == "endattack1":
        _fail("endattack1 fired without holding the toward key")
        return
    print("PASS no-held-toward rejected: attack=" + player.attack_kind)

    # 5. Fail closed: out of grabdistance (endattack1 limit 150 source units).
    if not _grab_victim(player, victim, "grab1", 0.35):
        _fail("grab1 far chain setup")
        return
    victim.position = Vector3(2.0, 1.2, 0.0)
    player.set_key_status({"right": true, "a": true})
    player.set_held_directions({"right": true})
    var far_key_ok: bool = player.record_standing_combo_press("a")
    if player.attack_kind == "endattack1":
        _fail("endattack1 fired out of grabdistance")
        return
    print("PASS out-of-range rejected: accepted_press=", far_key_ok,
            " attack=", player.attack_kind)

    # 6. Fail closed: the held-victim window closes when the victim breaks out
    #    of grabbed1/2 (here: the grab hold expires into its ground idle).
    if not _grab_victim(player, victim, "grab1", 0.35):
        _fail("grab1 window-close setup")
        return
    for _step: int in range(400):
        player.position = Vector3(0.0, 1.2, 0.0)
        victim.position = Vector3(0.35, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
        victim._physics_process(1.0 / 60.0)
        if victim.state not in ["grabbed1", "grabbed2"]:
            break
    player.set_key_status({"right": true, "a": true})
    player.set_held_directions({"right": true})
    player.record_standing_combo_press("a")
    if player.attack_kind == "endattack1" and victim.state not in ["grabbed1", "grabbed2"]:
        _fail("endattack1 fired after the hold window closed")
        return
    print("PASS window-closed rejected: victim=", victim.state)

    print("GRAB_FINISHER_INPUT_VALIDATION=" + JSON.stringify({
        "endattack1": "endattackcomp1",
        "endattack2": "endattackcomp2",
        "fail_closed": ["no_held_toward", "out_of_range", "window_closed"],
        "source": "brucelee.set links order 34/35, keyboard variant 1",
    }))
    quit(0)

extends SceneTree
## Verify the recovered brucelee.set candobasicattacks finisher links end to end
## on the real main.tscn, and that everything else fails closed.
##
## Native facts being exercised (adreno_200/set/brucelee.set, keyboard variant 1):
##   order 34 candobasicattacks -> endattack1, [pressa], empty unique (generic)
##   order 35 candobasicattacks -> endattack2, [pressc], unique endbrucelee
##   order 36 candobasicattacks -> endattack brick, [pressa], unique endbrickdavis
##   keystatus right pressed; conditions oppposestun + grabdistance
##   entry_frame 0, no time window; the window is the current action's
##   candobasicattacks group membership.
##
## The `unique` token names the matchup OPPONENT.  Against the Brick opponent of
## this fixture, order 36 is the native finisher: order 34 is deferred while the
## specific variant applies, and order 35 is the mirror-only endbrucelee link.
## brucelee.set contains no "endattack2 brick" row, so the c-key path must fail
## closed.  Generic rows are still asserted from the native table (link order,
## sequence, keystatus, conditions) so their coverage is retained.
##
## Successful path: grab1/grab2 puts the victim in grabbed1/2 (its pose reads
## stun), the attacker returns to a candobasicattacks action, and the documented
## A key while holding toward starts endattack brick and turns the victim into
## endattackcomp1.

const BRUCE_ACTIONS: Array[String] = ["endattack1", "endattack2"]
const BRICK_FINISHER: String = "endattack brick"
const FAILURE_MARK: String = "FAIL"

var match_scene: Node = null


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(FAILURE_MARK + ": " + message)
    quit(1)


func _endattack_kind(kind: String) -> bool:
    return (kind in ["endattack1", "endattack2"]
            or kind.begins_with("endattack "))


func _assert_recovered_link_rows(player: PortFighter) -> bool:
    # Keep the generic rows AND the Brick row asserted from the native table.
    var by_order: Dictionary = {}
    for link: Dictionary in player._native_links:
        by_order[int(link.get("order", -1))] = link
    var expected: Dictionary = {
        34: ["endattack1", ""],
        35: ["endattack2", "endbrucelee"],
        36: ["endattack brick", "endbrickdavis"],
    }
    for order: int in expected:
        var row: Array = expected[order]
        var link: Dictionary = by_order.get(order, {})
        var unique: Array = Array(link.get("unique", []))
        var tag: String = str(unique[0]) if not unique.is_empty() else ""
        if (link.is_empty()
                or str(link.get("to", "")) != str(row[0])
                or str(link.get("from_group", "")) != "candobasicattacks"
                or tag != str(row[1])):
            _fail("recovered link order " + str(order) + " drifted: " + str(link))
            return false
    if player._opponent_suffix_token() != "brick":
        _fail("expected a Brick opponent token, got " + player._opponent_suffix_token())
        return false
    if player._native_link_unique_ok(by_order.get(35, {})):
        _fail("mirror-only order 35 unexpectedly passed the owner gate")
        return false
    if not player._native_link_unique_ok(by_order.get(36, {})):
        _fail("Brick order 36 was refused by the owner gate")
        return false
    return true


func _press_refused_finisher(player: PortFighter, victim: PortFighter,
        key: String) -> bool:
    # No recovered c-key endattack variant exists for a Brick opponent.  The
    # press must not start any endattack and must not consume the victim.
    if victim.state not in ["grabbed1", "grabbed2"]:
        push_error("Victim was not held before the refused finisher press")
        return false
    var before: String = player.attack_kind
    player.set_key_status({"right": true, key: true})
    player.set_held_directions({"right": true})
    player.record_standing_combo_press(key)
    if _endattack_kind(player.attack_kind):
        push_error("mirror-only finisher fired against Brick: " + player.attack_kind)
        return false
    if player.attack_kind != before:
        push_error("refused finisher press changed the grab: " + before
                + " -> " + player.attack_kind)
        return false
    for _step: int in range(120):
        player.position = Vector3(0.0, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
        if victim.state.begins_with("endattackcomp"):
            push_error("refused finisher consumed the victim: " + victim.state)
            return false
    return true


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

    # 1. Native link sanity: generic and Brick finisher links keep their
    #    recovered keysequences, keystatus, conditions and unique owner tags.
    if not _assert_recovered_link_rows(player):
        return
    var wanted: Dictionary = {
        "endattack1": {"step": "a", "conditions": ["oppposestun", "grabdistance"]},
        "endattack2": {"step": "c", "conditions": ["oppposestun", "grabdistance"]},
        "endattack brick": {"step": "a", "conditions": ["oppposestun", "grabdistance"]},
    }
    for finisher: String in wanted:
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

    # 2. grab1 -> endattack brick by the documented A key while holding toward.
    if not _grab_victim(player, victim, "grab1", 0.35):
        _fail("grab1 chain setup")
        return
    if not _press_finisher(player, victim, "a", BRICK_FINISHER, "endattackcomp1"):
        _fail(BRICK_FINISHER + " via grab1")
        return
    print("PASS " + BRICK_FINISHER + " from grab1: victim=" + victim.state)

    # 2b. Same recovered link from the idle action after the grab finished.
    if not _grab_victim(player, victim, "grab1", 0.35):
        _fail("grab1 idle-path setup")
        return
    if not _press_after_grab_idle(player, victim, "a", BRICK_FINISHER):
        _fail(BRICK_FINISHER + " from idle after grab")
        return
    print("PASS " + BRICK_FINISHER + " from idle after grab1")

    # 3. There is no "endattack2 brick" row: order 35 is the mirror-only
    #    endbrucelee link, so the c-key path must fail closed against Brick.
    if not _grab_victim(player, victim, "grab2", 0.35):
        _fail("grab2 chain setup")
        return
    if not _press_refused_finisher(player, victim, "c"):
        _fail("mirror-only c finisher was not refused")
        return
    print("PASS mirror-only c finisher refused: victim=" + victim.state)

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
    if _endattack_kind(player.attack_kind):
        _fail("finisher fired without holding the toward key: " + player.attack_kind)
        return
    print("PASS no-held-toward rejected: attack=" + player.attack_kind)

    # 5. Fail closed: out of grabdistance (order 36 limit 150 source units).
    if not _grab_victim(player, victim, "grab1", 0.35):
        _fail("grab1 far chain setup")
        return
    victim.position = Vector3(2.0, 1.2, 0.0)
    player.set_key_status({"right": true, "a": true})
    player.set_held_directions({"right": true})
    var far_key_ok: bool = player.record_standing_combo_press("a")
    if _endattack_kind(player.attack_kind):
        _fail("finisher fired out of grabdistance: " + player.attack_kind)
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
    if _endattack_kind(player.attack_kind) and victim.state not in ["grabbed1", "grabbed2"]:
        _fail("finisher fired after the hold window closed: " + player.attack_kind)
        return
    print("PASS window-closed rejected: victim=", victim.state)

    print("GRAB_FINISHER_INPUT_VALIDATION=" + JSON.stringify({
        "brick_finisher": BRICK_FINISHER,
        "brick_victim": "endattackcomp1",
        "generic_rows": [34, 35],
        "brick_row": 36,
        "mirror_finisher_refused": "endattack2 / endbrucelee",
        "fail_closed": ["no_held_toward", "out_of_range", "window_closed", "mirror_c"],
        "source": "brucelee.set links order 34/35/36, keyboard variant 1",
    }))
    quit(0)

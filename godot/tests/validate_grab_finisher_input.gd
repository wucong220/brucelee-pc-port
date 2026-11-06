extends SceneTree
## Verify the recovered brucelee.set candobasicattacks finisher links end to end
## on the real main.tscn under the native active-unique list, and that
## everything else fails closed.
##
## Native facts being exercised (adreno_200/set/brucelee.set, keyboard variant 1):
##   order 34 candobasicattacks -> endattack1, [pressa], empty unique (generic)
##   order 35 candobasicattacks -> endattack2, [pressc], unique endbrucelee
##   order 36 candobasicattacks -> endattack brick, [pressa], unique endbrickdavis
##   order 44 candobasicattacks -> endattack smallboy, [pressa], unique endsmallboy
##   keystatus right pressed; conditions oppposestun + grabdistance
##   entry_frame 0, no time window; the window is the current action's
##   candobasicattacks group membership.
##
## CFighter::IsLinkAllowed compares a row's `unique` tags with the fighter's own
## active list.  The default list is the 8 characters.list IDs, so:
##   * A starts endattack1 (order 34) and C starts endattack2 (order 35);
##   * orders 36..44 are refused even against a Brick opponent.
## An explicit {grabs/graba=grababrick, endmove=endsmallboy} selection removes
## grababrucelee/endbrucelee and makes orders 8/383/44 apply, so the documented
## A press then starts the big-skeleton endattack smallboy and C is refused.
##
## Successful path: grab1/grab2 puts the victim in grabbed1/2 (its pose reads
## stun), the attacker returns to a candobasicattacks action, and the documented
## key while holding toward starts the finisher and converts the victim into
## endattackcomp1/2.

const DEFAULT_FINISHERS: Dictionary = {
    "a": ["endattack1", "m01_end_attack_01", "endattackcomp1"],
    "c": ["endattack2", "m01_end_attack_02", "endattackcomp2"],
}
const BRICK_STYLE: Dictionary = {
    "grabs/graba": "grababrick",
    "endmove/endmove": "endsmallboy",
}
const FAILURE_MARK: String = "FAIL"

var match_scene: Node = null
var player: PortFighter = null
var victim: PortFighter = null


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(FAILURE_MARK + ": " + message)
    quit(1)


func _endattack_kind(kind: String) -> bool:
    return (kind in ["endattack1", "endattack2"]
            or kind.begins_with("endattack "))


func _set_style(groups: Dictionary) -> bool:
    var catalog = StyleCatalog.new()
    if not catalog.load_catalog():
        _fail("style catalog failed closed: " + catalog.error)
        return false
    var store = match_scene.get("style_store")
    if store == null:
        _fail("main did not create the saved style store")
        return false
    store.selections = catalog.defaults()
    for group_key: String in groups:
        store.selections[group_key] = groups[group_key]
    match_scene._apply_style_editor()
    return true


func _assert_recovered_link_rows() -> bool:
    var by_order: Dictionary = {}
    for link: Dictionary in player._native_links:
        by_order[int(link.get("order", -1))] = link
    var expected: Dictionary = {
        34: ["endattack1", ""],
        35: ["endattack2", "endbrucelee"],
        36: ["endattack brick", "endbrickdavis"],
        44: ["endattack smallboy", "endsmallboy"],
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
    var default_expected: Array = PortFighter.DEFAULT_BRUCE_UNIQUES.duplicate()
    default_expected.sort()
    if player.active_uniques() != default_expected:
        _fail("default active uniques are wrong: " + str(player.active_uniques()))
        return false
    if not player._native_link_unique_ok(by_order[34]):
        _fail("empty-unique order 34 was refused")
        return false
    if not player._native_link_unique_ok(by_order[35]):
        _fail("default endbrucelee order 35 was refused")
        return false
    for order: int in [36, 44]:
        if player._native_link_unique_ok(by_order[order]):
            _fail("default gate accepted order " + str(order))
            return false
    return true


func _press_refused_finisher(key: String) -> bool:
    # No c-key endattack variant survives the selected style.  The press must
    # not start any endattack and must not consume the victim.
    if victim.state not in ["grabbed1", "grabbed2"]:
        push_error("Victim was not held before the refused finisher press")
        return false
    var before: String = player.attack_kind
    player.set_key_status({"right": true, key: true})
    player.set_held_directions({"right": true})
    player.record_standing_combo_press(key)
    if _endattack_kind(player.attack_kind):
        push_error("refused finisher fired: " + player.attack_kind)
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


func _grab_via_link(step_direction: String, key: String, miss: String,
        kind: String, distance: float) -> bool:
    match_scene._reset_match()
    player._clear_link_state()
    player.state = "idle"
    player.state_time = 0.0
    player.attack_kind = ""
    player.rage = 100.0
    player.position = Vector3(0.0, 1.2, 0.0)
    victim.position = Vector3(distance, 1.2, 0.0)
    player.facing = 1.0
    player.set_key_status({})
    player.set_held_directions({step_direction: true})
    if not player.record_standing_combo_press(key):
        push_error("link did not start from the step action")
        return false
    if player.attack_kind != miss:
        push_error("Expected " + miss + ", got " + player.attack_kind)
        return false
    for step: int in range(200):
        player.position = Vector3(0.0, 1.2, 0.0)
        victim.position = Vector3(distance, 1.2, 0.0)
        player._physics_process(1.0 / 60.0)
        victim._physics_process(1.0 / 60.0)
        if player.attack_kind == kind and victim.state in ["grabbed1", "grabbed2"]:
            return true
    push_error(miss + " never chained into " + kind + "; player="
            + player.attack_kind + " victim=" + victim.state)
    return false


func _press_finisher(key: String, finisher: String, victim_state: String) -> bool:
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


func _press_after_grab_idle(key: String, finisher: String) -> bool:
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
    current_scene = match_scene
    await process_frame
    await process_frame
    match_scene.set_process(false)
    match_scene.set_physics_process(false)
    player = match_scene.get("player")
    victim = match_scene.get("computer")
    player.set_physics_process(false)
    victim.set_physics_process(false)
    player.rage = 100.0

    # 1. Native link sanity: the recovered keysequences, keystatus, conditions
    #    and unique owner tags are unchanged.
    if not _assert_recovered_link_rows():
        return
    var wanted: Dictionary = {
        "endattack1": {"step": "a"},
        "endattack2": {"step": "c"},
        "endattack brick": {"step": "a"},
        "endattack smallboy": {"step": "a"},
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
        for condition: String in ["oppposestun", "grabdistance"]:
            if not conditions.has(condition):
                _fail(finisher + " lost condition " + condition)
                return

    # 2. Default native: grab1 -> endattack1 by the documented A key.
    if not _grab_via_link("up", "a", "grab1_miss", "grab1", 0.35):
        _fail("grab1 chain setup")
        return
    if not _press_finisher("a", "endattack1", "endattackcomp1"):
        _fail("endattack1 via grab1")
        return
    print("PASS endattack1 from grab1: victim=" + victim.state)

    # 2b. Same recovered link from the idle action after the grab finished.
    if not _grab_via_link("up", "a", "grab1_miss", "grab1", 0.35):
        _fail("grab1 idle-path setup")
        return
    if not _press_after_grab_idle("a", "endattack1"):
        _fail("endattack1 from idle after grab")
        return
    print("PASS endattack1 from idle after grab1")

    # 3. Default native: grab2 -> endattack2 by the documented C key.
    if not _grab_via_link("down", "c", "grab2_miss", "grab2", 0.35):
        _fail("grab2 chain setup")
        return
    if not _press_finisher("c", "endattack2", "endattackcomp2"):
        _fail("endattack2 via grab2")
        return
    print("PASS endattack2 from grab2: victim=" + victim.state)

    # 4. Fail closed: the same A press without the held toward key must not
    #    fire the finisher (keystatus right pressed is required).
    if not _grab_via_link("up", "a", "grab1_miss", "grab1", 0.35):
        _fail("grab1 chain setup (no-held)")
        return
    player.set_key_status({"a": true})
    player.set_held_directions({})
    player.record_standing_combo_press("a")
    if _endattack_kind(player.attack_kind):
        _fail("finisher fired without holding the toward key: " + player.attack_kind)
        return
    print("PASS no-held-toward rejected: attack=" + player.attack_kind)

    # 5. Fail closed: out of grabdistance.
    if not _grab_via_link("up", "a", "grab1_miss", "grab1", 0.35):
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
    if not _grab_via_link("up", "a", "grab1_miss", "grab1", 0.35):
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

    # 7. Explicit Brick / big finisher style: grab1 brick -> endattack smallboy,
    #    and the removed endbrucelee row refuses the C key.
    if not _set_style(BRICK_STYLE):
        return
    if not _grab_via_link("up", "a", "grab1miss brick", "grab1 brick", 0.35):
        _fail("Brick grab1 chain setup")
        return
    if not _press_finisher("a", "endattack smallboy", "endattackcomp1"):
        _fail("endattack smallboy via explicit Brick style")
        return
    print("PASS endattack smallboy from explicit Brick style: victim=" + victim.state)
    if not _grab_via_link("down", "c", "grab2_miss", "grab2", 0.35):
        _fail("Brick style grab2 setup")
        return
    if not _press_refused_finisher("c"):
        _fail("removed endbrucelee c finisher was not refused")
        return
    print("PASS selected c finisher refused: victim=" + victim.state)

    print("GRAB_FINISHER_INPUT_VALIDATION=" + JSON.stringify({
        "default_finishers": {"a": "endattack1/endattackcomp1",
            "c": "endattack2/endattackcomp2"},
        "brick_style_finisher": "endattack smallboy/endattackcomp1",
        "generic_rows": [34, 35],
        "brick_rows": [36, 44],
        "selected_c_refused": "endbrucelee removed by the selection",
        "fail_closed": ["no_held_toward", "out_of_range", "window_closed"],
        "source": "brucelee.set links order 34/35/36/44, keyboard variant 1",
    }))
    quit(0)

extends SceneTree
## Validate the grab miss -> grab chains on the Bruce candidate through the
## recovered native link path, under the native per-fighter active-unique list.
##
## The prototype used a pending combo queue drained by
## _try_begin_pending_special_combo.  That function is gone; the decompiled
## model (krm::CFighter::UserControlUpdate) re-evaluates the native link table
## on every physics update, so this test drives the same recovered behaviour
## through the public API only:
##   record_standing_combo_press for the link input, _physics_process for the
##   frame clock, and begin_grabbed (called by the grab contact path) for the
##   victim state.
##
## Native facts exercised (adreno_200/set/brucelee.set, native_links.json,
## keyboard variant 1).  CFighter::IsLinkAllowed compares a row's `unique` tags
## with the fighter's own active list; the Brick opponent does NOT add its IDs.
##   DEFAULT (characters.list uniques of Bruce Lee):
##     stepright -> grab1miss     order 6,   unique grababrucelee
##     stepleft  -> grab2miss     order 7,   unique grabbbrucelee
##     grab1miss -> grab1         order 347, automatic, window [8, 9]
##     grab2miss -> grab2         order 349, automatic, window [8, 9]
##   EXPLICIT Brick style (grabs/graba = grababrick):
##     grababrick replaces grababrucelee in the seven category slots, so
##     stepright -> grab1miss brick order 8  (unique grababrick)
##     grab1miss brick -> grab1 brick order 383 (same unique, window [10, 11])
##     The style catalog has no Brick grabs/grabb entry, so grab2 stays Bruce
##     and every grabbbrick row (order 17/385) stays refused.
## Conditions: grabdistance + oppposestand + oppnotblocking.
## Miss actions consume 66 rage on entry.
## Generic grab impacts 6 + 5 + 9 = 20 (grab1) / 5 + 15 = 20 (grab2);
## Brick grab1 impacts 6 + 6 + 10 = 22.
## Damage totals below are read from the recovered ATTACKS row for the selected
## kind, not hardcoded, so a native-damage drift stays visible.
##
## The opponent's skeleton class is "large" (thai set), so both the Bruce and
## the Brick variants resolve their forbigguy size versions.

const CANDIDATES: Dictionary = {
    "bruce": {
        "bytes": 12188652,
        "sha256": "6014515278745d97c264dad48ecef9ae92304fc868f0d6e0f0ef6917f285dd14",
        "animations": 104,
    },
    "brick": {
        "bytes": 4986780,
        "sha256": "c5dd5ba63a4cf6a65a994809d1f43f159db0c33cc4cd4e0b400658f680a74318",
        "animations": 94,
    },
}
const DEFAULT_CASES: Array = [
    # step direction, key, miss, grab, first impact, total damage, victim state,
    # miss clip (size version), grab clip (size version), victim clip,
    # grab source animation.
    ["up", "a", "grab1miss", "grab1", 6.0, 20.0, "grabbed1",
        "m02_grab_01_forbigguy", "m01_grab_01_forbigguy",
        "all_grabbed_01_forset03", "m01_grab_01"],
    ["down", "c", "grab2miss", "grab2", 5.0, 20.0, "grabbed2",
        "m02_grab_01_forbigguy", "m01_grab_02_forbigguy",
        "all_grabbed_02_forset03", "m01_grab_02"],
]
const BRICK_CASES: Array = [
    ["up", "a", "grab1miss brick", "grab1 brick", 6.0, 22.0, "grabbed1",
        "m02_grab_01_forbigguy", "m03_grab_01_forbigguy",
        "all_grabbed_01_forset03", "m03_grab_01"],
]
const RAGE_BEFORE: float = 70.0
const RAGE_COST: float = 66.0
const BRICK_STYLE: Dictionary = {"grabs/graba": "grababrick"}

var scene: Node = null
var player: PortFighter = null
var defender: PortFighter = null


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected the Bruce and Brick candidate GLB paths")
        quit(1)
        return
    if not _validate_candidate_identity(args[0], "bruce"):
        quit(1)
        return
    if not _validate_candidate_identity(args[1], "brick"):
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
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
    defender = scene.get("computer")
    player.set_physics_process(false)
    defender.set_physics_process(false)
    if not player.candidate_loaded:
        push_error("Grab candidate failed: " + player.candidate_load_error)
        quit(1)
        return
    if not defender.candidate_loaded:
        push_error("Grab victim candidate failed: " + defender.candidate_load_error)
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    for required: String in ["grab1_miss", "grab2_miss", "grab1", "grab2"]:
        if not clips.has(required):
            push_error("Candidate is missing " + required)
            quit(1)
            return

    if not _assert_default_link_rows():
        quit(1)
        return
    for case: Array in DEFAULT_CASES:
        if not _validate_grab(case):
            quit(1)
            return
    if not _validate_grab_range():
        quit(1)
        return

    # Explicit Brick style: only the selected ID may pass, and it replaces the
    # Bruce grab-a entry instead of being added next to it.
    if not _set_style(BRICK_STYLE):
        quit(1)
        return
    if not _assert_brick_link_rows():
        quit(1)
        return
    for case: Array in BRICK_CASES:
        if not _validate_grab(case):
            quit(1)
            return
    # Brick has no selectable grabs/grabb entry: the still-selected Bruce
    # grabbbrucelee keeps grab2 native and refuses the grabbbrick rows.
    if not _validate_grab(DEFAULT_CASES[1]):
        quit(1)
        return

    # These clear the defender's action-category table, so they run last.
    if not _validate_blocked_grab_rejects_chain():
        quit(1)
        return
    if not _validate_below_rage_gate():
        quit(1)
        return

    print("GRAB_VALIDATION=" + JSON.stringify({
        "default_grabs": ["grab1miss->grab1", "grab2miss->grab2"],
        "brick_style_grabs": ["grab1miss brick->grab1 brick"],
        "default_rows": [6, 7, 347, 349],
        "brick_rows": [8, 383],
        "bruce_bytes": CANDIDATES["bruce"]["bytes"],
        "bruce_sha256": CANDIDATES["bruce"]["sha256"],
        "brick_bytes": CANDIDATES["brick"]["bytes"],
        "brick_sha256": CANDIDATES["brick"]["sha256"],
        "scope": "native active uniques: the default set is the 8 characters.list "
                + "IDs; the Brick opponent adds nothing. An explicit grabs/graba="
                + "grababrick selection makes orders 8/383 the only grab-a rows; "
                + "grab2 stays Bruce because no Brick grabb entry exists.",
    }))
    scene.queue_free()
    await process_frame
    quit(0)


func _set_style(groups: Dictionary) -> bool:
    ## Route the selection through main's store, exactly like VS / Free
    ## Training: the test never pokes fighter internals.
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


func _reset(distance: float) -> void:
    scene._reset_match()
    player._clear_link_state()
    player.state = "idle"
    player.state_time = 0.0
    player.attack_kind = ""
    player.health = PortFighter.MAX_HEALTH
    defender.health = PortFighter.MAX_HEALTH
    defender.guard_held = false
    player.rage = RAGE_BEFORE
    player.position = Vector3(0.0, 1.2, 0.0)
    defender.position = Vector3(distance, 1.2, 0.0)
    player.opponent = defender
    player.facing = 1.0
    player.set_key_status({})
    player.set_held_directions({})


func _pin(distance: float) -> void:
    player.position = Vector3(0.0, 1.2, 0.0)
    defender.position = Vector3(distance, 1.2, 0.0)


func _step(distance: float) -> void:
    # Two 1/60 steps per source frame: the frame clock truncates
    # (elapsed_ms * 0.03), so one 1/60 step does not advance a whole frame.
    for _half: int in range(2):
        _pin(distance)
        player._physics_process(1.0 / 60.0)
        defender._physics_process(1.0 / 60.0)


func _start_miss(step_direction: String, key: String, distance: float) -> bool:
    # The recovered grab links start from the step actions, which the movement
    # layer reports while the matching direction is held: up -> stepright
    # (grab1miss), down -> stepleft (grab2miss).  The keyboard variant of both
    # links is a single press.
    _reset(distance)
    player.set_held_directions({step_direction: true})
    if player._current_action_name() not in ["stepright", "stepleft"]:
        push_error("Held " + step_direction + " did not select a step action: "
                + player._current_action_name())
        return false
    return player.record_standing_combo_press(key)


func _validate_grab(case: Array) -> bool:
    var step_direction: String = case[0]
    var key: String = case[1]
    var miss: String = case[2]
    var target: String = case[3]
    # The recovered ATTACKS row for the selected kind is the evidence for
    # damage; generic and Brick variants do not share the same impact totals.
    var details: Dictionary = player.ATTACKS.get(target, {})
    var multi: Array = Array(details.get("multi_impacts", []))
    var first_impact: float = float(case[4])
    if not multi.is_empty() and Dictionary(multi[0]).has("damage"):
        first_impact = float(Dictionary(multi[0])["damage"])
    var total_damage: float = float(details.get("damage", float(case[5])))
    if multi.is_empty():
        # A single-impact recovered row (e.g. Brick grab2) applies its whole
        # damage in one impact.
        first_impact = total_damage
    var victim_state: String = case[6]
    var miss_clip: String = case[7]
    var grab_clip: String = case[8]
    var victim_clip: String = case[9]
    var grab_animation: String = case[10]
    # The link row names the native action; the playable kind is its mapped
    # ATTACKS entry ("grab1miss" -> "grab1_miss", variant rows keep their name).
    var miss_kind: String = player.kind_for_action(miss)
    if miss_kind.is_empty():
        miss_kind = miss
    if not _start_miss(step_direction, key, 0.3):
        push_error(miss + " did not start")
        return false
    if player.attack_kind != miss_kind:
        push_error("Expected " + miss_kind + ", got " + player.attack_kind)
        return false
    if player.current_source_animation() != "m02_grab_01":
        push_error(miss + " requested " + player.current_source_animation())
        return false
    player._animate_candidate()
    if player.candidate_animation_clip != miss_clip:
        push_error(miss + " did not play the large-opponent size version: "
                + player.candidate_animation_clip)
        return false
    if absf(player.rage - (RAGE_BEFORE - RAGE_COST)) > 0.001:
        push_error(miss + " did not consume 66 rage: " + str(player.rage))
        return false
    # The automatic chain opens on the recovered link window: [8, 9] for the
    # default grab1miss/grab2miss rows, [10, 11] for the Brick grab1 row.
    var auto_link: Dictionary = {}
    for candidate: Dictionary in player._native_links:
        if (str(candidate.get("from", "")) == miss
                and str(candidate.get("to", "")) == target):
            auto_link = candidate
            break
    var chain_frame: int = int(Array(auto_link.get("time", [8, 9]))[0])
    # The frame clock lags one physics step, so check (a) it has NOT chained
    # before the recovered window opens and (b) it has chained within the
    # two-frame window plus one clock step.  This keeps the window assertion
    # strict without pinning an exact tick.
    for _frame: int in range(chain_frame - 1):
        _step(0.3)
    if player.attack_kind != miss_kind:
        push_error(miss + " chained before its [%d, %d] window: " % [chain_frame, chain_frame + 1]
                + player.attack_kind)
        return false
    var chained: bool = false
    for _frame: int in range(4):
        _step(0.3)
        if player.attack_kind == target:
            chained = true
            break
    if not chained:
        push_error(miss + " did not chain to " + target + " around frame "
                + str(chain_frame) + ": " + player.attack_kind)
        return false
    if player.current_source_animation() != grab_animation:
        push_error(target + " requested " + player.current_source_animation())
        return false
    player._animate_candidate()
    if player.candidate_animation_clip != grab_clip:
        push_error(target + " did not play the large-opponent size version: "
                + player.candidate_animation_clip)
        return false
    # The chain must actually grab: the contact path calls begin_grabbed, which
    # puts the victim into grabbed1/grabbed2 on the set's victim clip, and the
    # recovered impacts must land for the full damage.
    var saw_grabbed: bool = false
    var saw_first_impact: bool = false
    for _frame: int in range(150):
        _step(0.3)
        if (not saw_first_impact and defender.health
                < PortFighter.MAX_HEALTH - 0.001):
            saw_first_impact = true
            if absf(defender.health - (PortFighter.MAX_HEALTH - first_impact)) > 0.001:
                push_error(target + " first impact was not " + str(first_impact)
                        + ": " + str(defender.health))
                return false
        if defender.state == victim_state:
            saw_grabbed = true
            defender._animate_candidate()
            if defender.candidate_animation_clip != victim_clip:
                push_error(target + " victim clip was "
                        + defender.candidate_animation_clip)
                return false
            if not bool(player.get("_grab_connected")):
                push_error(target + " did not set the grab-connected flag")
                return false
    if not saw_grabbed:
        push_error(target + " never grabbed the victim: " + defender.state)
        return false
    if absf(defender.health - (PortFighter.MAX_HEALTH - total_damage)) > 0.001:
        push_error(target + " total damage was not " + str(total_damage) + ": "
                + str(defender.health))
        return false
    return true


func _validate_grab_range() -> bool:
    # grab1miss -> grab1 requires grabdistance; beyond it the miss plays out and
    # returns to idle without grabbing or dealing damage.
    if not _start_miss("up", "a", 2.0):
        push_error("Far grab miss did not start")
        return false
    for _frame: int in range(40):
        _step(2.0)
    if player.attack_kind in ["grab1", "grab2", "grab1 brick", "grab2 brick"]:
        push_error("Grab chained out of range")
        return false
    if not is_equal_approx(defender.health, PortFighter.MAX_HEALTH):
        push_error("Out-of-range grab dealt damage")
        return false
    return true


func _validate_blocked_grab_rejects_chain() -> bool:
    # oppnotblocking is a condition of the chain, so a guarding opponent keeps
    # the miss from becoming a grab.
    if not _start_miss("up", "a", 0.3):
        push_error("Blocked grab miss did not start")
        return false
    defender.guard_held = true
    # Fail-closed blocking state: with no recovered action-category row the
    # native CFighter::IsBlocking probe reports true, so oppnotblocking is false
    # for the whole [8, 9] chain window.
    defender._native_action_categories.clear()
    for _frame: int in range(40):
        defender.guard_held = true
        defender._native_action_categories.clear()
        _step(0.3)
    if player.attack_kind in ["grab1", "grab1 brick"]:
        push_error("Grab chained into a blocking opponent")
        return false
    if bool(player.get("_grab_connected")):
        push_error("A blocked grab set the grab-connected flag")
        return false
    if not is_equal_approx(defender.health, PortFighter.MAX_HEALTH):
        push_error("A blocked grab dealt damage: " + str(defender.health))
        return false
    if defender.state in ["grabbed1", "grabbed2"]:
        push_error("A blocked grab put the victim in " + defender.state)
        return false
    return true


func _validate_below_rage_gate() -> bool:
    # rage2thirds compares rage < 66, so 65 must not start the grab miss; the
    # same press falls through to the basic attack instead.
    _reset(0.3)
    player.rage = 65.0
    player.set_held_directions({"up": true})
    player.record_standing_combo_press("a")
    if player.attack_kind in ["grab1_miss", "grab2_miss", "grab1", "grab2",
            "grab1miss", "grab2miss", "grab1miss brick", "grab2miss brick",
            "grab1 brick", "grab2 brick"]:
        push_error("Grab started below the rage2thirds gate: " + player.attack_kind)
        return false
    if absf(player.rage - 65.0) > 0.001:
        push_error("Rejected grab spent rage: " + str(player.rage))
        return false
    return true


func _by_order() -> Dictionary:
    var by_order: Dictionary = {}
    for link: Dictionary in player._native_links:
        by_order[int(link.get("order", -1))] = link
    return by_order


func _assert_default_link_rows() -> bool:
    var default_expected: Array = PortFighter.DEFAULT_BRUCE_UNIQUES.duplicate()
    default_expected.sort()
    if player.active_uniques() != default_expected:
        push_error("default active uniques are not the 8 native IDs: "
                + str(player.active_uniques()))
        return false
    var by_order: Dictionary = _by_order()
    var expected: Dictionary = {
        6: ["stepright", "grab1miss", "grababrucelee"],
        7: ["stepleft", "grab2miss", "grabbbrucelee"],
        8: ["stepright", "grab1miss brick", "grababrick"],
        17: ["stepleft", "grab2miss brick", "grabbbrick"],
        347: ["grab1miss", "grab1", "grababrucelee"],
        349: ["grab2miss", "grab2", "grabbbrucelee"],
        383: ["grab1miss brick", "grab1 brick", "grababrick"],
        385: ["grab2miss brick", "grab2 brick", "grabbbrick"],
    }
    for order: int in expected:
        var row: Array = expected[order]
        var link: Dictionary = by_order.get(order, {})
        var unique: Array = Array(link.get("unique", []))
        var tag: String = str(unique[0]) if not unique.is_empty() else ""
        if (link.is_empty()
                or ("" if link.get("from") == null else str(link.get("from"))) != str(row[0])
                or str(link.get("to", "")) != str(row[1])
                or tag != str(row[2])):
            push_error("recovered link order " + str(order) + " drifted: " + str(link))
            return false
    # Native gate: the default set owns the Bruce rows and nothing else.
    for order: int in [6, 7, 347, 349]:
        if not player._native_link_unique_ok(by_order[order]):
            push_error("default gate refused the Bruce row " + str(order))
            return false
    for order: int in [8, 17, 383, 385]:
        if player._native_link_unique_ok(by_order[order]):
            push_error("default gate accepted the Brick row " + str(order))
            return false
    return true


func _assert_brick_link_rows() -> bool:
    var expected: Array[String] = [
        "brucelee", "hpunchbrucelee", "lpunchbrucelee", "hkickbrucelee",
        "lkickbrucelee", "grababrick", "grabbbrucelee", "endbrucelee",
    ]
    expected.sort()
    if player.active_uniques() != expected:
        push_error("explicit Brick active uniques are wrong: "
                + str(player.active_uniques()))
        return false
    var by_order: Dictionary = _by_order()
    if player._native_link_unique_ok(by_order[6]):
        push_error("explicit Brick selection kept the generic order 6 row")
        return false
    if player._native_link_unique_ok(by_order[347]):
        push_error("explicit Brick selection kept the generic order 347 row")
        return false
    if not player._native_link_unique_ok(by_order[8]):
        push_error("explicit Brick selection refused order 8")
        return false
    if not player._native_link_unique_ok(by_order[383]):
        push_error("explicit Brick selection refused order 383")
        return false
    # grab-b group was not selected: both Brick and Bruce-b behaviour stay.
    if not player._native_link_unique_ok(by_order[7]):
        push_error("explicit Brick selection refused the native order 7 row")
        return false
    if not player._native_link_unique_ok(by_order[349]):
        push_error("explicit Brick selection refused the native order 349 row")
        return false
    if player._native_link_unique_ok(by_order[17]):
        push_error("unselectable grabbbrick order 17 was accepted")
        return false
    if player._native_link_unique_ok(by_order[385]):
        push_error("unselectable grabbbrick order 385 was accepted")
        return false
    return true


func _validate_candidate_identity(path: String, role: String) -> bool:
    var expected: Dictionary = CANDIDATES[role]
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error(role + " candidate could not be opened")
        return false
    var bytes: PackedByteArray = file.get_buffer(file.get_length())
    file.close()
    if bytes.size() != int(expected["bytes"]):
        push_error(role + " candidate size mismatch: " + str(bytes.size()))
        return false
    var hash: HashingContext = HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    hash.update(bytes)
    if hash.finish().hex_encode().to_lower() != String(expected["sha256"]):
        push_error(role + " candidate SHA-256 mismatch")
        return false
    var json_length: int = bytes.decode_u32(12)
    var document: Variant = JSON.parse_string(
        bytes.slice(20, 20 + json_length).get_string_from_utf8())
    if (not document is Dictionary or not document.has("animations")
            or document["animations"].size() != int(expected["animations"])):
        push_error(role + " candidate animation count mismatch")
        return false
    return true

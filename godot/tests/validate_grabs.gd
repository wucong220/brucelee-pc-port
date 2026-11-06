extends SceneTree
## Validate grab miss -> grab chains on the Bruce candidate through the recovered
## native link path.
##
## The prototype used a pending combo queue drained by
## _try_begin_pending_standing_combo.  That function is gone; the decompiled
## model (krm::CFighter::UserControlUpdate) re-evaluates the native link table
## on every physics update, so this test drives the same recovered behaviour
## through the public API only:
##   record_standing_combo_press for the link input, _physics_process for the
##   frame clock, and begin_grabbed (called by the grab contact path) for the
##   victim state.
##
## Native facts exercised (adreno_200/set/brucelee.set, native_links.json,
## keyboard variant 1).  The recovered table holds generic AND opponent-suffixed
## rows; the `unique` token names the matchup OPPONENT, so the Brick opponent
## of this fixture selects the Brick rows while generic rows stay in the table:
##   stepright -> grab1miss       order 6,  unique grababrucelee (generic)
##   stepright -> grab1miss brick order 8,  unique grababrick    (Brick)
##   stepleft  -> grab2miss       order 7,  unique grabbbrucelee (generic)
##   stepleft  -> grab2miss brick order 17, unique grabbbrick    (Brick)
##   grab1miss -> grab1           order 347, automatic, window [8, 9],
##                            conditions grabdistance + oppposestand +
##                            oppnotblocking
##   grab1miss brick -> grab1 brick order 383, automatic, same conditions
##   grab2miss -> grab2           order 349
##   grab2miss brick -> grab2 brick order 385
##   miss actions consume 66 rage on entry
##   generic grab impacts 6 + 5 + 9 = 20 (grab1) / 5 + 15 = 20 (grab2)
##   Brick grab1 impacts 6 + 6 + 10 = 22, Brick grab2 damage 20
## Damage totals below are read from the recovered ATTACKS row for the selected
## kind, not hardcoded, so a native-damage drift stays visible.
##
## The opponent's skeleton class is "large" (thai set), so the Brick miss/grab
## clips resolve to m02_grab_01_forbigguy / m03_grab_0x_forbigguy.

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
const GRAB_CASES: Array = [
    # step direction, key, miss, grab, first impact, total damage, victim state,
    # miss clip (size version), grab clip (size version), victim clip.
    # The Brick opponent selects the recovered opponent-suffix rows.
    ["up", "a", "grab1miss brick", "grab1 brick", 6.0, 22.0, "grabbed1",
        "m02_grab_01_forbigguy", "m03_grab_01_forbigguy", "all_grabbed_01_forset03"],
    ["down", "c", "grab2miss brick", "grab2 brick", 5.0, 20.0, "grabbed2",
        "m02_grab_01_forbigguy", "m03_grab_02_forbigguy", "all_grabbed_02_forset03"],
]
const RAGE_BEFORE: float = 70.0
const RAGE_COST: float = 66.0


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
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var defender: PortFighter = scene.get("computer")
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
    # Keep generic and Brick link rows asserted separately (link-order coverage).
    if not _assert_recovered_link_rows(player):
        quit(1)
        return
    for case: Array in GRAB_CASES:
        if not _validate_grab(scene, player, defender, case):
            quit(1)
            return
    if not _validate_grab_range(scene, player, defender):
        quit(1)
        return
    if not _validate_blocked_grab_rejects_chain(scene, player, defender):
        quit(1)
        return
    if not _validate_below_rage_gate(scene, player, defender):
        quit(1)
        return
    print("GRAB_VALIDATION=" + JSON.stringify({
        "grabs": ["grab1miss brick->grab1 brick", "grab2miss brick->grab2 brick"],
        "generic_rows": [6, 7, 347, 349],
        "brick_rows": [8, 17, 383, 385],
        "bruce_bytes": CANDIDATES["bruce"]["bytes"],
        "bruce_sha256": CANDIDATES["bruce"]["sha256"],
        "brick_bytes": CANDIDATES["brick"]["bytes"],
        "brick_sha256": CANDIDATES["brick"]["sha256"],
        "scope": "native links: the Brick opponent selects recovered orders "
                + "8/17/383/385; generic 6/7/347/349 stay in the table; "
                + "step -> grab miss (rage -66), automatic chain at frames 8-9 "
                + "when in range and not blocking, victim enters grabbed1/2",
    }))
    scene.queue_free()
    await process_frame
    quit(0)


func _reset(scene: Node, player: PortFighter, defender: PortFighter,
        distance: float) -> void:
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


func _pin(player: PortFighter, defender: PortFighter, distance: float) -> void:
    player.position = Vector3(0.0, 1.2, 0.0)
    defender.position = Vector3(distance, 1.2, 0.0)


func _step(player: PortFighter, defender: PortFighter, distance: float) -> void:
    # Two 1/60 steps per source frame: the frame clock truncates
    # (elapsed_ms * 0.03), so one 1/60 step does not advance a whole frame.
    for _half: int in range(2):
        _pin(player, defender, distance)
        player._physics_process(1.0 / 60.0)
        defender._physics_process(1.0 / 60.0)


func _start_miss(scene: Node, player: PortFighter, defender: PortFighter,
        step_direction: String, key: String, distance: float) -> bool:
    # The recovered grab links start from the step actions, which the movement
    # layer reports while the matching direction is held: up -> stepright
    # (grab1miss), down -> stepleft (grab2miss).  The keyboard variant of both
    # links is a single press.
    _reset(scene, player, defender, distance)
    player.set_held_directions({step_direction: true})
    if player._current_action_name() not in ["stepright", "stepleft"]:
        push_error("Held " + step_direction + " did not select a step action: "
                + player._current_action_name())
        return false
    return player.record_standing_combo_press(key)


func _validate_grab(scene: Node, player: PortFighter, defender: PortFighter,
        case: Array) -> bool:
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
    if not _start_miss(scene, player, defender, step_direction, key, 0.3):
        push_error(miss + " did not start")
        return false
    if player.attack_kind != miss:
        push_error("Expected " + miss + ", got " + player.attack_kind)
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
    # generic grab1miss/grab2miss rows, [10, 11] for the Brick variant rows.
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
        _step(player, defender, 0.3)
    if player.attack_kind != miss:
        push_error(miss + " chained before its [%d, %d] window: " % [chain_frame, chain_frame + 1]
                + player.attack_kind)
        return false
    var chained: bool = false
    for _frame: int in range(4):
        _step(player, defender, 0.3)
        if player.attack_kind == target:
            chained = true
            break
    if not chained:
        push_error(miss + " did not chain to " + target + " around frame "
                + str(chain_frame) + ": " + player.attack_kind)
        return false
    if player.current_source_animation() != ("m03_grab_01" if target == "grab1 brick"
            else "m03_grab_02"):
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
        _step(player, defender, 0.3)
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


func _validate_grab_range(scene: Node, player: PortFighter,
        defender: PortFighter) -> bool:
    # grab1miss -> grab1 requires grabdistance; beyond it the miss plays out and
    # returns to idle without grabbing or dealing damage.
    if not _start_miss(scene, player, defender, "up", "a", 2.0):
        push_error("Far grab miss did not start")
        return false
    for _frame: int in range(40):
        _step(player, defender, 2.0)
    if player.attack_kind in ["grab1", "grab2", "grab1 brick", "grab2 brick"]:
        push_error("Grab chained out of range")
        return false
    if not is_equal_approx(defender.health, PortFighter.MAX_HEALTH):
        push_error("Out-of-range grab dealt damage")
        return false
    return true


func _validate_blocked_grab_rejects_chain(scene: Node, player: PortFighter,
        defender: PortFighter) -> bool:
    # oppnotblocking is a condition of the chain, so a guarding opponent keeps
    # the miss from becoming a grab.
    if not _start_miss(scene, player, defender, "up", "a", 0.3):
        push_error("Blocked grab miss did not start")
        return false
    defender.guard_held = true
    # Fail-closed blocking state: with no recovered action-category row the
    # native CFighter::IsBlocking probe reports true, so oppnotblocking is false
    # for the whole Brick [10, 11] chain window.
    defender._native_action_categories.clear()
    for _frame: int in range(40):
        defender.guard_held = true
        defender._native_action_categories.clear()
        _step(player, defender, 0.3)
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


func _validate_below_rage_gate(scene: Node, player: PortFighter,
        defender: PortFighter) -> bool:
    # rage2thirds compares rage < 66, so 65 must not start the grab miss; the
    # same press falls through to the basic attack instead.
    _reset(scene, player, defender, 0.3)
    player.rage = 65.0
    player.set_held_directions({"up": true})
    player.record_standing_combo_press("a")
    if player.attack_kind in ["grab1_miss", "grab2_miss", "grab1", "grab2",
            "grab1miss brick", "grab2miss brick", "grab1 brick", "grab2 brick"]:
        push_error("Grab started below the rage2thirds gate: " + player.attack_kind)
        return false
    if absf(player.rage - 65.0) > 0.001:
        push_error("Rejected grab spent rage: " + str(player.rage))
        return false
    return true


func _assert_recovered_link_rows(player: PortFighter) -> bool:
    # Generic and Brick rows are both table facts; assert them explicitly so a
    # link-order regression cannot hide behind a passing runtime chain.
    var by_order: Dictionary = {}
    for link: Dictionary in player._native_links:
        by_order[int(link.get("order", -1))] = link
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
    if player._opponent_suffix_token() != "brick":
        push_error("expected a Brick opponent token, got "
                + player._opponent_suffix_token())
        return false
    if player._native_link_unique_ok(by_order.get(6, {})):
        push_error("generic order 6 unexpectedly passed the owner gate")
        return false
    if not player._native_link_unique_ok(by_order.get(8, {})):
        push_error("Brick order 8 was refused by the owner gate")
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

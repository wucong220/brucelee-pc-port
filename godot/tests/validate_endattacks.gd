extends SceneTree
## Validate the grab-based endattack finishers on the Bruce candidate through
## the recovered native link path, under native per-fighter active uniques.
##
## The prototype drained a pending combo queue with
## _try_begin_pending_special_combo.  That function is gone; the decompiled
## model re-evaluates the native link table every physics update, and the
## finisher consumes the victim through begin_endattack_victim, so this test
## drives the same recovered behaviour through the public API only:
##   request_attack for the base attack, record_standing_combo_press for the
##   link input, _physics_process for the frame clock, and the victim states
##   endattackcomp1/endattackcomp2 that begin_endattack_victim enters.
##
## Native facts exercised (adreno_200/set/brucelee.set, native_links.json,
## keyboard variant 1).  CFighter::IsLinkAllowed compares the row's `unique`
## tags with the fighter's active list, so the opponent does not select rows:
##   DEFAULT (8 characters.list uniques):
##     stepright -> grab1miss order 6 -> grab1 order 347 -> grabbed1
##     candobasicattacks -> endattack1 order 34, empty unique, [pressa]
##     candobasicattacks -> endattack2 order 35, unique endbrucelee, [pressc]
##     orders 36..44 (endattack <other>) are refused: their tags are absent.
##   EXPLICIT {grabs/graba=grababrick, endmove=endsmallboy}:
##     stepright -> grab1miss brick order 8 -> grab1 brick order 383
##     endattack1 (order 34) is deferred while the selected specific row
##     endattack smallboy (order 44, unique endsmallboy) applies; endbrucelee
##     was replaced, so the c-key endattack2 row is refused.
## All finisher links use keystatus right pressed and conditions oppposestun +
## grabdistance.  The finisher's own source damage is 0; it converts the victim
## into endattackcomp1/2 (all_end_attack_01/02_forset03, 93/130 frames) and then
## faceupko.
##
## The opponent's skeleton class is "large" (thai set), so the recovered size
## versions are played: m01_grab_01_forbigguy, m01_end_attack_01_forbigguy,
## m01_end_attack_02_forbigguy, and the Brick rows m03_grab_01_forbigguy /
## m03_end_attack_01_forbigguy.

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
const GRAB_DISTANCE: float = 0.3
const RAGE_BEFORE: float = 70.0
const BRICK_STYLE: Dictionary = {
    "grabs/graba": "grababrick",
    "endmove/endmove": "endsmallboy",
}

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
        push_error("Endattack candidate failed: " + player.candidate_load_error)
        quit(1)
        return
    if not defender.candidate_loaded:
        push_error("Endattack victim candidate failed: " + defender.candidate_load_error)
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    for required: String in ["grab1", "endattack1", "endattack2"]:
        if not clips.has(required):
            push_error("Candidate is missing " + required)
            quit(1)
            return
    if not _assert_recovered_link_rows():
        quit(1)
        return

    # ------------------------------------------------ default native profile
    # grab1 -> endattack1 (order 34, empty unique) by the documented A key.
    if not _validate_endattack_from_grab("up", "a", "grab1miss", "grab1",
            "a", "endattack1", "m01_end_attack_01",
            "m01_end_attack_01_forbigguy", "grabbed1", "endattackcomp1",
            "all_end_attack_01_forset03", 93):
        quit(1)
        return
    # grab2 -> endattack2 (order 35, unique endbrucelee) by the C key.
    if not _validate_endattack_from_grab("down", "c", "grab2miss", "grab2",
            "c", "endattack2", "m01_end_attack_02",
            "m01_end_attack_02_forbigguy", "grabbed2", "endattackcomp2",
            "all_end_attack_02_forset03", 130):
        quit(1)
        return
    if not _validate_grab_flag_reset():
        quit(1)
        return
    if not _validate_normal_hit_no_variant():
        quit(1)
        return

    # -------------------------------------- explicit Brick / big finisher style
    if not _set_style(BRICK_STYLE):
        quit(1)
        return
    if not _assert_brick_link_rows():
        quit(1)
        return
    if not _validate_endattack_from_grab("up", "a", "grab1miss brick",
            "grab1 brick", "a", "endattack smallboy", "m03_end_attack_01",
            "m03_end_attack_01_forbigguy", "grabbed1", "endattackcomp1",
            "all_end_attack_01_forset03", 93):
        quit(1)
        return
    if not _validate_selected_c_finisher_refused():
        quit(1)
        return

    # The blocked-grab case clears the defender's category table; run it last.
    if not _validate_blocked_grab_rejects_endattack():
        quit(1)
        return

    print("ENDATTACK_VALIDATION=" + JSON.stringify({
        "default_finishers": ["endattack1", "endattack2"],
        "brick_style_finisher": "endattack smallboy",
        "source_damage": 0.0,
        "victims": {
            "endattackcomp1": ["all_end_attack_01_forset03", 93],
            "endattackcomp2": ["all_end_attack_02_forset03", 130],
        },
        "default_rows": [6, 34, 35, 347],
        "brick_rows": [8, 44, 383],
        "bruce_bytes": CANDIDATES["bruce"]["bytes"],
        "bruce_sha256": CANDIDATES["bruce"]["sha256"],
        "brick_bytes": CANDIDATES["brick"]["bytes"],
        "brick_sha256": CANDIDATES["brick"]["sha256"],
        "scope": "native active uniques: default Bruce uses orders 6/347/34 and "
                + "35; the Brick opponent adds nothing. An explicit "
                + "graba=grababrick + endmove=endsmallboy selection makes 8/383/44 "
                + "apply and removes endbrucelee, so the c-key finisher is refused.",
    }))
    scene.queue_free()
    await process_frame
    quit(0)


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


func _reset() -> void:
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
    defender.position = Vector3(GRAB_DISTANCE, 1.2, 0.0)
    player.opponent = defender
    player.facing = 1.0
    player.set_key_status({})
    player.set_held_directions({})


func _pin() -> void:
    player.position = Vector3(0.0, 1.2, 0.0)
    defender.position = Vector3(GRAB_DISTANCE, 1.2, 0.0)


func _step(advance_defender: bool) -> void:
    # Two 1/60 steps per source frame: the frame clock truncates
    # (elapsed_ms * 0.03), so one 1/60 step does not advance a whole frame.
    for _half: int in range(2):
        _pin()
        player._physics_process(1.0 / 60.0)
        if advance_defender:
            defender._physics_process(1.0 / 60.0)


func _start_grab(step_direction: String, key: String, miss: String,
        target: String, victim_state: String) -> bool:
    _reset()
    player.set_held_directions({step_direction: true})
    if not player.record_standing_combo_press(key):
        push_error(miss + " did not start")
        return false
    var miss_kind: String = player.kind_for_action(miss)
    if miss_kind.is_empty():
        miss_kind = miss
    if player.attack_kind != miss_kind:
        push_error("Expected " + miss_kind + ", got " + player.attack_kind)
        return false
    for _frame: int in range(200):
        _step(true)
        if defender.state == victim_state and player.attack_kind == target:
            return true
    push_error(miss + " never grabbed: player=" + player.attack_kind
            + " victim=" + defender.state)
    return false


func _validate_endattack_from_grab(step_direction: String, grab_key: String,
        miss: String, grab: String, finisher_key: String, finisher: String,
        source_animation: String, size_clip: String, victim_state: String,
        victim_finisher_state: String, victim_clip: String,
        victim_frames: int) -> bool:
    if not _start_grab(step_direction, grab_key, miss, grab, victim_state):
        return false
    if not bool(player.get("_grab_connected")):
        push_error(grab + " did not set the grab-connected flag")
        return false
    var health_before: float = defender.health
    # The finisher link needs the toward key held (keystatus right pressed) and
    # the documented attack key.  It must fire while the victim is still held,
    # before the grab animation finishes.
    player.set_held_directions({"right": true})
    player.set_key_status({"right": true, finisher_key: true})
    if not player.record_standing_combo_press(finisher_key):
        push_error(finisher + " did not start from the grab")
        return false
    if player.attack_kind != finisher:
        push_error("Expected " + finisher + ", got " + player.attack_kind)
        return false
    if player.current_source_animation() != source_animation:
        push_error(finisher + " requested " + player.current_source_animation())
        return false
    player._animate_candidate()
    if player.candidate_animation_clip != size_clip:
        push_error(finisher + " did not play the large-opponent size version: "
                + player.candidate_animation_clip)
        return false
    var saw_comp: bool = false
    for _frame: int in range(400):
        _step(true)
        if defender.state == victim_finisher_state and not saw_comp:
            saw_comp = true
            defender._animate_candidate()
            if defender.candidate_animation_clip != victim_clip:
                push_error(finisher + " victim clip was "
                        + defender.candidate_animation_clip)
                return false
            # begin_endattack_victim holds the victim for the recovered frame
            # count of the opponent set's clip (thai forset03: 93 / 130).
            var expected_time: float = float(victim_frames) / PortFighter.SOURCE_FRAME_RATE
            if defender.state_time > expected_time + 0.0001 \
                    or defender.state_time < expected_time - (2.0 / 60.0) - 0.0001:
                push_error(finisher + " victim timing was " + str(defender.state_time)
                        + ", expected " + str(expected_time))
                return false
        if saw_comp and defender.state == "faceupko":
            break
    if not saw_comp:
        push_error(finisher + " never consumed the victim: " + defender.state)
        return false
    if defender.state != "faceupko":
        push_error(finisher + " victim did not finish into faceupko: " + defender.state)
        return false
    if absf(defender.health - health_before) > 0.001:
        push_error(finisher + " invented damage: " + str(defender.health))
        return false
    return true


func _validate_grab_flag_reset() -> bool:
    # A successful grab records the grab-connected flag.  The flag is not an
    # endattack property: starting any chained attack begins a new action and
    # clears it, so the old "still set after the finisher" check moved to the
    # moment the grab lands, and reset_fighter must still clear it.
    if not _start_grab("up", "a", "grab1miss", "grab1", "grabbed1"):
        return false
    if not bool(player.get("_grab_connected")):
        push_error("Successful grab did not set the grab-connected flag")
        return false
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    if bool(player.get("_grab_connected")):
        push_error("reset_fighter did not clear the grab-connected flag")
        return false
    return true


func _validate_blocked_grab_rejects_endattack() -> bool:
    # Back to the default native style: this is the last case and it clears the
    # defender's action-category table.
    if not _set_style({}):
        return false
    # A guarded opponent fails oppnotblocking, so the miss never chains into a
    # grab, the grab-connected flag stays clear, and the finisher link (which
    # needs oppposestun) cannot start.
    _reset()
    player.set_held_directions({"up": true})
    defender.guard_held = true
    defender._native_action_categories.clear()
    if not player.record_standing_combo_press("a"):
        push_error("Blocked-grab setup did not start grab1miss")
        return false
    if player.attack_kind != "grab1_miss":
        push_error("Blocked-grab setup expected grab1_miss, got " + player.attack_kind)
        return false
    # Fail-closed blocking state: with no recovered action-category row the
    # native CFighter::IsBlocking probe reports true, so oppnotblocking is false
    # for the whole [8, 9] chain window.
    defender._native_action_categories.clear()
    for _frame: int in range(40):
        defender.guard_held = true
        defender._native_action_categories.clear()
        _step(true)
    if player.attack_kind == "grab1":
        push_error("Grab chained into a blocking opponent")
        return false
    if bool(player.get("_grab_connected")):
        push_error("A blocked grab set the grab-connected flag")
        return false
    player.set_held_directions({"right": true})
    player.set_key_status({"right": true, "a": true})
    player.record_standing_combo_press("a")
    if (player.attack_kind in ["endattack1", "endattack2"]
            or String(player.attack_kind).begins_with("endattack ")):
        push_error("Endattack started after a blocked grab")
        return false
    return true


func _validate_normal_hit_no_variant() -> bool:
    # A normal landed hit can open the generic finisher window (oppposestun +
    # grabdistance), but it must never select an opponent-suffix endattack row:
    # the default active list has none of those tags.  Assert the gate is closed
    # for both a Brick and a smallboy row while the attacker lands highpunch3.
    _reset()
    var brick_link: Dictionary = _finisher_link("endattack brick")
    var smallboy_link: Dictionary = _finisher_link("endattack smallboy")
    if brick_link.is_empty() or smallboy_link.is_empty():
        push_error("Native table lost a recovered endattack variant row")
        return false
    if player._native_link_unique_ok(brick_link) \
            or player._native_link_unique_ok(smallboy_link):
        push_error("default gate accepted an opponent-suffix endattack row")
        return false
    if not player.request_attack("high_punch3"):
        push_error("Normal base hit did not start")
        return false
    var landed: bool = false
    for _frame: int in range(160):
        _step(true)
        if player.attack_kind.begins_with("endattack "):
            push_error("opponent-suffix finisher fired without a selection: "
                    + player.attack_kind)
            return false
        if bool(player.get("_attack_hit_landed")):
            landed = true
            player.set_held_directions({"right": true})
            player.set_key_status({"right": true, "a": true})
            player.record_standing_combo_press("a")
    if not landed:
        push_error("Normal base hit never landed")
        return false
    if player.attack_kind.begins_with("endattack "):
        push_error("opponent-suffix finisher fired after a normal hit: "
                + player.attack_kind)
        return false
    return true


func _finisher_link(finisher: String) -> Dictionary:
    for link: Dictionary in player._native_links:
        if (String(link.get("to", "")) == finisher
                and String(link.get("from_group", "")) == "candobasicattacks"):
            return link
    return {}


func _validate_selected_c_finisher_refused() -> bool:
    # The endmove group now selects endsmallboy, so endbrucelee left the active
    # list and order 35 (endattack2) is refused.  No other c-key endattack row
    # exists for this selection, so the press must not consume the victim.
    if not _start_grab("down", "c", "grab2miss", "grab2", "grabbed2"):
        return false
    var before: String = player.attack_kind
    player.set_held_directions({"right": true})
    player.set_key_status({"right": true, "c": true})
    player.record_standing_combo_press("c")
    if (player.attack_kind in ["endattack1", "endattack2"]
            or String(player.attack_kind).begins_with("endattack ")):
        push_error("removed endbrucelee still started " + player.attack_kind)
        return false
    if player.attack_kind != before:
        push_error("refused c finisher changed the grab: " + before + " -> "
                + player.attack_kind)
        return false
    for _frame: int in range(120):
        _step(true)
        if defender.state.begins_with("endattackcomp"):
            push_error("refused c finisher consumed the victim: " + defender.state)
            return false
    return true


func _by_order() -> Dictionary:
    var by_order: Dictionary = {}
    for link: Dictionary in player._native_links:
        by_order[int(link.get("order", -1))] = link
    return by_order


func _assert_recovered_link_rows() -> bool:
    # Both the generic rows and the Brick-specific rows are native table facts.
    var by_order: Dictionary = _by_order()
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
            push_error("recovered link order " + str(order) + " drifted: " + str(link))
            return false
    var default_expected: Array = PortFighter.DEFAULT_BRUCE_UNIQUES.duplicate()
    default_expected.sort()
    if player.active_uniques() != default_expected:
        push_error("default active uniques are wrong: " + str(player.active_uniques()))
        return false
    if not player._native_link_unique_ok(by_order[34]):
        push_error("empty-unique order 34 was refused")
        return false
    if not player._native_link_unique_ok(by_order[35]):
        push_error("default endbrucelee order 35 was refused")
        return false
    for order: int in [36, 44]:
        if player._native_link_unique_ok(by_order[order]):
            push_error("default gate accepted order " + str(order))
            return false
    return true


func _assert_brick_link_rows() -> bool:
    var by_order: Dictionary = _by_order()
    if not player._native_link_unique_ok(by_order[44]):
        push_error("explicit endsmallboy refused order 44")
        return false
    if player._native_link_unique_ok(by_order[35]):
        push_error("explicit endsmallboy kept the replaced endbrucelee row")
        return false
    if player._native_link_unique_ok(by_order[36]):
        push_error("explicit endsmallboy accepted the unselectable endbrickdavis row")
        return false
    if not player._native_link_unique_ok(by_order[34]):
        push_error("empty-unique order 34 was refused by the selected style")
        return false
    return true


func _validate_candidate_identity(path: String, role: String) -> bool:
    var expected: Dictionary = CANDIDATES[role]
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error(role + " endattack candidate could not be opened")
        return false
    var bytes: PackedByteArray = file.get_buffer(file.get_length())
    file.close()
    if bytes.size() != int(expected["bytes"]):
        push_error(role + " endattack candidate size mismatch: " + str(bytes.size()))
        return false
    var hash: HashingContext = HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    hash.update(bytes)
    if hash.finish().hex_encode().to_lower() != String(expected["sha256"]):
        push_error(role + " endattack candidate SHA-256 mismatch")
        return false
    var json_length: int = bytes.decode_u32(12)
    var document: Variant = JSON.parse_string(
        bytes.slice(20, 20 + json_length).get_string_from_utf8())
    if (not document is Dictionary or not document.has("animations")
            or document["animations"].size() != int(expected["animations"])):
        push_error(role + " endattack candidate animation count mismatch")
        return false
    return true

extends SceneTree
const PC = preload("res://scripts/prototype_controls.gd")
## Real-input variant: drive the exact main.gd -> fighter input path with
## InputEventKey presses and Input action state, not direct fighter method calls.
##
## Recovered native real-key/link path (adreno_200/set/brucelee.set, keyboard
## sequence variant index 1 = fighter+0x1c = 1).  CFighter::IsLinkAllowed is an
## exact membership test against the fighter's own active unique list, so the
## Brick opponent does not select its rows:
##   DEFAULT (8 characters.list uniques of Bruce Lee):
##     stepright -> grab1miss   link order 6,   unique grababrucelee
##     grab1miss -> grab1       link order 347, automatic, window [8, 9]
##     stepleft  -> grab2miss   link order 7,   unique grabbbrucelee
##     grab2miss -> grab2       link order 349, automatic, window [8, 9]
##     candobasicattacks -> endattack1 order 34 (A), endattack2 order 35 (C)
##   EXPLICIT {grabs/graba=grababrick, endmove=endsmallboy}:
##     stepright -> grab1miss brick order 8 -> grab1 brick order 383
##     candobasicattacks -> endattack smallboy order 44 (A); order 35 is refused
##     because endbrucelee left the active list.
## grab1miss/grab2miss carry action.rage = -66, spent when the miss begins, so
## the holding step is not a one-frame shortcut to grab1/grab2: the miss plays
## through the recovered window and only then does the automatic chain hand over
## to the grab, which then connects the victim into grabbed1/grabbed2.
##
## This test pins that native two-step path and then drives the recovered
## candobasicattacks finisher links through the same real input path.
## Everything is fail-closed: any missing intermediate state aborts with exit 1.

const BRICK_STYLE: Dictionary = {
    "grabs/graba": "grababrick",
    "endmove/endmove": "endsmallboy",
}

var match_scene: Node = null
var player: PortFighter = null
var victim: PortFighter = null


func _initialize() -> void:
    call_deferred("_run")


func _key(code: Key) -> InputEventKey:
    var event := InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    event.pressed = true
    return event


func _fail(message: String) -> void:
    push_error("FAIL: " + message)
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


func _assert_recovered_link_rows() -> void:
    var by_order: Dictionary = {}
    for link: Dictionary in player._native_links:
        by_order[int(link.get("order", -1))] = link
    var expected: Dictionary = {
        6: ["stepright", "grab1miss", "grababrucelee"],
        7: ["stepleft", "grab2miss", "grabbbrucelee"],
        8: ["stepright", "grab1miss brick", "grababrick"],
        34: ["", "endattack1", ""],
        35: ["", "endattack2", "endbrucelee"],
        36: ["", "endattack brick", "endbrickdavis"],
        347: ["grab1miss", "grab1", "grababrucelee"],
        349: ["grab2miss", "grab2", "grabbbrucelee"],
        383: ["grab1miss brick", "grab1 brick", "grababrick"],
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
            _fail("recovered link order " + str(order) + " drifted: " + str(link))
            return
    var default_expected: Array = PortFighter.DEFAULT_BRUCE_UNIQUES.duplicate()
    default_expected.sort()
    if player.active_uniques() != default_expected:
        _fail("default active uniques are wrong: " + str(player.active_uniques()))
        return
    if player._native_link_unique_ok(by_order[8]):
        _fail("default gate accepted the Brick order 8 row")
        return
    if not player._native_link_unique_ok(by_order[6]):
        _fail("default gate refused the Bruce order 6 row")
        return


func _sync_main_input_state() -> void:
    # Mirror main.gd::_process/_physics_process: held directions and the key
    # status both come from the same PC bindings that produce the press events.
    player.set_held_directions(match_scene._held_direction_flags())
    match_scene._update_player_key_status()


func _pin(distance: float) -> void:
    player.position = Vector3(0.0, 1.2, 0.0)
    victim.position = Vector3(distance, 1.2, 0.0)
    player.facing = 1.0


func _step_frames(distance: float, max_steps: int, until: Callable) -> bool:
    # One 1/60 physics step advances the native frame clock ~0.5 source frames
    # (frame = truncate(elapsed_ms * 0.03)); the automatic grab window is
    # reached by ~step 16-22 and the grab contact by ~step 106.
    for step: int in range(max_steps):
        _pin(distance)
        player._physics_process(1.0 / 60.0)
        victim._physics_process(1.0 / 60.0)
        if bool(until.call()):
            return true
    return false


func _reset_round() -> void:
    match_scene._reset_match()
    player = match_scene.get("player")
    victim = match_scene.get("computer")
    player.set_physics_process(false)
    victim.set_physics_process(false)
    player.rage = 100.0
    _pin(0.35)


func _run_grab(distance: float, step_action: String, step_key: Key,
        attack_key: Key, miss: String, grab: String, victim_state: String,
        finisher: String, finisher_victim: String, finisher_key: Key) -> bool:
    # 1) Real key press for the holding step. The direction comes from
    #    main.gd._held_direction_flags() (up -> stepright, down -> stepleft).
    Input.action_press(step_action)
    _sync_main_input_state()
    match_scene._unhandled_input(_key(step_key))
    _sync_main_input_state()
    _pin(distance)
    if player._current_action_name() != (
            "stepright" if step_action == PC.MOVE_UP else "stepleft"):
        _fail("held step did not select the native step action: "
                + player._current_action_name())
        return false

    # 2) The documented attack key press must start the recovered step -> miss
    #    link.  The miss kind is the mapped ATTACKS entry ("grab1_miss") for the
    #    default rows and the variant name for the explicit Brick row.
    match_scene._unhandled_input(_key(attack_key))
    if player.attack_kind != miss:
        _fail("real input " + str(step_action) + "+attack did not start "
                + miss + " (native step link): " + player.attack_kind)
        return false
    print("PASS real input started " + miss)

    # 3) The miss must play through its recovered window and chain automatically
    #    into the grab, which then holds the victim. The miss spends its 66 rage
    #    on entry, so a one-step shortcut cannot pass this.
    var chained := _step_frames(distance, 200, func() -> bool:
        return player.attack_kind == grab)
    if not chained:
        _fail(miss + " did not chain to " + grab + ": " + player.attack_kind)
        return false
    var held := _step_frames(distance, 200, func() -> bool:
        return victim.state in ["grabbed1", "grabbed2"])
    if not held:
        _fail(grab + " did not hold the victim: " + victim.state)
        return false
    if victim.state != victim_state:
        _fail(grab + " held the victim in " + victim.state + ", expected "
                + victim_state)
        return false
    print("PASS real input " + grab + " -> " + victim.state)

    # 4) Release the step and hold the toward key (D), then press the
    #    recovered documented finisher key.  All endattack links need
    #    keystatus right pressed, so the real input status update must expose
    #    it.  An empty `finisher` means the selected style has no row for this
    #    key: the press must fail closed instead.
    Input.action_release(step_action)
    Input.action_press(PC.MOVE_RIGHT)
    _sync_main_input_state()
    match_scene._unhandled_input(_key(KEY_D))
    _sync_main_input_state()
    match_scene._unhandled_input(_key(finisher_key))
    if finisher.is_empty():
        if _endattack_kind(player.attack_kind):
            _fail("removed finisher row fired: " + player.attack_kind)
            return false
        var refused := _step_frames(distance, 160, func() -> bool:
            return victim.state.begins_with("endattackcomp"))
        if refused:
            _fail("refused finisher still consumed the victim: " + victim.state)
            return false
        print("PASS real input refused finisher: attack="
                + player.attack_kind + " victim=" + victim.state)
        return true
    if player.attack_kind != finisher:
        _fail("real input finisher did not start " + finisher + ": "
                + player.attack_kind)
        return false
    var consumed := _step_frames(distance, 160, func() -> bool:
        return victim.state == finisher_victim)
    if not consumed:
        _fail(finisher + " did not consume the victim: " + victim.state)
        return false
    print("PASS real input " + finisher + " -> " + victim.state)
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
    _pin(0.35)

    _assert_recovered_link_rows()

    # Default native: hold W (stepright) + J -> grab1miss -> grab1 -> grabbed1;
    # the A finisher is order 34 (endattack1, empty unique).
    if not _run_grab(0.35, PC.MOVE_UP, KEY_W, KEY_J, "grab1_miss",
            "grab1", "grabbed1", "endattack1", "endattackcomp1", KEY_J):
        return

    # Symmetric second real-key path: hold S + L -> grab2miss -> grab2 ->
    # grabbed2; the C finisher is order 35 (endattack2, unique endbrucelee).
    release_all()
    _reset_round()
    if not _run_grab(0.35, PC.MOVE_DOWN, KEY_S, KEY_L, "grab2_miss",
            "grab2", "grabbed2", "endattack2", "endattackcomp2", KEY_L):
        return

    # Explicit Brick / big finisher style through the same real input path.
    release_all()
    _reset_round()
    if not _set_style(BRICK_STYLE):
        return
    if not _run_grab(0.35, PC.MOVE_UP, KEY_W, KEY_J, "grab1miss brick",
            "grab1 brick", "grabbed1", "endattack smallboy",
            "endattackcomp1", KEY_J):
        return
    # endbrucelee left the active list with the explicit endmove selection, so
    # the C press must fail closed (grab2 itself is still the Bruce row, as the
    # style catalog has no Brick grabs/grabb entry).
    release_all()
    _reset_round()
    if not _run_grab(0.35, PC.MOVE_DOWN, KEY_S, KEY_L, "grab2_miss",
            "grab2", "grabbed2", "", "", KEY_L):
        return

    print("REAL_INPUT_GRAB_VALIDATION=" + JSON.stringify({
        "default": {
            "grab1": "stepright+a -> grab1miss -> grab1 -> endattack1",
            "grab2": "stepleft+c -> grab2miss -> grab2 -> endattack2",
        },
        "brick_style": {
            "grab1": "stepright+a -> grab1miss brick -> grab1 brick -> endattack smallboy",
            "grab2": "stepleft+c -> grab2miss -> grab2 -> c refused",
        },
        "default_rows": [6, 7, 34, 35, 347, 349],
        "brick_rows": [8, 36, 44, 383],
        "keyboard_variant": 1,
        "source": "brucelee.set links order 6/7/8 (miss entry) + 347/349/383 (auto window) + 34/35/44 (finisher)",
    }))
    quit(0)


func release_all() -> void:
    Input.action_release(PC.MOVE_LEFT)
    Input.action_release(PC.MOVE_RIGHT)
    Input.action_release(PC.MOVE_UP)
    Input.action_release(PC.MOVE_DOWN)

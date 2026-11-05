extends SceneTree
const PC = preload("res://scripts/prototype_controls.gd")
## Real-input variant: drive the exact main.gd -> fighter input path with
## InputEventKey presses and Input action state, not direct fighter method calls.
##
## Recovered native real-key/link path (adreno_200/set/brucelee.set, keyboard
## sequence variant index 1 = fighter+0x1c = 1):
##   stepright -> grab1miss   link order 6,   sequence [pressa], rage2thirds,
##                            unique grababrucelee, input_reset true
##   grab1miss -> grab1       link order 347, automatic, window [8, 9],
##                            conditions grabdistance + oppposestand +
##                            oppnotblocking
##   stepleft  -> grab2miss   link order 7,   sequence [pressc], rage2thirds,
##                            unique grabbbrucelee, input_reset true
##   grab2miss -> grab2       link order 349, automatic, window [8, 9], same
##                            conditions
## grab1miss/grab2miss carry action.rage = -66, spent when the miss begins, so
## the holding step is not a one-frame shortcut to grab1/grab2: the miss plays
## through the recovered [8, 9] window and only then does the automatic chain
## hand over to the grab, which then connects the victim into grabbed1/grabbed2.
##
## The real input path starts a grab MISS, not the grab itself, on the
## documented "hold step toward + attack key" gesture.  This test pins that
## native two-step path and then drives the recovered candobasicattacks
## finisher links through the same real input path.  Everything is fail-closed:
## any missing intermediate state aborts with exit 1.
##
## brucelee.set holds generic AND opponent-suffixed rows; the `unique` token
## names the matchup OPPONENT.  Against the Brick opponent of this fixture the
## native chain is stepright -> grab1miss brick (order 8) -> grab1 brick
## (order 383) -> endattack brick (order 36, unique endbrickdavis).  The
## generic rows (6/347/34) stay in the table, order 34 is deferred while the
## specific variant applies, and order 35 (endattack2, unique endbrucelee) is
## the mirror-only c-key link.  brucelee.set contains no "endattack2 brick",
## so the second real-key path must fail closed at the finisher press.

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


func _assert_recovered_link_rows() -> void:
    # Generic and Brick rows are both native table facts.
    var by_order: Dictionary = {}
    for link: Dictionary in player._native_links:
        by_order[int(link.get("order", -1))] = link
    var expected: Dictionary = {
        6: ["stepright", "grab1miss", "grababrucelee"],
        8: ["stepright", "grab1miss brick", "grababrick"],
        17: ["stepleft", "grab2miss brick", "grabbbrick"],
        34: ["", "endattack1", ""],
        35: ["", "endattack2", "endbrucelee"],
        36: ["", "endattack brick", "endbrickdavis"],
        347: ["grab1miss", "grab1", "grababrucelee"],
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
            _fail("recovered link order " + str(order) + " drifted: " + str(link))
            return
    if player._opponent_suffix_token() != "brick":
        _fail("expected a Brick opponent token, got " + player._opponent_suffix_token())
        return
    if player._native_link_unique_ok(by_order.get(35, {})):
        _fail("mirror-only order 35 unexpectedly passed the owner gate")
        return
    if not player._native_link_unique_ok(by_order.get(36, {})):
        _fail("Brick order 36 was refused by the owner gate")
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


func _step_frames(distance: float, max_steps: int,
        until: Callable) -> bool:
    # One 1/60 physics step advances the native frame clock ~0.5 source frames
    # (frame = truncate(elapsed_ms * 0.03)); the [8, 9] automatic grab window is
    # reached by ~step 15-16 and the grab contact by ~step 106.
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
    #    link.  Against Brick these are orders 8 / 17 (orders 6 / 7 are the
    #    generic grababrucelee / grabbbrucelee rows).
    match_scene._unhandled_input(_key(attack_key))
    if player.attack_kind != miss:
        _fail("real input " + str(step_action) + "+attack did not start "
                + miss + " (native step link): " + player.attack_kind)
        return false
    print("PASS real input started " + miss)

    # 3) The miss must play through its recovered [8, 9] window and chain
    #    automatically into the Brick grab (orders 383 / 385), which then holds
    #    the victim. The miss spends its 66 rage on entry, so a one-step
    #    shortcut cannot pass this.
    var chained := _step_frames(distance, 200, func() -> bool:
        return player.attack_kind == grab)
    if not chained:
        _fail(miss + " did not chain to " + grab + " (native order "
                + ("383" if grab == "grab1 brick" else "385") + "): " + player.attack_kind)
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
    #    it.  An empty `finisher` means the recovered table has no variant for
    #    this opponent/key: the press must fail closed instead.
    Input.action_release(step_action)
    Input.action_press(PC.MOVE_RIGHT)
    _sync_main_input_state()
    match_scene._unhandled_input(_key(KEY_D))
    _sync_main_input_state()
    match_scene._unhandled_input(_key(finisher_key))
    if finisher.is_empty():
        if _endattack_kind(player.attack_kind):
            _fail("mirror-only finisher fired against Brick: " + player.attack_kind)
            return false
        var refused := _step_frames(distance, 160, func() -> bool:
            return victim.state.begins_with("endattackcomp"))
        if refused:
            _fail("refused finisher still consumed the victim: " + victim.state)
            return false
        print("PASS real input refused mirror-only finisher: attack="
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

    # Hold W (native stepright) and press J: main.gd maps the stepright gesture
    # to the recovered Brick miss, whose automatic [8, 9] link chains into the
    # Brick grab.  The A finisher is order 36 (unique endbrickdavis).
    if not _run_grab(0.35, PC.MOVE_UP, KEY_W, KEY_J, "grab1miss brick",
            "grab1 brick", "grabbed1", "endattack brick", "endattackcomp1", KEY_J):
        return

    # Symmetric second real-key path: hold S and press L -> Brick grab2 miss ->
    # grab2 brick.  There is no recovered "endattack2 brick" row (order 35 is
    # mirror-only endbrucelee), so the L finisher press must fail closed.
    my_release_all()
    _reset_round()
    if not _run_grab(0.35, PC.MOVE_DOWN, KEY_S, KEY_L, "grab2miss brick",
            "grab2 brick", "grabbed2", "", "", KEY_L):
        return

    print("REAL_INPUT_GRAB_VALIDATION=" + JSON.stringify({
        "grab1": "stepright+a -> grab1miss brick -> grab1 brick -> grabbed1 -> endattack brick -> endattackcomp1",
        "grab2": "stepleft+c -> grab2miss brick -> grab2 brick -> grabbed2 -> (no endattack2 brick, fail closed)",
        "generic_rows": [6, 34, 35, 347],
        "brick_rows": [8, 17, 36, 383, 385],
        "keyboard_variant": 1,
        "source": "brucelee.set links order 6/8/17 (miss entry) + 347/383/385 (auto [8,9]) + 34/35/36 (finisher)",
    }))
    quit(0)


func my_release_all() -> void:
    Input.action_release(PC.MOVE_LEFT)
    Input.action_release(PC.MOVE_RIGHT)
    Input.action_release(PC.MOVE_UP)
    Input.action_release(PC.MOVE_DOWN)

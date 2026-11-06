extends SceneTree
## Headless acceptance test for the recovered canblock action time windows.
##
## Usage (single headless invocation, no editor import / no windows):
##   godot --headless --path <project> \
##         --script res://tests/validate_canblock_windows.gd \
##         -- <bruce.glb> <brick.glb>
##
## Asserts:
##   1. the window model is a verbatim projection of every shipped set's
##      actions[].groups.canblock / .canblock2 (4 sets, 381 authored windows);
##   2. no action without a canblock group gets an invented window - in
##      particular a guard action's `facing` duration is NOT substituted
##      (thai.set / karate.set guard actions fail closed);
##   3. every shipped guard window is modelled with inclusive endpoints
##      ([6,14] highblock, [6,23] lowblock, [6,20] highblockbrutal, ...);
##   4. a block/guard decision is only valid inside its owning action's
##      authored window: outside it (or with no window table) the contact
##      applies full damage, inside it the contact is blocked;
##   5. chained blocks in blockstun and ground-attack blocks use the owning
##      action's own authored window instead of an unconditional/constant one;
##   6. the native AI's block leaf fails closed outside the window and its
##      decision record carries the window diagnostics.
##
## All numbers below come from data/native_links*.json; nothing is invented.
## See evidence/canblock_windows.json and REPORT.md for the extracted tables.

const CanBlockWindows = preload("res://scripts/canblock_windows.gd")

const SET_FILES: Array[String] = [
    "res://data/native_links.json",
    "res://data/native_links_brick.json",
    "res://data/native_links_karate.json",
    "res://data/native_links_kungfu.json",
]

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _check(name: String, actual: Variant, expected: Variant) -> void:
    checks += 1
    if actual != expected:
        var message: String = "%s: actual=%s expected=%s" % [
            name, JSON.stringify(actual), JSON.stringify(expected)]
        failures.append(message)
        push_error("CANBLOCK_WINDOW_FAIL: " + message)


func _ok(name: String, condition: bool) -> void:
    _check(name, condition, true)


## "group|start|end|linking" keys rebuilt straight from the exported JSON.
func _authored_keys(action: Dictionary) -> Array[String]:
    var keys: Array[String] = []
    var groups_value: Variant = action.get("groups", {})
    if not groups_value is Dictionary:
        return keys
    var groups: Dictionary = groups_value
    for group: String in CanBlockWindows.CANBLOCK_GROUPS:
        var entry_value: Variant = groups.get(group)
        if not entry_value is Array:
            continue
        var entry: Array = Array(entry_value)
        if entry.size() < 2:
            continue
        var start: int = int(entry[0])
        var end: int = int(entry[1])
        if start < 0 or end < 0 or start > end:
            continue
        var linking: int = int(entry[2]) if entry.size() >= 3 else 0
        keys.append("%s|%d|%d|%d" % [group, start, end, linking])
    return keys


func _model_keys(windows: Array[Dictionary]) -> Array[String]:
    var keys: Array[String] = []
    for window: Dictionary in windows:
        keys.append("%s|%d|%d|%d" % [
            String(window.get("group", "")),
            int(window.get("start", -1)),
            int(window.get("end", -1)),
            int(window.get("linking", 0)),
        ])
    return keys


func _load_model(path: String) -> CanBlockWindows:
    var model: CanBlockWindows = CanBlockWindows.new()
    if not model.load_set(path):
        _check(path + " loads", false, true)
    return model


func _no_windows() -> Array[Dictionary]:
    var empty: Array[Dictionary] = []
    return empty


# --- 1/2: the model is the exported data ----------------------------------


func _check_set(path: String) -> void:
    var model: CanBlockWindows = _load_model(path)
    var text: String = FileAccess.get_file_as_string(path)
    var parsed: Variant = JSON.parse_string(text)
    if not parsed is Dictionary:
        _check(path + " parses", false, true)
        return
    var data: Dictionary = parsed
    var actions: Array = Array(data.get("actions", []))
    var links: Array = Array(data.get("links", []))
    var expected_windows: int = 0
    var expected_actions: int = 0
    var no_window_actions: int = 0
    for action_value: Variant in actions:
        if not action_value is Dictionary:
            continue
        var action: Dictionary = action_value
        var name_value: String = String(action.get("name", ""))
        var authored: Array[String] = _authored_keys(action)
        var modelled: Array[String] = _model_keys(model.windows_for(name_value))
        _check(path + ":" + name_value + " windows", modelled, authored)
        if authored.is_empty():
            no_window_actions += 1
            # No authored group => no block decision can ever be valid on this
            # action, whatever its facing/impactable windows say.
            _ok(path + ":" + name_value + " fails closed at frame 0",
                not model.open(name_value, 0.0))
        else:
            expected_actions += 1
            expected_windows += authored.size()
    _check(path + " action_count", model.action_count, actions.size())
    _check(path + " link_count", model.link_count, links.size())
    _check(path + " window_count", model.window_count, expected_windows)
    _check(path + " actions_with_windows", model.windows.size(), expected_actions)
    _check(path + " no_window_actions", no_window_actions,
        actions.size() - expected_actions)
    _check(path + " load_error", model.load_error, "")
    print("CANBLOCK_WINDOW_CHECK set=%s actions=%d windows=%d no_window=%d"
            % [model.set_path, model.action_count, model.window_count,
                    no_window_actions])


func _check_authored_values() -> void:
    var bruce: CanBlockWindows = _load_model(SET_FILES[0])
    var thai: CanBlockWindows = _load_model(SET_FILES[1])
    var karate: CanBlockWindows = _load_model(SET_FILES[2])
    var kungfu: CanBlockWindows = _load_model(SET_FILES[3])

    # brucelee.set guard actions (the recovered [6,14]/[6,23] pair).
    _check("bruce highblock", _model_keys(bruce.windows_for("highblock")),
        ["canblock|6|14|0"])
    _check("bruce lowblock", _model_keys(bruce.windows_for("lowblock")),
        ["canblock|6|23|0"])
    _check("bruce midblock", _model_keys(bruce.windows_for("midblock")),
        ["canblock|6|14|0"])
    _check("bruce highblockhard", _model_keys(bruce.windows_for("highblockhard")),
        ["canblock|6|14|0"])
    _check("bruce highblockbrutal", _model_keys(bruce.windows_for("highblockbrutal")),
        ["canblock|6|20|0"])
    _check("bruce idle", _model_keys(bruce.windows_for("idle")),
        ["canblock|0|140|0"])
    _check("bruce faceupattack", _model_keys(bruce.windows_for("faceupattack")),
        ["canblock|27|38|0"])
    _check("bruce facedownattack", _model_keys(bruce.windows_for("facedownattack")),
        ["canblock|26|35|0"])
    _check("bruce highpunch2 canblock2",
        _model_keys(bruce.windows_for("highpunch2")),
        ["canblock|12|81|0", "canblock2|0|5|0"])

    # Inclusive endpoints, both ends.
    _ok("highblock frame 5.99 closed", not bruce.open("highblock", 5.99))
    _ok("highblock frame 6 open", bruce.open("highblock", 6.0))
    _ok("highblock frame 14 open", bruce.open("highblock", 14.0))
    _ok("highblock frame 14.01 closed", not bruce.open("highblock", 14.01))
    _ok("lowblock frame 6 open", bruce.open("lowblock", 6.0))
    _ok("lowblock frame 23 open", bruce.open("lowblock", 23.0))
    _ok("lowblock frame 23.01 closed", not bruce.open("lowblock", 23.01))
    _ok("highblockbrutal frame 20 open", bruce.open("highblockbrutal", 20.0))
    _ok("highblockbrutal frame 20.01 closed",
        not bruce.open("highblockbrutal", 20.01))
    _check("containing window at frame 8",
        String(bruce.containing_window("highblock", 8.0).get("group", "")),
        "canblock")
    _check("containing window outside",
        bruce.containing_window("highblock", 3.0), {})
    _ok("unknown action fails closed", not bruce.open("no-such-action", 0.0))

    # thai.set (the AI opponent's set) authors NO canblock group on any guard
    # action.  The facing duration [0,17] / [0,23] must not become a window.
    var thai_guards: Array[String] = [
        "highblock", "lowblock", "midblock", "highblockhard", "highblockbrutal",
    ]
    var no_windows: Array[Dictionary] = []
    for guard: String in thai_guards:
        _check("thai " + guard + " has no window",
            thai.windows_for(guard), no_windows)
        _ok("thai " + guard + " fails closed at frame 8",
            not thai.open(guard, 8.0))
        _ok("thai " + guard + " fails closed at frame 0",
            not thai.open(guard, 0.0))
    _check("thai idle", _model_keys(thai.windows_for("idle")),
        ["canblock|0|120|0"])

    # karate.set only authors lowblock, from frame 15.
    _check("karate lowblock", _model_keys(karate.windows_for("lowblock")),
        ["canblock|15|23|0"])
    _ok("karate highblock fails closed", karate.windows_for("highblock").is_empty())
    _ok("karate lowblock frame 14.99 closed",
        not karate.open("lowblock", 14.99))
    _ok("karate lowblock frame 15 open", karate.open("lowblock", 15.0))

    # kungfu.set authors a different, narrower set of guard windows.
    _check("kungfu highblock", _model_keys(kungfu.windows_for("highblock")),
        ["canblock|6|14|0"])
    _check("kungfu lowblock", _model_keys(kungfu.windows_for("lowblock")),
        ["canblock|6|23|0"])
    _check("kungfu midblock", _model_keys(kungfu.windows_for("midblock")),
        ["canblock|4|14|0"])
    _check("kungfu highblockbrutal",
        _model_keys(kungfu.windows_for("highblockbrutal")),
        ["canblock|8|20|0"])
    _ok("kungfu highblockbrutal frame 7 closed",
        not kungfu.open("highblockbrutal", 7.0))
    _ok("kungfu highblockbrutal frame 8 open",
        kungfu.open("highblockbrutal", 8.0))


# --- 3/4/5: runtime gate --------------------------------------------------


func _check_fighter_windows(player: PortFighter, computer: PortFighter) -> void:
    var bruce: CanBlockWindows = _load_model(SET_FILES[0])
    var thai: CanBlockWindows = _load_model(SET_FILES[1])
    _check("player window set",
        String(player.canblock_window_source().get("set_path", "")),
        "adreno_200/set/brucelee.set")
    _check("computer window set",
        String(computer.canblock_window_source().get("set_path", "")),
        "adreno_200/set/thai.set")
    _check("player window_count",
        int(player.canblock_window_source().get("window_count", -1)),
        bruce.window_count)
    _check("computer window_count",
        int(computer.canblock_window_source().get("window_count", -1)),
        thai.window_count)
    _check("player highblock windows",
        _model_keys(player.canblock_windows_for_action("highblock")),
        ["canblock|6|14|0"])
    _check("computer highblock windows (missing in thai.set)",
        computer.canblock_windows_for_action("highblock"), _no_windows())
    _ok("computer highblock fails closed (no facing substitute)",
        not computer.canblock_window_open("highblock", 8.0))

    # Standing guard: the owning action is idle, whose authored window is
    # [0,140] (Bruce) / [0,120] (Brick).  Frame 141 is outside both.
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    _check("idle owning action",
        String(player.block_decision_context().get("action", "")), "idle")
    _ok("idle frame 0 open", player.guard_window_open())
    player.state_time = 141.0 / PortFighter.SOURCE_FRAME_RATE
    _ok("idle frame 141 closed", not player.guard_window_open())
    player.state_time = 0.0
    _ok("idle frame 0 open again", player.guard_window_open())

    # No window table at all => fail closed, never a fallback to a boolean.
    var saved_windows: CanBlockWindows = player._canblock_windows
    player._canblock_windows = null
    player.begin_guard()
    _ok("missing window table fails closed",
        not player._can_block_current_hit({"strength": "normal", "height": "high"}))
    player._canblock_windows = saved_windows
    player.end_guard()

    # Guard action inside / outside its own authored window.
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    player.begin_block("highblock")
    _ok("guarded high impact inside window",
        player._can_block_current_hit({"strength": "normal", "height": "high"}))
    player.state_time = 141.0 / PortFighter.SOURCE_FRAME_RATE
    _ok("guarded high impact outside window fails closed",
        not player._can_block_current_hit({"strength": "normal", "height": "high"}))
    player.end_guard()

    # Ground attack: the authored faceupattack window replaces the hardcoded
    # 27/38, with inclusive endpoints from the set itself.
    for case_value: Variant in [
            [26.999, false], [27.0, true], [38.0, true], [38.001, false]]:
        var case: Array = Array(case_value)
        player.reset_fighter(Vector3(0.0, 1.2, 0.0))
        player.state = "faceupattack"
        player.state_time = float(case[0]) / PortFighter.SOURCE_FRAME_RATE
        _check("faceupattack frame %.3f" % float(case[0]),
            player._can_block_current_hit(), bool(case[1]))
    # thai.set authors no faceupattack canblock group: no invented window.
    computer.reset_fighter(Vector3(0.0, 1.2, 0.0))
    computer.state = "faceupattack"
    computer.state_time = 30.0 / PortFighter.SOURCE_FRAME_RATE
    _ok("thai faceupattack without window fails closed",
        not computer._can_block_current_hit())

    # Chained block: the owning action is the block animation itself.
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    player.state = "blockstun"
    player.last_reaction_source_action = "highblock"
    player.last_reaction_exit_frame = 14
    player.last_reaction_entry_frame = 0
    player.state_time = (14.0 - 3.0) / PortFighter.SOURCE_FRAME_RATE
    _check("blockstun owning action",
        String(player.block_decision_context().get("action", "")), "highblock")
    _check("blockstun frame",
        int(round(float(player.block_decision_context().get("frame", -1.0)))), 3)
    _ok("chained block before frame 6 fails closed",
        not player.blockstun_window_open())
    player.state_time = (14.0 - 8.0) / PortFighter.SOURCE_FRAME_RATE
    _ok("chained block at frame 8 allowed", player.blockstun_window_open())
    player.state_time = 0.0
    _ok("chained block at inclusive end 14 allowed",
        player.blockstun_window_open())
    _ok("highblock end boundary exclusive above 14",
        not player.canblock_window_open("highblock", 14.01))
    # thai.set's highblock has no authored window, so a Brick chained block
    # fails closed even inside the reaction clock.
    computer.reset_fighter(Vector3(0.0, 1.2, 0.0))
    computer.state = "blockstun"
    computer.last_reaction_source_action = "highblock"
    computer.last_reaction_exit_frame = 14
    computer.last_reaction_entry_frame = 0
    computer.state_time = (14.0 - 8.0) / PortFighter.SOURCE_FRAME_RATE
    _ok("thai chained block fails closed (no authored window)",
        not computer.blockstun_window_open())
    computer.reset_fighter(Vector3(0.0, 1.2, 0.0))
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))


func _contact_case(
        scene: Node, player: PortFighter, computer: PortFighter,
        outside_window: bool
) -> Dictionary:
    scene._reset_match()
    player.set_physics_process(false)
    computer.set_physics_process(false)
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    computer.reset_fighter(Vector3(0.6, 1.2, 0.0))
    player.facing = 1.0
    computer.guard_held = true
    computer.state = "idle"
    # 141 native source frames is outside thai.set idle [0,120]; frame 0 is in.
    computer.state_time = (
        (141.0 if outside_window else 0.0) / PortFighter.SOURCE_FRAME_RATE)
    if not player.request_attack("punch"):
        _check("contact attack started", false, true)
        return {}
    player._advance_timed_states(
        float(player.ATTACKS["punch"]["startup"]) + 0.001)
    player._try_attack_contact()
    return {
        "state": computer.state,
        "health": computer.health,
        "guard_held": computer.guard_held,
    }


func _check_contact(scene: Node, player: PortFighter, computer: PortFighter) -> void:
    var outside: Dictionary = _contact_case(scene, player, computer, true)
    _ok("outside window: full damage",
        absf(float(outside.get("health", -1.0)) - 95.0) < 0.001)
    _check("outside window: hitstun", outside.get("state", ""), "hitstun")
    var inside: Dictionary = _contact_case(scene, player, computer, false)
    _ok("inside window: chip damage",
        absf(float(inside.get("health", -1.0)) - 99.4) < 0.001)
    _check("inside window: blockstun", inside.get("state", ""), "blockstun")
    print("CANBLOCK_WINDOW_CHECK contact_outside=%s contact_inside=%s"
            % [JSON.stringify(outside), JSON.stringify(inside)])


# --- 6: AI decision gate --------------------------------------------------


func _check_ai_gate(scene: Node, computer: PortFighter) -> void:
    var ai: RefCounted = scene.get("native_ai")
    if ai == null:
        _check("scene.native_ai present", false, true)
        return
    computer.reset_fighter(Vector3(0.0, 1.2, 0.0))
    computer.state = "blockstun"
    computer.last_reaction_source_action = "highblock"
    computer.last_reaction_exit_frame = 14
    computer.last_reaction_entry_frame = 0
    computer.state_time = (14.0 - 8.0) / PortFighter.SOURCE_FRAME_RATE
    ai._apply_block("highblock")
    _ok("AI block leaf outside authored window holds no guard",
        not computer.guard_held)
    computer.reset_fighter(Vector3(0.0, 1.2, 0.0))
    ai._apply_block("highblock")
    _ok("AI block leaf inside idle window holds the guard", computer.guard_held)
    computer.end_guard()
    var record: Dictionary = ai._record(
        "block", "__block_high__", "highblock", "actionblockhigh", "")
    _ok("decision record carries guard_window",
        record.get("guard_window", {}) is Dictionary)
    _ok("decision record carries guard_window_open",
        record.has("guard_window_open"))
    _check("decision window open in idle", record.get("guard_window_open", false), true)
    print("CANBLOCK_WINDOW_CHECK ai_decision=%s" % JSON.stringify(record))


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() >= 2:
        OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
        OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")

    for path: String in SET_FILES:
        _check_set(path)
    _check_authored_values()

    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    if player == null or computer == null:
        _check("main.tscn exposes fighters", false, true)
        _finish()
        return
    player.set_physics_process(false)
    computer.set_physics_process(false)
    _check_fighter_windows(player, computer)
    _check_contact(scene, player, computer)
    _check_ai_gate(scene, computer)
    _finish()


func _finish() -> void:
    print("CANBLOCK_WINDOW_CHECK total_checks=%d failures=%d"
            % [checks, failures.size()])
    if failures.is_empty():
        print("CANBLOCK_WINDOW_VALIDATION=PASS")
        quit(0)
    else:
        print("CANBLOCK_WINDOW_VALIDATION=FAIL count=%d" % failures.size())
        for failure: String in failures:
            print("  - " + failure)
        quit(1)

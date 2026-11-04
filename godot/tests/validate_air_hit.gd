extends SceneTree
## Headless acceptance test for the recovered `impactablefromair` / air-hit
## branch.
##
## Expectations come only from godot/data/native_links.json:
##   * brucelee.set rows 238-241: from_group `impactablefromair` -> impacthardair
##     with `impact` + `oppattackstrength{brutal,hard,medium,normal}` +
##     `oppattackheighthigh`;
##   * thai.set rows 160-163: the same target with strength only (no height);
##   * the victim actions carrying the group (highkick3 [0,16], specialkickhigh
##     brick [0,28], ...) and the target's own return link
##     impacthardair -> faceupidle [25,25] (row 317).
##
## Run:
##   godot --headless --path <project> --script res://tests/validate_air_hit.gd \
##         -- <bruce.glb> <brick.glb>
##
## Exit 0 = the recovered air rows resolve in the gate, the fallback selector
## applies the same recovered rows, a real airborne contact reaches
## `impacthardair` and returns to `faceupidle`, and every non-air case fails
## closed (no invented reaction).

const NativeReactionState = preload("res://scripts/native_reaction_state.gd")
const BRUCE_LINKS := "res://data/native_links.json"
const BRICK_LINKS := "res://data/native_links_brick.json"

var checks: Dictionary = {}
var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _check(name: String, actual: Variant, expected: Variant) -> void:
    var ok: bool = actual == expected
    checks[name] = {"actual": actual, "expected": expected, "ok": ok}
    if not ok:
        failures.append("%s: actual=%s expected=%s" % [
            name, str(actual), str(expected)
        ])


func _truth(name: String, value: bool) -> void:
    _check(name, value, true)


## JSON null arrives as Variant nil; str(nil) would be "<null>".
func _text(value: Variant) -> String:
    if value == null:
        return ""
    return str(value)


func _load_json(path: String) -> Dictionary:
    var text: String = FileAccess.get_file_as_string(path)
    var parsed: Variant = JSON.parse_string(text)
    return parsed if parsed is Dictionary else {}


func _links_for_group(data: Dictionary, group: String) -> Array:
    var out: Array = []
    for link_value: Variant in Array(data.get("links", [])):
        if not link_value is Dictionary:
            continue
        var link: Dictionary = link_value
        if _text(link.get("from_group", "")) == group:
            out.append(link)
    return out


func _action_groups(data: Dictionary, action: String) -> Dictionary:
    for action_value: Variant in Array(data.get("actions", [])):
        if not action_value is Dictionary:
            continue
        var row: Dictionary = action_value
        if _text(row.get("name", "")) == action:
            var groups: Variant = row.get("groups", {})
            return groups if groups is Dictionary else {}
    return {}


func _air_window(data: Dictionary, action: String) -> Array:
    return Array(_action_groups(data, action).get("impactablefromair", []))


## --- 1. recovered data -------------------------------------------------------


func _check_recovered_rows() -> void:
    var bruce: Dictionary = _load_json(BRUCE_LINKS)
    var brick: Dictionary = _load_json(BRICK_LINKS)
    var bruce_air: Array = _links_for_group(bruce, "impactablefromair")
    var brick_air: Array = _links_for_group(brick, "impactablefromair")
    _check("bruce_air_rows", bruce_air.size(), 4)
    _check("brick_air_rows", brick_air.size(), 4)
    var expected_strengths: Array = ["brutal", "hard", "medium", "normal"]
    for index: int in range(bruce_air.size()):
        var link: Dictionary = bruce_air[index]
        var conditions: Array = Array(link.get("conditions", []))
        _check("bruce_air_target_%d" % index, _text(link.get("to", "")),
            "impacthardair")
        _truth("bruce_air_strength_%d" % index, conditions.has(
            "oppattackstrength" + _text(expected_strengths[index])))
        _truth("bruce_air_height_%d" % index,
            conditions.has("oppattackheighthigh"))
        _truth("bruce_air_has_impact_%d" % index, conditions.has("impact"))
    for index: int in range(brick_air.size()):
        var link: Dictionary = brick_air[index]
        _check("brick_air_target_%d" % index, _text(link.get("to", "")),
            "impacthardair")
        _truth("brick_air_no_height_%d" % index,
            not Array(link.get("conditions", [])).has("oppattackheighthigh"))
    # The target's own outgoing return link, recovered as row 317.
    var return_windows: Array = []
    for link_value: Variant in Array(bruce.get("links", [])):
        var link: Dictionary = link_value
        if _text(link.get("from", "")) != "impacthardair":
            continue
        return_windows.append([_text(link.get("to", "")),
            Array(link.get("time", []))])
    _check("air_return_rows", return_windows.size(), 1)
    if not return_windows.is_empty():
        _check("air_return_target", return_windows[0][0], "faceupidle")
        _check("air_return_window", return_windows[0][1], [25.0, 25.0])
    # Airborne action windows: the group window is the airborne part.
    _check("highkick3_air_window", _air_window(bruce, "highkick3"), [0.0, 16.0, 0.0])
    _check("highkick3_ground_window",
        Array(_action_groups(bruce, "highkick3").get("impactable", [])),
        [17.0, 51.0, 0.0])
    _check("brick_air_window",
        _air_window(brick, "specialkickhigh brick"), [0.0, 28.0, 0.0])
    # The air group is a property of the victim's action, not a global flag: a
    # grounded action must not carry it.
    _truth("idle_has_no_air_window", _air_window(bruce, "idle").is_empty())


## --- 2. gate condition / matrix ---------------------------------------------


func _probe(action: String, strength: String, height: String, frame: float) -> Dictionary:
    return {
        "action": action,
        "frame": frame,
        "health": 100.0,
        "incoming_damage": 7.0,
        "distance": 10.0,
        "victim_radius": 25.0,
        "status": {"left": false},
        "attacker": {
            "impact_active": true,
            "height": height,
            "strength": strength,
            "direction": "frontal",
            "radius": 70.0,
            "scale": 1.0,
            "last_index": 0,
            "cursor": 0,
            "damage": 7.0,
        },
    }


func _check_gate(gate: NativeReactionState, name: String, action: String,
        strength: String, height: String, frame: float, expected: String) -> void:
    _check(name, _text(gate.resolve(_probe(action, strength, height, frame))
        .get("to", "")), expected)


func _check_gate_matrix() -> void:
    var gate: NativeReactionState = NativeReactionState.new()
    if not gate.load_native_links(BRUCE_LINKS):
        failures.append("cannot load " + BRUCE_LINKS)
        return
    # 0x1a4208: OppAttackDirFromAir is a recovered condition.
    _check("condition_fromair", gate.condition_ok("oppattackdirfromair", {
        "attacker": {"direction": "fromair"},
    }), true)
    _check("condition_fromair_refused", gate.condition_ok("oppattackdirfromair", {
        "attacker": {"direction": "frontal"},
    }), false)
    _truth("condition_fromair_recovered",
        NativeReactionState.RECOVERED_CONDITIONS.has("oppattackdirfromair"))
    for strength: String in ["brutal", "hard", "medium", "normal"]:
        _check_gate(gate, "gate_highkick3_%s" % strength, "highkick3",
            strength, "high", 5.0, "impacthardair")
    # Frame 30 is the ground `impactable` window; the air rows no longer apply,
    # and brutal+high+frontal has no ground row either.
    _check_gate(gate, "gate_highkick3_ground_frame", "highkick3",
        "brutal", "high", 30.0, "")
    # Low height is not an air row; at frame 5 the ground window is closed too.
    _check_gate(gate, "gate_highkick3_low_height", "highkick3",
        "hard", "low", 5.0, "")
    var brick_gate: NativeReactionState = NativeReactionState.new()
    if not brick_gate.load_native_links(BRICK_LINKS):
        failures.append("cannot load " + BRICK_LINKS)
        return
    for strength: String in ["brutal", "hard", "medium", "normal"]:
        _check_gate(brick_gate, "brick_gate_%s" % strength,
            "specialkickhigh brick", strength, "high", 5.0, "impacthardair")


## --- 3. real contact setup ---------------------------------------------------


func _place(scene: Node) -> void:
    scene._reset_match()
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.position = Vector3(0.0, 1.2, 0.0)
    computer.position = Vector3(0.7, 1.2, 0.0)
    player.facing = 1.0
    computer.facing = -1.0


func _airborne_victim(scene: Node, victim_is_player: bool) -> PortFighter:
    _place(scene)
    var victim: PortFighter = (
        scene.get("player") if victim_is_player else scene.get("computer")
    )
    victim.state = "startup"
    victim.attack_kind = (
        "high_kick3" if victim_is_player else "special_kick_high_brick"
    )
    victim.state_time = 5.0 / victim.SOURCE_FRAME_RATE
    victim.health = 100.0
    return victim


func _air_contact(scene: Node, victim_is_player: bool) -> void:
    var victim: PortFighter = _airborne_victim(scene, victim_is_player)
    var attacker: PortFighter = (
        scene.get("computer") if victim_is_player else scene.get("player")
    )
    if not attacker.request_attack("high_kick3"):
        failures.append("attacker could not start high_kick3")
        return
    attacker._advance_timed_states(
        float(attacker.ATTACKS["high_kick3"]["startup"]))
    attacker._try_attack_contact()


func _advance_to_faceup(victim: PortFighter) -> String:
    for _step: int in range(200):
        victim._advance_timed_states(1.0 / 60.0)
        if victim.state == "faceupidle":
            return victim.state
    return victim.state


## --- 4/5. scene phases -------------------------------------------------------


func _instantiate() -> Node:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    scene.get("player").set_physics_process(false)
    scene.get("computer").set_physics_process(false)
    return scene


func _run_opt_out() -> void:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_NATIVE_REACTION", "0")
    var scene: Node = await _instantiate()
    var player: PortFighter = scene.get("player")
    _check("off_enabled", player.native_reaction_enabled, false)
    _truth("off_gate_absent", player.get("_native_reaction_gate") == null)

    # Grounded victim: the air branch must not fire.
    _place(scene)
    var grounded: Dictionary = player.reaction_for_incoming({
        "strength": "hard", "height": "high", "direction": "frontal",
    }, false)
    _truth("off_grounded_not_air", _text(grounded.get("source_action", ""))
        != "impacthardair")
    _check("off_grounded_air_state", player._native_air_state(), false)

    # Airborne victim: the fallback selector reads the recovered rows.
    _airborne_victim(scene, true)
    _check("off_air_state", player._native_air_state(), true)
    _check("off_row_hard", _text(player._native_air_hit_reaction({
        "strength": "hard", "height": "high", "direction": "frontal",
    }).get("source_action", "")), "impacthardair")
    _check("off_row_normal", _text(player._native_air_hit_reaction({
        "strength": "normal", "height": "high", "direction": "frontal",
    }).get("source_action", "")), "impacthardair")
    # No recovered air row answers these: fail closed, no invented reaction.
    _check("off_row_low_height", player._native_air_hit_reaction({
        "strength": "hard", "height": "low", "direction": "frontal",
    }).is_empty(), true)
    _check("off_row_no_strength", player._native_air_hit_reaction({
        "strength": "", "height": "high", "direction": "frontal",
    }).is_empty(), true)
    _check("off_row_unknown_condition", player._native_air_condition_ok(
        "notarecoveredcondition", {"strength": "hard", "height": "high"}), false)

    # Real airborne contact through the fallback selector.
    _air_contact(scene, true)
    _check("off_real_source", player.last_reaction_source_action,
        "impacthardair")
    _check("off_real_animation", player.last_reaction_animation,
        "all_impct_hard_frnt_air")
    _check("off_real_exit", player.last_reaction_exit_frame, 25)
    _check("off_real_return", _advance_to_faceup(player), "faceupidle")

    scene.queue_free()
    current_scene = null
    await process_frame


func _run_default() -> void:
    OS.set_environment("BRUCELEE_NATIVE_REACTION", "")
    var scene: Node = await _instantiate()
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    _check("on_enabled", player.native_reaction_enabled, true)

    # Current air state comes from the recovered action window.
    _airborne_victim(scene, true)
    _check("on_air_state_inside", player._native_air_state(), true)
    var details: Dictionary = player.ATTACKS["high_kick3"]
    player.state = "recovery"
    player.state_time = (
        float(details["animation_frame_count"] - 30) / player.SOURCE_FRAME_RATE
    )
    _check("on_air_state_frame", player._native_reaction_frame(), 30.0)
    _check("on_air_state_outside", player._native_air_state(), false)
    _place(scene)
    _check("on_air_state_idle", player._native_air_state(), false)

    # Bruce as the airborne victim (brucelee.set rows 238-241).
    _air_contact(scene, true)
    _check("on_bruce_source", player.last_reaction_source_action,
        "impacthardair")
    _check("on_bruce_animation", player.last_reaction_animation,
        "all_impct_hard_frnt_air")
    _check("on_bruce_exit", player.last_reaction_exit_frame, 25)
    _check("on_bruce_resolved", _text(
        player.last_native_reaction.get("resolved", "")), "impacthardair")
    _check("on_bruce_order", int(player.last_native_reaction.get("order", -1)),
        239)
    _truth("on_bruce_clip",
        player._candidate_clip_paths.has("all_impct_hard_frnt_air"))
    _check("on_bruce_return", _advance_to_faceup(player), "faceupidle")

    # Brick as the airborne victim (thai.set rows 160-163, no height token).
    _air_contact(scene, false)
    _check("on_brick_source", computer.last_reaction_source_action,
        "impacthardair")
    _check("on_brick_animation", computer.last_reaction_animation,
        "all_impct_hard_frnt_air")
    _check("on_brick_order", int(computer.last_native_reaction.get("order", -1)),
        161)

    # Fail closed: a grounded victim keeps the ordinary recovered impact.
    _place(scene)
    var grounded: Dictionary = player.reaction_for_incoming({
        "strength": "hard", "height": "high", "direction": "frontal",
        "attack_radius": 70.0, "damage": 7.0,
    }, false)
    _truth("on_grounded_not_air",
        _text(grounded.get("source_action", "")) != "impacthardair")
    _check("on_grounded_air_state", player._native_air_state(), false)
    _truth("on_grounded_gate_result",
        _text(player.last_native_reaction.get("result", "")) != "air-branch")

    scene.queue_free()
    current_scene = null
    await process_frame


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("expected <bruce.glb> <brick.glb>")
        quit(1)
        return
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])

    _check_recovered_rows()
    _check_gate_matrix()
    await _run_opt_out()
    await _run_default()

    var failed_names: Array = []
    for key: String in checks.keys():
        var row: Variant = checks[key]
        if row is Dictionary and row.has("ok") and not bool(row["ok"]):
            failed_names.append(key)
    for message: String in failures:
        push_error(message)
    print("AIR_HIT_VALIDATION=" + JSON.stringify({
        "checks": checks.size(),
        "failed": failed_names,
    }))
    quit(1 if not failed_names.is_empty() else 0)

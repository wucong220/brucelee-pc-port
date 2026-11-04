extends SceneTree
## Default/opt-out comparison for the recovered reaction gate (NativeReactionState).
##
## The script instantiates the real res://scenes/main.tscn twice in one process:
## first with BRUCELEE_NATIVE_REACTION=0 (opt-out: the pre-recovery heuristic),
## then with BRUCELEE_NATIVE_REACTION unset (default: recovered
## canblock/impact/KO link scan plus FollowLink +0xF0/+0xF4 parking).
##
##   godot --headless --path <project> --script res://tests/validate_native_reaction_gate.gd
##
## Exit 0 = the opt-out path keeps the old selection, the default path selects the
## recovered link targets, the two paths agree for the rows where they must, and
## the FollowLink parking path defers/executes at the recorded frame.

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


func _instantiate_main() -> Node:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", "")
    OS.set_environment("BRUCELEE_OPPONENT_GLB", "")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    scene.get("player").set_physics_process(false)
    scene.get("computer").set_physics_process(false)
    scene._reset_match()
    return scene


func _free_main(scene: Node) -> void:
    scene.queue_free()
    current_scene = null
    await process_frame
    await process_frame


func _place(scene: Node, victim_x: float = 0.6) -> void:
    scene._reset_match()
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.position = Vector3(0.0, 1.2, 0.0)
    computer.position = Vector3(victim_x, 1.2, 0.0)
    player.facing = 1.0
    computer.facing = -1.0


func _probe(scene: Node, impact: Dictionary, blocked: bool) -> Dictionary:
    var player: PortFighter = scene.get("player")
    return player.reaction_for_incoming(impact, blocked)


func _impact(
        strength: String,
        height: String,
        direction: String,
        damage: float = 5.0
) -> Dictionary:
    return {
        "strength": strength,
        "height": height,
        "direction": direction,
        "attack_radius": 70.0,
        "damage": damage,
    }


func _contact(scene: Node, blocked: bool, victim_health: float = 100.0) -> void:
    _place(scene)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    computer.health = victim_health
    computer.guard_held = blocked
    if not player.request_attack("punch"):
        failures.append("could not start punch contact")
        return
    player._advance_timed_states(float(player.ATTACKS["punch"]["startup"]))
    player._try_attack_contact()


func _run_off(scene: Node) -> Dictionary:
    var player: PortFighter = scene.get("player")
    _check("off_enabled", player.native_reaction_enabled, false)
    _check("off_gate", player.get("_native_reaction_gate"), null)
    _truth("off_last_native_empty", player.last_native_reaction.is_empty())

    var cases: Array = [
        ["off_normal_high", _impact("normal", "high", "frontal"), false],
        ["off_normal_med", _impact("normal", "medium", "frontal"), false],
        ["off_normal_low", _impact("normal", "low", "frontal"), false],
        ["off_hard_med", _impact("hard", "medium", "frontal", 7.0), false],
        ["off_hard_low_right", _impact("hard", "low", "fromright", 7.0), false],
        ["off_hard_high", _impact("hard", "high", "frontal", 7.0), false],
        ["off_brutal_high_left", _impact("brutal", "high", "fromleft", 12.0), false],
        ["off_block_normal_high", _impact("normal", "high", "frontal"), true],
        ["off_block_normal_med", _impact("normal", "medium", "frontal"), true],
        ["off_block_hard_high", _impact("hard", "high", "frontal", 7.0), true],
    ]
    var selected: Dictionary = {}
    for case: Array in cases:
        _place(scene)
        var reaction: Dictionary = _probe(scene, case[1], case[2])
        selected[case[0]] = String(reaction.get("source_action", ""))
    _check("off_high", selected["off_normal_high"], "impactlightfronthigh")
    _check("off_med", selected["off_normal_med"], "impactlightfrontmid")
    _check("off_low", selected["off_normal_low"], "impactlightfrontlow")
    _check("off_hard_med", selected["off_hard_med"], "impacthardfrontmid")
    _check("off_hard_low_right", selected["off_hard_low_right"], "impacthardrightlow")
    _check("off_hard_high", selected["off_hard_high"], "impacthardfronthigh")
    _check("off_brutal_high_left", selected["off_brutal_high_left"], "impactbrutalleft")
    _check("off_block_high", selected["off_block_normal_high"], "highblock")
    _check("off_block_med", selected["off_block_normal_med"], "midblock")
    _check("off_block_hard", selected["off_block_hard_high"], "highblockhard")

    # Lethal and out-of-range probes: the existing heuristic does not run the
    # healthzero/distance checks, so these differ from the opt-in path.
    _place(scene)
    player.health = 4.0
    _check("off_lethal_normal_high",
        String(_probe(scene, _impact("normal", "high", "frontal", 9.0), false)
            .get("source_action", "")), "impactlightfronthigh")
    _place(scene)
    player.health = 4.0
    _check("off_lethal_normal_med",
        String(_probe(scene, _impact("normal", "medium", "frontal", 9.0), false)
            .get("source_action", "")), "impactlightfrontmid")
    _place(scene)
    player.health = 4.0
    _check("off_lethal_hard_high",
        String(_probe(scene, _impact("hard", "high", "frontal", 9.0), false)
            .get("source_action", "")), "impacthardfronthigh")
    _place(scene)
    player.health = 4.0
    _check("off_lethal_hard_med",
        String(_probe(scene, _impact("hard", "medium", "frontal", 9.0), false)
            .get("source_action", "")), "impacthardfrontmid")
    _place(scene, 3.0)
    _truth("off_far_keeps_profile",
        not _probe(scene, _impact("normal", "high", "frontal"), false).is_empty())

    # Existing real contact path.
    _contact(scene, true)
    var computer: PortFighter = scene.get("computer")
    _check("off_guard_state", computer.state, "blockstun")
    _check("off_guard_health", computer.health, 99.4)
    _check("off_guard_source", computer.last_reaction_source_action, "midblock")
    _contact(scene, false)
    _check("off_hit_state", computer.state, "hitstun")
    _check("off_hit_health", computer.health, 95.0)
    _check("off_hit_source", computer.last_reaction_source_action, "impactlightfrontmid")
    _contact(scene, false, 1.0)
    _check("off_lethal_health", computer.health, 0.0)
    _check("off_lethal_state", computer.state, "ko")

    return selected


func _run_on(scene: Node, off_selected: Dictionary) -> Dictionary:
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    _check("on_enabled", player.native_reaction_enabled, true)
    var gate: NativeReactionState = player.get("_native_reaction_gate")
    _truth("on_gate_loaded", gate != null)
    if gate == null:
        return {}
    _check("on_gate_links", gate.links.size(), player.get("_native_links").size())
    _check("on_gate_actions", gate.actions.size(), player.get("_native_actions").size())
    _check("on_gate_links_recovered", gate.links.size(), 396)
    _check("on_gate_actions_recovered", gate.actions.size(), 200)
    _check("on_gate_no_pending", gate.pending_frame, -1)
    var brick_gate: NativeReactionState = computer.get("_native_reaction_gate")
    _truth("on_brick_gate_loaded", brick_gate != null)
    if brick_gate != null:
        _check("on_brick_gate_links", brick_gate.links.size(),
            computer.get("_native_links").size())

    var cases: Array = [
        ["on_normal_high", _impact("normal", "high", "frontal"), false, "impactlightfronthigh", 219],
        ["on_normal_med", _impact("normal", "medium", "frontal"), false, "impactlightfrontmid", 223],
        ["on_normal_low", _impact("normal", "low", "frontal"), false, "impactlightfrontlow", 220],
        ["on_hard_med", _impact("hard", "medium", "frontal", 7.0), false, "impacthardfrontmid", 234],
        ["on_hard_low_right", _impact("hard", "low", "fromright", 7.0), false, "impacthardrightlow", 230],
        ["on_hard_high", _impact("hard", "high", "frontal", 7.0), false, "impacthardfronthigh", 227],
        ["on_brutal_high_left", _impact("brutal", "high", "fromleft", 12.0), false, "impactbrutalleft", 235],
        ["on_block_normal_high", _impact("normal", "high", "frontal"), true, "highblock", 93],
        ["on_block_normal_med", _impact("normal", "medium", "frontal"), true, "midblock", 94],
        ["on_block_hard_high", _impact("hard", "high", "frontal", 7.0), true, "highblockhard", 95],
    ]
    var selected: Dictionary = {}
    for case: Array in cases:
        _place(scene)
        var reaction: Dictionary = _probe(scene, case[1], case[2])
        selected[case[0]] = String(reaction.get("source_action", ""))
        _check(String(case[0]) + "_source", selected[case[0]], String(case[3]))
        _check(String(case[0]) + "_order",
            int(player.last_native_reaction.get("order", -1)), int(case[4]))
        _check(String(case[0]) + "_result",
            String(player.last_native_reaction.get("result", "")), "ok")
        # The port's existing profile/entry must carry the same animation and
        # exit frame as the gate target (the recovered row is not re-invented).
        _truth(String(case[0]) + "_has_animation",
            not String(reaction.get("animation", "")).is_empty())

    # Off/on agreement for the recovered block/impact rows that already existed.
    var agree_pairs: Array = [
        ["off_normal_high", "on_normal_high"],
        ["off_normal_med", "on_normal_med"],
        ["off_normal_low", "on_normal_low"],
        ["off_hard_med", "on_hard_med"],
        ["off_hard_low_right", "on_hard_low_right"],
        ["off_hard_high", "on_hard_high"],
        ["off_brutal_high_left", "on_brutal_high_left"],
        ["off_block_normal_high", "on_block_normal_high"],
        ["off_block_normal_med", "on_block_normal_med"],
        ["off_block_hard_high", "on_block_hard_high"],
    ]
    for pair: Array in agree_pairs:
        _check("agree_" + String(pair[1]),
            selected[pair[1]], String(off_selected.get(pair[0], "")))

    # KO rows: the gate resolves the recovered healthzero targets.
    _place(scene)
    player.health = 4.0
    _probe(scene, _impact("normal", "high", "frontal", 9.0), false)
    _check("on_lethal_normal_high",
        String(player.last_native_reaction.get("resolved", "")), "impactstunhigh")
    _check("on_lethal_normal_high_order",
        int(player.last_native_reaction.get("order", -1)), 209)
    _place(scene)
    player.health = 4.0
    _probe(scene, _impact("normal", "medium", "frontal", 9.0), false)
    _check("on_lethal_normal_med",
        String(player.last_native_reaction.get("resolved", "")), "impactstunlow")
    _place(scene)
    player.health = 4.0
    _probe(scene, _impact("hard", "high", "frontal", 9.0), false)
    _check("on_lethal_hard_high",
        String(player.last_native_reaction.get("resolved", "")), "impacthardfronthigh")
    _place(scene)
    player.health = 4.0
    _probe(scene, _impact("hard", "medium", "frontal", 9.0), false)
    _check("on_lethal_hard_med",
        String(player.last_native_reaction.get("resolved", "")), "impacthardfrontlow")

    # Recovered impact distance check: outside the reach the gate fails closed.
    _place(scene, 3.0)
    var far: Dictionary = _probe(scene, _impact("normal", "high", "frontal"), false)
    _truth("on_far_empty", far.is_empty())
    _check("on_far_result",
        String(player.last_native_reaction.get("result", "")), "no-matching-link")

    # Recovered impactsfromstun scan while the victim is in a stun action.
    _place(scene)
    player.state = "stun"
    player.state_time = 55.0 / 30.0
    var stun: Dictionary = _probe(scene, _impact("hard", "high", "frontal", 7.0), false)
    _check("on_stun_source", String(stun.get("source_action", "")), "stunhardimpact")
    _check("on_stun_order", int(player.last_native_reaction.get("order", -1)), 128)

    # Real contact path with the gate on.
    _contact(scene, true)
    _check("on_guard_state", computer.state, "blockstun")
    _check("on_guard_health", computer.health, 99.4)
    _check("on_guard_source", computer.last_reaction_source_action, "midblock")
    _contact(scene, false)
    _check("on_hit_state", computer.state, "hitstun")
    _check("on_hit_health", computer.health, 95.0)
    _check("on_hit_source", computer.last_reaction_source_action, "impactlightfrontmid")
    # Lethal normal medium: recovered rows 210 -> impactstunlow, then 288
    # [14,17] -> stun. That is the KO chain entry, not an immediate `ko` state.
    _contact(scene, false, 1.0)
    _check("on_lethal_health", computer.health, 0.0)
    # This fixture loads no candidate GLB for the opponent, so the recovered
    # impactstun entry has no clip to play and the port keeps its fail-closed
    # `ko` state. validate_stun covers the loaded-candidate path (row 210 ->
    # impactstunlow, then row 288 [14,17] -> stun).
    _check("on_lethal_state", computer.state, "ko")
    _check("on_lethal_resolved",
        String(computer.last_native_reaction.get("resolved", "")), "impactstunlow")
    var lethal_entry: Dictionary = computer._native_healthzero_impact_entry("impactstunlow")
    _check("on_lethal_entry_animation",
        String(lethal_entry.get("animation", "")), "all_impct_light_frnt_low")
    _check("on_lethal_entry_exit", int(lethal_entry.get("exit_frame", -1)), 14)
    _check("on_lethal_entry_next", String(lethal_entry.get("next_state", "")), "stun")

    # FollowLink +0xF0/+0xF4 parking. A real recovered row is given a future
    # linking_frame so the recovery scan selects it first; this is a fixture for
    # the recovered parking branch, which no reaction row in the shipped table
    # currently exercises (all reaction rows carry linking_frame 0).
    var injected: Dictionary = {}
    for link_value: Variant in gate.links:
        var link: Dictionary = link_value
        if String(link.get("to", "")) == "impactlightfronthigh":
            injected = link.duplicate(true)
            break
    if injected.is_empty():
        failures.append("parking fixture row not found in gate.links")
        return selected
    injected["order"] = -1
    injected["linking_frame"] = 1
    gate.links.insert(0, injected)
    _place(scene)
    # The link window admits the row at frame 0.99999 while FollowLink compares
    # the integer frame (0) with the target frame (1) and parks it.
    player.state_time = 0.99999 / 30.0
    var parked_hit: Dictionary = _probe(scene, _impact("normal", "high", "frontal"), false)
    _truth("parking_deferred_empty", parked_hit.is_empty())
    _check("parking_pending_frame", gate.pending_frame, 1)
    _check("parking_deferred_flag",
        bool(player.last_native_reaction.get("deferred", false)), true)
    _truth("parking_has_pending_reaction",
        not Dictionary(player.get("_native_pending_reaction")).is_empty())
    # A second hit while the link is parked fails closed (UserControlUpdate
    # returns before the link loop).
    var blocked_hit: Dictionary = _probe(scene, _impact("normal", "high", "frontal"), false)
    _truth("parking_blocks_scan", blocked_hit.is_empty())
    _check("parking_blocks_scan_result",
        String(player.last_native_reaction.get("result", "")), "blocked-by-pending")
    # Apply the contact the way the attacker would, then execute BasicUpdate.
    player.receive_hit(5.0, false, 0.0, 1.0, {})
    _check("parking_hit_health", player.health, 95.0)
    player._advance_native_reaction_parking(0.5)
    _truth("parking_not_ready",
        not Dictionary(player.get("_native_pending_reaction")).is_empty())
    _check("parking_still_parked", gate.pending_frame, 1)
    player._advance_native_reaction_parking(1.0)
    _truth("parking_cleared", gate.can_follow())
    _check("parking_executed_frame",
        float(player.last_native_reaction.get("executed_frame", -1.0)), 1.0)
    _truth("parking_pending_cleared",
        Dictionary(player.get("_native_pending_reaction")).is_empty())
    _check("parking_applied_source",
        player.last_reaction_source_action, "impactlightfronthigh")
    _check("parking_applied_animation",
        player.last_reaction_animation, "all_impct_light_frnt_high")
    _check("parking_applied_exit", player.last_reaction_exit_frame, 13)
    _check("parking_applied_state", player.state, "hitstun")
    _check("parking_applied_time", snappedf(player.state_time, 0.001),
        snappedf(13.0 / 30.0, 0.001))

    gate.links.remove_at(0)
    gate.reset()
    return selected


func _run() -> void:
    # 1) Opt-out: BRUCELEE_NATIVE_REACTION=0 keeps the pre-recovery heuristic.
    OS.set_environment("BRUCELEE_NATIVE_REACTION", "0")
    var off_scene: Node = await _instantiate_main()
    var off_selected: Dictionary = _run_off(off_scene)
    await _free_main(off_scene)

    # 2) Default (env unset): the recovered link scan and FollowLink parking.
    OS.set_environment("BRUCELEE_NATIVE_REACTION", "")
    var on_scene: Node = await _instantiate_main()
    var on_selected: Dictionary = _run_on(on_scene, off_selected)
    await _free_main(on_scene)

    var failed_names: Array = []
    for key: String in checks.keys():
        var row: Variant = checks[key]
        if row is Dictionary and row.has("ok") and not bool(row["ok"]):
            failed_names.append(key)
    for message: String in failures:
        push_error(message)
    var report: Dictionary = {
        "checks": checks.size(),
        "failed": failed_names,
        "off_selected": off_selected,
        "on_selected": on_selected,
    }
    print("NATIVE_REACTION_GATE_VALIDATION=" + JSON.stringify(report))
    quit(1 if not failed_names.is_empty() else 0)

extends SceneTree
## Headless validation of the recovered reaction gate (NativeReactionState).
##
## Expectations come from godot/data/native_links.json link order and the
## condition semantics recovered in evidence/RECOVERY.md.  Every expected target
## names a real link from brucelee.set; nothing here is invented.
##
##   godot --headless --path app -s res://tests/validate_native_reaction_state.gd
##
## Exit 0 = every recovered row resolved as expected and every unrecovered case
## refused (fail closed).

const NativeReactionState = preload("res://scripts/native_reaction_state.gd")

var checks: Dictionary = {}
var failures: Array = []


func _initialize() -> void:
    call_deferred("_run")


func _probe(fields: Dictionary) -> Dictionary:
    var attacker: Dictionary = {
        "impact_active": bool(fields.get("impact_active", true)),
        "height": String(fields.get("height", "high")),
        "strength": String(fields.get("strength", "normal")),
        "direction": String(fields.get("direction", "frontal")),
        "radius": float(fields.get("radius", 60.0)),
        "scale": float(fields.get("scale", 1.0)),
        "last_index": int(fields.get("last_index", 0)),
        "cursor": int(fields.get("cursor", 0)),
        "damage": float(fields.get("damage", 5.0)),
    }
    return {
        "action": String(fields.get("action", "")),
        "frame": float(fields.get("frame", 0.0)),
        "health": float(fields.get("health", 100.0)),
        "incoming_damage": float(fields.get("damage", 5.0)),
        "distance": float(fields.get("distance", 10.0)),
        "victim_radius": 25.0,
        "status": {"left": bool(fields.get("guard", false))},
        "attacker": attacker,
    }


func _to(gate: NativeReactionState, fields: Dictionary) -> String:
    return String(gate.resolve(_probe(fields)).get("to", ""))


func _check(name: String, actual: Variant, expected: Variant) -> void:
    var ok: bool = actual == expected
    checks[name] = {"actual": actual, "expected": expected, "ok": ok}
    if not ok:
        failures.append("%s: actual=%s expected=%s" % [name, str(actual), str(expected)])


func _run() -> void:
    var gate: NativeReactionState = NativeReactionState.new()
    if not gate.load_native_links(NativeReactionState.NATIVE_LINKS_PATH):
        push_error("cannot load native links: " + gate.load_error)
        quit(1)
        return
    checks["links_loaded"] = gate.links.size()
    checks["actions_loaded"] = gate.actions.size()
    print("LOAD=" + gate.load_error)
    if gate.links.size() < 300 or gate.actions.size() < 150:
        push_error("link table too small: " + str(gate.describe()))
        quit(1)
        return

    # ---- high / mid / low block (canblock rows 92-96, 97-101) -------------
    # The recovered block key is the "left" status token in every layout.
    _check("block_normal_high",
        _to(gate, {"action": "idle", "frame": 10.0, "guard": true, "height": "high"}),
        "highblock")
    _check("block_normal_med",
        _to(gate, {"action": "idle", "frame": 10.0, "guard": true, "height": "medium"}),
        "midblock")
    _check("block_normal_low",
        _to(gate, {"action": "idle", "frame": 10.0, "guard": true, "height": "low"}),
        "lowblock")
    _check("block_hard_any_height",
        _to(gate, {"action": "idle", "frame": 10.0, "guard": true, "strength": "hard"}),
        "highblockhard")
    _check("block_brutal",
        _to(gate, {"action": "idle", "frame": 10.0, "guard": true, "strength": "brutal"}),
        "highblockbrutal")
    # Guard not held: the block rows fail InputStatusCheck and the impactable
    # rows take over (normal/high/frontal -> row 219).
    _check("no_guard_falls_to_hit",
        _to(gate, {"action": "idle", "frame": 10.0, "height": "high", "direction": "frontal"}),
        "impactlightfronthigh")
    # Group window gate: highblock only carries canblock [6,14].
    _check("window_before",
        _to(gate, {"action": "highblock", "frame": 3.0, "guard": true, "height": "high"}), "")
    _check("window_inside",
        _to(gate, {"action": "highblock", "frame": 8.0, "guard": true, "height": "high"}),
        "highblock")

    # ---- impact selection -------------------------------------------------
    _check("hit_normal_high_frontal",
        _to(gate, {"action": "idle", "frame": 10.0, "height": "high", "direction": "frontal"}),
        "impactlightfronthigh")
    _check("hit_normal_low_frontal",
        _to(gate, {"action": "idle", "frame": 10.0, "height": "low", "direction": "frontal"}),
        "impactlightfrontlow")
    _check("hit_normal_med_frontal",
        _to(gate, {"action": "idle", "frame": 10.0, "height": "medium", "direction": "frontal"}),
        "impactlightfrontmid")
    _check("hit_hard_med_frontal",
        _to(gate, {"action": "idle", "frame": 10.0, "strength": "hard",
            "height": "medium", "direction": "frontal"}),
        "impacthardfrontmid")
    _check("hit_brutal_high_fromleft",
        _to(gate, {"action": "idle", "frame": 10.0, "strength": "brutal",
            "height": "high", "direction": "fromleft"}),
        "impactbrutalleft")
    _check("hit_hard_high_fromabove",
        _to(gate, {"action": "idle", "frame": 10.0, "strength": "hard",
            "height": "high", "direction": "fromabove"}),
        "impacthardabove")
    # Rows 213/214 put lethal hard hits on impacthardfrontlow before the
    # non-lethal height table is reached.
    _check("lethal_hard_med_prefers_ko_row",
        _to(gate, {"action": "idle", "frame": 10.0, "health": 4.0, "damage": 9.0,
            "strength": "hard", "height": "medium", "direction": "frontal"}),
        "impacthardfrontlow")
    _check("lethal_normal_high_uses_stun_row",
        _to(gate, {"action": "idle", "frame": 10.0, "health": 4.0, "damage": 9.0,
            "height": "high", "direction": "frontal"}),
        "impactstunhigh")

    # ---- fail closed ------------------------------------------------------
    # hard + medium + fromleft matches no recovered row, so nothing is chosen.
    _check("unmatched_combination_refused",
        _to(gate, {"action": "idle", "frame": 10.0, "strength": "hard",
            "height": "medium", "direction": "fromleft"}), "")
    # The `impact` condition includes the recovered distance gate.
    _check("distance_out_of_range_refused",
        _to(gate, {"action": "idle", "frame": 10.0, "distance": 5000.0}), "")
    # The impact cursor must still have an unspent impact.
    _check("spent_cursor_refused",
        _to(gate, {"action": "idle", "frame": 10.0, "last_index": 0, "cursor": 1}), "")
    # An unknown action carries no group, so no group link applies.
    _check("unknown_action_refused",
        _to(gate, {"action": "no-such-action", "frame": 10.0}), "")

    # ---- stun / KO chain --------------------------------------------------
    # The stun chain only advances while nobody's impact window is active, so
    # these fixtures clear the attacker record (the recovered `impact`
    # condition is what gates the impactsfromstun rows).
    _check("stun_to_stun2",
        _to(gate, {"action": "stun", "frame": 56.0, "impact_active": false}), "stun2")
    _check("stun2_to_stunfall",
        _to(gate, {"action": "stun2", "frame": 56.0, "impact_active": false}), "stunfall")
    _check("stunfall_to_faceupko",
        _to(gate, {"action": "stunfall", "frame": 72.0, "impact_active": false}), "faceupko")
    _check("stunhardimpact_to_faceupko",
        _to(gate, {"action": "stunhardimpact", "frame": 21.0, "impact_active": false}),
        "faceupko")
    _check("stunbrutalimpact_to_facedownko",
        _to(gate, {"action": "stunbrutalimpact", "frame": 41.0, "impact_active": false}),
        "facedownko")
    # ... and an active incoming impact takes the impactsfromstun rows first.
    _check("stun_hit_by_normal_takes_stun_impact",
        _to(gate, {"action": "stun", "frame": 10.0, "strength": "normal"}),
        "stunlighthighimpact")
    _check("stun_hit_by_brutal_takes_brutal_impact",
        _to(gate, {"action": "stun", "frame": 10.0, "strength": "brutal"}),
        "stunbrutalimpact")
    _check("impact_hard_high_hz_to_faceupko",
        _to(gate, {"action": "impacthardfronthigh", "frame": 25.0, "health": 0.0,
            "damage": 0.0}), "faceupko")
    _check("faceupidle_hz_to_faceupko",
        _to(gate, {"action": "faceupidle", "frame": 10.0, "health": 20.0,
            "damage": 30.0}), "faceupko")
    _check("faceupidle_nonlethal_refused",
        _to(gate, {"action": "faceupidle", "frame": 10.0, "health": 20.0,
            "damage": 5.0}), "")

    # ---- FollowLink deferral (+0xF0/+0xF4) -------------------------------
    var parked: Dictionary = {"order": 9999, "from": "idle", "to": "lowpunch1",
        "linking_frame": 9, "time": [0, 140], "keystatus": [[], [], []],
        "conditions": []}
    var first: Dictionary = gate.follow_link(parked, 4.0)
    _check("defer_pending", bool(first.get("deferred", false)), true)
    _check("defer_blocks_new_links", gate.can_follow(), false)
    _check("defer_pending_frame", gate.pending_frame, 9)
    _check("defer_not_ready", gate.advance(8.0).is_empty(), true)
    _check("defer_blocked_resolve_while_pending",
        gate.resolve(_probe({"action": "idle", "frame": 8.0})).is_empty(), true)
    var run: Dictionary = gate.advance(9.0)
    _check("defer_executes", String(run.get("link", {}).get("to", "")), "lowpunch1")
    _check("defer_cleared", gate.can_follow(), true)
    # A link whose target frame is already reached runs immediately.
    var immediate: Dictionary = gate.follow_link(parked, 12.0)
    _check("no_defer_when_frame_reached", bool(immediate.get("execute", false)), true)

    # ---- damage gate (DamageReceiveCheck) --------------------------------
    var attacker: Dictionary = {"impact_active": true, "last_index": 0, "cursor": 0,
        "damage": 7.0}
    _check("damage_on_receivedamage_clip",
        gate.damage_applies("impacthardfronthigh", attacker), true)
    _check("damage_refused_on_block_clip",
        gate.damage_applies("highblock", attacker), false)
    _check("damage_refused_when_cursor_spent",
        gate.damage_applies("impacthardfronthigh",
            {"impact_active": true, "last_index": 0, "cursor": 1}), false)
    _check("damage_refused_when_not_attacking",
        gate.damage_applies("impacthardfronthigh",
            {"impact_active": false, "last_index": 0, "cursor": 0}), false)
    _check("damage_amount_scaled", gate.damage_amount({"damage": 7.0}, 1.0), 7)

    # ---- unknown condition must fail closed ------------------------------
    # An unrecovered condition (no caller evaluator installed) is false, so a
    # link carrying it cannot match rather than being assumed true.
    _check("unknown_condition_refused",
        gate.condition_ok("notarecoveredcondition",
            _probe({"action": "idle", "frame": 10.0})), false)
    # Delegated conditions only pass when the caller supplies an evaluator.
    gate.extra_condition_eval = func(condition: String, _probe_value: Dictionary) -> bool:
        return condition == "totally_unknown_token"
    _check("delegated_condition_passes",
        gate.condition_ok("totally_unknown_token", _probe({"action": "idle", "frame": 10.0})), true)
    _check("recovered_condition_ignores_delegate",
        gate.condition_ok("ragethird", _probe({"action": "idle", "frame": 10.0})), false)
    gate.extra_condition_eval = Callable()

    var failed_names: Array = []
    for key: String in checks.keys():
        var row: Variant = checks[key]
        if row is Dictionary and row.has("ok") and not bool(row["ok"]):
            failed_names.append(key)
    for message: String in failures:
        push_error(message)
    if not failed_names.is_empty():
        for entry: Variant in gate.trace:
            if String(Dictionary(entry).get("kind", "")) == "no-match":
                print("DIAG=" + JSON.stringify(entry))
                break
    var report: Dictionary = {
        "checks": checks.size(),
        "failed": failed_names,
        "links": gate.links.size(),
        "actions": gate.actions.size(),
        "trace_entries": gate.trace.size(),
    }
    print("NATIVE_REACTION_STATE_VALIDATION=" + JSON.stringify(report))
    quit(1 if not failed_names.is_empty() else 0)

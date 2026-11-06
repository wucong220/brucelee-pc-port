extends SceneTree
## CheckConditions coverage + truth table for every native link token.
##
## Two layers:
##   1. A pure truth table over scripts/native_conditions.gd.  Each row states
##      the native field values and the expected boolean, including boundary
##      values (rage 32/33/65/66/99/100, grab slack 25.0, healthzero equality,
##      the +0x168 height-high asymmetry, unspent-impact high-water).
##   2. Integration through PortFighter._native_condition_ok against the real
##      main.tscn: the fighter adapter must project the opponent's live attack
##      impact records into the same evaluator.
##
## Exit 0 only when every row matches.

const NativeConditions = preload("res://scripts/native_conditions.gd")

var checks: Dictionary = {}
var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _ck(name: String, actual: Variant, expected: Variant) -> void:
    var ok: bool = actual == expected
    checks[name] = {"actual": actual, "expected": expected, "ok": ok}
    if not ok:
        failures.append("%s actual=%s expected=%s" % [name, str(actual), str(expected)])


func _p(fields: Dictionary = {}) -> Dictionary:
    var probe: Dictionary = {
        "self_pose": "",
        "self_radius": 25.0,
        "self_health": 100.0,
        "self_rage": 0.0,
        "self_rage_forced": false,
        "self_dummy_health": false,
        "distance": 0.0,
        "incoming_damage": 0.0,
        "counter_open": false,
        "opponent_pose": "",
        "opponent_blocking": false,
        "opponent_scale": 1.0,
        "opponent_radius": 25.0,
        "opponent_attacking": false,
        "opponent_active_impact": null,
        "opponent_next_impact": null,
        "opponent_processed": 0,
        "opponent_about_to_grab": false,
        "relative_facing_dot": 1.0,
    }
    probe.merge(fields, true)
    return probe


func _rec(fields: Dictionary = {}) -> Dictionary:
    var record: Dictionary = {
        "id": 0, "start": 0, "end": 10, "radius": 70.0,
        "height": "high", "strength": "normal", "direction": "frontal",
    }
    record.merge(fields, true)
    return record


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    _pure_table()
    if args.size() >= 1:
        await _integration(args[0])
    for name: String in failures:
        push_error("condition truth-table failed: " + name)
    var report: Dictionary = {
        "checks": checks.size(),
        "failed": failures,
        "implemented_tokens": NativeConditions.IMPLEMENTED_TOKENS.size(),
        "recovered_unused_tokens": NativeConditions.RECOVERED_UNUSED_TOKENS,
        "rows": checks,
    }
    print("NATIVE_CONDITION_TRUTH_TABLE=" + JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)


func _pure_table() -> void:
    # ---- token domain -----------------------------------------------------
    for token: String in NativeConditions.IMPLEMENTED_TOKENS:
        _ck("known_%s" % token, NativeConditions.is_known(token), true)
    for token: String in NativeConditions.RECOVERED_UNUSED_TOKENS:
        _ck("known_unused_%s" % token, NativeConditions.is_known(token), true)
    _ck("unknown_empty", NativeConditions.is_known(""), false)
    _ck("unknown_bogus", NativeConditions.is_known("oppattackstrengthfatal"), false)
    _ck("unknown_refused", NativeConditions.evaluate("oppattackstrengthfatal", _p({
        "opponent_active_impact": _rec()})), false)

    # ---- impact (0x1a42e4 / 0x1a4388) -------------------------------------
    _ck("impact_live_in_reach", NativeConditions.evaluate("impact", _p({
        "opponent_attacking": true, "opponent_active_impact": _rec(),
        "distance": 95.0, "self_radius": 25.0, "opponent_scale": 1.0,
        "opponent_processed": 0})), true)
    _ck("impact_radius_scale", NativeConditions.evaluate("impact", _p({
        "opponent_attacking": true, "opponent_active_impact": _rec(),
        "distance": 95.1, "self_radius": 25.0, "opponent_scale": 1.0})), false)
    _ck("impact_scale_2", NativeConditions.evaluate("impact", _p({
        "opponent_attacking": true, "opponent_active_impact": _rec(),
        "distance": 165.0, "self_radius": 25.0, "opponent_scale": 2.0})), true)
    _ck("impact_not_attacking", NativeConditions.evaluate("impact", _p({
        "opponent_attacking": false, "opponent_active_impact": _rec()})), false)
    _ck("impact_no_record", NativeConditions.evaluate("impact", _p({
        "opponent_attacking": true, "opponent_active_impact": null})), false)
    _ck("impact_processed_0", NativeConditions.evaluate("impact", _p({
        "opponent_attacking": true, "opponent_active_impact": _rec({"id": 0}),
        "opponent_processed": 0})), true)
    _ck("impact_processed_1", NativeConditions.evaluate("impact", _p({
        "opponent_attacking": true, "opponent_active_impact": _rec({"id": 0}),
        "opponent_processed": 1})), false)
    _ck("impact_second_id_1", NativeConditions.evaluate("impact", _p({
        "opponent_attacking": true, "opponent_active_impact": _rec({"id": 1}),
        "opponent_processed": 1})), true)

    # ---- healthzero (0x1a43b4) --------------------------------------------
    _ck("healthzero_lt", NativeConditions.evaluate("healthzero", _p({
        "incoming_damage": 99.0, "self_health": 100.0})), false)
    _ck("healthzero_eq", NativeConditions.evaluate("healthzero", _p({
        "incoming_damage": 100.0, "self_health": 100.0})), true)
    _ck("healthzero_gt", NativeConditions.evaluate("healthzero", _p({
        "incoming_damage": 101.0, "self_health": 100.0})), true)
    _ck("healthzero_dummy", NativeConditions.evaluate("healthzero", _p({
        "incoming_damage": 200.0, "self_health": 100.0, "self_dummy_health": true})), false)

    # ---- pose tokens (gid_stand/laying/stun at animation +0xac) ------------
    _ck("posestun_stun", NativeConditions.evaluate("oppposestun", _p({"opponent_pose": "stun"})), true)
    _ck("posestun_stand", NativeConditions.evaluate("oppposestun", _p({"opponent_pose": "stand"})), false)
    _ck("posestand_stand", NativeConditions.evaluate("oppposestand", _p({"opponent_pose": "stand"})), true)
    _ck("posestand_laying", NativeConditions.evaluate("oppposestand", _p({"opponent_pose": "laying"})), false)
    _ck("poselaying_laying", NativeConditions.evaluate("oppposelaying", _p({"opponent_pose": "laying"})), true)
    _ck("poselaying_crouch", NativeConditions.evaluate("oppposelaying", _p({"opponent_pose": "crouch"})), false)

    # ---- oppnotblocking (IsBlocking gid_block) ----------------------------
    _ck("notblocking_false_when_blocking", NativeConditions.evaluate("oppnotblocking", _p({
        "opponent_blocking": true})), false)
    _ck("notblocking_true_when_free", NativeConditions.evaluate("oppnotblocking", _p({
        "opponent_blocking": false})), true)

    # ---- grabdistance (0x1a3d08, radii + 25.0f) ---------------------------
    _ck("grabdistance_eq", NativeConditions.evaluate("grabdistance", _p({
        "distance": 90.0, "opponent_radius": 40.0, "self_radius": 25.0})), true)
    _ck("grabdistance_over", NativeConditions.evaluate("grabdistance", _p({
        "distance": 90.1, "opponent_radius": 40.0, "self_radius": 25.0})), false)
    _ck("grabdistance_slack_is_25", NativeConditions.evaluate("grabdistance", _p({
        "distance": 65.0, "opponent_radius": 40.0, "self_radius": 25.0})), true)
    _ck("grabdistance_slack_26", NativeConditions.evaluate("grabdistance", _p({
        "distance": 91.0, "opponent_radius": 40.0, "self_radius": 25.0})), false)

    # ---- rage (0x1a434c/0x1a4360/0x1a4374) --------------------------------
    _ck("ragethird_32.9", NativeConditions.evaluate("ragethird", _p({"self_rage": 32.9})), false)
    _ck("ragethird_33", NativeConditions.evaluate("ragethird", _p({"self_rage": 33.0})), true)
    _ck("ragethird_forced", NativeConditions.evaluate("ragethird", _p({
        "self_rage": 0.0, "self_rage_forced": true})), true)
    _ck("rage2thirds_65.9", NativeConditions.evaluate("rage2thirds", _p({"self_rage": 65.9})), false)
    _ck("rage2thirds_66", NativeConditions.evaluate("rage2thirds", _p({"self_rage": 66.0})), true)
    _ck("maxrage_99", NativeConditions.evaluate("maxrage", _p({"self_rage": 99.0})), false)
    _ck("maxrage_100", NativeConditions.evaluate("maxrage", _p({"self_rage": 100.0})), true)

    # ---- countertime (IsInCounterTime 0x1b0380) ---------------------------
    _ck("countertime_false", NativeConditions.evaluate("countertime", _p({"counter_open": false})), false)
    _ck("countertime_true", NativeConditions.evaluate("countertime", _p({"counter_open": true})), true)

    # ---- oppattack records: +0x164 vs +0x168 ------------------------------
    var active_med: Dictionary = _rec({"height": "medium", "strength": "hard", "direction": "fromleft"})
    var next_high: Dictionary = _rec({"id": 1, "height": "high", "strength": "brutal", "direction": "fromabove"})
    for spec: Array in [
        ["oppattackheightmed", active_med, next_high, true],
        ["oppattackheightlow", active_med, next_high, false],
        ["oppattackheighthigh", active_med, next_high, true],
        ["oppattackstrengthhard", active_med, next_high, true],
        ["oppattackstrengthbrutal", active_med, next_high, false],
        ["oppattackdirfromleft", active_med, next_high, true],
        ["oppattackdirfrontal", active_med, next_high, false],
    ]:
        _ck("record_%s" % spec[0], NativeConditions.evaluate(spec[0], _p({
            "opponent_active_impact": spec[1], "opponent_next_impact": spec[2]})), spec[3])
    # Height-high reads +0x168 only: no active record but a high next record is
    # TRUE; medium with the same inputs is FALSE.  This is the native asymmetry.
    _ck("high_uses_next_only", NativeConditions.evaluate("oppattackheighthigh", _p({
        "opponent_active_impact": null, "opponent_next_impact": next_high})), true)
    _ck("med_uses_active_only", NativeConditions.evaluate("oppattackheightmed", _p({
        "opponent_active_impact": null, "opponent_next_impact": active_med})), false)
    _ck("high_no_next_false", NativeConditions.evaluate("oppattackheighthigh", _p({
        "opponent_active_impact": next_high, "opponent_next_impact": null})), false)

    # ---- oppattackdirfromair ----------------------------------------------
    _ck("dirfromair_true", NativeConditions.evaluate("oppattackdirfromair", _p({
        "opponent_active_impact": _rec({"direction": "fromair"})})), true)
    _ck("dirfromair_false", NativeConditions.evaluate("oppattackdirfromair", _p({
        "opponent_active_impact": _rec({"direction": "frontal"})})), false)

    # ---- recovered but unused tokens --------------------------------------
    _ck("abouttograb_15", NativeConditions.evaluate("oppabouttograb", _p({
        "opponent_about_to_grab": true, "distance": 80.0,
        "opponent_radius": 40.0, "self_radius": 25.0})), true)
    _ck("abouttograb_over", NativeConditions.evaluate("oppabouttograb", _p({
        "opponent_about_to_grab": true, "distance": 80.1,
        "opponent_radius": 40.0, "self_radius": 25.0})), false)
    _ck("abouttograb_not", NativeConditions.evaluate("oppabouttograb", _p({
        "opponent_about_to_grab": false})), false)
    _ck("oppinfront_pos", NativeConditions.evaluate("oppinfront", _p({"relative_facing_dot": 0.5})), true)
    _ck("oppinback_neg", NativeConditions.evaluate("oppinback", _p({"relative_facing_dot": -0.5})), true)
    _ck("oppinfront_neg_false", NativeConditions.evaluate("oppinfront", _p({"relative_facing_dot": -0.5})), false)

    # ---- impact_selection (+0x164 / +0x168) -------------------------------
    var records: Array = [
        {"id": 0, "start": 5, "end": 8, "radius": 70.0, "height": "medium"},
        {"id": 1, "start": 12, "end": 15, "radius": 70.0, "height": "high"},
    ]
    var before: Dictionary = NativeConditions.impact_selection(records, 2.0)
    _ck("select_before_active_null", before.get("active"), null)
    _ck("select_before_next_0", int(Dictionary(before.get("next", {})).get("id", -1)), 0)
    var in_first: Dictionary = NativeConditions.impact_selection(records, 6.0)
    _ck("select_in_active_0", int(Dictionary(in_first.get("active", {})).get("id", -1)), 0)
    _ck("select_in_next_0", int(Dictionary(in_first.get("next", {})).get("id", -1)), 0)
    var between: Dictionary = NativeConditions.impact_selection(records, 10.0)
    _ck("select_between_active_null", between.get("active"), null)
    _ck("select_between_next_1", int(Dictionary(between.get("next", {})).get("id", -1)), 1)
    var after: Dictionary = NativeConditions.impact_selection(records, 20.0)
    _ck("select_after_active_null", after.get("active"), null)
    _ck("select_after_next_null", after.get("next"), null)


func _set_attack_frame(fighter: PortFighter, kind: String, frame: float) -> void:
    if not fighter.ATTACKS.has(kind):
        return
    var details: Dictionary = fighter.ATTACKS[kind]
    var rate: float = PortFighter.SOURCE_FRAME_RATE
    var startup: int = int(round(float(details["startup"]) * rate))
    var active: int = int(round(float(details["active"]) * rate))
    var recovery: int = int(round(float(details["recovery"]) * rate))
    fighter.attack_kind = kind
    if frame < float(startup):
        fighter.state = "startup"
        fighter.state_time = maxf(float(startup) - frame, 0.0) / rate
    elif frame < float(startup + active):
        fighter.state = "active"
        fighter.state_time = maxf(float(startup + active) - frame, 0.0) / rate
    else:
        fighter.state = "recovery"
        fighter.state_time = maxf(float(startup + active + recovery) - frame, 0.0) / rate
    fighter._attack_hit_landed = false
    fighter._multi_impact_applied.clear()


func _place(fighter: PortFighter, other: PortFighter, source_distance: float) -> void:
    var world_gap: float = source_distance * fighter.source_units_to_world
    fighter.position = Vector3(0.0, 1.2, 0.0)
    other.position = Vector3(world_gap, 1.2, 0.0)


func _integration(glb: String) -> void:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", glb)
    OS.set_environment("BRUCELEE_OPPONENT_GLB", "")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)
    player.opponent = computer
    computer.opponent = player
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    computer.reset_fighter(Vector3(0.0, 1.2, 0.0))

    # impact: live window + reach + high-water through the real adapter.
    # lowpunch3 (the Bruce "punch" row) has damage_time [8, 11].
    _set_attack_frame(computer, "punch", 9.0)
    _place(player, computer, 0.0)
    _ck("int_impact_true", player._native_condition_ok("impact", {}), true)
    _place(player, computer, 200.0)
    _ck("int_impact_far", player._native_condition_ok("impact", {}), false)
    _place(player, computer, 0.0)
    computer._attack_hit_landed = true
    _ck("int_impact_spent", player._native_condition_ok("impact", {}), false)
    computer._attack_hit_landed = false

    # +0x168 height-high: highkick3's damage_time starts at 10; frame 5 is
    # before the first record, yet the upcoming record is high -> TRUE.
    _set_attack_frame(computer, "high_kick3", 5.0)
    _place(player, computer, 0.0)
    _ck("int_height_high_next", player._native_condition_ok("oppattackheighthigh", {}), true)
    _ck("int_height_med_before_impact", player._native_condition_ok("oppattackheightmed", {}), false)
    _set_attack_frame(computer, "high_kick3", 11.0)
    _ck("int_height_high_active", player._native_condition_ok("oppattackheighthigh", {}), true)

    # grabdistance boundary through the adapter (radii + 25 source units).
    _set_attack_frame(computer, "punch", 9.0)
    var slack_distance: float = (
        player.source_radius_for_current_animation()
        + computer.source_radius_for_current_animation() + 25.0
    )
    _place(player, computer, slack_distance - 0.5)
    _ck("int_grabdistance_in", player._native_condition_ok("grabdistance", {}), true)
    _place(player, computer, slack_distance + 1.0)
    _ck("int_grabdistance_out", player._native_condition_ok("grabdistance", {}), false)

    # healthzero uses the attacker's damage, not the defender's current health.
    var damage: float = float(computer.ATTACKS["punch"]["damage"])
    player.health = damage
    _ck("int_healthzero_eq", player._native_condition_ok("healthzero", {}), true)
    player.health = damage + 1.0
    _ck("int_healthzero_survive", player._native_condition_ok("healthzero", {}), false)
    player.health = 100.0

    # countertime through the opponent animation's counter_time window ([0,8]).
    _set_attack_frame(computer, "punch", 0.0)
    _ck("int_countertime_frame0", player._native_condition_ok("countertime", {}), true)
    _set_attack_frame(computer, "punch", 30.0)
    _ck("int_countertime_late", player._native_condition_ok("countertime", {}), false)

    # rage thresholds through the adapter.
    player.rage = 32.0
    _ck("int_ragethird_32", player._native_condition_ok("ragethird", {}), false)
    player.rage = 33.0
    _ck("int_ragethird_33", player._native_condition_ok("ragethird", {}), true)
    player.rage = 65.0
    _ck("int_rage2thirds_65", player._native_condition_ok("rage2thirds", {}), false)
    player.rage = 66.0
    _ck("int_rage2thirds_66", player._native_condition_ok("rage2thirds", {}), true)
    player.rage = 0.0

    # pose: the exported action row is authoritative.  "stun" action pose is
    # stun; a hit reaction animation's pose is stand.
    computer.attack_kind = ""
    computer.state = "stun"
    computer.state_time = 0.0
    _ck("int_oppposestun_true", player._native_condition_ok("oppposestun", {}), true)
    _ck("int_oppposestand_false", player._native_condition_ok("oppposestand", {}), false)
    computer.state = "idle"
    computer.state_time = 0.0
    _ck("int_oppposestand_idle", player._native_condition_ok("oppposestand", {}), true)

    # Unknown token through the adapter still fails closed.
    _ck("int_unknown_false", player._native_condition_ok("not_a_condition", {}), false)

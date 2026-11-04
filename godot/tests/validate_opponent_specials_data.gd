extends SceneTree
## Headless data-contract validation for the opponent-specific special/endattack
## port attack kinds (isolated copy).
##
## For every per-character fighting-set config this asserts:
##   * the config parses through PortFighter with no fail-closed error;
##   * the recovered special/endattack kinds exist and map to the recovered
##     source action + clip + frame count;
##   * FightStats.categories_for_action(action_for_kind(...)) returns the
##     recovered "special" / "endmove" category;
##   * Lo Ming's own recovered `specialpunchhigh loming` row (m04_e02_pnch_high_03,
##     96 frames, two impacts 6 + 9) is the port kind, and the SinFu-borrowed
##     miss/hit slots are gone;
##   * a tampered Lo Ming animation name fails closed.

const Fighter = preload("res://scripts/fighter.gd")
const FightStats = preload("res://scripts/fight_stats.gd")

# config -> {special: {kind: carries the recovered "special" category},
#            endattack: kind}
const CASES: Dictionary = {
    "res://data/attack_config_chief.json": {
        "special": {"special_kick_high": true},
        "endattack": "endattack",
    },
    "res://data/attack_config_johnson.json": {
        "special": {"special_kick_high_brick": true},
        "endattack": "endattack_brick",
    },
    "res://data/attack_config_ken.json": {
        "special": {"special_kick_high": true},
        "endattack": "endattack",
    },
    "res://data/attack_config_loming.json": {
        "special": {"special_kick_high": true, "special_punch_high": true},
        "endattack": "endattack",
    },
    "res://data/attack_config_master.json": {
        "special": {"special_kick_high": true},
        "endattack": "endattack",
    },
    "res://data/attack_config_shenlo.json": {
        "special": {"special_kick_high": true},
        "endattack": "endattack",
    },
    "res://data/attack_config_sinfu.json": {
        # specialpunchhighmiss sinfu carries only ["attack"] in kungfu.set, so
        # the port must NOT record the special category for it.
        "special": {
            "special_kick_high": true,
            "special_punch_high_miss": false,
            "special_punch_high_hit": true,
        },
        "endattack": "endattack",
    },
    "res://data/attack_config_smallboy.json": {
        "special": {"special_kick_high_brick": true},
        "endattack": "endattack_brick",
    },
    "res://data/fighting_set_m03_mapped_attacks.json": {
        "special": {"special_kick_high_brick": true},
        "endattack": "endattack_brick",
    },
}


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("OPPONENT_SPECIALS_DATA_FAIL: " + message)
    quit(1)


func _run() -> void:
    var report: Dictionary = {}
    for path: String in CASES:
        var case: Dictionary = CASES[path]
        var fighter = Fighter.new()
        fighter.configure("probe", false, Color.WHITE)
        fighter.configure_attack_config(path)
        root.add_child(fighter)
        await process_frame
        if not fighter.attack_config_error.is_empty():
            _fail(path + " failed closed: " + fighter.attack_config_error)
            return
        var kinds: Dictionary = {}
        var expected_specials: Dictionary = case["special"]
        for kind_value: Variant in expected_specials.keys():
            var kind: String = String(kind_value)
            var expect_special: bool = bool(expected_specials[kind])
            if not fighter.ATTACKS.has(kind):
                _fail(path + " lacks attack kind " + kind)
                return
            var row: Dictionary = fighter.ATTACKS[kind]
            var action: String = FightStats.action_for_kind(
                    fighter.ATTACKS, kind)
            var categories: Array = FightStats.categories_for_action(action)
            if expect_special and not categories.has("special"):
                _fail("%s/%s maps to %s with no recovered special category %s"
                        % [path, kind, action, JSON.stringify(categories)])
                return
            if not expect_special and categories.has("special"):
                _fail("%s/%s maps to %s but the recovered set row has no special category"
                        % [path, kind, action])
                return
            kinds[kind] = {
                "source_action": action,
                "animation": String(row.get("animation", "")),
                "frames": int(row.get("animation_frame_count", -1)),
                "special_category": expect_special,
            }
        var endattack: String = String(case["endattack"])
        if not fighter.ATTACKS.has(endattack):
            _fail(path + " lacks attack kind " + endattack)
            return
        var end_row: Dictionary = fighter.ATTACKS[endattack]
        var end_action: String = FightStats.action_for_kind(fighter.ATTACKS, endattack)
        var end_categories: Array = FightStats.categories_for_action(end_action)
        if not end_categories.has("endmove"):
            _fail("%s/%s maps to %s with no recovered endmove category %s"
                    % [path, endattack, end_action, JSON.stringify(end_categories)])
            return
        kinds[endattack] = {
            "source_action": end_action,
            "animation": String(end_row.get("animation", "")),
            "frames": int(end_row.get("animation_frame_count", -1)),
        }
        report[path] = {
            "attack_count": fighter.ATTACKS.size(),
            "kinds": kinds,
        }
        fighter.queue_free()
        await process_frame

    # ---- Lo Ming's own recovered specialpunchhigh loming row ----
    var loming = Fighter.new()
    loming.configure("probe", false, Color.WHITE)
    loming.configure_attack_config("res://data/attack_config_loming.json")
    root.add_child(loming)
    await process_frame
    if not loming.attack_config_error.is_empty():
        _fail("loming failed closed: " + loming.attack_config_error)
        return
    if loming.ATTACKS.has("special_punch_high_miss") or loming.ATTACKS.has("special_punch_high_hit"):
        _fail("loming still carries the borrowed SinFu miss/hit special punch high")
        return
    if not loming.ATTACKS.has("special_punch_high"):
        _fail("loming lacks the recovered special_punch_high kind")
        return
    var loming_row: Dictionary = loming.ATTACKS["special_punch_high"]
    if (String(loming_row["source_action"]) != "specialpunchhigh loming"
            or String(loming_row["animation"]) != "m04_e02_pnch_high_03"
            or int(loming_row["animation_frame_count"]) != 96
            or absf(float(loming_row["damage"]) - 15.0) > 0.001
            or absf(float(loming_row["animation_radius"]) - 55.0) > 0.001):
        _fail("loming special_punch_high does not match specialpunchhigh loming: "
                + JSON.stringify(loming_row))
        return
    var multi: Array = loming_row["multi_impacts"]
    if multi.size() != 2:
        _fail("loming special_punch_high must carry the two recovered impact windows")
        return
    if (int(multi[0]["damage_time"][0]) != 7 or int(multi[0]["damage_time"][1]) != 9
            or absf(float(multi[0]["damage"]) - 6.0) > 0.001
            or absf(float(multi[0]["attack_radius"]) - 80.0) > 0.001
            or String(multi[0]["body_part"]) != "larm"
            or String(multi[0]["strength"]) != "normal"
            or String(multi[0]["direction"]) != "fromleft"):
        _fail("loming first impact does not match the recovered row: "
                + JSON.stringify(multi[0]))
        return
    if (int(multi[1]["damage_time"][0]) != 13 or int(multi[1]["damage_time"][1]) != 15
            or absf(float(multi[1]["damage"]) - 9.0) > 0.001
            or String(multi[1]["body_part"]) != "rarm"
            or String(multi[1]["strength"]) != "hard"
            or String(multi[1]["direction"]) != "frontal"):
        _fail("loming second impact does not match the recovered row: "
                + JSON.stringify(multi[1]))
        return
    # Phase sum must close exactly on the ANM frame count.
    var startup: int = int(round(float(loming_row["startup"]) * Fighter.SOURCE_FRAME_RATE))
    var active: int = int(round(float(loming_row["active"]) * Fighter.SOURCE_FRAME_RATE))
    var recovery: int = int(round(float(loming_row["recovery"]) * Fighter.SOURCE_FRAME_RATE))
    if startup != 7 or active != 9 or recovery != 80:
        _fail("loming special_punch_high phases are %d/%d/%d, expected 7/9/80"
                % [startup, active, recovery])
        return
    var specials_categories: Array = FightStats.categories_for_action(
            "specialpunchhigh loming")
    if not specials_categories.has("special"):
        _fail("fight stats table has no special category for specialpunchhigh loming")
        return
    loming.queue_free()
    await process_frame

    # ---- Tampering the recovered animation must fail closed ----
    var text: String = FileAccess.get_file_as_string("res://data/attack_config_loming.json")
    var parsed: Variant = JSON.parse_string(text)
    if not parsed is Dictionary:
        _fail("loming config is not valid JSON")
        return
    var tampered_config: Dictionary = parsed
    tampered_config["attacks"]["special_punch_high"]["animation"] = "m04_sp_pnch_high"
    var tampered = Fighter.new()
    tampered.configure("tampered", false, Color.WHITE)
    tampered.configure_attack_config("res://data/attack_config_loming.json")
    var tampered_result: Dictionary = tampered._parse_attack_config(tampered_config)
    if not tampered_result.is_empty():
        _fail("tampered loming special animation was accepted")
        return
    if not tampered.attack_config_error.contains("does not match recovered kungfu.set"):
        _fail("tampered loming config reported the wrong error: "
                + tampered.attack_config_error)
        return
    tampered.queue_free()
    await process_frame

    print("OPPONENT_SPECIALS_DATA_OK=" + JSON.stringify({
        "configs": report.size(),
        "loming_special_punch_high": {
            "source_action": "specialpunchhigh loming",
            "animation": "m04_e02_pnch_high_03",
            "frames": 96,
            "damage": 15.0,
            "impacts": 2,
        },
        "tamper_rejected": true,
    }))
    quit(0)

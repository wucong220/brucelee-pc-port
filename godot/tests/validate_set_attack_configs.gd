extends SceneTree
## Headless check that the mapped per-character attack configs parse and match
## the recovered fighting-set tables. No candidate GLB is required: this covers
## the data contract (frames, damage, radius, animation, reactions) that the
## integration patch installs for Master, SinFu and Ken.

const Fighter = preload("res://scripts/fighter.gd")

const CASES: Dictionary = {
    "res://data/attack_config_master.json": {
        "slots": 27,
        "source_archive": "kungfu.set",
        "checks": {
            "punch": ["lowpunch3", "m04_pnch_low_03", 71, 10, 6, 55, 7.0, 85.0],
            "high_punch": ["highpunch1", "m04_pnch_high_01", 68, 6, 5, 57, 5.0, 75.0],
            "special_kick_high": ["specialkickhigh master", "m04_e01_kck_high_03", 73, 14, 3, 56, 12.0, 95.0],
            "special_punch_low": ["specialpunchlow master", "m04_e01_pnch_low_03", 82, 4, 25, 53, 16.0, 65.0],
            "grab1": ["grab1 master", "m04_sp_pnch_low", 28, 7, 2, 19, 20.0, 45.0],
            "endattack": ["endattack master", "m04_end_attack_02", 75, 37, 4, 34, 0.0, 75.0],
        },
    },
    "res://data/attack_config_sinfu.json": {
        "slots": 28,
        "source_archive": "kungfu.set",
        "checks": {
            "low_kick3": ["lowkick3", "m04_kck_low_02", 34, 6, 4, 24, 7.0, 100.0],
            "special_punch_high_miss": ["specialpunchhighmiss sinfu", "m04_sp_pnch_high_fail", 71, 10, 3, 58, 0.0, 40.0],
            "special_punch_high_hit": ["specialpunchhighhit sinfu", "m04_sp_pnch_high", 50, 11, 12, 27, 20.0, 45.0],
            "grab2": ["grab2 sinfu", "m04_sp_kck_low", 55, 12, 12, 31, 20.0, 45.0],
        },
    },
    "res://data/attack_config_ken.json": {
        "slots": 26,
        "source_archive": "karate.set",
        "checks": {
            "punch": ["lowpunch3", "m02_pnch_low_03", 57, 14, 7, 36, 7.0, 70.0],
            "high_punch3": ["highpunch3", "m02_pnch_high_02", 20, 8, 4, 8, 7.0, 80.0],
            "low_kick": ["lowkick1", "m02_kck_low_01", 26, 5, 4, 17, 4.0, 65.0],
            "special_kick_high": ["specialkickhigh ken", "m02_sp_kck_high", 48, 20, 4, 24, 13.0, 75.0],
            "special_punch_low": ["specialpunchlow ken", "m02_sp_pnch_low", 47, 8, 15, 24, 14.0, 60.0],
            "grab2": ["grab2 ken", "m02_grab_02", 98, 65, 6, 27, 20.0, 45.0],
            "endattack": ["endattack ken", "m02_end_attack_01", 132, 18, 1, 113, 0.0, 45.0],
        },
    },
}


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    for path: String in CASES:
        var case: Dictionary = CASES[path]
        var fighter = Fighter.new()
        fighter.configure("check", false, Color.WHITE)
        fighter.configure_attack_config(path)
        root.add_child(fighter)
        await process_frame
        if not fighter.attack_config_error.is_empty():
            _fail(path + " failed closed: " + fighter.attack_config_error)
            return
        if fighter.ATTACKS.size() != int(case["slots"]):
            _fail("%s loaded %d attacks, expected %d"
                    % [path, fighter.ATTACKS.size(), int(case["slots"])])
            return
        if fighter.REACTION_PROFILES.size() != 2:
            _fail(path + " reaction profiles did not load")
            return
        var checks: Dictionary = case["checks"]
        for slot: String in checks:
            if not fighter.ATTACKS.has(slot):
                _fail(path + " lacks slot " + slot)
                return
            var row: Array = checks[slot]
            var details: Dictionary = fighter.ATTACKS[slot]
            var expected_frames: int = int(row[2])
            var expected_startup: int = int(row[3])
            var expected_active: int = int(row[4])
            var expected_recovery: int = int(row[5])
            var actual_startup: int = int(round(float(details["startup"]) * Fighter.SOURCE_FRAME_RATE))
            var actual_active: int = int(round(float(details["active"]) * Fighter.SOURCE_FRAME_RATE))
            var actual_recovery: int = int(round(float(details["recovery"]) * Fighter.SOURCE_FRAME_RATE))
            var impact: Dictionary = details["source_impact"]
            if (String(details["source_action"]) != String(row[0])
                    or String(details["animation"]) != String(row[1])
                    or int(details["animation_frame_count"]) != expected_frames
                    or actual_startup != expected_startup
                    or actual_active != expected_active
                    or actual_recovery != expected_recovery
                    or absf(float(details["damage"]) - float(row[6])) > 0.001
                    or absf(float(impact["attack_radius"]) - float(row[7])) > 0.001):
                _fail("%s/%s does not match the recovered set row: %s"
                        % [path, slot, JSON.stringify(details)])
                return
            if actual_startup + actual_active + actual_recovery != expected_frames:
                _fail("%s/%s phases do not sum to the clip length" % [path, slot])
                return
        # A multi-impact action must expose every recovered damage window.
        if path.ends_with("attack_config_ken.json"):
            var multi: Array = fighter.ATTACKS["special_punch_low"]["multi_impacts"]
            if multi.size() != 2:
                _fail("ken special_punch_low did not load two impacts")
                return
            if (int(multi[0]["damage_time"][0]) != 8
                    or int(multi[1]["damage_time"][1]) != 22):
                _fail("ken special_punch_low impact windows are wrong")
                return
        fighter.queue_free()
        await process_frame
    # Tampering with a recovered frame count must fail closed.
    var tampered = Fighter.new()
    tampered.configure("tampered", false, Color.WHITE)
    tampered.configure_attack_config("res://data/attack_config_ken.json")
    var text: String = FileAccess.get_file_as_string("res://data/attack_config_ken.json")
    var parsed: Variant = JSON.parse_string(text)
    if not parsed is Dictionary:
        _fail("ken config is not valid JSON")
        return
    var config: Dictionary = parsed
    # Keep the phase sum intact so the tamper reaches the recovered-row check.
    config["attacks"]["high_punch3"]["startup_frames"] = 7
    config["attacks"]["high_punch3"]["active_frames"] = 5
    if not tampered._parse_attack_config(config).is_empty():
        _fail("tampered ken startup frame was accepted")
        return
    if not tampered.attack_config_error.contains("does not match recovered karate.set frames"):
        _fail("tampered config reported the wrong error: " + tampered.attack_config_error)
        return
    tampered.queue_free()
    print("SET_ATTACK_CONFIG_VALIDATION=" + JSON.stringify({
        "configs": CASES.keys(),
        "tamper_rejected": true,
    }))
    quit(0)


func _fail(message: String) -> void:
    push_error(message)
    quit(1)

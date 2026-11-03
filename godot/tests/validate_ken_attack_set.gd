extends SceneTree
## Ken (karate.set) runtime check with the real candidate GLB: every recovered
## slot must request, play its own m02 animation, and report the set's frames.
## Run: godot --headless --path godot --script res://tests/validate_ken_attack_set.gd -- <ken.glb>

const Fighter = preload("res://scripts/fighter.gd")

const EXPECTED: Dictionary = {
    "punch": "m02_pnch_low_03",
    "kick": "m02_kck_low_03",
    "high_punch": "m02_pnch_high_01",
    "high_punch2": "m02_pnch_high_03",
    "high_punch3": "m02_pnch_high_02",
    "low_punch": "m02_pnch_low_01",
    "low_punch2": "m02_pnch_low_02",
    "low_punch3": "m02_pnch_low_03",
    "high_kick": "m02_kck_high_01",
    "high_kick2": "m02_kck_high_03",
    "high_kick3": "m02_kck_high_02",
    "low_kick": "m02_kck_low_01",
    "low_kick2": "m02_kck_low_02",
    "low_kick3": "m02_kck_low_03",
    "special_kick_high": "m02_sp_kck_high",
    "special_kick_low": "m02_sp_kck_low",
    "special_punch_high": "m02_sp_pnch_high",
    "special_punch_low": "m02_sp_pnch_low",
    "parry_high": "m02_parry_high",
    "parry_attack": "m02_pnch_low_03",
    "grab1": "m02_grab_01",
    "grab2": "m02_grab_02",
    "grab1_miss": "m02_grab_01",
    "grab2_miss": "m02_grab_01",
    "attack_to_floor": "m02_attack_to_floor",
    "endattack": "m02_end_attack_01",
}


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty():
        push_error("Ken candidate GLB path required")
        quit(1)
        return
    var ken = Fighter.new()
    ken.configure("ken", false, Color.WHITE)
    ken.set_physics_process(false)
    ken.configure_attack_config(Fighter.KEN_ATTACK_CONFIG_PATH)
    ken.configure_candidate_asset(args[0], "", Fighter.KEN_CLIPS, "body_hair")
    root.add_child(ken)
    await process_frame
    if not ken.attack_config_error.is_empty():
        push_error("Ken attack config failed closed: " + ken.attack_config_error)
        quit(1)
        return
    if ken.ATTACKS.size() != EXPECTED.size():
        push_error("Ken attack set loaded %d slots, expected %d"
                % [ken.ATTACKS.size(), EXPECTED.size()])
        quit(1)
        return
    if not ken.candidate_loaded:
        push_error("Ken candidate failed: " + ken.candidate_load_error)
        quit(1)
        return
    for action: String in EXPECTED:
        ken.reset_fighter(Vector3(0.0, 1.20, 0.0))
        if not ken.supports_attack(action):
            push_error("Ken candidate does not support " + action)
            quit(1)
            return
        if not ken.request_attack(action):
            push_error("Ken request failed for " + action)
            quit(1)
            return
        ken._animate_candidate()
        if ken.candidate_animation_clip != String(EXPECTED[action]):
            push_error("Ken clip mismatch for %s: %s" % [action, ken.candidate_animation_clip])
            quit(1)
            return
    # A real swing must connect at the recovered distance and deal the
    # recovered damage during the recovered active window.
    var target = Fighter.new()
    target.configure("target", true, Color.WHITE)
    target.configure_attack_config(Fighter.ATTACK_CONFIG_PATH)
    root.add_child(target)
    await process_frame
    ken.opponent = target
    target.opponent = ken
    ken.reset_fighter(Vector3(0.0, 1.20, 0.0))
    target.reset_fighter(Vector3(0.6, 1.20, 0.0))
    ken.facing = 1
    var starting_health: float = target.health
    var expected_damage: float = float(ken.ATTACKS["high_punch"]["damage"])
    if not ken.request_attack("high_punch"):
        push_error("Ken high_punch request failed")
        quit(1)
        return
    ken._advance_timed_states(float(ken.ATTACKS["high_punch"]["startup"]))
    ken._try_attack_contact()
    if absf((starting_health - target.health) - expected_damage) > 0.001:
        push_error("Ken high_punch damage was %f, expected %f"
                % [starting_health - target.health, expected_damage])
        quit(1)
        return
    print("KEN_ATTACK_SET_VALIDATION=" + JSON.stringify({
        "slots": EXPECTED.size(),
        "config_attacks": ken.ATTACKS.size(),
        "high_punch_damage": starting_health - target.health,
    }))
    ken.queue_free()
    target.queue_free()
    await process_frame
    quit(0)

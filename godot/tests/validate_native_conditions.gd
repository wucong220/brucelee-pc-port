extends SceneTree
## Direct checks of the recovered native link conditions.

const IMPACT_CONDITIONS: Array = [
    ["oppattackheightlow", "height", "low"],
    ["oppattackheightmed", "height", "medium"],
    ["oppattackheighthigh", "height", "high"],
    ["oppattackstrengthnormal", "strength", "normal"],
    ["oppattackstrengthmedium", "strength", "medium"],
    ["oppattackstrengthhard", "strength", "hard"],
    ["oppattackstrengthbrutal", "strength", "brutal"],
    ["oppattackdirfrontal", "direction", "frontal"],
    ["oppattackdirfromleft", "direction", "fromleft"],
    ["oppattackdirfromright", "direction", "fromright"],
    ["oppattackdirfromabove", "direction", "fromabove"],
]


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the Bruce candidate GLB")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
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

    var checks: Dictionary = {}
    var dummy_link: Dictionary = {"to": "grab1"}

    # Every oppattack condition must match the exported impact of the
    # opponent's current action, whatever action that resolves to.
    for kind: String in ["punch", "high_kick3", "punch2" if computer.ATTACKS.has("punch2") else "punch"]:
        if not computer.ATTACKS.has(kind):
            continue
        computer.attack_kind = kind
        computer.state = "startup"
        computer.state_time = float(computer.ATTACKS[kind]["startup"])
        var action: String = computer._current_action_name()
        var impact: Dictionary = player._native_actions.get(action, {}).get("impact", {})
        if impact.is_empty():
            continue
        for spec: Array in IMPACT_CONDITIONS:
            var condition: String = spec[0]
            var expected: bool = String(impact.get(spec[1], "")) == String(spec[2])
            var actual: bool = player._native_condition_ok(condition, dummy_link)
            checks[kind + ":" + condition] = actual == expected
            if actual != expected:
                push_error("Impact condition mismatch " + kind + " " + condition)
                quit(1)
                return

    # grab_distance is stored per target action (grab1 = 70 source units).
    player.position = Vector3(0.0, 1.2, 0.0)
    computer.position = Vector3(0.5, 1.2, 0.0)
    player.opponent = computer
    checks["grab_in_range"] = player._native_condition_ok("grabdistance", dummy_link)
    computer.position = Vector3(2.0, 1.2, 0.0)
    checks["grab_out_of_range_false"] = not player._native_condition_ok("grabdistance", dummy_link)

    # Rage gates.
    player.rage = 40.0
    checks["ragethird_40"] = player._native_condition_ok("ragethird", dummy_link)
    player.rage = 20.0
    checks["ragethird_20_false"] = not player._native_condition_ok("ragethird", dummy_link)
    player.rage = 70.0
    checks["rage2thirds_70"] = player._native_condition_ok("rage2thirds", dummy_link)

    # counter_time uses the opponent's attack window (lowpunch1 = [0,8]).
    computer.reset_fighter(Vector3(0.4, 1.2, 0.0))
    computer.attack_kind = "punch"
    computer.state = "startup"
    computer.state_time = float(computer.ATTACKS["punch"]["startup"])
    checks["countertime_frame0"] = player._native_condition_ok("countertime", dummy_link)
    computer.state = "recovery"
    computer.state_time = float(computer.ATTACKS["punch"]["recovery"])
    checks["countertime_late_false"] = not player._native_condition_ok("countertime", dummy_link)

    for key: String in checks.keys():
        if not bool(checks[key]):
            push_error("Native condition failed: " + key)
            quit(1)
            return
    print("NATIVE_CONDITION_VALIDATION=" + JSON.stringify(checks))
    quit(0)

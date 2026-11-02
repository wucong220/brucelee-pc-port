extends SceneTree
## Native parry link: candocounter -> parryhigh (down + toward), then the
## automatic parryattack follow-up.

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
    if not player.candidate_loaded:
        push_error("Parry candidate failed: " + player.candidate_load_error)
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    for required: String in ["parry_high", "parry_attack"]:
        if not clips.has(required):
            push_error("Candidate is missing " + required)
            quit(1)
            return

    var checks: Dictionary = {}

    player.reset_fighter(Vector3(-0.25, 1.2, 0.0))
    computer.reset_fighter(Vector3(0.25, 1.2, 0.0))
    player.health = 9999.0
    player.rage = 100.0
    computer.health = 9999.0
    # The opponent is at its attack's first frame: the recovered counter_time
    # window is [0,0], so that single frame is the counter condition.
    computer.attack_kind = "high_punch"
    computer.state = "startup"
    computer.state_time = float(computer.ATTACKS["high_punch"]["startup"])
    player.record_standing_combo_press("down")
    player.record_standing_combo_press("right")
    checks["parry"] = player.attack_kind
    if player.attack_kind != "parry_high":
        push_error("down+toward did not start parry_high: " + player.attack_kind)
        quit(1)
        return

    for _frame: int in range(120):
        player._physics_process(1.0 / 60.0)
    checks["after_parry"] = player.attack_kind

    player.reset_fighter(Vector3(-0.25, 1.2, 0.0))
    player.rage = 100.0
    computer.state = "idle"
    computer.attack_kind = ""
    player.record_standing_combo_press("down")
    player.record_standing_combo_press("right")
    checks["no_attack"] = player.attack_kind
    if player.attack_kind == "parry_high":
        push_error("parry started without an incoming attack")
        quit(1)
        return

    print("PARRY_VALIDATION=" + JSON.stringify(checks))
    quit(0)

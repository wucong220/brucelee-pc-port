extends SceneTree
## The combo window must follow human key gaps, not one strict 0.8s total.
## A sequence is valid while every adjacent press is inside COMBO_MAX_GAP and
## the whole sequence is inside COMBO_MAX_TOTAL.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and Brick candidate GLB paths")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    player.set_physics_process(false)
    computer_idle(scene)

    var cases: Array = [
        {"gap": 0.20, "expect": true},
        {"gap": 0.40, "expect": true},
        {"gap": 0.50, "expect": true},
        {"gap": 0.70, "expect": false},
    ]
    for entry: Dictionary in cases:
        var matched: bool = _press_three(player, float(entry["gap"]))
        if matched != bool(entry["expect"]):
            push_error("gap %.2f matched=%s expected=%s" % [
                float(entry["gap"]), str(matched), str(entry["expect"])
            ])
            quit(1)
            return
    print("COMBO_TIMING_VALIDATION=" + JSON.stringify({
        "max_gap": PortFighter.COMBO_MAX_GAP_SECONDS,
        "max_total": PortFighter.COMBO_MAX_TOTAL_SECONDS,
        "accepted_gaps": [0.20, 0.40, 0.50],
        "rejected_gap": 0.70,
    }))
    quit(0)


func computer_idle(scene: Node) -> void:
    var computer: PortFighter = scene.get("computer")
    computer.set_physics_process(false)
    computer.reset_fighter(Vector3(0.25, 1.20, 0.0))
    computer.health = 9999.0


func _press_three(player: PortFighter, gap: float) -> bool:
    player.reset_fighter(Vector3(-0.25, 1.20, 0.0))
    player.health = 9999.0
    player.rage = 100.0
    for press: int in range(3):
        if not player.record_standing_combo_press("a"):
            player.request_attack_or_queue("punch")
        if press < 2:
            var frames: int = int(round(gap * 60.0))
            for _frame: int in range(frames):
                player._physics_process(1.0 / 60.0)
    var queued: Array = player.get("_queued_attacks")
    return (String(player.get("_standing_combo_pending_attack")) == "high_punch"
            or player.attack_kind == "high_punch"
            or queued.has("high_punch"))

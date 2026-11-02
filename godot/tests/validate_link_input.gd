extends SceneTree
## Link-driven input regression: the decompiled UserControlUpdate model.
## Events carry a consumed bit; links are re-evaluated every physics update
## against the current animation's frame window. There is no wall-clock combo
## window and no FIFO of attacks.

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
    var computer: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)

    player.reset_fighter(Vector3(-0.25, 1.20, 0.0))
    computer.reset_fighter(Vector3(0.25, 1.20, 0.0))
    player.health = 9999.0
    var started: Array[String] = []
    player.attack_started.connect(func(kind: String) -> void: started.append(kind))

    # 1. J J J from neutral: the first press is a real punch and the level-1
    #    window then turns the sequence into the native follow-up. No wall-clock
    #    timer is involved; the link is re-checked every physics update.
    for press: int in range(3):
        if not player.record_standing_combo_press("a"):
            player.request_attack("punch")
        for _frame: int in range(8):
            player._physics_process(1.0 / 60.0)
    for _frame: int in range(120):
        player._physics_process(1.0 / 60.0)
    if started != ["punch", "high_punch2"]:
        push_error("link did not fire the native follow-up: " + str(started))
        quit(1)
        return

    # 2. The current animation's own link wins over the generic a/a/a link.
    player.reset_fighter(Vector3(-0.25, 1.20, 0.0))
    player.health = 9999.0
    player.attack_kind = "high_punch"
    player.state = "recovery"
    player.state_time = 1.5
    player._attack_hit_landed = true
    player._attack_connected = true
    player._animate_candidate()
    started.clear()
    for press: int in range(3):
        player.record_standing_combo_press("a")
        for _frame: int in range(8):
            player._physics_process(1.0 / 60.0)
    if player.attack_kind != "high_punch":
        push_error("native link window did not select high_punch: " + player.attack_kind)
        quit(1)
        return

    # 3. Consumed events must not retrigger the same link.
    var before: int = started.size()
    for _frame: int in range(120):
        player._physics_process(1.0 / 60.0)
    if started.size() != before:
        push_error("consumed events retriggered: " + str(started))
        quit(1)
        return

    print("LINK_INPUT_VALIDATION=" + JSON.stringify({
        "neutral_jjj": ["punch", "high_punch2"],
        "late_window": "high_punch",
        "no_wall_clock_window": true,
        "consumed_events": true,
    }))
    quit(0)

extends SceneTree
## Regression for the input queue: every attack key in a partial sequence must
## produce an attack, and the combo target must be the final queued attack.

const SequenceCases: Dictionary = {
    "aaa": ["a", "a", "a"],
    "bdd": ["b", "d", "d"],
}

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and opponent GLB paths")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)
    for case_name: String in SequenceCases:
        player.reset_fighter(Vector3(0.0, 1.2, 0.0))
        computer.reset_fighter(Vector3(0.3, 1.2, 0.0))
        player.health = 9999.0
        computer.health = 9999.0
        var started: Array[String] = []
        player.attack_started.connect(func(action: String): started.append(action))
        for key: String in SequenceCases[case_name]:
            _press(player, key)
            for _frame: int in range(12):
                player.position = Vector3(0.0, 1.2, 0.0)
                computer.position = Vector3(0.3, 1.2, 0.0)
                player._physics_process(1.0 / 60.0)
        for _frame: int in range(900):
            player.position = Vector3(0.0, 1.2, 0.0)
            computer.position = Vector3(0.3, 1.2, 0.0)
            player._physics_process(1.0 / 60.0)
        if started.size() < 3:
            push_error("Sequence " + case_name + " swallowed an attack: " + str(started))
            quit(1)
            return
        if case_name == "aaa" and started[-1] != "high_punch":
            push_error("A/A/A target was not the final attack: " + str(started))
            quit(1)
            return
        if not player._queued_attacks.is_empty() or player.state not in ["idle", "idle2", "idle3"]:
            push_error("Sequence " + case_name + " did not drain the attack queue")
            quit(1)
            return
        print(case_name + " -> " + str(started))
    print("ATTACK_QUEUE_VALIDATION=" + JSON.stringify({"cases": SequenceCases.keys()}))
    quit(0)


func _press(player: PortFighter, key: String) -> void:
    if key == "a":
        if not player.record_standing_combo_press("a"):
            player.request_attack_or_queue("punch")
    elif key == "b":
        if not player.record_standing_combo_press("b"):
            player.request_attack_or_queue("kick")
    elif key == "c":
        if not player.record_standing_combo_press("c"):
            player.request_attack_or_queue("heavy")
    elif key == "d":
        if not player.record_standing_combo_press("d"):
            player.request_attack_or_queue("kick")

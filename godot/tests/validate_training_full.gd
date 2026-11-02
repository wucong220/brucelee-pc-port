extends SceneTree
## End-to-end move-training driver. Every lesson is entered through the
## training page and then completed with real fighter input calls.

const SEQUENCES: Dictionary = {
    "punch": [["a"]],
    "kick": [["b"]],
    "high_punch": [["a"], ["a"], ["a"]],
    "high_kick": [["b"], ["c"], ["c"]],
    "high_punch2": [["a"], ["a"], ["a"]],
    "low_punch2": [["a"], ["b"], ["b"]],
    "high_kick2": [["b"], ["c"], ["c"]],
    "low_kick2": [["b"], ["d"], ["d"]],
    "high_punch3": [["up", "a"], ["in", "a"], ["in", "a"]],
    "low_punch3": [["down", "a"], ["out", "b"], ["out", "a"]],
    "low_kick3": [["down", "b"], ["out", "d"], ["out", "d"]],
    "high_kick3": [["up", "b"], ["in", "c"], ["in", "c"]],
    "special_kick_high": [["out", "b"], ["in", "c"], ["in", "c"]],
    "special_kick_low": [["left", "b"], ["in", "c"], ["in", "c"]],
    "special_punch_low": [["down", "a"], ["out", "a"], ["out", "a"]],
    "special_punch_high": [["up", "a"], ["up", "a"], ["up", "a"]],
    "grab1": [["left", "a"], ["a"], ["a"]],
    "grab2": [["left", "b"], ["c"], ["c"]],
    "endattack1": [["up", "in", "b"], ["a"], ["a"]],
    "endattack2": [["up", "in", "a"], ["c"], ["c"]],
    "attacktofloor": [["b"], ["c"], ["c"]],
    "facedownattack": [["a"], ["a"], ["a"]],
    "faceupattack": [["a"], ["a"], ["a"]],
    "heavy": [["c"]],
}

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
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
    var training = scene.get("move_training")
    player.set_physics_process(false)
    computer.set_physics_process(false)
    training.open()
    for index: int in range(training.entries.size()):
        var entry: Dictionary = training.entries[index]
        training._start_at(index)
        _play(player, computer, entry)
        var advanced: bool = false
        for _frame: int in range(1000):
            player.position = Vector3(0.0, 1.2, 0.0)
            computer.position = Vector3(0.3, 1.2, 0.0)
            player._physics_process(1.0 / 60.0)
            training._process(1.0 / 60.0)
            if training.current_index > index or training.state == "complete":
                advanced = true
                break
        if not advanced:
            push_error("TRAINING FAILED at " + str(index + 1) + " " + String(entry["id"])
                    + " state=" + player.state + " attack=" + player.attack_kind
                    + " success=" + str(training.success_timer))
            quit(1)
            return
        print("PASS " + str(index + 1) + " " + String(entry["id"]))
    print("FULL_TRAINING_VALIDATION=PASS")
    quit(0)


func _play(player: PortFighter, computer: PortFighter, entry: Dictionary) -> void:
    var id: String = String(entry["id"])
    if id == "parry_high" or id == "parry_low" or id == "parry_attack":
        var kind: String = "parry_high" if id != "parry_low" else "parry_low"
        for _press: int in range(3):
            player.record_parry_press(kind)
        return
    if not SEQUENCES.has(id):
        return
    for step_value: Variant in SEQUENCES[id]:
        var step: Array = step_value
        var key: String = String(step[-1])
        var mods: Array[String] = []
        for token: Variant in step:
            var text: String = String(token)
            if text != key:
                mods.append(text)
        if player.state in ["facedownidle", "faceupidle"]:
            player.record_virtual_press(key)
        elif key == "b":
            var result: int = player.try_attack_to_floor_press("b")
            if result == PortFighter.AttackToFloorInputResult.IGNORED:
                if not player.record_standing_combo_press("b", mods):
                    player.request_attack_or_queue("kick")
        elif key == "c":
            var result: int = player.try_attack_to_floor_press("c")
            if result == PortFighter.AttackToFloorInputResult.IGNORED:
                if not player.record_standing_combo_press("c", mods):
                    player.request_attack_or_queue("heavy")
        elif key == "d":
            var result: int = player.try_attack_to_floor_press("d")
            if result == PortFighter.AttackToFloorInputResult.IGNORED:
                if not player.record_standing_combo_press("d", mods):
                    player.request_attack_or_queue("kick")
        else:
            if not player.record_standing_combo_press("a", mods):
                player.request_attack_or_queue("punch")
        for _frame: int in range(10):
            player.position = Vector3(0.0, 1.2, 0.0)
            computer.position = Vector3(0.3, 1.2, 0.0)
            player._physics_process(1.0 / 60.0)

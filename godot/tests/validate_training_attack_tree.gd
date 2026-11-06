extends SceneTree
## Recovered `training_attack.tree` interpreter: the dummy's random attack
## stream must come from the shipped node graph, not a high/low alternation.
##
##   godot --headless --path godot --script res://tests/validate_training_attack_tree.gd -- <player.glb> <opponent.glb>

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    failures.append(message)
    push_error("TRAINING_ATTACK_TREE_FAIL: " + message)


func _check(condition: bool, message: String) -> bool:
    if not condition:
        _fail(message)
    return condition


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected player and opponent GLB paths")
        quit(1)
        return

    # ---- recovered data shape
    var parsed: Variant = JSON.parse_string(
        FileAccess.get_file_as_string("res://data/native_ai/training_attack_tree.json"))
    if not _check(parsed is Dictionary, "training attack tree JSON missing"):
        _finish()
        return
    var payload: Dictionary = parsed
    var nodes: Dictionary = payload.get("nodes", {})
    _check(nodes.size() == 12, "tree has %d nodes, expected 12" % nodes.size())
    var do_attack: Dictionary = nodes.get("do_attack", {})
    var rolls: Array = do_attack.get("children", [])
    _check(rolls.size() == 2, "do_attack does not have two branches")
    if rolls.size() == 2:
        _check(abs(float(rolls[0].get("param", 0.0)) - 0.1) < 0.000001,
            "attacking branch probability is not the recovered 0.1")
        _check(abs(float(rolls[1].get("param", 0.0)) - 0.1) < 0.000001,
            "idle branch probability is not the recovered 0.1")
    for level: String in ["combo_level1", "combo_level2", "combo_level3"]:
        var node: Dictionary = nodes.get(level, {})
        _check(abs(float(node.get("param", 0.0)) - 4.0) < 0.000001,
            level + " is not the recovered four-way random_number")
        var cases: Array = []
        for child: Variant in Array(node.get("children", [])):
            cases.append(String((child as Dictionary).get("case", "")))
        _check(cases == ["0", "1", "2", "3"],
            level + " cases are " + str(cases))
    _check(String(nodes.get("combo_continue", {}).get("condition", "")) == "my_animation",
        "combo_continue is not the recovered animation lookup")

    # ---- runtime stream
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
    var training = scene.get("move_training")
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    var defense: Dictionary = training.selectable_trainings()[3]
    training.open_select()
    training.current_training = defense
    training.steps = defense["steps"]
    training.state = "active"
    training._start_step(0)
    _check(training._dummy_mode() == "attack",
        "defense step is not using the recovered training_attack tree")
    _check(training._dummy_ai != null, "training attack interpreter did not load")
    if training._dummy_ai == null:
        _finish()
        return
    _check(training._dummy_ai.tree.size() == 12,
        "runtime tree has %d nodes" % training._dummy_ai.tree.size())
    _check(training.get("_dummy_cycle") == null,
        "the old high/low alternation state is still present")

    # Hold the guard so the lesson remains in the block loop and the dummy keeps
    # producing the recovered stream instead of knocking the player down.
    for _frame: int in range(900):
        player.guard_held = true
        player._physics_process(1.0 / 60.0)
        computer._physics_process(1.0 / 60.0)
        training._process(1.0 / 60.0)

    var counts: Dictionary = training._dummy_ai.action_counts
    var types: Array[String] = []
    for key: String in counts:
        types.append(key)
    types.sort()
    _check(types.size() >= 4,
        "random stream only used %d attack kinds: %s" % [types.size(), str(types)])
    _check(types.has("highpunch1") or types.has("highpunch2") or types.has("highpunch3"),
        "stream never used a high punch")
    _check(types.has("lowpunch1") or types.has("lowpunch2") or types.has("lowpunch3"),
        "stream never used a low punch")
    _check(types.has("highkick1") or types.has("highkick2") or types.has("highkick3"),
        "stream never used a high kick")
    _check(types.has("lowkick1") or types.has("lowkick2") or types.has("lowkick3"),
        "stream never used a low kick")
    var level2 := 0
    var level3 := 0
    for key: String in counts:
        if key in ["highpunch2", "lowpunch2", "highkick2", "lowkick2"]:
            level2 += int(counts[key])
        if key in ["highpunch3", "lowpunch3", "highkick3", "lowkick3"]:
            level3 += int(counts[key])
    _check(level2 + level3 > 0,
        "the recovered combo_continue levels never ran")
    _check(training._dummy_ai.decisions.size() > 0,
        "the interpreter produced no decision log")

    print("TRAINING_ATTACK_TREE_VALIDATION=" + JSON.stringify({
        "nodes": nodes.size(),
        "attack_types": types,
        "action_counts": counts,
        "combo_level2": level2,
        "combo_level3": level3,
        "failures": failures,
    }))
    _finish()


func _finish() -> void:
    paused = false
    if failures.is_empty():
        quit(0)
    else:
        quit(1)

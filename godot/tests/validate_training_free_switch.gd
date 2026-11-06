extends SceneTree
## The recovered free-training fighter dock must actually switch the loaded
## opponent and reopen the free sandbox after the existing env/reload path.
##
##   godot --headless --path godot --script res://tests/validate_training_free_switch.gd -- <player.glb> <opponent.glb>

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    failures.append(message)
    push_error("TRAINING_FREE_SWITCH_FAIL: " + message)


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
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    var training = scene.get("move_training")
    training.open()
    training._practice_index = 0
    training._accept_practice()
    training.selected_index = 0
    training._accept_selected()
    training._accept_free_config()

    var entries: Array = training.fighter_dock_entries()
    var shenlo := -1
    for i: int in range(entries.size()):
        if String(entries[i]["opponent"]) == "shenlo":
            shenlo = i
    if not _check(shenlo >= 0, "Shen Lo is missing from the fighter dock"):
        _finish()
        return
    _check(bool(entries[shenlo]["selectable"]), "Shen Lo is not selectable")
    training._fighter_index = shenlo
    training._refresh_select_fighter()
    _check(training._fighter_name.text == "SHEN LO",
        "dock name is " + training._fighter_name.text)
    training._accept_fighter()
    _check(OS.get_environment("BRUCELEE_TRAINING_FREE") == "1",
        "the free-training reload flag was not set")

    var reloaded: Node = null
    for _i: int in range(300):
        await process_frame
        if current_scene != scene:
            reloaded = current_scene
            break
    if not _check(reloaded != null, "the opponent switch did not reload the scene"):
        _finish()
        return

    var free_training = null
    for _i: int in range(300):
        await process_frame
        free_training = reloaded.get("move_training")
        if free_training != null and String(free_training.state) == "free":
            break
    if not _check(free_training != null, "reloaded scene has no training screen"):
        _finish()
        return
    _check(String(free_training.state) == "free",
        "free training did not reopen (state=%s)" % free_training.state)
    _check(String(reloaded.training_current_opponent_key()) == "shenlo",
        "reloaded opponent is " + String(reloaded.training_current_opponent_key()))
    _check(reloaded.training_mode == true, "reloaded training_mode is off")
    _check(OS.get_environment("BRUCELEE_TRAINING_FREE").is_empty(),
        "the free-training reload flag was not consumed")

    print("TRAINING_FREE_SWITCH_VALIDATION=" + JSON.stringify({
        "opponent": String(reloaded.training_current_opponent_key()),
        "state": String(free_training.state),
        "training_mode": reloaded.training_mode == true,
        "flag_cleared": OS.get_environment("BRUCELEE_TRAINING_FREE").is_empty(),
        "failures": failures,
    }))
    _finish()


func _finish() -> void:
    paused = false
    if failures.is_empty():
        quit(0)
    else:
        quit(1)

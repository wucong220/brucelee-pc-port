extends SceneTree
## Drive the move gallery through every catalog entry with no input and report
## which moves start a real animation and which have no playable action.

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
    var gallery = scene.get("move_gallery")
    if gallery == null:
        push_error("Move gallery is missing from the main scene")
        quit(1)
        return
    if gallery.entries.size() != 25:
        push_error("Move gallery catalog is " + str(gallery.entries.size()))
        quit(1)
        return
    scene._on_menu_command("gallery")
    if gallery.state != "active" or scene.hud.visible:
        push_error("Move gallery did not open from the main menu")
        quit(1)
        return
    var failures: Array[String] = []
    for index: int in range(gallery.entries.size()):
        gallery.index = index
        gallery._play_current()
        var entry: Dictionary = gallery.entries[index]
        if not gallery.play_error.is_empty():
            failures.append(String(entry["id"]) + " -> " + gallery.play_error)
        print("GALLERY " + str(index + 1) + " " + String(entry["id"])
                + " state=" + gallery.player.state
                + " kind=" + gallery.player.attack_kind
                + " error=" + gallery.play_error)
    if not failures.is_empty():
        push_error("GALLERY_FAILURES=" + str(failures))
        quit(1)
        return
    var sequence_expectations: Dictionary = {
        "high_punch3": ["punch", "high_punch", "high_punch2", "high_punch3"],
        "special_kick_high": ["stepback", "special_kick_high"],
        "grab1": ["stepright", "grab1"],
    }
    for entry_id: String in sequence_expectations:
        var sequence_entry: Dictionary = gallery._entry_by_id(entry_id)
        var expected_index: int = gallery.entries.find(sequence_entry)
        if expected_index < 0:
            push_error("Missing gallery entry " + entry_id)
            quit(1)
            return
        gallery.index = expected_index
        gallery._play_current()
        if Array(gallery.sequence) != Array(sequence_expectations[entry_id]):
            push_error("Gallery prerequisite sequence mismatch for " + entry_id
                    + ": " + str(gallery.sequence))
            quit(1)
            return
    print("MOVE_GALLERY_VALIDATION=" + JSON.stringify({
        "entries": gallery.entries.size(),
        "all_playable": true,
    }))
    quit(0)

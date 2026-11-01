extends SceneTree

const Fighter = preload("res://scripts/fighter.gd")

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var source_path: String = "res://data/fighting_set_m03_mapped_attacks.json"
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_path))
    if not data is Dictionary:
        push_error("Could not parse the Brick attack config")
        quit(1)
        return
    var attacks: Dictionary = data["attacks"]
    attacks.erase("high_punch2")
    var test_root: String = OS.get_environment("LOCALAPPDATA")
    if test_root.is_empty():
        test_root = OS.get_temp_dir()
    var test_path: String = test_root.path_join(
        "BruceLee-PC-Port/brick-missing-action-%d.json" % Time.get_ticks_usec()
    )
    var handle: FileAccess = FileAccess.open(test_path, FileAccess.WRITE)
    if handle == null:
        push_error("Could not write the missing-action config")
        quit(1)
        return
    handle.store_string(JSON.stringify(data))
    handle.close()

    var brick = Fighter.new()
    brick.configure("brick", false, Color.WHITE)
    brick.configure_attack_config(test_path)
    root.add_child(brick)
    await process_frame
    if not brick.ATTACKS.is_empty():
        push_error("Config missing high_punch2 unexpectedly loaded an attack set")
        quit(1)
        return
    if not brick.attack_config_error.contains("lacks high_punch2"):
        push_error("Missing action did not fail with a precise error: "
                + brick.attack_config_error)
        quit(1)
        return
    print("BRICK_ATTACK_CONFIG_REQUIRED=PASS")
    brick.queue_free()
    await process_frame
    DirAccess.remove_absolute(test_path)
    quit(0)

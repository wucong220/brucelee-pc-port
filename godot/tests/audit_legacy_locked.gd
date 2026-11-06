extends SceneTree
func _initialize(): call_deferred("run")
func run():
    OS.set_environment("BRUCELEE_MAIN_MENU", "1")
    var scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    var store = scene.get("style_store")
    var player = scene.get("player")
    var report = scene.get("player_style_report")
    var ok = store.loaded_ok and store.selected("grabs/graba") == "grababrick" and not player.active_uniques().has("grababrick") and player.active_uniques().has("grababrucelee") and not report.get("locked_selections", []).is_empty()
    print("LEGACY_LOCK_TEST ok=",ok," saved=",store.selected("grabs/graba")," active=",player.active_uniques()," dropped=",report.get("locked_selections", []))
    quit(0 if ok else 1)

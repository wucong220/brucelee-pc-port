extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_OPPONENT_GLB", "D:/BruceLeeWork/reaction-fixtures-20261103/ken_missing_mid.glb")
    OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", PortFighter.KEN_ATTACK_CONFIG_PATH)
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    scene.set_physics_process(false)
    var defender: PortFighter = scene.get("computer")
    defender.set_physics_process(false)
    if not defender.candidate_loaded or defender._candidate_clip_paths.has("all_impct_light_frnt_mid"):
        push_error("missing fixture not loaded correctly")
        quit(1)
        return
    defender.reset_fighter(Vector3(0.6, 1.2, 0.0))
    defender.receive_hit(5.0, false, 0.0, 1.0, defender.REACTION_PROFILES["hit"]["medium"])
    defender._animate_candidate()
    if defender.last_reaction_clip_implemented or defender.candidate_animation_clip == "all_impct_light_frnt_mid":
        push_error("missing reaction was marked playable")
        quit(1)
        return
    print("MISSING_REACTION_VALIDATION=" + JSON.stringify({"loaded": defender.candidate_loaded, "implemented": defender.last_reaction_clip_implemented, "selected": defender.candidate_animation_clip}))
    scene.queue_free()
    await process_frame
    quit(0)

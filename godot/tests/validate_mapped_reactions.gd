extends SceneTree
## Run each menu candidate in the real main scene; assert combat and animation.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    if args.size() != 1 or args[0] not in ["master", "sinfu", "ken"]:
        _fail("expected master, sinfu or ken")
        return
    var main_script = load("res://scripts/main.gd")
    var config: Dictionary = main_script.get_script_constant_map()["MENU_OPPONENT_CONFIG"][args[0]]
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_OPPONENT_GLB", config["glb"])
    OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", config["attack_config"])
    OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", config["texture_root"])
    OS.set_environment("BRUCELEE_OPPONENT_MATERIAL_PROFILE", config["material_profile"])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    scene.set_physics_process(false)
    var defender: PortFighter = scene.get("computer")
    var attacker: PortFighter = scene.get("player")
    defender.set_physics_process(false)
    attacker.set_physics_process(false)
    if not defender.candidate_loaded or not defender.attack_config_error.is_empty():
        _fail("candidate/config failed: " + defender.candidate_load_error + defender.attack_config_error)
        return
    var animation: AnimationPlayer = defender.get("_candidate_animation")
    animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    var skeleton: Skeleton3D = defender.get("_candidate_skeleton")
    var results: Array = []
    for group: String in ["hit", "block"]:
        for height: String in ["low", "medium", "high"]:
            defender.reset_fighter(Vector3(0.6, 1.2, 0.0))
            var profile: Dictionary = defender.REACTION_PROFILES[group][height]
            var expected: String = profile["animation"]
            if not defender.receive_hit(5.0, group == "block", 0.0, 1.0, profile):
                _fail("receive_hit rejected " + group + "/" + height)
                return
            defender._animate_candidate()
            if not defender.last_reaction_clip_implemented or defender.candidate_animation_clip != expected or not animation.is_playing():
                _fail("reaction did not play " + group + "/" + height + " " + defender.candidate_animation_clip)
                return
            animation.seek(0.0, true)
            var before: Array = []
            for bone: int in skeleton.get_bone_count():
                before.append(skeleton.get_bone_pose_rotation(bone))
            animation.advance(minf(0.1, animation.current_animation_length * 0.5))
            var moved := false
            for bone: int in skeleton.get_bone_count():
                if absf(Quaternion(before[bone]).dot(skeleton.get_bone_pose_rotation(bone))) < 0.99999:
                    moved = true
                    break
            if not moved:
                _fail("skeleton did not move for " + expected)
                return
            results.append({"group": group, "height": height, "clip": expected, "exit_frame": defender.last_reaction_exit_frame, "skeleton_moved": moved})
    # Exercise actual attack contact and guard decision, not only direct receive_hit.
    for blocked: bool in [false, true]:
        attacker.reset_fighter(Vector3(0.0, 1.2, 0.0))
        defender.reset_fighter(Vector3(0.6, 1.2, 0.0))
        attacker.facing = 1
        defender.guard_held = blocked
        if not attacker.request_attack("high_punch"):
            _fail("attack request rejected")
            return
        attacker._advance_timed_states(float(attacker.ATTACKS["high_punch"]["startup"]))
        attacker._try_attack_contact()
        defender._animate_candidate()
        if defender.state != ("blockstun" if blocked else "hitstun") or not defender.last_reaction_clip_implemented or not animation.is_playing():
            _fail("contact did not play reaction: " + defender.state + " / " + defender.candidate_animation_clip)
            return
        results.append({"contact_blocked": blocked, "clip": defender.candidate_animation_clip, "state": defender.state})
        if OS.get_environment("REACTION_SCREENSHOTS") == "1":
            animation.advance(0.1)
            await RenderingServer.frame_post_draw
            var image: Image = root.get_texture().get_image()
            var label: String = "block" if blocked else "hit"
            var save_error: Error = image.save_png("D:/BruceLeeWork/reaction-integration-20261103/screenshots/%s_%s.png" % [args[0], label])
            if save_error != OK:
                _fail("screenshot failed: " + str(save_error))
                return
    # A missing clip must never be advertised as playable.
    var paths: Dictionary = defender.get("_candidate_clip_paths")
    paths.erase("all_impct_light_frnt_mid")
    defender.reset_fighter(Vector3(0.6, 1.2, 0.0))
    defender.receive_hit(5.0, false, 0.0, 1.0, defender.REACTION_PROFILES["hit"]["medium"])
    defender._animate_candidate()
    if defender.last_reaction_clip_implemented or defender.candidate_animation_clip == "all_impct_light_frnt_mid":
        _fail("missing reaction played")
        return
    print("MAPPED_REACTIONS=" + JSON.stringify({"character": args[0], "candidate": config["glb"], "results": results, "missing_fail_closed": true}))
    scene.queue_free()
    await process_frame
    quit(0)

func _fail(message: String) -> void:
    push_error(message)
    quit(1)

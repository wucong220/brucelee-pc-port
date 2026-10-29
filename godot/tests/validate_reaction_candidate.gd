extends SceneTree
## Check reaction selection and interruption with a local candidate GLB.


func _initialize() -> void:
    call_deferred("_run_check")


func _run_check() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2 or args[1] not in ["with-reactions", "legacy"]:
        push_error("Expected a GLB path and with-reactions or legacy")
        quit(1)
        return
    var expect_reactions: bool = args[1] == "with-reactions"
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    player.set_physics_process(false)
    if not player.candidate_loaded:
        push_error("Candidate GLB was not integrated: " + player.candidate_load_error)
        quit(1)
        return
    var animation: AnimationPlayer = player.get("_candidate_animation")
    animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    var skeletons: Array[Node] = player.find_children("*", "Skeleton3D", true, false)
    if skeletons.size() != 1:
        push_error("Expected one candidate skeleton")
        quit(1)
        return
    var skeleton: Skeleton3D = skeletons[0]
    var skeleton_parent: Node3D = skeleton.get_parent() as Node3D
    if skeleton_parent == null:
        push_error("Candidate skeleton parent is not 3D")
        quit(1)
        return
    var character: Node3D = player.get("_candidate_character")
    var character_rest: Vector3 = player.get("_candidate_character_rest_position")
    for group: String in ["hit", "block"]:
        for height: String in ["low", "medium", "high"]:
            player.reset_fighter(Vector3(-0.25, 1.2, 0.0))
            player._animate_candidate()
            animation.seek(0.0, true)
            var idle_skeleton_position: Vector3 = skeleton_parent.global_position
            var profile: Dictionary = player.REACTION_PROFILES[group][height]
            player.receive_hit(5.0, group == "block", 0.0, 1.0, profile)
            player._animate_candidate()
            var expected: String = String(profile["animation"]) if expect_reactions else "m01_idle_01"
            if player.candidate_animation_clip != expected or not animation.is_playing():
                push_error("Wrong reaction clip for %s/%s: %s" % [group, height, player.candidate_animation_clip])
                quit(1)
                return
            if expect_reactions:
                animation.seek(0.0, true)
                var fighter_position: Vector3 = player.position
                var skeleton_start: Vector3 = skeleton_parent.global_position
                var positions: Array[Vector3] = []
                var rotations: Array[Quaternion] = []
                for bone: int in skeleton.get_bone_count():
                    positions.append(skeleton.get_bone_pose_position(bone))
                    rotations.append(skeleton.get_bone_pose_rotation(bone))
                animation.advance(animation.current_animation_length * 0.5)
                var moved: bool = false
                for bone: int in skeleton.get_bone_count():
                    if (positions[bone].distance_to(skeleton.get_bone_pose_position(bone)) > 0.00001
                            or absf(rotations[bone].dot(skeleton.get_bone_pose_rotation(bone))) < 0.99999):
                        moved = true
                        break
                if not moved:
                    push_error("Reaction skeleton did not move: " + expected)
                    quit(1)
                    return
                for fraction: float in [0.25, 0.5, 0.75, 1.0]:
                    animation.seek(animation.current_animation_length * fraction, true)
                    var displacement: float = skeleton_parent.global_position.distance_to(skeleton_start)
                    if not is_finite(displacement) or displacement > 0.5:
                        push_error("Reaction skeleton moved more than the candidate safety bound: " + expected)
                        quit(1)
                        return
                if not player.position.is_equal_approx(fighter_position):
                    push_error("Visual reaction changed the fighter position: " + expected)
                    quit(1)
                    return
                if character == null or not character.position.is_equal_approx(character_rest):
                    push_error("Reaction displaced the candidate character root: " + expected)
                    quit(1)
                    return
                player.receive_hit(5.0, group == "block", 0.0, 1.0, profile)
                player._animate_candidate()
                if animation.current_animation_position > 0.001:
                    push_error("Repeated reaction did not restart: " + expected)
                    quit(1)
                    return
            player._advance_timed_states(player.state_time + 0.001)
            player._animate_candidate()
            if player.state != "idle" or player.candidate_animation_clip != "m01_idle_01":
                push_error("Reaction did not return to idle: " + expected)
                quit(1)
                return
            if expect_reactions and not character.position.is_equal_approx(character_rest):
                push_error("Reaction root did not return to rest: " + expected)
                quit(1)
                return
            animation.seek(0.0, true)
            if skeleton_parent.global_position.distance_to(idle_skeleton_position) > 0.001:
                push_error("Idle did not restore skeleton position after reaction: " + expected)
                quit(1)
                return
    player.reset_fighter(Vector3(-0.25, 1.2, 0.0))
    if not player.request_attack("punch"):
        push_error("Could not start attack before interruption")
        quit(1)
        return
    player._animate_candidate()
    animation.advance(0.4)
    player.receive_hit(5.0, false, 0.0, 1.0, player.REACTION_PROFILES["hit"]["medium"])
    player._animate_candidate()
    if player.state != "hitstun":
        push_error("Reaction did not interrupt the attack")
        quit(1)
        return
    if expect_reactions and not character.position.is_equal_approx(character_rest):
        push_error("Attack interruption did not restore the character root")
        quit(1)
        return
    player.receive_hit(1000.0, false, 0.0, 1.0, player.REACTION_PROFILES["hit"]["low"])
    player._animate_candidate()
    if player.state != "ko" or player.candidate_animation_clip != "m01_idle_01":
        push_error("KO retained a reaction animation")
        quit(1)
        return
    player.reset_fighter(Vector3(-0.25, 1.2, 0.0))
    player._animate_candidate()
    if player.state != "idle" or player.candidate_animation_clip != "m01_idle_01":
        push_error("Reset retained a reaction animation")
        quit(1)
        return
    if expect_reactions:
        var unsafe_clip := Animation.new()
        var unsafe_track: int = unsafe_clip.add_track(Animation.TYPE_POSITION_3D)
        unsafe_clip.track_set_path(unsafe_track, NodePath("unrecognized_root"))
        if player._prepare_candidate_reaction(unsafe_clip):
            push_error("Unknown reaction transform target was accepted")
            quit(1)
            return
    print("REACTION_CANDIDATE_VALIDATION=" + JSON.stringify({"mode": args[1], "profiles": 6}))
    quit(0)

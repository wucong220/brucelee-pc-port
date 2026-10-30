extends SceneTree
## Check the world-space contract of CPU-skinned candidate bounds.

const CandidateBounds = preload("res://scripts/candidate_bounds.gd")
const EPSILON: float = 0.005

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and Brick candidate GLB paths")
        quit(1)
        return
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", "")
    OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", "")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    scene.set_process(false)
    scene.set_physics_process(false)
    var bruce: PortFighter = scene.get("player")
    var brick: PortFighter = scene.get("computer")
    bruce.set_physics_process(false)
    brick.set_physics_process(false)
    if not bruce.candidate_loaded or not brick.candidate_loaded:
        push_error("Candidate models did not load")
        quit(1)
        return
    var reports: Array[Dictionary] = []
    for fighter: PortFighter in [bruce, brick]:
        fighter.reset_fighter(Vector3(0.0, 1.2, 0.0))
        fighter.rotation.y = 0.0
        fighter._animate_candidate()
        var clip: String = "m01_kick_low_01" if fighter == bruce else "m03_kck_low_01"
        var animation: AnimationPlayer = fighter._candidate_animation
        if not animation.has_animation(clip):
            push_error("Missing candidate animation " + clip)
            quit(1)
            return
        animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
        animation.play(clip)
        animation.seek(0.4, true)
        animation.advance(0.0)
        await process_frame
        await process_frame
        var initial_result: Dictionary = CandidateBounds.scene_bounds(fighter._candidate_root)
        if not initial_result.has("bounds"):
            push_error("Cannot measure initial bounds: " + str(initial_result))
            quit(1)
            return
        var initial: AABB = initial_result["bounds"]
        fighter.rotation.y = PI
        await process_frame
        await process_frame
        var rotated_result: Dictionary = CandidateBounds.scene_bounds(fighter._candidate_root)
        if not rotated_result.has("bounds"):
            push_error("Cannot measure rotated bounds: " + str(rotated_result))
            quit(1)
            return
        var rotated: AABB = rotated_result["bounds"]
        var expected_rotated: AABB = AABB(
            Vector3(-initial.end.x, initial.position.y, -initial.end.z),
            initial.size
        )
        if (not _close_aabb(rotated, expected_rotated)
                or absf(rotated.position.x - initial.position.x) < 0.01):
            push_error("Rotation did not change asymmetric world bounds as expected: %s %s %s"
                    % [clip, initial, rotated])
            quit(1)
            return
        var shift: Vector3 = Vector3(2.3, 0.0, -1.7)
        fighter.global_position += shift
        await process_frame
        await process_frame
        var translated_result: Dictionary = CandidateBounds.scene_bounds(fighter._candidate_root)
        if not translated_result.has("bounds"):
            push_error("Cannot measure translated bounds: " + str(translated_result))
            quit(1)
            return
        var translated: AABB = translated_result["bounds"]
        if not _close_aabb(translated, AABB(rotated.position + shift, rotated.size)):
            push_error("Candidate bounds did not follow world translation for " + clip)
            quit(1)
            return
        reports.append({"clip": clip, "initial_x": initial.position.x,
            "rotated_x": rotated.position.x, "translation": [shift.x, shift.z]})
    print("CANDIDATE_BOUNDS_SPACE=passed " + JSON.stringify(reports))
    quit(0)

func _close_aabb(a: AABB, b: AABB) -> bool:
    return a.position.distance_to(b.position) <= EPSILON and a.size.distance_to(b.size) <= EPSILON

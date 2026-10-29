extends SceneTree
## Verify that a local candidate GLB can replace the player's placeholder visuals
## in the real combat scene without changing the gameplay state machine.


const CandidateBounds = preload("res://scripts/candidate_bounds.gd")
const EXPECTED_PLAYER_ANIMATED_HEIGHT: float = 1.6010163
const ANIMATED_HEIGHT_TOLERANCE: float = 0.01


func _initialize() -> void:
    call_deferred("_run_check")


func _run_check() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty() or args.size() > 2:
        push_error("Expected a local candidate GLB path and optional texture root")
        quit(1)
        return
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    var expect_textures: bool = args.size() == 2
    if expect_textures:
        OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", args[1])
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        push_error("Cannot load the combat scene")
        quit(1)
        return
    var scene: Node = packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var opponent: PortFighter = scene.get("computer")
    if player == null or opponent == null:
        push_error("Fighters are missing after scene initialization")
        quit(1)
        return
    if not player.candidate_loaded:
        push_error("Candidate GLB was not integrated: " + player.candidate_load_error)
        quit(1)
        return
    if player.candidate_animation_clip != "m01_idle_01":
        push_error("Integrated candidate did not start in the idle clip")
        quit(1)
        return
    if expect_textures and not player.candidate_textures_loaded:
        push_error("Integrated candidate textures did not load: " + player.candidate_texture_error)
        quit(1)
        return
    if absf(player.candidate_visual_height - 1.8) > 0.01:
        push_error(
            "Integrated candidate height is not normalized: %.6f"
            % player.candidate_visual_height
        )
        quit(1)
        return
    var candidate_root: Node3D = player.get("_candidate_root")
    if candidate_root == null:
        push_error("Integrated candidate root is unavailable")
        quit(1)
        return
    var expected_scale: float = (
        PortFighter.CANDIDATE_HEIGHT / PortFighter.CANDIDATE_SOURCE_HEIGHT
    )
    if not candidate_root.scale.is_equal_approx(Vector3.ONE * expected_scale):
        push_error("Integrated candidate scale is incorrect: %s" % candidate_root.scale)
        quit(1)
        return
    var expected_anchor_y: float = (
        -PortFighter.PLAYER_ORIGIN_HEIGHT
        - PortFighter.CANDIDATE_SOURCE_MIN_Y * expected_scale
    )
    if not candidate_root.position.is_equal_approx(
            Vector3(0.0, expected_anchor_y, 0.0)):
        push_error(
            "Integrated candidate is not anchored at the fighter origin: %s"
            % candidate_root.position
        )
        quit(1)
        return
    var measured: Dictionary = CandidateBounds.scene_bounds(candidate_root)
    if not measured["error"].is_empty():
        push_error("Integrated candidate bounds failed: " + measured["error"])
        quit(1)
        return
    var final_bounds: AABB = measured["bounds"]
    var expected_floor_y: float = PortFighter.CANDIDATE_FLOOR_Y
    if absf(final_bounds.size.y - EXPECTED_PLAYER_ANIMATED_HEIGHT) > ANIMATED_HEIGHT_TOLERANCE:
        push_error(
            "Integrated candidate animated height is %.6f, expected %.6f"
            % [final_bounds.size.y, EXPECTED_PLAYER_ANIMATED_HEIGHT]
        )
        quit(1)
        return
    if absf(final_bounds.position.y - expected_floor_y) > 0.02:
        push_error(
            "Integrated candidate floor is %.6f, expected %.6f"
            % [final_bounds.position.y, expected_floor_y]
        )
        quit(1)
        return
    player.reset_fighter(Vector3(-0.25, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.25, 1.2, 0.0))
    opponent.guard_held = false
    if not player.request_attack("punch"):
        push_error("Integrated candidate player could not start a punch")
        quit(1)
        return
    for frame in range(15):
        await physics_frame
    if player.candidate_animation_clip != "m01_pnch_low_01":
        push_error(
            "Punch state did not select the punch clip: state=%s kind=%s clip=%s"
            % [player.state, player.attack_kind, player.candidate_animation_clip]
        )
        quit(1)
        return
    if absf(opponent.health - 95.0) > 0.001:
        push_error("Integrated candidate punch did not apply 5 damage: %.3f" % opponent.health)
        quit(1)
        return
    if (opponent.last_reaction_source_action != "impactlightfrontmid"
            or opponent.last_reaction_exit_frame != 14):
        push_error("Integrated candidate punch did not apply the source reaction profile")
        quit(1)
        return
    print("COMBAT_CANDIDATE_VALIDATION=" + JSON.stringify({
        "candidate_loaded": true,
        "candidate_textures_loaded": player.candidate_textures_loaded,
        "candidate_visual_height": player.candidate_visual_height,
        "candidate_world_min_y": final_bounds.position.y,
        "candidate_world_height": final_bounds.size.y,
        "idle_clip": "m01_idle_01",
        "punch_clip": player.candidate_animation_clip,
        "punch_target_health": opponent.health,
        "punch_hitstun_frames": opponent.last_reaction_exit_frame,
    }))
    quit(0)

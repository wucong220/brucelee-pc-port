extends Node3D
## Gameplay demonstrator: intentionally original, with placeholder meshes.
## Original character models/animations and exact rules remain unported.

const CandidateBounds = preload("res://scripts/candidate_bounds.gd")
const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")
const CANDIDATE_HEIGHT_TOLERANCE: float = 0.01

var player: PortFighter
var computer: PortFighter
var hud: PortHUD
var ai_timer: float = 0.0
var ai_guard_sequence: int = -1
var ai_guard_decision: bool = false
var done: bool = false
var training_mode: bool = false
var training_completed: bool = false
var elapsed: float = 0.0
var notice_timer: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = 0xB17E
    _build_environment()
    _build_fighters()
    hud = PortHUD.new()
    add_child(hud)
    _reset_match()
    if OS.get_environment("BRUCELEE_EXPORT_SELF_TEST") == "1":
        call_deferred("_run_export_self_test")


func _run_export_self_test() -> void:
    # Freeze gameplay before the readiness wait so autonomous AI input cannot
    # change the candidate animation that this deterministic self-test checks.
    set_physics_process(false)
    player.set_physics_process(false)
    computer.set_physics_process(false)
    var opponent_idle_clip: String = ""
    await get_tree().process_frame
    await get_tree().process_frame
    for _frame: int in 120:
        await get_tree().physics_frame
    if not player.candidate_loaded:
        push_error("EXPORT_SELF_TEST: candidate GLB was not loaded: "
                + player.candidate_load_error)
        get_tree().quit(1)
        return
    if not player.candidate_textures_loaded:
        push_error("EXPORT_SELF_TEST: candidate textures were not loaded: "
                + player.candidate_texture_error)
        get_tree().quit(1)
        return
    var expect_opponent_candidate: bool = not OS.get_environment(
        "BRUCELEE_OPPONENT_GLB"
    ).is_empty()
    if expect_opponent_candidate and not computer.candidate_loaded:
        push_error("EXPORT_SELF_TEST: opponent candidate GLB was not loaded: "
                + computer.candidate_load_error)
        get_tree().quit(1)
        return
    if expect_opponent_candidate:
        computer.reset_fighter(Vector3(2.0, 1.20, 0.0))
        computer._animate_candidate()
        if computer.candidate_animation_clip != "m03_idle_01":
            push_error("EXPORT_SELF_TEST: opponent candidate did not select Brick idle")
            get_tree().quit(1)
            return
        opponent_idle_clip = computer.candidate_animation_clip
        if (not OS.get_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT").is_empty()
                and not computer.candidate_textures_loaded):
            push_error("EXPORT_SELF_TEST: opponent textures were not loaded: "
                    + computer.candidate_texture_error)
            get_tree().quit(1)
            return
    if player.candidate_animation_clip != "m01_idle_01":
        push_error("EXPORT_SELF_TEST: candidate did not start in idle")
        get_tree().quit(1)
        return
    var candidate_root: Node3D = player.get("_candidate_root")
    if candidate_root == null:
        push_error("EXPORT_SELF_TEST: candidate root is unavailable")
        get_tree().quit(1)
        return
    var measured: Dictionary = CandidateBounds.scene_bounds(candidate_root)
    if not measured["error"].is_empty():
        push_error("EXPORT_SELF_TEST: candidate bounds failed: " + measured["error"])
        get_tree().quit(1)
        return
    var bounds: AABB = measured["bounds"]
    var expected_floor_y: float = 0.0
    if (not is_finite(bounds.size.y) or bounds.size.y <= 0.0
            or absf(player.candidate_visual_height - PortFighter.CANDIDATE_HEIGHT)
                    > CANDIDATE_HEIGHT_TOLERANCE):
        push_error("EXPORT_SELF_TEST: candidate visual normalization is invalid")
        get_tree().quit(1)
        return
    if (not is_finite(bounds.position.y)
            or absf(bounds.position.y - expected_floor_y) > 0.02):
        push_error("EXPORT_SELF_TEST: candidate floor is %.6f, expected %.6f" % [
            bounds.position.y, expected_floor_y,
        ])
        get_tree().quit(1)
        return
    var internal_path: String = (
        CandidatePathGuard.repository_root().path_join("internal-candidate.glb")
    )
    if CandidatePathGuard.external_path_error(
            internal_path, "candidate path").is_empty():
        push_error("EXPORT_SELF_TEST: application-internal candidate path was accepted")
        get_tree().quit(1)
        return

    player.reset_fighter(Vector3(-0.25, 1.2, 0.0))
    computer.reset_fighter(Vector3(0.25, 1.2, 0.0))
    if not player.request_attack("punch"):
        push_error("EXPORT_SELF_TEST: could not start punch")
        get_tree().quit(1)
        return
    player._physics_process(0.2)
    if absf(computer.health - 95.0) > 0.001:
        push_error("EXPORT_SELF_TEST: punch target health is %.3f" % computer.health)
        get_tree().quit(1)
        return
    if (computer.last_reaction_source_action != "impactlightfrontmid"
            or computer.last_reaction_exit_frame != 14):
        push_error("EXPORT_SELF_TEST: recovered punch reaction was not applied")
        get_tree().quit(1)
        return
    if player.candidate_animation_clip != "m01_pnch_low_01":
        push_error("EXPORT_SELF_TEST: punch clip was not selected")
        get_tree().quit(1)
        return
    var reaction_available: bool = player.get("_candidate_clip_paths").has("all_impct_light_frnt_mid")
    player.receive_hit(5.0, false, 0.0, 1.0, player.REACTION_PROFILES["hit"]["medium"])
    player._animate_candidate()
    var expected_reaction: String = "all_impct_light_frnt_mid" if reaction_available else "m01_idle_01"
    if player.candidate_animation_clip != expected_reaction:
        push_error("EXPORT_SELF_TEST: reaction clip was not selected")
        get_tree().quit(1)
        return
    print("EXPORT_SELF_TEST=" + JSON.stringify({
        "candidate_world_height": bounds.size.y,
        "candidate_world_min_y": bounds.position.y,
        "candidate_visual_height": player.candidate_visual_height,
        "candidate_textures_loaded": player.candidate_textures_loaded,
        "internal_path_rejected": true,
        "punch_target_health": computer.health,
        "punch_hitstun_frames": computer.last_reaction_exit_frame,
        "reaction_clip": player.candidate_animation_clip,
        "opponent_candidate_loaded": computer.candidate_loaded,
        "opponent_idle_clip": opponent_idle_clip,
        "opponent_textures_loaded": computer.candidate_textures_loaded,
        "opponent_texture_reason": computer.candidate_texture_reason,
    }))
    get_tree().quit(0)

func _build_environment() -> void:
    var environment: WorldEnvironment = WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(0.07, 0.10, 0.16)
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color = Color(0.62, 0.64, 0.78)
    environment.environment.ambient_light_energy = 0.65
    add_child(environment)
    var light: DirectionalLight3D = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
    light.light_energy = 1.65
    add_child(light)
    var camera: Camera3D = Camera3D.new()
    camera.position = Vector3(0.0, 6.0, 12.5)
    camera.current = true
    add_child(camera)
    camera.look_at(Vector3(0.0, 1.1, 0.0), Vector3.UP)
    _try_add_local_background()
    _make_floor()
    _make_arena_line(-7.0)
    _make_arena_line(7.0)

func _try_add_local_background() -> void:
    var image_path: String = OS.get_environment("BRUCELEE_BACKGROUND_PATH")
    if image_path.is_empty():
        var local_app_data: String = OS.get_environment("LOCALAPPDATA")
        if local_app_data.is_empty():
            return
        image_path = local_app_data.path_join(
            "BruceLee-PC-Port/local-assets/sprites/background.png"
        )
    var image: Image = Image.new()
    if image.load(image_path) != OK:
        return
    var texture: ImageTexture = ImageTexture.create_from_image(image)
    var quad: QuadMesh = QuadMesh.new()
    quad.size = Vector2(15.0, 7.5)
    var backdrop: MeshInstance3D = MeshInstance3D.new()
    backdrop.name = "LocalOriginalBackground"
    backdrop.mesh = quad
    backdrop.position = Vector3(0.0, 3.45, -3.9)
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_texture = texture
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    backdrop.material_override = material
    add_child(backdrop)

func _make_floor() -> void:
    var floor: StaticBody3D = StaticBody3D.new()
    floor.name = "ArenaFloor"
    floor.collision_layer = 1
    floor.collision_mask = 2
    floor.position = Vector3(0.0, -0.22, 0.0)
    var shape: CollisionShape3D = CollisionShape3D.new()
    var box: BoxShape3D = BoxShape3D.new()
    box.size = Vector3(15.0, 0.45, 8.0)
    shape.shape = box
    floor.add_child(shape)
    var visual: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = box.size
    visual.mesh = mesh
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(0.28, 0.28, 0.33)
    visual.material_override = material
    floor.add_child(visual)
    add_child(floor)

func _make_arena_line(x: float) -> void:
    var visual: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(0.05, 0.02, 7.0)
    visual.mesh = mesh
    visual.position = Vector3(x, 0.02, 0.0)
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(0.9, 0.72, 0.42)
    visual.material_override = material
    add_child(visual)

func _build_fighters() -> void:
    player = PortFighter.new()
    player.configure("Bruce (placeholder)", true, Color(0.85, 0.56, 0.18))
    player.configure_candidate_asset(
        OS.get_environment("BRUCELEE_PLAYER_GLB"),
        OS.get_environment("BRUCELEE_PLAYER_TEXTURE_ROOT"),
        PortFighter.CANDIDATE_CLIPS,
        "body_hair"
    )
    add_child(player)
    computer = PortFighter.new()
    computer.configure("Opponent (placeholder)", false, Color(0.20, 0.65, 0.76))
    computer.configure_attack_config(PortFighter.BRICK_ATTACK_CONFIG_PATH)
    computer.configure_candidate_asset(
        OS.get_environment("BRUCELEE_OPPONENT_GLB"),
        OS.get_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT"),
        PortFighter.BRICK_CLIPS,
        "body",
        false
    )
    add_child(computer)
    player.opponent = computer
    computer.opponent = player
    player.combat_ko.connect(_on_ko)
    computer.combat_ko.connect(_on_ko)
    player.combat_hit.connect(_on_hit)
    computer.combat_hit.connect(_on_hit)

func _reset_match() -> void:
    player.reset_fighter(Vector3(-0.25 if training_mode else -2.0, 1.20, 0.0))
    computer.reset_fighter(Vector3(0.25 if training_mode else 2.0, 1.20, 0.0))
    if training_mode:
        computer._enter_locomotion_state("facedownidle")
        computer._animate_candidate()
    done = false
    training_completed = false
    elapsed = 0.0
    ai_timer = 0.75
    ai_guard_sequence = -1
    ai_guard_decision = false
    notice_timer = 1.2
    hud.show_message("TRAINING · K L L / K U U" if training_mode else "ROUND 1 · FIGHT")

func _physics_process(delta: float) -> void:
    if hud == null:
        return
    hud.set_health(player.health, computer.health)
    hud.set_context_hint(_contextual_controls())
    if notice_timer > 0.0:
        notice_timer -= delta
        if notice_timer <= 0.0 and not done:
            hud.show_message("")
    if done or training_completed:
        player.move_axis = Vector2.ZERO
        computer.move_axis = Vector2.ZERO
        return
    elapsed += delta
    var x: float = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
    var z: float = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    player.move_axis = Vector2(x, z)
    player.guard_held = Input.is_key_pressed(KEY_SHIFT)
    if training_mode:
        computer.move_axis = Vector2.ZERO
        computer.guard_held = false
    else:
        _think_ai(delta)

func _contextual_controls() -> String:
    if done or training_completed:
        return ""
    var clips: Dictionary = player.get("_candidate_clip_paths")
    if player.state in ["facedownidle", "faceupidle"]:
        var getup_clip: String = (PortFighter.FACEDOWN_GETUP_CLIP
                if player.state == "facedownidle" else PortFighter.FACEUP_GETUP_CLIP)
        var attack_clip: String = (PortFighter.FACEDOWN_ATTACK_CLIP
                if player.state == "facedownidle" else PortFighter.FACEUP_ATTACK_CLIP)
        var options: Array[String] = []
        if clips.has(getup_clip):
            options.append("A/D: get up when available")
        if clips.has(attack_clip):
            options.append("Ground attack, press in order: J J J / J K K / K L L / K U U")
        return "   |   ".join(options)
    if (player.state in ["idle", "idle2"]
            and is_instance_valid(computer)
            and computer.current_source_pose() == "laying"
            and clips.has(PortFighter.ATTACK_TO_FLOOR_CLIP)
            and clips.has(PortFighter.IDLE2_CLIP)):
        return "Downed opponent: press K L L / K U U in order (close range)"
    return ""

func _think_ai(delta: float) -> void:
    var separation: float = player.position.x - computer.position.x
    var separation_z: float = player.position.z - computer.position.z
    var distance: float = Vector2(separation, separation_z).length()
    var source_reach: float = maxf(
        computer.attack_reach_world("punch", player),
        computer.attack_reach_world("kick", player)
    )
    computer.move_axis = Vector2.ZERO
    if distance > source_reach:
        computer.move_axis.x = signf(separation)
        computer.move_axis.y = signf(separation_z)
    elif distance < source_reach * 0.65:
        computer.move_axis.x = -signf(separation) * 0.35
        computer.move_axis.y = -signf(separation_z) * 0.35
    var in_attack_reach: bool = distance <= source_reach
    # Prototype AI makes one decision per attack when the attack first poses
    # a nearby threat, and holds it through the active window.
    var player_threat: bool = _player_attack_poses_guard_threat()
    if not player_threat:
        ai_guard_sequence = -1
        ai_guard_decision = false
    if (player_threat and player.attack_sequence != ai_guard_sequence
            and distance <= player.attack_reach_world(player.attack_kind, computer)):
        ai_guard_sequence = player.attack_sequence
        ai_guard_decision = rng.randf() < 0.25
    computer.guard_held = (player_threat and player.attack_sequence == ai_guard_sequence
            and ai_guard_decision)
    ai_timer -= delta
    if ai_timer <= 0.0:
        ai_timer = rng.randf_range(0.45, 0.95)
        if in_attack_reach:
            var moves: Array[String] = ["punch", "kick", "heavy"]
            var available: Array[String] = []
            for move: String in moves:
                if (computer.supports_attack(move)
                        and computer.attack_reach_world(move, player) >= distance):
                    available.append(move)
            if not available.is_empty():
                computer.request_attack(available[rng.randi_range(0, available.size() - 1)])


func _player_attack_poses_guard_threat() -> bool:
    if player.state in ["startup", "active"]:
        return true
    if player.state not in ["facedownattack", "faceupattack"]:
        return false
    var source_frame: float = player.state_time * PortFighter.SOURCE_FRAME_RATE
    var damage_end_frame: int = (
        PortFighter.FACEDOWN_ATTACK_DAMAGE_END_FRAME
        if player.state == "facedownattack"
        else PortFighter.FACEUP_ATTACK_DAMAGE_END_FRAME
    )
    # These prototype inputs enter the recovery attacks directly, so the
    # AI-visible startup extends until the recovered damage window ends.
    return source_frame <= float(damage_end_frame) + 0.0001


func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event: InputEventKey = event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    if done and key_event.keycode not in [KEY_R, KEY_F2]:
        return
    if training_completed and key_event.keycode not in [KEY_R, KEY_F2]:
        return
    match key_event.keycode:
        KEY_J:
            player.record_virtual_press("a")
            player.request_attack("punch")
        KEY_K:
            if (player.try_attack_to_floor_press("b")
                    == PortFighter.AttackToFloorInputResult.IGNORED):
                player.record_virtual_press("b")
                player.request_attack("kick")
        KEY_L:
            if (player.try_attack_to_floor_press("c")
                    == PortFighter.AttackToFloorInputResult.IGNORED):
                player.record_virtual_press("c")
                player.request_attack("heavy")
        KEY_U:
            if (player.try_attack_to_floor_press("d")
                    == PortFighter.AttackToFloorInputResult.IGNORED):
                player.record_virtual_press("d")
        KEY_R:
            _reset_match()
        KEY_F2:
            if training_mode:
                training_mode = false
                _reset_match()
            elif _training_available():
                training_mode = true
                _reset_match()
            else:
                hud.show_message("TRAINING NEEDS CANDIDATE ANIMATIONS")
                notice_timer = 2.0

func _training_available() -> bool:
    var player_clips: Dictionary = player.get("_candidate_clip_paths")
    var computer_clips: Dictionary = computer.get("_candidate_clip_paths")
    return (player.candidate_loaded and computer.candidate_loaded
            and player_clips.has(PortFighter.ATTACK_TO_FLOOR_CLIP)
            and player_clips.has(PortFighter.IDLE2_CLIP)
            and computer_clips.has(PortFighter.BRICK_FACEDOWN_IDLE_CLIP)
            and computer_clips.has(PortFighter.FACEDOWN_IMPACT_CLIP))

func _on_hit(attacker: PortFighter, defender: PortFighter, action: String, damage: float, blocked: bool) -> void:
    if done or training_completed:
        return
    if (training_mode and attacker == player and defender == computer
            and action == "attacktofloor" and damage > 0.0 and not blocked
            and defender.state == "impactfacedown"):
        training_completed = true
        hud.show_message("TRAINING HIT · R RETRY · F2 EXIT")
        notice_timer = 0.0
        return
    if blocked:
        hud.show_message("BLOCK!")
    elif attacker == player:
        hud.show_message("HIT · " + action.to_upper())
    else:
        hud.show_message("TAKE HIT")
    notice_timer = 0.30

func _on_ko(fighter: PortFighter) -> void:
    if training_completed:
        return
    done = true
    if fighter == computer:
        hud.show_message("YOU WIN!  ·  R TO RESTART")
    else:
        hud.show_message("YOU LOSE  ·  R TO RESTART")

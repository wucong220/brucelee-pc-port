extends CharacterBody3D
class_name PortFighter
## Original clean-room placeholder implementation. Not extracted Android game code.

signal combat_hit(attacker: PortFighter, defender: PortFighter, action: String, damage: float, blocked: bool)
signal combat_ko(fighter: PortFighter)

const BASE_SPEED: float = 3.6
const MAX_HEALTH: float = 100.0
const CANDIDATE_SOURCE_MIN_Y: float = -0.09393310546875
const CANDIDATE_SOURCE_HEIGHT: float = 173.415954589844
const CANDIDATE_HEIGHT: float = 1.8
const CANDIDATE_FLOOR_Y: float = 0.0
const PLAYER_ORIGIN_HEIGHT: float = 1.2
const CANDIDATE_CLIPS: Dictionary = {
    "idle": "m01_idle_01",
    "punch": "m01_pnch_low_01",
    "kick": "m01_kick_low_01",
}
const SOURCE_FRAME_RATE: float = 30.0
const SOURCE_CHARACTER_HEIGHT: float = CANDIDATE_SOURCE_HEIGHT
const WORLD_CHARACTER_HEIGHT: float = CANDIDATE_HEIGHT
const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")
const CandidateMaterialLoader = preload("res://scripts/candidate_material_loader.gd")
const HEAVY_ATTACK: Dictionary = {
    # No recovered fighting-set mapping for this prototype attack yet.
    "startup": 0.33, "active": 0.10, "recovery": 0.42,
    "range": 1.85, "damage": 19.0, "push": 0.55,
}
const ATTACK_CONFIG_PATH: String = "res://data/fighting_set_low_attacks.json"
var ATTACKS: Dictionary = {}
var attack_config_error: String = ""
var radius_scale: float = 1.0
var source_units_to_world: float = WORLD_CHARACTER_HEIGHT / SOURCE_CHARACTER_HEIGHT
var source_animation_radii: Dictionary = {
    "m01_idle_01": 25.0,
    "m01_pnch_low_01": 40.0,
    "m01_kick_low_01": 50.0,
}


var character_name: String = "Fighter"
var is_player: bool = true
var health: float = MAX_HEALTH
var move_axis: Vector2 = Vector2.ZERO
var guard_held: bool = false
var opponent: PortFighter
var state: String = "idle"
var state_time: float = 0.0
var attack_kind: String = ""
var _attack_connected: bool = false
var facing: float = 1.0
var combo_hits: int = 0
var candidate_loaded: bool = false
var candidate_load_error: String = ""
var candidate_animation_clip: String = ""
var candidate_visual_height: float = 0.0
var candidate_textures_loaded: bool = false
var candidate_texture_error: String = ""
var _time: float = 0.0
var _body: MeshInstance3D
var _left_arm: MeshInstance3D
var _right_arm: MeshInstance3D
var _color: Color = Color(0.7, 0.45, 0.2)
var _placeholder_visuals: Array[MeshInstance3D] = []
var _candidate_root: Node3D
var _candidate_animation: AnimationPlayer
var _candidate_clip_paths: Dictionary = {}
var _candidate_action: String = ""

func configure(display_name: String, human: bool, tint: Color) -> void:
    character_name = display_name
    is_player = human
    _color = tint

func _ready() -> void:
    if not _load_attack_definitions():
        push_error("Fighting-set attack config failed closed: " + attack_config_error)
    collision_layer = 2
    collision_mask = 1 | 2
    var capsule: CapsuleShape3D = CapsuleShape3D.new()
    capsule.radius = 0.34
    capsule.height = 1.9
    var collision: CollisionShape3D = CollisionShape3D.new()
    collision.shape = capsule
    add_child(collision)
    _body = _add_mesh(CapsuleMesh.new(), Vector3(0.0, 0.0, 0.0), _color)
    _body.scale = Vector3(0.9, 1.0, 0.65)
    var head: SphereMesh = SphereMesh.new()
    head.radius = 0.23
    head.height = 0.46
    _add_mesh(head, Vector3(0.0, 0.90, 0.0), Color(0.95, 0.78, 0.60))
    var arm: BoxMesh = BoxMesh.new()
    arm.size = Vector3(0.16, 0.70, 0.20)
    _left_arm = _add_mesh(arm, Vector3(-0.47, 0.18, 0.0), _color.darkened(0.08))
    _right_arm = _add_mesh(arm, Vector3(0.47, 0.18, 0.0), _color.darkened(0.08))
    var foot: BoxMesh = BoxMesh.new()
    foot.size = Vector3(0.27, 0.10, 0.43)
    _add_mesh(foot, Vector3(-0.20, -0.86, 0.0), Color(0.16, 0.16, 0.16))
    _add_mesh(foot, Vector3(0.20, -0.86, 0.0), Color(0.16, 0.16, 0.16))
    _try_load_candidate_visual()

func _load_attack_definitions() -> bool:
    ATTACKS = {}
    attack_config_error = ""
    radius_scale = 1.0
    source_units_to_world = WORLD_CHARACTER_HEIGHT / SOURCE_CHARACTER_HEIGHT
    source_animation_radii = {
        "m01_idle_01": 25.0,
        "m01_pnch_low_01": 40.0,
        "m01_kick_low_01": 50.0,
    }
    if not FileAccess.file_exists(ATTACK_CONFIG_PATH):
        attack_config_error = "missing " + ATTACK_CONFIG_PATH
        return false
    var file: FileAccess = FileAccess.open(ATTACK_CONFIG_PATH, FileAccess.READ)
    if file == null:
        attack_config_error = "could not open " + ATTACK_CONFIG_PATH
        return false
    var parser: JSON = JSON.new()
    var parse_error: Error = parser.parse(file.get_as_text())
    if parse_error != OK:
        attack_config_error = "invalid JSON: " + parser.get_error_message()
        return false
    var parsed: Variant = parser.data
    if not parsed is Dictionary:
        attack_config_error = "root is not an object"
        return false
    var loaded: Dictionary = _parse_attack_config(parsed)
    if loaded.is_empty():
        return false
    loaded["heavy"] = HEAVY_ATTACK
    ATTACKS = loaded
    return true


func _is_number(value: Variant) -> bool:
    return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _parse_attack_config(config: Dictionary) -> Dictionary:
    var schema_value: Variant = config.get("schema_version")
    if not _is_number(schema_value) or float(schema_value) != 2.0:
        return _reject_attack_config("unsupported schema version")
    if typeof(config.get("source_archive")) != TYPE_STRING or String(config.get("source_archive")) != "brucelee.set":
        return _reject_attack_config("unexpected source archive")
    var frame_rate_value: Variant = config.get("frame_rate")
    if not _is_number(frame_rate_value) or absf(float(frame_rate_value) - SOURCE_FRAME_RATE) > 0.001:
        return _reject_attack_config("frame rate does not match the source")
    var geometry_value: Variant = config.get("source_geometry")
    if not geometry_value is Dictionary:
        return _reject_attack_config("source_geometry is not an object")
    var geometry: Dictionary = geometry_value
    for key: String in [
            "source_height", "world_height", "radius_scale",
            "idle_source_archive", "animation_radii"]:
        if not geometry.has(key):
            return _reject_attack_config("source_geometry lacks " + key)
    if (not _is_number(geometry["source_height"])
            or not _is_number(geometry["world_height"])
            or not _is_number(geometry["radius_scale"])):
        return _reject_attack_config("source_geometry contains non-numeric scale values")
    var source_height: float = float(geometry["source_height"])
    var world_height: float = float(geometry["world_height"])
    var loaded_radius_scale: float = float(geometry["radius_scale"])
    if (typeof(geometry["idle_source_archive"]) != TYPE_STRING
            or String(geometry["idle_source_archive"]) != "Default.set"):
        return _reject_attack_config("unexpected idle source archive")
    if (source_height <= 0.0
            or absf(source_height - SOURCE_CHARACTER_HEIGHT) > 0.001
            or world_height <= 0.0
            or absf(world_height - WORLD_CHARACTER_HEIGHT) > 0.001
            or loaded_radius_scale <= 0.0
            or absf(loaded_radius_scale - 1.0) > 0.001):
        return _reject_attack_config("source_geometry has invalid or unexpected scale values")
    var radii_value: Variant = geometry["animation_radii"]
    if not radii_value is Dictionary:
        return _reject_attack_config("animation_radii is not an object")
    var radii: Dictionary = radii_value
    var loaded_radii: Dictionary = {}
    for animation: String in ["m01_idle_01", "m01_pnch_low_01", "m01_kick_low_01"]:
        if not radii.has(animation) or not _is_number(radii[animation]):
            return _reject_attack_config("animation_radii." + animation + " is missing or non-numeric")
        var radius: float = float(radii[animation])
        if radius <= 0.0:
            return _reject_attack_config("animation_radii." + animation + " is invalid")
        loaded_radii[animation] = radius
    if (absf(float(loaded_radii["m01_idle_01"]) - 25.0) > 0.001
            or absf(float(loaded_radii["m01_pnch_low_01"]) - 40.0) > 0.001
            or absf(float(loaded_radii["m01_kick_low_01"]) - 50.0) > 0.001):
        return _reject_attack_config("animation_radii do not match the source animations")
    var configured_attacks: Variant = config.get("attacks")
    if not configured_attacks is Dictionary:
        return _reject_attack_config("attacks is not an object")
    var result: Dictionary = {}
    for action: String in ["punch", "kick"]:
        var entry_value: Variant = configured_attacks.get(action)
        if not entry_value is Dictionary:
            return _reject_attack_config(action + " is not an object")
        var entry: Dictionary = entry_value
        for key: String in [
                "source_action", "animation", "animation_frame_count",
                "startup_frames", "active_frames", "recovery_frames",
                "damage", "prototype_push", "source_impact"]:
            if not entry.has(key):
                return _reject_attack_config(action + " lacks " + key)
        if (not _is_number(entry["startup_frames"]) or not _is_number(entry["active_frames"])
                or not _is_number(entry["recovery_frames"])
                or not _is_number(entry["animation_frame_count"])
                or not _is_number(entry["damage"])
                or not _is_number(entry["prototype_push"])):
            return _reject_attack_config(action + " contains non-numeric values")
        var startup_frames: int = int(entry["startup_frames"])
        var active_frames: int = int(entry["active_frames"])
        var recovery_frames: int = int(entry["recovery_frames"])
        var frame_count: int = int(entry["animation_frame_count"])
        if (startup_frames < 0 or active_frames < 0 or recovery_frames < 0
                or frame_count <= 0
                or startup_frames + active_frames + recovery_frames <= 0):
            return _reject_attack_config(action + " has invalid frame counts")
        if startup_frames + active_frames + recovery_frames != frame_count:
            return _reject_attack_config(action + " phase frames do not sum to animation_frame_count")
        if (float(entry["startup_frames"]) != float(startup_frames)
                or float(entry["active_frames"]) != float(active_frames)
                or float(entry["recovery_frames"]) != float(recovery_frames)
                or float(entry["animation_frame_count"]) != float(frame_count)):
            return _reject_attack_config(action + " frame counts are not integers")
        if typeof(entry["source_action"]) != TYPE_STRING or typeof(entry["animation"]) != TYPE_STRING:
            return _reject_attack_config(action + " source identifiers are not strings")
        var expected_source: String = "lowpunch1" if action == "punch" else "lowkick1"
        var expected_animation: String = "m01_pnch_low_01" if action == "punch" else "m01_kick_low_01"
        var expected_frame_count: int = 69 if action == "punch" else 86
        if String(entry["source_action"]) != expected_source:
            return _reject_attack_config(action + " source action is not " + expected_source)
        if String(entry["animation"]) != expected_animation:
            return _reject_attack_config(action + " animation is not " + expected_animation)
        if frame_count != expected_frame_count:
            return _reject_attack_config(action + " animation frame count is not " + str(expected_frame_count))
        var damage: float = float(entry["damage"])
        var push: float = float(entry["prototype_push"])
        if damage < 0.0 or push < 0.0:
            return _reject_attack_config(action + " has invalid numeric values")
        var impact_value: Variant = entry["source_impact"]
        if not impact_value is Dictionary:
            return _reject_attack_config(action + " source_impact is not an object")
        var impact: Dictionary = impact_value
        for key: String in ["attack_radius", "body_part", "height", "strength", "direction"]:
            if not impact.has(key):
                return _reject_attack_config(action + " impact lacks " + key)
        if not _is_number(impact["attack_radius"]) or float(impact["attack_radius"]) <= 0.0:
            return _reject_attack_config(action + " impact radius is invalid")
        for key: String in ["body_part", "height", "strength", "direction"]:
            if typeof(impact[key]) != TYPE_STRING:
                return _reject_attack_config(action + " impact enum " + key + " is not a string")
        if String(impact["body_part"]) not in ["larm", "rarm", "lleg", "rleg"]:
            return _reject_attack_config(action + " body part is invalid")
        if String(impact["height"]) not in ["high", "medium", "low"]:
            return _reject_attack_config(action + " height is invalid")
        if String(impact["strength"]) not in ["hard", "normal", "brutal"]:
            return _reject_attack_config(action + " strength is invalid")
        if String(impact["direction"]) not in ["frontal", "fromleft", "fromright", "fromabove"]:
            return _reject_attack_config(action + " direction is invalid")
        result[action] = {
            "startup": float(startup_frames) / SOURCE_FRAME_RATE,
            "active": float(active_frames) / SOURCE_FRAME_RATE,
            "recovery": float(recovery_frames) / SOURCE_FRAME_RATE,
            "damage": damage,
            "push": push,
            "source_action": String(entry["source_action"]),
            "animation": String(entry["animation"]),
            "animation_frame_count": frame_count,
            "source_impact": impact.duplicate(true),
        }
    # Commit instance geometry only after every attack has validated.
    radius_scale = loaded_radius_scale
    source_units_to_world = world_height / source_height
    source_animation_radii = loaded_radii
    return result


func _reject_attack_config(message: String) -> Dictionary:
    attack_config_error = message
    return {}


func _add_mesh(mesh: Mesh, local_pos: Vector3, color: Color) -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    node.mesh = mesh
    node.position = local_pos
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    node.material_override = material
    add_child(node)
    _placeholder_visuals.append(node)
    return node

## Load the player's real candidate GLB from a user-selected local file.
## The shipped project remains runnable with the generated placeholder visuals.
func _try_load_candidate_visual() -> void:
    if not is_player:
        return
    var path_result: Dictionary = _candidate_path()
    if not path_result["error"].is_empty():
        candidate_load_error = path_result["error"]
        push_warning("Player candidate GLB disabled: " + candidate_load_error)
        return
    var path: String = path_result["path"]
    if path.is_empty():
        return
    var document: GLTFDocument = GLTFDocument.new()
    var state: GLTFState = GLTFState.new()
    var result: Error = document.append_from_file(path, state)
    if result != OK:
        candidate_load_error = "GLB read failed with error %d" % result
        push_warning("Player candidate GLB disabled: " + candidate_load_error)
        return
    var generated: Node = document.generate_scene(state)
    if generated == null or not generated is Node3D:
        if generated != null:
            generated.free()
        candidate_load_error = "GLB did not generate a 3D scene"
        push_warning("Player candidate GLB disabled: " + candidate_load_error)
        return

    _candidate_root = Node3D.new()
    _candidate_root.name = "LocalCandidateCharacter"
    # The candidate's local forward is +Z; PortFighter's local front is +X.
    _candidate_root.rotation.y = PI * 0.5
    _candidate_root.add_child(generated)
    add_child(_candidate_root)
    if not _fit_candidate_visual():
        candidate_load_error = "GLB mesh bounds could not be measured"
        _candidate_root.queue_free()
        _candidate_root = null
        push_warning("Player candidate GLB disabled: " + candidate_load_error)
        return

    _candidate_animation = _find_animation_player(generated)
    if _candidate_animation == null:
        _candidate_root.queue_free()
        _candidate_root = null
        candidate_load_error = "GLB has no AnimationPlayer"
        push_warning("Player candidate GLB disabled: " + candidate_load_error)
        return
    var missing: Array[String] = []
    for action: String in CANDIDATE_CLIPS:
        var expected: String = CANDIDATE_CLIPS[action]
        var matched: String = _find_animation_clip(_candidate_animation, expected)
        if matched.is_empty():
            missing.append(expected)
        else:
            _candidate_clip_paths[action] = matched
    if not missing.is_empty():
        _candidate_root.queue_free()
        _candidate_root = null
        _candidate_animation = null
        candidate_load_error = "GLB is missing candidate clips: " + ", ".join(missing)
        push_warning("Player candidate GLB disabled: " + candidate_load_error)
        return
    var idle: Animation = _candidate_animation.get_animation(_candidate_clip_paths["idle"])
    idle.loop_mode = Animation.LOOP_LINEAR
    var material_result: Dictionary = CandidateMaterialLoader.new().apply_to(
        generated, OS.get_environment("BRUCELEE_PLAYER_TEXTURE_ROOT")
    )
    candidate_textures_loaded = material_result["loaded"]
    candidate_texture_error = material_result["error"]
    if not candidate_texture_error.is_empty():
        push_warning("Player candidate textures disabled: " + candidate_texture_error)
    for visual: MeshInstance3D in _placeholder_visuals:
        visual.visible = false
    candidate_loaded = true
    _play_candidate_action("idle")


func _fit_candidate_visual() -> bool:
    if CANDIDATE_SOURCE_HEIGHT <= 0.0:
        return false
    # The local candidate converter preserves the source Z-up height and places
    # the model origin near the feet. The measured bounds include the rigid hair
    # attachment and place the lowest body vertex slightly below source y=0.
    var factor: float = CANDIDATE_HEIGHT / CANDIDATE_SOURCE_HEIGHT
    _candidate_root.scale = Vector3.ONE * factor
    _candidate_root.position = Vector3(
        0.0, -PLAYER_ORIGIN_HEIGHT - CANDIDATE_SOURCE_MIN_Y * factor, 0.0
    )
    candidate_visual_height = CANDIDATE_SOURCE_HEIGHT * factor
    return true


func _candidate_path() -> Dictionary:
    var chosen: String = OS.get_environment("BRUCELEE_PLAYER_GLB")
    var args: PackedStringArray = OS.get_cmdline_user_args()
    var index: int = 0
    while index < args.size():
        var value: String = args[index]
        if value == "--candidate-player-glb" or value.begins_with("--candidate-player-glb="):
            if value == "--candidate-player-glb":
                if index + 1 >= args.size() or args[index + 1].begins_with("--"):
                    return {"path": "", "error": "--candidate-player-glb requires a path"}
                index += 1
                chosen = args[index]
            else:
                chosen = value.trim_prefix("--candidate-player-glb=")
        index += 1
    if chosen.is_empty():
        return {"path": "", "error": ""}
    var path_error: String = CandidatePathGuard.external_path_error(
        chosen, "candidate path"
    )
    if not path_error.is_empty():
        return {"path": "", "error": path_error}
    var normalized: String = CandidatePathGuard.normalize_absolute_path(chosen)
    if chosen.get_extension().to_lower() != "glb":
        return {"path": "", "error": "candidate path must be a local .glb file"}
    if not FileAccess.file_exists(normalized):
        return {"path": "", "error": "candidate GLB does not exist"}
    return {"path": normalized, "error": ""}


func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child: Node in node.get_children():
        var found: AnimationPlayer = _find_animation_player(child)
        if found != null:
            return found
    return null


func _find_animation_clip(player: AnimationPlayer, expected: String) -> String:
    for clip: StringName in player.get_animation_list():
        var name: String = String(clip)
        if name == expected or name.ends_with("/" + expected):
            return name
    return ""


func _play_candidate_action(action: String) -> void:
    if _candidate_animation == null or not _candidate_clip_paths.has(action):
        return
    if _candidate_action == action and _candidate_animation.is_playing():
        return
    _candidate_action = action
    candidate_animation_clip = _candidate_clip_paths[action]
    _candidate_animation.play(candidate_animation_clip)

func request_attack(kind: String) -> bool:
    if state != "idle" or guard_held or not ATTACKS.has(kind):
        return false
    attack_kind = kind
    _attack_connected = false
    state = "startup"
    state_time = float(ATTACKS[kind]["startup"])
    return true

func _physics_process(delta: float) -> void:
    _time += delta
    if opponent != null and is_instance_valid(opponent):
        facing = 1.0 if opponent.global_position.x >= global_position.x else -1.0
    # Turn the torso toward the opponent (local 'front' is +X).
    rotation.y = 0.0 if facing > 0.0 else PI
    _advance_timed_states(delta)
    if state == "active" and not _attack_connected:
        _try_attack_contact()
    var motion: Vector3 = Vector3.ZERO
    if state == "idle" and not guard_held:
        motion = Vector3(move_axis.x, 0.0, move_axis.y).normalized() * BASE_SPEED
    elif state == "idle" and guard_held:
        motion = Vector3(move_axis.x, 0.0, move_axis.y).normalized() * BASE_SPEED * 0.25
    velocity.x = motion.x
    velocity.z = motion.z
    if is_on_floor():
        velocity.y = 0.0
    else:
        velocity.y -= 12.0 * delta
    move_and_slide()
    position.x = clampf(position.x, -6.8, 6.8)
    position.z = clampf(position.z, -3.0, 3.0)
    _animate_visuals()
    _animate_candidate()

func _advance_timed_states(delta: float) -> void:
    var remaining: float = delta
    while (remaining > 0.0
            and state in ["startup", "active", "recovery", "hitstun", "blockstun"]):
        if state == "active" and not _attack_connected:
            _try_attack_contact()
        if remaining < state_time:
            state_time -= remaining
            return
        remaining -= maxf(state_time, 0.0)
        _advance_state()

func _advance_state() -> void:
    match state:
        "startup":
            state = "active"
            state_time = float(ATTACKS[attack_kind]["active"])
        "active":
            state = "recovery"
            state_time = float(ATTACKS[attack_kind]["recovery"])
        "recovery", "hitstun", "blockstun":
            state = "idle"
            state_time = 0.0
            attack_kind = ""

func _try_attack_contact() -> void:
    if opponent == null or not is_instance_valid(opponent) or opponent.state == "ko":
        return
    var details: Dictionary = ATTACKS[attack_kind]
    var dx: float = opponent.global_position.x - global_position.x
    var dz: float = opponent.global_position.z - global_position.z
    var distance: float = Vector2(dx, dz).length()
    if distance > attack_reach_world(attack_kind, opponent):
        return
    if dx * facing < -0.1:
        return
    var damage: float = float(details["damage"])
    var blocked: bool = opponent.guard_held and opponent.state == "idle"
    # Mark contact before emitting signals, including a guarded hit.
    _attack_connected = true
    opponent.receive_hit(damage, blocked, float(details["push"]), facing)
    combo_hits += 1
    combat_hit.emit(self, opponent, attack_kind, damage, blocked)


func current_source_animation() -> String:
    if state in ["startup", "active", "recovery"] and attack_kind in ["punch", "kick"]:
        return String(ATTACKS[attack_kind]["animation"])
    if state in ["startup", "active", "recovery"] and attack_kind == "heavy":
        return CANDIDATE_CLIPS["kick"]
    return CANDIDATE_CLIPS["idle"]


func source_radius_for_current_animation() -> float:
    var animation: String = current_source_animation()
    if not source_animation_radii.has(animation):
        animation = CANDIDATE_CLIPS["idle"]
    return float(source_animation_radii[animation]) * radius_scale


func attack_reach_world(kind: String, target: PortFighter = null) -> float:
    if not ATTACKS.has(kind):
        return 0.0
    var details: Dictionary = ATTACKS[kind]
    if not details.has("source_impact"):
        return float(details.get("range", 0.0))
    var impact: Dictionary = details["source_impact"]
    var source_reach: float = float(impact["attack_radius"]) * radius_scale
    if target != null:
        source_reach += target.source_radius_for_current_animation()
    return source_reach * source_units_to_world

func receive_hit(amount: float, blocked: bool, push: float, direction: float) -> void:
    if state == "ko":
        return
    _attack_connected = false
    if blocked:
        health = maxf(0.0, health - amount * 0.12)
        state = "blockstun"
        state_time = 0.14
    else:
        health = maxf(0.0, health - amount)
        state = "hitstun"
        state_time = 0.30
        combo_hits = 0
    position.x = clampf(position.x + direction * push * (0.30 if blocked else 1.0), -6.8, 6.8)
    if health <= 0.0:
        state = "ko"
        combat_ko.emit(self)

func reset_fighter(start_position: Vector3) -> void:
    global_position = start_position
    velocity = Vector3.ZERO
    move_axis = Vector2.ZERO
    health = MAX_HEALTH
    state = "idle"
    state_time = 0.0
    attack_kind = ""
    _attack_connected = false
    guard_held = false
    combo_hits = 0

func _animate_visuals() -> void:
    if candidate_loaded:
        return
    if _body == null:
        return
    var bounce: float = 0.035 * sin(_time * 8.0)
    _body.position.y = bounce
    _right_arm.rotation.z = 0.0
    _left_arm.rotation.z = 0.0
    if state in ["startup", "active"]:
        _right_arm.rotation.z = 1.05 if attack_kind == "punch" else 0.45
    elif guard_held and state == "idle":
        _right_arm.rotation.z = 0.90
        _left_arm.rotation.z = -0.90
    elif state == "hitstun":
        _right_arm.rotation.z = -0.50
        _left_arm.rotation.z = 0.50
    if state == "ko":
        _body.rotation.z = 1.1
    else:
        _body.rotation.z = 0.0


func _animate_candidate() -> void:
    if not candidate_loaded:
        return
    _candidate_root.global_position.y = (
        CANDIDATE_FLOOR_Y
        - CANDIDATE_SOURCE_MIN_Y * (CANDIDATE_HEIGHT / CANDIDATE_SOURCE_HEIGHT)
    )
    var requested: String = "idle"
    if state in ["startup", "active", "recovery"]:
        if attack_kind == "punch":
            requested = "punch"
        elif attack_kind in ["kick", "heavy"]:
            requested = "kick"
    _play_candidate_action(requested)

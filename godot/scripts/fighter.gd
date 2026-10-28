extends CharacterBody3D
class_name PortFighter
## Original clean-room placeholder implementation. Not extracted Android game code.

signal combat_hit(attacker: PortFighter, defender: PortFighter, action: String, damage: float, blocked: bool)
signal combat_ko(fighter: PortFighter)

const BASE_SPEED: float = 3.6
const MAX_HEALTH: float = 100.0
const ATTACKS: Dictionary = {
    "punch": {"startup": 0.12, "active": 0.09, "recovery": 0.18, "range": 1.65, "damage": 8.0, "push": 0.20},
    "kick": {"startup": 0.23, "active": 0.12, "recovery": 0.28, "range": 2.2, "damage": 14.0, "push": 0.35},
    "heavy": {"startup": 0.33, "active": 0.10, "recovery": 0.42, "range": 1.85, "damage": 19.0, "push": 0.55},
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
var facing: float = 1.0
var combo_hits: int = 0
var _time: float = 0.0
var _body: MeshInstance3D
var _left_arm: MeshInstance3D
var _right_arm: MeshInstance3D
var _color: Color = Color(0.7, 0.45, 0.2)

func configure(display_name: String, human: bool, tint: Color) -> void:
    character_name = display_name
    is_player = human
    _color = tint

func _ready() -> void:
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

func _add_mesh(mesh: Mesh, local_pos: Vector3, color: Color) -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    node.mesh = mesh
    node.position = local_pos
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    node.material_override = material
    add_child(node)
    return node

func request_attack(kind: String) -> bool:
    if state != "idle" or guard_held or not ATTACKS.has(kind):
        return false
    attack_kind = kind
    state = "startup"
    state_time = float(ATTACKS[kind]["startup"])
    return true

func _physics_process(delta: float) -> void:
    _time += delta
    if opponent != null and is_instance_valid(opponent):
        facing = 1.0 if opponent.global_position.x >= global_position.x else -1.0
    # Turn the torso toward the opponent (local 'front' is +X).
    rotation.y = 0.0 if facing > 0.0 else PI
    if state in ["startup", "active", "recovery", "hitstun", "blockstun"]:
        state_time -= delta
        if state_time <= 0.0:
            _advance_state()
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

func _advance_state() -> void:
    match state:
        "startup":
            state = "active"
            state_time = float(ATTACKS[attack_kind]["active"])
            _try_attack_contact()
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
    if absf(dx) > float(details["range"]) or absf(dz) > 0.95:
        return
    if dx * facing < -0.1:
        return
    var damage: float = float(details["damage"])
    var blocked: bool = opponent.guard_held and opponent.state == "idle"
    opponent.receive_hit(damage, blocked, float(details["push"]), facing)
    combo_hits += 1
    combat_hit.emit(self, opponent, attack_kind, damage, blocked)

func receive_hit(amount: float, blocked: bool, push: float, direction: float) -> void:
    if state == "ko":
        return
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
    health = MAX_HEALTH
    state = "idle"
    state_time = 0.0
    attack_kind = ""
    guard_held = false
    combo_hits = 0

func _animate_visuals() -> void:
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

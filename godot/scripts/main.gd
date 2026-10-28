extends Node3D
## Gameplay demonstrator: intentionally original, with placeholder meshes.
## Original character models/animations and exact rules remain unported.

var player: PortFighter
var computer: PortFighter
var hud: PortHUD
var ai_timer: float = 0.0
var done: bool = false
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
    add_child(player)
    computer = PortFighter.new()
    computer.configure("Opponent (placeholder)", false, Color(0.20, 0.65, 0.76))
    add_child(computer)
    player.opponent = computer
    computer.opponent = player
    player.combat_ko.connect(_on_ko)
    computer.combat_ko.connect(_on_ko)
    player.combat_hit.connect(_on_hit)
    computer.combat_hit.connect(_on_hit)

func _reset_match() -> void:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    computer.reset_fighter(Vector3(2.0, 1.20, 0.0))
    done = false
    elapsed = 0.0
    ai_timer = 0.75
    notice_timer = 1.2
    hud.show_message("ROUND 1 · FIGHT")

func _physics_process(delta: float) -> void:
    if hud == null:
        return
    hud.set_health(player.health, computer.health)
    if notice_timer > 0.0:
        notice_timer -= delta
        if notice_timer <= 0.0 and not done:
            hud.show_message("")
    if done:
        player.move_axis = Vector2.ZERO
        computer.move_axis = Vector2.ZERO
        return
    elapsed += delta
    var x: float = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
    var z: float = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    player.move_axis = Vector2(x, z)
    player.guard_held = Input.is_key_pressed(KEY_SHIFT)
    _think_ai(delta)

func _think_ai(delta: float) -> void:
    var separation: float = player.position.x - computer.position.x
    var range_x: float = absf(separation)
    computer.move_axis = Vector2.ZERO
    if range_x > 1.9:
        computer.move_axis.x = signf(separation)
    elif range_x < 1.2:
        computer.move_axis.x = -signf(separation) * 0.35
    computer.guard_held = player.state == "startup" and range_x < 2.1 and rng.randf() < 0.25
    ai_timer -= delta
    if ai_timer <= 0.0:
        ai_timer = rng.randf_range(0.45, 0.95)
        if range_x < 2.15:
            var moves: Array[String] = ["punch", "kick", "heavy"]
            computer.request_attack(moves[rng.randi_range(0, moves.size() - 1)])

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event: InputEventKey = event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    match key_event.keycode:
        KEY_J:
            player.request_attack("punch")
        KEY_K:
            player.request_attack("kick")
        KEY_L:
            player.request_attack("heavy")
        KEY_R:
            _reset_match()

func _on_hit(attacker: PortFighter, defender: PortFighter, action: String, damage: float, blocked: bool) -> void:
    if blocked:
        hud.show_message("BLOCK!")
    elif attacker == player:
        hud.show_message("HIT · " + action.to_upper())
    else:
        hud.show_message("TAKE HIT")
    notice_timer = 0.30

func _on_ko(fighter: PortFighter) -> void:
    done = true
    if fighter == computer:
        hud.show_message("YOU WIN!  ·  R TO RESTART")
    else:
        hud.show_message("YOU LOSE  ·  R TO RESTART")

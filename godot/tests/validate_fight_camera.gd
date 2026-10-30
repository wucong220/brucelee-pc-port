extends SceneTree
## Validate prototype framing at arena extremes; this is not original-camera evidence.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var opponent: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    opponent.set_physics_process(false)
    var camera: Camera3D = scene.get("fight_camera")
    await process_frame
    var viewport_size: Vector2 = root.get_visible_rect().size
    if viewport_size.x < 1.0 or viewport_size.y < 1.0:
        push_error("Camera test has no viewport size")
        quit(1)
        return
    var cases: Array = [
        [Vector3(-0.25, 1.2, 0.0), Vector3(0.25, 1.2, 0.0)],
        [Vector3(-2.0, 1.2, 0.0), Vector3(2.0, 1.2, 0.0)],
        [Vector3(-6.8, 1.2, -3.0), Vector3(6.8, 1.2, 3.0)],
        [Vector3(6.8, 1.2, -3.0), Vector3(-6.8, 1.2, 3.0)],
        [Vector3(6.8, 1.2, 3.0), Vector3(6.3, 1.2, 3.0)],
        [Vector3(-6.8, 1.2, -3.0), Vector3(-6.3, 1.2, -3.0)],
    ]
    var tested_viewports: Array[Vector2] = []
    for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(800, 600)]:
        root.size = window_size
        root.content_scale_size = window_size
        await process_frame
        viewport_size = root.get_visible_rect().size
        tested_viewports.append(viewport_size)
        for pair: Array in cases:
            player.global_position = pair[0]
            opponent.global_position = pair[1]
            scene._update_fight_camera()
            for fighter_position: Vector3 in pair:
                for x_offset: float in [-0.85, 0.85]:
                    for height: float in [0.0, 2.2]:
                        var point: Vector3 = Vector3(
                            fighter_position.x + x_offset, height, fighter_position.z
                        )
                        var projected: Vector2 = camera.unproject_position(point)
                        if (camera.is_position_behind(point)
                                or projected.x < viewport_size.x * 0.05
                                or projected.x > viewport_size.x * 0.95
                                or projected.y < viewport_size.y * 0.10
                                or projected.y > viewport_size.y * 0.90):
                            push_error("Fighter outside camera margin: %s -> %s, viewport %s"
                                    % [point, projected, viewport_size])
                            quit(1)
                            return
    player.global_position = Vector3(-0.25, 1.2, 0.0)
    opponent.global_position = Vector3(0.25, 1.2, 0.0)
    scene._update_fight_camera()
    var feet: Vector3 = Vector3(0.0, 0.0, 0.0)
    var head: Vector3 = Vector3(0.0, 1.8, 0.0)
    var current_height: float = camera.unproject_position(feet).distance_to(
        camera.unproject_position(head)
    )
    camera.global_position = Vector3(0.0, 6.0, 12.5)
    camera.look_at(Vector3(0.0, 1.1, 0.0), Vector3.UP)
    var old_height: float = camera.unproject_position(feet).distance_to(
        camera.unproject_position(head)
    )
    if current_height < old_height * 1.5:
        push_error("Close-range camera did not improve character visibility")
        quit(1)
        return
    print("FIGHT_CAMERA_VALIDATION=passed viewports=" + str(tested_viewports))
    quit(0)

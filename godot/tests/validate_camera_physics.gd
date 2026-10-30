extends SceneTree
## Exercise the prototype camera with actual CharacterBody3D physics updates.

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
    var camera: Camera3D = scene.get("fight_camera")
    var reports: Array[Dictionary] = []
    for ticks: int in [60, 120]:
        Engine.physics_ticks_per_second = ticks
        for viewport: Vector2i in [Vector2i(1280, 720), Vector2i(480, 900)]:
            root.size = viewport
            root.content_scale_size = viewport
            await process_frame
            player.reset_fighter(Vector3(-1.0, 1.2, 0.0))
            opponent.reset_fighter(Vector3(1.0, 1.2, 0.0))
            player.move_axis = Vector2(-1.0, -0.6)
            opponent.move_axis = Vector2(1.0, 0.6)
            scene._update_fight_camera()
            var previous: Vector3 = camera.global_position
            var maximum_speed: float = 0.0
            for _frame: int in range(ticks * 2):
                await physics_frame
                scene._update_fight_camera()
                var speed: float = camera.global_position.distance_to(previous) * float(ticks)
                maximum_speed = maxf(maximum_speed, speed)
                previous = camera.global_position
                if not is_finite(speed) or speed > 40.0:
                    push_error("Unexpected camera displacement in physics simulation: " + str(speed))
                    quit(1)
                    return
                var size: Vector2 = root.get_visible_rect().size
                for fighter: PortFighter in [player, opponent]:
                    for x_offset: float in [-0.85, 0.85]:
                        for height: float in [0.0, 2.2]:
                            var point: Vector3 = Vector3(
                                fighter.global_position.x + x_offset,
                                height,
                                fighter.global_position.z
                            )
                            var projected: Vector2 = camera.unproject_position(point)
                            if (camera.is_position_behind(point)
                                    or projected.x < size.x * 0.05
                                    or projected.x > size.x * 0.95
                                    or projected.y < size.y * 0.10
                                    or projected.y > size.y * 0.90):
                                push_error("Fighter left camera margin during physics movement")
                                quit(1)
                                return
            if player.global_position.x > -3.0 or opponent.global_position.x < 3.0:
                push_error("Physics movement did not actually separate both fighters")
                quit(1)
                return
            reports.append({"ticks": ticks, "viewport": str(viewport),
                "max_camera_speed": maximum_speed})
    print("CAMERA_PHYSICS_VALIDATION=passed " + JSON.stringify(reports))
    quit(0)

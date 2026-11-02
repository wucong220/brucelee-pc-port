extends SceneTree
## Validate the native CBeatEmUpCamera follow pose (not the old prototype orbit).

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

    var cases: Array = [
        [Vector3(-0.25, 1.2, 0.0), Vector3(0.25, 1.2, 0.0)],
        [Vector3(-2.0, 1.2, 0.0), Vector3(2.0, 1.2, 0.0)],
        [Vector3(-6.8, 1.2, -3.0), Vector3(6.8, 1.2, 3.0)],
        [Vector3(6.8, 1.2, -3.0), Vector3(-6.8, 1.2, 3.0)],
    ]
    for pair: Array in cases:
        player.global_position = pair[0]
        opponent.global_position = pair[1]
        scene._restart_fight_camera()
        scene._update_fight_camera(1.0 / 60.0)
        var player_screen: Vector2 = camera.unproject_position(
            player.global_position + Vector3(0.0, 1.2, 0.0)
        )
        var opponent_screen: Vector2 = camera.unproject_position(
            opponent.global_position + Vector3(0.0, 1.2, 0.0)
        )
        if player_screen.x >= opponent_screen.x:
            push_error("native camera did not keep player left: %s >= %s"
                    % [player_screen, opponent_screen])
            quit(1)
            return
        var a: Vector3 = scene._camera_fighter_point(player)
        var b: Vector3 = scene._camera_fighter_point(opponent)
        var pose: Dictionary = scene._native_camera_pose(a, b, scene._camera_aspect_scale())
        var target: Vector3 = pose["target"] * scene.CAM_SOURCE_UNITS_TO_WORLD
        if absf(camera.global_position.y - target.y) > 0.001:
            push_error("native camera is not level with its look-at point")
            quit(1)
            return
        if camera.global_position.distance_to(target) < 2.70:
            push_error("native camera violated the 275 source-unit minimum")
            quit(1)
            return

    # Side is a persistent match flag, not a per-frame auto-side.
    player.global_position = Vector3(-1.0, 1.2, 0.0)
    opponent.global_position = Vector3(1.0, 1.2, 0.0)
    scene._cam_side = 0
    scene._restart_fight_camera()
    scene._update_fight_camera(1.0 / 60.0)
    var side_zero: Vector3 = camera.global_position
    scene._cam_side = 1
    scene._restart_fight_camera()
    scene._update_fight_camera(1.0 / 60.0)
    if camera.global_position.is_equal_approx(side_zero):
        push_error("native camera side flag did not mirror the camera")
        quit(1)
        return
    print("FIGHT_CAMERA_VALIDATION=passed")
    quit(0)

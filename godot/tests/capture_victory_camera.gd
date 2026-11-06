extends SceneTree
## Windowed capture of the REAL main.tscn MATCH_WIN/MATCH_LOSE result pose with
## the original m01_victory_01 camera. Emits 1280x720 PNG screenshots for a
## left-side winner, a right-side winner, and the JSON-missing fail-back camera.
##
## usage: --path <proj> --resolution 1280x720 --rendering-driver opengl3 \
##        --script res://tests/capture_victory_camera.gd -- <bruce.glb> <brick.glb> <gametext_root> <out_dir>

var _out_dir: String = ""


func _initialize() -> void:
    call_deferred("_run")


func _new_scene(
        bruce: String, brick: String, text_root: String,
        bruce_tex: String, brick_tex: String
) -> Node:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_TIME", "60")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", bruce)
    OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", bruce_tex)
    OS.set_environment("BRUCELEE_OPPONENT_GLB", brick)
    OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", brick_tex)
    OS.set_environment("BRUCELEE_OPPONENT_MATERIAL_PROFILE", "body")
    OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", "res://data/fighting_set_m03_mapped_attacks.json")
    OS.set_environment("BRUCELEE_GAME_TEXT_ROOT", text_root)
    OS.set_environment("BRUCELEE_GAME_TEXT_FLIP", "1")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    return scene


func _wait_candidates(scene: Node, timeout_frames: int = 900) -> bool:
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    for _i: int in range(timeout_frames):
        if player.candidate_loaded and computer.candidate_loaded:
            return true
        await physics_frame
    return player.candidate_loaded and computer.candidate_loaded


func _freeze(scene: Node) -> void:
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)


func _setup(scene: Node, winner_is_player: bool) -> void:
    scene._reset_match()
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.global_position = Vector3(-2.0, 1.20, 0.0)
    computer.global_position = Vector3(2.0, 1.20, 0.0)
    player.facing = 1.0
    computer.facing = -1.0
    scene.pending_round_winner = 1 if winner_is_player else 2
    scene.player_rounds = 2 if winner_is_player else 0
    scene.computer_rounds = 0 if winner_is_player else 2
    scene._begin_winner_result_pose()
    if scene.hud != null:
        scene.hud.show_message(
            "YOU WIN THE MATCH · R TO RESTART" if winner_is_player
            else "YOU LOSE THE MATCH · R TO RESTART"
        )
    # Pose the winner a little way into the victory clip so the body is not the
    # bind pose (the camera is the subject; the clip stays the native one).
    var winner: PortFighter = player if winner_is_player else computer
    if winner._candidate_animation != null and not winner.result_clip.is_empty():
        var duration: float = winner.result_clip_duration()
        if duration > 0.0:
            winner._candidate_animation.seek(duration * 0.35, true)


func _goto_frame(scene: Node, frame: int) -> void:
    scene.set("_camera_anm_frame", 0.0)
    var steps: int = maxi(1, int(round(float(frame) / 0.5)))
    for _i: int in range(steps):
        scene._update_fight_camera(1.0 / 60.0)


func _capture(name: String) -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    var path: String = _out_dir.path_join(name)
    var err: int = image.save_png(path)
    print("SHOT %s %dx%d err=%d" % [name, image.get_width(), image.get_height(), err])
    if err != OK:
        print("SHOTB64 %s %s" % [name, Marshalls.raw_to_base64(image.save_png_to_buffer())])


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 6:
        push_error("Expected <bruce.glb> <brick.glb> <gametext_root> <out_dir> <bruce_tex> <brick_tex>")
        quit(2)
        return
    var bruce: String = args[0]
    var brick: String = args[1]
    var text_root: String = args[2]
    _out_dir = args[3].replace("\\", "/")
    var bruce_tex: String = args[4]
    var brick_tex: String = args[5]
    DirAccess.make_dir_recursive_absolute(_out_dir)

    # Winner LEFT (player) / MATCH_WIN.
    var scene: Node = _new_scene(bruce, brick, text_root, bruce_tex, brick_tex)
    if not await _wait_candidates(scene):
        push_error("winner-left candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    _setup(scene, true)
    _goto_frame(scene, 0)
    await _capture("01_match_win_camera_frame000.png")
    _goto_frame(scene, 30)
    await _capture("02_match_win_camera_frame030.png")
    print("WINNER_LEFT camera_fov=%f pos=%s" % [
        (scene.get("fight_camera") as Camera3D).fov,
        (scene.get("fight_camera") as Camera3D).global_position,
    ])
    scene.queue_free()
    await process_frame

    # Winner RIGHT (computer) / MATCH_LOSE.
    scene = _new_scene(bruce, brick, text_root, bruce_tex, brick_tex)
    if not await _wait_candidates(scene):
        push_error("winner-right candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    _setup(scene, false)
    _goto_frame(scene, 0)
    await _capture("03_match_lose_camera_frame000.png")
    _goto_frame(scene, 30)
    await _capture("04_match_lose_camera_frame030.png")
    print("WINNER_RIGHT camera_fov=%f pos=%s" % [
        (scene.get("fight_camera") as Camera3D).fov,
        (scene.get("fight_camera") as Camera3D).global_position,
    ])
    scene.queue_free()
    await process_frame

    # Fail-back (JSON missing): pre-existing fixed result camera.
    scene = _new_scene(bruce, brick, text_root, bruce_tex, brick_tex)
    if not await _wait_candidates(scene):
        push_error("fallback candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    scene.set("_camera_anm_dir", "res://data/camera_anm_missing/")
    _setup(scene, true)
    scene._update_fight_camera(1.0 / 60.0)
    await _capture("05_fallback_json_missing.png")
    print("FALLBACK camera_fov=%f pos=%s" % [
        (scene.get("fight_camera") as Camera3D).fov,
        (scene.get("fight_camera") as Camera3D).global_position,
    ])
    scene.queue_free()
    await process_frame

    print("VICTORY_CAMERA_CAPTURE=done")
    quit(0)

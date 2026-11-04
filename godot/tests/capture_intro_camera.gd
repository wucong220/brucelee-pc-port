extends SceneTree
## Windowed capture of the REAL main.tscn MATCH_STATE_INTRO (SetState(3),
## READY/FIGHT) pose with the original m01_intro_01 camera. Emits 1280x720 PNG
## screenshots for:
##   player LEFT  player-anchored dummy  (frames 0 / 45 / 88)
##   player RIGHT player-anchored dummy  (frames 0 / 45)
##   opponent-anchored intro dummy       (frames 0 / 45)
##   JSON-missing fail-back analytic cam (frame 0)
##
## usage: --path <proj> --resolution 1280x720 --rendering-driver opengl3 \
##        --script res://tests/capture_intro_camera.gd -- \
##        <bruce.glb> <brick.glb> <gametext_root> <out_dir> <bruce_tex> <brick_tex>

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


func _setup_intro(scene: Node, scenario: String) -> void:
    scene._reset_match()
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    # Keep this legacy screenshot fixture on m01_intro_01; the new capture
    # script covers the other selected intro cameras.
    player.select_intro_clip(0)
    if scenario == "player_right":
        player.global_position = Vector3(2.0, 1.20, 0.0)
        computer.global_position = Vector3(-2.0, 1.20, 0.0)
        player.facing = -1.0
        computer.facing = 1.0
    else:
        player.global_position = Vector3(-2.0, 1.20, 0.0)
        computer.global_position = Vector3(2.0, 1.20, 0.0)
        player.facing = 1.0
        computer.facing = -1.0
    OS.set_environment("BRUCELEE_ROUND_INTRO", "1")
    scene._start_round_intro()
    if scenario == "opponent_anchor":
        scene._intro_camera_begin(computer, false, "m01_intro_01")


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


func _run_scenario(
        label: String, bruce: String, brick: String, text_root: String,
        bruce_tex: String, brick_tex: String, frames: Array
) -> bool:
    var scene: Node = _new_scene(bruce, brick, text_root, bruce_tex, brick_tex)
    if not await _wait_candidates(scene):
        push_error(label + " candidates did not load")
        return false
    await process_frame
    _freeze(scene)
    _setup_intro(scene, label)
    for frame: int in frames:
        _goto_frame(scene, frame)
        await _capture("%s_frame%03d.png" % [label, frame])
    var cam: Camera3D = scene.get("fight_camera")
    print("%s camera_fov=%f pos=%s clip=%s" % [
        label.to_upper(), cam.fov, cam.global_position, scene.get("_camera_anm_clip"),
    ])
    scene.queue_free()
    await process_frame
    return true


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

    if not await _run_scenario("player_left", bruce, brick, text_root, bruce_tex, brick_tex,
            [0, 45, 88, 110]):
        quit(1)
        return
    if not await _run_scenario("player_right", bruce, brick, text_root, bruce_tex, brick_tex,
            [0, 45]):
        quit(1)
        return
    if not await _run_scenario("opponent_anchor", bruce, brick, text_root, bruce_tex, brick_tex,
            [0, 45]):
        quit(1)
        return

    # Fail-back (JSON missing): pre-existing analytic follow camera.
    var scene: Node = _new_scene(bruce, brick, text_root, bruce_tex, brick_tex)
    if not await _wait_candidates(scene):
        push_error("fallback candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    scene.set("_camera_anm_dir", "res://data/camera_anm_missing/")
    _setup_intro(scene, "player_left")
    scene._update_fight_camera(1.0 / 60.0)
    await _capture("fallback_json_missing_frame000.png")
    print("FALLBACK camera_fov=%f pos=%s" % [
        (scene.get("fight_camera") as Camera3D).fov,
        (scene.get("fight_camera") as Camera3D).global_position,
    ])
    scene.queue_free()
    await process_frame

    print("INTRO_CAMERA_CAPTURE=done")
    quit(0)

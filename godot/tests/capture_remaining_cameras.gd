extends SceneTree
## Windowed capture of the live main.tscn camera for the newly wired cinematic
## clips: all 16 characters.list intro cameras and all 12 victory cameras.
## The camera is armed through the same main.gd entry points used by the game;
## only the selected clip is forced so every row can be captured in one run.
##
## usage: --path <proj> --resolution 1280x720 --rendering-driver opengl3 \
##        --script res://tests/capture_remaining_cameras.gd -- \
##        <player.glb> <opponent.glb> <gametext_root> <out_dir> <player_tex> <opponent_tex>

const CAMERA_DIR := "res://data/camera_anm/"
var _out_dir: String = ""
var _scene: Node = null
var _player: PortFighter = null
var _computer: PortFighter = null


func _initialize() -> void:
    call_deferred("_run")


func _new_scene(player_glb: String, opponent_glb: String, text_root: String,
        player_tex: String, opponent_tex: String) -> Node:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_ROUND_TIME", "60")
    OS.set_environment("BRUCELEE_PLAYER_GLB", player_glb)
    OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", player_tex)
    OS.set_environment("BRUCELEE_OPPONENT_GLB", opponent_glb)
    OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", opponent_tex)
    OS.set_environment("BRUCELEE_OPPONENT_MATERIAL_PROFILE", "body")
    OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG",
        "res://data/fighting_set_m03_mapped_attacks.json")
    OS.set_environment("BRUCELEE_GAME_TEXT_ROOT", text_root)
    OS.set_environment("BRUCELEE_GAME_TEXT_FLIP", "1")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    return scene


func _wait_candidates(timeout_frames: int = 1200) -> bool:
    for _i: int in range(timeout_frames):
        if _player.candidate_loaded and _computer.candidate_loaded:
            return true
        await physics_frame
    return _player.candidate_loaded and _computer.candidate_loaded


func _freeze() -> void:
    _scene.set_process(false)
    _scene.set_physics_process(false)
    _player.set_physics_process(false)
    _computer.set_physics_process(false)
    _player.opponent = _computer
    _computer.opponent = _player


func _place(player_on_right: bool = false) -> void:
    if player_on_right:
        _player.reset_fighter(Vector3(2.0, 1.20, 0.0))
        _computer.reset_fighter(Vector3(-2.0, 1.20, 0.0))
        _player.facing = -1.0
        _computer.facing = 1.0
    else:
        _player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
        _computer.reset_fighter(Vector3(2.0, 1.20, 0.0))
        _player.facing = 1.0
        _computer.facing = -1.0
    _player.visible = true
    _computer.visible = true


func _capture(name: String) -> void:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    var path: String = _out_dir.path_join(name)
    var err: int = image.save_png(path)
    print("SHOT %s %dx%d err=%d" % [name, image.get_width(), image.get_height(), err])
    if err != OK:
        print("SHOTB64 %s %s" % [name,
            Marshalls.raw_to_base64(image.save_png_to_buffer())])


func _apply_frame(frame: int) -> void:
    _scene.set("_camera_anm_frame", float(frame))
    if bool(_scene.get("_intro_camera_active")):
        _scene._intro_camera_play_authored(0.0)
    else:
        _scene._camera_anm_play_authored(0.0)


func _capture_frames(label: String, clip: String, frames: Array) -> void:
    var ref = load("res://scripts/camera_anm_player.gd").new()
    if not ref.load_json(CAMERA_DIR + clip + ".json"):
        push_error("capture reference missing: " + clip)
        return
    for frame: int in frames:
        var index: int = clampi(int(frame), 0, ref.frame_count() - 1)
        _apply_frame(index)
        await _capture("%s_frame%03d.png" % [label, index])


func _frames_for(clip: String, count: int) -> Array:
    var mid: int = int(count / 2)
    return [0, mid, count - 1] if count > 3 else [0, maxi(0, count - 1)]


func _capture_intro(clip: String, intro_map: Dictionary) -> void:
    var row: Dictionary = intro_map.get(clip, {})
    var camera: String = String(row.get("camera", ""))
    if camera.is_empty():
        return
    var frames: Array = _frames_for(clip, int(row.get("frames", 0)))
    _scene._enter_match_state(4)
    _scene._intro_camera_end()
    if clip.begins_with("m01"):
        _place()
        # Play the actual intro pose when the candidate carries it.
        if _player.get("_candidate_clip_paths").has(clip):
            _player._play_candidate_action(clip)
        if not _scene._intro_camera_begin(_player, false, clip):
            push_error("intro camera begin failed: " + clip)
            return
    else:
        # SetState(1/2) moves both fighters to the origin and shows only the
        # fighter whose intro is playing.
        _player.global_position = Vector3(0.0, 1.20, 0.0)
        _computer.global_position = Vector3(0.0, 1.20, 0.0)
        _player.visible = false
        _computer.visible = true
        if _computer.get("_candidate_clip_paths").has(clip):
            _computer._play_candidate_action(clip)
        if not _scene._intro_camera_begin(_computer, false, clip, true):
            push_error("opponent intro camera begin failed: " + clip)
            return
    await _capture_frames("intro_" + clip, camera, frames)


func _capture_victory(clip: String, victory_map: Dictionary) -> void:
    var row: Dictionary = victory_map.get(clip, {})
    var camera: String = String(row.get("camera", ""))
    if camera.is_empty():
        return
    var frames: Array = _frames_for(clip, int(row.get("frames", 0)))
    _scene._enter_match_state(4)
    _scene._camera_anm_end()
    _place()
    var winner: PortFighter = _player if clip.begins_with("m01") else _computer
    var loser: PortFighter = _computer if winner == _player else _player
    var player_pre: Vector3 = _scene._camera_anm_fighter_point(_player)
    var computer_pre: Vector3 = _scene._camera_anm_fighter_point(_computer)
    _player.global_position = Vector3(0.0, 1.20, 0.0)
    _computer.global_position = Vector3(0.0, 1.20, 0.0)
    winner.visible = true
    loser.visible = false
    if winner.get("_candidate_clip_paths").has(clip):
        winner._play_candidate_action(clip)
    if not _scene._camera_anm_begin(camera, winner, player_pre, computer_pre):
        push_error("victory camera begin failed: " + clip)
        return
    await _capture_frames("victory_" + clip, camera, frames)
    _scene._camera_anm_end()


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 6:
        push_error("Expected <player.glb> <opponent.glb> <text_root> <out_dir> <player_tex> <opponent_tex>")
        quit(2)
        return
    _out_dir = args[3].replace("\\", "/")
    DirAccess.make_dir_recursive_absolute(_out_dir)
    _scene = _new_scene(args[0], args[1], args[2], args[4], args[5])
    _player = _scene.get("player")
    _computer = _scene.get("computer")
    if not await _wait_candidates():
        push_error("remaining-camera capture candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze()

    var intro_map: Dictionary = {}
    var victory_map: Dictionary = {}
    var intro_file: FileAccess = FileAccess.open(
        CAMERA_DIR + "intro_camera_map.json", FileAccess.READ)
    if intro_file != null:
        intro_map = Dictionary(JSON.parse_string(intro_file.get_as_text()).get(
            "camera_clips", {}))
    var victory_file: FileAccess = FileAccess.open(
        CAMERA_DIR + "victory_camera_map.json", FileAccess.READ)
    if victory_file != null:
        victory_map = Dictionary(JSON.parse_string(victory_file.get_as_text()).get(
            "camera_clips", {}))

    var intro_clips: Array = []
    for key: Variant in intro_map:
        intro_clips.append(String(key))
    intro_clips.sort()
    for clip: String in intro_clips:
        await _capture_intro(clip, intro_map)
        await process_frame

    var victory_clips: Array = []
    for key: Variant in victory_map:
        victory_clips.append(String(key))
    victory_clips.sort()
    for clip: String in victory_clips:
        await _capture_victory(clip, victory_map)
        await process_frame

    print("REMAINING_CAMERA_CAPTURE=done intros=%d victories=%d" % [
        intro_clips.size(), victory_clips.size()])
    quit(0)

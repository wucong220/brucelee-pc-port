extends SceneTree
## Validates the recovered 38-file impact/block SFX library and all 21 original
## music tracks against a real package audio root, while proving the existing
## Bruce voice (33 keys) and commentator/result (8 keys) sets still load.
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_sfx_music_audio.gd \
##       -- <package_root>

const SfxMusicMap = preload("res://scripts/sfx_music_map.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    failures.append(message)
    push_error(message)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        _fail("expected one argument: <package_root>")
        _finish()
        return
    var package_root: String = args[0].replace("\\", "/").trim_suffix("/")
    for sub: String in [
        "audio/sfx", "audio/music", "audio/bruce_lee",
        "audio/commentator", "audio/menu_sfx",
    ]:
        if not DirAccess.dir_exists_absolute(package_root.path_join(sub)):
            _fail("missing package audio directory: " + sub)
    if not failures.is_empty():
        _finish()
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_SCENE", "")
    OS.set_environment("BRUCELEE_SFX_ROOT", package_root.path_join("audio/sfx"))
    OS.set_environment("BRUCELEE_MUSIC_ROOT", package_root.path_join("audio/music"))
    OS.set_environment("BRUCELEE_VOICE_ROOT", package_root.path_join("audio/bruce_lee"))
    OS.set_environment(
        "BRUCELEE_COMMENTATOR_ROOT", package_root.path_join("audio/commentator")
    )
    OS.set_environment(
        "BRUCELEE_MENU_SFX_ROOT", package_root.path_join("audio/menu_sfx")
    )

    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    scene.set_process(false)
    scene.set_physics_process(false)
    await process_frame
    await process_frame

    # ---- library counts -----------------------------------------------------
    var sfx: Dictionary = scene.get("_sfx_audio")
    var sfx_errors: Dictionary = scene.get("_sfx_audio_error")
    if sfx.size() != 38:
        _fail("expected 38 SFX streams, got %d: %s" % [sfx.size(), str(sfx_errors)])
    for name: String in SfxMusicMap.SFX_FILES:
        if not sfx.has(name):
            _fail("SFX stream missing: " + name)

    var music: Dictionary = scene.get("_music_streams")
    if music.size() != 21:
        _fail("expected 21 music streams, got %d: %s" % [
            music.size(), str(scene.get("_music_stream_paths"))
        ])
    for rel: String in SfxMusicMap.MUSIC_FILES:
        if not music.has(rel):
            _fail("music stream missing: " + rel)

    var voices: Dictionary = scene.get("_voice_audio")
    var voice_errors: Dictionary = scene.get("_voice_audio_error")
    if voices.size() != 33:
        _fail("Bruce voice set changed: expected 33 keys, got %d errors=%s" % [
            voices.size(), str(voice_errors)
        ])
    scene.call("_load_result_audio")
    var result_audio: Dictionary = scene.get("_result_audio")
    if result_audio.size() != 8:
        _fail("commentator/result set changed: expected 8 keys, got %d" % result_audio.size())

    var menu = scene.get("prototype_menu")
    if menu == null or menu.nav_sfx == null or menu.accept_sfx == null \
            or menu.back_sfx == null:
        _fail("menu SFX not loaded: " + str(
            menu.menu_sfx_errors if menu != null else "no menu"
        ))

    # ---- every table file is present, no invented filename ------------------
    var table_files: Dictionary = {}
    for group: Dictionary in [
        SfxMusicMap.SFX_ACTIONS, SfxMusicMap.ATTACK_SFX,
        SfxMusicMap.MOVE_SFX,
    ]:
        for _key: String in group:
            for value: Variant in group[_key]:
                if value is Dictionary:
                    table_files[String(Dictionary(value).get("file", ""))] = true
    for family: String in SfxMusicMap.SET_ACTION_SFX:
        var rows: Dictionary = SfxMusicMap.SET_ACTION_SFX[family]
        for _key: String in rows:
            for value: Variant in rows[_key]:
                if value is Dictionary:
                    table_files[String(Dictionary(value).get("file", ""))] = true
    table_files.erase("")
    if table_files.size() != 38:
        _fail("cue tables reference %d distinct SFX files, expected 38" % table_files.size())
    for name: String in table_files:
        if not SfxMusicMap.SFX_FILES.has(name):
            _fail("cue table references a file outside the 38-file library: " + name)

    # ---- the 10 scene tracks are the story data's exact mapping -------------
    if SfxMusicMap.SCENE_MUSIC.size() != 10:
        _fail("expected 10 scene music rows, got %d" % SfxMusicMap.SCENE_MUSIC.size())
    for scene_key: String in SfxMusicMap.SCENE_MUSIC:
        var rel: String = String(SfxMusicMap.SCENE_MUSIC[scene_key])
        if not SfxMusicMap.MUSIC_FILES.has(rel):
            _fail("scene %s points outside the 21-track library: %s" % [scene_key, rel])

    # ---- actual playback selection for menu / scene / story / map -----------
    scene.call("play_menu_music")
    await process_frame
    if String(scene.get("_music_key")) != SfxMusicMap.MENU_MUSIC:
        _fail("menu track not selected: " + String(scene.get("_music_key")))

    for scene_key: String in SfxMusicMap.SCENE_MUSIC:
        OS.set_environment("BRUCELEE_SCENE", scene_key)
        var expected: String = String(SfxMusicMap.SCENE_MUSIC[scene_key])
        scene.call("_play_scene_music")
        await process_frame
        if String(scene.get("_music_key")) != expected:
            _fail("scene %s selected %s, expected %s" % [
                scene_key, String(scene.get("_music_key")), expected
            ])

    scene.call(
        "play_story_music",
        "sounds/music/story/story_chapter_1_temple_and_street.wav",
    )
    await process_frame
    if String(scene.get("_music_key")) != "story/Story_Chapter_1_Temple_and_Street.wav":
        _fail("story track not selected: " + String(scene.get("_music_key")))

    scene.call("play_map_music")
    await process_frame
    if String(scene.get("_music_key")) != SfxMusicMap.MAP_MUSIC:
        _fail("map track not selected: " + String(scene.get("_music_key")))

    # ---- recovered reaction cues actually play ------------------------------
    var player: PortFighter = scene.get("player")
    var opponent: PortFighter = scene.get("computer")
    if player == null or opponent == null:
        _fail("fighters were not created")
        _finish()
        return
    player.set_physics_process(false)
    opponent.set_physics_process(false)

    var log: Array = scene.get("_sfx_play_log")
    log.clear()
    opponent.last_reaction_source_action = "impactlightfrontmid"
    opponent.last_reaction_exit_frame = 20
    scene.call("_on_hit", player, opponent, "punch", 5.0, false)
    await process_frame
    _expect_log(log, "Punch_Body_Light_2.wav", "light body hit")

    log.clear()
    opponent.last_reaction_source_action = "highblock"
    opponent.last_reaction_exit_frame = 10
    scene.call("_on_hit", player, opponent, "punch", 5.0, true)
    await create_timer(0.3).timeout
    await process_frame
    _expect_log(log, "Block_Arms_2.wav", "high block")

    log.clear()
    opponent.last_reaction_source_action = "impactfacedown"
    opponent.last_reaction_exit_frame = 30
    scene.call("_on_hit", player, opponent, "punch", 5.0, false)
    await create_timer(0.5).timeout
    await process_frame
    _expect_log(log, "Kick_Head_Light_1.wav", "facedown impact")
    _expect_log(log, "Fall_1_Normal.wav", "facedown fall")

    log.clear()
    scene.call("_play_attack_sfx", "punch")
    await create_timer(0.5).timeout
    await process_frame
    _expect_log(log, "Air_Punch_Light_1.wav", "punch swing")
    _expect_log(log, "Shoe_Foot_L.wav", "punch step")

    # KungFu faceupattack is the only set-specific cue outside brucelee.set.
    var kungfu_rows: Array = SfxMusicMap.set_cues("kungfu", "faceupattack")
    var kungfu_has_clothing_2: bool = false
    for value: Variant in kungfu_rows:
        if value is Dictionary and String(Dictionary(value).get("file", "")) == "Clothing_2.wav":
            kungfu_has_clothing_2 = true
    if not kungfu_has_clothing_2:
        _fail("KungFu faceupattack does not carry Clothing_2.wav")

    # Boot_L/Boot_R are Thai/Karate movement cues.
    var thai_has_boot: bool = false
    for value: Variant in SfxMusicMap.move_cues("thai"):
        if value is Dictionary and String(Dictionary(value).get("file", "")).begins_with("Boot_"):
            thai_has_boot = true
    if not thai_has_boot:
        _fail("Thai movement cues do not carry Boot_L/Boot_R")

    _finish()


func _expect_log(log: Array, filename: String, label: String) -> void:
    for value: Variant in log:
        if value is Dictionary and String(Dictionary(value).get("file", "")) == filename:
            return
    _fail("%s did not play %s; log=%s" % [label, filename, str(log)])


func _finish() -> void:
    if not failures.is_empty():
        print("SFX_MUSIC_VALIDATION=failed")
        print(JSON.stringify({"failures": failures}))
        quit(1)
        return
    var scene: Node = current_scene
    print("SFX_MUSIC_VALIDATION=" + JSON.stringify({
        "sfx_loaded": Dictionary(scene.get("_sfx_audio")).size(),
        "sfx_errors": Dictionary(scene.get("_sfx_audio_error")).size(),
        "music_loaded": Dictionary(scene.get("_music_streams")).size(),
        "voice_loaded": Dictionary(scene.get("_voice_audio")).size(),
        "voice_errors": Dictionary(scene.get("_voice_audio_error")).size(),
        "result_loaded": Dictionary(scene.get("_result_audio")).size(),
        "menu_sfx_loaded": 3,
        "scene_music_rows": SfxMusicMap.SCENE_MUSIC.size(),
        "story_music_distinct": 9,
        "sfx_table_files": 38,
        "music_table_tracks": SfxMusicMap.MUSIC_FILES.size(),
    }))
    quit(0)

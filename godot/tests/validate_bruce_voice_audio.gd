extends SceneTree
## The original Bruce Lee attack/voice WAVs must load and play on attack start.
## The recovered set gives `punch` (lowpunch1) its voice at frame 4, so the cue
## now starts 4/30 s after the action instead of at the same instant.  Wait for
## the scheduled cue and assert the frame itself, not just "a child exists".

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    var voices: Dictionary = scene.get("_voice_audio")
    var errors: Dictionary = scene.get("_voice_audio_error")
    if voices.size() < 20:
        push_error("Bruce voice set incomplete: " + str(voices.keys()) + " errors=" + str(errors))
        quit(1)
        return
    var player: PortFighter = scene.get("player")
    scene.set("_sfx_play_log", [])
    if not player.request_attack("punch"):
        push_error("voice test could not start punch")
        quit(1)
        return
    # punch -> lowpunch1 voice is Hit_Light_5_BL.wav at source frame 4.
    await create_timer(0.4).timeout
    await process_frame
    var voice_entry: Dictionary = {}
    var log: Array = scene.get("_sfx_play_log")
    for value: Variant in log:
        if value is Dictionary and bool(Dictionary(value).get("is_voice", false)):
            voice_entry = value
            break
    if voice_entry.is_empty():
        push_error("attack_started did not play the recovered voice cue; log=" + str(log))
        quit(1)
        return
    if int(voice_entry.get("frame", -1)) != 4:
        push_error("punch voice frame changed: " + str(voice_entry))
        quit(1)
        return
    var audio: Node = scene.get("combat_audio")
    print("BRUCE_VOICE_VALIDATION=" + JSON.stringify({
        "loaded": voices.size(),
        "errors": errors.size(),
        "children_after_punch": audio.get_child_count() if audio != null else -1,
        "voice_file": String(voice_entry.get("file", "")),
        "voice_frame": int(voice_entry.get("frame", -1)),
        "voice_delay": float(voice_entry.get("delay", -1.0)),
    }))
    quit(0)

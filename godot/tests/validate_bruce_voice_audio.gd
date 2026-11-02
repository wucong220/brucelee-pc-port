extends SceneTree
## The original Bruce Lee attack/voice WAVs must load and play on attack start.

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
    if not player.request_attack("punch"):
        push_error("voice test could not start punch")
        quit(1)
        return
    var audio: Node = scene.get("combat_audio")
    if audio == null or audio.get_child_count() == 0:
        push_error("attack_started did not create a voice player")
        quit(1)
        return
    print("BRUCE_VOICE_VALIDATION=" + JSON.stringify({
        "loaded": voices.size(),
        "errors": errors.size(),
        "children_after_punch": audio.get_child_count(),
    }))
    quit(0)

extends SceneTree
## Validate local WAV loading and hit/block playback without bundled game audio.

const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the extracted adreno_200/sounds/sfx directory")
        quit(1)
        return
    OS.set_environment("BRUCELEE_AUDIO_ROOT", args[0])
    if (CandidatePathGuard.external_path_error(
            args[0], "candidate audio root"
    ).is_empty() == false):
        push_error("Candidate audio root rejected")
        quit(1)
        return
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var opponent: PortFighter = scene.get("computer")
    var streams: Dictionary = scene.get("_candidate_audio").duplicate()
    var combat_audio: Node = scene.get("combat_audio")
    player.set_physics_process(false)
    opponent.set_physics_process(false)
    var errors: Dictionary = scene.get("_candidate_audio_error")
    for event: String in ["punch", "kick", "block"]:
        if not streams.has(event) or not streams[event] is AudioStreamWAV:
            push_error("Candidate audio failed for %s: %s" % [event, errors.get(event, "")])
            quit(1)
            return
        var stream: AudioStreamWAV = streams[event]
        if stream.get_length() <= 0.0 or stream.mix_rate != 32000:
            push_error("Unexpected candidate audio metadata for " + event)
            quit(1)
            return
    scene.set("_candidate_audio", {})
    scene._on_hit(player, opponent, "punch", 5.0, false)
    if combat_audio.get_child_count() != 0:
        push_error("Missing candidate audio did not fail silently")
        quit(1)
        return
    scene.set("_candidate_audio", streams)
    scene._on_hit(player, opponent, "punch", 5.0, false)
    await process_frame
    scene._on_hit(player, opponent, "kick", 5.0, true)
    await process_frame
    scene._on_hit(player, opponent, "attacktofloor", 5.0, false)
    await process_frame
    if combat_audio.get_child_count() != 2:
        push_error("Unsupported attack action should not reuse a candidate sound")
        quit(1)
        return
    for child: Node in combat_audio.get_children():
        var audio: AudioStreamPlayer = child as AudioStreamPlayer
        if audio == null or not audio.playing:
            push_error("Candidate sound did not start")
            quit(1)
            return
    var longest_stream: float = 0.0
    for stream: AudioStreamWAV in streams.values():
        longest_stream = maxf(longest_stream, stream.get_length())
    await create_timer(longest_stream + 0.25).timeout
    await process_frame
    if combat_audio.get_child_count() != 0:
        push_error("Finished candidate sound players were not released")
        quit(1)
        return
    scene.set("_candidate_audio", streams)
    scene._on_hit(player, opponent, "punch", 5.0, false)
    await process_frame
    if combat_audio.get_child_count() != 1:
        push_error("Early-stop test did not start one candidate sound")
        quit(1)
        return
    scene._stop_combat_audio()
    await create_timer(0.15).timeout
    await process_frame
    if combat_audio.get_child_count() != 0:
        push_error("Early-stopped candidate sound player was not released")
        quit(1)
        return
    if not scene.get("_candidate_audio").is_empty():
        push_error("Early stop did not clear candidate audio resources")
        quit(1)
        return
    scene.set("_candidate_audio", {})
    streams.clear()
    await create_timer(0.1).timeout
    await process_frame
    print("CANDIDATE_AUDIO_VALIDATION=passed")
    quit(0)

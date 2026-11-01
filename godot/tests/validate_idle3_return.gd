extends SceneTree
## specialkickhigh returns to idle3 when m01_idle_03 is available.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var with_clip: PortFighter = load("res://scripts/fighter.gd").new()
    var without_clip: PortFighter = load("res://scripts/fighter.gd").new()
    with_clip.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    without_clip.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(with_clip)
    root.add_child(without_clip)
    await process_frame
    with_clip._candidate_clip_paths[PortFighter.IDLE3_CLIP] = PortFighter.IDLE3_CLIP
    if not with_clip.request_attack("special_kick_high"):
        push_error("special kick high request failed")
        quit(1)
        return
    if not without_clip.request_attack("special_kick_high"):
        push_error("fallback special kick high request failed")
        quit(1)
        return
    var details: Dictionary = with_clip.ATTACKS["special_kick_high"]
    var duration: float = (
        float(details["startup"]) + float(details["active"]) + float(details["recovery"])
    )
    with_clip._advance_timed_states(duration + 0.001)
    without_clip._advance_timed_states(duration + 0.001)
    if with_clip.state != "idle3":
        push_error("special kick high did not return to idle3: " + with_clip.state)
        quit(1)
        return
    if absf(with_clip.source_radius_for_current_animation() - 40.0) > 0.001:
        push_error("idle3 radius was not 40: "
            + str(with_clip.source_radius_for_current_animation()))
        quit(1)
        return
    if without_clip.state != "idle":
        push_error("missing idle3 clip did not fall back to idle: " + without_clip.state)
        quit(1)
        return
    print("IDLE3_RETURN_VALIDATION=" + JSON.stringify({
        "window": [53, 57],
        "idle3_duration_frames": PortFighter.IDLE3_DURATION_FRAMES,
        "idle3_radius": 40.0,
        "missing_clip_fallback": "idle",
    }))
    with_clip.queue_free()
    without_clip.queue_free()
    await process_frame
    quit(0)

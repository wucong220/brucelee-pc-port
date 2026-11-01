extends SceneTree
## Validate specialpunchhighmiss -> idle2 [116,122] and missing-clip fallback.

func _initialize() -> void:
    call_deferred("_run")


func _new_fighter() -> PortFighter:
    var fighter: PortFighter = load("res://scripts/fighter.gd").new()
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    return fighter


func _set_idle2_clip(fighter: PortFighter, present: bool) -> void:
    if present:
        fighter._candidate_clip_paths[PortFighter.IDLE2_CLIP] = "m01_idle_02"
    else:
        fighter._candidate_clip_paths.erase(PortFighter.IDLE2_CLIP)


func _run() -> void:
    var with_clip: PortFighter = _new_fighter()
    var without_clip: PortFighter = _new_fighter()
    await process_frame
    with_clip.reset_fighter(Vector3.ZERO)
    without_clip.reset_fighter(Vector3.ZERO)
    _set_idle2_clip(with_clip, true)
    _set_idle2_clip(without_clip, false)
    if not with_clip.request_attack("special_punch_high_miss"):
        push_error("special punch high miss request failed")
        quit(1)
        return
    if not without_clip.request_attack("special_punch_high_miss"):
        push_error("special punch high miss fallback request failed")
        quit(1)
        return
    with_clip._advance_timed_states(123.0 / PortFighter.SOURCE_FRAME_RATE)
    without_clip._advance_timed_states(123.0 / PortFighter.SOURCE_FRAME_RATE)
    if with_clip.state != "idle2":
        push_error("special punch high miss did not return to idle2: "
            + with_clip.state)
        quit(1)
        return
    if without_clip.state != "idle":
        push_error("special punch high miss missing-clip fallback was not idle: "
            + without_clip.state)
        quit(1)
        return
    print("SPECIAL_PUNCH_HIGH_RETURN_VALIDATION=" + JSON.stringify({
        "return_window": [116, 122],
        "target": "idle2",
        "with_clip_state": with_clip.state,
        "without_clip_state": without_clip.state,
    }))
    with_clip.queue_free()
    without_clip.queue_free()
    await process_frame
    quit(0)

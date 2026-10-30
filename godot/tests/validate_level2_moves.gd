extends SceneTree
## Validate the level-2 normal attack transitions on the 35-clip candidate.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the 35-clip Bruce candidate GLB")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", "")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    player.set_physics_process(false)
    if not player.candidate_loaded:
        push_error("Level-2 candidate failed to load: " + player.candidate_load_error)
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    for required: String in ["high_punch2", "low_punch2", "high_kick2", "low_kick2"]:
        if not clips.has(required):
            push_error("Candidate is missing " + required)
            quit(1)
            return
    if not _validate_transition(player, "high_punch", "a", "high_punch2"):
        quit(1)
        return
    if not _validate_transition(player, "punch", "a", "low_punch2", "b"):
        quit(1)
        return
    if not _validate_transition(player, "high_kick", "b", "high_kick2", "c"):
        quit(1)
        return
    if not _validate_transition(player, "kick", "b", "low_kick2", "d"):
        quit(1)
        return
    if not _validate_level3_progression(player):
        quit(1)
        return
    print("LEVEL2_MOVE_VALIDATION=" + JSON.stringify({
        "level2": ["high_punch2", "low_punch2", "high_kick2", "low_kick2"],
        "wavelet_note": "m01_pnch_low_02 now decodes after allowing an unused zeroed approximation root",
        "candidate_bytes": 2020448,
        "candidate_sha256": "fbd4174f919e2a2afae18788c867c82fc736cdd035c0baabf8f8cfe4f19d9dc6",
        "scope": "PC prototype combo-level state; native keystatus unverified",
    }))
    await create_timer(0.1).timeout
    await process_frame
    scene.queue_free()
    await process_frame
    quit(0)


func _validate_level3_progression(player: PortFighter) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    if not player.request_attack("high_punch"):
        push_error("Could not start high_punch for the level-3 check")
        return false
    player.record_standing_combo_press("a")
    player.record_standing_combo_press("a")
    player.record_standing_combo_press("a")
    player._advance_timed_states(40.0 / PortFighter.SOURCE_FRAME_RATE)
    if not player._try_begin_pending_standing_combo():
        push_error("high_punch2 did not start")
        return false
    if player.attack_kind != "high_punch2":
        push_error("Expected high_punch2 before level 3: " + player.attack_kind)
        return false
    player.record_standing_combo_press("a", ["up"])
    player.record_standing_combo_press("a", ["in"])
    player.record_standing_combo_press("a", ["in"])
    player._advance_timed_states(40.0 / PortFighter.SOURCE_FRAME_RATE)
    if not player._try_begin_pending_standing_combo():
        push_error("high_punch2 did not progress to high_punch3")
        return false
    if player.attack_kind != "high_punch3":
        push_error("Level 3 selected " + player.attack_kind)
        return false
    return true


func _validate_transition(
        player: PortFighter, base: String, key1: String, target: String,
        key2: String = ""
) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    if not player.request_attack(base):
        push_error("Could not start " + base)
        return false
    player.record_standing_combo_press(key1)
    player.record_standing_combo_press(key2 if key2 != "" else key1)
    player.record_standing_combo_press(key2 if key2 != "" else key1)
    if String(player.get("_standing_combo_pending_attack")) != target:
        push_error("Sequence did not queue " + target + ": "
                + String(player.get("_standing_combo_pending_attack")))
        return false
    player._advance_timed_states(40.0 / PortFighter.SOURCE_FRAME_RATE)
    if not player._try_begin_pending_standing_combo():
        push_error(target + " did not transition")
        return false
    if player.attack_kind != target:
        push_error("Transitioned to " + player.attack_kind)
        return false
    var expected_clip: String = String(PortFighter.CANDIDATE_CLIPS[target])
    if player.current_source_animation() != expected_clip:
        push_error(target + " requested " + player.current_source_animation())
        return false
    return true

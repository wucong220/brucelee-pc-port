extends SceneTree
## Validate grab1/grab2 multi-impact attacks on the 44-clip candidate.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the 44-clip Bruce candidate GLB")
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
        push_error("Grab candidate failed: " + player.candidate_load_error)
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    for required: String in ["grab1", "grab2"]:
        if not clips.has(required):
            push_error("Candidate is missing " + required)
            quit(1)
            return
    var defender: PortFighter = load("res://scripts/fighter.gd").new()
    defender.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(defender)
    await process_frame
    if not _validate_grab(player, defender, "punch", "a", "a", "grab1", 150):
        quit(1)
        return
    if not _validate_grab(player, defender, "kick", "b", "c", "grab2", 180):
        quit(1)
        return
    if not _validate_grab_range(player, defender):
        quit(1)
        return
    print("GRAB_VALIDATION=" + JSON.stringify({
        "grabs": ["grab1", "grab2"],
        "candidate_bytes": 3164064,
        "candidate_sha256": "e155bec24771ea60724b09fbfee1620bd887d7226a2730aba5a6578e892c6d73",
        "scope": "PC prototype: direct grab when in range; miss animation belongs to the Ken skeleton and is not bundled",
    }))
    defender.queue_free()
    await create_timer(0.1).timeout
    await process_frame
    scene.queue_free()
    await process_frame
    quit(0)


func _validate_grab(
        player: PortFighter, defender: PortFighter, base: String,
        first_key: String, repeat_key: String, target: String, steps: int
) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    player.rage = 70.0
    defender.global_position = Vector3(2.0, 1.20, 0.0)
    player.opponent = defender
    if not player.request_attack(base):
        push_error("Could not start " + base)
        return false
    player.record_standing_combo_press(first_key, ["left"])
    player.record_standing_combo_press(repeat_key)
    player.record_standing_combo_press(repeat_key)
    if String(player.get("_standing_combo_pending_attack")) != target:
        push_error("Sequence did not queue " + target)
        return false
    player._advance_timed_states(40.0 / PortFighter.SOURCE_FRAME_RATE)
    defender.reset_fighter(Vector3(-1.7, 1.20, 0.0))
    player.opponent = defender
    player.facing = 1.0
    if not player._try_begin_pending_standing_combo():
        push_error(target + " did not start in range")
        return false
    if player.attack_kind != target:
        push_error("Expected " + target + ", got " + player.attack_kind)
        return false
    if absf(player.rage - 4.0) > 0.001:
        push_error(target + " did not consume 66 rage: " + str(player.rage))
        return false
    for _i: int in range(steps):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if absf(defender.health - 80.0) > 0.001:
        push_error(target + " multi impacts did not total 20: " + str(defender.health))
        return false
    return true


func _validate_grab_range(player: PortFighter, defender: PortFighter) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    player.rage = 70.0
    if not player.request_attack("punch"):
        return false
    player.record_standing_combo_press("a", ["left"])
    player.record_standing_combo_press("a")
    player.record_standing_combo_press("a")
    if String(player.get("_standing_combo_pending_attack")) != "grab1":
        push_error("Far grab sequence did not queue grab1")
        return false
    player._advance_timed_states(40.0 / PortFighter.SOURCE_FRAME_RATE)
    defender.reset_fighter(Vector3(2.0, 1.20, 0.0))
    player.opponent = defender
    if player._try_begin_pending_standing_combo():
        push_error("Grab fired out of range")
        return false
    if player.attack_kind == "grab1":
        push_error("Grab changed the attack out of range")
        return false
    return true

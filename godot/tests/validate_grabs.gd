extends SceneTree
## Validate grab miss -> grab chains on the 47-clip candidate.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the 47-clip Bruce candidate GLB")
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
    if not _validate_candidate_identity(args[0]):
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    for required: String in ["grab1_miss", "grab2_miss", "grab1", "grab2"]:
        if not clips.has(required):
            push_error("Candidate is missing " + required)
            quit(1)
            return
    var defender: PortFighter = load("res://scripts/fighter.gd").new()
    defender.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(defender)
    await process_frame
    if not _validate_grab(player, defender, "punch", "a", "a", "grab1_miss", "grab1", 150):
        quit(1)
        return
    if not _validate_grab(player, defender, "kick", "b", "c", "grab2_miss", "grab2", 180):
        quit(1)
        return
    if not _validate_grab_range(player, defender):
        quit(1)
        return
    if not _validate_blocked_grab_rejects_chain(player, defender):
        quit(1)
        return
    print("GRAB_VALIDATION=" + JSON.stringify({
        "grabs": ["grab1_miss->grab1", "grab2_miss->grab2"],
        "candidate_bytes": 4039952,
        "candidate_sha256": "592bfb185f2c587dde5a00b20ba92a8ae49b6211e957fb39f1a98c94da02afb0",
        "scope": "retargeted m02_grab_01 miss animation; chain at frames 8-9 when in range",
    }))
    defender.queue_free()
    await create_timer(0.1).timeout
    await process_frame
    scene.queue_free()
    await process_frame
    quit(0)


func _start_miss(player: PortFighter, defender: PortFighter, base: String, first_key: String, repeat_key: String) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    player.rage = 70.0
    player.facing = 1.0
    defender.reset_fighter(Vector3(2.0, 1.20, 0.0))
    player.opponent = defender
    if not player.request_attack(base):
        return false
    player.record_standing_combo_press(first_key, ["left"])
    player.record_standing_combo_press(repeat_key)
    player.record_standing_combo_press(repeat_key)
    player._advance_timed_states(40.0 / PortFighter.SOURCE_FRAME_RATE)
    return player._try_begin_pending_standing_combo()


func _validate_grab(
        player: PortFighter, defender: PortFighter, base: String,
        first_key: String, repeat_key: String, miss: String, target: String, steps: int
) -> bool:
    if not _start_miss(player, defender, base, first_key, repeat_key):
        push_error(miss + " did not start")
        return false
    if player.attack_kind != miss:
        push_error("Expected " + miss + ", got " + player.attack_kind)
        return false
    if absf(player.rage - 4.0) > 0.001:
        push_error(miss + " did not consume 66 rage")
        return false
    defender.reset_fighter(Vector3(-1.9, 1.20, 0.0))
    player.opponent = defender
    for _j: int in range(9):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.attack_kind != target:
        push_error(miss + " did not chain to " + target + ": " + player.attack_kind)
        return false
    for _i: int in range(steps):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if absf(defender.health - 80.0) > 0.001:
        push_error(target + " total damage was not 20: " + str(defender.health))
        return false
    return true


func _validate_grab_range(player: PortFighter, defender: PortFighter) -> bool:
    if not _start_miss(player, defender, "punch", "a", "a"):
        push_error("Far grab miss did not start")
        return false
    defender.reset_fighter(Vector3(2.0, 1.20, 0.0))
    player.opponent = defender
    for _i: int in range(20):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.attack_kind in ["grab1", "grab2"]:
        push_error("Grab chained out of range")
        return false
    if not is_equal_approx(defender.health, 100.0):
        push_error("Out-of-range grab dealt damage")
        return false
    return true


func _validate_blocked_grab_rejects_chain(player: PortFighter, defender: PortFighter) -> bool:
    if not _start_miss(player, defender, "punch", "a", "a"):
        return false
    defender.reset_fighter(Vector3(-1.9, 1.20, 0.0))
    defender.guard_held = true
    player.opponent = defender
    for _j: int in range(9):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.attack_kind == "grab1":
        push_error("Grab chained into a blocking opponent")
        return false
    return true


func _validate_candidate_identity(path: String) -> bool:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Could not open candidate GLB")
        return false
    var bytes: PackedByteArray = file.get_buffer(file.get_length())
    file.close()
    if bytes.size() != 4039952:
        push_error("Candidate size mismatch: " + str(bytes.size()))
        return false
    var hash: HashingContext = HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    hash.update(bytes)
    if hash.finish().hex_encode().to_lower() != "592bfb185f2c587dde5a00b20ba92a8ae49b6211e957fb39f1a98c94da02afb0":
        push_error("Candidate SHA-256 mismatch")
        return false
    var json_length: int = bytes.decode_u32(12)
    var document: Variant = JSON.parse_string(bytes.slice(20, 20 + json_length).get_string_from_utf8())
    if not document is Dictionary or not document.has("animations") or document["animations"].size() != 47:
        push_error("Candidate animation count mismatch")
        return false
    return true

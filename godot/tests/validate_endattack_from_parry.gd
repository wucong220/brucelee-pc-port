extends SceneTree

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty():
        push_error("candidate GLB path required")
        quit(1)
        return
    var player: PortFighter = load("res://scripts/fighter.gd").new()
    var defender: PortFighter = load("res://scripts/fighter.gd").new()
    player.configure("probe", true, Color.WHITE)
    player.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    player.configure_candidate_asset(args[0], "", PortFighter.CANDIDATE_CLIPS, "body")
    defender.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(player)
    root.add_child(defender)
    await process_frame
    if not player.candidate_loaded:
        push_error("candidate failed to load")
        quit(1)
        return
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    defender.reset_fighter(Vector3(-1.5, 1.20, 0.0))
    player.opponent = defender
    defender.opponent = player
    player.attack_kind = "parry_attack"
    player.attack_sequence += 1
    player.state = "recovery"
    player.state_time = (85.0 - 20.0) / PortFighter.SOURCE_FRAME_RATE
    player._attack_hit_landed = true
    defender.state = "stun"
    player.record_standing_combo_press("b", ["up", "in"])
    player.record_standing_combo_press("a", [])
    if not player.record_standing_combo_press("a", []):
        push_error("parry attack did not complete the endattack sequence")
        quit(1)
        return
    if player.attack_kind != "endattack1":
        push_error("parry endattack selected " + player.attack_kind)
        quit(1)
        return
    print("PARRY_ENDATTACK_VALIDATION=" + JSON.stringify({
        "from": "parry_attack",
        "to": player.attack_kind,
        "state": player.state,
    }))
    player.queue_free()
    defender.queue_free()
    await process_frame
    quit(0)

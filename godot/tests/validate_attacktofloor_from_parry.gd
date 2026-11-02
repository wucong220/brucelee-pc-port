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
    for fighter: PortFighter in [player, defender]:
        fighter.configure("probe", fighter == player, Color.WHITE)
        fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
        fighter.configure_candidate_asset(
            args[0], "", PortFighter.CANDIDATE_CLIPS, "body"
        )
        root.add_child(fighter)
    await process_frame
    if not player.candidate_loaded or not defender.candidate_loaded:
        push_error("candidate failed to load")
        quit(1)
        return
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    defender.reset_fighter(Vector3(2.0, 1.20, 0.0))
    player.opponent = defender
    defender.opponent = player
    defender.state = "facedownidle"
    player.attack_kind = "parry_high"
    player.attack_sequence += 1
    player.state = "active"
    player.state_time = 0.0
    if not player._candobasicattack_window_contains_current_frame():
        push_error("parry_high active frame is outside its recovered group window")
        quit(1)
        return
    # Native keyboard layout: C is the single-key attacktofloor link.
    player.record_standing_combo_press("c")
    if player.state != "attacktofloor":
        push_error("parry input did not enter attacktofloor: " + player.state)
        quit(1)
        return
    print("PARRY_ATTACKTOFLOOR_VALIDATION=" + JSON.stringify({
        "from": "parry_high",
        "to": "attacktofloor",
        "window": PortFighter.CANDOBASICATTACK_WINDOWS["parry_high"],
    }))
    player.queue_free()
    defender.queue_free()
    await process_frame
    quit(0)

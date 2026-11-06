extends SceneTree
## Reaction selection must prefer recovered native reaction links when the
## candidate actually has the reaction clip.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the Bruce candidate GLB")
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

    var reactions: Array = player.get("_native_reactions").get("hit")
    var clips: Dictionary = player.get("_candidate_clip_paths")
    if reactions.size() < 20:
        push_error("Too few recovered reactions: " + str(reactions.size()))
        quit(1)
        return

    var checks: Dictionary = {"total": reactions.size()}
    var non_normal: Dictionary = {}
    for entry_value: Variant in reactions:
        var entry: Dictionary = entry_value
        var strength: String = String(entry.get("strength", ""))
        if strength not in ["hard", "brutal"]:
            continue
        if not clips.has(String(entry.get("animation", ""))):
            continue
        non_normal = entry
        break
    if non_normal.is_empty():
        push_error("No hard/brutal reaction with a candidate clip")
        quit(1)
        return

    var reaction: Dictionary = player.reaction_for_incoming({
        "strength": non_normal["strength"],
        "height": non_normal["height"],
        "direction": non_normal["direction"],
    }, false)
    checks["selected"] = String(reaction.get("source_action", ""))
    checks["animation"] = String(reaction.get("animation", ""))
    if reaction.is_empty():
        push_error("Native reaction was not selected")
        quit(1)
        return
    if not clips.has(String(reaction.get("animation", ""))):
        push_error("Selected reaction clip is missing from the candidate")
        quit(1)
        return

    var stun_hard: Dictionary = player._stun_impact_reaction({"strength": "hard", "height": "high"})
    checks["stun_hard"] = String(stun_hard.get("target", ""))
    checks["stun_hard_next"] = String(stun_hard.get("next_state", ""))
    if (String(stun_hard.get("target", "")) != "stunhardimpact"
            or String(stun_hard.get("next_state", "")) != "faceupko"
            or int(stun_hard.get("exit_frame", -1)) != 20):
        push_error("Stun-hard impact lookup is wrong: " + str(stun_hard))
        quit(1)
        return
    var stun_brutal: Dictionary = player._stun_impact_reaction({"strength": "brutal", "height": "high"})
    checks["stun_brutal"] = String(stun_brutal.get("target", ""))
    if (String(stun_brutal.get("target", "")) != "stunbrutalimpact"
            or String(stun_brutal.get("next_state", "")) != "facedownko"):
        push_error("Stun-brutal impact lookup is wrong: " + str(stun_brutal))
        quit(1)
        return

    print("NATIVE_REACTION_VALIDATION=" + JSON.stringify(checks))
    quit(0)

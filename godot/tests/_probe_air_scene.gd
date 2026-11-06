extends SceneTree
## TEMPORARY probe (not a deliverable): exercise the real main.tscn reaction
## selection while the victim (player) is inside an impactablefromair action.

var failures: Array[String] = []

func _impact(strength: String, height: String, direction: String) -> Dictionary:
    return {
        "strength": strength, "height": height, "direction": direction,
        "attack_radius": 70.0, "damage": 7.0,
    }

func _instantiate() -> Node:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", "")
    OS.set_environment("BRUCELEE_OPPONENT_GLB", "")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    scene.get("player").set_physics_process(false)
    scene.get("computer").set_physics_process(false)
    return scene

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var env: String = OS.get_environment("BRUCELEE_NATIVE_REACTION")
    print("== ENV BRUCELEE_NATIVE_REACTION='", env, "' ==")
    var scene: Node = await _instantiate()
    var player: PortFighter = scene.get("player")
    print("native_reaction_enabled=", player.native_reaction_enabled)
    var native_hits: Array = player._native_reactions.get("hit", [])
    var has_air_entry: bool = false
    for e: Variant in native_hits:
        if String(Dictionary(e).get("source_action", "")) == "impacthardair":
            has_air_entry = true
            print("NATIVE_REACTION_ENTRY impacthardair=", JSON.stringify(e))
    print("has_air_entry_in__native_reactions=", has_air_entry)

    var kinds: Array = ["high_kick3", "special_kick_high", "special_kick_high_brick", "special_kick_low", "special_punch_low"]
    for kind: String in kinds:
        if not player.ATTACKS.has(kind):
            print("KIND absent: ", kind)
            continue
        scene._reset_match()
        player.position = Vector3(0.0, 1.2, 0.0)
        scene.get("computer").position = Vector3(0.6, 1.2, 0.0)
        var desc: Dictionary = player.ATTACKS[kind]
        player.state = "startup"
        player.attack_kind = kind
        player.state_time = 5.0 / player.SOURCE_FRAME_RATE
        var action_name: String = player._current_action_name()
        var groups: Variant = player._native_actions.get(action_name, {}).get("groups", {})
        var has_air_group: bool = groups is Dictionary and Dictionary(groups).has("impactablefromair")
        for strength: String in ["normal", "hard", "brutal", "medium"]:
            var reaction: Dictionary = player.reaction_for_incoming(_impact(strength, "high", "frontal"), false)
            print("KIND=", kind, " action=", action_name, " air_group=", has_air_group,
                " strength=", strength, " -> src=", String(reaction.get("source_action", "")),
                " anim=", String(reaction.get("animation", "")),
                " last=", JSON.stringify(player.last_native_reaction))
    scene.queue_free()
    current_scene = null
    await process_frame
    quit(0)

extends SceneTree
## Validate the four directional candobasicattacks links against the 30-clip candidate.

const TARGET_CLIPS: Array[String] = [
    "high_punch3",
    "low_punch3",
    "low_kick3",
    "high_kick3",
    "all_impct_hard_rht_high",
    "all_idle_face_up",
]

const CASES: Array[Dictionary] = [
    {"initial": "punch", "steps": [["up", "a"], ["in", "a"], ["in", "a"]],
     "target": "high_punch3", "animation": "m01_pnch_high_03"},
    {"initial": "punch", "steps": [["down", "a"], ["out", "b"], ["out", "a"]],
     "target": "low_punch3", "animation": "m01_pnch_low_03"},
    {"initial": "kick", "steps": [["down", "b"], ["out", "d"], ["out", "d"]],
     "target": "low_kick3", "animation": "m01_kick_low_03"},
    {"initial": "kick", "steps": [["up", "b"], ["in", "c"], ["in", "c"]],
     "target": "high_kick3", "animation": "m01_sp_kick_jump_01"},
]


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the 30-clip Bruce candidate GLB")
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
    var opponent: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    opponent.set_physics_process(false)
    if not player.candidate_loaded:
        push_error("Directional candidate failed to load: " + player.candidate_load_error)
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    for clip: String in TARGET_CLIPS:
        if not clips.has(clip):
            push_error("Directional candidate is missing " + clip)
            quit(1)
            return
    for entry: Dictionary in CASES:
        if not _validate_sequence(player, entry):
            quit(1)
            return
        if not _validate_self_replay(player, entry):
            quit(1)
            return
    if not await _validate_high_reaction(player, opponent):
        quit(1)
        return
    if not _validate_faceup_return(player):
        quit(1)
        return
    print("DIRECTIONAL_COMBO_VALIDATION=" + JSON.stringify({
        "sequences": [[
            "up+a -> in+a -> in+a => highpunch3",
            "down+a -> out+b -> out+a => lowpunch3",
            "down+b -> out+d -> out+d => lowkick3",
            "up+b -> in+c -> in+c => highkick3",
        ]],
        "high_punch3_damage": 6.0,
        "high_punch3_reaction": "impacthardrighthigh",
        "hard_high_fromright_return": "faceupidle",
        "modifier_mapping": "up/down from move axes, in/out toward/away from opponent",
        "scope": "PC prototype modifiers; native physical keys and input clock unverified",
    }))
    await create_timer(0.1).timeout
    await process_frame
    scene.queue_free()
    await process_frame
    quit(0)


func _validate_sequence(player: PortFighter, entry: Dictionary) -> bool:
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    var steps: Array = entry["steps"]
    var initial: String = String(entry["initial"])
    var target: String = String(entry["target"])
    var first: Array = steps[0]
    if player.record_standing_combo_press(String(first[1]), first.slice(0, 1)):
        push_error("First directional press unexpectedly matched " + target)
        return false
    if not player.request_attack(initial):
        push_error("Could not start " + initial + " for " + target)
        return false
    for index: int in range(1, steps.size()):
        var step: Array = steps[index]
        player.record_standing_combo_press(String(step[1]), step.slice(0, 1))
    if String(player.get("_standing_combo_pending_attack")) != target:
        push_error("Directional sequence did not queue " + target)
        return false
    var window: Array = PortFighter.CANDOBASICATTACK_WINDOWS[initial]
    player._advance_timed_states(float(window[0] - 1) / PortFighter.SOURCE_FRAME_RATE)
    if player._try_begin_pending_standing_combo():
        push_error(target + " transitioned before the source window")
        return false
    player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if not player._try_begin_pending_standing_combo():
        push_error(target + " did not transition at the source window start")
        return false
    if player.attack_kind != target:
        push_error(target + " selected " + player.attack_kind)
        return false
    if player.current_source_animation() != String(entry["animation"]):
        push_error(target + " requested " + player.current_source_animation())
        return false
    return true


func _validate_self_replay(player: PortFighter, entry: Dictionary) -> bool:
    # Each new attack is also a candobasicattacks member. Re-entering the same
    # action must restart the clip even with visual blending enabled.
    player.candidate_visual_blending_enabled = true
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    var target: String = String(entry["target"])
    var steps: Array = entry["steps"]
    if not player.request_attack(target):
        player.candidate_visual_blending_enabled = false
        push_error("Could not start " + target + " as its own source")
        return false
    for step: Array in steps:
        player.record_standing_combo_press(String(step[1]), step.slice(0, 1))
    if String(player.get("_standing_combo_pending_attack")) != target:
        player.candidate_visual_blending_enabled = false
        push_error(target + " did not queue its own replay")
        return false
    var window: Array = PortFighter.CANDOBASICATTACK_WINDOWS[target]
    player._advance_timed_states(float(window[0]) / PortFighter.SOURCE_FRAME_RATE)
    player._animate_candidate()
    var animation: AnimationPlayer = player.get("_candidate_animation")
    if animation == null or not animation.is_playing():
        player.candidate_visual_blending_enabled = false
        push_error(target + " clip is not playing before its replay")
        return false
    animation.seek(1.0, true)
    var transitioned: bool = player._try_begin_pending_standing_combo()
    player._animate_candidate()
    var position: float = animation.current_animation_position
    var action: String = String(player.get("_candidate_action"))
    var still_playing: bool = animation.is_playing()
    player.candidate_visual_blending_enabled = false
    if not transitioned:
        push_error(target + " did not replay at its own window start")
        return false
    if position > 0.05 or action != target:
        push_error(target + " replay kept position %s or action %s" % [position, action])
        return false
    if not still_playing:
        push_error(target + " replay did not leave the clip playing")
        return false
    return true


func _validate_high_reaction(player: PortFighter, opponent: PortFighter) -> bool:
    # Reactions come from the defender's own fighting set; the scene computer
    # uses thai.set, so build a Bruce-configured defender for this check.
    var defender: PortFighter = load("res://scripts/fighter.gd").new()
    defender.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(defender)
    await process_frame
    var impact: Dictionary = player.ATTACKS["high_punch3"]["source_impact"]
    var expected_damage: float = float(player.ATTACKS["high_punch3"]["damage"])
    var reaction: Dictionary = defender.reaction_for_incoming(impact, false)
    if (String(reaction.get("source_action", "")) != "impacthardrighthigh"
            or String(reaction.get("animation", "")) != "all_impct_hard_rht_high"
            or String(reaction.get("return_action", "")) != "faceupidle"):
        push_error("hard/high/fromright did not select the recovered reaction: "
                + JSON.stringify(reaction))
        defender.queue_free()
        return false
    defender.receive_hit(expected_damage, false, 0.0, 1.0, reaction)
    var accepted: bool = (
        defender.state == "hitstun"
        and defender.last_reaction_source_action == "impacthardrighthigh"
        and absf(defender.health - (100.0 - expected_damage)) <= 0.001
    )
    defender.queue_free()
    if not accepted:
        push_error("The recovered hard/high/fromright reaction was not applied")
        return false
    return true


func _validate_faceup_return(player: PortFighter) -> bool:
    var exact: Dictionary = player.get("EXACT_REACTIONS")
    var reaction: Dictionary = exact["hit"][2]
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player._time = 0.0
    if not player.receive_hit(6.0, false, 0.0, 1.0, reaction):
        push_error("The face-up return fixture hit was rejected")
        return false
    player._advance_timed_states(
        float(reaction["exit_start_frame"]) / PortFighter.SOURCE_FRAME_RATE + 0.01
    )
    if player.state != "faceupidle":
        push_error("hard/high/fromright did not return to faceupidle: " + player.state)
        return false
    return true

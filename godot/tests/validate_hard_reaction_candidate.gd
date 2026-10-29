extends SceneTree
## Play the three verified Bruce hard-reaction clips from a local 12-clip GLB.


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected the Bruce hard-reaction GLB and the Brick GLB")
        quit(1)
        return
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", "")
    OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", "")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var opponent: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    opponent.set_physics_process(false)
    if not player.candidate_loaded or not opponent.candidate_loaded:
        push_error("Hard-reaction candidates failed to load: %s | %s" % [
            player.candidate_load_error, opponent.candidate_load_error,
        ])
        quit(1)
        return
    var cases: Array[Dictionary] = [
        {
            "kind": "punch",
            "blocked": false,
            "action": "impacthardfrontmid",
            "animation": "all_impct_crotch",
            "exit_frame": 27,
            "radius": 40.0,
            "return_action": "idle",
            "return_implemented": true,
        },
        {
            "kind": "punch",
            "blocked": true,
            "action": "highblockhard",
            "animation": "all_block_high_hard",
            "exit_frame": 11,
            "radius": 25.0,
            "return_action": "idle2",
            "return_implemented": false,
        },
        {
            "kind": "kick",
            "blocked": false,
            "action": "impacthardrightlow",
            "animation": "all_impct_hard_rht_low",
            "exit_frame": 23,
            "radius": 70.0,
            "return_action": "facedownidle",
            "return_implemented": false,
        },
    ]
    for spec: Dictionary in cases:
        if not _check_case(player, opponent, spec):
            quit(1)
            return
    for group: String in ["hit", "block"]:
        for entry_value: Variant in player.EXACT_REACTIONS[group]:
            var entry: Dictionary = entry_value
            if bool(entry["clip_implemented"]):
                push_error("Exact reaction JSON clip_implemented must stay false")
                quit(1)
                return
    print("HARD_REACTION_CANDIDATE_VALIDATION=" + JSON.stringify({"clips": 3}))
    quit(0)


func _check_case(player: PortFighter, opponent: PortFighter, spec: Dictionary) -> bool:
    var kind: String = spec["kind"]
    var blocked: bool = spec["blocked"]
    var expected_animation: String = spec["animation"]
    player.reset_fighter(Vector3(0.6, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.0, 1.2, 0.0))
    player.guard_held = blocked
    if not opponent.request_attack(kind):
        push_error("Could not start Brick " + kind)
        return false
    opponent._advance_timed_states(float(opponent.ATTACKS[kind]["startup"]))
    opponent._try_attack_contact()
    player._animate_candidate()
    var animation: AnimationPlayer = player.get("_candidate_animation")
    var played: String = player.candidate_animation_clip
    var expected_state: String = "blockstun" if blocked else "hitstun"
    var entry: Dictionary = _exact_entry(player, expected_animation)
    if (player.state != expected_state
            or not player.last_reaction_clip_implemented
            or player.last_reaction_source_action != String(spec["action"])
            or player.last_reaction_animation != expected_animation
            or player.last_reaction_exit_frame != int(spec["exit_frame"])
            or not _clip_is(played, expected_animation)
            or _clip_is(played, "all_impct_light_frnt_mid")
            or _clip_is(played, "all_impct_light_frnt_low")
            or _clip_is(played, "all_impct_light_frnt_high")
            or animation == null
            or not animation.is_playing()
            or not _clip_is(String(animation.current_animation), expected_animation)
            or absf(player.source_radius_for_current_animation() - float(spec["radius"])) > 0.001
            or absf(player.state_time - float(spec["exit_frame"]) / PortFighter.SOURCE_FRAME_RATE) > 0.0001
            or entry.is_empty()
            or String(entry["return_action"]) != String(spec["return_action"])
            or bool(entry["return_implemented"]) != bool(spec["return_implemented"])
            or bool(entry["clip_implemented"])):
        push_error("Hard reaction clip was not played: " + JSON.stringify({
            "expected": expected_animation,
            "state": player.state,
            "played": played,
            "source_action": player.last_reaction_source_action,
            "animation": player.last_reaction_animation,
            "exit_frame": player.last_reaction_exit_frame,
            "clip_implemented": player.last_reaction_clip_implemented,
            "radius": player.source_radius_for_current_animation(),
        }))
        return false
    player._advance_timed_states(player.state_time + 0.001)
    player._animate_candidate()
    if (player.state != "idle"
            or not _clip_is(player.candidate_animation_clip, "m01_idle_01")
            or _clip_is(player.candidate_animation_clip, "facedownidle")
            or _clip_is(player.candidate_animation_clip, "idle2")
            or _clip_is(player.candidate_animation_clip, "all_idle_face_down_forbigguy")):
        push_error("Hard reaction did not return explicitly to idle: " + expected_animation)
        return false
    return true


func _exact_entry(player: PortFighter, animation_name: String) -> Dictionary:
    for group_value: Variant in player.EXACT_REACTIONS.values():
        if not group_value is Array:
            continue
        for entry_value: Variant in group_value:
            if entry_value is Dictionary and String(entry_value["animation"]) == animation_name:
                return entry_value
    return {}


func _clip_is(actual: String, expected: String) -> bool:
    return actual == expected or actual.ends_with("/" + expected)

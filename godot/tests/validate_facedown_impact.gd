extends SceneTree

var _ko_hit_count: int = 0
## Play the verified facedown low-impact reaction from the 16-clip candidate.


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected the Bruce facedown-impact GLB and the Brick GLB")
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
        push_error("Facedown-impact candidates failed to load: %s | %s" % [
            player.candidate_load_error, opponent.candidate_load_error,
        ])
        quit(1)
        return
    if not _clips_are_present(player):
        quit(1)
        return
    if not _check_low_impact(player, opponent):
        quit(1)
        return
    if not _check_medium_stays_standing(player, opponent):
        quit(1)
        return
    if not _check_lethal_facedown_ko(player, opponent):
        quit(1)
        return
    if not _check_missing_clip(player, opponent):
        quit(1)
        return
    if not _check_missing_facedown_clip_stays_standing_ko(player, opponent):
        quit(1)
        return
    print("FACEDOWN_IMPACT_VALIDATION=" + JSON.stringify({
        "clip": "all_impct_facedwn",
        "exit_frame": 11,
        "radius": 80,
        "facedownko_radius": 100,
        "not_implemented": ["facedownattack"],
    }))
    quit(0)


func _clips_are_present(player: PortFighter) -> bool:
    var animation: AnimationPlayer = player.get("_candidate_animation")
    var expected: Array[String] = [
        "m01_idle_01", "m01_pnch_low_01", "m01_kick_low_01",
        "all_block_high", "all_block_low", "all_block_mid",
        "all_impct_light_frnt_high", "all_impct_light_frnt_low",
        "all_impct_light_frnt_mid", "all_impct_crotch",
        "all_impct_hard_rht_low", "all_block_high_hard",
        "m01_idle_02", "all_idle_face_down", "all_getup_facedwn",
        "all_impct_facedwn",
    ]
    if animation == null or animation.get_animation_list().size() != expected.size():
        push_error("Facedown-impact GLB does not expose exactly 16 clips")
        return false
    for clip_name: String in expected:
        if _find_clip(animation, clip_name).is_empty():
            push_error("Facedown-impact GLB is missing " + clip_name)
            return false
    if not player._candidate_clip_paths.has("all_impct_facedwn"):
        push_error("all_impct_facedwn did not pass the candidate track check")
        return false
    var clip: Animation = animation.get_animation(_find_clip(animation, "all_impct_facedwn"))
    if clip.loop_mode != Animation.LOOP_NONE:
        push_error("all_impct_facedwn is looping")
        return false
    if not _character_tracks_disabled(player, "all_impct_facedwn"):
        return false
    for group: String in ["hit", "block"]:
        for entry_value: Variant in player.EXACT_REACTIONS[group]:
            if bool((entry_value as Dictionary)["clip_implemented"]):
                push_error("JSON clip_implemented changed")
                return false
    return true


func _check_low_impact(player: PortFighter, opponent: PortFighter) -> bool:
    if not _enter_facedown(player, opponent):
        return false
    var damage: float = float(opponent.ATTACKS["kick"]["damage"])
    var before_health: float = player.health
    if not _follow_up(player, opponent, "kick"):
        return false
    if String(opponent.ATTACKS["kick"]["source_impact"]["height"]) != "low":
        push_error("Brick kick is not the verified low impact")
        return false
    if not _impact_is(player, before_health - damage, 0.6):
        push_error("Low impact did not enter impactfacedown")
        return false
    var exit_time: float = 11.0 / player.SOURCE_FRAME_RATE
    player._advance_timed_states(maxf(exit_time - player.state_time - 0.001, 0.0))
    player._animate_candidate()
    if player.state != "impactfacedown" or not _clip_is(player.candidate_animation_clip, "all_impct_facedwn"):
        push_error("impactfacedown ended before frame 11")
        return false
    player._advance_timed_states(0.002)
    player._animate_candidate()
    if player.state != "facedownidle" or not _clip_is(player.candidate_animation_clip, "all_idle_face_down"):
        push_error("impactfacedown did not return to facedownidle at frame 11")
        return false
    if absf(player.source_radius_for_current_animation() - 75.0) > 0.001:
        push_error("Return from impactfacedown did not restore the facedown radius")
        return false
    return true


func _check_medium_stays_standing(player: PortFighter, opponent: PortFighter) -> bool:
    if not _enter_facedown(player, opponent):
        return false
    if String(opponent.ATTACKS["punch"]["source_impact"]["height"]) == "low":
        push_error("Brick punch is low, so it cannot prove the medium exclusion")
        return false
    if not _follow_up(player, opponent, "punch"):
        return false
    if player.state == "impactfacedown" or player.last_reaction_source_action == "impactfacedown":
        push_error("Medium hit entered impactfacedown")
        return false
    if player.state != "hitstun" or player.last_reaction_source_action != "impacthardfrontmid":
        push_error("Medium hit left the existing standing reaction")
        return false
    return true


func _check_lethal_facedown_ko(player: PortFighter, opponent: PortFighter) -> bool:
    if not _enter_facedown(player, opponent):
        return false
    var damage: float = float(opponent.ATTACKS["kick"]["damage"])
    player.health = damage
    if not _follow_up(player, opponent, "kick"):
        return false
    if not _facedown_ko_is(player):
        push_error("Lethal low impact did not enter facedownko")
        return false
    player.move_axis = Vector2(-1.0, 0.0)
    player._advance_timed_states(1.0)
    player._animate_candidate()
    if player.state != "facedownko" or _clip_is(player.candidate_animation_clip, "all_getup_facedwn"):
        push_error("facedownko accepted a getup")
        return false
    _ko_hit_count = 0
    if not opponent.combat_hit.is_connected(_count_ko_hit):
        opponent.combat_hit.connect(_count_ko_hit)
    if not _follow_up(player, opponent, "kick"):
        return false
    if _ko_hit_count != 0 or opponent.combo_hits != 0 or opponent._attack_connected:
        push_error("facedownko still recorded a new hit")
        return false
    if player.state != "facedownko" or player.health > 0.0:
        push_error("A later attack changed facedownko")
        return false
    if not _enter_facedown(player, opponent):
        return false
    player.health = float(opponent.ATTACKS["punch"]["damage"])
    if not _follow_up(player, opponent, "punch"):
        return false
    if not _facedown_ko_is(player):
        push_error("Lethal medium impact did not prefer facedownko")
        return false
    return true


func _facedown_ko_is(player: PortFighter) -> bool:
    return (
        player.state == "facedownko"
        and player.health <= 0.0
        and _clip_is(player.candidate_animation_clip, "all_idle_face_down")
        and not _clip_is(player.candidate_animation_clip, "all_impct_facedwn")
        and absf(player.position.x - 0.6) <= 0.001
        and absf(player.source_radius_for_current_animation() - 100.0) <= 0.001
        and not bool(player.EXACT_REACTIONS["hit"][1]["clip_implemented"])
    )


func _check_missing_facedown_clip_stays_standing_ko(player: PortFighter, opponent: PortFighter) -> bool:
    if not _enter_facedown(player, opponent):
        return false
    var saved: String = String(player._candidate_clip_paths["all_idle_face_down"])
    player._candidate_clip_paths.erase("all_idle_face_down")
    player.health = float(opponent.ATTACKS["kick"]["damage"])
    if not _follow_up(player, opponent, "kick"):
        player._candidate_clip_paths["all_idle_face_down"] = saved
        return false
    player._candidate_clip_paths["all_idle_face_down"] = saved
    if player.state != "ko" or player.state == "facedownko":
        push_error("Missing facedown clip still entered facedownko")
        return false
    return true


func _check_missing_clip(player: PortFighter, opponent: PortFighter) -> bool:
    if not _enter_facedown(player, opponent):
        return false
    var saved: String = String(player._candidate_clip_paths["all_impct_facedwn"])
    player._candidate_clip_paths.erase("all_impct_facedwn")
    if not _follow_up(player, opponent, "kick"):
        player._candidate_clip_paths["all_impct_facedwn"] = saved
        return false
    player._candidate_clip_paths["all_impct_facedwn"] = saved
    if player.state == "impactfacedown":
        push_error("Missing all_impct_facedwn still entered impactfacedown")
        return false
    if player.state != "hitstun" or player.last_reaction_source_action != "impacthardrightlow":
        push_error("Missing ground clip did not keep the standing low reaction")
        return false
    return true


func _enter_facedown(player: PortFighter, opponent: PortFighter) -> bool:
    player.reset_fighter(Vector3(0.6, 1.2, 0.0))
    opponent.reset_fighter(Vector3(0.0, 1.2, 0.0))
    if not opponent.request_attack("kick"):
        push_error("Could not start the knockdown kick")
        return false
    opponent._advance_timed_states(float(opponent.ATTACKS["kick"]["startup"]))
    opponent._try_attack_contact()
    player._advance_timed_states(player.state_time + 0.001)
    player._animate_candidate()
    player.move_axis = Vector2.ZERO
    if player.state != "facedownidle" or not _clip_is(player.candidate_animation_clip, "all_idle_face_down"):
        push_error("Could not enter facedownidle before the ground impact")
        return false
    return true


func _follow_up(player: PortFighter, opponent: PortFighter, kind: String) -> bool:
    opponent.reset_fighter(Vector3(0.0, 1.2, 0.0))
    player.global_position = Vector3(0.6, 1.2, 0.0)
    player.velocity = Vector3.ZERO
    if not opponent.request_attack(kind):
        push_error("Could not start facedown follow-up " + kind)
        return false
    opponent._advance_timed_states(float(opponent.ATTACKS[kind]["startup"]))
    opponent._try_attack_contact()
    player._animate_candidate()
    return true


func _impact_is(player: PortFighter, health: float, position_x: float) -> bool:
    var animation: AnimationPlayer = player.get("_candidate_animation")
    return (
        player.state == "impactfacedown"
        and player.last_reaction_source_action == "impactfacedown"
        and player.last_reaction_animation == "all_impct_facedwn"
        and player.last_reaction_exit_frame == 11
        and player.last_reaction_clip_implemented
        and _clip_is(player.candidate_animation_clip, "all_impct_facedwn")
        and animation != null
        and _clip_is(String(animation.current_animation), "all_impct_facedwn")
        and absf(player.source_radius_for_current_animation() - 80.0) <= 0.001
        and absf(player.health - health) <= 0.001
        and player.health > 0.0
        and absf(player.position.x - position_x) <= 0.001
        and not bool(player.EXACT_REACTIONS["hit"][1]["clip_implemented"])
        and not bool(player.EXACT_REACTIONS["hit"][1]["return_implemented"])
    )


func _character_tracks_disabled(player: PortFighter, animation_name: String) -> bool:
    var animation: AnimationPlayer = player.get("_candidate_animation")
    var clip_path: String = _find_clip(animation, animation_name)
    if clip_path.is_empty():
        push_error("Missing clip for track check: " + animation_name)
        return false
    var clip: Animation = animation.get_animation(clip_path)
    var animation_root: Node = animation.get_node_or_null(animation.root_node)
    for track: int in clip.get_track_count():
        var kind: int = clip.track_get_type(track)
        if kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
            continue
        var target: Node = animation_root.get_node_or_null(clip.track_get_path(track))
        if target == null or String(target.name) != "character":
            continue
        if clip.track_is_enabled(track):
            push_error("Character transform track stayed enabled: " + animation_name)
            return false
    return true


func _find_clip(animation: AnimationPlayer, expected: String) -> String:
    if animation == null:
        return ""
    for clip: StringName in animation.get_animation_list():
        var name: String = String(clip)
        if name == expected or name.ends_with("/" + expected):
            return name
    return ""


func _clip_is(actual: String, expected: String) -> bool:
    return actual == expected or actual.ends_with("/" + expected)


func _count_ko_hit(
        _attacker: PortFighter,
        _defender: PortFighter,
        _action: String,
        _damage: float,
        _blocked: bool
) -> void:
    _ko_hit_count += 1

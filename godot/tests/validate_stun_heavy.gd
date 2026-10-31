extends SceneTree
## Validate the hard stun-impact reaction on the 50-clip candidate.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the 50-clip Bruce candidate GLB")
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
        push_error("Stun-heavy candidate failed: " + player.candidate_load_error)
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    for required: String in ["stun_hard"]:
        if not clips.has(required):
            push_error("Candidate is missing " + required)
            quit(1)
            return
    var ko_seen: Array = [false]
    var dispatched: Dictionary = player.reaction_for_incoming(
        {"strength": "hard", "height": "high", "direction": "frontal"}, false
    )
    if (dispatched.is_empty()
            or String(dispatched.get("source_action", "")) != "impacthardfronthigh"
            or String(dispatched.get("animation", "")) != "all_impct_hard_frnt_high"):
        push_error("reaction_for_incoming did not dispatch the hard frontal reaction")
        quit(1)
        return
    player.combat_ko.connect(func(_fighter: PortFighter) -> void: ko_seen[0] = true)
    var cases: Array[Dictionary] = [
        {
            "source": "impacthardfronthigh",
            "key": "stun_hard",
            "from": "stun",
            "frames": 20,
            "next": "faceupko",
        },
        {
            "source": "impacthardfronthigh",
            "key": "stun_hard",
            "from": "stun2",
            "frames": 20,
            "next": "faceupko",
        },
    ]
    for case: Dictionary in cases:
        player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
        player.state = String(case["from"])
        player.state_time = 0.1
        player.health = 0.0
        var reaction: Dictionary = {
            "source_action": String(case["source"]),
            "animation": String(clips[String(case["key"])]),
            "exit_start_frame": 20,
            "animation_duration_frames": 35,
            "linking_frame": 0,
        }
        if not player.receive_hit(1.0, false, 0.0, 1.0, reaction):
            push_error("stun impact rejected " + String(case["source"]))
            quit(1)
            return
        player._animate_candidate()
        if player.candidate_animation_clip != String(clips[String(case["key"])]):
            push_error("stun impact clip mismatch for " + String(case["source"]))
            quit(1)
            return
        for _i: int in range(int(case["frames"])):
            player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        if player.state != String(case["next"]):
            push_error(
                "stun impact next state mismatch for " + String(case["source"])
                + ": " + player.state
            )
            quit(1)
            return
        if not bool(ko_seen[0]):
            push_error("stun impact did not emit combat_ko for " + String(case["source"]))
            quit(1)
            return
        ko_seen[0] = false
    # hard/medium satisfies overlapping source links; hard-first is a PC choice.
    var hard_medium: Dictionary = player.reaction_for_incoming(
        {"strength": "hard", "height": "medium", "direction": "frontal"}, false
    )
    player.reset_fighter(Vector3.ZERO)
    player.state = "stun"
    player.health = 10.0
    if not player.receive_hit(2.0, false, 0.0, 1.0, hard_medium):
        push_error("hard/medium dispatch was rejected")
        quit(1)
        return
    if (player.state != "stunimpact" or player.health != 8.0
            or player.last_reaction_animation != "stun_hard"):
        push_error("hard/medium did not select the candidate hard reaction")
        quit(1)
        return
    # Source links 134/133: brutal stun hit -> stunbrutalimpact -> facedownko.
    for origin: String in ["stun", "stun2"]:
        player.reset_fighter(Vector3.ZERO)
        player.state = origin
        player.health = 10.0
        var brutal_reaction: Dictionary = player.reaction_for_incoming(
            {"strength": "brutal", "height": "medium", "direction": "frontal"}, false
        )
        if (String(brutal_reaction.get("source_action", "")) != "stunbrutalimpact"
                or String(brutal_reaction.get("animation", "")) != "stun_brutal"):
            push_error("brutal stun reaction did not select stunbrutalimpact from " + origin)
            quit(1)
            return
        if not player.receive_hit(2.0, false, 0.0, 1.0, brutal_reaction):
            push_error("brutal stun hit was rejected from " + origin)
            quit(1)
            return
        if (player.state != "stunimpact" or player.health != 8.0
                or player.last_reaction_animation != "stun_brutal"):
            push_error("brutal stun hit mismatch from " + origin)
            quit(1)
            return
        for _i: int in range(39):
            player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        if player.state != "stunimpact":
            push_error("brutal stunimpact ended before frame 40 from " + origin)
            quit(1)
            return
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        if player.state != "facedownko":
            push_error("brutal stunimpact did not enter facedownko from " + origin)
            quit(1)
            return
    # Source links 96/346: brutal block -> highblockbrutal -> idle2 [17,20].
    player.reset_fighter(Vector3.ZERO)
    player.health = 10.0
    var brutal_block: Dictionary = player.reaction_for_incoming(
        {"strength": "brutal", "height": "medium", "direction": "frontal"}, true
    )
    if (String(brutal_block.get("source_action", "")) != "highblockbrutal"
            or String(brutal_block.get("animation", "")) != "all_block_high_brutal"):
        push_error("brutal block did not select highblockbrutal")
        quit(1)
        return
    if (int(brutal_block.get("exit_start_frame", -1)) != 17
            or int(brutal_block.get("animation_duration_frames", -1)) != 20
            or String(brutal_block.get("return_action", "")) != "idle2"):
        push_error("brutal block metadata does not match source [17,20]")
        quit(1)
        return
    if not player.receive_hit(2.0, true, 0.0, 1.0, brutal_block):
        push_error("brutal block was rejected")
        quit(1)
        return
    if player.state != "blockstun" or absf(player.health - 9.76) > 0.001:
        push_error("brutal block did not enter blockstun with chip damage")
        quit(1)
        return
    # Source links 237/337: brutal medium frontal hit -> impactbrutalmid -> facedownidle.
    player.reset_fighter(Vector3.ZERO)
    player.health = 100.0
    var brutal_mid: Dictionary = player.reaction_for_incoming(
        {"strength": "brutal", "height": "medium", "direction": "frontal"}, false
    )
    if (String(brutal_mid.get("source_action", "")) != "impactbrutalmid"
            or String(brutal_mid.get("animation", "")) != "all_sp_pnch_low_forset04"
            or int(brutal_mid.get("exit_start_frame", -1)) != 25
            or int(brutal_mid.get("animation_duration_frames", -1)) != 28
            or String(brutal_mid.get("return_action", "")) != "facedownidle"):
        push_error("brutal medium hit did not select impactbrutalmid metadata")
        quit(1)
        return
    if int(brutal_mid.get("entry_frame", -1)) != 6:
        push_error("brutal medium hit lacks source entry_frame 6")
        quit(1)
        return
    if not player.receive_hit(5.0, false, 0.0, 1.0, brutal_mid):
        push_error("brutal medium hit was rejected")
        quit(1)
        return
    if (player.state != "hitstun" or absf(player.health - 95.0) > 0.001
            or player.last_reaction_source_action != "impactbrutalmid"):
        push_error("brutal medium hit did not enter hitstun")
        quit(1)
        return
    if (player.last_reaction_entry_frame != 6
            or absf(player.state_time - 19.0 / PortFighter.SOURCE_FRAME_RATE) > 0.001):
        push_error("brutal medium runtime did not start at frame 6 and end at 25")
        quit(1)
        return
    if clips.has("all_sp_pnch_low_forset04"):
        player._animate_candidate()
        if absf(player._candidate_animation.current_animation_position
                - 6.0 / PortFighter.SOURCE_FRAME_RATE) > 0.001:
            push_error("brutal medium animation did not seek to frame 6")
            quit(1)
            return
    player.reset_fighter(Vector3.ZERO)
    player.state = "faceupidle"
    if not player.reaction_for_incoming(
        {"strength": "brutal", "height": "medium", "direction": "frontal"}, false
    ).is_empty():
        push_error("non-impactable state accepted brutal medium reaction")
        quit(1)
        return
    for case: Dictionary in [
        {"height": "high", "direction": "fromleft",
            "source": "impactbrutalleft", "animation": "all_impct_spectacular_lft",
            "exit": 39, "duration": 45},
        {"height": "high", "direction": "fromright",
            "source": "impactbrutalright", "animation": "all_impct_spectacular_rht",
            "exit": 41, "duration": 45},
    ]:
        player.reset_fighter(Vector3.ZERO)
        player.health = 100.0
        var reaction: Dictionary = player.reaction_for_incoming({
            "strength": "brutal", "height": String(case["height"]),
            "direction": String(case["direction"]),
        }, false)
        if (String(reaction.get("source_action", "")) != String(case["source"])
                or String(reaction.get("animation", "")) != String(case["animation"])
                or int(reaction.get("exit_start_frame", -1)) != int(case["exit"])
                or int(reaction.get("animation_duration_frames", -1)) != int(case["duration"])):
            push_error("brutal high reaction metadata mismatch: " + String(case["source"]))
            quit(1)
            return
        if not player.receive_hit(5.0, false, 0.0, 1.0, reaction):
            push_error("brutal high hit was rejected: " + String(case["source"]))
            quit(1)
            return
        if (player.state != "hitstun" or absf(player.health - 95.0) > 0.001
                or player.last_reaction_source_action != String(case["source"])):
            push_error("brutal high hit did not enter hitstun: " + String(case["source"]))
            quit(1)
            return
    for case: Dictionary in [
        {"height": "high", "direction": "fromleft", "exit": 15,
            "source": "impactlightlefthigh", "animation": "all_impct_light_lft_high"},
        {"height": "high", "direction": "fromright", "exit": 15,
            "source": "impactlightrighthigh", "animation": "all_impct_light_rht_high"},
        {"height": "low", "direction": "fromleft", "exit": 15,
            "source": "impactlightleftlow", "animation": "all_impct_light_lft_low"},
        {"height": "low", "direction": "fromright", "exit": 13,
            "source": "impactlightrightlow", "animation": "all_impct_light_rht_low"},
    ]:
        player.reset_fighter(Vector3.ZERO)
        player.health = 100.0
        var reaction: Dictionary = player.reaction_for_incoming({
            "strength": "normal", "height": String(case["height"]),
            "direction": String(case["direction"]),
        }, false)
        if (String(reaction.get("source_action", "")) != String(case["source"])
                or String(reaction.get("animation", "")) != String(case["animation"])
                or int(reaction.get("exit_start_frame", -1)) != int(case["exit"])
                or int(reaction.get("animation_duration_frames", -1)) != 17):
            push_error("normal directional reaction mismatch: " + String(case["source"]))
            quit(1)
            return
        if not player.receive_hit(5.0, false, 0.0, 1.0, reaction):
            push_error("normal directional hit was rejected: " + String(case["source"]))
            quit(1)
            return
        if (player.state != "hitstun" or absf(player.health - 95.0) > 0.001
                or player.last_reaction_source_action != String(case["source"])):
            push_error("normal directional hit did not enter hitstun: " + String(case["source"]))
            quit(1)
            return
    for case: Dictionary in [
        {"height": "low", "direction": "fromleft", "exit": 25, "duration": 29,
            "source": "impacthardleftlow", "animation": "all_impct_hard_lft_low",
            "return": "faceupidle"},
        {"height": "high", "direction": "fromleft", "exit": 26, "duration": 29,
            "source": "impacthardlefthigh", "animation": "all_impct_hard_lft_high",
            "return": "faceupidle"},
        {"height": "high", "direction": "fromabove", "exit": 17, "duration": 17,
            "source": "impacthardabove", "animation": "all_impct_hard_above",
            "return": "facedownidle"},
    ]:
        player.reset_fighter(Vector3.ZERO)
        player.health = 100.0
        var reaction: Dictionary = player.reaction_for_incoming({
            "strength": "hard", "height": String(case["height"]),
            "direction": String(case["direction"]),
        }, false)
        if (String(reaction.get("source_action", "")) != String(case["source"])
                or String(reaction.get("animation", "")) != String(case["animation"])
                or int(reaction.get("exit_start_frame", -1)) != int(case["exit"])
                or int(reaction.get("animation_duration_frames", -1)) != int(case["duration"])
                or String(reaction.get("return_action", "")) != String(case["return"])):
            push_error("hard directional reaction mismatch: " + String(case["source"]))
            quit(1)
            return
        if not player.receive_hit(5.0, false, 0.0, 1.0, reaction):
            push_error("hard directional hit was rejected: " + String(case["source"]))
            quit(1)
            return
        if (player.state != "hitstun" or absf(player.health - 95.0) > 0.001
                or player.last_reaction_source_action != String(case["source"])):
            push_error("hard directional hit did not enter hitstun: " + String(case["source"]))
            quit(1)
            return
    # Source link 113: hard high frontal lethal hit -> faceupko.
    player.reset_fighter(Vector3.ZERO)
    player.health = 5.0
    var hard_high_lethal: Dictionary = player.reaction_for_incoming(
        {"strength": "hard", "height": "high", "direction": "frontal"}, false
    )
    if not player.receive_hit(5.0, false, 0.0, 1.0, hard_high_lethal):
        push_error("hard high frontal lethal hit was rejected")
        quit(1)
        return
    if (player.state != "stunimpact"
            or player.last_reaction_source_action != "impacthardfronthigh"
            or player.last_reaction_animation != "all_impct_hard_frnt_high"):
        push_error("hard high frontal lethal path mismatch")
        quit(1)
        return
    for _i: int in range(22):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stunimpact":
        push_error("hard high frontal lethal ended before frame 23")
        quit(1)
        return
    player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "faceupko":
        push_error("hard high frontal lethal did not enter faceupko")
        quit(1)
        return
    # Repeated same high-frontal hit must restart the reaction animation.
    player.reset_fighter(Vector3.ZERO)
    player.health = 10.0
    var repeat_reaction: Dictionary = player.reaction_for_incoming(
        {"strength": "hard", "height": "high", "direction": "frontal"}, false
    )
    if not player.receive_hit(2.0, false, 0.0, 1.0, repeat_reaction):
        push_error("nonlethal hard high setup was rejected")
        quit(1)
        return
    if clips.has("all_impct_hard_frnt_high"):
        player._animate_candidate()
    if not player.receive_hit(8.0, false, 0.0, 1.0, repeat_reaction):
        push_error("repeated lethal hard high hit was rejected")
        quit(1)
        return
    if player.state != "stunimpact" or player._candidate_action != "":
        push_error("repeated lethal hard high did not reset the reaction action")
        quit(1)
        return
    if clips.has("all_impct_hard_frnt_high"):
        player._animate_candidate()
        if absf(player._candidate_animation.current_animation_position) > 0.01:
            push_error("repeated lethal hard high did not restart animation")
            quit(1)
            return
    # Source links 228/213/214: hard low/medium frontal hits use frontlow.
    player.reset_fighter(Vector3.ZERO)
    player.health = 100.0
    var frontlow_reaction: Dictionary = player.reaction_for_incoming(
        {"strength": "hard", "height": "low", "direction": "frontal"}, false
    )
    if (String(frontlow_reaction.get("source_action", "")) != "impacthardfrontlow"
            or String(frontlow_reaction.get("animation", "")) != "all_impct_hard_frnt_low"
            or int(frontlow_reaction.get("exit_start_frame", -1)) != 20
            or int(frontlow_reaction.get("animation_duration_frames", -1)) != 23):
        push_error("hard frontlow nonlethal reaction mismatch")
        quit(1)
        return
    if not player.receive_hit(5.0, false, 0.0, 1.0, frontlow_reaction):
        push_error("hard frontlow nonlethal hit was rejected")
        quit(1)
        return
    if player.state != "hitstun" or absf(player.health - 95.0) > 0.001:
        push_error("hard frontlow nonlethal did not enter hitstun")
        quit(1)
        return
    var had_frontlow: bool = clips.has("all_impct_hard_frnt_low")
    if not had_frontlow:
        # State transition is testable without the optional visual clip.
        clips["all_impct_hard_frnt_low"] = "synthetic:all_impct_hard_frnt_low"
    for key: Dictionary in [
        {"height": "low", "source": "impacthardfrontlow"},
        {"height": "medium", "source": "impacthardfrontmid"},
    ]:
        player.reset_fighter(Vector3.ZERO)
        player.health = 5.0
        var lethal_reaction: Dictionary = player.reaction_for_incoming({
            "strength": "hard", "height": String(key["height"]),
            "direction": "frontal",
        }, false)
        if String(lethal_reaction.get("source_action", "")) != String(key["source"]):
            push_error("hard frontlow lethal dispatch mismatch: " + String(key["source"]))
            quit(1)
            return
        if not player.receive_hit(5.0, false, 0.0, 1.0, lethal_reaction):
            push_error("hard frontlow lethal hit was rejected: " + String(key["source"]))
            quit(1)
            return
        if (player.state != "stunimpact"
                or player.last_reaction_source_action != "impacthardfrontlow"
                or player.last_reaction_animation != "all_impct_hard_frnt_low"):
            push_error("hard frontlow lethal path mismatch: " + String(key["source"]))
            quit(1)
            return
        for _i: int in range(20):
            player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        if player.state != "stunimpact":
            push_error("hard frontlow lethal ended before frame 21")
            quit(1)
            return
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        if player.state != "facedownko":
            push_error("hard frontlow lethal did not enter facedownko")
            quit(1)
            return
    if not had_frontlow:
        clips.erase("all_impct_hard_frnt_low")
    print("STUN_HEAVY_VALIDATION=" + JSON.stringify({
        "cases": ["stun hard -> faceupko", "stun2 hard -> faceupko",
            "stun/stun2 brutal -> facedownko", "brutal block -> highblockbrutal",
            "brutal medium -> impactbrutalmid",
            "brutal high left/right -> impactbrutalleft/right",
            "normal directional light hits",
            "hard directional left/above reactions",
            "hard frontlow nonlethal/lethal reactions",
            "hard high frontal lethal faceupko"],
        "scope": "prototype hard stun-impact transition; source timing approximate",
    }))
    scene.queue_free()
    await process_frame
    quit(0)

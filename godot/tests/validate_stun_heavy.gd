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
    print("STUN_HEAVY_VALIDATION=" + JSON.stringify({
        "cases": ["stun hard -> faceupko", "stun2 hard -> faceupko",
            "stun/stun2 brutal -> facedownko", "brutal block -> highblockbrutal",
            "brutal medium -> impactbrutalmid",
            "brutal high left/right -> impactbrutalleft/right"],
        "scope": "prototype hard stun-impact transition; source timing approximate",
    }))
    scene.queue_free()
    await process_frame
    quit(0)

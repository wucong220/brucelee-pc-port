extends SceneTree
## Validate the prototype stun state for healthzero impactstun links.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 1:
        push_error("Expected the 48-clip Bruce candidate GLB")
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
    var ko_seen: Array = [false]
    player.combat_ko.connect(func(_fighter: PortFighter) -> void: ko_seen[0] = true)
    if not player.candidate_loaded:
        push_error("Stun candidate failed: " + player.candidate_load_error)
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    for required: String in ["stun", "stun_fall"]:
        if not clips.has(required):
            push_error("Candidate is missing " + required)
            quit(1)
            return
    for dispatch_case: Dictionary in [
        {"height": "high", "source": "impactlightfronthigh", "animation": "all_impct_light_frnt_high"},
        {"height": "low", "source": "impactlightfrontlow", "animation": "all_impct_light_frnt_low"},
        {"height": "medium", "source": "impactlightfrontmid", "animation": "all_impct_light_frnt_mid"},
    ]:
        var dispatched: Dictionary = player.reaction_for_incoming(
            {"strength": "normal", "height": String(dispatch_case["height"]), "direction": "frontal"},
            false,
        )
        if (String(dispatched.get("source_action", "")) != String(dispatch_case["source"])
                or String(dispatched.get("animation", "")) != String(dispatch_case["animation"])):
            push_error("reaction_for_incoming mismatch for " + String(dispatch_case["height"]))
            quit(1)
            return
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 5.0
    var reaction: Dictionary = {
        "source_action": "impactlightfronthigh",
        "animation": "all_impct_light_frnt_high",
        "exit_start_frame": 13,
        "animation_duration_frames": 17,
        "linking_frame": 0,
    }
    if not player.receive_hit(5.0, false, 0.0, 1.0, reaction):
        push_error("receive_hit rejected stun fixture")
        quit(1)
        return
    if player.state != "impactstun":
        push_error("Lethal normal hit did not enter impactstun: " + player.state)
        quit(1)
        return
    player._animate_candidate()
    if player.candidate_animation_clip != String(clips["all_impct_light_frnt_high"]):
        push_error("impactstun did not play all_impct_light_frnt_high")
        quit(1)
        return
    for _i: int in range(14):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stun":
        push_error("impactstun did not enter stun: " + player.state)
        quit(1)
        return
    player._animate_candidate()
    if player.candidate_animation_clip != String(clips["stun"]):
        push_error("stun did not play all_stunned")
        quit(1)
        return
    for _i: int in range(PortFighter.STUN_DURATION_FRAMES):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stun2":
        push_error("stun did not advance to stun2: " + player.state)
        quit(1)
        return
    player._animate_candidate()
    if player.candidate_animation_clip != String(clips["stun"]):
        push_error("stun2 did not keep playing all_stunned")
        quit(1)
        return
    for _i: int in range(PortFighter.STUN_DURATION_FRAMES):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stunfall":
        push_error("stun2 did not advance to stunfall: " + player.state)
        quit(1)
        return
    player._animate_candidate()
    if player.candidate_animation_clip != String(clips["stun_fall"]):
        push_error("stunfall did not play all_stunned_fall")
        quit(1)
        return
    for _i: int in range(PortFighter.STUN_FALL_DURATION_FRAMES - 1):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stunfall":
        push_error("stunfall ended before its 71-79 source window: " + player.state)
        quit(1)
        return
    player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "faceupko":
        push_error("stunfall did not finish in faceupko at the source window start: " + player.state)
        quit(1)
        return
    if not bool(ko_seen[0]):
        push_error("stunfall -> faceupko did not emit combat_ko")
        quit(1)
        return
    ko_seen[0] = false
    # Lethal low hit must use the low impactstun entry, not the high clip.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 5.0
    var low_reaction: Dictionary = {
        "source_action": "impactlightfrontlow",
        "animation": "all_impct_light_frnt_low",
        "exit_start_frame": 13,
        "animation_duration_frames": 17,
        "linking_frame": 0,
    }
    if not player.receive_hit(5.0, false, 0.0, 1.0, low_reaction):
        push_error("low impactstun fixture rejected")
        quit(1)
        return
    if player.state != "impactstun":
        push_error("low impactstun did not enter impactstun: " + player.state)
        quit(1)
        return
    player._animate_candidate()
    if player.candidate_animation_clip != String(clips["all_impct_light_frnt_low"]):
        push_error("low impactstun did not play all_impct_light_frnt_low")
        quit(1)
        return
    for _i: int in range(13):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "impactstun":
        push_error("low impactstun ended before frame 14: " + player.state)
        quit(1)
        return
    player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stun":
        push_error("low impactstun did not enter stun on frame 14: " + player.state)
        quit(1)
        return
    # Source link 210 routes lethal normal medium hits through impactstunlow.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 5.0
    var medium_reaction: Dictionary = player.reaction_for_incoming(
        {"strength": "normal", "height": "medium", "direction": "frontal"}, false
    )
    if not player.receive_hit(5.0, false, 0.0, 1.0, medium_reaction):
        push_error("medium lethal hit was rejected")
        quit(1)
        return
    if player.state != "impactstun" or player.last_reaction_animation != "all_impct_light_frnt_low":
        push_error("medium lethal hit did not enter low impactstun: " + player.state)
        quit(1)
        return
    if absf(player.health) > 0.001 or bool(ko_seen[0]):
        push_error("medium lethal entry has incorrect health or premature KO")
        quit(1)
        return
    player._advance_timed_states(13.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "impactstun":
        push_error("medium impactstun ended before frame 14")
        quit(1)
        return
    player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stun":
        push_error("medium impactstun did not enter stun on frame 14")
        quit(1)
        return
    ko_seen[0] = false
    # The source facedowngetup impactable group starts at frame 12.
    for frame: int in [11, 12]:
        player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
        player.state = "facedowngetup"
        player.state_time = float(frame) / PortFighter.SOURCE_FRAME_RATE
        player.health = 5.0
        if not player.receive_hit(5.0, false, 0.0, 1.0, medium_reaction):
            push_error("facedowngetup medium hit rejected at frame %d" % frame)
            quit(1)
            return
        var expected_state: String = "impactstun" if frame == 12 else "ko"
        if player.state != expected_state:
            push_error("facedowngetup frame %d selected %s instead of %s" % [frame, player.state, expected_state])
            quit(1)
            return
    # highkick3 joins impactable at frame 17; the previous frame is excluded.
    for frame: int in [16, 17]:
        player.reset_fighter(Vector3.ZERO)
        player.state = "active"
        player.attack_kind = "high_kick3"
        var details: Dictionary = player.ATTACKS["high_kick3"]
        player.state_time = (float(details["animation_frame_count"]) - float(frame)) / PortFighter.SOURCE_FRAME_RATE - float(details["recovery"])
        if player._medium_lethal_impactable() != (frame == 17):
            push_error("highkick3 impactable window mismatch at frame %d" % frame)
            quit(1)
            return
    # Source facedownattack is impactable at [29,35]; candidate exits at 32.
    for frame: int in [28, 29]:
        player.reset_fighter(Vector3.ZERO)
        player.state = "facedownattack"
        player.state_time = float(frame) / PortFighter.SOURCE_FRAME_RATE
        player.health = 5.0
        player.receive_hit(5.0, false, 0.0, 1.0, medium_reaction)
        if player.state != ("impactstun" if frame == 29 else "ko"):
            push_error("facedownattack medium entry mismatch at frame %d" % frame)
            quit(1)
            return
    player.reset_fighter(Vector3.ZERO)
    player.state = "hitstun"
    player.last_reaction_source_action = "impactlightfrontmid"
    player.last_reaction_exit_frame = 14
    player.state_time = 5.0 / PortFighter.SOURCE_FRAME_RATE
    player.health = 5.0
    player.receive_hit(5.0, false, 0.0, 1.0, medium_reaction)
    if player.state != "impactstun":
        push_error("impactable light reaction did not accept medium lethal hit")
        quit(1)
        return
    # Missing low impact clip must fall back rather than enter a blank state.
    var saved_low_clip: String = String(clips["all_impct_light_frnt_low"])
    clips.erase("all_impct_light_frnt_low")
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 5.0
    player.receive_hit(5.0, false, 0.0, 1.0, medium_reaction)
    clips["all_impct_light_frnt_low"] = saved_low_clip
    if player.state != "ko":
        push_error("Missing low clip did not fall back to KO")
        quit(1)
        return
    ko_seen[0] = false
    # Nonlethal and blocked hits must not enter the stun state.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 100.0
    if not player.receive_hit(5.0, false, 0.0, 1.0, reaction):
        push_error("nonlethal stun fixture rejected")
        quit(1)
        return
    if player.state != "hitstun":
        push_error("nonlethal hit entered " + player.state + " instead of hitstun")
        quit(1)
        return
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 5.0
    if not player.receive_hit(100.0, true, 0.0, 1.0, reaction):
        push_error("blocked stun fixture rejected")
        quit(1)
        return
    if player.state == "stun":
        push_error("blocked lethal hit entered stun")
        quit(1)
        return
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.state = "stun"
    player.state_time = 0.1
    player.health = 0.0
    var stun_reaction: Dictionary = {
        "source_action": "impactlightfronthigh",
        "animation": "all_impct_light_frnt_high",
        "exit_start_frame": 13,
        "animation_duration_frames": 17,
        "linking_frame": 0,
    }
    if not player.receive_hit(1.0, false, 0.0, 1.0, stun_reaction):
        push_error("stun impact fixture rejected")
        quit(1)
        return
    if player.state != "stunimpact":
        push_error("stun hit did not enter stunimpact: " + player.state)
        quit(1)
        return
    player._animate_candidate()
    if player.candidate_animation_clip != String(clips["all_impct_light_frnt_high"]):
        push_error("stunimpact did not play all_impct_light_frnt_high")
        quit(1)
        return
    for _i: int in range(14):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stunfall":
        push_error("stunimpact did not return to stunfall: " + player.state)
        quit(1)
        return
    var stun_cases: Array[Dictionary] = [
        {"source": "impactlightfrontlow", "animation": "all_impct_light_frnt_low", "accepted": true},
        {"source": "impactlightfrontmid", "animation": "all_impct_crotch", "accepted": true},
        {"source": "impacthardfrontlow", "animation": "", "accepted": false},
        {"source": "impactbrutallow", "animation": "", "accepted": false},
    ]
    for case: Dictionary in stun_cases:
        player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
        player.state = "stun"
        player.state_time = 0.1
        player.health = 0.0
        var case_reaction: Dictionary = {
            "source_action": String(case["source"]),
            "animation": String(case["animation"]),
            "exit_start_frame": 13,
            "animation_duration_frames": 17,
            "linking_frame": 0,
        }
        var accepted: bool = player.receive_hit(1.0, false, 0.0, 1.0, case_reaction)
        if accepted != bool(case["accepted"]):
            push_error("stunimpact acceptance mismatch for " + String(case["source"]))
            quit(1)
            return
        if accepted:
            if player.state != "stunimpact":
                push_error("accepted stunimpact did not enter stunimpact")
                quit(1)
                return
            player._animate_candidate()
            if player.candidate_animation_clip != String(clips[String(case["animation"])]):
                push_error("stunimpact clip mismatch for " + String(case["source"]))
                quit(1)
                return
        elif player.state != "stun":
            push_error("rejected stunimpact changed state for " + String(case["source"]))
            quit(1)
            return
    # Source link 131 offers [15,20]; the PC candidate selects frame 15.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.state = "stun"
    player.state_time = 0.1
    player.health = 0.0
    if not player.receive_hit(1.0, false, 0.0, 1.0, player.reaction_for_incoming(
        {"strength": "normal", "height": "medium", "direction": "frontal"}, false
    )):
        push_error("medium stunimpact fixture rejected")
        quit(1)
        return
    for _i: int in range(14):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stunimpact":
        push_error("medium stunimpact ended before 15 frames")
        quit(1)
        return
    # Repeated impact remains fail-closed in the current prototype.
    var timer_before_repeat: float = player.state_time
    var health_before_repeat: float = player.health
    if player.receive_hit(3.0, false, 0.0, 1.0, medium_reaction):
        push_error("Repeated stunimpact unexpectedly accepted")
        quit(1)
        return
    if (player.state != "stunimpact" or player.state_time != timer_before_repeat
            or player.health != health_before_repeat):
        push_error("Rejected repeated impact changed the state")
        quit(1)
        return
    player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if player.state != "stunfall":
        push_error("medium stunimpact did not end in stunfall on frame 15: " + player.state)
        quit(1)
        return
    # Both stun states use real normal/medium dispatch and the 15-frame exit.
    for origin: String in ["stun", "stun2"]:
        player.reset_fighter(Vector3.ZERO)
        player.state = origin
        player.health = 10.0
        if not player.receive_hit(2.0, false, 0.0, 1.0, medium_reaction):
            push_error("Normal medium was rejected from " + origin)
            quit(1)
            return
        if (player.state != "stunimpact" or player.health != 8.0
                or player.last_reaction_animation != "all_impct_crotch"):
            push_error("Normal medium dispatch mismatch from " + origin)
            quit(1)
            return
        player._advance_timed_states(14.0 / PortFighter.SOURCE_FRAME_RATE)
        if player.state != "stunimpact":
            push_error("Medium stunimpact exited early from " + origin)
            quit(1)
            return
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        if player.state != "stunfall":
            push_error("Medium stunimpact missed frame-15 exit from " + origin)
            quit(1)
            return
    # Nonlethal normal medium must stay hitstun and preserve health.
    player.reset_fighter(Vector3.ZERO)
    player.health = 100.0
    if not player.receive_hit(2.0, false, 0.0, 1.0, medium_reaction):
        push_error("Nonlethal medium was rejected")
        quit(1)
        return
    if player.state != "hitstun" or player.health != 98.0:
        push_error("Nonlethal medium did not stay in hitstun")
        quit(1)
        return
    # Blocked lethal medium must enter blockstun without the impactstun chain.
    player.reset_fighter(Vector3.ZERO)
    player.health = 5.0
    if not player.receive_hit(5.0, true, 0.0, 1.0, medium_reaction):
        push_error("Blocked medium was rejected")
        quit(1)
        return
    if player.state != "blockstun" or player.health <= 0.0:
        push_error("Blocked medium entered an invalid state")
        quit(1)
        return
    # Missing medium reaction clip must reject the hit without state or health changes.
    var saved_crotch_clip: String = String(clips["all_impct_crotch"])
    clips.erase("all_impct_crotch")
    player.reset_fighter(Vector3.ZERO)
    player.state = "stun"
    player.health = 10.0
    var accepted_without_crotch: bool = player.receive_hit(2.0, false, 0.0, 1.0, medium_reaction)
    clips["all_impct_crotch"] = saved_crotch_clip
    if accepted_without_crotch or player.state != "stun" or player.health != 10.0:
        push_error("Missing medium reaction clip changed stun state or health")
        quit(1)
        return
    # Empty reaction source must fail closed from both stun and stun2.
    for source_state: String in ["stun", "stun2"]:
        player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
        player.state = source_state
        player.state_time = 0.1
        player.health = 0.0
        if player.receive_hit(1.0, false, 0.0, 1.0, {}):
            push_error("empty stunimpact reaction was accepted from " + source_state)
            quit(1)
            return
        if player.state != source_state:
            push_error("empty stunimpact reaction changed state from " + source_state)
            quit(1)
            return
    # If the high impact clip is absent, impactstun must fall through to KO.
    var saved_high_clip: String = String(clips["all_impct_light_frnt_high"])
    clips.erase("all_impct_light_frnt_high")
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 5.0
    if not player.receive_hit(5.0, false, 0.0, 1.0, reaction):
        push_error("missing-high-clip fixture was rejected")
        quit(1)
        return
    if player.state != "ko":
        push_error("missing high clip did not fall through to ko: " + player.state)
        quit(1)
        return
    clips["all_impct_light_frnt_high"] = saved_high_clip
    var defender: PortFighter = PortFighter.new()
    defender.configure("Stun endmove defender", false, Color.CYAN)
    defender.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    defender.configure_candidate_asset(args[0], "", PortFighter.CANDIDATE_CLIPS, "body")
    root.add_child(defender)
    await process_frame
    if not defender.candidate_loaded:
        push_error("Stun endmove defender candidate failed")
        quit(1)
        return
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 100.0
    defender.reset_fighter(Vector3(-1.9, 1.20, 0.0))
    defender.health = 5.0
    player.opponent = defender
    if not player.request_attack("high_punch"):
        push_error("Stun endmove attack did not start")
        quit(1)
        return
    for _i: int in range(6):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    for _i: int in range(14):
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if defender.state != "stun":
        push_error("Stun endmove setup did not stun defender: " + defender.state)
        quit(1)
        return
    player.record_standing_combo_press("b", ["up", "in"])
    player.record_standing_combo_press("a")
    player.record_standing_combo_press("a")
    if player.attack_kind != "endattack1":
        push_error("Stun opponent did not accept endattack1: " + player.attack_kind)
        quit(1)
        return
    player._animate_candidate()
    var player_clips: Dictionary = player.get("_candidate_clip_paths")
    if player.candidate_animation_clip != String(player_clips.get("endattack1", "")):
        push_error("Stun endmove did not play the endattack1 candidate clip")
        quit(1)
        return
    # endattack2 must also be reachable from stun.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 100.0
    defender.reset_fighter(Vector3(-1.9, 1.20, 0.0))
    defender.health = 5.0
    player.opponent = defender
    if not player.request_attack("high_punch"):
        push_error("Stun endattack2 setup did not start")
        quit(1)
        return
    for _i: int in range(6):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    for _i: int in range(14):
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if defender.state != "stun":
        push_error("Stun endattack2 setup did not stun defender: " + defender.state)
        quit(1)
        return
    player.record_standing_combo_press("a", ["up", "in"])
    player.record_standing_combo_press("c")
    player.record_standing_combo_press("c")
    if player.attack_kind != "endattack2":
        push_error("Stun opponent did not accept endattack2: " + player.attack_kind)
        quit(1)
        return
    # The same endmove gate must work while the opponent is in stun2.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 100.0
    defender.reset_fighter(Vector3(-1.9, 1.20, 0.0))
    defender.health = 5.0
    player.opponent = defender
    if not player.request_attack("high_punch"):
        push_error("Stun2 endmove attack did not start")
        quit(1)
        return
    for _i: int in range(6):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    for _i: int in range(14):
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if defender.state != "stun":
        push_error("Stun2 endmove setup did not stun defender: " + defender.state)
        quit(1)
        return
    for _i: int in range(PortFighter.STUN_DURATION_FRAMES):
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if defender.state != "stun2":
        push_error("Endmove stun2 setup did not reach stun2: " + defender.state)
        quit(1)
        return
    player.record_standing_combo_press("b", ["up", "in"])
    player.record_standing_combo_press("a")
    player.record_standing_combo_press("a")
    if player.attack_kind != "endattack1":
        push_error("Stun2 opponent did not accept endattack1: " + player.attack_kind)
        quit(1)
        return
    # endattack2 must also be reachable from stun2.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 100.0
    defender.reset_fighter(Vector3(-1.9, 1.20, 0.0))
    defender.health = 5.0
    player.opponent = defender
    if not player.request_attack("high_punch"):
        push_error("Stun2 endattack2 setup did not start")
        quit(1)
        return
    for _i: int in range(6):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    for _i: int in range(14):
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if defender.state != "stun":
        push_error("Stun2 endattack2 setup did not stun defender: " + defender.state)
        quit(1)
        return
    for _i: int in range(PortFighter.STUN_DURATION_FRAMES):
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if defender.state != "stun2":
        push_error("Endmove stun2 setup did not reach stun2: " + defender.state)
        quit(1)
        return
    player.record_standing_combo_press("a", ["up", "in"])
    player.record_standing_combo_press("c")
    player.record_standing_combo_press("c")
    if player.attack_kind != "endattack2":
        push_error("Stun2 opponent did not accept endattack2: " + player.attack_kind)
        quit(1)
        return
    # A real normal/medium punch uses the source impactstunlow link.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    defender.reset_fighter(Vector3(-1.9, 1.20, 0.0))
    defender.health = 5.0
    player.opponent = defender
    if not player.request_attack("punch"):
        push_error("Medium punch setup did not start")
        quit(1)
        return
    player._advance_timed_states(6.0 / PortFighter.SOURCE_FRAME_RATE)
    if (defender.state != "impactstun" or defender.health != 0.0
            or defender.last_reaction_animation != "all_impct_light_frnt_low"):
        push_error("Medium punch did not enter low impactstun: " + defender.state)
        quit(1)
        return
    # A real low kick must enter impactstun with the low clip before stun.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 100.0
    defender.reset_fighter(Vector3(-1.9, 1.20, 0.0))
    defender.health = 5.0
    player.opponent = defender
    if not player.request_attack("kick"):
        push_error("Low kick setup did not start")
        quit(1)
        return
    for _i: int in range(10):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if defender.state != "impactstun":
        push_error("Low kick did not enter impactstun: " + defender.state)
        quit(1)
        return
    var remaining_impact_frames: int = int(round(
        defender.state_time * PortFighter.SOURCE_FRAME_RATE
    ))
    for _i: int in range(maxi(remaining_impact_frames, 0)):
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if defender.state != "stun":
        push_error("Low kick impactstun did not enter stun: " + defender.state)
        quit(1)
        return
    # A real high punch must enter impactstun with the high clip.
    player.reset_fighter(Vector3(-2.0, 1.20, 0.0))
    player.health = 100.0
    defender.reset_fighter(Vector3(-1.9, 1.20, 0.0))
    defender.health = 5.0
    player.opponent = defender
    if not player.request_attack("high_punch"):
        push_error("High punch setup did not start")
        quit(1)
        return
    for _i: int in range(10):
        player._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if defender.state != "impactstun":
        push_error("High punch did not enter impactstun: " + defender.state)
        quit(1)
        return
    defender._animate_candidate()
    if defender.candidate_animation_clip != String(clips["all_impct_light_frnt_high"]):
        push_error("High punch impactstun did not play all_impct_light_frnt_high")
        quit(1)
        return
    var remaining_high_impact: int = int(round(
        defender.state_time * PortFighter.SOURCE_FRAME_RATE
    ))
    for _i: int in range(maxi(remaining_high_impact, 0)):
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if defender.state != "stun":
        push_error("High punch impactstun did not enter stun: " + defender.state)
        quit(1)
        return
    for _i: int in range(PortFighter.STUN_DURATION_FRAMES):
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if defender.state != "stun2":
        push_error("High punch real chain did not reach stun2: " + defender.state)
        quit(1)
        return
    for _i: int in range(PortFighter.STUN_DURATION_FRAMES):
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if defender.state != "stunfall":
        push_error("High punch real chain did not reach stunfall: " + defender.state)
        quit(1)
        return
    for _i: int in range(PortFighter.STUN_FALL_DURATION_FRAMES + 1):
        defender._advance_timed_states(1.0 / PortFighter.SOURCE_FRAME_RATE)
    if defender.state != "faceupko":
        push_error("High punch real chain did not reach faceupko: " + defender.state)
        quit(1)
        return
    defender._animate_candidate()
    if defender.candidate_animation_clip != String(clips["all_idle_face_up"]):
        push_error("faceupko did not play all_idle_face_up")
        quit(1)
        return
    print("STUN_VALIDATION=" + JSON.stringify({
        "state_chain": ["stun", "stun2", "stunfall", "faceupko"],
        "animation": clips["stun"],
        "scope": "prototype stun path for healthzero normal hits; source impactstun timing is not fully recovered",
    }))
    await process_frame
    scene.queue_free()
    await process_frame
    quit(0)

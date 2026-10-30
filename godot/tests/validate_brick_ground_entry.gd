extends SceneTree
## Candidate gameplay chain; this does not validate original runtime behavior.


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and Brick candidate GLBs")
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
    var brick: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    brick.set_physics_process(false)
    if not player.candidate_loaded or not brick.candidate_loaded:
        push_error("Candidates failed to load: %s | %s" % [
            player.candidate_load_error, brick.candidate_load_error])
        quit(1)
        return
    if not _exercise(player, brick):
        quit(1)
        return
    if not _check_candidate_timing(player, brick):
        quit(1)
        return
    print("BRICK_GROUND_ENTRY_CANDIDATE=passed")
    quit(0)


func _reset(player: PortFighter, brick: PortFighter) -> bool:
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    brick.reset_fighter(Vector3(0.6, 1.2, 0.0))
    player.state = "faceupidle"
    player.state_time = 10.0 / PortFighter.SOURCE_FRAME_RATE
    player.facing = 1.0
    player.record_virtual_press("a")
    player.record_virtual_press("a")
    return player.record_virtual_press("a")


func _exercise(player: PortFighter, brick: PortFighter) -> bool:
    var reaction_name: String = PortFighter.BRICK_FRONT_LOW_CLIP
    var idle_name: String = PortFighter.BRICK_FACEDOWN_IDLE_CLIP
    if not brick._candidate_clip_paths.has(reaction_name) or not brick._candidate_clip_paths.has(idle_name):
        push_error("Brick candidate clips failed loading/track checks")
        return false
    var animation: AnimationPlayer = brick.get("_candidate_animation")
    var reaction: Animation = animation.get_animation(brick._candidate_clip_paths[reaction_name])
    var invalid: Animation = reaction.duplicate(true)
    for track: int in range(invalid.get_track_count() - 1, -1, -1):
        invalid.remove_track(track)
    if brick._valid_brick_ground_clip(invalid, 23.0 / PortFighter.SOURCE_FRAME_RATE):
        push_error("Empty reaction clip was accepted")
        return false
    invalid = reaction.duplicate(true)
    invalid.track_set_path(0, NodePath("missing:missing"))
    if brick._valid_brick_ground_clip(invalid, 23.0 / PortFighter.SOURCE_FRAME_RATE):
        push_error("Invalid skeleton target was accepted")
        return false
    invalid = reaction.duplicate(true)
    invalid.length = 0.1
    if brick._valid_brick_ground_clip(invalid, 23.0 / PortFighter.SOURCE_FRAME_RATE):
        push_error("Wrong reaction duration was accepted")
        return false
    for mode: String in ["idle", "move", "punch", "kick"]:
        if not _reset(player, brick):
            return false
        if mode == "move":
            brick.move_axis = Vector2(1.0, 0.0)
        elif mode in ["punch", "kick"]:
            if not brick.request_attack(mode):
                return false
        var health: float = brick.health
        player._advance_timed_states(9.01 / PortFighter.SOURCE_FRAME_RATE)
        if (brick.state != "hitstun" or brick.last_reaction_source_action != "impacthardfrontlow"
                or absf(brick.health - (health - 6.0)) > 0.001):
            push_error("Candidate hit failed for " + mode)
            return false
        brick._animate_candidate()
        if brick.candidate_animation_clip != brick._candidate_clip_paths[reaction_name]:
            push_error("Brick reaction did not play")
            return false
        player._advance_timed_states(5.0 / PortFighter.SOURCE_FRAME_RATE)
        if absf(brick.health - (health - 6.0)) > 0.001:
            push_error("Face-up attack hit twice")
            return false
        brick._advance_timed_states(19.999 / PortFighter.SOURCE_FRAME_RATE)
        if brick.state != "hitstun":
            push_error("Brick exited before candidate frame 20")
            return false
        brick._advance_timed_states(0.002 / PortFighter.SOURCE_FRAME_RATE)
        brick._animate_candidate()
        if (brick.state != "facedownidle" or brick.current_source_pose() != "laying"
                or brick.candidate_animation_clip != brick._candidate_clip_paths[idle_name]):
            push_error("Brick did not enter its own facedown clip")
            return false
        brick.move_axis = Vector2(1.0, 0.0)
        brick._advance_timed_states(2.0)
        if brick.state != "facedownidle" or brick.record_virtual_press("a"):
            push_error("Brick used Bruce ground followups")
            return false
    for kind: String in ["punch", "kick"]:
        for phase: String in ["startup", "active", "recovery"]:
            if not _reset(player, brick) or not brick.request_attack(kind):
                return false
            brick.state = phase
            brick.state_time = float(brick.ATTACKS[kind][phase])
            player._advance_timed_states(9.01 / PortFighter.SOURCE_FRAME_RATE)
            if brick.last_reaction_source_action != "impacthardfrontlow":
                push_error("Mapped attack phase was rejected: " + kind + " " + phase)
                return false
    if not _reset(player, brick):
        return false
    player._advance_timed_states(9.01 / PortFighter.SOURCE_FRAME_RATE)
    brick._advance_timed_states(2.0)
    if brick.state != "facedownidle":
        push_error("Large time step missed candidate return")
        return false
    for case_name: String in ["guard", "lethal", "reaction_missing", "idle_missing", "wrong_state", "move_missing"]:
        if not _reset(player, brick):
            return false
        var removed_key: String = ""
        if case_name == "guard":
            brick.guard_held = true
        elif case_name == "lethal":
            brick.health = 6.0
        elif case_name == "reaction_missing":
            removed_key = reaction_name
        elif case_name == "idle_missing":
            removed_key = idle_name
        elif case_name == "move_missing":
            brick.move_axis = Vector2(1.0, 0.0)
            removed_key = "move"
        elif case_name == "wrong_state":
            brick.state = "hitstun"
            brick.state_time = 1.0
        var saved: String = ""
        if not removed_key.is_empty():
            saved = brick._candidate_clip_paths[removed_key]
            brick._candidate_clip_paths.erase(removed_key)
        player._advance_timed_states(9.01 / PortFighter.SOURCE_FRAME_RATE)
        if not removed_key.is_empty():
            brick._candidate_clip_paths[removed_key] = saved
        if brick.last_reaction_source_action == "impacthardfrontlow":
            push_error("Candidate incorrectly accepted " + case_name)
            return false
        if case_name == "guard" and brick.state != "blockstun":
            return false
        if case_name == "lethal" and brick.state != "ko":
            return false
        if case_name not in ["guard", "lethal"] and brick.state != "hitstun":
            return false
    return true


func _check_candidate_timing(player: PortFighter, brick: PortFighter) -> bool:
    # Idle has no gameplay frame clock: test the visual loop separately from
    # the state predicate, without interpreting its playback time as native time.
    for action: String in ["idle", "move"]:
        if not _reset(player, brick):
            return false
        brick.move_axis = Vector2(1.0, 0.0) if action == "move" else Vector2.ZERO
        brick._animate_candidate()
        var animation: AnimationPlayer = brick.get("_candidate_animation")
        var clip_path: String = brick._candidate_clip_paths[action]
        var clip: Animation = animation.get_animation(clip_path)
        if String(animation.current_animation) != clip_path or clip.loop_mode != Animation.LOOP_LINEAR:
            push_error("Wrong candidate loop: " + action)
            return false
        for playback_time: float in [0.0, clip.length - 0.001]:
            animation.seek(playback_time, true)
            if (absf(animation.current_animation_position - playback_time) > 0.0001
                    or not brick._accepts_brick_faceup_candidate(6.0, false)):
                push_error("Candidate loop boundary failed: " + action)
                return false
        animation.advance(0.002)
        if (animation.current_animation_position > 0.01
                or not brick._accepts_brick_faceup_candidate(6.0, false)):
            push_error("Candidate loop wrap failed: " + action)
            return false

    # Attack state_time is a phase countdown, so exercise real phase transitions
    # instead of assigning a fictitious absolute source frame.
    for kind: String in ["punch", "kick"]:
        if not _reset(player, brick) or not brick.request_attack(kind):
            return false
        player.position.x = -5.0
        for phase: String in ["startup", "active", "recovery"]:
            if brick.state != phase:
                push_error("Unexpected phase before boundary: " + phase)
                return false
            var remaining: float = brick.state_time
            if remaining <= 0.001:
                return false
            brick._advance_timed_states(remaining - 0.001)
            if brick.state != phase or not brick._accepts_brick_faceup_candidate(6.0, false):
                push_error("Candidate rejected phase end: " + kind + " " + phase)
                return false
            brick._advance_timed_states(0.002)
            var expected: String = (
                "active" if phase == "startup"
                else ("recovery" if phase == "active" else "idle")
            )
            if brick.state != expected or not brick._accepts_brick_faceup_candidate(6.0, false):
                push_error("Candidate rejected phase transition: " + kind + " " + phase)
                return false
        var timings: Dictionary = brick.ATTACKS[kind]
        var elapsed: float = 0.0
        for phase: String in ["startup", "active", "recovery"]:
            elapsed += float(timings[phase])
            for side: float in [-0.001, 0.001]:
                if not _reset(player, brick) or not brick.request_attack(kind):
                    return false
                player.position.x = -5.0
                brick._advance_timed_states(elapsed + side)
                player.position.x = 0.0
                player._try_faceup_attack_contact()
                if brick.last_reaction_source_action != "impacthardfrontlow":
                    push_error("Contact failed at phase transition: %s %s %s" % [
                        kind, phase, side])
                    return false
    return true

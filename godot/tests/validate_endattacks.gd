extends SceneTree
## Validate the grab-based endattack finishers on the Bruce candidate through
## the recovered native link path.
##
## The prototype drained a pending combo queue with
## _try_begin_pending_standing_combo.  That function is gone; the decompiled
## model re-evaluates the native link table every physics update, and the
## finisher consumes the victim through begin_endattack_victim, so this test
## drives the same recovered behaviour through the public API only:
##   request_attack for the base attack, record_standing_combo_press for the
##   link input, _physics_process for the frame clock, and the victim states
##   endattackcomp1/endattackcomp2 that begin_endattack_victim enters.
##
## Native facts exercised (adreno_200/set/brucelee.set, native_links.json,
## keyboard variant 1):
##   candobasicattacks -> endattack1  link order 34, sequence [pressa],
##       keystatus right pressed, conditions oppposestun + grabdistance (150)
##   candobasicattacks -> endattack2  link order 35, sequence [pressc],
##       keystatus right pressed, conditions oppposestun + grabdistance (90),
##       unique endbrucelee
##   endattack1/endattack2 source damage is 0; the finisher converts the victim
##   into endattackcomp1 (all_end_attack_01_forset03, 93 frames) or
##   endattackcomp2 (all_end_attack_02_forset03, 130 frames) and then faceupko
##   without dealing damage of its own
##
## The finisher links require oppposestun.  A grabbed victim reads as stun, and
## so does a victim held in hitstun, which is how a normal landed hit (the old
## "normal-hit endmove" path) reaches the same links.  endattack1 becomes active
## immediately and consumes the stunned victim; endattack2 activates 20 frames
## later, after a normal hit's stun has ended, so it correctly plays and whiffs
## without damage.  Both cases are covered.
##
## The opponent's skeleton class is "large" (thai set), so the endattack clips
## resolve to their recovered forbigguy size versions.

const CANDIDATES: Dictionary = {
    "bruce": {
        "bytes": 12528732,
        "sha256": "787869f618f5b8347c3d5f04a8155dd2bb95cca42b76e6d394b6336b963eb80e",
        "animations": 121,
    },
    "brick": {
        "bytes": 4986780,
        "sha256": "c5dd5ba63a4cf6a65a994809d1f43f159db0c33cc4cd4e0b400658f680a74318",
        "animations": 94,
    },
}
const GRAB_DISTANCE: float = 0.3
const RAGE_BEFORE: float = 70.0


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected the Bruce and Brick candidate GLB paths")
        quit(1)
        return
    if not _validate_candidate_identity(args[0], "bruce"):
        quit(1)
        return
    if not _validate_candidate_identity(args[1], "brick"):
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var defender: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    defender.set_physics_process(false)
    if not player.candidate_loaded:
        push_error("Endattack candidate failed: " + player.candidate_load_error)
        quit(1)
        return
    if not defender.candidate_loaded:
        push_error("Endattack victim candidate failed: " + defender.candidate_load_error)
        quit(1)
        return
    var clips: Dictionary = player.get("_candidate_clip_paths")
    for required: String in ["grab1", "endattack1", "endattack2"]:
        if not clips.has(required):
            push_error("Candidate is missing " + required)
            quit(1)
            return
    if not _validate_endattack_from_grab(scene, player, defender, "up", "a",
            "grab1_miss", "grab1", "a", "endattack1", "m01_end_attack_01",
            "m01_end_attack_01_forbigguy", "grabbed1", "endattackcomp1",
            "all_end_attack_01_forset03", 93):
        quit(1)
        return
    if not _validate_endattack_from_grab(scene, player, defender, "down", "c",
            "grab2_miss", "grab2", "c", "endattack2", "m01_end_attack_02",
            "m01_end_attack_02_forbigguy", "grabbed2", "endattackcomp2",
            "all_end_attack_02_forset03", 130):
        quit(1)
        return
    if not _validate_grab_flag_reset(scene, player, defender):
        quit(1)
        return
    if not _validate_blocked_grab_rejects_endattack(scene, player, defender):
        quit(1)
        return
    if not _validate_normal_hit_endmove(scene, player, defender, "endattack1",
            "a", "m01_end_attack_01", "endattackcomp1",
            "all_end_attack_01_forset03", 93, true):
        quit(1)
        return
    if not _validate_normal_hit_endmove(scene, player, defender, "endattack2",
            "c", "m01_end_attack_02", "endattackcomp2",
            "all_end_attack_02_forset03", 130, false):
        quit(1)
        return
    print("ENDATTACK_VALIDATION=" + JSON.stringify({
        "endattack1": "m01_end_attack_01",
        "endattack2": "m01_end_attack_02",
        "source_record_indexes": {"endattack1": 34, "endattack2": 35},
        "source_damage": 0.0,
        "victim": {
            "endattackcomp1": ["all_end_attack_01_forset03", 93],
            "endattackcomp2": ["all_end_attack_02_forset03", 130],
        },
        "bruce_bytes": CANDIDATES["bruce"]["bytes"],
        "bruce_sha256": CANDIDATES["bruce"]["sha256"],
        "brick_bytes": CANDIDATES["brick"]["bytes"],
        "brick_sha256": CANDIDATES["brick"]["sha256"],
        "scope": "native links: grab holds the opponent (grabbed1/2 reads as "
                + "stun) and the candobasicattacks finisher link converts it "
                + "through begin_endattack_victim; original impact damage is zero",
    }))
    scene.queue_free()
    await process_frame
    quit(0)


func _reset(scene: Node, player: PortFighter, defender: PortFighter) -> void:
    scene._reset_match()
    player._clear_link_state()
    player.state = "idle"
    player.state_time = 0.0
    player.attack_kind = ""
    player.health = PortFighter.MAX_HEALTH
    defender.health = PortFighter.MAX_HEALTH
    defender.guard_held = false
    player.rage = RAGE_BEFORE
    player.position = Vector3(0.0, 1.2, 0.0)
    defender.position = Vector3(GRAB_DISTANCE, 1.2, 0.0)
    player.opponent = defender
    player.facing = 1.0
    player.set_key_status({})
    player.set_held_directions({})


func _pin(player: PortFighter, defender: PortFighter) -> void:
    player.position = Vector3(0.0, 1.2, 0.0)
    defender.position = Vector3(GRAB_DISTANCE, 1.2, 0.0)


func _step(player: PortFighter, defender: PortFighter, advance_defender: bool) -> void:
    # Two 1/60 steps per source frame: the frame clock truncates
    # (elapsed_ms * 0.03), so one 1/60 step does not advance a whole frame.
    for _half: int in range(2):
        _pin(player, defender)
        player._physics_process(1.0 / 60.0)
        if advance_defender:
            defender._physics_process(1.0 / 60.0)


func _start_grab(scene: Node, player: PortFighter, defender: PortFighter,
        step_direction: String, key: String, miss: String, target: String,
        victim_state: String) -> bool:
    _reset(scene, player, defender)
    player.set_held_directions({step_direction: true})
    if not player.record_standing_combo_press(key):
        push_error(miss + " did not start")
        return false
    if player.attack_kind != miss:
        push_error("Expected " + miss + ", got " + player.attack_kind)
        return false
    for _frame: int in range(200):
        _step(player, defender, true)
        if defender.state == victim_state and player.attack_kind == target:
            return true
    push_error(miss + " never grabbed: player=" + player.attack_kind
            + " victim=" + defender.state)
    return false


func _validate_endattack_from_grab(scene: Node, player: PortFighter,
        defender: PortFighter, step_direction: String, grab_key: String,
        miss: String, grab: String, finisher_key: String, finisher: String,
        source_animation: String, size_clip: String, victim_state: String,
        victim_finisher_state: String, victim_clip: String,
        victim_frames: int) -> bool:
    if not _start_grab(scene, player, defender, step_direction, grab_key, miss,
            grab, victim_state):
        return false
    if not bool(player.get("_grab_connected")):
        push_error(grab + " did not set the grab-connected flag")
        return false
    var health_before: float = defender.health
    # The finisher link needs the toward key held (keystatus right pressed) and
    # the documented attack key.  It must fire while the victim is still held,
    # before the grab animation finishes.
    player.set_held_directions({"right": true})
    player.set_key_status({"right": true, finisher_key: true})
    if not player.record_standing_combo_press(finisher_key):
        push_error(finisher + " did not start from the grab")
        return false
    if player.attack_kind != finisher:
        push_error("Expected " + finisher + ", got " + player.attack_kind)
        return false
    if player.current_source_animation() != source_animation:
        push_error(finisher + " requested " + player.current_source_animation())
        return false
    player._animate_candidate()
    if player.candidate_animation_clip != size_clip:
        push_error(finisher + " did not play the large-opponent size version: "
                + player.candidate_animation_clip)
        return false
    var saw_comp: bool = false
    for _frame: int in range(400):
        _step(player, defender, true)
        if defender.state == victim_finisher_state and not saw_comp:
            saw_comp = true
            defender._animate_candidate()
            if defender.candidate_animation_clip != victim_clip:
                push_error(finisher + " victim clip was "
                        + defender.candidate_animation_clip)
                return false
            # begin_endattack_victim holds the victim for the recovered frame
            # count of the opponent set's clip (thai forset03: 93 / 130).
            var expected_time: float = float(victim_frames) / PortFighter.SOURCE_FRAME_RATE
            if defender.state_time > expected_time + 0.0001 \
                    or defender.state_time < expected_time - (2.0 / 60.0) - 0.0001:
                push_error(finisher + " victim timing was " + str(defender.state_time)
                        + ", expected " + str(expected_time))
                return false
        if saw_comp and defender.state == "faceupko":
            break
    if not saw_comp:
        push_error(finisher + " never consumed the victim: " + defender.state)
        return false
    if defender.state != "faceupko":
        push_error(finisher + " victim did not finish into faceupko: " + defender.state)
        return false
    if absf(defender.health - health_before) > 0.001:
        push_error(finisher + " invented damage: " + str(defender.health))
        return false
    return true


func _validate_grab_flag_reset(scene: Node, player: PortFighter,
        defender: PortFighter) -> bool:
    # A successful grab records the grab-connected flag.  The flag is not an
    # endattack property: starting any chained attack begins a new action and
    # clears it, so the old "still set after the finisher" check moved to the
    # moment the grab lands, and reset_fighter must still clear it.
    if not _start_grab(scene, player, defender, "up", "a", "grab1_miss",
            "grab1", "grabbed1"):
        return false
    if not bool(player.get("_grab_connected")):
        push_error("Successful grab did not set the grab-connected flag")
        return false
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    if bool(player.get("_grab_connected")):
        push_error("reset_fighter did not clear the grab-connected flag")
        return false
    return true


func _validate_blocked_grab_rejects_endattack(scene: Node, player: PortFighter,
        defender: PortFighter) -> bool:
    # A guarded opponent fails oppnotblocking, so the miss never chains into a
    # grab, the grab-connected flag stays clear, and the finisher link (which
    # needs oppposestun) cannot start.
    _reset(scene, player, defender)
    player.set_held_directions({"up": true})
    defender.guard_held = true
    if not player.record_standing_combo_press("a"):
        push_error("Blocked-grab setup did not start grab1")
        return false
    if player.attack_kind != "grab1_miss":
        push_error("Blocked-grab setup expected grab1_miss, got " + player.attack_kind)
        return false
    for _frame: int in range(40):
        _step(player, defender, true)
    if player.attack_kind == "grab1":
        push_error("Grab chained into a blocking opponent")
        return false
    if bool(player.get("_grab_connected")):
        push_error("A blocked grab set the grab-connected flag")
        return false
    player.set_held_directions({"right": true})
    player.set_key_status({"right": true, "a": true})
    player.record_standing_combo_press("a")
    if player.attack_kind in ["endattack1", "endattack2"]:
        push_error("Endattack started after a blocked grab")
        return false
    return true


func _validate_normal_hit_endmove(scene: Node, player: PortFighter,
        defender: PortFighter, finisher: String, key: String,
        source_animation: String, victim_finisher_state: String,
        victim_clip: String, victim_frames: int, expect_conversion: bool) -> bool:
    # The same finisher links also fire after an ordinary landed hit: the victim
    # stays stunned (oppposestun) while the attacker's candobasicattacks window
    # is open.  highpunch3's window opens at frame 21, which still overlaps the
    # recovered hard-impact hitstun, so the documented key starts the finisher.
    # endattack1 is active immediately and consumes the stunned victim;
    # endattack2 activates 20 frames later, after the stun has ended, so it
    # plays and whiffs without damage.  The finisher's own source damage is 0
    # in both cases.
    _reset(scene, player, defender)
    if not player.request_attack("high_punch3"):
        push_error("Normal base hit did not start before " + finisher)
        return false
    var link: Dictionary = _finisher_link(player, finisher)
    if link.is_empty():
        push_error("Native link table lost the candobasicattacks -> " + finisher)
        return false
    var health_before: float = -1.0
    var landed: bool = false
    var started: bool = false
    for _frame: int in range(120):
        _step(player, defender, true)
        if not bool(player.get("_attack_hit_landed")):
            continue
        landed = true
        # The finisher link is only legal inside the source action's
        # candobasicattacks window while the victim reads as stunned
        # (oppposestun).  The hard highpunch3 impact keeps the victim in
        # hitstun through that window's opening frames.
        if not (player._native_link_applies(link)
                and player._native_link_window_ok(link)
                and player._native_link_conditions_ok(link)):
            continue
        if defender.state != "hitstun":
            push_error(finisher + " window opened without a stunned victim: "
                    + defender.state)
            return false
        health_before = defender.health
        player.set_held_directions({"right": true})
        player.set_key_status({"right": true, key: true})
        if not player.record_standing_combo_press(key):
            push_error("Normal-hit " + finisher + " did not start")
            return false
        started = true
        break
    if not landed:
        push_error("Normal base hit never landed before " + finisher)
        return false
    if not started:
        push_error("Normal base hit never opened the " + finisher + " window")
        return false
    if player.attack_kind != finisher:
        push_error("Expected " + finisher + " after normal hit, got " + player.attack_kind)
        return false
    if player.current_source_animation() != source_animation:
        push_error("Normal-hit " + finisher + " requested "
                + player.current_source_animation())
        return false
    # endattack2 becomes active 20 frames after the press, by which time a
    # normal hit's hitstun has expired, so oppposestun is false and
    # begin_endattack_victim correctly refuses to consume the victim.  The link
    # and the recovered clip must still play, and the finisher must invent no
    # damage across its whole animation.
    if not expect_conversion:
        var saw_finisher_frame: bool = false
        for _frame: int in range(260):
            _step(player, defender, true)
            if player.attack_kind == finisher:
                saw_finisher_frame = true
            if defender.state == victim_finisher_state:
                push_error("Normal-hit " + finisher
                        + " converted a victim whose stun had already expired")
                return false
        if not saw_finisher_frame:
            push_error("Normal-hit " + finisher + " ended before its animation ran")
            return false
        if absf(defender.health - health_before) > 0.001:
            push_error("Normal-hit " + finisher + " invented damage")
            return false
        return true
    var saw_comp: bool = false
    for _frame: int in range(400):
        _step(player, defender, true)
        if defender.state == victim_finisher_state and not saw_comp:
            saw_comp = true
            defender._animate_candidate()
            if defender.candidate_animation_clip != victim_clip:
                push_error("Normal-hit " + finisher + " victim clip was "
                        + defender.candidate_animation_clip)
                return false
            var expected_time: float = float(victim_frames) / PortFighter.SOURCE_FRAME_RATE
            if defender.state_time > expected_time + 0.0001 \
                    or defender.state_time < expected_time - (2.0 / 60.0) - 0.0001:
                push_error("Normal-hit " + finisher + " victim timing was "
                        + str(defender.state_time))
                return false
        if saw_comp and defender.state == "faceupko":
            break
    if not saw_comp:
        push_error("Normal-hit " + finisher + " never consumed the victim: "
                + defender.state)
        return false
    if absf(defender.health - health_before) > 0.001:
        push_error("Normal-hit " + finisher + " invented damage")
        return false
    return true


func _finisher_link(player: PortFighter, finisher: String) -> Dictionary:
    # The recovered candobasicattacks finisher link, in native order.
    for candidate: Dictionary in player._native_links:
        if (String(candidate.get("to", "")) == finisher
                and String(candidate.get("from_group", "")) == "candobasicattacks"):
            return candidate
    return {}


func _validate_candidate_identity(path: String, role: String) -> bool:
    var expected: Dictionary = CANDIDATES[role]
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error(role + " endattack candidate could not be opened")
        return false
    var bytes: PackedByteArray = file.get_buffer(file.get_length())
    file.close()
    if bytes.size() != int(expected["bytes"]):
        push_error(role + " endattack candidate size mismatch: " + str(bytes.size()))
        return false
    var hash: HashingContext = HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    hash.update(bytes)
    if hash.finish().hex_encode().to_lower() != String(expected["sha256"]):
        push_error(role + " endattack candidate SHA-256 mismatch")
        return false
    var json_length: int = bytes.decode_u32(12)
    var document: Variant = JSON.parse_string(
        bytes.slice(20, 20 + json_length).get_string_from_utf8())
    if (not document is Dictionary or not document.has("animations")
            or document["animations"].size() != int(expected["animations"])):
        push_error(role + " endattack candidate animation count mismatch")
        return false
    return true

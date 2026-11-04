extends SceneTree
## Regression: a grab hit must not apply the generic reaction knockback push.
##
## The grab contact used to feed the victim's recovered reaction root position
## into receive_hit()'s generic push (position.x += direction * push), so the
## victim was shoved away from the attacker before begin_grabbed() could hold
## it.  This test drives the real main.tscn and the real candidate GLBs through
## the recovered link path (stepright+A -> grab1_miss -> grab1, stepleft+C ->
## grab2_miss -> grab2) and measures the victim's own world position.
##
## Assertions per opponent and grab slot:
##   1. the contact lands (the victim loses health);
##   2. the victim never moves: |x - x_at_grab_start| stays 0 for the whole
##      sampled hold, while a NON-grab hard hit on the same real fighters still
##      displaces the victim (the falsifiability control);
##   3. begin_grabbed() still runs and selects the set's victim clip whenever
##      the opponent candidate provides that slot (Brick/Master/SinFu here).
##      When the candidate lacks the slot the grab must fail closed: no hold,
##      and still no push (this is the shipped Ken candidate's state).
##   4. a held victim stays inside the grab's reach, so every recovered
##      multi-impact of the grab lands (the placement the fix restores).
##
## Run:
##   godot --headless --path <project> --script res://tests/validate_grab_contact_no_push.gd -- \
##     <bruce.glb> <brick.glb> <ken.glb> <master.glb> <sinfu.glb>

const OPPONENTS: Array = [
    {
        "id": "brick",
        "glb_arg": 1,
        "attack_config": "res://data/fighting_set_m03_mapped_attacks.json",
        "skeleton": "large",
    },
    {
        "id": "ken",
        "glb_arg": 2,
        "attack_config": "res://data/attack_config_ken.json",
        "skeleton": "medium",
    },
    {
        "id": "master",
        "glb_arg": 3,
        "attack_config": "res://data/attack_config_master.json",
        "skeleton": "small",
    },
    {
        "id": "sinfu",
        "glb_arg": 4,
        "attack_config": "res://data/attack_config_sinfu.json",
        "skeleton": "medium",
    },
]
const GRAB_CASES: Array = [
    ["up", "a", "grab1_miss", "grab1", "grabbed1"],
    ["down", "c", "grab2_miss", "grab2", "grabbed2"],
]
const CONTROL_ATTACK: String = "high_punch3"
const CONTROL_MIN_PUSH: float = 0.5
const CONTACT_DISTANCE: float = 0.3
const SOURCE_FRAME: float = 1.0 / 60.0
const GRAB_FRAMES: int = 210
const PUSH_EPSILON: float = 0.000001

var checks: int = 0
var failures: int = 0
var results: Array = []


func _initialize() -> void:
    call_deferred("_run")


func check(ok: bool, label: String, detail: String = "") -> void:
    checks += 1
    if ok:
        print("PASS  ", label)
    else:
        failures += 1
        print("FAIL  ", label, ("  | " + detail) if detail != "" else "")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 5:
        check(false, "five candidate GLB arguments were supplied",
                "got " + str(args.size()))
        _finish()
        return
    for opponent: Dictionary in OPPONENTS:
        var ok: bool = await _validate_opponent(opponent, args)
        if not ok:
            break
    _finish()


func _finish() -> void:
    print("GRAB_CONTACT_REGRESSION=" + JSON.stringify({
        "schema": 1,
        "engine": Engine.get_version_info().get("string", ""),
        "checks": checks,
        "failures": failures,
        "cases": results,
        "control": {"attack": CONTROL_ATTACK, "min_push": CONTROL_MIN_PUSH},
    }))
    quit(0 if failures == 0 else 1)


func _validate_opponent(opponent: Dictionary, args: PackedStringArray) -> bool:
    var glb: String = args[int(opponent["glb_arg"])]
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", glb)
    OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", String(opponent["attack_config"]))
    OS.set_environment("BRUCELEE_OPPONENT_SKELETON", String(opponent["skeleton"]))
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var defender: PortFighter = scene.get("computer")
    check(player != null and defender != null,
            String(opponent["id"]) + ": main.tscn created both fighters")
    if player == null or defender == null:
        scene.queue_free()
        await process_frame
        return false
    player.set_physics_process(false)
    defender.set_physics_process(false)
    var loaded: bool = player.candidate_loaded and defender.candidate_loaded
    check(loaded, String(opponent["id"]) + ": both candidate GLBs loaded",
            player.candidate_load_error + " / " + defender.candidate_load_error)
    if not loaded:
        scene.queue_free()
        await process_frame
        return false
    player._animate_candidate()
    defender._animate_candidate()
    # Record which grab victim slots this opponent candidate can really play.
    var slots: Dictionary = {}
    for grab: Array in GRAB_CASES:
        var slot: String = grab[4]
        slots[slot] = {
            "available": defender._candidate_clip_paths.has(slot),
            "clip": String(defender.candidate_clips.get(slot, "")),
        }
    for grab: Array in GRAB_CASES:
        var case_result: Dictionary = _validate_grab(
            scene, player, defender, opponent, grab, slots)
        results.append(case_result)
        if not bool(case_result.get("ok", false)):
            scene.queue_free()
            await process_frame
            return false
    _validate_control(scene, player, defender, opponent)
    scene.queue_free()
    await process_frame
    await process_frame
    return true


func _reset(scene: Node, player: PortFighter, defender: PortFighter) -> void:
    scene._reset_match()
    player._clear_link_state()
    player.state = "idle"
    player.state_time = 0.0
    player.attack_kind = ""
    player.health = PortFighter.MAX_HEALTH
    player.rage = PortFighter.RAGE_MAX
    defender.health = PortFighter.MAX_HEALTH
    defender.guard_held = false
    defender.state = "idle"
    defender.state_time = 0.0
    defender.attack_kind = ""
    player.position = Vector3(0.0, 1.2, 0.0)
    defender.position = Vector3(CONTACT_DISTANCE, 1.2, 0.0)
    player.opponent = defender
    player.facing = 1.0
    player.set_key_status({})
    player.set_held_directions({})
    defender.set_key_status({})
    defender.set_held_directions({})
    defender.move_axis = Vector2.ZERO


func _pin(player: PortFighter, defender: PortFighter) -> void:
    player.position = Vector3(0.0, 1.2, 0.0)
    defender.position = Vector3(CONTACT_DISTANCE, 1.2, 0.0)


func _half_step(player: PortFighter, defender: PortFighter) -> void:
    player._physics_process(SOURCE_FRAME)
    player._animate_candidate()
    defender._physics_process(SOURCE_FRAME)
    defender._animate_candidate()


func _start_grab(
        scene: Node, player: PortFighter, defender: PortFighter, grab: Array) -> String:
    _reset(scene, player, defender)
    defender.move_axis = Vector2.ZERO
    player.set_held_directions({grab[0]: true})
    if player._current_action_name() not in ["stepright", "stepleft"]:
        return "held direction did not select a step action: " + player._current_action_name()
    if not player.record_standing_combo_press(grab[1]):
        return "the recovered link input did not start " + grab[2]
    if player.attack_kind != grab[2]:
        return "expected " + grab[2] + ", got " + player.attack_kind
    for _frame: int in range(16):
        _pin(player, defender)
        for _half: int in range(2):
            _half_step(player, defender)
        if player.attack_kind == grab[3]:
            player.set_held_directions({})
            player.set_key_status({})
            return ""
    return grab[2] + " did not chain to " + grab[3] + " (got " + player.attack_kind + ")"


func _validate_grab(
        scene: Node, player: PortFighter, defender: PortFighter,
        opponent: Dictionary, grab: Array, slots: Dictionary) -> Dictionary:
    var label: String = String(opponent["id"]) + " " + String(grab[3])
    var target: String = String(grab[3])
    var slot: String = String(grab[4])
    var error: String = _start_grab(scene, player, defender, grab)
    if not error.is_empty():
        check(false, label + " reached the grab through the recovered link", error)
        return {"opponent": opponent["id"], "grab": target, "ok": false, "error": error}
    var grab_clip: String = player.candidate_animation_clip
    var x0: float = defender.position.x
    var max_dx: float = 0.0
    var health: float = defender.health
    var first_impact_dx: float = 0.0
    var first_impact_seen: bool = false
    var grabbed_state: String = ""
    var grabbed_clip: String = ""
    var grabbed_state_time: float = 0.0
    var grab_connected: bool = false
    for _frame: int in range(GRAB_FRAMES):
        for _half: int in range(2):
            _half_step(player, defender)
            max_dx = maxf(max_dx, absf(defender.position.x - x0))
            if not first_impact_seen and defender.health < health - 0.0001:
                first_impact_seen = true
                first_impact_dx = defender.position.x - x0
            health = defender.health
            if grabbed_state.is_empty() and defender.state in ["grabbed1", "grabbed2"]:
                grabbed_state = defender.state
                grabbed_clip = defender.candidate_animation_clip
                grabbed_state_time = defender.state_time
                grab_connected = bool(player.get("_grab_connected"))
    var total_damage: float = PortFighter.MAX_HEALTH - defender.health
    var slot_info: Dictionary = slots.get(slot, {})
    var slot_available: bool = bool(slot_info.get("available", false))
    var expected_clip: String = String(slot_info.get("clip", ""))
    check(first_impact_seen, label + " contact lands on the victim",
            "victim health stayed " + str(defender.health))
    if first_impact_seen:
        check(absf(first_impact_dx) <= PUSH_EPSILON,
                label + " first grab impact does not push the victim",
                "dx=" + str(first_impact_dx))
    check(max_dx <= PUSH_EPSILON,
            label + " victim stays at the grab contact for the whole hold",
            "max_abs_dx=" + str(max_dx))
    if slot_available:
        check(grabbed_state == slot,
                label + " begin_grabbed puts the victim in " + slot,
                "state=" + grabbed_state)
        check(grabbed_clip == expected_clip,
                label + " victim plays the set's recovered clip " + expected_clip,
                "clip=" + grabbed_clip)
        var fallback_frames: int = int(
            PortFighter.GRAB_VICTIM_DATA.get(target, [slot, -1])[1])
        check(absf(grabbed_state_time - float(fallback_frames)
                        / PortFighter.SOURCE_FRAME_RATE) <= 2.0 / PortFighter.SOURCE_FRAME_RATE,
                label + " victim hold length uses the non-player victim table",
                "state_time=" + str(grabbed_state_time))
        check(grab_connected, label + " attacker records the grab as connected")
        var expected_total: float = 0.0
        var details: Dictionary = (
            player.ATTACKS[target] if player.ATTACKS.has(target) else {})
        for impact: Dictionary in Array(details.get("multi_impacts", [])):
            expected_total += float(impact.get("damage", 0.0))
        check(is_equal_approx(total_damage, expected_total),
                label + " a held victim stays inside reach for every impact",
                "damage=" + str(total_damage) + " expected=" + str(expected_total))
    else:
        check(grabbed_state.is_empty(),
                label + " fails closed when the candidate lacks " + expected_clip,
                "held as " + grabbed_state)
        print("NOTE  ", label, ": candidate has no ", slot,
                " clip (expected ", expected_clip, "); hold refused (no grabbed state)")
    var record: Dictionary = {
        "opponent": opponent["id"],
        "grab": target,
        "ok": true,
        "slot": slot,
        "slot_available": slot_available,
        "expected_clip": expected_clip,
        "grabbed_state": grabbed_state,
        "grabbed_clip": grabbed_clip,
        "grabbed_state_time": grabbed_state_time,
        "grab_connected": grab_connected,
        "max_abs_dx": max_dx,
        "first_impact_dx": first_impact_dx,
        "total_damage": total_damage,
        "x0": x0,
        "x_final": defender.position.x,
        "attacker_grab_clip": grab_clip,
    }
    return record


func _validate_control(
        scene: Node, player: PortFighter, defender: PortFighter,
        opponent: Dictionary) -> void:
    # Falsifiability: the same real fighters under a non-grab hard hit must
    # still be pushed by the generic reaction root.  If this ever stops moving
    # the victim, the "no push" assertions above would be meaningless.
    var label: String = String(opponent["id"]) + " control " + CONTROL_ATTACK
    _reset(scene, player, defender)
    # Stand the control outside grab range so its own attack root motion cannot
    # overshoot the victim and flip the attacker's facing inside the contact.
    player.position = Vector3(-0.7, 1.2, 0.0)
    defender.position = Vector3(0.3, 1.2, 0.0)
    if not player.request_attack(CONTROL_ATTACK):
        check(false, label + " starts the non-grab control attack")
        return
    var x0: float = defender.position.x
    var max_dx: float = 0.0
    var contact: bool = false
    var push_dx: float = 0.0
    var previous_health: float = defender.health
    for _frame: int in range(GRAB_FRAMES):
        for _half: int in range(2):
            player._physics_process(SOURCE_FRAME)
            player._animate_candidate()
            var after_attacker: float = defender.position.x
            var dropped: bool = defender.health < previous_health - 0.0001
            if not contact and dropped:
                contact = true
                push_dx = after_attacker - x0
            defender._physics_process(SOURCE_FRAME)
            defender._animate_candidate()
            max_dx = maxf(max_dx, absf(defender.position.x - x0))
            previous_health = defender.health
    check(contact, label + " contact lands on the victim")
    check(absf(push_dx) >= CONTROL_MIN_PUSH,
            label + " still applies the generic reaction push",
            "push_dx=" + str(push_dx))
    check(max_dx >= CONTROL_MIN_PUSH,
            label + " push is visible in the sampled trajectory",
            "max_abs_dx=" + str(max_dx))
    var control_details: Dictionary = (
        player.ATTACKS[CONTROL_ATTACK] if player.ATTACKS.has(CONTROL_ATTACK) else {})
    var control_reaction: Dictionary = {}
    if control_details.has("source_impact"):
        control_reaction = defender.reaction_for_incoming(
            control_details["source_impact"], false)
    var control_root: float = float(PortFighter.REACTION_ROOT_PUSH_SOURCE.get(
        String(control_reaction.get("source_action", "")), -1.0))
    results.append({
        "opponent": opponent["id"],
        "control": CONTROL_ATTACK,
        "max_abs_dx": max_dx,
        "push_dx": push_dx,
        "x0": x0,
        "x_final": defender.position.x,
        "contact": contact,
        "reaction_source": String(control_reaction.get("source_action", "")),
        "root_source": control_root,
        "root_push_world": control_root * defender.source_units_to_world,
    })

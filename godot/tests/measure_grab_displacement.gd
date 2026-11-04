extends SceneTree
## Measure the victim displacement of a grab hit on the real main.tscn.
##
## The grab attacks (grab1/grab2) reach their contacts through the game's own
## link path: hold up -> stepright + A starts grab1_miss, which chains into
## grab1 on its recovered [8, 9] window; hold down -> stepleft + C starts
## grab2_miss -> grab2.  The victim is NOT pinned once the grab starts, so its
## world position is exactly what the hit reaction code did to it.
##
## Every distance printed here is a measured position delta of the real
## candidate fighter under test, not a formula.
##
## Run:
##   godot --headless --path <project> --script res://tests/measure_grab_displacement.gd -- \
##     <bruce.glb> <brick.glb> <ken.glb> <master.glb> <sinfu.glb>

const BRUCE_ATTACK_CONFIG: String = "res://data/fighting_set_low_attacks.json"
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
    # step direction, key, miss action, grab action
    ["up", "a", "grab1_miss", "grab1"],
    ["down", "c", "grab2_miss", "grab2"],
]
const CONTACT_DISTANCE: float = 0.3
const SOURCE_FRAME: float = 1.0 / 60.0
const GRAB_FRAMES: int = 210

var failures: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    failures += 1
    push_error(message)
    print("MEASURE_FAIL ", message)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 5:
        _fail("expected 5 candidate GLB args (bruce brick ken master sinfu)")
        quit(1)
        return
    var cases: Array = []
    for opponent: Dictionary in OPPONENTS:
        var measured: Array = await _measure_opponent(opponent, args)
        if measured.is_empty():
            quit(1)
            return
        cases.append_array(measured)
    print("MEASURE_JSON=" + JSON.stringify({
        "schema": 1,
        "engine": Engine.get_version_info().get("string", ""),
        "attacker_glb": args[0],
        "opponent_glbs": {
            "brick": args[1], "ken": args[2],
            "master": args[3], "sinfu": args[4],
        },
        "contact_distance": CONTACT_DISTANCE,
        "grab_frames": GRAB_FRAMES,
        "cases": cases,
        "failures": failures,
    }))
    quit(0 if failures == 0 else 1)


func _measure_opponent(opponent: Dictionary, args: PackedStringArray) -> Array:
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
    if player == null or defender == null:
        _fail(String(opponent["id"]) + ": main.tscn did not create both fighters")
        return []
    player.set_physics_process(false)
    defender.set_physics_process(false)
    if not player.candidate_loaded:
        _fail(String(opponent["id"]) + ": attacker candidate failed: "
                + player.candidate_load_error)
        return []
    if not defender.candidate_loaded:
        _fail(String(opponent["id"]) + ": opponent candidate failed: "
                + defender.candidate_load_error)
        return []
    var results: Array = []
    for grab: Array in GRAB_CASES:
        var record: Dictionary = _measure_grab(
            scene, player, defender, opponent, grab)
        if record.is_empty():
            return []
        results.append(record)
    scene.queue_free()
    await process_frame
    await process_frame
    return results


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


func _sample(player: PortFighter, defender: PortFighter) -> Dictionary:
    return {
        "x": defender.position.x,
        "ax": player.position.x,
        "state": defender.state,
        "clip": defender.candidate_animation_clip,
        "state_time": defender.state_time,
        "health": defender.health,
        "grab_connected": bool(player.get("_grab_connected")),
        "attack_kind": player.attack_kind,
        "attack_clip": player.candidate_animation_clip,
    }


func _measure_grab(
        scene: Node, player: PortFighter, defender: PortFighter,
        opponent: Dictionary, grab: Array) -> Dictionary:
    var step_direction: String = grab[0]
    var key: String = grab[1]
    var miss: String = grab[2]
    var target: String = grab[3]
    _reset(scene, player, defender)
    defender.move_axis = Vector2.ZERO
    player.set_held_directions({step_direction: true})
    if player._current_action_name() not in ["stepright", "stepleft"]:
        _fail(target + ": held " + step_direction + " did not select a step action: "
                + player._current_action_name())
        return {}
    if not player.record_standing_combo_press(key):
        _fail(target + ": " + miss + " was not started by the recovered link input")
        return {}
    if player.attack_kind != miss:
        _fail(target + ": expected " + miss + ", got " + player.attack_kind)
        return {}
    # The miss -> grab chain is automatic and needs the two fighters inside
    # grabdistance; pin both while the miss plays so only the grab contact can
    # move the victim.
    var chained: bool = false
    for _frame: int in range(16):
        _pin(player, defender)
        for _half: int in range(2):
            _half_step(player, defender)
        if player.attack_kind == target:
            chained = true
            break
    if not chained:
        _fail(target + ": " + miss + " did not chain to " + target
                + " (got " + player.attack_kind + ")")
        return {}
    # Release the held direction; the grab is now the whole scenario.  From
    # here on neither fighter is repositioned by the test.
    player.set_held_directions({})
    player.set_key_status({})
    if player.current_source_animation() != ("m01_grab_01" if target == "grab1"
            else "m01_grab_02"):
        _fail(target + ": requested " + player.current_source_animation())
        return {}
    var grab_clip: String = player.candidate_animation_clip
    var x0: float = defender.position.x
    var ax0: float = player.position.x
    var samples: Array = []
    samples.append(_sample(player, defender))
    for _frame: int in range(GRAB_FRAMES):
        for _half: int in range(2):
            _half_step(player, defender)
            samples.append(_sample(player, defender))
    # Analyse the sampled trajectory.  A "contact" is a health drop; the x
    # delta between the sample before the drop and the sample that carries the
    # drop is exactly the displacement the hit reaction applied.
    var impacts: Array = []
    var grabbed_index: int = -1
    var previous: Dictionary = samples[0]
    for index: int in range(1, samples.size()):
        var current: Dictionary = samples[index]
        var dropped: bool = float(current["health"]) < float(previous["health"]) - 0.0001
        if dropped:
            var slot: String = "grabbed1" if target == "grab1" else "grabbed2"
            impacts.append({
                "sample": index,
                "source_frame": float(index) * 0.5 / 30.0,
                "damage": float(previous["health"]) - float(current["health"]),
                "x_before": float(previous["x"]),
                "x_after": float(current["x"]),
                "dx": float(current["x"]) - float(previous["x"]),
                "state_after": String(current["state"]),
                "clip_after": String(current["clip"]),
                "grab_slot_available": defender._candidate_clip_paths.has(slot),
            })
        if grabbed_index < 0 and String(current["state"]) in ["grabbed1", "grabbed2"]:
            grabbed_index = index
        previous = current
    var xs: Array = []
    for sample: Dictionary in samples:
        xs.append(float(sample["x"]))
    var max_abs: float = 0.0
    for value: float in xs:
        max_abs = maxf(max_abs, absf(value - x0))
    var grabbed: Dictionary = {}
    if grabbed_index >= 0:
        var gs: Dictionary = samples[grabbed_index]
        var slot: String = String(gs["state"])
        var expected_clip: String = String(defender.candidate_clips.get(slot, ""))
        var expected_frames: int = int(PortFighter.VICTIM_CLIP_FRAMES.get(expected_clip, -1))
        grabbed = {
            "state": slot,
            "clip": String(gs["clip"]),
            "expected_clip": expected_clip,
            "state_time": float(gs["state_time"]),
            "expected_state_time": float(expected_frames) / PortFighter.SOURCE_FRAME_RATE,
            "slot_available": defender._candidate_clip_paths.has(slot),
            "grab_connected": bool(gs["grab_connected"]),
        }
    var reaction_preview: Dictionary = {}
    var details: Dictionary = (
        player.ATTACKS[target] if player.ATTACKS.has(target) else {})
    if details.has("source_impact"):
        var reaction: Dictionary = defender.reaction_for_incoming(details["source_impact"], false)
        var root_source: float = float(
            PortFighter.REACTION_ROOT_PUSH_SOURCE.get(
                String(reaction.get("source_action", "")), -1.0))
        reaction_preview = {
            "source_action": String(reaction.get("source_action", "")),
            "animation": String(reaction.get("animation", "")),
            "root_source": root_source,
            "root_push_world": root_source * defender.source_units_to_world,
        }
    return {
        "opponent": String(opponent["id"]),
        "grab": target,
        "opponent_glb": OS.get_environment("BRUCELEE_OPPONENT_GLB"),
        "opponent_attack_config": String(opponent["attack_config"]),
        "opponent_skeleton": String(opponent["skeleton"]),
        "attacker_grab_clip": grab_clip,
        "attacker_source_units_to_world": player.source_units_to_world,
        "x0": x0,
        "attacker_x0": ax0,
        "attacker_x_final": float(samples[-1]["ax"]),
        "x_final": float(samples[-1]["x"]),
        "dx_final": float(samples[-1]["x"]) - x0,
        "max_abs_dx": max_abs,
        "impact_count": impacts.size(),
        "impacts": impacts,
        "total_damage": PortFighter.MAX_HEALTH - float(samples[-1]["health"]),
        "grabbed": grabbed,
        "reaction_preview": reaction_preview,
        "final_state": String(samples[-1]["state"]),
        "final_health": float(samples[-1]["health"]),
        "attacker_attack_kind_final": String(samples[-1]["attack_kind"]),
        "samples": samples.size(),
    }

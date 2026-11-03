extends SceneTree
## Headless acceptance test for the recovered native AI patch.
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_native_ai.gd \
##         -- <bruce.glb> <brick.glb>
##
## Asserts, against the real res://scenes/main.tscn:
##   1. the recovered tree/profile data loads and is internally consistent;
##   2. Brick's profile floats equal adreno_200/characters.list;
##   3. the tree drives Brick's attacks through the port's native action slots;
##   4. an opponent in `laying` reaches the recovered attacktofloor branch;
##   5. an attacking opponent reaches the recovered block/counter branch;
##   6. the recovered rage bands (none/onethird/twothirds/full) change the
##      special-attack share, replacing the prototype's 1/3 + 2/3 thresholds;
##   7. the recovered attacktofloor cancel window start is 45 frames, not 80.

const PROFILE_EXPECT: Dictionary = {
    "punchfromidle": 0.33000001311302185,
    "dospring": 0.8700000047683716,
    "doacounter": 0.05000000074505806,
    "doattackeasy": -1.0,
    "reachlevel2": 1.0,
    "doblockeasy": 0.15000000596046448,
    "doblockhard": 0.550000011920929,
    "grabtwothirds": 0.0,
}

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    failures.append(message)
    push_error("NATIVE_AI_FAIL: " + message)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        _fail("expected <bruce.glb> <brick.glb>")
        _finish()
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var brick: PortFighter = scene.get("computer")
    var ai: RefCounted = scene.get("native_ai")
    player.set_physics_process(false)
    brick.set_physics_process(false)
    if not brick.candidate_loaded:
        _fail("brick candidate failed: " + brick.candidate_load_error)
        _finish()
        return
    if ai == null:
        _fail("scene.native_ai is null: the main.gd hook was not applied")
        _finish()
        return
    if not ai.load_error.is_empty():
        _fail("native AI data error: " + ai.load_error)

    _check_data(ai)
    _check_profile(ai)
    _check_tree(ai)
    _check_actions(ai, brick)
    _check_attack_to_floor(player, brick, ai, scene)
    _check_block_branch(player, brick, ai, scene)
    _check_rage_bands(player, brick, ai, scene)
    _check_recovery_window(brick)
    _finish()


# --- 1/2/3: data integrity ------------------------------------------------


func _check_data(ai: RefCounted) -> void:
    if ai.tree.size() != 169:
        _fail("tree node count %d != 169" % ai.tree.size())
    if not ai.tree.has("root"):
        _fail("tree has no root node")
    for key: String in ["random_probability", "profile_probability", "my_state",
                        "my_animation", "my_rage", "distance", "near",
                        "opp_attacking", "opp_pose", "opp_attack_height",
                        "winning", "repetition", "near_limits", "my_last_action"]:
        var found: bool = JSON.stringify(ai.tree).contains("\"" + key + "\"")
        if not found:
            _fail("tree lost condition " + key)
    print("NATIVE_AI_CHECK data nodes=%d profiles=%d" % [ai.tree.size(), ai.profiles.size()])


func _check_profile(ai: RefCounted) -> void:
    var profile: Dictionary = ai.profiles.get("brick davis", {}).get("profile", {})
    if profile.is_empty():
        _fail("brick davis missing from ai_profiles.json")
        return
    var expected: Dictionary = {
        "punchfromidle": 0.33000001311302185,
        "dospring": 0.8700000047683716,
        "doacounter": 0.05000000074505806,
        "reachlevel2": 1.0,
        "doblockeasy": 0.15000000596046448,
        "doblockhard": 0.550000011920929,
        "grabtwothirds": 0.0,
        "guessheighthard": 0.699999988079071,
    }
    for key: String in expected:
        var actual: float = float(profile.get(key, -1.0))
        if absf(actual - float(expected[key])) > 0.0000001:
            _fail("profile %s = %f, expected %f" % [key, actual, float(expected[key])])
    print("NATIVE_AI_CHECK profile keys=%d doacounter=%f dospring=%f"
            % [profile.size(), float(profile.get("doacounter", -1.0)),
               float(profile.get("dospring", -1.0))])


func _check_tree(ai: RefCounted) -> void:
    var missing: Array[String] = []
    var action_nodes: int = 0
    for name: String in ai.tree:
        var node: Dictionary = ai.tree[name]
        if node.has("actions"):
            action_nodes += 1
            for value: Variant in Array(node["actions"]):
                var base: String = ai._action_base(String(value))
                if not ai.action_map.has(base):
                    missing.append(String(value))
    if not missing.is_empty():
        _fail("unmapped tree actions: " + ", ".join(missing.slice(0, 5)))
    print("NATIVE_AI_CHECK tree action_nodes=%d mapped=%d" % [action_nodes, ai.action_map.size()])


func _check_actions(ai: RefCounted, brick: PortFighter) -> void:
    var unsupported: Array[String] = []
    for base: String in ai.action_map:
        var slots: Array = Array(ai.action_map[base])
        if slots.is_empty():
            unsupported.append(base)
            continue
        var token: String = String(slots[0])
        if token.begins_with("__"):
            continue
        var any: bool = false
        for slot: Variant in slots:
            if brick.supports_attack(String(slot)):
                any = true
        if not any:
            unsupported.append(base)
    print("NATIVE_AI_CHECK brick_unsupported=" + ",".join(unsupported))


# --- 4: knockdown -> attacktofloor branch ---------------------------------


func _check_attack_to_floor(player: PortFighter, brick: PortFighter, ai: RefCounted, scene: Node) -> void:
    if not brick.supports_attack("attack_to_floor_brick"):
        print("NATIVE_AI_SKIP attacktofloor (brick clip missing)")
        return
    var hits: int = 0
    var seeds: int = 0
    for seed_value: int in range(1, 120):
        seeds = seed_value
        _reset(scene, player, brick, ai, seed_value)
        player.state = "facedownidle"
        player.state_time = 0.0
        brick.position = player.position + Vector3(0.55, 0.0, 0.0)
        var decision: Dictionary = ai.step(1.0 / 60.0)
        if String(decision.get("native", "")) == "attacktofloor":
            hits += 1
            if String(decision.get("action", "")) != "attack_to_floor_brick":
                _fail("attacktofloor decision dispatched %s" % decision.get("action", ""))
            break
    if hits == 0:
        _fail("knockdown branch never selected attacktofloor in %d seeds" % seeds)
    print("NATIVE_AI_CHECK attacktofloor_hits=%d seeds=%d" % [hits, seeds])


# --- 5: block/counter branch ----------------------------------------------


func _check_block_branch(player: PortFighter, brick: PortFighter, ai: RefCounted, scene: Node) -> void:
    var blocks: int = 0
    for seed_value: int in range(1, 60):
        _reset(scene, player, brick, ai, seed_value)
        player.state = "startup"
        player.attack_kind = "high_punch"
        player.state_time = 0.05
        brick.position = player.position + Vector3(0.5, 0.0, 0.0)
        var decision: Dictionary = ai.step(1.0 / 60.0)
        if String(decision.get("kind", "")) == "block" or brick.guard_held:
            blocks += 1
    if blocks == 0:
        _fail("opp_attacking branch never blocked/countered")
    print("NATIVE_AI_CHECK block_branch_hits=%d/59" % blocks)


# --- 6: rage bands --------------------------------------------------------


func _check_rage_bands(player: PortFighter, brick: PortFighter, ai: RefCounted, scene: Node) -> void:
    # 6a. The band edges themselves (RAGE_MAX = 100).
    var bands: Array[String] = []
    for value: float in [0.0, 33.4, 66.7, 100.0]:
        brick.rage = value
        bands.append(String(ai._rage_band()))
    if bands != ["none", "onethird", "twothirds", "full"]:
        _fail("rage bands %s != [none, onethird, twothirds, full]" % str(bands))

    # 6b. Behaviour.  The shipped tree gates specials behind
    # params_by_difficulty [0,0,0,1,1] (difficulty index >= 3), so the sample
    # runs at index 4 and restores the configured difficulty afterwards.
    ai.set_difficulty(4)
    var no_rage: Dictionary = _sample_actions(player, brick, ai, scene, 0.0, 400)
    var full_rage: Dictionary = _sample_actions(player, brick, ai, scene, 100.0, 400)
    ai.set_difficulty(2)
    var no_special: int = _count_power_moves(no_rage)
    var full_special: int = _count_power_moves(full_rage)
    if no_special != 0 or full_special <= 0:
        _fail("rage gate wrong: none=%d (want 0) full=%d (want >0), bands=%s"
                % [no_special, full_special, str(bands)])
    print("NATIVE_AI_CHECK rage_power_moves none=%d full=%d dif4" % [no_special, full_special])


func _sample_actions(player: PortFighter, brick: PortFighter, ai: RefCounted,
        scene: Node, rage: float, samples: int) -> Dictionary:
    var counts: Dictionary = {}
    for index: int in range(samples):
        _reset(scene, player, brick, ai, index + 1)
        brick.rage = rage
        brick.position = player.position + Vector3(0.5, 0.0, 0.0)
        player.health = 40.0
        brick.health = 100.0
        var decision: Dictionary = ai.step(1.0 / 60.0)
        var native: String = String(decision.get("native", ""))
        if not native.is_empty():
            counts[native] = int(counts.get(native, 0)) + 1
        brick.move_axis = Vector2.ZERO
        brick.guard_held = false
        brick.state = "idle"
        brick.attack_kind = ""
    return counts


func _count_power_moves(counts: Dictionary) -> int:
    ## Rage-gated native actions: specials and grabs (the tree routes both
    ## through the my_rage branches).
    var total: int = 0
    for key: String in counts:
        if key.begins_with("special") or key.begins_with("grab"):
            total += int(counts[key])
    return total


# --- 7: recovery window ---------------------------------------------------


func _check_recovery_window(brick: PortFighter) -> void:
    if not brick.has_method("attack_cancel_window_start"):
        _fail("PortFighter.attack_cancel_window_start() missing: fighter.gd hook not applied")
        return
    brick.state = "attacktofloor"
    brick.attack_kind = "attack_to_floor_brick"
    brick.state_time = 40.0 / PortFighter.SOURCE_FRAME_RATE
    var start: int = brick.attack_cancel_window_start()
    if start != 45:
        _fail("attacktofloor cancel window start %d != 45" % start)
    if brick.attack_cancel_window_open():
        _fail("attacktofloor cancel window open at frame 40")
    brick.state_time = 46.0 / PortFighter.SOURCE_FRAME_RATE
    if not brick.attack_cancel_window_open():
        _fail("attacktofloor cancel window closed at frame 46")
    print("NATIVE_AI_CHECK attacktofloor_cancel_start=%d" % start)


# --- helpers --------------------------------------------------------------


func _reset(scene: Node, player: PortFighter, brick: PortFighter, ai: RefCounted, seed_value: int) -> void:
    scene._reset_match()
    player.position = Vector3(0.0, 1.2, 0.0)
    brick.position = Vector3(0.6, 1.2, 0.0)
    player.state = "idle"
    player.state_time = 0.0
    player.attack_kind = ""
    player.attack_sequence = 0
    brick.state = "idle"
    brick.state_time = 0.0
    brick.attack_kind = ""
    brick.guard_held = false
    brick.move_axis = Vector2.ZERO
    ai.state = "default"
    ai.last_node = ""
    ai.last_action = ""
    ai.action_counts.clear()
    ai.unsupported_actions.clear()
    ai.decisions.clear()
    ai._repetition = 0
    ai._last_signature = ""
    ai._rng.seed = seed_value


func _finish() -> void:
    if failures.is_empty():
        print("NATIVE_AI_VALIDATION=PASS")
        quit(0)
    else:
        print("NATIVE_AI_VALIDATION=FAIL count=%d" % failures.size())
        for failure: String in failures:
            print("  - " + failure)
        quit(1)

extends SceneTree
## Verify the recovered size-class grab/finisher selection in the real scene.
##
## adreno_200/Animations.versions keys alternate clip files by skeleton class:
## "opp_skeleton" for the attacker-side grab/finisher clips and "my_skeleton"
## for the victim-side clips. characters.list supplies each fighter's class.
## This test drives res://scenes/main.tscn and asserts, per case, that the
## attacker plays the class version, that the action is refused when the loaded
## candidate or the table cannot satisfy the rule, and that a previous class
## selection is not left behind.
##
## Run:
##   godot --headless --path godot --script res://tests/validate_size_variants.gd -- \
##     <bruce_with_variants.glb> <bruce_without_variants.glb> \
##     <brick.glb> <ken.glb> <master.glb>

const BRICK_CONFIG: String = "res://data/fighting_set_m03_mapped_attacks.json"
const KEN_CONFIG: String = "res://data/attack_config_ken.json"
const MASTER_CONFIG: String = "res://data/attack_config_master.json"
const MISSING_TABLE: String = "res://data/does_not_exist_size_variants.json"

var _results: Array = []
var _failures: Array = []
var _glbs: Dictionary = {}


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 5:
        push_error("Expected five candidate GLB paths")
        quit(1)
        return
    _glbs = {"bruce_variants": args[0], "bruce_plain": args[1],
             "brick": args[2], "ken": args[3], "master": args[4]}
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")

    # Attacker = player (Bruce, medium in characters.list); the opponent's
    # class comes from the opponent config, so these are the real defaults.
    await _case(
        "vs_large_opponent_grab_uses_bigguy",
        "bruce_variants", "brick", BRICK_CONFIG, "", "medium", "",
        "grab1", "request", false, true, "variant", "m01_grab_01_forbigguy"
    )
    await _case(
        "vs_medium_opponent_grab_uses_base",
        "bruce_variants", "ken", KEN_CONFIG, "m02", "medium", "",
        "grab1", "request", false, true, "base", "m01_grab_01"
    )
    await _case(
        "vs_small_opponent_grab_uses_smallguy",
        "bruce_variants", "master", MASTER_CONFIG, "", "medium", "",
        "grab1", "request", false, true, "variant", "m01_grab_01_forsmallguy"
    )
    await _case(
        "vs_small_opponent_finisher_uses_smallguy",
        "bruce_variants", "master", MASTER_CONFIG, "", "medium", "",
        "endattack1", "request", false, true, "variant", "m01_end_attack_01_forsmallguy"
    )
    await _case(
        "vs_small_opponent_keeps_archived_typo",
        "bruce_variants", "master", MASTER_CONFIG, "", "medium", "",
        "endattack2", "request", false, true, "variant", "m01_end_attack_02_for_smallguy"
    )
    await _case(
        "missing_version_fails_closed",
        "bruce_plain", "brick", BRICK_CONFIG, "", "medium", "",
        "grab1", "request", false, false, "unavailable", ""
    )
    await _case(
        "unknown_class_fails_closed",
        "bruce_variants", "brick", BRICK_CONFIG, "", "medium", "huge",
        "grab1", "request", false, false, "unavailable", ""
    )
    # Attacker = opponent (Brick, large); the held victim is the player, so the
    # player's declared class is the one the table keys on.
    await _case(
        "opponent_grab_vs_large_victim",
        "bruce_variants", "brick", BRICK_CONFIG, "", "large", "",
        "grab1_brick", "request", true, true, "variant", "m03_grab_01_forbigguy"
    )
    await _case(
        "opponent_grab_vs_small_victim",
        "bruce_variants", "brick", BRICK_CONFIG, "", "small", "",
        "grab1_brick", "request", true, true, "variant", "m03_grab_01_forsmallguy"
    )
    # The recovered table itself missing: the class decision cannot be made, so
    # every grab/finisher is refused instead of playing the base clip.
    await _case(
        "missing_table_fails_closed",
        "bruce_variants", "brick", BRICK_CONFIG, "", "medium", "",
        "grab1", "request", false, false, "unavailable", "", MISSING_TABLE
    )
    # Native link path: _try_follow_links -> _begin_chained_attack must apply the
    # same gate (grab1/grab2/endattack1/endattack2 are real link targets).
    await _case(
        "chained_link_resolves_version",
        "bruce_variants", "brick", BRICK_CONFIG, "", "medium", "",
        "endattack1", "chain", false, true, "variant", "m01_end_attack_01_forbigguy"
    )
    await _case(
        "chained_link_missing_version_refused",
        "bruce_plain", "brick", BRICK_CONFIG, "", "medium", "",
        "endattack1", "chain", false, false, "unavailable", ""
    )
    await _class_switch_case("class_switch_restores_slot", "bruce_variants", "brick")
    # No candidate at all: there is no clip to choose, so the placeholder rig
    # keeps its grabs instead of failing closed over a version that cannot exist.
    await _case(
        "placeholder_grab_allowed_without_candidate",
        "", "", BRICK_CONFIG, "", "medium", "",
        "grab1", "request", false, true, "base", ""
    )

    var summary: Dictionary = {
        "case_count": _results.size(),
        "failure_count": _failures.size(),
        "failures": _failures,
        "results": _results,
    }
    print("SIZE_VARIANT_RESULTS=" + JSON.stringify(summary))
    quit(1 if _failures.size() > 0 else 0)


func _case(
        name: String,
        player_key: String,
        opponent_key: String,
        opponent_config: String,
        opponent_prefix: String,
        player_class: String,
        opponent_class: String,
        kind: String,
        mode: String,
        opponent_attacks: bool,
        expect_accepted: bool,
        expect_status: String,
        expect_clip: String,
        variants_path: String = ""
) -> void:
    var scene: Node = await _load_scene(
        player_key, opponent_key, opponent_config, opponent_prefix,
        player_class, opponent_class, variants_path
    )
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    var attacker: PortFighter = computer if opponent_attacks else player
    var defender: PortFighter = player if opponent_attacks else computer
    var observation: Dictionary = _drive(scene, attacker, defender, kind, mode)
    _record(name, kind, mode, attacker, player, computer, observation,
            expect_accepted, expect_status, expect_clip)
    scene.queue_free()
    await process_frame


func _class_switch_case(name: String, player_key: String, opponent_key: String) -> void:
    ## Same fighter pair, three classes in a row: the slot must follow the
    ## current class and must not keep an earlier resolved version.
    var scene: Node = await _load_scene(
        player_key, opponent_key, BRICK_CONFIG, "", "medium", "", ""
    )
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    computer.set_skeleton_class("small")
    var first: Dictionary = _drive(scene, player, computer, "grab1", "request")
    computer.set_skeleton_class("large")
    var second: Dictionary = _drive(scene, player, computer, "grab1", "request")
    computer.set_skeleton_class("huge")
    var refused: Dictionary = _drive(scene, player, computer, "grab1", "request")
    computer.set_skeleton_class("large")
    var third: Dictionary = _drive(scene, player, computer, "grab1", "request")
    var entry: Dictionary = {
        "case": name,
        "kind": "grab1",
        "mode": "request",
        "steps": [
            {"class": "small", "accepted": first.get("accepted", false),
             "playing": first.get("playing", ""), "status": _status(first)},
            {"class": "large", "accepted": second.get("accepted", false),
             "playing": second.get("playing", ""), "status": _status(second)},
            {"class": "huge", "accepted": refused.get("accepted", false),
             "playing": refused.get("playing", ""), "status": _status(refused)},
            {"class": "large", "accepted": third.get("accepted", false),
             "playing": third.get("playing", ""), "status": _status(third)},
        ],
    }
    var ok: bool = (
        String(entry["steps"][0]["playing"]) == "m01_grab_01_forsmallguy"
        and String(entry["steps"][1]["playing"]) == "m01_grab_01_forbigguy"
        and bool(entry["steps"][2]["accepted"]) == false
        and String(entry["steps"][3]["playing"]) == "m01_grab_01_forbigguy"
    )
    _results.append(entry)
    if not ok:
        _failures.append(entry)
        push_error("size variant case failed: " + name + " -> " + JSON.stringify(entry))
    else:
        print("SIZE_VARIANT_CASE_OK=" + name + " playing="
              + String(entry["steps"][3]["playing"]))
    scene.queue_free()
    await process_frame


func _status(observation: Dictionary) -> String:
    var selection: Dictionary = observation.get("selection", {})
    return String(selection.get("status", ""))


func _record(
        name: String,
        kind: String,
        mode: String,
        attacker: PortFighter,
        player: PortFighter,
        computer: PortFighter,
        observation: Dictionary,
        expect_accepted: bool,
        expect_status: String,
        expect_clip: String
) -> void:
    var selection: Dictionary = observation.get("selection", {})
    var entry: Dictionary = {
        "case": name,
        "kind": kind,
        "mode": mode,
        "attacker": attacker.character_name,
        "player_skeleton": player.skeleton_class,
        "opponent_skeleton": computer.skeleton_class,
        "accepted": observation.get("accepted", false),
        "state": observation.get("state", ""),
        "playing": observation.get("playing", ""),
        "selection": selection,
        "expected": {"accepted": expect_accepted, "status": expect_status, "clip": expect_clip},
    }
    _results.append(entry)
    var ok: bool = bool(entry["accepted"]) == expect_accepted
    if ok and expect_accepted:
        ok = String(selection.get("status", "")) == expect_status
        if ok and not expect_clip.is_empty():
            ok = String(entry["playing"]) == expect_clip
    if not ok:
        _failures.append(entry)
        push_error("size variant case failed: " + name + " -> " + JSON.stringify(entry))
    else:
        print("SIZE_VARIANT_CASE_OK=" + name + " playing=" + String(entry["playing"]))


func _load_scene(
        player_key: String,
        opponent_key: String,
        opponent_config: String,
        opponent_prefix: String,
        player_class: String,
        opponent_class: String,
        variants_path: String
) -> Node:
    OS.set_environment("BRUCELEE_PLAYER_GLB", String(_glbs.get(player_key, player_key)))
    OS.set_environment("BRUCELEE_PLAYER_SKELETON", player_class)
    OS.set_environment("BRUCELEE_OPPONENT_GLB", String(_glbs.get(opponent_key, opponent_key)))
    OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", opponent_config)
    OS.set_environment("BRUCELEE_OPPONENT_CLIP_PREFIX", opponent_prefix)
    OS.set_environment("BRUCELEE_OPPONENT_SKELETON", opponent_class)
    OS.set_environment("BRUCELEE_SIZE_VARIANTS", variants_path)
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    return scene


func _drive(
        scene: Node, attacker: PortFighter, defender: PortFighter, kind: String,
        mode: String
) -> Dictionary:
    attacker.set_physics_process(false)
    defender.set_physics_process(false)
    scene._reset_match()
    attacker.position = Vector3(0.0, 1.2, 0.0)
    defender.position = Vector3(0.3, 1.2, 0.0)
    attacker.state = "idle"
    attacker.state_time = 0.0
    attacker.attack_kind = ""
    var accepted: bool = (
        attacker._begin_chained_attack(kind, 0, 0) if mode == "chain"
        else attacker.request_attack(kind)
    )
    var observation: Dictionary = {"accepted": accepted}
    if accepted:
        for _step: int in range(3):
            attacker.position = Vector3(0.0, 1.2, 0.0)
            defender.position = Vector3(0.3, 1.2, 0.0)
            attacker._physics_process(1.0 / 60.0)
            defender._physics_process(1.0 / 60.0)
        observation["state"] = attacker.state
        observation["attack_kind"] = attacker.attack_kind
        observation["playing"] = attacker.candidate_animation_clip
    observation["selection"] = attacker.size_variant_state()
    return observation

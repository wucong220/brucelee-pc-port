extends SceneTree
## Verify the recovered size-class selector on the remaining versioned slots.
##
## Animations.versions also versions three base clips the earlier delivery left
## on their base clips:
##   all_idle_face_down / all_idle_face_up  (ground idles, audience "self")
##   m01_sp_pnch_high                       (special high punch, audience "opponent")
##
## This test drives the real res://scenes/main.tscn:
##   * the ATTACKER plays the class version of the special high punch, keyed by
##     the OPPONENT's class (small / medium / large), and the action is refused
##     when the loaded candidate lacks the required version;
##   * the VICTIM's ground idle (face down and face up) uses its OWN class
##     version, and an unavailable version never falls back to the base clip;
##   * a class switch never leaves a stale version behind.
##
## Run:
##   godot --headless --path godot --script res://tests/validate_size_variants_extras.gd -- \
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

    # ---- Attacker: m01_sp_pnch_high, audience "opponent" -------------------
    await _attack_case(
        "special_punch_vs_large_uses_bigguy",
        "bruce_variants", "brick", BRICK_CONFIG, "", "medium", "",
        "special_punch_high_hit", "request", true, "variant",
        "m01_sp_pnch_high_forbigguy"
    )
    await _attack_case(
        "special_punch_vs_small_uses_smallguy",
        "bruce_variants", "master", MASTER_CONFIG, "", "medium", "",
        "special_punch_high_hit", "request", true, "variant",
        "m01_sp_pnch_high_forsmallguy"
    )
    await _attack_case(
        "special_punch_vs_medium_uses_base",
        "bruce_variants", "ken", KEN_CONFIG, "m02", "medium", "",
        "special_punch_high_hit", "request", true, "base",
        "m01_sp_pnch_high"
    )
    await _attack_case(
        "special_punch_missing_version_refused",
        "bruce_plain", "brick", BRICK_CONFIG, "", "medium", "",
        "special_punch_high_hit", "request", false, "unavailable", ""
    )
    # Native miss link redirects to the hit variant, then resolves its version.
    await _attack_case(
        "special_punch_chain_vs_large_uses_bigguy",
        "bruce_variants", "brick", BRICK_CONFIG, "", "medium", "",
        "special_punch_high_miss", "chain", true, "variant",
        "m01_sp_pnch_high_forbigguy"
    )
    await _attack_case(
        "special_punch_missing_table_refused",
        "bruce_variants", "brick", BRICK_CONFIG, "", "medium", "",
        "special_punch_high_hit", "request", false, "unavailable", "",
        MISSING_TABLE
    )

    # ---- Victim: ground idles, audience "self" ----------------------------
    # Player (Bruce, medium) down: base clips are the original choice.
    await _ground_case(
        "victim_player_medium_facedown_uses_base",
        "bruce_variants", "ken", KEN_CONFIG, "m02", "medium", "",
        "player", "facedownidle", true, "base", "all_idle_face_down"
    )
    await _ground_case(
        "victim_player_medium_faceup_uses_base",
        "bruce_variants", "ken", KEN_CONFIG, "m02", "medium", "",
        "player", "faceupidle", true, "base", "all_idle_face_up"
    )
    # Large opponent (Brick) down: forbigguy ground idles.
    await _ground_case(
        "victim_large_facedown_uses_bigguy",
        "bruce_variants", "brick", BRICK_CONFIG, "", "medium", "",
        "computer", "facedownidle", true, "variant", "all_idle_face_down_forbigguy"
    )
    await _ground_case(
        "victim_large_faceup_uses_bigguy",
        "bruce_variants", "brick", BRICK_CONFIG, "", "medium", "",
        "computer", "faceupidle", true, "variant", "all_idle_face_up_forbigguy"
    )
    # Small opponent (Master) down: forsmallguy ground idles.
    await _ground_case(
        "victim_small_facedown_uses_smallguy",
        "bruce_variants", "master", MASTER_CONFIG, "", "medium", "",
        "computer", "facedownidle", true, "variant", "all_idle_face_down_forsmallguy"
    )
    await _ground_case(
        "victim_small_faceup_uses_smallguy",
        "bruce_variants", "master", MASTER_CONFIG, "", "medium", "",
        "computer", "faceupidle", true, "variant", "all_idle_face_up_forsmallguy"
    )
    # A required class version the candidate cannot play: fail closed. The
    # Master candidate only carries the small versions, so a forced "large"
    # class must not fall back to the base all_idle_face_down.
    await _ground_case(
        "victim_missing_version_facedown_fails_closed",
        "bruce_variants", "master", MASTER_CONFIG, "", "medium", "large",
        "computer", "facedownidle", false, "unavailable", ""
    )
    await _ground_case(
        "victim_missing_version_faceup_fails_closed",
        "bruce_variants", "master", MASTER_CONFIG, "", "medium", "large",
        "computer", "faceupidle", false, "unavailable", ""
    )
    # The version table itself missing: the class decision cannot be made.
    await _ground_case(
        "victim_missing_table_fails_closed",
        "bruce_variants", "brick", BRICK_CONFIG, "", "medium", "",
        "computer", "facedownidle", false, "unavailable", "", MISSING_TABLE
    )
    await _ground_class_switch_case()

    var summary: Dictionary = {
        "case_count": _results.size(),
        "failure_count": _failures.size(),
        "failures": _failures,
        "results": _results,
    }
    print("SIZE_VARIANT_EXTRAS_RESULTS=" + JSON.stringify(summary))
    quit(1 if _failures.size() > 0 else 0)


func _attack_case(
        name: String,
        player_key: String,
        opponent_key: String,
        opponent_config: String,
        opponent_prefix: String,
        player_class: String,
        opponent_class: String,
        kind: String,
        mode: String,
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
    var observation: Dictionary = _drive_attack(scene, player, computer, kind, mode)
    var selection: Dictionary = observation.get("selection", {})
    var entry: Dictionary = {
        "case": name, "kind": kind, "mode": mode, "side": "attacker",
        "player_skeleton": player.skeleton_class,
        "opponent_skeleton": computer.skeleton_class,
        "accepted": observation.get("accepted", false),
        "playing": observation.get("playing", ""),
        "selection": selection,
        "expected": {"accepted": expect_accepted, "status": expect_status, "clip": expect_clip},
    }
    var ok: bool = bool(entry["accepted"]) == expect_accepted
    if ok and expect_accepted:
        ok = String(selection.get("status", "")) == expect_status
        if ok and not expect_clip.is_empty():
            ok = String(entry["playing"]) == expect_clip
    _record(name, entry, ok)
    scene.queue_free()
    await process_frame


func _ground_case(
        name: String,
        player_key: String,
        opponent_key: String,
        opponent_config: String,
        opponent_prefix: String,
        player_class: String,
        opponent_class: String,
        who: String,
        state_name: String,
        expect_available: bool,
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
    var fighter: PortFighter = player if who == "player" else computer
    var observation: Dictionary = _drive_ground_idle(scene, fighter, state_name)
    var ground: Dictionary = observation.get("ground", {})
    var entry: Dictionary = {
        "case": name, "state": state_name, "side": "victim", "who": who,
        "skeleton_class": fighter.skeleton_class,
        "playing": observation.get("playing", ""),
        "ground": ground,
        "expected": {"available": expect_available, "status": expect_status, "clip": expect_clip},
    }
    var ok: bool = String(ground.get("status", "")) == expect_status
    if ok and expect_available:
        ok = String(entry["playing"]) == expect_clip
    if ok and not expect_available:
        # Fail closed must record a reason and must not play the base ground clip.
        ok = String(ground.get("error", "")) != ""
        var base_clip: String = String(ground.get("base", ""))
        if not base_clip.is_empty():
            ok = ok and String(entry["playing"]) != base_clip
    _record(name, entry, ok)
    scene.queue_free()
    await process_frame


func _ground_class_switch_case() -> void:
    ## Master candidate carries the small versions only: small -> forsmallguy,
    ## medium -> base, large/huge -> unavailable, then small -> forsmallguy again
    ## (no stale large resolution left behind).
    var scene: Node = await _load_scene(
        "bruce_variants", "master", MASTER_CONFIG, "", "medium", "", ""
    )
    var computer: PortFighter = scene.get("computer")
    var steps: Array = []
    for klass: String in ["small", "medium", "large", "huge", "small"]:
        computer.set_skeleton_class(klass)
        var observation: Dictionary = _drive_ground_idle(scene, computer, "facedownidle")
        var ground: Dictionary = observation.get("ground", {})
        steps.append({
            "class": klass,
            "status": ground.get("status", ""),
            "playing": observation.get("playing", ""),
        })
    var entry: Dictionary = {"case": "ground_idle_class_switch", "steps": steps}
    var ok: bool = (
        String(steps[0]["playing"]) == "all_idle_face_down_forsmallguy"
        and String(steps[1]["playing"]) == "all_idle_face_down"
        and String(steps[2]["status"]) == "unavailable"
        and String(steps[3]["status"]) == "unavailable"
        and String(steps[4]["playing"]) == "all_idle_face_down_forsmallguy"
    )
    _record("ground_idle_class_switch", entry, ok)
    scene.queue_free()
    await process_frame


func _record(name: String, entry: Dictionary, ok: bool) -> void:
    _results.append(entry)
    if not ok:
        _failures.append(entry)
        push_error("size variant extras case failed: " + name + " -> " + JSON.stringify(entry))
    else:
        print("SIZE_VARIANT_EXTRAS_CASE_OK=" + name
              + " playing=" + String(entry.get("playing", "")))


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


func _drive_attack(
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
        observation["playing"] = attacker.candidate_animation_clip
    observation["selection"] = attacker.size_variant_state()
    return observation


func _drive_ground_idle(
        scene: Node, fighter: PortFighter, state_name: String
) -> Dictionary:
    fighter.set_physics_process(false)
    fighter.state = state_name
    fighter.state_time = 0.0
    fighter.attack_kind = ""
    fighter._animate_candidate()
    return {
        "state": fighter.state,
        "playing": fighter.candidate_animation_clip,
        "ground": fighter.ground_idle_state(),
    }

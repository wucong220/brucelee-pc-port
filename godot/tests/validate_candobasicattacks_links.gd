extends SceneTree
## Runtime regression for the complete candobasicattacks link coverage on the
## real res://scenes/main.tscn.
##
## Reference mode (default) needs the full Bruce candidate that carries the
## recovered endattack size variants; it asserts:
##   * the port loaded the complete 84-member / 21-link table;
##   * the 11 player-owned links that resolve against a Brick opponent start the
##     recovered target kind (orders 32/33, the recovered `endattack brick`
##     variant at order 36, and the eight directional standing links);
##   * the empty-unique generic `endattack1` link (order 34) is superseded by its
##     recovered opponent variant, and the mirror-only `endattack2` link
##     (order 35, unique endbrucelee) plus the eight other-character links
##     (orders 37-44) are refused by the unique owner gate;
##   * the lowpunch1 candobasicattacks window is exactly [22,69] and gates the
##     link at frames 9/21/22/40/69;
##   * a missing attack clip refuses the link instead of playing the previous
##     clip;
##   * a failed member table refuses every candobasicattacks group link.
##
## The owner-gate expectations follow the recovered brucelee.set data
## (SHA-256 860b6dac1ae5043456fbf72b1cd93a5a1c76f036b3b995df5e57ce68b4d3762c):
## in brucelee.set the `unique` token names the matchup OPPONENT, so against
## Brick only `endbrickdavis` (order 36) may pass; `endbrucelee` (order 35) and
## the eight `end<other>` tokens must fail closed. Order 34 has no unique token
## at all, so it is a generic link that is deferred while a proven specific
## variant applies. `_native_target_kind()` is a pure action->kind lookup and is
## therefore not empty for a variant that exists but whose owner is another
## character; the owner gate, not the lookup, proves the link is refused.
##
## Packaged mode ("packaged" third argument) uses the shipped 92-clip Bruce
## candidate and asserts the recovered `endattack brick` finisher link fails
## closed because the large-opponent size variant is absent, while every other
## live link passes.
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_candobasicattacks_links.gd \
##       -- <bruce.glb> <brick.glb> [packaged]

const FPS: float = 30.0

# order, target action, key tokens, conditions, expectation mode, expected kind
#   "plays"    -> applies + owner gate + conditions + runtime kind must match
#   "deferred" -> generic link applies and its owner gate passes, but a proven
#                 specific variant supersedes it and it must not play itself
#   "refused"  -> link applies structurally, but the owner gate refuses it and
#                 its own recovered kind must never reach attack_kind
const LINKS: Array = [
    [32, "attacktofloor", ["c"], ["oppposelaying"], "plays", "attacktofloor"],
    [33, "attacktofloor", ["d"], ["oppposelaying"], "plays", "attacktofloor"],
    [34, "endattack1", ["a"], ["oppposestun", "grabdistance"], "deferred", "endattack1"],
    [35, "endattack2", ["c"], ["oppposestun", "grabdistance"], "refused", "endattack2"],
    [36, "endattack brick", ["a"], ["oppposestun", "grabdistance"], "plays", "endattack brick"],
    [37, "endattack chief", ["a"], ["oppposestun", "grabdistance"], "refused", "endattack chief"],
    [38, "endattack johnson", ["a"], ["oppposestun", "grabdistance"], "refused", "endattack johnson"],
    [39, "endattack ken", ["a"], ["oppposestun", "grabdistance"], "refused", "endattack ken"],
    [40, "endattack loming", ["a"], ["oppposestun"], "refused", "endattack loming"],
    [41, "endattack master", ["a"], ["oppposestun"], "refused", "endattack master"],
    [42, "endattack shenlo", ["a"], ["oppposestun"], "refused", "endattack shenlo"],
    [43, "endattack sinfu", ["a"], ["oppposestun"], "refused", "endattack sinfu"],
    [44, "endattack smallboy", ["a"], ["oppposestun", "grabdistance"], "refused", "endattack smallboy"],
    [83, "highkick3", ["in", "c"], [], "plays", "high_kick3"],
    [84, "highpunch3", ["in", "a"], [], "plays", "high_punch3"],
    [85, "lowpunch3", ["out", "b"], [], "plays", "low_punch3"],
    [86, "lowkick3", ["out", "d"], [], "plays", "low_kick3"],
    [87, "lowkick1", ["d"], [], "plays", "kick"],
    [88, "lowpunch1", ["b"], [], "plays", "punch"],
    [89, "highkick1", ["c"], [], "plays", "high_kick"],
    [90, "highpunch1", ["a"], [], "plays", "high_punch"],
]

var player: PortFighter
var computer: PortFighter
var failures: Array[String] = []
var packaged: bool = false


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 2:
        push_error("Expected Bruce and Brick candidate GLB paths")
        quit(1)
        return
    packaged = args.size() >= 3 and String(args[2]) == "packaged"
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
    player = scene.get("player")
    computer = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)
    if not player.candidate_loaded or not computer.candidate_loaded:
        push_error("candidate load failed")
        quit(1)
        return

    var coverage: Dictionary = player.candobasicattacks_coverage()
    if not bool(coverage.get("complete", false)):
        failures.append("coverage not complete: " + String(coverage.get("error", "")))
    if int(coverage.get("members", 0)) != 84:
        failures.append("coverage members " + str(coverage.get("members", 0)))
    if int(coverage.get("links", 0)) != 21:
        failures.append("coverage links " + str(coverage.get("links", 0)))

    var by_order: Dictionary = {}
    for link: Dictionary in player._native_links:
        by_order[int(link.get("order", -1))] = link

    for row: Array in LINKS:
        var order: int = row[0]
        var target: String = row[1]
        var keys: Array = row[2]
        var conditions: Array = row[3]
        var mode: String = row[4]
        var expected: String = row[5]
        var link: Dictionary = by_order.get(order, {})
        if link.is_empty() or String(link.get("to", "")) != target:
            failures.append("missing link %d %s" % [order, target])
            continue
        _reset_actors()
        _setup_conditions(conditions)
        player.set_key_status({"right": true})
        var applies: bool = player._native_link_applies(link)
        var unique_ok: bool = player._native_link_unique_ok(link)
        var conditions_ok: bool = player._native_link_conditions_ok(link)
        var before_kind: String = player.attack_kind
        for token: String in keys:
            player.record_standing_combo_press(token)
        var after_kind: String = player.attack_kind
        match mode:
            "plays":
                if not applies:
                    failures.append("link %d not applicable" % order)
                elif not unique_ok:
                    failures.append("link %d failed the unique owner gate" % order)
                elif not conditions_ok:
                    failures.append("link %d conditions false" % order)
                elif packaged and expected == "endattack brick":
                    # Shipped 92-clip candidate lacks the large-opponent
                    # finisher clip, so the recovered variant fails closed.
                    if after_kind == expected:
                        failures.append("packaged candidate unexpectedly played %s" % expected)
                elif after_kind != expected:
                    failures.append("link %d expected %s got %s" % [order, expected, after_kind])
            "deferred":
                if not applies:
                    failures.append("generic link %d not applicable" % order)
                elif not unique_ok:
                    failures.append("generic link %d failed the unique owner gate" % order)
                elif not conditions_ok:
                    failures.append("generic link %d conditions false" % order)
                elif not player._defer_generic_link_for_variant(link):
                    failures.append("generic link %d was not superseded by its opponent variant" % order)
                elif after_kind == expected:
                    failures.append("generic link %d still played %s" % [order, expected])
            "refused":
                if not applies:
                    failures.append("owner link %d not applicable" % order)
                elif unique_ok:
                    failures.append("owner link %d passed the unique gate" % order)
                elif after_kind == expected:
                    failures.append("owner link %d played %s" % [order, expected])
            _:
                failures.append("link %d has unknown expectation mode %s" % [order, mode])

    # Window gate on the lowpunch1 candobasicattacks record.
    var punch_link: Dictionary = by_order.get(88, {})
    player.set_key_status({})
    var expected_boundaries: Dictionary = {
        9.0: "", 21.0: "high_punch2", 22.0: "high_punch",
        40.0: "high_punch", 69.0: "high_punch",
    }
    for frame: float in expected_boundaries:
        _reset_actors()
        _place("punch", frame)
        var window: Array = player._native_link_window_for_action(punch_link, "lowpunch1")
        if window.size() < 2 or int(window[0]) != 22 or int(window[1]) != 69:
            failures.append("lowpunch1 window " + str(window))
        var before_sequence: int = player.attack_sequence
        player.record_standing_combo_press("a")
        var want: String = String(expected_boundaries[frame])
        if want.is_empty():
            if player.attack_sequence != before_sequence:
                failures.append("window frame %s fired unexpectedly (%s)"
                        % [str(frame), player.attack_kind])
        elif player.attack_kind != want:
            failures.append("window frame %s expected %s got %s"
                    % [str(frame), want, player.attack_kind])

    if not packaged:
        # A missing attack clip must refuse the link, not keep the old clip.
        _reset_actors()
        _setup_conditions([])
        var saved_clip: Variant = player._candidate_clip_paths.get("high_punch3")
        player._candidate_clip_paths.erase("high_punch3")
        player.record_standing_combo_press("in")
        player.record_standing_combo_press("a")
        if player.attack_kind == "high_punch3":
            failures.append("missing clip did not fail closed")
        if saved_clip != null:
            player._candidate_clip_paths["high_punch3"] = saved_clip
        # A failed member table refuses every group link.
        _reset_actors()
        _place("punch", 40.0)
        var was_complete: bool = player._candobasicattacks_complete
        player._candobasicattacks_complete = false
        var before_kind: String = player.attack_kind
        player.record_standing_combo_press("a")
        if player.attack_kind != before_kind:
            failures.append("incomplete member table still followed a group link")
        player._candobasicattacks_complete = was_complete

    var result: Dictionary = {
        "packaged": packaged,
        "coverage": coverage,
        "failures": failures,
    }
    print("CANDOBASICATTACKS_LINKS=" + JSON.stringify(result))
    if not failures.is_empty():
        push_error("CANDOBASICATTACKS_LINK_FAILURES=" + str(failures))
        quit(1)
        return
    quit(0)


func _reset_actors() -> void:
    player.reset_fighter(Vector3(-0.25, 1.20, 0.0))
    computer.reset_fighter(Vector3(0.25, 1.20, 0.0))
    player.health = 9999.0
    computer.health = 9999.0
    computer.state = "idle"
    player.facing = 1.0
    player.set_key_status({})
    player._clear_link_events()
    player._link_scan_action = ""
    player._link_scan_previous_frame = -1.0


func _setup_conditions(conditions: Array) -> void:
    for condition: String in conditions:
        match condition:
            "oppposestun":
                computer.state = "stun"
            "oppposelaying":
                computer.state = "facedownidle"
            "grabdistance":
                computer.global_position = Vector3(0.05, 1.20, 0.0)
    _place("punch", 40.0)


func _place(kind: String, frame: float) -> void:
    player.reset_fighter(Vector3(-0.25, 1.20, 0.0))
    player.health = 9999.0
    player.facing = 1.0
    player.attack_kind = kind
    var details: Dictionary = player.ATTACKS[kind]
    var startup: int = int(round(float(details["startup"]) * FPS))
    var active: int = int(round(float(details["active"]) * FPS))
    var count: int = int(details["animation_frame_count"])
    if frame <= float(startup):
        player.state = "startup"
        player.state_time = maxf((float(startup) - frame) / FPS, 0.0)
    elif frame <= float(startup + active):
        player.state = "active"
        player.state_time = (float(startup + active) - frame) / FPS
    else:
        player.state = "recovery"
        player.state_time = (float(count) - frame) / FPS
    player._attack_connected = true
    player._attack_hit_landed = true
    player._clear_link_events()
    player._link_scan_action = ""
    player._link_scan_previous_frame = -1.0
    player._animate_candidate()

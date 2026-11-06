extends SceneTree
## Probe (not a regression): exercise every recovered candobasicattacks link
## against the real res://scenes/main.tscn and report what actually happens.
##
## Usage:
##   godot --headless --path <project> --script res://tests/_probe_candobasicattacks.gd \
##       -- <bruce.glb> <brick.glb>

const FPS: float = 30.0

# order, target action, variant-1 key tokens, conditions, expectation mode,
# expected kind.  The `unique` token names the matchup OPPONENT, so against a
# Brick opponent order 36 is the native finisher, generic order 34 is deferred,
# order 35 (endbrucelee) and orders 37-44 are refused by the owner gate.
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
var results: Array = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and Brick candidate GLB paths")
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
    player = scene.get("player")
    computer = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)
    if not player.candidate_loaded:
        push_error("player candidate: " + player.candidate_load_error)
        quit(1)
        return
    if not computer.candidate_loaded:
        push_error("opponent candidate: " + computer.candidate_load_error)
        quit(1)
        return

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
            results.append({"order": order, "target": target, "status": "MISSING_LINK"})
            continue
        _reset_actors()
        _setup_conditions(conditions)
        # Native keystatus for finishers is "right pressed" (the toward-opponent
        # held direction); the port reads it from MOVE_RIGHT.
        player.set_key_status({"right": true})
        # Measure every gate before the press, while the source action current.
        var applies: bool = player._native_link_applies(link)
        var unique_ok: bool = player._native_link_unique_ok(link)
        var window_ok: bool = player._native_link_window_ok(link, -1.0)
        var sequence_ok: bool = player._link_sequence_matches(link)
        var status_ok: bool = player._native_link_status_ok(link)
        var conditions_ok: bool = player._native_link_conditions_ok(link)
        var target_kind: String = player._native_target_kind(link)
        var before_sequence: int = player.attack_sequence
        var before_kind: String = player.attack_kind
        var before_state: String = player.state
        for token: String in keys:
            player.record_standing_combo_press(token)
        var after_kind: String = player.attack_kind
        var after_state: String = player.state
        var status: String
        match mode:
            "plays":
                if not applies:
                    status = "NOT_APPLICABLE"
                elif not unique_ok:
                    status = "OWNER_GATE"
                elif not window_ok:
                    status = "WINDOW_CLOSED"
                elif not status_ok:
                    status = "STATUS_GATE"
                elif not conditions_ok:
                    status = "CONDITIONS_GATE"
                elif after_kind == expected:
                    status = "PASS"
                else:
                    status = "FAILED"
            "deferred":
                if not applies:
                    status = "NOT_APPLICABLE"
                elif not player._defer_generic_link_for_variant(link):
                    status = "NOT_DEFERRED"
                elif after_kind == expected:
                    status = "GENERIC_STILL_PLAYED"
                else:
                    status = "DEFERRED"
            "refused":
                if not applies:
                    status = "NOT_APPLICABLE"
                elif unique_ok:
                    status = "OWNER_NOT_FILTERED"
                elif after_kind == expected:
                    status = "OWNER_HAS_KIND"
                else:
                    status = "OWNER_REFUSED"
            _:
                status = "UNKNOWN_MODE"
        results.append({
            "order": order, "target": target, "expected": expected,
            "mode": mode, "applies": applies, "unique_ok": unique_ok,
            "sequence_ok": sequence_ok, "status_ok": status_ok,
            "conditions_ok": conditions_ok, "target_kind": target_kind,
            "before": {"kind": before_kind, "state": before_state},
            "after": {"kind": after_kind, "state": after_state},
            "status": status,
        })

    # Window boundary: lowpunch1 candobasicattacks is [22,69]. Frame 9 is
    # outside both it and combolevel1 [10,21]; frame 21 is inside combolevel1
    # and must take the combolevel1 link, not the candobasicattacks one.
    var boundaries: Array = []
    var punch_link: Dictionary = by_order.get(88, {})
    if not punch_link.is_empty():
        player.set_key_status({})
        for frame: float in [9.0, 21.0, 22.0, 40.0, 69.0]:
            _reset_actors()
            _place("punch", frame)
            var before_kind: String = player.attack_kind
            var window: Array = player._native_link_window_for_action(punch_link, "lowpunch1")
            player.record_standing_combo_press("a")
            boundaries.append({
                "frame": frame, "window": window,
                "kind": player.attack_kind, "before": before_kind,
                "fired": player.attack_kind != before_kind,
            })
    print("CANDOBASICATTACKS_PROBE=" + JSON.stringify({
        "links": results, "boundaries": boundaries,
    }))
    var failures: int = 0
    for row: Dictionary in results:
        if String(row["status"]) not in ["PASS", "OWNER_REFUSED"]:
            failures += 1
    for row: Dictionary in boundaries:
        if float(row["frame"]) == 9.0 and bool(row["fired"]):
            failures += 1
        if float(row["frame"]) >= 22.0 and String(row["kind"]) != "high_punch":
            failures += 1
        if float(row["frame"]) == 21.0 and String(row["kind"]) != "high_punch2":
            failures += 1
    quit(0 if failures == 0 else 1)


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

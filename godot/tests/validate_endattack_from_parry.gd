extends SceneTree
## Validate the recovered candobasicattacks -> endattack1 link from a parry
## attack, through the real victim conversion path.
##
## Native facts (adreno_200/set/brucelee.set, native_links.json, keyboard
## variant 1 = fighter+0x1c):
##   order 34  candobasicattacks -> endattack1, sequence [pressa],
##             keystatus right=pressed, conditions oppposestun + grabdistance,
##             unique [] (generic)
##   order 90  candobasicattacks -> highpunch1, sequence [pressa], no keystatus,
##             no conditions
## Link order is native scan order.  Without `right` held, order 34 fails its
## recovered InputStatusCheck and the later order-90 link wins: endattack1 must
## not be invented.  With `right` held, order 34 fires first and the finisher
## converts a stunned victim into endattackcomp1 (93 source frames, Thai
## all_end_attack_01_forset03) then exits to faceupko.  The old three-press
## [up,in,b] / [a] / [a] sequence belonged to the removed prototype
## STANDING_COMBO_SEQUENCES table, not to the recovered native link table.

const FINISHER_ORDER: int = 34
const COMPETITOR_ORDER: int = 90


func _initialize() -> void:
    call_deferred("_run")


func _link_by_order(f: PortFighter, order: int) -> Dictionary:
    for link: Dictionary in f._native_links:
        if int(link.get("order", -1)) == order:
            return link
    return {}


func _reset_parry(f: PortFighter, d: PortFighter) -> void:
    f._clear_link_state()
    f.reset_fighter(Vector3(0.0, 1.20, 0.0))
    d.reset_fighter(Vector3(0.30, 1.20, 0.0))
    f.opponent = d
    d.opponent = f
    f.attack_kind = "parry_attack"
    f.attack_sequence += 1
    f.state = "recovery"
    f.state_time = (85.0 - 20.0) / PortFighter.SOURCE_FRAME_RATE
    f._attack_hit_landed = true
    d.state = "stun"
    f.set_key_status({})
    f.set_held_directions({})


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty():
        push_error("candidate GLB path required")
        quit(1)
        return
    var player: PortFighter = load("res://scripts/fighter.gd").new()
    var defender: PortFighter = load("res://scripts/fighter.gd").new()
    for fighter: PortFighter in [player, defender]:
        fighter.configure("probe", fighter == player, Color.WHITE)
        fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
        fighter.configure_candidate_asset(
            args[0], "", PortFighter.CANDIDATE_CLIPS, "body"
        )
        root.add_child(fighter)
    await process_frame
    if not player.candidate_loaded or not defender.candidate_loaded:
        push_error("candidate failed to load")
        quit(1)
        return
    var finisher: Dictionary = _link_by_order(player, FINISHER_ORDER)
    var competitor: Dictionary = _link_by_order(player, COMPETITOR_ORDER)
    if (finisher.is_empty() or competitor.is_empty()
            or String(finisher.get("to", "")) != "endattack1"
            or String(competitor.get("to", "")) != "highpunch1"
            or int(finisher.get("order", -1)) >= int(competitor.get("order", -1))):
        push_error("recovered finisher/competitor link order drifted")
        quit(1)
        return
    _reset_parry(player, defender)
    if not (player._native_link_applies(finisher)
            and player._native_link_unique_ok(finisher)
            and player._native_link_window_ok(finisher)
            and player._native_link_conditions_ok(finisher)):
        push_error("order 34 is not applicable in the parry_attack window")
        quit(1)
        return
    if player._native_link_status_ok(finisher):
        push_error("order 34 passed InputStatusCheck without right held")
        quit(1)
        return
    # The obsolete prototype sequence must fail closed: native order 90 wins.
    player.record_standing_combo_press("b", ["up", "in"])
    player.record_standing_combo_press("a", [])
    player.record_standing_combo_press("a", [])
    if player.attack_kind == "endattack1":
        push_error("obsolete prototype sequence invented endattack1")
        quit(1)
        return
    if player.attack_kind != "high_punch":
        push_error("native link order 90 did not win without right held: "
                + player.attack_kind)
        quit(1)
        return
    # Recovered keyboard-variant-1 finisher input: one A press, right held.
    _reset_parry(player, defender)
    player.set_key_status({"right": true})
    player.set_held_directions({"right": true})
    if not player._native_link_status_ok(finisher):
        push_error("order 34 refused right-held InputStatusCheck")
        quit(1)
        return
    if not player.record_standing_combo_press("a"):
        push_error("parry attack did not complete the endattack sequence")
        quit(1)
        return
    if player.attack_kind != "endattack1":
        push_error("parry endattack selected " + player.attack_kind)
        quit(1)
        return
    if player.current_source_animation() != "m01_end_attack_01":
        push_error("endattack1 requested " + player.current_source_animation())
        quit(1)
        return
    var health_before: float = defender.health
    var saw_comp: bool = false
    var comp_frames_ok: bool = false
    var comp_clip_ok: bool = false
    var saw_exit: bool = false
    for _i in range(500):
        player._physics_process(1.0 / 60.0)
        defender._physics_process(1.0 / 60.0)
        if defender.state == "endattackcomp1" and not saw_comp:
            saw_comp = true
            comp_frames_ok = absf(
                defender.state_time
                - (93.0 / PortFighter.SOURCE_FRAME_RATE)
            ) <= (2.0 / 60.0) + 0.0001
            comp_clip_ok = (
                defender.current_victim_animation()
                == "all_end_attack_01_forset03"
            )
        if saw_comp and defender.state == "faceupko":
            saw_exit = true
            break
    if not saw_comp:
        push_error("endattack1 never consumed the stunned victim: "
                + defender.state)
        quit(1)
        return
    if not comp_frames_ok:
        push_error("endattackcomp1 hold was not the recovered 93 frames")
        quit(1)
        return
    if not comp_clip_ok:
        push_error("endattackcomp1 selected the wrong victim clip: "
                + defender.current_victim_animation())
        quit(1)
        return
    if not saw_exit:
        push_error("endattackcomp1 did not exit to faceupko: "
                + defender.state)
        quit(1)
        return
    if absf(defender.health - health_before) > 0.001:
        push_error("endattack1 invented damage")
        quit(1)
        return
    print("PARRY_ENDATTACK_VALIDATION=" + JSON.stringify({
        "from": "parry_attack",
        "to": "endattack1",
        "source_animation": "m01_end_attack_01",
        "native_link": FINISHER_ORDER,
        "sequence": ["a"],
        "keystatus": "right pressed",
        "conditions": ["oppposestun", "grabdistance"],
        "obsolete_sequence_kind": "high_punch",
        "obsolete_link_order": COMPETITOR_ORDER,
        "victim_start": "stun",
        "victim_comp": "endattackcomp1",
        "victim_clip": "all_end_attack_01_forset03",
        "victim_frames": 93,
        "victim_exit": "faceupko",
        "state": player.state,
    }))
    player.queue_free()
    defender.queue_free()
    await process_frame
    quit(0)

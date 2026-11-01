extends SceneTree
## parryhigh has no recovered impacts; it must never apply a zero-damage hit.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var attacker: PortFighter = load("res://scripts/fighter.gd").new()
    var defender: PortFighter = load("res://scripts/fighter.gd").new()
    attacker.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    defender.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(attacker)
    root.add_child(defender)
    await process_frame
    attacker.global_position = Vector3.ZERO
    defender.global_position = Vector3.ZERO
    if not attacker.request_attack("parry_high"):
        push_error("parry_high request failed")
        quit(1)
        return
    var health_before: float = defender.health
    var state_before: String = defender.state
    attacker._physics_process(0.2)
    if defender.state != state_before or not is_equal_approx(defender.health, health_before):
        push_error("parry_high applied a contact: state=" + defender.state
            + " health=" + str(defender.health))
        quit(1)
        return
    print("NON_CONTACT_PARRY_VALIDATION=" + JSON.stringify({
        "attack": "parry_high",
        "defender_state": defender.state,
        "health_delta": defender.health - health_before,
    }))
    attacker.queue_free()
    defender.queue_free()
    await process_frame
    quit(0)

extends SceneTree
## Hit bookkeeping must be per-attack: starting a new attack clears landed/
## connected/grab flags and the multi-impact applied list.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var f: PortFighter = load("res://scripts/fighter.gd").new()
    f.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(f)
    f.set_physics_process(false)
    f._attack_hit_landed = true
    f._attack_connected = true
    f._grab_connected = true
    f._multi_impact_applied = [0, 2]
    if not f.request_attack("punch"):
        push_error("request_attack failed")
        quit(1)
        return
    if f._attack_hit_landed or f._attack_connected or f._grab_connected:
        push_error("new attack did not clear hit bookkeeping flags")
        quit(1)
        return
    if not f._multi_impact_applied.is_empty():
        push_error("new attack did not clear multi-impact bookkeeping")
        quit(1)
        return
    print("HIT_BOOKKEEPING_VALIDATION=" + JSON.stringify({
        "flags_cleared": true, "multi_impact_cleared": true,
    }))
    quit(0)

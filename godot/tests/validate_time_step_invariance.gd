extends SceneTree
## Time-step invariance for attack phase scheduling: the same total elapsed
## time must produce the same hits/position/final state regardless of chunking.

func _initialize() -> void:
    call_deferred("_run")


func _make_fighter() -> PortFighter:
    var f: PortFighter = load("res://scripts/fighter.gd").new()
    f.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(f)
    f.set_physics_process(false)
    return f


func _simulate(step_seconds: Array) -> Dictionary:
    var p: PortFighter = _make_fighter()
    var o: PortFighter = _make_fighter()
    p.reset_fighter(Vector3(0.0, 1.2, 0.0))
    o.reset_fighter(Vector3(0.4, 1.2, 0.0))
    p.opponent = o
    o.opponent = p
    if not p.request_attack("punch"):
        return {"error": "request failed"}
    var hp_before: float = o.health
    for dt: float in step_seconds:
        p.position = Vector3(0.0, 1.2, 0.0)
        o.position = Vector3(0.4, 1.2, 0.0)
        p._physics_process(dt)
        o._physics_process(dt)
    var result: Dictionary = {
        "health_delta": hp_before - o.health,
        "state": p.state,
        "attack": p.attack_kind,
        "x": snappedf(p.position.x, 0.0001),
        "hits": p.combo_hits,
    }
    p.queue_free()
    o.queue_free()
    return result


func _run() -> void:
    var four: Array = []
    for _i: int in range(4):
        four.append(0.1)
    var coarse: Dictionary = _simulate([0.4])
    var fine: Dictionary = _simulate(four)
    var same: bool = (
        absf(float(coarse["health_delta"]) - float(fine["health_delta"])) < 0.001
        and int(coarse["hits"]) == int(fine["hits"])
        and String(coarse["state"]) == String(fine["state"])
        and String(coarse["attack"]) == String(fine["attack"])
        and absf(float(coarse["x"]) - float(fine["x"])) < 0.001
    )
    if not same:
        push_error("TIME_STEP_INVARIANCE_FAIL coarse=" + JSON.stringify(coarse)
                + " fine=" + JSON.stringify(fine))
        quit(1)
        return
    print("TIME_STEP_INVARIANCE_VALIDATION=" + JSON.stringify({
        "coarse": coarse, "fine": fine, "invariant": true,
    }))
    quit(0)

extends SceneTree
## TEMPORARY probe (not a deliverable): show how the recovered reaction gate
## resolves incoming impacts while the victim action carries impactablefromair.

const G = preload("res://scripts/native_reaction_state.gd")

var lines: Array[String] = []

func _probe(action: String, strength: String, height: String, direction: String,
        frame: float = 5.0) -> Dictionary:
    var attacker: Dictionary = {
        "impact_active": true,
        "height": height,
        "strength": strength,
        "direction": direction,
        "radius": 70.0,
        "scale": 1.0,
        "last_index": 0,
        "cursor": 0,
        "damage": 7.0,
    }
    return {
        "action": action,
        "frame": frame,
        "health": 100.0,
        "incoming_damage": 7.0,
        "distance": 10.0,
        "victim_radius": 25.0,
        "status": {"left": false},
        "attacker": attacker,
    }

func _initialize() -> void:
    var gate: G = G.new()
    var ok: bool = gate.load_native_links(G.NATIVE_LINKS_PATH)
    print("LOAD ok=", ok, " ", gate.load_error)
    var air_actions: Array = []
    for name: String in gate.actions:
        var groups: Variant = gate.actions[name].get("groups", {})
        if groups is Dictionary and Dictionary(groups).has("impactablefromair"):
            air_actions.append(name)
    print("AIR_ACTIONS=", air_actions)
    for action: String in air_actions:
        var grp: Dictionary = Dictionary(gate.actions[action].get("groups", {}))
        print("-- action=", action, " pose=", gate.actions[action].get("pose", ""),
            " airwin=", grp.get("impactablefromair", []),
            " impwin=", grp.get("impactable", []))
        for strength: String in ["normal", "medium", "hard", "brutal"]:
            for direction: String in ["frontal", "fromleft", "fromright", "fromabove"]:
                var r: Dictionary = gate.resolve(_probe(action, strength, "high", direction))
                print("   ", strength, "/high/", direction, " -> ",
                    r.get("to", ""), " order=", r.get("order", -1),
                    " result=", r.get("result", "?"))
    quit(0)

extends SceneTree
## Audit every configured attack's state source radius against the recovered ANM radius.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var raw_file: FileAccess = FileAccess.open(
        "res://data/attack_animation_radii.json", FileAccess.READ
    )
    if raw_file == null:
        push_error("missing attack_animation_radii.json")
        quit(1)
        return
    var raw: Variant = JSON.parse_string(raw_file.get_as_text())
    if not raw is Dictionary:
        push_error("attack animation radii is not an object")
        quit(1)
        return
    var fighter: PortFighter = load("res://scripts/fighter.gd").new()
    fighter.configure_attack_config(PortFighter.ATTACK_CONFIG_PATH)
    root.add_child(fighter)
    await process_frame
    var failures: Array[String] = []
    var checked: int = 0
    for key: String in fighter.ATTACKS.keys():
        var action: Dictionary = fighter.ATTACKS[key]
        var source_action: String = String(action.get("source_action", ""))
        if source_action.is_empty():
            if key != "heavy":
                failures.append(key + " has no source_action but is not heavy")
            continue
        if not raw.get("actions", {}).has(source_action):
            failures.append(key + " has no recovered radius entry")
            continue
        var recovered: Dictionary = raw["actions"][source_action]
        if String(action.get("animation", "")) != String(recovered.get("animation", "")):
            failures.append(key + " animation mismatch")
            continue
        fighter.reset_fighter(Vector3.ZERO)
        if not fighter.request_attack(key):
            failures.append(key + " request failed")
            continue
        checked += 1
        var expected: float = float(recovered["animation_radius"])
        var actual: float = fighter.source_radius_for_current_animation()
        if absf(actual - expected) > 0.001:
            failures.append("%s expected %.1f got %.1f" % [key, expected, actual])
    if checked != raw["actions"].size():
        failures.append("checked %d of %d recovered actions" % [
            checked, raw["actions"].size()
        ])
    if not failures.is_empty():
        push_error("attack animation radius mismatches: " + JSON.stringify(failures))
        quit(1)
        return
    print("ATTACK_ANIMATION_RADII_VALIDATION=" + JSON.stringify({
        "configured_actions": fighter.ATTACKS.size(),
        "checked_actions": checked,
        "skipped": ["heavy"],
        "mismatches": [],
    }))
    fighter.queue_free()
    await process_frame
    quit(0)

extends SceneTree

const HUD = preload("res://scripts/hud.gd")

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var hud = HUD.new()
    root.add_child(hud)
    await process_frame
    if hud.rage_bar == null:
        push_error("HUD has no rage bar")
        quit(1)
        return
    hud.set_rage(55.0)
    if absf(hud.rage_bar.value - 55.0) > 0.001:
        push_error("HUD rage did not update: " + str(hud.rage_bar.value))
        quit(1)
        return
    hud.set_rage(150.0)
    if absf(hud.rage_bar.value - 100.0) > 0.001:
        push_error("HUD rage was not clamped: " + str(hud.rage_bar.value))
        quit(1)
        return
    print("HUD_RAGE_VALIDATION=" + JSON.stringify({
        "rage": hud.rage_bar.value,
        "max": hud.rage_bar.max_value,
    }))
    hud.queue_free()
    await process_frame
    quit(0)

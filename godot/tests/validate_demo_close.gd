extends SceneTree

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_DEMO_RAGE", "100")
    OS.set_environment("BRUCELEE_DEMO_CLOSE", "1")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    if player == null or computer == null:
        push_error("main scene lacks fighters")
        quit(1)
        return
    if Vector2(player.global_position.x, player.global_position.z).distance_to(
            Vector2(computer.global_position.x, computer.global_position.z)) > 1.5:
        push_error("demo close distance wrong: %s / %s" % [
            str(player.global_position.x), str(computer.global_position.x)
        ])
        quit(1)
        return
    var hud: PortHUD = scene.get("hud")
    if hud == null or not hud.footer.text.contains("J J J"):
        push_error("demo footer hint missing")
        quit(1)
        return
    if not hud.footer.text.contains("Back+K -> Toward+L -> Toward+L"):
        push_error("demo footer special hint is not direction-neutral")
        quit(1)
        return
    if hud.footer.text.contains("A+K") or hud.footer.text.contains("D+L"):
        push_error("demo footer special hint hardcodes facing")
        quit(1)
        return
    print("DEMO_CLOSE_VALIDATION=" + JSON.stringify({
        "player_x": player.global_position.x,
        "computer_x": computer.global_position.x,
        "rage": player.rage,
        "footer": hud.footer.text,
    }))
    scene.queue_free()
    await process_frame
    quit(0)

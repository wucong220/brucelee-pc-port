extends SceneTree
var failures := 0
func _initialize():
    call_deferred("run")
func check(label, ok, detail=""):
    print(("PASS " if ok else "FAIL "), label, " ", detail)
    if not ok: failures += 1
func key(code):
    var e = InputEventKey.new()
    e.keycode = code
    e.physical_keycode = code
    e.pressed = true
    return e
func press(node, code):
    return node.handle_input_event(key(code))
func run():
    OS.set_environment("BRUCELEE_MAIN_MENU", "1")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_STYLE_EDITOR", "")
    var scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    var menu = scene.get("prototype_menu")
    var training = scene.get("move_training")
    var player = scene.get("player")
    var victim = scene.get("computer")
    check("normal boot main menu and candidates", menu.visible and player.candidate_loaded and victim.candidate_loaded, str([menu.visible,player.candidate_loaded,victim.candidate_loaded]))
    var phase = OS.get_cmdline_user_args()[0]
    if phase == "create":
        check("no preexisting save", not scene.get("style_store").file_found)
        for i in range(5): press(menu, KEY_DOWN)
        check("training row selected", menu.selected_command() == "move_training", menu.selected_command())
        press(menu, KEY_ENTER)
        check("practice opened", training.state == "practice", training.state)
        press(training, KEY_DOWN)
        press(training, KEY_ENTER)
        var editor = scene.get("style_editor")
        check("practice opens editor", editor != null and editor.is_open())
        if editor == null: quit(1); return
        print("CATEGORY ", editor.current_options())
        # personality, special, grabs
        press(editor, KEY_DOWN)
        press(editor, KEY_DOWN)
        press(editor, KEY_ENTER)
        check("grabs menu opened", editor.screen_name() == "grabs", editor.screen_name())
        press(editor, KEY_ENTER)
        check("grab A dock opened", editor.group_key() == "grabs/graba", editor.group_key())
        for i in range(3): press(editor, KEY_RIGHT)
        var entry = editor.current_entry()
        print("BRICK_ENTRY ", entry)
        check("Brick grab A focused", entry.get("id", "") == "grababrick", str(entry.get("id", "")))
        press(editor, KEY_ENTER)
        check("fresh profile refuses locked Brick", scene.get("style_store").selected("grabs/graba") == "grababrucelee" and not FileAccess.file_exists("user://style_selections.json") and String(editor.get("_status")).contains("LOCKED"), str(editor.get("_status")))
        var granted = scene.get("progress").sync_story_exp(9600)
        check("live progression grants 57", granted.has(57), str(granted))
        press(editor, KEY_ENTER)
        check("UI saved Brick entry", scene.get("style_store").selected("grabs/graba") == "grababrick" and FileAccess.file_exists("user://style_selections.json"), str(editor.get("_status")))
        check("UI selection updated active IDs", player.active_uniques().has("grababrick") and not player.active_uniques().has("grababrucelee"), str(player.active_uniques()))
        for i in range(3): press(editor, KEY_ESCAPE)
        check("editor closed to practice", not editor.is_open() and training.state == "practice", training.state)
        # Back out via practice cancel and start VS using main menu.
        press(training, KEY_ESCAPE)
        check("returned main menu", menu.visible, str([menu.visible,training.state]))
        if menu.visible:
            while menu.selected_command() != "fight": press(menu, KEY_UP)
            press(menu, KEY_ENTER)
            check("VS start retains Brick", player.active_uniques().has("grababrick"), str(player.active_uniques()))
    else:
        var store = scene.get("style_store")
        check("fresh process loaded UI save", store.loaded_ok and store.selected("grabs/graba") == "grababrick", str([store.loaded_ok,store.last_error,store.selections]))
        check("fresh boot active Brick ID", player.active_uniques().has("grababrick") and not player.active_uniques().has("grababrucelee"), str(player.active_uniques()))
        press(menu, KEY_ENTER)
        check("fresh process VS start", not menu.visible, str(menu.visible))
    # Drive real key handler with held action state, pin position/rage as fixture.
    scene.set_process(false)
    scene.set_physics_process(false)
    player.set_physics_process(false)
    victim.set_physics_process(false)
    scene._reset_match()
    player.rage = 100.0
    player.position = Vector3(0,1.2,0)
    victim.position = Vector3(0.35,1.2,0)
    player.facing = 1.0
    Input.action_press("prototype_move_up")
    player.set_held_directions(scene._held_direction_flags())
    scene._update_player_key_status()
    scene._unhandled_input(key(KEY_W))
    player.set_held_directions(scene._held_direction_flags())
    scene._update_player_key_status()
    scene._unhandled_input(key(KEY_J))
    check("W+J starts Brick grab miss", player.attack_kind == "grab1miss brick", player.attack_kind)
    var chained = false
    var held = false
    for i in range(220):
        player.position = Vector3(0,1.2,0)
        victim.position = Vector3(0.35,1.2,0)
        player._physics_process(1.0/60.0)
        victim._physics_process(1.0/60.0)
        if player.attack_kind == "grab1 brick": chained = true
        if victim.state == "grabbed1": held = true; break
    player._animate_candidate()
    check("Brick grab chains and holds", chained and held, str([chained,held,player.attack_kind,victim.state,player.candidate_animation_clip]))
    Input.action_release("prototype_move_up")
    print("RESULT phase=",phase," failures=",failures," save=",ProjectSettings.globalize_path("user://style_selections.json"))
    quit(0 if failures == 0 else 1)

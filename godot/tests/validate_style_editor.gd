extends SceneTree
## Headless validation for the opt-in Style Editor integration.
##
##   godot --headless --path godot --script res://tests/validate_style_editor.gd
##
## Covers the decoded catalog counts/layouts, the opt-in main-menu row, the
## user:// selection file (save / load / tamper fail-closed), real keyboard
## navigation through the category -> special -> fighter flow including the
## persistent "saved" highlight, and the fighter's direct-clip apply/fail-closed
## behaviour. No GLB is needed: the apply test installs a fake AnimationPlayer
## so presence/absence of a clip is measured, not assumed.

const CatalogScript = preload("res://scripts/style_catalog.gd")
const StoreScript = preload("res://scripts/style_selection_store.gd")
const ScreenScript = preload("res://scripts/style_editor_screen.gd")
const MenuScript = preload("res://scripts/prototype_menu.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const ClipMap = preload("res://scripts/style_clip_map.gd")
const PrototypeControls = preload("res://scripts/prototype_controls.gd")

const TEST_SAVE := "user://style_selections_test.json"

var failures: Array = []
var checks: int = 0


func _initialize() -> void:
    call_deferred("_run")


func check(condition: bool, label: String) -> void:
    checks += 1
    if condition:
        print("CHECK PASS %s" % label)
    else:
        failures.append(label)
        print("CHECK FAIL %s" % label)


func _press(keycode: Key) -> void:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = keycode
    event.physical_keycode = keycode
    event.pressed = true
    Input.parse_input_event(event)
    await process_frame
    await process_frame


func _run() -> void:
    PrototypeControls.ensure_default_actions()
    OS.set_environment("BRUCELEE_STYLE_EDITOR", "")
    OS.set_environment("BRUCELEE_PROGRESS", "")
    var catalog = CatalogScript.new()
    var loaded: bool = catalog.load_catalog()
    check(loaded, "style catalog loads")
    if not loaded:
        print("catalog error: " + catalog.error)
        quit(1)
        return

    _check_catalog(catalog)
    await _check_menu_gating()
    _check_clip_index(catalog)
    var store = _check_store(catalog)
    await _check_navigation(catalog, store)
    await _check_fighter_apply(catalog)

    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    print("STYLE EDITOR VALIDATION: %d checks, %d failed" % [checks, failures.size()])
    if failures.is_empty():
        quit(0)
    else:
        for failure in failures:
            print("FAILED: " + String(failure))
        quit(1)


func _check_catalog(catalog) -> void:
    check(int(catalog.strings_count()) == 205, "205 decoded strings")
    check(catalog.data["entries"].size() == 60, "60 decoded style entries")
    check(catalog.group("personality/personality").get("count", 0) == 10, "personality 10")
    check(catalog.group("special/hpunch").get("count", 0) == 10, "hpunch 10")
    check(catalog.group("special/lpunch").get("count", 0) == 7, "lpunch 7")
    check(catalog.group("special/hkick").get("count", 0) == 9, "hkick 9")
    check(catalog.group("special/lkick").get("count", 0) == 7, "lkick 7")
    check(catalog.group("grabs/graba").get("count", 0) == 5, "graba 5")
    check(catalog.group("grabs/grabb").get("count", 0) == 5, "grabb 5")
    check(catalog.group("endmove/endmove").get("count", 0) == 7, "endmove 7")
    check(catalog.groups_in_order().size() == 8, "8 selectable groups")
    check(bool(catalog.data.get("personality_injected", false)), "personality injected")

    var recovered: Array = catalog.recovered_category_options()
    check(recovered.size() == 5, "recovered category menu has 5 rows")
    check(String(recovered[0][1]) == "special", "recovered row 0 = special")
    check(String(recovered[1][1]) == "grabs", "recovered row 1 = grabs")
    check(String(recovered[2][1]) == "endmove", "recovered row 2 = endmove")
    check(String(recovered[3][1]) == "reset", "recovered row 3 = reset")
    check(String(recovered[4][1]) == "training", "recovered row 4 = training")
    var options: Array = catalog.category_options()
    check(options.size() == 6, "screen shows personality + 5 recovered rows")
    check(String(options[0][1]) == "personality", "personality row is first")

    check(
        catalog.widget_rect("styleeditor.ui", "title") == Rect2(0, 5, 300, 40),
        "styleeditor title rect"
    )
    check(
        catalog.widget_rect("styleeditor.ui", "menu") == Rect2(80, 60, 400, 180),
        "styleeditor menu rect"
    )
    check(
        catalog.widget_rect("styleeditor.ui", "back") == Rect2(2, 270, 48, 48),
        "styleeditor back rect"
    )
    check(
        catalog.widget_rect("styleeditor.ui", "help") == Rect2(428, 270, 48, 48),
        "styleeditor help rect"
    )
    check(
        catalog.widget_rect("stylespecial.ui", "menu") == Rect2(80, 80, 400, 160),
        "stylespecial menu rect"
    )
    check(
        catalog.widget_rect("stylegrabs.ui", "menu") == Rect2(80, 120, 400, 160),
        "stylegrabs menu rect"
    )
    check(
        catalog.widget_rect("styleselectfighterhpunch.ui", "fighters")
        == Rect2(200, 200, 280, 70),
        "fighter dock rect"
    )
    check(
        catalog.widget_rect("confirmresetstyle.ui", "menu") == Rect2(130, 180, 350, 80),
        "reset confirm menu rect"
    )
    var dock_order: Array = catalog.entries("special/hpunch")
    check(String(dock_order[0]["character"]) == "brucelee", "hpunch dock starts at brucelee")
    check(String(dock_order[dock_order.size() - 1]["character"]) == "loming",
          "hpunch dock ends at loming")

    var personality: Dictionary = catalog.entry("personality/personality", "personality brucelee")
    check(not personality.is_empty(), "personality brucelee entry exists")
    check(
        (personality.get("named_clips", []) as Array).has("m01_intro_01"),
        "personality names the recovered intro clip"
    )
    check(String(personality.get("clip", "")).is_empty(), "personality has no combat clip")


func _check_menu_gating() -> void:
    var baseline: Array = MenuScript.MAIN_COMMANDS
    var menu = MenuScript.new()
    root.add_child(menu)
    await process_frame
    menu.show_main_menu()
    await process_frame
    var commands: Array = menu.main_commands()
    check(commands == baseline, "flag-off main commands are the const baseline")
    check(not commands.has("style_editor"), "flag-off menu has no STYLE EDITOR row")
    check(String(menu.selected_command()) == "fight", "flag-off menu still starts on fight")
    menu.queue_free()
    await process_frame

    OS.set_environment("BRUCELEE_STYLE_EDITOR", "1")
    var style_menu = MenuScript.new()
    root.add_child(style_menu)
    await process_frame
    var style_commands: Array = style_menu.main_commands()
    check(
        String(style_commands[style_commands.size() - 2]) == "style_editor",
        "STYLE EDITOR is inserted before QUIT GAME"
    )
    check(String(style_commands[style_commands.size() - 1]) == "quit", "QUIT stays last")
    var labels: Array = style_menu.main_labels()
    check(
        String(labels[labels.size() - 2]) == "STYLE EDITOR",
        "STYLE EDITOR label is present"
    )
    style_menu.queue_free()
    await process_frame

    OS.set_environment("BRUCELEE_PROGRESS", "1")
    var both = MenuScript.new()
    root.add_child(both)
    await process_frame
    var both_commands: Array = both.main_commands()
    check(
        String(both_commands[both_commands.size() - 3]) == "records",
        "RECORDS precedes STYLE EDITOR when both flags are on"
    )
    check(
        String(both_commands[both_commands.size() - 2]) == "style_editor",
        "STYLE EDITOR stays before QUIT with both flags"
    )
    both.queue_free()
    await process_frame
    OS.set_environment("BRUCELEE_PROGRESS", "")
    OS.set_environment("BRUCELEE_STYLE_EDITOR", "")


func _check_clip_index(catalog) -> void:
    check(
        String(catalog.entry("special/hpunch", "hpunchbrucelee").get("clip", ""))
        == "m01_sp_pnch_high",
        "bruce hpunch has a direct clip"
    )
    check(
        String(catalog.entry("special/hpunch", "hpunchshenlo").get("clip", ""))
        == "m04_e03_pnch_high_03",
        "shenlo hpunch has a direct clip"
    )
    check(
        String(catalog.entry("special/hpunch", "hpunchsinfu").get("clip", ""))
        == "m04_sp_pnch_high",
        "sinfu hpunch has one exact clip"
    )
    check(
        String(catalog.entry("special/hpunch", "hpunchloming").get("clip", "")).is_empty(),
        "loming hpunch has no exact row -> no clip"
    )
    check(
        String(catalog.entry("grabs/graba", "grababrucelee").get("clip", "")) == "m01_grab_01",
        "bruce grab A direct clip"
    )
    check(
        String(catalog.entry("endmove/endmove", "endbrucelee").get("clip", ""))
        == "m01_end_attack_02",
        "bruce endmove direct clip"
    )
    var direct: int = 0
    for entry in catalog.data["entries"]:
        if not String(entry.get("clip", "")).is_empty():
            direct += 1
    check(direct == 49, "49 of 60 entries have a direct clip (got %d)" % direct)


func _check_store(catalog):
    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    var store = StoreScript.new()
    store.configure(TEST_SAVE)
    store.load_selections(catalog)
    check(store.selections.size() == 8, "store defaults cover 8 groups")
    check(
        String(store.selections.get("special/hpunch", "")) == "hpunchbrucelee",
        "default hpunch is the always-available Bruce entry"
    )
    check(store.set_selection(catalog, "special/hpunch", "hpunchshenlo"), "set selection")
    check(not store.set_selection(catalog, "special/hpunch", "does-not-exist"),
          "unknown id is refused")
    check(store.save(), "save selections")
    check(FileAccess.file_exists(TEST_SAVE), "selection file exists")

    var reloaded = StoreScript.new()
    reloaded.configure(TEST_SAVE)
    reloaded.load_selections(catalog)
    check(reloaded.loaded_ok, "saved file reloads")
    check(reloaded.checksum_ok, "checksum verifies")
    check(
        String(reloaded.selections.get("special/hpunch", "")) == "hpunchshenlo",
        "saved selection round-trips"
    )

    var file: FileAccess = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
    file.store_string("{\"schema\":\"brucelee-style-selections/1\",\"version\":1,\"payload_json\":\"{}\",\"checksum\":\"bad\"}")
    file.close()
    var tampered = StoreScript.new()
    tampered.configure(TEST_SAVE)
    tampered.load_selections(catalog)
    check(not tampered.loaded_ok, "tampered file fails closed")
    check(tampered.last_error.contains("checksum"), "tamper error mentions checksum")
    check(
        String(tampered.selections.get("special/hpunch", "")) == "hpunchbrucelee",
        "tamper falls back to decoded defaults"
    )
    return reloaded


func _check_navigation(catalog, store) -> void:
    var screen = ScreenScript.new()
    root.add_child(screen)
    await process_frame
    screen.configure(null, null, catalog, store)
    screen.open()
    await process_frame
    var report: Dictionary = screen.layout_report()
    check(report["screen"] == "category", "editor opens on the category screen")
    check((report["options"] as Array).size() == 6, "category screen shows 6 rows")
    check(screen.screen_name() == "category", "category screen name")

    await _press(KEY_DOWN)
    check(screen.cursor() == 1, "DOWN moves the category cursor")
    await _press(KEY_ENTER)
    check(screen.screen_name() == "special", "ENTER opens SPECIAL MOVES")
    check((screen.current_options() as Array).size() == 4, "special shows 4 moves")
    check(
        screen.layout_report()["widgets"].get("menu", []) == [80.0, 80.0, 400.0, 160.0],
        "special layout comes from stylespecial.ui"
    )
    await _press(KEY_ENTER)
    check(screen.screen_name() == "fighter", "ENTER opens the hpunch fighter dock")
    check(screen.group_key() == "special/hpunch", "fighter group is special/hpunch")
    check(screen.fighter_cursor() == 1, "cursor starts at the saved entry (shenlo)")

    await _press(KEY_RIGHT)
    check(screen.fighter_cursor() == 2, "RIGHT moves the fighter dock")
    check(
        String(screen.current_entry().get("id", "")) == "hpunchmaster",
        "fighter cursor points at the master"
    )
    await _press(KEY_ENTER)
    check(
        String(store.selections.get("special/hpunch", "")) == "hpunchshenlo",
        "locked ENTER does not change the saved selection"
    )
    check(
        String(screen.layout_report().get("status", "")).contains("LOCKED"),
        "locked ENTER reports LOCKED"
    )
    await _press(KEY_LEFT)
    await _press(KEY_LEFT)
    check(
        String(screen.current_entry().get("id", "")) == "hpunchbrucelee",
        "cursor returns to the always-available default"
    )
    await _press(KEY_ENTER)
    check(
        String(store.selections.get("special/hpunch", "")) == "hpunchbrucelee",
        "ENTER saves the always-available default"
    )
    check(
        String(screen.saved_entry_id()) == "hpunchbrucelee",
        "saved selection is the highlighted entry"
    )
    var fighter_report: Dictionary = screen.layout_report()
    check(
        String(fighter_report.get("saved_id", "")) == String(fighter_report.get("current_id", "")),
        "current selection is highlighted after save"
    )

    await _press(KEY_ESCAPE)
    check(screen.screen_name() == "special", "ESC returns to special")
    await _press(KEY_ESCAPE)
    check(screen.screen_name() == "category", "ESC returns to category")
    await _press(KEY_ESCAPE)
    check(not screen.is_open(), "ESC closes the editor at the category screen")

    screen.open()
    await process_frame
    await _press(KEY_DOWN)
    await _press(KEY_ENTER)
    await _press(KEY_ENTER)
    check(screen.screen_name() == "fighter", "reopened fighter screen")
    check(screen.fighter_cursor() == 0, "reopen starts on the saved entry")
    check(String(screen.saved_entry_id()) == "hpunchbrucelee", "reopen restores saved id")

    await _press(KEY_H)
    check(screen.screen_name() == "help", "H opens the help screen")
    await _press(KEY_ESCAPE)
    check(screen.screen_name() == "fighter", "ESC closes help")

    await _press(KEY_ESCAPE)
    await _press(KEY_ESCAPE)
    for i in range(4):
        await _press(KEY_DOWN)
    await _press(KEY_ENTER)
    check(screen.screen_name() == "reset", "reset confirmation opens")
    check((screen.current_options() as Array).size() == 2, "reset asks no/yes")
    await _press(KEY_ESCAPE)
    check(screen.screen_name() == "category", "ESC cancels reset")

    screen.close()
    await process_frame
    screen.queue_free()
    await process_frame


func _add_clip(player: AnimationPlayer, name: String) -> void:
    var animation: Animation = Animation.new()
    animation.length = 0.2
    var library: AnimationLibrary = null
    if player.has_animation_library(""):
        library = player.get_animation_library("")
    else:
        library = AnimationLibrary.new()
        player.add_animation_library("", library)
    library.add_animation(name, animation)


func _check_fighter_apply(catalog) -> void:
    var fighter = FighterScript.new()
    fighter.configure("Style Test", true, Color.WHITE)
    root.add_child(fighter)
    await process_frame
    var player: AnimationPlayer = AnimationPlayer.new()
    player.name = "FakeCandidateAnimation"
    fighter.add_child(player)
    for clip in [
        "m01_sp_pnch_high", "m01_sp_pnch_low", "m01_kck_front_step",
        "m01_sp_kick_low", "m01_grab_01", "m01_grab_02", "m01_end_attack_02",
    ]:
        _add_clip(player, clip)
    fighter.set("_candidate_animation", player)
    fighter.set("_candidate_clip_paths", {
        "special_punch_high_hit": "m01_sp_pnch_high",
        "special_punch_low_hit": "m01_sp_pnch_low",
        "special_kick_high": "m01_kck_front_step",
        "special_kick_low_hit": "m01_sp_kick_low",
        "grab1": "m01_grab_01",
        "grab2": "m01_grab_02",
        "endattack1": "m01_end_attack_01",
        "endattack2": "m01_end_attack_02",
    })
    var snapshot: Dictionary = fighter.style_runtime_snapshot()
    check(bool(snapshot.get("loaded", false)), "fake fighter reports a loaded library")

    var selections: Dictionary = catalog.defaults()
    var report: Dictionary = fighter.apply_style_selections(selections, catalog)
    check((report.get("applied", []) as Array).size() == 7,
          "all seven identity defaults apply")
    check(not (report.get("applied", []) as Array).has("personality/personality"),
          "personality is never a combat swap")
    check(
        String(fighter.get("_candidate_clip_paths")["special_punch_high_hit"])
        == "m01_sp_pnch_high",
        "identity hpunch keeps its clip"
    )

    selections["special/hpunch"] = "hpunchshenlo"
    report = fighter.apply_style_selections(selections, catalog)
    check(
        String(report["results"]["special/hpunch"]["status"]) == "size_variant_refused",
        "hpunch is a size-variant slot and refuses a different clip"
    )
    check(
        String(fighter.get("_candidate_clip_paths")["special_punch_high_hit"])
        == "m01_sp_pnch_high",
        "refused hpunch leaves the slot untouched"
    )

    selections["special/lkick"] = "lkickshenlo"
    report = fighter.apply_style_selections(selections, catalog)
    check(
        String(report["results"]["special/lkick"]["status"]) == "clip_not_loaded",
        "foreign clip fails closed when the fighter lacks it"
    )
    check(
        String(fighter.get("_candidate_clip_paths")["special_kick_low_hit"])
        == "m01_sp_kick_low",
        "failed foreign clip leaves the slot untouched"
    )

    _add_clip(player, "m04_e03_kck_low_03")
    report = fighter.apply_style_selections(selections, catalog)
    check(
        String(report["results"]["special/lkick"]["status"]) == "apply",
        "direct foreign clip applies once loaded"
    )
    check(
        String(fighter.get("_candidate_clip_paths")["special_kick_low_hit"])
        == "m04_e03_kck_low_03",
        "applied clip replaces the slot"
    )

    selections["special/hpunch"] = "hpunchloming"
    report = fighter.apply_style_selections(selections, catalog)
    check(
        String(report["results"]["special/hpunch"]["status"]) == "no_direct_clip",
        "entry without an exact row reports no_direct_clip"
    )
    check(
        String(fighter.get("_candidate_clip_paths")["special_punch_high_hit"])
        == "m01_sp_pnch_high",
        "no-direct-clip entry restores the base clip"
    )

    selections["personality/personality"] = "personality shenlo"
    report = fighter.apply_style_selections(selections, catalog)
    check(
        String(report["results"]["personality/personality"]["status"]) == "no_combat_slot",
        "personality reports no combat slot"
    )

    selections["special/hpunch"] = "not-a-real-id"
    report = fighter.apply_style_selections(selections, catalog)
    check(
        String(report["results"]["special/hpunch"]["status"]) == "unknown_entry",
        "unknown saved id reports unknown_entry"
    )

    fighter.queue_free()
    await process_frame




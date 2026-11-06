extends SceneTree
## Native per-fighter active uniques: default, tutorial (use_custom_style=false),
## Free Training and VS wiring, on the real res://scenes/main.tscn.
##
## CFighter+0x120 holds exact integer IDs.  For Bruce Lee the default list is
## the 8 characters.list uniques; CStyleEditor::SetUniquesList rebuilds the
## seven style-category IDs only for the modes that pass use_custom_style=true
## (Free Training / VS) and only when the saved style really exists.  Tutorial
## lessons pass false and must ignore the saved style entirely.
##
## usage: --headless --path <proj> --script res://tests/validate_native_uniques.gd -- \
##   <player.glb> <brick.glb>
##
## The style file is written into the isolated user:// directory of this run, so
## the VS/Free-Training checks exercise the real saved-style load path.

const BRUCE_PATH := "res://data/fighting_set_low_attacks.json"
const SAVED_STYLE: Dictionary = {
    "special/hpunch": "hpunchbrick",

    "grabs/graba": "grababrick",
    "endmove/endmove": "endsmallboy",
}
const EXPECTED_SAVED: Array[String] = [
    "brucelee", "endsmallboy", "grababrick", "grabbbrucelee",
    "hkickbrucelee", "hpunchbrick", "lkickbrucelee", "lpunchbrucelee",
]

var _failures: Array[String] = []
var _checks: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _check(label: String, ok: bool, detail: String = "") -> void:
    _checks += 1
    if ok:
        print("PASS ", label, " ", detail)
    else:
        _failures.append(label + " " + detail)
        push_error("FAIL " + label + " " + detail)


func _default_expected() -> Array:
    var out: Array = PortFighter.DEFAULT_BRUCE_UNIQUES.duplicate()
    out.sort()
    return out


func _boot(player_glb: String, opponent_glb: String) -> Node:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", player_glb)
    OS.set_environment("BRUCELEE_OPPONENT_GLB", opponent_glb)
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    return scene


func _freeze(scene: Node) -> void:
    scene.set_process(false)
    scene.set_physics_process(false)
    var player = scene.get("player")
    var computer = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)


func _by_order(player) -> Dictionary:
    var out: Dictionary = {}
    for link: Dictionary in player._native_links:
        out[int(link.get("order", -1))] = link
    return out


func _gate_snapshot(player) -> Dictionary:
    var by_order: Dictionary = _by_order(player)
    var result: Dictionary = {}
    for order: int in [6, 7, 8, 17, 34, 35, 36, 44]:
        result[order] = player._native_link_unique_ok(by_order.get(order, {}))
    return result


func _check_default_gate(player, label: String) -> void:
    _check(label + " active uniques are the 8 default IDs",
        player.active_uniques() == _default_expected(), str(player.active_uniques()))
    var gate: Dictionary = _gate_snapshot(player)
    for order: int in [6, 7, 34, 35]:
        _check(label + " allows native row " + str(order), bool(gate[order]), str(gate))
    for order: int in [8, 17, 36, 44]:
        _check(label + " refuses opponent-suffix row " + str(order),
            not bool(gate[order]), str(gate))


func _check_saved_gate(player, label: String) -> void:
    _check(label + " active uniques are the explicit saved style",
        player.active_uniques() == EXPECTED_SAVED, str(player.active_uniques()))
    var gate: Dictionary = _gate_snapshot(player)
    # 34 has no tag, so it always passes the membership gate; it is shadowed at
    # scan time by the selected specific row (covered by the endattack tests).
    # 6/35 were replaced by the selection; 17/36 have no selectable style entry.
    for order: int in [6, 17, 35, 36]:
        _check(label + " refuses the unselected row " + str(order),
            not bool(gate[order]), str(gate))
    for order: int in [7, 8, 34, 44]:
        _check(label + " allows the native/selected row " + str(order),
            bool(gate[order]), str(gate))


func _start_lesson(training, action: String) -> bool:
    ## Drives move_training's own _prepare_step so the use_custom_style field
    ## from training_native.json decides the fighter state.
    for entry: Dictionary in training.trainings:
        for step: Dictionary in Array(entry.get("steps", [])):
            if action in Array(step.get("success_animations", [])):
                training.current_training = entry
                training.steps = entry.get("steps", [])
                training.state = "active"
                training._start_step(int(step.get("index", 0)))
                return true
    return false


func _write_saved_style() -> bool:
    var catalog = StyleCatalog.new()
    if not catalog.load_catalog():
        push_error("style catalog failed: " + catalog.error)
        return false
    var store = StyleSelectionStore.new()
    store.configure(StyleSelectionStore.SAVE_PATH)
    store.selections = catalog.defaults()
    for group_key: String in SAVED_STYLE:
        store.selections[group_key] = SAVED_STYLE[group_key]
    if not store.save():
        push_error("style save failed: " + store.last_error)
        return false
    return true


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected <player.glb> <brick.glb>")
        quit(2)
        return
    # ---------------------------------------------------------- scene A: default
    var scene_a: Node = _boot(args[0], args[1])
    await process_frame
    await process_frame
    var player_a = scene_a.get("player")
    if not player_a.candidate_loaded:
        push_error("player candidate failed: " + player_a.candidate_load_error)
        quit(1)
        return
    if not scene_a.get("computer").candidate_loaded:
        push_error("opponent candidate failed")
        quit(1)
        return
    _freeze(scene_a)
    _check("main creates the saved style store without the opt-in editor screen",
        scene_a.get("style_store") != null and scene_a.get("style_editor") == null, "")
    _check("no style file yet", not bool(scene_a.get("style_store").file_found), "")
    _check_default_gate(player_a, "VS-default")
    # An explicit request without a saved style must stay default.
    var catalog = StyleCatalog.new()
    catalog.load_catalog()
    var report: Dictionary = player_a.apply_style_selections(
        catalog.defaults(), catalog)
    _check("default catalog selections keep the 8 default IDs",
        player_a.active_uniques() == _default_expected(), str(player_a.active_uniques()))
    # ------------------------------------------------- tutorial lesson (scene A)
    var training = scene_a.get("move_training")
    if not _start_lesson(training, "specialkickhigh"):
        push_error("no use_custom_style=false lesson found")
        quit(1)
        return
    _check("tutorial lesson is use_custom_style=false",
        training.current_training.get("use_custom_style", true) == false, "")
    _check("tutorial enters the default unique list",
        bool(player_a.tutorial_default_uniques)
        and player_a.active_uniques() == _default_expected(),
        str(player_a.active_uniques()))
    # A late style apply during the lesson must not leak in.
    var late_report: Dictionary = player_a.apply_style_selections(
        catalog.defaults(), catalog)
    _check("late style apply is refused while the tutorial gate is active",
        String(late_report.get("error", "")) == "tutorial default style is active"
        and player_a.active_uniques() == _default_expected(),
        String(late_report.get("error", "")))
    # ------------------------------------------------------ Free Training (A)
    training.enter_free_training()
    _check("Free Training clears the tutorial gate",
        not bool(player_a.tutorial_default_uniques), "")
    _check("Free Training uses the saved (default) style list",
        player_a.active_uniques() == _default_expected(), str(player_a.active_uniques()))
    # -------------------------------------------- write the explicit style file
    _check("saved style file written", _write_saved_style(), "")
    # A saved style can only exist for a granted entry: grader the recovered
    # story-EXP row that unlocks Brick's special moves (ids <= 9600), exactly
    # like a profile that reached that threshold.
    var granted: Array = scene_a.get("progress").sync_story_exp(9600)
    _check("style unlock grant includes Brick hkick 23 and grab 57",
        granted.has(23) and granted.has(57), str(granted))
    scene_a.queue_free()
    await process_frame
    # ------------------------------------------------------- scene B: VS wiring
    var scene_b: Node = _boot(args[0], args[1])
    await process_frame
    await process_frame
    var player_b = scene_b.get("player")
    _freeze(scene_b)
    var store_b = scene_b.get("style_store")
    _check("VS boot loads the saved style file",
        store_b != null and bool(store_b.file_found) and bool(store_b.loaded_ok),
        "%s / %s" % [store_b.last_error if store_b != null else "no store",
            store_b.save_path if store_b != null else ""])
    _check_saved_gate(player_b, "VS-saved")
    _check("VS match start applied the saved style",
        bool(scene_b.get("player_style_report").get("uniques", []) == EXPECTED_SAVED)
        or player_b.active_uniques() == EXPECTED_SAVED,
        str(scene_b.get("player_style_report")))
    # The VS match path really selects the selected Brick grab row.
    scene_b._reset_match()
    player_b._clear_link_state()
    player_b.state = "idle"
    player_b.state_time = 0.0
    player_b.attack_kind = ""
    player_b.rage = 70.0
    player_b.position = Vector3(0.0, 1.2, 0.0)
    scene_b.get("computer").position = Vector3(0.3, 1.2, 0.0)
    player_b.opponent = scene_b.get("computer")
    player_b.facing = 1.0
    player_b.set_held_directions({"up": true})
    player_b.record_standing_combo_press("a")
    _check("VS saved style starts the selected grab1miss brick row",
        player_b.attack_kind == "grab1miss brick", player_b.attack_kind)
    # ------------------------------------------------- tutorial again (scene B)
    var training_b = scene_b.get("move_training")
    if not _start_lesson(training_b, "specialkickhigh"):
        push_error("no lesson in scene B")
        quit(1)
        return
    _check("tutorial in a saved-style match falls back to the 8 default IDs",
        bool(player_b.tutorial_default_uniques)
        and player_b.active_uniques() == _default_expected(),
        str(player_b.active_uniques()))
    training_b.close()
    _check("leaving training restores the saved style list",
        not bool(player_b.tutorial_default_uniques)
        and player_b.active_uniques() == EXPECTED_SAVED,
        str(player_b.active_uniques()))
    # ------------------------------------------------ Free Training (scene B)
    training_b.enter_free_training()
    _check("Free Training keeps the saved style list",
        not bool(player_b.tutorial_default_uniques)
        and player_b.active_uniques() == EXPECTED_SAVED,
        str(player_b.active_uniques()))
    print("NATIVE_UNIQUES_VALIDATION=" + JSON.stringify({
        "checks": _checks,
        "failures": _failures,
        "default_uniques": _default_expected(),
        "saved_uniques": EXPECTED_SAVED,
        "source": "characters.list uniques + styleeditor_runtime unique IDs",
    }))
    scene_b.queue_free()
    await process_frame
    quit(0 if _failures.is_empty() else 1)

extends SceneTree
## End-to-end check of the replayed Style Editor on the real main.tscn (headless).
##
##   godot --headless --path godot --script res://tests/validate_style_editor_runtime.gd \
##         -- <player.glb> <player_texture_root>
##
## Unlike validate_style_editor.gd (which unit-tests the catalog, the store, the
## screen and a synthetic AnimationPlayer), this test goes through main.gd's own
## hooks: BRUCELEE_STYLE_EDITOR=1 must create the screen/store/catalog in _ready,
## _apply_style_editor() must push the saved selections into the real
## PortFighter, and the clip the game actually starts must be the mapped clip.
##
## The real candidate GLB is required: with BRUCELEE_PLAYER_GLB empty main.gd
## builds placeholder visuals only and no animation library exists at all, so
## there is nothing for a style to apply to (that path is covered by
## validate_style_editor.gd with a fake AnimationPlayer). The two paths come
## from the command line, or from CAPTURE_PLAYER_GLB / CAPTURE_TEXTURE_ROOT.

const TEST_SAVE := "user://style_selections_runtime_test.json"

var failures: Array = []
var checks: int = 0



func _initialize() -> void:
    call_deferred("_run")


func check(ok: bool, label: String, detail: String = "") -> void:
    checks += 1
    if ok:
        print("CHECK PASS %s" % label)
        return
    failures.append(label + (" | " + detail if not detail.is_empty() else ""))
    print("CHECK FAIL %s %s" % [label, detail])


func _wait_candidates(scene: Node, timeout_frames: int = 1200) -> bool:
    ## main.gd builds the fighters first and the candidate GLB/library lands a
    ## few frames later (fighter._build_candidate sets candidate_loaded). The
    ## style hook is a no-op until then, exactly like a real boot, so the test
    ## waits for the same condition the game itself reports.
    var player: PortFighter = scene.get("player")
    for _i in range(timeout_frames):
        if player != null and player.candidate_loaded:
            return true
        await physics_frame
    return player != null and player.candidate_loaded


func _run() -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    var args: PackedStringArray = OS.get_cmdline_user_args()
    var player_glb: String = String(args[0]) if args.size() > 0 else OS.get_environment("CAPTURE_PLAYER_GLB")
    var player_tex: String = String(args[1]) if args.size() > 1 else OS.get_environment("CAPTURE_TEXTURE_ROOT")
    if player_glb.is_empty() or not FileAccess.file_exists(player_glb):
        print("STYLE_EDITOR_RUNTIME SKIP: no candidate GLB (%s)" % player_glb)
        quit(2)
        return
    OS.set_environment("BRUCELEE_PLAYER_GLB", player_glb)
    OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", player_tex)
    OS.set_environment("BRUCELEE_STYLE_EDITOR", "1")
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PROGRESS", "")

    var packed: PackedScene = load("res://scenes/main.tscn")
    check(packed != null, "main.tscn loads")
    if packed == null:
        quit(1)
        return
    var scene: Node = packed.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame
    var candidates_ready: bool = await _wait_candidates(scene)
    check(candidates_ready, "the candidate library finishes loading")
    scene.set_physics_process(false)

    var player: PortFighter = scene.get("player")
    check(player != null, "the real match created the player fighter")
    var catalog = scene.get("style_catalog")
    check(catalog != null, "BRUCELEE_STYLE_EDITOR=1 creates the catalog in main._ready")
    var store = scene.get("style_store")
    check(store != null, "BRUCELEE_STYLE_EDITOR=1 creates the selection store")
    var editor = scene.get("style_editor")
    check(editor != null, "BRUCELEE_STYLE_EDITOR=1 adds the editor layer")
    if player == null or catalog == null or store == null or editor == null:
        scene.queue_free()
        await process_frame
        _finish()
        return

    var snapshot: Dictionary = player.style_runtime_snapshot()
    check(bool(snapshot.get("loaded", false)), "the fighter has a loaded candidate library")
    var animations: Dictionary = snapshot.get("animations", {})
    check(animations.size() > 0, "the candidate library exposes clip names")

    # Deterministic selection state: the decoded defaults, in the test file.
    store.configure(TEST_SAVE)
    store.load_selections(catalog)
    check((store.selections as Dictionary).size() == 8, "the store covers 8 decoded groups")

    # The hook main.gd calls from _reset_match().
    scene.call("_apply_style_editor")
    var report: Dictionary = editor.apply_report()
    check(bool(report.get("animations_loaded", false)), "the apply report saw the loaded library")
    var applied: Array = report.get("applied", [])
    check(applied.size() == 7, "seven decoded defaults applied to the real fighter",
          "applied=%s" % [str(applied)])
    var results: Dictionary = report.get("results", {})
    check(
        String(results.get("personality/personality", {}).get("status", "")) == "no_combat_slot",
        "personality reports no_combat_slot on the real fighter"
    )

    # Every applied group must own its slot, and the slot must hold the mapped clip.
    var slots: Dictionary = player.style_runtime_snapshot().get("slots", {})
    var mismatches: Array = []
    for group_key in applied:
        var result: Dictionary = results.get(group_key, {})
        var slot: String = String(result.get("slot", ""))
        var clip: String = String(result.get("clip", ""))
        var entry: Dictionary = catalog.entry(String(group_key), String(store.selections.get(group_key, "")))
        if slot.is_empty() or String(slots.get(slot, "")) != clip:
            mismatches.append("%s slot=%s have=%s want=%s" % [
                group_key, slot, String(slots.get(slot, "")), clip
            ])
        elif String(entry.get("clip", "")) != clip:
            mismatches.append("%s catalog clip=%s applied=%s" % [
                group_key, String(entry.get("clip", "")), clip
            ])
    check(mismatches.is_empty(), "each applied slot holds exactly the decoded clip",
          " ; ".join(PackedStringArray(mismatches)))

    # The clip table used by the attack state machine follows the same swap.
    var attack_mismatch: Array = []
    for group_key in applied:
        var result: Dictionary = results.get(group_key, {})
        var slot: String = String(result.get("slot", ""))
        if player.ATTACKS.has(slot) and typeof(player.ATTACKS[slot]) == TYPE_DICTIONARY:
            var animation: String = String(player.ATTACKS[slot].get("animation", ""))
            if animation != String(result.get("clip", "")):
                attack_mismatch.append("%s ATTACKS.animation=%s" % [slot, animation])
    check(attack_mismatch.is_empty(), "the live ATTACKS entry follows the applied clip",
          " ; ".join(PackedStringArray(attack_mismatch)))

    # The game must actually start the mapped clip when the attack is requested.
    player._enter_locomotion_state("idle")
    var started: bool = player.request_attack("special_punch_low_hit")
    check(started, "the game starts the recovered special_punch_low_hit animation")
    if started:
        await process_frame
        var animation_player: AnimationPlayer = player.get("_candidate_animation")
        var expected: String = String(player._candidate_clip_paths.get("special_punch_low_hit", ""))
        check(animation_player != null, "the fighter has a candidate AnimationPlayer")
        if animation_player != null:
            check(String(animation_player.current_animation) == expected,
                  "the played animation is the mapped clip (%s)" % expected,
                  "current=%s" % String(animation_player.current_animation))

    # Fail closed, still on the real fighter: a foreign clip that is not loaded
    # must be reported and must not change the slot.
    store.set_selection(catalog, "special/lkick", "lkickshenlo")
    scene.call("_apply_style_editor")
    report = editor.apply_report()
    var locked_found: bool = false
    for item: Variant in Array(report.get("locked_selections", [])):
        if item is Dictionary:
            var dropped: Dictionary = item
            if String(dropped.get("group", "")) == "special/lkick" and String(dropped.get("entry", "")) == "lkickshenlo" and String(dropped.get("reason", "")) == "locked_or_unavailable":
                locked_found = true
    check(locked_found, "the locked foreign style is recorded as dropped")
    check(not player.active_uniques().has("lkickshenlo"),
          "the locked foreign style is absent from active uniques")
    slots = player.style_runtime_snapshot().get("slots", {})
    check(String(slots.get("special_kick_low_hit", "")) == "m01_sp_kick_low",
          "the refused foreign clip leaves special_kick_low_hit untouched",
          "have=%s" % String(slots.get("special_kick_low_hit", "")))

    # A size-variant slot keeps its own clip.
    store.set_selection(catalog, "special/hpunch", "hpunchshenlo")
    scene.call("_apply_style_editor")
    report = editor.apply_report()
    check(
        String(report.get("results", {}).get("special/hpunch", {}).get("status", "")) == "size_variant_refused",
        "a size-variant slot refuses a different clip on the real fighter"
    )
    slots = player.style_runtime_snapshot().get("slots", {})
    check(String(slots.get("special_punch_high_hit", "")) == "m01_sp_pnch_high",
          "the refused size-variant slot keeps its clip",
          "have=%s" % String(slots.get("special_punch_high_hit", "")))

    # Re-applying from the base snapshot must not stack swaps.
    store.reset(catalog)
    scene.call("_apply_style_editor")
    report = editor.apply_report()
    check((report.get("applied", []) as Array).size() == 7,
          "resetting and re-applying restores the seven identity defaults")

    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    scene.queue_free()
    await process_frame
    _finish()


func _finish() -> void:
    print("STYLE EDITOR RUNTIME: %d checks, %d failed" % [checks, failures.size()])
    for failure in failures:
        print("FAILED: " + String(failure))
    quit(0 if failures.is_empty() else 1)

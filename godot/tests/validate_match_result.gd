extends SceneTree
## Validates the ported native match-result sequence on the real main.tscn.

const ROUND_WAIT: float = 3.0
const STATE_TIME_UP: int = 5
const STATE_KO_WIN: int = 7
const STATE_ROUND_END: int = 15
const STATE_MATCH_WIN: int = 12
const STATE_MATCH_LOSE: int = 13
var shots: String = ""
var results: Dictionary = {}


func _initialize() -> void:
    call_deferred("_run")


func _capture(name: String) -> void:
    if DisplayServer.get_name() == "headless":
        print("SHOT_SKIPPED_HEADLESS %s" % name)
        return
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    var path: String = shots.path_join(name)
    var err: int = image.save_png(path)
    print("SHOT %s %dx%d err=%d" % [name, image.get_width(), image.get_height(), err])
    if err != OK:
        # The staged Godot build may run with a write-restricted token; emit the
        # PNG as base64 so the harness can recover the exact frame.
        print("SHOTB64 %s %s" % [name, Marshalls.raw_to_base64(image.save_png_to_buffer())])


func _new_scene(
        bruce: String,
        brick: String,
        round_time: int,
        text_root: String,
        attack_config: String = "res://data/fighting_set_m03_mapped_attacks.json"
) -> Node:
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_TIME", str(round_time))
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", bruce)
    OS.set_environment("BRUCELEE_OPPONENT_GLB", brick)
    OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", attack_config)
    OS.set_environment("BRUCELEE_GAME_TEXT_ROOT", text_root)
    OS.set_environment("BRUCELEE_GAME_TEXT_FLIP", "1")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    return scene


func _wait_candidates(scene: Node, timeout_frames: int = 900) -> bool:
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    for _i: int in range(timeout_frames):
        if player.candidate_loaded and computer.candidate_loaded:
            return true
        await physics_frame
    return player.candidate_loaded and computer.candidate_loaded


func _freeze(scene: Node) -> void:
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)


func _tick(scene: Node, seconds: float, step: float = 0.05) -> void:
    var remaining: float = seconds
    while remaining > 0.0:
        var dt: float = minf(remaining, step)
        scene._physics_process(dt)
        remaining -= dt


func _tick_until(scene: Node, target_state: int, max_seconds: float = 9.0) -> bool:
    var elapsed: float = 0.0
    var step: float = 0.02
    while elapsed < max_seconds:
        if _state(scene) == target_state:
            return true
        scene._physics_process(step)
        elapsed += step
    return _state(scene) == target_state


func _real_punch_ko(scene: Node, attacker: PortFighter, defender: PortFighter) -> bool:
    if attacker == scene.get("player"):
        attacker.reset_fighter(Vector3(0.0, 1.20, 0.0))
        defender.reset_fighter(Vector3(0.6, 1.20, 0.0))
    else:
        defender.reset_fighter(Vector3(0.0, 1.20, 0.0))
        attacker.reset_fighter(Vector3(0.6, 1.20, 0.0))
    defender.health = 1.0
    # reset_fighter does not touch facing, and the AI-side fighter may still be
    # facing the wrong way. Turn the attacker toward the defender before the
    # real punch so the contact test is not skipped by the facing gate.
    attacker.facing = (
        1.0 if defender.global_position.x >= attacker.global_position.x else -1.0
    )
    if not attacker.request_attack("punch"):
        push_error("request_attack(punch) failed")
        return false
    attacker._physics_process(float(attacker.ATTACKS["punch"]["startup"]) + 0.01)
    if defender.health > 0.0:
        return false
    # A lethal "hard" hit enters the recovered impact clip before the fighter
    # reports KO; drive the defender's own physics until combat_ko fires.  The
    # punch is still the only source of the damage.
    for _i: int in range(150):
        if _state(scene) != 4:
            break
        defender._physics_process(1.0 / 60.0)
    return _state(scene) != 4


func _state(scene: Node) -> int:
    var value: Variant = scene.get("match_state")
    if typeof(value) == TYPE_INT:
        return value
    return -1


func _check_texture(scene: Node, gametext_root: String) -> Dictionary:
    var overlay: Sprite2D = scene.get("_game_text_rect")
    var textures: Dictionary = scene.get("_game_text_textures")
    var wanted: Array[String] = ["READY", "FIGHT", "YOU_WIN", "YOU_LOSE", "TIME_IS_UP"]
    var loaded: Array[String] = []
    for key: String in wanted:
        if textures.has(key):
            loaded.append(key)
    var flip_h: bool = overlay != null and overlay.flip_h
    var flip_v: bool = overlay != null and overlay.flip_v
    var matches_source: bool = false
    if textures.has("YOU_WIN"):
        var file_path: String = gametext_root.path_join("BL_gameText-YOU_WIN.png")
        var source: Image = Image.new()
        if source.load(file_path) == OK:
            var loaded_image: Image = (textures["YOU_WIN"] as Texture2D).get_image()
            matches_source = (
                loaded_image.get_width() == source.get_width()
                and loaded_image.get_height() == source.get_height()
                and loaded_image.get_data() == source.get_data()
            )
    return {
        "loaded": loaded,
        "flip_h": flip_h,
        "flip_v": flip_v,
        "matches_unmirrored_source": matches_source,
    }


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 4:
        push_error("Expected <bruce.glb> <brick.glb> <screenshot_dir> <gametext_root>")
        quit(2)
        return
    var bruce: String = args[0]
    var brick: String = args[1]
    shots = args[2].replace("\\", "/")
    var gametext_root: String = args[3].replace("\\", "/")
    DirAccess.make_dir_recursive_absolute(shots)
    var failures: Array[String] = []

    # ---- Scenario A: player wins the match by a real KO ----
    var scene: Node = _new_scene(bruce, brick, 60, gametext_root)
    if not await _wait_candidates(scene):
        push_error("KO-win candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    scene._reset_match()
    results["text"] = _check_texture(scene, gametext_root)
    if bool(results["text"].get("flip_h", true)) or not bool(results["text"].get("flip_v", false)):
        failures.append("game text flip is not the verified flip_v-only orientation")
    await _capture("01_round_start.png")
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    results["intro_state"] = _state(scene)

    if not _real_punch_ko(scene, player, computer):
        failures.append("round1 real punch did not KO the computer")
    results["ko_win_round_state"] = _state(scene)
    results["ko_win_round_score"] = [scene.player_rounds, scene.computer_rounds]
    results["ko_win_round_player_clip"] = player.candidate_animation_clip
    results["ko_win_round_computer_clip"] = computer.candidate_animation_clip
    if _state(scene) != STATE_KO_WIN:
        failures.append("state 4 KO did not enter state 7")
    await _capture("02_ko_win_text.png")

    if not _tick_until(scene, STATE_ROUND_END):
        failures.append("state 7 did not reach state 15 after 3000 ms")
    _tick(scene, 0.1)
    if scene.round_number != 2:
        failures.append("state 15 did not start round 2")
    results["round2"] = scene.round_number
    if not _tick_until(scene, 4):
        failures.append("round 2 intro did not reach the fight state")

    if not _real_punch_ko(scene, player, computer):
        failures.append("round2 real punch did not KO the computer")
    results["ko_win_match_round_state"] = _state(scene)
    results["ko_win_match_score"] = [scene.player_rounds, scene.computer_rounds]
    await _capture("03_ko_win_match_text.png")

    if not _tick_until(scene, STATE_MATCH_WIN):
        failures.append("winning KO did not enter state 12")
    results["ko_win_pose_state"] = _state(scene)
    results["ko_win_pose_visible"] = [player.visible, computer.visible]
    results["ko_win_player_clip"] = player.candidate_animation_clip
    results["ko_win_computer_clip"] = computer.candidate_animation_clip
    results["ko_win_player_victory"] = player.has_result_clip("victory")
    results["ko_win_computer_defeat"] = computer.has_result_clip("defeat")
    if _state(scene) != STATE_MATCH_WIN:
        failures.append("winning KO did not reach state 12")
    if player.visible == computer.visible:
        failures.append("state 12 did not hide exactly one fighter")
    if not player.result_clip.is_empty():
        player._candidate_animation.seek(
            maxf(player.result_clip_duration() * 0.35, 0.0), true
        )
    await _capture("04_ko_win_victory_pose.png")

    if not _tick_until(scene, STATE_ROUND_END):
        failures.append("state 12 did not reach state 15 after the victory clip")
    _tick(scene, 0.1)
    results["ko_win_match_over"] = scene.match_over
    results["ko_win_final_state"] = _state(scene)
    await _capture("05_ko_win_match_over.png")
    if not scene.match_over:
        failures.append("state 15 did not close the match")

    # ---- Reset path (R key handler -> _reset_match) ----
    var restart := InputEventKey.new()
    restart.keycode = KEY_R
    restart.physical_keycode = KEY_R
    restart.pressed = true
    scene._unhandled_input(restart)
    await process_frame
    results["reset_round"] = scene.round_number
    results["reset_score"] = [scene.player_rounds, scene.computer_rounds]
    results["reset_health"] = [player.health, computer.health]
    results["reset_states"] = [player.state, computer.state]
    results["reset_visible"] = [player.visible, computer.visible]
    results["reset_match_over"] = scene.match_over
    results["reset_done"] = scene.done
    results["reset_phase"] = _state(scene)
    await _capture("06_reset_after_win.png")
    if (scene.round_number != 1 or scene.player_rounds != 0
            or scene.computer_rounds != 0 or scene.match_over or scene.done
            or player.health != PortFighter.MAX_HEALTH
            or computer.health != PortFighter.MAX_HEALTH
            or not player.visible or not computer.visible):
        failures.append("reset did not restore round 1 / score / health / visibility")
    scene.queue_free()
    await process_frame

    # ---- Scenario B: computer wins the match by a real KO ----
    scene = _new_scene(bruce, brick, 60, gametext_root)
    if not await _wait_candidates(scene):
        push_error("KO-loss candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    scene._reset_match()
    player = scene.get("player")
    computer = scene.get("computer")
    for round_index: int in range(2):
        if not _real_punch_ko(scene, computer, player):
            failures.append(
                "computer real punch did not KO the player (round %d)" % (round_index + 1)
            )
            break
        results["ko_loss_round%d_state" % (round_index + 1)] = _state(scene)
        if round_index == 0:
            if not _tick_until(scene, STATE_ROUND_END):
                failures.append("losing KO did not enter state 8 then 15")
            _tick(scene, 0.1)
            if not _tick_until(scene, 4):
                failures.append("KO-loss round 2 intro did not reach the fight state")
        else:
            if not _tick_until(scene, STATE_MATCH_LOSE):
                failures.append("losing KO did not enter state 13")
    results["ko_loss_pose_state"] = _state(scene)
    results["ko_loss_visible"] = [player.visible, computer.visible]
    results["ko_loss_player_clip"] = player.candidate_animation_clip
    results["ko_loss_computer_clip"] = computer.candidate_animation_clip
    results["ko_loss_player_defeat"] = player.has_result_clip("defeat")
    results["ko_loss_computer_victory"] = computer.has_result_clip("victory")
    if _state(scene) != STATE_MATCH_LOSE:
        failures.append("losing KO did not enter state 13")
    if not computer.result_clip.is_empty():
        computer._candidate_animation.seek(
            maxf(computer.result_clip_duration() * 0.35, 0.0), true
        )
    await _capture("07_ko_loss_victory_pose.png")
    scene.queue_free()
    await process_frame

    # ---- Scenario C: time up decides two rounds (state 5) ----
    scene = _new_scene(bruce, brick, 3, gametext_root)
    if not await _wait_candidates(scene):
        push_error("Time-up candidates did not load")
        quit(1)
        return
    await process_frame
    _freeze(scene)
    scene._reset_match()
    player = scene.get("player")
    computer = scene.get("computer")
    player.health = 70.0
    computer.health = 40.0
    if not _tick_until(scene, STATE_TIME_UP):
        failures.append("timer 0 did not enter state 5")
    results["time_up_round1_state"] = _state(scene)
    results["time_up_overlay_visible"] = (
        scene._game_text_rect != null and scene._game_text_rect.visible
    )
    results["time_up_uses_texture"] = (
        scene._game_text_rect != null
        and scene._game_text_textures.has("TIME_IS_UP")
        and scene._game_text_rect.texture == scene._game_text_textures["TIME_IS_UP"]
    )
    await _capture("08_time_up.png")
    if not _tick_until(scene, STATE_KO_WIN):
        failures.append("state 5 did not decide the time-up winner")
    results["time_up_round1_winner_state"] = _state(scene)
    results["time_up_round1_score"] = [scene.player_rounds, scene.computer_rounds]
    await _capture("09_time_up_win_text.png")
    if not _tick_until(scene, STATE_ROUND_END):
        failures.append("time-up round 1 did not reach state 15")
    _tick(scene, 0.1)
    if not _tick_until(scene, 4):
        failures.append("time-up round 2 intro did not reach the fight state")
    results["time_up_round2"] = scene.round_number
    player.health = 80.0
    computer.health = 10.0
    if not _tick_until(scene, STATE_TIME_UP):
        failures.append("round 2 timer 0 did not enter state 5")
    if not _tick_until(scene, STATE_KO_WIN):
        failures.append("round 2 time up did not decide the winner")
    if not _tick_until(scene, STATE_MATCH_WIN):
        failures.append("second time up did not reach state 12")
    results["time_up_match_state"] = _state(scene)
    results["time_up_match_score"] = [scene.player_rounds, scene.computer_rounds]
    if _state(scene) != STATE_MATCH_WIN:
        failures.append("second time up did not reach state 12")
    if not player.result_clip.is_empty():
        player._candidate_animation.seek(
            maxf(player.result_clip_duration() * 0.35, 0.0), true
        )
    await _capture("10_time_up_victory_pose.png")
    if not _tick_until(scene, STATE_ROUND_END):
        failures.append("time-up victory pose did not reach state 15")
    _tick(scene, 0.1)
    results["time_up_match_over"] = scene.match_over
    await _capture("11_time_up_match_over.png")
    scene.queue_free()
    await process_frame

    # ---- Scenario D: Master76 has no result clip (documented gap) ----
    var master_path: String = OS.get_environment("BRUCELEE_MASTER_GLB")
    results["master76_path"] = master_path
    results["master76_exists"] = (
        not master_path.is_empty() and FileAccess.file_exists(master_path)
    )
    if not master_path.is_empty() and FileAccess.file_exists(master_path):
        scene = _new_scene(
            bruce, master_path, 60, gametext_root,
            "res://data/attack_config_master.json"
        )
        computer = scene.get("computer")
        var master_ready: bool = await _wait_candidates(scene)
        results["master76_candidates_loaded"] = master_ready
        results["master76_load_error"] = computer.candidate_load_error
        if master_ready:
            await process_frame
            _freeze(scene)
            scene._reset_match()
            results["master76_victory_clip"] = computer.has_result_clip("victory")
            results["master76_defeat_clip"] = computer.has_result_clip("defeat")
            results["master76_result_clip_names"] = computer.result_clip_names("victory")
        scene.queue_free()
        await process_frame

    # ---- Scenario E: KO at full health using only real punches ----
    # No health is injected here: the defender starts at 100 HP and the loop
    # lands repeated real punch contacts until combat_ko reports the knockout.
    scene = _new_scene(bruce, brick, 60, gametext_root)
    if await _wait_candidates(scene):
        await process_frame
        _freeze(scene)
        scene._reset_match()
        player = scene.get("player")
        computer = scene.get("computer")
        player.reset_fighter(Vector3(0.0, 1.20, 0.0))
        computer.reset_fighter(Vector3(0.6, 1.20, 0.0))
        var hits: int = 0
        for _guard: int in range(40):
            if computer.health <= 0.0:
                break
            player.facing = 1.0
            if not player.request_attack("punch"):
                player._physics_process(0.1)
                continue
            player._physics_process(float(player.ATTACKS["punch"]["startup"]) + 0.01)
            player._physics_process(2.4)
            hits += 1
        results["full_health_ko"] = computer.health <= 0.0
        results["full_health_ko_hits"] = hits
        results["full_health_ko_state"] = _state(scene)
        results["full_health_ko_score"] = [scene.player_rounds, scene.computer_rounds]
        results["full_health_ko_no_health_injection"] = true
        if computer.health > 0.0 or _state(scene) != STATE_KO_WIN or scene.player_rounds != 1:
            failures.append("full-health real-punch KO did not reach state 7 with a round win")
        scene.queue_free()
        await process_frame
    else:
        failures.append("full-health KO candidates did not load")

    results["failures"] = failures
    print("MATCH_RESULT_VALIDATION=" + JSON.stringify(results))
    quit(0 if failures.is_empty() else 1)

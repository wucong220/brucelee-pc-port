extends SceneTree
## Round-flow regression for the ported CBeatEmUpGame state machine.
## A round knockout is produced by a real punch, then the test walks the
## native result phases (7/8 -> 15 -> intro 3 -> fight 4 -> 12/13 -> 15).
##
## The driver advances the REAL play clocks: every simulated frame steps the
## scene, the player and the computer by 1/60 s, exactly as the engine does in
## gameplay. An earlier revision stepped only the defender with the scene clock
## disabled, so the KO result phases never advanced; that was a stale harness
## expectation, not a gameplay defect. The round2 probe measured the real play
## path at 4->7 @ frame 331, 7->15 @ 512 and player_rounds=1.

const STATE_KO_WIN: int = 7
const STATE_KO_LOSE: int = 8
const STATE_ROUND_END: int = 15
const STATE_FIGHT: int = 4
const FRAME: float = 1.0 / 60.0
var results: Dictionary = {}
var failures: Array[String] = []
var _trace: Array[int] = []
var _trace_last: int = -1
var _round1_path: Array[int] = []
var _round1_rounds: int = -1


func _initialize() -> void:
    call_deferred("_run")


func _state(scene: Node) -> int:
    var value: Variant = scene.get("match_state")
    return value if typeof(value) == TYPE_INT else -1


## One real physics frame of gameplay: scene + player + computer, all at dt.
func _step_frame(scene: Node, dt: float) -> void:
    scene._physics_process(dt)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    if player != null:
        player._physics_process(dt)
    if computer != null:
        computer._physics_process(dt)
    _note_state(scene)


## Record the match-state path so the 4 -> 7 -> 15 sequence is proven directly.
func _note_state(scene: Node) -> void:
    var st: int = _state(scene)
    if st != _trace_last:
        _trace.append(st)
        _trace_last = st


func _tick(scene: Node, seconds: float, step: float = 1.0 / 60.0) -> void:
    var remaining: float = seconds
    while remaining > 0.0:
        var dt: float = minf(remaining, step)
        _step_frame(scene, dt)
        remaining -= dt


func _tick_until(scene: Node, target: int, max_seconds: float = 9.0) -> bool:
    var elapsed: float = 0.0
    while elapsed < max_seconds:
        if _state(scene) == target:
            return true
        _step_frame(scene, FRAME)
        elapsed += FRAME
    return _state(scene) == target


func _real_ko(scene: Node, attacker: PortFighter, defender: PortFighter) -> bool:
    if attacker == scene.get("player"):
        attacker.reset_fighter(Vector3(0.0, 1.20, 0.0))
        defender.reset_fighter(Vector3(0.6, 1.20, 0.0))
    else:
        defender.reset_fighter(Vector3(0.0, 1.20, 0.0))
        attacker.reset_fighter(Vector3(0.6, 1.20, 0.0))
    defender.health = 1.0
    attacker.facing = (
        1.0 if defender.global_position.x >= attacker.global_position.x else -1.0
    )
    if not attacker.request_attack("punch"):
        return false
    # Land the punch on the attacker's own clock.
    attacker._physics_process(float(attacker.ATTACKS["punch"]["startup"]) + 0.01)
    if defender.health > 0.0:
        return false
    # Then advance the real play clocks (scene + player + computer) until the
    # KO result phase is entered; stepping only the defender never leaves 4.
    var target: int = (
        STATE_KO_WIN if attacker == scene.get("player") else STATE_KO_LOSE
    )
    return _tick_until(scene, target, 12.0)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and Brick candidate GLB paths")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)
    if not player.candidate_loaded or not computer.candidate_loaded:
        push_error("Candidates did not load")
        quit(1)
        return
    scene._reset_match()
    _trace_last = -1
    _note_state(scene)
    var hud: PortHUD = scene.get("hud")
    var round_parent: Node = hud.round_label.get_parent()
    var round_in_row: bool = (
        round_parent is HBoxContainer or round_parent is VBoxContainer
    )
    if (not round_in_row or hud.round_label.text != "ROUND 1  ·  0 — 0"):
        failures.append("Round label is not embedded in the top HUD row")
    if (scene.round_number != 1 or scene.player_rounds != 0
            or scene.computer_rounds != 0 or scene.match_over):
        failures.append("Initial round state is wrong")

    # Round 1: real player knockout.
    if not _real_ko(scene, player, computer):
        failures.append("Round 1 real KO failed")
    if (scene.player_rounds != 1 or scene.round_number != 1
            or not scene.done or _state(scene) != STATE_KO_WIN):
        failures.append("First player knockout did not score / enter state 7")
    _round1_rounds = scene.player_rounds
    scene._on_ko(computer)
    if scene.player_rounds != 1:
        failures.append("Duplicate KO signal scored the round twice")
    player.move_axis = Vector2(1.0, 0.0)
    computer.move_axis = Vector2(-1.0, 0.0)
    scene._physics_process(0.1)
    if player.move_axis != Vector2.ZERO or computer.move_axis != Vector2.ZERO:
        failures.append("Result phase did not clear fighter movement")

    if not _tick_until(scene, STATE_ROUND_END):
        failures.append("State 7 did not reach state 15")
    _tick(scene, 0.1)
    # Prove the real play path 4 -> 7 -> 15 and the single round point.
    _round1_path = _trace.slice(0, 3)
    if (_round1_path.size() < 3
            or int(_round1_path[0]) != STATE_FIGHT
            or int(_round1_path[1]) != STATE_KO_WIN
            or int(_round1_path[2]) != STATE_ROUND_END):
        failures.append("Round 1 did not follow 4->7->15 (saw %s)" % str(_trace))
    if _round1_rounds != 1:
        failures.append("Round 1 player_rounds was %d, expected 1" % _round1_rounds)
    if not _tick_until(scene, STATE_FIGHT):
        failures.append("Round 2 intro did not reach the fight state")
    if (scene.round_number != 2 or scene.player_rounds != 1
            or scene.computer_rounds != 0 or scene.done or scene.match_over):
        failures.append("Next round did not start with score preserved")
    if (player.health != PortFighter.MAX_HEALTH
            or computer.health != PortFighter.MAX_HEALTH):
        failures.append("Next round did not restore health")

    # Round 2: real player knockout closes the match.
    if not _real_ko(scene, player, computer):
        failures.append("Round 2 real KO failed")
    if scene.player_rounds != 2 or _state(scene) != STATE_KO_WIN:
        failures.append("Second KO did not score")
    if not _tick_until(scene, STATE_ROUND_END):
        failures.append("Winning KO did not reach state 15")
    _tick(scene, 0.1)
    if not scene.match_over:
        failures.append("Best-of-three player match did not close")

    scene._reset_match()
    if (scene.round_number != 1 or scene.player_rounds != 0
            or scene.computer_rounds != 0 or scene.match_over or scene.done):
        failures.append("Match reset did not clear scores")

    # Computer match: two real punches.
    for round_index: int in range(2):
        if not _real_ko(scene, computer, player):
            failures.append("Computer real KO failed (round %d)" % (round_index + 1))
            break
        if _state(scene) != STATE_KO_LOSE:
            failures.append("Computer KO did not enter state 8")
        if round_index == 0:
            if not _tick_until(scene, STATE_ROUND_END):
                failures.append("State 8 did not reach state 15")
            _tick(scene, 0.1)
            if not _tick_until(scene, STATE_FIGHT):
                failures.append("KO-loss round 2 intro did not reach the fight state")
    if not _tick_until(scene, STATE_ROUND_END):
        failures.append("Losing KO did not reach state 15")
    _tick(scene, 0.1)
    if scene.computer_rounds != 2 or not scene.match_over:
        failures.append("Best-of-three computer match did not close")

    results["failures"] = failures
    results["rounds_to_win"] = scene.ROUNDS_TO_WIN
    results["player_rounds"] = scene.player_rounds
    results["computer_rounds"] = scene.computer_rounds
    results["round"] = scene.round_number
    results["match_state"] = _state(scene)
    results["round1_state_path"] = _round1_path
    results["player_rounds_after_round1"] = _round1_rounds
    print("ROUND_FLOW_VALIDATION=" + JSON.stringify(results))
    scene.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)

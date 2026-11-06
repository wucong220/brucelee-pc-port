extends SceneTree
## Multi-round combat-state regression. Every knockout is produced by a real
## punch through the fighter's own attack/contact path.
##
## The driver advances the REAL play clocks: every simulated frame steps the
## scene, the player and the computer by 1/60 s, exactly as the engine does in
## gameplay. An earlier revision stepped only the defender with the scene clock
## disabled, so no round ever left the fight state; that was a stale harness
## expectation, not a gameplay defect.

const STATE_FIGHT: int = 4
const STATE_KO_WIN: int = 7
const STATE_KO_LOSE: int = 8
const STATE_ROUND_END: int = 15
const FRAME: float = 1.0 / 60.0
var failures: Array[String] = []
var _trace: Array[int] = []
var _trace_last: int = -1
var _round1_path: Array[int] = []
var _round1_rounds: int = -1
var _round2_snapshot: Dictionary = {}
var _capture_round2: bool = false


func _initialize() -> void:
    call_deferred("_run")


func _state(scene: Node) -> int:
    var value: Variant = scene.get("match_state")
    return value if typeof(value) == TYPE_INT else -1


## One real physics frame of gameplay: scene + player + computer, all at dt.
func _step_frame(scene: Node, dt: float) -> void:
    scene._physics_process(dt)
    # Capture the round-2 reset exactly when the scene enters the new fight,
    # before the live AI gets a frame; otherwise the AI's first step (idle ->
    # stepback/attack) is mistaken for a retained combat state.
    if (_capture_round2 and _round2_snapshot.is_empty()
            and scene.round_number == 2 and _state(scene) == STATE_FIGHT):
        var p: PortFighter = scene.get("player")
        var c: PortFighter = scene.get("computer")
        _round2_snapshot = {
            "player_state": p.state,
            "computer_state": c.state,
            "player_health": p.health,
            "computer_health": c.health,
            "player_clip": p.candidate_animation_clip,
            "computer_clip": c.candidate_animation_clip,
            "player_reaction": p.last_reaction_animation,
            "computer_reaction": c.last_reaction_animation,
        }
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    if player != null:
        player._physics_process(dt)
    if computer != null:
        computer._physics_process(dt)
    _note_state(scene)


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
    attacker._physics_process(float(attacker.ATTACKS["punch"]["startup"]) + 0.01)
    if defender.health > 0.0:
        return false
    # Advance the real play clocks until the KO result phase is entered.
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
    scene._reset_match()
    _trace_last = -1
    _note_state(scene)

    if not _real_ko(scene, player, computer):
        failures.append("Round 1 real KO failed")
    if scene.player_rounds != 1 or not scene.done or _state(scene) != STATE_KO_WIN:
        failures.append("Round 1 did not score / enter state 7")
    _round1_rounds = scene.player_rounds
    if not _tick_until(scene, STATE_ROUND_END):
        failures.append("Round 1 result did not reach state 15")
    _round1_path = _trace.slice(0, 3)
    if (_round1_path.size() < 3
            or int(_round1_path[0]) != STATE_FIGHT
            or int(_round1_path[1]) != STATE_KO_WIN
            or int(_round1_path[2]) != STATE_ROUND_END):
        failures.append("Round 1 did not follow 4->7->15 (saw %s)" % str(_trace))
    if _round1_rounds != 1:
        failures.append("Round 1 player_rounds was %d, expected 1" % _round1_rounds)
    _capture_round2 = true
    if not _tick_until(scene, STATE_FIGHT):
        failures.append("Round 2 intro did not reach the fight state")
    _capture_round2 = false
    if (_round2_snapshot.is_empty()
            or String(_round2_snapshot.get("player_state", "")) != "idle"
            or String(_round2_snapshot.get("computer_state", "")) != "idle"
            or not is_equal_approx(
                float(_round2_snapshot.get("player_health", 0.0)),
                PortFighter.MAX_HEALTH)
            or not is_equal_approx(
                float(_round2_snapshot.get("computer_health", 0.0)),
                PortFighter.MAX_HEALTH)
            or String(_round2_snapshot.get("player_clip", "")) != "m01_idle_01"
            or String(_round2_snapshot.get("computer_clip", "")) != "m03_idle_01"
            or not String(_round2_snapshot.get("player_reaction", "")).is_empty()
            or not String(_round2_snapshot.get("computer_reaction", "")).is_empty()):
        failures.append(
            "Round 2 reset retained combat/reaction state (snapshot=%s)"
            % str(_round2_snapshot)
        )

    if not _real_ko(scene, player, computer):
        failures.append("Round 2 real KO failed")
    if scene.player_rounds != 2 or _state(scene) != STATE_KO_WIN:
        failures.append("Round 2 did not score")
    if not _tick_until(scene, STATE_ROUND_END):
        failures.append("Round 2 result did not reach state 15")
    _tick(scene, 0.1)
    if not scene.match_over:
        failures.append("Round 2 did not close the match")

    scene._reset_match()
    if (player.state != "idle" or computer.state != "idle"
            or player.health != PortFighter.MAX_HEALTH
            or computer.health != PortFighter.MAX_HEALTH
            or scene.round_number != 1 or scene.player_rounds != 0
            or scene.computer_rounds != 0 or scene.match_over or scene.done):
        failures.append("Match reset retained combat or score state")

    for round_index: int in range(2):
        if not _real_ko(scene, computer, player):
            failures.append("Computer real KO failed (round %d)" % (round_index + 1))
            break
        if _state(scene) != STATE_KO_LOSE:
            failures.append("Computer KO did not enter state 8")
        if round_index == 0:
            if not _tick_until(scene, STATE_ROUND_END):
                failures.append("Computer round 1 did not reach state 15")
            _tick(scene, 0.1)
            if not _tick_until(scene, STATE_FIGHT):
                failures.append("Computer round 2 intro did not reach the fight state")
    if not _tick_until(scene, STATE_ROUND_END):
        failures.append("Computer round 2 did not reach state 15")
    _tick(scene, 0.1)
    if scene.computer_rounds != 2 or not scene.match_over:
        failures.append("Computer did not close a two-round match")

    scene._reset_match()
    if (scene.player_rounds != 0 or scene.computer_rounds != 0
            or scene.match_over or scene.round_number != 1 or scene.done):
        failures.append("Match reset after a computer win retained score state")

    print("MULTI_ROUND_VALIDATION=" + JSON.stringify({
        "failures": failures,
        "round": scene.round_number,
        "player_state": player.state,
        "computer_state": computer.state,
        "player_clip": player.candidate_animation_clip,
        "computer_clip": computer.candidate_animation_clip,
        "round1_state_path": _round1_path,
        "player_rounds_after_round1": _round1_rounds,
        "round2_reset_snapshot": _round2_snapshot,
    }))
    scene.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)

extends SceneTree
## Multi-round combat-state regression. Every knockout is produced by a real
## punch through the fighter's own attack/contact path.

const STATE_FIGHT: int = 4
const STATE_KO_WIN: int = 7
const STATE_KO_LOSE: int = 8
const STATE_ROUND_END: int = 15
var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _state(scene: Node) -> int:
    var value: Variant = scene.get("match_state")
    return value if typeof(value) == TYPE_INT else -1


func _tick(scene: Node, seconds: float, step: float = 0.05) -> void:
    var remaining: float = seconds
    while remaining > 0.0:
        var dt: float = minf(remaining, step)
        scene._physics_process(dt)
        remaining -= dt


func _tick_until(scene: Node, target: int, max_seconds: float = 9.0) -> bool:
    var elapsed: float = 0.0
    while elapsed < max_seconds:
        if _state(scene) == target:
            return true
        scene._physics_process(0.02)
        elapsed += 0.02
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
    for _i: int in range(150):
        if _state(scene) != STATE_FIGHT:
            break
        defender._physics_process(1.0 / 60.0)
    return _state(scene) != STATE_FIGHT


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

    if not _real_ko(scene, player, computer):
        failures.append("Round 1 real KO failed")
    if scene.player_rounds != 1 or not scene.done or _state(scene) != STATE_KO_WIN:
        failures.append("Round 1 did not score / enter state 7")
    if not _tick_until(scene, STATE_ROUND_END):
        failures.append("Round 1 result did not reach state 15")
    _tick(scene, 0.1)
    if not _tick_until(scene, STATE_FIGHT):
        failures.append("Round 2 intro did not reach the fight state")
    if (player.state != "idle" or computer.state != "idle"
            or player.health != PortFighter.MAX_HEALTH
            or computer.health != PortFighter.MAX_HEALTH
            or player.candidate_animation_clip != "m01_idle_01"
            or computer.candidate_animation_clip != "m03_idle_01"
            or not player.last_reaction_animation.is_empty()
            or not computer.last_reaction_animation.is_empty()):
        failures.append("Round 2 reset retained combat/reaction state")

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
    }))
    scene.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)

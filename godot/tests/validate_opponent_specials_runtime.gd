extends SceneTree
## Headless runtime validation in the real res://scenes/main.tscn.
##
## Usage:
##   godot --headless --path <copy> --script res://tests/validate_opponent_specials_runtime.gd -- \
##     <label> <player_glb> <config> <opponent_glb> <texture_root|-> \
##     <special_kind> <special_clip> <endattack_kind> <endattack_clip> [missing]
##
## play mode    : the opponent's recovered special + endattack kinds must be
##                reported as supported, start, play their recovered clip, and
##                record the recovered fight-stat category (special / endmove)
##                on the fighter record without cross-recording the other one.
## missing mode : with a candidate that lacks the special clip the kind must be
##                refused (supports_attack false, request_attack false, no clip
##                substitution), i.e. the whole class fails closed.

const FightStats = preload("res://scripts/fight_stats.gd")


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("OPPONENT_SPECIALS_RUNTIME_FAIL: " + message)
    quit(1)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() < 9:
        _fail("expected <label> <player_glb> <config> <opponent_glb> <texture_root|-> "
                + "<special_kind> <special_clip> <endattack_kind> <endattack_clip> [missing]")
        return
    var label: String = args[0]
    var player_glb: String = args[1]
    var config: String = args[2]
    var opponent_glb: String = args[3]
    var texture_root: String = "" if args[4] == "-" else args[4]
    var special_kind: String = args[5]
    var special_clip: String = args[6]
    var endattack_kind: String = args[7]
    var endattack_clip: String = args[8]
    var missing: bool = args.size() > 9 and args[9] == "missing"

    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", player_glb)
    OS.set_environment("BRUCELEE_PLAYER_TEXTURE_ROOT", "")
    OS.set_environment("BRUCELEE_OPPONENT_ATTACK_CONFIG", config)
    OS.set_environment("BRUCELEE_OPPONENT_GLB", opponent_glb)
    OS.set_environment("BRUCELEE_OPPONENT_TEXTURE_ROOT", texture_root)
    OS.set_environment("BRUCELEE_OPPONENT_CLIP_PREFIX", "")
    OS.set_environment("BRUCELEE_OPPONENT_MASTER", "1" if label == "master" else "")

    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_physics_process(false)
    var computer: PortFighter = scene.get("computer")
    computer.set_physics_process(false)
    if not computer.candidate_loaded:
        _fail(label + ": candidate_loaded=false error=" + computer.candidate_load_error)
        return
    if not computer.attack_config_error.is_empty():
        _fail(label + ": attack config failed closed: " + computer.attack_config_error)
        return
    if not computer.ATTACKS.has(special_kind):
        _fail(label + " lacks attack kind " + special_kind)
        return
    if not computer.ATTACKS.has(endattack_kind):
        _fail(label + " lacks attack kind " + endattack_kind)
        return

    var result: Dictionary = {
        "label": label,
        "config": config,
        "glb": opponent_glb,
        "attack_count": computer.ATTACKS.size(),
        "special": {},
        "endattack": {},
        "missing_clip_mode": missing,
    }

    if missing:
        var supported: bool = computer.supports_attack(special_kind)
        computer.reset_fighter(Vector3(1.5, 1.2, 0.0))
        computer.reset_anim_categories()
        var before_clip: String = computer.candidate_animation_clip
        var started: bool = computer.request_attack(special_kind)
        var after_kind: String = computer.attack_kind
        computer._animate_candidate()
        var after_clip: String = computer.candidate_animation_clip
        var substituted: bool = (after_clip == special_clip
                or after_clip == "m04_sp_pnch_high"
                or after_clip == "m04_sp_pnch_high_fail")
        if supported:
            _fail(label + ": supports_attack returned true without the special clip")
            return
        if started:
            _fail(label + ": request_attack accepted a kind without its clip")
            return
        if not after_kind.is_empty():
            _fail(label + ": attack_kind changed to " + after_kind + " without a clip")
            return
        if substituted:
            _fail(label + ": a substitute clip " + after_clip + " was played")
            return
        result["special"] = {
            "supports_attack": supported,
            "request_attack": started,
            "attack_kind": after_kind,
            "clip_before": before_clip,
            "clip_after": after_clip,
            "substituted": substituted,
        }
        print("OPPONENT_SPECIALS_RUNTIME_OK=" + JSON.stringify(result))
        quit(0)
        return

    if not computer.supports_attack(special_kind):
        _fail(label + " does not support " + special_kind + " (" + special_clip + ")")
        return
    computer.reset_fighter(Vector3(1.5, 1.2, 0.0))
    computer.reset_anim_categories()
    var special_started: bool = computer.request_attack(special_kind)
    if not special_started:
        _fail(label + ": request_attack refused " + special_kind)
        return
    var special_categories: int = computer.anim_category(FightStats.SPECIAL)
    var special_cross: int = computer.anim_category(FightStats.ENDMOVE)
    computer._animate_candidate()
    var played_special: String = computer.candidate_animation_clip
    if played_special != special_clip:
        _fail("%s/%s played %s, expected %s"
                % [label, special_kind, played_special, special_clip])
        return
    if special_categories != 1:
        _fail(label + ": " + special_kind + " did not record the special category")
        return
    if special_cross != 0:
        _fail(label + ": " + special_kind + " wrongly recorded endmove")
        return
    result["special"] = {
        "kind": special_kind,
        "clip": played_special,
        "special_category": special_categories,
        "endmove_category": special_cross,
    }

    computer.reset_fighter(Vector3(1.5, 1.2, 0.0))
    computer.reset_anim_categories()
    var end_started: bool = computer.request_attack(endattack_kind)
    if not end_started:
        _fail(label + ": request_attack refused " + endattack_kind)
        return
    var end_categories: int = computer.anim_category(FightStats.ENDMOVE)
    var end_cross: int = computer.anim_category(FightStats.SPECIAL)
    computer._animate_candidate()
    var played_end: String = computer.candidate_animation_clip
    if played_end != endattack_clip:
        _fail("%s/%s played %s, expected %s"
                % [label, endattack_kind, played_end, endattack_clip])
        return
    if end_categories != 1:
        _fail(label + ": " + endattack_kind + " did not record the endmove category")
        return
    if end_cross != 0:
        _fail(label + ": " + endattack_kind + " wrongly recorded special")
        return
    result["endattack"] = {
        "kind": endattack_kind,
        "clip": played_end,
        "endmove_category": end_categories,
        "special_category": end_cross,
    }

    print("OPPONENT_SPECIALS_RUNTIME_OK=" + JSON.stringify(result))
    quit(0)

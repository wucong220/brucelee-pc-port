extends RefCounted
## Data-driven AI recovered from the shipped `adreno_200/ai/standard.tree`
## decision tree and the per-character `ai_profile` block of
## `adreno_200/characters.list`.
##
## This replaces the prototype's hand-tuned thresholds (uniform 0.45..0.95 s
## decision timer, uniform move choice, rage gates at 1/3 and 2/3, 25 % guard
## roll) with the original node graph and the original profile probabilities.
##
## Provenance and per-constant status live in `data/native_ai/provenance.json`
## and `docs/EVIDENCE.md` / `docs/RECOVERY_GAPS.md`.  Conditions whose native
## threshold is not recoverable are read from `tuning.json`, where each entry is
## explicitly marked UNRECOVERED; nothing here fabricates a native value.
##
## Recursion into the tree stops after MAX_WALK steps; the native evaluator has
## no such guard, but a malformed/edited tree must not hang the game loop.

const TREE_PATH := "res://data/native_ai/standard_tree.json"
const PROFILES_PATH := "res://data/native_ai/ai_profiles.json"
const ACTION_MAP_PATH := "res://data/native_ai/action_map.json"
const TUNING_PATH := "res://data/native_ai/tuning.json"

const MAX_WALK := 64
## The native state machine's initial state (CDecisionTree parses a "default"
## state and `treecheckmystate` maps it to `treedefaultbehavior`).
const INITIAL_STATE := "default"

## Tree leaf actions that are not attacks: the value is the dispatch token.
const DISPATCH_BLOCK_HIGH := "__block_high__"
const DISPATCH_BLOCK_MID := "__block_mid__"
const DISPATCH_BLOCK_LOW := "__block_low__"
const DISPATCH_MOVE_FWD := "__move_fwd__"
const DISPATCH_MOVE_BACK := "__move_back__"
const DISPATCH_MOVE_LEFT := "__move_left__"
const DISPATCH_MOVE_RIGHT := "__move_right__"
const DISPATCH_SKIP_FWD := "__skip_fwd__"
const DISPATCH_SKIP_BACK := "__skip_back__"
const DISPATCH_STEP_FWD := "__step_fwd__"
const DISPATCH_STEP_BACK := "__step_back__"
const DISPATCH_STEP_LEFT := "__step_left__"
const DISPATCH_STEP_RIGHT := "__step_right__"
const DISPATCH_IDLE := "__idle__"
const DISPATCH_GETUP := "__getup__"

const BLOCK_TOKENS: Array[String] = [
    DISPATCH_BLOCK_HIGH, DISPATCH_BLOCK_MID, DISPATCH_BLOCK_LOW,
]
const MOVE_TOKENS: Array[String] = [
    DISPATCH_MOVE_FWD, DISPATCH_MOVE_BACK, DISPATCH_MOVE_LEFT,
    DISPATCH_MOVE_RIGHT, DISPATCH_SKIP_FWD, DISPATCH_SKIP_BACK,
    DISPATCH_STEP_FWD, DISPATCH_STEP_BACK, DISPATCH_STEP_LEFT,
    DISPATCH_STEP_RIGHT,
]

var tree: Dictionary = {}
var profiles: Dictionary = {}
var action_map: Dictionary = {}
var tuning: Dictionary = {}
var load_error: String = ""

var fighter: PortFighter
var opponent: PortFighter
var character_key: String = ""
var profile: Dictionary = {}
var difficulty_index: int = 2  # medium: UI index 1 -> trunc(2*1) = slot 2

## Native AI state (`my_state`), set by a leaf's `set_state` and read by
## `treecheckmystate`.  Persists across frames exactly like the native node.
var state: String = INITIAL_STATE
var last_node: String = ""
var last_action: String = ""

var decisions: Array[Dictionary] = []
var _repetition: int = 0
var _last_signature: String = ""
var _opp_last_attack: String = ""
var _opp_repeat: int = 0
var _opp_was_startup: bool = false
var _rng := RandomNumberGenerator.new()

## Diagnostics: how many times each native action was selected and which
## actions could not be dispatched by the current fighting set.
var action_counts: Dictionary = {}
var unsupported_actions: Dictionary = {}


func load_data() -> bool:
    var tree_text: String = FileAccess.get_file_as_string(TREE_PATH)
    if tree_text.is_empty():
        load_error = "cannot read " + TREE_PATH
        return false
    var parsed: Variant = JSON.parse_string(tree_text)
    if not parsed is Dictionary:
        load_error = "invalid tree JSON"
        return false
    tree = parsed
    var profiles_text: String = FileAccess.get_file_as_string(PROFILES_PATH)
    var profiles_parsed: Variant = JSON.parse_string(profiles_text)
    if profiles_parsed is Dictionary:
        profiles = profiles_parsed
    var map_text: String = FileAccess.get_file_as_string(ACTION_MAP_PATH)
    var map_parsed: Variant = JSON.parse_string(map_text)
    if map_parsed is Dictionary:
        action_map = map_parsed
    var tuning_text: String = FileAccess.get_file_as_string(TUNING_PATH)
    var tuning_parsed: Variant = JSON.parse_string(tuning_text)
    if tuning_parsed is Dictionary:
        tuning = tuning_parsed
    if tree.is_empty():
        load_error = "empty tree"
        return false
    return true


func configure(
    own_fighter: PortFighter,
    other_fighter: PortFighter,
    key: String,
    seed_value: int = 0
) -> void:
    fighter = own_fighter
    opponent = other_fighter
    character_key = key
    var entry: Variant = profiles.get(key, {})
    profile = Dictionary(entry).get("profile", {}) if entry is Dictionary else {}
    _rng.seed = seed_value
    var difficulty: String = OS.get_environment("BRUCELEE_AI_DIFFICULTY")
    match difficulty:
        "easy":
            difficulty_index = 0
        "medium", "":
            difficulty_index = 2
        "hard":
            difficulty_index = 4
        _:
            if difficulty.is_valid_int():
                difficulty_index = clampi(int(difficulty), 0, 4)


func set_difficulty(index: int) -> void:
    difficulty_index = clampi(index, 0, 4)


## Walk the tree once and execute the resulting node.  Returns a decision record
## {"kind", "action", "native", "node", "state", "reason"} for tests/logs.
func step(delta: float) -> Dictionary:
    if fighter == null or not is_instance_valid(fighter):
        return _record("none", "", "", "", "no_fighter")
    _update_opponent_attack_sequence()
    if not _can_act():
        return _record("none", "", "", "", "busy")

    var walk: Dictionary = _walk()
    if walk.has("error"):
        return _record("none", "", "", "", String(walk["error"]))

    var node_name: String = String(walk.get("node_name", ""))
    var node: Dictionary = walk.get("node", {})
    var actions: Array = node.get("actions", [])
    var next_state: String = String(node.get("set_state", state))
    last_node = node_name

    if actions.is_empty():
        # Pure state change (for example {"set_state": "wait_to_idle_attack"}).
        state = next_state
        return _record("none", "", "", node_name, "state_change")

    var native_action: String = ""
    var dispatch: String = ""
    var picked: Dictionary = _pick_action(actions)
    native_action = String(picked.get("native", ""))
    dispatch = String(picked.get("dispatch", ""))

    var signature: String = native_action + "|" + node_name
    if signature == _last_signature:
        _repetition += 1
    else:
        _repetition = 1
        _last_signature = signature

    state = next_state
    last_action = native_action
    action_counts[native_action] = int(action_counts.get(native_action, 0)) + 1

    var kind: String = "none"
    if dispatch.is_empty():
        unsupported_actions[native_action] = true
        kind = "unsupported"
    elif dispatch.begins_with("__block"):
        kind = "block"
        _apply_block(dispatch)
    elif MOVE_TOKENS.has(dispatch):
        kind = "move"
        _apply_move(dispatch, delta)
    elif dispatch == DISPATCH_IDLE:
        kind = "idle"
        _apply_idle()
    elif dispatch == DISPATCH_GETUP:
        kind = "getup"
        _apply_getup()
    else:
        kind = "attack"
        if not _apply_attack(native_action, dispatch):
            kind = "attack_rejected"
    return _record(kind, dispatch, native_action, node_name, "")


func _record(kind: String, action: String, native: String, node: String, reason: String) -> Dictionary:
    var entry: Dictionary = {
        "kind": kind,
        "action": action,
        "native": native,
        "node": node,
        "state": state,
        "reason": reason,
    }
    if decisions.size() > 256:
        decisions.pop_front()
    decisions.append(entry)
    return entry


# --- tree walk -------------------------------------------------------------


func _walk() -> Dictionary:
    var node_name: String = "root"
    var node: Variant = tree.get(node_name)
    for _step_index in range(MAX_WALK):
        if not node is Dictionary:
            return {"error": "missing_node:" + node_name}
        var dict: Dictionary = node
        if _is_leaf(dict):
            return {"node_name": node_name, "node": dict}
        if not dict.has("condition"):
            return {"error": "bad_node:" + node_name}
        var result: String = _eval_condition(dict)
        var child: Dictionary = _pick_child(dict, result)
        if child.is_empty():
            return {"error": "no_case:%s=%s" % [dict.get("condition", ""), result]}
        if child.has("node"):
            node_name = String(child["node"])
            node = tree.get(node_name)
        else:
            # Inline child (condition or leaf) stored under its parent.
            node_name = node_name + "/" + String(child.get("case", "?"))
            node = child
    return {"error": "walk_limit"}


func _is_leaf(node: Dictionary) -> bool:
    if node.has("actions"):
        return true
    return node.has("set_state") and not node.has("condition")


func _pick_child(node: Dictionary, result: String) -> Dictionary:
    var children: Array = node.get("children", [])
    var fallback: Dictionary = {}
    for child_value: Variant in children:
        if not child_value is Dictionary:
            continue
        var child: Dictionary = child_value
        var case_value: String = String(child.get("case", ""))
        if case_value == result:
            return child
        # The shipped tree contains the misspelling "defaulr"; treat it as the
        # same default branch instead of losing the whole decision.
        if case_value in ["default", "defaulr"]:
            fallback = child
    return fallback


# --- conditions ------------------------------------------------------------


func _eval_condition(node: Dictionary) -> String:
    var condition: String = String(node.get("condition", ""))
    match condition:
        "random_probability":
            return "true" if _rng.randf() < _probability(node) else "false"
        "profile_probability":
            var key: String = String(node.get("str_param", ""))
            var value: float = float(profile.get(key, 0.0))
            return "true" if _rng.randf() < value else "false"
        "my_state":
            return state
        "my_animation":
            return _my_animation()
        "my_last_action":
            return last_node if not last_node.is_empty() else "default"
        "my_rage":
            return _rage_band()
        "distance":
            return _distance_band()
        "near":
            return "true" if _in_attack_reach() else "false"
        "near_limits":
            return "true" if _near_limits() else "false"
        "winning":
            return "true" if _winning() else "false"
        "opp_attacking":
            return "true" if _opp_attacking() else "false"
        "opp_pose":
            return _opp_pose()
        "opp_attack_height":
            return _opp_attack_height()
        "repetition":
            return _classify_repetition(_opp_repeat)
    return "default"


func _probability(node: Dictionary) -> float:
    var by_difficulty: Variant = node.get("params_by_difficulty")
    # Native only registers params_by_difficulty; "params_by_dificulty" is
    # dead data in .rodata and must not be treated as a fallback.
    if by_difficulty is Array and not Array(by_difficulty).is_empty():
        var values: Array = by_difficulty
        return float(values[clampi(difficulty_index, 0, values.size() - 1)])
    return float(node.get("param", 0.0))


func _my_animation() -> String:
    if fighter.state in ["facedownidle", "faceupidle", "idle", "idle2", "idle3"]:
        return fighter.state
    var action: String = fighter._current_action_name()
    if not action.is_empty():
        return action
    return "default"


func _update_opponent_attack_sequence() -> void:
    if opponent == null or not is_instance_valid(opponent):
        return
    var is_startup: bool = opponent.state == "startup"
    if is_startup and not _opp_was_startup:
        var action: String = opponent._current_action_name()
        if not action.is_empty():
            if action == _opp_last_attack:
                _opp_repeat += 1
            else:
                _opp_repeat = 0
                _opp_last_attack = action
    _opp_was_startup = is_startup


func _classify_repetition(value: int) -> String:
    # Native consecutive_attacks is 0-based; the shipped labels are 0..4 and
    # 6_or_more for the sixth and later identical attack.
    if value >= 5:
        return "6_or_more"
    return str(value)


func _rage_band() -> String:
    var value: float = clampf(fighter.rage, 0.0, 100.0)
    if value >= 100.0:
        return "full"
    if value >= 66.0:
        return "twothirds"
    if value >= 33.0:
        return "onethird"
    return "none"


func _distance_band() -> String:
    # Recovered conditions.config thresholds are native world units: close
    # [0,100), medium [100,200), far [200,1000).  The port scale below is the
    # declared arena-width mapping (ARENA_HALF_X / 400.0), not an invented
    # reach multiplier.
    var scale_value: float = PortFighter.ARENA_HALF_X / 400.0
    var separation: float = _separation()
    if separation < 100.0 * scale_value:
        return "close"
    if separation < 200.0 * scale_value:
        return "medium"
    if separation < 1000.0 * scale_value:
        return "far"
    return "none"


func _in_attack_reach() -> bool:
    # conditions.config "near": [0,120) native units.
    return _separation() < 120.0 * (PortFighter.ARENA_HALF_X / 400.0)


func _near_limits() -> bool:
    # conditions.config "near_limits": distance_to_limit = 400 - |pos| < 50.
    var scale_value: float = PortFighter.ARENA_HALF_X / 400.0
    var origin_distance: float = Vector3(
        fighter.position.x, fighter.position.y, fighter.position.z
    ).length()
    var distance_to_limit: float = 400.0 - origin_distance / scale_value
    return distance_to_limit >= 0.0 and distance_to_limit < 50.0


## Tuning entries carry {"value", "status", "basis"} in the shipped JSON so the
## provenance of every non-recovered number travels with the data.
func _tune_float(key: String, fallback: float) -> float:
    var entry: Variant = tuning.get(key)
    if entry is Dictionary:
        return float(Dictionary(entry).get("value", fallback))
    if entry is float or entry is int:
        return float(entry)
    return fallback


func _winning() -> bool:
    if opponent == null or not is_instance_valid(opponent):
        return false
    return fighter.health >= opponent.health


func _opp_attacking() -> bool:
    if opponent == null or not is_instance_valid(opponent):
        return false
    return opponent.state in ["startup", "active"]


func _opp_pose() -> String:
    if opponent == null or not is_instance_valid(opponent):
        return "stand"
    if opponent.state in ["facedownidle", "faceupidle"]:
        return "laying"
    if opponent.state in ["stun", "stunfall", "stunfallhold"]:
        return "stun"
    return "stand"


func _opp_attack_height() -> String:
    if opponent == null or not is_instance_valid(opponent):
        return "medium"
    if not opponent.ATTACKS.has(opponent.attack_kind):
        return "medium"
    var height: String = String(Dictionary(opponent.ATTACKS[opponent.attack_kind]).get("height", "medium"))
    return height if height in ["high", "medium", "low"] else "medium"


func _attack_reach() -> float:
    var best: float = 0.0
    for kind: String in ["punch", "kick", "high_punch", "low_kick"]:
        if fighter.supports_attack(kind):
            best = maxf(best, fighter.attack_reach_world(kind, opponent))
    if best <= 0.0:
        best = 1.0
    return best


func _separation() -> float:
    var delta: Vector3 = opponent.position - fighter.position
    return Vector2(delta.x, delta.z).length()


# --- actions ---------------------------------------------------------------


## Choose among the leaf's alternatives.  The shipped tree lists one entry per
## character ("specialkicklow brick", "specialkicklow chief", ...).  The native
## node picks the entry belonging to the fighter, so entries naming another
## character must not be used: their set row carries that character's rage cost
## and animation.  Order: this character's entry, then the generic entry, then
## anything the fighting set actually supports.
func _pick_action(actions: Array) -> Dictionary:
    var tokens: Array[String] = [character_key]
    var short_name: String = character_key.split(" ")[0]
    if short_name != character_key:
        tokens.append(short_name)
    var compact: String = character_key.replace(" ", "")
    if compact != character_key and not tokens.has(compact):
        tokens.append(compact)
    match character_key:
        "brick davis": tokens.append("brick")
        "ken godall": tokens.append("ken")
        "the master": tokens.append("master")
        "lo ming a", "lo ming b": tokens.append("loming")
        "shen lo": tokens.append("shenlo")
        "sin fu": tokens.append("sinfu")
    var mine: Array[String] = []
    var generic: Array[String] = []
    var rest: Array[String] = []
    for value: Variant in actions:
        var text: String = String(value)
        var space: int = text.rfind(" ")
        if space < 0:
            generic.append(text)
            continue
        var suffix: String = text.substr(space + 1)
        if tokens.has(suffix):
            mine.append(text)
        else:
            rest.append(text)
    for native: String in mine + generic:
        var slots: Array = Array(action_map.get(_action_base(native), []))
        for slot_value: Variant in slots:
            var slot: String = String(slot_value)
            if slot.begins_with("__"):
                return {"native": native, "dispatch": slot}
            if fighter.supports_attack(slot):
                return {"native": native, "dispatch": slot}
    # Last resort: another character's variant only when nothing else exists.
    for native: String in rest:
        var slots: Array = Array(action_map.get(_action_base(native), []))
        for slot_value: Variant in slots:
            var slot: String = String(slot_value)
            if slot.begins_with("__"):
                return {"native": native, "dispatch": slot}
            if fighter.supports_attack(slot):
                return {"native": native, "dispatch": slot}
    var all: Array[String] = mine + generic + rest
    return {"native": "" if all.is_empty() else all[0], "dispatch": ""}


func _action_base(native: String) -> String:
    var space: int = native.rfind(" ")
    return native.substr(0, space) if space > 0 else native


func _apply_attack(native: String, kind: String) -> bool:
    # PortFighter.request_attack() refuses while guard_held, so a tree decision
    # to attack must drop the guard first (the native block action ends when the
    # next decision picks a different action).
    fighter.guard_held = false
    if not fighter.request_attack(kind):
        return false
    # Recovered per-action rage cost: the set stores negative values on the
    # special/miss actions (for example "specialkicklow brick" = -33 in
    # thai.set).  The prototype AI used a separate invented cost table; the
    # native cost is the action's own value.
    var cost: float = fighter._action_rage_value(native)
    if cost < 0.0:
        fighter.rage = maxf(0.0, fighter.rage + cost)
    return true


func _apply_block(_token: String) -> void:
    # Native highblock/midblock/lowblock: hold the guard.  PortFighter has a
    # single guard flag; the block-height clips are visual only.  Parries are
    # separate tree actions (actioncounter*_attack -> parryhigh/parrylow).
    fighter.guard_held = true


func _apply_idle() -> void:
    fighter.guard_held = false
    fighter.move_axis = Vector2.ZERO


func _apply_getup() -> void:
    # Native actiongetup lists faceupgetup/facedowngetup; the port decides by the
    # current floor state.  Both entry points already exist for the player.
    fighter.move_axis = Vector2.ZERO
    if fighter.state == "facedownidle":
        fighter._begin_facedown_getup()
    elif fighter.state == "faceupidle":
        fighter._begin_faceup_getup()


func _apply_move(token: String, _delta: float) -> void:
    fighter.guard_held = false
    var to_opponent: Vector3 = opponent.position - fighter.position
    var forward: float = signf(to_opponent.x)
    var lateral: float = signf(to_opponent.z)
    var hold: float = 1.0
    match token:
        DISPATCH_MOVE_FWD, DISPATCH_STEP_FWD:
            fighter.move_axis = Vector2(forward, 0.0)
        DISPATCH_SKIP_FWD:
            fighter.move_axis = Vector2(forward * 1.5, 0.0)
        DISPATCH_MOVE_BACK, DISPATCH_STEP_BACK:
            fighter.move_axis = Vector2(-forward * 0.6, 0.0)
        DISPATCH_SKIP_BACK:
            fighter.move_axis = Vector2(-forward, 0.0)
        DISPATCH_MOVE_LEFT, DISPATCH_STEP_LEFT:
            fighter.move_axis = Vector2(0.0, lateral)
        DISPATCH_MOVE_RIGHT, DISPATCH_STEP_RIGHT:
            fighter.move_axis = Vector2(0.0, -lateral)
    fighter.move_axis *= hold


func _can_act() -> bool:
    # `request_attack` only starts from a standing idle, so the tree is only
    # walked while the fighter can still choose an action.  The native AIUpdate
    # runs every frame; the gating here is the port's action-entry contract.
    return fighter.state in ["idle", "idle2", "idle3", "facedownidle", "faceupidle"]

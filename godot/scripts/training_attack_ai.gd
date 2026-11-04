extends RefCounted
class_name PortTrainingAttackAI

## Interpreter for the recovered `adreno_200/ai/training_attack.tree`.
##
## The shipped tree is a data graph, not a fixed high/low alternation:
##
##   do_attack --(random_probability 0.1)--> combo_level1
##   combo_level1 --(random_number 4)--> highpunch1 / lowpunch1 / highkick1 / lowkick1
##   combo_continue --(my_animation)--> combo_level2 / combo_level3
##
## Every node, case, probability and action is read from
## `res://data/native_ai/training_attack_tree.json`, generated verbatim from the
## untouched data.zpak by `tools/build_training_attack_tree.py`.
##
## The port's action entry point (`PortFighter.request_attack`) only accepts a
## new attack from a standing idle (or a recovered cancel window), so a combo
## continuation is rolled once per attack and queued for the next standing
## idle.  That cadence is a port contract, not a recovered timer; the recovered
## probability (0.1) and the four-way random choice are unchanged.  Movement
## branches (`advance`/`walk_forward`) are interpreted but the training dummy is
## placed in `near` range, so it does not need to walk; a reached movement branch
## is reported as `unsupported` instead of inventing locomotion.

const TREE_PATH := "res://data/native_ai/training_attack_tree.json"

const DISPATCH_ATTACKS := {
    "highpunch1": "high_punch",
    "lowpunch1": "low_punch",
    "highkick1": "high_kick",
    "lowkick1": "low_kick",
    "highpunch2": "high_punch2",
    "lowpunch2": "low_punch2",
    "highkick2": "high_kick2",
    "lowkick2": "low_kick2",
    "highpunch3": "high_punch3",
    "lowpunch3": "low_punch3",
    "highkick3": "high_kick3",
    "lowkick3": "low_kick3",
}
const DISPATCH_MOVES := ["skipfwd", "movefwd", "stepfwd"]
const DISPATCH_GETUP := "faceupgetup"
const MAX_WALK := 32

var tree: Dictionary = {}
var load_error := ""
var fighter: PortFighter
var opponent: PortFighter

var last_node := ""
var last_action := ""
var decisions: Array[Dictionary] = []
var action_counts: Dictionary = {}
var unsupported: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _pending_attack := ""
var _pending_node := ""
var _combo_rolled := false
var _attack_serial := -1


func load_data() -> bool:
    var text: String = FileAccess.get_file_as_string(TREE_PATH)
    if text.is_empty():
        load_error = "cannot read " + TREE_PATH
        return false
    var parsed: Variant = JSON.parse_string(text)
    if not parsed is Dictionary:
        load_error = "invalid training attack tree JSON"
        return false
    var payload: Dictionary = parsed
    var nodes: Variant = payload.get("nodes", null)
    if not nodes is Dictionary or not Dictionary(nodes).has("root"):
        load_error = "training attack tree has no nodes.root"
        return false
    tree = nodes
    return true


func configure(own_fighter: PortFighter, other: PortFighter, seed_value: int = 0) -> void:
    fighter = own_fighter
    opponent = other
    _rng.seed = seed_value
    _pending_attack = ""
    _pending_node = ""
    _combo_rolled = false
    _attack_serial = -1


## Walk the recovered tree once.  Returns a log record for tests and captures.
func step(_delta: float) -> Dictionary:
    if fighter == null or not is_instance_valid(fighter):
        return _record("none", "", "no_fighter")
    if fighter.state not in [
            "idle", "idle2", "idle3", "startup", "active", "recovery",
            "facedownidle", "faceupidle"]:
        return _record("none", "", "busy")

    # A queued combo starts as soon as the previous attack returns to idle.
    if not _pending_attack.is_empty() and fighter.state in ["idle", "idle2", "idle3"]:
        var queued := _pending_attack
        var queued_node := _pending_node
        _pending_attack = ""
        _pending_node = ""
        if _request_attack(queued):
            last_action = queued
            last_node = queued_node
            return _record("attack", queued, queued_node)

    # The tree's combo branch is reached while the dummy is attacking.  Roll it
    # once per attack so the 10 % probability is not re-rolled every frame.
    var attacking: bool = fighter.state in ["startup", "active", "recovery"]
    if attacking:
        if fighter.attack_sequence != _attack_serial:
            _attack_serial = fighter.attack_sequence
            _combo_rolled = false
        if _combo_rolled or not _pending_attack.is_empty():
            return _record("none", "", "attacking")
        _combo_rolled = true
    else:
        _combo_rolled = false

    if fighter.state in ["facedownidle", "faceupidle"] and not attacking:
        return _record("none", "", "floor")
    if fighter.state in ["idle2", "idle3"]:
        # The port's idle variants are still a standing idle for attack entry;
        # the tree's my_animation case reads them correctly.
        pass

    var walk: Dictionary = _walk()
    if walk.has("error"):
        return _record("none", "", String(walk["error"]))

    var node_name := String(walk.get("node_name", ""))
    var node: Dictionary = walk.get("node", {})
    last_node = node_name
    var action := String(node.get("action", ""))
    if action.is_empty() and node.get("actions") is Array:
        # do_nothing: the shipped idle list; choosing no action is the idle.
        var actions: Array = node["actions"]
        if not actions.is_empty():
            action = String(actions[_rng.randi_range(0, actions.size() - 1)])
        return _record("idle", "idle", node_name)

    if action.is_empty():
        return _record("none", "", node_name + ":no_action")

    if DISPATCH_ATTACKS.has(action):
        if attacking:
            # Queue the recovered combo level for the next standing idle.
            _pending_attack = action
            _pending_node = node_name
            return _record("queued", action, node_name)
        if fighter.state not in ["idle", "idle2", "idle3"]:
            return _record("none", action, node_name + ":not_idle")
        if _request_attack(action):
            last_action = action
            return _record("attack", action, node_name)
        return _record("attack_rejected", action, node_name)

    if action == DISPATCH_GETUP:
        if fighter.state == "faceupidle":
            fighter._begin_faceup_getup()
            return _record("getup", action, node_name)
        if fighter.state == "facedownidle":
            fighter._begin_facedown_getup()
            return _record("getup", action, node_name)
        return _record("none", action, node_name + ":not_floor")

    if DISPATCH_MOVES.has(action):
        # The tree's advance/walk_forward branch is the recovered answer to an
        # out-of-range player.  The training loop owns the dummy's physics, so
        # this applies the same PortFighter base speed the native step actions
        # use; no new AI threshold is introduced.
        if _apply_move(action, _delta):
            return _record("move", action, node_name)
        return _record("move_rejected", action, node_name)

    unsupported[action] = true
    return _record("unsupported", action, node_name)


func _apply_move(action: String, delta: float) -> bool:
    if opponent == null or not is_instance_valid(opponent):
        return false
    var direction: Vector3 = opponent.global_position - fighter.global_position
    direction.y = 0.0
    if direction.length_squared() <= 0.000001:
        return false
    var scale := 1.0
    match action:
        "stepfwd":
            scale = 0.25
        "skipfwd":
            scale = PortFighter.SKIP_SPEED_SCALE
        "movefwd":
            scale = 1.0
    fighter.global_position += direction.normalized() * PortFighter.BASE_SPEED * scale * delta
    fighter.global_position.x = clampf(
        fighter.global_position.x, -PortFighter.ARENA_HALF_X, PortFighter.ARENA_HALF_X)
    return true


func _request_attack(native: String) -> bool:
    var kind := String(DISPATCH_ATTACKS.get(native, ""))
    if kind.is_empty():
        return false
    fighter.guard_held = false
    if not fighter.request_attack(kind):
        unsupported[native + ":request"] = true
        return false
    action_counts[native] = int(action_counts.get(native, 0)) + 1
    return true


func _record(kind: String, native: String, node: String) -> Dictionary:
    var entry := {
        "kind": kind,
        "native": native,
        "node": node,
        "state": fighter.state if fighter != null else "",
    }
    if decisions.size() > 256:
        decisions.pop_front()
    decisions.append(entry)
    return entry


# --- tree walk -------------------------------------------------------------


func _walk() -> Dictionary:
    var node_name := "root"
    var node: Variant = tree.get(node_name)
    for _step in range(MAX_WALK):
        if not node is Dictionary:
            return {"error": "missing_node:" + node_name}
        var dict: Dictionary = node
        if dict.has("action") or dict.has("actions"):
            return {"node_name": node_name, "node": dict}
        if not dict.has("condition"):
            return {"error": "bad_node:" + node_name}
        var result := _condition(dict)
        var child := _pick_child(dict, result)
        if child.is_empty():
            return {"error": "no_case:%s=%s" % [dict.get("condition", ""), result]}
        if child.has("node"):
            node_name = String(child["node"])
            node = tree.get(node_name)
        else:
            node_name = node_name + "/" + String(child.get("case", "?"))
            node = child
    return {"error": "walk_limit"}


func _pick_child(node: Dictionary, result: String) -> Dictionary:
    var fallback: Dictionary = {}
    for child_value: Variant in node.get("children", []):
        if not child_value is Dictionary:
            continue
        var child: Dictionary = child_value
        var case_value := String(child.get("case", ""))
        if case_value == result:
            return child
        if case_value in ["default", "defaulr"]:
            fallback = child
    return fallback


# --- conditions ------------------------------------------------------------


func _condition(node: Dictionary) -> String:
    var condition := String(node.get("condition", ""))
    match condition:
        "my_animation":
            return _my_animation()
        "opp_pose":
            return _opp_pose()
        "near":
            return "true" if _separation() < _reach() else "false"
        "distance":
            return _distance_band()
        "me_attacking":
            return "true" if fighter.state in [
                "startup", "active", "recovery"] else "false"
        "random_probability":
            return "true" if _rng.randf() < float(node.get("param", 0.0)) else "false"
        "random_number":
            var count: int = maxi(1, int(float(node.get("param", 1.0))))
            return str(_rng.randi_range(0, count - 1))
    return "default"


func _my_animation() -> String:
    if fighter.state in ["facedownidle", "faceupidle", "idle", "idle2", "idle3"]:
        return fighter.state
    var action := String(fighter._current_action_name())
    if not action.is_empty():
        return action
    return "default"


func _opp_pose() -> String:
    if opponent == null or not is_instance_valid(opponent):
        return "stand"
    if opponent.state in ["facedownidle", "faceupidle"]:
        return "laying"
    return "stand"


func _separation() -> float:
    var delta: Vector3 = opponent.position - fighter.position
    return Vector2(delta.x, delta.z).length()


func _reach() -> float:
    var best := 0.0
    for kind: String in ["high_punch", "high_kick", "low_punch", "low_kick"]:
        if fighter.supports_attack(kind):
            best = maxf(best, fighter.attack_reach_world(kind, opponent))
    return best if best > 0.0 else 1.0


func _distance_band() -> String:
    # Same recovered conditions.config thresholds and declared port mapping as
    # NativeAI: close [0,100), medium [100,200), far [200,1000).
    var scale_value: float = PortFighter.ARENA_HALF_X / 400.0
    var separation := _separation()
    if separation < 100.0 * scale_value:
        return "close"
    if separation < 200.0 * scale_value:
        return "medium"
    if separation < 1000.0 * scale_value:
        return "far"
    return "none"

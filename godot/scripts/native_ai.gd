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
##
## Action selection: the shipped action leaves are a *set*, not a priority list.
## `CFighter::AIUpdate` (libdefault.so 0x001a8b2c) scans the current action's
## native link array in source order and follows the first link whose
## `TimeWindowCheck`, action-set/key gate and `CheckConditions` all pass.
## `_native_link_pick()` projects that rule onto the existing recovered
## `PortFighter._native_links` table.  If the native table/methods are usable
## but no link is eligible, the result is a deliberate no-action
## (`native_no_eligible_link`), never the old picker.  The old leaf/action-map
## picker is available only behind an explicit, default-off opt-in and only for
## completely unavailable native data/methods.
##
## Block selection: the existing canblock rows/guard-window diagnostics remain
## in place for `_apply_block` and `_record`; no row value, action variant,
## weight or time window is invented here.
##
## Time windows: the AI gate computes the current action frame against the
## set's authored link `time` / `from_group` windows.  It does not use the
## player-input idle shortcut in PortFighter._native_link_window_ok, which would
## make an idle self-link [120,120] win at frame 0.  The existing
## `guard_window_open` canblock diagnostics are preserved unchanged.

const TREE_PATH := "res://data/native_ai/standard_tree.json"
const PROFILES_PATH := "res://data/native_ai/ai_profiles.json"
const ACTION_MAP_PATH := "res://data/native_ai/action_map.json"
const TUNING_PATH := "res://data/native_ai/tuning.json"
const NativeActionSelector = preload("res://scripts/native_action_selector.gd")

const MAX_WALK := 64
## The native state machine's initial state (CDecisionTree parses a "default"
## state and `treecheckmystate` maps it to `treedefaultbehavior`).
const INITIAL_STATE := "default"

## The complete `my_animation` value domain recovered from the shipped
## `standard.tree`: 18 condition nodes share exactly these 23 case strings.
## `default` is the tree's own fallback child, not an animation name.  The list
## is the order printed by the read-only audit
## (`audit-ai-20261103/out/audit_coverage.txt`, section `my_animation`), which
## was parsed independently from the original `adreno_200/ai/standard.tree`.
const MY_ANIMATION_CASES: Array[String] = [
    "default",
    "facedownidle",
    "faceupidle",
    "idle",
    "idle loming",
    "idle master",
    "idle shenlo",
    "idle sinfu",
    "idle2",
    "idle3",
    "moveback",
    "moveback shenlo",
    "movefwd",
    "movefwd shenlo",
    "moveleft",
    "moveright",
    "skipback",
    "stepback",
    "stepfwd",
    "stepleft",
    "stepleft shenlo",
    "stepright",
    "stepright shenlo",
]
const MY_ANIMATION_FALLBACK := "default"
## Character suffixes that actually occur in the tree's `my_animation` cases:
## `idle loming/master/shenlo/sinfu` and
## `movefwd/moveback/stepleft/stepright shenlo`.  Only those five profile keys
## are listed; every other character reports the generic token.  These are
## exact suffixes from `standard_tree.json` and the kungfu set action table
## (`character-movesets-20261103/evidence/set_action_table_kungfu.md`); no
## suffix is derived from a display name.
const MY_ANIMATION_CHARACTER_SUFFIXES: Dictionary = {
    "lo ming a": "loming",
    "lo ming b": "loming",
    "shen lo": "shenlo",
    "sin fu": "sinfu",
    "the master": "master",
}

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
## Recovered block actions a block leaf can list.  The shipped leaves order them
## by the opponent's attack strength, then by the leaf's own height guess:
##   actionblockhigh/actionblockmedium: highblockbrutal, highblockhard, <height>
##   actionblocklow:                    highblockhard, lowblock
## (the low leaf deliberately carries no brutal variant, so a brutal attack
## against a low guess falls back to the leaf's own guard and the canblock row
## still plays highblockbrutal on impact).
const BLOCK_ACTIONS: Array[String] = [
    "highblockbrutal", "highblockhard", "highblock", "midblock", "lowblock",
]
## Height-specific guards a leaf can hold; these are the `opp_attack_height`
## branches of the tree (doblockguessingheight and *_blockalways).
const BLOCK_GUARD_ACTIONS: Array[String] = ["highblock", "midblock", "lowblock"]
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
## Compact native-link selection diagnostics from the latest step.  The full
## evaluation array is intentionally not retained per decision record.
var last_native_selection: Dictionary = {}
## Compatibility only: the old leaf/action-map picker may be explicitly enabled
## for a caller that cannot supply native links.  Default is off; even when on,
## it is never used for a native table that simply has no eligible link.
var legacy_picker_opt_in: bool = false

var decisions: Array[Dictionary] = []
var _repetition: int = 0
var _last_signature: String = ""
var _opp_last_attack: String = ""
var _opp_repeat: int = 0
var _opp_was_startup: bool = false
var _rng := RandomNumberGenerator.new()

## Diagnostics: how many times each native action was selected and which
## actions could not be dispatched by the current fighting set.  Raw animation
## names outside the recovered 23-case domain are recorded separately; they
## never reach the tree, because `_my_animation()` fails closed to `default`.
var action_counts: Dictionary = {}
var unsupported_actions: Dictionary = {}
var unknown_animation_tokens: Dictionary = {}


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


## Explicit opt-in for the pre-native compatibility picker.  Default is false.
## Environment `BRUCELEE_AI_LEGACY_PICKER=1` is the other explicit switch.
func set_legacy_picker_opt_in(enabled: bool) -> void:
    legacy_picker_opt_in = enabled


func _legacy_picker_enabled() -> bool:
    return legacy_picker_opt_in or OS.get_environment("BRUCELEE_AI_LEGACY_PICKER") == "1"


## Walk the tree once and execute the resulting node.  Returns a decision record
## {"kind", "action", "native", "node", "state", "reason"} for tests/logs.
func step(delta: float) -> Dictionary:
    last_native_selection = {}
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

    # Native CFighter::AIUpdate rule: scan the current action's native links in
    # source order.  A selected link is authoritative.  A usable native table
    # with no eligible link returns no action (no FollowLink); it never falls
    # through to the old picker.  The old picker is an explicit opt-in only for
    # the case where native link methods/data are completely unavailable.
    var native_attempt: Dictionary = _native_link_pick(actions)
    last_native_selection = native_attempt.duplicate(true)
    var picked: Dictionary = {}
    var native_ready: bool = (
        bool(native_attempt.get("available", false))
        and bool(native_attempt.get("ok", false))
    )
    if not native_ready:
        if _legacy_picker_enabled():
            picked = _pick_action(actions)
            last_native_selection["fallback"] = "legacy_picker_opt_in"
        else:
            state = next_state
            last_action = ""
            return _record(
                "none", "", "", node_name, "native_data_unavailable", true
            )
    elif not bool(native_attempt.get("selected", false)):
        state = next_state
        last_action = ""
        return _record(
            "none", "", "", node_name, "native_no_eligible_link", true
        )
    else:
        picked = native_attempt

    var native_action: String = String(picked.get("native", ""))
    var dispatch: String = String(picked.get("dispatch", ""))
    if native_action.is_empty():
        state = next_state
        last_action = ""
        return _record(
            "none", "", "", node_name, "native_no_action_legacy_opt_in", true
        )

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
        _apply_block(native_action)
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
    return _record(kind, dispatch, native_action, node_name, "", true)


func _record(
    kind: String,
    action: String,
    native: String,
    node: String,
    reason: String,
    include_native_selection: bool = false
) -> Dictionary:
    var entry: Dictionary = {
        "kind": kind,
        "action": action,
        "native": native,
        "node": node,
        "state": state,
        "reason": reason,
        "guard_action": fighter.guard_block_action if fighter != null else "",
        "guard_height": fighter.guard_height if fighter != null else "",
        # The authored canblock window that owns this decision.  A closed
        # window means the block leaf failed closed (no guard is held).
        "guard_window": (
            fighter.block_decision_context()
            if fighter != null and is_instance_valid(fighter) else {}
        ),
        "guard_window_open": (
            fighter.guard_window_open()
            if fighter != null and is_instance_valid(fighter) else false
        ),
        # Compact native-link diagnostics.  It records the source-order attempt
        # without persisting the full evaluation list for every decision.
        "native_selection": last_native_selection.duplicate(true) if include_native_selection else {},
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
    return _my_animation_case(_current_native_animation())


func _current_native_animation() -> String:
    ## The port records the current native action in two places:
    ##  * `_locomotion_action` is the action actually playing for walking/skip
    ##    locomotion; `_advance_locomotion_visual()` advances stepfwd -> movefwd
    ##    (and the other three pairs) after the recovered four-frame chain
    ##    window.  The AI runs after `main.gd` zeroes the AI's move_axis, so the
    ##    previous frame's stored locomotion action is the native animation the
    ##    decision tree sees.
    ##  * `state` covers the idle/floor actions and `_current_action_name()`
    ##    returns the native `source_action` for attacks.
    if fighter == null or not is_instance_valid(fighter):
        return ""
    if fighter.state in ["idle", "idle2", "idle3"]:
        var locomotion: String = String(fighter._locomotion_action)
        if not locomotion.is_empty():
            return locomotion
        return fighter.state
    if fighter.state in ["facedownidle", "faceupidle"]:
        return fighter.state
    return String(fighter._current_action_name())


func _my_animation_case(raw: String) -> String:
    ## Resolve one port animation/action name to an exact tree case.
    ##
    ## A character-suffixed variant is used only when both the tree names it and
    ## the fighter's own recovered set contains that action
    ## (`PortFighter._native_actions`, loaded from the set's native_links file).
    ## Anything else - including attack names and `skipfwd`, which has no
    ## `my_animation` case - fails closed to the tree's own `default` branch.
    if raw.is_empty():
        return MY_ANIMATION_FALLBACK
    var suffix: String = _character_animation_suffix()
    if not suffix.is_empty() and fighter != null and is_instance_valid(fighter):
        var suffixed: String = raw + " " + suffix
        if fighter._native_actions.has(suffixed) and MY_ANIMATION_CASES.has(suffixed):
            return suffixed
    if MY_ANIMATION_CASES.has(raw):
        return raw
    unknown_animation_tokens[raw] = int(unknown_animation_tokens.get(raw, 0)) + 1
    return MY_ANIMATION_FALLBACK


func _character_animation_suffix() -> String:
    return String(MY_ANIMATION_CHARACTER_SUFFIXES.get(character_key, ""))


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
    # conditions.config "opp_attack_height" reads the opponent's *current*
    # impact record height (CFighter+0x164 -> +0x18).  The port's equivalent is
    # the source_impact row of the attack the opponent is playing: ATTACKS rows
    # keep it under "source_impact", so reading a top-level "height" always
    # missed and every guess collapsed to the fallback below.
    if opponent == null or not is_instance_valid(opponent):
        return "medium"
    var height: String = String(_opp_impact_metadata().get("height", ""))
    if height in ["high", "medium", "low"]:
        return height
    # Metadata missing (no live attack / no recovered height): the tree still
    # needs a band, and the port's declared fallback is the middle one.
    return "medium"


## The opponent's current impact record metadata, or {} when there is none.
##
## Recovered from CFighter::CheckConditions (oppattackstrength* / oppattackheight*
## read record+0x1C / record+0x18).  The port models that record with the
## `source_impact` block of the attack the opponent is currently playing; it is
## absent whenever no attack is live, which is exactly the "impact metadata
## missing" case every block-selection fallback below names.
func _opp_impact_metadata() -> Dictionary:
    if opponent == null or not is_instance_valid(opponent):
        return {}
    if not opponent.ATTACKS.has(opponent.attack_kind):
        return {}
    var impact_value: Variant = Dictionary(
        opponent.ATTACKS[opponent.attack_kind]
    ).get("source_impact", {})
    if not impact_value is Dictionary:
        return {}
    var impact: Dictionary = impact_value
    var strength: String = String(impact.get("strength", ""))
    if strength.is_empty():
        return {}
    return {
        "height": String(impact.get("height", "")),
        "strength": strength,
    }


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


## Project the proven CFighter::AIUpdate rule onto PortFighter._native_links.
##
## Native evidence: libdefault.so 0x001a8b2c calls TimeWindowCheck, compares
## the link action hash with the terminal action set, checks key sequence/status
## only when the action is not in that set, then calls CheckConditions; the first
## eligible link wins in the active-set link array's source order.
##
## The full selector evaluation is not stored in every decision record.  This
## function returns a compact diagnostic dictionary; the actual selection is
## delegated to NativeActionSelector.select_first_eligible().
func _native_link_pick(actions: Array) -> Dictionary:
    var diag: Dictionary = {
        "available": false,
        "ok": false,
        "selected": false,
        "reason": "native_link_data_unavailable",
        "candidate_count": 0,
        "evaluated_count": 0,
        "link_index": -1,
        "action": "",
        "native": "",
        "dispatch": "",
        "skip_counts": {},
    }
    if fighter == null or not is_instance_valid(fighter):
        diag["reason"] = "no_fighter"
        return diag
    for method: String in [
            "_native_link_applies", "_native_link_unique_ok",
            "_native_link_window_ok", "_native_link_window_for_action",
            "_native_link_conditions_ok", "_link_text"]:
        if not fighter.has_method(method):
            diag["reason"] = "native_link_api_missing:" + method
            return diag
    var links_value: Variant = fighter.get("_native_links")
    if not links_value is Array:
        diag["reason"] = "native_links_missing"
        return diag
    var links: Array = links_value
    if links.is_empty():
        diag["reason"] = "native_links_empty"
        return diag

    var candidates: Array[Dictionary] = []
    var mappings: Array[Dictionary] = []
    var skip_counts: Dictionary = {}
    for index in range(links.size()):
        var link_value: Variant = links[index]
        if not link_value is Dictionary:
            skip_counts["not_dictionary"] = int(skip_counts.get("not_dictionary", 0)) + 1
            continue
        var link: Dictionary = link_value
        if not bool(fighter._native_link_applies(link)):
            skip_counts["not_applies"] = int(skip_counts.get("not_applies", 0)) + 1
            continue
        if not bool(fighter._native_link_unique_ok(link)):
            skip_counts["unique_filtered"] = int(skip_counts.get("unique_filtered", 0)) + 1
            continue
        var target: String = fighter._link_text(link, "to")
        if target.is_empty():
            skip_counts["missing_target"] = int(skip_counts.get("missing_target", 0)) + 1
            continue
        var steps_value: Variant = link.get("steps")
        var status_value: Variant = link.get("status")
        if not steps_value is Array or not status_value is Array:
            skip_counts["missing_gate_data"] = int(skip_counts.get("missing_gate_data", 0)) + 1
            continue
        var steps: Array = steps_value
        var status: Array = status_value
        candidates.append({
            "action": target,
            "time_window_open": _native_link_window_ok_for_ai(link),
            "has_key_sequence": _has_nonempty_step(steps),
            "has_key_status": not status.is_empty(),
            "conditions_pass": _native_link_conditions_ok_for_ai(link),
        })
        mappings.append({
            "link_index": index,
            "link": link,
            "target": target,
            "from": fighter._link_text(link, "from"),
            "from_group": fighter._link_text(link, "from_group"),
        })

    diag["available"] = true
    diag["candidate_count"] = candidates.size()
    diag["skip_counts"] = skip_counts
    if candidates.is_empty():
        diag["ok"] = true
        diag["reason"] = "no_applicable_links"
        return diag

    var result: Dictionary = NativeActionSelector.select_first_eligible(candidates, actions)
    diag["ok"] = bool(result.get("ok", false))
    diag["reason"] = String(result.get("reason", ""))
    var evaluations: Array = Array(result.get("evaluations", []))
    diag["evaluated_count"] = evaluations.size()
    if not bool(diag["ok"]):
        diag["selected"] = false
        return diag
    if not bool(result.get("selected", false)):
        diag["selected"] = false
        return diag

    var candidate_index: int = int(result.get("index", -1))
    if candidate_index < 0 or candidate_index >= mappings.size():
        diag["ok"] = false
        diag["reason"] = "selector_index_out_of_range"
        return diag
    var mapping: Dictionary = mappings[candidate_index]
    var link: Dictionary = mapping["link"]
    var selected_candidate: Dictionary = candidates[candidate_index]
    var dispatch: String = _dispatch_for_native(link)
    diag["selected"] = true
    diag["index"] = candidate_index
    diag["link_index"] = int(mapping["link_index"])
    diag["action"] = String(mapping["target"])
    diag["native"] = String(mapping["target"])
    diag["link_from"] = String(mapping["from"])
    diag["link_from_group"] = String(mapping["from_group"])
    diag["dispatch"] = dispatch
    diag["has_key_sequence"] = bool(selected_candidate.get("has_key_sequence", false))
    diag["has_key_status"] = bool(selected_candidate.get("has_key_status", false))
    diag["time_window_open"] = bool(selected_candidate.get("time_window_open", false))
    diag["conditions_pass"] = bool(selected_candidate.get("conditions_pass", false))
    if dispatch.is_empty():
        diag["reason"] = "native_link_unmapped"
    for evaluation_value: Variant in evaluations:
        if not evaluation_value is Dictionary:
            continue
        var evaluation: Dictionary = evaluation_value
        if int(evaluation.get("index", -1)) != candidate_index:
            continue
        diag["listed"] = bool(evaluation.get("listed", false))
        diag["gate_reason"] = String(evaluation.get("gate_reason", ""))
        break
    return diag


func _has_nonempty_step(steps: Array) -> bool:
    for step_value: Variant in steps:
        if step_value is Array and not Array(step_value).is_empty():
            return true
    return false


## Native CheckConditions `impact` is not the port's hit-bookkeeping flag.
##
## Decompiled `krm::CFighter::CheckConditions` @0x001b3920 (the branch reached
## from `IsAttacking(other)` @0x001b02c4) checks:
##   - other+0x164 != 0       -> the opponent has a current impact record
##   - distance <= radius     -> impact+0x10 * attacker+0x15C + defender radius
##   - other+0x16c <= impact+0 -> impact has not already been processed
## The port's `_attack_hit_landed` flips only after contact, so using it here
## made every canblock link fail during the opponent's startup.  For the AI
## decision path, use the live opponent attack/impact record and the recovered
## reach formula instead.
func _native_impact_condition_ok() -> bool:
    if opponent == null or not is_instance_valid(opponent):
        return false
    if opponent.state not in ["startup", "active"]:
        return false
    if opponent.attack_kind.is_empty() or not opponent.ATTACKS.has(opponent.attack_kind):
        return false
    if _opp_impact_metadata().is_empty():
        return false
    # attack_reach_world() adds the defender source radius, matching the native
    # formula's GetRadius(this) term.
    if _separation() > opponent.attack_reach_world(opponent.attack_kind, fighter):
        return false
    # The native high-water comparison prevents reusing an already-consumed
    # impact.  The port's equivalent consumed marker is _attack_hit_landed.
    if bool(opponent._attack_hit_landed):
        return false
    return true


func _native_link_conditions_ok_for_ai(link: Dictionary) -> bool:
    for condition_value: Variant in Array(link.get("conditions", [])):
        var condition: String = String(condition_value)
        if not _native_condition_ok_for_ai(condition, link):
            return false
    return true


func _native_condition_ok_for_ai(condition: String, link: Dictionary) -> bool:
    # One evaluator for every caller: the fighter's canonical CheckConditions
    # probe models the live opponent impact record (+0x164/+0x168), IsAttacking,
    # the distance formula and the processed-impact high-water.  prefer_next is
    # the AI's pre-contact projection (BasicUpdate +0x168) so a guard can be
    # selected before the impact frame; link/reaction paths stay exact.
    return bool(fighter._native_condition_ok(condition, link, true))


## Native TimeWindowCheck projection for the AI link scan.  PortFighter's
## _native_link_window_ok() intentionally opens idle for the *player input* path;
## native AIUpdate must still test the idle animation's own source frame against
## the link window (otherwise idle->idle [120,120] would win at frame 0).
func _native_link_window_ok_for_ai(link: Dictionary) -> bool:
    if fighter == null or not is_instance_valid(fighter):
        return false
    var action: String = fighter._current_action_name()
    var window: Array = fighter._native_link_window_for_action(link, action)
    if window.size() < 2:
        return false
    var frame: float
    if fighter.state in ["idle", "idle2", "idle3", "facedownidle", "faceupidle"]:
        frame = fighter.state_time * float(PortFighter.SOURCE_FRAME_RATE)
    else:
        frame = fighter._current_attack_source_frame()
    if frame < 0.0:
        return false
    var start: float = float(window[0])
    var end: float = float(window[1])
    if window.size() >= 3:
        start = maxf(start, float(window[2]))
    var linking_frame: int = int(link.get("linking_frame", 0))
    if linking_frame > 0 and frame + 0.0001 < float(linking_frame):
        return false
    return frame + 0.0001 >= start and frame <= end + 0.0001


func _dispatch_for_native(link: Dictionary) -> String:
    if fighter == null or not is_instance_valid(fighter):
        return ""
    var target: String = fighter._link_text(link, "to")
    if target.is_empty():
        return ""
    if fighter.has_method("_native_target_kind"):
        var target_kind: String = String(fighter._native_target_kind(link))
        if not target_kind.is_empty() and (
                target_kind.begins_with("__") or fighter.supports_attack(target_kind)):
            return target_kind
    for slot_value: Variant in Array(action_map.get(_action_base(target), [])):
        var slot: String = String(slot_value)
        if slot.begins_with("__"):
            return slot
        if fighter.supports_attack(slot):
            return slot
    return ""


## Choose among the leaf's alternatives.  The shipped tree lists one entry per
## character ("specialkicklow brick", "specialkicklow chief", ...).  The native
## node picks the entry belonging to the fighter, so entries naming another
## character must not be used: their set row carries that character's rage cost
## and animation.  Order: this character's entry, then the generic entry, then
## anything the fighting set actually supports.
func _pick_action(actions: Array) -> Dictionary:
    # A block leaf is resolved through the recovered canblock rows before the
    # generic per-character pick, so the native high/mid/low (and hard/brutal)
    # guard selection survives instead of collapsing into one block token.
    var block_choice: String = _block_choice(actions)
    if not block_choice.is_empty():
        var block_token: String = _block_dispatch(block_choice)
        if not block_token.is_empty():
            return {"native": block_choice, "dispatch": block_token}
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


## Choose the guard a block leaf holds, from the leaf's own action list.
##
## The shipped tree already encodes the recovered canblock rows in that list: a
## leaf lists the strength variants (highblockbrutal, highblockhard) followed by
## the block for the height the tree's `opp_attack_height` branch selected.  The
## matching is therefore done against the rows themselves
## (PortFighter.canblock_row_for) using the opponent's current impact record, so
## the port never re-derives the mapping:
##   * a recovered row for the opponent's strength/height names the action to
##     hold - e.g. normal+low -> lowblock, hard+anything -> highblockhard;
##   * the row's target must be in this leaf's list, otherwise the leaf cannot
##     play it (the low leaf has no highblockbrutal) and the fallback applies.
## Fallbacks:
##   * no impact metadata (no live attack or no recovered strength) -> the
##     leaf's height-specific guard, i.e. the tree's own height guess;
##   * nothing recognised -> the first listed block action, and finally "" so
##     _pick_action keeps its existing generic priority.
func _block_choice(actions: Array) -> String:
    var candidates: Array[String] = []
    for value: Variant in actions:
        var native: String = String(value)
        if BLOCK_ACTIONS.has(_action_base(native)):
            candidates.append(native)
    if candidates.is_empty():
        return ""
    var metadata: Dictionary = _opp_impact_metadata()
    if not metadata.is_empty():
        var row: Dictionary = PortFighter.canblock_row_for(
            String(metadata.get("strength", "")),
            String(metadata.get("height", ""))
        )
        var target: String = String(row.get("target", ""))
        if not target.is_empty():
            for native: String in candidates:
                if _action_base(native) == target:
                    return native
    for native: String in candidates:
        if BLOCK_GUARD_ACTIONS.has(_action_base(native)):
            return native
    return candidates[0]


func _block_dispatch(native: String) -> String:
    for slot_value: Variant in Array(action_map.get(_action_base(native), [])):
        var slot: String = String(slot_value)
        if slot.begins_with("__block"):
            return slot
    return ""


func _apply_attack(native: String, kind: String) -> bool:
    # PortFighter.request_attack() refuses while guarding, so a tree decision
    # to attack must drop the guard first (the native block action ends when the
    # next decision picks a different action).
    fighter.end_guard()
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


func _apply_block(native_action: String) -> void:
    # Native highblock/midblock/lowblock (+ the hard/brutal block rows): the tree
    # names the guard action, so the fighter holds that selection instead of a
    # bare flag.  A block leaf is a block/guard *decision* and is therefore only
    # valid while the fighter's current action is inside its authored
    # canblock/canblock2 window.  Outside (or with no authored window) it fails
    # closed: no guard is held, so no contact can be blocked.  The contact gate
    # in PortFighter._can_block_current_hit enforces the same rule at impact.
    if not fighter.guard_window_open():
        fighter.end_guard()
        return
    # An entry that is not a recovered block action keeps the port's
    # unqualified guard.
    if not fighter.begin_block(_action_base(native_action)):
        fighter.begin_guard()


func _apply_idle() -> void:
    fighter.end_guard()
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
    fighter.end_guard()
    var to_opponent: Vector3 = opponent.position - fighter.position
    var forward: float = signf(to_opponent.x)
    var lateral: float = signf(to_opponent.z)
    var hold: float = 1.0
    if not fighter.polar_movement_enabled:
        # A world-space fighter (the opponent AI) must advance along the full
        # opponent vector, not just its x sign; otherwise a side-stepping
        # player leaves a permanent z gap that stepfwd can never close.
        var toward: Vector2 = Vector2(to_opponent.x, to_opponent.z)
        if toward.length_squared() > 0.000001:
            toward = toward.normalized()
        match token:
            DISPATCH_MOVE_FWD, DISPATCH_STEP_FWD:
                fighter.move_axis = toward
            DISPATCH_SKIP_FWD:
                fighter.move_axis = toward * 1.5
            DISPATCH_MOVE_BACK, DISPATCH_STEP_BACK:
                fighter.move_axis = -toward * 0.6
            DISPATCH_SKIP_BACK:
                fighter.move_axis = -toward
            DISPATCH_MOVE_LEFT, DISPATCH_STEP_LEFT:
                fighter.move_axis = Vector2(-toward.y, toward.x)
            DISPATCH_MOVE_RIGHT, DISPATCH_STEP_RIGHT:
                fighter.move_axis = Vector2(toward.y, -toward.x)
        fighter.move_axis *= hold
        return
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

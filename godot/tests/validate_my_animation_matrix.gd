extends SceneTree
## Headless acceptance test for the recovered `my_animation` condition matrix.
##
## The expected domain is the 23 case strings parsed from
## `adreno_200/ai/standard.tree` (same list as
## `audit-ai-20261103/out/audit_coverage.txt`).  The test also exercises the
## runtime mapper with real PortFighter state/locomotion values and the native
## action tables, then proves unknown tokens fail closed to `default`.

const NativeAIScript = preload("res://scripts/native_ai.gd")

const EXPECTED_CASES: Array[String] = [
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

var failures: Array[String] = []
var checks: int = 0
var produced: Dictionary = {}


func _initialize() -> void:
    call_deferred("_run")


func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)
        push_error("MY_ANIMATION_MATRIX_FAIL: " + message)


func _run() -> void:
    var ai: RefCounted = NativeAIScript.new()
    if not ai.load_data():
        _check(false, "native AI data failed to load: " + String(ai.load_error))
        _finish()
        return

    _check_tree_matrix(ai)
    _check_runtime_mapping(ai)
    _finish()


# --- tree condition matrix -------------------------------------------------


func _check_tree_matrix(ai: RefCounted) -> void:
    var nodes: Array[Dictionary] = []
    # The shipped tree is a flat top-level node map; root references only some
    # of it.  Walk every top-level node and its inline children.
    for node_name: String in ai.tree:
        var node_value: Variant = ai.tree[node_name]
        if node_value is Dictionary:
            _collect_animation_nodes(node_value, node_name, nodes)
    _check(nodes.size() == 18, "my_animation node count %d != 18" % nodes.size())

    var seen: Dictionary = {}
    for node: Dictionary in nodes:
        var has_default: bool = false
        var path: String = String(node.get("_path", ""))
        for child_value: Variant in Array(node.get("children", [])):
            if not child_value is Dictionary:
                continue
            var child: Dictionary = child_value
            var case_name: String = String(child.get("case", ""))
            seen[case_name] = true
            if case_name == "default":
                has_default = true
            var picked: Dictionary = ai._pick_child(node, case_name)
            _check(
                String(picked.get("case", "")) == case_name,
                "%s: _pick_child(%s) returned %s" % [path, case_name, picked]
            )
        _check(has_default, "%s: no default child" % path)

    var actual: Array[String] = []
    for key: Variant in seen.keys():
        actual.append(String(key))
    actual.sort()
    var expected: Array[String] = EXPECTED_CASES.duplicate()
    expected.sort()
    _check(actual == expected, "tree cases %s != expected %s" % [actual, expected])

    var constant_cases: Array[String] = []
    for value: Variant in NativeAIScript.MY_ANIMATION_CASES:
        constant_cases.append(String(value))
    constant_cases.sort()
    _check(
        constant_cases == expected,
        "MY_ANIMATION_CASES %s != tree/audit %s" % [constant_cases, expected]
    )
    _check(
        String(NativeAIScript.MY_ANIMATION_FALLBACK) == "default",
        "MY_ANIMATION_FALLBACK must be the tree's default case"
    )

    # Every one of the 23 tokens must reach a child on every my_animation node;
    # nodes without an explicit case must use their default child.
    for node: Dictionary in nodes:
        for token: String in EXPECTED_CASES:
            var picked: Dictionary = ai._pick_child(node, token)
            _check(not picked.is_empty(), "%s: no child for token %s" % [node.get("_path", ""), token])

    # The mapper must accept every whitelisted token verbatim when no character
    # suffix applies, and reject tokens outside the domain.
    for token: String in EXPECTED_CASES:
        _check(
            String(ai._my_animation_case(token)) == token,
            "_my_animation_case(%s) did not return the whitelisted token" % token
        )
    for token: String in ["", "lowpunch1", "specialkicklow brick", "skipfwd", "movefwd foo"]:
        _check(
            String(ai._my_animation_case(token)) == "default",
            "_my_animation_case(%s) did not fail closed to default" % token
        )
    print("MY_ANIMATION_MATRIX_CHECK nodes=%d cases=%d" % [nodes.size(), EXPECTED_CASES.size()])


func _collect_animation_nodes(
    node: Variant, path: String, out: Array[Dictionary]
) -> void:
    if not node is Dictionary:
        return
    var dict: Dictionary = node
    if String(dict.get("condition", "")) == "my_animation":
        var copy: Dictionary = dict.duplicate(true)
        copy["_path"] = path
        out.append(copy)
    for index: int in range(Array(dict.get("children", [])).size()):
        var child_value: Variant = Array(dict.get("children", []))[index]
        if not child_value is Dictionary:
            continue
        var child: Dictionary = child_value
        _collect_animation_nodes(
            child,
            path + "/" + String(child.get("case", "?")) + "#" + str(index),
            out
        )


# --- runtime mapper --------------------------------------------------------


func _check_runtime_mapping(ai: RefCounted) -> void:
    var kungfu: Dictionary = _load_action_table("res://data/native_links_kungfu.json")
    var thai: Dictionary = _load_action_table("res://data/native_links_brick.json")
    _check(kungfu.has("idle shenlo"), "kungfu set lost idle shenlo")
    _check(kungfu.has("movefwd shenlo"), "kungfu set lost movefwd shenlo")
    _check(kungfu.has("moveback shenlo"), "kungfu set lost moveback shenlo")
    _check(kungfu.has("stepleft shenlo"), "kungfu set lost stepleft shenlo")
    _check(kungfu.has("stepright shenlo"), "kungfu set lost stepright shenlo")

    var fighter := PortFighter.new()
    ai.fighter = fighter
    ai.unknown_animation_tokens.clear()

    # Idle: generic characters report idle; the four kungfu characters whose
    # shipped set carries a distinct idle action report that exact action.
    _expect(ai, fighter, "brick davis", "idle", "", thai, "idle")
    _expect(ai, fighter, "the master", "idle", "", kungfu, "idle master")
    _expect(ai, fighter, "lo ming a", "idle", "", kungfu, "idle loming")
    _expect(ai, fighter, "lo ming b", "idle", "", kungfu, "idle loming")
    _expect(ai, fighter, "shen lo", "idle", "", kungfu, "idle shenlo")
    _expect(ai, fighter, "sin fu", "idle", "", kungfu, "idle sinfu")
    _expect(ai, fighter, "shen lo", "idle2", "", kungfu, "idle2")
    _expect(ai, fighter, "shen lo", "idle3", "", kungfu, "idle3")
    _expect(ai, fighter, "brick davis", "facedownidle", "", thai, "facedownidle")
    _expect(ai, fighter, "brick davis", "faceupidle", "", thai, "faceupidle")

    # Generic locomotion from the thai set.
    for token: String in [
        "movefwd", "moveback", "moveleft", "moveright",
        "skipback", "stepback", "stepfwd", "stepleft", "stepright",
    ]:
        _expect(ai, fighter, "brick davis", "idle", token, thai, token)

    # ShenLo's recovered kungfu set names four movement variants explicitly.
    _expect(ai, fighter, "shen lo", "idle", "movefwd", kungfu, "movefwd shenlo")
    _expect(ai, fighter, "shen lo", "idle", "moveback", kungfu, "moveback shenlo")
    _expect(ai, fighter, "shen lo", "idle", "stepleft", kungfu, "stepleft shenlo")
    _expect(ai, fighter, "shen lo", "idle", "stepright", kungfu, "stepright shenlo")
    # No suffixed variants exist for these; do not invent them.
    _expect(ai, fighter, "shen lo", "idle", "stepfwd", kungfu, "stepfwd")
    _expect(ai, fighter, "shen lo", "idle", "moveleft", kungfu, "moveleft")
    _expect(ai, fighter, "shen lo", "idle", "moveright", kungfu, "moveright")
    # The same set-wide shenlo actions must not be borrowed by other characters.
    _expect(ai, fighter, "the master", "idle", "movefwd", kungfu, "movefwd")
    _expect(ai, fighter, "the master", "idle", "stepleft", kungfu, "stepleft")

    # Unknown animation tokens fail closed.  skipfwd has no my_animation case
    # in the shipped tree, and attack source actions are outside the domain.
    _expect(ai, fighter, "brick davis", "idle", "skipfwd", thai, "default")
    _check(
        int(ai.unknown_animation_tokens.get("skipfwd", 0)) == 1,
        "skipfwd was not recorded as an unknown token"
    )
    fighter._locomotion_action = ""
    fighter.state = "startup"
    fighter.attack_kind = "punch"
    fighter.ATTACKS = {"punch": {"source_action": "lowpunch1"}}
    _check(String(ai._my_animation()) == "default", "attack lowpunch1 did not fail closed")
    fighter.ATTACKS = {"punch": {"source_action": "specialkicklow brick"}}
    _check(
        String(ai._my_animation()) == "default",
        "suffixed attack specialkicklow brick did not fail closed"
    )
    _check(
        int(ai.unknown_animation_tokens.get("lowpunch1", 0)) == 1,
        "lowpunch1 was not recorded as an unknown token"
    )

    var expected: Array[String] = EXPECTED_CASES.duplicate()
    expected.sort()
    var actual: Array[String] = []
    for key: Variant in produced.keys():
        actual.append(String(key))
    actual.sort()
    _check(actual == expected, "runtime mapper produced %s, expected %s" % [actual, expected])
    fighter.free()


func _load_action_table(path: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    var table: Dictionary = {}
    if not parsed is Dictionary:
        return table
    for row_value: Variant in Array(Dictionary(parsed).get("actions", [])):
        if row_value is Dictionary:
            var row: Dictionary = row_value
            table[String(row.get("name", ""))] = row
    return table


func _expect(
    ai: RefCounted,
    fighter: PortFighter,
    character_key: String,
    state: String,
    locomotion: String,
    native_actions: Dictionary,
    expected: String
) -> void:
    ai.character_key = character_key
    fighter.state = state
    fighter._locomotion_action = locomotion
    fighter._native_actions = native_actions
    var actual: String = String(ai._my_animation())
    _check(
        actual == expected,
        "%s state=%s locomotion=%s -> %s, expected %s"
        % [character_key, state, locomotion, actual, expected]
    )
    if actual == expected:
        produced[actual] = true


func _finish() -> void:
    var payload: Dictionary = {
        "checks": checks,
        "failed": failures,
        "produced": produced.keys(),
    }
    if failures.is_empty():
        print("MY_ANIMATION_MATRIX_VALIDATION=" + JSON.stringify(payload))
        quit(0)
    else:
        print("MY_ANIMATION_MATRIX_VALIDATION=" + JSON.stringify(payload))
        for failure: String in failures:
            print("  - " + failure)
        quit(1)

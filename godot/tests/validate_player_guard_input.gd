extends SceneTree
## Headless acceptance test for the player's direct-input guard.
##
## Usage (single headless invocation, no editor import / no windows):
##   godot --headless --path <project> \
##         --script res://tests/validate_player_guard_input.gd
##
## Native evidence:
##   * every canblock/canblock2 link in all four shipped sets requires exactly
##     `left` + `pressed` in all three layout variants; none carries a height or
##     attack token;
##   * data/training_native.json's block lessons are `hold left` and list
##     highblock/lowblock/midblock as the success outcomes;
##   * data/lang/training_lang.json says "Press and hold Left ... to block all
##     attacks", and its loading tip says changing *attack* height breaks the
##     rival's defense.
##
## Therefore the direct-input guard has one proven gesture and no high/mid/low
## height token.  The test locks that negative result: every token, including
## up/down/a/b/c/d/f, must resolve to an empty height, and a token set without
## `left` must fail closed.

const SET_FILES: Array[String] = [
    "res://data/native_links.json",
    "res://data/native_links_brick.json",
    "res://data/native_links_karate.json",
    "res://data/native_links_kungfu.json",
]
const BLOCK_TARGETS: Array[String] = [
    "highblock", "lowblock", "midblock", "highblockhard", "highblockbrutal",
]
## strength, height, target action, guard height band.
const IMPACT_MATRIX: Array[Array] = [
    ["normal", "low", "lowblock", "low"],
    ["normal", "medium", "midblock", "medium"],
    ["normal", "high", "highblock", "high"],
    ["hard", "low", "highblockhard", "high"],
    ["hard", "medium", "highblockhard", "high"],
    ["hard", "high", "highblockhard", "high"],
    ["brutal", "low", "highblockbrutal", "high"],
    ["brutal", "medium", "highblockbrutal", "high"],
    ["brutal", "high", "highblockbrutal", "high"],
]
## Held-token sets that still raise the unqualified guard (extra tokens are
## allowed by InputStatusCheck, but none may add a height).
const GUARD_TRUE_CASES: Array[Array] = [
    ["left"],
    ["left", "up"],
    ["left", "down"],
    ["left", "in"],
    ["left", "out"],
    ["left", "a"],
    ["left", "b"],
    ["left", "c"],
    ["left", "d"],
    ["left", "f"],
    ["right", "left"],
]
## Held-token sets without the recovered guard token must fail closed.
const GUARD_FALSE_CASES: Array[Array] = [
    [],
    ["up"],
    ["down"],
    ["in"],
    ["out"],
    ["right"],
    ["a"],
    ["b"],
    ["c"],
    ["d"],
    ["f"],
]

var failures: Array[String] = []
var checks: int = 0
var block_links_checked: int = 0


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    failures.append(message)
    push_error("PLAYER_GUARD_INPUT_FAIL: " + message)


func _check(name: String, actual: Variant, expected: Variant) -> void:
    checks += 1
    if actual != expected:
        _fail("%s: actual=%s expected=%s" % [
            name, JSON.stringify(actual), JSON.stringify(expected)])


func _ok(name: String, condition: bool) -> void:
    _check(name, condition, true)


func _load_json(path: String) -> Dictionary:
    checks += 1
    var text: String = FileAccess.get_file_as_string(path)
    if text.is_empty():
        _fail("cannot read " + path)
        return {}
    var parsed: Variant = JSON.parse_string(text)
    if not parsed is Dictionary:
        _fail("invalid JSON in " + path)
        return {}
    return parsed


func _status_key(variant: Variant) -> String:
    var parts: Array[String] = []
    if not variant is Array:
        return "<not-array>"
    for pair_value: Variant in Array(variant):
        if not pair_value is Array:
            parts.append("<not-pair>")
            continue
        var pair: Array = Array(pair_value)
        if pair.size() < 2:
            parts.append("<short-pair>")
            continue
        parts.append("%s:%s" % [str(pair[0]), str(pair[1])])
    return ",".join(parts)


# --- 1: every block link requires exactly left:pressed ---------------------


func _check_native_block_rows() -> void:
    _ok("DIRECT_GUARD_STATUS is the recovered left token",
        PortFighter.DIRECT_GUARD_STATUS == "left")
    _ok("no direct-input token -> height row is recovered",
        PortFighter.DIRECT_GUARD_HEIGHT_BY_TOKEN.is_empty())

    for path: String in SET_FILES:
        var data: Dictionary = _load_json(path)
        if data.is_empty():
            continue
        var links: Array = Array(data.get("links", []))
        var targets: Dictionary = {}
        var found: int = 0
        for link_value: Variant in links:
            if not link_value is Dictionary:
                continue
            var link: Dictionary = link_value
            var target: String = String(link.get("to", ""))
            if target not in BLOCK_TARGETS:
                continue
            found += 1
            block_links_checked += 1
            targets[target] = int(targets.get(target, 0)) + 1

            # keysequence must be empty in all layout variants: the guard is a
            # held status, not a press sequence.
            var sequences: Array = Array(link.get("keysequence", []))
            _check(path + " order " + str(link.get("order", -1)) + " sequence variants",
                sequences.size(), 3)
            for index: int in range(sequences.size()):
                _check(path + " order " + str(link.get("order", -1)) + " sequence " + str(index),
                    Array(sequences[index]).is_empty(), true)

            # Every layout variant must be exactly [left, pressed].
            var statuses: Array = Array(link.get("keystatus", []))
            _check(path + " order " + str(link.get("order", -1)) + " status variants",
                statuses.size(), 3)
            for index: int in range(statuses.size()):
                _check(path + " order " + str(link.get("order", -1)) + " status " + str(index),
                    _status_key(statuses[index]), "left:pressed")

            var conditions: Array = Array(link.get("conditions", []))
            _ok(path + " order " + str(link.get("order", -1)) + " has impact condition",
                conditions.has("impact"))
        _check(path + " block link count", found, 10)
        _check(path + " block target set", targets.keys().size(), 5)
        for target: String in BLOCK_TARGETS:
            _check(path + " target count " + target, int(targets.get(target, 0)), 2)


# --- 2: no token selects a height -----------------------------------------


func _check_height_token_matrix() -> void:
    for token: String in ["left", "right", "up", "down", "in", "out",
            "a", "b", "c", "d", "f", ""]:
        _check("direct_guard_height_for(%s)" % [token],
            PortFighter.direct_guard_height_for(token), "")

    for tokens: Array in GUARD_TRUE_CASES:
        var decision: Dictionary = PortFighter.direct_guard_input(tokens)
        _check("guard tokens " + str(tokens) + " guard",
            bool(decision.get("guard", false)), true)
        _check("guard tokens " + str(tokens) + " height",
            String(decision.get("height", "")), "")
        _check("guard tokens " + str(tokens) + " action",
            String(decision.get("action", "")), "")

    for tokens: Array in GUARD_FALSE_CASES:
        var decision: Dictionary = PortFighter.direct_guard_input(tokens)
        _check("no-guard tokens " + str(tokens) + " guard",
            bool(decision.get("guard", false)), false)
        _check("no-guard tokens " + str(tokens) + " height",
            String(decision.get("height", "")), "")


# --- 3: real fighter state stays unqualified -------------------------------


func _check_fighter_state() -> void:
    var fighter: PortFighter = PortFighter.new()
    fighter.begin_guard()
    _ok("begin_guard raises guard", fighter.guard_held)
    _check("begin_guard height", fighter.guard_height, "")
    _check("begin_guard action", fighter.guard_block_action, "")

    fighter.end_guard()
    _ok("end_guard clears guard", not fighter.guard_held)
    _check("end_guard height", fighter.guard_height, "")

    _ok("left+down raises unqualified guard",
        fighter.begin_guard_from_input(["left", "down"]))
    _check("left+down height", fighter.guard_height, "")
    _check("left+down action", fighter.guard_block_action, "")

    fighter.end_guard()
    _ok("down alone fails closed",
        not fighter.begin_guard_from_input(["down"]))
    _ok("down alone leaves guard down", not fighter.guard_held)
    _check("down alone height", fighter.guard_height, "")

    fighter.begin_guard()
    _ok("AI block action still sets height", fighter.begin_block("lowblock"))
    _check("AI lowblock height", fighter.guard_height, "low")
    _check("AI lowblock action", fighter.guard_block_action, "lowblock")
    _ok("unknown block action fails closed", not fighter.begin_block("not-a-block"))
    fighter.end_guard()
    fighter.free()


# --- 4: height is selected by the incoming impact, not by input -----------


func _check_impact_matrix() -> void:
    for row: Array in IMPACT_MATRIX:
        var strength: String = String(row[0])
        var height: String = String(row[1])
        var expected_action: String = String(row[2])
        var expected_band: String = String(row[3])
        var resolved: Dictionary = PortFighter.canblock_row_for(strength, height)
        _check("%s/%s row target" % [strength, height],
            String(resolved.get("target", "")), expected_action)
        _check("%s/%s guard band" % [strength, height],
            PortFighter.block_guard_height(expected_action), expected_band)
    _ok("unencoded medium strength fails closed",
        PortFighter.canblock_row_for("medium", "high").is_empty())
    _ok("unknown height fails closed",
        PortFighter.canblock_row_for("normal", "unknown").is_empty())


# --- 5: the shipped training/help data says hold left, no height ----------


func _check_training_data() -> void:
    var training: Dictionary = _load_json("res://data/training_native.json")
    var block_steps: int = 0
    for training_value: Variant in Array(training.get("trainings", [])):
        if not training_value is Dictionary:
            continue
        var training_row: Dictionary = training_value
        for step_value: Variant in Array(training_row.get("steps", [])):
            if not step_value is Dictionary:
                continue
            var step: Dictionary = step_value
            var title: String = str(step.get("input_title_key", ""))
            if title not in ["block", "blockagain"]:
                continue
            block_steps += 1
            _check("training %s input sample" % [title],
                step.get("input_sample", []), ["hold", "left"])
            var animations: Array = Array(step.get("success_animations", []))
            for action: String in ["highblock", "lowblock", "midblock"]:
                _ok("training %s success includes %s" % [title, action],
                    animations.has(action))
    _ok("training has at least two block lessons", block_steps >= 2)

    var lang: Dictionary = _load_json("res://data/lang/training_lang.json")
    var keys_value: Variant = lang.get("keys", {})
    var keys: Dictionary = keys_value if keys_value is Dictionary else {}
    var help_value: Variant = keys.get("defense_training_1_help", {})
    var help: String = ""
    if help_value is Dictionary:
        help = String(Dictionary(help_value).get("LangEnglish", ""))
    _ok("training help says hold Left", help.contains("Press and hold Left"))
    _ok("training help says block all attacks", help.contains("block all attacks"))
    var tip_value: Variant = keys.get("loading1", {})
    var tip: String = ""
    if tip_value is Dictionary:
        tip = String(Dictionary(tip_value).get("LangEnglish", ""))
    _ok("loading tip makes attack height the defense breaker",
        tip.contains("attack height") and tip.contains("defense"))


func _run() -> void:
    _check_native_block_rows()
    _check_height_token_matrix()
    _check_fighter_state()
    _check_impact_matrix()
    _check_training_data()
    print("PLAYER_GUARD_INPUT_CHECK block_links=%d checks=%d failures=%d" % [
        block_links_checked, checks, failures.size()])
    if failures.is_empty():
        print("PLAYER_GUARD_INPUT_VALIDATION=PASS")
        quit(0)
    else:
        for failure: String in failures:
            push_error("PLAYER_GUARD_INPUT_FAIL: " + failure)
        print("PLAYER_GUARD_INPUT_VALIDATION=FAIL")
        quit(1)

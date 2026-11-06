extends SceneTree
## Headless acceptance test for the recovered high/mid/low block selection.
##
## Usage:
##   godot --headless --path <project> \
##         --script res://tests/validate_ai_block_heights.gd -- <bruce.glb> <brick.glb>
##
## The candidate GLBs are optional: every assertion below runs against the
## shipped data (data/native_links.json, the fighting-set attack configs and
## data/native_ai), so the test also runs without them.
##
## Asserts:
##   1. PortFighter.CANBLOCK_ROWS equals the exported canblock/canblock2 rows
##      (strength, height token, target action, link order);
##   2. the guard-action -> height map covers exactly those row targets;
##   3. the standing block gate follows the rows: every recovered impact row is
##      blockable while any recovered guard is held, an impact whose
##      strength/height has no row is not, and an impact record without metadata
##      (or an unqualified guard) keeps the port's legacy unconditional block;
##   4. a blocked hit resolves to the row's target animation, and a blocked
##      contact without metadata falls back to the guard action being held;
##   5. the AI block leaves select the guard through those rows using the
##      opponent's current impact strength/height, and fall back to the leaf's
##      own height guess when that metadata is missing;
##   6. a live AI guard decision carries the selected guard into the fighter.

## strength, height, canblock target.  brucelee.set orders 92-101.
const MATRIX: Array[Array] = [
    ["normal", "low", "lowblock"],
    ["normal", "medium", "midblock"],
    ["normal", "high", "highblock"],
    ["hard", "low", "highblockhard"],
    ["hard", "medium", "highblockhard"],
    ["hard", "high", "highblockhard"],
    ["brutal", "low", "highblockbrutal"],
    ["brutal", "medium", "highblockbrutal"],
    ["brutal", "high", "highblockbrutal"],
]
## Per-leaf expectations for the shipped action lists.  A leaf can only hold an
## action it lists; when the recovered row target is absent the leaf's own
## height guess is the fallback.
const LEAF_EXPECT: Array[Array] = [
    # strength, height, leaf, expected guard action
    ["normal", "low", "actionblockhigh", "highblock"],
    ["normal", "low", "actionblockmedium", "midblock"],
    ["normal", "low", "actionblocklow", "lowblock"],
    ["normal", "medium", "actionblockhigh", "highblock"],
    ["normal", "medium", "actionblockmedium", "midblock"],
    ["normal", "medium", "actionblocklow", "lowblock"],
    ["normal", "high", "actionblockhigh", "highblock"],
    ["normal", "high", "actionblockmedium", "midblock"],
    ["normal", "high", "actionblocklow", "lowblock"],
    ["hard", "low", "actionblockhigh", "highblockhard"],
    ["hard", "low", "actionblockmedium", "highblockhard"],
    ["hard", "low", "actionblocklow", "highblockhard"],
    ["hard", "medium", "actionblockhigh", "highblockhard"],
    ["hard", "medium", "actionblockmedium", "highblockhard"],
    ["hard", "medium", "actionblocklow", "highblockhard"],
    ["hard", "high", "actionblockhigh", "highblockhard"],
    ["hard", "high", "actionblockmedium", "highblockhard"],
    ["hard", "high", "actionblocklow", "highblockhard"],
    # the shipped low leaf carries no highblockbrutal (only highblockhard and
    # lowblock), so a brutal attack against its guess falls back to lowblock.
    ["brutal", "medium", "actionblockhigh", "highblockbrutal"],
    ["brutal", "medium", "actionblockmedium", "highblockbrutal"],
    ["brutal", "medium", "actionblocklow", "lowblock"],
]

var failures: Array[String] = []


## JSON null arrives as Variant nil; str(nil) is "<null>", so nulls are
## normalised here instead of being passed to the String constructor.
func _text(value: Variant) -> String:
    if value == null:
        return ""
    return str(value)


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    failures.append(message)
    push_error("BLOCK_HEIGHT_FAIL: " + message)


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() >= 2:
        OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
        OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_ROUND_INTRO", "0")
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var brick: PortFighter = scene.get("computer")
    var ai: RefCounted = scene.get("native_ai")
    if player == null or brick == null:
        _fail("main.tscn did not expose player/computer")
        _finish()
        return
    player.set_physics_process(false)
    brick.set_physics_process(false)
    if ai == null:
        _fail("scene.native_ai is null: the main.gd hook was not applied")
        _finish()
        return
    if not ai.load_error.is_empty():
        _fail("native AI data error: " + ai.load_error)

    _check_rows_match_export()
    _check_height_map(player)
    _check_block_gate(player)
    _check_reaction_matrix(player)
    _check_ai_selection(ai, player, brick)
    _check_ai_guard_decision(ai, player, brick, scene)
    _finish()


# --- 1: the table is the exported link data -------------------------------


func _check_rows_match_export() -> void:
    var text: String = FileAccess.get_file_as_string("res://data/native_links.json")
    if text.is_empty():
        _fail("cannot read res://data/native_links.json")
        return
    var parsed: Variant = JSON.parse_string(text)
    if not parsed is Dictionary:
        _fail("native_links.json is not an object")
        return
    # key -> link orders of both canblock groups.
    var exported: Dictionary = {}
    for link_value: Variant in Dictionary(parsed).get("links", []):
        if not link_value is Dictionary:
            continue
        var link: Dictionary = link_value
        var group: String = _text(link.get("from_group", ""))
        if group != "canblock" and group != "canblock2":
            continue
        var conditions: Array = Array(link.get("conditions", []))
        if not conditions.has("impact"):
            continue
        var strength: String = ""
        var height: String = ""
        for condition_value: Variant in conditions:
            var condition: String = _text(condition_value)
            if condition.begins_with("oppattackstrength"):
                strength = condition.substr("oppattackstrength".length())
            elif condition.begins_with("oppattackheight"):
                height = condition.substr("oppattackheight".length())
        if height == "med":
            height = "medium"
        if strength.is_empty():
            continue
        var key: String = "%s|%s|%s" % [strength, height, _text(link.get("to", ""))]
        var orders: Array = Array(exported.get(key, []))
        orders.append(int(link.get("order", -1)))
        exported[key] = orders
    if exported.size() != 5:
        _fail("native_links.json has %d distinct canblock rows, expected 5" % exported.size())
    if PortFighter.CANBLOCK_ROWS.size() != exported.size():
        _fail("CANBLOCK_ROWS has %d rows, native_links.json has %d"
                % [PortFighter.CANBLOCK_ROWS.size(), exported.size()])
    for row: Dictionary in PortFighter.CANBLOCK_ROWS:
        var key: String = "%s|%s|%s" % [
            String(row["strength"]), String(row["height"]), String(row["target"])]
        if not exported.has(key):
            _fail("CANBLOCK_ROWS row is not an exported canblock link: " + key)
            continue
        var expected_orders: Array = Array(row["orders"]).duplicate()
        expected_orders.sort()
        var exported_orders: Array = Array(exported[key]).duplicate()
        exported_orders.sort()
        if expected_orders != exported_orders:
            _fail("row %s orders %s != exported %s"
                    % [key, str(expected_orders), str(exported_orders)])
    print("BLOCK_HEIGHT_CHECK exported_rows=%d table_rows=%d"
            % [exported.size(), PortFighter.CANBLOCK_ROWS.size()])


# --- 2: guard action -> height map ----------------------------------------


func _check_height_map(player: PortFighter) -> void:
    var expected: Dictionary = {
        "highblock": "high",
        "midblock": "medium",
        "lowblock": "low",
        "highblockhard": "high",
        "highblockbrutal": "high",
    }
    if PortFighter.BLOCK_GUARD_HEIGHTS.size() != expected.size():
        _fail("BLOCK_GUARD_HEIGHTS has %d entries, expected %d"
                % [PortFighter.BLOCK_GUARD_HEIGHTS.size(), expected.size()])
    for action: String in expected:
        var actual: String = PortFighter.block_guard_height(action)
        if actual != String(expected[action]):
            _fail("guard height %s -> %s, expected %s"
                    % [action, actual, String(expected[action])])
    for row: Dictionary in PortFighter.CANBLOCK_ROWS:
        var target: String = String(row["target"])
        if not PortFighter.BLOCK_GUARD_HEIGHTS.has(target):
            _fail("row target %s has no guard height" % target)
    if not PortFighter.block_guard_height("").is_empty():
        _fail("block_guard_height('') must be empty")
    if not PortFighter.block_guard_height("idle").is_empty():
        _fail("block_guard_height('idle') must be empty")
    if player.begin_block("parryhigh"):
        _fail("begin_block accepted a non-block action")
        player.end_guard()
    print("BLOCK_HEIGHT_CHECK guard_height_actions=%d"
            % PortFighter.BLOCK_GUARD_HEIGHTS.size())


# --- 3: the standing block gate ------------------------------------------


func _check_block_gate(player: PortFighter) -> void:
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    var guards: Array[String] = [
        "highblock", "midblock", "lowblock", "highblockhard", "highblockbrutal",
    ]
    for guard: String in guards:
        if not player.begin_block(guard):
            _fail("begin_block refused " + guard)
            continue
        if player.guard_height != PortFighter.block_guard_height(guard):
            _fail("begin_block %s set guard_height %s" % [guard, player.guard_height])
        for entry: Array in MATRIX:
            var impact: Dictionary = {
                "strength": String(entry[0]),
                "height": String(entry[1]),
                "direction": "frontal",
                "attack_radius": 60.0,
            }
            if not player._can_block_current_hit(impact):
                _fail("guarded %s could not block %s/%s, row target %s"
                        % [guard, entry[0], entry[1], entry[2]])
        player.end_guard()
        if player.guard_held or not player.guard_block_action.is_empty():
            _fail("end_guard kept the %s selection" % guard)
    # An impact strength/height combination the set never encodes has no
    # canblock row, so a recovered guard fails closed instead of inventing one.
    player.begin_block("midblock")
    if player._can_block_current_hit({"strength": "medium", "height": "low"}):
        _fail("impact strength 'medium' has no canblock row but was blocked")
    if not player._can_block_current_hit({"strength": "hard"}):
        _fail("hard row (no height condition) was not blockable")
    if not player._can_block_current_hit({"strength": "brutal"}):
        _fail("brutal row (no height condition) was not blockable")
    if not player._can_block_current_hit({"height": "low"}):
        _fail("impact without a strength lost the metadata-missing fallback")
    if not player._can_block_current_hit({}):
        _fail("empty impact record lost the metadata-missing fallback")
    player.end_guard()
    # The unqualified guard (direct input) keeps the port's legacy block.
    player.begin_guard()
    if not player._can_block_current_hit({"strength": "medium", "height": "low"}):
        _fail("unqualified guard lost the legacy block")
    if not player.guard_block_action.is_empty() or not player.guard_height.is_empty():
        _fail("begin_guard must not claim a block height")
    player.end_guard()
    print("BLOCK_HEIGHT_CHECK gate_guards=%d impact_rows=%d"
            % [guards.size(), MATRIX.size()])


# --- 4: the block reaction is the row target -----------------------------


func _check_reaction_matrix(player: PortFighter) -> void:
    player.reset_fighter(Vector3(0.0, 1.2, 0.0))
    # A block link carries the CheckConditions `impact` token, which requires a
    # live +0x164 record and the native reach formula.  Put the synthetic
    # attacker inside that reach so the row selection, not the distance gate, is
    # what this matrix measures.
    if player.opponent != null and is_instance_valid(player.opponent):
        player.opponent.position = player.position + Vector3(0.4, 0.0, 0.0)
    for entry: Array in MATRIX:
        var impact: Dictionary = {
            "strength": String(entry[0]),
            "height": String(entry[1]),
            "direction": "frontal",
            "attack_radius": 60.0,
            "body_part": "larm",
        }
        var reaction: Dictionary = player.reaction_for_incoming(impact, true)
        var action: String = String(reaction.get("source_action", ""))
        if action != String(entry[2]):
            _fail("blocked %s/%s resolved to %s, expected %s"
                    % [entry[0], entry[1], action, entry[2]])
            continue
        if not reaction.has("exit_start_frame") or not reaction.has("animation"):
            _fail("blocked row %s has no exit frame/animation" % entry[2])
    # No recovered impact metadata: the held guard action supplies the reaction.
    for guard: String in ["lowblock", "midblock", "highblock"]:
        player.begin_block(guard)
        var fallback: Dictionary = player.reaction_for_incoming(
            {"attack_radius": 60.0}, true)
        if String(fallback.get("source_action", "")) != guard:
            _fail("metadata-less blocked contact with a %s guard resolved to %s"
                    % [guard, String(fallback.get("source_action", ""))])
        player.end_guard()
    print("BLOCK_HEIGHT_CHECK reaction_rows=%d fallbacks=3" % MATRIX.size())


# --- 5: AI block leaf selection ------------------------------------------


func _check_ai_selection(ai: RefCounted, player: PortFighter, brick: PortFighter) -> void:
    var leaves: Array[String] = ["actionblockhigh", "actionblockmedium", "actionblocklow"]
    var actions_by_leaf: Dictionary = {}
    for leaf: String in leaves:
        var node_value: Variant = ai.tree.get(leaf, {})
        if not node_value is Dictionary or not Dictionary(node_value).has("actions"):
            _fail("tree leaf %s has no action list" % leaf)
            return
        actions_by_leaf[leaf] = Array(Dictionary(node_value)["actions"])
    # The AI has to read the opponent's current impact record.  Bruce's config
    # supplies normal low/medium/high and hard high/medium; Brick's shipped set
    # supplies hard low (low_kick3) and brutal medium (special_punch_low_brick),
    # the only brutal row among the loaded sets.
    # strength, height, attack kind, owner ("player" is the AI's opponent).
    var attacks: Array[Array] = [
        ["normal", "low", "kick", "player"],
        ["normal", "medium", "punch", "player"],
        ["normal", "high", "high_punch", "player"],
        ["hard", "low", "low_kick3", "brick"],
        ["hard", "medium", "low_punch3", "player"],
        ["hard", "high", "high_punch3", "player"],
        ["brutal", "medium", "special_punch_low_brick", "brick"],
    ]
    var attacks_by_key: Dictionary = {}
    for row: Array in attacks:
        attacks_by_key["%s|%s" % [row[0], row[1]]] = row
    if not player.ATTACKS.has("kick"):
        _fail("player config has no 'kick' attack")
        return
    player.state = "startup"
    player.attack_kind = "high_punch"
    if String(ai._opp_impact_metadata().get("strength", "")) != "normal":
        _fail("AI did not read the opponent's current impact record: "
                + str(ai._opp_impact_metadata()))
    var checked: int = 0
    for entry: Array in LEAF_EXPECT:
        var key: String = "%s|%s" % [entry[0], entry[1]]
        if not attacks_by_key.has(key):
            _fail("no test attack for %s" % key)
            continue
        var attack: Array = Array(attacks_by_key[key])
        var kind: String = String(attack[2])
        var owner: String = String(attack[3])
        if not player.ATTACKS.has(kind) and not brick.ATTACKS.has(kind):
            _fail("test attack %s is in neither loaded fighting set" % kind)
            continue
        if owner == "brick":
            ai.opponent = brick
            brick.attack_kind = kind
        else:
            player.attack_kind = kind
        var metadata: Dictionary = ai._opp_impact_metadata()
        if (String(metadata.get("strength", "")) != String(entry[0])
                or String(metadata.get("height", "")) != String(entry[1])):
            _fail("%s reported impact metadata %s" % [kind, str(metadata)])
        var choice: String = ai._block_choice(Array(actions_by_leaf[String(entry[2])]))
        if choice != String(entry[3]):
            _fail("%s leaf with %s impact chose %s, expected %s"
                    % [entry[2], key, choice, entry[3]])
        checked += 1
        ai.opponent = player
        brick.attack_kind = ""
    # Metadata missing (no live attack): the leaf's own height guess.
    player.attack_kind = ""
    for leaf: String in leaves:
        var fallback: String = ai._block_choice(Array(actions_by_leaf[leaf]))
        var expected_guess: String = String(leaf).replace("actionblock", "")
        if expected_guess == "medium":
            expected_guess = "midblock"
        else:
            expected_guess = expected_guess + "block"
        if fallback != expected_guess:
            _fail("%s without impact metadata chose %s, expected its height guess %s"
                    % [leaf, fallback, expected_guess])
    print("BLOCK_HEIGHT_CHECK ai_leaf_cases=%d metadata_missing_leaves=%d"
            % [checked, leaves.size()])


# --- 6: a live guard decision carries the selection ---------------------


func _check_ai_guard_decision(
        ai: RefCounted, player: PortFighter, brick: PortFighter, scene: Node
) -> void:
    # The tree reaches a guard through two paths: doblockguessingheight (the
    # opp_attack_height branch -> actionblock<height>) and doblocknoguessingheight
    # (a fixed random 0.33 high / 0.5 medium / else low guess).  Both are shipped
    # tree data, so the assertion is the recovered selection *for the leaf the
    # tree picked*: a normal attack keeps that leaf's height block (the canblock
    # row's target is the leaf's own height for normal), while a hard attack
    # always selects the hard row target, which every leaf lists.
    var cases: Array[Array] = [
        ["high_punch", "normal"],
        ["high_punch3", "hard"],
    ]
    for entry: Array in cases:
        var blocks: int = 0
        var checked: int = 0
        var mismatches: Array[String] = []
        for seed_value: int in range(1, 80):
            _reset(scene, player, brick, ai, seed_value)
            _seed_impact_frame(player, String(entry[0]))
            brick.position = player.position + Vector3(0.5, 0.0, 0.0)
            var decision: Dictionary = ai.step(1.0 / 60.0)
            if String(decision.get("kind", "")) != "block":
                continue
            blocks += 1
            var node: String = String(decision.get("node", "")).replace("_grab", "")
            var expected: String = ""
            if String(entry[1]) == "hard":
                # every shipped block leaf lists highblockhard.
                expected = "highblockhard"
            else:
                match node:
                    "actionblockhigh":
                        expected = "highblock"
                    "actionblockmedium":
                        expected = "midblock"
                    "actionblocklow":
                        expected = "lowblock"
            if expected.is_empty():
                continue
            checked += 1
            if brick.guard_block_action != expected:
                mismatches.append("seed=%d node=%s guard=%s"
                        % [seed_value, node, brick.guard_block_action])
            elif brick.guard_height != PortFighter.block_guard_height(expected):
                mismatches.append("seed=%d height=%s" % [seed_value, brick.guard_height])
        if blocks == 0 or checked == 0:
            _fail("%s never produced a checked guard decision in 79 seeds" % entry[0])
        elif not mismatches.is_empty():
            _fail("%s guard mismatches: %s"
                    % [entry[0], ", ".join(mismatches.slice(0, 3))])
        print("BLOCK_HEIGHT_CHECK ai_guard attack=%s strength=%s blocks=%d checked=%d"
                % [entry[0], entry[1], blocks, checked])


# --- helpers -------------------------------------------------------------


func _reset(
        scene: Node, player: PortFighter, brick: PortFighter, ai: RefCounted, seed_value: int
) -> void:
    scene._reset_match()
    player.position = Vector3(0.0, 1.2, 0.0)
    brick.position = Vector3(0.6, 1.2, 0.0)
    player.end_guard()
    brick.end_guard()
    player.state = "idle"
    player.state_time = 0.0
    player.attack_kind = ""
    player.attack_sequence = 0
    brick.state = "idle"
    brick.state_time = 0.0
    brick.attack_kind = ""
    brick.move_axis = Vector2.ZERO
    ai.state = "default"
    ai.last_node = ""
    ai.last_action = ""
    ai.action_counts.clear()
    ai.unsupported_actions.clear()
    ai.decisions.clear()
    ai._repetition = 0
    ai._last_signature = ""
    ai._rng.seed = seed_value


func _seed_impact_frame(fighter: PortFighter, kind: String) -> void:
    ## Seed the attacker at the first frame whose native impact record is live.
    ## CheckConditions reads opponent+0x164 (BasicUpdate), so the block links are
    ## only meaningful inside that damage_time window.
    if not fighter.ATTACKS.has(kind):
        return
    fighter.attack_kind = kind
    var details: Dictionary = fighter.ATTACKS[kind]
    var action: String = fighter._current_action_name()
    var timing: Variant = fighter._native_actions.get(action, {}).get("impact", {}).get("damage_time")
    var target: int = int(Array(timing)[0]) if timing is Array and Array(timing).size() >= 2 else 0
    var rate: float = PortFighter.SOURCE_FRAME_RATE
    var startup: int = int(round(float(details["startup"]) * rate))
    var active: int = int(round(float(details["active"]) * rate))
    var recovery: int = int(round(float(details["recovery"]) * rate))
    var total: int = int(details["animation_frame_count"])
    fighter._attack_clock_active = false
    if target < startup:
        fighter.state = "startup"
        fighter.state_time = maxf(float(startup - target), 0.0) / rate
    elif target < startup + active:
        fighter.state = "active"
        fighter.state_time = maxf(float(startup + active - target), 0.0) / rate
    else:
        fighter.state = "recovery"
        fighter.state_time = maxf(float(total - target), 0.0) / rate


func _finish() -> void:
    if failures.is_empty():
        print("BLOCK_HEIGHT_VALIDATION=PASS")
        quit(0)
    else:
        print("BLOCK_HEIGHT_VALIDATION=FAIL count=%d" % failures.size())
        for failure: String in failures:
            print("  - " + failure)
        quit(1)

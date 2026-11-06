extends SceneTree
## Regressions for the recovered FollowLink metadata and pose conditions.
##
## The unique-tag checks below follow the native active-unique semantics of
## brucelee.set (SHA-256 860b6dac1ae5043456fbf72b1cd93a5a1c76f036b3b995df5e57ce68b4d3762c):
## CFighter::IsLinkAllowed accepts a tagged row only when every tag is an exact
## member of the fighter's own list (CFighter+0x120).  The default Bruce list is
## the characters.list `uniques` array; another character's ID enters it only
## through an explicit style selection.  The current opponent is irrelevant, so
## the same default set is asserted against a Brick opponent here.
## The generic (order 6) and Brick-specific (order 8) step links are both
## asserted from the recovered table so link-order regressions stay visible.

const DEFAULT_UNIQUES: Array[String] = [
    "brucelee", "hpunchbrucelee", "lpunchbrucelee", "hkickbrucelee",
    "lkickbrucelee", "endbrucelee", "grababrucelee", "grabbbrucelee",
]


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.size() != 2:
        push_error("Expected Bruce and Brick candidate GLB paths")
        quit(1)
        return
    OS.set_environment("BRUCELEE_MAIN_MENU", "0")
    OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
    OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    scene.set_process(false)
    scene.set_physics_process(false)
    var player: PortFighter = scene.get("player")
    var computer: PortFighter = scene.get("computer")
    player.set_physics_process(false)
    computer.set_physics_process(false)

    var checks: Dictionary = {}

    # entry_frame: parry_attack starts at frame 3 when chained from parryhigh.
    player.reset_fighter(Vector3(-0.25, 1.2, 0.0))
    player._begin_chained_attack("parry_attack", 3)
    var entry_frame: float = player._current_attack_source_frame()
    checks["entry_frame"] = entry_frame
    if absf(entry_frame - 3.0) > 0.2:
        push_error("entry_frame not applied: " + str(entry_frame))
        quit(1)
        return

    # Native recovery: lowpunch3 -> idle2 [51,81], entry_frame 5.
    player.reset_fighter(Vector3(-0.25, 1.2, 0.0))
    player.attack_kind = "low_punch3"
    player.state = "recovery"
    player.state_time = 0.0
    var returned: Dictionary = player._native_recovery_return()
    checks["recovery"] = String(returned.get("state", ""))
    checks["recovery_entry"] = int(returned.get("entry_frame", -1))
    if (String(returned.get("state", "")) != "idle2"
            or int(returned.get("entry_frame", -1)) != 5):
        push_error("native recovery link is wrong: " + str(returned))
        quit(1)
        return

    # Pose conditions use the recovered action pose, not the state enum.
    computer.reset_fighter(Vector3(0.25, 1.2, 0.0))
    checks["pose_idle"] = computer._fighter_pose()
    computer.state = "hitstun"
    checks["pose_hitstun"] = computer._fighter_pose()
    computer.state = "faceupidle"
    checks["pose_faceup"] = computer._fighter_pose()
    if checks["pose_idle"] != "stand" or checks["pose_hitstun"] != "stun" or checks["pose_faceup"] != "laying":
        push_error("pose mapping is wrong: " + str(checks))
        quit(1)
        return

    # Recovered link-order / unique-tag rows (generic first, then the Brick
    # variant).  These are table facts, independent of runtime state.
    var by_order: Dictionary = {}
    for link: Dictionary in player._native_links:
        by_order[int(link.get("order", -1))] = link
    var expected_rows: Dictionary = {
        6: ["stepright", "grab1miss", "grababrucelee"],
        8: ["stepright", "grab1miss brick", "grababrick"],
        34: ["", "endattack1", ""],
        35: ["", "endattack2", "endbrucelee"],
        36: ["", "endattack brick", "endbrickdavis"],
    }
    for order: int in expected_rows:
        var row: Array = expected_rows[order]
        var link: Dictionary = by_order.get(order, {})
        var unique: Array = Array(link.get("unique", []))
        var tag: String = str(unique[0]) if not unique.is_empty() else ""
        if (link.is_empty()
                or ("" if link.get("from") == null else str(link.get("from"))) != str(row[0])
                or str(link.get("to", "")) != String(row[1])
                or tag != String(row[2])):
            push_error("recovered link order " + str(order) + " drifted: " + str(link))
            quit(1)
            return
        checks["link_" + str(order)] = str(link.get("to", ""))

    # Default active list: exactly the characters.list uniques of Bruce Lee.
    checks["default_uniques"] = player.active_uniques()
    var expected_default: Array = DEFAULT_UNIQUES.duplicate()
    expected_default.sort()
    if checks["default_uniques"] != expected_default:
        push_error("default active uniques are not native: "
                + str(checks["default_uniques"]))
        quit(1)
        return
    if player._native_link_unique_ok({"unique": ["grababrick"]}):
        push_error("default Bruce accepted grababrick")
        quit(1)
        return
    if not player._native_link_unique_ok({"unique": ["grababrucelee"]}):
        push_error("default Bruce refused grababrucelee")
        quit(1)
        return
    if player._native_link_unique_ok({"unique": ["endbrickdavis"]}):
        push_error("default Bruce accepted endbrickdavis")
        quit(1)
        return
    if not player._native_link_unique_ok({"unique": ["endbrucelee"]}):
        push_error("default Bruce refused endbrucelee")
        quit(1)
        return
    # The opponent's own fighter uses its own single characters.list label.
    checks["brick_uniques"] = computer.active_uniques()
    if checks["brick_uniques"] != ["brickdavis"]:
        push_error("Brick active uniques are not native: " + str(checks["brick_uniques"]))
        quit(1)
        return
    if not computer._native_link_unique_ok({"unique": ["brickdavis"]}):
        push_error("Brick refused its own unique label")
        quit(1)
        return
    if computer._native_link_unique_ok({"unique": ["grababrick"]}):
        push_error("Brick accepted a style-entry ID as a character label")
        quit(1)
        return

    # Explicit style selection is the only way another character's ID enters
    # Bruce's list; it replaces the group default instead of being added.
    var catalog = StyleCatalog.new()
    if not catalog.load_catalog():
        push_error("style catalog failed closed: " + catalog.error)
        quit(1)
        return
    var selections: Dictionary = catalog.defaults()
    selections["grabs/graba"] = "grababrick"
    player.apply_style_selections(selections, catalog)
    checks["explicit_uniques"] = player.active_uniques()
    if not player._native_link_unique_ok({"unique": ["grababrick"]}):
        push_error("explicit Brick grababrick was refused")
        quit(1)
        return
    if player._native_link_unique_ok({"unique": ["grababrucelee"]}):
        push_error("explicit Brick selection kept the replaced Bruce grab ID")
        quit(1)
        return
    if player.tutorial_default_uniques:
        push_error("style selection leaked the tutorial flag")
        quit(1)
        return

    print("P2_RECOVERED_LINK_VALIDATION=" + JSON.stringify(checks))
    quit(0)

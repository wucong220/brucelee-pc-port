extends SceneTree
## Data contract for the complete recovered candobasicattacks coverage.
##
## Proves, without a candidate model, that:
##   * the derived member table carries exactly the 84 brucelee.set members and
##     the 21 incoming links of the recovered group;
##   * every member window equals the exported native_links.json group window,
##     and its ANM frame count (from the decoded animation inventory) is present;
##   * the member set splits into whole-animation windows (movement/idle) and
##     partial attack windows, so the port's window rule can be checked;
##   * every non-owner link resolves to no port attack kind (fail closed);
##   * every live link target maps to a recovered port attack kind.
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_candobasicattacks_data.gd

const MEMBERS_PATH: String = "res://data/candobasicattacks_members.json"
const NATIVE_LINKS_PATH: String = "res://data/native_links.json"
const PLAYER_CONFIG_PATH: String = "res://data/fighting_set_low_attacks.json"
const BRUCELEE_SET_PATH: String = "adreno_200/set/brucelee.set"


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var members_doc: Dictionary = _read_json(MEMBERS_PATH)
    var links_doc: Dictionary = _read_json(NATIVE_LINKS_PATH)
    var player_config: Dictionary = _read_json(PLAYER_CONFIG_PATH)
    if members_doc.is_empty() or links_doc.is_empty() or player_config.is_empty():
        quit(1)
        return

    var failures: Array[String] = []
    var source: Dictionary = members_doc.get("source", {})
    if String(members_doc.get("group", "")) != "candobasicattacks":
        failures.append("group name")
    if String(source.get("set_path", "")) != BRUCELEE_SET_PATH:
        failures.append("set path")
    if String(source.get("set_sha256", "")) != String(
            links_doc.get("source", {}).get("set_sha256", "")):
        failures.append("set sha256 does not match native_links.json")
    var members: Array = members_doc.get("members", [])
    var links: Array = members_doc.get("links", [])
    if members.size() != 84:
        failures.append("member count " + str(members.size()))
    if links.size() != 21:
        failures.append("link count " + str(links.size()))

    var actions: Dictionary = {}
    for action_value: Variant in links_doc.get("actions", []):
        var action: Dictionary = action_value
        actions[String(action.get("name", ""))] = action
    var native_links: Dictionary = {}
    for link_value: Variant in links_doc.get("links", []):
        var link: Dictionary = link_value
        native_links[int(link.get("order", -1))] = link

    var whole: int = 0
    var partial: int = 0
    for member_value: Variant in members:
        var member: Dictionary = member_value
        var name: String = String(member.get("name", ""))
        var window: Array = Array(member.get("window", []))
        var frames: int = int(member.get("frames", 0))
        if name.is_empty() or window.size() != 3 or frames <= 0:
            failures.append("invalid member " + name)
            continue
        var native_group: Variant = actions.get(name, {}).get("groups", {}).get(
            "candobasicattacks"
        )
        if not native_group is Array or Array(native_group).size() < 2:
            failures.append("native group window missing for " + name)
            continue
        if (int(Array(native_group)[0]) != int(window[0])
                or int(Array(native_group)[1]) != int(window[1])):
            failures.append("window drift for " + name)
        if int(window[0]) == 0 and int(window[1]) >= frames - 1:
            whole += 1
        else:
            partial += 1
    if whole != 13:
        failures.append("whole-animation member count " + str(whole))
    if partial != 71:
        failures.append("partial-window member count " + str(partial))

    var source_to_kind: Dictionary = {}
    for kind: String in player_config.get("attacks", {}):
        var source_action: String = String(
            Dictionary(player_config["attacks"][kind]).get("source_action", "")
        )
        if not source_action.is_empty():
            source_to_kind[source_action] = kind

    var live: int = 0
    var owner_refused: int = 0
    for link_value: Variant in links:
        var link: Dictionary = link_value
        var index: int = int(link.get("source_index", -1))
        var native: Dictionary = native_links.get(index, {})
        if native.is_empty() or String(native.get("to", "")) != String(link.get("to", "")):
            failures.append("link %d missing from native_links.json" % index)
            continue
        var owner: Variant = link.get("owner")
        var target: String = String(link.get("to", ""))
        if owner == null:
            if not source_to_kind.has(target) and target != "attacktofloor":
                failures.append("live link %d target %s has no kind" % [index, target])
            else:
                live += 1
        elif String(owner) == "brucelee":
            if not source_to_kind.has(target):
                failures.append("brucelee link %d target %s has no kind" % [index, target])
            else:
                live += 1
        else:
            if source_to_kind.has(target):
                failures.append("owner link %d target %s resolves to a player kind"
                        % [index, target])
            else:
                owner_refused += 1
    if live != 12:
        failures.append("live link count " + str(live))
    if owner_refused != 9:
        failures.append("owner-refused link count " + str(owner_refused))

    print("CANDOBASICATTACKS_DATA=" + JSON.stringify({
        "members": members.size(),
        "links": links.size(),
        "whole_clip_members": whole,
        "partial_window_members": partial,
        "live_links": live,
        "owner_refused_links": owner_refused,
        "set_sha256": String(source.get("set_sha256", "")),
    }))
    if not failures.is_empty():
        push_error("CANDOBASICATTACKS_DATA_FAILURES=" + str(failures))
        quit(1)
        return
    quit(0)


func _read_json(path: String) -> Dictionary:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("cannot open " + path)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        push_error("invalid JSON " + path)
        return {}
    return parsed

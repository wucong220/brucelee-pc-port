extends RefCounted
## Recovered `canblock` / `canblock2` action time windows.
##
## Every shipped fighting set stores each action's block window in its own
## group table (data/native_links*.json -> actions[].groups.canblock and
## .canblock2).  A `from_group` link is followed only while the *current*
## animation frame lies inside that group's inclusive [start, end] interval:
## docs/FIGHTING_SET_FINDINGS.md "受击、格挡和返回窗口" records
## CFighter::TimeWindowCheck 0x1A1F00-0x1A1FBC reading the group's own start/end
## frames for group links.  The five recovered block rows
## (PortFighter.CANBLOCK_ROWS, link orders 92-101 of brucelee.set) are such
## `from_group` links.
##
## This module is the port's single model of those windows.  It contains NO
## hardcoded frame numbers: the only source is the exported JSON of the set the
## fighter loaded.  An action without a canblock/canblock2 group has no
## authored block window and therefore fails closed.  The action's `facing`
## duration is a different group and is never used as a substitute.
##
## Units are native source frames (SOURCE_FRAME_RATE = 30 fps).  The third
## element of a group array is the recovered linking frame; it is retained in
## the evidence but does not widen the window (the exported block rows carry 0).

const CANBLOCK_GROUPS: Array[String] = ["canblock", "canblock2"]
## Inclusive endpoints with the same epsilon other recovered window checks use.
const WINDOW_EPSILON: float = 0.0001

var source_path: String = ""
var load_error: String = ""
var set_path: String = ""
var action_count: int = 0
var link_count: int = 0
## action name -> Array[Dictionary] with keys group/start/end/linking.
var windows: Dictionary = {}
var window_count: int = 0


## Build the model from a parsed native_links JSON dictionary.
## Returns false (and sets load_error) when the file is not a usable set export.
func build(parsed: Dictionary, path: String = "") -> bool:
    source_path = path
    var source_value: Variant = parsed.get("source", {})
    var source: Dictionary = source_value if source_value is Dictionary else {}
    set_path = String(source.get("set_path", ""))
    load_error = ""
    windows = {}
    window_count = 0
    action_count = 0
    link_count = 0
    var actions_value: Variant = parsed.get("actions", [])
    if not actions_value is Array:
        load_error = "actions is not an array"
        return false
    var actions: Array = Array(actions_value)
    var links_value: Variant = parsed.get("links", [])
    if links_value is Array:
        link_count = Array(links_value).size()
    for row_value: Variant in actions:
        if not row_value is Dictionary:
            continue
        var row: Dictionary = row_value
        action_count += 1
        var name_value: String = String(row.get("name", ""))
        if name_value.is_empty():
            continue
        var authored: Array[Dictionary] = windows_for_row(row)
        if authored.is_empty():
            continue
        windows[name_value] = authored
        window_count += authored.size()
    if action_count == 0:
        load_error = "no actions in " + path
        return false
    return true


## Load a set export from a res:// (or absolute) path.  Used by headless
## validation to compare every shipped set against its own window table.
func load_set(path: String) -> bool:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        load_error = "cannot read " + path
        return false
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not parsed is Dictionary:
        load_error = "invalid JSON in " + path
        return false
    return build(Dictionary(parsed), path)


## The authored windows of one native action row.  Malformed, inverted or
## absent groups produce an empty list, i.e. fail closed, never a guess.
static func windows_for_row(row: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var groups_value: Variant = row.get("groups", {})
    if not groups_value is Dictionary:
        return result
    var groups: Dictionary = groups_value
    for group: String in CANBLOCK_GROUPS:
        var entry_value: Variant = groups.get(group)
        if not entry_value is Array:
            continue
        var entry: Array = Array(entry_value)
        if entry.size() < 2:
            continue
        var start: int = int(entry[0])
        var end: int = int(entry[1])
        if start < 0 or end < 0 or start > end:
            continue
        var linking: int = int(entry[2]) if entry.size() >= 3 else 0
        result.append({
            "group": group,
            "start": start,
            "end": end,
            "linking": linking,
        })
    return result


func windows_for(action: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if action.is_empty():
        return result
    var value: Variant = windows.get(action, [])
    if not value is Array:
        return result
    for entry_value: Variant in Array(value):
        if entry_value is Dictionary:
            result.append(Dictionary(entry_value))
    return result


## Inclusive [start, end] comparison at the current native source frame.
static func window_contains(window: Dictionary, frame: float) -> bool:
    var start: float = float(window.get("start", 0))
    var end: float = float(window.get("end", -1))
    if end < start:
        return false
    return (frame + WINDOW_EPSILON >= start
        and frame <= end + WINDOW_EPSILON)


func open(action: String, frame: float) -> bool:
    for window: Dictionary in windows_for(action):
        if window_contains(window, frame):
            return true
    return false


## The authored window that contains `frame`, or {} when the decision would
## fail closed.  Handy for tests and decision logs.
func containing_window(action: String, frame: float) -> Dictionary:
    for window: Dictionary in windows_for(action):
        if window_contains(window, frame):
            return window
    return {}


func describe() -> Dictionary:
    return {
        "source_path": source_path,
        "set_path": set_path,
        "action_count": action_count,
        "link_count": link_count,
        "actions_with_windows": windows.size(),
        "window_count": window_count,
        "groups": CANBLOCK_GROUPS,
        "load_error": load_error,
    }

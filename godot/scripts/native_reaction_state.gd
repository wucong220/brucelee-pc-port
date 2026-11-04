extends RefCounted
class_name NativeReactionState
## Recovered reaction / stun / impact state gate for the PC port.
##
## This is an ADDITIVE module: it re-implements only the part of the native
## per-frame fighter state machine that decides *which* reaction a fighter
## enters, using the recovered link order and the recovered condition
## semantics.  It does not touch animation playback, hit-stun clocks or the
## existing `reaction_for_incoming()` heuristic; a caller opts in.
##
## Everything below is traceable to one of two sources:
##
## [1] libdefault.so (SHA-256 1da7a30c...) disassembly, read-only:
##     * krm::CFighter::UserControlUpdate  ELF 0x1a89c0 (Ghidra 0x1b89c0)
##         BasicUpdate -> if (+0xF0) return -> for each link of the current
##         animation, in link order: TimeWindowCheck, InputSequenceCheck,
##         InputStatusCheck, CheckConditions; first match wins:
##         FollowLink + ConsumeEvents (+ consume-all when link+0xE0) and then
##         CFighter::DamageReceiveCheck.
##     * krm::CFighter::FollowLink        ELF 0x1a8040 (Ghidra 0x1b8040)
##         target_frame = link+0xD4 when link+0x8 == 0, else the animation
##         frame table entry for the link target; if target_frame > +0x34
##         (current frame) the link is parked in +0xF0/+0xF4 and executed
##         later, otherwise it runs immediately.
##     * krm::CFighter::BasicUpdate       ELF 0x1a8330 (Ghidra 0x1b8330)
##         executes the parked link once current frame >= +0xF4, then clears
##         +0xF0 (one-shot); the current impact record is +0x164.
##     * krm::CFighter::DamageReceiveCheck ELF 0x1a548c (Ghidra 0x1b548c)
##         damage applies only when the opponent IsAttacking() (+0x164 != 0)
##         and the victim animation BelongsToGroup("ReceiveDamage").
##     * CheckConditions ELF 0x1a3920 (Ghidra 0x1b3920):
##         - "impact":      opponent impact record active
##                          AND victim distance (+0x80) <=
##                              record.radius(+0x10) * opponent+0x15C
##                              + victim GetRadius()
##                          AND record.last_index(byte) >= opponent+0x16C(byte)
##                          (sites 0x1a42e4 / 0x1a4388)
##         - "healthzero":  AttackDamage(opponent) >= victim health (+0x144)
##                          (site 0x1a43b4)
##         - oppattack{strength,height,dir}*: compare the opponent's *current*
##           impact record fields (record+0x1C strength, +0x20 direction,
##           +0x18 height, sites 0x1a40f8..0x1a4270)
## [2] godot/data/native_links.json, exported from brucelee.set: the link rows
##     themselves (order, from/from_group, conditions, keystatus, time,
##     entry_frame, linking_frame, blending) and every action's group windows.
##
## Unrecovered and therefore FAIL CLOSED (no reaction is chosen):
##   * the `IsBlocking()` category literal and the `IsDefeated()` group literal
##     are runtime-initialised global string handles; the compiled code never
##     stores the literal, so no name is claimed here.
##   * conditions outside the recovered set (ragethird, rage2thirds,
##     oppposestun/stand/laying, oppnotblocking, grabdistance, countertime) are
##     delegated to an optional caller-supplied evaluator; without one they make
##     the link not match instead of being guessed.
##
## Native addresses are ELF virtual addresses; Ghidra's dumps are +0x10000.

const NATIVE_LINKS_PATH: String = "res://data/native_links.json"

## CFighter fields used by the recovered rules (documentation only).
const FIELD_CURRENT_FRAME: int = 0x34
const FIELD_PENDING_LINK: int = 0xF0
const FIELD_PENDING_FRAME: int = 0xF4
const FIELD_IMPACT_RECORD: int = 0x164
const FIELD_IMPACT_CURSOR: int = 0x16C
const FIELD_HEALTH: int = 0x144

## Conditions whose semantics were recovered from CheckConditions.
const RECOVERED_CONDITIONS: Array[String] = [
    "impact", "healthzero",
    "oppattackheightlow", "oppattackheightmed", "oppattackheighthigh",
    "oppattackstrengthnormal", "oppattackstrengthmedium",
    "oppattackstrengthhard", "oppattackstrengthbrutal",
    "oppattackdirfrontal", "oppattackdirfromleft", "oppattackdirfromright",
    "oppattackdirfromabove", "oppattackdirfromair",
]

## Group checked by DamageReceiveCheck (ELF 0x1a5568 -> rodata 0x5bab9c).
const DAMAGE_GROUP: String = "receivedamage"

const REASON_OK: String = "ok"
const REASON_NO_LINK: String = "no-matching-link"
const REASON_UNKNOWN_CONDITION: String = "unknown-condition"
const REASON_NO_GROUP: String = "action-has-no-group"
const REASON_NO_WINDOW: String = "link-window-missing"
const REASON_DEFERRED: String = "deferred"

var actions: Dictionary = {}
var links: Array = []
var load_error: String = ""

## FollowLink parked state (CFighter+0xF0/+0xF4).
var pending_link: Dictionary = {}
var pending_frame: int = -1

## Optional caller-supplied evaluator for the conditions listed as unrecovered.
## Called as Callable(condition_name: String, probe: Dictionary) -> bool.
var extra_condition_eval: Callable = Callable()

## Input layout index used by GetKeySequence/GetKeyStatus (fighter+0x1C).
## 1 is the keyboard layout the PC port already selects.
var sequence_index: int = 1

## Scope of this gate: reaction-family targets only.
##
## The native link table is shared by movement, basic attacks and reactions, in
## one global order.  The recovered block rows (92-101) and the movement rows
## (for example 28, canmove -> stepback) both require the same "left" status
## token, so with a single status vector the earlier movement row would win.
## Whether the original input layer maps that token to a distinct guard key is
## NOT recovered (it lives in adreno_200/input.config, not in the binary), so
## this gate deliberately does not decide that competition: it resolves only
## the reaction family and leaves input-driven links to the existing link path.
const REACTION_TARGET_PREFIXES: Array[String] = [
    "impact", "stun", "faceup", "facedown",
]
const REACTION_TARGET_CONTAINS: Array[String] = ["block"]
const REACTION_TARGET_SUFFIXES: Array[String] = ["ko"]


func is_reaction_target(target: String) -> bool:
    if target.is_empty():
        return false
    for prefix: String in REACTION_TARGET_PREFIXES:
        if target.begins_with(prefix):
            return true
    for needle: String in REACTION_TARGET_CONTAINS:
        if target.find(needle) >= 0:
            return true
    for suffix: String in REACTION_TARGET_SUFFIXES:
        if target.ends_with(suffix):
            return true
    return false

## Every decision is appended here for evidence: {action, frame, result, ...}.
var trace: Array = []


func load_native_links(path: String = NATIVE_LINKS_PATH) -> bool:
    actions.clear()
    links.clear()
    load_error = ""
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        load_error = "cannot open " + path
        return false
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        load_error = "invalid JSON in " + path
        return false
    for action: Variant in Dictionary(parsed).get("actions", []):
        if action is Dictionary:
            actions[str(Dictionary(action).get("name", ""))] = action
    for link_value: Variant in Dictionary(parsed).get("links", []):
        if link_value is Dictionary:
            links.append(link_value)
    load_error = "loaded actions=%d links=%d" % [actions.size(), links.size()]
    # The export preserves native order; sorting by the recorded order keeps the
    # "first match wins" rule stable even if a file is edited.
    links.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return int(a.get("order", 0)) < int(b.get("order", 0)))
    if links.is_empty():
        load_error = "no links in " + path
        return false
    return true


func reset() -> void:
    pending_link = {}
    pending_frame = -1
    trace.clear()


## CFighter::UserControlUpdate early-out: a parked link blocks new input.
func can_follow() -> bool:
    return pending_link.is_empty()


## Target frame of a link for the *current* animation, i.e. FollowLink's
## `frame` value.  Recovered rule: link+0xD4 when link+0x8 == 0; the exported
## table stores that value as `linking_frame`.
func link_target_frame(link: Dictionary) -> int:
    return int(link.get("linking_frame", 0))


## CFighter::FollowLink.  Returns {"deferred": bool, "execute": bool, "link": ..}
## The caller executes the animation when `execute` is true, exactly like the
## native immediate branch; otherwise the link is parked until advance().
func follow_link(link: Dictionary, frame: float) -> Dictionary:
    var target: int = link_target_frame(link)
    if target > int(frame):
        pending_link = link
        pending_frame = target
        _record("defer", link, frame, {"defer_frame": target})
        return {"deferred": true, "execute": false, "link": link}
    _clear_pending()
    _record("follow", link, frame, {})
    return {"deferred": false, "execute": true, "link": link}


## CFighter::BasicUpdate: run the parked link once the frame reaches +0xF4.
## `frame` is the animation frame after this update (CFighter+0x34).
func advance(frame: float) -> Dictionary:
    if pending_link.is_empty():
        return {}
    if int(frame) < pending_frame:
        return {}
    var link: Dictionary = pending_link
    _clear_pending()
    _record("execute-pending", link, frame, {})
    return {"deferred": false, "execute": true, "link": link}


func _clear_pending() -> void:
    pending_link = {}
    pending_frame = -1


## Link window for the current action.  Recovered TimeWindowCheck shape:
## direct links use link.time; group links use the action's group window
## [start, end, linking?] and require the action to carry that group.
func link_window(link: Dictionary, action: String) -> Array:
    var source: String = _text(link.get("from"))
    if not source.is_empty():
        return Array(link.get("time", []))
    var row: Dictionary = actions.get(action, {})
    var groups: Variant = row.get("groups", {})
    if not groups is Dictionary:
        return []
    var group: String = _text(link.get("from_group"))
    if group.is_empty() or not Dictionary(groups).has(group):
        return []
    var entry: Variant = Dictionary(groups)[group]
    if not entry is Array or Array(entry).size() < 2:
        return []
    var window: Array = [int(Array(entry)[0]), int(Array(entry)[1])]
    if Array(entry).size() >= 3:
        window.append(int(Array(entry)[2]))
    return window


func _in_window(window: Array, frame: float, linking_frame: int) -> bool:
    if window.size() < 2:
        return false
    var start: float = float(window[0])
    var end: float = float(window[1])
    if window.size() >= 3:
        start = maxf(start, float(window[2]))
    if linking_frame > 0 and frame + 0.0001 < float(linking_frame):
        return false
    return frame + 0.0001 >= start and frame <= end + 0.0001


## InputSequenceCheck.  Every recovered reaction and block link has an empty
## key sequence in all three layout variants, so the reaction gate is purely
## state driven.  A link that needs key events is input driven and is left to
## the existing link path (fighter.gd); this module refuses it instead of
## matching on an absent event stream.
func sequence_ok(link: Dictionary) -> bool:
    var variants: Variant = link.get("keysequence", [])
    if not variants is Array:
        return false
    if Array(variants).is_empty():
        return true
    var index: int = clampi(sequence_index, 0, Array(variants).size() - 1)
    return Array(Array(variants)[index]).is_empty()


## InputStatusCheck for the reaction links.  The recovered block links carry
## keystatus [[["left","pressed"]]] in every layout variant; `probe.status`
## supplies the pressed state of that token.
func status_ok(link: Dictionary, status: Dictionary) -> bool:
    var variants: Variant = link.get("keystatus", [])
    if not variants is Array or Array(variants).is_empty():
        return false
    var pairs: Array = Array(Array(variants)[0])
    for pair_value: Variant in pairs:
        var pair: Array = Array(pair_value)
        if pair.size() < 2:
            continue
        var token: String = str(pair[0])
        var want: bool = str(pair[1]) == "pressed"
        if bool(status.get(token, false)) != want:
            return false
    return true


## CheckConditions for one recovered condition name.
## `probe` carries the values the native code reads (see file header).
func condition_ok(condition: String, probe: Dictionary) -> bool:
    var attacker: Dictionary = Dictionary(probe.get("attacker", {}))
    match condition:
        "impact":
            if not bool(attacker.get("impact_active", false)):
                return false
            # 0x1a42e4: distance <= record.radius * opponent+0x15C + GetRadius()
            var reach: float = (
                float(attacker.get("radius", 0.0))
                * float(attacker.get("scale", 1.0))
                + float(probe.get("victim_radius", 0.0))
            )
            if float(probe.get("distance", INF)) > reach:
                return false
            # 0x1a4388: the record still has an unspent impact
            return int(attacker.get("last_index", -1)) >= int(attacker.get("cursor", 0))
        "healthzero":
            # 0x1a43b4: AttackDamage(opponent) >= victim health
            return float(probe.get("incoming_damage", 0.0)) >= float(probe.get("health", 0.0))
        "oppattackheightlow":
            return str(attacker.get("height", "")) == "low"
        "oppattackheightmed":
            return str(attacker.get("height", "")) in ["medium", "med"]
        "oppattackheighthigh":
            return str(attacker.get("height", "")) == "high"
        "oppattackstrengthnormal":
            return str(attacker.get("strength", "")) == "normal"
        "oppattackstrengthmedium":
            return str(attacker.get("strength", "")) == "medium"
        "oppattackstrengthhard":
            return str(attacker.get("strength", "")) == "hard"
        "oppattackstrengthbrutal":
            return str(attacker.get("strength", "")) == "brutal"
        "oppattackdirfrontal":
            return str(attacker.get("direction", "")) == "frontal"
        "oppattackdirfromleft":
            return str(attacker.get("direction", "")) == "fromleft"
        "oppattackdirfromright":
            return str(attacker.get("direction", "")) == "fromright"
        "oppattackdirfromabove":
            return str(attacker.get("direction", "")) == "fromabove"
        "oppattackdirfromair":
            # 0x1a4208 compares record+0x20 with OppAttackDirFromAir.
            return str(attacker.get("direction", "")) == "fromair"
    if extra_condition_eval.is_valid():
        return bool(extra_condition_eval.call(condition, probe))
    return false


## The recovered reaction link loop (UserControlUpdate).  Returns {} when no
## link matches, which the caller must treat as "no reaction" (fail closed).
## The returned dictionary is the native link row plus "result" metadata.
func resolve(probe: Dictionary) -> Dictionary:
    if not can_follow():
        # Native: a parked link returns before the link loop runs.
        _record("blocked-by-pending", {}, float(probe.get("frame", 0.0)), {})
        return {}
    var action: String = str(probe.get("action", ""))
    if action.is_empty():
        return {}
    var frame: float = float(probe.get("frame", 0.0))
    var status: Dictionary = Dictionary(probe.get("status", {}))
    var considered: int = 0
    var last_skip: String = ""
    for link: Dictionary in links:
        if not _applies_to(link, action):
            continue
        considered += 1
        if not sequence_ok(link):
            last_skip = "needs-key-events order=%s" % str(link.get("order", -1))
            continue
        var window: Array = link_window(link, action)
        if window.size() < 2:
            last_skip = "no-window order=%s" % str(link.get("order", -1))
            continue
        var linking_frame: int = link_target_frame(link)
        if not _in_window(window, frame, linking_frame):
            last_skip = "out-of-window order=%s %s frame=%s" % [
                str(link.get("order", -1)), str(window), str(frame)]
            continue
        var conditions: Array = Array(link.get("conditions", []))
        var keys: Array = Array(link.get("keystatus", []))
        var needs_status: bool = false
        for variant: Variant in keys:
            if Array(variant).size() > 0:
                needs_status = true
                break
        if needs_status and not status_ok(link, status):
            last_skip = "status order=%s" % str(link.get("order", -1))
            continue
        var failed: String = ""
        for condition: Variant in conditions:
            if not condition_ok(str(condition), probe):
                failed = str(condition)
                break
        if not failed.is_empty():
            last_skip = "condition %s order=%s to=%s" % [
                failed, str(link.get("order", -1)), str(link.get("to", ""))]
            continue
        var out: Dictionary = link.duplicate(true)
        out["result"] = REASON_OK
        _record("match", link, frame, {"order": link.get("order", -1)})
        return out
    _record("no-match", {}, frame, {"considered": considered,
        "last_skip": last_skip, "action": action})
    return {}


## JSON null arrives as Variant nil; str(nil) is "<null>", so nulls are
## normalised here instead of being compared as text.
func _text(value: Variant) -> String:
    if value == null:
        return ""
    return str(value)


func _applies_to(link: Dictionary, action: String) -> bool:
    if not is_reaction_target(_text(link.get("to"))):
        return false
    var source: String = _text(link.get("from"))
    if not source.is_empty():
        return source == action
    var group: String = _text(link.get("from_group"))
    if group.is_empty():
        return false
    var row: Dictionary = actions.get(action, {})
    var groups: Variant = row.get("groups", {})
    if not groups is Dictionary:
        return false
    return Dictionary(groups).has(group)


## CFighter::DamageReceiveCheck gate for the animation the fighter just
## entered: true only when that animation carries the "ReceiveDamage" group.
## A block animation carries only `canblock*`, so a blocked hit deals no damage.
func damage_applies(new_action: String, attacker: Dictionary) -> bool:
    if not bool(attacker.get("impact_active", false)):
        return false
    var row: Dictionary = actions.get(new_action, {})
    var groups: Variant = row.get("groups", {})
    if not groups is Dictionary:
        return false
    if not Dictionary(groups).has(DAMAGE_GROUP):
        return false
    return int(attacker.get("last_index", -1)) >= int(attacker.get("cursor", 0))


## Damage amount of the attacker's current record:
## u32(record.damage(+0x10) * attacker damage scale(+0x154)).
func damage_amount(attacker: Dictionary, damage_scale: float) -> int:
    return int(float(attacker.get("damage", 0.0)) * damage_scale)


func _record(kind: String, link: Dictionary, frame: float, extra: Dictionary) -> void:
    var row: Dictionary = {
        "kind": kind,
        "frame": frame,
        "order": link.get("order", -1),
        "to": link.get("to", ""),
        "from_group": link.get("from_group", ""),
    }
    row.merge(extra, true)
    trace.append(row)


func describe() -> Dictionary:
    return {
        "links": links.size(),
        "actions": actions.size(),
        "pending": pending_link.get("to", ""),
        "pending_frame": pending_frame,
        "can_follow": can_follow(),
        "load_error": load_error,
        "recovered_conditions": RECOVERED_CONDITIONS,
        "damage_group": DAMAGE_GROUP,
        "trace": trace,
    }

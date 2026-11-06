extends RefCounted
## Proven native action-selection rule, isolated for review before any port change.
##
## Evidence (direct ARM disassembly, libdefault.so sha256
## 1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70):
##   * krm::CDecisionTree::MakeDecision @ ELF 0x00220d6c returns a terminal
##     node's embedded action vector at node+8.  It does not rank actions.
##   * krm::CFighter::AIUpdate @ ELF 0x001a8b2c calls MakeDecision, then scans
##     the active-set link array from index 0 upward.  Link array/count/stride
##     come from GetActiveSetAnimation()->+0x104/+0x100/+0x108.  The first link
##     satisfying all three gates below is followed:
##       1. TimeWindowCheck(link) != 0
##       2. link action is in the decision action set
##          OR the link has no key-sequence and no key-status requirement
##       3. CheckConditions(link+0xb8) != 0
##   * No RNG or per-action weight exists in either MakeDecision or AIUpdate.
##     RNG lives only in condition objects (CRandomProbability::Check and
##     CProfileProbCondition::Check: zmathRandomGet()%1000 < int(p*1000)).
##
## This module deliberately takes the ordered links and the already-evaluated
## native gates as inputs.  It never sorts links, never consults leaf action
## order, never invents a probability/weight/window, and fails closed when any
## required native fact is absent.

const REQUIRED_LINK_FIELDS: Array[String] = [
    "action",
    "time_window_open",
    "has_key_sequence",
    "has_key_status",
    "conditions_pass",
]
const FORBIDDEN_LINK_FIELDS: Array[String] = [
    "weight", "probability", "priority", "chance",
]


static func _fail(reason: String) -> Dictionary:
    return {
        "ok": false,
        "selected": false,
        "index": -1,
        "action": "",
        "reason": reason,
        "evaluations": [],
    }


static func select_first_eligible(links: Array, decision_actions: Array) -> Dictionary:
    if links == null or decision_actions == null:
        return _fail("missing_inputs")
    var decision_set: Dictionary = {}
    for value: Variant in decision_actions:
        if typeof(value) != TYPE_STRING:
            return _fail("decision_action_not_string")
        decision_set[value] = true

    var evaluations: Array[Dictionary] = []
    for index in range(links.size()):
        var value: Variant = links[index]
        if typeof(value) != TYPE_DICTIONARY:
            return _fail("link_not_dictionary:%d" % index)
        var link: Dictionary = value
        for field: String in FORBIDDEN_LINK_FIELDS:
            if link.has(field):
                return _fail("forbidden_weight_like_field:%s" % field)
        for field: String in REQUIRED_LINK_FIELDS:
            if not link.has(field):
                return _fail("missing_link_field:%s" % field)
        if typeof(link["action"]) != TYPE_STRING:
            return _fail("link_action_not_string:%d" % index)
        if typeof(link["time_window_open"]) != TYPE_BOOL:
            return _fail("time_window_open_not_bool:%d" % index)
        if typeof(link["has_key_sequence"]) != TYPE_BOOL:
            return _fail("has_key_sequence_not_bool:%d" % index)
        if typeof(link["has_key_status"]) != TYPE_BOOL:
            return _fail("has_key_status_not_bool:%d" % index)
        if typeof(link["conditions_pass"]) != TYPE_BOOL:
            return _fail("conditions_pass_not_bool:%d" % index)

        var action: String = link["action"]
        if action.is_empty():
            return _fail("empty_link_action:%d" % index)
        var listed: bool = decision_set.has(action)
        var no_key_requirement: bool = (
            not bool(link["has_key_sequence"]) and not bool(link["has_key_status"])
        )
        var action_gate: bool = listed or no_key_requirement
        var gate_reason: String
        if listed:
            gate_reason = "listed"
        elif no_key_requirement:
            gate_reason = "no_key_requirement"
        else:
            gate_reason = "unlisted_with_key_requirement"

        var selected: bool = (
            bool(link["time_window_open"])
            and action_gate
            and bool(link["conditions_pass"])
        )
        evaluations.append({
            "index": index,
            "action": action,
            "listed": listed,
            "no_key_requirement": no_key_requirement,
            "action_gate": action_gate,
            "gate_reason": gate_reason,
            "time_window_open": link["time_window_open"],
            "conditions_pass": link["conditions_pass"],
            "selected": selected,
        })
        if selected:
            return {
                "ok": true,
                "selected": true,
                "index": index,
                "action": action,
                "reason": "first_eligible_native_link",
                "evaluations": evaluations,
            }

    return {
        "ok": true,
        "selected": false,
        "index": -1,
        "action": "",
        "reason": "no_eligible_link",
        "evaluations": evaluations,
    }

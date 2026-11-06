extends RefCounted
## Resolve style availability from the live progress service. It contains the
## native Unlocker/CharacterList flags loaded at startup and later grants.
const UnlockRegistryScript = preload("res://scripts/unlock_registry.gd")
var progress: Node = null
var registry = null
var registry_ok := false

func _init() -> void:
    refresh()

func refresh() -> bool:
    registry = UnlockRegistryScript.new()
    registry_ok = registry.load_data()
    return registry_ok

func state_for(entry: Dictionary) -> Dictionary:
    var state := {"available": false, "reason": "", "unlock_id": -1, "exp": 0}
    if entry.is_empty():
        state.reason = "unknown_entry"
        return state
    if entry.get("always_available", false) == true:
        state.available = true
        state.reason = "always_available"
        return state
    var row = entry.get("unlock", null)
    if not row is Dictionary:
        state.reason = "no_unlock_rule"
        return state
    var id := int(row.get("id", -1))
    state.unlock_id = id
    state.exp = int(row.get("exp", 0))
    if not registry_ok:
        state.reason = "unlock_data_missing"
        return state
    if id < 0 or id >= registry.num_ids:
        state.reason = "unknown_unlock_id"
        return state
    var grant: Dictionary = registry.entry_for_id(id)
    if grant.is_empty():
        state.reason = "unknown_unlock_id"
        return state
    if String(grant.get("item_type", "")) != String(row.get("item_type", "")) or String(grant.get("item_id", "")) != String(entry.get("id", "")):
        state.reason = "unlock_rule_mismatch"
        return state
    if grant.get("source", "") == "story_exp" and int(grant.get("exp", -1)) != state.exp:
        state.reason = "unlock_rule_mismatch"
        return state
    if not is_instance_valid(progress) or not bool(progress.get("active")) or progress.get("service") == null:
        state.reason = "progress_unavailable"
        return state
    if progress.get("service").unlocked_ids().has(id):
        state.available = true
        state.reason = "unlocked"
    else:
        state.reason = "locked"
    return state

func summary() -> Dictionary:
    return {"registry_ok": registry_ok, "progress_active": is_instance_valid(progress) and bool(progress.get("active"))}

extends RefCounted
class_name StyleClipMap

## Direct-clip rules shared by the Style Editor screen and the fighter.
##
## A selection changes gameplay ONLY when all of these hold:
##   1. the style entry has exactly one clip from its character's existing
##      attack table (generated at build time; no fuzzy or invented mapping),
##   2. the active fighter has a slot for that group,
##   3. the clip is actually present in the fighter's loaded animation library,
##   4. the slot is not a size-variant slot whose current clip differs
##      (fighter._prepare_size_variant would otherwise re-resolve it).
## Anything else is reported and left untouched (fail closed).

const GROUP_PLAYER_SLOTS: Dictionary = {
    ## Personality is decoded and selectable, but the combat prototype has no
    ## personality state: resolve() always returns no_combat_slot. The empty
    ## slot list keeps it in the report without ever applying a combat clip.
    "personality/personality": [],
    "special/hpunch": ["special_punch_high_hit", "special_punch_high"],
    "special/lpunch": ["special_punch_low_hit", "special_punch_low"],
    "special/hkick": ["special_kick_high", "special_kick_high_brick"],
    "special/lkick": ["special_kick_low_hit", "special_kick_low"],
    "grabs/graba": ["grab1", "grab1_brick"],
    "grabs/grabb": ["grab2", "grab2_brick"],
    "endmove/endmove": ["endattack2", "endattack", "endattack1"],
}

## Mirrors fighter.SIZE_CLASS_ATTACKS. Those slots are resolved again by
## _prepare_size_variant from their base clip, so swapping in a different clip
## would either be overwritten or make the grab/finisher fail closed. A style
## clip is accepted there only when it is already the slot's clip (identity).
const SIZE_VARIANT_SLOTS: Dictionary = {
    "grab1": true, "grab2": true,
    "grab1_brick": true, "grab2_brick": true,
    "grab1_miss": true, "grab2_miss": true,
    "grab1_miss_brick": true, "grab2_miss_brick": true,
    "endattack1": true, "endattack2": true,
    "endattack": true, "endattack_brick": true,
    "special_punch_high_hit": true,
}

const ALL_PLAYER_SLOTS: Array[String] = [
    "special_punch_high_hit", "special_punch_high",
    "special_punch_low_hit", "special_punch_low",
    "special_kick_high", "special_kick_high_brick",
    "special_kick_low_hit", "special_kick_low",
    "grab1", "grab1_brick", "grab2", "grab2_brick",
    "endattack1", "endattack2", "endattack", "endattack_brick",
]


static func target_slot(group_key: String, slot_clips: Dictionary) -> String:
    for slot in GROUP_PLAYER_SLOTS.get(group_key, []):
        if slot_clips.has(slot):
            return String(slot)
    return ""


## entry: one decoded style entry (see style_catalog.gd).
## slot_clips: the fighter's _candidate_clip_paths (slot -> current clip).
## animations: the set of animation names present in the loaded library.
static func resolve(entry: Dictionary, slot_clips: Dictionary, animations: Dictionary) -> Dictionary:
    var group_key: String = String(entry.get("group", ""))
    var category: String = String(entry.get("category", ""))
    var named: Array = entry.get("named_clips", [])
    if category == "personality":
        var loaded_named: Array = []
        for clip in named:
            if animations.has(String(clip)):
                loaded_named.append(String(clip))
        return {
            "status": "no_combat_slot",
            "applied": false,
            "clip": "",
            "slot": "",
            "named_clips": named,
            "named_loaded": loaded_named,
            "reason": "personality clips are named but the combat prototype has no personality state",
        }
    var clip: String = String(entry.get("clip", ""))
    if clip.is_empty():
        return {
            "status": "no_direct_clip",
            "applied": false,
            "clip": "",
            "slot": "",
            "named_clips": [],
            "named_loaded": [],
            "reason": String(entry.get("clip_reason", "no exact source_action row")),
        }
    if not GROUP_PLAYER_SLOTS.has(group_key):
        return {
            "status": "no_slot",
            "applied": false,
            "clip": clip,
            "slot": "",
            "named_clips": [],
            "named_loaded": [],
            "reason": "no gameplay slot is defined for " + group_key,
        }
    var slot: String = target_slot(group_key, slot_clips)
    if slot.is_empty():
        return {
            "status": "slot_missing",
            "applied": false,
            "clip": clip,
            "slot": "",
            "named_clips": [],
            "named_loaded": [],
            "reason": "the active fighter has no slot for this group",
        }
    var current: String = String(slot_clips.get(slot, ""))
    if SIZE_VARIANT_SLOTS.has(slot) and current != clip:
        return {
            "status": "size_variant_refused",
            "applied": false,
            "clip": clip,
            "slot": slot,
            "named_clips": [],
            "named_loaded": [],
            "reason": "size-variant slot keeps its own clip (%s)" % current,
        }
    if not animations.has(clip):
        return {
            "status": "clip_not_loaded",
            "applied": false,
            "clip": clip,
            "slot": slot,
            "named_clips": [],
            "named_loaded": [],
            "reason": "clip %s is not present in this fighter's loaded library" % clip,
        }
    return {
        "status": "apply",
        "applied": true,
        "clip": clip,
        "slot": slot,
        "named_clips": [],
        "named_loaded": [],
        "reason": "direct clip for %s" % slot,
    }


static func status_text(result: Dictionary) -> String:
    match String(result.get("status", "")):
        "apply":
            return "DIRECT CLIP APPLIED · %s" % String(result.get("clip", ""))
        "no_combat_slot":
            var named: Array = result.get("named_clips", [])
            if named.is_empty():
                return "NO COMBAT SLOT · key/name shown, not applied"
            return "NO COMBAT SLOT · named clips %s" % ", ".join(
                PackedStringArray(named)
            )
        "no_direct_clip":
            return "NO DIRECT CLIP · key/name shown, not applied"
        "clip_not_loaded":
            return "CLIP NOT LOADED · %s" % String(result.get("clip", ""))
        "size_variant_refused":
            return "SIZE VARIANT · not applied"
        "slot_missing":
            return "NO FIGHTER SLOT · not applied"
        "no_slot":
            return "NO GAMEPLAY SLOT · not applied"
        _:
            return "NOT APPLIED · " + String(result.get("reason", ""))

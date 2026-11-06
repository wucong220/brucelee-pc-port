extends RefCounted
class_name NativeConditions
## Single source of truth for every `CheckConditions` token a native fighting
## link can carry, recovered from krm::CFighter::CheckConditions.
##
## Evidence (read-only): libdefault.so sha256
## 1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70
##
##   krm::CFighter::CheckConditions @ ELF 0x001a3920 (Ghidra 0x001b3920)
##   The function walks the link condition vector.  Each token is a runtime
##   interned `krm::gid_*` HashString compared against a global handle; the
##   comparison then reads CFighter fields.  The literal pool at ELF
##   0x001a4038..0x001a40e4 plus .got/.rel.dyn/.dynsym resolve every handle to
##   its `gid_*` symbol (evidence/token_map.json):
##
##     token                         gid symbol                    dispatch site
##     impact                        gid_Impact                    0x1a396c
##     oppabouttograb                gid_OppAboutToGrab            0x1a3960
##     oppattackheightmed            gid_OppAttackHeightMedium     0x1a3974
##     oppattackheighthigh           gid_OppAttackHeightHigh       0x1a397c
##     oppattackheightlow            gid_OppAttackHeightLow        0x1a398c
##     oppattackstrengthnormal       gid_OppAttackStrengthNormal   0x1a3984
##     oppattackstrengthmedium       gid_OppAttackStrengthMedium   0x1a399c
##     oppattackstrengthhard         gid_OppAttackStrengthHard     0x1a3994
##     oppattackstrengthbrutal       gid_OppAttackStrengthBrutal   0x1a39a8
##     oppattackdirfrontal           gid_OppAttackDirFrontal       0x1a3ab4
##     oppattackdirfromleft          gid_OppAttackDirFromLeft      0x1a3ac8
##     oppattackdirfromright         gid_OppAttackDirFromRight     0x1a3adc
##     oppattackdirfromair           gid_OppAttackDirFromAir       0x1a3af0
##     oppattackdirfromabove         gid_OppAttackDirFromAbove     0x1a3b04
##     oppnotblocking                gid_OppNotBlocking            0x1a3b18
##     oppposelaying                 gid_OppPoseLaying              0x1a3b2c
##     oppposestand                  gid_OppPoseStand               0x1a3b40
##     oppposestun                   gid_OppPoseStun                0x1a3b54
##     maxrage                       gid_MaxRage                   0x1a3b68
##     rage2thirds                   gid_Rage2Thirds               0x1a3b7c
##     ragethird                     gid_RageThird                 0x1a3b90
##     countertime                   gid_CounterTime               0x1a3ba4
##     grabdistance                  gid_GrabDistance              0x1a3bb8
##     healthzero                    gid_HealthZero                0x1a3bcc
##     oppinfront                    gid_OppInFront                0x1a3be0
##     oppinback                     gid_OppInBack                 0x1a3bf4
##
## IMPLEMENTED_TOKENS contains every token carried by an exported link table
## (21) plus oppattackdirfromair, which is recovered from the same function but
## is not carried by any exported set link.  oppabouttograb, maxrage, oppinfront
## and oppinback are also recovered from the same function but do not occur in
## the exported set link tables; they are still evaluated (so a future export
## cannot silently acquire a guessed semantic) and are documented in
## RECOVERED_UNUSED_TOKENS.
##
## Field facts read by these checks (ELF offsets on CFighter `this`):
##   +0x7c   opponent fighter pointer
##   +0x80   cached 3D distance produced by CBeatEmUpGame::CollisionChecker
##   +0x144  health
##   +0x14c  rage (uint)
##   +0x151  force-conditions / rage-ignore byte (Init clears)
##   +0x152  dummy-health byte (Init clears; only reader enables ModifyHealth(100))
##   +0x154  damage multiplier (AttackDamage)
##   +0x15c  radius scale
##   +0x164  current active impact record (0 when no impact window contains frame)
##   +0x168  first impact record at/after the current frame (BasicUpdate
##           0x1a8330); this is what oppattackheighthigh reads, NOT +0x164
##   +0x16c  processed-impact high-water byte
##
## The evaluator takes a canonical probe.  Every field is explicit so the same
## function serves the fighter link scan, the AI link scan and the reaction gate:
##   self_pose / opponent_pose        animation pose string (animation +0xac)
##   self_radius / opponent_radius    GetRadius() source units
##   opponent_scale                   radius scale (+0x15c)
##   distance                         +0x80 in source units
##   self_health, self_rage            +0x144, +0x14c
##   self_rage_forced, self_dummy_health  +0x151, +0x152 (false in the port)
##   incoming_damage                  AttackDamage(opponent) integer
##   counter_open                     IsInCounterTime(opponent)
##   opponent_blocking                IsBlocking(opponent)
##   opponent_attacking               IsAttacking(opponent) == +0x164 != 0
##   opponent_active_impact           record at +0x164 or null
##   opponent_next_impact             record at +0x168 or null
##   opponent_processed               +0x16c byte
##
## An impact record is a Dictionary {id:int, start:int, end:int, radius:float,
## height:String, strength:String, direction:String}.  A token outside this
## table returns FALSE (fail closed, never guessed true).

const IMPLEMENTED_TOKENS: Array[String] = [
    "impact", "healthzero",
    "oppattackheightlow", "oppattackheightmed", "oppattackheighthigh",
    "oppattackstrengthnormal", "oppattackstrengthmedium",
    "oppattackstrengthhard", "oppattackstrengthbrutal",
    "oppattackdirfrontal", "oppattackdirfromleft", "oppattackdirfromright",
    "oppattackdirfromabove", "oppattackdirfromair",
    "oppnotblocking", "oppposelaying", "oppposestand", "oppposestun",
    "ragethird", "rage2thirds", "countertime", "grabdistance",
]

## Recovered by the same function but absent from every exported set link table.
const RECOVERED_UNUSED_TOKENS: Array[String] = [
    "oppabouttograb", "maxrage", "oppinfront", "oppinback",
]

const RAGE_THIRD: float = 33.0      # 0x21
const RAGE_TWO_THIRDS: float = 66.0 # 0x42
const RAGE_MAX: float = 100.0
const GRAB_DISTANCE_SLACK: float = 25.0   # DAT_001b4038 = 25.0f
const ABOUT_TO_GRAB_SLACK: float = 15.0   # DAT_001b40e4 = 15.0f


static func is_known(token: String) -> bool:
    return IMPLEMENTED_TOKENS.has(token) or RECOVERED_UNUSED_TOKENS.has(token)


## Pure evaluation of one token.  Unknown tokens (including empty) fail closed.
static func evaluate(token: String, probe: Dictionary) -> bool:
    match token:
        "impact":
            var active: Variant = probe.get("opponent_active_impact")
            if active == null or not bool(probe.get("opponent_attacking", false)):
                return false
            var record: Dictionary = active
            # 0x1a42e4: distance <= impact.radius(+0x10) * opponent+0x15C
            #           + GetRadius(this)  (all source units)
            var reach: float = (
                float(record.get("radius", 0.0))
                * float(probe.get("opponent_scale", 1.0))
                + float(probe.get("self_radius", 0.0))
            )
            if float(probe.get("distance", INF)) > reach:
                return false
            # 0x1a4388: opponent+0x16C <= impact+0 (unspent record)
            return int(probe.get("opponent_processed", 0)) <= int(record.get("id", 0))

        "healthzero":
            # 0x1a43b4: this[0x152] == 0 and AttackDamage(opponent) >= health
            if bool(probe.get("self_dummy_health", false)):
                return false
            return float(probe.get("incoming_damage", 0.0)) >= float(probe.get("self_health", 0.0))

        "oppposestun":
            return _opponent_pose(probe) == "stun"
        "oppposestand":
            return _opponent_pose(probe) == "stand"
        "oppposelaying":
            return _opponent_pose(probe) == "laying"

        "oppnotblocking":
            return not bool(probe.get("opponent_blocking", false))

        "grabdistance":
            # 0x1a3d08: distance <= GetRadius(opponent) + GetRadius(this) + 25.0f
            return float(probe.get("distance", INF)) <= (
                float(probe.get("opponent_radius", 0.0))
                + float(probe.get("self_radius", 0.0))
                + GRAB_DISTANCE_SLACK
            )

        "ragethird":
            # 0x1a4374: fail only while rage < 0x21 and +0x151 == 0
            return float(probe.get("self_rage", 0.0)) >= RAGE_THIRD or bool(
                probe.get("self_rage_forced", false)
            )
        "rage2thirds":
            # 0x1a4360: fail only while rage < 0x42 and +0x151 == 0
            return float(probe.get("self_rage", 0.0)) >= RAGE_TWO_THIRDS or bool(
                probe.get("self_rage_forced", false)
            )
        "maxrage":
            # 0x1a434c: fail only while rage < 100 and +0x151 == 0
            return float(probe.get("self_rage", 0.0)) >= RAGE_MAX or bool(
                probe.get("self_rage_forced", false)
            )

        "countertime":
            # 0x1a3cc4: IsInCounterTime(opponent): anim+0xd8 <= frame <= anim+0xdc
            return bool(probe.get("counter_open", false))

        "oppattackheightlow":
            return _field(probe.get("opponent_active_impact"), "height", "low")
        "oppattackheightmed":
            return _field(probe.get("opponent_active_impact"), "height", "medium")
        "oppattackheighthigh":
            # 0x1a4298 reads opponent+0x168 (BasicUpdate: first impact record at
            # or after the current frame), unlike every other height/strength/
            # direction check which reads +0x164.  This asymmetry is native.
            return _field(probe.get("opponent_next_impact"), "height", "high")

        "oppattackstrengthnormal":
            return _field(probe.get("opponent_active_impact"), "strength", "normal")
        "oppattackstrengthmedium":
            return _field(probe.get("opponent_active_impact"), "strength", "medium")
        "oppattackstrengthhard":
            return _field(probe.get("opponent_active_impact"), "strength", "hard")
        "oppattackstrengthbrutal":
            return _field(probe.get("opponent_active_impact"), "strength", "brutal")

        "oppattackdirfrontal":
            return _field(probe.get("opponent_active_impact"), "direction", "frontal")
        "oppattackdirfromleft":
            return _field(probe.get("opponent_active_impact"), "direction", "fromleft")
        "oppattackdirfromright":
            return _field(probe.get("opponent_active_impact"), "direction", "fromright")
        "oppattackdirfromabove":
            return _field(probe.get("opponent_active_impact"), "direction", "fromabove")
        "oppattackdirfromair":
            return _field(probe.get("opponent_active_impact"), "direction", "fromair")

        "oppabouttograb":
            # 0x1a4358: IsAboutToGrab(opponent) and
            #           distance <= GetRadius(opponent)+GetRadius(this)+15.0f
            if not bool(probe.get("opponent_about_to_grab", false)):
                return false
            return float(probe.get("distance", INF)) <= (
                float(probe.get("opponent_radius", 0.0))
                + float(probe.get("self_radius", 0.0))
                + ABOUT_TO_GRAB_SLACK
            )

        "oppinfront":
            # 0x1a439c: this+0xc4 >= 0 (relative facing dot)
            return float(probe.get("relative_facing_dot", 1.0)) >= 0.0
        "oppinback":
            # 0x1a43a8: this+0xc4 < 0
            return float(probe.get("relative_facing_dot", 1.0)) < 0.0
    return false


static func _opponent_pose(probe: Dictionary) -> String:
    return String(probe.get("opponent_pose", "")).to_lower()


static func _field(record: Variant, field: String, value: String) -> bool:
    if record == null:
        return false
    if not record is Dictionary:
        return false
    return String(Dictionary(record).get(field, "")).to_lower() == value


## Pick the impact records that BasicUpdate 0x1a8330 keeps for the opponent.
## `records` is the native action's impact list, already sorted by damage_time.
## Returns {active: Dictionary|null, next: Dictionary|null}; `next` is the
## first record whose end >= frame (BasicUpdate +0x168), `active` is the record
## whose [start,end] contains frame (+0x164).
static func impact_selection(records: Array, frame: float) -> Dictionary:
    var active: Variant = null
    var next: Variant = null
    for record_value: Variant in records:
        if not record_value is Dictionary:
            continue
        var record: Dictionary = record_value
        var start: float = float(record.get("start", 0))
        var end: float = float(record.get("end", 0))
        if frame + 0.0001 >= start and frame <= end + 0.0001:
            if active == null:
                active = record
        if next == null and end + 0.0001 >= frame:
            next = record
    return {"active": active, "next": next}

extends CharacterBody3D
class_name PortFighter
## Original clean-room placeholder implementation. Not extracted Android game code.

signal combat_hit(attacker: PortFighter, defender: PortFighter, action: String, damage: float, blocked: bool)
signal combat_ko(fighter: PortFighter)

const BASE_SPEED: float = 3.6
const MAX_HEALTH: float = 100.0
const CANDIDATE_SOURCE_MIN_Y: float = -0.09393310546875
const CANDIDATE_SOURCE_HEIGHT: float = 173.415954589844
const CANDIDATE_HEIGHT: float = 1.8
const CANDIDATE_FLOOR_Y: float = 0.0
const PLAYER_ORIGIN_HEIGHT: float = 1.2
const CANDIDATE_CLIPS: Dictionary = {
    "idle": "m01_idle_01",
    "punch": "m01_pnch_low_01",
    "kick": "m01_kick_low_01",
    "high_punch": "m01_pnch_high_01",
    "high_kick": "m01_kick_high_01",
    "high_punch3": "m01_pnch_high_03",
    "low_punch3": "m01_pnch_low_03",
    "low_kick3": "m01_kick_low_03",
    "high_kick3": "m01_sp_kick_jump_01",
    "special_kick_high": "m01_kck_front_step",
    "high_punch2": "m01_pnch_high_02",
    "low_punch2": "m01_pnch_low_02",
    "high_kick2": "m01_kick_high_02",
    "low_kick2": "m01_kick_low_02",
    "special_kick_low_miss": "m01_sp_kick_low_fail",
    "special_kick_low_hit": "m01_sp_kick_low",
    "special_punch_low_miss": "m01_sp_pnch_low_fail",
    "special_punch_low_hit": "m01_sp_pnch_low",
    "special_punch_high_miss": "m01_sp_pnch_high_fail",
    "special_punch_high_hit": "m01_sp_pnch_high",
    "parry_high": "m01_parry_high",
    "parry_low": "m01_kick_low_02",
    "parry_attack": "m01_pnch_high_03",
    "grab1": "m01_grab_01",
    "grab2": "m01_grab_02",
    "grab1_miss": "m02_grab_01",
    "grab2_miss": "m02_grab_01",
    "endattack1": "m01_end_attack_01",
    "endattack2": "m01_end_attack_02",
    "stun": "all_stunned",
    "stun_fall": "all_stunned_fall",
    "stun_hard": "all_impct_hard_frnt_high",
    "stun_brutal": "all_impct_spectacular_lft",
}
const BRICK_CLIPS: Dictionary = {
    "idle": "m03_idle_01",
    "punch": "m03_pnch_low_01",
    "kick": "m03_kck_low_01",
    "move": "m03_movefwd",
}
const SOURCE_FRAME_RATE: float = 30.0
const SOURCE_CHARACTER_HEIGHT: float = CANDIDATE_SOURCE_HEIGHT
const WORLD_CHARACTER_HEIGHT: float = CANDIDATE_HEIGHT
const CANDIDATE_ATTACK_TO_FLOOR_BLENDING_FRAMES: int = 6
const CANDIDATE_ATTACK_TO_FLOOR_RETURN_BLENDING_FRAMES: int = 10
const CANDIDATE_BRICK_FACEDOWN_IMPACT_BLENDING_FRAMES: int = 6
const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")
const CandidateMaterialLoader = preload("res://scripts/candidate_material_loader.gd")
const CandidateBounds = preload("res://scripts/candidate_bounds.gd")
const HEAVY_ATTACK: Dictionary = {
    # No recovered fighting-set mapping for this prototype attack yet.
    "startup": 0.33, "active": 0.10, "recovery": 0.42,
    "range": 1.85, "damage": 19.0, "push": 0.55,
}
const ATTACK_CONFIG_PATH: String = "res://data/fighting_set_low_attacks.json"
const BRICK_ATTACK_CONFIG_PATH: String = "res://data/fighting_set_m03_mapped_attacks.json"
const SOURCE_ANIMATION_RADII_DATA: Dictionary = {
    "m01_idle_01": 25.0,
    "m01_pnch_low_01": 40.0,
    "m01_kick_low_01": 50.0,
    "m01_pnch_high_01": 45.0,
    "m01_kick_high_01": 60.0,
    "m01_pnch_high_03": 60.0,
    "m01_pnch_low_03": 40.0,
    "m01_kick_low_03": 50.0,
    "m01_sp_kick_jump_01": 60.0,
    "m01_kck_front_step": 65.0,
    "m01_pnch_high_02": 45.0,
    "m01_pnch_low_02": 40.0,
    "m01_kick_high_02": 60.0,
    "m01_kick_low_02": 50.0,
    "m01_sp_kick_low_fail": 25.0,
    "m01_sp_kick_low": 25.0,
    "m01_sp_pnch_low_fail": 25.0,
    "m01_sp_pnch_low": 25.0,
    "m01_sp_pnch_high_fail": 40.0,
    "m01_sp_pnch_high": 25.0,
    "m01_parry_high": 40.0,
    "m01_grab_01": 40.0,
    "m01_grab_02": 25.0,
    "m01_end_attack_01": 45.0,
    "m01_end_attack_02": 45.0,
    "all_impct_hard_frnt_high": 80.0,
    "all_impct_light_frnt_low": 40.0,
    "all_impct_light_frnt_mid": 40.0,
    "all_impct_light_frnt_high": 40.0,
    "all_block_low": 40.0,
    "all_block_mid": 40.0,
    "all_block_high": 40.0,
}
const IDLE2_CLIP: String = "m01_idle_02"
const FACEDOWN_IDLE_CLIP: String = "all_idle_face_down"
const BRICK_FACEDOWN_IDLE_CLIP: String = "all_idle_face_down_forbigguy"
const BRICK_FRONT_LOW_CLIP: String = "all_impct_hard_frnt_low"
const BRICK_FRONT_LOW_REACTION: Dictionary = {
    "source_action": "impacthardfrontlow",
    "animation": BRICK_FRONT_LOW_CLIP,
    "animation_radius": 80.0,
    # The source gives [20,23]; frame 20 is a prototype choice.
    "exit_start_frame": 20,
    "animation_duration_frames": 23,
    "return_action": "facedownidle",
    "clip_implemented": false,
}
const FACEDOWN_GETUP_CLIP: String = "all_getup_facedwn"
const IDLE2_DURATION_FRAMES: int = 43
const FACEDOWN_IDLE_DURATION_FRAMES: int = 45
const FACEDOWN_GETUP_WINDOW_START: int = 10
const FACEDOWN_GETUP_WINDOW_END: int = 45
const FACEDOWN_GETUP_EXIT_FRAME: int = 16
const FACEDOWN_IMPACT_CLIP: String = "all_impct_facedwn"
const FACEDOWN_IMPACT_EXIT_FRAME: int = 11
const BRICK_FACEDOWN_IMPACT_RADIUS: float = 85.0
const BRICK_FACEDOWN_IMPACT_REACTION: Dictionary = {
    "source_action": "impactfacedown",
    "animation": FACEDOWN_IMPACT_CLIP,
    "animation_radius": BRICK_FACEDOWN_IMPACT_RADIUS,
    # thai.set link 88 runs over facedownidle [0,45]. The impact clip's
    # return link 182 reaches facedownidle at frame 11.
    "exit_start_frame": FACEDOWN_IMPACT_EXIT_FRAME,
    "animation_duration_frames": 11,
    "return_action": "facedownidle",
    "clip_implemented": false,
}
const FACEDOWN_KO_RADIUS: float = 100.0
const FACEDOWN_ATTACK_CLIP: String = "all_getup_facedwn_attack"
const FACEDOWN_ATTACK_DURATION_FRAMES: int = 35
const FACEDOWN_ATTACK_EXIT_FRAME: int = 32
const FACEDOWN_ATTACK_DAMAGE_START_FRAME: int = 6
const FACEDOWN_ATTACK_DAMAGE_END_FRAME: int = 9
const FACEDOWN_ATTACK_DAMAGE: float = 6.0
const FACEDOWN_ATTACK_RADIUS: float = 120.0
const FACEUP_IMPACT_TO_FLOOR_CLIP: String = "all_stunned_fall"
const FACEUP_IDLE_CLIP: String = "all_idle_face_up"
const FACEUP_IMPACT_TO_FLOOR_DURATION_FRAMES: int = 79
const FACEUP_IMPACT_TO_FLOOR_ENTRY_FRAME: int = 21
const FACEUP_IMPACT_TO_FLOOR_EXIT_FRAME: int = 48
const FACEUP_IDLE_DURATION_FRAMES: int = 45
const FACEUP_GETUP_CLIP: String = "all_getup_faceup"
const FACEUP_GETUP_DURATION_FRAMES: int = 24
const FACEUP_GETUP_WINDOW_START: int = 10
const FACEUP_GETUP_WINDOW_END: int = 45
# The source links to idle over [20,24]. Switching at source frame 20 is a
# deterministic candidate choice, not proof of the original transition frame.
const FACEUP_GETUP_EXIT_FRAME: int = 20
const FACEUP_ATTACK_CLIP: String = "all_getup_faceup_attack"
const FACEUP_ATTACK_DURATION_FRAMES: int = 38
const FACEUP_ATTACK_EXIT_FRAME: int = 37
const FACEUP_ATTACK_DAMAGE_START_FRAME: int = 9
const FACEUP_ATTACK_DAMAGE_END_FRAME: int = 14
const FACEUP_ATTACK_DAMAGE: float = 6.0
const FACEUP_ATTACK_RADIUS: float = 90.0
const FACEUP_IMPACT_CLIP: String = "all_impct_faceup"
const FACEUP_IMPACT_DURATION_FRAMES: int = 11
const FACEUP_IMPACT_EXIT_FRAME: int = 11
const FACEUP_KO_RADIUS: float = 100.0
const ATTACK_TO_FLOOR_CLIP: String = "m01_attack_to_floor"
const ATTACK_TO_FLOOR_DURATION_FRAMES: int = 90
const ATTACK_TO_FLOOR_ENTRY_FRAME: int = 9
const ATTACK_TO_FLOOR_EXIT_START_FRAME: int = 80
const ATTACK_TO_FLOOR_DAMAGE_START_FRAME: int = 18
const ATTACK_TO_FLOOR_DAMAGE_END_FRAME: int = 23
const ATTACK_TO_FLOOR_DAMAGE: float = 6.0
const ATTACK_TO_FLOOR_RADIUS: float = 60.0
const ATTACK_TO_FLOOR_IMPACT: Dictionary = {
    "strength": "normal", "height": "low", "direction": "frontal",
    "body_part": "lleg", "attack_radius": ATTACK_TO_FLOOR_RADIUS,
}
const ATTACK_TO_FLOOR_SEQUENCES: Array[Array] = [["b", "c", "c"], ["b", "d", "d"]]
const STANDING_COMBO_INPUT_PROTOTYPE_WINDOW_SECONDS: float = 0.5
const RAGE_MAX: float = 100.0
const RAGE_GAIN_PER_HIT: float = 10.0
# Prototype meter: ragethird is 33, rage2thirds is 66. The native scale is unverified.
const SPECIAL_RAGE_COSTS: Dictionary = {
    "special_kick_high": 33.0,
    "special_kick_low_miss": 66.0,
    "special_punch_low_miss": 66.0,
    "special_punch_high_miss": 66.0,
    "grab1": 66.0,
    "grab2": 66.0,
    "grab1_miss": 66.0,
    "grab2_miss": 66.0,
}
const SPECIAL_CHAIN_MISSES: Dictionary = {
    "special_kick_low_miss": "special_kick_low_hit",
    "special_punch_low_miss": "special_punch_low_hit",
    "special_punch_high_miss": "special_punch_high_hit",
    "parry_high": "parry_attack",
    "grab1_miss": "grab1",
    "grab2_miss": "grab2",
}
const SPECIAL_REQUIRES_STEPBACK: Dictionary = {
    "special_kick_high": true,
    "special_kick_low_miss": true,
}
const SPECIAL_CHAIN_WINDOW: Dictionary = {
    "special_kick_low_miss": [14, 16],
    "special_punch_low_miss": [8, 9],
    "special_punch_high_miss": [6, 7],
    "grab1_miss": [8, 9],
    "grab2_miss": [8, 9],
}
const PROTOTYPE_GRAB_DISTANCE: float = 0.62
const STUN_CLIP: String = "all_stunned"
const STUN_FALL_CLIP: String = "all_stunned_fall"
# Source windows: stun->stun2 and stun2->stunfall [55,61]; stunfall->faceupko [71,79].
# The PC candidate selects each window start.
const STUN_DURATION_FRAMES: int = 55
const STUN_FALL_DURATION_FRAMES: int = 71
const STUN_IMPACT_ENTRY_FRAMES: int = 14
const GRAB_ATTACKS: Dictionary = {"grab1": true, "grab2": true}
const PARRY_RAGE_COSTS: Dictionary = {"parry_high": 33.0, "parry_low": 30.0}
const ENDATTACK_ATTACKS: Dictionary = {"endattack1": true, "endattack2": true}
const NON_CONTACT_ATTACKS: Dictionary = {"endattack1": true, "endattack2": true, "parry_low": true}
# Each sequence is a list of simultaneous-token steps, matching the native
# keysequence shape. Direction tokens (up/down/in/out) are produced by the PC
# prototype input layer and are not recovered Android physical keys.
const STANDING_COMBO_SEQUENCES: Array[Dictionary] = [
    {"steps": [["a"], ["a"], ["a"]], "attack": "high_punch", "source_index": 90},
    {"steps": [["a"], ["b"], ["b"]], "attack": "punch", "source_index": 88},
    {"steps": [["b"], ["c"], ["c"]], "attack": "high_kick", "source_index": 89},
    {"steps": [["b"], ["d"], ["d"]], "attack": "kick", "source_index": 87},
    {"steps": [["up", "a"], ["in", "a"], ["in", "a"]], "attack": "high_punch3", "source_index": 84},
    {"steps": [["down", "a"], ["out", "b"], ["out", "a"]], "attack": "low_punch3", "source_index": 85},
    {"steps": [["down", "b"], ["out", "d"], ["out", "d"]], "attack": "low_kick3", "source_index": 86},
    {"steps": [["up", "b"], ["in", "c"], ["in", "c"]], "attack": "high_kick3", "source_index": 83},
    {"steps": [["out", "b"], ["in", "c"], ["in", "c"]], "attack": "special_kick_high"},
    {"steps": [["a"], ["a"], ["a"]], "attack": "high_punch2", "from_attack": "high_punch"},
    {"steps": [["a"], ["b"], ["b"]], "attack": "low_punch2", "from_attack": "punch"},
    {"steps": [["b"], ["c"], ["c"]], "attack": "high_kick2", "from_attack": "high_kick"},
    {"steps": [["b"], ["d"], ["d"]], "attack": "low_kick2", "from_attack": "kick"},
    {"steps": [["up", "a"], ["in", "a"], ["in", "a"]], "attack": "high_punch3", "from_attack": "high_punch2"},
    {"steps": [["down", "a"], ["out", "b"], ["out", "a"]], "attack": "low_punch3", "from_attack": "low_punch2"},
    {"steps": [["up", "b"], ["in", "c"], ["in", "c"]], "attack": "high_kick3", "from_attack": "high_kick2"},
    {"steps": [["down", "b"], ["out", "d"], ["out", "d"]], "attack": "low_kick3", "from_attack": "low_kick2"},
    {"steps": [["left", "b"], ["in", "c"], ["in", "c"]], "attack": "special_kick_low_miss", "from_attack": "punch"},
    {"steps": [["down", "a"], ["out", "a"], ["out", "a"]], "attack": "special_punch_low_miss", "from_attack_in": ["high_punch3", "low_punch3", "low_kick3", "high_kick3"]},
    {"steps": [["up", "a"], ["up", "a"], ["up", "a"]], "attack": "special_punch_high_miss", "from_attack_in": ["high_punch3", "low_punch3", "low_kick3", "high_kick3"]},
    {"steps": [["left", "a"], ["a"], ["a"]], "attack": "grab1_miss", "from_attack": "punch"},
    {"steps": [["left", "b"], ["c"], ["c"]], "attack": "grab2_miss", "from_attack": "kick"},
    {"steps": [["up", "in", "b"], ["a"], ["a"]], "attack": "endattack1", "source_record_index": 34, "from_attack_in": ["high_punch", "punch", "kick", "high_kick", "high_punch3", "low_punch3", "low_kick3", "high_kick3", "high_punch2", "low_punch2", "high_kick2", "low_kick2", "special_kick_high", "special_kick_low_miss", "special_kick_low_hit", "special_punch_low_miss", "special_punch_low_hit", "special_punch_high_miss", "special_punch_high_hit", "grab1", "grab2"]},
    {"steps": [["up", "in", "a"], ["c"], ["c"]], "attack": "endattack2", "source_record_index": 35, "from_attack_in": ["high_punch", "punch", "kick", "high_kick", "high_punch3", "low_punch3", "low_kick3", "high_kick3", "high_punch2", "low_punch2", "high_kick2", "low_kick2", "special_kick_high", "special_kick_low_miss", "special_kick_low_hit", "special_punch_low_miss", "special_punch_low_hit", "special_punch_high_miss", "special_punch_high_hit", "grab1", "grab2"]},
]
const CANDOBASICATTACK_WINDOWS: Dictionary = {
    # idle/idle2 are recorded group memberships only. The transition path only
    # evaluates windows while the current attack is in startup/active/recovery,
    # so those two entries cannot be reached at runtime.
    "idle": [0, 140],
    "idle2": [0, 43],
    "punch": [22, 69],
    "kick": [31, 86],
    "high_punch": [17, 101],
    "high_kick": [33, 73],
    "high_punch3": [21, 85],
    "low_punch3": [33, 81],
    "low_kick3": [26, 56],
    "high_kick3": [30, 51],
    "grab1": [45, 150],
    "grab2": [4, 180],
    "high_punch2": [32, 81],
    "low_punch2": [20, 65],
    "high_kick2": [28, 95],
    "low_kick2": [17, 27],
}
const BRUCE_ATTACK_METADATA: Dictionary = {
    "punch": {
        "source_action": "lowpunch1",
        "animation": "m01_pnch_low_01",
        "frame_count": 69,
        "damage": 5.0,
        "radius": 70.0,
        "body_part": "larm",
        "height": "medium",
        "strength": "normal",
        "direction": "frontal",
    },
    "kick": {
        "source_action": "lowkick1",
        "animation": "m01_kick_low_01",
        "frame_count": 86,
        "damage": 5.0,
        "radius": 70.0,
        "body_part": "lleg",
        "height": "low",
        "strength": "normal",
        "direction": "frontal",
    },
    "high_punch": {
        "source_action": "highpunch1",
        "animation": "m01_pnch_high_01",
        "frame_count": 101,
        "damage": 5.0,
        "radius": 70.0,
        "body_part": "larm",
        "height": "high",
        "strength": "normal",
        "direction": "frontal",
    },
    "high_kick": {
        "source_action": "highkick1",
        "animation": "m01_kick_high_01",
        "frame_count": 73,
        "damage": 6.0,
        "radius": 75.0,
        "body_part": "lleg",
        "height": "high",
        "strength": "normal",
        "direction": "frontal",
    },
    "high_punch3": {
        "source_action": "highpunch3",
        "animation": "m01_pnch_high_03",
        "frame_count": 85,
        "damage": 6.0,
        "radius": 70.0,
        "body_part": "larm",
        "height": "high",
        "strength": "hard",
        "direction": "fromright",
    },
    "low_punch3": {
        "source_action": "lowpunch3",
        "animation": "m01_pnch_low_03",
        "frame_count": 81,
        "damage": 7.0,
        "radius": 75.0,
        "body_part": "larm",
        "height": "medium",
        "strength": "hard",
        "direction": "frontal",
    },
    "low_kick3": {
        "source_action": "lowkick3",
        "animation": "m01_kick_low_03",
        "frame_count": 56,
        "damage": 5.0,
        "radius": 70.0,
        "body_part": "lleg",
        "height": "medium",
        "strength": "normal",
        "direction": "frontal",
    },
    "high_kick3": {
        "source_action": "highkick3",
        "animation": "m01_sp_kick_jump_01",
        "frame_count": 51,
        "damage": 8.0,
        "radius": 80.0,
        "body_part": "lleg",
        "height": "high",
        "strength": "hard",
        "direction": "fromright",
    },
    "special_kick_high": {
        "source_action": "specialkickhigh",
        "animation": "m01_kck_front_step",
        "frame_count": 57,
        "damage": 12.0,
        "radius": 115.0,
        "body_part": "lleg",
        "height": "high",
        "strength": "hard",
        "direction": "frontal",
    },
    "high_punch2": {
        "source_action": "highpunch2",
        "animation": "m01_pnch_high_02",
        "frame_count": 81,
        "damage": 5.0,
        "radius": 75.0,
        "body_part": "larm",
        "height": "high",
        "strength": "normal",
        "direction": "fromleft",
    },
    "low_punch2": {
        "source_action": "lowpunch2",
        "animation": "m01_pnch_low_02",
        "frame_count": 65,
        "damage": 6.0,
        "radius": 75.0,
        "body_part": "larm",
        "height": "medium",
        "strength": "normal",
        "direction": "frontal",
    },
    "high_kick2": {
        "source_action": "highkick2",
        "animation": "m01_kick_high_02",
        "frame_count": 95,
        "damage": 5.0,
        "radius": 80.0,
        "body_part": "lleg",
        "height": "high",
        "strength": "normal",
        "direction": "fromleft",
    },
    "low_kick2": {
        "source_action": "lowkick2",
        "animation": "m01_kick_low_02",
        "frame_count": 27,
        "damage": 5.0,
        "radius": 70.0,
        "body_part": "lleg",
        "height": "low",
        "strength": "normal",
        "direction": "fromleft",
    },
    "special_kick_low_miss": {
        "source_action": "specialkicklowmiss",
        "animation": "m01_sp_kick_low_fail",
        "frame_count": 50,
        "damage": 0.0,
        "radius": 25.0,
        "body_part": "lleg",
        "height": "high",
        "strength": "normal",
        "direction": "frontal",
    },
    "special_kick_low_hit": {
        "source_action": "specialkicklowhit",
        "animation": "m01_sp_kick_low",
        "frame_count": 39,
        "damage": 15.0,
        "radius": 45.0,
        "body_part": "larm",
        "height": "high",
        "strength": "hard",
        "direction": "frontal",
    },
    "special_punch_low_miss": {
        "source_action": "specialpunchlowmiss",
        "animation": "m01_sp_pnch_low_fail",
        "frame_count": 33,
        "damage": 0.0,
        "radius": 25.0,
        "body_part": "larm",
        "height": "high",
        "strength": "normal",
        "direction": "frontal",
    },
    "special_punch_low_hit": {
        "source_action": "specialpunchlowhit",
        "animation": "m01_sp_pnch_low",
        "frame_count": 178,
        "damage": 15.0,
        "radius": 45.0,
        "body_part": "larm",
        "height": "high",
        "strength": "hard",
        "direction": "frontal",
    },
    "special_punch_high_miss": {
        "source_action": "specialpunchhighmiss",
        "animation": "m01_sp_pnch_high_fail",
        "frame_count": 122,
        "damage": 0.0,
        "radius": 45.0,
        "body_part": "larm",
        "height": "high",
        "strength": "normal",
        "direction": "frontal",
    },
    "special_punch_high_hit": {
        "source_action": "specialpunchhighhit",
        "animation": "m01_sp_pnch_high",
        "frame_count": 80,
        "damage": 21.0,
        "radius": 70.0,
        "body_part": "larm",
        "height": "high",
        "strength": "normal",
        "direction": "frontal",
    },
    "parry_high": {
        "source_action": "parryhigh",
        "animation": "m01_parry_high",
        "frame_count": 62,
        "damage": 0.0,
        "radius": 40.0,
        "body_part": "larm",
        "height": "high",
        "strength": "normal",
        "direction": "frontal",
    },
    "parry_low": {
        "source_action": "parrylow",
        "animation": "m01_kick_low_02",
        "frame_count": 27,
        "damage": 0.0,
        "radius": 40.0,
        "body_part": "larm",
        "height": "low",
        "strength": "normal",
        "direction": "frontal",
    },
    "parry_attack": {
        "source_action": "parryattack",
        "animation": "m01_pnch_high_03",
        "frame_count": 85,
        "damage": 10.0,
        "radius": 75.0,
        "body_part": "larm",
        "height": "high",
        "strength": "hard",
        "direction": "frontal",
    },
    "grab1": {
        "source_action": "grab1",
        "animation": "m01_grab_01",
        "frame_count": 150,
        "damage": 20.0,
        "radius": 45.0,
        "body_part": "larm",
        "height": "high",
        "strength": "normal",
        "direction": "frontal",
    },
    "grab2": {
        "source_action": "grab2",
        "animation": "m01_grab_02",
        "frame_count": 180,
        "damage": 20.0,
        "radius": 45.0,
        "body_part": "larm",
        "height": "high",
        "strength": "normal",
        "direction": "frontal",
    },
    "endattack1": {
        "source_action": "endattack1",
        "animation": "m01_end_attack_01",
        "frame_count": 377,
        "damage": 0.0,
        "radius": 65.0,
        "body_part": "larm",
        "height": "high",
        "strength": "normal",
        "direction": "frontal",
    },
    "endattack2": {
        "source_action": "endattack2",
        "animation": "m01_end_attack_02",
        "frame_count": 235,
        "damage": 0.0,
        "radius": 75.0,
        "body_part": "rleg",
        "height": "high",
        "strength": "hard",
        "direction": "frontal",
    },
    "grab1_miss": {
        "source_action": "grab1miss",
        "animation": "m02_grab_01",
        "frame_count": 47,
        "damage": 0.0,
        "radius": 45.0,
        "body_part": "larm",
        "height": "high",
        "strength": "normal",
        "direction": "frontal",
    },
    "grab2_miss": {
        "source_action": "grab2miss",
        "animation": "m02_grab_01",
        "frame_count": 47,
        "damage": 0.0,
        "radius": 45.0,
        "body_part": "larm",
        "height": "high",
        "strength": "normal",
        "direction": "frontal",
    },
}

enum AttackToFloorInputResult {
    IGNORED,
    BUFFERED,
    STARTED,
}

enum AttackToFloorSequenceMatch {
    NO_MATCH,
    PREFIX,
    COMPLETE,
}

# Each key is a recovered source action, not an ANM header pose. Values were
# read from brucelee.set; idle and facedownidle were also checked in thai.set.
# The prototype currently maps these state names one-to-one to source actions.
const SOURCE_ACTION_POSES: Dictionary = {
    "idle": "stand",
    "idle2": "stand",
    "facedownidle": "laying",
    "facedownko": "laying",
    "facedowngetup": "stand",
    "impactfacedown": "laying",
    "facedownattack": "laying",
    "impacttofloor": "laying",
    "faceupidle": "laying",
    "faceupgetup": "stand",
    "faceupattack": "laying",
    "impactfaceup": "laying",
    "faceupko": "laying",
    "attacktofloor": "stand",
}
# UserControlUpdate expires a whole input vector based on the last event's
# +500 clock value. The clock unit is not proven, so this is an explicit PC
# prototype lifetime and must not be presented as the original timing.
const GROUND_ATTACK_INPUT_PROTOTYPE_WINDOW_SECONDS: float = 0.5
const GROUND_ATTACK_SEQUENCES: Array = [
    ["a", "a", "a"],
    ["a", "b", "b"],
    ["b", "c", "c"],
    ["b", "d", "d"],
]
const FACEDOWN_ATTACK_IMPACT: Dictionary = {
    "attack_radius": FACEDOWN_ATTACK_RADIUS,
    "body_part": "rarm",
    "height": "medium",
    "strength": "hard",
    "direction": "frontal",
}
const FACEUP_ATTACK_IMPACT: Dictionary = {
    "attack_radius": FACEUP_ATTACK_RADIUS,
    "body_part": "larm",
    "height": "low",
    "strength": "hard",
    "direction": "frontal",
}
const RETURN_ANIMATION_RADII: Dictionary = {
    "m01_idle_02": 40.0,
    "all_idle_face_down": 75.0,
    "all_idle_face_down_forbigguy": 75.0,
    "all_getup_facedwn": 25.0,
    "all_impct_facedwn": 80.0,
    "all_impct_hard_rht_high": 80.0,
    "all_getup_facedwn_attack": 45.0,
    "all_stunned_fall": 75.0,
    "all_idle_face_up": 75.0,
    "all_getup_faceup": 40.0,
    "all_getup_faceup_attack": 45.0,
    "all_impct_faceup": 80.0,
}
const REACTION_ROOT_PUSH_SOURCE: Dictionary = {
    "impactlightfronthigh": 36.86962890625,
    "impactlightfrontlow": 18.252197265625,
    "impactlightfrontmid": 22.845458984375,
}


const REACTION_PROFILE_DATA: Dictionary = {
    "hit": {
        "low": {
            "source_action": "impactlightfrontlow",
            "animation": "all_impct_light_frnt_low",
            "exit_start_frame": 13,
            "animation_duration_frames": 17,
            "linking_frame": 0,
        },
        "medium": {
            "source_action": "impactlightfrontmid",
            "animation": "all_impct_light_frnt_mid",
            "exit_start_frame": 14,
            "animation_duration_frames": 16,
            "linking_frame": 0,
        },
        "high": {
            "source_action": "impactlightfronthigh",
            "animation": "all_impct_light_frnt_high",
            "exit_start_frame": 13,
            "animation_duration_frames": 17,
            "linking_frame": 0,
        },
    },
    "block": {
        "low": {
            "source_action": "lowblock",
            "animation": "all_block_low",
            "exit_start_frame": 12,
            "animation_duration_frames": 23,
            "linking_frame": 14,
        },
        "medium": {
            "source_action": "midblock",
            "animation": "all_block_mid",
            "exit_start_frame": 12,
            "animation_duration_frames": 14,
            "linking_frame": 0,
        },
        "high": {
            "source_action": "highblock",
            "animation": "all_block_high",
            "exit_start_frame": 12,
            "animation_duration_frames": 14,
            "linking_frame": 0,
        },
    },
}

const THAI_ANIMATION_RADII_DATA: Dictionary = {
    "m03_idle_01": 43.0,
    "m03_pnch_low_01": 40.0,
    "m03_kck_low_01": 50.0,
    "m03_movefwd": 50.0,
}
const THAI_REACTION_PROFILE_DATA: Dictionary = {
    "hit": {
        "low": {
            "source_action": "impactlightfrontlow",
            "animation": "all_impct_light_frnt_low",
            "animation_radius": 40.0,
            "exit_start_frame": 13,
            "animation_duration_frames": 17,
            "linking_frame": 0,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
        "medium": {
            "source_action": "impactlightfrontmid",
            "animation": "all_impct_light_frnt_mid",
            "animation_radius": 40.0,
            "exit_start_frame": 14,
            "animation_duration_frames": 16,
            "linking_frame": 0,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
        "high": {
            "source_action": "impactlightfronthigh",
            "animation": "all_impct_light_frnt_high",
            "animation_radius": 40.0,
            "exit_start_frame": 13,
            "animation_duration_frames": 17,
            "linking_frame": 0,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
    },
    "block": {
        "low": {
            "source_action": "lowblock",
            "animation": "all_block_low",
            "animation_radius": 40.0,
            "exit_start_frame": 12,
            "animation_duration_frames": 23,
            "linking_frame": 14,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
        "medium": {
            "source_action": "midblock",
            "animation": "all_block_mid",
            "animation_radius": 40.0,
            "exit_start_frame": 12,
            "animation_duration_frames": 14,
            "linking_frame": 0,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
        "high": {
            "source_action": "highblock",
            "animation": "m03_blck_high",
            "animation_radius": 40.0,
            "exit_start_frame": 12,
            "animation_duration_frames": 17,
            "linking_frame": 0,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
    },
}
const BRUCE_EXACT_REACTION_DATA: Dictionary = {
    "hit": [
        {
            "strength": "hard",
            "height": "medium",
            "direction": "frontal",
            "source_action": "impacthardfrontmid",
            "animation": "all_impct_crotch",
            "animation_radius": 40.0,
            "exit_start_frame": 27,
            "animation_duration_frames": 30,
            "linking_frame": 0,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
        {
            "strength": "hard",
            "height": "low",
            "direction": "fromright",
            "source_action": "impacthardrightlow",
            "animation": "all_impct_hard_rht_low",
            "animation_radius": 70.0,
            "exit_start_frame": 23,
            "animation_duration_frames": 25,
            "linking_frame": 0,
            "return_action": "facedownidle",
            "return_implemented": false,
            "clip_implemented": false,
        },
        {
            "strength": "hard",
            "height": "high",
            "direction": "fromright",
            "source_action": "impacthardrighthigh",
            "animation": "all_impct_hard_rht_high",
            "animation_radius": 80.0,
            "exit_start_frame": 26,
            "animation_duration_frames": 29,
            "linking_frame": 0,
            "return_action": "faceupidle",
            "return_implemented": true,
            "clip_implemented": false,
        },
        {
            "strength": "hard",
            "height": "high",
            "direction": "frontal",
            "source_action": "impacthardfronthigh",
            "animation": "all_impct_hard_frnt_high",
            "animation_radius": 80.0,
            "exit_start_frame": 23,
            "animation_duration_frames": 35,
            "linking_frame": 0,
            "return_action": "faceupidle",
            "return_implemented": true,
            "clip_implemented": false,
        },
    ],
    "block": [
        {
            "strength": "hard",
            "height": "",
            "direction": "",
            "source_action": "highblockhard",
            "animation": "all_block_high_hard",
            "animation_radius": 25.0,
            "exit_start_frame": 11,
            "animation_duration_frames": 14,
            "linking_frame": 0,
            "return_action": "idle2",
            "return_implemented": false,
            "clip_implemented": false,
        },
        {
            "strength": "brutal",
            "height": "",
            "direction": "",
            "source_action": "highblockbrutal",
            "animation": "all_block_high_brutal",
            "animation_radius": 25.0,
            "exit_start_frame": 17,
            "animation_duration_frames": 20,
            "linking_frame": 0,
            "return_action": "idle2",
            "return_implemented": false,
            "clip_implemented": false,
        },
    ],
}
var ATTACKS: Dictionary = {}
var REACTION_PROFILES: Dictionary = {}
var EXACT_REACTIONS: Dictionary = {}
var attack_config_path: String = ATTACK_CONFIG_PATH
var attack_config_error: String = ""
var radius_scale: float = 1.0
var source_units_to_world: float = WORLD_CHARACTER_HEIGHT / SOURCE_CHARACTER_HEIGHT
var source_animation_radii: Dictionary = SOURCE_ANIMATION_RADII_DATA.duplicate(true)


var character_name: String = "Fighter"
var is_player: bool = true
var health: float = MAX_HEALTH
var move_axis: Vector2 = Vector2.ZERO
var guard_held: bool = false
var opponent: PortFighter
var state: String = "idle"
var state_time: float = 0.0
var attack_kind: String = ""
var attack_sequence: int = 0
var _attack_connected: bool = false
var _ground_attack_input_history: Array[Dictionary] = []
var _ground_attack_input_owner: String = ""
var _standing_combo_input_history: Array[Dictionary] = []
var _standing_combo_pending_attack: String = ""
# A matched sequence belongs to the attack that was running when it completed.
# The pending entry is only valid while that exact attack instance is still the
# current one; native link priority and the member record's third field remain
# unverified, so this binding is a prototype safety rule.
var _standing_combo_pending_source_sequence: int = -1
var _standing_combo_pending_source_kind: String = ""
var last_reaction_group: String = ""
var last_reaction_source_action: String = ""
var last_reaction_animation: String = ""
var last_reaction_exit_frame: int = -1
var last_reaction_clip_implemented: bool = false
var facing: float = 1.0
var combo_hits: int = 0
var rage: float = 0.0
var _special_stepback_origin: bool = false
var _multi_impact_applied: Array = []
var _attack_hit_landed: bool = false
var _grab_connected: bool = false
var _stun_impact_next_state: String = "stunfall"
var _parry_press_times: Array = []
var candidate_loaded: bool = false
var candidate_load_error: String = ""
var candidate_animation_clip: String = ""
var candidate_visual_height: float = 0.0
var candidate_textures_loaded: bool = false
var candidate_texture_error: String = ""
var candidate_texture_reason: String = ""
var candidate_glb_path: String = ""
var candidate_texture_root: String = ""
var candidate_clips: Dictionary = CANDIDATE_CLIPS.duplicate(true)
var candidate_material_profile: String = "body_hair"
var candidate_scale_attack_timing: bool = false
var candidate_visual_blending_enabled: bool = false
var candidate_visual_blend_pending_seconds: float = 0.0
var candidate_visual_blend_seconds_last: float = 0.0
var candidate_visual_blend_source_action_last: String = ""
var candidate_visual_blend_target_action_last: String = ""
var _time: float = 0.0
var _body: MeshInstance3D
var _left_arm: MeshInstance3D
var _right_arm: MeshInstance3D
var _color: Color = Color(0.7, 0.45, 0.2)
var _placeholder_visuals: Array[MeshInstance3D] = []
var _candidate_root: Node3D
var _candidate_animation: AnimationPlayer
var _candidate_clip_paths: Dictionary = {}
var _candidate_action: String = ""
var _candidate_character: Node3D
var _candidate_character_rest_position: Vector3
var _candidate_skeleton: Skeleton3D
var _candidate_skeleton_parent: Node
var _candidate_source_min_y: float = CANDIDATE_SOURCE_MIN_Y
var _candidate_visual_scale: float = 1.0

func configure(display_name: String, human: bool, tint: Color) -> void:
    character_name = display_name
    is_player = human
    _color = tint


func configure_candidate_asset(
        path: String,
        texture_root: String,
        clips: Dictionary = CANDIDATE_CLIPS,
        material_profile: String = "body_hair",
        scale_attack_timing: bool = false
) -> void:
    if is_inside_tree():
        push_error("Candidate asset must be configured before the fighter enters the tree")
        return
    candidate_glb_path = path
    candidate_texture_root = texture_root
    candidate_clips = clips.duplicate(true)
    candidate_material_profile = material_profile
    candidate_scale_attack_timing = scale_attack_timing


func configure_attack_config(path: String) -> void:
    if is_inside_tree():
        push_error("Attack config must be configured before the fighter enters the tree")
        return
    attack_config_path = path


func _ready() -> void:
    if OS.get_environment("BRUCELEE_CANDIDATE_VISUAL_BLENDING") == "1":
        candidate_visual_blending_enabled = true
    if not _load_attack_definitions():
        push_error("Fighting-set attack config failed closed: " + attack_config_error)
    collision_layer = 2
    collision_mask = 1 | 2
    var capsule: CapsuleShape3D = CapsuleShape3D.new()
    capsule.radius = 0.34
    capsule.height = 1.9
    var collision: CollisionShape3D = CollisionShape3D.new()
    collision.shape = capsule
    add_child(collision)
    _body = _add_mesh(CapsuleMesh.new(), Vector3(0.0, 0.0, 0.0), _color)
    _body.scale = Vector3(0.9, 1.0, 0.65)
    var head: SphereMesh = SphereMesh.new()
    head.radius = 0.23
    head.height = 0.46
    _add_mesh(head, Vector3(0.0, 0.90, 0.0), Color(0.95, 0.78, 0.60))
    var arm: BoxMesh = BoxMesh.new()
    arm.size = Vector3(0.16, 0.70, 0.20)
    _left_arm = _add_mesh(arm, Vector3(-0.47, 0.18, 0.0), _color.darkened(0.08))
    _right_arm = _add_mesh(arm, Vector3(0.47, 0.18, 0.0), _color.darkened(0.08))
    var foot: BoxMesh = BoxMesh.new()
    foot.size = Vector3(0.27, 0.10, 0.43)
    _add_mesh(foot, Vector3(-0.20, -0.86, 0.0), Color(0.16, 0.16, 0.16))
    _add_mesh(foot, Vector3(0.20, -0.86, 0.0), Color(0.16, 0.16, 0.16))
    _try_load_candidate_visual()

func _load_attack_definitions() -> bool:
    ATTACKS = {}
    REACTION_PROFILES = {}
    EXACT_REACTIONS = {}
    attack_config_error = ""
    radius_scale = 1.0
    source_units_to_world = WORLD_CHARACTER_HEIGHT / SOURCE_CHARACTER_HEIGHT
    source_animation_radii = SOURCE_ANIMATION_RADII_DATA.duplicate(true)
    if not FileAccess.file_exists(attack_config_path):
        attack_config_error = "missing " + attack_config_path
        return false
    var file: FileAccess = FileAccess.open(attack_config_path, FileAccess.READ)
    if file == null:
        attack_config_error = "could not open " + attack_config_path
        return false
    var parser: JSON = JSON.new()
    var parse_error: Error = parser.parse(file.get_as_text())
    if parse_error != OK:
        attack_config_error = "invalid JSON: " + parser.get_error_message()
        return false
    var parsed: Variant = parser.data
    if not parsed is Dictionary:
        attack_config_error = "root is not an object"
        return false
    var loaded: Dictionary = _parse_attack_config(parsed)
    if loaded.is_empty():
        return false
    loaded["heavy"] = HEAVY_ATTACK
    ATTACKS = loaded
    return true


func _is_number(value: Variant) -> bool:
    return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _parse_attack_config(config: Dictionary) -> Dictionary:
    var archive_value: Variant = config.get("source_archive", "")
    if typeof(archive_value) == TYPE_STRING and String(archive_value) == "thai.set":
        return _parse_thai_mapped_attack_config(config)
    var schema_value: Variant = config.get("schema_version")
    if not _is_number(schema_value) or float(schema_value) != 4.0:
        return _reject_attack_config("unsupported schema version")
    if typeof(config.get("source_archive")) != TYPE_STRING or String(config.get("source_archive")) != "brucelee.set":
        return _reject_attack_config("unexpected source archive")
    var frame_rate_value: Variant = config.get("frame_rate")
    if not _is_number(frame_rate_value) or absf(float(frame_rate_value) - SOURCE_FRAME_RATE) > 0.001:
        return _reject_attack_config("frame rate does not match the source")
    var geometry_value: Variant = config.get("source_geometry")
    if not geometry_value is Dictionary:
        return _reject_attack_config("source_geometry is not an object")
    var geometry: Dictionary = geometry_value
    for key: String in [
            "source_height", "world_height", "radius_scale",
            "idle_source_archive", "animation_radii"]:
        if not geometry.has(key):
            return _reject_attack_config("source_geometry lacks " + key)
    if (not _is_number(geometry["source_height"])
            or not _is_number(geometry["world_height"])
            or not _is_number(geometry["radius_scale"])):
        return _reject_attack_config("source_geometry contains non-numeric scale values")
    var source_height: float = float(geometry["source_height"])
    var world_height: float = float(geometry["world_height"])
    var loaded_radius_scale: float = float(geometry["radius_scale"])
    if (typeof(geometry["idle_source_archive"]) != TYPE_STRING
            or String(geometry["idle_source_archive"]) != "Default.set"):
        return _reject_attack_config("unexpected idle source archive")
    if (source_height <= 0.0
            or absf(source_height - SOURCE_CHARACTER_HEIGHT) > 0.001
            or world_height <= 0.0
            or absf(world_height - WORLD_CHARACTER_HEIGHT) > 0.001
            or loaded_radius_scale <= 0.0
            or absf(loaded_radius_scale - 1.0) > 0.001):
        return _reject_attack_config("source_geometry has invalid or unexpected scale values")
    var radii_value: Variant = geometry["animation_radii"]
    if not radii_value is Dictionary:
        return _reject_attack_config("animation_radii is not an object")
    var radii: Dictionary = radii_value
    var loaded_radii: Dictionary = {}
    for animation: String in SOURCE_ANIMATION_RADII_DATA:
        if not radii.has(animation) or not _is_number(radii[animation]):
            return _reject_attack_config("animation_radii." + animation + " is missing or non-numeric")
        var radius: float = float(radii[animation])
        if radius <= 0.0:
            return _reject_attack_config("animation_radii." + animation + " is invalid")
        loaded_radii[animation] = radius
    for animation: String in SOURCE_ANIMATION_RADII_DATA:
        if absf(
                float(loaded_radii[animation])
                - float(SOURCE_ANIMATION_RADII_DATA[animation])
        ) > 0.001:
            return _reject_attack_config(
                "animation_radii do not match the source animations"
            )
    var loaded_reactions: Dictionary = _parse_reaction_profiles(
        config.get("reaction_profiles")
    )
    if loaded_reactions.is_empty():
        return {}
    var loaded_exact: Dictionary = _parse_exact_reactions(config.get("exact_reactions"))
    if loaded_exact.is_empty():
        return {}
    var configured_attacks: Variant = config.get("attacks")
    if not configured_attacks is Dictionary:
        return _reject_attack_config("attacks is not an object")
    var result: Dictionary = {}
    for action: String in BRUCE_ATTACK_METADATA:
        var entry_value: Variant = configured_attacks.get(action)
        if not entry_value is Dictionary:
            return _reject_attack_config(action + " is not an object")
        var entry: Dictionary = entry_value
        for key: String in [
                "source_action", "animation", "animation_frame_count",
                "startup_frames", "active_frames", "recovery_frames",
                "damage", "prototype_push", "source_impact"]:
            if not entry.has(key):
                return _reject_attack_config(action + " lacks " + key)
        if (not _is_number(entry["startup_frames"]) or not _is_number(entry["active_frames"])
                or not _is_number(entry["recovery_frames"])
                or not _is_number(entry["animation_frame_count"])
                or not _is_number(entry["damage"])
                or not _is_number(entry["prototype_push"])):
            return _reject_attack_config(action + " contains non-numeric values")
        var startup_frames: int = int(entry["startup_frames"])
        var active_frames: int = int(entry["active_frames"])
        var recovery_frames: int = int(entry["recovery_frames"])
        var frame_count: int = int(entry["animation_frame_count"])
        if (startup_frames < 0 or active_frames < 0 or recovery_frames < 0
                or frame_count <= 0
                or startup_frames + active_frames + recovery_frames <= 0):
            return _reject_attack_config(action + " has invalid frame counts")
        if startup_frames + active_frames + recovery_frames != frame_count:
            return _reject_attack_config(action + " phase frames do not sum to animation_frame_count")
        if (float(entry["startup_frames"]) != float(startup_frames)
                or float(entry["active_frames"]) != float(active_frames)
                or float(entry["recovery_frames"]) != float(recovery_frames)
                or float(entry["animation_frame_count"]) != float(frame_count)):
            return _reject_attack_config(action + " frame counts are not integers")
        if typeof(entry["source_action"]) != TYPE_STRING or typeof(entry["animation"]) != TYPE_STRING:
            return _reject_attack_config(action + " source identifiers are not strings")
        var expected: Dictionary = BRUCE_ATTACK_METADATA[action]
        var expected_source: String = String(expected["source_action"])
        var expected_animation: String = String(expected["animation"])
        var expected_frame_count: int = int(expected["frame_count"])
        if String(entry["source_action"]) != expected_source:
            return _reject_attack_config(action + " source action is not " + expected_source)
        if String(entry["animation"]) != expected_animation:
            return _reject_attack_config(action + " animation is not " + expected_animation)
        if frame_count != expected_frame_count:
            return _reject_attack_config(action + " animation frame count is not " + str(expected_frame_count))
        var damage: float = float(entry["damage"])
        var push: float = float(entry["prototype_push"])
        if (damage < 0.0 or push < 0.0
                or absf(damage - float(expected["damage"])) > 0.001):
            return _reject_attack_config(action + " has invalid numeric values")
        var impact_value: Variant = entry["source_impact"]
        if not impact_value is Dictionary:
            return _reject_attack_config(action + " source_impact is not an object")
        var impact: Dictionary = impact_value
        for key: String in ["attack_radius", "body_part", "height", "strength", "direction"]:
            if not impact.has(key):
                return _reject_attack_config(action + " impact lacks " + key)
        if not _is_number(impact["attack_radius"]) or float(impact["attack_radius"]) <= 0.0:
            return _reject_attack_config(action + " impact radius is invalid")
        for key: String in ["body_part", "height", "strength", "direction"]:
            if typeof(impact[key]) != TYPE_STRING:
                return _reject_attack_config(action + " impact enum " + key + " is not a string")
        if String(impact["body_part"]) not in ["larm", "rarm", "lleg", "rleg"]:
            return _reject_attack_config(action + " body part is invalid")
        if String(impact["height"]) not in ["high", "medium", "low"]:
            return _reject_attack_config(action + " height is invalid")
        if String(impact["strength"]) not in ["hard", "normal", "brutal"]:
            return _reject_attack_config(action + " strength is invalid")
        if String(impact["direction"]) not in ["frontal", "fromleft", "fromright", "fromabove"]:
            return _reject_attack_config(action + " direction is invalid")
        var expected_body_part: String = String(expected["body_part"])
        var expected_height: String = String(expected["height"])
        if (absf(float(impact["attack_radius"]) - float(expected["radius"])) > 0.001
                or String(impact["body_part"]) != expected_body_part
                or String(impact["height"]) != expected_height
                or String(impact["strength"]) != String(expected["strength"])
                or String(impact["direction"]) != String(expected["direction"])):
            return _reject_attack_config(
                action + " impact does not match the recovered reaction profile"
            )
        var multi_impacts: Array = []
        if entry.has("multi_impacts"):
            if not entry["multi_impacts"] is Array:
                return _reject_attack_config(action + " multi_impacts is not an array")
            for multi_value: Variant in entry["multi_impacts"]:
                if not multi_value is Dictionary:
                    return _reject_attack_config(action + " multi impact is not an object")
                var multi_impact: Dictionary = multi_value
                for key: String in ["damage", "damage_time", "attack_radius", "body_part", "height", "strength", "direction"]:
                    if not multi_impact.has(key):
                        return _reject_attack_config(action + " multi impact lacks " + key)
                var timing_value: Variant = multi_impact["damage_time"]
                if (not timing_value is Array or timing_value.size() != 2
                        or not _is_number(timing_value[0]) or not _is_number(timing_value[1])
                        or float(timing_value[0]) < 0.0
                        or float(timing_value[1]) < float(timing_value[0])):
                    return _reject_attack_config(action + " multi impact timing is invalid")
                if not _is_number(multi_impact["damage"]) or not _is_number(multi_impact["attack_radius"]):
                    return _reject_attack_config(action + " multi impact values are non-numeric")
                multi_impacts.append(multi_impact.duplicate(true))
        result[action] = {
            "multi_impacts": multi_impacts,
            "startup": float(startup_frames) / SOURCE_FRAME_RATE,
            "active": float(active_frames) / SOURCE_FRAME_RATE,
            "recovery": float(recovery_frames) / SOURCE_FRAME_RATE,
            "damage": damage,
            "push": push,
            "source_action": String(entry["source_action"]),
            "animation": String(entry["animation"]),
            "animation_frame_count": frame_count,
            "source_impact": impact.duplicate(true),
        }
    # Commit instance metadata only after every attack has validated.
    radius_scale = loaded_radius_scale
    source_units_to_world = world_height / source_height
    source_animation_radii = loaded_radii
    REACTION_PROFILES = loaded_reactions
    EXACT_REACTIONS = loaded_exact
    return result


func _parse_reaction_profiles(
        value: Variant,
        expected_profiles: Dictionary = REACTION_PROFILE_DATA
) -> Dictionary:
    if not value is Dictionary:
        return _reject_attack_config("reaction_profiles is not an object")
    var configured: Dictionary = value
    var loaded: Dictionary = {}
    for group: String in ["hit", "block"]:
        var group_value: Variant = configured.get(group)
        if not group_value is Dictionary:
            return _reject_attack_config(group + " reactions are not an object")
        var group_profiles: Dictionary = group_value
        var loaded_group: Dictionary = {}
        for height: String in ["low", "medium", "high"]:
            var profile_value: Variant = group_profiles.get(height)
            if not profile_value is Dictionary:
                return _reject_attack_config(
                    group + " " + height + " reaction is not an object"
                )
            var profile: Dictionary = profile_value
            for key: String in [
                    "source_action", "animation", "exit_start_frame",
                    "animation_duration_frames", "linking_frame"]:
                if not profile.has(key):
                    return _reject_attack_config(
                        group + " " + height + " reaction lacks " + key
                    )
            if (typeof(profile["source_action"]) != TYPE_STRING
                    or typeof(profile["animation"]) != TYPE_STRING):
                return _reject_attack_config(
                    group + " " + height + " reaction identifiers are invalid"
                )
            if (not _is_number(profile["exit_start_frame"])
                    or not _is_number(profile["animation_duration_frames"])
                    or not _is_number(profile["linking_frame"])):
                return _reject_attack_config(
                    group + " " + height + " reaction frames are invalid"
                )
            var exit_frame: int = int(profile["exit_start_frame"])
            var duration_frames: int = int(profile["animation_duration_frames"])
            var linking_frame: int = int(profile["linking_frame"])
            if (float(profile["exit_start_frame"]) != float(exit_frame)
                    or float(profile["animation_duration_frames"])
                    != float(duration_frames)
                    or float(profile["linking_frame"]) != float(linking_frame)
                    or exit_frame < 0
                    or duration_frames <= 0
                    or exit_frame > duration_frames
                    or linking_frame < 0
                    or linking_frame > duration_frames):
                return _reject_attack_config(
                    group + " " + height + " reaction frame values are invalid"
                )
            var expected: Dictionary = expected_profiles[group][height]
            if (String(profile["source_action"]) != expected["source_action"]
                    or String(profile["animation"]) != expected["animation"]
                    or exit_frame != int(expected["exit_start_frame"])
                    or duration_frames != int(expected["animation_duration_frames"])
                    or linking_frame != int(expected["linking_frame"])):
                return _reject_attack_config(
                    group + " " + height + " reaction does not match the source links"
                )
            for extra_key: String in [
                    "animation_radius", "return_action",
                    "return_implemented", "clip_implemented"]:
                if not expected.has(extra_key):
                    continue
                if not profile.has(extra_key):
                    return _reject_attack_config(
                        group + " " + height + " reaction lacks " + extra_key
                    )
                var expected_extra: Variant = expected[extra_key]
                var actual_extra: Variant = profile[extra_key]
                if _is_number(expected_extra):
                    if (not _is_number(actual_extra)
                            or absf(float(actual_extra) - float(expected_extra)) > 0.001):
                        return _reject_attack_config(
                            group + " " + height + " reaction " + extra_key
                            + " does not match the source links"
                        )
                elif typeof(expected_extra) == TYPE_BOOL:
                    if (typeof(actual_extra) != TYPE_BOOL
                            or bool(actual_extra) != bool(expected_extra)):
                        return _reject_attack_config(
                            group + " " + height + " reaction " + extra_key
                            + " does not match the source links"
                        )
                elif String(actual_extra) != String(expected_extra):
                    return _reject_attack_config(
                        group + " " + height + " reaction " + extra_key
                        + " does not match the source links"
                    )
            loaded_group[height] = profile.duplicate(true)
        loaded[group] = loaded_group
    return loaded



func _parse_thai_mapped_attack_config(config: Dictionary) -> Dictionary:
    var schema_value: Variant = config.get("schema_version")
    if not _is_number(schema_value) or float(schema_value) != 4.0:
        return _reject_attack_config("unsupported schema version")
    var frame_rate_value: Variant = config.get("frame_rate")
    if not _is_number(frame_rate_value) or absf(float(frame_rate_value) - SOURCE_FRAME_RATE) > 0.001:
        return _reject_attack_config("frame rate does not match the source")
    var geometry_value: Variant = config.get("source_geometry")
    if not geometry_value is Dictionary:
        return _reject_attack_config("source_geometry is not an object")
    var geometry: Dictionary = geometry_value
    for key: String in [
            "source_height", "world_height", "radius_scale",
            "idle_source_archive", "animation_radii"]:
        if not geometry.has(key):
            return _reject_attack_config("source_geometry lacks " + key)
    if (not _is_number(geometry["source_height"])
            or not _is_number(geometry["world_height"])
            or not _is_number(geometry["radius_scale"])):
        return _reject_attack_config("source_geometry contains non-numeric scale values")
    var source_height: float = float(geometry["source_height"])
    var world_height: float = float(geometry["world_height"])
    var loaded_radius_scale: float = float(geometry["radius_scale"])
    if (typeof(geometry["idle_source_archive"]) != TYPE_STRING
            or String(geometry["idle_source_archive"]) != "thai.set"):
        return _reject_attack_config("unexpected idle source archive")
    if (source_height <= 0.0
            or absf(source_height - SOURCE_CHARACTER_HEIGHT) > 0.001
            or world_height <= 0.0
            or absf(world_height - WORLD_CHARACTER_HEIGHT) > 0.001
            or loaded_radius_scale <= 0.0
            or absf(loaded_radius_scale - 1.0) > 0.001):
        return _reject_attack_config("source_geometry has invalid or unexpected scale values")
    var radii_value: Variant = geometry["animation_radii"]
    if not radii_value is Dictionary:
        return _reject_attack_config("animation_radii is not an object")
    var radii: Dictionary = radii_value
    if radii.size() != THAI_ANIMATION_RADII_DATA.size():
        return _reject_attack_config("animation_radii does not contain only the four current clips")
    var loaded_radii: Dictionary = {}
    for animation: String in THAI_ANIMATION_RADII_DATA:
        if not radii.has(animation) or not _is_number(radii[animation]):
            return _reject_attack_config("animation_radii." + animation + " is missing or non-numeric")
        var radius: float = float(radii[animation])
        if absf(radius - float(THAI_ANIMATION_RADII_DATA[animation])) > 0.001 or radius <= 0.0:
            return _reject_attack_config("animation_radii." + animation + " does not match thai.set")
        loaded_radii[animation] = radius
    var loaded_reactions: Dictionary = _parse_reaction_profiles(
        config.get("reaction_profiles"),
        THAI_REACTION_PROFILE_DATA
    )
    if loaded_reactions.is_empty():
        return {}
    var configured_attacks: Variant = config.get("attacks")
    if not configured_attacks is Dictionary:
        return _reject_attack_config("attacks is not an object")
    var attacks: Dictionary = configured_attacks
    if attacks.size() != 2:
        return _reject_attack_config("thai mapping contains more than the verified attacks")
    var result: Dictionary = {}
    for action: String in ["punch", "kick"]:
        var entry_value: Variant = attacks.get(action)
        if not entry_value is Dictionary:
            return _reject_attack_config(action + " is not an object")
        var entry: Dictionary = entry_value
        for key: String in [
                "source_action", "animation", "animation_frame_count",
                "startup_frames", "active_frames", "recovery_frames",
                "damage", "prototype_push", "source_impact"]:
            if not entry.has(key):
                return _reject_attack_config(action + " lacks " + key)
        if (not _is_number(entry["startup_frames"]) or not _is_number(entry["active_frames"])
                or not _is_number(entry["recovery_frames"])
                or not _is_number(entry["animation_frame_count"])
                or not _is_number(entry["damage"])
                or not _is_number(entry["prototype_push"])):
            return _reject_attack_config(action + " contains non-numeric values")
        var startup_frames: int = int(entry["startup_frames"])
        var active_frames: int = int(entry["active_frames"])
        var recovery_frames: int = int(entry["recovery_frames"])
        var frame_count: int = int(entry["animation_frame_count"])
        if (float(entry["startup_frames"]) != float(startup_frames)
                or float(entry["active_frames"]) != float(active_frames)
                or float(entry["recovery_frames"]) != float(recovery_frames)
                or float(entry["animation_frame_count"]) != float(frame_count)
                or startup_frames + active_frames + recovery_frames != frame_count):
            return _reject_attack_config(action + " phase frames do not match the clip")
        var expected_source: String = "lowpunch3" if action == "punch" else "lowkick3"
        var expected_animation: String = "m03_pnch_low_01" if action == "punch" else "m03_kck_low_01"
        var expected_frames: Array = [8, 4, 26, 38] if action == "punch" else [9, 3, 29, 41]
        if (String(entry["source_action"]) != expected_source
                or String(entry["animation"]) != expected_animation
                or startup_frames != int(expected_frames[0])
                or active_frames != int(expected_frames[1])
                or recovery_frames != int(expected_frames[2])
                or frame_count != int(expected_frames[3])
                or absf(float(entry["damage"]) - 7.0) > 0.001
                or absf(float(entry["prototype_push"])) > 0.001):
            return _reject_attack_config(action + " does not match the verified thai.set attack")
        var impact_value: Variant = entry["source_impact"]
        if not impact_value is Dictionary:
            return _reject_attack_config(action + " source_impact is not an object")
        var impact: Dictionary = impact_value
        var expected_impact: Dictionary = {
            "attack_radius": 80.0,
            "body_part": "larm",
            "height": "medium",
            "strength": "hard",
            "direction": "frontal",
        } if action == "punch" else {
            "attack_radius": 70.0,
            "body_part": "lleg",
            "height": "low",
            "strength": "hard",
            "direction": "fromright",
        }
        for key: String in expected_impact.keys():
            if not impact.has(key):
                return _reject_attack_config(action + " impact lacks " + key)
            if _is_number(expected_impact[key]):
                if (not _is_number(impact[key])
                        or absf(float(impact[key]) - float(expected_impact[key])) > 0.001):
                    return _reject_attack_config(action + " impact does not match thai.set")
            elif String(impact[key]) != String(expected_impact[key]):
                return _reject_attack_config(action + " impact does not match thai.set")
        result[action] = {
            "startup": float(startup_frames) / SOURCE_FRAME_RATE,
            "active": float(active_frames) / SOURCE_FRAME_RATE,
            "recovery": float(recovery_frames) / SOURCE_FRAME_RATE,
            "damage": float(entry["damage"]),
            "push": float(entry["prototype_push"]),
            "source_action": String(entry["source_action"]),
            "animation": String(entry["animation"]),
            "animation_frame_count": frame_count,
            "source_impact": impact.duplicate(true),
        }
    radius_scale = loaded_radius_scale
    source_units_to_world = world_height / source_height
    source_animation_radii = loaded_radii
    REACTION_PROFILES = loaded_reactions
    EXACT_REACTIONS = {}
    return result


func _parse_exact_reactions(value: Variant) -> Dictionary:
    if not value is Dictionary:
        return _reject_attack_config("exact_reactions is not an object")
    var configured: Dictionary = value
    if configured.size() != BRUCE_EXACT_REACTION_DATA.size():
        return _reject_attack_config("exact_reactions has unexpected groups")
    var loaded: Dictionary = {}
    for group: String in BRUCE_EXACT_REACTION_DATA.keys():
        var expected_entries: Array = BRUCE_EXACT_REACTION_DATA[group]
        var actual_value: Variant = configured.get(group)
        if not actual_value is Array or actual_value.size() != expected_entries.size():
            return _reject_attack_config(group + " exact reaction count does not match brucelee.set")
        var loaded_entries: Array = []
        for index in range(expected_entries.size()):
            if not actual_value[index] is Dictionary:
                return _reject_attack_config(group + " exact reaction is not an object")
            var actual: Dictionary = actual_value[index]
            var expected: Dictionary = expected_entries[index]
            if actual.size() != expected.size():
                return _reject_attack_config(group + " exact reaction has unexpected fields")
            for key: String in expected.keys():
                if not actual.has(key):
                    return _reject_attack_config(group + " exact reaction lacks " + key)
                var expected_value: Variant = expected[key]
                var actual_field: Variant = actual[key]
                if _is_number(expected_value):
                    if (not _is_number(actual_field)
                            or absf(float(actual_field) - float(expected_value)) > 0.001):
                        return _reject_attack_config(
                            group + " exact reaction " + key + " does not match brucelee.set"
                        )
                elif typeof(expected_value) == TYPE_BOOL:
                    if typeof(actual_field) != TYPE_BOOL or bool(actual_field) != bool(expected_value):
                        return _reject_attack_config(
                            group + " exact reaction " + key + " does not match brucelee.set"
                        )
                elif String(actual_field) != String(expected_value):
                    return _reject_attack_config(
                        group + " exact reaction " + key + " does not match brucelee.set"
                    )
            var duration_frames: int = int(actual["animation_duration_frames"])
            var exit_frame: int = int(actual["exit_start_frame"])
            var linking_frame: int = int(actual["linking_frame"])
            if (duration_frames <= 0
                    or exit_frame < 0
                    or exit_frame > duration_frames
                    or linking_frame < 0
                    or linking_frame > duration_frames
                    or float(actual["animation_radius"]) <= 0.0):
                return _reject_attack_config(group + " exact reaction frames are invalid")
            if bool(actual["clip_implemented"]):
                return _reject_attack_config(group + " exact reaction clip is not in the candidate")
            loaded_entries.append(actual.duplicate(true))
        loaded[group] = loaded_entries
    return loaded


func _reject_attack_config(message: String) -> Dictionary:
    attack_config_error = message
    return {}


func _add_mesh(mesh: Mesh, local_pos: Vector3, color: Color) -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    node.mesh = mesh
    node.position = local_pos
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    node.material_override = material
    add_child(node)
    _placeholder_visuals.append(node)
    return node

## Load this fighter's candidate GLB from a user-selected local file.
## The shipped project remains runnable with the generated placeholder visuals.
func _try_load_candidate_visual() -> void:
    candidate_loaded = false
    candidate_load_error = ""
    _reset_candidate_derived_state()
    var path_result: Dictionary = _candidate_path()
    if not path_result["error"].is_empty():
        candidate_load_error = path_result["error"]
        push_warning(character_name + " candidate GLB disabled: " + candidate_load_error)
        return
    var path: String = path_result["path"]
    if path.is_empty():
        return
    var clip_error: String = _candidate_clip_mapping_error()
    if not clip_error.is_empty():
        candidate_load_error = clip_error
        push_warning(character_name + " candidate GLB disabled: " + candidate_load_error)
        return
    var document: GLTFDocument = GLTFDocument.new()
    var state: GLTFState = GLTFState.new()
    var result: Error = document.append_from_file(path, state)
    if result != OK:
        candidate_load_error = "GLB read failed with error %d" % result
        _reset_candidate_derived_state()
        push_warning(character_name + " candidate GLB disabled: " + candidate_load_error)
        return
    var generated: Node = document.generate_scene(state)
    if generated == null or not generated is Node3D:
        if generated != null:
            generated.free()
        candidate_load_error = "GLB did not generate a 3D scene"
        _reset_candidate_derived_state()
        push_warning(character_name + " candidate GLB disabled: " + candidate_load_error)
        return

    _candidate_root = Node3D.new()
    _candidate_root.name = "LocalCandidateCharacter"
    # The candidate's local forward is +Z; PortFighter's local front is +X.
    _candidate_root.rotation.y = PI * 0.5
    _candidate_root.add_child(generated)
    add_child(_candidate_root)
    if not _fit_candidate_visual():
        if candidate_load_error.is_empty():
            candidate_load_error = "GLB mesh bounds could not be measured"
        _candidate_root.queue_free()
        _candidate_root = null
        _reset_candidate_derived_state()
        push_warning(character_name + " candidate GLB disabled: " + candidate_load_error)
        return

    _candidate_animation = _find_animation_player(generated)
    if _candidate_animation == null:
        _candidate_root.queue_free()
        _candidate_root = null
        candidate_load_error = "GLB has no AnimationPlayer"
        _reset_candidate_derived_state()
        push_warning(character_name + " candidate GLB disabled: " + candidate_load_error)
        return
    var missing: Array[String] = []
    for action: String in ["idle", "punch", "kick"]:
        var expected: String = candidate_clips[action]
        var matched: String = _find_animation_clip(_candidate_animation, expected)
        if matched.is_empty():
            missing.append(expected)
        else:
            _candidate_clip_paths[action] = matched
    if not missing.is_empty():
        _candidate_root.queue_free()
        _candidate_root = null
        candidate_load_error = "GLB is missing candidate clips: " + ", ".join(missing)
        _reset_candidate_derived_state()
        push_warning(character_name + " candidate GLB disabled: " + candidate_load_error)
        return
    # This local candidate has a named character root. Its reaction translation
    # is not yet mapped to gameplay movement and must not move the visual alone.
    var character_nodes: Array[Node] = generated.find_children("character", "Node3D", true, false)
    if character_nodes.size() == 1:
        _candidate_character = character_nodes[0] as Node3D
        _candidate_character_rest_position = _candidate_character.position
        var skeleton_nodes: Array[Node] = _candidate_character.find_children("*", "Skeleton3D", true, false)
        if skeleton_nodes.size() == 1:
            _candidate_skeleton = skeleton_nodes[0] as Skeleton3D
            _candidate_skeleton_parent = _candidate_skeleton.get_parent()
    for action: String in [
            "move", "ko", "high_punch", "high_kick",
            "high_punch3", "low_punch3", "low_kick3", "high_kick3",
            "special_kick_high",
            "high_punch2", "low_punch2", "high_kick2", "low_kick2",
            "special_kick_low_miss", "special_kick_low_hit",
            "special_punch_low_miss", "special_punch_low_hit",
            "special_punch_high_miss", "special_punch_high_hit",
            "parry_high", "parry_low", "parry_attack", "grab1", "grab2", "grab1_miss", "grab2_miss",
            "endattack1", "endattack2", "stun", "stun_fall",
            "stun_hard", "stun_brutal"]:
        if not candidate_clips.has(action):
            continue
        var matched_optional: String = _find_animation_clip(
            _candidate_animation, String(candidate_clips[action])
        )
        if not matched_optional.is_empty():
            _candidate_clip_paths[action] = matched_optional
    # Reaction clips are optional so earlier three-clip local assets still work.
    for group: String in REACTION_PROFILE_DATA:
        for height: String in REACTION_PROFILE_DATA[group]:
            var reaction_name: String = REACTION_PROFILE_DATA[group][height]["animation"]
            var matched: String = _find_animation_clip(_candidate_animation, reaction_name)
            if not matched.is_empty() and _candidate_skeleton != null:
                var clip: Animation = _candidate_animation.get_animation(matched)
                if _prepare_candidate_reaction(clip):
                    _candidate_clip_paths[reaction_name] = matched
    # Exact hard reactions stay clip_implemented false in JSON. A loaded GLB
    # can still play one after its tracks pass the same candidate check.
    for exact_group: String in EXACT_REACTIONS:
        var exact_entries: Variant = EXACT_REACTIONS[exact_group]
        if not exact_entries is Array or _candidate_skeleton == null:
            continue
        for exact_value: Variant in exact_entries:
            if not exact_value is Dictionary:
                continue
            var exact_entry: Dictionary = exact_value
            var exact_name: String = String(exact_entry.get("animation", ""))
            if exact_name.is_empty():
                continue
            var matched_exact: String = _find_animation_clip(_candidate_animation, exact_name)
            if matched_exact.is_empty():
                continue
            var exact_clip: Animation = _candidate_animation.get_animation(matched_exact)
            if _prepare_candidate_reaction(exact_clip):
                _candidate_clip_paths[exact_name] = matched_exact
    # Return clips stay return_implemented false in JSON. A loaded GLB can
    # enter one only after the same candidate track check used above.
    if _candidate_skeleton != null:
        for return_clip_name: String in [
            IDLE2_CLIP, FACEDOWN_IDLE_CLIP, BRICK_FACEDOWN_IDLE_CLIP, FACEDOWN_GETUP_CLIP,
            FACEDOWN_IMPACT_CLIP, FACEDOWN_ATTACK_CLIP,
            FACEUP_IMPACT_TO_FLOOR_CLIP, FACEUP_IDLE_CLIP,
            FACEUP_GETUP_CLIP, FACEUP_ATTACK_CLIP, FACEUP_IMPACT_CLIP,
            ATTACK_TO_FLOOR_CLIP, BRICK_FRONT_LOW_CLIP,
        ]:
            var matched_return: String = _find_animation_clip(
                _candidate_animation, return_clip_name
            )
            if matched_return.is_empty():
                continue
            var return_clip: Animation = _candidate_animation.get_animation(matched_return)
            if return_clip_name in [BRICK_FRONT_LOW_CLIP, BRICK_FACEDOWN_IDLE_CLIP]:
                var expected_length: float = (
                    23.0 / SOURCE_FRAME_RATE if return_clip_name == BRICK_FRONT_LOW_CLIP
                    else 45.0 / SOURCE_FRAME_RATE
                )
                if not _valid_brick_ground_clip(return_clip, expected_length):
                    continue
            if _prepare_candidate_reaction(return_clip):
                _candidate_clip_paths[return_clip_name] = matched_return
    var idle: Animation = _candidate_animation.get_animation(_candidate_clip_paths["idle"])
    idle.loop_mode = Animation.LOOP_LINEAR
    if _candidate_clip_paths.has("move"):
        var move: Animation = _candidate_animation.get_animation(
            _candidate_clip_paths["move"]
        )
        move.loop_mode = Animation.LOOP_LINEAR
    for looping_return: String in [
        IDLE2_CLIP, FACEDOWN_IDLE_CLIP, BRICK_FACEDOWN_IDLE_CLIP, FACEUP_IDLE_CLIP,
    ]:
        if not _candidate_clip_paths.has(looping_return):
            continue
        var looping_clip: Animation = _candidate_animation.get_animation(
            _candidate_clip_paths[looping_return]
        )
        looping_clip.loop_mode = Animation.LOOP_LINEAR
    if _candidate_clip_paths.has(FACEDOWN_GETUP_CLIP):
        var getup_clip: Animation = _candidate_animation.get_animation(
            _candidate_clip_paths[FACEDOWN_GETUP_CLIP]
        )
        getup_clip.loop_mode = Animation.LOOP_NONE
    if _candidate_clip_paths.has(FACEDOWN_IMPACT_CLIP):
        var facedown_impact_clip: Animation = _candidate_animation.get_animation(
            _candidate_clip_paths[FACEDOWN_IMPACT_CLIP]
        )
        facedown_impact_clip.loop_mode = Animation.LOOP_NONE
    if _candidate_clip_paths.has(FACEDOWN_ATTACK_CLIP):
        var facedown_attack_clip: Animation = _candidate_animation.get_animation(
            _candidate_clip_paths[FACEDOWN_ATTACK_CLIP]
        )
        facedown_attack_clip.loop_mode = Animation.LOOP_NONE
    if _candidate_clip_paths.has(FACEUP_IMPACT_TO_FLOOR_CLIP):
        var faceup_impact_clip: Animation = _candidate_animation.get_animation(
            _candidate_clip_paths[FACEUP_IMPACT_TO_FLOOR_CLIP]
        )
        faceup_impact_clip.loop_mode = Animation.LOOP_NONE
    if _candidate_clip_paths.has(FACEUP_GETUP_CLIP):
        var faceup_getup_clip: Animation = _candidate_animation.get_animation(
            _candidate_clip_paths[FACEUP_GETUP_CLIP]
        )
        faceup_getup_clip.loop_mode = Animation.LOOP_NONE
    if _candidate_clip_paths.has(FACEUP_ATTACK_CLIP):
        var faceup_attack_clip: Animation = _candidate_animation.get_animation(
            _candidate_clip_paths[FACEUP_ATTACK_CLIP]
        )
        faceup_attack_clip.loop_mode = Animation.LOOP_NONE
    if _candidate_clip_paths.has(ATTACK_TO_FLOOR_CLIP):
        var attack_to_floor_clip: Animation = _candidate_animation.get_animation(
            _candidate_clip_paths[ATTACK_TO_FLOOR_CLIP]
        )
        attack_to_floor_clip.loop_mode = Animation.LOOP_NONE
    for action: String in _candidate_clip_paths:
        _disable_candidate_character_position_tracks(
            _candidate_animation.get_animation(_candidate_clip_paths[action])
        )
    _align_candidate_attack_timings()
    var texture_root: String = candidate_texture_root
    if texture_root.is_empty():
        texture_root = OS.get_environment(
            "BRUCELEE_PLAYER_TEXTURE_ROOT" if is_player
            else "BRUCELEE_OPPONENT_TEXTURE_ROOT"
        )
    var material_result: Dictionary = CandidateMaterialLoader.new().apply_to(
        generated, texture_root, candidate_material_profile
    )
    candidate_textures_loaded = material_result["loaded"]
    candidate_texture_error = material_result["error"]
    candidate_texture_reason = material_result["reason"]
    if not candidate_texture_error.is_empty():
        push_warning(character_name + " candidate textures disabled: " + candidate_texture_error)
    for visual: MeshInstance3D in _placeholder_visuals:
        visual.visible = false
    candidate_loaded = true
    _play_candidate_action("idle")


func _reset_candidate_derived_state() -> void:
    candidate_animation_clip = ""
    candidate_visual_height = 0.0
    candidate_textures_loaded = false
    candidate_texture_error = ""
    candidate_texture_reason = ""
    _candidate_action = ""
    candidate_visual_blend_pending_seconds = 0.0
    candidate_visual_blend_seconds_last = 0.0
    candidate_visual_blend_source_action_last = ""
    candidate_visual_blend_target_action_last = ""
    _candidate_clip_paths.clear()
    _candidate_animation = null
    _candidate_character = null
    _candidate_skeleton = null
    _candidate_skeleton_parent = null
    _candidate_source_min_y = CANDIDATE_SOURCE_MIN_Y
    _candidate_visual_scale = 1.0


func _candidate_clip_mapping_error() -> String:
    for action: Variant in candidate_clips:
        if typeof(action) != TYPE_STRING or String(action).is_empty():
            return "candidate clip mapping has an invalid action name"
        var mapped: Variant = candidate_clips[action]
        if typeof(mapped) != TYPE_STRING or String(mapped).strip_edges().is_empty():
            return "candidate clip mapping has an invalid " + String(action)
    for action: String in ["idle", "punch", "kick"]:
        if not candidate_clips.has(action):
            return "candidate clip mapping lacks " + action
    return ""


func _fit_candidate_visual() -> bool:
    if CANDIDATE_HEIGHT <= 0.0:
        return false
    var measured: Dictionary = _candidate_local_bounds()
    var factor: float
    var visual_source_height: float
    var measured_error: String = String(measured.get("error", ""))
    var measured_bounds: AABB
    var has_bounds: bool = measured.has("bounds")
    if has_bounds:
        measured_bounds = measured["bounds"]
    if not measured_error.is_empty() or not has_bounds or measured_bounds.size.y <= 0.0:
        if not is_player:
            candidate_load_error = measured_error
            if candidate_load_error.is_empty():
                candidate_load_error = "candidate GLB has no positive visual height"
            return false
        # Preserve the previous player-only behavior for candidate layouts that
        # cannot be measured by the strict CPU-skinning bounds path.
        _candidate_source_min_y = CANDIDATE_SOURCE_MIN_Y
        visual_source_height = CANDIDATE_SOURCE_HEIGHT
        factor = CANDIDATE_HEIGHT / visual_source_height
        push_warning(character_name + " candidate uses fixed source scale fallback")
    else:
        _candidate_source_min_y = measured_bounds.position.y
        visual_source_height = measured_bounds.size.y
        factor = CANDIDATE_HEIGHT / visual_source_height
    _candidate_visual_scale = factor
    _candidate_root.scale = Vector3.ONE * factor
    _candidate_root.position = Vector3(
        0.0, -PLAYER_ORIGIN_HEIGHT - _candidate_source_min_y * factor, 0.0
    )
    candidate_visual_height = visual_source_height * factor
    return true


func _candidate_local_bounds() -> Dictionary:
    var original_transform: Transform3D = _candidate_root.global_transform
    _candidate_root.global_transform = Transform3D.IDENTITY
    var measured: Dictionary = CandidateBounds.scene_bounds(_candidate_root)
    _candidate_root.global_transform = original_transform
    return measured


func _candidate_path() -> Dictionary:
    var chosen: String = candidate_glb_path
    if chosen.is_empty():
        chosen = OS.get_environment(
            "BRUCELEE_PLAYER_GLB" if is_player else "BRUCELEE_OPPONENT_GLB"
        )
    var args: PackedStringArray = OS.get_cmdline_user_args()
    var index: int = 0
    while index < args.size():
        var value: String = args[index]
        var argument: String = (
            "--candidate-player-glb" if is_player else "--candidate-opponent-glb"
        )
        if value == argument or value.begins_with(argument + "="):
            if value == argument:
                if index + 1 >= args.size() or args[index + 1].begins_with("--"):
                    return {"path": "", "error": argument + " requires a path"}
                index += 1
                chosen = args[index]
            else:
                chosen = value.trim_prefix(argument + "=")
        index += 1
    if chosen.is_empty():
        return {"path": "", "error": ""}
    var path_error: String = CandidatePathGuard.external_path_error(
        chosen, "candidate path"
    )
    if not path_error.is_empty():
        return {"path": "", "error": path_error}
    var normalized: String = CandidatePathGuard.normalize_absolute_path(chosen)
    if chosen.get_extension().to_lower() != "glb":
        return {"path": "", "error": "candidate path must be a local .glb file"}
    if not FileAccess.file_exists(normalized):
        return {"path": "", "error": "candidate GLB does not exist"}
    return {"path": normalized, "error": ""}


func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child: Node in node.get_children():
        var found: AnimationPlayer = _find_animation_player(child)
        if found != null:
            return found
    return null


func _find_animation_clip(player: AnimationPlayer, expected: String) -> String:
    for clip: StringName in player.get_animation_list():
        var name: String = String(clip)
        if name == expected or name.ends_with("/" + expected):
            return name
    return ""


func _disable_candidate_character_position_tracks(clip: Animation) -> void:
    if clip == null or _candidate_character == null:
        return
    var animation_root: Node = _candidate_animation.get_node_or_null(
        _candidate_animation.root_node
    )
    if animation_root == null:
        return
    for track: int in clip.get_track_count():
        var kind: int = clip.track_get_type(track)
        if kind not in [
            Animation.TYPE_POSITION_3D,
            Animation.TYPE_ROTATION_3D,
            Animation.TYPE_SCALE_3D,
        ]:
            continue
        var target: Node = animation_root.get_node_or_null(clip.track_get_path(track))
        if target == _candidate_character:
            clip.track_set_enabled(track, false)


func _align_candidate_attack_timings() -> void:
    if not candidate_scale_attack_timing:
        return
    for action: String in ["punch", "kick"]:
        if not ATTACKS.has(action) or not _candidate_clip_paths.has(action):
            continue
        var details: Dictionary = ATTACKS[action]
        var state_duration: float = (
            float(details["startup"]) + float(details["active"])
            + float(details["recovery"])
        )
        var clip_duration: float = _candidate_animation.get_animation(
            _candidate_clip_paths[action]
        ).length
        if state_duration <= 0.0 or clip_duration <= 0.0:
            continue
        var factor: float = clip_duration / state_duration
        details["startup"] = float(details["startup"]) * factor
        details["active"] = float(details["active"]) * factor
        details["recovery"] = float(details["recovery"]) * factor
        details["candidate_timing_scale"] = factor
        ATTACKS[action] = details


func _valid_brick_ground_clip(clip: Animation, expected_length: float) -> bool:
    if clip == null or absf(clip.length - expected_length) > 0.002:
        return false
    var animation_root: Node = _candidate_animation.get_node_or_null(_candidate_animation.root_node)
    if animation_root == null or _candidate_skeleton == null:
        return false
    var bone_tracks: int = 0
    for track: int in clip.get_track_count():
        var path: NodePath = clip.track_get_path(track)
        if clip.track_get_key_count(track) == 0:
            return false
        if path.get_subname_count() > 0:
            if (path.get_subname_count() != 1
                    or animation_root.get_node_or_null(path) != _candidate_skeleton
                    or _candidate_skeleton.find_bone(String(path.get_subname(0))) < 0):
                return false
            bone_tracks += 1
    return bone_tracks > 0


func _prepare_candidate_reaction(clip: Animation) -> bool:
    var animation_root: Node = _candidate_animation.get_node_or_null(_candidate_animation.root_node)
    if animation_root == null:
        return false
    var character_position_tracks: Array[int] = []
    for track: int in clip.get_track_count():
        var kind: int = clip.track_get_type(track)
        if kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
            return false
        var track_path: NodePath = clip.track_get_path(track)
        var target: Node = animation_root.get_node_or_null(track_path)
        if track_path.get_subname_count() > 0:
            if target != _candidate_skeleton:
                return false
            continue # Skeleton bone tracks.
        if target == _candidate_character:
            # Object translation is not gameplay push. Object rotation is not
            # fighter facing. Object scale must not resize the mesh while the
            # hit capsule stays fixed. Bone tracks still play.
            character_position_tracks.append(track)
        # The candidate exporter places the animated skeleton under this parent;
        # retain its pose transforms as unverified visual motion, not gameplay push.
        elif target != _candidate_skeleton_parent:
            return false
    for track: int in character_position_tracks:
        clip.track_set_enabled(track, false)
    return true


func _play_candidate_action(action: String, start_frame: int = 0) -> void:
    if _candidate_animation == null or not _candidate_clip_paths.has(action):
        return
    if _candidate_action == action and _candidate_animation.is_playing():
        candidate_visual_blend_pending_seconds = 0.0
        return
    var previous_action: String = _candidate_action
    var blend_seconds: float = candidate_visual_blend_pending_seconds
    var blend_applied: bool = (
        candidate_visual_blending_enabled
        and blend_seconds > 0.0
        and _candidate_animation.is_playing()
    )
    _candidate_action = action
    candidate_animation_clip = _candidate_clip_paths[action]
    candidate_visual_blend_pending_seconds = 0.0
    candidate_visual_blend_seconds_last = blend_seconds if blend_applied else 0.0
    candidate_visual_blend_source_action_last = previous_action if blend_applied else ""
    candidate_visual_blend_target_action_last = action if blend_applied else ""
    if blend_applied:
        _candidate_animation.play(candidate_animation_clip, blend_seconds)
    else:
        _candidate_animation.play(candidate_animation_clip)
    if start_frame > 0:
        _candidate_animation.seek(
            float(start_frame) / SOURCE_FRAME_RATE, true
        )


func supports_attack(kind: String) -> bool:
    if not ATTACKS.has(kind):
        return false
    if candidate_loaded and not _candidate_clip_paths.has(kind):
        return false
    return true



func _uses_standing_idle_rules() -> bool:
    return state == "idle" or state == "idle2"


func _can_block_current_hit() -> bool:
    if _uses_standing_idle_rules():
        return true
    if state != "faceupattack":
        return false
    var source_frame: float = state_time * SOURCE_FRAME_RATE
    return source_frame + 0.0001 >= 27.0 and source_frame <= 38.0001


func _clear_reaction_tracking() -> void:
    last_reaction_group = ""
    last_reaction_source_action = ""
    last_reaction_animation = ""
    last_reaction_exit_frame = -1
    last_reaction_clip_implemented = false


func _restart_candidate_action() -> void:
    if _candidate_animation != null:
        _candidate_animation.stop()
    _candidate_action = ""
    candidate_visual_blend_pending_seconds = 0.0


func _queue_candidate_visual_blend(seconds: float) -> void:
    if (candidate_visual_blending_enabled
            and is_finite(seconds)
            and seconds > 0.0):
        candidate_visual_blend_pending_seconds = seconds
    else:
        candidate_visual_blend_pending_seconds = 0.0


func _enter_locomotion_state(next_state: String) -> void:
    var previous_state: String = state
    state = next_state
    state_time = 0.0
    attack_kind = ""
    _clear_ground_attack_input_history()
    _clear_standing_combo_state()
    _clear_reaction_tracking()
    if (candidate_visual_blending_enabled
            and previous_state == "attacktofloor"
            and next_state == "idle2"
            and _candidate_action == ATTACK_TO_FLOOR_CLIP
            and _candidate_animation != null
            and _candidate_animation.is_playing()):
        _queue_candidate_visual_blend(
            float(CANDIDATE_ATTACK_TO_FLOOR_RETURN_BLENDING_FRAMES)
                    / SOURCE_FRAME_RATE
        )
    else:
        _restart_candidate_action()


func _verified_post_hit_return_state() -> String:
    var profile: Dictionary = _profile_for_animation(last_reaction_animation)
    var return_action: String = String(profile.get("return_action", ""))
    # The return clip alone must not start a post-hit state. The hard reaction
    # that links to it has to be registered and marked implemented.
    var reaction_clip_ready: bool = (
        last_reaction_clip_implemented
        and _candidate_clip_paths.has(last_reaction_animation)
    )
    if (attack_config_path == BRICK_ATTACK_CONFIG_PATH
            and last_reaction_source_action == "impacthardfrontlow"
            and last_reaction_animation == BRICK_FRONT_LOW_CLIP
            and reaction_clip_ready
            and _candidate_clip_paths.has(BRICK_FACEDOWN_IDLE_CLIP)):
        return "facedownidle"
    if (reaction_clip_ready
            and return_action == "idle2"
            and _candidate_clip_paths.has(IDLE2_CLIP)):
        return "idle2"
    if (reaction_clip_ready
            and return_action == "facedownidle"
            and _candidate_clip_paths.has(FACEDOWN_IDLE_CLIP)
            and _candidate_clip_paths.has(FACEDOWN_GETUP_CLIP)):
        return "facedownidle"
    if (reaction_clip_ready
            and return_action == "faceupidle"
            and _candidate_clip_paths.has(FACEUP_IDLE_CLIP)):
        return "faceupidle"
    return "idle"


func _advance_impactstun_state(delta: float) -> void:
    state_time -= delta
    if state_time > 0.000001:
        return
    state = "stun"
    state_time = float(STUN_DURATION_FRAMES) / SOURCE_FRAME_RATE


func _advance_stun_state(delta: float) -> void:
    state_time -= delta
    if state_time > 0.000001:
        return
    if state == "stun":
        state = "stun2"
        state_time = float(STUN_DURATION_FRAMES) / SOURCE_FRAME_RATE
    elif state == "stun2":
        state = "stunfall"
        state_time = float(STUN_FALL_DURATION_FRAMES) / SOURCE_FRAME_RATE
    else:
        _begin_faceup_ko(0.0)


func _advance_stun_impact_state(delta: float) -> void:
    state_time -= delta
    if state_time > 0.000001:
        return
    if _stun_impact_next_state == "stunfall":
        state = "stunfall"
        state_time = float(STUN_FALL_DURATION_FRAMES) / SOURCE_FRAME_RATE
    elif _stun_impact_next_state == "faceupko":
        _begin_faceup_ko(0.0)
    elif _stun_impact_next_state == "facedownko":
        _begin_facedown_ko()
    else:
        state = _stun_impact_next_state
        state_time = 0.0


func _advance_return_state(delta: float) -> void:
    if state == "idle2":
        state_time += maxf(delta, 0.0)
        _wrap_return_loop(IDLE2_DURATION_FRAMES)
        return
    if state == "facedownidle":
        var before: float = state_time
        state_time += maxf(delta, 0.0)
        if (attack_config_path != BRICK_ATTACK_CONFIG_PATH
                and _facedown_getup_requested(before, state_time)):
            _begin_facedown_getup()
            return
        _wrap_return_loop(FACEDOWN_IDLE_DURATION_FRAMES)
        return
    if state == "facedownko":
        state_time += maxf(delta, 0.0)
        _wrap_return_loop(FACEDOWN_IDLE_DURATION_FRAMES)
        return
    if state == "facedowngetup":
        state_time += maxf(delta, 0.0)
        if _reached_source_frame(state_time, FACEDOWN_GETUP_EXIT_FRAME):
            _enter_locomotion_state("idle")
        return
    if state == "impactfacedown":
        state_time += maxf(delta, 0.0)
        if _reached_source_frame(state_time, FACEDOWN_IMPACT_EXIT_FRAME):
            _enter_locomotion_state("facedownidle")
        return
    if state == "facedownattack":
        var before: float = state_time
        var after: float = before + maxf(delta, 0.0)
        if (_attack_connected == false
                and _source_frame_window_intersects(
                    before,
                    after,
                    FACEDOWN_ATTACK_DAMAGE_START_FRAME,
                    FACEDOWN_ATTACK_DAMAGE_END_FRAME,
                )):
            _try_facedown_attack_contact()
        state_time = after
        if _reached_source_frame(state_time, FACEDOWN_ATTACK_EXIT_FRAME):
            _enter_locomotion_state("idle")
        return
    if state == "impacttofloor":
        state_time += maxf(delta, 0.0)
        if _reached_source_frame(state_time, FACEUP_IMPACT_TO_FLOOR_EXIT_FRAME):
            _enter_locomotion_state("faceupidle")
        return
    if state == "impactfaceup":
        state_time += maxf(delta, 0.0)
        if _reached_source_frame(state_time, FACEUP_IMPACT_EXIT_FRAME):
            _enter_locomotion_state("faceupidle")
        return
    if state == "faceupko":
        state_time += maxf(delta, 0.0)
        _wrap_return_loop(FACEUP_IDLE_DURATION_FRAMES)
        return
    if state == "faceupidle":
        var before: float = state_time
        state_time += maxf(delta, 0.0)
        if _faceup_getup_requested(before, state_time):
            _begin_faceup_getup()
            return
        _wrap_return_loop(FACEUP_IDLE_DURATION_FRAMES)
        return
    if state == "faceupgetup":
        state_time += maxf(delta, 0.0)
        if _reached_source_frame(state_time, FACEUP_GETUP_EXIT_FRAME):
            _enter_locomotion_state("idle")
        return
    if state == "attacktofloor":
        var before: float = state_time
        var after: float = before + maxf(delta, 0.0)
        if (_attack_connected == false
                and _source_frame_window_intersects(
                    before, after, ATTACK_TO_FLOOR_DAMAGE_START_FRAME,
                    ATTACK_TO_FLOOR_DAMAGE_END_FRAME)):
            _try_attack_to_floor_contact()
        state_time = after
        if _reached_source_frame(state_time, ATTACK_TO_FLOOR_EXIT_START_FRAME):
            # The recovered direct edge is idle2 [80,90]. Frame 80 is the
            # deterministic earliest-frame candidate; native timing is unverified.
            _enter_locomotion_state("idle2")
        return
    if state == "faceupattack":
        var before: float = state_time
        var after: float = before + maxf(delta, 0.0)
        if (_attack_connected == false
                and _source_frame_window_intersects(
                    before,
                    after,
                    FACEUP_ATTACK_DAMAGE_START_FRAME,
                    FACEUP_ATTACK_DAMAGE_END_FRAME,
                )):
            _try_faceup_attack_contact()
        state_time = after
        if _reached_source_frame(state_time, FACEUP_ATTACK_EXIT_FRAME):
            _enter_locomotion_state("idle")
        return


func _wrap_return_loop(duration_frames: int) -> void:
    var duration: float = float(duration_frames) / SOURCE_FRAME_RATE
    if duration <= 0.0:
        return
    while state_time >= duration:
        state_time -= duration


func _reached_source_frame(seconds: float, frame: int) -> bool:
    return seconds * SOURCE_FRAME_RATE + 0.0001 >= float(frame)


func _source_frame_window_intersects(
        before: float, after: float, start_frame: int, end_frame: int
) -> bool:
    var start_frame_time: float = minf(before, after) * SOURCE_FRAME_RATE
    var end_frame_time: float = maxf(before, after) * SOURCE_FRAME_RATE
    return (
        end_frame_time + 0.0001 >= float(start_frame)
        and start_frame_time <= float(end_frame) + 0.0001
    )


func _facedown_getup_requested(before: float, after: float) -> bool:
    # brucelee.set uses keystatus left/right. This prototype only has move_axis:
    # negative x stands in for left and positive x for right. It is not a
    # verified original keyboard binding.
    if absf(move_axis.x) <= 0.001 or not _candidate_clip_paths.has(FACEDOWN_GETUP_CLIP):
        return false
    var start_frame: float = minf(before, after) * SOURCE_FRAME_RATE
    var end_frame: float = maxf(before, after) * SOURCE_FRAME_RATE
    return (
        end_frame + 0.0001 >= float(FACEDOWN_GETUP_WINDOW_START)
        and start_frame <= float(FACEDOWN_GETUP_WINDOW_END) + 0.0001
    )


func _faceup_getup_requested(before: float, after: float) -> bool:
    # brucelee.set uses keystatus left/right. This prototype only has
    # move_axis, so negative x stands in for left and positive x for right.
    # This is a candidate PC mapping, not a verified Android input binding.
    if absf(move_axis.x) <= 0.001 or not _candidate_clip_paths.has(FACEUP_GETUP_CLIP):
        return false
    var start_frame: float = minf(before, after) * SOURCE_FRAME_RATE
    var end_frame: float = maxf(before, after) * SOURCE_FRAME_RATE
    return (
        end_frame + 0.0001 >= float(FACEUP_GETUP_WINDOW_START)
        and start_frame <= float(FACEUP_GETUP_WINDOW_END) + 0.0001
    )


func _begin_facedown_getup() -> void:
    state = "facedowngetup"
    state_time = 0.0
    attack_kind = ""
    _clear_ground_attack_input_history()
    _restart_candidate_action()


func _begin_faceup_getup() -> void:
    state = "faceupgetup"
    state_time = 0.0
    attack_kind = ""
    _clear_ground_attack_input_history()
    _clear_reaction_tracking()
    _restart_candidate_action()


func _accepts_facedown_low_impact(impact_height: String, blocked: bool, damage: float) -> bool:
    return (
        state == "facedownidle"
        and attack_config_path != BRICK_ATTACK_CONFIG_PATH
        and not blocked
        and impact_height == "low"
        and health - damage > 0.0
        and _candidate_clip_paths.has(FACEDOWN_IMPACT_CLIP)
    )


func _accepts_impact_to_floor(
        impact_height: String,
        blocked: bool,
        damage: float
) -> bool:
    var source_frame: float = state_time * SOURCE_FRAME_RATE
    var in_source_window: bool = (
        (state == "facedowngetup"
            and source_frame + 0.0001 >= 5.0
            and source_frame <= 11.0001)
        or
        (state == "facedownattack"
            and source_frame + 0.0001 >= 24.0
            and source_frame <= 31.0001)
        or
        (state == "faceupattack"
            and source_frame + 0.0001 >= 24.0
            and source_frame <= 31.0001)
    )
    return (
        in_source_window
        and not blocked
        and impact_height == "low"
        and health - damage > 0.0
        and _candidate_clip_paths.has(FACEUP_IMPACT_TO_FLOOR_CLIP)
        and _candidate_clip_paths.has(FACEUP_IDLE_CLIP)
    )


func _accepts_faceup_low_impact(
        impact_height: String,
        blocked: bool,
        damage: float,
) -> bool:
    return (
        state == "faceupidle"
        and not blocked
        and impact_height == "low"
        and health - damage > 0.0
        and _candidate_clip_paths.has(FACEUP_IMPACT_CLIP)
        and _candidate_clip_paths.has(FACEUP_IDLE_CLIP)
    )


func _accepts_faceup_ko(damage: float, blocked: bool) -> bool:
    return (
        state == "faceupidle"
        and not blocked
        and health - damage <= 0.0
        and _candidate_clip_paths.has(FACEUP_IDLE_CLIP)
    )


func _begin_facedown_ko() -> void:
    state = "facedownko"
    state_time = 0.0
    attack_kind = ""
    _attack_connected = false
    _clear_reaction_tracking()
    _restart_candidate_action()
    combat_ko.emit(self)


func _begin_faceup_ko(amount: float) -> void:
    health = maxf(0.0, health - amount)
    state = "faceupko"
    state_time = 0.0
    attack_kind = ""
    _attack_connected = false
    _clear_ground_attack_input_history()
    combo_hits = 0
    _clear_reaction_tracking()
    _restart_candidate_action()
    combat_ko.emit(self)


func begin_impact_to_floor(amount: float) -> void:
    health = maxf(0.0, health - amount)
    state = "impacttofloor"
    state_time = (
        float(FACEUP_IMPACT_TO_FLOOR_ENTRY_FRAME) / SOURCE_FRAME_RATE
    )
    attack_kind = ""
    _attack_connected = false
    _clear_ground_attack_input_history()
    combo_hits = 0
    _clear_reaction_tracking()
    _restart_candidate_action()


func begin_facedown_impact(amount: float) -> void:
    health = maxf(0.0, health - amount)
    state = "impactfacedown"
    state_time = 0.0
    attack_kind = ""
    _attack_connected = false
    _clear_ground_attack_input_history()
    combo_hits = 0
    last_reaction_group = "hit"
    last_reaction_source_action = "impactfacedown"
    last_reaction_animation = FACEDOWN_IMPACT_CLIP
    last_reaction_exit_frame = FACEDOWN_IMPACT_EXIT_FRAME
    last_reaction_clip_implemented = _candidate_clip_paths.has(FACEDOWN_IMPACT_CLIP)
    if _candidate_animation != null:
        _candidate_animation.stop()
        _candidate_action = ""
    candidate_visual_blend_pending_seconds = 0.0


func begin_faceup_impact(amount: float) -> void:
    health = maxf(0.0, health - amount)
    state = "impactfaceup"
    state_time = 0.0
    attack_kind = ""
    _attack_connected = false
    _clear_ground_attack_input_history()
    combo_hits = 0
    last_reaction_group = "hit"
    last_reaction_source_action = "impactfaceup"
    last_reaction_animation = FACEUP_IMPACT_CLIP
    last_reaction_exit_frame = FACEUP_IMPACT_EXIT_FRAME
    last_reaction_clip_implemented = _candidate_clip_paths.has(FACEUP_IMPACT_CLIP)
    _restart_candidate_action()


func record_virtual_press(virtual_key: String) -> bool:
    # This is the PC prototype's abstract press path. The original Android
    # physical-key mapping is not yet proven, so main.gd supplies a/b/c/d from
    # explicit keyboard bindings and this method only reproduces the recovered
    # three-item sequences as prototype input events.
    if (state not in ["facedownidle", "faceupidle"]
            or attack_config_path == BRICK_ATTACK_CONFIG_PATH):
        _clear_ground_attack_input_history()
        return false
    if virtual_key not in ["a", "b", "c", "d"]:
        return false
    if state == "faceupidle":
        var source_frame: float = state_time * SOURCE_FRAME_RATE
        if source_frame < -0.0001 or source_frame > 45.0001:
            _clear_ground_attack_input_history()
            return false
    _prune_ground_attack_input_history()
    if _ground_attack_input_owner != state:
        _clear_ground_attack_input_history()
        _ground_attack_input_owner = state
    _ground_attack_input_history.append({"key": virtual_key, "time": _time})
    if not _matches_ground_attack_sequence():
        return false
    var attack_state: String = (
        "facedownattack" if state == "facedownidle" else "faceupattack"
    )
    var attack_clip: String = (
        FACEDOWN_ATTACK_CLIP if state == "facedownidle" else FACEUP_ATTACK_CLIP
    )
    if not _candidate_clip_paths.has(attack_clip):
        return false
    state = attack_state
    state_time = 0.0
    attack_kind = attack_state
    attack_sequence += 1
    _attack_connected = false
    _clear_ground_attack_input_history()
    _restart_candidate_action()
    return true


func record_standing_combo_press(
        virtual_key: String,
        modifiers: Array = []
) -> bool:
    # Prototype-only sequence path for the recovered candobasicattacks links.
    # Physical key status, exact key-event lifetime and link scheduling remain
    # unverified. Only an attack with a recovered source window may buffer
    # sequence input, so Heavy (no source window) never accumulates a match.
    if not _accepts_standing_combo_input(virtual_key):
        _clear_standing_combo_state()
        return false
    _prune_standing_combo_input_history()
    var tokens: Array = [virtual_key]
    for modifier: Variant in modifiers:
        var token: String = String(modifier)
        if not tokens.has(token):
            tokens.append(token)
    if tokens.has("b") and (tokens.has("out") or tokens.has("left")):
        _special_stepback_origin = true
    _standing_combo_input_history.append({"tokens": tokens, "time": _time})
    var matched_attack: String = _matching_standing_combo_attack()
    if matched_attack.is_empty():
        return false
    # Prototype priority: the most recently completed sequence replaces an
    # earlier pending one. Native link priority is not recovered yet.
    _standing_combo_pending_attack = matched_attack
    _standing_combo_pending_source_sequence = attack_sequence
    _standing_combo_pending_source_kind = attack_kind
    _clear_standing_combo_input_history()
    return _try_begin_pending_standing_combo()


func record_parry_press(kind: String = "parry_high") -> bool:
    if state not in ["idle", "idle2"]:
        _parry_press_times.clear()
        return false
    _parry_press_times = _parry_press_times.filter(
        func(value: float) -> bool: return _time - value <= 0.5)
    _parry_press_times.append(_time)
    if _parry_press_times.size() < 3:
        return false
    _parry_press_times.clear()
    if not PARRY_RAGE_COSTS.has(kind) or not supports_attack(kind):
        return false
    var cost: float = float(PARRY_RAGE_COSTS[kind])
    if rage < cost:
        return false
    rage -= cost
    attack_kind = kind
    attack_sequence += 1
    _attack_connected = false
    _attack_hit_landed = false
    _grab_connected = false
    _multi_impact_applied.clear()
    state = "startup"
    state_time = float(ATTACKS[kind]["startup"])
    _restart_candidate_action()
    return true


func begin_guard() -> void:
    # Guard press must cancel a matched combo immediately. Waiting for the next
    # physics frame loses a rapid press-and-release tap entirely.
    guard_held = true
    _clear_standing_combo_state()


func end_guard() -> void:
    guard_held = false
    _parry_press_times.clear()


func _accepts_standing_combo_input(virtual_key: String) -> bool:
    # Guard rejects attack requests, so it must also reject combo history.
    # Otherwise a press made while guarding becomes the first key of a later
    # sequence.
    if (guard_held
            or attack_config_path == BRICK_ATTACK_CONFIG_PATH
            or virtual_key not in ["a", "b", "c", "d"]
            or state not in ["idle", "idle2", "startup", "active", "recovery"]):
        return false
    if state in ["startup", "active", "recovery"]:
        if attack_kind == "heavy" or not CANDOBASICATTACK_WINDOWS.has(attack_kind):
            return false
    return true


func _clear_standing_combo_input_history() -> void:
    _standing_combo_input_history.clear()


func _clear_standing_combo_state() -> void:
    _special_stepback_origin = false
    _clear_standing_combo_input_history()
    _standing_combo_pending_attack = ""
    _standing_combo_pending_source_sequence = -1
    _standing_combo_pending_source_kind = ""


func _prune_standing_combo_input_history() -> void:
    if _standing_combo_input_history.is_empty():
        return
    var first_time: float = float(_standing_combo_input_history.front()["time"])
    if _time > first_time + STANDING_COMBO_INPUT_PROTOTYPE_WINDOW_SECONDS:
        _clear_standing_combo_input_history()


func _matching_standing_combo_attack() -> String:
    # Links in candobasicattacks are ordered; lower source_index wins when
    # several sequences match. The few sequences without a recovered link
    # carry a high fallback index and retain their declaration order.
    var best_attack: String = ""
    var best_index: int = 999999
    for require_source: bool in [true, false]:
        for entry: Dictionary in STANDING_COMBO_SEQUENCES:
            var from_attack: String = String(entry.get("from_attack", ""))
            var from_attack_in: Array = entry.get("from_attack_in", [])
            if require_source:
                if not from_attack.is_empty() and from_attack != attack_kind:
                    continue
                if not from_attack_in.is_empty() and not from_attack_in.has(attack_kind):
                    continue
                if from_attack.is_empty() and from_attack_in.is_empty():
                    continue
            if not require_source and (not from_attack.is_empty() or not from_attack_in.is_empty()):
                continue
            if require_source and not supports_attack(String(entry["attack"])):
                continue
            if not require_source and not from_attack.is_empty():
                continue
            var steps: Array = entry["steps"]
            var required: int = steps.size() - 1
            for event_index: int in range(_standing_combo_input_history.size() - 1, -1, -1):
                var event: Dictionary = _standing_combo_input_history[event_index]
                if not _event_satisfies_step(event, steps[required]):
                    continue
                required -= 1
                if required < 0:
                    var index: int = int(entry.get("source_index", 999999))
                    if best_attack.is_empty() or index < best_index:
                        best_attack = String(entry["attack"])
                        best_index = index
                    break
        if not best_attack.is_empty():
            return best_attack
    return ""


func _event_satisfies_step(event: Dictionary, step: Variant) -> bool:
    var tokens: Array = event.get("tokens", [])
    var required_tokens: Array = step if step is Array else [step]
    # Absolute left/right are only consumed by steps that ask for them, so the
    # in/out directional sequences keep their exact token sets.
    var effective: Array = tokens.duplicate()
    if not required_tokens.has("left"):
        effective.erase("left")
    if not required_tokens.has("right"):
        effective.erase("right")
    if required_tokens.has("left") or required_tokens.has("right"):
        # Absolute side steps take precedence over the facing-relative in/out
        # token, which the same keyboard input also produces.
        effective.erase("in")
        effective.erase("out")
    # A step must match the pressed token set exactly. Otherwise the plain
    # a/a/a sequence would also consume up+a presses and shadow highpunch3.
    if effective.size() != required_tokens.size():
        return false
    for token: Variant in required_tokens:
        if not effective.has(String(token)):
            return false
    return true


func _current_attack_source_frame() -> float:
    if state not in ["startup", "active", "recovery"] or not ATTACKS.has(attack_kind):
        return -1.0
    if attack_kind == "heavy":
        return -1.0
    var details: Dictionary = ATTACKS[attack_kind]
    var remaining_frames: float = state_time * SOURCE_FRAME_RATE
    if state == "startup":
        remaining_frames += (
            float(details["active"]) + float(details["recovery"])
        ) * SOURCE_FRAME_RATE
    elif state == "active":
        remaining_frames += float(details["recovery"]) * SOURCE_FRAME_RATE
    return float(details["animation_frame_count"]) - remaining_frames


func _candobasicattack_window_contains_current_frame() -> bool:
    if not CANDOBASICATTACK_WINDOWS.has(attack_kind):
        return false
    var window: Array = CANDOBASICATTACK_WINDOWS[attack_kind]
    var frame: float = _current_attack_source_frame()
    return (frame + 0.0001 >= float(window[0])
            and frame <= float(window[1]) + 0.0001)


func _try_begin_pending_standing_combo() -> bool:
    if _standing_combo_pending_attack.is_empty():
        return false
    # The pending entry is bound to the attack that was current when the
    # sequence completed. Ending that attack, switching to another one, being
    # interrupted, or holding it in a Heavy attack cancels the entry instead of
    # reusing the old input in a later attack.
    if (state not in ["startup", "active", "recovery"]
            or attack_kind == "heavy"
            or attack_kind != _standing_combo_pending_source_kind
            or attack_sequence != _standing_combo_pending_source_sequence):
        _clear_standing_combo_state()
        return false
    if not _candobasicattack_window_contains_current_frame():
        # endmove is a prototype extension: its source link is from_group
        # candobasicattacks and requires oppposestun; allow the endmove input
        # while the actual unblocked hitstun overlap exists, even if the base
        # action's recorded combo window starts later.
        if not (ENDATTACK_ATTACKS.has(_standing_combo_pending_attack)
                and _attack_hit_landed
                and opponent != null and is_instance_valid(opponent)
                and opponent.state in ["hitstun", "stun", "stun2"]):
            return false
    var special_cost: float = float(SPECIAL_RAGE_COSTS.get(
            _standing_combo_pending_attack, 0.0))
    if special_cost > 0.0 and rage < special_cost:
        _clear_standing_combo_state()
        return false
    if (special_cost > 0.0
            and SPECIAL_REQUIRES_STEPBACK.has(_standing_combo_pending_attack)
            and not _special_stepback_origin):
        _clear_standing_combo_state()
        return false
    if GRAB_ATTACKS.has(_standing_combo_pending_attack):
        if not _attack_hit_landed:
            _clear_standing_combo_state()
            return false
        if (opponent == null or not is_instance_valid(opponent)
                or opponent.guard_held
                or opponent.state not in ["idle", "idle2", "hitstun"]):
            _clear_standing_combo_state()
            return false
        var grab_distance: float = Vector2(
            opponent.global_position.x - global_position.x,
            opponent.global_position.z - global_position.z).length()
        if grab_distance > PROTOTYPE_GRAB_DISTANCE:
            _clear_standing_combo_state()
            return false
    if ENDATTACK_ATTACKS.has(_standing_combo_pending_attack):
        if not (_grab_connected or _attack_hit_landed):
            _clear_standing_combo_state()
            return false
        if (opponent == null or not is_instance_valid(opponent)
                or opponent.guard_held
                or opponent.state not in ["hitstun", "stun", "stun2"]):
            _clear_standing_combo_state()
            return false
        var end_distance: float = Vector2(
            opponent.global_position.x - global_position.x,
            opponent.global_position.z - global_position.z).length()
        if end_distance > PROTOTYPE_GRAB_DISTANCE:
            _clear_standing_combo_state()
            return false
    if not supports_attack(_standing_combo_pending_attack):
        _clear_standing_combo_state()
        return false
    var next_attack: String = _standing_combo_pending_attack
    if special_cost > 0.0:
        rage = maxf(0.0, rage - special_cost)
    var target_action: String = _candidate_action_for_attack(next_attack)
    _clear_standing_combo_state()
    state = "startup"
    state_time = float(ATTACKS[next_attack]["startup"])
    attack_kind = next_attack
    attack_sequence += 1
    _attack_connected = false
    # Re-blending a clip into itself would keep the previous playback position:
    # _play_candidate_action() returns early when the same action is still
    # playing. Same-action transitions therefore restart from frame 0.
    if (candidate_visual_blending_enabled
            and target_action != _candidate_action
            and _candidate_animation != null
            and _candidate_animation.is_playing()):
        _queue_candidate_visual_blend(2.0 / SOURCE_FRAME_RATE)
    else:
        _restart_candidate_action()
    return true


func _candidate_action_for_attack(kind: String) -> String:
    match kind:
        "punch":
            return "punch"
        "kick", "heavy":
            return "kick"
        "high_punch", "high_kick", "high_punch3", "low_punch3", "low_kick3", "high_kick3", "special_kick_high", "high_punch2", "low_punch2", "high_kick2", "low_kick2", "special_kick_low_miss", "special_kick_low_hit", "special_punch_low_miss", "special_punch_low_hit", "special_punch_high_miss", "special_punch_high_hit", "parry_high", "parry_low", "parry_attack", "grab1", "grab2", "grab1_miss", "grab2_miss", "endattack1", "endattack2":
            return kind
    return ""


func _clear_ground_attack_input_history() -> void:
    _ground_attack_input_history.clear()
    _ground_attack_input_owner = ""


func _prune_ground_attack_input_history() -> void:
    if _ground_attack_input_history.is_empty():
        return
    var last_time: float = float(_ground_attack_input_history.back()["time"])
    if _time > last_time + GROUND_ATTACK_INPUT_PROTOTYPE_WINDOW_SECONDS:
        _clear_ground_attack_input_history()


func try_attack_to_floor_press(
        virtual_key: String
) -> AttackToFloorInputResult:
    # Prototype-only mapping for recovered b/c/d sequences. Native key status,
    # source-frame clocks, link order and deferred third-value timing remain unverified.
    if (state not in ["idle", "idle2", "startup", "active", "recovery"]
            or attack_config_path == BRICK_ATTACK_CONFIG_PATH
            or virtual_key not in ["b", "c", "d"]):
        _clear_ground_attack_input_history()
        return AttackToFloorInputResult.IGNORED
    if state in ["startup", "active", "recovery"]:
        # candobasicattacks links can select attacktofloor from a current
        # group member window; Heavy has no recovered window and stays closed.
        if (attack_kind == "heavy"
                or not CANDOBASICATTACK_WINDOWS.has(attack_kind)
                or not _candobasicattack_window_contains_current_frame()):
            _clear_ground_attack_input_history()
            return AttackToFloorInputResult.IGNORED
    if (not _candidate_clip_paths.has(ATTACK_TO_FLOOR_CLIP)
            or not _candidate_clip_paths.has(IDLE2_CLIP)):
        _clear_ground_attack_input_history()
        return AttackToFloorInputResult.IGNORED
    if opponent == null or not is_instance_valid(opponent) or opponent.current_source_pose() != "laying":
        _clear_ground_attack_input_history()
        return AttackToFloorInputResult.IGNORED
    _prune_ground_attack_input_history()
    var input_owner: String = (
        "attacktofloor:attack:" + attack_kind + ":" + str(attack_sequence)
        if state in ["startup", "active", "recovery"]
        else "attacktofloor:" + state
    )
    if _ground_attack_input_owner != input_owner:
        _clear_ground_attack_input_history()
        _ground_attack_input_owner = input_owner
    _ground_attack_input_history.append({"key": virtual_key, "time": _time})
    var match_state: AttackToFloorSequenceMatch = _specific_sequence_match_state(
        ATTACK_TO_FLOOR_SEQUENCES
    )
    if match_state == AttackToFloorSequenceMatch.COMPLETE:
        _begin_attack_to_floor()
        return AttackToFloorInputResult.STARTED
    if match_state == AttackToFloorSequenceMatch.PREFIX:
        return AttackToFloorInputResult.BUFFERED
    # A non-prefix input discards the whole chain. A leading b can begin a new
    # chain; c/d falls back to their ordinary input path.
    _clear_ground_attack_input_history()
    if virtual_key == "b":
        _ground_attack_input_owner = input_owner
        _ground_attack_input_history.append({"key": "b", "time": _time})
        return AttackToFloorInputResult.BUFFERED
    return AttackToFloorInputResult.IGNORED


func _specific_sequence_match_state(sequences: Array) -> AttackToFloorSequenceMatch:
    if _ground_attack_input_history.is_empty():
        return AttackToFloorSequenceMatch.NO_MATCH
    var observed: Array[String] = []
    for event_value: Variant in _ground_attack_input_history:
        if not event_value is Dictionary:
            return AttackToFloorSequenceMatch.NO_MATCH
        var event: Dictionary = event_value
        observed.append(String(event.get("key", "")))
    var has_prefix: bool = false
    for sequence_value: Variant in sequences:
        var sequence: Array = sequence_value
        if observed.size() > sequence.size():
            continue
        var matches_prefix: bool = true
        for index: int in range(observed.size()):
            if observed[index] != String(sequence[index]):
                matches_prefix = false
                break
        if not matches_prefix:
            continue
        if observed.size() == sequence.size():
            return AttackToFloorSequenceMatch.COMPLETE
        has_prefix = true
    if has_prefix:
        return AttackToFloorSequenceMatch.PREFIX
    return AttackToFloorSequenceMatch.NO_MATCH


func record_attack_to_floor_press(virtual_key: String) -> bool:
    return try_attack_to_floor_press(virtual_key) == AttackToFloorInputResult.STARTED


func _begin_attack_to_floor() -> void:
    var previous_state: String = state
    state = "attacktofloor"
    state_time = float(ATTACK_TO_FLOOR_ENTRY_FRAME) / SOURCE_FRAME_RATE
    attack_kind = "attacktofloor"
    attack_sequence += 1
    _attack_connected = false
    _clear_ground_attack_input_history()
    if (candidate_visual_blending_enabled
            and previous_state in ["idle", "idle2"]
            and _candidate_animation != null
            and _candidate_animation.is_playing()):
        _queue_candidate_visual_blend(
            float(CANDIDATE_ATTACK_TO_FLOOR_BLENDING_FRAMES) / SOURCE_FRAME_RATE
        )
    else:
        _restart_candidate_action()


func _try_attack_to_floor_contact() -> void:
    if (opponent == null or not is_instance_valid(opponent)
            or opponent.state in ["ko", "facedownko", "faceupko"]):
        return
    var dx: float = opponent.global_position.x - global_position.x
    var dz: float = opponent.global_position.z - global_position.z
    if Vector2(dx, dz).length() > attack_reach_world("attacktofloor", opponent) or dx * facing < -0.1:
        return
    var blocked: bool = opponent.guard_held and opponent._can_block_current_hit()
    var reaction: Dictionary = opponent.reaction_for_incoming(ATTACK_TO_FLOOR_IMPACT, blocked)
    if not opponent.receive_hit(
        ATTACK_TO_FLOOR_DAMAGE, blocked, 0.0, facing, reaction
    ):
        return
    _attack_connected = true
    _register_landed_hit(ATTACK_TO_FLOOR_DAMAGE, blocked)
    combat_hit.emit(self, opponent, "attacktofloor", ATTACK_TO_FLOOR_DAMAGE, blocked)


func _matches_ground_attack_sequence() -> bool:
    # InputSequenceCheck scans the event vector backwards and skips entries
    # that do not match the current required key. This is an ordered
    # subsequence check, not an equality check against the last three presses.
    for sequence_value: Variant in GROUND_ATTACK_SEQUENCES:
        var sequence: Array = sequence_value
        var required: int = sequence.size() - 1
        for event_index: int in range(_ground_attack_input_history.size() - 1, -1, -1):
            var event: Dictionary = _ground_attack_input_history[event_index]
            if String(event["key"]) != String(sequence[required]):
                continue
            required -= 1
            if required < 0:
                return true
    return false


func request_attack(kind: String) -> bool:
    if not _uses_standing_idle_rules() or guard_held or not ATTACKS.has(kind):
        return false
    attack_kind = kind
    attack_sequence += 1
    _attack_connected = false
    _attack_hit_landed = false
    _grab_connected = false
    _multi_impact_applied.clear()
    state = "startup"
    state_time = float(ATTACKS[kind]["startup"])
    return true

func _physics_process(delta: float) -> void:
    _time += delta
    if opponent != null and is_instance_valid(opponent):
        facing = 1.0 if opponent.global_position.x >= global_position.x else -1.0
    # Turn the torso toward the opponent (local 'front' is +X).
    rotation.y = 0.0 if facing > 0.0 else PI
    if guard_held:
        # Raising guard between two presses must not keep a partial sequence or
        # a matched-but-unexecuted combo alive.
        _clear_standing_combo_state()
    _advance_timed_states(delta)
    _try_begin_pending_standing_combo()
    if (state == "active" and ATTACKS.has(attack_kind)
            and not NON_CONTACT_ATTACKS.has(attack_kind)
            and Array(ATTACKS[attack_kind].get("multi_impacts", [])).is_empty()
            and not _attack_connected
            and not SPECIAL_CHAIN_MISSES.has(attack_kind)):
        _try_attack_contact()
    var motion: Vector3 = Vector3.ZERO
    if _uses_standing_idle_rules() and not guard_held:
        motion = Vector3(move_axis.x, 0.0, move_axis.y).normalized() * BASE_SPEED
    elif _uses_standing_idle_rules() and guard_held:
        motion = Vector3(move_axis.x, 0.0, move_axis.y).normalized() * BASE_SPEED * 0.25
    velocity.x = motion.x
    velocity.z = motion.z
    if is_on_floor():
        velocity.y = 0.0
    else:
        velocity.y -= 12.0 * delta
    move_and_slide()
    position.x = clampf(position.x, -6.8, 6.8)
    position.z = clampf(position.z, -3.0, 3.0)
    _animate_visuals()
    _animate_candidate()

func _advance_timed_states(delta: float) -> void:
    if state == "impactstun":
        _advance_impactstun_state(delta)
        return
    if state in ["stun", "stun2", "stunfall"]:
        _advance_stun_state(delta)
        return
    if state == "stunimpact":
        _advance_stun_impact_state(delta)
        return
    if state in [
        "idle2", "facedownidle", "facedownko", "facedowngetup",
        "impactfacedown", "facedownattack", "impacttofloor", "faceupidle",
        "faceupgetup", "faceupattack", "impactfaceup", "faceupko",
        "attacktofloor",
    ]:
        _advance_return_state(delta)
        return
    var remaining: float = delta
    while (remaining > 0.0
            and state in ["startup", "active", "recovery", "hitstun", "blockstun"]):
        if state == "active" and ATTACKS.has(attack_kind) and not NON_CONTACT_ATTACKS.has(attack_kind):
            if not Array(ATTACKS[attack_kind].get("multi_impacts", [])).is_empty():
                _try_multi_impact_contacts()
            elif (not _attack_connected
                    and not SPECIAL_CHAIN_MISSES.has(attack_kind)):
                _try_attack_contact()
        _try_special_chain()
        if remaining < state_time:
            state_time -= remaining
            return
        remaining -= maxf(state_time, 0.0)
        _advance_state()

func _try_multi_impact_contacts() -> void:
    var details: Dictionary = ATTACKS[attack_kind]
    var impacts: Array = details.get("multi_impacts", [])
    var frame: float = _current_attack_source_frame()
    for index: int in range(impacts.size()):
        if _multi_impact_applied.has(index):
            continue
        var impact: Dictionary = impacts[index]
        var timing: Array = impact["damage_time"]
        if frame + 0.0001 < float(timing[0]) or frame > float(timing[1]) + 0.0001:
            continue
        if opponent == null or not is_instance_valid(opponent):
            return
        var dx: float = opponent.global_position.x - global_position.x
        var dz: float = opponent.global_position.z - global_position.z
        var distance: float = Vector2(dx, dz).length()
        var reach: float = (float(impact["attack_radius"]) * radius_scale
                + opponent.source_radius_for_current_animation()) * source_units_to_world
        if distance > reach or dx * facing < -0.1:
            continue
        var blocked: bool = opponent.guard_held and (
            opponent._can_block_current_hit() or opponent.state == "blockstun")
        var reaction: Dictionary = opponent.reaction_for_incoming(impact, blocked)
        var damage: float = float(impact["damage"])
        _multi_impact_applied.append(index)
        if not opponent.receive_hit(damage, blocked, 0.0, facing, reaction):
            continue
        _attack_connected = true
        _register_landed_hit(damage, blocked)
        combat_hit.emit(self, opponent, attack_kind, damage, blocked)


func _try_special_chain() -> void:
    if attack_kind == "parry_high":
        var parry_frame: float = _current_attack_source_frame()
        if parry_frame + 0.0001 < 9.0 or parry_frame > 10.0001:
            return
        if (opponent == null or not is_instance_valid(opponent)
                or opponent.state not in ["startup", "active"]):
            return
        var distance: float = Vector2(
            opponent.global_position.x - global_position.x,
            opponent.global_position.z - global_position.z).length()
        var reach: float = opponent.attack_reach_world(opponent.attack_kind, self)
        if reach <= 0.0 or distance > reach:
            return
        _begin_chained_attack("parry_attack")
        return
    if not SPECIAL_CHAIN_MISSES.has(attack_kind):
        return
    var window: Array = SPECIAL_CHAIN_WINDOW[attack_kind]
    var frame: float = _current_attack_source_frame()
    if frame + 0.0001 < float(window[0]) or frame > float(window[1]) + 0.0001:
        return
    if (opponent == null or not is_instance_valid(opponent)
            or opponent.guard_held
            or opponent.state not in ["idle", "idle2"]):
        return
    var distance: float = Vector2(
        opponent.global_position.x - global_position.x,
        opponent.global_position.z - global_position.z).length()
    if distance > PROTOTYPE_GRAB_DISTANCE:
        return
    _begin_chained_attack(String(SPECIAL_CHAIN_MISSES[attack_kind]))


func _begin_chained_attack(kind: String) -> void:
    attack_kind = kind
    attack_sequence += 1
    _attack_connected = false
    _attack_hit_landed = false
    _grab_connected = false
    state = "startup"
    state_time = float(ATTACKS[kind]["startup"])
    _restart_candidate_action()


func _advance_state() -> void:
    match state:
        "startup":
            state = "active"
            state_time = float(ATTACKS[attack_kind]["active"])
        "active":
            state = "recovery"
            state_time = float(ATTACKS[attack_kind]["recovery"])
        "recovery", "hitstun", "blockstun":
            var next_state: String = "idle"
            if state != "recovery":
                next_state = _verified_post_hit_return_state()
            _enter_locomotion_state(next_state)


func _try_facedown_attack_contact() -> void:
    if (opponent == null or not is_instance_valid(opponent)
            or opponent.state in [
                "ko", "facedownko", "faceupidle", "faceupgetup", "faceupattack",
                "impactfaceup", "faceupko",
            ]):
        return
    var dx: float = opponent.global_position.x - global_position.x
    var dz: float = opponent.global_position.z - global_position.z
    var distance: float = Vector2(dx, dz).length()
    if distance > attack_reach_world("facedownattack", opponent):
        return
    if dx * facing < -0.1:
        return
    var blocked: bool = opponent.guard_held and opponent._can_block_current_hit()
    var reaction: Dictionary = opponent.reaction_for_incoming(
        FACEDOWN_ATTACK_IMPACT, blocked
    )
    _attack_connected = true
    if not opponent.receive_hit(
        FACEDOWN_ATTACK_DAMAGE, blocked, 0.0, facing, reaction
    ):
        return
    _register_landed_hit(FACEDOWN_ATTACK_DAMAGE, blocked)
    combat_hit.emit(
        self, opponent, "facedownattack", FACEDOWN_ATTACK_DAMAGE, blocked
    )


func _try_faceup_attack_contact() -> void:
    if (opponent == null or not is_instance_valid(opponent)
            or opponent.state in [
                "ko", "facedownko", "faceupidle", "faceupgetup", "faceupattack",
                "impactfaceup", "faceupko",
            ]):
        return
    var dx: float = opponent.global_position.x - global_position.x
    var dz: float = opponent.global_position.z - global_position.z
    var distance: float = Vector2(dx, dz).length()
    if distance > attack_reach_world("faceupattack", opponent):
        return
    if dx * facing < -0.1:
        return
    var blocked: bool = opponent.guard_held and opponent._can_block_current_hit()
    var reaction: Dictionary = opponent.reaction_for_incoming(
        FACEUP_ATTACK_IMPACT, blocked
    )
    if opponent._accepts_brick_faceup_candidate(FACEUP_ATTACK_DAMAGE, blocked):
        reaction = BRICK_FRONT_LOW_REACTION.duplicate(true)
    _attack_connected = true
    if not opponent.receive_hit(
        FACEUP_ATTACK_DAMAGE, blocked, 0.0, facing, reaction
    ):
        return
    _register_landed_hit(FACEUP_ATTACK_DAMAGE, blocked)
    combat_hit.emit(
        self, opponent, "faceupattack", FACEUP_ATTACK_DAMAGE, blocked
    )


func _register_landed_hit(damage: float, blocked: bool) -> void:
    combo_hits += 1
    if damage > 0.0 and not blocked:
        _attack_hit_landed = true
        if GRAB_ATTACKS.has(attack_kind):
            _grab_connected = true
        rage = minf(RAGE_MAX, rage + RAGE_GAIN_PER_HIT)


func _try_attack_contact() -> void:
    if (opponent == null or not is_instance_valid(opponent)
            or opponent.state in ["ko", "facedownko"]):
        return
    var details: Dictionary = ATTACKS[attack_kind]
    var dx: float = opponent.global_position.x - global_position.x
    var dz: float = opponent.global_position.z - global_position.z
    var distance: float = Vector2(dx, dz).length()
    if distance > attack_reach_world(attack_kind, opponent):
        return
    if dx * facing < -0.1:
        return
    var damage: float = float(details["damage"])
    var blocked: bool = opponent.guard_held and opponent._can_block_current_hit()
    var reaction: Dictionary = {}
    if details.has("source_impact"):
        reaction = opponent.reaction_for_incoming(details["source_impact"], blocked)
    var impact_height: String = ""
    if details.has("source_impact"):
        impact_height = String(details["source_impact"].get("height", ""))
    var accepts_impact_to_floor: bool = opponent._accepts_impact_to_floor(
        impact_height, blocked, damage
    )
    var accepts_faceup_impact: bool = opponent._accepts_faceup_low_impact(
        impact_height, blocked, damage
    )
    var accepts_faceup_ko: bool = opponent._accepts_faceup_ko(damage, blocked)
    if (opponent.state in [
                "faceupidle", "faceupgetup", "faceupattack",
                "impactfaceup", "faceupko",
            ]
            and not accepts_impact_to_floor
            and not accepts_faceup_impact
            and not accepts_faceup_ko):
        return
    # Mark contact before emitting signals, including a guarded hit.
    var accepted: bool = true
    # Ground states only accept the verified low-impact paths. Other hits keep
    # their existing reaction path, except the face-up states protected above.
    if accepts_faceup_ko:
        opponent._begin_faceup_ko(damage)
    elif accepts_impact_to_floor:
        opponent.begin_impact_to_floor(damage)
    elif accepts_faceup_impact:
        opponent.begin_faceup_impact(damage)
    elif opponent._accepts_facedown_low_impact(impact_height, blocked, damage):
        opponent.begin_facedown_impact(damage)
    else:
        accepted = opponent.receive_hit(
            damage, blocked, float(details["push"]), facing, reaction
        )
    if not accepted:
        return
    _attack_connected = true
    _register_landed_hit(damage, blocked)
    combat_hit.emit(self, opponent, attack_kind, damage, blocked)


func current_source_animation() -> String:
    if (state in ["hitstun", "blockstun"]
            and not last_reaction_animation.is_empty()):
        return last_reaction_animation
    if (state in ["startup", "active", "recovery"]
            and attack_kind != "heavy" and ATTACKS.has(attack_kind)):
        return String(ATTACKS[attack_kind]["animation"])
    if state in ["startup", "active", "recovery"] and attack_kind == "heavy":
        return CANDIDATE_CLIPS["kick"]
    if state == "idle2":
        return IDLE2_CLIP
    if state == "facedownidle" or state == "facedownko":
        return _facedown_idle_clip()
    if state == "facedowngetup":
        return FACEDOWN_GETUP_CLIP
    if state == "impactfacedown":
        return FACEDOWN_IMPACT_CLIP
    if state == "facedownattack":
        return FACEDOWN_ATTACK_CLIP
    if state == "impacttofloor":
        return FACEUP_IMPACT_TO_FLOOR_CLIP
    if state == "impactfaceup":
        return FACEUP_IMPACT_CLIP
    if state == "faceupko":
        return FACEUP_IDLE_CLIP
    if state == "faceupidle":
        return FACEUP_IDLE_CLIP
    if state == "faceupgetup":
        return FACEUP_GETUP_CLIP
    if state == "faceupattack":
        return FACEUP_ATTACK_CLIP
    if state == "attacktofloor":
        return ATTACK_TO_FLOOR_CLIP
    return _owner_idle_animation()


func current_source_pose() -> String:
    if not candidate_loaded or not SOURCE_ACTION_POSES.has(state):
        return ""
    # Only these actions currently have Brick-specific candidate mappings.
    if (attack_config_path == BRICK_ATTACK_CONFIG_PATH
            and state not in ["idle", "facedownidle", "impactfacedown"]):
        return ""
    var animation: String = current_source_animation()
    # A logical state that lacks its validated visual clip must not report a
    # source pose. This keeps downstream checks fail-closed.
    var clip_key: String = "idle" if state == "idle" else animation
    if not _candidate_clip_paths.has(clip_key):
        return ""
    return String(SOURCE_ACTION_POSES[state])


func _owner_idle_animation() -> String:
    if candidate_clips.has("idle"):
        return String(candidate_clips["idle"])
    return String(CANDIDATE_CLIPS["idle"])


func _facedown_idle_clip() -> String:
    if attack_config_path == BRICK_ATTACK_CONFIG_PATH:
        return BRICK_FACEDOWN_IDLE_CLIP
    return FACEDOWN_IDLE_CLIP


func _stored_animation_radius(animation: String) -> float:
    if (attack_config_path == BRICK_ATTACK_CONFIG_PATH
            and animation == FACEDOWN_IMPACT_CLIP):
        # thai.set action 92 uses radius 85. The Bruce set uses 80 for the
        # same animation, so this value is character-config specific.
        return BRICK_FACEDOWN_IMPACT_RADIUS
    if source_animation_radii.has(animation) and _is_number(source_animation_radii[animation]):
        return float(source_animation_radii[animation])
    if RETURN_ANIMATION_RADII.has(animation) and _is_number(RETURN_ANIMATION_RADII[animation]):
        return float(RETURN_ANIMATION_RADII[animation])
    var profile: Dictionary = _profile_for_animation(animation)
    if profile.has("animation_radius") and _is_number(profile["animation_radius"]):
        return float(profile["animation_radius"])
    return -1.0


func _profile_for_animation(animation: String) -> Dictionary:
    if (attack_config_path == BRICK_ATTACK_CONFIG_PATH
            and animation == BRICK_FRONT_LOW_CLIP):
        return BRICK_FRONT_LOW_REACTION
    for group_value: Variant in [REACTION_PROFILES, EXACT_REACTIONS]:
        if not group_value is Dictionary:
            continue
        var groups: Dictionary = group_value
        for entries: Variant in groups.values():
            if entries is Dictionary:
                var profiles: Dictionary = entries
                for profile_value: Variant in profiles.values():
                    if (profile_value is Dictionary
                            and String(profile_value.get("animation", "")) == animation):
                        return profile_value
            elif entries is Array:
                for profile_value: Variant in entries:
                    if (profile_value is Dictionary
                            and String(profile_value.get("animation", "")) == animation):
                        return profile_value
    return {}


func source_radius_for_current_animation() -> float:
    if state == "facedownko":
        return FACEDOWN_KO_RADIUS * radius_scale
    if state == "faceupko":
        return FACEUP_KO_RADIUS * radius_scale
    var animation: String = current_source_animation()
    var radius: float = _stored_animation_radius(animation)
    if radius < 0.0:
        radius = _stored_animation_radius(_owner_idle_animation())
    if radius < 0.0:
        return 0.0
    return radius * radius_scale


func attack_reach_world(kind: String, target: PortFighter = null) -> float:
    if kind == "facedownattack":
        var facedown_source_reach: float = FACEDOWN_ATTACK_RADIUS * radius_scale
        if target != null:
            facedown_source_reach += target.source_radius_for_current_animation()
        return facedown_source_reach * source_units_to_world
    if kind == "attacktofloor":
        var source_reach: float = ATTACK_TO_FLOOR_RADIUS * radius_scale
        if target != null:
            source_reach += target.source_radius_for_current_animation()
        return source_reach * source_units_to_world
    if kind == "faceupattack":
        var faceup_source_reach: float = FACEUP_ATTACK_RADIUS * radius_scale
        if target != null:
            faceup_source_reach += target.source_radius_for_current_animation()
        return faceup_source_reach * source_units_to_world
    if not ATTACKS.has(kind):
        return 0.0
    var details: Dictionary = ATTACKS[kind]
    if not details.has("source_impact"):
        return float(details.get("range", 0.0))
    var impact: Dictionary = details["source_impact"]
    var source_reach: float = float(impact["attack_radius"]) * radius_scale
    if target != null:
        source_reach += target.source_radius_for_current_animation()
    return source_reach * source_units_to_world


func reaction_for_incoming(impact: Dictionary, blocked: bool) -> Dictionary:
    if _is_brick_facedown_low_impact(impact, blocked):
        return BRICK_FACEDOWN_IMPACT_REACTION.duplicate(true)
    var exact: Dictionary = _matching_exact_reaction(impact, blocked)
    if not exact.is_empty():
        return exact
    if (not blocked and String(impact.get("strength", "")) == "brutal"
            and state in ["stun", "stun2"]):
        # brucelee.set link 134: impactsfromstun + brutal -> stunbrutalimpact,
        # all_impct_spectacular_lft, then link 133 [40,45] -> facedownko.
        return {
            "source_action": "stunbrutalimpact",
            "animation": "stun_brutal",
            "exit_start_frame": 40,
            "animation_duration_frames": 45,
            "linking_frame": 0,
        }
    # Hard and brutal attacks have no light-height fallback when the exact link is absent.
    if String(impact.get("strength", "")) != "normal":
        return {}
    return _reaction_profile_for_impact(impact, blocked)


func _is_brick_facedown_low_impact(impact: Dictionary, blocked: bool) -> bool:
    return (
        attack_config_path == BRICK_ATTACK_CONFIG_PATH
        and state == "facedownidle"
        and not blocked
        and String(impact.get("height", "")) == "low"
    )


func _is_brick_facedown_impact_reaction(reaction: Dictionary) -> bool:
    return (
        attack_config_path == BRICK_ATTACK_CONFIG_PATH
        and String(reaction.get("source_action", "")) == "impactfacedown"
        and String(reaction.get("animation", "")) == FACEDOWN_IMPACT_CLIP
    )


func _accepts_brick_faceup_candidate(damage: float, blocked: bool) -> bool:
    # The mapped Thai idle, movefwd, lowpunch3 and lowkick3 have impactable
    # windows covering their complete source clips. This gates logical states
    # only; it does not reproduce native TimeWindowCheck or sample GLB time.
    var mapped_state: bool = false
    if state == "idle":
        var moving: bool = absf(move_axis.x) > 0.001 or absf(move_axis.y) > 0.001
        mapped_state = _candidate_clip_paths.has("move" if moving else "idle")
    if state in ["startup", "active", "recovery"]:
        mapped_state = (attack_kind in ["punch", "kick"] and ATTACKS.has(attack_kind)
            and _candidate_clip_paths.has(attack_kind))
    return (
        attack_config_path == BRICK_ATTACK_CONFIG_PATH
        and candidate_loaded
        and mapped_state
        and not blocked
        and health - damage > 0.0
        and _candidate_clip_paths.has(BRICK_FRONT_LOW_CLIP)
        and _candidate_clip_paths.has(BRICK_FACEDOWN_IDLE_CLIP)
    )


func _matching_exact_reaction(impact: Dictionary, blocked: bool) -> Dictionary:
    var group: String = "block" if blocked else "hit"
    var entries_value: Variant = EXACT_REACTIONS.get(group, [])
    if not entries_value is Array:
        return {}
    var strength: String = String(impact.get("strength", ""))
    var height: String = String(impact.get("height", ""))
    var direction: String = String(impact.get("direction", ""))
    var strength_only: Dictionary = {}
    for entry_value: Variant in entries_value:
        if not entry_value is Dictionary:
            continue
        var entry: Dictionary = entry_value
        if String(entry.get("strength", "")) != strength:
            continue
        var entry_height: String = String(entry.get("height", ""))
        var entry_direction: String = String(entry.get("direction", ""))
        if entry_height == height and entry_direction == direction:
            return entry.duplicate(true)
        if (blocked
                and entry_height.is_empty()
                and entry_direction.is_empty()
                and strength_only.is_empty()):
            strength_only = entry
    if not strength_only.is_empty():
        return strength_only.duplicate(true)
    return {}


func _reaction_profile_for_impact(
        impact: Dictionary,
        blocked: bool
) -> Dictionary:
    var group: String = "block" if blocked else "hit"
    var height: String = String(impact.get("height", ""))
    if not REACTION_PROFILES.has(group):
        return {}
    var profiles: Dictionary = REACTION_PROFILES[group]
    if not profiles.has(height):
        return {}
    return profiles[height]


# Verified subset of brucelee.set impactable membership for the medium-lethal
# candidate. Unknown actions remain on their existing KO path.
func _medium_lethal_impactable() -> bool:
    if attack_config_path != ATTACK_CONFIG_PATH:
        return false
    if state == "idle":
        # PC idle uses Default.set's m01_idle_01 as a standing approximation;
        # brucelee.set's idle is impactable for [0,140].
        return true
    if state == "idle2":
        return state_time * SOURCE_FRAME_RATE <= 43.0001
    if state == "facedowngetup":
        var frame: float = state_time * SOURCE_FRAME_RATE
        return frame + 0.0001 >= 12.0 and frame <= 19.0001
    if state == "facedownattack":
        var frame: float = state_time * SOURCE_FRAME_RATE
        return frame + 0.0001 >= 29.0 and frame <= 35.0001
    if state == "hitstun":
        var hit_windows: Dictionary = {
            "impactlightfronthigh": 17, "impactlightfrontlow": 17,
            "impactlightfrontmid": 16, "impacthardfrontmid": 30,
            "impactlightrighthigh": 17, "impactlightlefthigh": 17,
            "impactlightrightlow": 17, "impactlightleftlow": 17,
        }
        if hit_windows.has(last_reaction_source_action) and last_reaction_exit_frame >= 0:
            var frame: float = float(last_reaction_exit_frame) - state_time * SOURCE_FRAME_RATE
            return frame >= -0.0001 and frame <= float(hit_windows[last_reaction_source_action]) + 0.0001
        return false
    if state == "attacktofloor":
        return state_time * SOURCE_FRAME_RATE <= 90.0001
    if state in ["startup", "active", "recovery"]:
        var windows: Dictionary = {
            "punch": [0, 69], "kick": [0, 86],
            "high_punch": [0, 101], "high_punch2": [0, 81],
            "high_punch3": [0, 85], "low_punch2": [0, 65],
            "low_punch3": [0, 81], "high_kick": [0, 73],
            "high_kick2": [0, 95], "high_kick3": [17, 51],
            "low_kick2": [0, 27], "low_kick3": [0, 56],
            "parry_high": [30, 62], "parry_low": [17, 27],
            "parry_attack": [15, 85], "grab1_miss": [0, 47],
            "grab2_miss": [0, 14], "special_kick_high": [17, 57],
            "special_kick_low_miss": [24, 50],
            "special_punch_low_miss": [16, 33],
            "special_punch_high_miss": [0, 122], "endattack2": [0, 235],
        }
        if windows.has(attack_kind):
            var bounds: Array = windows[attack_kind]
            var frame: float = _current_attack_source_frame()
            return frame + 0.0001 >= float(bounds[0]) and frame <= float(bounds[1]) + 0.0001
    return false


func receive_hit(
        amount: float,
        blocked: bool,
        push: float,
        direction: float,
        reaction: Dictionary = {}
) -> bool:
    _parry_press_times.clear()
    # faceupgetup and faceupattack still keep unverified incoming hits
    # out of the standing hitstun/blockstun/KO paths until those links have
    # their own evidence-backed transitions.
    if state in ["stun", "stun2"] and not blocked:
        var stun_source: String = String(reaction.get("source_action", ""))
        var stun_animation: String
        var stun_exit_frame: int
        var stun_next_state: String = "stunfall"
        if stun_source == "impactlightfronthigh":
            stun_animation = "all_impct_light_frnt_high"
            stun_exit_frame = 13
        elif stun_source == "impactlightfrontlow":
            stun_animation = "all_impct_light_frnt_low"
            stun_exit_frame = 13
        elif stun_source == "impactlightfrontmid":
            stun_animation = "all_impct_crotch"
            # Source link 131 allows [15,20]; choose 15 for this PC candidate.
            stun_exit_frame = 15
        elif stun_source.begins_with("impacthard"):
            stun_animation = "stun_hard"
            stun_exit_frame = 20
            stun_next_state = "faceupko"
        elif stun_source == "stunbrutalimpact":
            stun_animation = "stun_brutal"
            stun_exit_frame = 40
            stun_next_state = "facedownko"
        else:
            return false
        if not _candidate_clip_paths.has(stun_animation):
            return false
        health = maxf(0.0, health - amount)
        state = "stunimpact"
        state_time = float(stun_exit_frame) / SOURCE_FRAME_RATE
        combo_hits = 0
        last_reaction_group = "hit"
        last_reaction_source_action = "stunimpact"
        last_reaction_animation = stun_animation
        last_reaction_exit_frame = stun_exit_frame
        last_reaction_clip_implemented = true
        _stun_impact_next_state = stun_next_state
        return true
    if state in [
        "ko", "facedownko", "faceupidle", "faceupgetup", "faceupattack",
        "impactfaceup", "faceupko", "stun", "stun2", "stunfall", "stunimpact", "impactstun",
    ]:
        return false
    var state_before: String = state
    var medium_lethal_eligible: bool = _medium_lethal_impactable()
    var reaction_root_source: float = float(
        REACTION_ROOT_PUSH_SOURCE.get(String(reaction.get("source_action", "")), -1.0)
    )
    if reaction_root_source >= 0.0:
        # Source reaction positions are (X horizontal, Y depth, Z up). Their
        # depth component is the current best evidence for forward displacement;
        # the exact native push mapping remains unverified.
        push = reaction_root_source * source_units_to_world
    var brick_facedown_impact: bool = (
        state_before == "facedownidle"
        and not blocked
        and _is_brick_facedown_impact_reaction(reaction)
    )
    # thai.set has no defensible generic fallback for a nonlethal low hit while
    # Brick is lying. Keep that state fail closed if the reaction clip is not
    # loaded. Lethal links are handled by the higher-priority healthzero edge.
    if (brick_facedown_impact
            and health - amount > 0.0
            and not _candidate_clip_paths.has(FACEDOWN_IMPACT_CLIP)):
        return false
    var position_before: float = position.x
    _attack_connected = false
    # Being hit cancels a sequence that matched during the interrupted attack.
    _clear_standing_combo_state()
    if blocked:
        health = maxf(0.0, health - amount * 0.12)
        state = "blockstun"
        state_time = 0.14
    else:
        health = maxf(0.0, health - amount)
        state = "hitstun"
        state_time = 0.30
        combo_hits = 0
    last_reaction_group = "block" if blocked else "hit"
    if (reaction.has("exit_start_frame")
            and reaction.has("source_action")
            and reaction.has("animation")):
        last_reaction_source_action = String(reaction["source_action"])
        last_reaction_animation = String(reaction["animation"])
        last_reaction_exit_frame = int(reaction["exit_start_frame"])
        var configured_clip: bool = reaction.get("clip_implemented", true) == true
        var prepared_clip: bool = _candidate_clip_paths.has(last_reaction_animation)
        last_reaction_clip_implemented = configured_clip or prepared_clip
        state_time = float(last_reaction_exit_frame) / SOURCE_FRAME_RATE
    else:
        last_reaction_source_action = ""
        last_reaction_animation = ""
        last_reaction_exit_frame = -1
        last_reaction_clip_implemented = false
    position.x = clampf(position.x + direction * push * (0.30 if blocked else 1.0), -6.8, 6.8)
    var stun_entry_source: String = String(reaction.get("source_action", ""))
    var stun_entry_clip: String = (
        "all_impct_light_frnt_low"
        if stun_entry_source in ["impactlightfrontlow", "impactlightfrontmid"]
        else "all_impct_light_frnt_high"
    )
    if (health <= 0.0 and not blocked
            and _candidate_clip_paths.has("stun")
            and _candidate_clip_paths.has(stun_entry_clip)
            and (stun_entry_source in ["impactlightfronthigh", "impactlightfrontlow"]
                or (stun_entry_source == "impactlightfrontmid" and medium_lethal_eligible))):
        # Source impactstun high/low links land at [14,17] before stun; this
        # prototype plays the matching impact reaction for 14 frames first.
        state = "impactstun"
        state_time = float(STUN_IMPACT_ENTRY_FRAMES) / SOURCE_FRAME_RATE
        combo_hits = 0
        last_reaction_group = "hit"
        last_reaction_source_action = "impactstun"
        last_reaction_animation = stun_entry_clip
        last_reaction_exit_frame = STUN_IMPACT_ENTRY_FRAMES
        last_reaction_clip_implemented = true
        return true
    if (health <= 0.0 and state_before == "facedownidle"
            and _candidate_clip_paths.has(_facedown_idle_clip())):
        # brucelee.set lists healthzero before the low-impact link. Do not play
        # impactfacedown or apply the standing prototype push.
        position.x = position_before
        _begin_facedown_ko()
    elif brick_facedown_impact:
        # Thai link 88 selects impactfacedown directly. It has no damageable
        # source group, so the transition must happen in the same hit update.
        position.x = position_before
        state = "impactfacedown"
        state_time = 0.0
        combo_hits = 0
        if (candidate_visual_blending_enabled
                and _candidate_action == BRICK_FACEDOWN_IDLE_CLIP
                and _candidate_animation != null
                and _candidate_animation.is_playing()):
            _queue_candidate_visual_blend(
                float(CANDIDATE_BRICK_FACEDOWN_IMPACT_BLENDING_FRAMES)
                        / SOURCE_FRAME_RATE
            )
        else:
            _restart_candidate_action()
    elif health <= 0.0:
        state = "ko"
        combat_ko.emit(self)
    elif _candidate_animation != null and _candidate_clip_paths.has(last_reaction_animation):
        # A second hit of the same type must start the reaction again.
        _candidate_animation.stop()
        _candidate_action = ""
        candidate_visual_blend_pending_seconds = 0.0
    return true


func reset_fighter(start_position: Vector3) -> void:
    global_position = start_position
    velocity = Vector3.ZERO
    move_axis = Vector2.ZERO
    health = MAX_HEALTH
    state = "idle"
    state_time = 0.0
    attack_kind = ""
    _attack_connected = false
    _clear_ground_attack_input_history()
    _clear_standing_combo_state()
    last_reaction_group = ""
    last_reaction_source_action = ""
    last_reaction_animation = ""
    last_reaction_exit_frame = -1
    last_reaction_clip_implemented = false
    guard_held = false
    combo_hits = 0
    rage = 0.0
    _attack_hit_landed = false
    _grab_connected = false
    _multi_impact_applied.clear()
    _parry_press_times.clear()
    if candidate_loaded:
        if _candidate_character != null:
            _candidate_character.position = _candidate_character_rest_position
        if _candidate_animation != null:
            _candidate_animation.stop()
        _candidate_action = ""
        candidate_visual_blend_pending_seconds = 0.0
        candidate_visual_blend_seconds_last = 0.0
        candidate_visual_blend_source_action_last = ""
        candidate_visual_blend_target_action_last = ""
        candidate_animation_clip = ""
        _animate_candidate()

func _animate_visuals() -> void:
    if candidate_loaded:
        return
    if _body == null:
        return
    var bounce: float = 0.035 * sin(_time * 8.0)
    _body.position.y = bounce
    _right_arm.rotation.z = 0.0
    _left_arm.rotation.z = 0.0
    if state in ["startup", "active"]:
        _right_arm.rotation.z = 1.05 if attack_kind == "punch" else 0.45
    elif guard_held and _uses_standing_idle_rules():
        _right_arm.rotation.z = 0.90
        _left_arm.rotation.z = -0.90
    elif state == "hitstun":
        _right_arm.rotation.z = -0.50
        _left_arm.rotation.z = 0.50
    if state == "ko":
        _body.rotation.z = 1.1
    else:
        _body.rotation.z = 0.0


func _animate_candidate() -> void:
    if not candidate_loaded:
        return
    _candidate_root.global_position.y = (
        CANDIDATE_FLOOR_Y
        - _candidate_source_min_y * _candidate_visual_scale
    )
    var requested: String = "idle"
    var start_frame: int = 0
    if state in ["startup", "active", "recovery"]:
        if attack_kind == "punch":
            requested = "punch"
        elif attack_kind in ["kick", "heavy"]:
            requested = "kick"
        elif attack_kind in ["high_punch", "high_kick", "high_punch3", "low_punch3",
                "low_kick3", "high_kick3", "special_kick_high",
                "high_punch2", "low_punch2", "high_kick2", "low_kick2",
                "special_kick_low_miss", "special_kick_low_hit",
                "special_punch_low_miss", "special_punch_low_hit",
                "special_punch_high_miss", "special_punch_high_hit",
                "parry_high", "parry_low", "parry_attack", "grab1", "grab2", "grab1_miss", "grab2_miss",
                "endattack1", "endattack2"]:
            requested = attack_kind
    elif state in ["stun", "stun2"] and _candidate_clip_paths.has("stun"):
        requested = "stun"
    elif state == "stunfall" and _candidate_clip_paths.has("stun_fall"):
        requested = "stun_fall"
    elif (state in ["hitstun", "blockstun", "stunimpact", "impactstun"]
            and last_reaction_clip_implemented
            and _candidate_clip_paths.has(last_reaction_animation)):
        requested = last_reaction_animation
        if _candidate_action != requested and _candidate_character != null:
            _candidate_character.position = _candidate_character_rest_position
    elif state == "ko" and _candidate_clip_paths.has("ko"):
        requested = "ko"
    elif state == "idle2" and _candidate_clip_paths.has(IDLE2_CLIP):
        requested = IDLE2_CLIP
    elif state in ["facedownidle", "facedownko"] and _candidate_clip_paths.has(_facedown_idle_clip()):
        requested = _facedown_idle_clip()
    elif state == "facedowngetup" and _candidate_clip_paths.has(FACEDOWN_GETUP_CLIP):
        requested = FACEDOWN_GETUP_CLIP
    elif state == "impactfacedown" and _candidate_clip_paths.has(FACEDOWN_IMPACT_CLIP):
        requested = FACEDOWN_IMPACT_CLIP
        if _candidate_action != requested and _candidate_character != null:
            _candidate_character.position = _candidate_character_rest_position
    elif state == "facedownattack" and _candidate_clip_paths.has(FACEDOWN_ATTACK_CLIP):
        requested = FACEDOWN_ATTACK_CLIP
        if _candidate_action != requested and _candidate_character != null:
            _candidate_character.position = _candidate_character_rest_position
    elif state == "impacttofloor" and _candidate_clip_paths.has(FACEUP_IMPACT_TO_FLOOR_CLIP):
        requested = FACEUP_IMPACT_TO_FLOOR_CLIP
        if _candidate_action != requested and _candidate_character != null:
            _candidate_character.position = _candidate_character_rest_position
    elif state == "impactfaceup" and _candidate_clip_paths.has(FACEUP_IMPACT_CLIP):
        requested = FACEUP_IMPACT_CLIP
        if _candidate_action != requested and _candidate_character != null:
            _candidate_character.position = _candidate_character_rest_position
    elif state == "faceupko" and _candidate_clip_paths.has(FACEUP_IDLE_CLIP):
        requested = FACEUP_IDLE_CLIP
    elif state == "faceupidle" and _candidate_clip_paths.has(FACEUP_IDLE_CLIP):
        requested = FACEUP_IDLE_CLIP
    elif state == "faceupgetup" and _candidate_clip_paths.has(FACEUP_GETUP_CLIP):
        requested = FACEUP_GETUP_CLIP
    elif state == "faceupattack" and _candidate_clip_paths.has(FACEUP_ATTACK_CLIP):
        requested = FACEUP_ATTACK_CLIP
        if _candidate_action != requested and _candidate_character != null:
            _candidate_character.position = _candidate_character_rest_position
    elif state == "attacktofloor" and _candidate_clip_paths.has(ATTACK_TO_FLOOR_CLIP):
        requested = ATTACK_TO_FLOOR_CLIP
        start_frame = ATTACK_TO_FLOOR_ENTRY_FRAME
        if _candidate_action != requested and _candidate_character != null:
            _candidate_character.position = _candidate_character_rest_position
    elif state == "idle" and _candidate_clip_paths.has("move") and (
            absf(move_axis.x) > 0.001 or absf(move_axis.y) > 0.001
    ):
        requested = "move"
    if requested == FACEUP_IMPACT_TO_FLOOR_CLIP:
        start_frame = int(state_time * SOURCE_FRAME_RATE + 0.0001)
    _play_candidate_action(requested, start_frame)

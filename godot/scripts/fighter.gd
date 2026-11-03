extends CharacterBody3D
class_name PortFighter
## Original clean-room placeholder implementation. Not extracted Android game code.

signal combat_hit(attacker: PortFighter, defender: PortFighter, action: String, damage: float, blocked: bool)
signal combat_ko(fighter: PortFighter)
signal attack_started(action: String)
signal parry_succeeded(action: String)

const BASE_SPEED: float = 3.6
const MAX_HEALTH: float = 100.0
const CANDIDATE_SOURCE_MIN_Y: float = -0.09393310546875
const CANDIDATE_SOURCE_HEIGHT: float = 173.415954589844
const PC_TARGET_CHARACTER_HEIGHT: float = 1.8
const CANDIDATE_HEIGHT: float = PC_TARGET_CHARACTER_HEIGHT
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
    "grabbed1": "all_grabbed_01_forset03",
    "grabbed2": "all_grabbed_02_forset03",
    "endattackcomp1": "all_end_attack_01_forset03",
    "endattackcomp2": "all_end_attack_02_forset03",
    "endattack1": "m01_end_attack_01",
    "endattack2": "m01_end_attack_02",
    "stun": "all_stunned",
    "stun_fall": "all_stunned_fall",
    "stun_hard": "all_impct_hard_frnt_high",
    "stun_brutal": "all_impct_spectacular_lft",
    "move": "m01_movelft",
    "movefwd": "m02_movefwd",
    "moveback": "m01_movebck",
    "moveleft": "m01_moverht",
    "moveright": "m01_movelft",
    "stepfwd": "m01_stepfwd",
    "stepback": "m01_stepbck",
    "stepleft": "m01_steplft",
    "stepright": "m01_steprht",
}
const BRICK_CLIPS: Dictionary = {
    "idle": "m03_idle_01",
    "punch": "m03_pnch_low_01",
    "kick": "m03_kck_low_01",
    "high_punch": "m03_pnch_high_01",
    "high_punch2": "m03_pnch_high_02",
    "high_punch3": "m03_pnch_high_03",
    "low_punch": "m03_pnch_low_03",
    "low_punch2": "m03_pnch_low_02",
    "low_punch3": "m03_pnch_low_01",
    "high_kick": "m03_kck_high_01",
    "high_kick2": "m03_kck_high_02",
    "high_kick3": "m03_kck_high_03",
    "low_kick": "m03_kck_low_02",
    "low_kick2": "m03_kck_low_03",
    "low_kick3": "m03_kck_low_01",
    "special_kick_high_brick": "m03_sp_kck_high",
    "special_kick_low_brick": "m03_sp_kck_low",
    "special_punch_high_brick": "m03_sp_pnch_high",
    "special_punch_low_brick": "m03_sp_pnch_low",
    "parry_high_brick": "m03_parry_high",
    "parry_low_brick": "m03_parry_low",
    "parry_attack_brick": "m03_pnch_high_03",
    "grab1_brick": "m03_grab_01",
    "grab2_brick": "m03_grab_02",
    "attack_to_floor_brick": "m03_attack_to_floor",
    "endattack_brick": "m03_end_attack_01",
    "grab1_miss_brick": "m02_grab_01",
    "grab2_miss_brick": "m02_grab_01",
    "grabbed1": "all_grabbed_01_forset03",
    "grabbed2": "all_grabbed_02_forset03",
    "endattackcomp1": "all_end_attack_01_forset03",
    "endattackcomp2": "all_end_attack_02_forset03",
    "m03_blck_high": "m03_blck_high",
    "all_block_low": "all_block_low",
    "all_block_mid": "all_block_mid",
    "stun": "all_stunned",
    "stun_fall": "all_stunned_fall",
    "stun_hard": "all_impct_hard_frnt_high",
    "stun_brutal": "all_impct_spectacular_lft",
    "move": "m03_movefwd",
    "moveleft": "m03_movelft",
    "moveright": "m03_moverht",
    "stepfwd": "m03_stepfwd",
    "stepback": "m03_stepbck",
    "stepleft": "m03_steplft",
    "stepright": "m03_steprht",
}
# Candidate clip maps for the mapped set characters. Same shape as
# BRICK_CLIPS: attack slots -> their set animation, plus the support keys the
# state machine asks for. Generated from the fighting-set action tables.
const MASTER_CLIPS: Dictionary = {
    "idle": "m04_e01_idle_01",
    "punch": "m04_pnch_low_03",
    "kick": "m04_kck_low_02",
    "high_punch": "m04_pnch_high_01",
    "high_punch2": "m04_pnch_high_02",
    "high_punch3": "m04_pnch_high_03",
    "low_punch": "m04_pnch_low_01",
    "low_punch2": "m04_pnch_low_02",
    "low_punch3": "m04_pnch_low_03",
    "high_kick": "m04_kck_high_01",
    "high_kick2": "m04_kck_high_02",
    "high_kick3": "m04_kck_high_03",
    "low_kick": "m04_kck_low_03",
    "low_kick2": "m04_kck_low_01",
    "low_kick3": "m04_kck_low_02",
    "special_kick_high": "m04_e01_kck_high_03",
    "special_kick_low": "m04_e01_kck_low_03",
    "special_punch_high": "m04_e01_pnch_high_03",
    "special_punch_low": "m04_e01_pnch_low_03",
    "parry_high": "m01_parry_high",
    "parry_low": "m01_kick_low_02",
    "parry_attack": "m04_pnch_high_02",
    "grab1": "m04_sp_pnch_low",
    "grab2": "m04_sp_kck_low",
    "grab1_miss": "m04_sp_pnch_low",
    "grab2_miss": "m04_sp_kck_low",
    "attack_to_floor": "m01_attack_to_floor",
    "endattack": "m04_end_attack_02",
    "grabbed1": "all_sp_pnch_low_forset04",
    "grabbed2": "all_sp_kck_low_forset04",
    "highblock": "all_block_high",
    "all_block_low": "all_block_low",
    "all_block_mid": "all_block_mid",
    "stun": "all_stunned",
    "stun_fall": "all_stunned_fall",
    "stun_hard": "all_impct_hard_frnt_high",
    "stun_brutal": "all_impct_spectacular_lft",
    "move": "m04_movefwd",
    "moveleft": "m04_movelft",
    "moveright": "m04_moverht",
    "stepfwd": "m04_stepfwd",
    "stepback": "m04_stepbck",
    "stepleft": "m04_steplft",
    "stepright": "m04_steprht",
}
const SINFU_CLIPS: Dictionary = {
    "idle": "m04_e02_idle_01",
    "punch": "m04_pnch_low_03",
    "kick": "m04_kck_low_02",
    "high_punch": "m04_pnch_high_01",
    "high_punch2": "m04_pnch_high_02",
    "high_punch3": "m04_pnch_high_03",
    "low_punch": "m04_pnch_low_01",
    "low_punch2": "m04_pnch_low_02",
    "low_punch3": "m04_pnch_low_03",
    "high_kick": "m04_kck_high_01",
    "high_kick2": "m04_kck_high_02",
    "high_kick3": "m04_kck_high_03",
    "low_kick": "m04_kck_low_03",
    "low_kick2": "m04_kck_low_01",
    "low_kick3": "m04_kck_low_02",
    "special_kick_high": "m04_e02_kck_high_03",
    "special_kick_low": "m04_e02_kck_low_03",
    "special_punch_low": "m04_e02_pnch_low_03",
    "parry_high": "m01_parry_high",
    "parry_low": "m01_kick_low_02",
    "parry_attack": "m04_pnch_high_02",
    "grab1": "m04_grab_01",
    "grab2": "m04_sp_kck_low",
    "grab1_miss": "m02_grab_01",
    "grab2_miss": "m04_sp_kck_low",
    "attack_to_floor": "m01_attack_to_floor",
    "endattack": "m04_end_attack_02",
    "special_punch_high_miss": "m04_sp_pnch_high_fail",
    "special_punch_high_hit": "m04_sp_pnch_high",
    "grabbed1": "all_grabbed_01_forset04",
    "grabbed2": "all_sp_kck_low_forset04",
    "highblock": "all_block_high",
    "all_block_low": "all_block_low",
    "all_block_mid": "all_block_mid",
    "stun": "all_stunned",
    "stun_fall": "all_stunned_fall",
    "stun_hard": "all_impct_hard_frnt_high",
    "stun_brutal": "all_impct_spectacular_lft",
    "move": "m04_movefwd",
    "moveleft": "m04_movelft",
    "moveright": "m04_moverht",
    "stepfwd": "m04_stepfwd",
    "stepback": "m04_stepbck",
    "stepleft": "m04_steplft",
    "stepright": "m04_steprht",
}
const SHENLO_CLIPS: Dictionary = {
    "idle": "m04_e03_idle_01",
    "punch": "m04_pnch_low_03",
    "kick": "m04_kck_low_02",
    "high_punch": "m04_pnch_high_01",
    "high_punch2": "m04_pnch_high_02",
    "high_punch3": "m04_pnch_high_03",
    "low_punch": "m04_pnch_low_01",
    "low_punch2": "m04_pnch_low_02",
    "low_punch3": "m04_pnch_low_03",
    "high_kick": "m04_kck_high_01",
    "high_kick2": "m04_kck_high_02",
    "high_kick3": "m04_kck_high_03",
    "low_kick": "m04_kck_low_03",
    "low_kick2": "m04_kck_low_01",
    "low_kick3": "m04_kck_low_02",
    "special_kick_high": "m04_e03_kck_high_03",
    "special_kick_low": "m04_e03_kck_low_03",
    "special_punch_low": "m04_e03_pnch_low_03",
    "special_punch_high": "m04_e03_pnch_high_03",
    "parry_high": "m01_parry_high",
    "parry_low": "m01_kick_low_02",
    "parry_attack": "m04_pnch_high_02",
    "grab1": "m04_grab_01",
    "grab2": "m04_grab_02",
    "grab1_miss": "m02_grab_01",
    "grab2_miss": "m04_grab_02",
    "attack_to_floor": "m01_attack_to_floor",
    "endattack": "m04_end_attack_01",
    "grabbed1": "all_grabbed_01_forset04",
    "grabbed2": "all_grabbed_02_forset04",
    "highblock": "all_block_high",
    "all_block_low": "all_block_low",
    "all_block_mid": "all_block_mid",
    "stun": "all_stunned",
    "stun_fall": "all_stunned_fall",
    "stun_hard": "all_impct_hard_frnt_high",
    "stun_brutal": "all_impct_spectacular_lft",
    "move": "m04_e03_movefwd",
    "moveleft": "m04_movelft",
    "moveright": "m04_moverht",
    "stepfwd": "m04_stepfwd",
    "stepback": "m04_stepbck",
    "stepleft": "m04_e03_steplft",
    "stepright": "m04_e03_steprht",
}

const KEN_CLIPS: Dictionary = {
    "idle": "m02_idle_01",
    "punch": "m02_pnch_low_03",
    "kick": "m02_kck_low_03",
    "high_punch": "m02_pnch_high_01",
    "high_punch2": "m02_pnch_high_03",
    "high_punch3": "m02_pnch_high_02",
    "low_punch": "m02_pnch_low_01",
    "low_punch2": "m02_pnch_low_02",
    "low_punch3": "m02_pnch_low_03",
    "high_kick": "m02_kck_high_01",
    "high_kick2": "m02_kck_high_03",
    "high_kick3": "m02_kck_high_02",
    "low_kick": "m02_kck_low_01",
    "low_kick2": "m02_kck_low_02",
    "low_kick3": "m02_kck_low_03",
    "special_kick_high": "m02_sp_kck_high",
    "special_kick_low": "m02_sp_kck_low",
    "special_punch_high": "m02_sp_pnch_high",
    "special_punch_low": "m02_sp_pnch_low",
    "parry_high": "m02_parry_high",
    "parry_attack": "m02_pnch_low_03",
    "grab1": "m02_grab_01",
    "grab2": "m02_grab_02",
    "grab1_miss": "m02_grab_01",
    "grab2_miss": "m02_grab_01",
    "attack_to_floor": "m02_attack_to_floor",
    "endattack": "m02_end_attack_01",
    "grabbed1": "all_grabbed_01_forset02",
    "grabbed2": "all_grabbed_02_forset02",
    "endattackcomp1": "all_end_attack_01_forset02",
    "endattackcomp2": "all_end_attack_02_forset02",
    "highblock": "all_block_high",
    "all_block_low": "all_block_low",
    "all_block_mid": "all_block_mid",
    "stun": "all_stunned",
    "stun_fall": "all_stunned_fall",
    "stun_hard": "all_impct_hard_frnt_high",
    "stun_brutal": "all_impct_spectacular_lft",
    "move": "m02_movefwd",
    "moveleft": "m02_movelft",
    "moveright": "m02_moverht",
    "stepfwd": "m02_stepfwd",
    "stepback": "m02_stepbck",
    "stepleft": "m02_steplft",
    "stepright": "m02_steprht",
}

const SMALLBOY_ATTACK_DATA: Dictionary = {
    "punch": ["lowpunch3", "m03_pnch_low_01", 38, 8, 4, 26, 7.0, 80.0, "larm", "medium", "hard", "frontal"],
    "kick": ["lowkick3", "m03_kck_low_01", 41, 9, 3, 29, 7.0, 70.0, "lleg", "low", "hard", "fromright"],
    "high_punch": ["highpunch1", "m03_pnch_high_01", 19, 6, 3, 10, 5.0, 72.0, "larm", "high", "normal", "frontal"],
    "high_punch2": ["highpunch2", "m03_pnch_high_02", 31, 8, 4, 19, 7.0, 65.0, "rarm", "high", "normal", "fromleft"],
    "high_punch3": ["highpunch3", "m03_pnch_high_03", 35, 11, 4, 20, 8.0, 70.0, "larm", "high", "hard", "fromleft"],
    "low_punch": ["lowpunch1", "m03_pnch_low_03", 27, 9, 4, 14, 6.0, 62.0, "rarm", "medium", "normal", "frontal"],
    "low_punch2": ["lowpunch2", "m03_pnch_low_02", 35, 9, 4, 22, 6.0, 70.0, "larm", "medium", "normal", "frontal"],
    "low_punch3": ["lowpunch3", "m03_pnch_low_01", 38, 8, 4, 26, 7.0, 80.0, "larm", "medium", "hard", "frontal"],
    "high_kick": ["highkick1", "m03_kck_high_01", 44, 12, 4, 28, 6.0, 65.0, "lleg", "high", "normal", "frontal"],
    "high_kick2": ["highkick2", "m03_kck_high_02", 49, 9, 5, 35, 7.0, 65.0, "lleg", "high", "normal", "frontal"],
    "high_kick3": ["highkick3", "m03_kck_high_03", 47, 12, 4, 31, 8.0, 70.0, "lleg", "high", "hard", "fromright"],
    "low_kick": ["lowkick1", "m03_kck_low_02", 46, 6, 5, 35, 5.0, 65.0, "lleg", "medium", "normal", "frontal"],
    "low_kick2": ["lowkick2", "m03_kck_low_03", 37, 8, 4, 25, 6.0, 65.0, "rleg", "medium", "normal", "frontal"],
    "low_kick3": ["lowkick3", "m03_kck_low_01", 41, 9, 3, 29, 7.0, 70.0, "lleg", "low", "hard", "fromright"],
    "special_kick_high_brick": ["specialkickhigh smallboy", "m03_e01_sp_kck_high_02", 38, 7, 5, 26, 10.0, 80.0, "rleg", "high", "hard", "fromabove"],
    "special_kick_low_brick": ["specialkicklow smallboy", "m03_sp_kck_low", 56, 14, 4, 38, 9.0, 75.0, "rleg", "low", "hard", "fromleft"],
    "special_punch_high_brick": ["specialpunchhigh smallboy", "m03_shoulder_charge", 53, 4, 5, 44, 10.0, 75.0, "larm", "high", "hard", "frontal"],
    "special_punch_low_brick": ["specialpunchlow smallboy", "m03_sp_pnch_low", 44, 15, 4, 25, 9.0, 75.0, "rarm", "high", "hard", "frontal"],
    "parry_high_brick": ["parryhigh", "m03_parry_high", 43, 0, 2, 41, 0.0, 0.0, "larm", "high", "normal", "frontal"],
    "parry_low_brick": ["parrylow", "m03_parry_low", 41, 0, 2, 39, 0.0, 0.0, "larm", "low", "normal", "frontal"],
    "parry_attack_brick": ["parryattack", "m03_pnch_high_03", 35, 10, 5, 20, 10.0, 65.0, "rarm", "high", "hard", "frontal"],
    "grab1_brick": ["grab1 smallboy", "m03_grab_01", 90, 19, 2, 69, 6.0, 45.0, "larm", "high", "normal", "frontal"],
    "grab2_brick": ["grab2 smallboy", "m03_grab_02", 78, 46, 3, 29, 20.0, 45.0, "larm", "high", "hard", "frontal"],
    "attack_to_floor_brick": ["attacktofloor", "m03_attack_to_floor", 61, 11, 5, 45, 6.0, 35.0, "lleg", "low", "normal", "frontal"],
    "endattack_brick": ["endattack smallboy", "m03_end_attack_01", 93, 15, 4, 74, 0.0, 75.0, "lleg", "high", "brutal", "fromleft"],
    "grab1_miss_brick": ["grab1miss smallboy", "m02_grab_01", 47, 5, 3, 39, 0.0, 45.0, "larm", "high", "normal", "frontal"],
    "grab2_miss_brick": ["grab2miss smallboy", "m02_grab_01", 47, 9, 3, 35, 0.0, 45.0, "larm", "low", "normal", "frontal"],
}
const SMALLBOY_ANIMATION_RADII_DATA: Dictionary = {
    "m02_grab_01": 45.0,
    "m03_attack_to_floor": 35.0,
    "m03_e01_sp_kck_high_02": 25.0,
    "m03_end_attack_01": 75.0,
    "m03_grab_01": 45.0,
    "m03_grab_02": 45.0,
    "m03_idle_01": 43.0,
    "m03_kck_high_01": 30.0,
    "m03_kck_high_02": 30.0,
    "m03_kck_high_03": 45.0,
    "m03_kck_low_01": 50.0,
    "m03_kck_low_02": 50.0,
    "m03_kck_low_03": 50.0,
    "m03_movefwd": 50.0,
    "m03_parry_high": 40.0,
    "m03_parry_low": 40.0,
    "m03_pnch_high_01": 43.0,
    "m03_pnch_high_02": 43.0,
    "m03_pnch_high_03": 50.0,
    "m03_pnch_low_01": 40.0,
    "m03_pnch_low_02": 40.0,
    "m03_pnch_low_03": 40.0,
    "m03_shoulder_charge": 45.0,
    "m03_sp_kck_high": 45.0,
    "m03_sp_kck_low": 45.0,
    "m03_sp_pnch_high": 45.0,
    "m03_sp_pnch_low": 45.0,
}
const JOHNSON_ATTACK_DATA: Dictionary = {
    "punch": ["lowpunch3", "m03_pnch_low_01", 38, 8, 4, 26, 7.0, 80.0, "larm", "medium", "hard", "frontal"],
    "kick": ["lowkick3", "m03_kck_low_01", 41, 9, 3, 29, 7.0, 70.0, "lleg", "low", "hard", "fromright"],
    "high_punch": ["highpunch1", "m03_pnch_high_01", 19, 6, 3, 10, 5.0, 72.0, "larm", "high", "normal", "frontal"],
    "high_punch2": ["highpunch2", "m03_pnch_high_02", 31, 8, 4, 19, 7.0, 65.0, "rarm", "high", "normal", "fromleft"],
    "high_punch3": ["highpunch3", "m03_pnch_high_03", 35, 11, 4, 20, 8.0, 70.0, "larm", "high", "hard", "fromleft"],
    "low_punch": ["lowpunch1", "m03_pnch_low_03", 27, 9, 4, 14, 6.0, 62.0, "rarm", "medium", "normal", "frontal"],
    "low_punch2": ["lowpunch2", "m03_pnch_low_02", 35, 9, 4, 22, 6.0, 70.0, "larm", "medium", "normal", "frontal"],
    "low_punch3": ["lowpunch3", "m03_pnch_low_01", 38, 8, 4, 26, 7.0, 80.0, "larm", "medium", "hard", "frontal"],
    "high_kick": ["highkick1", "m03_kck_high_01", 44, 12, 4, 28, 6.0, 65.0, "lleg", "high", "normal", "frontal"],
    "high_kick2": ["highkick2", "m03_kck_high_02", 49, 9, 5, 35, 7.0, 65.0, "lleg", "high", "normal", "frontal"],
    "high_kick3": ["highkick3", "m03_kck_high_03", 47, 12, 4, 31, 8.0, 70.0, "lleg", "high", "hard", "fromright"],
    "low_kick": ["lowkick1", "m03_kck_low_02", 46, 6, 5, 35, 5.0, 65.0, "lleg", "medium", "normal", "frontal"],
    "low_kick2": ["lowkick2", "m03_kck_low_03", 37, 8, 4, 25, 6.0, 65.0, "rleg", "medium", "normal", "frontal"],
    "low_kick3": ["lowkick3", "m03_kck_low_01", 41, 9, 3, 29, 7.0, 70.0, "lleg", "low", "hard", "fromright"],
    "special_kick_high_brick": ["specialkickhigh johnson", "m03_e01_kck_high_03", 30, 9, 4, 17, 10.0, 80.0, "lleg", "high", "brutal", "fromright"],
    "special_kick_low_brick": ["specialkicklow johnson", "m03_sp_kck_low", 56, 13, 4, 39, 9.0, 75.0, "rleg", "low", "hard", "fromleft"],
    "special_punch_high_brick": ["specialpunchhigh johnson", "m03_e01_pnch_high_03", 52, 11, 5, 36, 8.0, 55.0, "rarm", "high", "hard", "frontal"],
    "special_punch_low_brick": ["specialpunchlow johnson", "m03_sp_pnch_low", 44, 15, 4, 25, 9.0, 75.0, "rarm", "high", "hard", "frontal"],
    "parry_high_brick": ["parryhigh", "m03_parry_high", 43, 0, 2, 41, 0.0, 0.0, "larm", "high", "normal", "frontal"],
    "parry_low_brick": ["parrylow", "m03_parry_low", 41, 0, 2, 39, 0.0, 0.0, "larm", "low", "normal", "frontal"],
    "parry_attack_brick": ["parryattack", "m03_pnch_high_03", 35, 10, 5, 20, 10.0, 65.0, "rarm", "high", "hard", "frontal"],
    "grab1_brick": ["grab1 johnson", "m03_grab_01", 90, 19, 2, 69, 6.0, 45.0, "larm", "high", "normal", "frontal"],
    "grab2_brick": ["grab2 johnson", "m03_grab_02", 78, 46, 3, 29, 20.0, 45.0, "larm", "high", "hard", "frontal"],
    "attack_to_floor_brick": ["attacktofloor", "m03_attack_to_floor", 61, 11, 5, 45, 6.0, 35.0, "lleg", "low", "normal", "frontal"],
    "endattack_brick": ["endattack johnson", "m03_end_attack_02", 130, 18, 1, 111, 0.0, 75.0, "rleg", "high", "hard", "fromleft"],
    "grab1_miss_brick": ["grab1miss johnson", "m02_grab_01", 47, 5, 3, 39, 0.0, 45.0, "larm", "high", "normal", "frontal"],
    "grab2_miss_brick": ["grab2miss johnson", "m02_grab_01", 47, 4, 4, 39, 0.0, 45.0, "larm", "high", "normal", "frontal"],
}
const JOHNSON_ANIMATION_RADII_DATA: Dictionary = {
    "m02_grab_01": 45.0,
    "m03_attack_to_floor": 35.0,
    "m03_e01_kck_high_03": 25.0,
    "m03_e01_pnch_high_03": 45.0,
    "m03_end_attack_01": 75.0,
    "m03_end_attack_02": 25.0,
    "m03_grab_01": 45.0,
    "m03_grab_02": 45.0,
    "m03_idle_01": 43.0,
    "m03_kck_high_01": 30.0,
    "m03_kck_high_02": 30.0,
    "m03_kck_high_03": 45.0,
    "m03_kck_low_01": 50.0,
    "m03_kck_low_02": 50.0,
    "m03_kck_low_03": 50.0,
    "m03_movefwd": 50.0,
    "m03_parry_high": 40.0,
    "m03_parry_low": 40.0,
    "m03_pnch_high_01": 43.0,
    "m03_pnch_high_02": 43.0,
    "m03_pnch_high_03": 50.0,
    "m03_pnch_low_01": 40.0,
    "m03_pnch_low_02": 40.0,
    "m03_pnch_low_03": 40.0,
    "m03_sp_kck_high": 45.0,
    "m03_sp_kck_low": 45.0,
    "m03_sp_pnch_high": 45.0,
    "m03_sp_pnch_low": 45.0,
}
const CHIEF_ATTACK_DATA: Dictionary = {
    "punch": ["lowpunch3", "m02_pnch_low_03", 57, 14, 7, 36, 7.0, 70.0, "larm", "medium", "hard", "frontal"],
    "kick": ["lowkick3", "m02_kck_low_03", 35, 9, 6, 20, 7.0, 110.0, "rleg", "low", "hard", "frontal"],
    "high_punch": ["highpunch1", "m02_pnch_high_01", 40, 7, 3, 30, 5.0, 60.0, "larm", "high", "normal", "frontal"],
    "high_punch2": ["highpunch2", "m02_pnch_high_03", 46, 8, 4, 34, 6.0, 70.0, "rarm", "high", "normal", "frontal"],
    "high_punch3": ["highpunch3", "m02_pnch_high_02", 20, 8, 4, 8, 7.0, 80.0, "larm", "high", "hard", "frontal"],
    "low_punch": ["lowpunch1", "m02_pnch_low_01", 31, 7, 4, 20, 6.0, 70.0, "larm", "medium", "normal", "frontal"],
    "low_punch2": ["lowpunch2", "m02_pnch_low_02", 27, 7, 4, 16, 6.0, 70.0, "larm", "medium", "normal", "frontal"],
    "low_punch3": ["lowpunch3", "m02_pnch_low_03", 57, 14, 7, 36, 7.0, 70.0, "larm", "medium", "hard", "frontal"],
    "high_kick": ["highkick1", "m02_kck_high_01", 50, 7, 6, 37, 5.0, 80.0, "lleg", "high", "normal", "frontal"],
    "high_kick2": ["highkick2", "m02_kck_high_03", 52, 14, 5, 33, 6.0, 80.0, "lleg", "high", "normal", "frontal"],
    "high_kick3": ["highkick3", "m02_kck_high_02", 50, 9, 4, 37, 8.0, 80.0, "lleg", "high", "hard", "frontal"],
    "low_kick": ["lowkick1", "m02_kck_low_01", 26, 5, 4, 17, 4.0, 65.0, "lleg", "low", "normal", "fromright"],
    "low_kick2": ["lowkick2", "m02_kck_low_02", 24, 8, 4, 12, 4.0, 65.0, "rleg", "low", "normal", "fromleft"],
    "low_kick3": ["lowkick3", "m02_kck_low_03", 35, 9, 6, 20, 7.0, 110.0, "rleg", "low", "hard", "frontal"],
    "special_kick_high": ["specialkickhigh chief", "m02_e01_kck_high_03", 32, 9, 8, 15, 12.0, 75.0, "rleg", "high", "hard", "frontal"],
    "special_kick_low": ["specialkicklow chief", "m02_e01_kck_low_03", 40, 11, 5, 24, 10.0, 70.0, "lleg", "low", "hard", "frontal"],
    "special_punch_high": ["specialpunchhigh chief", "m02_e01_pnch_high_03", 24, 8, 5, 11, 14.0, 45.0, "rarm", "high", "hard", "frontal"],
    "special_punch_low": ["specialpunchlow chief", "m02_e01_pnch_low_03", 24, 9, 4, 11, 10.0, 75.0, "larm", "high", "hard", "frontal"],
    "parry_high": ["parryhigh", "m02_parry_high", 19, 0, 2, 17, 0.0, 0.0, "larm", "high", "normal", "frontal"],
    "parry_attack": ["parryattack", "m02_pnch_low_03", 57, 14, 5, 38, 10.0, 65.0, "rarm", "high", "hard", "frontal"],
    "grab1": ["grab1 chief", "m02_grab_01", 47, 32, 7, 8, 16.0, 45.0, "larm", "low", "hard", "frontal"],
    "grab2": ["grab2 chief", "m02_grab_02", 98, 65, 6, 27, 20.0, 45.0, "larm", "low", "hard", "frontal"],
    "grab1_miss": ["grab1miss chief", "m02_grab_01", 47, 5, 3, 39, 0.0, 45.0, "larm", "high", "normal", "frontal"],
    "grab2_miss": ["grab2miss chief", "m02_grab_01", 47, 4, 4, 39, 0.0, 45.0, "larm", "high", "normal", "frontal"],
    "attack_to_floor": ["attacktofloor", "m02_attack_to_floor", 34, 8, 5, 21, 6.0, 105.0, "rarm", "low", "normal", "frontal"],
    "endattack": ["endattack chief", "m02_end_attack_02", 155, 17, 3, 135, 0.0, 75.0, "rleg", "high", "brutal", "fromleft"],
}
const CHIEF_ANIMATION_RADII_DATA: Dictionary = {
    "all_block_high": 40.0,
    "all_block_low": 40.0,
    "all_block_mid": 40.0,
    "all_impct_light_frnt_high": 40.0,
    "all_impct_light_frnt_low": 40.0,
    "all_impct_light_frnt_mid": 40.0,
    "m02_attack_to_floor": 45.0,
    "m02_e01_kck_high_03": 45.0,
    "m02_e01_kck_low_03": 40.0,
    "m02_e01_pnch_high_03": 45.0,
    "m02_e01_pnch_low_03": 45.0,
    "m02_end_attack_01": 25.0,
    "m02_end_attack_02": 25.0,
    "m02_grab_01": 25.0,
    "m02_grab_02": 25.0,
    "m02_idle_01": 55.0,
    "m02_kck_high_01": 50.0,
    "m02_kck_high_02": 40.0,
    "m02_kck_high_03": 50.0,
    "m02_kck_low_01": 50.0,
    "m02_kck_low_02": 50.0,
    "m02_kck_low_03": 70.0,
    "m02_parry_high": 40.0,
    "m02_pnch_high_01": 40.0,
    "m02_pnch_high_02": 60.0,
    "m02_pnch_high_03": 30.0,
    "m02_pnch_low_01": 40.0,
    "m02_pnch_low_02": 40.0,
    "m02_pnch_low_03": 45.0,
    "m02_sp_kck_high": 50.0,
    "m02_sp_kck_low": 45.0,
    "m02_sp_pnch_high": 30.0,
    "m02_sp_pnch_low": 45.0,
}
const LOMING_ATTACK_DATA: Dictionary = {
    "punch": ["lowpunch3", "m04_pnch_low_03", 71, 10, 6, 55, 7.0, 85.0, "larm", "medium", "hard", "frontal"],
    "kick": ["lowkick3", "m04_kck_low_02", 34, 6, 4, 24, 7.0, 100.0, "lleg", "low", "hard", "fromright"],
    "high_punch": ["highpunch1", "m04_pnch_high_01", 68, 6, 5, 57, 5.0, 75.0, "larm", "high", "normal", "frontal"],
    "high_punch2": ["highpunch2", "m04_pnch_high_02", 50, 6, 5, 39, 6.0, 65.0, "rarm", "high", "normal", "frontal"],
    "high_punch3": ["highpunch3", "m04_pnch_high_03", 50, 15, 8, 27, 7.0, 75.0, "larm", "high", "hard", "fromabove"],
    "low_punch": ["lowpunch1", "m04_pnch_low_01", 48, 5, 5, 38, 6.0, 70.0, "larm", "medium", "normal", "frontal"],
    "low_punch2": ["lowpunch2", "m04_pnch_low_02", 64, 8, 4, 52, 6.0, 85.0, "larm", "medium", "normal", "frontal"],
    "low_punch3": ["lowpunch3", "m04_pnch_low_03", 71, 10, 6, 55, 7.0, 85.0, "larm", "medium", "hard", "frontal"],
    "high_kick": ["highkick1", "m04_kck_high_01", 53, 9, 6, 38, 5.0, 80.0, "rleg", "high", "normal", "frontal"],
    "high_kick2": ["highkick2", "m04_kck_high_02", 43, 6, 6, 31, 6.0, 80.0, "rleg", "high", "normal", "fromright"],
    "high_kick3": ["highkick3", "m04_kck_high_03", 60, 9, 5, 46, 7.0, 80.0, "lleg", "high", "hard", "fromleft"],
    "low_kick": ["lowkick1", "m04_kck_low_03", 22, 6, 5, 11, 5.0, 70.0, "lleg", "low", "normal", "frontal"],
    "low_kick2": ["lowkick2", "m04_kck_low_01", 34, 5, 5, 24, 5.0, 100.0, "lleg", "low", "normal", "fromleft"],
    "low_kick3": ["lowkick3", "m04_kck_low_02", 34, 6, 4, 24, 7.0, 100.0, "lleg", "low", "hard", "fromright"],
    "special_kick_high": ["specialkickhigh loming", "m04_e02_kck_high_03", 85, 9, 6, 70, 13.0, 80.0, "lleg", "high", "hard", "frontal"],
    "special_kick_low": ["specialkicklow loming", "m04_e02_kck_low_03", 76, 10, 4, 62, 6.0, 75.0, "rleg", "low", "normal", "fromleft"],
    "special_punch_low": ["specialpunchlow loming", "m04_e02_pnch_low_03", 104, 11, 4, 89, 10.0, 75.0, "rarm", "medium", "hard", "frontal"],
    "parry_high": ["parryhigh", "m01_parry_high", 62, 0, 2, 60, 0.0, 0.0, "larm", "high", "normal", "frontal"],
    "parry_low": ["parrylow", "m01_kick_low_02", 27, 7, 4, 16, 0.0, 65.0, "rleg", "low", "normal", "frontal"],
    "parry_attack": ["parryattack", "m04_pnch_high_02", 50, 6, 5, 39, 10.0, 65.0, "rarm", "high", "hard", "frontal"],
    "grab1": ["grab1 loming", "m04_grab_01", 103, 34, 11, 58, 20.0, 45.0, "larm", "low", "hard", "frontal"],
    "grab2": ["grab2 loming", "m04_grab_02", 45, 7, 3, 35, 5.0, 45.0, "larm", "high", "hard", "frontal"],
    "grab1_miss": ["grab1miss loming", "m04_grab_01", 103, 5, 3, 95, 0.0, 45.0, "larm", "high", "normal", "frontal"],
    "grab2_miss": ["grab2miss loming", "m04_grab_02", 45, 4, 4, 37, 0.0, 50.0, "larm", "high", "normal", "frontal"],
    "attack_to_floor": ["attacktofloor", "m01_attack_to_floor", 90, 18, 5, 67, 6.0, 60.0, "lleg", "low", "normal", "frontal"],
    "endattack": ["endattack loming", "m04_end_attack_01", 93, 17, 3, 73, 0.0, 75.0, "rleg", "high", "brutal", "fromleft"],
    "special_punch_high_miss": ["specialpunchhighmiss sinfu", "m04_sp_pnch_high_fail", 71, 0, 2, 69, 0.0, 0.0, "larm", "high", "normal", "frontal"],
    "special_punch_high_hit": ["specialpunchhighhit sinfu", "m04_sp_pnch_high", 50, 11, 12, 27, 20.0, 45.0, "larm", "high", "hard", "frontal"],
}
const LOMING_ANIMATION_RADII_DATA: Dictionary = {
    "all_block_high": 60.0,
    "all_block_low": 60.0,
    "all_block_mid": 60.0,
    "all_impct_light_frnt_high": 40.0,
    "all_impct_light_frnt_low": 50.0,
    "all_impct_light_frnt_mid": 40.0,
    "m01_attack_to_floor": 45.0,
    "m01_kick_low_02": 40.0,
    "m01_parry_high": 40.0,
    "m02_grab_01": 25.0,
    "m04_e02_idle_01": 50.0,
    "m04_e02_kck_high_03": 50.0,
    "m04_e02_kck_low_03": 55.0,
    "m04_e02_pnch_low_03": 55.0,
    "m04_end_attack_01": 25.0,
    "m04_end_attack_02": 25.0,
    "m04_grab_01": 25.0,
    "m04_grab_02": 25.0,
    "m04_kck_high_01": 50.0,
    "m04_kck_high_02": 50.0,
    "m04_kck_high_03": 40.0,
    "m04_kck_low_01": 50.0,
    "m04_kck_low_02": 50.0,
    "m04_kck_low_03": 50.0,
    "m04_pnch_high_01": 40.0,
    "m04_pnch_high_02": 25.0,
    "m04_pnch_high_03": 60.0,
    "m04_pnch_low_01": 40.0,
    "m04_pnch_low_02": 40.0,
    "m04_pnch_low_03": 40.0,
    "m04_sp_kck_low": 25.0,
    "m04_sp_pnch_high": 25.0,
    "m04_sp_pnch_high_fail": 40.0,
}
const SOURCE_FRAME_RATE: float = 30.0
# Root-motion axis mapping is an isolated port adapter. EMPIRICAL means the
# current mapping has passed the behavior tests; UNVERIFIED means the native
# axis/sign semantics are not established. The raw ANM positions are never
# modified by this classification.
const ROOT_MOTION_MAPPING_STATUS: Dictionary = {
    "m01_pnch_low_01": "EMPIRICAL",
    "m03_pnch_low_01": "EMPIRICAL",
    "m03_kck_low_01": "EMPIRICAL",
}
const SOURCE_CHARACTER_HEIGHT: float = CANDIDATE_SOURCE_HEIGHT
const WORLD_CHARACTER_HEIGHT: float = CANDIDATE_HEIGHT
const CandidatePathGuard = preload("res://scripts/candidate_path_guard.gd")
const CandidateMaterialLoader = preload("res://scripts/candidate_material_loader.gd")
const CandidateBounds = preload("res://scripts/candidate_bounds.gd")
# SMALL BOY candidate clip table (generated from the set).
const SMALLBOY_CLIPS: Dictionary = {
    "idle": "m03_idle_01",
    "punch": "m03_pnch_low_01",
    "kick": "m03_kck_low_01",
    "high_punch": "m03_pnch_high_01",
    "high_punch2": "m03_pnch_high_02",
    "high_punch3": "m03_pnch_high_03",
    "low_punch": "m03_pnch_low_03",
    "low_punch2": "m03_pnch_low_02",
    "low_punch3": "m03_pnch_low_01",
    "high_kick": "m03_kck_high_01",
    "high_kick2": "m03_kck_high_02",
    "high_kick3": "m03_kck_high_03",
    "low_kick": "m03_kck_low_02",
    "low_kick2": "m03_kck_low_03",
    "low_kick3": "m03_kck_low_01",
    "special_kick_high_brick": "m03_e01_sp_kck_high_02",
    "special_kick_low_brick": "m03_sp_kck_low",
    "special_punch_high_brick": "m03_shoulder_charge",
    "special_punch_low_brick": "m03_sp_pnch_low",
    "parry_high_brick": "m03_parry_high",
    "parry_low_brick": "m03_parry_low",
    "parry_attack_brick": "m03_pnch_high_03",
    "grab1_brick": "m03_grab_01",
    "grab2_brick": "m03_grab_02",
    "attack_to_floor_brick": "m03_attack_to_floor",
    "endattack_brick": "m03_end_attack_01",
    "grab1_miss_brick": "m02_grab_01",
    "grab2_miss_brick": "m02_grab_01",
    "grabbed1": "all_grabbed_01_forset03",
    "grabbed2": "all_grabbed_02_forset03",
    "endattackcomp1": "all_end_attack_01_forset03",
    "endattackcomp2": "all_end_attack_02_forset03",
    "m03_blck_high": "m03_blck_high",
    "all_block_low": "all_block_low",
    "all_block_mid": "all_block_mid",
    "stun": "all_stunned",
    "stun_fall": "all_stunned_fall",
    "stun_hard": "all_impct_hard_frnt_high",
    "stun_brutal": "all_impct_spectacular_lft",
    "move": "m03_movefwd",
    "moveleft": "m03_movelft",
    "moveright": "m03_moverht",
    "stepfwd": "m03_stepfwd",
    "stepback": "m03_stepbck",
    "stepleft": "m03_steplft",
    "stepright": "m03_steprht",
}

# JOHNSON candidate clip table (generated from the set).
const JOHNSON_CLIPS: Dictionary = {
    "idle": "m03_idle_01",
    "punch": "m03_pnch_low_01",
    "kick": "m03_kck_low_01",
    "high_punch": "m03_pnch_high_01",
    "high_punch2": "m03_pnch_high_02",
    "high_punch3": "m03_pnch_high_03",
    "low_punch": "m03_pnch_low_03",
    "low_punch2": "m03_pnch_low_02",
    "low_punch3": "m03_pnch_low_01",
    "high_kick": "m03_kck_high_01",
    "high_kick2": "m03_kck_high_02",
    "high_kick3": "m03_kck_high_03",
    "low_kick": "m03_kck_low_02",
    "low_kick2": "m03_kck_low_03",
    "low_kick3": "m03_kck_low_01",
    "special_kick_high_brick": "m03_e01_kck_high_03",
    "special_kick_low_brick": "m03_sp_kck_low",
    "special_punch_high_brick": "m03_e01_pnch_high_03",
    "special_punch_low_brick": "m03_sp_pnch_low",
    "parry_high_brick": "m03_parry_high",
    "parry_low_brick": "m03_parry_low",
    "parry_attack_brick": "m03_pnch_high_03",
    "grab1_brick": "m03_grab_01",
    "grab2_brick": "m03_grab_02",
    "attack_to_floor_brick": "m03_attack_to_floor",
    "endattack_brick": "m03_end_attack_02",
    "grab1_miss_brick": "m02_grab_01",
    "grab2_miss_brick": "m02_grab_01",
    "grabbed1": "all_grabbed_01_forset03",
    "grabbed2": "all_grabbed_02_forset03",
    "endattackcomp1": "all_end_attack_01_forset03",
    "endattackcomp2": "all_end_attack_02_forset03",
    "m03_blck_high": "m03_blck_high",
    "all_block_low": "all_block_low",
    "all_block_mid": "all_block_mid",
    "stun": "all_stunned",
    "stun_fall": "all_stunned_fall",
    "stun_hard": "all_impct_hard_frnt_high",
    "stun_brutal": "all_impct_spectacular_lft",
    "move": "m03_movefwd",
    "moveleft": "m03_movelft",
    "moveright": "m03_moverht",
    "stepfwd": "m03_stepfwd",
    "stepback": "m03_stepbck",
    "stepleft": "m03_steplft",
    "stepright": "m03_steprht",
}

# THE CHIEF candidate clip table (generated from the set).
const CHIEF_CLIPS: Dictionary = {
    "idle": "m02_idle_01",
    "punch": "m02_pnch_low_03",
    "kick": "m02_kck_low_03",
    "high_punch": "m02_pnch_high_01",
    "high_punch2": "m02_pnch_high_03",
    "high_punch3": "m02_pnch_high_02",
    "low_punch": "m02_pnch_low_01",
    "low_punch2": "m02_pnch_low_02",
    "low_punch3": "m02_pnch_low_03",
    "high_kick": "m02_kck_high_01",
    "high_kick2": "m02_kck_high_03",
    "high_kick3": "m02_kck_high_02",
    "low_kick": "m02_kck_low_01",
    "low_kick2": "m02_kck_low_02",
    "low_kick3": "m02_kck_low_03",
    "special_kick_high": "m02_e01_kck_high_03",
    "special_kick_low": "m02_e01_kck_low_03",
    "special_punch_high": "m02_e01_pnch_high_03",
    "special_punch_low": "m02_e01_pnch_low_03",
    "parry_high": "m02_parry_high",
    "parry_attack": "m02_pnch_low_03",
    "grab1": "m02_grab_01",
    "grab2": "m02_grab_02",
    "grab1_miss": "m02_grab_01",
    "grab2_miss": "m02_grab_01",
    "attack_to_floor": "m02_attack_to_floor",
    "endattack": "m02_end_attack_02",
    "grabbed1": "all_grabbed_01_forset02",
    "grabbed2": "all_grabbed_02_forset02",
    "endattackcomp1": "all_end_attack_01_forset02",
    "endattackcomp2": "all_end_attack_02_forset02",
    "highblock": "all_block_high",
    "all_block_low": "all_block_low",
    "all_block_mid": "all_block_mid",
    "stun": "all_stunned",
    "stun_fall": "all_stunned_fall",
    "stun_hard": "all_impct_hard_frnt_high",
    "stun_brutal": "all_impct_spectacular_lft",
    "move": "m02_movefwd",
    "moveleft": "m02_movelft",
    "moveright": "m02_moverht",
    "stepfwd": "m02_stepfwd",
    "stepback": "m02_stepbck",
    "stepleft": "m02_steplft",
    "stepright": "m02_steprht",
}

# LO MING candidate clip table (generated from the set).
const LOMING_CLIPS: Dictionary = {
    "idle": "m04_e02_idle_01",
    "punch": "m04_pnch_low_03",
    "kick": "m04_kck_low_02",
    "high_punch": "m04_pnch_high_01",
    "high_punch2": "m04_pnch_high_02",
    "high_punch3": "m04_pnch_high_03",
    "low_punch": "m04_pnch_low_01",
    "low_punch2": "m04_pnch_low_02",
    "low_punch3": "m04_pnch_low_03",
    "high_kick": "m04_kck_high_01",
    "high_kick2": "m04_kck_high_02",
    "high_kick3": "m04_kck_high_03",
    "low_kick": "m04_kck_low_03",
    "low_kick2": "m04_kck_low_01",
    "low_kick3": "m04_kck_low_02",
    "special_kick_high": "m04_e02_kck_high_03",
    "special_kick_low": "m04_e02_kck_low_03",
    "special_punch_low": "m04_e02_pnch_low_03",
    "parry_high": "m01_parry_high",
    "parry_low": "m01_kick_low_02",
    "parry_attack": "m04_pnch_high_02",
    "grab1": "m04_grab_01",
    "grab2": "m04_grab_02",
    "grab1_miss": "m04_grab_01",
    "grab2_miss": "m04_grab_02",
    "attack_to_floor": "m01_attack_to_floor",
    "endattack": "m04_end_attack_01",
    "special_punch_high_miss": "m04_sp_pnch_high_fail",
    "special_punch_high_hit": "m04_sp_pnch_high",
    "grabbed1": "all_grabbed_01_forset04",
    "grabbed2": "all_sp_kck_low_forset04",
    "highblock": "all_block_high",
    "all_block_low": "all_block_low",
    "all_block_mid": "all_block_mid",
    "stun": "all_stunned",
    "stun_fall": "all_stunned_fall",
    "stun_hard": "all_impct_hard_frnt_high",
    "stun_brutal": "all_impct_spectacular_lft",
    "move": "m04_movefwd",
    "moveleft": "m04_movelft",
    "moveright": "m04_moverht",
    "stepfwd": "m04_stepfwd",
    "stepback": "m04_stepbck",
    "stepleft": "m04_steplft",
    "stepright": "m04_steprht",
}

const ATTACK_CONFIG_PATH: String = "res://data/fighting_set_low_attacks.json"
const BRICK_ATTACK_CONFIG_PATH: String = "res://data/fighting_set_m03_mapped_attacks.json"
# Per-character mapped configs. adreno_200/characters.list assigns each
# opponent a fighting set: "the master" and "sin fu" -> kungfu.set,
# "ken godall" -> karate.set, "brick davis" -> thai.set. The two kungfu
# characters share the set and differ only in the character-suffixed actions.
const MASTER_ATTACK_CONFIG_PATH: String = "res://data/attack_config_master.json"
const SINFU_ATTACK_CONFIG_PATH: String = "res://data/attack_config_sinfu.json"
const SHENLO_ATTACK_CONFIG_PATH: String = "res://data/attack_config_shenlo.json"
const SMALLBOY_ATTACK_CONFIG_PATH: String = "res://data/attack_config_smallboy.json"
const JOHNSON_ATTACK_CONFIG_PATH: String = "res://data/attack_config_johnson.json"
const CHIEF_ATTACK_CONFIG_PATH: String = "res://data/attack_config_chief.json"
const LOMING_ATTACK_CONFIG_PATH: String = "res://data/attack_config_loming.json"
const KEN_ATTACK_CONFIG_PATH: String = "res://data/attack_config_ken.json"
const KUNGFU_NATIVE_LINKS_PATH: String = "res://data/native_links_kungfu.json"
const KARATE_NATIVE_LINKS_PATH: String = "res://data/native_links_karate.json"
const ATTACK_ROOT_MOTION_PATH: String = "res://data/attack_root_motion.json"
const MOVEMENT_ROOT_MOTION_PATH: String = "res://data/movement_root_motion.json"
const LOCOMOTION_STEP_TO_MOVE: Dictionary = {
    "stepfwd": "movefwd", "stepback": "moveback",
    "stepright": "moveright", "stepleft": "moveleft",
}
const LOCOMOTION_CHAIN_FRAME: float = 4.0
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
const IDLE3_CLIP: String = "m01_idle_03"
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
const IDLE3_DURATION_FRAMES: int = 143
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
# Per-config "fighting set profile". Bruce's own config (ATTACK_CONFIG_PATH) is
# not listed: an empty profile means the brucelee.set rules. Every entry below
# is recovered data from the set named in `source_archive`; the reaction exit
# frames are the outgoing link windows of that set's impact/hard actions.
const SET_ATTACK_PROFILES: Dictionary = {
    "res://data/attack_config_shenlo.json": {
        "source_archive": "kungfu.set",
        "link_tag": "shenlo",
        "native_links": KUNGFU_NATIVE_LINKS_PATH,
        "facedown_idle_clip": FACEDOWN_IDLE_CLIP,
        "facedown_impact_radius": 80.0,
        "front_low_clip": "all_impct_hard_frnt_low",
        "front_low_reaction": {
            "source_action": "impacthardfrontlow",
            "animation": "all_impct_hard_frnt_low",
            "animation_radius": 75.0,
            "exit_start_frame": 13,
            "animation_duration_frames": 23,
            "return_action": "facedownidle",
        },
        "front_high_reaction": {
            "animation": "all_impct_hard_frnt_high",
            "animation_radius": 70.0,
            "exit_start_frame": 25,
            "animation_duration_frames": 35,
            "return_action": "faceupidle",
        },
        "facedown_low_impact": false,
        "facedown_getup": true,
    },

    "res://data/fighting_set_m03_mapped_attacks.json": {
        "source_archive": "thai.set",
        "link_tag": "brick",
        "native_links": BRICK_NATIVE_LINKS_PATH,
        "facedown_idle_clip": BRICK_FACEDOWN_IDLE_CLIP,
        "facedown_impact_radius": BRICK_FACEDOWN_IMPACT_RADIUS,
        "front_low_clip": BRICK_FRONT_LOW_CLIP,
        "front_low_reaction": BRICK_FRONT_LOW_REACTION,
        "front_high_reaction": {
            "animation": "all_impct_hard_frnt_high",
            "animation_radius": 70.0,
            "exit_start_frame": 23,
            "animation_duration_frames": 35,
            "return_action": "faceupidle",
        },
        "facedown_low_impact": true,
        "facedown_getup": false,
    },
    "res://data/attack_config_master.json": {
        "source_archive": "kungfu.set",
        "link_tag": "themaster",
        "native_links": KUNGFU_NATIVE_LINKS_PATH,
        "facedown_idle_clip": FACEDOWN_IDLE_CLIP,
        "facedown_impact_radius": 80.0,
        "front_low_clip": "all_impct_hard_frnt_low",
        # kungfu.set: impacthardfrontlow -> facedownidle [13,23]
        "front_low_reaction": {
            "source_action": "impacthardfrontlow",
            "animation": "all_impct_hard_frnt_low",
            "animation_radius": 75.0,
            "exit_start_frame": 13,
            "animation_duration_frames": 23,
            "return_action": "facedownidle",
        },
        # kungfu.set: impacthardfronthigh -> faceupidle [25,35]
        "front_high_reaction": {
            "animation": "all_impct_hard_frnt_high",
            "animation_radius": 70.0,
            "exit_start_frame": 25,
            "animation_duration_frames": 35,
            "return_action": "faceupidle",
        },
        "facedown_low_impact": false,
        "facedown_getup": true,
    },
    "res://data/attack_config_sinfu.json": {
        "source_archive": "kungfu.set",
        "link_tag": "sinfu",
        "native_links": KUNGFU_NATIVE_LINKS_PATH,
        "facedown_idle_clip": FACEDOWN_IDLE_CLIP,
        "facedown_impact_radius": 80.0,
        "front_low_clip": "all_impct_hard_frnt_low",
        "front_low_reaction": {
            "source_action": "impacthardfrontlow",
            "animation": "all_impct_hard_frnt_low",
            "animation_radius": 75.0,
            "exit_start_frame": 13,
            "animation_duration_frames": 23,
            "return_action": "facedownidle",
        },
        "front_high_reaction": {
            "animation": "all_impct_hard_frnt_high",
            "animation_radius": 70.0,
            "exit_start_frame": 25,
            "animation_duration_frames": 35,
            "return_action": "faceupidle",
        },
        "facedown_low_impact": false,
        "facedown_getup": true,
    },
    "res://data/attack_config_ken.json": {
        "source_archive": "karate.set",
        "link_tag": "ken",
        "native_links": KARATE_NATIVE_LINKS_PATH,
        "facedown_idle_clip": FACEDOWN_IDLE_CLIP,
        "facedown_impact_radius": 80.0,
        "front_low_clip": "all_impct_hard_frnt_low",
        # karate.set: impacthardfrontlow -> facedownidle [13,23]
        "front_low_reaction": {
            "source_action": "impacthardfrontlow",
            "animation": "all_impct_hard_frnt_low",
            "animation_radius": 80.0,
            "exit_start_frame": 13,
            "animation_duration_frames": 23,
            "return_action": "facedownidle",
        },
        # karate.set: impacthardfronthigh -> faceupidle [20,35]
        "front_high_reaction": {
            "animation": "all_impct_hard_frnt_high",
            "animation_radius": 80.0,
            "exit_start_frame": 20,
            "animation_duration_frames": 35,
            "return_action": "faceupidle",
        },
        "facedown_low_impact": false,
        "facedown_getup": true,
    },
    "res://data/attack_config_smallboy.json": {
        "source_archive": "thai.set",
        "link_tag": "smallboy",
        "native_links": BRICK_NATIVE_LINKS_PATH,
        "facedown_idle_clip": BRICK_FACEDOWN_IDLE_CLIP,
        "facedown_impact_radius": BRICK_FACEDOWN_IMPACT_RADIUS,
        "front_low_clip": BRICK_FRONT_LOW_CLIP,
        "front_low_reaction": BRICK_FRONT_LOW_REACTION,
        "front_high_reaction": {
            "animation": "all_impct_hard_frnt_high",
            "animation_radius": 70.0,
            "exit_start_frame": 23,
            "animation_duration_frames": 35,
            "return_action": "faceupidle",
        },
        "facedown_low_impact": true,
        "facedown_getup": false,
    },
    "res://data/attack_config_johnson.json": {
        "source_archive": "thai.set",
        "link_tag": "johnson",
        "native_links": BRICK_NATIVE_LINKS_PATH,
        "facedown_idle_clip": BRICK_FACEDOWN_IDLE_CLIP,
        "facedown_impact_radius": BRICK_FACEDOWN_IMPACT_RADIUS,
        "front_low_clip": BRICK_FRONT_LOW_CLIP,
        "front_low_reaction": BRICK_FRONT_LOW_REACTION,
        "front_high_reaction": {
            "animation": "all_impct_hard_frnt_high",
            "animation_radius": 70.0,
            "exit_start_frame": 23,
            "animation_duration_frames": 35,
            "return_action": "faceupidle",
        },
        "facedown_low_impact": true,
        "facedown_getup": false,
    },
    "res://data/attack_config_chief.json": {
        "source_archive": "karate.set",
        "link_tag": "chief",
        "native_links": KARATE_NATIVE_LINKS_PATH,
        "facedown_idle_clip": FACEDOWN_IDLE_CLIP,
        "facedown_impact_radius": 80.0,
        "front_low_clip": "all_impct_hard_frnt_low",
        # karate.set: impacthardfrontlow -> facedownidle [13,23]
        "front_low_reaction": {
            "source_action": "impacthardfrontlow",
            "animation": "all_impct_hard_frnt_low",
            "animation_radius": 80.0,
            "exit_start_frame": 13,
            "animation_duration_frames": 23,
            "return_action": "facedownidle",
        },
        # karate.set: impacthardfronthigh -> faceupidle [20,35]
        "front_high_reaction": {
            "animation": "all_impct_hard_frnt_high",
            "animation_radius": 80.0,
            "exit_start_frame": 20,
            "animation_duration_frames": 35,
            "return_action": "faceupidle",
        },
        "facedown_low_impact": false,
        "facedown_getup": true,
    },
    "res://data/attack_config_loming.json": {
        "source_archive": "kungfu.set",
        "link_tag": "loming",
        "native_links": KUNGFU_NATIVE_LINKS_PATH,
        "facedown_idle_clip": FACEDOWN_IDLE_CLIP,
        "facedown_impact_radius": 80.0,
        "front_low_clip": "all_impct_hard_frnt_low",
        "front_low_reaction": {
            "source_action": "impacthardfrontlow",
            "animation": "all_impct_hard_frnt_low",
            "animation_radius": 75.0,
            "exit_start_frame": 13,
            "animation_duration_frames": 23,
            "return_action": "facedownidle",
        },
        "front_high_reaction": {
            "animation": "all_impct_hard_frnt_high",
            "animation_radius": 70.0,
            "exit_start_frame": 25,
            "animation_duration_frames": 35,
            "return_action": "faceupidle",
        },
        "facedown_low_impact": false,
        "facedown_getup": true,
    },
}
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
const ATTACK_TO_FLOOR_EXIT_START_FRAME: int = 80
## Recovered candobasicattacks group windows (tools/kdf_combo_group_inventory.py):
## brucelee.set m01_attack_to_floor [45,90] and thai.set m03_attack_to_floor
## [45,61].  The group window is when a candobasicattacks link may start, so the
## action is cancellable from frame 45 even though its own exit link to idle2
## only opens at frame 80 (Bruce) / 61 (Brick).  The prototype used 80 as the
## cancel start, which is 35 frames late.
const ATTACK_CANCEL_START_FRAMES: Dictionary = {"attacktofloor": 45}
const ATTACK_TO_FLOOR_DAMAGE_START_FRAME: int = 18
const ATTACK_TO_FLOOR_DAMAGE_END_FRAME: int = 23
const ATTACK_TO_FLOOR_DAMAGE: float = 6.0
const ATTACK_TO_FLOOR_RADIUS: float = 60.0
const ATTACK_TO_FLOOR_IMPACT: Dictionary = {
    "strength": "normal", "height": "low", "direction": "frontal",
    "body_part": "lleg", "attack_radius": ATTACK_TO_FLOOR_RADIUS,
}
# Link input follows the decompiled CFighter::UserControlUpdate model: events
# stay in a queue with a consumed bit, and every physics update re-evaluates
# each link against the current animation's frame window. There is no
# wall-clock combo window and no FIFO of attacks.
# CBeatEmUpGame::Update compares the last event's timestamp (+0x0c) + 500 with
# the update time; the timestamp comes from krt::time::GetCurrentMili(), so the
# lifetime is 500 milliseconds. Expiry marks the whole vector consumed.
const LINK_EVENT_LIFETIME_MS: int = 500
const NATIVE_LINKS_PATH: String = "res://data/native_links.json"
const BRICK_NATIVE_LINKS_PATH: String = "res://data/native_links_brick.json"
# adreno_200/input.config: control_profile 0 is the touch layout (a/b only),
# 1 is the ZDK keyboard layout (a/b/c/d). CBeatEmUpMatch::LoadFighter receives
# the current input layout and writes it to fighter+0x1c, which
# CLinkDescr::GetKeySequence(index) uses to pick one of the stored variants.
# The PC port runs the keyboard layout, so variant 1 is the native sequence.
const LINK_SEQUENCE_INDEX: int = 1
# CFighter::CheckConditions @0x1b3db0 compares fighter+0x14c (rage) with
# <100 / <0x42(66) / <0x21(33) for MaxRage/Rage2Thirds/RageThird.
const RAGE_MAX: float = 100.0
# PC arena footprint, derived from the original Temple Yard combatarea mesh:
# 879.94 source units wide / 907.73 deep at 0.01038 world/source units.
const ARENA_HALF_X: float = 4.55
const ARENA_HALF_Z: float = 4.70
const STUN_CLIP: String = "all_stunned"
const STUN_FALL_CLIP: String = "all_stunned_fall"
# Source windows: stun->stun2 and stun2->stunfall [55,61]; stunfall->faceupko [71,79].
# The PC candidate selects each window start.
const STUN_DURATION_FRAMES: int = 55
const STUN_FALL_DURATION_FRAMES: int = 71
const STUN_IMPACT_ENTRY_FRAMES: int = 14
const GRAB_ATTACKS: Dictionary = {
    "grab1": true, "grab2": true, "grab1_brick": true, "grab2_brick": true,
}
# Victim state after a Brick grab hit; source grabcompl1/2 -> facedown/faceup.
const GRAB_VICTIM_DATA: Dictionary = {
    # Bruce grab attacks and Brick grab attacks share the universal victim
    # clips; the victim candidate must contain them (63-victim for Bruce,
    # and a Brick candidate with all_grabbed_* for Brick).
    "grab1": ["grabbed1", 90, "facedownidle"],
    "grab2": ["grabbed2", 78, "faceupidle"],
    "grab1_brick": ["grabbed1", 90, "facedownidle"],
    "grab2_brick": ["grabbed2", 78, "faceupidle"],
}
# Attacker endattack consumes the grabbed victim into endattackcomp -> faceupko.
const ENDATTACK_VICTIM_DATA: Dictionary = {
    "grabbed1": ["endattackcomp1", 93],
    "grabbed2": ["endattackcomp2", 130],
}
# "endattack" is the mapped-set finisher name (kungfu/karate); without it the
# victim of a Ken/Master/SinFu finisher is never consumed and endattackcomp is
# unreachable for those sets.
const ENDATTACK_ATTACKS: Dictionary = {
    "endattack1": true, "endattack2": true, "endattack": true,
}
# brucelee.set stores one grabbed victim action per attacker, e.g.
# "grabcompl1 ken" -> all_grabbed_01_forset02. The victim candidate's static map
# only carries the Thai (forset03) clip, so the grab resolves the opponent's set
# from this table at runtime. Keyed by the attacker's config path.
const VICTIM_OPPONENT_SUFFIX: Dictionary = {
    "res://data/attack_config_smallboy.json": "brick",
    "res://data/attack_config_johnson.json": "brick",
    "res://data/attack_config_chief.json": "ken",
    "res://data/attack_config_loming.json": "sinfu",
    "res://data/fighting_set_m03_mapped_attacks.json": "brick",
    "res://data/attack_config_master.json": "master",
    "res://data/attack_config_sinfu.json": "sinfu",
    "res://data/attack_config_ken.json": "ken",
}
# endattackcomp names its per-attacker actions by set family: only thai and
# karate have one. kungfu has no endattackcomp action, so it must fail closed.
const ENDATTACK_OPPONENT_ACTION: Dictionary = {
    "res://data/attack_config_smallboy.json": "endattackcompthai",
    "res://data/attack_config_johnson.json": "endattackcompthai",
    "res://data/attack_config_chief.json": "endattackcompkarate",
    "res://data/fighting_set_m03_mapped_attacks.json": "endattackcompthai",
    "res://data/attack_config_ken.json": "endattackcompkarate",
}
# ---------------------------------------------------------------------------
# Size-class animation versions (recovered).
#
# adreno_200/Animations.versions lists alternate clip files for one base clip:
# {"binary": <base clip>, "versions": [{"my_skeleton"|"opp_skeleton": <class>,
# "binary": <version clip>}]}. characters.list gives every fighter its class in
# the "skeleton" field (small / medium / large). A version exists only for
# small and large, so a medium fighter plays the base clip.
#
# The port plays the version the original table selects for the grab and grab
# finisher slots. A required version that the loaded candidate lacks is never
# replaced by the wrong-size clip: the grab/finisher fails closed instead.
#
# The same table also versions all_idle_face_down/up (ground idles, audience
# "self") and m01_sp_pnch_high (the special high punch, audience "opponent").
# Both are selected here as well: the ground idles by the downed fighter's own
# class, the special high punch by the opponent's class.
const SIZE_VARIANTS_PATH: String = "res://data/size_variants.json"
const SIZE_CLASS_SMALL: String = "small"
const SIZE_CLASS_MEDIUM: String = "medium"
const SIZE_CLASS_LARGE: String = "large"
# Attack slots whose original clips carry size versions. Kept explicit so the
# resolved clip can only replace a slot that really has a recovered version.
const SIZE_CLASS_ATTACKS: Dictionary = {
    "grab1": true, "grab2": true,
    "grab1_brick": true, "grab2_brick": true,
    "grab1_miss": true, "grab2_miss": true,
    "grab1_miss_brick": true, "grab2_miss_brick": true,
    "endattack1": true, "endattack2": true,
    "endattack": true, "endattack_brick": true,
    # m01_sp_pnch_high also carries size versions (audience "opponent"); only
    # the hit variant maps it, the miss/fail clip is unversioned.
    "special_punch_high_hit": true,
}
const NON_CONTACT_ATTACKS: Dictionary = {
    "endattack1": true, "endattack2": true, "endattack": true,
    "parry_low": true,
    "parry_high_brick": true, "parry_low_brick": true,
    "endattack_brick": true,
    "grab1_miss_brick": true, "grab2_miss_brick": true,
}
# Each sequence is a list of simultaneous-token steps, matching the native
# keysequence shape. Direction tokens (up/down/in/out) are produced by the PC
# prototype input layer and are not recovered Android physical keys.
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
    "parry_high": [10, 62],
    "parry_low": [10, 27],
    "parry_attack": [15, 85],
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
        "body_part": "rarm",
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
    "idle3": "stand",
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
    "m01_idle_03": 40.0,
    "m01_movebck": 40.0,
    "m01_moverht": 25.0,
    "m01_movelft": 35.0,
    "m01_stepfwd": 40.0,
    "m01_stepbck": 40.0,
    "m01_steplft": 40.0,
    "m01_steprht": 40.0,
    "all_idle_face_down": 75.0,
    "all_idle_face_down_forbigguy": 75.0,
    "all_getup_facedwn": 25.0,
    "all_impct_facedwn": 80.0,
    "all_impct_hard_rht_high": 80.0,
    "all_getup_facedwn_attack": 45.0,
    "all_stunned": 40.0,
    "all_stunned_fall": 70.0,
    "all_idle_face_up": 75.0,
    "all_getup_faceup": 40.0,
    "all_getup_faceup_attack": 45.0,
    "all_impct_faceup": 80.0,
}
# stunimpact uses action-specific radii for the same source ANMs.
const STUN_IMPACT_SOURCE_RADII: Dictionary = {
    "stun_hard": 85.0,
    "stun_brutal": 25.0,
    "all_impct_light_frnt_high": 40.0,
    "all_impct_light_frnt_low": 25.0,
    "all_impct_crotch": 40.0,
}
const REACTION_ROOT_PUSH_SOURCE: Dictionary = {
    "impactlightfronthigh": 36.86962890625,
    "impactlightfrontlow": 18.252197265625,
    "impactlightfrontmid": 22.845458984375,
    # Prototype input: the maximum absolute value among the first two raw
    # position components of the decoded reaction clip. This is not a native
    # axis/sign or final-knockback mapping claim.
    "impactbrutalleft": 187.198974609375,
    "impactbrutalmid": 181.56494140625,
    "impactbrutalright": 187.095458984375,
    "impacthardabove": 35.1337890625,
    "impacthardfronthigh": 200.7998046875,
    "impacthardfrontlow": 3.348388671875,
    "impacthardfrontmid": 69.15380859375,
    "impacthardlefthigh": 199.577880859375,
    "impacthardleftlow": 37.691650390625,
    "impacthardrighthigh": 194.52294921875,
    "impactlightleftlow": 7.284912109375,
    "impactlightrightlow": 21.27294921875,
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
    "m03_pnch_high_01": 43.0,
    "m03_pnch_high_02": 43.0,
    "m03_pnch_high_03": 50.0,
    "m03_pnch_low_03": 40.0,
    "m03_pnch_low_02": 40.0,
    "m03_kck_high_01": 30.0,
    "m03_kck_high_02": 30.0,
    "m03_kck_high_03": 45.0,
    "m03_kck_low_02": 50.0,
    "m03_kck_low_03": 50.0,
}
const THAI_ATTACK_DATA: Dictionary = {
    "punch": ["lowpunch3", "m03_pnch_low_01", 38, 8, 4, 26, 7.0, 80.0, "larm", "medium", "hard", "frontal"],
    "kick": ["lowkick3", "m03_kck_low_01", 41, 9, 3, 29, 7.0, 70.0, "lleg", "low", "hard", "fromright"],
    "high_punch": ["highpunch1", "m03_pnch_high_01", 19, 6, 3, 10, 5.0, 72.0, "larm", "high", "normal", "frontal"],
    "high_punch2": ["highpunch2", "m03_pnch_high_02", 31, 8, 4, 19, 7.0, 65.0, "rarm", "high", "normal", "fromleft"],
    "high_punch3": ["highpunch3", "m03_pnch_high_03", 35, 11, 4, 20, 8.0, 70.0, "larm", "high", "hard", "fromleft"],
    "low_punch": ["lowpunch1", "m03_pnch_low_03", 27, 9, 4, 14, 6.0, 62.0, "rarm", "medium", "normal", "frontal"],
    "low_punch2": ["lowpunch2", "m03_pnch_low_02", 35, 9, 4, 22, 6.0, 70.0, "larm", "medium", "normal", "frontal"],
    "low_punch3": ["lowpunch3", "m03_pnch_low_01", 38, 8, 4, 26, 7.0, 80.0, "larm", "medium", "hard", "frontal"],
    "high_kick": ["highkick1", "m03_kck_high_01", 44, 12, 4, 28, 6.0, 65.0, "lleg", "high", "normal", "frontal"],
    "high_kick2": ["highkick2", "m03_kck_high_02", 49, 9, 5, 35, 7.0, 65.0, "lleg", "high", "normal", "frontal"],
    "high_kick3": ["highkick3", "m03_kck_high_03", 47, 12, 4, 31, 8.0, 70.0, "lleg", "high", "hard", "fromright"],
    "low_kick": ["lowkick1", "m03_kck_low_02", 46, 6, 5, 35, 5.0, 65.0, "lleg", "medium", "normal", "frontal"],
    "low_kick2": ["lowkick2", "m03_kck_low_03", 37, 8, 4, 25, 6.0, 65.0, "rleg", "medium", "normal", "frontal"],
    "low_kick3": ["lowkick3", "m03_kck_low_01", 41, 9, 3, 29, 7.0, 70.0, "lleg", "low", "hard", "fromright"],
    "special_kick_high_brick": ["specialkickhigh brick", "m03_sp_kck_high", 73, 23, 6, 44, 10.0, 55.0, "lleg", "high", "hard", "frontal"],
    "special_kick_low_brick": ["specialkicklow brick", "m03_sp_kck_low", 56, 13, 5, 38, 9.0, 75.0, "rleg", "low", "hard", "fromleft"],
    "special_punch_high_brick": ["specialpunchhigh brick", "m03_sp_pnch_high", 54, 11, 4, 39, 11.0, 65.0, "rarm", "high", "hard", "fromright"],
    "special_punch_low_brick": ["specialpunchlow brick", "m03_sp_pnch_low", 44, 15, 4, 25, 8.0, 75.0, "rarm", "medium", "brutal", "frontal"],
    "parry_high_brick": ["parryhigh", "m03_parry_high", 43, 9, 1, 33, 0.0, 40.0, "larm", "high", "normal", "frontal"],
    "parry_low_brick": ["parrylow", "m03_parry_low", 41, 9, 1, 31, 0.0, 40.0, "larm", "low", "normal", "frontal"],
    "parry_attack_brick": ["parryattack", "m03_pnch_high_03", 35, 10, 5, 20, 10.0, 65.0, "rarm", "high", "hard", "frontal"],
    "grab1_brick": ["grab1 brick", "m03_grab_01", 90, 19, 2, 69, 6.0, 45.0, "larm", "high", "normal", "frontal"],
    "grab2_brick": ["grab2 brick", "m03_grab_02", 78, 46, 3, 29, 20.0, 45.0, "larm", "high", "hard", "frontal"],
    "attack_to_floor_brick": ["attacktofloor", "m03_attack_to_floor", 61, 11, 5, 45, 6.0, 35.0, "lleg", "low", "normal", "frontal"],
    "endattack_brick": ["endattack brick", "m03_end_attack_01", 93, 17, 3, 73, 0.0, 75.0, "rleg", "high", "brutal", "fromleft"],
    "grab1_miss_brick": ["grab1miss brick", "m02_grab_01", 47, 5, 3, 39, 0.0, 45.0, "larm", "high", "normal", "frontal"],
    "grab2_miss_brick": ["grab2miss brick", "m02_grab_01", 47, 4, 4, 39, 0.0, 45.0, "larm", "high", "normal", "frontal"],
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
# Recovered per-character tables (see data/attack_config_*.json and
# evidence/set_action_tables.md). The parser compares the JSON against
# these rows so a config edit that drifts from the fighting set fails closed.
const MASTER_ANIMATION_RADII_DATA: Dictionary = {
    "all_block_high": 60.0,
    "all_block_low": 60.0,
    "all_block_mid": 60.0,
    "all_impct_light_frnt_high": 40.0,
    "all_impct_light_frnt_low": 50.0,
    "all_impct_light_frnt_mid": 40.0,
    "m01_attack_to_floor": 45.0,
    "m01_kick_low_02": 40.0,
    "m01_parry_high": 40.0,
    "m04_e01_idle_01": 35.0,
    "m04_e01_kck_high_03": 45.0,
    "m04_e01_kck_low_03": 45.0,
    "m04_e01_pnch_high_03": 65.0,
    "m04_e01_pnch_low_03": 40.0,
    "m04_end_attack_02": 25.0,
    "m04_kck_high_01": 50.0,
    "m04_kck_high_02": 50.0,
    "m04_kck_high_03": 40.0,
    "m04_kck_low_01": 50.0,
    "m04_kck_low_02": 50.0,
    "m04_kck_low_03": 50.0,
    "m04_pnch_high_01": 40.0,
    "m04_pnch_high_02": 25.0,
    "m04_pnch_high_03": 60.0,
    "m04_pnch_low_01": 40.0,
    "m04_pnch_low_02": 40.0,
    "m04_pnch_low_03": 40.0,
    "m04_sp_kck_low": 25.0,
    "m04_sp_pnch_low": 25.0,
}
const MASTER_ATTACK_DATA: Dictionary = {
    "punch": ["lowpunch3", "m04_pnch_low_03", 71, 10, 6, 55, 7.0, 85.0, "larm", "medium", "hard", "frontal"],
    "kick": ["lowkick3", "m04_kck_low_02", 34, 6, 4, 24, 7.0, 100.0, "lleg", "low", "hard", "fromright"],
    "high_punch": ["highpunch1", "m04_pnch_high_01", 68, 6, 5, 57, 5.0, 75.0, "larm", "high", "normal", "frontal"],
    "high_punch2": ["highpunch2", "m04_pnch_high_02", 50, 6, 5, 39, 6.0, 65.0, "rarm", "high", "normal", "frontal"],
    "high_punch3": ["highpunch3", "m04_pnch_high_03", 50, 15, 8, 27, 7.0, 75.0, "larm", "high", "hard", "fromabove"],
    "low_punch": ["lowpunch1", "m04_pnch_low_01", 48, 5, 5, 38, 6.0, 70.0, "larm", "medium", "normal", "frontal"],
    "low_punch2": ["lowpunch2", "m04_pnch_low_02", 64, 8, 4, 52, 6.0, 85.0, "larm", "medium", "normal", "frontal"],
    "low_punch3": ["lowpunch3", "m04_pnch_low_03", 71, 10, 6, 55, 7.0, 85.0, "larm", "medium", "hard", "frontal"],
    "high_kick": ["highkick1", "m04_kck_high_01", 53, 9, 6, 38, 5.0, 80.0, "rleg", "high", "normal", "frontal"],
    "high_kick2": ["highkick2", "m04_kck_high_02", 43, 6, 6, 31, 6.0, 80.0, "rleg", "high", "normal", "fromright"],
    "high_kick3": ["highkick3", "m04_kck_high_03", 60, 9, 5, 46, 7.0, 80.0, "lleg", "high", "hard", "fromleft"],
    "low_kick": ["lowkick1", "m04_kck_low_03", 22, 6, 5, 11, 5.0, 70.0, "lleg", "low", "normal", "frontal"],
    "low_kick2": ["lowkick2", "m04_kck_low_01", 34, 5, 5, 24, 5.0, 100.0, "lleg", "low", "normal", "fromleft"],
    "low_kick3": ["lowkick3", "m04_kck_low_02", 34, 6, 4, 24, 7.0, 100.0, "lleg", "low", "hard", "fromright"],
    "special_kick_high": ["specialkickhigh master", "m04_e01_kck_high_03", 73, 14, 3, 56, 12.0, 95.0, "rleg", "high", "brutal", "fromright"],
    "special_kick_low": ["specialkicklow master", "m04_e01_kck_low_03", 153, 15, 4, 134, 10.0, 90.0, "rleg", "low", "hard", "fromright"],
    "special_punch_high": ["specialpunchhigh master", "m04_e01_pnch_high_03", 62, 7, 4, 51, 10.0, 135.0, "larm", "high", "hard", "frontal"],
    "special_punch_low": ["specialpunchlow master", "m04_e01_pnch_low_03", 82, 4, 25, 53, 16.0, 65.0, "larm", "low", "normal", "frontal"],
    "parry_high": ["parryhigh", "m01_parry_high", 62, 9, 2, 51, 0.0, 40.0, "larm", "high", "normal", "frontal"],
    "parry_low": ["parrylow", "m01_kick_low_02", 27, 7, 4, 16, 0.0, 65.0, "rleg", "low", "normal", "frontal"],
    "parry_attack": ["parryattack", "m04_pnch_high_02", 50, 6, 5, 39, 10.0, 65.0, "rarm", "high", "hard", "frontal"],
    "grab1": ["grab1 master", "m04_sp_pnch_low", 28, 7, 2, 19, 20.0, 45.0, "larm", "high", "hard", "frontal"],
    "grab2": ["grab2 master", "m04_sp_kck_low", 55, 12, 12, 31, 20.0, 45.0, "larm", "low", "hard", "frontal"],
    "grab1_miss": ["grab1miss master", "m04_sp_pnch_low", 28, 5, 3, 20, 0.0, 45.0, "larm", "high", "normal", "frontal"],
    "grab2_miss": ["grab2miss master", "m04_sp_kck_low", 55, 4, 4, 47, 0.0, 45.0, "larm", "high", "normal", "frontal"],
    "attack_to_floor": ["attacktofloor", "m01_attack_to_floor", 90, 18, 5, 67, 6.0, 60.0, "lleg", "low", "normal", "frontal"],
    "endattack": ["endattack master", "m04_end_attack_02", 75, 37, 4, 34, 0.0, 75.0, "lleg", "high", "brutal", "fromleft"],
}
const MASTER_REACTION_PROFILE_DATA: Dictionary = {
    "hit": {
        "low": {
            "source_action": "impactlightfrontlow",
            "animation": "all_impct_light_frnt_low",
            "animation_radius": 50.0,
            "exit_start_frame": 14,
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
            "exit_start_frame": 16,
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
            "animation_radius": 60.0,
            "exit_start_frame": 10,
            "animation_duration_frames": 23,
            "linking_frame": 14,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
        "medium": {
            "source_action": "midblock",
            "animation": "all_block_mid",
            "animation_radius": 60.0,
            "exit_start_frame": 12,
            "animation_duration_frames": 14,
            "linking_frame": 0,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
        "high": {
            "source_action": "highblock",
            "animation": "all_block_high",
            "animation_radius": 60.0,
            "exit_start_frame": 12,
            "animation_duration_frames": 14,
            "linking_frame": 0,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
    },
}

const SINFU_ANIMATION_RADII_DATA: Dictionary = {
    "all_block_high": 60.0,
    "all_block_low": 60.0,
    "all_block_mid": 60.0,
    "all_impct_light_frnt_high": 40.0,
    "all_impct_light_frnt_low": 50.0,
    "all_impct_light_frnt_mid": 40.0,
    "m01_attack_to_floor": 45.0,
    "m01_kick_low_02": 40.0,
    "m01_parry_high": 40.0,
    "m02_grab_01": 25.0,
    "m04_e02_idle_01": 50.0,
    "m04_e02_kck_high_03": 50.0,
    "m04_e02_kck_low_03": 55.0,
    "m04_e02_pnch_low_03": 55.0,
    "m04_end_attack_02": 25.0,
    "m04_grab_01": 25.0,
    "m04_kck_high_01": 50.0,
    "m04_kck_high_02": 50.0,
    "m04_kck_high_03": 40.0,
    "m04_kck_low_01": 50.0,
    "m04_kck_low_02": 50.0,
    "m04_kck_low_03": 50.0,
    "m04_pnch_high_01": 40.0,
    "m04_pnch_high_02": 25.0,
    "m04_pnch_high_03": 60.0,
    "m04_pnch_low_01": 40.0,
    "m04_pnch_low_02": 40.0,
    "m04_pnch_low_03": 40.0,
    "m04_sp_kck_low": 25.0,
    "m04_sp_pnch_high": 25.0,
    "m04_sp_pnch_high_fail": 40.0,
}
const SHENLO_ANIMATION_RADII_DATA: Dictionary = {
    "m01_attack_to_floor": 45.0,
    "m01_kick_low_02": 40.0,
    "m01_parry_high": 40.0,
    "m02_grab_01": 25.0,
    "m04_e02_kck_high_03": 50.0,
    "m04_e02_kck_low_03": 55.0,
    "m04_e02_pnch_low_03": 55.0,
    "m04_e03_idle_01": 45.0,
    "m04_e03_kck_high_03": 55.0,
    "m04_e03_kck_low_03": 50.0,
    "m04_e03_movebck": 40.0,
    "m04_e03_movefwd": 40.0,
    "m04_e03_pnch_high_03": 35.0,
    "m04_e03_pnch_low_03": 40.0,
    "m04_e03_steplft": 40.0,
    "m04_e03_steprht": 40.0,
    "m04_end_attack_01": 35.0,
    "m04_end_attack_02": 25.0,
    "m04_grab_01": 25.0,
    "m04_grab_02": 25.0,
    "m04_kck_high_01": 50.0,
    "m04_kck_high_02": 50.0,
    "m04_kck_high_03": 40.0,
    "m04_kck_low_01": 50.0,
    "m04_kck_low_02": 50.0,
    "m04_kck_low_03": 50.0,
    "m04_movebck": 40.0,
    "m04_movefwd": 40.0,
    "m04_movelft": 25.0,
    "m04_moverht": 35.0,
    "m04_pnch_high_01": 40.0,
    "m04_pnch_high_02": 25.0,
    "m04_pnch_high_03": 60.0,
    "m04_pnch_low_01": 40.0,
    "m04_pnch_low_02": 40.0,
    "m04_pnch_low_03": 40.0,
    "m04_sp_kck_low": 25.0,
    "m04_sp_pnch_high": 25.0,
    "m04_sp_pnch_high_fail": 40.0,
    "m04_stepbck": 40.0,
    "m04_stepfwd": 35.0,
    "m04_steplft": 40.0,
    "m04_steprht": 40.0,
}
const SHENLO_ATTACK_DATA: Dictionary = {
    "punch": ["lowpunch3", "m04_pnch_low_03", 71, 10, 6, 55, 7.0, 85.0, "larm", "medium", "hard", "frontal"],
    "kick": ["lowkick3", "m04_kck_low_02", 34, 6, 4, 24, 7.0, 100.0, "lleg", "low", "hard", "fromright"],
    "high_punch": ["highpunch1", "m04_pnch_high_01", 68, 6, 5, 57, 5.0, 75.0, "larm", "high", "normal", "frontal"],
    "high_punch2": ["highpunch2", "m04_pnch_high_02", 50, 6, 5, 39, 6.0, 65.0, "rarm", "high", "normal", "frontal"],
    "high_punch3": ["highpunch3", "m04_pnch_high_03", 50, 15, 8, 27, 7.0, 75.0, "larm", "high", "hard", "fromabove"],
    "low_punch": ["lowpunch1", "m04_pnch_low_01", 48, 5, 5, 38, 6.0, 70.0, "larm", "medium", "normal", "frontal"],
    "low_punch2": ["lowpunch2", "m04_pnch_low_02", 64, 8, 4, 52, 6.0, 85.0, "larm", "medium", "normal", "frontal"],
    "low_punch3": ["lowpunch3", "m04_pnch_low_03", 71, 10, 6, 55, 7.0, 85.0, "larm", "medium", "hard", "frontal"],
    "high_kick": ["highkick1", "m04_kck_high_01", 53, 9, 6, 38, 5.0, 80.0, "rleg", "high", "normal", "frontal"],
    "high_kick2": ["highkick2", "m04_kck_high_02", 43, 6, 6, 31, 6.0, 80.0, "rleg", "high", "normal", "fromright"],
    "high_kick3": ["highkick3", "m04_kck_high_03", 60, 9, 5, 46, 7.0, 80.0, "lleg", "high", "hard", "fromleft"],
    "low_kick": ["lowkick1", "m04_kck_low_03", 22, 6, 5, 11, 5.0, 70.0, "lleg", "low", "normal", "frontal"],
    "low_kick2": ["lowkick2", "m04_kck_low_01", 34, 5, 5, 24, 5.0, 100.0, "lleg", "low", "normal", "fromleft"],
    "low_kick3": ["lowkick3", "m04_kck_low_02", 34, 6, 4, 24, 7.0, 100.0, "lleg", "low", "hard", "fromright"],
    "special_kick_high": ["specialkickhigh shenlo", "m04_e03_kck_high_03", 169, 9, 6, 154, 10.0, 80.0, "lleg", "high", "hard", "frontal"],
    "special_kick_low": ["specialkicklow shenlo", "m04_e03_kck_low_03", 194, 10, 5, 179, 6.0, 70.0, "rleg", "low", "normal", "fromleft"],
    "special_punch_low": ["specialpunchlow shenlo", "m04_e03_pnch_low_03", 83, 16, 5, 62, 7.0, 85.0, "rarm", "medium", "hard", "frontal"],
    "parry_high": ["parryhigh", "m01_parry_high", 62, 9, 2, 51, 0.0, 40.0, "larm", "high", "normal", "frontal"],
    "parry_low": ["parrylow", "m01_kick_low_02", 27, 7, 4, 16, 0.0, 65.0, "rleg", "low", "normal", "frontal"],
    "parry_attack": ["parryattack", "m04_pnch_high_02", 50, 6, 5, 39, 10.0, 65.0, "rarm", "high", "hard", "frontal"],
    "grab1": ["grab1 shenlo", "m04_grab_01", 103, 35, 10, 58, 20.0, 45.0, "larm", "high", "hard", "frontal"],
    "grab2": ["grab2 shenlo", "m04_grab_02", 45, 7, 3, 35, 5.0, 45.0, "larm", "high", "hard", "frontal"],
    "grab1_miss": ["grab1miss shenlo", "m02_grab_01", 47, 5, 3, 39, 0.0, 45.0, "larm", "high", "normal", "frontal"],
    "grab2_miss": ["grab2miss shenlo", "m04_grab_02", 45, 4, 4, 37, 0.0, 45.0, "larm", "high", "normal", "frontal"],
    "attack_to_floor": ["attacktofloor", "m01_attack_to_floor", 90, 18, 5, 67, 6.0, 60.0, "lleg", "low", "normal", "frontal"],
    "endattack": ["endattack shenlo", "m04_end_attack_01", 93, 17, 5, 71, 0.0, 80.0, "rleg", "high", "hard", "fromleft"],
    "special_punch_high": ["specialpunchhigh shenlo", "m04_e03_pnch_high_03", 115, 14, 5, 96, 7.0, 75.0, "larm", "high", "hard", "fromleft"],
}
const SINFU_ATTACK_DATA: Dictionary = {
    "punch": ["lowpunch3", "m04_pnch_low_03", 71, 10, 6, 55, 7.0, 85.0, "larm", "medium", "hard", "frontal"],
    "kick": ["lowkick3", "m04_kck_low_02", 34, 6, 4, 24, 7.0, 100.0, "lleg", "low", "hard", "fromright"],
    "high_punch": ["highpunch1", "m04_pnch_high_01", 68, 6, 5, 57, 5.0, 75.0, "larm", "high", "normal", "frontal"],
    "high_punch2": ["highpunch2", "m04_pnch_high_02", 50, 6, 5, 39, 6.0, 65.0, "rarm", "high", "normal", "frontal"],
    "high_punch3": ["highpunch3", "m04_pnch_high_03", 50, 15, 8, 27, 7.0, 75.0, "larm", "high", "hard", "fromabove"],
    "low_punch": ["lowpunch1", "m04_pnch_low_01", 48, 5, 5, 38, 6.0, 70.0, "larm", "medium", "normal", "frontal"],
    "low_punch2": ["lowpunch2", "m04_pnch_low_02", 64, 8, 4, 52, 6.0, 85.0, "larm", "medium", "normal", "frontal"],
    "low_punch3": ["lowpunch3", "m04_pnch_low_03", 71, 10, 6, 55, 7.0, 85.0, "larm", "medium", "hard", "frontal"],
    "high_kick": ["highkick1", "m04_kck_high_01", 53, 9, 6, 38, 5.0, 80.0, "rleg", "high", "normal", "frontal"],
    "high_kick2": ["highkick2", "m04_kck_high_02", 43, 6, 6, 31, 6.0, 80.0, "rleg", "high", "normal", "fromright"],
    "high_kick3": ["highkick3", "m04_kck_high_03", 60, 9, 5, 46, 7.0, 80.0, "lleg", "high", "hard", "fromleft"],
    "low_kick": ["lowkick1", "m04_kck_low_03", 22, 6, 5, 11, 5.0, 70.0, "lleg", "low", "normal", "frontal"],
    "low_kick2": ["lowkick2", "m04_kck_low_01", 34, 5, 5, 24, 5.0, 100.0, "lleg", "low", "normal", "fromleft"],
    "low_kick3": ["lowkick3", "m04_kck_low_02", 34, 6, 4, 24, 7.0, 100.0, "lleg", "low", "hard", "fromright"],
    "special_kick_high": ["specialkickhigh sinfu", "m04_e02_kck_high_03", 85, 9, 6, 70, 10.0, 55.0, "lleg", "high", "hard", "frontal"],
    "special_kick_low": ["specialkicklow sinfu", "m04_e02_kck_low_03", 76, 10, 16, 50, 12.0, 75.0, "rleg", "low", "normal", "fromleft"],
    "special_punch_low": ["specialpunchlow sinfu", "m04_e02_pnch_low_03", 104, 11, 4, 89, 10.0, 75.0, "rarm", "medium", "hard", "frontal"],
    "parry_high": ["parryhigh", "m01_parry_high", 62, 9, 2, 51, 0.0, 40.0, "larm", "high", "normal", "frontal"],
    "parry_low": ["parrylow", "m01_kick_low_02", 27, 7, 4, 16, 0.0, 65.0, "rleg", "low", "normal", "frontal"],
    "parry_attack": ["parryattack", "m04_pnch_high_02", 50, 6, 5, 39, 10.0, 65.0, "rarm", "high", "hard", "frontal"],
    "grab1": ["grab1 sinfu", "m04_grab_01", 103, 34, 11, 58, 20.0, 45.0, "larm", "low", "hard", "frontal"],
    "grab2": ["grab2 sinfu", "m04_sp_kck_low", 55, 12, 12, 31, 20.0, 45.0, "larm", "low", "hard", "frontal"],
    "grab1_miss": ["grab1miss sinfu", "m02_grab_01", 47, 5, 3, 39, 0.0, 45.0, "larm", "high", "normal", "frontal"],
    "grab2_miss": ["grab2miss sinfu", "m04_sp_kck_low", 55, 4, 4, 47, 0.0, 45.0, "larm", "high", "normal", "frontal"],
    "attack_to_floor": ["attacktofloor", "m01_attack_to_floor", 90, 18, 5, 67, 6.0, 60.0, "lleg", "low", "normal", "frontal"],
    "endattack": ["endattack sinfu", "m04_end_attack_02", 75, 37, 3, 35, 0.0, 75.0, "rleg", "high", "hard", "fromleft"],
    "special_punch_high_miss": ["specialpunchhighmiss sinfu", "m04_sp_pnch_high_fail", 71, 10, 3, 58, 0.0, 40.0, "larm", "high", "normal", "frontal"],
    "special_punch_high_hit": ["specialpunchhighhit sinfu", "m04_sp_pnch_high", 50, 11, 12, 27, 20.0, 45.0, "larm", "high", "hard", "frontal"],
}
const SINFU_REACTION_PROFILE_DATA: Dictionary = {
    "hit": {
        "low": {
            "source_action": "impactlightfrontlow",
            "animation": "all_impct_light_frnt_low",
            "animation_radius": 50.0,
            "exit_start_frame": 14,
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
            "exit_start_frame": 16,
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
            "animation_radius": 60.0,
            "exit_start_frame": 10,
            "animation_duration_frames": 23,
            "linking_frame": 14,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
        "medium": {
            "source_action": "midblock",
            "animation": "all_block_mid",
            "animation_radius": 60.0,
            "exit_start_frame": 12,
            "animation_duration_frames": 14,
            "linking_frame": 0,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
        "high": {
            "source_action": "highblock",
            "animation": "all_block_high",
            "animation_radius": 60.0,
            "exit_start_frame": 12,
            "animation_duration_frames": 14,
            "linking_frame": 0,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
    },
}

const KEN_ANIMATION_RADII_DATA: Dictionary = {
    "all_block_high": 40.0,
    "all_block_low": 40.0,
    "all_block_mid": 40.0,
    "all_impct_light_frnt_high": 40.0,
    "all_impct_light_frnt_low": 40.0,
    "all_impct_light_frnt_mid": 40.0,
    "m02_attack_to_floor": 45.0,
    "m02_end_attack_01": 25.0,
    "m02_grab_01": 25.0,
    "m02_grab_02": 25.0,
    "m02_idle_01": 55.0,
    "m02_kck_high_01": 50.0,
    "m02_kck_high_02": 40.0,
    "m02_kck_high_03": 50.0,
    "m02_kck_low_01": 50.0,
    "m02_kck_low_02": 50.0,
    "m02_kck_low_03": 70.0,
    "m02_parry_high": 40.0,
    "m02_pnch_high_01": 40.0,
    "m02_pnch_high_02": 60.0,
    "m02_pnch_high_03": 30.0,
    "m02_pnch_low_01": 40.0,
    "m02_pnch_low_02": 40.0,
    "m02_pnch_low_03": 45.0,
    "m02_sp_kck_high": 50.0,
    "m02_sp_kck_low": 45.0,
    "m02_sp_pnch_high": 30.0,
    "m02_sp_pnch_low": 45.0,
}
const KEN_ATTACK_DATA: Dictionary = {
    "punch": ["lowpunch3", "m02_pnch_low_03", 57, 14, 7, 36, 7.0, 70.0, "larm", "medium", "hard", "frontal"],
    "kick": ["lowkick3", "m02_kck_low_03", 35, 9, 6, 20, 7.0, 110.0, "rleg", "low", "hard", "frontal"],
    "high_punch": ["highpunch1", "m02_pnch_high_01", 40, 7, 3, 30, 5.0, 60.0, "larm", "high", "normal", "frontal"],
    "high_punch2": ["highpunch2", "m02_pnch_high_03", 46, 8, 4, 34, 6.0, 70.0, "rarm", "high", "normal", "frontal"],
    "high_punch3": ["highpunch3", "m02_pnch_high_02", 20, 8, 4, 8, 7.0, 80.0, "larm", "high", "hard", "frontal"],
    "low_punch": ["lowpunch1", "m02_pnch_low_01", 31, 7, 4, 20, 6.0, 70.0, "larm", "medium", "normal", "frontal"],
    "low_punch2": ["lowpunch2", "m02_pnch_low_02", 27, 7, 4, 16, 6.0, 70.0, "larm", "medium", "normal", "frontal"],
    "low_punch3": ["lowpunch3", "m02_pnch_low_03", 57, 14, 7, 36, 7.0, 70.0, "larm", "medium", "hard", "frontal"],
    "high_kick": ["highkick1", "m02_kck_high_01", 50, 7, 6, 37, 5.0, 80.0, "lleg", "high", "normal", "frontal"],
    "high_kick2": ["highkick2", "m02_kck_high_03", 52, 14, 5, 33, 6.0, 80.0, "lleg", "high", "normal", "frontal"],
    "high_kick3": ["highkick3", "m02_kck_high_02", 50, 9, 4, 37, 8.0, 80.0, "lleg", "high", "hard", "frontal"],
    "low_kick": ["lowkick1", "m02_kck_low_01", 26, 5, 4, 17, 4.0, 65.0, "lleg", "low", "normal", "fromright"],
    "low_kick2": ["lowkick2", "m02_kck_low_02", 24, 8, 4, 12, 4.0, 65.0, "rleg", "low", "normal", "fromleft"],
    "low_kick3": ["lowkick3", "m02_kck_low_03", 35, 9, 6, 20, 7.0, 110.0, "rleg", "low", "hard", "frontal"],
    "special_kick_high": ["specialkickhigh ken", "m02_sp_kck_high", 48, 20, 4, 24, 13.0, 75.0, "rleg", "high", "hard", "frontal"],
    "special_kick_low": ["specialkicklow ken", "m02_sp_kck_low", 60, 15, 7, 38, 12.0, 65.0, "rleg", "low", "hard", "frontal"],
    "special_punch_high": ["specialpunchhigh ken", "m02_sp_pnch_high", 58, 9, 7, 42, 15.0, 80.0, "larm", "high", "hard", "frontal"],
    "special_punch_low": ["specialpunchlow ken", "m02_sp_pnch_low", 47, 8, 15, 24, 14.0, 60.0, "larm", "medium", "normal", "frontal"],
    "parry_high": ["parryhigh", "m02_parry_high", 19, 9, 2, 8, 0.0, 40.0, "larm", "high", "normal", "frontal"],
    "parry_attack": ["parryattack", "m02_pnch_low_03", 57, 14, 5, 38, 10.0, 65.0, "rarm", "high", "hard", "frontal"],
    "grab1": ["grab1 ken", "m02_grab_01", 47, 32, 7, 8, 16.0, 45.0, "larm", "low", "hard", "frontal"],
    "grab2": ["grab2 ken", "m02_grab_02", 98, 65, 6, 27, 20.0, 45.0, "larm", "low", "hard", "frontal"],
    "grab1_miss": ["grab1miss ken", "m02_grab_01", 47, 5, 3, 39, 0.0, 45.0, "larm", "high", "normal", "frontal"],
    "grab2_miss": ["grab2miss ken", "m02_grab_01", 47, 4, 4, 39, 0.0, 45.0, "larm", "high", "normal", "frontal"],
    "attack_to_floor": ["attacktofloor", "m02_attack_to_floor", 34, 8, 5, 21, 6.0, 105.0, "rarm", "low", "normal", "frontal"],
    "endattack": ["endattack ken", "m02_end_attack_01", 132, 18, 1, 113, 0.0, 45.0, "rleg", "high", "hard", "fromleft"],
}
const KEN_REACTION_PROFILE_DATA: Dictionary = {
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
            "animation": "all_block_high",
            "animation_radius": 40.0,
            "exit_start_frame": 12,
            "animation_duration_frames": 14,
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
        {
            "strength": "brutal",
            "height": "medium",
            "direction": "frontal",
            "source_action": "impactbrutalmid",
            "animation": "all_sp_pnch_low_forset04",
            "animation_radius": 60.0,
            "entry_frame": 6,
            "exit_start_frame": 25,
            "animation_duration_frames": 28,
            "linking_frame": 0,
            "return_action": "facedownidle",
            "return_implemented": false,
            "clip_implemented": false,
        },
        {
            "strength": "brutal",
            "height": "high",
            "direction": "fromleft",
            "source_action": "impactbrutalleft",
            "animation": "all_impct_spectacular_lft",
            "animation_radius": 85.0,
            "entry_frame": 0,
            "exit_start_frame": 39,
            "animation_duration_frames": 45,
            "linking_frame": 0,
            "return_action": "facedownidle",
            "return_implemented": false,
            "clip_implemented": false,
        },
        {
            "strength": "brutal",
            "height": "high",
            "direction": "fromright",
            "source_action": "impactbrutalright",
            "animation": "all_impct_spectacular_rht",
            "animation_radius": 25.0,
            "entry_frame": 0,
            "exit_start_frame": 41,
            "animation_duration_frames": 45,
            "linking_frame": 0,
            "return_action": "facedownidle",
            "return_implemented": false,
            "clip_implemented": false,
        },
        {
            "strength": "normal",
            "height": "high",
            "direction": "fromleft",
            "source_action": "impactlightlefthigh",
            "animation": "all_impct_light_lft_high",
            "animation_radius": 40.0,
            "entry_frame": 0,
            "exit_start_frame": 15,
            "animation_duration_frames": 17,
            "linking_frame": 0,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
        {
            "strength": "normal",
            "height": "high",
            "direction": "fromright",
            "source_action": "impactlightrighthigh",
            "animation": "all_impct_light_rht_high",
            "animation_radius": 40.0,
            "entry_frame": 0,
            "exit_start_frame": 15,
            "animation_duration_frames": 17,
            "linking_frame": 0,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
        {
            "strength": "normal",
            "height": "low",
            "direction": "fromleft",
            "source_action": "impactlightleftlow",
            "animation": "all_impct_light_lft_low",
            "animation_radius": 40.0,
            "entry_frame": 0,
            "exit_start_frame": 15,
            "animation_duration_frames": 17,
            "linking_frame": 0,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
        {
            "strength": "normal",
            "height": "low",
            "direction": "fromright",
            "source_action": "impactlightrightlow",
            "animation": "all_impct_light_rht_low",
            "animation_radius": 40.0,
            "entry_frame": 0,
            "exit_start_frame": 13,
            "animation_duration_frames": 17,
            "linking_frame": 0,
            "return_action": "idle",
            "return_implemented": true,
            "clip_implemented": false,
        },
        {
            "strength": "hard",
            "height": "low",
            "direction": "fromleft",
            "source_action": "impacthardleftlow",
            "animation": "all_impct_hard_lft_low",
            "animation_radius": 80.0,
            "entry_frame": 0,
            "exit_start_frame": 25,
            "animation_duration_frames": 29,
            "linking_frame": 0,
            "return_action": "faceupidle",
            "return_implemented": false,
            "clip_implemented": false,
        },
        {
            "strength": "hard",
            "height": "high",
            "direction": "fromleft",
            "source_action": "impacthardlefthigh",
            "animation": "all_impct_hard_lft_high",
            "animation_radius": 80.0,
            "entry_frame": 0,
            "exit_start_frame": 26,
            "animation_duration_frames": 29,
            "linking_frame": 0,
            "return_action": "faceupidle",
            "return_implemented": false,
            "clip_implemented": false,
        },
        {
            "strength": "hard",
            "height": "high",
            "direction": "fromabove",
            "source_action": "impacthardabove",
            "animation": "all_impct_hard_above",
            "animation_radius": 70.0,
            "entry_frame": 0,
            "exit_start_frame": 17,
            "animation_duration_frames": 17,
            "linking_frame": 0,
            "return_action": "facedownidle",
            "return_implemented": false,
            "clip_implemented": false,
        },
        {
            "strength": "hard",
            "height": "low",
            "direction": "frontal",
            "source_action": "impacthardfrontlow",
            "animation": "all_impct_hard_frnt_low",
            "animation_radius": 70.0,
            "entry_frame": 0,
            "exit_start_frame": 20,
            "animation_duration_frames": 23,
            "linking_frame": 0,
            "return_action": "facedownidle",
            "return_implemented": false,
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
# Resolved from SET_ATTACK_PROFILES for non-Bruce fighting sets; empty means
# the brucelee.set rules.
var attack_set_profile: Dictionary = {}
var radius_scale: float = 1.0
var source_units_to_world: float = WORLD_CHARACTER_HEIGHT / SOURCE_CHARACTER_HEIGHT
var source_animation_radii: Dictionary = SOURCE_ANIMATION_RADII_DATA.duplicate(true)


var character_name: String = "Fighter"
var is_player: bool = true
var health: float = MAX_HEALTH
var move_axis: Vector2 = Vector2.ZERO
var _locomotion_action: String = ""
var _locomotion_time: float = 0.0
var _movement_root_tracks: Dictionary = {}
var _locomotion_root_prev: Vector3 = Vector3.ZERO
var _locomotion_root_ready: bool = false
var polar_movement_enabled: bool = false
var training_step_lock: bool = false
var held_directions: Dictionary = {}
var guard_held: bool = false
var opponent: PortFighter
var state: String = "idle"
var state_time: float = 0.0
var attack_kind: String = ""
var attack_sequence: int = 0
var _attack_root_tracks: Dictionary = {}
var attack_root_motion_enabled: bool = true
var _attack_root_sequence: int = -1
var _attack_root_previous_frame: float = -1.0
var _attack_root_previous_value: Vector3 = Vector3.ZERO
var _attack_connected: bool = false
var _parry_absorbed: bool = false
var _link_events: Array[Dictionary] = []
# Link metadata exported from brucelee.set (link order, group windows,
# keysequence, keystatus, conditions, time, entry/linking frames).
var _native_actions: Dictionary = {}
var _native_reactions: Dictionary = {"hit": [], "block": []}
var _native_links: Array = []
var _link_scan_action: String = ""
var _link_scan_previous_frame: float = -1.0
var _action_to_attack: Dictionary = {}
var _key_status: Dictionary = {}
var last_reaction_group: String = ""
var last_reaction_source_action: String = ""
var last_reaction_animation: String = ""
var last_reaction_exit_frame: int = -1
var last_reaction_entry_frame: int = 0
var last_reaction_clip_implemented: bool = false
var facing: float = 1.0
var combo_hits: int = 0
var rage: float = 0.0
var _multi_impact_applied: Array = []
var _attack_hit_landed: bool = false
var _grab_connected: bool = false
var _endattack_victim_started: bool = false
var _stun_impact_next_state: String = "stunfall"
var candidate_loaded: bool = false
var candidate_load_error: String = ""
var candidate_animation_clip: String = ""
# Result presentation (CBeatEmUpGame::SetState 12/13/14). The winner plays the
# result clip that characters.list already bound to this fighter when the match
# configuration was built; the hidden loser is never given an animation in
# SetState(12/13). The pools are the archive lists, not the loaded GLB's clip
# names, because a candidate GLB can also carry other characters' result clips.
var result_clip: String = ""
var result_pose_active: bool = false
var character_result_clips: Dictionary = {}
var result_clip_index_victory: int = 0
var result_clip_index_defeat: int = 0
var result_clip_gap_last: String = ""
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
# Size-class selection state (adreno_200/Animations.versions). skeleton_class is
# the fighter's characters.list "skeleton" value; the rest records the last
# resolution so a test or the HUD can prove which version was chosen.
var skeleton_class: String = SIZE_CLASS_MEDIUM
var _size_variants: Dictionary = {}
var size_variants_error: String = ""
var size_variant_status_last: String = ""
var size_variant_class_last: String = ""
var size_variant_base_last: String = ""
var size_variant_clip_last: String = ""
var size_variant_error: String = ""
# Ground-idle resolution state (all_idle_face_down/up, audience "self"). Kept
# separate from the attack-slot state so both can be proven independently.
var ground_idle_status_last: String = ""
var ground_idle_class_last: String = ""
var ground_idle_base_last: String = ""
var ground_idle_clip_last: String = ""
var ground_idle_error: String = ""
# The archived animation name behind each resolved victim slot, so the
# size-variant lookup uses the set's clip name instead of a candidate path.
var _victim_selected_animation: Dictionary = {}
# Base candidate path per grab/finisher slot, captured once the candidate clips
# are mapped, so a version resolution can always be undone.
var _size_variant_base_path: Dictionary = {}
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


func _load_attack_root_motion() -> void:
    _attack_root_tracks.clear()
    var file: FileAccess = FileAccess.open(ATTACK_ROOT_MOTION_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        push_warning("Attack root-motion data is not an object; disabled")
        return
    for source_action: Variant in parsed:
        var track: Variant = parsed[source_action]
        if not track is Array:
            continue
        var points: Array[Vector3] = []
        for sample: Variant in track:
            if not sample is Array or sample.size() < 2:
                continue
            points.append(Vector3(
                float(sample[0]), float(sample[1]), float(sample[2])
            ))
        if points.size() >= 2:
            var key: String = String(source_action)
            _attack_root_tracks[key] = points


func _load_movement_root_motion() -> void:
    _movement_root_tracks.clear()
    var file: FileAccess = FileAccess.open(MOVEMENT_ROOT_MOTION_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        push_warning("Movement root-motion data is not an object; disabled")
        return
    for animation_name: Variant in parsed:
        var entry: Variant = parsed[animation_name]
        if not entry is Dictionary:
            continue
        var raw_values: Variant = entry.get("values")
        if not raw_values is Array or Array(raw_values).size() < 2:
            continue
        var points: Array[Vector3] = []
        for sample: Variant in raw_values:
            if not sample is Array or sample.size() < 3:
                continue
            points.append(Vector3(
                float(sample[0]), float(sample[1]), float(sample[2])
            ))
        if points.size() >= 2:
            _movement_root_tracks[String(animation_name)] = points


func _movement_root_clip_for_action(action: String) -> String:
    if action.is_empty():
        return ""
    if candidate_clips.has(action):
        return String(candidate_clips[action])
    if _candidate_clip_paths.has(action):
        return String(_candidate_clip_paths[action])
    return action


func _sample_movement_root(track: Array, frame: float) -> Vector3:
    var bounded: float = clampf(frame, 0.0, float(track.size() - 1))
    var left: int = int(floor(bounded))
    var right: int = mini(left + 1, track.size() - 1)
    var weight: float = bounded - float(left)
    return track[left].lerp(track[right], weight)


func _locomotion_root_delta() -> Vector3:
    if _locomotion_action.is_empty():
        _locomotion_root_ready = false
        return Vector3.ZERO
    var clip: String = _movement_root_clip_for_action(_locomotion_action)
    if not _movement_root_tracks.has(clip):
        _locomotion_root_ready = false
        return Vector3.ZERO
    var track: Array = _movement_root_tracks[clip]
    var frame: float = _locomotion_time * SOURCE_FRAME_RATE
    var point: Vector3 = _sample_movement_root(track, frame)
    if not _locomotion_root_ready:
        _locomotion_root_prev = point
        _locomotion_root_ready = true
        return Vector3.ZERO
    var delta: Vector3 = point - _locomotion_root_prev
    _locomotion_root_prev = point
    return _root_motion_delta_to_pc_world(delta, clip)


func _sample_attack_root(track: Array, frame: float) -> Vector3:
    var bounded: float = clampf(frame, 0.0, float(track.size() - 1))
    var left: int = int(floor(bounded))
    var right: int = mini(left + 1, track.size() - 1)
    var weight: float = bounded - float(left)
    return track[left].lerp(track[right], weight)


func _seed_attack_root_motion() -> void:
    _attack_root_sequence = attack_sequence
    if state not in ["startup", "active", "recovery"] or not ATTACKS.has(attack_kind):
        return
    var animation_name: String = String(ATTACKS[attack_kind].get("animation", ""))
    var track: Variant = _attack_root_tracks.get(animation_name)
    if not track is Array or track.size() < 2:
        return
    var frame: float = _current_attack_source_frame()
    if frame < 0.0:
        return
    _attack_root_previous_frame = frame
    _attack_root_previous_value = _sample_attack_root(track, frame)


func _apply_attack_root_motion() -> void:
    if not attack_root_motion_enabled:
        return
    if state not in ["startup", "active", "recovery"] or not ATTACKS.has(attack_kind):
        return
    var animation_name: String = String(ATTACKS[attack_kind].get("animation", ""))
    var track: Variant = _attack_root_tracks.get(animation_name)
    if not track is Array or track.size() < 2:
        return
    var frame: float = _current_attack_source_frame()
    if frame < 0.0:
        return
    if attack_sequence != _attack_root_sequence:
        _seed_attack_root_motion()
        return
    if frame + 0.0001 < _attack_root_previous_frame:
        _attack_root_previous_frame = frame
        _attack_root_previous_value = _sample_attack_root(track, frame)
        return
    var current: Vector3 = _sample_attack_root(track, frame)
    var delta: Vector3 = current - _attack_root_previous_value
    if delta.length_squared() > 0.0:
        var motion: Vector3 = _root_motion_delta_to_pc_world(delta, animation_name)
        position.x = clampf(position.x + motion.x, -ARENA_HALF_X, ARENA_HALF_X)
        position.z = clampf(position.z + motion.z, -ARENA_HALF_Z, ARENA_HALF_Z)
    _attack_root_previous_frame = frame
    _attack_root_previous_value = current


func root_motion_mapping_status(animation_name: String) -> String:
    return String(ROOT_MOTION_MAPPING_STATUS.get(animation_name, "UNVERIFIED"))


func _root_motion_delta_to_pc_world(delta: Vector3, animation_name: String) -> Vector3:
    # The only place raw ANM positions are converted into PC world motion.
    # Source movement tracks establish the axes: movefwd/stepfwd are -Y,
    # moveback/stepback are +Y, steplft is +X and steprht is -X. Local +X is
    # forward and local +Z is right, so source +X (left) maps to local -Z.
    # Per-clip status remains EMPIRICAL/UNVERIFIED for non-movement clips.
    return Vector3(
        facing * (-delta.y) * source_units_to_world,
        0.0,
        facing * (-delta.x) * source_units_to_world
    )


func _load_size_variants() -> void:
    ## Read the derived Animations.versions table once. A table that cannot be
    ## read is a hard error: every grab/finisher then fails closed (the class
    ## decision cannot be made), instead of silently playing base clips.
    ## BRUCELEE_SIZE_VARIANTS overrides the path (tests, packaging).
    _size_variants.clear()
    size_variants_error = ""
    var path: String = OS.get_environment("BRUCELEE_SIZE_VARIANTS")
    if path.is_empty():
        path = SIZE_VARIANTS_PATH
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        size_variants_error = "missing " + path
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        size_variants_error = "size variant table is not an object"
        return
    var table: Variant = Dictionary(parsed).get("variants")
    if not table is Dictionary:
        size_variants_error = "size variant table has no variants object"
        return
    for base: Variant in Dictionary(table):
        var entry: Variant = Dictionary(table)[base]
        if not entry is Dictionary:
            continue
        var audience: String = String(Dictionary(entry).get("audience", ""))
        var versions: Variant = Dictionary(entry).get("versions")
        if audience not in ["self", "opponent"] or not versions is Dictionary:
            continue
        var classes: Dictionary = {}
        for size_class: Variant in Dictionary(versions):
            var clip: String = String(Dictionary(versions)[size_class]).strip_edges()
            if not clip.is_empty():
                classes[String(size_class).strip_edges().to_lower()] = clip
        if not classes.is_empty():
            _size_variants[String(base)] = {
                "audience": audience, "versions": classes,
            }


func set_skeleton_class(value: String) -> void:
    ## characters.list "skeleton" value: small, medium or large. Anything else
    ## is kept verbatim so size_variant_for can fail closed on it.
    skeleton_class = value.strip_edges().to_lower()


func skeleton_class_name() -> String:
    var value: String = skeleton_class.strip_edges().to_lower()
    if value in [SIZE_CLASS_SMALL, SIZE_CLASS_MEDIUM, SIZE_CLASS_LARGE]:
        return value
    return ""


func size_variant_for(base_clip: String) -> Dictionary:
    ## Resolve one archived base clip to the version its owner's class selects.
    ## status: "base"     - no version exists, or the class is medium;
    ##         "variant"  - the class version is loaded and can play;
    ##         "unavailable" - a version is required but cannot be played.
    var result: Dictionary = {
        "status": "base", "clip": base_clip, "class": "", "reason": "",
    }
    var entry: Variant = _size_variants.get(base_clip)
    if not entry is Dictionary:
        return result
    var audience: String = String(Dictionary(entry).get("audience", ""))
    var owner: PortFighter = opponent if audience == "opponent" else self
    if owner == null or not is_instance_valid(owner):
        result["status"] = "unavailable"
        result["reason"] = (
            base_clip + ": the size version is keyed by the "
            + ("opponent" if audience == "opponent" else "own")
            + " skeleton class and no such fighter is set"
        )
        return result
    var klass: String = owner.skeleton_class_name()
    result["class"] = klass
    if klass.is_empty():
        result["status"] = "unavailable"
        result["reason"] = (
            base_clip + ": unknown skeleton class "
            + JSON.stringify(owner.skeleton_class)
        )
        return result
    var versions: Dictionary = Dictionary(entry)["versions"]
    if klass == SIZE_CLASS_MEDIUM or not versions.has(klass):
        # The original archive lists no version for this class: the base clip is
        # the original choice, not a wrong-size substitute.
        return result
    var version_clip: String = String(versions[klass])
    var matched: String = ""
    if _candidate_animation != null:
        matched = _find_animation_clip(_candidate_animation, version_clip)
    if matched.is_empty():
        result["status"] = "unavailable"
        result["reason"] = (
            base_clip + ": " + klass + " version " + version_clip
            + " is not in the loaded candidate"
        )
        return result
    result["status"] = "variant"
    result["clip"] = matched
    return result


func _size_variant_archived(base_clip: String) -> Dictionary:
    ## Same rule as size_variant_for, but reports the archived clip name (the
    ## version file name) instead of a candidate path. Ground-idle slots are
    ## keyed in _candidate_clip_paths by archived name, so they need this form.
    var result: Dictionary = {
        "status": "base", "clip": base_clip, "class": "", "reason": "",
    }
    var entry: Variant = _size_variants.get(base_clip)
    if not entry is Dictionary:
        return result
    var audience: String = String(Dictionary(entry).get("audience", ""))
    var owner: PortFighter = opponent if audience == "opponent" else self
    if owner == null or not is_instance_valid(owner):
        result["status"] = "unavailable"
        result["reason"] = (
            base_clip + ": the size version is keyed by the "
            + ("opponent" if audience == "opponent" else "own")
            + " skeleton class and no such fighter is set"
        )
        return result
    var klass: String = owner.skeleton_class_name()
    result["class"] = klass
    if klass.is_empty():
        result["status"] = "unavailable"
        result["reason"] = (
            base_clip + ": unknown skeleton class "
            + JSON.stringify(owner.skeleton_class)
        )
        return result
    var versions: Dictionary = Dictionary(entry).get("versions", {})
    if klass == SIZE_CLASS_MEDIUM or not versions.has(klass):
        return result
    var version_clip: String = String(versions[klass])
    if not _candidate_clip_paths.has(version_clip):
        result["status"] = "unavailable"
        result["reason"] = (
            base_clip + ": " + klass + " version " + version_clip
            + " is not in the loaded candidate"
        )
        return result
    result["status"] = "variant"
    result["clip"] = version_clip
    return result


func _resolved_ground_idle(base_clip: String) -> String:
    ## Pick the ground-idle clip for the fighter's own class. A required class
    ## version that the candidate cannot play makes the idle unavailable: the
    ## caller's _candidate_clip_paths.has() check then keeps the wrong-size base
    ## clip from playing (fail closed). The decision is recorded for the tests.
    ground_idle_base_last = base_clip
    if not size_variants_error.is_empty():
        ground_idle_status_last = "unavailable"
        ground_idle_class_last = ""
        ground_idle_clip_last = ""
        ground_idle_error = (
            size_variants_error + " (size class table unavailable)"
        )
        return ""
    var resolved: Dictionary = _size_variant_archived(base_clip)
    ground_idle_status_last = String(resolved.get("status", ""))
    ground_idle_class_last = String(resolved.get("class", ""))
    ground_idle_clip_last = String(resolved.get("clip", base_clip))
    ground_idle_error = String(resolved.get("reason", ""))
    if ground_idle_status_last == "unavailable":
        return ""
    if not candidate_loaded:
        # Placeholder rig: no candidate clip exists to swap, so the base name is
        # reported and the availability check simply finds nothing to play.
        return base_clip
    return String(resolved.get("clip", base_clip))


func ground_idle_state() -> Dictionary:
    ## Everything a test or the HUD needs to prove the ground-idle class choice.
    return {
        "skeleton_class": skeleton_class,
        "status": ground_idle_status_last,
        "class_used": ground_idle_class_last,
        "base": ground_idle_base_last,
        "clip": ground_idle_clip_last,
        "error": ground_idle_error,
        "playing": candidate_animation_clip,
    }


func size_variant_state() -> Dictionary:
    ## Everything a test or the HUD needs to prove which clip was selected.
    return {
        "skeleton_class": skeleton_class,
        "table_entries": _size_variants.size(),
        "table_error": size_variants_error,
        "status": size_variant_status_last,
        "class_used": size_variant_class_last,
        "base": size_variant_base_last,
        "clip": size_variant_clip_last,
        "error": size_variant_error,
        "playing": candidate_animation_clip,
    }


func _size_variant_base_clip(action: String) -> String:
    ## The archived animation name of an action, not the resolved candidate
    ## path: the version table is keyed by archived file basenames.
    var mapped: String = String(candidate_clips.get(action, ""))
    if not mapped.is_empty():
        return mapped
    if ATTACKS.has(action):
        return String(ATTACKS[action].get("animation", ""))
    return ""


func _snapshot_size_variant_base_paths() -> void:
    ## Remember the base candidate path of every grab/finisher slot so a later
    ## class resolution can always restore it; without this a resolved version
    ## could survive into a different matchup.
    _size_variant_base_path.clear()
    for action: Variant in SIZE_CLASS_ATTACKS:
        var key: String = String(action)
        if _candidate_clip_paths.has(key):
            _size_variant_base_path[key] = _candidate_clip_paths[key]


func _prepare_size_variant(kind: String) -> bool:
    ## Resolve the size version for one attack slot. Returns false when a
    ## required version is unavailable (or the table itself is missing), which
    ## must refuse the grab/finisher instead of playing the base clip.
    if not SIZE_CLASS_ATTACKS.has(kind):
        return true
    var base_clip: String = _size_variant_base_clip(kind)
    if base_clip.is_empty():
        return true
    if not candidate_loaded:
        # No candidate clips are loaded, so there is no clip to choose from and
        # no wrong-size clip to avoid: the placeholder rig plays no clip at all.
        size_variant_status_last = "base"
        size_variant_class_last = ""
        size_variant_base_last = base_clip
        size_variant_clip_last = base_clip
        size_variant_error = ""
        return true
    return _apply_size_variant(kind, base_clip)


func _apply_size_variant(slot: String, base_clip: String) -> bool:
    ## Point slot at the size version of base_clip and record the decision.
    ## Returns false when a required version is unavailable: the caller must
    ## then refuse the grab/finisher instead of playing the base clip.
    var base_path: String = String(_size_variant_base_path.get(slot, ""))
    if not size_variants_error.is_empty():
        # Without the recovered table the class decision cannot be made, so the
        # grab/finisher fails closed rather than silently using the base clip.
        size_variant_status_last = "unavailable"
        size_variant_class_last = ""
        size_variant_base_last = base_clip
        size_variant_clip_last = base_clip
        size_variant_error = size_variants_error + " (size class table unavailable)"
        if not base_path.is_empty():
            _candidate_clip_paths[slot] = base_path
        return false
    var resolved: Dictionary = size_variant_for(base_clip)
    size_variant_status_last = String(resolved.get("status", ""))
    size_variant_class_last = String(resolved.get("class", ""))
    size_variant_base_last = base_clip
    size_variant_clip_last = String(resolved.get("clip", base_clip))
    size_variant_error = String(resolved.get("reason", ""))
    if size_variant_status_last == "unavailable":
        # Never leave a previously resolved version in the slot.
        if not base_path.is_empty():
            _candidate_clip_paths[slot] = base_path
        return false
    if size_variant_status_last == "variant":
        _candidate_clip_paths[slot] = String(resolved["clip"])
    elif not base_path.is_empty():
        _candidate_clip_paths[slot] = base_path
    return true


func _ready() -> void:
    if OS.get_environment("BRUCELEE_CANDIDATE_VISUAL_BLENDING") == "1":
        candidate_visual_blending_enabled = true
    if not _load_attack_definitions():
        push_error("Fighting-set attack config failed closed: " + attack_config_error)
    _load_native_links()
    _load_attack_root_motion()
    _load_movement_root_motion()
    _load_size_variants()
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
    attack_set_profile = SET_ATTACK_PROFILES.get(attack_config_path, {})
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
    ATTACKS = loaded
    return true


func _is_number(value: Variant) -> bool:
    return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _parse_attack_config(config: Dictionary) -> Dictionary:
    var archive_value: Variant = config.get("source_archive", "")
    if (typeof(archive_value) == TYPE_STRING and String(archive_value) == "thai.set"
            and (attack_config_path == BRICK_ATTACK_CONFIG_PATH
                 or attack_config_path.is_empty())):
        return _parse_thai_mapped_attack_config(config)
    if attack_config_path == SMALLBOY_ATTACK_CONFIG_PATH:
        return _parse_set_mapped_attack_config(
            config, "thai.set", SMALLBOY_ATTACK_DATA,
            SMALLBOY_ANIMATION_RADII_DATA, THAI_REACTION_PROFILE_DATA
        )
    if attack_config_path == JOHNSON_ATTACK_CONFIG_PATH:
        return _parse_set_mapped_attack_config(
            config, "thai.set", JOHNSON_ATTACK_DATA,
            JOHNSON_ANIMATION_RADII_DATA, THAI_REACTION_PROFILE_DATA
        )
    if attack_config_path == CHIEF_ATTACK_CONFIG_PATH:
        return _parse_set_mapped_attack_config(
            config, "karate.set", CHIEF_ATTACK_DATA,
            CHIEF_ANIMATION_RADII_DATA, KEN_REACTION_PROFILE_DATA
        )
    if attack_config_path == LOMING_ATTACK_CONFIG_PATH:
        return _parse_set_mapped_attack_config(
            config, "kungfu.set", LOMING_ATTACK_DATA,
            LOMING_ANIMATION_RADII_DATA, SINFU_REACTION_PROFILE_DATA
        )
    if attack_config_path == MASTER_ATTACK_CONFIG_PATH:
        return _parse_set_mapped_attack_config(
            config, "kungfu.set", MASTER_ATTACK_DATA,
            MASTER_ANIMATION_RADII_DATA, MASTER_REACTION_PROFILE_DATA
        )
    if attack_config_path == SINFU_ATTACK_CONFIG_PATH:
        return _parse_set_mapped_attack_config(
            config, "kungfu.set", SINFU_ATTACK_DATA,
            SINFU_ANIMATION_RADII_DATA, SINFU_REACTION_PROFILE_DATA
        )
    if attack_config_path == SHENLO_ATTACK_CONFIG_PATH:
        # ShenLo shares kungfu.set reactions with SinFu but owns the m04_e03_*
        # attack and locomotion clips, so only the attack tables differ.
        return _parse_set_mapped_attack_config(
            config, "kungfu.set", SHENLO_ATTACK_DATA,
            SHENLO_ANIMATION_RADII_DATA, SINFU_REACTION_PROFILE_DATA
        )
    if attack_config_path == KEN_ATTACK_CONFIG_PATH:
        return _parse_set_mapped_attack_config(
            config, "karate.set", KEN_ATTACK_DATA,
            KEN_ANIMATION_RADII_DATA, KEN_REACTION_PROFILE_DATA
        )
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
                "damage", "source_impact"]:
            if not entry.has(key):
                return _reject_attack_config(action + " lacks " + key)
        if (not _is_number(entry["startup_frames"]) or not _is_number(entry["active_frames"])
                or not _is_number(entry["recovery_frames"])
                or not _is_number(entry["animation_frame_count"])
                or not _is_number(entry["damage"])):
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
        if (damage < 0.0
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
    if radii.size() < THAI_ANIMATION_RADII_DATA.size():
        return _reject_attack_config("animation_radii lacks the four verified base clips")
    var loaded_radii: Dictionary = {}
    for animation: String in THAI_ANIMATION_RADII_DATA:
        if not radii.has(animation) or not _is_number(radii[animation]):
            return _reject_attack_config("animation_radii." + animation + " is missing or non-numeric")
        var radius: float = float(radii[animation])
        if absf(radius - float(THAI_ANIMATION_RADII_DATA[animation])) > 0.001 or radius <= 0.0:
            return _reject_attack_config("animation_radii." + animation + " does not match thai.set")
        loaded_radii[animation] = radius
    for animation: String in radii:
        if not _is_number(radii[animation]) or float(radii[animation]) <= 0.0:
            return _reject_attack_config("animation_radii." + animation + " is invalid")
        loaded_radii[animation] = float(radii[animation])
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
    var allowed_actions: Array[String] = [
        "punch", "kick",
        "high_punch", "high_punch2", "high_punch3",
        "low_punch", "low_punch2", "low_punch3",
        "high_kick", "high_kick2", "high_kick3",
        "low_kick", "low_kick2", "low_kick3",
        "special_kick_high_brick", "special_kick_low_brick",
        "special_punch_high_brick", "special_punch_low_brick",
        "parry_high_brick", "parry_low_brick", "parry_attack_brick",
        "grab1_brick", "grab2_brick", "attack_to_floor_brick", "endattack_brick",
        "grab1_miss_brick", "grab2_miss_brick",
    ]
    for required_action: String in THAI_ATTACK_DATA:
        if not attacks.has(required_action):
            return _reject_attack_config("thai mapping lacks " + required_action)
    var result: Dictionary = {}
    for action: String in attacks.keys():
        if action not in allowed_actions:
            return _reject_attack_config("thai mapping contains an unknown action: " + action)
        var entry_value: Variant = attacks.get(action)
        if not entry_value is Dictionary:
            return _reject_attack_config(action + " is not an object")
        var entry: Dictionary = entry_value
        for key: String in [
                "source_action", "animation", "animation_frame_count",
                "startup_frames", "active_frames", "recovery_frames",
                "damage", "source_impact"]:
            if not entry.has(key):
                return _reject_attack_config(action + " lacks " + key)
        if (not _is_number(entry["startup_frames"]) or not _is_number(entry["active_frames"])
                or not _is_number(entry["recovery_frames"])
                or not _is_number(entry["animation_frame_count"])
                or not _is_number(entry["damage"])):
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
        var expected: Array = THAI_ATTACK_DATA.get(action, [])
        if expected.is_empty():
            return _reject_attack_config(action + " lacks recovered thai.set evidence")
        if (String(entry["source_action"]) != String(expected[0])
                or String(entry["animation"]) != String(expected[1])
                or frame_count != int(expected[2])
                or startup_frames != int(expected[3])
                or active_frames != int(expected[4])
                or recovery_frames != int(expected[5])
                or absf(float(entry["damage"]) - float(expected[6])) > 0.001):
            return _reject_attack_config(action + " does not match recovered thai.set frames")
        var impact_value: Variant = entry["source_impact"]
        if not impact_value is Dictionary:
            return _reject_attack_config(action + " source_impact is not an object")
        var impact: Dictionary = impact_value
        for key: String in ["attack_radius", "body_part", "height", "strength", "direction"]:
            if not impact.has(key):
                return _reject_attack_config(action + " impact lacks " + key)
        if (not _is_number(impact["attack_radius"])
                or absf(float(impact["attack_radius"]) - float(expected[7])) > 0.001
                or String(impact["body_part"]) != String(expected[8])
                or String(impact["height"]) != String(expected[9])
                or String(impact["strength"]) != String(expected[10])
                or String(impact["direction"]) != String(expected[11])):
            return _reject_attack_config(action + " impact does not match recovered thai.set data")
        result[action] = {
            "startup": float(startup_frames) / SOURCE_FRAME_RATE,
            "active": float(active_frames) / SOURCE_FRAME_RATE,
            "recovery": float(recovery_frames) / SOURCE_FRAME_RATE,
            "damage": float(entry["damage"]),
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


func _parse_set_mapped_attack_config(
        config: Dictionary,
        set_name: String,
        attack_data: Dictionary,
        radii_data: Dictionary,
        reaction_data: Dictionary
) -> Dictionary:
    # Mapped fighting-set profile: the JSON may only restate what the recovered
    # table holds, and every table row must be present. This is the same
    # contract as _parse_thai_mapped_attack_config, generalised so kungfu.set
    # (Master/SinFu) and karate.set (Ken) reuse it instead of Brick's table.
    var schema_value: Variant = config.get("schema_version")
    if not _is_number(schema_value) or float(schema_value) != 4.0:
        return _reject_attack_config("unsupported schema version")
    if (typeof(config.get("source_archive")) != TYPE_STRING
            or String(config.get("source_archive")) != set_name):
        return _reject_attack_config("unexpected source archive")
    var frame_rate_value: Variant = config.get("frame_rate")
    if (not _is_number(frame_rate_value)
            or absf(float(frame_rate_value) - SOURCE_FRAME_RATE) > 0.001):
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
            or String(geometry["idle_source_archive"]) != set_name):
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
    for animation: String in radii_data:
        if not radii.has(animation) or not _is_number(radii[animation]):
            return _reject_attack_config("animation_radii." + animation + " is missing or non-numeric")
        var radius: float = float(radii[animation])
        if radius <= 0.0 or absf(radius - float(radii_data[animation])) > 0.001:
            return _reject_attack_config("animation_radii." + animation + " does not match " + set_name)
        loaded_radii[animation] = radius
    for animation: String in radii:
        if not _is_number(radii[animation]) or float(radii[animation]) <= 0.0:
            return _reject_attack_config("animation_radii." + animation + " is invalid")
        loaded_radii[animation] = float(radii[animation])
    var loaded_reactions: Dictionary = _parse_reaction_profiles(
        config.get("reaction_profiles"), reaction_data
    )
    if loaded_reactions.is_empty():
        return {}
    var configured_attacks: Variant = config.get("attacks")
    if not configured_attacks is Dictionary:
        return _reject_attack_config("attacks is not an object")
    var attacks: Dictionary = configured_attacks
    for required_action: String in attack_data:
        if not attacks.has(required_action):
            return _reject_attack_config(set_name + " mapping lacks " + required_action)
    var result: Dictionary = {}
    for action: String in attacks.keys():
        if not attack_data.has(action):
            return _reject_attack_config(
                set_name + " mapping contains an unknown action: " + action
            )
        var entry_value: Variant = attacks[action]
        if not entry_value is Dictionary:
            return _reject_attack_config(action + " is not an object")
        var entry: Dictionary = entry_value
        for key: String in [
                "source_action", "animation", "animation_frame_count",
                "startup_frames", "active_frames", "recovery_frames",
                "damage", "source_impact"]:
            if not entry.has(key):
                return _reject_attack_config(action + " lacks " + key)
        if (not _is_number(entry["startup_frames"]) or not _is_number(entry["active_frames"])
                or not _is_number(entry["recovery_frames"])
                or not _is_number(entry["animation_frame_count"])
                or not _is_number(entry["damage"])):
            return _reject_attack_config(action + " contains non-numeric values")
        var startup_frames: int = int(entry["startup_frames"])
        var active_frames: int = int(entry["active_frames"])
        var recovery_frames: int = int(entry["recovery_frames"])
        var frame_count: int = int(entry["animation_frame_count"])
        if (float(entry["startup_frames"]) != float(startup_frames)
                or float(entry["active_frames"]) != float(active_frames)
                or float(entry["recovery_frames"]) != float(recovery_frames)
                or float(entry["animation_frame_count"]) != float(frame_count)
                or startup_frames < 0 or active_frames <= 0 or recovery_frames < 0
                or startup_frames + active_frames + recovery_frames != frame_count):
            return _reject_attack_config(action + " phase frames do not match the clip")
        var expected: Array = attack_data.get(action, [])
        if (String(entry["source_action"]) != String(expected[0])
                or String(entry["animation"]) != String(expected[1])
                or frame_count != int(expected[2])
                or startup_frames != int(expected[3])
                or active_frames != int(expected[4])
                or recovery_frames != int(expected[5])
                or absf(float(entry["damage"]) - float(expected[6])) > 0.001):
            return _reject_attack_config(
                action + " does not match recovered " + set_name + " frames"
            )
        var impact_value: Variant = entry["source_impact"]
        if not impact_value is Dictionary:
            return _reject_attack_config(action + " source_impact is not an object")
        var impact: Dictionary = impact_value
        for key: String in ["attack_radius", "body_part", "height", "strength", "direction"]:
            if not impact.has(key):
                return _reject_attack_config(action + " impact lacks " + key)
        if (not _is_number(impact["attack_radius"])
                or absf(float(impact["attack_radius"]) - float(expected[7])) > 0.001
                or String(impact["body_part"]) != String(expected[8])
                or String(impact["height"]) != String(expected[9])
                or String(impact["strength"]) != String(expected[10])
                or String(impact["direction"]) != String(expected[11])):
            return _reject_attack_config(
                action + " impact does not match recovered " + set_name + " data"
            )
        var multi_impacts: Array = []
        if entry.has("multi_impacts"):
            if not entry["multi_impacts"] is Array:
                return _reject_attack_config(action + " multi_impacts is not an array")
            for multi_value: Variant in entry["multi_impacts"]:
                if not multi_value is Dictionary:
                    return _reject_attack_config(action + " multi impact is not an object")
                var multi_impact: Dictionary = multi_value
                for key: String in [
                        "damage", "damage_time", "attack_radius",
                        "body_part", "height", "strength", "direction"]:
                    if not multi_impact.has(key):
                        return _reject_attack_config(action + " multi impact lacks " + key)
                var timing_value: Variant = multi_impact["damage_time"]
                if (not timing_value is Array or Array(timing_value).size() != 2
                        or not _is_number(timing_value[0]) or not _is_number(timing_value[1])
                        or float(timing_value[0]) < 0.0
                        or float(timing_value[1]) < float(timing_value[0])
                        or float(timing_value[1]) >= float(frame_count)):
                    return _reject_attack_config(action + " multi impact timing is invalid")
                if (not _is_number(multi_impact["damage"])
                        or not _is_number(multi_impact["attack_radius"])):
                    return _reject_attack_config(action + " multi impact values are non-numeric")
                if String(multi_impact["body_part"]) not in ["larm", "rarm", "lleg", "rleg"]:
                    return _reject_attack_config(action + " multi impact body part is invalid")
                if String(multi_impact["height"]) not in ["high", "medium", "low"]:
                    return _reject_attack_config(action + " multi impact height is invalid")
                if String(multi_impact["strength"]) not in ["hard", "normal", "brutal"]:
                    return _reject_attack_config(action + " multi impact strength is invalid")
                if String(multi_impact["direction"]) not in ["frontal", "fromleft", "fromright", "fromabove"]:
                    return _reject_attack_config(action + " multi impact direction is invalid")
                multi_impacts.append(multi_impact.duplicate(true))
            var window_start: int = int(multi_impacts[0]["damage_time"][0])
            var window_end: int = int(multi_impacts[multi_impacts.size() - 1]["damage_time"][1])
            if (window_start != startup_frames
                    or window_end - window_start + 1 != active_frames):
                return _reject_attack_config(
                    action + " multi impact windows do not span the active phase"
                )
        var animation_radius: float = float(radii_data.get(String(entry["animation"]), -1.0))
        result[action] = {
            "startup": float(startup_frames) / SOURCE_FRAME_RATE,
            "active": float(active_frames) / SOURCE_FRAME_RATE,
            "recovery": float(recovery_frames) / SOURCE_FRAME_RATE,
            "damage": float(entry["damage"]),
            "source_action": String(entry["source_action"]),
            "animation": String(entry["animation"]),
            "animation_frame_count": frame_count,
            "animation_radius": animation_radius,
            "source_impact": impact.duplicate(true),
            "multi_impacts": multi_impacts,
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
        candidate_load_error = (
            "GLB read failed with error %d: %s (validate skin inverseBindMatrices "
            + "count == joints count before exporting)"
        ) % [result, path]
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
    # A mapped set candidate may ship only the character-specific clips (the
    # Master candidate has no m04 base punch/kick yet). Such candidates still
    # load; per-action availability stays gated by supports_attack().
    var required_clips: Array[String] = ["idle", "punch", "kick"]
    if not attack_set_profile.is_empty():
        # A mapped set candidate may ship only some of the set's clips (the
        # Master candidate has no m04 base punch/kick yet); those are optional.
        required_clips = ["idle"]
    for action: String in ["idle", "punch", "kick"]:
        if not candidate_clips.has(action):
            continue
        var expected: String = candidate_clips[action]
        var matched: String = _find_animation_clip(_candidate_animation, expected)
        if matched.is_empty():
            if action in required_clips:
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
            "low_punch", "low_kick",
            "high_punch3", "low_punch3", "low_kick3", "high_kick3",
            "special_kick_high", "special_kick_low",
            "special_punch_high", "special_punch_low",
            "attack_to_floor", "endattack",
            "special_kick_high_brick", "special_kick_low_brick",
            "special_punch_high_brick", "special_punch_low_brick",
            "parry_high_brick", "parry_low_brick", "parry_attack_brick",
            "grab1_brick", "grab2_brick", "attack_to_floor_brick", "endattack_brick",
            "grab1_miss_brick", "grab2_miss_brick",
            "high_punch2", "low_punch2", "high_kick2", "low_kick2",
            "special_kick_low_miss", "special_kick_low_hit",
            "special_punch_low_miss", "special_punch_low_hit",
            "special_punch_high_miss", "special_punch_high_hit",
            "parry_high", "parry_low", "parry_attack", "grab1", "grab2", "grab1_miss", "grab2_miss", "grabbed1", "grabbed2", "endattackcomp1", "endattackcomp2",
            "endattack1", "endattack2", "stun", "stun_fall",
            "stun_hard", "stun_brutal",
            "move", "movefwd", "moveback", "moveleft", "moveright", "stepfwd", "stepback",
            "stepleft", "stepright"]:
        if not candidate_clips.has(action):
            continue
        var matched_optional: String = _find_animation_clip(
            _candidate_animation, String(candidate_clips[action])
        )
        if not matched_optional.is_empty():
            _candidate_clip_paths[action] = matched_optional
    # Candidate-provided reactions are separate from source-link flags. Never
    # expose one through the generic animation table before its tracks pass the
    # reaction safety check, including reactions selected by native links.
    var reaction_names: Dictionary = {}
    for group: String in REACTION_PROFILES:
        for profile: Variant in Dictionary(REACTION_PROFILES[group]).values():
            reaction_names[String(profile.get("animation", ""))] = true
    for group: String in EXACT_REACTIONS:
        for profile: Variant in EXACT_REACTIONS[group]:
            reaction_names[String(profile.get("animation", ""))] = true
    for group: String in _native_reactions:
        for profile: Variant in _native_reactions[group]:
            reaction_names[String(profile.get("animation", ""))] = true
    for reaction_name: String in reaction_names:
        var matched: String = _find_animation_clip(_candidate_animation, reaction_name)
        _candidate_clip_paths.erase(reaction_name)
        if not matched.is_empty() and _candidate_skeleton != null:
            if _prepare_candidate_reaction(_candidate_animation.get_animation(matched)):
                _candidate_clip_paths[reaction_name] = matched
    for anim_name: String in _candidate_animation.get_animation_list():
        var native_name: String = anim_name.get_file()
        if reaction_names.has(native_name):
            continue
        if not _candidate_clip_paths.values().has(anim_name):
            _candidate_clip_paths[anim_name] = anim_name
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
            IDLE2_CLIP, IDLE3_CLIP, FACEDOWN_IDLE_CLIP, BRICK_FACEDOWN_IDLE_CLIP, FACEDOWN_GETUP_CLIP,
            FACEDOWN_IMPACT_CLIP, FACEDOWN_ATTACK_CLIP,
            FACEUP_IMPACT_TO_FLOOR_CLIP, FACEUP_IDLE_CLIP,
            FACEUP_GETUP_CLIP, FACEUP_ATTACK_CLIP, FACEUP_IMPACT_CLIP,
            ATTACK_TO_FLOOR_CLIP, BRICK_FRONT_LOW_CLIP,
            "m03_blck_high", "all_block_low", "all_block_mid",
            "all_impct_hard_frnt_high",
            "all_impct_light_frnt_low", "all_impct_light_frnt_mid",
            "all_impct_light_frnt_high",
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
        IDLE2_CLIP, IDLE3_CLIP, FACEDOWN_IDLE_CLIP, BRICK_FACEDOWN_IDLE_CLIP, FACEUP_IDLE_CLIP,
        "all_idle_face_down_forbigguy", "all_idle_face_up_forbigguy",
        "all_idle_face_down_forsmallguy", "all_idle_face_up_forsmallguy",
        "move", "movefwd", "moveback", "moveleft", "moveright", "stepfwd", "stepback",
        "stepleft", "stepright",
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
    _snapshot_size_variant_base_paths()
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
        var path_text: String = String(clip.track_get_path(track))
        # The GLB wraps the authored character under Z_up_to_glTF_Y_up/root,
        # so resolving the absolute track path can miss the character node.
        # Its position track carries the per-clip source translation (for
        # m01_kck_front_step it drives the visible mesh down/forward) and must
        # never move the visual by itself; gameplay uses attack_root_motion.
        if target == _candidate_character or path_text == "character" \
                or path_text.ends_with("/character"):
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
    # The candidate idle clip contains a visible two-beat body sway. After a
    # solitary attack the port would loop that sway and make every move look
    # like a failed recoil. Hold the first idle pose instead.
    _candidate_animation.speed_scale = (
        0.0 if action in ["idle", "idle2", "idle3"] else 1.0
    )
    if blend_applied:
        _candidate_animation.play(candidate_animation_clip, blend_seconds)
    else:
        _candidate_animation.play(candidate_animation_clip)
    if action in ["idle", "idle2", "idle3"]:
        _candidate_animation.seek(0.0, true)
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
    return state in ["idle", "idle2", "idle3"]


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
    last_reaction_entry_frame = 0
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


func _enter_locomotion_state(next_state: String, start_frame: int = 0) -> void:
    var previous_state: String = state
    state = next_state
    state_time = float(start_frame) / SOURCE_FRAME_RATE
    attack_kind = ""
    _clear_link_state()
    _clear_reaction_tracking()
    if (candidate_visual_blending_enabled
            and previous_state == "attacktofloor"
            and next_state == "idle2"
            and _candidate_action == ATTACK_TO_FLOOR_CLIP
            and _candidate_animation != null
            and _candidate_animation.is_playing()):
        _queue_candidate_visual_blend(
            float(_native_link_blending_from(
                        "attacktofloor", "idle2",
                        0
                    )) / SOURCE_FRAME_RATE
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
    if (bool(attack_set_profile.get("facedown_low_impact", false))
            and last_reaction_source_action == "impacthardfrontlow"
            and last_reaction_animation == String(
                attack_set_profile.get("front_low_clip", BRICK_FRONT_LOW_CLIP)
            )
            and reaction_clip_ready
            and _candidate_clip_paths.has(_facedown_idle_clip())):
        return "facedownidle"
    if (reaction_clip_ready
            and return_action == "idle2"
            and _candidate_clip_paths.has(IDLE2_CLIP)):
        return "idle2"
    if (reaction_clip_ready
            and return_action == "facedownidle"
            and _candidate_clip_paths.has(_facedown_idle_clip())
            and _candidate_clip_paths.has(FACEDOWN_GETUP_CLIP)):
        return "facedownidle"
    if (reaction_clip_ready
            and return_action == "faceupidle"
            and _candidate_clip_paths.has(_faceup_idle_clip())):
        return "faceupidle"
    return "idle"


func _stun_step_seconds(source: String, target: String, fallback_frames: int) -> float:
    # Duration of a stun state comes from its outgoing link window start.
    for link: Dictionary in _native_links:
        if _link_text(link, "from") == source and _link_text(link, "to") == target:
            var window: Array = Array(link.get("time", []))
            if not window.is_empty():
                return float(window[0]) / SOURCE_FRAME_RATE
    return float(fallback_frames) / SOURCE_FRAME_RATE


func _advance_impactstun_state(delta: float) -> void:
    state_time -= delta
    if state_time > 0.000001:
        return
    state = "stun"
    state_time = _stun_step_seconds("stun", "stun2", STUN_DURATION_FRAMES)


func _advance_stun_state(delta: float) -> void:
    state_time -= delta
    if state_time > 0.000001:
        return
    # The next stun state comes from the current action's outgoing links:
    # stun -> stun2 [55,61], stun2 -> stunfall [55,61], stunfall -> faceupko [71,79].
    var from_state: String = state
    for target: String in ["stun2", "stunfall", "faceupko"]:
        if not _has_native_link(from_state, target):
            continue
        if target == "faceupko":
            _begin_faceup_ko(0.0)
            return
        state = target
        state_time = _stun_step_seconds(from_state, target, STUN_DURATION_FRAMES)
        return
    _begin_faceup_ko(0.0)


func _stun_impact_reaction(impact: Dictionary) -> Dictionary:
    # Recovered stun-impact targets (pose "stun") and their outgoing links.
    var strength: String = String(impact.get("strength", ""))
    var height: String = String(impact.get("height", ""))
    var wanted: String = ""
    if height == "medium":
        wanted = "stunmediumimpact"
    elif strength == "hard":
        wanted = "stunhardimpact"
    elif strength == "brutal":
        wanted = "stunbrutalimpact"
    elif strength == "normal":
        wanted = "stunlighthighimpact" if height == "high" else (
            "stunlightlowimpact" if height == "low" else "stunmediumimpact")
    if wanted.is_empty():
        return {}
    var row: Dictionary = _native_actions.get(wanted, {})
    if row.is_empty() or String(row.get("pose", "")) != "stun":
        return {}
    for link: Dictionary in _native_links:
        if _link_text(link, "from") != wanted:
            continue
        var target: String = _link_text(link, "to")
        if target not in ["faceupko", "facedownko", "stunfall"]:
            continue
        var window: Array = Array(link.get("time", []))
        if window.is_empty():
            continue
        return {
            "target": wanted,
            "animation": String(row.get("animation", "")),
            "exit_frame": int(window[0]),
            "next_state": target,
        }
    return {}


func _has_native_link(source: String, target: String) -> bool:
    for link: Dictionary in _native_links:
        if _link_text(link, "from") == source and _link_text(link, "to") == target:
            return true
    return false


func _advance_stun_impact_state(delta: float) -> void:
    state_time -= delta
    if state_time > 0.000001:
        return
    if _stun_impact_next_state == "stunfall":
        state = "stunfall"
        state_time = _stun_step_seconds("stunfall", "faceupko", STUN_FALL_DURATION_FRAMES)
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
    if state == "idle3":
        state_time += maxf(delta, 0.0)
        _wrap_return_loop(IDLE3_DURATION_FRAMES)
        return
    if state == "facedownidle":
        var before: float = state_time
        state_time += maxf(delta, 0.0)
        if (bool(attack_set_profile.get("facedown_getup", true))
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
        if _reached_source_frame(state_time, _native_link_start_frame("facedownattack", FACEDOWN_ATTACK_EXIT_FRAME)):
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
        if _reached_source_frame(state_time, _native_link_start_frame("attacktofloor", ATTACK_TO_FLOOR_EXIT_START_FRAME)):
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
        if _reached_source_frame(state_time, _native_link_start_frame("faceupattack", FACEUP_ATTACK_EXIT_FRAME)):
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
    _restart_candidate_action()


func _begin_faceup_getup() -> void:
    state = "faceupgetup"
    state_time = 0.0
    attack_kind = ""
    _clear_reaction_tracking()
    _restart_candidate_action()


func _accepts_facedown_low_impact(impact_height: String, blocked: bool, damage: float) -> bool:
    return (
        state == "facedownidle"
        and not bool(attack_set_profile.get("facedown_low_impact", false))
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
            and source_frame + 0.0001 >= 22.0
            and source_frame <= 28.0001)
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
        and _candidate_clip_paths.has(_faceup_idle_clip())
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
        and _candidate_clip_paths.has(_faceup_idle_clip())
    )


func _accepts_faceup_ko(damage: float, blocked: bool) -> bool:
    return (
        state == "faceupidle"
        and not blocked
        and health - damage <= 0.0
        and _candidate_clip_paths.has(_faceup_idle_clip())
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
    combo_hits = 0
    _clear_reaction_tracking()
    _restart_candidate_action()


func begin_facedown_impact(amount: float) -> void:
    health = maxf(0.0, health - amount)
    state = "impactfacedown"
    state_time = 0.0
    attack_kind = ""
    _attack_connected = false
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
    combo_hits = 0
    last_reaction_group = "hit"
    last_reaction_source_action = "impactfaceup"
    last_reaction_animation = FACEUP_IMPACT_CLIP
    last_reaction_exit_frame = FACEUP_IMPACT_EXIT_FRAME
    last_reaction_clip_implemented = _candidate_clip_paths.has(FACEUP_IMPACT_CLIP)
    _restart_candidate_action()


func record_standing_combo_press(
        virtual_key: String,
        modifiers: Array = []
) -> bool:
    # Decompiled model: a press becomes an event with a consumed bit. Links are
    # re-evaluated against that event queue every physics update; no wall-clock
    # combo window and no FIFO of attacks.
    if not _accepts_link_input(virtual_key):
        _clear_link_state()
        return false
    var tokens: Array = [virtual_key]
    for modifier: Variant in modifiers:
        var token: String = String(modifier)
        if not tokens.has(token):
            tokens.append(token)
    _link_events.append({
        "tokens": tokens,
        "consumed": false,
        "time_ms": int(_time * 1000.0),
    })
    return _try_follow_links()


func begin_guard() -> void:
    # Decompiled guard path rejects link input, so the event queue is dropped.
    guard_held = true
    _clear_link_state()


func end_guard() -> void:
    guard_held = false


func _accepts_link_input(virtual_key: String) -> bool:
    # Guard rejects attack requests, so it must also reject combo history.
    # Otherwise a press made while guarding becomes the first key of a later
    # sequence.
    if (guard_held
            or not attack_set_profile.is_empty()
            or virtual_key not in [
                "a", "b", "c", "d",
                "up", "down", "left", "right", "in", "out",
            ]
            or state not in ["idle", "idle2", "idle3", "startup", "active", "recovery",
                "facedownidle", "faceupidle"]):
        return false
    return true


func _expire_link_events() -> void:
    # CBeatEmUpGame::Update: last event timestamp + 500 < now -> mark the whole
    # vector consumed (not deleted); pruning the consumed batch keeps the port's
    # queue bounded and cannot change matching, because consumed events never
    # match again.
    if _link_events.is_empty():
        return
    var now_ms: int = int(_time * 1000.0)
    var last_ms: int = int(_link_events.back().get("time_ms", now_ms))
    if last_ms + LINK_EVENT_LIFETIME_MS >= now_ms:
        return
    _link_events.clear()


func _clear_link_events() -> void:
    _link_events.clear()


func _clear_link_state() -> void:
    _clear_link_events()


func _link_sequence_matches(entry: Dictionary) -> bool:
    # krm::CFighter::InputSequenceCheck: scan events backwards, skip unconsumed
    # matches only when the step matches, and skip every consumed event.
    var steps: Array = entry["steps"]
    if steps.is_empty():
        return true
    var has_key: bool = false
    for step: Variant in steps:
        if not Array(step).is_empty():
            has_key = true
            break
    if not has_key:
        return true
    var required: int = steps.size() - 1
    for event_index: int in range(_link_events.size() - 1, -1, -1):
        var event: Dictionary = _link_events[event_index]
        if bool(event["consumed"]):
            continue
        if not _event_satisfies_step(event, steps[required]):
            continue
        required -= 1
        if required < 0:
            return true
    return false


func _facing_window_ok() -> bool:
    # CFighter::FacingUpdate only turns to the opponent while the current
    # action's recovered facing window allows it (for example grab1 = [0,1]).
    var action: String = _current_action_name()
    if action.is_empty():
        return true
    var window: Variant = _native_actions.get(action, {}).get("facing")
    if not window is Array or Array(window).size() < 2:
        return true
    var start: int = int(window[0])
    var end: int = int(window[1])
    if start > end:
        return false
    var frame: float = _current_attack_source_frame()
    if frame < 0.0:
        frame = 0.0
    return frame + 0.0001 >= float(start) and frame <= float(end) + 0.0001


func _current_action_name() -> String:
    if ATTACKS.has(attack_kind):
        var source_action: String = str(ATTACKS[attack_kind].get("source_action", ""))
        if not source_action.is_empty():
            return source_action
    if state in ["facedownidle", "faceupidle"]:
        return state
    if state in ["idle", "idle2", "idle3"]:
        # Movement animations are native actions too: special_kick_high is a
        # direct link from stepback, so the current action must report it.
        var movement: String = _native_movement_action()
        if not movement.is_empty():
            return movement
        return state
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
        effective.erase("in")
        effective.erase("out")
    if effective.size() > required_tokens.size():
        return false
    for token: Variant in required_tokens:
        var token_text: String = String(token)
        if not effective.has(token_text):
            # Native InputStatusCheck also accepts a held direction; a press
            # edge alone is not required for a directional step.
            var held_token: String = token_text
            if held_token.begins_with("press"):
                held_token = held_token.substr(5)
            var held_ok: bool = false
            match held_token:
                "down", "out":
                    held_ok = bool(held_directions.get("down", false))
                "up", "in":
                    held_ok = bool(held_directions.get("up", false))
                "left":
                    held_ok = bool(held_directions.get("left", false))
                "right":
                    held_ok = bool(held_directions.get("right", false))
            if not held_ok:
                return false
    return true


func _current_attack_source_frame() -> float:
    if state not in ["startup", "active", "recovery"] or not ATTACKS.has(attack_kind):
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


func _link_text(link: Dictionary, key: String) -> String:
    var value: Variant = link.get(key)
    if value == null:
        return ""
    return str(value)


func _native_link_unique_ok(link: Dictionary) -> bool:
    # Recovered unique links name the character-specific action variant, for
    # example grababrucelee / grababrick. Skip other characters' variants.
    var unique: Array = Array(link.get("unique", []))
    if unique.is_empty():
        return true
    var tag: String = String(attack_set_profile.get("link_tag", "brucelee"))
    for value: Variant in unique:
        if String(value).to_lower().contains(tag):
            return true
    return false


func _native_link_applies(link: Dictionary) -> bool:
    var action: String = _current_action_name()
    if action.is_empty():
        return false
    var source: String = _link_text(link, "from")
    if not source.is_empty():
        return source == action
    var group: String = _link_text(link, "from_group")
    if group.is_empty():
        return false
    var action_row: Dictionary = _native_actions.get(action, {})
    var groups: Dictionary = action_row.get("groups", {})
    return groups.has(group)


func _native_link_window(link: Dictionary) -> Array:
    return _native_link_window_for_action(link, _current_action_name())


func _native_link_window_for_action(link: Dictionary, action: String) -> Array:
    var source: String = _link_text(link, "from")
    if not source.is_empty():
        return Array(link.get("time", []))
    var action_row: Dictionary = _native_actions.get(action, {})
    var groups: Dictionary = action_row.get("groups", {})
    var group: String = _link_text(link, "from_group")
    if not groups.has(group):
        return []
    var entry: Variant = groups[group]
    if not entry is Array or entry.size() < 2:
        return []
    var window: Array = [int(entry[0]), int(entry[1])]
    if entry.size() >= 3:
        window.append(int(entry[2]))
    return window


func source_state_time_for_target(source_kind: String, target_action: String) -> float:
    # Place the primed source animation at the start of the target link window
    # so training and preview scenarios exercise a real link instead of a fixed
    # 1.5 s recovery guess.
    if not ATTACKS.has(source_kind):
        return 0.0
    var action: String = str(ATTACKS[source_kind].get("source_action", ""))
    var target_native: String = target_action
    if ATTACKS.has(target_action):
        var target_source: String = str(ATTACKS[target_action].get("source_action", ""))
        if not target_source.is_empty():
            target_native = target_source
    # If the target is reached from another action (for example a miss action
    # followed by an automatic hit link), prime at the entry link instead.
    for link: Dictionary in _native_links:
        if _link_text(link, "to") != target_native:
            continue
        var entry_source: String = _link_text(link, "from")
        if not entry_source.is_empty() and not kind_for_action(entry_source).is_empty():
            target_native = entry_source
        break
    var frame_count: float = float(ATTACKS[source_kind]["animation_frame_count"])
    var best_entry_frame: float = -1.0
    for link: Dictionary in _native_links:
        if _link_text(link, "to") != target_native:
            continue
        var applies: bool = false
        var source: String = _link_text(link, "from")
        if not source.is_empty():
            applies = source == action
        else:
            var groups: Dictionary = _native_actions.get(action, {}).get("groups", {})
            applies = groups.has(_link_text(link, "from_group"))
        if not applies:
            continue
        var window: Array = _native_link_window_for_action(link, action)
        if window.size() < 2:
            continue
        var frame: float = float(window[0]) + 1.0
        if window.size() >= 3:
            frame = maxf(frame, float(window[2]) + 1.0)
        # A target can have several native entry links (for example lowkick3
        # has a [17,27] basic-attack link and a [11,16] combo link). Prime at
        # the earliest applicable entry, not merely the first link in order.
        if best_entry_frame < 0.0 or frame < best_entry_frame:
            best_entry_frame = frame
    if best_entry_frame >= 0.0:
        return maxf(
            (frame_count - best_entry_frame) / SOURCE_FRAME_RATE,
            1.0 / SOURCE_FRAME_RATE
        )
    return 0.0


func link_requirements_for_target(target_kind: String) -> Dictionary:
    # Held-key requirements declared by the native link that lands on this
    # move (InputStatusCheck data). Used by training/preview scenarios.
    var result: Dictionary = {}
    var native_target: String = target_kind
    if ATTACKS.has(target_kind):
        var target_source: String = str(ATTACKS[target_kind].get("source_action", ""))
        if not target_source.is_empty():
            native_target = target_source
    for link: Dictionary in _native_links:
        if _link_text(link, "to") != native_target:
            continue
        for pair_value: Variant in Array(link.get("status", [])):
            var pair: Array = pair_value
            if pair.size() >= 2:
                result[str(pair[0])] = str(pair[1]) == "pressed"
        return result
    return result


func _native_link_window_ok(link: Dictionary, previous_frame: float = -1.0) -> bool:
    if state in ["idle", "idle2", "idle3", "facedownidle", "faceupidle"]:
        return true
    var window: Array = _native_link_window(link)
    if window.size() < 2:
        return false
    var frame: float = _current_attack_source_frame()
    if frame < 0.0:
        return false
    var start: float = float(window[0])
    var end: float = float(window[1])
    if window.size() >= 3:
        start = maxf(start, float(window[2]))
    var linking_frame: int = int(link.get("linking_frame", 0))
    if linking_frame > 0 and frame + 0.0001 < float(linking_frame):
        return false
    # A large physics delta can jump over a 2-3 frame automatic link window.
    # Treat the interval [previous_frame, frame] as open if it overlaps the
    # native window, instead of requiring the post-step frame to be inside it.
    if previous_frame >= 0.0:
        return (previous_frame <= end + 0.0001
                and frame + 0.0001 >= start)
    return frame + 0.0001 >= start and frame <= end + 0.0001


func link_source_action_for_target(target_kind: String) -> String:
    var native_target: String = target_kind
    if ATTACKS.has(target_kind):
        var target_source: String = str(ATTACKS[target_kind].get("source_action", ""))
        if not target_source.is_empty():
            native_target = target_source
    for link: Dictionary in _native_links:
        if _link_text(link, "to") != native_target:
            continue
        return _link_text(link, "from")
    return ""


func kind_for_action(action: String) -> String:
    return String(_action_to_attack.get(action, ""))


func link_sequence_for_target(target_kind: String) -> Array[String]:
    # Keys of the native link that lands on this move, in the variant selected
    # by the active input layout.
    var native_target: String = target_kind
    if ATTACKS.has(target_kind):
        var target_source: String = str(ATTACKS[target_kind].get("source_action", ""))
        if not target_source.is_empty():
            native_target = target_source
    var result: Array[String] = []
    for link: Dictionary in _native_links:
        if _link_text(link, "to") != native_target:
            continue
        for step: Variant in Array(link.get("steps", [])):
            var tokens: Array = Array(step)
            if not tokens.is_empty():
                result.append(str(tokens[0]))
        return result
    return result


func _native_link_status_ok(link: Dictionary) -> bool:
    # status is the flat pair list of the selected key-status variant.
    var status: Array = link.get("status", [])
    for pair_value: Variant in status:
        var pair: Array = pair_value
        if pair.size() < 2:
            continue
        var token: String = str(pair[0])
        if token == "impossible":
            return false
        var want_pressed: bool = str(pair[1]) == "pressed"
        if bool(_key_status.get(token, false)) != want_pressed:
            return false
    return true


func _opponent_distance() -> float:
    if opponent == null or not is_instance_valid(opponent):
        return 9999.0
    return Vector2(
        opponent.global_position.x - global_position.x,
        opponent.global_position.z - global_position.z).length()


func _fighter_pose() -> String:
    # Recovered action pose: stand / laying / crouch / stun / jump.
    if state in ["hitstun", "blockstun", "stun", "stun2", "stunfall",
            "stunimpact", "impactstun"]:
        return "stun"
    if state in ["facedownidle", "facedownko", "facedowngetup", "facedownattack",
            "impactfacedown", "impacttofloor", "faceupidle", "faceupko",
            "faceupgetup", "faceupattack", "impactfaceup", "attacktofloor"]:
        return "laying"
    var action: String = _current_action_name()
    var row: Dictionary = _native_actions.get(action, {})
    var pose: String = String(row.get("pose", ""))
    if not pose.is_empty():
        return pose
    if state in ["idle", "idle2", "idle3"]:
        return "stand"
    return ""


func _native_condition_ok(condition: String, link: Dictionary) -> bool:
    match condition:
        "oppposestun":
            return opponent != null and is_instance_valid(opponent) \
                and opponent._fighter_pose() == "stun"
        "oppposelaying":
            return opponent != null and is_instance_valid(opponent) \
                and opponent._fighter_pose() == "laying"
        "oppposestand":
            return opponent != null and is_instance_valid(opponent) \
                and opponent._fighter_pose() == "stand"
        "oppnotblocking":
            return opponent == null or not opponent.guard_held
        "grabdistance":
            # The action's attack record stores grab_distance in source units.
            var to_action: String = _link_text(link, "to")
            if to_action == "specialkicklowhit":
                # SPECIAL LOW KICK's hit link is a kick, not a grab; the
                # recovered grab_distance is too strict for the kick radius.
                var low_kind: String = String(_action_to_attack.get(to_action, ""))
                if not low_kind.is_empty() and ATTACKS.has(low_kind):
                    return _opponent_distance() <= attack_reach_world(low_kind, opponent)
            var raw_grab: Variant = _native_actions.get(
                to_action, {}).get("grab_distance")
            if raw_grab == null:
                # No recovered grab_distance: fail closed rather than guess.
                return false
            return _opponent_distance() <= float(raw_grab) * source_units_to_world
        "ragethird":
            # CheckConditions @1b3db0 compares rage < 0x21(33) => false.
            return rage >= float(int(RAGE_MAX / 3.0))
        "rage2thirds":
            # CheckConditions @1b3db0 compares rage < 0x42(66) => false.
            return rage >= float(int(RAGE_MAX * 2.0 / 3.0))
        "healthzero":
            return opponent != null and is_instance_valid(opponent) and opponent.health <= 0.0
        "impact":
            return _attack_hit_landed
        "countertime":
            # IsInCounterTime: the opponent's animation frame must be inside the
            # attack's counter_time window, which brucelee.set stores inside the
            # action's attack record (for example [0,8] on lowpunch1/highpunch1).
            if opponent == null or not is_instance_valid(opponent):
                return false
            var opponent_action: String = opponent._current_action_name()
            var counter_window: Variant = _native_actions.get(
                opponent_action, {}).get("counter_time")
            if not counter_window is Array or Array(counter_window).size() < 2:
                return false
            var counter_frame: float = opponent._current_attack_source_frame()
            if counter_frame < 0.0:
                return false
            return (counter_frame + 0.0001 >= float(counter_window[0])
                    and counter_frame <= float(counter_window[1]) + 0.0001)
        "oppattackheightlow":
            return _opponent_impact_is("height", ["low"])
        "oppattackheightmed":
            return _opponent_impact_is("height", ["medium", "med"])
        "oppattackheighthigh":
            return _opponent_impact_is("height", ["high"])
        "oppattackstrengthnormal":
            return _opponent_impact_is("strength", ["normal"])
        "oppattackstrengthmedium":
            return _opponent_impact_is("strength", ["medium"])
        "oppattackstrengthhard":
            return _opponent_impact_is("strength", ["hard"])
        "oppattackstrengthbrutal":
            return _opponent_impact_is("strength", ["brutal"])
        "oppattackdirfrontal":
            return _opponent_impact_is("direction", ["frontal"])
        "oppattackdirfromleft":
            return _opponent_impact_is("direction", ["fromleft"])
        "oppattackdirfromright":
            return _opponent_impact_is("direction", ["fromright"])
        "oppattackdirfromabove":
            return _opponent_impact_is("direction", ["fromabove"])
        _:
            # Unknown condition: fail closed.
            return false


func _opponent_impact_is(field: String, accepted: Array) -> bool:
    # oppattack* conditions compare the incoming attack's first impact, which
    # brucelee.set stores as attack.impacts[0].{height,strength,direction}.
    # Each fighter's own config carries this, so Brick attacks resolve too.
    if opponent == null or not is_instance_valid(opponent):
        return false
    var details: Dictionary = opponent.ATTACKS.get(opponent.attack_kind, {})
    var impact: Variant = details.get("source_impact")
    if not impact is Dictionary or Dictionary(impact).is_empty():
        impact = _native_actions.get(
            opponent._current_action_name(), {}).get("impact")
    if not impact is Dictionary:
        return false
    return String(Dictionary(impact).get(field, "")) in accepted


func _native_link_conditions_ok(link: Dictionary) -> bool:
    for condition: Variant in Array(link.get("conditions", [])):
        if not _native_condition_ok(String(condition), link):
            return false
    return true


func _native_target_kind(link: Dictionary) -> String:
    var target_action: String = _link_text(link, "to")
    if target_action == "attacktofloor":
        return "attacktofloor"
    return String(_action_to_attack.get(target_action, ""))


func _consume_link_events(link: Dictionary) -> void:
    # krm::CFighter::ConsumeEvents: mark the matched events consumed.
    var steps: Array = link["steps"]
    if steps.is_empty():
        # Automatic follow-ups have no input step; nothing to consume.
        return
    var required: int = steps.size() - 1
    for event_index: int in range(_link_events.size() - 1, -1, -1):
        var event: Dictionary = _link_events[event_index]
        # Decompiled ConsumeEvents scans from the end and writes +0x10 = 1 on
        # string matches without checking its previous value.
        if not _event_satisfies_step(event, steps[required]):
            continue
        event["consumed"] = true
        required -= 1
        if required < 0:
            return


func _auto_link_release_ok(link: Dictionary) -> bool:
    # A small class of automatic links is gated by the source action's
    # impactable window. parryhigh -> parryattack is the concrete case: the
    # link is [9,10], but parryhigh only becomes impactable at frame 30, and
    # the parry absorb must survive until then. Keep the native link shape but
    # release it when the absorb happened or the impactable window opened.
    var steps: Array = Array(link.get("steps", []))
    if not steps.is_empty():
        return true
    var source: String = _link_text(link, "from")
    if source.is_empty():
        return true
    var row: Dictionary = _native_actions.get(source, {})
    if row.is_empty() or row.get("impact") != null:
        return true
    var groups: Variant = row.get("groups")
    if not groups is Dictionary:
        return true
    var impactable: Variant = Dictionary(groups).get("impactable")
    if not impactable is Array or Array(impactable).size() < 2:
        return true
    var window: Array = _native_link_window(link)
    if window.size() < 2:
        return true
    var impactable_start: int = int(Array(impactable)[0])
    if impactable_start <= int(window[1]):
        return true
    return _parry_absorbed or _current_attack_source_frame() >= float(impactable_start)


func _try_follow_links() -> bool:
    # krm::CFighter::UserControlUpdate: walk the current animation's links in
    # native order. TimeWindowCheck + InputSequenceCheck + InputStatusCheck +
    # CheckConditions, then FollowLink + ConsumeEvents.
    if state not in ["idle", "idle2", "idle3", "startup", "active", "recovery",
            "facedownidle", "faceupidle"]:
        return false
    _expire_link_events()
    var scan_action: String = _current_action_name()
    var scan_frame: float = _current_attack_source_frame()
    if scan_action != _link_scan_action:
        _link_scan_previous_frame = -1.0
    var previous_scan_frame: float = _link_scan_previous_frame
    _link_scan_action = scan_action
    _link_scan_previous_frame = scan_frame
    for link: Dictionary in _native_links:
        if not _native_link_applies(link):
            continue
        if not _native_link_unique_ok(link):
            continue
        if not _native_link_window_ok(link, previous_scan_frame):
            continue
        if not _auto_link_release_ok(link):
            continue
        if not _link_sequence_matches(link):
            continue
        if not _native_link_status_ok(link):
            continue
        if not _native_link_conditions_ok(link):
            continue
        var ground_target: String = _link_text(link, "to")
        if ground_target == "facedownattack" or ground_target == "faceupattack":
            var ground_clip: String = (
                FACEDOWN_ATTACK_CLIP if ground_target == "facedownattack"
                else FACEUP_ATTACK_CLIP
            )
            if not _candidate_clip_paths.has(ground_clip):
                continue
            _consume_link_events(link)
            if _link_text(link, "input_reset") == "true":
                _clear_link_events()
            _begin_ground_attack(ground_target)
            return true
        var target: String = _native_target_kind(link)
        if target.is_empty():
            continue
        var consume_all: bool = _link_text(link, "input_reset") == "true"
        if target == "attacktofloor":
            if (not _candidate_clip_paths.has(ATTACK_TO_FLOOR_CLIP)
                    or not _candidate_clip_paths.has(IDLE2_CLIP)):
                continue
            _consume_link_events(link)
            if consume_all:
                _clear_link_events()
            _begin_attack_to_floor()
            return true
        if not ATTACKS.has(target):
            continue
        # Size-class versions are resolved before the link is consumed: a
        # required but missing version must not swallow the input and must not
        # start the chained grab/finisher with the wrong-size clip.
        if not _prepare_size_variant(target):
            continue
        if not _begin_chained_attack(
            target,
            int(link.get("entry_frame", 0)),
            int(link.get("blending", 0))
        ):
            continue
        # The native link conditions (ragethird / rage2thirds) gate on the
        # meter; the set has no per-link rage cost field, so do not spend here.
        _consume_link_events(link)
        if consume_all:
            _clear_link_events()
        return true
    return false


func _normalize_press_token(token: String) -> String:
    match token:
        "pressa":
            return "a"
        "pressb":
            return "b"
        "pressc":
            return "c"
        "pressd":
            return "d"
        "pressup":
            return "up"
        "pressdown":
            return "down"
        "pressleft":
            return "left"
        "pressright":
            return "right"
        "pressin":
            return "in"
        "pressout":
            return "out"
    return token


func _load_native_links() -> void:
    var path: String = String(
        attack_set_profile.get("native_links", NATIVE_LINKS_PATH)
    )
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Native link metadata is missing: " + path)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        push_error("Native link metadata is invalid")
        return
    for action: Variant in parsed.get("actions", []):
        if action is Dictionary:
            _native_actions[str(action.get("name", ""))] = action
    for link_value: Variant in parsed.get("links", []):
        if not link_value is Dictionary:
            continue
        var link: Dictionary = link_value
        var sequences: Array = Array(link.get("keysequence", []))
        var variant: Array = []
        if LINK_SEQUENCE_INDEX < sequences.size():
            variant = Array(sequences[LINK_SEQUENCE_INDEX])
        var steps: Array = []
        for token: Variant in variant:
            # Each key of the selected variant is one event; a two-key variant
            # such as [in, a] is an ordered two-press sequence.
            steps.append([_normalize_press_token(str(token))])
        var status_variants: Array = Array(link.get("keystatus", []))
        var status: Array = []
        if LINK_SEQUENCE_INDEX < status_variants.size():
            for pair_value: Variant in Array(status_variants[LINK_SEQUENCE_INDEX]):
                var pair: Array = pair_value
                if pair.size() >= 2:
                    status.append([str(pair[0]), str(pair[1])])
        link["steps"] = steps
        link["status"] = status
        _native_links.append(link)
    for kind: String in ATTACKS:
        var source_action: String = str(ATTACKS[kind].get("source_action", ""))
        if not source_action.is_empty() and not _action_to_attack.has(source_action):
            _action_to_attack[source_action] = kind
    # These actions are code-defined in the port and have no low-attacks JSON
    # source_action; their native action name is the attack kind itself.
    for alias: String in ["facedownattack", "faceupattack", "attacktofloor"]:
        if ATTACKS.has(alias) and not _action_to_attack.has(alias):
            _action_to_attack[alias] = alias
    _build_native_reactions()


func set_key_status(tokens: Dictionary) -> void:
    _key_status = tokens


func _candidate_action_for_attack(kind: String) -> String:
    match kind:
        "punch":
            return "punch"
        "kick":
            return "kick"
        "high_punch", "high_kick", "low_punch", "low_kick", "high_punch3", "low_punch3", "low_kick3", "high_kick3", "special_kick_high", "high_punch2", "low_punch2", "high_kick2", "low_kick2", "special_kick_low_miss", "special_kick_low_hit", "special_punch_low_miss", "special_punch_low_hit", "special_punch_high_miss", "special_punch_high_hit", "special_kick_high_brick", "special_kick_low_brick", "special_punch_high_brick", "special_punch_low_brick", "parry_high_brick", "parry_low_brick", "parry_attack_brick", "grab1_brick", "grab2_brick", "attack_to_floor_brick", "endattack_brick", "grab1_miss_brick", "grab2_miss_brick", "parry_high", "parry_low", "parry_attack", "grab1", "grab2", "grab1_miss", "grab2_miss", "grabbed1", "grabbed2", "endattack1", "endattack2":
            return kind
    return ""


func _begin_ground_attack(attack_state: String) -> void:
    # facedownidle/faceupidle -> facedownattack/faceupattack is a native direct
    # link; the target is a ground state, not an ATTACKS entry.
    state = attack_state
    state_time = 0.0
    attack_kind = attack_state
    attack_sequence += 1
    _attack_connected = false
    _restart_candidate_action()


func _begin_attack_to_floor() -> void:
    var previous_state: String = state
    state = "attacktofloor"
    state_time = float(_native_entry_frame("attacktofloor", 0)) / SOURCE_FRAME_RATE
    attack_kind = "attacktofloor"
    attack_sequence += 1
    _attack_connected = false
    attack_started.emit("attacktofloor")
    if (candidate_visual_blending_enabled
            and previous_state in ["idle", "idle2", "idle3"]
            and _candidate_animation != null
            and _candidate_animation.is_playing()):
        _queue_candidate_visual_blend(
            float(_native_link_blending_to("attacktofloor", 0)) / SOURCE_FRAME_RATE
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


func request_attack(kind: String) -> bool:
    if guard_held or not ATTACKS.has(kind):
        return false
    if not _uses_standing_idle_rules():
        # The grab finisher starts from the tail of the grab attack while the
        # victim is still held; other attacks still require a standing idle,
        # except inside a recovered group cancel window (attacktofloor [45,..]).
        if not (kind == "endattack_brick"
                and state in ["startup", "active", "recovery"]
                and opponent != null and is_instance_valid(opponent)
                and opponent.state in ["grabbed1", "grabbed2"]):
            if not attack_cancel_window_open():
                return false
    if not _prepare_size_variant(kind):
        # The original selects the grab/finisher clip from the opponent's
        # skeleton class. A required version the candidate cannot play is a
        # refusal, never a fall back to the wrong-size base clip.
        push_warning(character_name + " " + kind + " refused: " + size_variant_error)
        return false
    attack_kind = kind
    attack_sequence += 1
    _attack_connected = false
    _parry_absorbed = false
    _attack_hit_landed = false
    _grab_connected = false
    _endattack_victim_started = false
    _multi_impact_applied.clear()
    state = "startup"
    state_time = float(ATTACKS[kind]["startup"])
    _seed_attack_root_motion()
    attack_started.emit(kind)
    return true


func _polar_movement(speed: float) -> Vector3:
    # WASD is expressed in the opponent-relative frame: the pole is the
    # midpoint between both fighters, A/D change the radius and W/S change the
    # angle around that pole. The camera sits on the perpendicular bisector.
    if opponent == null or not is_instance_valid(opponent):
        return Vector3(move_axis.x, 0.0, move_axis.y).normalized() * speed
    if move_axis.length_squared() <= 0.000001:
        return Vector3.ZERO
    # Orbit the opponent, not the moving midpoint: the midpoint moves as
    # only one fighter moves and would otherwise make the radius drift.
    var center: Vector3 = opponent.global_position
    var radial: Vector3 = global_position - center
    radial.y = 0.0
    if radial.length_squared() <= 0.000001:
        return Vector3(move_axis.x, 0.0, move_axis.y).normalized() * speed
    var radius: float = radial.length()
    var away: Vector3 = radial / radius
    var tangent: Vector3 = Vector3(-away.z, 0.0, away.x)
    # A/D move along the fighter line (radial), W/S orbit around the midpoint
    # (angular). D goes toward the opponent, A away; S goes down-screen and W
    # up-screen. Scale tangential speed by radius so angular speed does not
    # explode when the fighters are very close.
    var radial_motion: Vector3 = away * (-move_axis.x) * speed
    var angular_speed: float = speed * clampf(radius / 2.0, 0.0, 1.0)
    var tangent_motion: Vector3 = tangent * (-move_axis.y) * angular_speed
    return radial_motion + tangent_motion


func _physics_process(delta: float) -> void:
    _time += delta
    if opponent != null and is_instance_valid(opponent) and _facing_window_ok():
        var to_opponent: Vector3 = opponent.global_position - global_position
        to_opponent.y = 0.0
        if to_opponent.length_squared() > 0.000001:
            facing = 1.0 if to_opponent.x >= 0.0 else -1.0
            # Turn the torso toward the opponent in the whole ground plane,
            # not just between +X and -X.
            rotation.y = atan2(-to_opponent.z, to_opponent.x)
    if guard_held:
        # Raising guard between two presses must not keep a partial sequence or
        # a matched-but-unexecuted combo alive.
        _clear_link_state()
    _apply_attack_root_motion()
    _advance_timed_states(delta)
    if ((attack_kind == "endattack_brick" or ENDATTACK_ATTACKS.has(attack_kind))
            and state == "active"
            and not _endattack_victim_started
            and opponent != null and is_instance_valid(opponent)
            and opponent.state in ["grabbed1", "grabbed2"]):
        if opponent.begin_endattack_victim():
            _endattack_victim_started = true
    _try_follow_links()
    if (state == "active" and ATTACKS.has(attack_kind)
            and not NON_CONTACT_ATTACKS.has(attack_kind)
            and Array(ATTACKS[attack_kind].get("multi_impacts", [])).is_empty()
            and not _attack_connected):
        _try_attack_contact()
    var motion: Vector3 = Vector3.ZERO
    _advance_locomotion_visual(delta)
    var root_driven: bool = (
        _uses_standing_idle_rules()
        and not guard_held
        and not _locomotion_action.is_empty()
        and _movement_root_tracks.has(_movement_root_clip_for_action(_locomotion_action))
    )
    if root_driven:
        var root_delta: Vector3 = _locomotion_root_delta()
        global_position += root_delta
        global_position.x = clampf(global_position.x, -ARENA_HALF_X, ARENA_HALF_X)
        global_position.z = clampf(global_position.z, -ARENA_HALF_Z, ARENA_HALF_Z)
        velocity = root_delta / maxf(delta, 0.0001)
    else:
        if _uses_standing_idle_rules() and not guard_held:
            motion = (_polar_movement(BASE_SPEED) if polar_movement_enabled
                    else Vector3(move_axis.x, 0.0, move_axis.y).normalized() * BASE_SPEED)
        elif _uses_standing_idle_rules() and guard_held:
            motion = (_polar_movement(BASE_SPEED * 0.25) if polar_movement_enabled
                    else Vector3(move_axis.x, 0.0, move_axis.y).normalized() * BASE_SPEED * 0.25)
        velocity.x = motion.x
        velocity.z = motion.z
        if is_on_floor():
            velocity.y = 0.0
        else:
            velocity.y -= 12.0 * delta
        move_and_slide()
        position.x = clampf(position.x, -ARENA_HALF_X, ARENA_HALF_X)
        position.z = clampf(position.z, -ARENA_HALF_Z, ARENA_HALF_Z)
    _animate_visuals()
    _animate_candidate()

func _advance_locomotion_visual(delta: float) -> void:
    if not _uses_standing_idle_rules():
        _locomotion_action = ""
        _locomotion_time = 0.0
        return
    var base: String = _native_movement_action()
    if base.is_empty():
        _locomotion_action = ""
        _locomotion_time = 0.0
        return
    var family_move: String = String(LOCOMOTION_STEP_TO_MOVE.get(base, ""))
    if _locomotion_action.is_empty() or (
            _locomotion_action != base
            and _locomotion_action != family_move
    ):
        _locomotion_action = base
        _locomotion_time = 0.0
        _locomotion_root_ready = false
    _locomotion_time += delta
    if (_locomotion_action.begins_with("step")
            and not family_move.is_empty()
            and _candidate_clip_paths.has(family_move)
            and _locomotion_time >= LOCOMOTION_CHAIN_FRAME / SOURCE_FRAME_RATE):
        _locomotion_action = family_move
        _locomotion_time = 0.0
        _locomotion_root_ready = false
    var active_clip: String = _movement_root_clip_for_action(_locomotion_action)
    if _movement_root_tracks.has(active_clip):
        var track: Array = _movement_root_tracks[active_clip]
        var max_time: float = float(maxi(track.size() - 1, 1)) / SOURCE_FRAME_RATE
        if _locomotion_time > max_time:
            _locomotion_time = fmod(_locomotion_time, max_time)
            _locomotion_root_ready = false

func _advance_timed_states(delta: float) -> void:
    if state in ["grabbed1", "grabbed2"]:
        state_time -= delta
        if state_time <= 0.000001:
            state = "facedownidle" if state == "grabbed1" else "faceupidle"
            state_time = 0.0
            attack_kind = ""
            _restart_candidate_action()
        return
    if state in ["endattackcomp1", "endattackcomp2"]:
        state_time -= delta
        if state_time <= 0.000001:
            _begin_faceup_ko(0.0)
        return
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
        "idle2", "idle3", "facedownidle", "facedownko", "facedowngetup",
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
                    ):
                _try_attack_contact()
        if (state == "active"
                and ATTACKS.has(attack_kind)
                and not Array(ATTACKS[attack_kind].get("multi_impacts", [])).is_empty()
                and remaining > (1.0 / SOURCE_FRAME_RATE) + 0.000001
                and state_time > (1.0 / SOURCE_FRAME_RATE) + 0.000001):
            # A large physics step must not skip later multi-impact windows:
            # advance one source frame at a time while the active state lasts.
            var multi_frame_step: float = 1.0 / SOURCE_FRAME_RATE
            remaining -= multi_frame_step
            state_time -= multi_frame_step
            _apply_attack_root_motion()
            continue
        if remaining < state_time:
            state_time -= remaining
            _apply_attack_root_motion()
            return
        remaining -= maxf(state_time, 0.0)
        state_time = 0.0
        _apply_attack_root_motion()
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
        if _multi_impact_applied.is_empty() and distance > reach:
            continue
        # Once the first impact lands, later impacts still belong to the same
        # connected sequence. Block push or grab hold motion can move the
        # target slightly outside the opening reach or behind the facing line;
        # do not discard the remaining connected hits.
        if (_multi_impact_applied.is_empty() and dx * facing < -0.1
                and not GRAB_ATTACKS.has(attack_kind)):
            continue
        var blocked: bool = opponent.guard_held and (
            opponent._can_block_current_hit() or opponent.state == "blockstun")
        var reaction: Dictionary = opponent.reaction_for_incoming(impact, blocked)
        var damage: float = float(impact["damage"])
        _multi_impact_applied.append(index)
        if not opponent.receive_hit(damage, blocked, 0.0, facing, reaction):
            continue
        _attack_connected = true
        if (not blocked and opponent.health > 0.0
                and GRAB_VICTIM_DATA.has(attack_kind)):
            opponent.begin_grabbed(attack_kind)
        _register_landed_hit(damage, blocked)
        combat_hit.emit(self, opponent, attack_kind, damage, blocked)


func _apply_attack_start_frame(kind: String, start_frame: int) -> void:
    # FollowLink entry_frame: the target animation starts at this source frame.
    var details: Dictionary = ATTACKS.get(kind, {})
    if details.is_empty():
        return
    var fps: float = SOURCE_FRAME_RATE
    var startup_frames: float = float(details.get("startup", 0.0)) * fps
    var active_frames: float = float(details.get("active", 0.0)) * fps
    var total_frames: float = float(details.get("animation_frame_count", 0))
    var frame: float = clampf(float(start_frame), 0.0, maxf(total_frames - 1.0, 0.0))
    if frame < startup_frames:
        state = "startup"
        state_time = (startup_frames - frame) / fps
    elif frame < startup_frames + active_frames:
        state = "active"
        state_time = (startup_frames + active_frames - frame) / fps
    else:
        state = "recovery"
        state_time = maxf((total_frames - frame) / fps, 0.0)


func _begin_chained_attack(
        kind: String, start_frame: int = 0, blend_frames: int = 0
) -> bool:
    # Native first links for the special moves are the miss/fail animations.
    # They are not useful as playable moves; go straight to the hit variants.
    if kind in ["special_kick_low_miss", "special_punch_low_miss",
            "special_punch_high_miss"]:
        var hit_kind: String = kind.replace("_miss", "_hit")
        if ATTACKS.has(hit_kind):
            kind = hit_kind
    # A link target that is a grab/finisher must pass the same size-class gate as
    # a requested attack, otherwise the link would play the base clip.
    if not _prepare_size_variant(kind):
        push_warning(character_name + " " + kind + " link refused: " + size_variant_error)
        return false
    attack_kind = kind
    var rage_cost: float = _action_rage_value(kind)
    if rage_cost < 0.0:
        # Recovered special-move cost (for example -66 on the miss actions).
        rage = maxf(0.0, rage + rage_cost)
    attack_sequence += 1
    _attack_connected = false
    _parry_absorbed = false
    _attack_hit_landed = false
    _grab_connected = false
    _endattack_victim_started = false
    _multi_impact_applied.clear()
    _apply_attack_start_frame(kind, start_frame)
    _seed_attack_root_motion()
    _restart_candidate_action()
    if blend_frames > 0:
        _queue_candidate_visual_blend(float(blend_frames) / SOURCE_FRAME_RATE)
    attack_started.emit(kind)
    return true


func _native_link_blending_to(target_action: String, fallback: int) -> int:
    for link: Dictionary in _native_links:
        if _link_text(link, "to") != target_action:
            continue
        var blending: int = int(link.get("blending", 0))
        if blending > 0:
            return blending
    return fallback


func _native_link_blending_from(source_action: String, target_action: String, fallback: int) -> int:
    for link: Dictionary in _native_links:
        if _link_text(link, "from") != source_action:
            continue
        if _link_text(link, "to") != target_action:
            continue
        var blending: int = int(link.get("blending", 0))
        if blending > 0:
            return blending
    return fallback


func _native_entry_frame(target_action: String, fallback: int) -> int:
    # FollowLink entry_frame recorded on links that target this action.
    for link: Dictionary in _native_links:
        if _link_text(link, "to") != target_action:
            continue
        var entry_value: Variant = link.get("entry_frame")
        if typeof(entry_value) == TYPE_INT or typeof(entry_value) == TYPE_FLOAT:
            return int(entry_value)
    return fallback


func attack_cancel_window_start() -> int:
    ## Native group-window start for the current action, or -1 when the action
    ## has no recovered cancel window.  Frames are source frames at 30 fps.
    var action: String = _current_action_name()
    if action.is_empty():
        return -1
    if not ATTACK_CANCEL_START_FRAMES.has(action):
        return -1
    return int(ATTACK_CANCEL_START_FRAMES[action])


func attack_cancel_window_open() -> bool:
    var start: int = attack_cancel_window_start()
    if start < 0:
        return false
    if not ATTACKS.has(attack_kind):
        return false
    var frame: float = state_time * SOURCE_FRAME_RATE
    var duration: float = float(ATTACKS[attack_kind]["animation_frame_count"])
    return frame + 0.0001 >= float(start) and frame <= duration + 0.0001


func _native_link_start_frame(source_action: String, fallback: int) -> int:
    # Window start of the action's outgoing link (return/exit frame).
    for link: Dictionary in _native_links:
        if _link_text(link, "from") != source_action:
            continue
        var window: Array = Array(link.get("time", []))
        if window.size() >= 2:
            return int(window[0])
    return fallback


func _native_recovery_return() -> Dictionary:
    # The end-of-attack state comes from the current action's outgoing link to
    # idle/idle2/idle3 (for example lowpunch3 -> idle2 [51,81], entry_frame 5).
    var action: String = _current_action_name()
    if action.is_empty():
        return {}
    var frame: float = _current_attack_source_frame()
    for link: Dictionary in _native_links:
        if _link_text(link, "from") != action:
            continue
        var target: String = _link_text(link, "to")
        if target not in ["idle", "idle2", "idle3"]:
            continue
        var window: Array = Array(link.get("time", []))
        if window.size() >= 2 and frame + 0.0001 >= float(window[0]):
            return {
                "state": target,
                "entry_frame": int(link.get("entry_frame", 0)),
            }
    return {}


func _advance_state() -> void:
    match state:
        "startup":
            state = "active"
            state_time = float(ATTACKS[attack_kind]["active"])
        "active":
            state = "recovery"
            state_time = float(ATTACKS[attack_kind]["recovery"])
        "grabbed1", "grabbed2":
            state = "facedownidle" if state == "grabbed1" else "faceupidle"
            state_time = 0.0
            attack_kind = ""
            _restart_candidate_action()
        "recovery", "hitstun", "blockstun":
            if state == "recovery":
                var native_return: Dictionary = _native_recovery_return()
                if not native_return.is_empty():
                    _enter_locomotion_state(
                        String(native_return["state"]),
                        int(native_return.get("entry_frame", 0))
                    )
                    return
                _enter_locomotion_state("idle")
                return
            _enter_locomotion_state(_verified_post_hit_return_state())


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


func _action_rage_value(action: String) -> float:
    # Positive action.rage values are recovered rage gain; negative values are
    # special-move costs (for example -33 / -66).
    var row: Dictionary = _native_actions.get(action, {})
    var value: Variant = row.get("rage")
    if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
        return float(value)
    return 0.0


func _register_landed_hit(damage: float, blocked: bool) -> void:
    combo_hits += 1
    if damage > 0.0 and not blocked:
        _attack_hit_landed = true
        if GRAB_ATTACKS.has(attack_kind):
            _grab_connected = true
        var rage_gain: float = _action_rage_value(_current_action_name())
        if rage_gain > 0.0:
            rage = minf(RAGE_MAX, rage + rage_gain)


func _attacker_set_suffix() -> String:
    if opponent == null or not is_instance_valid(opponent):
        return ""
    return String(VICTIM_OPPONENT_SUFFIX.get(opponent.attack_config_path, ""))


func _victim_clip_available(animation: String) -> String:
    # Match the set's clip name against the victim's AnimationPlayer. The
    # candidate may store a "<prefix>/<name>" variant, so return the playable
    # name, or "" when the clip is absent. No substitute is guessed.
    if animation.is_empty() or _candidate_animation == null:
        return ""
    var matched: String = _find_animation_clip(_candidate_animation, animation)
    if matched.is_empty() or not _candidate_clip_paths.values().has(matched):
        return ""
    return matched


func _select_grab_victim_clip(slot_key: String) -> bool:
    # slot_key is grabbed1/grabbed2; the set action is grabcompl1/2 <attacker>.
    var suffix: String = _attacker_set_suffix()
    if suffix.is_empty():
        return false
    var action: String = (
        "grabcompl" + slot_key.substr(slot_key.length() - 1) + " " + suffix
    )
    var row: Dictionary = _native_actions.get(action, {})
    var animation: String = String(row.get("animation", ""))
    var matched: String = _victim_clip_available(animation)
    if matched.is_empty():
        return false
    _candidate_clip_paths[slot_key] = matched
    _victim_selected_animation[slot_key] = animation
    return true


func _select_endattack_victim_clip(slot_key: String) -> bool:
    # slot_key is endattackcomp1/endattackcomp2. Only thai/karate carry a
    # prefixed action; kungfu has none and therefore fails closed.
    if opponent == null or not is_instance_valid(opponent):
        return false
    var prefix: String = String(
        ENDATTACK_OPPONENT_ACTION.get(opponent.attack_config_path, "")
    )
    if prefix.is_empty():
        return false
    var action: String = prefix + " " + slot_key.substr(slot_key.length() - 1)
    var row: Dictionary = _native_actions.get(action, {})
    var animation: String = String(row.get("animation", ""))
    var matched: String = _victim_clip_available(animation)
    if matched.is_empty():
        return false
    _candidate_clip_paths[slot_key] = matched
    _victim_selected_animation[slot_key] = animation
    return true


func _apply_victim_size_variant(slot_key: String) -> bool:
    ## The victim clips can carry their own size version (Animations.versions
    ## "opp_skeleton" on a grabbed/endattackcomp clip). Resolve it against the
    ## archived clip name the set selected and fail closed when it is missing.
    var animation: String = String(
        _victim_selected_animation.get(
            slot_key, String(candidate_clips.get(slot_key, ""))
        )
    )
    if animation.is_empty():
        return true
    if not candidate_loaded:
        # Placeholder rig: no candidate clip exists to swap for a version.
        return true
    if not _apply_size_variant(slot_key, animation):
        push_warning(
            character_name + " " + slot_key + " refused: " + size_variant_error
        )
        return false
    return true


func begin_grabbed(kind: String) -> bool:
    var data: Array = GRAB_VICTIM_DATA.get(kind, [])
    if data.is_empty():
        return false
    var clip_key: String = String(data[0])
    if not _candidate_clip_paths.has(clip_key):
        return false
    # The player's static map holds only the Thai victim set; use his recovered
    # per-opponent action instead, and refuse the grab if the variant is absent.
    if is_player and not _select_grab_victim_clip(clip_key):
        return false
    if not _apply_victim_size_variant(clip_key):
        return false
    state = clip_key
    state_time = float(data[1]) / SOURCE_FRAME_RATE
    attack_kind = ""
    _attack_connected = false
    _restart_candidate_action()
    return true


func begin_endattack_victim() -> bool:
    var data: Array = ENDATTACK_VICTIM_DATA.get(state, [])
    if data.is_empty():
        return false
    var clip_key: String = String(data[0])
    if not _candidate_clip_paths.has(clip_key):
        return false
    if is_player and not _select_endattack_victim_clip(clip_key):
        return false
    if not _apply_victim_size_variant(clip_key):
        return false
    state = clip_key
    state_time = float(data[1]) / SOURCE_FRAME_RATE
    attack_kind = ""
    _attack_connected = false
    _restart_candidate_action()
    return true


func _try_attack_contact() -> void:
    if (opponent == null or not is_instance_valid(opponent)
            or opponent.state in ["ko", "facedownko"]):
        return
    var details: Dictionary = ATTACKS[attack_kind]
    var damage: float = float(details["damage"])
    # Recovered miss/parry actions carry damage 0; they must not put the
    # opponent into hitstun or invalidate oppposestand before the follow-up
    # link resolves.
    if damage <= 0.0:
        _attack_connected = true
        return
    var dx: float = opponent.global_position.x - global_position.x
    var dz: float = opponent.global_position.z - global_position.z
    var distance: float = Vector2(dx, dz).length()
    if distance > attack_reach_world(attack_kind, opponent):
        return
    if dx * facing < -0.1:
        return
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
            damage, blocked, 0.0, facing, reaction
        )
    if not accepted:
        return
    _attack_connected = true
    _register_landed_hit(damage, blocked)
    combat_hit.emit(self, opponent, attack_kind, damage, blocked)
    if not blocked and opponent.health > 0.0 and GRAB_VICTIM_DATA.has(attack_kind):
        opponent.begin_grabbed(attack_kind)


func current_source_animation() -> String:
    if (state in ["hitstun", "blockstun"]
            and not last_reaction_animation.is_empty()):
        return last_reaction_animation
    if state in ["startup", "active", "recovery"] and ATTACKS.has(attack_kind):
        return String(ATTACKS[attack_kind]["animation"])
    if state in ["stun", "stun2"]:
        return STUN_CLIP
    if state == "stunfall":
        return STUN_FALL_CLIP
    if state in ["stunimpact", "impactstun"] and not last_reaction_animation.is_empty():
        return last_reaction_animation
    if state in ["idle", "idle2", "idle3"]:
        var movement_action: String = _native_movement_action()
        if not movement_action.is_empty():
            return String(candidate_clips.get(movement_action, candidate_clips["idle"]))
    if state == "idle2":
        return IDLE2_CLIP
    if state == "idle3":
        return IDLE3_CLIP
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
        return _faceup_idle_clip()
    if state == "faceupidle":
        return _faceup_idle_clip()
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
    if (not attack_set_profile.is_empty()
            and state not in ["idle", "facedownidle", "impactfacedown"]):
        return ""
    var animation: String = current_source_animation()
    # A logical state that lacks its validated visual clip must not report a
    # source pose. This keeps downstream checks fail-closed.
    var clip_key: String = "idle" if state == "idle" else animation
    if not _candidate_clip_paths.has(clip_key):
        return ""
    return String(SOURCE_ACTION_POSES[state])


func set_held_directions(directions: Dictionary) -> void:
    held_directions = directions.duplicate()


func _native_movement_action() -> String:
    # Native step links: left -> stepback, right -> stepfwd, in/up ->
    # stepright, out/down -> stepleft. Held-key flags are used instead of the
    # net movement vector so holding A (stepback) survives pressing D + L.
    if not held_directions.is_empty():
        # Native link status: left=stepback, right=stepfwd, in/up=stepright,
        # out/down=stepleft. Vertical setup keys take priority when a second
        # direction is pressed for a special command (S + D, W + A, ...).
        if bool(held_directions.get("down", false)):
            return "stepleft"
        if bool(held_directions.get("up", false)):
            return "stepright"
        if bool(held_directions.get("left", false)):
            return "stepback"
        if bool(held_directions.get("right", false)):
            return "stepfwd"
    var x: float = move_axis.x
    var y: float = move_axis.y
    if absf(x) <= 0.001 and absf(y) <= 0.001:
        return ""
    # Fallback when a caller has not supplied held-key flags yet (tests and
    # training setup): native axes are left=stepback, right=stepfwd,
    # out/down=stepleft, in/up=stepright.
    if absf(y) > 0.001:
        var vertical: String = "stepleft" if y > 0.0 else "stepright"
        if _native_actions.has(vertical):
            return vertical
        return _movement_action()
    var horizontal: String = "stepback" if x < 0.0 else "stepfwd"
    if _native_actions.has(horizontal):
        return horizontal
    return _movement_action()


func _movement_action() -> String:
    var x: float = move_axis.x
    var y: float = move_axis.y
    if absf(x) <= 0.001 and absf(y) <= 0.001:
        return ""
    var action: String
    if absf(x) >= absf(y):
        action = "moveleft" if x < 0.0 else "moveright"
    else:
        action = "stepfwd" if y < 0.0 else "stepback"
    if _candidate_clip_paths.has(action):
        return action
    if _candidate_clip_paths.has("move"):
        return "move"
    return ""


func _owner_idle_animation() -> String:
    if candidate_clips.has("idle"):
        return String(candidate_clips["idle"])
    return String(CANDIDATE_CLIPS["idle"])


func _facedown_idle_clip() -> String:
    ## all_idle_face_down is versioned by the owner's own skeleton class. A
    ## required version the candidate lacks yields "" (fail closed); otherwise a
    ## resolved class version wins, and the profile value remains the base.
    var resolved: String = _resolved_ground_idle(FACEDOWN_IDLE_CLIP)
    if resolved.is_empty() and ground_idle_status_last == "unavailable":
        return ""
    if not resolved.is_empty() and resolved != FACEDOWN_IDLE_CLIP:
        return resolved
    return String(attack_set_profile.get("facedown_idle_clip", FACEDOWN_IDLE_CLIP))


func _faceup_idle_clip() -> String:
    ## all_idle_face_up is versioned by the owner's own skeleton class.
    return _resolved_ground_idle(FACEUP_IDLE_CLIP)


func _stored_animation_radius(animation: String) -> float:
    if (animation == FACEDOWN_IMPACT_CLIP
            and attack_set_profile.has("facedown_impact_radius")):
        # thai.set action 92 uses radius 85, kungfu.set/karate.set use 80 for
        # the same animation, so this value is character-config specific.
        return float(attack_set_profile["facedown_impact_radius"])
    if (state in ["stunimpact", "impactstun"]
            and STUN_IMPACT_SOURCE_RADII.has(animation)
            and _is_number(STUN_IMPACT_SOURCE_RADII[animation])):
        return float(STUN_IMPACT_SOURCE_RADII[animation])
    if source_animation_radii.has(animation) and _is_number(source_animation_radii[animation]):
        return float(source_animation_radii[animation])
    if RETURN_ANIMATION_RADII.has(animation) and _is_number(RETURN_ANIMATION_RADII[animation]):
        return float(RETURN_ANIMATION_RADII[animation])
    var profile: Dictionary = _profile_for_animation(animation)
    if profile.has("animation_radius") and _is_number(profile["animation_radius"]):
        return float(profile["animation_radius"])
    return -1.0


func _profile_for_animation(animation: String) -> Dictionary:
    if (animation == String(attack_set_profile.get("front_low_clip", BRICK_FRONT_LOW_CLIP))
            and attack_set_profile.has("front_low_reaction")):
        return attack_set_profile["front_low_reaction"]
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
    if state == "impacttofloor":
        # all_stunned_fall is shared with stunfall; the recovered impact action
        # uses radius 75 while stunfall uses 70.
        return 75.0 * radius_scale
    # These three overrides are brucelee.set values for actions whose ANM is
    # shared with another clip. Mapped set configs load their own per-action
    # radii from the set, so the overrides must not leak into them.
    if attack_set_profile.is_empty():
        if state in ["startup", "active", "recovery"] and attack_kind == "parry_attack":
            # The recovered parryattack action uses radius 25 although its ANM is
            # shared with m01_pnch_high_03 (60 in the generic animation table).
            return 25.0 * radius_scale
        if state in ["startup", "active", "recovery"] and attack_kind == "parry_low":
            # The recovered parrylow action uses 40 although m01_kick_low_02's
            # generic table entry is 50.
            return 40.0 * radius_scale
        if (state in ["startup", "active", "recovery"]
                and attack_kind == "special_punch_low_miss"):
            # The recovered specialpunchlowmiss action uses 45 although the shared
            # m01_sp_pnch_low_fail table entry is 25.
            return 45.0 * radius_scale
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
    if (attack_set_profile.has("front_high_reaction") and not blocked
            and String(impact.get("strength", "")) == "hard"
            and String(impact.get("height", "")) == "high"
            and String(impact.get("direction", "")) == "frontal"
            and _candidate_clip_paths.has("all_impct_hard_frnt_high")):
        var front_high: Dictionary = (
            attack_set_profile["front_high_reaction"].duplicate(true)
        )
        front_high["source_action"] = "impacthardfronthigh"
        front_high["linking_frame"] = 0
        return front_high
    var exact: Dictionary = _matching_exact_reaction(impact, blocked)
    if not exact.is_empty():
        if (String(exact.get("source_action", "")) in [
                    "impactbrutalmid", "impactbrutalleft", "impactbrutalright",
                    "impactlightlefthigh", "impactlightrighthigh",
                    "impactlightleftlow", "impactlightrightlow",
                    "impacthardleftlow", "impacthardlefthigh", "impacthardabove",
                    "impacthardfrontlow",
                ] and not _medium_lethal_impactable()):
            return {}
        return exact
    # Hard and brutal attacks have no light-height fallback for hits when the
    # exact link is absent, but blocking still uses the block profile.
    if not blocked and String(impact.get("strength", "")) != "normal":
        return {}
    return _reaction_profile_for_impact(impact, blocked)


func _is_brick_facedown_low_impact(impact: Dictionary, blocked: bool) -> bool:
    return (
        bool(attack_set_profile.get("facedown_low_impact", false))
        and state == "facedownidle"
        and not blocked
        and String(impact.get("height", "")) == "low"
    )


func _is_brick_facedown_impact_reaction(reaction: Dictionary) -> bool:
    return (
        bool(attack_set_profile.get("facedown_low_impact", false))
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
    var front_low: String = String(
        attack_set_profile.get("front_low_clip", BRICK_FRONT_LOW_CLIP)
    )
    return (
        bool(attack_set_profile.get("facedown_low_impact", false))
        and candidate_loaded
        and mapped_state
        and not blocked
        and health - damage > 0.0
        and _candidate_clip_paths.has(front_low)
        and _candidate_clip_paths.has(_facedown_idle_clip())
    )


func _build_native_reactions() -> void:
    # Reaction links target impact*/block* actions whose conditions encode the
    # incoming impact. Only animations present in the candidate are used.
    _native_reactions = {"hit": [], "block": []}
    for link: Dictionary in _native_links:
        var target: String = _link_text(link, "to")
        if target.is_empty():
            continue
        var is_block: bool = target.contains("block")
        var is_hit: bool = target.begins_with("impact")
        if not is_block and not is_hit:
            continue
        var row: Dictionary = _native_actions.get(target, {})
        var animation: String = String(row.get("animation", ""))
        if animation.is_empty():
            continue
        var conditions: Array = Array(link.get("conditions", []))
        if not conditions.has("impact"):
            continue
        var strength: String = _condition_attribute(conditions, "oppattackstrength")
        var height: String = _condition_attribute(conditions, "oppattackheight")
        var direction: String = _condition_attribute(conditions, "oppattackdir")
        if strength.is_empty():
            continue
        var exit_start: int = -1
        var duration: int = -1
        var return_action: String = "idle"
        for out: Dictionary in _native_links:
            if _link_text(out, "from") != target:
                continue
            var out_target: String = _link_text(out, "to")
            if out_target in ["idle", "idle2", "faceupidle", "facedownidle"]:
                var window: Array = Array(out.get("time", []))
                if window.size() >= 2:
                    exit_start = int(window[0])
                    duration = int(window[1])
                    return_action = out_target
                break
        if exit_start < 0:
            continue
        var entry: Dictionary = {
            "strength": strength,
            "height": height,
            "direction": direction,
            "source_action": target,
            "animation": animation,
            "exit_start_frame": exit_start,
            "animation_duration_frames": duration,
            "linking_frame": 0,
            "return_action": return_action,
        }
        var group: String = "block" if is_block else "hit"
        var group_entries: Array = _native_reactions[group]
        group_entries.append(entry)


func _condition_attribute(conditions: Array, prefix: String) -> String:
    for condition: Variant in conditions:
        var text: String = String(condition)
        if text.begins_with(prefix):
            var suffix: String = text.substr(prefix.length())
            if suffix == "med":
                return "medium"
            return suffix
    return ""


func _matching_exact_reaction(impact: Dictionary, blocked: bool) -> Dictionary:
    var group: String = "block" if blocked else "hit"
    var entries_value: Variant = EXACT_REACTIONS.get(group, [])
    if _native_reactions.get(group, []).size() > 0:
        var merged: Array = []
        if entries_value is Array:
            merged.append_array(entries_value)
        for native_entry: Variant in _native_reactions[group]:
            if native_entry is Dictionary and _candidate_clip_paths.has(
                    String(Dictionary(native_entry).get("animation", ""))):
                merged.append(native_entry)
        entries_value = merged
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
    if state == "idle3":
        return state_time * SOURCE_FRAME_RATE <= 143.0001
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


func _action_impactable_start(kind: String) -> int:
    # Start of the action's recovered impactable group window, or -1.
    if not ATTACKS.has(kind):
        return -1
    var action: String = String(ATTACKS[kind].get("source_action", ""))
    var groups: Variant = _native_actions.get(action, {}).get("groups")
    if not groups is Dictionary:
        return -1
    var window: Variant = Dictionary(groups).get("impactable")
    if not window is Array or Array(window).size() < 2:
        return -1
    return int(window[0])


func receive_hit(
        amount: float,
        blocked: bool,
        push: float,
        direction: float,
        reaction: Dictionary = {}
) -> bool:
    if (state in ["startup", "active", "recovery"]
            and attack_kind in ["parry_high", "parry_low"]):
        # parryhigh is impactable only from its recovered impactable start
        # (brucelee.set: parryhigh [30,62]); before that the parry absorbs.
        var impactable_start: int = _action_impactable_start(attack_kind)
        var absorb_until: float = float(impactable_start) if impactable_start >= 0 else 25.0
        if _current_attack_source_frame() < absorb_until:
            _parry_absorbed = true
            parry_succeeded.emit(attack_kind)
            return false
    if (state in ["startup", "active", "recovery"]
            and attack_kind in ["parry_high_brick", "parry_low_brick"]):
        # thai.set marks parryhigh/parrylow impactable only from frame 25.
        # Absorb earlier incoming strikes so the parry window is defensive.
        if _current_attack_source_frame() < 25.0:
            return false
    if (state in ["startup", "active"]
            and attack_kind in ["parry_attack", "parry_attack_brick"]):
        # The prototype counter owns the exchange once the parry chains.
        return false
    # A real hit/block cancels unconsumed link events. Parry/counter returns
    # above do not clear them, so their own follow-up inputs survive.
    _clear_link_state()
    # faceupgetup and faceupattack still keep unverified incoming hits
    # out of the standing hitstun/blockstun/KO paths until those links have
    # their own evidence-backed transitions.
    if state in ["stun", "stun2"] and not blocked:
        var stun_source: String = String(reaction.get("source_action", ""))
        var stun_animation: String = ""
        var stun_exit_frame: int = 0
        var stun_next_state: String = "stunfall"
        var native_stun: Dictionary = _stun_impact_reaction(reaction)
        if (not native_stun.is_empty()
                and _candidate_clip_paths.has(String(native_stun["animation"]))):
            stun_animation = String(native_stun["animation"])
            stun_exit_frame = int(native_stun["exit_frame"])
            stun_next_state = String(native_stun["next_state"])
        elif stun_source == "impactlightfronthigh":
            stun_animation = "all_impct_light_frnt_high"
            stun_exit_frame = _native_link_start_frame("impactlightfronthigh", 0)
        elif stun_source == "impactlightfrontlow":
            stun_animation = "all_impct_light_frnt_low"
            stun_exit_frame = _native_link_start_frame("impactlightfrontlow", 0)
        elif stun_source == "impactlightfrontmid":
            stun_animation = "all_impct_crotch"
            stun_exit_frame = _native_link_start_frame("impactlightfrontmid", 0)
        elif stun_source.begins_with("impacthard"):
            stun_animation = "stun_hard"
            stun_exit_frame = _native_link_start_frame("impacthardfronthigh", 0)
            stun_next_state = "faceupko"
        elif stun_source == "stunbrutalimpact":
            stun_animation = "stun_brutal"
            stun_exit_frame = _native_link_start_frame("stunbrutalimpact", 0)
            stun_next_state = "facedownko"
        else:
            return false
        if not _candidate_clip_paths.has(stun_animation):
            return false
        var stun_push_source: float = float(
            REACTION_ROOT_PUSH_SOURCE.get(stun_source, -1.0)
        )
        if stun_source == "stunbrutalimpact":
            # stun_brutal uses the spectacular-left source animation; use the
            # corresponding decoded reaction positions as a prototype input.
            stun_push_source = float(REACTION_ROOT_PUSH_SOURCE.get("impactbrutalleft", -1.0))
        if stun_push_source >= 0.0:
            position.x = clampf(
                position.x + direction * stun_push_source * source_units_to_world,
                -ARENA_HALF_X, ARENA_HALF_X
            )
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
    # Outside their verified impactable windows, nonlethal hits must not fall
    # through to standing hitstun. Lethal hits still reach the healthzero path.
    if (state in ["facedowngetup", "facedownattack", "impacttofloor"]
            and health - amount > 0.0):
        return false
    var state_before: String = state
    var medium_lethal_eligible: bool = _medium_lethal_impactable()
    var reaction_root_source: float = float(
        REACTION_ROOT_PUSH_SOURCE.get(String(reaction.get("source_action", "")), -1.0)
    )
    if reaction_root_source >= 0.0:
        # The reaction's decoded root position component is the push input.
        push = reaction_root_source * source_units_to_world
    else:
        # No recovered reaction root: do not apply the invented prototype push.
        push = 0.0
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
    if (not blocked and health - amount <= 0.0
            and state_before == "facedownidle"
            and _candidate_clip_paths.has(_facedown_idle_clip())):
        # A lethal hit cannot promote an already-downed opponent into the
        # standing impactstun/faceupko path. Prefer the source healthzero edge.
        health = maxf(0.0, health - amount)
        position.x = position_before
        _begin_facedown_ko()
        return true
    _attack_connected = false
    # Being hit cancels a sequence that matched during the interrupted attack.
    _clear_link_state()
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
        last_reaction_entry_frame = int(reaction.get("entry_frame", 0))
        var configured_clip: bool = reaction.get("clip_implemented", true) == true
        var prepared_clip: bool = _candidate_clip_paths.has(last_reaction_animation)
        last_reaction_clip_implemented = configured_clip or prepared_clip
        state_time = float(maxi(last_reaction_exit_frame - last_reaction_entry_frame, 0)) / SOURCE_FRAME_RATE
    else:
        last_reaction_source_action = ""
        last_reaction_animation = ""
        last_reaction_exit_frame = -1
        last_reaction_entry_frame = 0
        last_reaction_clip_implemented = false
    position.x = clampf(position.x + direction * push * (0.30 if blocked else 1.0), -ARENA_HALF_X, ARENA_HALF_X)
    if (health <= 0.0 and not blocked
            and _candidate_clip_paths.has("all_impct_hard_frnt_high")
            and last_reaction_source_action == "impacthardfronthigh"):
        # Source link 113: healthzero -> faceupko at [23,29].
        state = "stunimpact"
        state_time = float(_native_link_start_frame("impacthardfronthigh", 0)) / SOURCE_FRAME_RATE
        combo_hits = 0
        last_reaction_source_action = "impacthardfronthigh"
        last_reaction_animation = "all_impct_hard_frnt_high"
        last_reaction_exit_frame = _native_link_start_frame("impacthardfronthigh", 0)
        last_reaction_entry_frame = 0
        last_reaction_clip_implemented = true
        _stun_impact_next_state = "faceupko"
        if _candidate_animation != null:
            _candidate_animation.stop()
        _candidate_action = ""
        candidate_visual_blend_pending_seconds = 0.0
        return true
    if (health <= 0.0 and not blocked
            and _candidate_clip_paths.has("all_impct_hard_frnt_low")
            and last_reaction_source_action in [
                "impacthardfrontlow", "impacthardfrontmid"
            ]):
        # Source links 213/214/228: hard medium/low frontal lethal hits use
        # impacthardfrontlow; link 289 then enters facedownko at [21,23].
        state = "stunimpact"
        state_time = float(_native_link_start_frame("impacthardfrontlow", 0)) / SOURCE_FRAME_RATE
        combo_hits = 0
        last_reaction_source_action = "impacthardfrontlow"
        last_reaction_animation = "all_impct_hard_frnt_low"
        last_reaction_exit_frame = _native_link_start_frame("impacthardfrontlow", 0)
        last_reaction_entry_frame = 0
        last_reaction_clip_implemented = true
        _stun_impact_next_state = "facedownko"
        if _candidate_animation != null:
            _candidate_animation.stop()
        _candidate_action = ""
        candidate_visual_blend_pending_seconds = 0.0
        return true
    var stun_entry_source: String = String(reaction.get("source_action", ""))
    var stun_entry_clip: String = (
        "all_impct_light_frnt_low"
        if stun_entry_source in [
            "impactlightfrontlow", "impactlightleftlow",
            "impactlightrightlow", "impactlightfrontmid"
        ]
        else "all_impct_light_frnt_high"
    )
    if (health <= 0.0 and not blocked
            and _candidate_clip_paths.has("stun")
            and _candidate_clip_paths.has(stun_entry_clip)
            and (stun_entry_source in [
                    "impactlightfronthigh", "impactlightlefthigh",
                    "impactlightrighthigh", "impactlightfrontlow",
                    "impactlightleftlow", "impactlightrightlow"
                ] or (stun_entry_source == "impactlightfrontmid" and medium_lethal_eligible))):
        # Source impactstun high/low links land at [14,17] before stun; this
        # prototype plays the matching impact reaction for 14 frames first.
        state = "impactstun"
        state_time = float(_native_link_start_frame("impactstunhigh", STUN_IMPACT_ENTRY_FRAMES)) / SOURCE_FRAME_RATE
        combo_hits = 0
        last_reaction_group = "hit"
        last_reaction_source_action = "impactstun"
        last_reaction_animation = stun_entry_clip
        last_reaction_exit_frame = _native_link_start_frame("impactstunhigh", STUN_IMPACT_ENTRY_FRAMES)
        last_reaction_clip_implemented = true
        _restart_candidate_action()
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
                float(_native_link_blending_from(
                    "facedownidle", "impactfacedown",
                    0
                )) / SOURCE_FRAME_RATE
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


# characters.list animations.victory / animations.defeat per character, in
# archive order (adreno_200/characters.list). The native match configuration
# stores
#   GetAnimation(charIndex, "victory", zmathRandomGet() % GetAnimationNumVersions)
# and
#   GetAnimation(charIndex, "defeat", 0)
# in TFighterConfig+0x5c / +0x60, and CBeatEmUpGame::LoadFighterAnimations loads
# those two names as the "Victory"/"Defeat" free animations. Only the victory
# index is a random draw; the defeat index is the literal 0.
const RESULT_CLIPS_BRUCELEE: Dictionary = {
    "victory": ["m01_victory_01", "m01_victory_02"],
    "defeat": ["m01_defeat_01"],
}
const RESULT_CLIPS_BRICK: Dictionary = {
    "victory": ["m03_victory_02"],
    "defeat": ["m01_defeat_01"],
}
const RESULT_CLIPS_SINFU: Dictionary = {
    "victory": ["m04_e02_victory_01"],
    "defeat": ["m01_defeat_01"],
}
const RESULT_CLIPS_MASTER: Dictionary = {
    "victory": ["m04_e01_victory_01"],
    "defeat": ["m01_defeat_01"],
}
const RESULT_CLIPS_SHENLO: Dictionary = {
    "victory": ["m04_e03_victory_01"],
    "defeat": ["m01_defeat_01"],
}
const RESULT_CLIPS_KEN: Dictionary = {
    "victory": ["m02_e01_victory_01"],
    "defeat": ["m01_defeat_01"],
}
const RESULT_CLIPS_SMALLBOY: Dictionary = {
    "victory": ["m03_victory_03"],
    "defeat": ["m01_defeat_01"],
}
const RESULT_CLIPS_JOHNSON: Dictionary = {
    "victory": ["m03_victory_01"],
    "defeat": ["m01_defeat_01"],
}
const RESULT_CLIPS_CHIEF: Dictionary = {
    "victory": ["m02_victory_01"],
    "defeat": ["m01_defeat_01"],
}
const RESULT_CLIPS_LOMING: Dictionary = {
    "victory": ["m04_victory_01", "m04_victory_02"],
    "defeat": ["m01_defeat_01"],
}


func configure_result_clips(pools: Dictionary) -> void:
    ## characters.list animations.intro/victory/defeat for this character. Set
    ## once before the fighter enters the tree; the result pose uses the pool
    ## rather than the loaded GLB's animation list.
    character_result_clips = pools.duplicate(true)
    result_clip_index_victory = 0
    result_clip_index_defeat = 0


func select_result_clips(victory_roll: int) -> void:
    ## Port of the per-match version choice in
    ## IBeatEmUpGameMode::SetFighterConfigFromCharacterList (0x1ff418):
    ## `version = zmathRandomGet() % GetAnimationNumVersions(...)` for the
    ## victory animation and the literal version 0 for the defeat animation.
    ## The draw happens once per match, not per round and not at pose time.
    var victory: Array[String] = result_clip_pool("victory")
    result_clip_index_victory = 0
    if not victory.is_empty():
        result_clip_index_victory = victory_roll % victory.size()
    result_clip_index_defeat = 0


func result_clip_pool(kind: String) -> Array[String]:
    var names: Array[String] = []
    var raw: Variant = character_result_clips.get(kind)
    if raw is Array:
        for value: Variant in raw:
            names.append(String(value))
    return names


func _selected_result_clip(kind: String) -> String:
    var pool: Array[String] = result_clip_pool(kind)
    if pool.is_empty():
        return ""
    var index: int = (
        result_clip_index_victory if kind == "victory" else result_clip_index_defeat
    )
    return pool[clampi(index, 0, pool.size() - 1)]


func result_clip_names(kind: String) -> Array[String]:
    ## Candidate clips whose names contain "victory" or "defeat". These are
    ## demo result animations (m01_victory_01, m03_victory_01, m01_defeat_01,
    ## ...). They are not fighting-set actions, so they are only discovered
    ## from the loaded GLB's animation list. They are used only to report an
    ## asset gap: a candidate GLB can carry another character's result clip.
    var wanted: String = "victory" if kind == "victory" else "defeat"
    var names: Array[String] = []
    for key: Variant in _candidate_clip_paths:
        var path: String = String(_candidate_clip_paths[key])
        if path.get_file().contains(wanted):
            names.append(String(key))
    names.sort()
    return names


func has_result_clip(kind: String) -> bool:
    ## True when this fighter can present the result kind: either the clip
    ## characters.list selected for it or, for a documented asset gap, any
    ## loaded result clip.
    var pool: Array[String] = result_clip_pool(kind)
    for name: String in pool:
        if _candidate_clip_paths.has(name):
            return true
    return not result_clip_names(kind).is_empty()


func enter_result_pose(kind: String) -> bool:
    ## Port of the winner-only clip switch in CBeatEmUpGame::SetState(12/13).
    ## The native call passes only the category ("Victory"/"Defeat"); the clip
    ## was fixed when the match configuration was built, so nothing here draws
    ## a new index. Returns false when the character provides no result clip.
    result_clip_gap_last = ""
    var wanted: String = _selected_result_clip(kind)
    if _candidate_animation == null:
        result_clip = ""
        result_pose_active = false
        return false
    if wanted.is_empty():
        result_clip_gap_last = "no characters.list %s pool" % kind
    elif _candidate_clip_paths.has(wanted):
        result_clip = wanted
    else:
        # The candidate GLB does not carry this character's characters.list
        # clip. Keep the pose visible with a loaded result clip and report the
        # gap instead of silently presenting another character's animation.
        var fallback: Array[String] = result_clip_names(kind)
        result_clip_gap_last = (
            "characters.list %s clip %s missing from GLB" % [kind, wanted]
        )
        if fallback.is_empty():
            result_clip = ""
            result_pose_active = false
            return false
        result_clip = fallback[0]
    if not _candidate_clip_paths.has(result_clip):
        result_clip = ""
        result_pose_active = false
        return false
    var clip: Animation = _candidate_animation.get_animation(
        _candidate_clip_paths[result_clip]
    )
    if clip != null:
        clip.loop_mode = Animation.LOOP_NONE
    state = "result"
    state_time = 0.0
    attack_kind = ""
    move_axis = Vector2.ZERO
    velocity = Vector3.ZERO
    result_pose_active = true
    _play_candidate_action(result_clip)
    return true


func result_clip_duration() -> float:
    if result_clip.is_empty() or _candidate_animation == null:
        return 0.0
    if not _candidate_clip_paths.has(result_clip):
        return 0.0
    var clip: Animation = _candidate_animation.get_animation(
        _candidate_clip_paths[result_clip]
    )
    if clip == null:
        return 0.0
    return clip.length


func clear_result_pose() -> void:
    result_clip = ""
    result_pose_active = false
    if state == "result":
        state = "idle"
        state_time = 0.0


func reset_fighter(start_position: Vector3) -> void:
    global_position = start_position
    velocity = Vector3.ZERO
    move_axis = Vector2.ZERO
    _locomotion_action = ""
    _locomotion_time = 0.0
    _locomotion_root_ready = false
    health = MAX_HEALTH
    state = "idle"
    state_time = 0.0
    result_clip = ""
    result_pose_active = false
    visible = true
    attack_kind = ""
    _attack_connected = false
    _parry_absorbed = false
    _clear_link_state()
    last_reaction_group = ""
    last_reaction_source_action = ""
    last_reaction_animation = ""
    last_reaction_exit_frame = -1
    last_reaction_entry_frame = 0
    last_reaction_clip_implemented = false
    guard_held = false
    combo_hits = 0
    rage = 0.0
    _attack_hit_landed = false
    _grab_connected = false
    _endattack_victim_started = false
    _multi_impact_applied.clear()
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
    if (state == "result" and not result_clip.is_empty()
            and _candidate_clip_paths.has(result_clip)):
        # SetState(12/13) winner-only victory / matched defeat clip.
        requested = result_clip
    elif state in ["startup", "active", "recovery"]:
        # Any attack kind whose clip the candidate provides plays that clip.
        # The previous explicit list only named the brucelee.set slots; mapped
        # set configs (kungfu/karate) use their own slot names, so the check is
        # the clip map itself.
        if _candidate_clip_paths.has(attack_kind):
            requested = attack_kind
    elif state in ["grabbed1", "grabbed2"] and _candidate_clip_paths.has(state):
        requested = state
    elif state in ["endattackcomp1", "endattackcomp2"] and _candidate_clip_paths.has(state):
        requested = state
    elif state in ["stun", "stun2"] and _candidate_clip_paths.has("stun"):
        requested = "stun"
    elif state == "stunfall" and _candidate_clip_paths.has("stun_fall"):
        requested = "stun_fall"
    elif (state in ["hitstun", "blockstun", "stunimpact", "impactstun"]
            and last_reaction_clip_implemented
            and _candidate_clip_paths.has(last_reaction_animation)):
        requested = last_reaction_animation
        start_frame = last_reaction_entry_frame
        if _candidate_action != requested and _candidate_character != null:
            _candidate_character.position = _candidate_character_rest_position
    elif state == "ko" and _candidate_clip_paths.has("ko"):
        requested = "ko"
    elif state in ["idle", "idle2", "idle3"] and not _native_movement_action().is_empty():
        requested = _locomotion_action if not _locomotion_action.is_empty() else _native_movement_action()
    elif state == "idle2" and _candidate_clip_paths.has(IDLE2_CLIP):
        requested = IDLE2_CLIP
    elif state == "idle3" and _candidate_clip_paths.has(IDLE3_CLIP):
        requested = IDLE3_CLIP
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
    elif state == "faceupko" and _candidate_clip_paths.has(_faceup_idle_clip()):
        requested = _faceup_idle_clip()
    elif state == "faceupidle" and _candidate_clip_paths.has(_faceup_idle_clip()):
        requested = _faceup_idle_clip()
    elif state == "faceupgetup" and _candidate_clip_paths.has(FACEUP_GETUP_CLIP):
        requested = FACEUP_GETUP_CLIP
    elif state == "faceupattack" and _candidate_clip_paths.has(FACEUP_ATTACK_CLIP):
        requested = FACEUP_ATTACK_CLIP
        if _candidate_action != requested and _candidate_character != null:
            _candidate_character.position = _candidate_character_rest_position
    elif state == "attacktofloor" and _candidate_clip_paths.has(ATTACK_TO_FLOOR_CLIP):
        requested = ATTACK_TO_FLOOR_CLIP
        start_frame = _native_entry_frame("attacktofloor", 0)
        if _candidate_action != requested and _candidate_character != null:
            _candidate_character.position = _candidate_character_rest_position
    if requested == FACEUP_IMPACT_TO_FLOOR_CLIP:
        start_frame = int(state_time * SOURCE_FRAME_RATE + 0.0001)
    _play_candidate_action(requested, start_frame)

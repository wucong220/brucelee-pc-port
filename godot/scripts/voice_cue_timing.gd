extends RefCounted
## Voice cue timing recovered from `adreno_200/set/brucelee.set`.
##
## Source of truth: every animation record's `sounds[]` array, entries with
## is_voice=true.  Field layout in the original set: file / frame / volume /
## unique / is_voice.  `frame` is the native 30 fps source frame of the
## action; a cue at f4 must start 4/30 s after the action starts.
##
## The data below is generated verbatim from the set by
## work/gen_voice_cue_timing.py.  No filename, frame or volume is invented.
## `file` is archive-relative (`sounds/voices/...`) so the caller can resolve
## it against the package voice root; `canonical` is the same file relative
## to <package>/audio/bruce_lee for the named Bruce voice.

const SOURCE_SET: String = "adreno_200/set/brucelee.set"
const SOURCE_SET_SHA256: String = "860b6dac1ae5043456fbf72b1cd93a5a1c76f036b3b995df5e57ce68b4d3762c"
const FRAME_RATE: float = 30.0

## port attack action -> original set action (from attack_audio_mapping.json).
const PORT_TO_SET_ACTION: Dictionary = {
    "attacktofloor": "attacktofloor",
    "endattack1": "endattack1",
    "endattack2": "endattack2",
    "facedownattack": "facedownattack",
    "faceupattack": "faceupattack",
    "grab1": "grab1",
    "grab1_miss": "grab1miss",
    "grab2": "grab2",
    "grab2_miss": "grab2miss",
    "high_kick": "highkick1",
    "high_kick2": "highkick2",
    "high_kick3": "highkick3",
    "high_punch": "highpunch1",
    "high_punch2": "highpunch2",
    "high_punch3": "highpunch3",
    "kick": "lowkick1",
    "low_kick": "lowkick1",
    "low_kick2": "lowkick2",
    "low_kick3": "lowkick3",
    "low_punch": "lowpunch1",
    "low_punch2": "lowpunch2",
    "low_punch3": "lowpunch3",
    "parry_attack": "parryattack",
    "parry_high": "parryhigh",
    "parry_low": "parrylow",
    "punch": "lowpunch1",
    "special_kick_high": "specialkickhigh",
    "special_kick_low_hit": "specialkicklowhit",
    "special_kick_low_miss": "specialkicklowmiss",
    "special_punch_high_hit": "specialpunchhighhit",
    "special_punch_high_miss": "specialpunchhighmiss",
    "special_punch_low_hit": "specialpunchlowhit",
    "special_punch_low_miss": "specialpunchlowmiss",
}

## set action -> voice cues [{file, canonical, frame, volume, unique, is_voice}].
## `unique` names the fighting-set character variant (empty = any).
const VOICE_ACTIONS: Dictionary = {
    "attacktofloor": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 17, "volume": 0.500, "unique": "", "is_voice": true},
       ],
    "endattack brick": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav", "canonical": "attack_light/Hit_Light_1_BL.wav", "frame": 8, "volume": 0.640, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 41, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "endattack chief": [
        {"file": "sounds/voices/bruce_lee/special/M01_End_Attack_01.avi _BL_Slow_Scream_A.wav", "canonical": "special/M01_End_Attack_01.avi _BL_Slow_Scream_A.wav", "frame": 15, "volume": 0.500, "unique": "", "is_voice": true},
       ],
    "endattack johnson": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_3_BL.wav", "canonical": "attack_light/Hit_Light_3_BL.wav", "frame": 1, "volume": 0.900, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/special/m01_sp_kick_high.wav", "canonical": "special/m01_sp_kick_high.wav", "frame": 73, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "endattack ken": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_8_BL.wav", "canonical": "attack_light/Hit_Light_8_BL.wav", "frame": 19, "volume": 0.900, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 55, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "endattack loming": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav", "canonical": "attack_light/Hit_Light_1_BL.wav", "frame": 12, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "endattack master": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav", "canonical": "attack_light/Hit_Light_1_BL.wav", "frame": 24, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "endattack shenlo": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 14, "volume": 1.000, "unique": "", "is_voice": true},
       ],
    "endattack sinfu": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav", "canonical": "attack_light/Hit_Light_1_BL.wav", "frame": 24, "volume": 1.000, "unique": "", "is_voice": true},
       ],
    "endattack smallboy": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav", "canonical": "attack_light/Hit_Light_1_BL.wav", "frame": 8, "volume": 0.640, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 41, "volume": 0.900, "unique": "brickdavis", "is_voice": true},
       ],
    "endattack1": [
        {"file": "sounds/voices/bruce_lee/special/m01_sp_kick_high.wav", "canonical": "special/m01_sp_kick_high.wav", "frame": 44, "volume": 0.500, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/special/M01_End_Attack_01.avi _BL_Slow_Scream_A.wav", "canonical": "special/M01_End_Attack_01.avi _BL_Slow_Scream_A.wav", "frame": 206, "volume": 0.500, "unique": "", "is_voice": true},
       ],
    "endattack2": [
        {"file": "sounds/voices/bruce_lee/special/M01_End_Attack_02.avi _BL_Slow_Scream_B.wav", "canonical": "special/M01_End_Attack_02.avi _BL_Slow_Scream_B.wav", "frame": 11, "volume": 0.500, "unique": "", "is_voice": true},
       ],
    "endattackcompkarate 1": [
        {"file": "sounds/voices/brick_davies/light_pain/hurt__light_male_ls_g_hurtgrunt02_brick_davies.wav", "canonical": "", "frame": 20, "volume": 0.850, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_1_BL.wav", "canonical": "pain_light/Pain_Light_1_BL.wav", "frame": 20, "volume": 0.850, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt05_the_cheif.wav", "canonical": "", "frame": 20, "volume": 0.850, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtpunch02_johnson.wav", "canonical": "", "frame": 20, "volume": 0.850, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtgrunt04_ken.wav", "canonical": "", "frame": 20, "volume": 0.850, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/lo_ming/light_pain/hurt_light_male_ls_l_hurtgrunt08_lo_ming.wav", "canonical": "", "frame": 20, "volume": 0.850, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/light_pain/male_ls_j_hurtgrunt04_shen_lo.wav", "canonical": "", "frame": 20, "volume": 0.850, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/light_pain/hurt_light_male_ls_f_sin_fu.wav", "canonical": "", "frame": 20, "volume": 0.850, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtgrunt06_small_boy.wav", "canonical": "", "frame": 20, "volume": 0.850, "unique": "smallboy", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_2.wav", "canonical": "", "frame": 20, "volume": 0.700, "unique": "themaster", "is_voice": true},
       ],
    "grab1": [
        {"file": "sounds/voices/bruce_lee/special/m01_grab_01.wav", "canonical": "special/m01_grab_01.wav", "frame": 43, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "grab1 chief": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_2_BL.wav", "canonical": "attack_light/Hit_Light_2_BL.wav", "frame": 10, "volume": 0.680, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_9_BL.wav", "canonical": "attack_light/Hit_Light_9_BL.wav", "frame": 28, "volume": 0.680, "unique": "", "is_voice": true},
       ],
    "grab1 ken": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_2_BL.wav", "canonical": "attack_light/Hit_Light_2_BL.wav", "frame": 10, "volume": 0.680, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_9_BL.wav", "canonical": "attack_light/Hit_Light_9_BL.wav", "frame": 28, "volume": 0.680, "unique": "", "is_voice": true},
       ],
    "grab1 master": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 6, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "grab2": [
        {"file": "sounds/voices/bruce_lee/special/M01_Grab_02_Back_Breaker.wav", "canonical": "special/M01_Grab_02_Back_Breaker.wav", "frame": 29, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "grab2 brick": [
        {"file": "sounds/voices/bruce_lee/special/M01_victory_01_Big_Scream.wav", "canonical": "special/M01_victory_01_Big_Scream.wav", "frame": 20, "volume": 0.900, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 45, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "grab2 johnson": [
        {"file": "sounds/voices/bruce_lee/special/M01_victory_01_Big_Scream.wav", "canonical": "special/M01_victory_01_Big_Scream.wav", "frame": 20, "volume": 0.900, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 45, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "grab2 master": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 21, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "grab2 sinfu": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_6_BL.wav", "canonical": "attack_light/Hit_Light_6_BL.wav", "frame": 10, "volume": 0.700, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 21, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "grab2 smallboy": [
        {"file": "sounds/voices/bruce_lee/special/M01_victory_01_Big_Scream.wav", "canonical": "special/M01_victory_01_Big_Scream.wav", "frame": 20, "volume": 0.900, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 45, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "grabcompl1 chief": [
        {"file": "sounds/voices/brick_davies/light_pain/hurt__light_male_ls_g_hurtgrunt02_brick_davies.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_1_BL.wav", "canonical": "pain_light/Pain_Light_1_BL.wav", "frame": 32, "volume": 0.850, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt05_the_cheif.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtpunch02_johnson.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtgrunt04_ken.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/lo_ming/light_pain/hurt_light_male_ls_l_hurtgrunt08_lo_ming.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/light_pain/male_ls_j_hurtgrunt04_shen_lo.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/light_pain/hurt_light_male_ls_f_sin_fu.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtgrunt06_small_boy.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "smallboy", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_2.wav", "canonical": "", "frame": 32, "volume": 0.700, "unique": "themaster", "is_voice": true},
       ],
    "grabcompl1 ken": [
        {"file": "sounds/voices/brick_davies/light_pain/hurt__light_male_ls_g_hurtgrunt02_brick_davies.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_1_BL.wav", "canonical": "pain_light/Pain_Light_1_BL.wav", "frame": 32, "volume": 0.850, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt05_the_cheif.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtpunch02_johnson.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtgrunt04_ken.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/lo_ming/light_pain/hurt_light_male_ls_l_hurtgrunt08_lo_ming.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/light_pain/male_ls_j_hurtgrunt04_shen_lo.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/light_pain/hurt_light_male_ls_f_sin_fu.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtgrunt06_small_boy.wav", "canonical": "", "frame": 32, "volume": 0.850, "unique": "smallboy", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_2.wav", "canonical": "", "frame": 32, "volume": 0.700, "unique": "themaster", "is_voice": true},
       ],
    "grabcompl1 loming": [
        {"file": "sounds/voices/lo_ming/heavy_pain/hurt_light_male_ls_l_hurtgrunt07_lo_ming.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/heavy_pain/male_ls_j_painscream04_shen_lo.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/heavy_pain/male_ls_f_painscream01_sin_fu_b.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_3.wav", "canonical": "", "frame": 38, "volume": 0.700, "unique": "themaster", "is_voice": true},
        {"file": "sounds/voices/brick_davies/light_pain/hurt__lightmale_ls_g_hurtpunch10_brick_davies.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_2_BL.wav", "canonical": "pain_light/Pain_Light_2_BL.wav", "frame": 38, "volume": 0.700, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt08_the_cheif.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtpunch02_johnson.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtpunch05_ken.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtpunch05_small_boy.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "smallboy", "is_voice": true},
       ],
    "grabcompl1 master": [
        {"file": "sounds/voices/lo_ming/heavy_pain/hurt_light_male_ls_l_hurtgrunt07_lo_ming.wav", "canonical": "", "frame": 7, "volume": 1.000, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/heavy_pain/male_ls_j_painscream04_shen_lo.wav", "canonical": "", "frame": 7, "volume": 1.000, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/heavy_pain/male_ls_f_painscream01_sin_fu_b.wav", "canonical": "", "frame": 7, "volume": 1.000, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_3.wav", "canonical": "", "frame": 7, "volume": 0.700, "unique": "themaster", "is_voice": true},
        {"file": "sounds/voices/brick_davies/light_pain/hurt__lightmale_ls_g_hurtpunch10_brick_davies.wav", "canonical": "", "frame": 7, "volume": 1.000, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_2_BL.wav", "canonical": "pain_light/Pain_Light_2_BL.wav", "frame": 7, "volume": 0.700, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt08_the_cheif.wav", "canonical": "", "frame": 7, "volume": 1.000, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtpunch02_johnson.wav", "canonical": "", "frame": 7, "volume": 1.000, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtpunch05_ken.wav", "canonical": "", "frame": 7, "volume": 1.000, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtpunch05_small_boy.wav", "canonical": "", "frame": 7, "volume": 1.000, "unique": "smallboy", "is_voice": true},
       ],
    "grabcompl1 shenlo": [
        {"file": "sounds/voices/lo_ming/heavy_pain/hurt_light_male_ls_l_hurtgrunt07_lo_ming.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/heavy_pain/male_ls_j_painscream04_shen_lo.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/heavy_pain/male_ls_f_painscream01_sin_fu_b.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_3.wav", "canonical": "", "frame": 38, "volume": 0.700, "unique": "themaster", "is_voice": true},
        {"file": "sounds/voices/brick_davies/light_pain/hurt__lightmale_ls_g_hurtpunch10_brick_davies.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_2_BL.wav", "canonical": "pain_light/Pain_Light_2_BL.wav", "frame": 38, "volume": 0.700, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt08_the_cheif.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtpunch02_johnson.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtpunch05_ken.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtpunch05_small_boy.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "smallboy", "is_voice": true},
       ],
    "grabcompl1 sinfu": [
        {"file": "sounds/voices/lo_ming/heavy_pain/hurt_light_male_ls_l_hurtgrunt07_lo_ming.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/heavy_pain/male_ls_j_painscream04_shen_lo.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/heavy_pain/male_ls_f_painscream01_sin_fu_b.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_3.wav", "canonical": "", "frame": 38, "volume": 0.700, "unique": "themaster", "is_voice": true},
        {"file": "sounds/voices/brick_davies/light_pain/hurt__lightmale_ls_g_hurtpunch10_brick_davies.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_2_BL.wav", "canonical": "pain_light/Pain_Light_2_BL.wav", "frame": 38, "volume": 0.700, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt08_the_cheif.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtpunch02_johnson.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtpunch05_ken.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtpunch05_small_boy.wav", "canonical": "", "frame": 38, "volume": 1.000, "unique": "smallboy", "is_voice": true},
       ],
    "grabcompl2 chief": [
        {"file": "sounds/voices/brick_davies/light_pain/hurt__light_male_ls_g_hurtgrunt02_brick_davies.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_1_BL.wav", "canonical": "pain_light/Pain_Light_1_BL.wav", "frame": 50, "volume": 0.850, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt05_the_cheif.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtpunch02_johnson.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtgrunt04_ken.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/lo_ming/light_pain/hurt_light_male_ls_l_hurtgrunt08_lo_ming.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/light_pain/male_ls_j_hurtgrunt04_shen_lo.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/light_pain/hurt_light_male_ls_f_sin_fu.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtgrunt06_small_boy.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "smallboy", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_2.wav", "canonical": "", "frame": 50, "volume": 0.700, "unique": "themaster", "is_voice": true},
       ],
    "grabcompl2 ken": [
        {"file": "sounds/voices/brick_davies/light_pain/hurt__light_male_ls_g_hurtgrunt02_brick_davies.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_1_BL.wav", "canonical": "pain_light/Pain_Light_1_BL.wav", "frame": 50, "volume": 0.850, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt05_the_cheif.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtpunch02_johnson.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtgrunt04_ken.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/lo_ming/light_pain/hurt_light_male_ls_l_hurtgrunt08_lo_ming.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/light_pain/male_ls_j_hurtgrunt04_shen_lo.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/light_pain/hurt_light_male_ls_f_sin_fu.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtgrunt06_small_boy.wav", "canonical": "", "frame": 50, "volume": 0.850, "unique": "smallboy", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_2.wav", "canonical": "", "frame": 50, "volume": 0.700, "unique": "themaster", "is_voice": true},
       ],
    "grabcompl2 loming": [
        {"file": "sounds/voices/lo_ming/heavy_pain/hurt_light_male_ls_l_hurtgrunt07_lo_ming.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/light_pain/male_ls_j_hurtpunch08_shen_lo.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/heavy_pain/male_ls_f_painscream01_sin_fu_a.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_7.wav", "canonical": "", "frame": 24, "volume": 0.700, "unique": "themaster", "is_voice": true},
        {"file": "sounds/voices/brick_davies/heavy_pain/hurt_heavy_male_ls_g_death02_brick_davies.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_heavy/PAIN_Loud_3.wav", "canonical": "pain_heavy/PAIN_Loud_3.wav", "frame": 24, "volume": 0.700, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_heavy/hurt_heavy_male_ls_h_death03_the_cheif.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/heavy_pain/hurt_heavy_male_ls_d_painscream07_johnson.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/heavy_pain/hurt_heavy_male_ls_c_painscream02_ken.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_heavy/hurt_hard_male_ls_b_surprised04_small_boy.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "smallboy", "is_voice": true},
       ],
    "grabcompl2 master": [
        {"file": "sounds/voices/brick_davies/light_pain/hurt__lightmale_ls_g_hurtpunch10_brick_davies.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_2_BL.wav", "canonical": "pain_light/Pain_Light_2_BL.wav", "frame": 23, "volume": 1.000, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt05_the_cheif.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtgrunt06_johnson.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtpunch05_ken.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/lo_ming/light_pain/hurt_light_male_ls_l_hurtpunch09_lo_ming.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/light_pain/male_ls_j_hurtgrunt04_shen_lo.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/light_pain/hurt_light_male_ls_f_sin_fu_b.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtpunch05_small_boy.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "smallboy", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_hvy_2.wav", "canonical": "", "frame": 23, "volume": 0.700, "unique": "themaster", "is_voice": true},
       ],
    "grabcompl2 shenlo": [
        {"file": "sounds/voices/lo_ming/heavy_pain/hurt_light_male_ls_l_hurtgrunt07_lo_ming.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/light_pain/male_ls_j_hurtpunch08_shen_lo.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/heavy_pain/male_ls_f_painscream01_sin_fu_a.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_7.wav", "canonical": "", "frame": 24, "volume": 0.700, "unique": "themaster", "is_voice": true},
        {"file": "sounds/voices/brick_davies/heavy_pain/hurt_heavy_male_ls_g_death02_brick_davies.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_heavy/PAIN_Loud_3.wav", "canonical": "pain_heavy/PAIN_Loud_3.wav", "frame": 24, "volume": 0.700, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_heavy/hurt_heavy_male_ls_h_death03_the_cheif.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/heavy_pain/hurt_heavy_male_ls_d_painscream07_johnson.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/heavy_pain/hurt_heavy_male_ls_c_painscream02_ken.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_heavy/hurt_hard_male_ls_b_surprised04_small_boy.wav", "canonical": "", "frame": 24, "volume": 1.000, "unique": "smallboy", "is_voice": true},
       ],
    "grabcompl2 sinfu": [
        {"file": "sounds/voices/brick_davies/light_pain/hurt__lightmale_ls_g_hurtpunch10_brick_davies.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_2_BL.wav", "canonical": "pain_light/Pain_Light_2_BL.wav", "frame": 23, "volume": 1.000, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt05_the_cheif.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtgrunt06_johnson.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtpunch05_ken.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/lo_ming/light_pain/hurt_light_male_ls_l_hurtpunch09_lo_ming.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/light_pain/male_ls_j_hurtgrunt04_shen_lo.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/light_pain/hurt_light_male_ls_f_sin_fu_b.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtpunch05_small_boy.wav", "canonical": "", "frame": 23, "volume": 1.000, "unique": "smallboy", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_hvy_2.wav", "canonical": "", "frame": 23, "volume": 0.700, "unique": "themaster", "is_voice": true},
       ],
    "highkick1": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_6_BL.wav", "canonical": "attack_light/Hit_Light_6_BL.wav", "frame": 2, "volume": 0.500, "unique": "", "is_voice": true},
       ],
    "highkick2": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_3_BL.wav", "canonical": "attack_light/Hit_Light_3_BL.wav", "frame": 3, "volume": 0.460, "unique": "", "is_voice": true},
       ],
    "highkick3": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 5, "volume": 0.750, "unique": "", "is_voice": true},
       ],
    "highpunch1": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav", "canonical": "attack_light/Hit_Light_1_BL.wav", "frame": 0, "volume": 0.600, "unique": "", "is_voice": true},
       ],
    "highpunch2": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_2_BL.wav", "canonical": "attack_light/Hit_Light_2_BL.wav", "frame": 6, "volume": 0.600, "unique": "", "is_voice": true},
       ],
    "highpunch3": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 7, "volume": 0.630, "unique": "", "is_voice": true},
       ],
    "impactbrutalmid": [
        {"file": "sounds/voices/brick_davies/heavy_pain/hurt_heavy_male_ls_g_death02_brick_davies.wav", "canonical": "", "frame": 6, "volume": 0.850, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_heavy/PAIN_Loud_3.wav", "canonical": "pain_heavy/PAIN_Loud_3.wav", "frame": 6, "volume": 0.700, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_heavy/hurt_heavy_male_ls_h_death03_the_cheif.wav", "canonical": "", "frame": 6, "volume": 0.850, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/heavy_pain/hurt_heavy_male_ls_d_painscream07_johnson.wav", "canonical": "", "frame": 6, "volume": 0.850, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/heavy_pain/hurt_heavy_male_ls_c_painscream02_ken.wav", "canonical": "", "frame": 6, "volume": 0.850, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/lo_ming/heavy_pain/hurt_light_male_ls_l_hurtgrunt07_lo_ming.wav", "canonical": "", "frame": 6, "volume": 0.850, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/heavy_pain/male_ls_j_painscream04_shen_lo.wav", "canonical": "", "frame": 6, "volume": 0.850, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/heavy_pain/male_ls_f_painscream01_sin_fu_a.wav", "canonical": "", "frame": 6, "volume": 0.850, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_heavy/hurt_hard_male_ls_b_death01_small_boy.wav", "canonical": "", "frame": 6, "volume": 0.850, "unique": "smallboy", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_hvy_6.wav", "canonical": "", "frame": 6, "volume": 0.700, "unique": "themaster", "is_voice": true},
       ],
    "impactfacedown": [
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_2_BL.wav", "canonical": "pain_light/Pain_Light_2_BL.wav", "frame": 1, "volume": 0.700, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/brick_davies/light_pain/hurt__lightmale_ls_g_hurtpunch10_brick_davies.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt08_the_cheif.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtgrunt06_johnson.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtpunch05_ken.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/lo_ming/light_pain/hurt_light_male_ls_l_hurtgrunt08_lo_ming.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/light_pain/male_ls_j_hurtpunch08_shen_lo.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/light_pain/hurt_light_male_ls_f_sin_fu_b.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtgrunt06_small_boy.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "smallboy", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_1.wav", "canonical": "", "frame": 1, "volume": 0.700, "unique": "themaster", "is_voice": true},
       ],
    "impactfaceup": [
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_2_BL.wav", "canonical": "pain_light/Pain_Light_2_BL.wav", "frame": 1, "volume": 0.700, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/brick_davies/light_pain/hurt__lightmale_ls_g_hurtpunch10_brick_davies.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt08_the_cheif.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtgrunt06_johnson.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtpunch05_ken.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/lo_ming/light_pain/hurt_light_male_ls_l_hurtgrunt08_lo_ming.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/light_pain/male_ls_j_hurtpunch08_shen_lo.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/light_pain/hurt_light_male_ls_f_sin_fu_b.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtgrunt06_small_boy.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "smallboy", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_1.wav", "canonical": "", "frame": 1, "volume": 0.700, "unique": "themaster", "is_voice": true},
       ],
    "impacthardfrontmid": [
        {"file": "sounds/voices/brick_davies/heavy_pain/hurt_heavy_male_ls_g_death02_brick_davies.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_heavy/PAIN_Loud_3.wav", "canonical": "pain_heavy/PAIN_Loud_3.wav", "frame": 1, "volume": 0.690, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_heavy/hurt_heavy_male_ls_h_death03_the_cheif.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/heavy_pain/hurt_heavy_male_ls_d_painscream07_johnson.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/heavy_pain/hurt_heavy_male_ls_c_painscream02_ken.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/lo_ming/heavy_pain/hurt_light_male_ls_l_hurtgrunt07_lo_ming.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/heavy_pain/male_ls_j_painscream04_shen_lo.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/heavy_pain/male_ls_f_painscream01_sin_fu_a.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_heavy/hurt_hard_male_ls_b_death01_small_boy.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "smallboy", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_hvy_6.wav", "canonical": "", "frame": 1, "volume": 0.690, "unique": "themaster", "is_voice": true},
       ],
    "impactlightfrontmid": [
        {"file": "sounds/voices/brick_davies/light_pain/hurt__lightmale_ls_g_hurtpunch10_brick_davies.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_2_BL.wav", "canonical": "pain_light/Pain_Light_2_BL.wav", "frame": 1, "volume": 0.700, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt05_the_cheif.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtpunch02_johnson.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtpunch05_ken.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/lo_ming/light_pain/hurt_light_male_ls_l_hurtpunch09_lo_ming.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/light_pain/male_ls_j_hurtpunch08_shen_lo.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/light_pain/hurt_light_male_ls_f_sin_fu_b.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtpunch05_small_boy.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "smallboy", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_3.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "shenlo", "is_voice": true},
       ],
    "impactlightlefthigh": [
        {"file": "sounds/voices/brick_davies/light_pain/hurt__light_male_ls_g_hurtgrunt02_brick_davies.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_1_BL.wav", "canonical": "pain_light/Pain_Light_1_BL.wav", "frame": 1, "volume": 0.850, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt05_the_cheif.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtpunch02_johnson.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtgrunt04_ken.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/lo_ming/light_pain/hurt_light_male_ls_l_hurtgrunt08_lo_ming.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/light_pain/male_ls_j_hurtgrunt04_shen_lo.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/light_pain/hurt_light_male_ls_f_sin_fu.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtgrunt06_small_boy.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "smallboy", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_2.wav", "canonical": "", "frame": 1, "volume": 0.700, "unique": "themaster", "is_voice": true},
       ],
    "impactlightrighthigh": [
        {"file": "sounds/voices/brick_davies/light_pain/hurt__light_male_ls_g_hurtgrunt02_brick_davies.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_light/Pain_Light_1_BL.wav", "canonical": "pain_light/Pain_Light_1_BL.wav", "frame": 1, "volume": 0.850, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_light/hurt_light_male_ls_h_hurtgrunt05_the_cheif.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/light_pain/hurt_light_male_ls_d_hurtpunch02_johnson.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/light_pain/hurt_light_male_ls_c_hurtgrunt04_ken.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/lo_ming/light_pain/hurt_light_male_ls_l_hurtgrunt08_lo_ming.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/light_pain/male_ls_j_hurtgrunt04_shen_lo.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/light_pain/hurt_light_male_ls_f_sin_fu.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_light/hurt_light_male_ls_b_hurtgrunt06_small_boy.wav", "canonical": "", "frame": 1, "volume": 0.850, "unique": "smallboy", "is_voice": true},
        {"file": "sounds/voices/the_master/pain/master_pain_lt_2.wav", "canonical": "", "frame": 1, "volume": 0.700, "unique": "themaster", "is_voice": true},
       ],
    "lowkick1": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_6_BL.wav", "canonical": "attack_light/Hit_Light_6_BL.wav", "frame": 0, "volume": 0.600, "unique": "", "is_voice": true},
       ],
    "lowkick2": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_6_BL.wav", "canonical": "attack_light/Hit_Light_6_BL.wav", "frame": 6, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "lowkick3": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 7, "volume": 0.500, "unique": "", "is_voice": true},
       ],
    "lowpunch1": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 4, "volume": 0.450, "unique": "", "is_voice": true},
       ],
    "lowpunch2": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_6_BL.wav", "canonical": "attack_light/Hit_Light_6_BL.wav", "frame": 4, "volume": 0.450, "unique": "", "is_voice": true},
       ],
    "lowpunch3": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_3_BL.wav", "canonical": "attack_light/Hit_Light_3_BL.wav", "frame": 7, "volume": 0.450, "unique": "", "is_voice": true},
       ],
    "specialkickhigh": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 9, "volume": 0.500, "unique": "", "is_voice": true},
       ],
    "specialkickhigh brick": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 11, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialkickhigh chief": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav", "canonical": "attack_light/Hit_Light_1_BL.wav", "frame": 7, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialkickhigh johnson": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 7, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialkickhigh ken": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 19, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialkickhigh loming": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_3_BL.wav", "canonical": "attack_light/Hit_Light_3_BL.wav", "frame": 8, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "specialkickhigh master": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 7, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "specialkickhigh shenlo": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_2_BL.wav", "canonical": "attack_light/Hit_Light_2_BL.wav", "frame": 9, "volume": 0.700, "unique": "", "is_voice": true},
        {"file": "sounds/voices/shen_lo/light_pain/male_ls_j_hurtgrunt04_shen_lo.wav", "canonical": "", "frame": 49, "volume": 0.650, "unique": "shenlo", "is_voice": true},
       ],
    "specialkickhigh sinfu": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 8, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "specialkickhigh smallboy": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 7, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialkicklow brick": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 12, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialkicklow chief": [
        {"file": "sounds/voices/chief/attck_light/hit_light_male_ls_h_attackgrunt07_the_cheif.wav", "canonical": "", "frame": 11, "volume": 0.700, "unique": "chief", "is_voice": true},
       ],
    "specialkicklow johnson": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 12, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialkicklow ken": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_3_BL.wav", "canonical": "attack_light/Hit_Light_3_BL.wav", "frame": 13, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialkicklow master": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav", "canonical": "attack_light/Hit_Light_1_BL.wav", "frame": 11, "volume": 0.700, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 118, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "specialkicklow sinfu": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_2_BL.wav", "canonical": "attack_light/Hit_Light_2_BL.wav", "frame": 9, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "specialkicklow smallboy": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 12, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialkicklowhit": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_6_BL.wav", "canonical": "attack_light/Hit_Light_6_BL.wav", "frame": 1, "volume": 0.500, "unique": "", "is_voice": true},
       ],
    "specialkicklowmiss": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_8_BL.wav", "canonical": "attack_light/Hit_Light_8_BL.wav", "frame": 10, "volume": 0.500, "unique": "brucelee", "is_voice": true},
       ],
    "specialpunchhigh brick": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 10, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialpunchhigh chief": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_3_BL.wav", "canonical": "attack_light/Hit_Light_3_BL.wav", "frame": 8, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialpunchhigh johnson": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 10, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "specialpunchhigh ken": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_3_BL.wav", "canonical": "attack_light/Hit_Light_3_BL.wav", "frame": 8, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialpunchhigh loming": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_4_BL.wav", "canonical": "attack_light/Hit_Light_4_BL.wav", "frame": 12, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "specialpunchhigh master": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_3_BL.wav", "canonical": "attack_light/Hit_Light_3_BL.wav", "frame": 5, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "specialpunchhigh shenlo": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav", "canonical": "attack_light/Hit_Light_1_BL.wav", "frame": 12, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "specialpunchhigh smallboy": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 4, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialpunchhighhit": [
        {"file": "sounds/voices/bruce_lee/special/M01_SP_Pnch_High.avi_OPTION_2.wav", "canonical": "special/M01_SP_Pnch_High.avi_OPTION_2.wav", "frame": 2, "volume": 0.500, "unique": "", "is_voice": true},
       ],
    "specialpunchhighhit sinfu": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_8_BL.wav", "canonical": "attack_light/Hit_Light_8_BL.wav", "frame": 6, "volume": 0.700, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_8_BL.wav", "canonical": "attack_light/Hit_Light_8_BL.wav", "frame": 10, "volume": 0.700, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_3_BL.wav", "canonical": "attack_light/Hit_Light_3_BL.wav", "frame": 16, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "specialpunchlow brick": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav", "canonical": "attack_light/Hit_Light_1_BL.wav", "frame": 14, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialpunchlow chief": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav", "canonical": "attack_light/Hit_Light_1_BL.wav", "frame": 8, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "specialpunchlow johnson": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav", "canonical": "attack_light/Hit_Light_1_BL.wav", "frame": 14, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialpunchlow ken": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_2_BL.wav", "canonical": "attack_light/Hit_Light_2_BL.wav", "frame": 8, "volume": 0.900, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 16, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialpunchlow loming": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_6_BL.wav", "canonical": "attack_light/Hit_Light_6_BL.wav", "frame": 9, "volume": 0.700, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav", "canonical": "attack_light/Hit_Light_1_BL.wav", "frame": 17, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "specialpunchlow master": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_3_BL.wav", "canonical": "attack_light/Hit_Light_3_BL.wav", "frame": 2, "volume": 0.700, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 50, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "specialpunchlow shenlo": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_6_BL.wav", "canonical": "attack_light/Hit_Light_6_BL.wav", "frame": 13, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "specialpunchlow sinfu": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_6_BL.wav", "canonical": "attack_light/Hit_Light_6_BL.wav", "frame": 9, "volume": 0.700, "unique": "", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_1_BL.wav", "canonical": "attack_light/Hit_Light_1_BL.wav", "frame": 17, "volume": 0.700, "unique": "", "is_voice": true},
       ],
    "specialpunchlow smallboy": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_5_BL.wav", "canonical": "attack_light/Hit_Light_5_BL.wav", "frame": 14, "volume": 0.900, "unique": "", "is_voice": true},
       ],
    "specialpunchlowhit": [
        {"file": "sounds/voices/bruce_lee/special/m01_sp_pnch_low.wav", "canonical": "special/m01_sp_pnch_low.wav", "frame": 3, "volume": 0.500, "unique": "", "is_voice": true},
       ],
    "specialpunchlowimpact": [
        {"file": "sounds/voices/brick_davies/heavy_pain/hurt_heavy_male_ls_g_painscream04_brick_davies.wav", "canonical": "", "frame": 2, "volume": 0.500, "unique": "brickdavis", "is_voice": true},
        {"file": "sounds/voices/bruce_lee/pain_heavy/PAIN_Loud_3.wav", "canonical": "pain_heavy/PAIN_Loud_3.wav", "frame": 2, "volume": 0.500, "unique": "brucelee", "is_voice": true},
        {"file": "sounds/voices/chief/pain_heavy/hurt_heavy_male_ls_h_death03_the_cheif.wav", "canonical": "", "frame": 2, "volume": 0.500, "unique": "chief", "is_voice": true},
        {"file": "sounds/voices/johnson/heavy_pain/hurt_heavy_male_ls_d_painscream07_johnson.wav", "canonical": "", "frame": 2, "volume": 0.500, "unique": "johnson", "is_voice": true},
        {"file": "sounds/voices/ken_goodall/heavy_pain/hurt_heavy_male_ls_c_painscream02_ken.wav", "canonical": "", "frame": 2, "volume": 0.500, "unique": "kengodall", "is_voice": true},
        {"file": "sounds/voices/lo_ming/heavy_pain/hurt_heavy_male_ls_l_death01_lo_ming.wav", "canonical": "", "frame": 2, "volume": 0.500, "unique": "loming", "is_voice": true},
        {"file": "sounds/voices/shen_lo/heavy_pain/male_ls_j_painscream04_shen_lo.wav", "canonical": "", "frame": 2, "volume": 0.500, "unique": "shenlo", "is_voice": true},
        {"file": "sounds/voices/sin_fu/heavy_pain/male_ls_f_painscream01_sin_fu_a.wav", "canonical": "", "frame": 2, "volume": 0.500, "unique": "sinfu", "is_voice": true},
        {"file": "sounds/voices/smallboy/pain_heavy/hurt_hard_male_ls_b_death01_small_boy.wav", "canonical": "", "frame": 2, "volume": 0.500, "unique": "smallboy", "is_voice": true},
        {"file": "sounds/voices/the_master/pain_heavy/master_hurt_heavy_2.wav", "canonical": "", "frame": 2, "volume": 0.500, "unique": "themaster", "is_voice": true},
       ],
    "specialpunchlowmiss": [
        {"file": "sounds/voices/bruce_lee/attack_light/Hit_Light_2_BL.wav", "canonical": "attack_light/Hit_Light_2_BL.wav", "frame": 7, "volume": 0.350, "unique": "brucelee", "is_voice": true},
       ],
}


static func voice_cues(action: String) -> Array:
    if VOICE_ACTIONS.has(action):
        return VOICE_ACTIONS[action]
    return []


static func attack_voice_cues(port_action: String) -> Array:
    if not PORT_TO_SET_ACTION.has(port_action):
        return []
    return voice_cues(String(PORT_TO_SET_ACTION[port_action]))


## True when a cue applies to `character_id` (empty unique = generic).
static func cue_matches(cue: Dictionary, character_id: String) -> bool:
    var unique: String = String(cue.get("unique", ""))
    return unique.is_empty() or unique == character_id


## Seconds from action start to this cue.  -1 when the set gives no frame.
static func cue_seconds(cue: Dictionary) -> float:
    if not cue.has("frame"):
        return -1.0
    return maxf(float(cue["frame"]), 0.0) / FRAME_RATE

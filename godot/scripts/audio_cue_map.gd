class_name AudioCueMap
extends RefCounted
## Canonical Bruce Lee voice-cue table recovered from the original fighting set.
##
## Source of truth: adreno_200/set/brucelee.set -> each animation record's
## `sounds` array, entries with is_voice=true (field layout: file/frame/volume/
## unique/is_voice).  Values below are the raw original cues; `frame` is the
## native 30 fps source frame of the animation.  This file is a PROPOSAL and is
## not referenced by the repo until the accompanying patch is applied.
##
## `file` is relative to the Bruce voice root (`.../audio/bruce_lee`).
const CUES: Dictionary = {
	"punch": [{"file": "attack_light/Hit_Light_5_BL.wav", "frame": 4, "volume": 0.45}],
	"kick": [{"file": "attack_light/Hit_Light_6_BL.wav", "frame": 0, "volume": 0.60}],
	"high_punch": [{"file": "attack_light/Hit_Light_1_BL.wav", "frame": 0, "volume": 0.60}],
	"high_punch2": [{"file": "attack_light/Hit_Light_2_BL.wav", "frame": 6, "volume": 0.60}],
	"high_punch3": [{"file": "attack_light/Hit_Light_5_BL.wav", "frame": 7, "volume": 0.63}],
	"low_punch": [{"file": "attack_light/Hit_Light_5_BL.wav", "frame": 4, "volume": 0.45}],
	"low_punch2": [{"file": "attack_light/Hit_Light_6_BL.wav", "frame": 4, "volume": 0.45}],
	"low_punch3": [{"file": "attack_light/Hit_Light_3_BL.wav", "frame": 7, "volume": 0.45}],
	"high_kick": [{"file": "attack_light/Hit_Light_6_BL.wav", "frame": 2, "volume": 0.50}],
	"high_kick2": [{"file": "attack_light/Hit_Light_3_BL.wav", "frame": 3, "volume": 0.46}],
	"high_kick3": [{"file": "attack_light/Hit_Light_4_BL.wav", "frame": 5, "volume": 0.75}],
	"low_kick": [{"file": "attack_light/Hit_Light_6_BL.wav", "frame": 0, "volume": 0.60}],
	"low_kick2": [{"file": "attack_light/Hit_Light_6_BL.wav", "frame": 6, "volume": 0.70}],
	"low_kick3": [{"file": "attack_light/Hit_Light_4_BL.wav", "frame": 7, "volume": 0.50}],
	"special_kick_high": [{"file": "attack_light/Hit_Light_4_BL.wav", "frame": 9, "volume": 0.50}],
	"special_kick_low_miss": [{"file": "attack_light/Hit_Light_8_BL.wav", "frame": 10, "volume": 0.50}],
	"special_kick_low_hit": [{"file": "attack_light/Hit_Light_6_BL.wav", "frame": 1, "volume": 0.50}],
	"special_punch_low_miss": [{"file": "attack_light/Hit_Light_2_BL.wav", "frame": 7, "volume": 0.35}],
	"special_punch_low_hit": [{"file": "special/m01_sp_pnch_low.wav", "frame": 3, "volume": 0.50}],
	"special_punch_high_hit": [{"file": "special/M01_SP_Pnch_High.avi_OPTION_2.wav", "frame": 2, "volume": 0.50}],
	"attacktofloor": [{"file": "attack_light/Hit_Light_5_BL.wav", "frame": 17, "volume": 0.50}],
	"grab1": [{"file": "special/m01_grab_01.wav", "frame": 43, "volume": 0.90}],
	"grab2": [{"file": "special/M01_Grab_02_Back_Breaker.wav", "frame": 29, "volume": 0.70}],
	"endattack1": [{"file": "special/m01_sp_kick_high.wav", "frame": 44, "volume": 0.50}, {"file": "special/M01_End_Attack_01.avi _BL_Slow_Scream_A.wav", "frame": 206, "volume": 0.50}],
	"endattack2": [{"file": "special/M01_End_Attack_02.avi _BL_Slow_Scream_B.wav", "frame": 11, "volume": 0.50}],
}

## Opponent-class-specific action kinds (the port names them with a `_brick`
## suffix) reuse the generic cue of their base action.  Exact per-opponent
## variants exist in the set and are listed in attack_audio_mapping.json; they
## can be wired later once the runtime knows the opponent class for the cue.
const VOICE_ALIAS: Dictionary = {
	"special_kick_high_brick": "special_kick_high",
	"special_kick_low_brick": "special_kick_low_hit",
	"special_punch_high_brick": "special_punch_high_hit",
	"special_punch_low_brick": "special_punch_low_hit",
	"parry_high_brick": "parry_high",
	"parry_low_brick": "parry_low",
	"parry_attack_brick": "parry_attack",
	"grab1_brick": "grab1",
	"grab2_brick": "grab2",
	"attack_to_floor_brick": "attacktofloor",
	"endattack_brick": "endattack1",
	"grab1_miss_brick": "grab1_miss",
	"grab2_miss_brick": "grab2_miss",
}

## Actions that carry more than one native voice cue: pick the one the port
## should play at startup (the earliest/loudest signature line).  endattack1
## has m01_sp_kick_high @f44 and the End_Attack slow scream @f206; the scream is
## the signature sound, so index 1 is primary.
const PRIMARY_INDEX: Dictionary = {
	"endattack1": 1,
}

## Bruce pain voice cues on receiving a hit (set reaction actions with is_voice).
## light: pain_light_2@f1 (frontmid/facedown/faceup), light_high: pain_light_1@f1
## (left/right high), heavy: PAIN_Loud_3@f1/f6, heavy_special: PAIN_Loud_3@f2.
const PAIN: Dictionary = {
	"light": "pain_light/Pain_Light_2_BL.wav",
	"light_high": "pain_light/Pain_Light_1_BL.wav",
	"heavy": "pain_heavy/PAIN_Loud_3.wav",
	"heavy_special": "pain_heavy/PAIN_Loud_3.wav",
}

## Commentator / result voice cues (archive adreno_200/sounds/commentator_voice).
## Time_Out/Great/Perfect are NOT present in the current package: they must be
## copied from the archive into <package>/audio/commentator before they can load.
const COMMENTATOR: Dictionary = {
	"ready": "Ready_Alt_1.wav",
	"fight": "Fight.wav",
	"win": "You_Win.wav",
	"lose": "You_Lose.wav",
	"draw": "Draw.wav",
	"time_out": "Time_Out.wav",
	"great": "Great.wav",
	"perfect": "Perfect.wav",
}

static func cues_for(kind: String) -> Array:
	if CUES.has(kind):
		return CUES[kind]
	var base: String = String(VOICE_ALIAS.get(kind, ""))
	if base != "" and CUES.has(base):
		return CUES[base]
	return []

static func primary_cue(kind: String) -> Dictionary:
	var c: Array = cues_for(kind)
	if c.is_empty():
		return {}
	var idx: int = int(PRIMARY_INDEX.get(kind, 0))
	if idx < 0 or idx >= c.size():
		idx = 0
	return c[idx]

## action -> relative voice file of the primary cue.
static func voice_files() -> Dictionary:
	var out: Dictionary = {}
	for kind: String in CUES:
		var cue: Dictionary = primary_cue(kind)
		if not cue.is_empty():
			out[kind] = String(cue["file"])
	for kind: String in VOICE_ALIAS:
		var base: String = String(VOICE_ALIAS[kind])
		var cue2: Dictionary = primary_cue(base)
		if not cue2.is_empty():
			out[kind] = String(cue2["file"])
	return out

static func has_voice(kind: String) -> bool:
	return not cues_for(kind).is_empty()

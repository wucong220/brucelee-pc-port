extends RefCounted
## Original SFX / music library recovered from data.zpak.
##
## Generated only from:
##   - adreno_200/set/{brucelee,thai,karate,kungfu}.set `sounds`
##   - attack-audio-20261103/attack_audio_mapping.json
##     (port_action -> original_set_action -> original_sfx_cues)
##   - story_mode.json sceneries[].music / subevents[].music
## No filename, frame or volume below is synthesised. `file` is
## relative to <package>/audio/sfx and <package>/audio/music.

## Every recovered `sounds[].frame` is a native 30 fps source frame, so a cue at
## f7 must start 7/30 s after its action/hit, never at the event start.
const FRAME_RATE: float = 30.0

const SFX_FILES: Array[String] = [
    "Air_Kick_Heavy_1.wav",
    "Air_Kick_Light_1.wav",
    "Air_Punch_Heavy_1.wav",
    "Air_Punch_Light_1.wav",
    "Block_Arms_2.wav",
    "Block_Legs_1.wav",
    "Block_Legs_2.wav",
    "Boot_L.wav",
    "Boot_R.wav",
    "Boot_Slide_Long.wav",
    "Boot_Slide_Short.wav",
    "Clothing_2.wav",
    "Clothing_3.wav",
    "Clothing_4.wav",
    "Fall_1_Normal.wav",
    "Fall_2_Normal.wav",
    "Fall_3_Normal.wav",
    "Fall_4_Normal.wav",
    "Kick_Body_Heavy_1.wav",
    "Kick_Body_Heavy_2.wav",
    "Kick_Body_Light_1.wav",
    "Kick_Body_Light_2.wav",
    "Kick_Head_Heavy_1.wav",
    "Kick_Head_Heavy_2.wav",
    "Kick_Head_Light_1.wav",
    "Kick_Head_Light_2.wav",
    "Punch_Body_Heavy_1.wav",
    "Punch_Body_Heavy_2.wav",
    "Punch_Body_Light_1.wav",
    "Punch_Body_Light_2.wav",
    "Punch_Head_Heavy_1.wav",
    "Punch_Head_Heavy_2.wav",
    "Punch_Head_Light_2.wav",
    "Shoe_Foot_L.wav",
    "Shoe_Foot_Long.wav",
    "Shoe_Foot_R.wav",
    "Shoe_Foot_Short.wav",
    "Shoe_Foot_Short_B.wav",
]

const MUSIC_FILES: Array[String] = [
    "day/Harbour_Day_BL.wav",
    "day/Rooftops_Day_BL.wav",
    "day/Street_Day_BL.wav",
    "day/Temple_Day_BL.wav",
    "day/Tournament_Day_BL.wav",
    "misc/Main_Theme_BL.wav",
    "misc/Map_BL.wav",
    "night/Harbour_Night_BL.wav",
    "night/Rooftops_Night_BL.wav",
    "night/Street_Night_BL.wav",
    "night/Temple_Night_BL.wav",
    "night/Tournament_Night_BL.wav",
    "story/Story_1_Temple_BL.wav",
    "story/Story_2_Rooftops_BL.wav",
    "story/Story_4_Tournament_BL.wav",
    "story/Story_5_Temple_BL.wav",
    "story/Story_Chapter_1_Temple_and_Street.wav",
    "story/Story_Chapter_2_Rooftops_and_Street.wav",
    "story/Story_Chapter_3_Harbour_Street_Tweak.wav",
    "story/Story_Chapter_4_Tournament_Hall_and_Harbour.wav",
    "story/Story_Chapter_5_Temple.wav",
]

const MENU_MUSIC: String = "misc/Main_Theme_BL.wav"
const MAP_MUSIC: String = "misc/Map_BL.wav"

## BRUCELEE_SCENE -> original scenery track (story_mode.json sceneries).
const SCENE_MUSIC: Dictionary = {
    "squarea": "night/Street_Night_BL.wav",
    "squareb": "day/Street_Day_BL.wav",
    "": "day/Temple_Day_BL.wav",
    "templeyardb": "night/Temple_Night_BL.wav",
    "harboura": "night/Harbour_Night_BL.wav",
    "harbourb": "day/Harbour_Day_BL.wav",
    "halla": "day/Tournament_Day_BL.wav",
    "tournamenthallb": "night/Tournament_Night_BL.wav",
    "rooftopsa": "day/Rooftops_Day_BL.wav",
    "rooftopsb": "night/Rooftops_Night_BL.wav",
}

## Original subevent music path -> package-relative library path.
const STORY_MUSIC: Dictionary = {
    "sounds/music/story/story_1_temple_bl.wav": "story/Story_1_Temple_BL.wav",
    "sounds/music/story/story_2_rooftops_bl.wav": "story/Story_2_Rooftops_BL.wav",
    "sounds/music/story/story_4_tournament_bl.wav": "story/Story_4_Tournament_BL.wav",
    "sounds/music/story/story_5_temple_bl.wav": "story/Story_5_Temple_BL.wav",
    "sounds/music/story/story_chapter_1_temple_and_street.wav": "story/Story_Chapter_1_Temple_and_Street.wav",
    "sounds/music/story/story_chapter_2_rooftops_and_street.wav": "story/Story_Chapter_2_Rooftops_and_Street.wav",
    "sounds/music/story/story_chapter_3_harbour_street_tweak.wav": "story/Story_Chapter_3_Harbour_Street_Tweak.wav",
    "sounds/music/story/story_chapter_4_tournament_hall_and_harbour.wav": "story/Story_Chapter_4_Tournament_Hall_and_Harbour.wav",
    "sounds/music/story/story_chapter_5_temple.wav": "story/Story_Chapter_5_Temple.wav",
}

## Full non-voice cue table from brucelee.set (all 179 sounding actions).
const SFX_ACTIONS: Dictionary = {
    "attacktofloor": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.800},
        {"file": "Shoe_Foot_L.wav", "frame": 36, "volume": 0.800},
        {"file": "Shoe_Foot_R.wav", "frame": 45, "volume": 0.800},
        {"file": "Shoe_Foot_L.wav", "frame": 65, "volume": 0.800},
        {"file": "Shoe_Foot_R.wav", "frame": 74, "volume": 0.600},
       ],
    "endattack brick": [
        {"file": "Clothing_3.wav", "frame": 16, "volume": 0.650},
        {"file": "Air_Kick_Light_1.wav", "frame": 40, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 63, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 68, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 82, "volume": 0.500},
       ],
    "endattack chief": [
        {"file": "Shoe_Foot_Short_B.wav", "frame": 8, "volume": 0.500},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 57, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 59, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 62, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 76, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 88, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 103, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 112, "volume": 0.500},
       ],
    "endattack johnson": [
        {"file": "Air_Punch_Heavy_1.wav", "frame": 1, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 12, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 19, "volume": 0.500},
        {"file": "Clothing_4.wav", "frame": 19, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 39, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 64, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 77, "volume": 0.500},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 81, "volume": 0.750},
        {"file": "Shoe_Foot_L.wav", "frame": 85, "volume": 0.500},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 88, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 97, "volume": 0.500},
       ],
    "endattack ken": [
        {"file": "Shoe_Foot_L.wav", "frame": 8, "volume": 0.500},
        {"file": "Clothing_4.wav", "frame": 18, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 35, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 44, "volume": 0.500},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 54, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 68, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 101, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 114, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 127, "volume": 0.500},
       ],
    "endattack loming": [
        {"file": "Shoe_Foot_L.wav", "frame": 2, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 8, "volume": 0.350},
        {"file": "Clothing_3.wav", "frame": 14, "volume": 1.000},
       ],
    "endattack master": [
        {"file": "Shoe_Foot_R.wav", "frame": 10, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 18, "volume": 0.600},
        {"file": "Clothing_3.wav", "frame": 27, "volume": 0.600},
        {"file": "Air_Kick_Light_1.wav", "frame": 30, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 34, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 38, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 43, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 49, "volume": 0.500},
       ],
    "endattack shenlo": [
        {"file": "Shoe_Foot_L.wav", "frame": 2, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 8, "volume": 0.350},
        {"file": "Clothing_3.wav", "frame": 14, "volume": 1.000},
       ],
    "endattack sinfu": [
        {"file": "Shoe_Foot_R.wav", "frame": 10, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 18, "volume": 0.600},
        {"file": "Clothing_3.wav", "frame": 27, "volume": 0.600},
        {"file": "Air_Kick_Light_1.wav", "frame": 30, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 34, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 38, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 43, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 49, "volume": 0.500},
       ],
    "endattack smallboy": [
        {"file": "Clothing_3.wav", "frame": 16, "volume": 0.650},
        {"file": "Air_Kick_Light_1.wav", "frame": 40, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 63, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 68, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 82, "volume": 0.500},
       ],
    "endattack1": [
        {"file": "Shoe_Foot_L.wav", "frame": 52, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 53, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 104, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 122, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 180, "volume": 0.500},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 240, "volume": 0.490},
        {"file": "Shoe_Foot_L.wav", "frame": 351, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 363, "volume": 0.500},
       ],
    "endattack2": [
        {"file": "Air_Punch_Light_1.wav", "frame": 10, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 43, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 61, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 73, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 83, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 96, "volume": 0.500},
       ],
    "endattackcomp1": [
        {"file": "Kick_Head_Heavy_1.wav", "frame": 64, "volume": 0.500},
        {"file": "Fall_2_Normal.wav", "frame": 191, "volume": 0.600},
        {"file": "Punch_Head_Heavy_1.wav", "frame": 248, "volume": 0.500},
        {"file": "Fall_3_Normal.wav", "frame": 333, "volume": 0.500},
       ],
    "endattackcomp2": [
        {"file": "Punch_Head_Light_2.wav", "frame": 9, "volume": 0.800},
        {"file": "Punch_Body_Heavy_2.wav", "frame": 63, "volume": 0.500},
        {"file": "Punch_Body_Heavy_2.wav", "frame": 75, "volume": 0.500},
        {"file": "Punch_Body_Heavy_2.wav", "frame": 85, "volume": 0.500},
        {"file": "Punch_Body_Heavy_1.wav", "frame": 97, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 191, "volume": 0.900},
        {"file": "Fall_3_Normal.wav", "frame": 230, "volume": 0.500},
       ],
    "endattackcompkarate 1": [
        {"file": "Kick_Body_Heavy_2.wav", "frame": 20, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 32, "volume": 0.800},
        {"file": "Punch_Head_Heavy_1.wav", "frame": 58, "volume": 0.650},
        {"file": "Shoe_Foot_R.wav", "frame": 91, "volume": 0.600},
        {"file": "Fall_2_Normal.wav", "frame": 105, "volume": 0.700},
       ],
    "endattackcompkarate 2": [
        {"file": "Punch_Head_Heavy_2.wav", "frame": 59, "volume": 0.700},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 96, "volume": 0.500},
        {"file": "Fall_3_Normal.wav", "frame": 142, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 148, "volume": 1.000},
       ],
    "endattackcompthai 1": [
        {"file": "Shoe_Foot_R.wav", "frame": 19, "volume": 0.500},
        {"file": "Punch_Head_Heavy_2.wav", "frame": 42, "volume": 0.450},
        {"file": "Shoe_Foot_R.wav", "frame": 58, "volume": 0.500},
        {"file": "Fall_3_Normal.wav", "frame": 73, "volume": 0.500},
       ],
    "endattackcompthai 2": [
        {"file": "Punch_Head_Heavy_1.wav", "frame": 3, "volume": 0.500},
        {"file": "Kick_Body_Heavy_2.wav", "frame": 19, "volume": 0.850},
        {"file": "Shoe_Foot_L.wav", "frame": 35, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 41, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 48, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 55, "volume": 0.350},
        {"file": "Shoe_Foot_L.wav", "frame": 66, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 84, "volume": 0.500},
        {"file": "Kick_Body_Light_2.wav", "frame": 85, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 89, "volume": 0.500},
        {"file": "Punch_Head_Heavy_1.wav", "frame": 91, "volume": 0.600},
        {"file": "Fall_4_Normal.wav", "frame": 118, "volume": 0.650},
       ],
    "faceupgetup": [
        {"file": "Shoe_Foot_Short_B.wav", "frame": 4, "volume": 0.550},
        {"file": "Clothing_3.wav", "frame": 6, "volume": 0.700},
       ],
    "grab1": [
        {"file": "Shoe_Foot_R.wav", "frame": 22, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 32, "volume": 0.600},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 43, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 53, "volume": 0.600},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 68, "volume": 0.700},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 120, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 132, "volume": 0.600},
       ],
    "grab1 brick": [
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Air_Kick_Light_1.wav", "frame": 17, "volume": 0.450},
        {"file": "Shoe_Foot_R.wav", "frame": 27, "volume": 0.500},
        {"file": "Shoe_Foot_Short.wav", "frame": 28, "volume": 0.500},
        {"file": "Air_Kick_Light_1.wav", "frame": 36, "volume": 0.600},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 46, "volume": 0.450},
        {"file": "Shoe_Foot_L.wav", "frame": 49, "volume": 0.500},
        {"file": "Air_Punch_Light_1.wav", "frame": 53, "volume": 0.500},
       ],
    "grab1 chief": [
        {"file": "Clothing_4.wav", "frame": 9, "volume": 0.700},
        {"file": "Kick_Body_Light_1.wav", "frame": 10, "volume": 0.700},
        {"file": "Shoe_Foot_R.wav", "frame": 21, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 25, "volume": 0.500},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 30, "volume": 0.700},
        {"file": "Shoe_Foot_Long.wav", "frame": 41, "volume": 0.500},
       ],
    "grab1 johnson": [
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Air_Kick_Light_1.wav", "frame": 17, "volume": 0.450},
        {"file": "Shoe_Foot_R.wav", "frame": 27, "volume": 0.500},
        {"file": "Shoe_Foot_Short.wav", "frame": 28, "volume": 0.500},
        {"file": "Air_Kick_Light_1.wav", "frame": 36, "volume": 0.600},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 46, "volume": 0.450},
        {"file": "Shoe_Foot_L.wav", "frame": 49, "volume": 0.500},
        {"file": "Air_Punch_Light_1.wav", "frame": 53, "volume": 0.500},
       ],
    "grab1 ken": [
        {"file": "Clothing_4.wav", "frame": 9, "volume": 0.700},
        {"file": "Kick_Body_Light_1.wav", "frame": 10, "volume": 0.700},
        {"file": "Shoe_Foot_R.wav", "frame": 21, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 25, "volume": 0.500},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 30, "volume": 0.700},
        {"file": "Shoe_Foot_Long.wav", "frame": 41, "volume": 0.500},
       ],
    "grab1 loming": [
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.600},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 34, "volume": 0.600},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 38, "volume": 0.750},
        {"file": "Shoe_Foot_L.wav", "frame": 61, "volume": 0.550},
        {"file": "Shoe_Foot_R.wav", "frame": 75, "volume": 0.550},
       ],
    "grab1 master": [
        {"file": "Air_Kick_Heavy_1.wav", "frame": 2, "volume": 0.800},
        {"file": "Clothing_3.wav", "frame": 5, "volume": 0.450},
        {"file": "Shoe_Foot_R.wav", "frame": 6, "volume": 0.350},
       ],
    "grab1 shenlo": [
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.600},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 34, "volume": 0.600},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 38, "volume": 0.850},
        {"file": "Shoe_Foot_L.wav", "frame": 61, "volume": 0.550},
        {"file": "Shoe_Foot_R.wav", "frame": 75, "volume": 0.550},
       ],
    "grab1 sinfu": [
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.600},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 34, "volume": 0.600},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 38, "volume": 0.850},
        {"file": "Shoe_Foot_L.wav", "frame": 61, "volume": 0.550},
        {"file": "Shoe_Foot_R.wav", "frame": 75, "volume": 0.550},
       ],
    "grab1 smallboy": [
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Air_Kick_Light_1.wav", "frame": 17, "volume": 0.450},
        {"file": "Shoe_Foot_R.wav", "frame": 27, "volume": 0.500},
        {"file": "Shoe_Foot_Short.wav", "frame": 28, "volume": 0.500},
        {"file": "Air_Kick_Light_1.wav", "frame": 36, "volume": 0.600},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 46, "volume": 0.450},
        {"file": "Shoe_Foot_L.wav", "frame": 49, "volume": 0.500},
        {"file": "Air_Punch_Light_1.wav", "frame": 53, "volume": 0.500},
       ],
    "grab1miss": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 7, "volume": 0.200},
       ],
    "grab1miss brick": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 7, "volume": 0.200},
       ],
    "grab1miss chief": [
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.750},
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
       ],
    "grab1miss johnson": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 7, "volume": 0.200},
       ],
    "grab1miss ken": [
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.750},
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
       ],
    "grab1miss loming": [
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.750},
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
       ],
    "grab1miss master": [
        {"file": "Clothing_3.wav", "frame": 5, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 6, "volume": 0.350},
       ],
    "grab1miss shenlo": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 7, "volume": 0.200},
       ],
    "grab1miss sinfu": [
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.750},
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
       ],
    "grab1miss smallboy": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 7, "volume": 0.200},
       ],
    "grab2": [
        {"file": "Shoe_Foot_L.wav", "frame": 10, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 11, "volume": 0.500},
       ],
    "grab2 brick": [
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 24, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 39, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 45, "volume": 0.600},
        {"file": "Clothing_4.wav", "frame": 45, "volume": 0.750},
        {"file": "Shoe_Foot_R.wav", "frame": 54, "volume": 0.500},
       ],
    "grab2 chief": [
        {"file": "Shoe_Foot_L.wav", "frame": 9, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 37, "volume": 0.500},
        {"file": "Air_Punch_Light_1.wav", "frame": 64, "volume": 0.500},
       ],
    "grab2 johnson": [
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 24, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 39, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 45, "volume": 0.600},
        {"file": "Clothing_4.wav", "frame": 45, "volume": 0.750},
        {"file": "Shoe_Foot_R.wav", "frame": 54, "volume": 0.500},
       ],
    "grab2 ken": [
        {"file": "Shoe_Foot_L.wav", "frame": 9, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 37, "volume": 0.500},
        {"file": "Air_Punch_Light_1.wav", "frame": 64, "volume": 0.500},
       ],
    "grab2 loming": [
        {"file": "Air_Kick_Light_1.wav", "frame": 7, "volume": 0.700},
        {"file": "Clothing_4.wav", "frame": 21, "volume": 0.600},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 23, "volume": 0.700},
        {"file": "Shoe_Foot_R.wav", "frame": 41, "volume": 0.500},
       ],
    "grab2 master": [
        {"file": "Shoe_Foot_Short_B.wav", "frame": 10, "volume": 0.500},
        {"file": "Kick_Body_Light_1.wav", "frame": 11, "volume": 0.600},
        {"file": "Air_Kick_Light_1.wav", "frame": 21, "volume": 0.500},
        {"file": "Kick_Body_Heavy_1.wav", "frame": 21, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 22, "volume": 0.600},
       ],
    "grab2 shenlo": [
        {"file": "Air_Kick_Light_1.wav", "frame": 7, "volume": 0.700},
        {"file": "Clothing_4.wav", "frame": 21, "volume": 0.600},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 23, "volume": 0.700},
        {"file": "Shoe_Foot_R.wav", "frame": 41, "volume": 0.500},
       ],
    "grab2 sinfu": [
        {"file": "Shoe_Foot_Short_B.wav", "frame": 10, "volume": 0.500},
        {"file": "Kick_Body_Light_1.wav", "frame": 11, "volume": 0.600},
        {"file": "Air_Kick_Light_1.wav", "frame": 21, "volume": 0.500},
        {"file": "Kick_Body_Heavy_1.wav", "frame": 21, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 22, "volume": 0.600},
       ],
    "grab2 smallboy": [
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 24, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 39, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 45, "volume": 0.600},
        {"file": "Clothing_4.wav", "frame": 45, "volume": 0.750},
        {"file": "Shoe_Foot_R.wav", "frame": 54, "volume": 0.500},
       ],
    "grab2miss": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 7, "volume": 0.200},
       ],
    "grab2miss brick": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 7, "volume": 0.200},
       ],
    "grab2miss chief": [
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.750},
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
       ],
    "grab2miss johnson": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 7, "volume": 0.200},
       ],
    "grab2miss ken": [
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.750},
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
       ],
    "grabcompl1": [
        {"file": "Kick_Body_Heavy_1.wav", "frame": 45, "volume": 0.900},
        {"file": "Punch_Body_Heavy_1.wav", "frame": 71, "volume": 0.950},
        {"file": "Punch_Head_Heavy_2.wav", "frame": 121, "volume": 0.900},
        {"file": "Fall_3_Normal.wav", "frame": 138, "volume": 0.700},
       ],
    "grabcompl1 brick": [
        {"file": "Kick_Body_Heavy_1.wav", "frame": 18, "volume": 0.500},
        {"file": "Kick_Body_Heavy_1.wav", "frame": 38, "volume": 0.650},
        {"file": "Punch_Head_Heavy_2.wav", "frame": 54, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 66, "volume": 0.850},
        {"file": "Fall_3_Normal.wav", "frame": 72, "volume": 0.500},
       ],
    "grabcompl1 chief": [
        {"file": "Fall_3_Normal.wav", "frame": 21, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 26, "volume": 0.740},
        {"file": "Punch_Body_Heavy_2.wav", "frame": 32, "volume": 0.600},
       ],
    "grabcompl1 johnson": [
        {"file": "Kick_Body_Heavy_1.wav", "frame": 18, "volume": 0.500},
        {"file": "Kick_Body_Heavy_1.wav", "frame": 38, "volume": 0.650},
        {"file": "Punch_Head_Heavy_2.wav", "frame": 54, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 66, "volume": 0.850},
        {"file": "Fall_3_Normal.wav", "frame": 72, "volume": 0.500},
       ],
    "grabcompl1 ken": [
        {"file": "Fall_3_Normal.wav", "frame": 21, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 26, "volume": 0.740},
        {"file": "Punch_Body_Heavy_2.wav", "frame": 32, "volume": 0.600},
       ],
    "grabcompl1 loming": [
        {"file": "Fall_4_Normal.wav", "frame": 28, "volume": 0.450},
        {"file": "Kick_Body_Light_2.wav", "frame": 38, "volume": 0.450},
        {"file": "Kick_Body_Light_2.wav", "frame": 41, "volume": 0.750},
       ],
    "grabcompl1 master": [
        {"file": "Punch_Body_Heavy_1.wav", "frame": 5, "volume": 0.900},
        {"file": "Fall_3_Normal.wav", "frame": 18, "volume": 0.700},
       ],
    "grabcompl1 shenlo": [
        {"file": "Kick_Body_Light_2.wav", "frame": 38, "volume": 0.450},
        {"file": "Kick_Body_Light_2.wav", "frame": 41, "volume": 0.750},
       ],
    "grabcompl1 sinfu": [
        {"file": "Kick_Body_Light_2.wav", "frame": 38, "volume": 0.450},
        {"file": "Kick_Body_Light_2.wav", "frame": 41, "volume": 0.750},
       ],
    "grabcompl1 smallboy": [
        {"file": "Kick_Body_Heavy_1.wav", "frame": 18, "volume": 0.500},
        {"file": "Kick_Body_Heavy_1.wav", "frame": 38, "volume": 0.650},
        {"file": "Punch_Head_Heavy_2.wav", "frame": 54, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 66, "volume": 0.850},
        {"file": "Fall_3_Normal.wav", "frame": 72, "volume": 0.500},
       ],
    "grabcompl2": [
        {"file": "Clothing_3.wav", "frame": 73, "volume": 0.850},
        {"file": "Fall_4_Normal.wav", "frame": 122, "volume": 0.650},
        {"file": "Fall_3_Normal.wav", "frame": 137, "volume": 0.350},
        {"file": "Fall_1_Normal.wav", "frame": 169, "volume": 0.600},
       ],
    "grabcompl2 brick": [
        {"file": "Shoe_Foot_L.wav", "frame": 28, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 37, "volume": 0.500},
        {"file": "Kick_Body_Heavy_2.wav", "frame": 47, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 49, "volume": 0.450},
        {"file": "Fall_4_Normal.wav", "frame": 70, "volume": 0.650},
       ],
    "grabcompl2 chief": [
        {"file": "Fall_3_Normal.wav", "frame": 50, "volume": 0.700},
        {"file": "Shoe_Foot_R.wav", "frame": 65, "volume": 0.700},
        {"file": "Punch_Body_Heavy_2.wav", "frame": 65, "volume": 0.700},
       ],
    "grabcompl2 johnson": [
        {"file": "Shoe_Foot_L.wav", "frame": 28, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 37, "volume": 0.500},
        {"file": "Kick_Body_Heavy_2.wav", "frame": 47, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 49, "volume": 0.450},
        {"file": "Fall_4_Normal.wav", "frame": 70, "volume": 0.650},
       ],
    "grabcompl2 ken": [
        {"file": "Fall_3_Normal.wav", "frame": 50, "volume": 0.700},
        {"file": "Shoe_Foot_R.wav", "frame": 65, "volume": 0.700},
        {"file": "Punch_Body_Heavy_2.wav", "frame": 65, "volume": 0.700},
       ],
    "grabcompl2 loming": [
        {"file": "Kick_Body_Light_1.wav", "frame": 7, "volume": 0.700},
        {"file": "Kick_Head_Heavy_1.wav", "frame": 23, "volume": 0.600},
        {"file": "Fall_4_Normal.wav", "frame": 34, "volume": 0.850},
       ],
    "grabcompl2 master": [
        {"file": "Fall_3_Normal.wav", "frame": 30, "volume": 0.700},
       ],
    "grabcompl2 shenlo": [
        {"file": "Kick_Body_Light_1.wav", "frame": 7, "volume": 0.700},
        {"file": "Kick_Head_Heavy_1.wav", "frame": 23, "volume": 0.600},
        {"file": "Fall_4_Normal.wav", "frame": 34, "volume": 0.850},
       ],
    "grabcompl2 sinfu": [
        {"file": "Fall_3_Normal.wav", "frame": 30, "volume": 0.700},
       ],
    "grabcompl2 smallboy": [
        {"file": "Shoe_Foot_L.wav", "frame": 28, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 37, "volume": 0.500},
        {"file": "Kick_Body_Heavy_2.wav", "frame": 47, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 49, "volume": 0.450},
        {"file": "Fall_4_Normal.wav", "frame": 70, "volume": 0.650},
       ],
    "highblock": [
        {"file": "Block_Arms_2.wav", "frame": 1, "volume": 0.750},
       ],
    "highblockbrutal": [
        {"file": "Block_Legs_1.wav", "frame": 1, "volume": 0.500},
       ],
    "highblockhard": [
        {"file": "Block_Arms_2.wav", "frame": 1, "volume": 0.450},
       ],
    "highkick1": [
        {"file": "Air_Kick_Light_1.wav", "frame": 2, "volume": 1.000},
        {"file": "Clothing_4.wav", "frame": 6, "volume": 0.800},
        {"file": "Shoe_Foot_L.wav", "frame": 24, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 46, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 57, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 65, "volume": 0.600},
       ],
    "highkick2": [
        {"file": "Air_Kick_Light_1.wav", "frame": 2, "volume": 1.000},
        {"file": "Clothing_3.wav", "frame": 5, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 22, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 35, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 43, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 56, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 72, "volume": 0.610},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 72, "volume": 0.600},
       ],
    "highkick3": [
        {"file": "Air_Kick_Heavy_1.wav", "frame": 2, "volume": 1.000},
        {"file": "Clothing_4.wav", "frame": 9, "volume": 0.800},
        {"file": "Shoe_Foot_L.wav", "frame": 17, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 23, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 38, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 41, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 49, "volume": 0.590},
       ],
    "highpunch1": [
        {"file": "Air_Kick_Light_1.wav", "frame": 3, "volume": 1.000},
       ],
    "highpunch2": [
        {"file": "Air_Punch_Heavy_1.wav", "frame": 2, "volume": 1.000},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 31, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 48, "volume": 0.600},
       ],
    "highpunch3": [
        {"file": "Air_Kick_Heavy_1.wav", "frame": 1, "volume": 1.000},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 29, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 30, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 61, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 63, "volume": 0.550},
        {"file": "Shoe_Foot_L.wav", "frame": 71, "volume": 0.650},
       ],
    "idle2": [
        {"file": "Shoe_Foot_L.wav", "frame": 8, "volume": 0.550},
        {"file": "Shoe_Foot_R.wav", "frame": 20, "volume": 0.550},
        {"file": "Shoe_Foot_L.wav", "frame": 30, "volume": 0.550},
        {"file": "Shoe_Foot_R.wav", "frame": 40, "volume": 0.550},
       ],
    "idle3": [
        {"file": "Shoe_Foot_L.wav", "frame": 3, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 14, "volume": 0.310},
        {"file": "Shoe_Foot_R.wav", "frame": 28, "volume": 0.260},
        {"file": "Shoe_Foot_L.wav", "frame": 41, "volume": 0.240},
        {"file": "Shoe_Foot_R.wav", "frame": 52, "volume": 0.260},
        {"file": "Shoe_Foot_L.wav", "frame": 63, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 77, "volume": 0.270},
        {"file": "Shoe_Foot_L.wav", "frame": 87, "volume": 0.290},
        {"file": "Shoe_Foot_L.wav", "frame": 100, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 110, "volume": 0.290},
        {"file": "Shoe_Foot_R.wav", "frame": 123, "volume": 0.210},
        {"file": "Shoe_Foot_L.wav", "frame": 136, "volume": 0.220},
       ],
    "impactbrutalleft": [
        {"file": "Kick_Head_Heavy_2.wav", "frame": 0, "volume": 0.700},
        {"file": "Fall_3_Normal.wav", "frame": 21, "volume": 0.750},
       ],
    "impactbrutalmid": [
        {"file": "Punch_Body_Heavy_2.wav", "frame": 6, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 17, "volume": 0.500},
        {"file": "Fall_2_Normal.wav", "frame": 20, "volume": 0.500},
       ],
    "impactbrutalright": [
        {"file": "Kick_Head_Heavy_1.wav", "frame": 0, "volume": 0.500},
        {"file": "Fall_4_Normal.wav", "frame": 22, "volume": 0.500},
       ],
    "impactfacedown": [
        {"file": "Kick_Head_Light_1.wav", "frame": 0, "volume": 1.000},
        {"file": "Fall_1_Normal.wav", "frame": 7, "volume": 0.270},
       ],
    "impactfaceup": [
        {"file": "Kick_Head_Light_1.wav", "frame": 1, "volume": 0.700},
        {"file": "Fall_1_Normal.wav", "frame": 7, "volume": 0.570},
       ],
    "impacthardabove": [
        {"file": "Kick_Head_Light_2.wav", "frame": 1, "volume": 0.500},
        {"file": "Fall_3_Normal.wav", "frame": 4, "volume": 0.500},
       ],
    "impacthardair": [
        {"file": "Punch_Body_Light_2.wav", "frame": 1, "volume": 0.500},
        {"file": "Fall_1_Normal.wav", "frame": 9, "volume": 0.500},
        {"file": "Fall_2_Normal.wav", "frame": 18, "volume": 0.350},
       ],
    "impacthardfronthigh": [
        {"file": "Kick_Head_Heavy_2.wav", "frame": 0, "volume": 0.900},
        {"file": "Fall_4_Normal.wav", "frame": 14, "volume": 0.700},
       ],
    "impacthardfrontlow": [
        {"file": "Kick_Body_Light_2.wav", "frame": 0, "volume": 0.500},
        {"file": "Fall_3_Normal.wav", "frame": 10, "volume": 0.500},
        {"file": "Fall_1_Normal.wav", "frame": 17, "volume": 0.350},
       ],
    "impacthardfrontmid": [
        {"file": "Punch_Body_Heavy_1.wav", "frame": 0, "volume": 0.500},
        {"file": "Boot_Slide_Short.wav", "frame": 2, "volume": 0.500},
       ],
    "impacthardlefthigh": [
        {"file": "Kick_Head_Heavy_1.wav", "frame": 0, "volume": 0.700},
        {"file": "Fall_3_Normal.wav", "frame": 10, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 24, "volume": 0.500},
       ],
    "impacthardleftlow": [
        {"file": "Kick_Body_Light_1.wav", "frame": 0, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 0, "volume": 0.500},
        {"file": "Fall_2_Normal.wav", "frame": 10, "volume": 0.500},
       ],
    "impacthardrighthigh": [
        {"file": "Kick_Head_Heavy_2.wav", "frame": 0, "volume": 0.700},
        {"file": "Fall_3_Normal.wav", "frame": 10, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 24, "volume": 0.500},
       ],
    "impacthardrightlow": [
        {"file": "Kick_Body_Light_1.wav", "frame": 0, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 0, "volume": 0.500},
        {"file": "Fall_2_Normal.wav", "frame": 10, "volume": 0.500},
       ],
    "impactlightair": [
        {"file": "Punch_Body_Light_1.wav", "frame": 0, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 9, "volume": 0.500},
       ],
    "impactlightfronthigh": [
        {"file": "Kick_Head_Light_1.wav", "frame": 0, "volume": 0.890},
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 16, "volume": 0.600},
       ],
    "impactlightfrontlow": [
        {"file": "Kick_Body_Light_2.wav", "frame": 0, "volume": 0.700},
        {"file": "Boot_Slide_Short.wav", "frame": 1, "volume": 0.700},
       ],
    "impactlightfrontmid": [
        {"file": "Punch_Body_Light_2.wav", "frame": 0, "volume": 1.000},
       ],
    "impactlightlefthigh": [
        {"file": "Kick_Head_Light_2.wav", "frame": 0, "volume": 0.700},
       ],
    "impactlightleftlow": [
        {"file": "Punch_Body_Light_1.wav", "frame": 1, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 9, "volume": 0.500},
       ],
    "impactlightrighthigh": [
        {"file": "Kick_Head_Light_1.wav", "frame": 0, "volume": 0.700},
       ],
    "impactlightrightlow": [
        {"file": "Punch_Body_Light_2.wav", "frame": 0, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 9, "volume": 0.500},
       ],
    "impactstunhigh": [
        {"file": "Kick_Head_Light_1.wav", "frame": 0, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 16, "volume": 0.500},
       ],
    "impactstunlow": [
        {"file": "Kick_Body_Light_2.wav", "frame": 0, "volume": 0.500},
        {"file": "Boot_Slide_Short.wav", "frame": 1, "volume": 0.500},
       ],
    "impacttofloor": [
        {"file": "Kick_Head_Light_2.wav", "frame": 13, "volume": 0.800},
        {"file": "Fall_1_Normal.wav", "frame": 27, "volume": 0.500},
        {"file": "Fall_1_Normal.wav", "frame": 48, "volume": 0.500},
       ],
    "lowblock": [
        {"file": "Block_Legs_1.wav", "frame": 1, "volume": 0.650},
       ],
    "lowkick1": [
        {"file": "Shoe_Foot_R.wav", "frame": 5, "volume": 0.600},
        {"file": "Clothing_4.wav", "frame": 5, "volume": 0.800},
        {"file": "Air_Kick_Light_1.wav", "frame": 6, "volume": 0.630},
        {"file": "Shoe_Foot_L.wav", "frame": 26, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 38, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 46, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 47, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 64, "volume": 0.650},
       ],
    "lowkick2": [
        {"file": "Shoe_Foot_L.wav", "frame": 3, "volume": 0.600},
        {"file": "Air_Kick_Light_1.wav", "frame": 6, "volume": 1.000},
        {"file": "Shoe_Foot_L.wav", "frame": 16, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 26, "volume": 0.650},
       ],
    "lowkick3": [
        {"file": "Air_Kick_Light_1.wav", "frame": 7, "volume": 0.700},
        {"file": "Shoe_Foot_R.wav", "frame": 7, "volume": 0.550},
        {"file": "Shoe_Foot_L.wav", "frame": 23, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 25, "volume": 0.650},
        {"file": "Shoe_Foot_L.wav", "frame": 38, "volume": 0.580},
        {"file": "Shoe_Foot_L.wav", "frame": 41, "volume": 0.600},
       ],
    "lowpunch1": [
        {"file": "Air_Punch_Light_1.wav", "frame": 4, "volume": 0.630},
        {"file": "Shoe_Foot_L.wav", "frame": 8, "volume": 0.600},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 8, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 13, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 16, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 34, "volume": 0.420},
        {"file": "Shoe_Foot_R.wav", "frame": 62, "volume": 0.600},
       ],
    "lowpunch2": [
        {"file": "Shoe_Foot_Short_B.wav", "frame": 2, "volume": 0.600},
        {"file": "Air_Punch_Light_1.wav", "frame": 4, "volume": 1.000},
        {"file": "Shoe_Foot_L.wav", "frame": 7, "volume": 0.480},
        {"file": "Shoe_Foot_R.wav", "frame": 15, "volume": 0.510},
        {"file": "Shoe_Foot_L.wav", "frame": 23, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 56, "volume": 0.600},
       ],
    "lowpunch3": [
        {"file": "Shoe_Foot_L.wav", "frame": 3, "volume": 0.500},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 7, "volume": 1.000},
        {"file": "Shoe_Foot_R.wav", "frame": 8, "volume": 0.440},
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.510},
       ],
    "midblock": [
        {"file": "Block_Legs_2.wav", "frame": 1, "volume": 0.350},
       ],
    "moveback": [
        {"file": "Shoe_Foot_Short_B.wav", "frame": 2, "volume": 0.550},
        {"file": "Boot_Slide_Short.wav", "frame": 8, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 12, "volume": 0.580},
       ],
    "movefwd": [
        {"file": "Shoe_Foot_R.wav", "frame": 6, "volume": 0.480},
        {"file": "Shoe_Foot_L.wav", "frame": 12, "volume": 0.500},
       ],
    "moveleft": [
        {"file": "Shoe_Foot_L.wav", "frame": 14, "volume": 0.320},
        {"file": "Shoe_Foot_R.wav", "frame": 24, "volume": 0.350},
        {"file": "Shoe_Foot_L.wav", "frame": 37, "volume": 0.290},
        {"file": "Shoe_Foot_R.wav", "frame": 49, "volume": 0.310},
       ],
    "moveright": [
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.200},
        {"file": "Shoe_Foot_R.wav", "frame": 24, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 37, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 49, "volume": 0.500},
       ],
    "skipback": [
        {"file": "Shoe_Foot_L.wav", "frame": 13, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 20, "volume": 0.520},
        {"file": "Shoe_Foot_L.wav", "frame": 30, "volume": 0.550},
        {"file": "Shoe_Foot_L.wav", "frame": 45, "volume": 0.550},
        {"file": "Shoe_Foot_R.wav", "frame": 51, "volume": 0.550},
       ],
    "skipfwd": [
        {"file": "Shoe_Foot_L.wav", "frame": 3, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 5, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 13, "volume": 0.590},
        {"file": "Shoe_Foot_R.wav", "frame": 22, "volume": 0.600},
       ],
    "specialkickhigh": [
        {"file": "Clothing_4.wav", "frame": 8, "volume": 0.600},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 9, "volume": 1.000},
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 27, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 38, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 47, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 57, "volume": 0.500},
       ],
    "specialkickhigh brick": [
        {"file": "Clothing_4.wav", "frame": 10, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 10, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 23, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 28, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 40, "volume": 0.350},
       ],
    "specialkickhigh chief": [
        {"file": "Boot_Slide_Short.wav", "frame": 3, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 7, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 26, "volume": 0.500},
       ],
    "specialkickhigh johnson": [
        {"file": "Air_Kick_Heavy_1.wav", "frame": 7, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 22, "volume": 0.500},
       ],
    "specialkickhigh ken": [
        {"file": "Shoe_Foot_L.wav", "frame": 1, "volume": 0.500},
        {"file": "Boot_Slide_Short.wav", "frame": 4, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 10, "volume": 0.500},
        {"file": "Clothing_3.wav", "frame": 17, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 19, "volume": 0.750},
        {"file": "Shoe_Foot_L.wav", "frame": 23, "volume": 0.650},
        {"file": "Shoe_Foot_R.wav", "frame": 29, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 45, "volume": 0.500},
       ],
    "specialkickhigh loming": [
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 8, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 9, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 21, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 58, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 70, "volume": 0.350},
       ],
    "specialkickhigh master": [
        {"file": "Shoe_Foot_L.wav", "frame": 3, "volume": 0.500},
        {"file": "Clothing_3.wav", "frame": 8, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 9, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 16, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 17, "volume": 0.350},
       ],
    "specialkickhigh shenlo": [
        {"file": "Clothing_4.wav", "frame": 5, "volume": 0.600},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 6, "volume": 0.350},
        {"file": "Fall_1_Normal.wav", "frame": 25, "volume": 0.200},
        {"file": "Shoe_Foot_R.wav", "frame": 56, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 102, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 119, "volume": 0.350},
        {"file": "Shoe_Foot_L.wav", "frame": 127, "volume": 0.350},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 129, "volume": 0.450},
       ],
    "specialkickhigh sinfu": [
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 8, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 9, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 21, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 58, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 70, "volume": 0.350},
       ],
    "specialkickhigh smallboy": [
        {"file": "Clothing_3.wav", "frame": 3, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 7, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 15, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 26, "volume": 0.500},
       ],
    "specialkicklow brick": [
        {"file": "Clothing_4.wav", "frame": 12, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 13, "volume": 0.500},
        {"file": "Boot_Slide_Short.wav", "frame": 21, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 36, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 52, "volume": 0.500},
       ],
    "specialkicklow chief": [
        {"file": "Boot_Slide_Short.wav", "frame": 1, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 4, "volume": 0.500},
        {"file": "Boot_Slide_Short.wav", "frame": 8, "volume": 0.500},
        {"file": "Clothing_4.wav", "frame": 11, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 16, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 35, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 38, "volume": 0.500},
       ],
    "specialkicklow johnson": [
        {"file": "Clothing_4.wav", "frame": 12, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 13, "volume": 0.500},
        {"file": "Boot_Slide_Short.wav", "frame": 21, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 36, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 52, "volume": 0.500},
       ],
    "specialkicklow ken": [
        {"file": "Boot_Slide_Short.wav", "frame": 12, "volume": 0.600},
        {"file": "Clothing_4.wav", "frame": 13, "volume": 0.750},
        {"file": "Shoe_Foot_R.wav", "frame": 40, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 56, "volume": 0.600},
       ],
    "specialkicklow loming": [
        {"file": "Shoe_Foot_Long.wav", "frame": 9, "volume": 0.500},
        {"file": "Clothing_4.wav", "frame": 10, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 15, "volume": 0.500},
        {"file": "Air_Kick_Light_1.wav", "frame": 21, "volume": 0.200},
        {"file": "Clothing_4.wav", "frame": 23, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 29, "volume": 0.450},
       ],
    "specialkicklow master": [
        {"file": "Shoe_Foot_L.wav", "frame": 4, "volume": 0.500},
        {"file": "Shoe_Foot_Long.wav", "frame": 15, "volume": 0.450},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 28, "volume": 0.350},
       ],
    "specialkicklow shenlo": [
        {"file": "Air_Kick_Light_1.wav", "frame": 8, "volume": 0.200},
        {"file": "Clothing_4.wav", "frame": 8, "volume": 0.350},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 17, "volume": 0.600},
        {"file": "Clothing_3.wav", "frame": 46, "volume": 1.000},
        {"file": "Shoe_Foot_L.wav", "frame": 50, "volume": 0.350},
        {"file": "Clothing_3.wav", "frame": 60, "volume": 0.500},
        {"file": "Clothing_3.wav", "frame": 84, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 91, "volume": 0.350},
        {"file": "Shoe_Foot_L.wav", "frame": 100, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 115, "volume": 0.200},
        {"file": "Shoe_Foot_L.wav", "frame": 132, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 141, "volume": 0.500},
       ],
    "specialkicklow sinfu": [
        {"file": "Shoe_Foot_Long.wav", "frame": 9, "volume": 0.500},
        {"file": "Clothing_4.wav", "frame": 10, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 15, "volume": 0.500},
        {"file": "Air_Kick_Light_1.wav", "frame": 21, "volume": 0.200},
        {"file": "Clothing_4.wav", "frame": 23, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 29, "volume": 0.450},
       ],
    "specialkicklow smallboy": [
        {"file": "Clothing_4.wav", "frame": 12, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 13, "volume": 0.500},
        {"file": "Boot_Slide_Short.wav", "frame": 21, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 36, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 52, "volume": 0.500},
       ],
    "specialkicklowhit": [
        {"file": "Shoe_Foot_Long.wav", "frame": 0, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 20, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 32, "volume": 0.500},
       ],
    "specialkicklowimpact": [
        {"file": "Shoe_Foot_Short_B.wav", "frame": 0, "volume": 0.500},
        {"file": "Kick_Body_Light_2.wav", "frame": 1, "volume": 1.000},
        {"file": "Shoe_Foot_L.wav", "frame": 12, "volume": 0.500},
        {"file": "Fall_3_Normal.wav", "frame": 16, "volume": 0.650},
        {"file": "Fall_3_Normal.wav", "frame": 26, "volume": 0.350},
       ],
    "specialkicklowmiss": [
        {"file": "Air_Kick_Heavy_1.wav", "frame": 12, "volume": 1.000},
        {"file": "Boot_Slide_Long.wav", "frame": 13, "volume": 0.510},
       ],
    "specialpunchhigh brick": [
        {"file": "Shoe_Foot_L.wav", "frame": 5, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 9, "volume": 0.750},
        {"file": "Shoe_Foot_R.wav", "frame": 16, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 33, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 45, "volume": 0.500},
       ],
    "specialpunchhigh chief": [
        {"file": "Air_Punch_Heavy_1.wav", "frame": 8, "volume": 0.750},
        {"file": "Shoe_Foot_L.wav", "frame": 10, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 14, "volume": 0.600},
       ],
    "specialpunchhigh johnson": [
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.750},
        {"file": "Shoe_Foot_R.wav", "frame": 4, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 24, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 45, "volume": 0.500},
       ],
    "specialpunchhigh ken": [
        {"file": "Boot_Slide_Short.wav", "frame": 7, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 10, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 30, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 46, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 57, "volume": 0.500},
       ],
    "specialpunchhigh loming": [
        {"file": "Air_Punch_Light_1.wav", "frame": 6, "volume": 0.450},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 12, "volume": 0.450},
        {"file": "Shoe_Foot_R.wav", "frame": 41, "volume": 0.350},
        {"file": "Shoe_Foot_L.wav", "frame": 48, "volume": 0.500},
       ],
    "specialpunchhigh master": [
        {"file": "Shoe_Foot_L.wav", "frame": 5, "volume": 0.350},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 6, "volume": 0.600},
       ],
    "specialpunchhigh shenlo": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
        {"file": "Shoe_Foot_R.wav", "frame": 9, "volume": 0.350},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 12, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 31, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 42, "volume": 0.350},
        {"file": "Shoe_Foot_L.wav", "frame": 56, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 68, "volume": 0.350},
        {"file": "Shoe_Foot_L.wav", "frame": 76, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 89, "volume": 0.500},
       ],
    "specialpunchhigh smallboy": [
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.750},
        {"file": "Shoe_Foot_R.wav", "frame": 4, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 24, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 45, "volume": 0.500},
       ],
    "specialpunchhighhit": [
        {"file": "Air_Punch_Light_1.wav", "frame": 4, "volume": 0.500},
        {"file": "Air_Punch_Light_1.wav", "frame": 17, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 41, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 77, "volume": 0.500},
       ],
    "specialpunchhighhit sinfu": [
        {"file": "Shoe_Foot_L.wav", "frame": 5, "volume": 0.500},
        {"file": "Air_Punch_Light_1.wav", "frame": 5, "volume": 0.450},
        {"file": "Clothing_3.wav", "frame": 8, "volume": 0.600},
        {"file": "Air_Kick_Light_1.wav", "frame": 10, "volume": 0.500},
        {"file": "Air_Punch_Light_1.wav", "frame": 16, "volume": 0.500},
        {"file": "Clothing_3.wav", "frame": 31, "volume": 0.450},
       ],
    "specialpunchhighimpact": [
        {"file": "Kick_Head_Light_1.wav", "frame": 5, "volume": 1.000},
        {"file": "Kick_Head_Light_2.wav", "frame": 19, "volume": 1.000},
        {"file": "Punch_Head_Heavy_2.wav", "frame": 44, "volume": 1.000},
        {"file": "Fall_4_Normal.wav", "frame": 55, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 68, "volume": 0.850},
       ],
    "specialpunchhighimpact sinfu": [
        {"file": "Kick_Head_Light_2.wav", "frame": 6, "volume": 1.000},
        {"file": "Punch_Body_Light_1.wav", "frame": 11, "volume": 1.000},
        {"file": "Kick_Head_Light_2.wav", "frame": 18, "volume": 1.000},
        {"file": "Shoe_Foot_L.wav", "frame": 27, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 31, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 42, "volume": 0.600},
       ],
    "specialpunchlow brick": [
        {"file": "Shoe_Foot_L.wav", "frame": 12, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 13, "volume": 0.750},
       ],
    "specialpunchlow chief": [
        {"file": "Boot_Slide_Short.wav", "frame": 4, "volume": 0.600},
        {"file": "Air_Kick_Light_1.wav", "frame": 7, "volume": 0.600},
        {"file": "Clothing_4.wav", "frame": 8, "volume": 0.750},
        {"file": "Shoe_Foot_L.wav", "frame": 10, "volume": 0.500},
       ],
    "specialpunchlow johnson": [
        {"file": "Shoe_Foot_L.wav", "frame": 12, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 13, "volume": 0.750},
       ],
    "specialpunchlow ken": [
        {"file": "Boot_Slide_Short.wav", "frame": 7, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 7, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 8, "volume": 0.500},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 16, "volume": 0.600},
        {"file": "Boot_Slide_Short.wav", "frame": 17, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 19, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 46, "volume": 0.500},
       ],
    "specialpunchlow loming": [
        {"file": "Air_Punch_Light_1.wav", "frame": 9, "volume": 0.200},
        {"file": "Shoe_Foot_R.wav", "frame": 11, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 48, "volume": 0.500},
       ],
    "specialpunchlow master": [
        {"file": "Air_Kick_Light_1.wav", "frame": 2, "volume": 0.600},
        {"file": "Clothing_3.wav", "frame": 9, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 20, "volume": 0.350},
        {"file": "Shoe_Foot_L.wav", "frame": 21, "volume": 0.350},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 22, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 49, "volume": 0.600},
       ],
    "specialpunchlow shenlo": [
        {"file": "Shoe_Foot_Short_B.wav", "frame": 1, "volume": 0.200},
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.200},
        {"file": "Clothing_3.wav", "frame": 13, "volume": 0.500},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 14, "volume": 0.600},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 24, "volume": 0.500},
       ],
    "specialpunchlow sinfu": [
        {"file": "Air_Punch_Light_1.wav", "frame": 9, "volume": 0.200},
        {"file": "Shoe_Foot_R.wav", "frame": 11, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 48, "volume": 0.500},
       ],
    "specialpunchlow smallboy": [
        {"file": "Shoe_Foot_L.wav", "frame": 12, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 13, "volume": 0.750},
       ],
    "specialpunchlowhit": [
        {"file": "Air_Punch_Heavy_1.wav", "frame": 1, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 3, "volume": 0.500},
        {"file": "Punch_Body_Heavy_2.wav", "frame": 4, "volume": 0.800},
        {"file": "Shoe_Foot_L.wav", "frame": 149, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 169, "volume": 0.500},
       ],
    "specialpunchlowimpact": [
        {"file": "Fall_3_Normal.wav", "frame": 105, "volume": 0.800},
        {"file": "Fall_1_Normal.wav", "frame": 129, "volume": 0.350},
       ],
    "stepback": [
        {"file": "Shoe_Foot_R.wav", "frame": 8, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 12, "volume": 0.500},
       ],
    "stepfwd": [
        {"file": "Shoe_Foot_Short_B.wav", "frame": 7, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 13, "volume": 0.500},
       ],
    "stepleft": [
        {"file": "Shoe_Foot_R.wav", "frame": 9, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 23, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 34, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 45, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 51, "volume": 0.420},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 56, "volume": 0.500},
       ],
    "stepright": [
        {"file": "Shoe_Foot_R.wav", "frame": 15, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 17, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 33, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 42, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 48, "volume": 0.440},
        {"file": "Shoe_Foot_R.wav", "frame": 53, "volume": 0.460},
        {"file": "Shoe_Foot_R.wav", "frame": 61, "volume": 0.430},
        {"file": "Shoe_Foot_L.wav", "frame": 73, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 82, "volume": 0.510},
        {"file": "Shoe_Foot_L.wav", "frame": 93, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 96, "volume": 0.460},
        {"file": "Shoe_Foot_L.wav", "frame": 112, "volume": 0.500},
       ],
    "stunbrutalimpact": [
        {"file": "Kick_Head_Heavy_2.wav", "frame": 0, "volume": 0.500},
        {"file": "Fall_3_Normal.wav", "frame": 21, "volume": 0.450},
       ],
    "stunfall": [
        {"file": "Fall_4_Normal.wav", "frame": 23, "volume": 0.500},
       ],
    "stunhardimpact": [
        {"file": "Kick_Head_Heavy_2.wav", "frame": 0, "volume": 0.700},
        {"file": "Fall_4_Normal.wav", "frame": 14, "volume": 0.500},
       ],
    "stunlighthighimpact": [
        {"file": "Kick_Head_Light_1.wav", "frame": 0, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 16, "volume": 0.500},
       ],
    "stunlightlowimpact": [
        {"file": "Kick_Body_Light_2.wav", "frame": 0, "volume": 0.500},
        {"file": "Boot_Slide_Short.wav", "frame": 1, "volume": 0.500},
       ],
    "stunmediumimpact": [
        {"file": "Kick_Body_Light_2.wav", "frame": 0, "volume": 0.500},
       ],
}

## Port attack kind -> exact brucelee.set attack cues.
const ATTACK_SFX: Dictionary = {
    "attack_to_floor_brick": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.800},
        {"file": "Shoe_Foot_L.wav", "frame": 36, "volume": 0.800},
        {"file": "Shoe_Foot_R.wav", "frame": 45, "volume": 0.800},
        {"file": "Shoe_Foot_L.wav", "frame": 65, "volume": 0.800},
        {"file": "Shoe_Foot_R.wav", "frame": 74, "volume": 0.600},
       ],
    "attacktofloor": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.800},
        {"file": "Shoe_Foot_L.wav", "frame": 36, "volume": 0.800},
        {"file": "Shoe_Foot_R.wav", "frame": 45, "volume": 0.800},
        {"file": "Shoe_Foot_L.wav", "frame": 65, "volume": 0.800},
        {"file": "Shoe_Foot_R.wav", "frame": 74, "volume": 0.600},
       ],
    "endattack1": [
        {"file": "Shoe_Foot_L.wav", "frame": 52, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 53, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 104, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 122, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 180, "volume": 0.500},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 240, "volume": 0.490},
        {"file": "Shoe_Foot_L.wav", "frame": 351, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 363, "volume": 0.500},
       ],
    "endattack2": [
        {"file": "Air_Punch_Light_1.wav", "frame": 10, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 43, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 61, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 73, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 83, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 96, "volume": 0.500},
       ],
    "endattack_brick": [
        {"file": "Clothing_3.wav", "frame": 16, "volume": 0.650},
        {"file": "Air_Kick_Light_1.wav", "frame": 40, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 63, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 68, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 82, "volume": 0.500},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 1, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 12, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 19, "volume": 0.500},
        {"file": "Clothing_4.wav", "frame": 19, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 39, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 64, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 77, "volume": 0.500},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 81, "volume": 0.750},
        {"file": "Shoe_Foot_L.wav", "frame": 85, "volume": 0.500},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 88, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 97, "volume": 0.500},
        {"file": "Clothing_3.wav", "frame": 16, "volume": 0.650},
        {"file": "Air_Kick_Light_1.wav", "frame": 40, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 63, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 68, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 82, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 10, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 18, "volume": 0.600},
        {"file": "Clothing_3.wav", "frame": 27, "volume": 0.600},
        {"file": "Air_Kick_Light_1.wav", "frame": 30, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 34, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 38, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 43, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 49, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 2, "volume": 0.350},
        {"file": "Shoe_Foot_R.wav", "frame": 8, "volume": 0.350},
        {"file": "Clothing_3.wav", "frame": 14, "volume": 1.000},
        {"file": "Shoe_Foot_R.wav", "frame": 10, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 18, "volume": 0.600},
        {"file": "Clothing_3.wav", "frame": 27, "volume": 0.600},
        {"file": "Air_Kick_Light_1.wav", "frame": 30, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 34, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 38, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 43, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 49, "volume": 0.500},
       ],
    "grab1": [
        {"file": "Shoe_Foot_R.wav", "frame": 22, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 32, "volume": 0.600},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 43, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 53, "volume": 0.600},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 68, "volume": 0.700},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 120, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 132, "volume": 0.600},
       ],
    "grab1_brick": [
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Air_Kick_Light_1.wav", "frame": 17, "volume": 0.450},
        {"file": "Shoe_Foot_R.wav", "frame": 27, "volume": 0.500},
        {"file": "Shoe_Foot_Short.wav", "frame": 28, "volume": 0.500},
        {"file": "Air_Kick_Light_1.wav", "frame": 36, "volume": 0.600},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 46, "volume": 0.450},
        {"file": "Shoe_Foot_L.wav", "frame": 49, "volume": 0.500},
        {"file": "Air_Punch_Light_1.wav", "frame": 53, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Air_Kick_Light_1.wav", "frame": 17, "volume": 0.450},
        {"file": "Shoe_Foot_R.wav", "frame": 27, "volume": 0.500},
        {"file": "Shoe_Foot_Short.wav", "frame": 28, "volume": 0.500},
        {"file": "Air_Kick_Light_1.wav", "frame": 36, "volume": 0.600},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 46, "volume": 0.450},
        {"file": "Shoe_Foot_L.wav", "frame": 49, "volume": 0.500},
        {"file": "Air_Punch_Light_1.wav", "frame": 53, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Air_Kick_Light_1.wav", "frame": 17, "volume": 0.450},
        {"file": "Shoe_Foot_R.wav", "frame": 27, "volume": 0.500},
        {"file": "Shoe_Foot_Short.wav", "frame": 28, "volume": 0.500},
        {"file": "Air_Kick_Light_1.wav", "frame": 36, "volume": 0.600},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 46, "volume": 0.450},
        {"file": "Shoe_Foot_L.wav", "frame": 49, "volume": 0.500},
        {"file": "Air_Punch_Light_1.wav", "frame": 53, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 2, "volume": 0.800},
        {"file": "Clothing_3.wav", "frame": 5, "volume": 0.450},
        {"file": "Shoe_Foot_R.wav", "frame": 6, "volume": 0.350},
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.600},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 34, "volume": 0.600},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 38, "volume": 0.750},
        {"file": "Shoe_Foot_L.wav", "frame": 61, "volume": 0.550},
        {"file": "Shoe_Foot_R.wav", "frame": 75, "volume": 0.550},
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.600},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 34, "volume": 0.600},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 38, "volume": 0.850},
        {"file": "Shoe_Foot_L.wav", "frame": 61, "volume": 0.550},
        {"file": "Shoe_Foot_R.wav", "frame": 75, "volume": 0.550},
       ],
    "grab1_miss": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 7, "volume": 0.200},
       ],
    "grab1_miss_brick": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 7, "volume": 0.200},
       ],
    "grab2": [
        {"file": "Shoe_Foot_L.wav", "frame": 10, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 11, "volume": 0.500},
       ],
    "grab2_brick": [
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 24, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 39, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 45, "volume": 0.600},
        {"file": "Clothing_4.wav", "frame": 45, "volume": 0.750},
        {"file": "Shoe_Foot_R.wav", "frame": 54, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 24, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 39, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 45, "volume": 0.600},
        {"file": "Clothing_4.wav", "frame": 45, "volume": 0.750},
        {"file": "Shoe_Foot_R.wav", "frame": 54, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 24, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 39, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 45, "volume": 0.600},
        {"file": "Clothing_4.wav", "frame": 45, "volume": 0.750},
        {"file": "Shoe_Foot_R.wav", "frame": 54, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 10, "volume": 0.500},
        {"file": "Kick_Body_Light_1.wav", "frame": 11, "volume": 0.600},
        {"file": "Air_Kick_Light_1.wav", "frame": 21, "volume": 0.500},
        {"file": "Kick_Body_Heavy_1.wav", "frame": 21, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 22, "volume": 0.600},
        {"file": "Air_Kick_Light_1.wav", "frame": 7, "volume": 0.700},
        {"file": "Clothing_4.wav", "frame": 21, "volume": 0.600},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 23, "volume": 0.700},
        {"file": "Shoe_Foot_R.wav", "frame": 41, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 10, "volume": 0.500},
        {"file": "Kick_Body_Light_1.wav", "frame": 11, "volume": 0.600},
        {"file": "Air_Kick_Light_1.wav", "frame": 21, "volume": 0.500},
        {"file": "Kick_Body_Heavy_1.wav", "frame": 21, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 22, "volume": 0.600},
       ],
    "grab2_miss": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 7, "volume": 0.200},
       ],
    "grab2_miss_brick": [
        {"file": "Shoe_Foot_L.wav", "frame": 6, "volume": 0.450},
        {"file": "Clothing_4.wav", "frame": 7, "volume": 0.200},
       ],
    "high_kick": [
        {"file": "Air_Kick_Light_1.wav", "frame": 2, "volume": 1.000},
        {"file": "Clothing_4.wav", "frame": 6, "volume": 0.800},
        {"file": "Shoe_Foot_L.wav", "frame": 24, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 46, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 57, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 65, "volume": 0.600},
       ],
    "high_kick2": [
        {"file": "Air_Kick_Light_1.wav", "frame": 2, "volume": 1.000},
        {"file": "Clothing_3.wav", "frame": 5, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 22, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 35, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 43, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 56, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 72, "volume": 0.610},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 72, "volume": 0.600},
       ],
    "high_kick3": [
        {"file": "Air_Kick_Heavy_1.wav", "frame": 2, "volume": 1.000},
        {"file": "Clothing_4.wav", "frame": 9, "volume": 0.800},
        {"file": "Shoe_Foot_L.wav", "frame": 17, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 23, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 38, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 41, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 49, "volume": 0.590},
       ],
    "high_punch": [
        {"file": "Air_Kick_Light_1.wav", "frame": 3, "volume": 1.000},
       ],
    "high_punch2": [
        {"file": "Air_Punch_Heavy_1.wav", "frame": 2, "volume": 1.000},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 31, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 48, "volume": 0.600},
       ],
    "high_punch3": [
        {"file": "Air_Kick_Heavy_1.wav", "frame": 1, "volume": 1.000},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 29, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 30, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 61, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 63, "volume": 0.550},
        {"file": "Shoe_Foot_L.wav", "frame": 71, "volume": 0.650},
       ],
    "kick": [
        {"file": "Shoe_Foot_R.wav", "frame": 5, "volume": 0.600},
        {"file": "Clothing_4.wav", "frame": 5, "volume": 0.800},
        {"file": "Air_Kick_Light_1.wav", "frame": 6, "volume": 0.630},
        {"file": "Shoe_Foot_L.wav", "frame": 26, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 38, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 46, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 47, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 64, "volume": 0.650},
       ],
    "low_kick": [
        {"file": "Shoe_Foot_R.wav", "frame": 5, "volume": 0.600},
        {"file": "Clothing_4.wav", "frame": 5, "volume": 0.800},
        {"file": "Air_Kick_Light_1.wav", "frame": 6, "volume": 0.630},
        {"file": "Shoe_Foot_L.wav", "frame": 26, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 38, "volume": 0.700},
        {"file": "Shoe_Foot_L.wav", "frame": 46, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 47, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 64, "volume": 0.650},
       ],
    "low_kick2": [
        {"file": "Shoe_Foot_L.wav", "frame": 3, "volume": 0.600},
        {"file": "Air_Kick_Light_1.wav", "frame": 6, "volume": 1.000},
        {"file": "Shoe_Foot_L.wav", "frame": 16, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 26, "volume": 0.650},
       ],
    "low_kick3": [
        {"file": "Air_Kick_Light_1.wav", "frame": 7, "volume": 0.700},
        {"file": "Shoe_Foot_R.wav", "frame": 7, "volume": 0.550},
        {"file": "Shoe_Foot_L.wav", "frame": 23, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 25, "volume": 0.650},
        {"file": "Shoe_Foot_L.wav", "frame": 38, "volume": 0.580},
        {"file": "Shoe_Foot_L.wav", "frame": 41, "volume": 0.600},
       ],
    "low_punch": [
        {"file": "Air_Punch_Light_1.wav", "frame": 4, "volume": 0.630},
        {"file": "Shoe_Foot_L.wav", "frame": 8, "volume": 0.600},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 8, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 13, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 16, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 34, "volume": 0.420},
        {"file": "Shoe_Foot_R.wav", "frame": 62, "volume": 0.600},
       ],
    "low_punch2": [
        {"file": "Shoe_Foot_Short_B.wav", "frame": 2, "volume": 0.600},
        {"file": "Air_Punch_Light_1.wav", "frame": 4, "volume": 1.000},
        {"file": "Shoe_Foot_L.wav", "frame": 7, "volume": 0.480},
        {"file": "Shoe_Foot_R.wav", "frame": 15, "volume": 0.510},
        {"file": "Shoe_Foot_L.wav", "frame": 23, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 56, "volume": 0.600},
       ],
    "low_punch3": [
        {"file": "Shoe_Foot_L.wav", "frame": 3, "volume": 0.500},
        {"file": "Air_Punch_Heavy_1.wav", "frame": 7, "volume": 1.000},
        {"file": "Shoe_Foot_R.wav", "frame": 8, "volume": 0.440},
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.510},
       ],
    "punch": [
        {"file": "Air_Punch_Light_1.wav", "frame": 4, "volume": 0.630},
        {"file": "Shoe_Foot_L.wav", "frame": 8, "volume": 0.600},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 8, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 13, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 16, "volume": 0.500},
        {"file": "Shoe_Foot_Short_B.wav", "frame": 34, "volume": 0.420},
        {"file": "Shoe_Foot_R.wav", "frame": 62, "volume": 0.600},
       ],
    "special_kick_high": [
        {"file": "Clothing_4.wav", "frame": 8, "volume": 0.600},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 9, "volume": 1.000},
        {"file": "Shoe_Foot_L.wav", "frame": 11, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 27, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 38, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 47, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 57, "volume": 0.500},
       ],
    "special_kick_high_brick": [
        {"file": "Clothing_4.wav", "frame": 10, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 10, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 23, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 28, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 40, "volume": 0.350},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 7, "volume": 0.600},
        {"file": "Shoe_Foot_R.wav", "frame": 22, "volume": 0.500},
        {"file": "Clothing_3.wav", "frame": 3, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 7, "volume": 0.600},
        {"file": "Shoe_Foot_L.wav", "frame": 15, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 26, "volume": 0.500},
       ],
    "special_kick_low_brick": [
        {"file": "Clothing_4.wav", "frame": 12, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 13, "volume": 0.500},
        {"file": "Boot_Slide_Short.wav", "frame": 21, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 36, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 52, "volume": 0.500},
        {"file": "Clothing_4.wav", "frame": 12, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 13, "volume": 0.500},
        {"file": "Boot_Slide_Short.wav", "frame": 21, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 36, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 52, "volume": 0.500},
        {"file": "Clothing_4.wav", "frame": 12, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 13, "volume": 0.500},
        {"file": "Boot_Slide_Short.wav", "frame": 21, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 36, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 52, "volume": 0.500},
       ],
    "special_kick_low_hit": [
        {"file": "Shoe_Foot_Long.wav", "frame": 0, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 20, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 32, "volume": 0.500},
       ],
    "special_kick_low_miss": [
        {"file": "Air_Kick_Heavy_1.wav", "frame": 12, "volume": 1.000},
        {"file": "Boot_Slide_Long.wav", "frame": 13, "volume": 0.510},
       ],
    "special_punch_high_brick": [
        {"file": "Shoe_Foot_L.wav", "frame": 5, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 9, "volume": 0.750},
        {"file": "Shoe_Foot_R.wav", "frame": 16, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 33, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 45, "volume": 0.500},
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.750},
        {"file": "Shoe_Foot_R.wav", "frame": 4, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 24, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 45, "volume": 0.500},
        {"file": "Clothing_4.wav", "frame": 2, "volume": 0.750},
        {"file": "Shoe_Foot_R.wav", "frame": 4, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 24, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 45, "volume": 0.500},
       ],
    "special_punch_high_hit": [
        {"file": "Air_Punch_Light_1.wav", "frame": 4, "volume": 0.500},
        {"file": "Air_Punch_Light_1.wav", "frame": 17, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 41, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 77, "volume": 0.500},
       ],
    "special_punch_low_brick": [
        {"file": "Shoe_Foot_L.wav", "frame": 12, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 13, "volume": 0.750},
        {"file": "Shoe_Foot_L.wav", "frame": 12, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 13, "volume": 0.750},
        {"file": "Shoe_Foot_L.wav", "frame": 12, "volume": 0.500},
        {"file": "Air_Kick_Heavy_1.wav", "frame": 13, "volume": 0.750},
       ],
    "special_punch_low_hit": [
        {"file": "Air_Punch_Heavy_1.wav", "frame": 1, "volume": 0.500},
        {"file": "Shoe_Foot_L.wav", "frame": 3, "volume": 0.500},
        {"file": "Punch_Body_Heavy_2.wav", "frame": 4, "volume": 0.800},
        {"file": "Shoe_Foot_L.wav", "frame": 149, "volume": 0.500},
        {"file": "Shoe_Foot_R.wav", "frame": 169, "volume": 0.500},
       ],
}

## Recovered second stage of an endattack finisher: the victim's own
## `endattackcomp` action.  brucelee.set stores one such action per attacker set
## family (`endattackcomp1/2`, `endattackcompkarate 1/2`, `endattackcompthai
## 1/2`) and every one of them carries its OWN `sounds[]` rows at that clip's
## 30 fps frames.  `data/native_links.json` (generated from brucelee.set) gives
## action -> clip, so the rows are selected from the clip the victim is really
## playing.  A clip with no recovered action (kungfu has no endattackcomp at
## all) maps to "" and therefore plays nothing: the table never borrows another
## action's cue.
const ENDATTACK_COMP_CLIP_ACTIONS: Dictionary = {
    "all_end_attack_01_forset01": "endattackcomp1",
    "all_end_attack_02_forset01": "endattackcomp2",
    "all_end_attack_01_forset02": "endattackcompkarate 1",
    "all_end_attack_02_forset02": "endattackcompkarate 2",
    "all_end_attack_01_forset03": "endattackcompthai 1",
    "all_end_attack_02_forset03": "endattackcompthai 2",
}

## Port attack slots whose attacker-side cues the recovered sets name
## `<slot> <set character>` ("endattack ken", "endattack brick", ...).  The
## opponent attack config's own `source_action` selects the row group, so a
## missing row means no cue instead of a guessed one.
const ENDATTACK_ATTACK_SLOTS: Dictionary = {
    "endattack": true,
    "endattack_brick": true,
}

## Set-family movement cues (movefwd) for the footstep layer.
const MOVE_SFX: Dictionary = {
    "brucelee": [
        {"file": "Shoe_Foot_R.wav", "frame": 6, "volume": 0.480},
        {"file": "Shoe_Foot_L.wav", "frame": 12, "volume": 0.500},
       ],
    "thai": [
        {"file": "Shoe_Foot_L.wav", "frame": 0, "volume": 0.500},
        {"file": "Boot_L.wav", "frame": 0, "volume": 0.550},
        {"file": "Boot_L.wav", "frame": 0, "volume": 0.550},
        {"file": "Shoe_Foot_R.wav", "frame": 10, "volume": 0.500},
        {"file": "Boot_R.wav", "frame": 10, "volume": 0.550},
        {"file": "Boot_R.wav", "frame": 10, "volume": 0.550},
       ],
    "karate": [
        {"file": "Boot_L.wav", "frame": 1, "volume": 0.500},
        {"file": "Boot_R.wav", "frame": 10, "volume": 0.500},
       ],
    "kungfu": [
        {"file": "Shoe_Foot_R.wav", "frame": 18, "volume": 0.550},
        {"file": "Shoe_Foot_L.wav", "frame": 38, "volume": 0.550},
        {"file": "Shoe_Foot_R.wav", "frame": 59, "volume": 0.550},
        {"file": "Shoe_Foot_L.wav", "frame": 80, "volume": 0.550},
       ],
}

## Cues only present in an opponent's own set (Clothing_2 in kungfu).
const SET_ACTION_SFX: Dictionary = {
    "kungfu": {
        "faceupattack": [
            {"file": "Clothing_4.wav", "frame": 7, "volume": 0.750},
            {"file": "Shoe_Foot_L.wav", "frame": 21, "volume": 0.550},
            {"file": "Clothing_2.wav", "frame": 23, "volume": 0.500},
            {"file": "Shoe_Foot_R.wav", "frame": 36, "volume": 0.550},
           ],
    },
}


static func action_cues(action: String) -> Array:
    if SFX_ACTIONS.has(action):
        return SFX_ACTIONS[action]
    return []


static func attack_cues(kind: String) -> Array:
    if ATTACK_SFX.has(kind):
        return ATTACK_SFX[kind]
    return action_cues(kind)


## Recovered `sounds[]` rows of the victim clip that is actually playing.
## "" when the clip has no recovered action (fail closed, no borrowed cue).
static func endattack_comp_action(clip: String) -> String:
    if clip.is_empty():
        return ""
    return String(ENDATTACK_COMP_CLIP_ACTIONS.get(clip, ""))


static func set_cues(family: String, action: String) -> Array:
    if not SET_ACTION_SFX.has(family):
        return []
    var rows: Dictionary = SET_ACTION_SFX[family]
    if rows.has(action):
        return rows[action]
    return []


static func scene_music(scene: String) -> String:
    if SCENE_MUSIC.has(scene):
        return String(SCENE_MUSIC[scene])
    return String(SCENE_MUSIC.get("", ""))


static func story_music(path: String) -> String:
    if STORY_MUSIC.has(path):
        return String(STORY_MUSIC[path])
    var name: String = path.get_file()
    for key: String in STORY_MUSIC:
        if String(STORY_MUSIC[key]).get_file() == name:
            return String(STORY_MUSIC[key])
    return ""


static func move_cues(family: String) -> Array:
    if MOVE_SFX.has(family):
        return MOVE_SFX[family]
    return MOVE_SFX.get("brucelee", [])


static func has_track(path: String) -> bool:
    return MUSIC_FILES.has(path)

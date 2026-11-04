extends RefCounted
class_name MenuSfxMap
## Canonical map of the nine original menu SFX, recovered from
## data.zpak -> adreno_200/sounds/menu_sfx (all nine verified byte-identical to
## the archive decode; see menu-sfx-full-20261104/evidence/menu_sfx_inventory.json).
##
## Every role below is tied to the decoded ORIGINAL UI/data that plays it; the
## `file` values are the exact archive basenames. Nothing here is invented.
##
## Source evidence (original data):
##   * gui/*.ui  `blmenu.sound`  -> menu_punch_2  (list cursor move)
##   * gui/*.ui  `bldock.sound`  -> story_page_flip_short_version (dock page turn)
##   * gui/backbutton.ui `blbutton(back).sound` and every `blbutton` action
##     rsk/backtomain -> back_bl_shout_short (back)
##   * gui/*eventdetails.ui / results / unlock.ui `blbutton|blmenu(fight)`
##     -> select_play_bl_shout (accept / start)
##   * gui/confirmbacktomainmenu.ui + confirmbacktomap.ui `blmenu.sound`
##     -> bonus_2_kata_scream (confirm / leave prompt)
##   * gui/loaded.ui `blbutton(toucharea).sound` -> combat_loading_gong (loading)
##   * ELF libdefault.so hardcodes (no .ui binding):
##       sounds/Menu_SFX/Bonus_Jingle.wav
##       sounds/Menu_SFX/Map_Selection_Flute.wav
##       sounds/Menu_SFX/New_Event_3_Drum_Hits.wav
##     played by exported functions PlayLevelUpSound / PlayEventSelectSound /
##     PlayUnlockSound (exact 1:1 pairing not proven by disassembly).
##
## There is NO dedicated "denied" cue in the original UI or engine: the only
## blocking contexts reuse `back_bl_shout_short` (notavailableindemo/lite popups)
## or `bonus_2_kata_scream` (confirm dialogs). DENIED is therefore left empty and
## the port must stay silent rather than invent a sound.

const ALL_FILES: Array[String] = [
	"Back_BL_Shout_Short.wav",
	"Bonus_2_kata_Scream.wav",
	"Bonus_Jingle.wav",
	"Combat_Loading_Gong.wav",
	"Map_Selection_Flute.wav",
	"Menu_Punch_2.wav",
	"New_Event_3_Drum_Hits.wav",
	"Select_Play_Bl_Shout.wav",
	"Story_Page_Flip_Short_Version.wav",
]

## Roles the port's menus currently use. Empty string means "no original cue".
const NAV := "Menu_Punch_2.wav"
const ACCEPT := "Select_Play_Bl_Shout.wav"
const BACK := "Back_BL_Shout_Short.wav"
const PAGE_FLIP := "Story_Page_Flip_Short_Version.wav"
const DENIED := ""  # unsourced: never substitute another file here

## Original contexts not yet drawn by the port (kept so a future screen can use
## the exact file without re-deriving it). CONFIRM/LOADING come from decoded .ui;
## the three engine files are hardcoded in libdefault.so.
const CONFIRM := "Bonus_2_kata_Scream.wav"
const LOADING := "Combat_Loading_Gong.wav"
const ENGINE_FILES: Array[String] = [
	"Bonus_Jingle.wav",
	"Map_Selection_Flute.wav",
	"New_Event_3_Drum_Hits.wav",
]

const ROLE_FILES: Dictionary = {
	"nav": NAV,
	"accept": ACCEPT,
	"back": BACK,
	"page_flip": PAGE_FLIP,
	"denied": DENIED,
	"confirm": CONFIRM,
	"loading": LOADING,
}

static func file_for_role(role: String) -> String:
	return String(ROLE_FILES.get(role, ""))

static func has_denied_cue() -> bool:
	return DENIED != ""

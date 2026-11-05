extends SceneTree
## Headless validation of the NARROWED profile-bodies deliverable.
##
## Proven and implemented:
##   * statistics — statsmenu.ui subrows (game_modes/battles/moves -> stats1/2/3)
##     open the decoded stats1/2/3 row tables; row titles are the decoded .lang
##     labels and each value widget's declared `stats` key is shown while the
##     runtime value stays NOT RECOVERED.
##   * achievements — the decoded achievementstable.ui shell (title, box,
##     statsview frame, pages label, rsk back).  The statsview ROW BINDING is
##     NOT RECOVERED (no widget/game.states reference), so the 38
##     achievements.list rows are an inventory only and are not drawn.
##   * art / fighters — decoded layout shells only; the pictureslider and grid
##     bindings are NOT RECOVERED and the 18 / 10 decoded refs stay inventory.
##
## Modes (last arg): normal | failclosed
##
##   godot --headless --path <project> --script res://tests/validate_profile_bodies.gd \
##         --quit-after 12000 -- <player.glb> <opponent.glb> <normal|failclosed>

const MenuArt = preload("res://scripts/menu_art.gd")
const ProfileBodies = preload("res://scripts/profile_bodies.gd")

const NR := "NOT RECOVERED"
var passed: int = 0
var failed: int = 0
var mode: String = "normal"
var scene: Node = null
var menu: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _check(cond: bool, desc: String) -> bool:
	if cond:
		passed += 1
		print("PASS " + desc)
	else:
		failed += 1
		printerr("FAIL " + desc)
	return cond


func _finish() -> void:
	print("PROFILE_BODIES_VALIDATION=" + JSON.stringify(
		{"mode": mode, "passed": passed, "failed": failed}))
	quit(1 if failed > 0 else 0)


func _any_contains(values: Array, needle: String) -> bool:
	for v: Variant in values:
		if String(v).contains(needle):
			return true
	return false


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Expected <player.glb> <opponent.glb> [normal|failclosed]")
		quit(1)
		return
	mode = args[2] if args.size() > 2 else "normal"
	OS.set_environment("BRUCELEE_MENU_ART", "1")
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
	OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
	for n: String in ["BRUCELEE_STORY_FLOW","BRUCELEE_STORY_LAUNCH","BRUCELEE_GAME_MODE",
		"BRUCELEE_MODE_LAUNCH","BRUCELEE_ATTRACT","BRUCELEE_CONTINUE","BRUCELEE_PROGRESS",
		"BRUCELEE_STYLE_EDITOR","BRUCELEE_SCENE","BRUCELEE_LANG"]:
		OS.set_environment(n, "")
	OS.set_environment("BRUCELEE_RECOVERED_PAGES_PATH", "")
	if mode == "failclosed":
		OS.set_environment("BRUCELEE_PROFILE_BODIES_PATH",
			"res://data/menu_art/__missing_profile_bodies__.json")
	else:
		OS.set_environment("BRUCELEE_PROFILE_BODIES_PATH", "")

	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	scene.set_process(false)
	scene.set_physics_process(false)
	var player: Object = scene.get("player")
	var computer: Object = scene.get("computer")
	if player != null: player.set_physics_process(false)
	if computer != null: computer.set_physics_process(false)
	menu = scene.get("prototype_menu")
	if not _check(menu != null and menu is MenuArt, "BRUCELEE_MENU_ART=1 selects PortMenuArt"):
		_finish(); return

	if mode == "failclosed":
		await _check_failclosed()
		_finish(); return

	_check_artifact()
	await _check_achievements_flow()
	await _check_statistics_flow()
	await _check_art_flow()
	await _check_fighters_flow()
	_finish()


func _open_main_row(index: int) -> void:
	scene.call("_open_main_menu")
	await process_frame
	for _i: int in range(index):
		menu.call("handle_key_event", _key(KEY_DOWN))
		await process_frame
	menu.call("handle_key_event", _key(KEY_ENTER))
	await process_frame


func _press(keycode: Key) -> void:
	menu.call("handle_key_event", _key(keycode))
	await process_frame


func _open_profile_row(index: int) -> void:
	await _open_main_row(1)
	for _i: int in range(index):
		await _press(KEY_DOWN)
	await _press(KEY_ENTER)


func _check_artifact() -> void:
	_check(bool(menu.call("profile_bodies_available")), "profile-bodies artifact loads")
	_check(ProfileBodies.error() == "", "profile-bodies artifact has no error")
	var ach: Dictionary = ProfileBodies.achievements()
	_check(int(ach.get("row_count", 0)) == 38, "38 achievement inventory rows decoded")
	_check(String(ach.get("page_format", "")) == "%d/%d",
		"achievement page format is the decoded %d/%d")
	_check(String(ach.get("row_binding", "")) == NR,
		"achievement statsview row binding is NOT RECOVERED")
	_check(String(ach.get("reached_state", "")) == NR,
		"achievement reached state is NOT RECOVERED")
	var pages: Dictionary = ProfileBodies.stats_pages()
	_check(Array(Dictionary(pages.get("stats1", {})).get("rows", [])).size() == 5,
		"stats1 has the 5 decoded rows")
	_check(Array(Dictionary(pages.get("stats2", {})).get("rows", [])).size() == 7,
		"stats2 has the 7 decoded rows")
	_check(Array(Dictionary(pages.get("stats3", {})).get("rows", [])).size() == 7,
		"stats3 has the 7 decoded rows")
	var art: Dictionary = ProfileBodies.artpictures()
	_check(Array(art.get("items", [])).size() == 18, "18 artpictures album rows decoded")
	_check(String(art.get("slider_binding", "")) == "PROVEN",
		"art pictureslider binding is PROVEN (native AddPicture order)")
	_check(String(art.get("slider_binding_evidence", "")).contains("0x16f130"),
		"art binding cites CUnlocker::SetArtPicturesToSlider")
	_check(String(Dictionary(Array(art.get("items", []))[0]).get("basename", ""))
		== "galeryart2_1", "art order starts at the decoded galeryart2_1")
	var fighters: Dictionary = ProfileBodies.fighters()
	_check(Array(fighters.get("items", [])).size() == 10,
		"10 characters.list uniques decoded")
	_check(String(fighters.get("grid_binding", "")) == "PROVEN",
		"fighter grid binding is PROVEN")
	_check(String(fighters.get("selection", "")) == "PROVEN",
		"fighters_gallery_current selectedcell binding is PROVEN")
	_check(String(fighters.get("profile_binding", "")) == "PROVEN",
		"fighter profile page binding is PROVEN")
	_check(int(fighters.get("grid_numcolumns", 0)) == 2,
		"grid numcolumns is the proven property default 2")
	_check(String(Dictionary(Array(fighters.get("items", []))[9]).get("name", ""))
		== "loming", "fighter order ends at the decoded loming")


func _check_achievements_flow() -> void:
	await _open_profile_row(0)
	_check(String(menu.get("screen_id")) == "profile_page:achievements",
		"achievements row opens the recovered achievements shell")
	var texts: Array = menu.call("label_texts")
	_check(_any_contains(texts, "Achievements"), "achievements title is decoded")
	_check(_any_contains(texts, "STATSVIEW ROW BINDING " + NR),
		"achievements row binding is explicitly NOT RECOVERED")
	_check(_any_contains(texts, "38 decoded achievements.list entries"),
		"achievements inventory count is reported")
	_check(_any_contains(texts, "PAGE " + NR),
		"achievement page counter is explicitly NOT RECOVERED")
	_check(not _any_contains(texts, "Finish arcade (Easy)"),
		"unbound achievement rows are NOT rendered")
	var info: Dictionary = menu.call("achievements_body_info")
	_check(String(info.get("row_binding", "")) == NR,
		"achievements hook reports the unproven row binding")
	await _press(KEY_ESCAPE)
	_check(String(menu.get("screen_id")) == "player_profile",
		"BACK from achievements returns to Player Profile")


func _check_statistics_flow() -> void:
	await _open_profile_row(1)
	_check(String(menu.get("screen_id")) == "profile_page:statistics",
		"statistics row opens the recovered statsmain")
	var texts: Array = menu.call("label_texts")
	_check(_any_contains(texts, "game_modes -> stats1"),
		"statistics shows the decoded subrow game_modes -> stats1")
	_check(_any_contains(texts, "battles -> stats2"),
		"statistics shows the decoded subrow battles -> stats2")
	_check(_any_contains(texts, "moves -> stats3"),
		"statistics shows the decoded subrow moves -> stats3")
	_check(_any_contains(texts, "STATS VALUES " + NR),
		"statistics body values are explicitly NOT RECOVERED")
	await _press(KEY_ENTER)
	_check(String(menu.get("screen_id")) == "profile_page:statistics:stats1",
		"ENTER opens the recovered stats1 body")
	var info: Dictionary = menu.call("stats_body_info")
	_check(int(info.get("row_count", 0)) == 5, "stats1 body has the 5 decoded rows")
	_check(Array(info.get("titles", [])).has("Best Story"),
		"stats1 row title is decoded (Best Story)")
	_check(Array(info.get("stat_keys", [])).has("story_top_level"),
		"stats1 binds the decoded stats key story_top_level")
	var texts1: Array = menu.call("label_texts")
	_check(_any_contains(texts1, NR), "stats1 values are explicitly NOT RECOVERED")
	_check(_any_contains(texts1, "story_top_level"), "stats1 shows the bound stats key")
	await _press(KEY_DOWN)
	_check(int(menu.call("profile_selection")) == 1,
		"DOWN moves the decoded stats submenu selection")
	await _press(KEY_ENTER)
	_check(String(menu.get("screen_id")) == "profile_page:statistics:stats2",
		"ENTER opens the recovered stats2 body")
	var texts2: Array = menu.call("label_texts")
	_check(_any_contains(texts2, "Fights"), "stats2 row title is decoded (Fights)")
	_check(_any_contains(texts2, "number_of_fights"), "stats2 shows number_of_fights")
	await _press(KEY_ESCAPE)
	_check(String(menu.get("screen_id")) == "player_profile",
		"BACK from a stats body returns to Player Profile (backtomain)")


func _check_art_flow() -> void:
	await _open_profile_row(2)
	_check(String(menu.get("screen_id")) == "profile_page:art",
		"art row opens the recovered album shell")
	var info: Dictionary = menu.call("art_album_info")
	_check(int(info.get("item_count", 0)) == 18, "album has 18 decoded pictures")
	_check(String(info.get("slider_binding", "")) == "PROVEN",
		"art slider binding is PROVEN")
	_check(String(info.get("current", "")) == "galeryart2_1",
		"album opens on the first decoded artpictures.list entry")
	var texts: Array = menu.call("label_texts")
	_check(_any_contains(texts, "1/18  galeryart2_1.tex"),
		"album shows the decoded picture index and file name")
	_check(_any_contains(texts, "artpictures.list order, PROVEN"),
		"album states the proven list order")
	_check(_any_contains(texts, "UNLOCK STATE " + "NOT RECOVERED IN THIS BUILD"),
		"album keeps the runtime unlock state explicitly NOT RECOVERED")
	await _press(KEY_RIGHT)
	_check(int(menu.call("profile_selection")) == 1,
		"RIGHT advances the pictureslider by one")
	_check(String(Dictionary(menu.call("art_album_info")).get("current", ""))
		== "galeryart2-c6", "picture 2 is the decoded galeryart2-c6")
	await _press(KEY_DOWN)
	_check(int(menu.call("profile_selection")) == 2,
		"DOWN is the documented PORT alias for the next picture")
	await _press(KEY_LEFT)
	_check(int(menu.call("profile_selection")) == 1, "LEFT steps back one picture")
	await _press(KEY_ESCAPE)
	_check(String(menu.get("screen_id")) == "player_profile",
		"BACK from art returns to Player Profile")


func _check_fighters_flow() -> void:
	await _open_profile_row(3)
	_check(String(menu.get("screen_id")) == "profile_page:fighters",
		"fighters row opens the recovered gallery grid")
	var info: Dictionary = menu.call("fighter_gallery_info")
	_check(int(info.get("item_count", 0)) == 10, "gallery has 10 decoded uniques")
	_check(String(info.get("grid_binding", "")) == "PROVEN",
		"fighter grid binding is PROVEN")
	_check(String(info.get("selectedcell_option", "")) == "fighters_gallery_current",
		"grid selectedcell is bound to fighters_gallery_current")
	_check(int(info.get("columns", 0)) == 2, "grid uses the proven 2-column default")
	var texts: Array = menu.call("label_texts")
	_check(_any_contains(texts, "Bruce Lee"), "cell 0 draws the decoded Bruce Lee")
	_check(_any_contains(texts, "Lo Ming"), "cell 9 draws the decoded Lo Ming")
	_check(_any_contains(texts, "characters.list uniques, PROVEN"),
		"grid states the proven membership/order")
	await _press(KEY_RIGHT)
	_check(int(menu.call("profile_selection")) == 1, "RIGHT moves one cell")
	await _press(KEY_DOWN)
	_check(int(menu.call("profile_selection")) == 3,
		"DOWN moves one ROW (+numcolumns = 2 cells)")
	await _press(KEY_ENTER)
	_check(String(menu.get("screen_id")) == "profile_page:fighters:3",
		"ENTER raises the grid's profile action for cell 3")
	var pinfo: Dictionary = menu.call("fighter_profile_info")
	_check(String(pinfo.get("name_key", "")) == "smallboy",
		"profile page resolves the same unique index (smallboy)")
	_check(String(pinfo.get("profile_binding", "")) == "PROVEN",
		"profile page binding is PROVEN")
	_check(String(pinfo.get("profile_text_key", "")) == "smallboy_profile",
		"profile page uses the decoded profile_text_tag key")
	var texts2: Array = menu.call("label_texts")
	_check(_any_contains(texts2, "Smallboy"), "profile page shows the decoded name")
	_check(_any_contains(texts2, "PHOTO " + "NOT RECOVERED IN THIS BUILD"),
		"profile photo pixels are explicitly NOT RECOVERED")
	await _press(KEY_ESCAPE)
	_check(String(menu.get("screen_id")) == "profile_page:fighters",
		"BACK from the fighter profile returns to the grid")
	await _press(KEY_ESCAPE)
	_check(String(menu.get("screen_id")) == "player_profile",
		"BACK from the grid returns to Player Profile")


func _check_failclosed() -> void:
	_check(not ProfileBodies.available(), "missing profile-bodies artifact fails closed")
	_check(ProfileBodies.error().contains("missing artifact"),
		"fail-closed cause is reported")
	_check(ProfileBodies.achievement_rows().is_empty(),
		"achievement inventory empty when fail closed")
	_check(ProfileBodies.art_items().is_empty(), "art inventory empty when fail closed")
	_check(ProfileBodies.fighter_items().is_empty(),
		"fighter inventory empty when fail closed")
	await _open_profile_row(0)
	_check(String(menu.get("screen_id")) == "profile_page:achievements",
		"achievements screen opens but stays fail closed")
	var texts: Array = menu.call("label_texts")
	_check(_any_contains(texts, "PROFILE PAGE " + "NOT RECOVERED IN THIS BUILD"),
		"achievements body keeps the explicit NOT RECOVERED marker")
	_check(_any_contains(texts, "profile bodies failed closed"),
		"achievements body reports the fail-closed cause")

extends SceneTree
## Headless input-flow validation for the TWO art/fighters gallery bindings that
## the earlier profile-bodies phase left NOT RECOVERED:
##
##   * ART      — artpicture.ui `pictureslider` (`album`) items come from
##                CUnlocker::SetArtPicturesToSlider (ELF 0x16f130) ->
##                CPictureSlider::AddPicture (0x219038, append): the album order
##                is exactly the decoded artpictures.list array order (18 rows).
##   * FIGHTERS — fightergalleryselect.ui `blfightergrid` cells are the
##                characters.list `uniques` array in array order (10 rows);
##                `selectedcell` is the `fighters_gallery_current` option;
##                Redraw (0x247b90) uses col = i % numcolumns, row = i / numcolumns
##                with the proven property defaults (numcolumns 2 / sep 32 / 0);
##                Confirm raises the grid's `profile` action and
##                fightergalleryprofile.ui resolves name/profile_text_tag/
##                profile_picture for the SAME index (CCharacterList::QueryString
##                0x1aef28).
##
## Modes: normal | tamper_order | tamper_demoted
##   * tamper_order reorders the art rows in a temp artifact -> must FAIL CLOSED.
##   * tamper_demoted sets grid_binding back to NOT RECOVERED -> must FAIL CLOSED.
##
## Original artwork pixels are never required: with no BRUCELEE_ART_PREVIEW_ROOT
## the album must draw the frame and the explicit NOT RECOVERED marker.
##
##   godot --headless --path <project> --script res://tests/validate_gallery_bindings.gd \
##         --quit-after 16000 -- <player.glb> <opponent.glb> <mode>

const MenuArt = preload("res://scripts/menu_art.gd")
const ProfileBodies = preload("res://scripts/profile_bodies.gd")
const ARTIFACT := "res://data/menu_art/profile_bodies.json"

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
	print("GALLERY_BINDINGS_VALIDATION=" + JSON.stringify(
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
		printerr("Expected <player.glb> <opponent.glb> [normal|tamper_order|tamper_demoted]")
		quit(1)
		return
	mode = args[2] if args.size() > 2 else "normal"
	OS.set_environment("BRUCELEE_MENU_ART", "1")
	OS.set_environment("BRUCELEE_MAIN_MENU", "1")
	OS.set_environment("BRUCELEE_PLAYER_GLB", args[0])
	OS.set_environment("BRUCELEE_OPPONENT_GLB", args[1])
	for n: String in ["BRUCELEE_STORY_FLOW","BRUCELEE_STORY_LAUNCH","BRUCELEE_GAME_MODE",
		"BRUCELEE_MODE_LAUNCH","BRUCELEE_ATTRACT","BRUCELEE_CONTINUE","BRUCELEE_PROGRESS",
		"BRUCELEE_STYLE_EDITOR","BRUCELEE_SCENE","BRUCELEE_LANG",
		"BRUCELEE_ART_PREVIEW_ROOT","BRUCELEE_PROFILE_PICTURE_ROOT"]:
		OS.set_environment(n, "")
	OS.set_environment("BRUCELEE_RECOVERED_PAGES_PATH", "")
	OS.set_environment("BRUCELEE_PROFILE_BODIES_PATH", "")
	var tampered: bool = mode.begins_with("tamper_")
	if tampered:
		# The Godot child process cannot write user:// in this harness, so the
		# runner materialises the tampered copy outside the engine and passes its
		# absolute path as the 4th argument.
		if args.size() < 4 or not FileAccess.file_exists(args[3]):
			printerr("tamper mode needs <artifact-path> as the 4th argument")
			quit(1)
			return
		OS.set_environment("BRUCELEE_PROFILE_BODIES_PATH", args[3])

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

	if tampered:
		await _check_fail_closed(mode)
		_finish(); return

	_check_order_contract()
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


func _check_order_contract() -> void:
	_check(ProfileBodies.available(), "profile-bodies artifact loads")
	_check(ProfileBodies.error() == "", "artifact has no error")
	var art_items: Array = ProfileBodies.art_items()
	var expected_art: Array = ProfileBodies.expected_art_order()
	_check(art_items.size() == expected_art.size(),
		"art album has all 18 decoded rows")
	var art_ok: bool = true
	for i: int in range(mini(art_items.size(), expected_art.size())):
		if String(Dictionary(art_items[i]).get("basename", "")) != String(expected_art[i]):
			art_ok = false
	_check(art_ok, "art album order equals the decoded artpictures.list order")
	var fighters: Array = ProfileBodies.fighter_items()
	var expected_f: Array = ProfileBodies.expected_fighter_order()
	_check(fighters.size() == expected_f.size(),
		"fighter grid has all 10 decoded uniques")
	var f_ok: bool = true
	for i: int in range(mini(fighters.size(), expected_f.size())):
		if String(Dictionary(fighters[i]).get("name", "")) != String(expected_f[i]):
			f_ok = false
	_check(f_ok, "fighter cell order equals the decoded characters.list uniques order")
	_check(ProfileBodies.grid_columns() == 2, "grid columns come from the proven default 2")
	_check(ProfileBodies.selectedcell_option() == "fighters_gallery_current",
		"grid selectedcell option is fighters_gallery_current")


func _check_art_flow() -> void:
	await _open_profile_row(2)
	_check(String(menu.get("screen_id")) == "profile_page:art", "art row opens the album")
	var info: Dictionary = menu.call("art_album_info")
	_check(String(info.get("slider_binding", "")) == "PROVEN", "slider binding is PROVEN")
	_check(String(info.get("current", "")) == "galeryart2_1",
		"album starts at artpictures.list[0]")
	var texts: Array = menu.call("label_texts")
	_check(_any_contains(texts, "PICTURE " + "NOT RECOVERED IN THIS BUILD"),
		"no local artwork -> explicit NOT RECOVERED marker")
	_check(not _stage_has("ArtAlbumPicture"),
		"no picture texture is invented when the local artwork root is unset")
	var steps: int = ProfileBodies.art_items().size() - 1
	for _i: int in range(steps):
		await _press(KEY_RIGHT)
	_check(int(menu.call("profile_selection")) == steps,
		"RIGHT walks the full 18-picture album")
	_check(String(Dictionary(menu.call("art_album_info")).get("current", ""))
		== "galeryart2_c2", "last picture is the decoded galeryart2_c2")
	await _press(KEY_RIGHT)
	_check(int(menu.call("profile_selection")) == steps,
		"RIGHT clamps at the last picture (native cursor clamp)")
	for _i: int in range(steps):
		await _press(KEY_LEFT)
	_check(int(menu.call("profile_selection")) == 0, "LEFT walks back to picture 1")
	await _press(KEY_LEFT)
	_check(int(menu.call("profile_selection")) == 0, "LEFT clamps at picture 1")
	await _press(KEY_ESCAPE)
	_check(String(menu.get("screen_id")) == "player_profile",
		"BACK from art returns to Player Profile")


func _check_fighters_flow() -> void:
	await _open_profile_row(3)
	_check(String(menu.get("screen_id")) == "profile_page:fighters", "fighters row opens the grid")
	var info: Dictionary = menu.call("fighter_gallery_info")
	_check(String(info.get("grid_binding", "")) == "PROVEN", "grid binding is PROVEN")
	_check(int(info.get("columns", 0)) == 2, "grid draws 2 columns (proven default)")
	var texts: Array = menu.call("label_texts")
	_check(_any_contains(texts, "Bruce Lee"), "cell 0 is the decoded Bruce Lee")
	_check(_any_contains(texts, "Lo Ming"), "cell 9 is the decoded Lo Ming")
	_check(_stage_count_prefix("FighterCellLabel") == 10,
		"exactly the 10 decoded uniques are drawn as cells")
	# row-major walk: index 3 == row 1, column 1
	await _press(KEY_DOWN)
	_check(int(menu.call("profile_selection")) == 2, "DOWN moves +numcolumns (row)")
	await _press(KEY_RIGHT)
	_check(int(menu.call("profile_selection")) == 3, "RIGHT moves +1 (column)")
	await _press(KEY_ENTER)
	_check(String(menu.get("screen_id")) == "profile_page:fighters:3",
		"ENTER raises the grid profile action for cell 3")
	var pinfo: Dictionary = menu.call("fighter_profile_info")
	_check(String(pinfo.get("name_key", "")) == "smallboy",
		"profile page uses the same unique index (smallboy)")
	_check(String(pinfo.get("profile_text_key", "")) == "smallboy_profile",
		"profile text comes from the decoded profile_text_tag")
	_check(not String(pinfo.get("profile_text", "")).is_empty(),
		"profile text is the decoded Lang text, not a placeholder")
	_check(not _stage_has("FighterProfilePhoto"),
		"no portrait texture is invented when the local picture root is unset")
	await _press(KEY_ESCAPE)
	_check(String(menu.get("screen_id")) == "profile_page:fighters",
		"BACK from the fighter profile returns to the grid")
	await _press(KEY_ESCAPE)
	_check(String(menu.get("screen_id")) == "player_profile",
		"BACK from the grid returns to Player Profile")


func _stage_has(node_name: String) -> bool:
	var stage: Node = menu.get("_stage")
	if stage == null:
		return false
	for child: Node in stage.get_children():
		if child.name == node_name:
			return true
	return false


func _stage_count_prefix(prefix: String) -> int:
	var stage: Node = menu.get("_stage")
	if stage == null:
		return 0
	var count: int = 0
	for child: Node in stage.get_children():
		if String(child.name).begins_with(prefix):
			count += 1
	return count


func _check_fail_closed(kind: String) -> void:
	_check(not ProfileBodies.available(), "tampered artifact fails closed (%s)" % kind)
	var cause: String = ProfileBodies.error()
	_check(not cause.is_empty(), "fail-closed cause is reported")
	if kind == "tamper_order":
		_check(cause.contains("order"), "reordered art rows are rejected by the order gate: " + cause)
	elif kind == "tamper_demoted":
		_check(cause.contains("binding"), "demoted grid binding is rejected: " + cause)
	_check(ProfileBodies.art_items().is_empty(), "art items empty when fail closed")
	_check(ProfileBodies.fighter_items().is_empty(), "fighter items empty when fail closed")
	await _open_profile_row(2)
	var texts: Array = menu.call("label_texts")
	_check(_any_contains(texts, "PROFILE PAGE NOT RECOVERED IN THIS BUILD"),
		"art page keeps the explicit NOT RECOVERED marker when fail closed")
	_check(_any_contains(texts, "profile bodies failed closed"),
		"art page reports the fail-closed cause")

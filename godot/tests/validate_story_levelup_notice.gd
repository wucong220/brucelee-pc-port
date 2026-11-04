extends SceneTree

## Headless validation of the recovered StoryLevelUp / LevelUpNotify /
## ExperienceUnlock presentation data and model.
##
## Run: godot --headless --path <project> --script res://tests/validate_story_levelup_notice.gd
## Exit 0 = all checks pass, 1 = failure.

const StoryData = preload("res://scripts/story_data.gd")

var failures: int = 0
var checks: int = 0


func check(ok: bool, label: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label, ("  | " + detail) if detail != "" else "")


func check_eq(actual: Variant, expected: Variant, label: String) -> void:
	check(actual == expected, label, "actual=%s expected=%s" % [str(actual), str(expected)])


func _initialize() -> void:
	print("=== Story level-up / unlock notice validation ===")
	var model = StoryNoticeModel.new()
	check(model.is_loaded(), "story_notice.json loads", model.error)
	if not model.is_loaded():
		_finish()
		return

	# ---- recovered level table (from libdefault.so 0x5bbd78) ----
	var table: Array = model.data["level_rule"]["table"]
	check_eq(table.size(), 50, "level table has 50 entries")
	check_eq(table[0], 200, "table[0]=200 (unreachable)")
	check_eq(table[1], 500, "table[1]=500 (1->2)")
	check_eq(table[5], 1700, "table[5]=1700 (5->6)")
	check_eq(table[49], 20000, "table[49]=20000 (49->50)")

	# ---- level curve semantics (StoryLevelUpPending/StoryLevelUp) ----
	check_eq(model.level_for_exp(0), 1, "exp 0 -> level 1")
	check_eq(model.level_for_exp(499), 1, "exp 499 -> level 1")
	check_eq(model.level_for_exp(500), 2, "exp 500 -> level 2")
	check_eq(model.level_for_exp(799), 2, "exp 799 -> level 2")
	check_eq(model.level_for_exp(800), 3, "exp 800 -> level 3")
	check_eq(model.level_for_exp(1699), 5, "exp 1699 -> level 5")
	check_eq(model.level_for_exp(1700), 6, "exp 1700 -> level 6 (threshold 1700)")
	check_eq(model.level_for_exp(20000), 50, "exp 20000 -> level 50")
	check_eq(model.level_for_exp(999999), 50, "level saturates at 50")
	check(model.level_up_pending(500, 1), "pending(exp500,level1)=true")
	check(not model.level_up_pending(499, 1), "pending(exp499,level1)=false")
	check(model.level_up_pending(1700, 5), "pending(exp1700,level5)=true")
	check(not model.level_up_pending(1699, 5), "pending(exp1699,level5)=false")

	# ---- recovered layout matches the decoded .ui ----
	var lv: Dictionary = model.data["screens"]["levelup"]
	var ul: Dictionary = model.data["screens"]["unlock"]
	check_eq(lv["sha256"], "cfdb71021a07250e246699367920a83cdb6edba6e4f64a52a876510a5bebd119", "levelup.ui sha256 recovered")
	check_eq(ul["sha256"], "c37571f60f5756b1f87daeed5dfb63ecff7572cab5bd0545e05a11a0fc36aff5", "unlock.ui sha256 recovered")
	var lv_names: Array = []
	for w: Dictionary in lv["widgets"]:
		lv_names.append(w["name"])
	check_eq(lv_names, ["black_rect", "yellow_line1", "title", "level", "yellow_line2", "menu"], "levelup.ui widget order")
	var ul_names: Array = []
	for w: Dictionary in ul["widgets"]:
		ul_names.append(w["name"])
	check_eq(ul_names, ["black_rect", "yellow_line1", "title", "icon", "title", "yellow_line2", "menu"], "unlock.ui widget order (two title rows)")
	var lv_rect := _rect(lv["widgets"], "black_rect")
	check_eq(lv_rect, [0, 70, 480, 170], "levelup black_rect 0,70 480x170")
	check_eq(_rect(lv["widgets"], "level"), [40, 130, 400, 64], "levelup level label 40,130 400x64")
	var title_row := _nth(lv["widgets"], "title", 0)
	check_eq(String(title_row["datasources"]["text"][0]), "translate", "levelup title datasource is translate")
	check_eq(String(title_row["datasources"]["text"][1]), "you_reached_level", "levelup title key you_reached_level")
	var level_row := _nth(lv["widgets"], "level", 0)
	check_eq(String(level_row["datasources"]["text"][1]), "Level %d", "levelup body format 'Level %d'")
	check_eq(String(level_row["datasources"]["text"][2][1]), "storycurrentlevel", "levelup body value gamemodes.storycurrentlevel")
	check_eq(lv["sound"], "sounds/menu_sfx/menu_punch_2.wav", "levelup menu sound recovered")
	check_eq(ul["sound"], "sounds/menu_sfx/select_play_bl_shout.wav", "unlock menu sound recovered")

	# ---- recovered translations (no invented text) ----
	check_eq(model.text("you_reached_level"), "Level Up!", "you_reached_level = 'Level Up!'")
	check_eq(model.text("move_unlocked"), "New move learned!", "move_unlocked translation")
	check_eq(model.text("fighter_unlocked"), "New Fighter unlocked!", "fighter_unlocked translation")
	check_eq(model.text("scenery_unlocked"), "New location unlocked!", "scenery_unlocked translation")
	check_eq(model.text("art_unlocked"), "New art unlocked!", "art_unlocked translation")
	check_eq(model.text("profile_unlocked"), "New profile unlocked!", "profile_unlocked translation")
	check_eq(model.text("continue"), "Continue", "continue translation")
	check_eq(model.text("ok"), "OK", "ok translation")
	check_eq(model.text("unknown_key_xyz"), "unknown_key_xyz", "missing key returns key, never invents")

	# ---- item_type -> title key map (rodata 0x5b9344 order) ----
	var map: Dictionary = model.data["item_type_title_key"]
	check_eq(map["style_anim"], "move_unlocked", "style_anim -> move_unlocked")
	check_eq(map["fighter"], "fighter_unlocked", "fighter -> fighter_unlocked")
	check_eq(map["scenery"], "scenery_unlocked", "scenery -> scenery_unlocked")
	check_eq(map["fighter_profile"], "profile_unlocked", "fighter_profile -> profile_unlocked")
	check_eq(map["art_picture"], "art_unlocked", "art_picture -> art_unlocked")

	# ---- notices_for with a real grant from ProgressService ----
	var svc = ProgressService.new()
	var fresh: Array = svc.add_story_exp(1700)
	check_eq(fresh, [17, 35, 60, 69, 97, 100], "exp 1700 grants 6 fresh unlock ids")
	var resolver := Callable(self, "_fake_resolver")
	var notices: Array = model.notices_for(0, 1700, fresh, svc.registry, resolver, 1, -1)
	check_eq(notices.size(), 7, "6 unlock notices + 1 level-up notice")
	var kinds: Array = []
	for n: Dictionary in notices:
		kinds.append(n["kind"])
	check_eq(kinds.slice(0, 6), ["experienceunlock", "experienceunlock", "experienceunlock", "experienceunlock", "experienceunlock", "experienceunlock"], "unlock notices come first")
	check_eq(kinds[6], "levelupnotify", "level-up notice comes last")
	var lv_notice: Dictionary = notices[6]
	check_eq(lv_notice["title"], "Level Up!", "level-up notice title")
	check_eq(lv_notice["body"], "Level 6", "level-up notice body 'Level 6'")
	check_eq(lv_notice["menu_label"], "Continue", "level-up notice menu 'Continue'")
	# one unlock notice shape
	var first: Dictionary = notices[0]
	check_eq(first["title"], "New move learned!", "unlock 35 (style_anim) title 'New move learned!'")
	check_eq(first["item_name"], "TEST_ITEM_NAME", "proven item name shown")
	check(first["item_name_recovered"], "proven item name flagged recovered")
	check(not first["icon_recovered"], "unlock icon flagged NOT RECOVERED")
	check_eq(first["icon_label"], "NOT RECOVERED", "unlock icon literal NOT RECOVERED")

	# unproven resolver -> item name is NOT RECOVERED, not invented
	var notices2: Array = model.notices_for(0, 500, [35], svc.registry, Callable(self, "_unproven_resolver"), 1, -1)
	check_eq(notices2[0]["item_name"], "NOT RECOVERED", "unproven item name = NOT RECOVERED")
	check(not notices2[0]["item_name_recovered"], "unproven item name flagged not recovered")

	# unknown item type -> title NOT RECOVERED
	var fake_reg = _FakeRegistry.new(999, "mystery_type", 0)
	var n3: Dictionary = model.unlock_notice(999, fake_reg, Callable())
	check_eq(n3["title"], "NOT RECOVERED", "unknown item type title = NOT RECOVERED")
	check(not n3["title_recovered"], "unknown item type title flagged not recovered")

	# description helper never empty
	check(model.describe(lv_notice).begins_with("levelupnotify"), "describe(levelup)")

	# ---- the recovered layout builds real Controls (headless instantiation) ----
	var view = StoryNoticeView.new()
	root.add_child(view)
	view.present(lv_notice)
	check(view.get_child_count() > 0, "level-up view builds widgets from recovered layout")
	view.present(notices[0])
	check(view.get_child_count() > 0, "unlock view builds widgets from recovered layout")
	view.hide_notice()
	check(not view.visible, "hide_notice hides the view")
	view.queue_free()

	_finish()


func _fake_resolver(_t: String, _id: Variant) -> Dictionary:
	return {"name": "TEST_ITEM_NAME", "proven": true}


func _unproven_resolver(_t: String, _id: Variant) -> Dictionary:
	return {"name": "", "proven": false}


func _rect(widgets: Array, name: String) -> Array:
	for w: Dictionary in widgets:
		if String(w.get("name", "")) == name:
			return [int(w.get("x", -1)), int(w.get("y", -1)), int(w.get("width", -1)), int(w.get("height", -1))]
	return []


func _nth(widgets: Array, name: String, n: int) -> Dictionary:
	var i: int = 0
	for w: Dictionary in widgets:
		if String(w.get("name", "")) == name:
			if i == n:
				return w
			i += 1
	return {}


func _finish() -> void:
	print("RESULT checks=%d failures=%d" % [checks, failures])
	if failures == 0:
		print("ALL PASS")
	quit(0 if failures == 0 else 1)


class _FakeRegistry:
	var _entry: Dictionary
	func _init(id: int, item_type: String, item_id: Variant) -> void:
		_entry = {"item_type": item_type, "item_id": item_id, "id": id}
	func entry_for_id(_id: int) -> Dictionary:
		return _entry

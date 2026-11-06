extends SceneTree
## Headless validation of the recovered-`.lang` localization layer.
##
##   godot --headless --path godot --script res://tests/validate_menu_lang.gd
##
## What it proves:
##   1. the data table holds 37 recovered keys x 10 languages and every value
##      is non-empty (the Python gate `tools/validate.py` proves those values
##      are byte-identical to the decoded .lang lookup);
##   2. `MenuLang.text()` falls back to the KEY VERBATIM for an unknown key;
##   3. every Arcade / Survival / Time Attack screen and the shared prototype
##      menu render exactly the recovered labels, for all 10 languages;
##   4. labels with no recovered key keep their original literal text;
##   5. the per-language text dump (MENU_LANG_DUMP) is written for the
##      independent Python check.

const GameModes = preload("res://scripts/game_modes.gd")
const Rules = preload("res://scripts/game_modes_rules.gd")
const MenuLang = preload("res://scripts/menu_lang.gd")

var fails: Array = []
var dump: Dictionary = {}
var configs: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails.append(msg)


func _header(gm: Node) -> Array:
	return [
		String((gm.get("title_label") as Label).text),
		String((gm.get("subtitle_label") as Label).text),
		String((gm.get("footer_label") as Label).text),
	]


func _plain(line: String) -> String:
	var value: String = line.strip_edges()
	if value.begins_with("> "):
		value = value.substr(2)
	return value


func _body(gm: Node) -> Array:
	var out: Array = []
	for line: Variant in gm.call("body_lines"):
		out.append(_plain(String(line)))
	return out


func _banner(gm: Node) -> String:
	return String((gm.get("banner") as Label).text)


func _new_gm() -> Node:
	var gm: Node = GameModes.new()
	root.add_child(gm)
	gm.configure(null, configs)
	return gm


func _text(key: String) -> String:
	return MenuLang.text(key)


func _run() -> void:
	for token: String in ["sinfu", "master", "ken", "shenlo", "smallboy", "johnson",
			"loming", "brick", "chief"]:
		configs[token] = {"glb": "x.glb", "texture_port": "", "port_candidate": token}

	print("== data table ==")
	check(MenuLang.is_loaded(), "menu_lang.json loads")
	var data: Dictionary = MenuLang.data()
	var languages: Array = MenuLang.languages()
	check(languages.size() == 10, "10 languages in the table (got %d)" % languages.size())
	var keys: Dictionary = data.get("keys", {})
	check(keys.size() == 37, "37 recovered keys in the table (got %d)" % keys.size())
	var all_values := true
	var value_count := 0
	for key: Variant in keys:
		var row: Dictionary = keys[key]
		for lang: Variant in languages:
			var value: Variant = row.get(lang, null)
			value_count += 1
			if value == null or String(value).is_empty():
				all_values = false
				print("  EMPTY %s / %s" % [key, lang])
	check(all_values, "every key has a non-empty value in all 10 languages (%d values)" % value_count)

	var mapped_ok := true
	for section: String in ["command_keys", "setting_keys", "option_keys", "mode_keys", "character_keys"]:
		var table: Dictionary = data.get(section, {})
		for token: Variant in table:
			if not keys.has(String(table[token])):
				mapped_ok = false
				print("  MISSING %s.%s -> %s" % [section, token, table[token]])
	for site: Variant in data.get("sites", []):
		var site_key: String = String((site as Dictionary).get("key", ""))
		if site_key in ["mode_keys", "character_keys", "option_keys"]:
			continue
		if not keys.has(site_key):
			mapped_ok = false
			print("  MISSING site %s -> %s" % [(site as Dictionary).get("id", ""), site_key])
	check(mapped_ok, "every mapped site/command/setting/option/mode/name key exists in the table")
	check((data.get("sites", []) as Array).size() == 61, "61 mapped display sites recorded")
	check((data.get("unmapped", []) as Array).size() == 35, "35 unmapped display sites recorded")

	print("== fallback to the key ==")
	check(MenuLang.text("no_such_key_xyz") == "no_such_key_xyz",
		"unknown key falls back to the key verbatim")
	check(MenuLang.text("") == "", "empty key yields empty text")
	check(MenuLang.text("ARCADE") == MenuLang.text("arcade"),
		"case-insensitive key lookup (ARCADE -> arcade)")
	check(MenuLang.set_language("xx-bogus") == "LangEnglish",
		"unknown language falls back to LangEnglish")
	check(MenuLang.command_label("arcade", "FALLBACK") == MenuLang.text("arcade"),
		"command_label uses the recovered key")
	check(MenuLang.command_label("no_command", "FALLBACK") == "FALLBACK",
		"command_label keeps the original label when no key exists")
	check(MenuLang.setting_label("TIME LIMIT") == "TIME LIMIT",
		"setting_label keeps an unmapped schema label")
	check(MenuLang.option_label("(unrecovered)") == "(unrecovered)",
		"option_label keeps an unmapped option label")
	check(MenuLang.character("master") == MenuLang.text("themaster"),
		"character('master') -> recovered The Master")
	check(MenuLang.character("nobody") == "NOBODY",
		"unknown character token falls back to the upper-cased token")

	print("== English screen labels (exact recovered text) ==")
	MenuLang.set_language("LangEnglish")
	var en: Node = _new_gm()
	en.call("show_mode_menu")
	check(_header(en)[0] == "Game Modes", "mode menu title = Game Modes")
	check(_body(en) == ["Arcade", "Survival", "Time Attack"], "mode menu rows localized")
	en.call("open_mode", "arcade")
	check(_header(en)[0] == "Arcade · Settings", "arcade settings title = Arcade · Settings")
	check(_body(en) == ["Rounds   < 3 >", "Time   < 60 >", "Difficulty   < Medium >",
		"START", "Back"], "arcade settings rows localized (START stays literal)")
	en.call("open_mode", "timeattack")
	check(_header(en)[0] == "Time Attack · Settings", "time attack settings title")
	check(_body(en)[2] == "START", "unmapped START row keeps its literal text")
	check(_body(en)[3] == "Back", "BACK row localized")
	en.call("show_pause")
	check(_header(en)[0] == "Pause", "pause title = Pause")
	check(_body(en) == ["Resume", "Main Menu"], "pause rows localized")
	en.call("_show_error", "X", "Y")
	check(_body(en) == ["Back"], "error screen action localized")

	print("== English results / next fight / banner ==")
	en.set("current_mode", "arcade")
	en.set("run", {
		"mode": "arcade", "score": 450, "fights_done": 3, "opponent_count": 3,
		"difficulty_index": 2, "difficulty_slot": 4, "time_limit": 60,
		"resolved": {"rounds": 3, "score_per_fight": 150},
	})
	en.set("last_result", {"outcome": "complete", "reason": ""})
	en.call("show_results", "complete")
	var arcade_rows: Array = _body(en)
	check(arcade_rows[0] == "TOTAL SCORE   450", "arcade score row = TOTAL SCORE (recovered)")
	check(arcade_rows[1] == "Wins   3 / 3", "arcade fights row = Wins (recovered)")
	check(arcade_rows[2] == "score per fight   150 (100 + 25*2)",
		"unmapped 'score per fight' row stays literal")
	check(arcade_rows[3] == "Rounds / Time   3 · 60 s", "rounds/time row composed from recovered labels")
	check(arcade_rows[4] == "Difficulty   Hard (ai slot 4)", "difficulty row localized")
	check(arcade_rows[6] == "Play" and arcade_rows[7] == "Settings" and arcade_rows[8] == "Main Menu",
		"result actions localized (Play / Settings / Main Menu)")

	en.set("current_mode", "survival")
	en.set("run", {"mode": "survival", "fights_done": 2, "time_limit": 60,
		"difficulty_index": 1, "difficulty_slot": 2})
	en.call("show_results", "failed")
	var survival_rows: Array = _body(en)
	check(survival_rows[0] == "fights survived   2", "survival count row stays literal (no key)")
	check(survival_rows[2] == "max_fights   FAIL CLOSED (unrecovered standalone)",
		"survival fail-closed row stays literal")
	check(survival_rows[4] == "Difficulty   Medium (ai slot 2)", "survival difficulty localized")

	en.set("current_mode", "timeattack")
	en.set("run", {"mode": "timeattack", "fights_done": 2, "run_time_limit": 120,
		"elapsed_seconds": 95.4, "difficulty_index": 1, "difficulty_slot": 2})
	en.call("show_results", "failed")
	var ta_rows: Array = _body(en)
	check(ta_rows[0] == "Your victories   2", "time attack beaten row = Your victories")
	check(ta_rows[2] == "Your Time   95.4 s", "time attack elapsed row = Your Time")

	# Next fight: build a real recovered run and read its spec.
	en.set("current_mode", "arcade")
	var rules_data: Dictionary = Rules.load_rules()
	var run: Dictionary = Rules.build_run("arcade", {"rounds": 0, "time": 1, "difficulty": 2}, rules_data)
	en.set("run", run)
	en.call("show_next_fight")
	var spec: Dictionary = Rules.next_fight_spec(run, configs)
	var next_rows: Array = _body(en)
	check(_header(en)[0] == "NEXT FIGHT", "unmapped NEXT FIGHT title stays literal")
	check(next_rows[0] == "opponent   " + MenuLang.character(String(spec["opponent"])),
		"next-fight opponent name localized, field word literal")
	check(next_rows[2] == "Time   60 s", "next-fight time row = Time")
	check(next_rows[3] == "Difficulty   Hard (ai slot 4)", "next-fight difficulty row localized")
	check(next_rows[4] == "Your Score   0", "next-fight score row = Your Score")

	var banner_spec: Dictionary = {
		"opponent": "master", "opponent_index": 0, "opponent_count": 1,
		"score": 0, "scene_variant": "templeyardb", "time": 60,
		"difficulty_index": 2, "difficulty_slot": 4,
	}
	en.call("show_battle_banner", banner_spec)
	check(_banner(en) == "Arcade · FIGHT 1/1 · Your Score 0 · VS The Master\ntempleyardb · 60 s · Difficulty Hard",
		"arcade battle banner localized (" + _banner(en).replace("\n", " | ") + ")")
	banner_spec["time"] = 0
	en.call("show_battle_banner", banner_spec)
	check(_banner(en).contains("templeyardb · ∞ · Difficulty Hard"),
		"infinite time renders the recovered inf value (∞)")

	print("== all 10 languages ==")
	for lang_value: Variant in languages:
		var lang: String = String(lang_value)
		MenuLang.set_language(lang)
		var gm: Node = _new_gm()
		var record: Dictionary = {}
		gm.call("show_mode_menu")
		var menu: Array = _body(gm)
		check(_header(gm)[0] == MenuLang.text("game_modes"),
			"%s mode menu title localized" % lang)
		check(menu == [MenuLang.text("arcade"), MenuLang.text("survival"),
			MenuLang.text("time_attack")], "%s mode menu rows localized" % lang)
		record["mode_menu"] = _header(gm) + menu

		gm.call("open_mode", "arcade")
		var settings: Array = _body(gm)
		var expected_settings: Array = [
			"%s   < %s >" % [MenuLang.text("round_number"), "3"],
			"%s   < %s >" % [MenuLang.text("round_time"), "60"],
			"%s   < %s >" % [MenuLang.text("difficulty_level"), MenuLang.text("medium")],
			"START",
			MenuLang.text("back"),
		]
		check(_header(gm)[0] == MenuLang.text("arcade") + " · " + MenuLang.text("settings"),
			"%s arcade settings title localized" % lang)
		check(settings == expected_settings, "%s arcade settings rows localized" % lang)
		record["arcade_settings"] = _header(gm) + settings

		gm.call("open_mode", "survival")
		check(_header(gm)[0] == MenuLang.text("survival") + " · " + MenuLang.text("settings"),
			"%s survival settings title localized" % lang)
		record["survival_settings"] = _header(gm) + _body(gm)

		gm.call("open_mode", "timeattack")
		check(_header(gm)[0] == MenuLang.text("time_attack") + " · " + MenuLang.text("settings"),
			"%s time attack settings title localized" % lang)
		check(_body(gm)[3] == MenuLang.text("back"),
			"%s time attack BACK row localized" % lang)
		record["timeattack_settings"] = _header(gm) + _body(gm)

		gm.set("current_mode", "arcade")
		gm.set("run", {"mode": "arcade", "score": 450, "fights_done": 3,
			"opponent_count": 3, "difficulty_index": 2, "difficulty_slot": 4,
			"time_limit": 60, "resolved": {"rounds": 3, "score_per_fight": 150}})
		gm.set("last_result", {"outcome": "complete", "reason": ""})
		gm.call("show_results", "complete")
		var results: Array = _body(gm)
		check(results[0] == MenuLang.text("total_score") + "   450",
			"%s results score label localized" % lang)
		check(results[3] == MenuLang.text("round_number") + " / " + MenuLang.text("round_time") + "   3 · 60 s",
			"%s results rounds/time composed labels" % lang)
		check(results[6] == MenuLang.text("play") and results[8] == MenuLang.text("main_menu"),
			"%s results actions localized" % lang)
		record["arcade_results"] = _header(gm) + results

		gm.set("current_mode", "arcade")
		gm.set("run", run)
		gm.call("show_next_fight")
		record["next_fight"] = _header(gm) + _body(gm)

		gm.call("show_pause")
		check(_header(gm)[0] == MenuLang.text("pause"), "%s pause title localized" % lang)
		check(_body(gm) == [MenuLang.text("resume"), MenuLang.text("main_menu")],
			"%s pause rows localized" % lang)
		record["pause"] = _header(gm) + _body(gm)

		var banner2: Dictionary = banner_spec.duplicate(true)
		banner2["time"] = 60
		gm.call("show_battle_banner", banner2)
		check(_banner(gm).begins_with(MenuLang.text("arcade") + " · FIGHT 1/1 · " + MenuLang.text("your_score")),
			"%s battle banner mode/score labels localized" % lang)
		check(_banner(gm).ends_with("VS " + MenuLang.text("themaster") + "\ntempleyardb · 60 s · " +
			MenuLang.text("difficulty_level") + " " + MenuLang.text("hard")),
			"%s battle banner opponent/difficulty localized" % lang)
		record["battle_banner"] = _banner(gm)

		dump[lang] = record
		gm.queue_free()

	# Non-English spot checks against the decoded table (independent of the UI).
	MenuLang.set_language("LangChineseSimpl")
	check(MenuLang.text("arcade") == "街机模式", "ZH arcade = 街机模式")
	check(MenuLang.text("settings") == "设置", "ZH settings = 设置")
	check(MenuLang.text("inf") == "∞", "ZH inf = ∞")
	MenuLang.set_language("LangJapanese")
	check(MenuLang.text("time_attack") == "タイムアタック", "JA time attack = タイムアタック")
	check(MenuLang.text("medium") == "ふつう", "JA medium = ふつう")
	MenuLang.set_language("LangRussian")
	check(MenuLang.text("survival") == "Бой на выживание", "RU survival localized")

	var dump_path: String = OS.get_environment("MENU_LANG_DUMP")
	if not dump_path.is_empty():
		var f: FileAccess = FileAccess.open(dump_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(dump, "  "))
			f.close()
			print("DUMP_WRITTEN %s" % dump_path)
		else:
			check(false, "could not write MENU_LANG_DUMP")

	print("")
	print("MENU_LANG_VALIDATE " + ("OK" if fails.is_empty() else "FAILED (%d)" % fails.size()))
	for failure: Variant in fails:
		print("  FAILED: " + String(failure))
	quit(0 if fails.is_empty() else 1)

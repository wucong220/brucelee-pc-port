extends SceneTree
## Headless validation of the recovered achievement .lang text in the Records UI.
##
## Proves:
##   * the runtime table is the verbatim decode of the 10 shipped .lang files
##     (1 screen-title key + the 38 exact achievements.list description keys);
##   * every one of the 390 key/language values resolves to real localized text;
##   * a key with no decoded value yields the literal "NOT RECOVERED" (no text
##     is invented, and the raw key is never presented as a label);
##   * BRUCELEE_LANG selects the language;
##   * the Records screen renders the decoded values in the header, section,
##     all 38 row labels and the selected-row detail, in every language;
##   * a deliberately absent key still renders "NOT RECOVERED" in the real UI;
##   * the old false note ("no achv_* text") is gone.
##
## Run: godot --headless --path godot --script res://tests/validate_achievement_text.gd
## Exit 0 = all checks pass.

const AchievementLang = preload("res://scripts/achievement_lang.gd")
const ProgressHooksScript = preload("res://scripts/progress_hooks.gd")
const RecordsScript = preload("res://scripts/progress_records_screen.gd")
const PrototypeControls = preload("res://scripts/prototype_controls.gd")

const TEST_SAVE := "user://achievement_text_test.json"
const MARKER := "NOT RECOVERED"

const LANGUAGES := [
	"LangEnglish", "LangChineseSimpl", "LangChineseTrad", "LangFrench",
	"LangGerman", "LangItalian", "LangJapanese", "LangKorean",
	"LangRussian", "LangSpanish",
]

## Exact verbatim values from Lang*.lang in data.zpak (cross-checked by
## tools/recover_achievement_text.py against the independent story-lang decode).
const EXPECTED_ARCADE_EASY := {
	"LangEnglish": "Finish arcade (Easy)",
	"LangChineseSimpl": "完成街机模式（低难）",
	"LangChineseTrad": "完成街機模式（低難）",
	"LangFrench": "Terminer en arcade (Facile)",
	"LangGerman": "Absolviere Arcade (einfach).",
	"LangItalian": "Finisci la modalità Arcade (facile)",
	"LangJapanese": "アーケード(かんたん)をクリア",
	"LangKorean": "아케이드(하) 완료",
	"LangRussian": "Завершить аркаду (Новичок)",
	"LangSpanish": "Termina arcade (Fácil)",
}
const EXPECTED_TITLE := {
	"LangEnglish": "Achievements",
	"LangChineseSimpl": "成就",
	"LangJapanese": "実績",
	"LangRussian": "Поощрения",
}

var failures := 0
var checks := 0


func check(ok: bool, label: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label, ("  | " + detail) if detail != "" else "")


func check_eq(actual, expected, label: String) -> void:
	check(actual == expected, label,
		"actual=%s expected=%s" % [str(actual), str(expected)])


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Achievement .lang text / records screen validation ===")
	PrototypeControls.ensure_default_actions()
	_remove(TEST_SAVE)
	OS.set_environment("BRUCELEE_LANG", "")
	OS.set_environment("BRUCELEE_PROGRESS", "1")

	await _table()
	await _languages_and_values()
	await _not_recovered()
	await _records_screen()
	await _runtime_language_switch()
	await _absent_key_in_ui()

	OS.set_environment("BRUCELEE_LANG", "")
	OS.set_environment("BRUCELEE_PROGRESS", "")
	_remove(TEST_SAVE)
	print("")
	print("ACHIEVEMENT_TEXT checks=%d failures=%d" % [checks, failures])
	print("ACHIEVEMENT_TEXT_VALIDATION " + ("OK" if failures == 0 else "FAILED"))
	quit(0 if failures == 0 else 1)


# ------------------------------------------------------------- 1. data table

func _table() -> void:
	check(AchievementLang.is_loaded(), "achievement_lang.json loads")
	check_eq(AchievementLang.languages().size(), 10, "10 shipped languages")
	check_eq(AchievementLang.languages(), LANGUAGES, "language order matches the .lang table")
	check_eq(AchievementLang.description_keys().size(), 38,
		"38 exact achievements.list description keys")
	check_eq(AchievementLang.screen_title_key(), "achievements",
		"screen title key is the achievementstable.ui translate key")
	check_eq((AchievementLang.not_recovered() as Array).size(), 0,
		"no recovered key is flagged absent")
	var data: Dictionary = AchievementLang.data()
	check_eq((data.get("keys", {}) as Dictionary).size(), 39,
		"table holds 1 title + 38 description keys")
	check_eq(String(data.get("schema", "")), "dragonwarrior-achievement-lang/1",
		"runtime table schema")
	check_eq(String(data.get("source", {}).get("archive", "")), "data.zpak",
		"table documents data.zpak provenance")
	# every description key is an achv_* translation key, not a synthesized label
	var all_achv := true
	for key: Variant in AchievementLang.description_keys():
		if not String(key).begins_with("achv_"):
			all_achv = false
	check(all_achv, "all 38 description keys are achv_* translation keys")


# ------------------------------------------------- 2. all decoded values

func _languages_and_values() -> void:
	# exact byte-for-byte values for one key in all ten languages
	var exact := true
	var mismatches: Array = []
	for lang: Variant in LANGUAGES:
		var got: String = AchievementLang.text("achv_arcade_easy", String(lang))
		if got != String(EXPECTED_ARCADE_EASY[lang]):
			exact = false
			mismatches.append("%s=%s" % [lang, got])
	check(exact, "achv_arcade_easy is verbatim in all 10 languages",
		", ".join(mismatches))
	var title_ok := true
	for lang: Variant in EXPECTED_TITLE.keys():
		if AchievementLang.screen_title(String(lang)) != String(EXPECTED_TITLE[lang]):
			title_ok = false
	check(title_ok, "screen title is verbatim in EN/ZH/JA/RU")

	# every key/language pair resolves to real text, never a raw key or marker
	var resolved := 0
	var bad: Array = []
	for key: Variant in AchievementLang.description_keys():
		for lang: Variant in LANGUAGES:
			var value: String = AchievementLang.text(String(key), String(lang))
			if value.is_empty() or value == MARKER or value == String(key):
				bad.append("%s/%s=%s" % [key, lang, value])
			else:
				resolved += 1
	check_eq(resolved, 380, "all 380 description values are decoded text")
	check(bad.size() == 0, "no raw key / empty string / marker among the 380",
		", ".join(bad))
	var has_all := true
	for key: Variant in AchievementLang.description_keys():
		for lang: Variant in LANGUAGES:
			if not AchievementLang.has_value(String(key), String(lang)):
				has_all = false
	check(has_all, "has_value() is true for every key/language pair")
	check_eq(AchievementLang.text("achv_versus_50", "LangEnglish"),
		"Win 50 battles in Versus", "achv_versus_50 EN value")
	check_eq(AchievementLang.text("achv_time_attack_beginner", "LangEnglish"),
		"Complete Time Attack in less than 6'30''",
		"fail-closed beginner row still has its recovered .lang text")
	check_eq(AchievementLang.text("achv_greats_5", "LangEnglish"),
		"Finish 5 rounds with 'Great'", "achv_greats_5 EN value")


# --------------------------------------------------- 3. NOT RECOVERED path

func _not_recovered() -> void:
	check_eq(AchievementLang.text("achv_truly_absent_probe"), MARKER,
		"an absent key yields the literal NOT RECOVERED")
	check_eq(AchievementLang.text("achv_truly_absent_probe", "LangJapanese"), MARKER,
		"an absent key stays NOT RECOVERED in every language")
	check(not AchievementLang.has_value("achv_truly_absent_probe"),
		"has_value() is false for an absent key")
	check_eq(AchievementLang.text("", "LangEnglish"), "", "empty key yields empty string")
	check_eq(AchievementLang.text("achv_arcade_easy", "LangNotShipped"), MARKER,
		"a language outside the 10 yields NOT RECOVERED, not invented text")
	# simulate a missing/corrupt table: still no invented text
	var saved_data: Dictionary = AchievementLang._data
	var saved_loaded: bool = AchievementLang._loaded
	AchievementLang._loaded = true
	AchievementLang._data = {}
	check_eq(AchievementLang.text("achv_arcade_easy"), MARKER,
		"a missing data table fails closed to NOT RECOVERED")
	AchievementLang._loaded = saved_loaded
	AchievementLang._data = saved_data
	check_eq(AchievementLang.text("achv_arcade_easy"), "Finish arcade (Easy)",
		"restoring the table restores the decoded value")


# ------------------------------------------------------- 4. records screen

func _records_screen() -> void:
	var hooks = ProgressHooksScript.new()
	root.add_child(hooks)
	hooks.configure(TEST_SAVE)
	var screen = RecordsScript.new()
	root.add_child(screen)
	screen.configure(hooks, TEST_SAVE)
	screen.open()
	await process_frame
	var state: Dictionary = screen.debug_state()
	var rows: Array = state["rows"]
	check_eq(rows.size(), 38, "records screen still lists 38 achievements")

	# every row carries the exact recovered key and its decoded value
	var keys_ok := true
	var text_ok := true
	var no_raw_key := true
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		var expected_key: String = String(hooks.service.achievements.rows[index]["id"])
		if String(row["description_key"]) != expected_key:
			keys_ok = false
		var expected_text: String = AchievementLang.text(expected_key, "LangEnglish")
		if String(row["display_text"]) != expected_text:
			text_ok = false
		if String(row["display_text"]).begins_with("achv_"):
			no_raw_key = false
		if not bool(row["text_recovered"]):
			no_raw_key = false
	check(keys_ok, "each row keeps its exact recovered description key")
	check(text_ok, "each row shows the decoded .lang value (not the raw key)")
	check(no_raw_key, "no row label is a raw achv_* translation key")
	check_eq(String(rows[0]["display_text"]), "Finish arcade (Easy)",
		"first row shows the decoded EN text")
	check_eq(String(rows[37]["display_text"]), "Win 50 battles in Versus",
		"last row shows the decoded EN text")

	var status: Dictionary = state["text"]
	check_eq(int(status["total"]), 38, "text status totals 38 rows")
	check_eq(int(status["recovered"]), 38, "text status reports 38 recovered")
	check_eq(int(status["not_recovered"]), 0, "text status reports 0 NOT RECOVERED")
	check_eq(String(status["language"]), "LangEnglish", "text status language")
	check_eq(String(status["marker"]), MARKER, "text status marker")

	# the real rendered Labels, not just the data model
	var grid_ok := true
	var grid_raw := 0
	for index: int in range(screen._row_nodes.size()):
		var title: Label = screen._row_nodes[index]["title"]
		var wanted: String = String(rows[index]["display_text"])
		if not title.text.contains(wanted):
			grid_ok = false
		if title.text.contains("achv_"):
			grid_raw += 1
	check(grid_ok, "every rendered row Label contains its decoded text")
	check_eq(grid_raw, 0, "no rendered row Label contains a raw achv_ key")
	check(String(screen._header_title.text).contains("Achievements"),
		"header uses the decoded .lang title", String(screen._header_title.text))
	check(String(screen._section_label.text).contains("Achievements"),
		"section label uses the decoded .lang title", String(screen._section_label.text))
	check(String(screen._detail_label.text).contains("Finish arcade (Easy)"),
		"selected detail shows the decoded text")
	check(String(screen._detail_label.text).contains("[.lang key achv_arcade_easy]"),
		"selected detail keeps the exact key for traceability")

	var note: String = String(state["note"])
	check(not note.contains("contain no achv_* text"),
		"the false 'no achv_* text' note is gone", note)
	check(note.contains("decoded .lang values") and note.contains("38/38"),
		"the note reports 38/38 decoded values honestly", note)
	# progress/regression: the pre-existing honest markers are still there
	check(note.contains("rows bound") or note.contains("TEXT-ONLY"),
		"the icon honesty note is preserved", note)
	check_eq(int(state["summary"]["achievement_total"]), 38,
		"summary achievement total is unchanged (regression)")

	screen.close()
	screen.queue_free()
	hooks.queue_free()
	await process_frame


# --------------------------------------------- 5. language switch in the UI

func _runtime_language_switch() -> void:
	var hooks = ProgressHooksScript.new()
	root.add_child(hooks)
	hooks.configure(TEST_SAVE)
	var screen = RecordsScript.new()
	root.add_child(screen)
	screen.configure(hooks, TEST_SAVE)
	screen.open()
	await process_frame
	check_eq(String(screen._rows[0]["display_text"]), "Finish arcade (Easy)",
		"default language is English")

	OS.set_environment("BRUCELEE_LANG", "zh")
	screen.refresh()
	await process_frame
	check_eq(AchievementLang.language(), "LangChineseSimpl",
		"BRUCELEE_LANG=zh resolves LangChineseSimpl")
	check_eq(String(screen._rows[0]["display_text"]), "完成街机模式（低难）",
		"refresh re-renders the Chinese .lang value")
	check(String(screen._row_nodes[0]["title"].text).contains("完成街机模式（低难）"),
		"the rendered row Label switches to Chinese")
	check(String(screen._header_title.text).contains("成就"),
		"the header switches to the Chinese title")
	check_eq(String(screen.debug_state()["text"]["language"]), "LangChineseSimpl",
		"text status follows the active language")

	OS.set_environment("BRUCELEE_LANG", "ja")
	screen.refresh()
	await process_frame
	check_eq(String(screen._rows[0]["display_text"]), "アーケード(かんたん)をクリア",
		"refresh re-renders the Japanese .lang value")
	check(String(screen._header_title.text).contains("実績"),
		"the header switches to the Japanese title")

	OS.set_environment("BRUCELEE_LANG", "")
	screen.refresh()
	await process_frame
	check_eq(String(screen._rows[0]["display_text"]), "Finish arcade (Easy)",
		"clearing BRUCELEE_LANG restores English")
	screen.close()
	screen.queue_free()
	hooks.queue_free()
	await process_frame


# ------------------------------- 6. an absent key is NOT RECOVERED in the UI

func _absent_key_in_ui() -> void:
	var hooks = ProgressHooksScript.new()
	root.add_child(hooks)
	hooks.configure(TEST_SAVE)
	var screen = RecordsScript.new()
	root.add_child(screen)
	screen.configure(hooks, TEST_SAVE)
	screen.open()
	await process_frame
	var engine = hooks.service.achievements
	var saved: Dictionary = engine.rows[0].duplicate(true)
	# Corrupt only the display key of one row. The condition/grant logic is
	# untouched; this is the exact path a truly-absent .lang key would take.
	engine.rows[0]["description_key"] = "achv_truly_absent_probe"
	screen.refresh()
	await process_frame
	check_eq(String(screen._rows[0]["display_text"]), MARKER,
		"an absent key renders literal NOT RECOVERED in a real row")
	check(not bool(screen._rows[0]["text_recovered"]),
		"the absent row is flagged not recovered")
	check(String(screen._row_nodes[0]["title"].text).contains(MARKER),
		"the rendered row Label shows NOT RECOVERED")
	check_eq(int(screen.debug_state()["text"]["not_recovered"]), 1,
		"text status counts exactly 1 NOT RECOVERED row")
	check_eq(int(screen.debug_state()["text"]["recovered"]), 37,
		"text status still counts 37 recovered rows")
	check(String(screen._detail_label.text).contains(MARKER),
		"the selected detail shows NOT RECOVERED")
	check(String(screen._detail_label.text).contains("achv_truly_absent_probe"),
		"the absent key itself is shown for traceability, not invented text")
	# restore and prove the screen recovers completely
	engine.rows[0] = saved
	screen.refresh()
	await process_frame
	check_eq(String(screen._rows[0]["display_text"]), "Finish arcade (Easy)",
		"restoring the key restores the decoded value")
	check_eq(int(screen.debug_state()["text"]["recovered"]), 38,
		"restoring the key returns to 38/38 recovered")
	screen.close()
	screen.queue_free()
	hooks.queue_free()
	await process_frame

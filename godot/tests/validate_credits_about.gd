extends SceneTree
## Headless validation of the two recovered UI unknowns:
##   * About `gamemodes.gameversion` -> "1.15.26" (native binary evidence)
##   * CCreditsView roll cadence/initial offset/end condition
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_credits_about.gd

const RecoveredPages = preload("res://scripts/recovered_pages.gd")
const PortCreditsRoll = preload("res://scripts/credits_roll.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, desc: String) -> bool:
	if cond:
		passed += 1
		print("PASS " + desc)
	else:
		failed += 1
		printerr("FAIL " + desc)
	return cond


func _finish() -> void:
	print("CREDITS_ABOUT_VALIDATION=" + JSON.stringify(
		{"passed": passed, "failed": failed}))
	quit(1 if failed > 0 else 0)


func _credits_height(path: String) -> int:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return -1
	for node: Variant in Array(Dictionary(parsed).get("layout", [])):
		var d: Dictionary = node as Dictionary
		if String(d.get("type", "")) == "credits":
			return int(d.get("height", -1))
	return -1


func _run() -> void:
	# --- About version ---------------------------------------------------
	_check(RecoveredPages.available(), "recovered-pages artifact loads")
	_check(RecoveredPages.error() == "", "recovered-pages artifact has no error")
	_check(RecoveredPages.about_version_text("LangEnglish")
		== "Bruce Lee Dragon Warrior 1.15.26",
		"English about version = recovered 1.15.26")
	_check(RecoveredPages.about_version_text("LangChineseSimpl").ends_with("1.15.26"),
		"Chinese about version keeps the recovered 1.15.26 substitution")
	_check(RecoveredPages.about_version_text("LangFrench")
		== "Bruce Lee Dragon Warrior 1.15.26",
		"French about version = recovered 1.15.26")
	_check(RecoveredPages.about_version_text("LangUnknown")
		== "Bruce Lee Dragon Warrior 1.15.26",
		"unknown language falls back to the English template with 1.15.26")

	# --- credits evidence record ----------------------------------------
	var scroll: Dictionary = RecoveredPages.credits_scroll()
	_check(int(scroll.get("tick_ms", 0)) == 33, "credits tick = 33 ms")
	_check(int(scroll.get("gate_ms", 0)) == 32, "credits gate = 32 ms")
	_check(int(scroll.get("max_backlog_ms", 0)) == 198, "credits backlog clamp = 198 ms")
	_check(int(scroll.get("view_height_px", 0)) == 320, "credits view height = 320")
	_check(int(scroll.get("initial_offset_px", 0)) == -320,
		"credits initial offset = -height = -320")
	_check(String(scroll.get("end_action", "")) == "END",
		"credits end action = recovered END")
	_check(_credits_height("res://data/menu_art/ui/creditsdle.json") == 320,
		"creditsdle credits widget height = 320")
	_check(_credits_height("res://data/menu_art/ui/creditsindiagames.json") == 320,
		"creditsindiagames credits widget height = 320")

	# --- per-tick delta +2,+1,+2,+1 -------------------------------------
	var r: PortCreditsRoll = PortCreditsRoll.new(PackedInt32Array([40, 40, 40]), 320)
	_check(r.offset == -320, "roll starts at -view_height")
	var seq: Array[int] = []
	for _i: int in range(5):
		r.tick()
		seq.append(r.offset)
	_check(seq == [-318, -317, -315, -314, -312],
		"tick offsets follow +2,+1,+2,+1 from a zero-initialised flip byte")

	# --- 33 ms fixed-step dispatch --------------------------------------
	var r2: PortCreditsRoll = PortCreditsRoll.new(PackedInt32Array([40, 40, 40]), 320)
	_check(r2.advance_ms(1000) == 0, "first Update only seeds the 33 ms clock")
	_check(r2.advance_ms(1032) == 0, "32 ms after seed is still gated")
	_check(r2.advance_ms(1033) == 1, "33 ms after seed fires exactly one tick")
	_check(r2.advance_ms(1100) == 2, "a 67 ms jump catches up two ticks")

	var r3: PortCreditsRoll = PortCreditsRoll.new(PackedInt32Array([40, 40, 40]), 320)
	r3.advance_ms(0)
	var t: int = 0
	for _i: int in range(20):
		t += 33
		r3.advance_ms(t)
	_check(r3.tick_count == 20, "twenty 33 ms frames produce twenty ticks")

	var r4: PortCreditsRoll = PortCreditsRoll.new(PackedInt32Array([40, 40, 40]), 320)
	r4.advance_ms(1000)
	_check(r4.advance_ms(5000) == 6, "198 ms backlog clamp yields at most six ticks")

	# --- end condition ---------------------------------------------------
	var r5: PortCreditsRoll = PortCreditsRoll.new(PackedInt32Array([10]), 320)
	var guard: int = 0
	while not r5.ended and guard < 1000:
		r5.tick()
		guard += 1
	_check(r5.ended, "roll ends when the last line passes the viewport")
	_check(r5.offset == 10, "end offset equals total content height (10)")
	_check(r5.end_action() == "END", "end action is the recovered END")
	_check(PortCreditsRoll.new(PackedInt32Array(), 320).ended,
		"zero-line roll ends immediately like Redraw")

	_finish()

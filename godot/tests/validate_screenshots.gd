extends SceneTree
## Pixel-level check of the captured screenshots: every PNG must be 1280x720,
## must not be blank, and must contain a meaningful number of non-background
## pixels (i.e. rendered text / HUD / scene).
##
##   godot --headless --path godot --script res://tests/validate_screenshots.gd -- <shots dir>
##
## The set of REQUIRED file names is enforced by tools/validate.py; this test
## proves the pixels are real.

var shots: String = ""
var fails: Array = []


func _initialize() -> void:
	call_deferred("_run")


func check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails.append(msg)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	shots = String(args[0]) if args.size() > 0 else ""
	if shots.is_empty():
		check(false, "screenshot directory argument missing")
		quit(1)
		return
	var dir: DirAccess = DirAccess.open(shots)
	if dir == null:
		check(false, "cannot open screenshot directory " + shots)
		quit(1)
		return
	var files: Array = []
	for name: String in dir.get_files():
		if name.to_lower().ends_with(".png"):
			files.append(name)
	files.sort()
	check(files.size() >= 54, "at least 54 screenshots present (got %d)" % files.size())

	var total_nonbg := 0
	for name: String in files:
		var path: String = shots.path_join(name)
		var image: Image = Image.new()
		var error: int = image.load(path)
		if error != OK:
			check(false, "%s loads (err=%d)" % [name, error])
			continue
		var width: int = image.get_width()
		var height: int = image.get_height()
		check(width == 1280 and height == 720, "%s is 1280x720 (got %dx%d)" % [name, width, height])
		var background: int = image.get_pixel(0, 0).to_rgba32()
		var nonbg: int = 0
		var colors: Dictionary = {}
		for y: int in range(0, height, 4):
			for x: int in range(0, width, 4):
				var color: Color = image.get_pixel(x, y)
				var packed: int = color.to_rgba32()
				if packed != background:
					nonbg += 1
				colors[packed] = true
		total_nonbg += nonbg
		check(nonbg > 200, "%s is not blank (non-background samples=%d)" % [name, nonbg])
		check(colors.size() > 20, "%s has rendered detail (%d sampled colours)" % [name, colors.size()])
		print("  %s nonbg=%d colours=%d" % [name, nonbg, colors.size()])
	check(total_nonbg > 20000, "the screenshot set is not uniformly blank")
	print("")
	print("SCREENSHOT_VALIDATE " + ("OK" if fails.is_empty() else "FAILED (%d)" % fails.size()))
	for failure: Variant in fails:
		print("  FAILED: " + String(failure))
	quit(0 if fails.is_empty() else 1)

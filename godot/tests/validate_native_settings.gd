extends SceneTree
## Headless validation of the recovered native settings format and its runtime
## persistence binding (replaces the old PORT json binding).
##
## Usage:
##   godot --headless --path <project> --script res://tests/validate_native_settings.gd -- \
##         <save-path> <mode> [fixture paths...]
##
## Modes:
##   codec     decode->encode each real extracted resource and require the bytes
##             to be identical (proves the codec is the native encoder).
##   session   build/write the native settings.dat and assert it reads back.
##   restart   a separate process: assert the saved native file restores the
##             language before any menu is built.
##   failclosed verify an unparseable settings.dat is never read as a language
##             and is never overwritten.

const Store = preload("res://scripts/native_settings_store.gd")
const LanguageDock = preload("res://scripts/language_dock.gd")

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


func _finish(mode: String) -> void:
	print("NATIVE_SETTINGS_VALIDATION=" + JSON.stringify({"mode": mode, "passed": passed, "failed": failed}))
	quit(1 if failed > 0 else 0)


func _read_all(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var b: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return b


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Expected <save-path> <mode> [fixtures...]")
		quit(1)
		return
	var save_path: String = args[0]
	var mode: String = args[1]
	OS.set_environment("BRUCELEE_LANGUAGE_SAVE_PATH", save_path)
	OS.set_environment("BRUCELEE_LANG", "")
	match mode:
		"codec":
			_check(FileAccess.file_exists(save_path), "settings.dat written by session mode exists")
			_check(LanguageDock.load_saved_index() == 6, "saved language index is 6")
			_check_native_bytes(save_path)
			for i: int in range(2, args.size()):
				_check_fixture(args[i])
		"session":
			_check_dock_artifact()
			if FileAccess.file_exists(save_path):
				DirAccess.remove_absolute(save_path)
			# Explicit legacy PORT migration: with no native file, the old JSON is
			# read once; the port must then write native and never touch the JSON.
			DirAccess.remove_absolute("user://ui_gaps_language.json")
			var lf := FileAccess.open("user://ui_gaps_language.json", FileAccess.WRITE)
			lf.store_string(JSON.stringify({"language_index": 3, "lang_table": "LangItalian"}))
			lf.close()
			_check(LanguageDock.load_saved_index() == 3, "legacy PORT json is read as an explicit migration")
			_check(LanguageDock.current_source() == "legacy_port_migration", "migration source is reported explicitly")
			DirAccess.remove_absolute("user://ui_gaps_language.json")
			_check(LanguageDock.save_index(6), "write native settings.dat for index 6: " + LanguageDock.path_used())
			_check(not FileAccess.file_exists("user://ui_gaps_language.json"), "the legacy PORT json is NOT rewritten")
			_check(FileAccess.file_exists(save_path), "settings.dat now exists")
			_check_native_bytes(save_path)
			_check(LanguageDock.load_saved_index() == 6, "read back index 6 from native settings.dat")
			_check(LanguageDock.current_index() == 6, "current_index() is the saved native index")
			var bytes: PackedByteArray = _read_all(save_path)
			_check(bytes.size() > 32, "native file is non-trivial (%d bytes)" % bytes.size())
			_check(bytes.slice(0, 12).get_string_from_ascii() == "1FDKENONCTX3", "file starts with the native 1FDKENONCTX3 signature")
			var info: Dictionary = Store.inspect(save_path)
			_check(String(info.get("error", "x")) == "", "inspect() parses without error: " + String(info.get("error", "")))
			_check(int(info.get("language", -1)) == 6, "inspect() reports language 6")
			_check(int(info.get("records", 0)) > 0, "inspect() sees records")
			# Prove the dock's in-memory payload equals what the store writes.
			_check(LanguageDock.save_bytes(6) == bytes, "dock save_bytes(6) equals the on-disk native bytes")
		"restart":
			_check(FileAccess.file_exists(save_path), "native settings.dat survived the restart")
			_check(LanguageDock.load_saved_index() == 6, "restarted process reads index 6 from native settings.dat")
			_check(LanguageDock.current_index() == 6, "restarted process current_index() is 6")
			_check(LanguageDock.current_source() == "native", "restarted process treats the value as a native save")
			_check(LanguageDock.lang_table_for_index(6) == "LangChineseSimpl", "index 6 still maps to LangChineseSimpl")
		"failclosed":
			var garbage := PackedByteArray()
			garbage.append_array("NOT-A-NATIVE-RESOURCE".to_ascii_buffer())
			var f := FileAccess.open(save_path, FileAccess.WRITE)
			f.store_buffer(garbage)
			f.close()
			_check(LanguageDock.load_saved_index() == -1, "garbage settings.dat does not yield a language")
			# Even with a valid legacy JSON present, an unparseable native file is a
			# hard failure: no silent fallback to the PORT binding.
			var lf2 := FileAccess.open("user://ui_gaps_language.json", FileAccess.WRITE)
			lf2.store_string(JSON.stringify({"language_index": 2, "lang_table": "LangGerman"}))
			lf2.close()
			_check(LanguageDock.load_saved_index() == -1, "unparseable native file does NOT silently fall back to the legacy json")
			DirAccess.remove_absolute("user://ui_gaps_language.json")
			_check(not LanguageDock.save_index(6), "save refuses to overwrite an unparseable settings.dat")
			_check(_read_all(save_path) == garbage, "the unparseable file is left byte-identical (fail closed)")
		_:
			printerr("unknown mode " + mode)
			failed += 1
	_finish(mode)


func _check_dock_artifact() -> void:
	_check(LanguageDock.available(), "language dock artifact still loads")
	_check(LanguageDock.native_format_status() == "RECOVERED", "native settings format is RECOVERED")
	_check(LanguageDock.native_file_name() == "settings.dat", "native file name is settings.dat")
	var p: Dictionary = LanguageDock.persistence()
	_check(String(p.get("signature", "")) == "1FDKENONCTX3", "persistence reports the 1FDKENONCTX3 container")


func _check_native_bytes(path: String) -> void:
	var bytes: PackedByteArray = _read_all(path)
	_check(bytes.size() > 0, "native file readable")
	if bytes.size() < 32:
		return
	_check(bytes.slice(0, 12).get_string_from_ascii() == "1FDKENONCTX3", "native signature present")
	var info: Dictionary = Store.inspect(path)
	_check(String(info.get("error", "x")) == "", "native container verifies (MD5/table): " + String(info.get("error", "")))


func _check_fixture(path: String) -> void:
	var bytes: PackedByteArray = _read_all(path)
	if bytes.is_empty():
		_check(false, "fixture readable: " + path)
		return
	var tree: Dictionary = Store.decode(bytes)
	if not _check(not tree.is_empty(), "decode real fixture " + path.get_file()):
		return
	var reencoded: PackedByteArray = Store.encode(tree)
	_check(reencoded == bytes, "re-encode is byte-identical for real native resource " + path.get_file())

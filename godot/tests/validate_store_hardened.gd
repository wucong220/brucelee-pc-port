extends SceneTree
## Headless acceptance for the hardened native settings store.
## Run:
##   godot --headless --path <project> --script res://tests/validate_store_hardened.gd -- <run-dir>

const Store = preload("res://scripts/native_settings_store.gd")

var passed: int = 0
var failed: int = 0
var fixtures: String
var work: String


func _init() -> void:
	fixtures = "res://fixtures"
	work = "user://work"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(work))
	print("WORK_DIR=", ProjectSettings.globalize_path(work))

	_test_unknown_provider_preserved()
	_test_unknown_option_cell_preserved()
	_test_option_missing_fails_closed()
	_test_language_missing_fails_closed()
	_test_corrupt_fails_closed()
	_test_invalid_index_fails_closed()
	_test_new_file()
	_test_int_language_in_place()
	_test_read_with_unknown_provider()
	_test_full_provider_tree_preserved()
	_test_prior_614_sample()

	print("STORE_HARDENED passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS " + label)
	else:
		failed += 1
		print("FAIL " + label)


func _read(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var b: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return b


func _copy_fixture(name: String) -> String:
	var dst := work.path_join(name)
	var b := _read(fixtures.path_join(name))
	var f := FileAccess.open(dst, FileAccess.WRITE)
	f.store_buffer(b)
	f.close()
	return dst


func _changed(a: PackedByteArray, b: PackedByteArray) -> Array:
	var out: Array = []
	if a.size() != b.size():
		return [-1]
	for i: int in range(a.size()):
		if a[i] != b[i]:
			out.append(i)
	return out


func _body_changes(a: PackedByteArray, b: PackedByteArray) -> Array:
	## Exclude the 16-byte MD5 tail; the body must change only at the language cell.
	var out: Array = []
	for i: int in _changed(a, b):
		if i >= 0 and i < a.size() - 16:
			out.append(i)
	return out


func _language_offsets(raw: PackedByteArray) -> Dictionary:
	var doc: Dictionary = Store._parse(raw)
	var found: Dictionary = Store._find_option_language(doc)
	if found.is_empty():
		return {}
	var second_at: int = int(found["rec_start"]) + int(found["language_idx"]) * 8 + 4
	return {"desc": second_at - 4, "second": second_at, "tag": int(found["tag"])}


func _expect_only_language_write(label: String, before: PackedByteArray, after: PackedByteArray,
		new_index: int, int_tag: bool = false) -> void:
	var offs: Dictionary = _language_offsets(before)
	_check(not offs.is_empty(), label + ": fixture layout")
	if offs.is_empty():
		return
	var allowed: Array = []
	for i: int in range(4):
		allowed.append(int(offs["second"]) + i)
	if int_tag:
		for i: int in range(4):
			allowed.append(int(offs["desc"]) + i)
	allowed.sort()
	var actual: Array = _body_changes(before, after)
	actual.sort()
	var outside: Array = []
	for i: int in actual:
		if not allowed.has(i):
			outside.append(i)
	_check(outside.is_empty(), label + ": no bytes outside the language cell changed")
	_check(not actual.is_empty(), label + ": language value actually changed")
	_check(after.size() == before.size(), label + ": size preserved")
	_check(Store.language_from_bytes(after) == new_index, label + ": new language reads back")


func _test_unknown_provider_preserved() -> void:
	var path := _copy_fixture("with_unknown_provider.dat")
	var before := _read(path)
	_check(Store.language_from_bytes(before) == 6, "unknown provider: initial language 6")
	_check(Store.write_language(path, 4), "unknown provider: language write succeeds")
	var after := _read(path)
	_expect_only_language_write("unknown provider", before, after, 4)
	_check(Store.last_error() == "", "unknown provider: no error")


func _test_unknown_option_cell_preserved() -> void:
	var path := _copy_fixture("unknown_cell_in_option.dat")
	var before := _read(path)
	_check(Store.write_language(path, 3), "unknown option cell: write succeeds")
	var after := _read(path)
	_expect_only_language_write("unknown option cell", before, after, 3)


func _test_option_missing_fails_closed() -> void:
	var path := _copy_fixture("option_missing.dat")
	var before := _read(path)
	_check(not Store.write_language(path, 4), "option missing: write refused")
	_check(Store.last_error().contains("option"), "option missing: explicit error")
	_check(_read(path) == before, "option missing: file unchanged")


func _test_language_missing_fails_closed() -> void:
	var path := _copy_fixture("language_missing.dat")
	var before := _read(path)
	_check(not Store.write_language(path, 4), "language missing: write refused")
	_check(Store.last_error().contains("language"), "language missing: explicit error")
	_check(_read(path) == before, "language missing: file unchanged")


func _test_corrupt_fails_closed() -> void:
	var path := _copy_fixture("corrupt.dat")
	var before := _read(path)
	_check(not Store.write_language(path, 4), "corrupt: write refused")
	_check(Store.last_error().contains("unparseable") or Store.last_error().contains("MD5"),
			"corrupt: parse error reported")
	_check(_read(path) == before, "corrupt: file unchanged")


func _test_invalid_index_fails_closed() -> void:
	var path := _copy_fixture("valid_plain.dat")
	var before := _read(path)
	_check(not Store.write_language(path, 8), "invalid index: write refused")
	_check(_read(path) == before, "invalid index: file unchanged")


func _test_new_file() -> void:
	var path := work.path_join("fresh_settings.dat")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_check(Store.write_language(path, 5), "new file: write succeeds")
	_check(FileAccess.file_exists(path), "new file: exists")
	_check(Store.read_language(path) == 5, "new file: language reads back")
	var doc: Dictionary = Store._parse(_read(path))
	_check(not doc.is_empty(), "new file: container parses")
	_check(not Store._find_option_language(doc).is_empty(), "new file: option/language present")


func _test_int_language_in_place() -> void:
	var path := _copy_fixture("int_language.dat")
	var before := _read(path)
	_check(Store.language_from_bytes(before) == 6, "int language: initial language 6")
	_check(Store.write_language(path, 2), "int language: write succeeds")
	var after := _read(path)
	_expect_only_language_write("int language", before, after, 2, true)


func _test_read_with_unknown_provider() -> void:
	var path := _copy_fixture("with_unknown_provider.dat")
	_check(Store.read_language(path) == 6, "read: unknown provider does not block language")


func _test_full_provider_tree_preserved() -> void:
	var path := _copy_fixture("full_provider_tree.dat")
	var before := _read(path)
	_check(Store.write_language(path, 1), "full provider tree: write succeeds")
	var after := _read(path)
	_expect_only_language_write("full provider tree", before, after, 1)


func _test_prior_614_sample() -> void:
	var path := _copy_fixture("sample_614.dat")
	var before := _read(path)
	_check(before.size() == 614, "prior sample: 614 bytes")
	_check(Store.language_from_bytes(before) == 6, "prior sample: initial language 6")
	_check(Store.write_language(path, 7), "prior sample: write succeeds")
	var after := _read(path)
	_expect_only_language_write("prior sample", before, after, 7)

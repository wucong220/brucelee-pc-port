extends SceneTree
## Isolated smoke test for PortNativeProgressStore (not the main.tscn test).

const NativeStore = preload("res://scripts/native_settings_store.gd")
const NativeProgressStore = preload("res://scripts/native_progress_store.gd")
const ProgressHooksScript = preload("res://scripts/progress_hooks.gd")

const DIR := "user://native_provider_store_test"
const NATIVE := "user://native_provider_store_test/settings.dat"
const JSON1 := "user://native_provider_store_test/p1.json"
const JSON2 := "user://native_provider_store_test/p2.json"

var checks := 0
var failures := 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label, "  ", detail)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _read(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	var b: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return b


func _write(path: String, b: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(b)
	f.close()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_remove(NATIVE)
	_remove(JSON1)
	_remove(JSON2)

	var p = ProgressHooksScript.new()
	p.configure(JSON1, NATIVE)
	_check(p.native_ok, "initial native configure ok", p.native_error)
	_check(FileAccess.file_exists(NATIVE), "initial native file created")
	var flags: Dictionary = p.native_store.read_flags()
	_check(flags.get("Unlocker.unlocked", []).size() == 117, "unlocked array 117")
	_check(flags.get("Unlocker.achievements", []).size() == 38, "achievements array 38")
	_check(flags.get("Unlocker.art_pictures", []).size() == 18, "art_pictures array 18")
	_check(flags.get("CharacterList.available", []).size() == 15, "characters available 15")
	_check(flags.get("CharacterList.profile_available", []).size() == 10, "profiles 10")
	_check(flags.get("SceneryList.available", []).size() == 10, "sceneries 10")
	_check(flags["Unlocker.art_pictures"][0] == 1 and flags["Unlocker.art_pictures"][1] == 1,
			"art defaults 0/1")
	_check(flags["CharacterList.available"][2] == 1 and flags["CharacterList.available"][4] == 1,
			"character defaults 2/4")
	_check(flags["CharacterList.profile_available"][0] == 1, "profile default 0")
	_check(flags["SceneryList.available"][0] == 1, "scenery default 0")

	# Mutate runtime state, then persist through native + JSON.
	p.service.state["unlocks"]["unlocked_ids"] = [7, 17, 40, 84, 90, 108]
	var ach_id: String = String(p.service.achievements.rows[0]["id"])
	p.service.state["achievements"]["reached"] = [ach_id]
	p.service.state["counters"]["number_of_perfects"] = 3
	_check(p.flush(), "flush native+json", p.native_error)
	flags = p.native_store.read_flags()
	for id in [7, 17, 40, 84, 90, 108]:
		_check(flags["Unlocker.unlocked"][id] == 1, "unlocked flag %d" % id)
	_check(flags["CharacterList.available"][7] == 1, "character flag item 7")
	_check(flags["CharacterList.profile_available"][1] == 1, "profile flag item 1")
	_check(flags["SceneryList.available"][3] == 1, "scenery flag item 3")
	_check(flags["Unlocker.art_pictures"][15] == 1, "art flag item 15")
	_check(flags["Unlocker.achievements"][0] == 1, "achievement flag 0")
	_check(absf(float(flags["Stats.data"].get("number_of_perfects", -1)) - 3.0) < 0.0001,
			"stats perfect count 3")

	# Native-only restart (delete JSON).
	_remove(JSON1)
	var p2 = ProgressHooksScript.new()
	p2.configure(JSON2, NATIVE)
	_check(p2.native_ok, "restart native configure ok", p2.native_error)
	_check(p2.service.unlocked_ids() == [7, 17, 40, 84, 90, 108],
			"restart restores unlocked ids", str(p2.service.unlocked_ids()))
	_check(p2.service.state["achievements"]["reached"].has(ach_id), "restart restores achievement")
	_check(int(p2.service.state["counters"].get("number_of_perfects", -1)) == 3,
			"restart restores native stat")

	# Unknown provider must survive an in-place save.
	var bytes: PackedByteArray = _read(NATIVE)
	var tree: Dictionary = NativeStore.decode(bytes)
	var mystery := {"k": "dict", "items": [
		[{"k": "str", "v": "blob"}, {"k": "array", "items": [
			{"k": "int", "v": 9}, {"k": "int", "v": 8}]}],
		[{"k": "str", "v": "label"}, {"k": "str", "v": "keep-me"}],
	]}
	(tree["items"] as Array).append([{"k": "str", "v": "MysteryProvider"}, mystery])
	_write(NATIVE, NativeStore.encode(tree))
	var before_unknown: Variant = _find_provider(NativeStore.decode(_read(NATIVE)), "MysteryProvider")
	var p3 = ProgressHooksScript.new()
	p3.configure("user://native_provider_store_test/p3.json", NATIVE)
	_check(p3.native_ok, "unknown provider configure ok", p3.native_error)
	p3.service.state["counters"]["number_of_perfects"] = 5
	_check(p3.flush(), "unknown provider save ok", p3.native_error)
	var after_unknown: Variant = _find_provider(NativeStore.decode(_read(NATIVE)), "MysteryProvider")
	_check(before_unknown == after_unknown, "unknown provider preserved")

	# Corrupt file fails closed.
	var corrupt := "user://native_provider_store_test/corrupt.dat"
	_write(corrupt, bytes.slice(0, bytes.size() - 1) + PackedByteArray([bytes[bytes.size() - 1] ^ 1]))
	var p4 = ProgressHooksScript.new()
	p4.configure("user://native_provider_store_test/p4.json", corrupt)
	_check(not p4.native_ok, "corrupt native file fails closed", p4.native_error)

	# Missing providers even without unknown providers fail closed.
	var plain_missing := {"k": "dict", "items": [
		[{"k": "str", "v": "option"}, NativeStore.default_option_tree(0)],
		[{"k": "str", "v": "version"}, NativeStore._float_node(NativeStore.CODE_VERSION)],
	]}
	var plain_missing_path := "user://native_provider_store_test/plain_missing.dat"
	_write(plain_missing_path, NativeStore.encode(plain_missing))
	var p6 = ProgressHooksScript.new()
	p6.configure("user://native_provider_store_test/p6.json", plain_missing_path)
	_check(not p6.native_ok, "missing providers fail closed", p6.native_error)

	# Missing providers with an unknown provider present fails closed.
	var option_only := {"k": "dict", "items": [
		[{"k": "str", "v": "option"}, NativeStore.default_option_tree(0)],
		[{"k": "str", "v": "MysteryProvider"}, mystery],
		[{"k": "str", "v": "version"}, NativeStore._float_node(NativeStore.CODE_VERSION)],
	]}
	var missing := "user://native_provider_store_test/missing.dat"
	_write(missing, NativeStore.encode(option_only))
	var p5 = ProgressHooksScript.new()
	p5.configure("user://native_provider_store_test/p5.json", missing)
	_check(not p5.native_ok, "missing providers + unknown fails closed", p5.native_error)

	_remove(NATIVE); _remove(JSON1); _remove(JSON2)
	_remove("user://native_provider_store_test/p3.json")
	_remove("user://native_provider_store_test/p4.json")
	_remove("user://native_provider_store_test/p5.json")
	_remove("user://native_provider_store_test/p6.json")
	_remove(plain_missing_path)
	_remove(corrupt); _remove(missing)
	p.free(); p2.free(); p3.free(); p4.free(); p5.free(); p6.free()

	print("=== NATIVE STORE RESULT: %d checks, %d failures ===" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _find_provider(tree: Dictionary, name: String) -> Variant:
	for pair: Variant in (tree.get("items", []) as Array):
		var p: Array = pair
		var key: Dictionary = p[0]
		if String(key.get("k", "")) == "str" and String(key.get("v", "")) == name:
			return p[1]
	return null

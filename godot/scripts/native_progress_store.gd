extends RefCounted
class_name PortNativeProgressStore
## Bridges the recovered native settings.dat providers to ProgressService.
##
## Cell layout and defaults come from the decoded resources and serializers:
##   Unlocker.unlocked[117], achievements[38], art_pictures[18]
##   CharacterList.available[15], profile_available[10]
##   SceneryList.available[10]
##   Stats.data: float dictionary (only recovered TReal keys; INCOMPLETE)
##
## Existing native files are updated by patching only the known provider cells;
## unknown providers/cells remain byte-identical.  A missing provider/cell or a
## corrupt container makes save/load fail closed instead of guessing.

const NativeStore = preload("res://scripts/native_settings_store.gd")
const CONFIG_PATH := "res://data/progress/native_providers.json"
const DEFAULT_PATH := "user://settings.dat"
const KNOWN_OPTION_KEYS := [
	"HUD", "input_layout", "input_gui_alpha", "sound_volume", "music_volume",
	"arcade_time", "versus_time", "survival_time", "camera_tilt", "language",
	"variable_mainmenu_selectedoption", "variable_playmenu_selectedoption",
]

var path: String = DEFAULT_PATH
var config: Dictionary = {}
var error: String = ""
var ready := false


func configure(save_path: String = "") -> bool:
	path = save_path if not save_path.is_empty() else DEFAULT_PATH
	error = ""
	ready = false
	if not FileAccess.file_exists(CONFIG_PATH):
		error = "native provider config missing: " + CONFIG_PATH
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		error = "native provider config is not an object"
		return false
	config = parsed
	if not _validate_config():
		return false
	ready = true
	return true


func is_ready() -> bool:
	return ready


func _validate_config() -> bool:
	if String(config.get("schema", "")) != "dragonwarrior-native-providers/1":
		error = "native provider config schema mismatch"
		return false
	var providers: Variant = config.get("providers", {})
	var defaults: Variant = config.get("defaults", {})
	var item_type: Variant = config.get("item_type", {})
	var stats: Variant = config.get("stats", {})
	if typeof(providers) != TYPE_DICTIONARY or typeof(defaults) != TYPE_DICTIONARY \
			or typeof(item_type) != TYPE_DICTIONARY or typeof(stats) != TYPE_DICTIONARY:
		error = "native provider config sections missing"
		return false
	for provider_value: Variant in (providers as Dictionary).keys():
		var provider: String = String(provider_value)
		var cells: Variant = (providers as Dictionary)[provider]
		if typeof(cells) != TYPE_DICTIONARY:
			error = "provider cells are not an object: " + provider
			return false
		for cell_value: Variant in (cells as Dictionary).keys():
			var cell: String = String(cell_value)
			var count_value: Variant = (cells as Dictionary)[cell]
			if provider == "Stats" and cell == "data":
				continue
			if typeof(count_value) != TYPE_INT and typeof(count_value) != TYPE_FLOAT:
				error = "invalid native count: %s.%s" % [provider, cell]
				return false
			if int(count_value) <= 0:
				error = "invalid native count: %s.%s" % [provider, cell]
				return false
	for key_value: Variant in (defaults as Dictionary).keys():
		var key: String = String(key_value)
		var arr: Variant = (defaults as Dictionary)[key]
		if typeof(arr) != TYPE_ARRAY:
			error = "native defaults are not arrays: " + key
			return false
		var count := _cell_count(key)
		if count < 0 or (arr as Array).size() != count:
			error = "native defaults length mismatch: " + key
			return false
	for type_value: Variant in (item_type as Dictionary).keys():
		var type_name: String = String(type_value)
		var entry: Variant = (item_type as Dictionary)[type_name]
		if typeof(entry) != TYPE_DICTIONARY:
			error = "item_type entry is not an object: " + type_name
			return false
		var provider := String((entry as Dictionary).get("provider", ""))
		var cell := String((entry as Dictionary).get("cell", ""))
		if _cell_count(provider + "." + cell) < 0:
			error = "item_type references unknown cell: " + type_name
			return false
	var keys: Variant = (stats as Dictionary).get("keys", [])
	if typeof(keys) != TYPE_ARRAY:
		error = "stats keys missing"
		return false
	return true


func _cell_count(cell_key: String) -> int:
	var parts := cell_key.split(".")
	if parts.size() != 2:
		return -1
	var providers: Dictionary = config.get("providers", {})
	if not providers.has(parts[0]):
		return -1
	var cells: Variant = providers[parts[0]]
	if typeof(cells) != TYPE_DICTIONARY or not (cells as Dictionary).has(parts[1]):
		return -1
	var value: Variant = (cells as Dictionary)[parts[1]]
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return -1


func _known_provider_names() -> Dictionary:
	var out: Dictionary = {}
	for name: String in ["option", "version", "Unlocker", "CharacterList", "SceneryList", "Stats"]:
		out[name] = true
	return out


func _provider_cell_specs() -> Array:
	var out: Array = []
	var providers: Dictionary = config.get("providers", {})
	for provider_value: Variant in providers.keys():
		var provider: String = String(provider_value)
		if provider == "Stats":
			continue
		var cells: Dictionary = providers[provider]
		for cell_value: Variant in cells.keys():
			out.append({"provider": provider, "cell": String(cell_value),
					"count": int(cells[cell_value])})
	return out


func _read_file() -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return bytes


func _write_file(bytes: PackedByteArray) -> bool:
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		error = "cannot write native settings.dat"
		return false
	out.store_buffer(bytes)
	out.close()
	return true


func _unknown_provider_present(names: Array) -> bool:
	var known := _known_provider_names()
	for name_value: Variant in names:
		if not known.has(String(name_value)):
			return true
	return false


func _missing_required(names: Array) -> Array:
	var missing: Array = []
	for spec: Dictionary in _provider_cell_specs():
		if not names.has(String(spec["provider"])) and not missing.has(String(spec["provider"])):
			missing.append(String(spec["provider"]))
	if not names.has("Stats"):
		missing.append("Stats")
	return missing


# --------------------------------------------------------------------- load

func load_into(service) -> bool:
	error = ""
	if not ready:
		error = "native progress store is not configured"
		return false
	if not FileAccess.file_exists(path):
		return _create_default_tree(service, {})
	var bytes: PackedByteArray = _read_file()
	if bytes.is_empty():
		error = "native settings.dat is empty"
		return false
	var doc: Dictionary = NativeStore._parse(bytes)
	if doc.is_empty():
		error = "native settings.dat is unparseable: " + NativeStore.last_error()
		return false
	var names: Array = NativeStore.root_provider_names(bytes)
	if names.is_empty() and not NativeStore.last_error().is_empty():
		error = "native settings.dat has no provider tree: " + NativeStore.last_error()
		return false
	var missing: Array = _missing_required(names)
	if not missing.is_empty():
		error = "native settings.dat is missing required providers: " + str(missing)
		return false

	var flags: Dictionary = {}
	for spec: Dictionary in _provider_cell_specs():
		var key: String = "%s.%s" % [spec["provider"], spec["cell"]]
		var arr: Array = NativeStore.provider_array_from_bytes(
				bytes, String(spec["provider"]), String(spec["cell"]), int(spec["count"]))
		if arr.is_empty() and not NativeStore.last_error().is_empty():
			error = "native provider read failed: " + NativeStore.last_error()
			return false
		for value: Variant in arr:
			if int(value) != 0 and int(value) != 1:
				error = "native provider flag is not 0/1: " + key
				return false
		flags[key] = arr
	var stats: Dictionary = NativeStore.float_dict_from_bytes(bytes, "Stats", "data")
	if stats.is_empty() and not NativeStore.last_error().is_empty():
		error = "native stats.data read failed: " + NativeStore.last_error()
		return false
	return _apply_native(service, flags, stats)


func _grant_map(service, item_type: String) -> Dictionary:
	var out: Dictionary = {}
	for row: Dictionary in service.registry.story_unlocks:
		if String(row.get("item_type", "")) == item_type:
			_add_grant(out, int(row.get("item_id", -1)), int(row.get("id", -1)))
	for row: Dictionary in service.registry.event_unlocks:
		if String(row.get("item_type", "")) == item_type:
			_add_grant(out, int(row.get("item_id", -1)), int(row.get("id", -1)))
	return out


func _add_grant(out: Dictionary, item_id: int, unlock_id: int) -> void:
	if item_id < 0 or unlock_id < 0:
		return
	if not out.has(item_id):
		out[item_id] = []
	(out[item_id] as Array).append(unlock_id)


func _is_default(cell_key: String, index: int) -> bool:
	var defaults: Dictionary = config.get("defaults", {})
	if not defaults.has(cell_key):
		return false
	var arr: Array = defaults[cell_key]
	return index >= 0 and index < arr.size() and bool(arr[index])


func _apply_native(service, flags: Dictionary, stats: Dictionary) -> bool:
	## Native providers are authoritative for unlocks and achievements. Story and
	## mode state (not represented in these native providers) remains in JSON.
	var ids: Dictionary = {}
	var unlocked: Array = flags["Unlocker.unlocked"]
	for i: int in range(unlocked.size()):
		if int(unlocked[i]) != 0:
			ids[i] = true
	var item_type: Dictionary = config.get("item_type", {})
	for type_value: Variant in item_type.keys():
		var type_name: String = String(type_value)
		var entry: Dictionary = item_type[type_name]
		var cell_key: String = "%s.%s" % [String(entry["provider"]), String(entry["cell"])]
		var arr: Array = flags[cell_key]
		var grants: Dictionary = _grant_map(service, type_name)
		for i: int in range(arr.size()):
			var flag: int = int(arr[i])
			var grant_ids: Array = grants.get(i, [])
			if flag != 0:
				if _is_default(cell_key, i):
					continue
				if grant_ids.is_empty():
					error = "native flag has no recovered grant: %s[%d]" % [cell_key, i]
					return false
				for id_value: Variant in grant_ids:
					ids[int(id_value)] = true
			elif _is_default(cell_key, i):
				error = "native file clears a recovered default: %s[%d]" % [cell_key, i]
				return false
			else:
				for id_value: Variant in grant_ids:
					if ids.has(int(id_value)):
						error = "native item flag 0 but unlock id %d is present: %s[%d]" % [
							int(id_value), cell_key, i]
						return false
	var sorted_ids: Array = ids.keys()
	sorted_ids.sort()
	for id_value: Variant in sorted_ids:
		var id: int = int(id_value)
		if id < 0 or id >= int(service.registry.num_ids):
			error = "native unlock id outside recovered id space: %d" % id
			return false
		if not service.state["unlocks"]["sources"].has(str(id)):
			service.state["unlocks"]["sources"][str(id)] = "native"
	service.state["unlocks"]["unlocked_ids"] = sorted_ids

	var reached: Dictionary = {}
	var ach_flags: Array = flags["Unlocker.achievements"]
	if ach_flags.size() != service.achievements.rows.size():
		error = "native achievements array length does not match recovered rows"
		return false
	for i: int in range(ach_flags.size()):
		if int(ach_flags[i]) != 0:
			var row: Dictionary = service.achievements.rows[i]
			reached[String(row["id"])] = true
	var reached_list: Array = reached.keys()
	reached_list.sort()
	service.state["achievements"]["reached"] = reached_list

	var stat_keys: Array = (config.get("stats", {}) as Dictionary).get("keys", [])
	for key_value: Variant in stat_keys:
		var key: String = String(key_value)
		if stats.has(key):
			service.state["counters"][key] = int(round(float(stats[key])))
	return true


# --------------------------------------------------------------------- save

func save_from(service) -> bool:
	error = ""
	if not ready:
		error = "native progress store is not configured"
		return false
	var flags: Dictionary = _flags_from_state(service)
	if not error.is_empty():
		return false
	var stats: Dictionary = _stats_from_state(service)
	if not FileAccess.file_exists(path):
		return _create_default_tree(service, {})
	var bytes: PackedByteArray = _read_file()
	if bytes.is_empty():
		error = "native settings.dat is empty"
		return false
	var doc: Dictionary = NativeStore._parse(bytes)
	if doc.is_empty():
		error = "native settings.dat is unparseable: " + NativeStore.last_error()
		return false
	var names: Array = NativeStore.root_provider_names(bytes)
	var missing: Array = _missing_required(names)
	if not missing.is_empty():
		error = "native settings.dat is missing required providers: " + str(missing)
		return false

	var array_patches: Array = []
	for spec: Dictionary in _provider_cell_specs():
		var key: String = "%s.%s" % [spec["provider"], spec["cell"]]
		array_patches.append({"provider": String(spec["provider"]),
				"cell": String(spec["cell"]), "values": flags[key]})
	var existing_stats: Dictionary = NativeStore.float_dict_from_bytes(bytes, "Stats", "data")
	if existing_stats.is_empty() and not NativeStore.last_error().is_empty():
		error = "native stats.data read failed: " + NativeStore.last_error()
		return false
	var stat_patch: Dictionary = {}
	for key_value: Variant in stats.keys():
		if existing_stats.has(String(key_value)):
			stat_patch[String(key_value)] = stats[key_value]
	var float_patches: Array = []
	if not stat_patch.is_empty():
		float_patches.append({"provider": "Stats", "dict": "data", "values": stat_patch})
	return NativeStore.patch_provider_cells(path, array_patches, float_patches)


func _unlocked_set(service) -> Dictionary:
	var out: Dictionary = {}
	for id_value: Variant in service.state["unlocks"]["unlocked_ids"]:
		out[int(id_value)] = true
	return out


func _flags_from_state(service) -> Dictionary:
	error = ""
	var ids: Dictionary = _unlocked_set(service)
	var flags: Dictionary = {}
	var unlocked: Array = []
	for i: int in range(int((config["providers"]["Unlocker"] as Dictionary)["unlocked"])):
		unlocked.append(1 if ids.has(i) else 0)
	for id_value: Variant in ids.keys():
		var id: int = int(id_value)
		if id < 0 or id >= unlocked.size():
			error = "unlock id outside native id space: %d" % id
			return {}
	flags["Unlocker.unlocked"] = unlocked

	var achieved: Dictionary = {}
	for id_value: Variant in service.state["achievements"]["reached"]:
		achieved[String(id_value)] = true
	var ach: Array = []
	for row: Dictionary in service.achievements.rows:
		ach.append(1 if achieved.has(String(row["id"])) else 0)
	flags["Unlocker.achievements"] = ach

	var defaults: Dictionary = config.get("defaults", {})
	for cell_key: Variant in defaults.keys():
		var source: Array = defaults[cell_key]
		var out: Array = []
		for value: Variant in source:
			out.append(1 if bool(value) else 0)
		flags[String(cell_key)] = out

	var item_type: Dictionary = config.get("item_type", {})
	for type_value: Variant in item_type.keys():
		var type_name: String = String(type_value)
		var entry: Dictionary = item_type[type_name]
		var cell_key: String = "%s.%s" % [String(entry["provider"]), String(entry["cell"])]
		var arr: Array = flags[cell_key]
		var grants: Dictionary = _grant_map(service, type_name)
		for item_id_value: Variant in grants.keys():
			var item_id: int = int(item_id_value)
			if item_id < 0 or item_id >= arr.size():
				error = "native item id outside array: %s[%d]" % [cell_key, item_id]
				return {}
			for unlock_id: Variant in grants[item_id]:
				if ids.has(int(unlock_id)):
					arr[item_id] = 1
	return flags


func _stats_from_state(service) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = (config.get("stats", {}) as Dictionary).get("keys", [])
	for key_value: Variant in keys:
		var key: String = String(key_value)
		out[key] = float(int(service.state["counters"].get(key, 0)))
	return out


# ---------------------------------------------------------- full tree creation

func _int_array_node(values: Array) -> Dictionary:
	var items: Array = []
	for value: Variant in values:
		items.append(NativeStore._int_node(int(value)))
	return {"k": "array", "items": items}


func _dict_node(pairs: Array) -> Dictionary:
	return {"k": "dict", "items": pairs}


func _option_from_tree(tree: Dictionary) -> Dictionary:
	if tree.is_empty():
		return NativeStore.default_option_tree(0)
	var items: Array = tree.get("items", [])
	for pair: Variant in items:
		var p: Array = pair
		var key: Dictionary = p[0]
		if String(key.get("k", "")) == "str" and String(key.get("v", "")) == "option":
			var value: Dictionary = p[1]
			if String(value.get("k", "")) != "dict":
				error = "existing option provider is not a dictionary"
				return {}
			for pair2: Variant in (value.get("items", []) as Array):
				var kd: Dictionary = (pair2 as Array)[0]
				if String(kd.get("k", "")) != "str" or not KNOWN_OPTION_KEYS.has(String(kd.get("v", ""))):
					error = "existing option provider has an unknown cell"
					return {}
			return value
	if tree.is_empty():
		return NativeStore.default_option_tree(0)
	error = "existing tree has no option provider"
	return {}


func _existing_known_only(tree: Dictionary) -> bool:
	if tree.is_empty():
		return true
	if String(tree.get("k", "")) != "dict":
		error = "existing settings root is not a dictionary"
		return false
	var known: Dictionary = _known_provider_names()
	var allowed_cells: Dictionary = {
		"Unlocker": ["unlocked", "achievements", "art_pictures"],
		"CharacterList": ["available", "profile_available"],
		"SceneryList": ["available"],
		"Stats": ["data"],
	}
	for pair: Variant in (tree.get("items", []) as Array):
		var p: Array = pair
		var key: Dictionary = p[0]
		var name: String = String(key.get("v", ""))
		if not known.has(name):
			error = "existing settings has unknown provider: " + name
			return false
		if name in ["option", "version"]:
			continue
		var value: Dictionary = p[1]
		if String(value.get("k", "")) != "dict":
			error = "existing provider is not a dictionary: " + name
			return false
		for pair2: Variant in (value.get("items", []) as Array):
			var kd: Dictionary = (pair2 as Array)[0]
			if not allowed_cells.has(name) or not (allowed_cells[name] as Array).has(String(kd.get("v", ""))):
				error = "existing provider has unknown cell: %s.%s" % [name, String(kd.get("v", ""))]
				return false
			if name == "Stats" and String(kd.get("v", "")) == "data":
				var data_value: Dictionary = (pair2 as Array)[1]
				if String(data_value.get("k", "")) != "dict":
					error = "existing Stats.data is not a dictionary"
					return false
				var allowed_stats: Array = (config.get("stats", {}) as Dictionary).get("keys", [])
				for pair3: Variant in (data_value.get("items", []) as Array):
					var kd3: Dictionary = (pair3 as Array)[0]
					if String(kd3.get("k", "")) != "str" or not allowed_stats.has(String(kd3.get("v", ""))):
						error = "existing Stats.data has an unknown key: " + String(kd3.get("v", ""))
						return false
	return true


func _create_default_tree(service, existing: Dictionary) -> bool:
	error = ""
	if not _existing_known_only(existing):
		return false
	var flags: Dictionary = _flags_from_state(service)
	if not error.is_empty():
		return false
	var stats: Dictionary = _stats_from_state(service)
	var option: Dictionary = _option_from_tree(existing)
	if option.is_empty():
		return false
	var version: Dictionary = NativeStore._float_node(NativeStore.CODE_VERSION)
	if not existing.is_empty():
		for pair: Variant in (existing.get("items", []) as Array):
			var p: Array = pair
			var key: Dictionary = p[0]
			if String(key.get("v", "")) == "version":
				version = p[1]
	var provider_nodes: Array = []
	provider_nodes.append([NativeStore._str_node("Unlocker"), _dict_node([
		[NativeStore._str_node("unlocked"), _int_array_node(flags["Unlocker.unlocked"])],
		[NativeStore._str_node("achievements"), _int_array_node(flags["Unlocker.achievements"])],
		[NativeStore._str_node("art_pictures"), _int_array_node(flags["Unlocker.art_pictures"])],
	])])
	provider_nodes.append([NativeStore._str_node("CharacterList"), _dict_node([
		[NativeStore._str_node("available"), _int_array_node(flags["CharacterList.available"])],
		[NativeStore._str_node("profile_available"), _int_array_node(flags["CharacterList.profile_available"])],
	])])
	provider_nodes.append([NativeStore._str_node("SceneryList"), _dict_node([
		[NativeStore._str_node("available"), _int_array_node(flags["SceneryList.available"])],
	])])
	var stat_pairs: Array = []
	for key_value: Variant in stats.keys():
		stat_pairs.append([NativeStore._str_node(String(key_value)),
				NativeStore._float_node(float(stats[key_value]))])
	provider_nodes.append([NativeStore._str_node("Stats"), _dict_node([
		[NativeStore._str_node("data"), _dict_node(stat_pairs)],
	])])

	var root_items: Array = [
		[NativeStore._str_node("option"), option],
	]
	root_items.append_array(provider_nodes)
	root_items.append([NativeStore._str_node("version"), version])
	var tree: Dictionary = _dict_node(root_items)
	var encoded: PackedByteArray = NativeStore.encode(tree)
	if encoded.is_empty():
		error = "native tree encode failed: " + NativeStore.last_error()
		return false
	if not _write_file(encoded):
		return false
	# Verify the written file is readable with the exact expected flags.
	return load_into(service)


# ------------------------------------------------------------------ summary

func read_flags() -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(path):
		error = "native settings.dat missing"
		return out
	var bytes: PackedByteArray = _read_file()
	for spec: Dictionary in _provider_cell_specs():
		var key: String = "%s.%s" % [spec["provider"], spec["cell"]]
		var arr: Array = NativeStore.provider_array_from_bytes(
				bytes, String(spec["provider"]), String(spec["cell"]), int(spec["count"]))
		if arr.is_empty() and not NativeStore.last_error().is_empty():
			error = NativeStore.last_error()
			return {}
		out[key] = arr
	out["Stats.data"] = NativeStore.float_dict_from_bytes(bytes, "Stats", "data")
	return out


func summary() -> Dictionary:
	return {
		"ready": ready,
		"path": path,
		"error": error,
		"flags": read_flags(),
	}

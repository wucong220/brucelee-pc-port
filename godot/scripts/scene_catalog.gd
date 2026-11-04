extends RefCounted
## Recovered `sceneries.list` catalogue for the opt-in scene dock
## (`BRUCELEE_SCENE_SELECT=1`).
##
## Every value served here is copied from decoded data.  Nothing is invented:
##
##   * rows and their order  : `adreno_200/sceneries.list`, decoded into
##                             `res://data/story/story_mode.json` under
##                             `tables.sceneries` -- the same table the story
##                             flow already launches its battles from;
##   * port scene variant    : `row.port_scene_variant`, the exact string the
##                             port writes into `BRUCELEE_SCENE` (`""` is the
##                             default Temple Yard A arena);
##   * dock icons and order  : `adreno_200/gui/selectscenery.ui`, decoded into
##                             `res://data/menu_art/ui/selectscenery.json`; the
##                             catalogue requires the dock's 10 item icons to be
##                             the 10 `sceneries.list` pictures, in order;
##   * display labels        : the row's `translate_name` resolved through the
##                             recovered `.lang` table
##                             (`res://data/story/story_text_by_language.json`).
##
## It fails closed: a missing/invalid layout, a dock that does not match the
## list, a missing icon texture or a variant with no menu command leaves
## `error` set and no rows, and the caller keeps the text scene menu.

## `tables.sceneries` of the decoded story data (a decode of sceneries.list).
const DATA_PATH := "res://data/story/story_mode.json"
const DEFAULT_LAYOUT := "res://data/menu_art/ui/selectscenery.json"
const LANG_PATH := "res://data/story/story_text_by_language.json"
## Test / packaging hook, like BRUCELEE_MAINMENU_PATH: point the dock at another
## decoded layout (used to prove the fail-closed path with a genuinely missing
## file).  Unset = the shipped decoded layout.
const LAYOUT_ENV := "BRUCELEE_SCENE_SELECT_LAYOUT"
const ART_ROOT := "res://ui/menu_art/"
const ICON_DIR := "mini"

## Port scene variant -> the menu command `main.gd` already implements for it.
## `main.gd`'s `MENU_SCENE_COMMANDS` is the authority: the scene-select test
## compares this table with the constants of the real `main.gd` script and
## drives every command to its `BRUCELEE_SCENE` value, so the two cannot drift
## silently.  The command names and the variants are the ones the text scene
## submenu has shipped since the scene switch existed.
const VARIANT_COMMANDS := {
	"": "temple_a",
	"templeyardb": "temple_b",
	"halla": "halla",
	"squarea": "squarea",
	"squareb": "squareb",
	"harboura": "harboura",
	"harbourb": "harbourb",
	"rooftopsa": "rooftopsa",
	"rooftopsb": "rooftopsb",
	"tournamenthallb": "tournamenthallb",
}

var error: String = ""
var layout_path: String = ""
var layout: Dictionary = {}
var source: Dictionary = {}

var _rows: Array = []
var _lang = null
var _icon_paths: Dictionary = {}
var _art_roots: Array[String] = []
var _art_override: String = ""


func _init() -> void:
	_lang = preload("res://scripts/story_lang.gd").new()


## Builds the catalogue for `language` (a `LangXxx` name; empty = table
## default).  Returns false with `error` set when anything is missing.
##
## `art_root` overrides where the decoded dock icons are looked up; it exists
## for the isolated fail-closed test (an empty directory proves the missing-icon
## path) and for packaged runs that keep the PNGs beside the executable.
func load_catalog(language: String = "", art_root: String = "") -> bool:
	error = ""
	_rows = []
	layout = {}
	source = {}
	_icon_paths = {}
	_art_override = art_root
	layout_path = OS.get_environment(LAYOUT_ENV)
	if layout_path.is_empty():
		layout_path = DEFAULT_LAYOUT
	if not FileAccess.file_exists(layout_path):
		error = "selectscenery layout missing: " + layout_path
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		error = "selectscenery layout is not a JSON object: " + layout_path
		return false
	layout = parsed
	if not _check_layout():
		return false
	if not _load_rows(language):
		return false
	return true


# ------------------------------------------------------------------ layout

func _widget(widget_name: String) -> Dictionary:
	for node: Variant in (layout.get("layout", []) as Array):
		if typeof(node) == TYPE_DICTIONARY and String((node as Dictionary).get("name", "")) == widget_name:
			return node
	return {}


func _check_layout() -> bool:
	var nodes: Variant = layout.get("layout")
	if typeof(nodes) != TYPE_ARRAY or (nodes as Array).is_empty():
		error = "selectscenery layout has no widgets: " + layout_path
		return false
	for node: Variant in (nodes as Array):
		if typeof(node) != TYPE_DICTIONARY:
			error = "selectscenery layout widget is not an object: " + layout_path
			return false
		for field: String in ["name", "type", "x", "y", "width", "height"]:
			if not (node as Dictionary).has(field):
				error = "selectscenery layout widget misses " + field + ": " + layout_path
				return false
		for field: String in ["x", "y", "width", "height"]:
			var value_type: int = typeof((node as Dictionary)[field])
			if value_type != TYPE_INT and value_type != TYPE_FLOAT:
				error = "selectscenery layout widget has non-numeric " + field + ": " + layout_path
				return false
	var label: Dictionary = _widget("scenery_name")
	if label.is_empty():
		error = "selectscenery layout misses the scenery_name label: " + layout_path
		return false
	if String(label.get("type", "")) != "label" and String(label.get("type", "")) != "bllabel":
		error = "scenery_name is not a label in " + layout_path
		return false
	var dock: Dictionary = _widget("sceneries")
	if dock.is_empty():
		error = "selectscenery layout misses the sceneries dock: " + layout_path
		return false
	if String(dock.get("type", "")) != "bldock":
		error = "sceneries is not a bldock in " + layout_path
		return false
	for field: String in ["optionwidth", "optionheight"]:
		if not dock.has(field):
			error = "sceneries dock misses " + field + " in " + layout_path
			return false
	if (dock.get("items", []) as Array).is_empty():
		error = "sceneries dock has no items in " + layout_path
		return false
	source = layout.get("source", {}) if typeof(layout.get("source", {})) == TYPE_DICTIONARY else {}
	return true


func label_widget() -> Dictionary:
	return _widget("scenery_name")


func dock_widget() -> Dictionary:
	return _widget("sceneries")


# -------------------------------------------------------------------- rows

func _load_rows(language: String) -> bool:
	if not FileAccess.file_exists(DATA_PATH):
		error = "story data missing: " + DATA_PATH
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		error = "story data is not a JSON object: " + DATA_PATH
		return false
	var tables: Variant = (parsed as Dictionary).get("tables", {})
	var rows: Variant = (tables as Dictionary).get("sceneries", []) if typeof(tables) == TYPE_DICTIONARY else []
	if typeof(rows) != TYPE_ARRAY or (rows as Array).is_empty():
		error = "story data has no sceneries table: " + DATA_PATH
		return false
	var dock: Dictionary = dock_widget()
	var items: Array = dock.get("items", [])
	if (rows as Array).size() != items.size():
		error = "sceneries.list has %d rows but the decoded dock has %d items" % [
			(rows as Array).size(), items.size()]
		return false
	_lang.current_lang = language if not language.is_empty() else _lang.current_lang
	_build_icon_index()
	var out: Array = []
	for index: int in range((rows as Array).size()):
		var row_value: Variant = (rows as Array)[index]
		if typeof(row_value) != TYPE_DICTIONARY:
			error = "sceneries row %d is not an object" % index
			return false
		var row: Dictionary = row_value
		for field: String in ["name", "picture", "translate_name"]:
			if not row.has(field):
				error = "sceneries row %d misses %s" % [index, field]
				return false
		var picture: String = String(row["picture"])
		var icon: String = picture.get_file().get_basename().to_lower()
		var item: Dictionary = items[index]
		var reference: Variant = item.get("$file", {})
		if typeof(reference) != TYPE_DICTIONARY:
			error = "dock item %d has no file reference in %s" % [index, layout_path]
			return false
		var item_icon: String = String((reference as Dictionary).get("basename", "")).to_lower()
		if item_icon != icon:
			error = "dock item %d is '%s' but sceneries.list row %d is '%s'" % [
				index, item_icon, index, icon]
			return false
		if not row.has("port_scene_variant"):
			error = "sceneries row %d ('%s') has no port_scene_variant" % [index, String(row["name"])]
			return false
		var variant: String = String(row["port_scene_variant"])
		if not VARIANT_COMMANDS.has(variant):
			error = "sceneries row %d ('%s') maps to scene variant '%s', which has no menu command" % [
				index, String(row["name"]), variant]
			return false
		if not _icon_paths.has(icon):
			error = "missing dock icon %s (decoded texture for sceneries.list row %d)" % [icon, index]
			return false
		out.append({
			"index": index,
			"name": String(row["name"]),
			"translate_name": String(row["translate_name"]),
			"label": _lang.text(String(row["translate_name"])),
			"icon": icon,
			"icon_path": String(_icon_paths[icon]),
			"variant": variant,
			"command": String(VARIANT_COMMANDS[variant]),
			# `always_available` is a recovered string on the always-open row and
			# JSON null on the story-gated rows; `str()` keeps a null from turning
			# into a failed String() conversion.
			"music": str(row.get("music", "")),
			"always_available": str(row.get("always_available", "")).to_lower() == "true",
		})
	_rows = out
	return true


func _build_icon_index() -> void:
	_art_roots = []
	if not _art_override.is_empty():
		# The override is a directory root; the icon folder is appended to it.
		_art_roots.append(_art_override.rstrip("/") + "/")
	else:
		_art_roots.append(ART_ROOT)
		# Exported packages keep the decoded PNGs beside the executable because
		# the original artwork is local-only and never committed (same rule as the
		# art menu in menu_art.gd).
		var beside_exe: String = OS.get_executable_path().get_base_dir().path_join(
			"ui/menu_art") + "/"
		if DirAccess.dir_exists_absolute(beside_exe):
			_art_roots.append(beside_exe)
	for art_root: String in _art_roots:
		var path: String = art_root + ICON_DIR
		for name: String in DirAccess.get_files_at(path):
			if not name.to_lower().ends_with(".png"):
				continue
			_icon_paths[name.get_basename().to_lower()] = path.path_join(name)


# ------------------------------------------------------------------ access

func rows() -> Array:
	return _rows.duplicate(true)


func row(index: int) -> Dictionary:
	if index < 0 or index >= _rows.size():
		return {}
	return _rows[index]


func size() -> int:
	return _rows.size()


## Provenance block for the report / tests: the decoded layout's own record of
## the container it came from, plus the dock geometry actually used.
func metadata() -> Dictionary:
	var dock: Dictionary = dock_widget()
	var label: Dictionary = label_widget()
	return {
		"layout": layout_path,
		"screen": String(layout.get("screen", "")),
		"layout_source": source.duplicate(true),
		"rows": _rows.size(),
		"dock": {
			"rect": {
				"x": float(dock.get("x", 0.0)), "y": float(dock.get("y", 0.0)),
				"width": float(dock.get("width", 0.0)),
				"height": float(dock.get("height", 0.0)),
			},
			"optionwidth": float(dock.get("optionwidth", 0.0)),
			"optionheight": float(dock.get("optionheight", 0.0)),
			"separation": float(dock.get("separation", 0.0)),
			"linerect": String(dock.get("linerect", "false")) == "true",
			"linerectcolor": dock.get("linerectcolor", []),
			"wraparround": String(dock.get("wraparround", "false")) == "true",
			"items": (dock.get("items", []) as Array).size(),
		},
		"label": {
			"rect": {
				"x": float(label.get("x", 0.0)), "y": float(label.get("y", 0.0)),
				"width": float(label.get("width", 0.0)),
				"height": float(label.get("height", 0.0)),
			},
			"textcolor": label.get("textcolor", []),
			"uppercase": String(label.get("uppercase", "false")) == "true",
			"align": String(label.get("align", "")),
			"datasources": label.get("datasources", {}),
		},
	}

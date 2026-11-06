extends RefCounted
class_name StyleSelectionStore

## user:// store for the opt-in Style Editor selections.
##
## Kept in its own file instead of the progress envelope so the existing
## progress schema/version is untouched: enabling the style editor cannot
## rewrite or invalidate a player's progress_save.json. The envelope is
## checksummed and loading fails closed: a missing/corrupt/tampered file gives
## the catalog defaults (never a partial or invented selection).

const SAVE_PATH: String = "user://style_selections.json"
const SCHEMA: String = "brucelee-style-selections/1"
const VERSION: int = 1

var save_path: String = SAVE_PATH
var selections: Dictionary = {}
var last_error: String = ""
var file_found: bool = false
var checksum_ok: bool = false
var loaded_ok: bool = false
var last_saved_utc: String = ""


func configure(path: String) -> void:
    if not path.is_empty():
        save_path = path


## Load the file, falling back to catalog defaults on every failure.
func load_selections(catalog: StyleCatalog) -> Dictionary:
    selections = catalog.defaults() if catalog != null else {}
    last_error = ""
    file_found = false
    checksum_ok = false
    loaded_ok = false
    last_saved_utc = ""
    if not FileAccess.file_exists(save_path):
        last_error = "no style selection file yet"
        return selections
    file_found = true
    var text: String = FileAccess.get_file_as_string(save_path)
    var json: JSON = JSON.new()
    if json.parse(text) != OK:
        last_error = "style selection file is not valid JSON"
        return selections
    if typeof(json.data) != TYPE_DICTIONARY:
        last_error = "style selection envelope is not an object"
        return selections
    var envelope: Dictionary = json.data
    if String(envelope.get("schema", "")) != SCHEMA:
        last_error = "unexpected style selection schema"
        return selections
    if int(envelope.get("version", 0)) != VERSION:
        last_error = "unexpected style selection version"
        return selections
    var payload_json: String = String(envelope.get("payload_json", ""))
    if payload_json.is_empty():
        last_error = "style selection payload missing"
        return selections
    if payload_json.sha256_text() != String(envelope.get("checksum", "")):
        last_error = "style selection checksum mismatch (fail closed)"
        return selections
    checksum_ok = true
    var payload: JSON = JSON.new()
    if payload.parse(payload_json) != OK or typeof(payload.data) != TYPE_DICTIONARY:
        last_error = "style selection payload is not an object"
        return selections
    var groups: Variant = payload.data.get("groups", null)
    if typeof(groups) != TYPE_DICTIONARY:
        last_error = "style selection payload has no groups"
        return selections
    selections = normalize(catalog, groups)
    loaded_ok = true
    last_saved_utc = String(envelope.get("saved_utc", ""))
    return selections


## Keep only known groups and known entry ids; anything else becomes the
## catalog default. This is also the fail-closed guard for hand-edited files.
func normalize(catalog: StyleCatalog, raw: Dictionary) -> Dictionary:
    var out: Dictionary = catalog.defaults() if catalog != null else {}
    if catalog == null:
        return out
    for group_key in catalog.groups_in_order():
        var value: String = String(raw.get(group_key, ""))
        if value.is_empty() or catalog.entry_index(group_key, value) < 0:
            value = String(out.get(group_key, ""))
        out[group_key] = value
    return out


func set_selection(catalog: StyleCatalog, group_key: String, entry_id: String) -> bool:
    if catalog == null or catalog.entry_index(group_key, entry_id) < 0:
        last_error = "unknown style selection: %s/%s" % [group_key, entry_id]
        return false
    selections[group_key] = entry_id
    return true


func reset(catalog: StyleCatalog) -> void:
    selections = catalog.defaults() if catalog != null else {}


func save() -> bool:
    last_error = ""
    var payload: Dictionary = {
        "groups": selections.duplicate(true),
        "saved_utc": Time.get_datetime_string_from_system(true),
    }
    var payload_json: String = JSON.stringify(payload)
    var envelope: Dictionary = {
        "schema": SCHEMA,
        "version": VERSION,
        "saved_utc": payload["saved_utc"],
        "checksum": payload_json.sha256_text(),
        "payload_json": payload_json,
    }
    var temp_path: String = save_path + ".tmp"
    var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        last_error = "cannot write style selection temp file: " + temp_path
        return false
    file.store_string(JSON.stringify(envelope))
    file.close()
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
    var move_error: Error = DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temp_path),
        ProjectSettings.globalize_path(save_path)
    )
    if move_error != OK:
        last_error = "cannot replace style selection file (error %d)" % move_error
        return false
    last_saved_utc = String(payload["saved_utc"])
    loaded_ok = true
    checksum_ok = true
    file_found = true
    return true


func selected(group_key: String) -> String:
    return String(selections.get(group_key, ""))


func saved_id_for(group_key: String, catalog: StyleCatalog) -> String:
    ## The id the current file really holds (used for the persistent highlight).
    return selected(group_key)

extends RefCounted
class_name PortNativeSettingsStore
## Native on-disk settings codec recovered from libdefault.so.
##
## Format (see res://data/menu_art/native_settings_format.json for the evidence):
##   the original game stores its settings/progress/achievements/options in a
##   "1FDKENONCTX3" krm resource file named `settings.dat` under the app write
##   path (krm::CApplication::Init/End -> sal::GetAppWritePath()).
##   Layout: "1FDK" + u32 'NONE' + "CTX3" + header(4 words) + string table
##   (u32 id=CRC32(text)+len, u32 len, text, 0) + pad + file refs + "DATA" +
##   5 u32 words + bin/typed offset tables + 8-byte records + payloads +
##   16-byte MD5 over everything before it.
##
## Cells: 0x3 dict(n, second=first_key-offset), 0x4 array, 0x6 HashString key,
##   0x2 float scalar, 0x0 int scalar, 0x7 resFileId.
##
## Byte-exactly validated against genuine extracted resources (see REPORT.md).

const MAGIC := "1FDKENONCTX3"
const NATIVE_FILE_NAME := "settings.dat"
## krm::BruceLee_GetCodeVersionNumber() == 0x2d06 (11526 = 1.15.26). Written into
## the root "version" cell so CBruceLeeSettings::UnSerialize skips its <10415 /
## <10505 migration defaults that would overwrite `language`.
const CODE_VERSION := 11526.0

static var _last_error: String = ""
static var _crc_table: Array = []


static func last_error() -> String:
	return _last_error


# ---------------------------------------------------------------- crc32 / md5

static func _ensure_crc() -> void:
	if not _crc_table.is_empty():
		return
	_crc_table.resize(256)
	for n: int in range(256):
		var c: int = n
		for _k: int in range(8):
			if (c & 1) != 0:
				c = 0xEDB88320 ^ (c >> 1)
			else:
				c = c >> 1
		_crc_table[n] = c & 0xffffffff


static func _crc32(bytes: PackedByteArray) -> int:
	_ensure_crc()
	var c: int = 0xffffffff
	for b: int in bytes:
		c = _crc_table[(c ^ b) & 0xff] ^ (c >> 8)
	return (c ^ 0xffffffff) & 0xffffffff


static func _md5(bytes: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(bytes)
	return ctx.finish()


# ------------------------------------------------------------------- reading

static func _u32(bytes: PackedByteArray, pos: int) -> int:
	var b: PackedByteArray = bytes.slice(pos, pos + 4)
	return b.decode_u32(0)


static func _width_value(bytes: PackedByteArray, pos: int, width: int) -> int:
	var b: PackedByteArray = bytes.slice(pos, pos + width)
	match width:
		1: return b.decode_u8(0)
		2: return b.decode_u16(0)
		_: return b.decode_u32(0)


static func _parse(bytes: PackedByteArray) -> Dictionary:
	_last_error = ""
	if bytes.size() < 32:
		_last_error = "resource shorter than 32 bytes"
		return {}
	if bytes.slice(0, 12).get_string_from_ascii() != MAGIC:
		_last_error = "missing 1FDKENONCTX3 signature"
		return {}
	var retained: int = _u32(bytes, 12)
	var file_count: int = _u32(bytes, 16)
	var function_count: int = _u32(bytes, 20)
	var total: int = _u32(bytes, 24)
	var count: int = total
	if count < 0 or count > 100000:
		_last_error = "implausible string count"
		return {}
	var strings: Array = []
	var pos: int = 0x1c
	for i: int in range(count):
		if pos + 8 > bytes.size():
			_last_error = "truncated string record"
			return {}
		var ident: int = _u32(bytes, pos)
		var ln: int = _u32(bytes, pos + 4)
		pos += 8
		if pos + ln + 1 > bytes.size():
			_last_error = "truncated string data"
			return {}
		var raw: PackedByteArray = bytes.slice(pos, pos + ln)
		if ((_crc32(raw) + ln) & 0xffffffff) != ident:
			_last_error = "string id mismatch at %d" % i
			return {}
		pos += ln + 1
		strings.append(raw.get_string_from_utf8())
	var table_end: int = pos
	var pad: int = (table_end - 0x1c) & 3
	pos = table_end + pad
	var width: int = 1 if total <= 255 else (2 if total <= 65535 else 4)
	var file_refs: Array = []
	for i: int in range(file_count):
		var triple: Array = []
		for j: int in range(3):
			triple.append(_width_value(bytes, pos, width))
			pos += width
		file_refs.append(triple)
	var func_refs: Array = []
	for i: int in range(function_count):
		func_refs.append(_width_value(bytes, pos, width))
		pos += width
	if pos + 4 > bytes.size() or bytes.slice(pos, pos + 4).get_string_from_ascii() != "DATA":
		_last_error = "DATA marker missing"
		return {}
	pos += 4
	if pos + 20 > bytes.size():
		_last_error = "truncated DATA header"
		return {}
	var rec_count: int = _u32(bytes, pos)
	var bin_count: int = _u32(bytes, pos + 4)
	var typed_count: int = _u32(bytes, pos + 8)
	var bin_bytes: int = _u32(bytes, pos + 12)
	var typed_bytes: int = _u32(bytes, pos + 16)
	if (rec_count < 0 or rec_count > 200000 or bin_count < 0 or bin_count > 200000
			or typed_count < 0 or typed_count > 200000 or bin_bytes < 0 or typed_bytes < 0):
		_last_error = "implausible DATA header counts (fail closed)"
		return {}
	pos += 20
	var bin_off: Array = []
	for i: int in range(bin_count):
		bin_off.append(_u32(bytes, pos)); pos += 4
	var typed_off: Array = []
	for i: int in range(typed_count):
		typed_off.append(_u32(bytes, pos)); pos += 4
	var recs: Array = []
	for i: int in range(rec_count):
		recs.append([_u32(bytes, pos), _u32(bytes, pos + 4)])
		pos += 8
	if pos + bin_bytes + typed_bytes + 16 != bytes.size():
		_last_error = "payload/tail bounds do not match file size"
		return {}
	var payload_start: int = pos
	pos += bin_bytes + typed_bytes
	var tail: PackedByteArray = bytes.slice(pos, pos + 16)
	if _md5(bytes.slice(0, pos)) != tail:
		_last_error = "MD5 tail mismatch"
		return {}
	return {"strings": strings, "file_refs": file_refs, "func_refs": func_refs,
			"retained": retained, "recs": recs, "bin_off": bin_off, "typed_off": typed_off,
			"bin_payload": bytes.slice(payload_start, payload_start + bin_bytes),
			"typed_payload": bytes.slice(payload_start + bin_bytes, pos)}


static func _key_at(doc: Dictionary, idx: int) -> Dictionary:
	var recs: Array = doc["recs"]
	if idx < 0 or idx >= recs.size():
		_last_error = "key record index out of range"
		return {}
	var d: Array = recs[idx]
	var tag: int = int(d[0]) & 0xf0000000
	if tag == 0x60000000:
		var strings: Array = doc["strings"]
		if int(d[1]) >= strings.size():
			_last_error = "string key ordinal out of range"
			return {}
		return {"k": "str", "v": strings[int(d[1])]}
	if tag == 0x00000000:
		return {"k": "int", "v": int(d[1])}
	_last_error = "unsupported key tag 0x%08x" % tag
	return {}


static func _read_node(doc: Dictionary, idx: int, guard: Array) -> Dictionary:
	guard[0] = int(guard[0]) + 1
	var recs: Array = doc["recs"]
	if int(guard[0]) > recs.size() * 4 + 16:
		_last_error = "record graph cycle"
		return {}
	if idx < 0 or idx >= recs.size():
		_last_error = "record index out of range"
		return {}
	var d: Array = recs[idx]
	var desc: int = int(d[0])
	var second: int = int(d[1])
	var tag: int = desc & 0xf0000000
	var cnt: int = desc & 0x1fffff
	if tag == 0x30000000:
		var items: Array = []
		var base: int = idx + second
		for j: int in range(cnt):
			var key: Dictionary = _key_at(doc, base + 2 * j)
			if key.is_empty():
				return {}
			var val: Dictionary = _read_node(doc, base + 2 * j + 1, guard)
			if val.is_empty():
				return {}
			items.append([key, val])
		return {"k": "dict", "items": items}
	if tag == 0x40000000:
		var elems: Array = []
		var base2: int = idx + second
		for j: int in range(cnt):
			var v: Dictionary = _read_node(doc, base2 + j, guard)
			if v.is_empty():
				return {}
			elems.append(v)
		return {"k": "array", "items": elems}
	if tag == 0x60000000:
		var strings2: Array = doc["strings"]
		if second >= strings2.size():
			_last_error = "string value ordinal out of range"
			return {}
		return {"k": "str", "v": strings2[second]}
	if tag == 0x20000000:
		if cnt != 0:
			_last_error = "typed float arrays (counted 0x2xxxxxxx) are NOT implemented"
			return {}
		return {"k": "float", "bits": second}
	if tag == 0x00000000:
		return {"k": "int", "v": second}
	if tag == 0x70000000:
		var refs: Array = doc["file_refs"]
		if second >= refs.size():
			_last_error = "file ref index out of range"
			return {}
		var t: Array = refs[second]
		var strings3: Array = doc["strings"]
		return {"k": "file", "v": [strings3[int(t[0])], strings3[int(t[1])], strings3[int(t[2])]]}
	_last_error = "unsupported cell tag 0x%08x at record %d" % [tag, idx]
	return {}


static func decode(bytes: PackedByteArray) -> Dictionary:
	var doc: Dictionary = _parse(bytes)
	if doc.is_empty():
		return {}
	return _read_node(doc, 0, [0])


# ------------------------------------------------------------------- writing

static func _float_bits(value: float) -> int:
	var b: PackedByteArray = PackedFloat32Array([value]).to_byte_array()
	return b.decode_u32(0)


static func _bits_float(bits: int) -> float:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, bits & 0xffffffff)
	return b.decode_float(0)


static func _str_node(s: String) -> Dictionary:
	return {"k": "str", "v": s}


static func _float_node(v: float) -> Dictionary:
	return {"k": "float", "bits": _float_bits(v)}


static func _int_node(v: int) -> Dictionary:
	return {"k": "int", "v": v & 0xffffffff}


static func default_option_tree(language_index: int) -> Dictionary:
	return {
		"k": "dict",
		"items": [
			[_str_node("HUD"), _float_node(0.0)],
			[_str_node("input_layout"), _float_node(0.0)],
			[_str_node("input_gui_alpha"), _float_node(0.25)],
			[_str_node("sound_volume"), _float_node(0.5)],
			[_str_node("music_volume"), _float_node(0.5)],
			[_str_node("arcade_time"), _float_node(1.0)],
			[_str_node("versus_time"), _float_node(1.0)],
			[_str_node("survival_time"), _float_node(1.0)],
			[_str_node("camera_tilt"), _float_node(1.0)],
			[_str_node("language"), _float_node(float(language_index))],
			[_str_node("variable_mainmenu_selectedoption"), _float_node(0.0)],
			[_str_node("variable_playmenu_selectedoption"), _float_node(0.0)],
		],
	}


static func default_tree(language_index: int) -> Dictionary:
	return {
		"k": "dict",
		"items": [
			[_str_node("option"), default_option_tree(language_index)],
			[_str_node("version"), _float_node(CODE_VERSION)],
		],
	}


static func _collect(ctx: Dictionary, v: Dictionary) -> void:
	match String(v.get("k", "")):
		"dict":
			for pair: Array in v["items"]:
				var key: Dictionary = pair[0]
				if key["k"] == "str" and not (ctx["tree_strings"] as Array).has(key["v"]):
					(ctx["tree_strings"] as Array).append(key["v"])
				_collect(ctx, pair[1])
		"array":
			for x: Dictionary in v["items"]:
				_collect(ctx, x)
		"str":
			if not (ctx["tree_strings"] as Array).has(v["v"]):
				(ctx["tree_strings"] as Array).append(v["v"])
		"file":
			if not (ctx["file_refs"] as Array).has(v["v"]):
				(ctx["file_refs"] as Array).append(v["v"])


static func _alloc(ctx: Dictionary) -> int:
	(ctx["records"] as Array).append([0, 0])
	return (ctx["records"] as Array).size() - 1


static func _fill(ctx: Dictionary, idx: int, v: Dictionary) -> void:
	var records: Array = ctx["records"]
	var tree_strings: Array = ctx["tree_strings"]
	var file_refs: Array = ctx["file_refs"]
	match String(v.get("k", "")):
		"dict":
			var pairs: Array = v["items"]
			var keys: Array = []
			var vals: Array = []
			for pair: Array in pairs:
				keys.append([_alloc(ctx), pair[0]])
				vals.append([_alloc(ctx), pair[1]])
			var first_key: int = keys[0][0] if not keys.is_empty() else idx
			for entry: Array in keys:
				var key: Dictionary = entry[1]
				if key["k"] == "str":
					var oi: int = tree_strings.find(key["v"])
					if oi < 0:
						_last_error = "internal: uninterned key"
						return
					var ki: int = entry[0]
					records[ki] = [0x60000000, oi]
				elif key["k"] == "int":
					var ki2: int = entry[0]
					records[ki2] = [0x00000000, int(key["v"]) & 0xffffffff]
				else:
					_last_error = "unsupported dict key kind " + String(key["k"])
					return
			records[idx] = [0x30000000 | (pairs.size() & 0x1fffff), first_key - idx]
			for entry2: Array in vals:
				_fill(ctx, entry2[0], entry2[1])
		"array":
			var elems: Array = v["items"]
			var vis: Array = []
			for x: Dictionary in elems:
				vis.append([_alloc(ctx), x])
			var first_el: int = vis[0][0] if not vis.is_empty() else idx
			records[idx] = [0x40000000 | (elems.size() & 0x1fffff), first_el - idx]
			for e: Array in vis:
				_fill(ctx, e[0], e[1])
		"str":
			var oi2: int = tree_strings.find(v["v"])
			if oi2 < 0:
				_last_error = "internal: uninterned string value"
				return
			records[idx] = [0x60000000, oi2]
		"float":
			records[idx] = [0x20000000, int(v["bits"]) & 0xffffffff]
		"int":
			records[idx] = [0x00000000, int(v["v"]) & 0xffffffff]
		"file":
			var fi: int = file_refs.find(v["v"])
			if fi < 0:
				_last_error = "internal: uninterned file ref"
				return
			records[idx] = [0x70000000, fi]
		_:
			_last_error = "unsupported node kind " + String(v.get("k", ""))


static func _put_u32(out: PackedByteArray, v: int) -> void:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v & 0xffffffff)
	out.append_array(b)


static func _put_width(out: PackedByteArray, v: int, width: int) -> void:
	match width:
		1:
			out.append(v & 0xff)
		2:
			var b := PackedByteArray()
			b.resize(2)
			b.encode_u16(0, v & 0xffff)
			out.append_array(b)
		_:
			_put_u32(out, v)


static func encode(tree: Dictionary) -> PackedByteArray:
	_last_error = ""
	var ctx: Dictionary = {"records": [], "tree_strings": [], "file_refs": []}
	_collect(ctx, tree)
	var root_idx: int = _alloc(ctx)
	_fill(ctx, root_idx, tree)
	if not _last_error.is_empty():
		return PackedByteArray()

	var records: Array = ctx["records"]
	var tree_strings: Array = ctx["tree_strings"]
	var file_refs: Array = ctx["file_refs"]

	var strings: Array = tree_strings.duplicate()
	var triples: Array = []
	for t: Array in file_refs:
		var triple: Array = []
		for s: String in t:
			if not strings.has(s):
				strings.append(s)
			triple.append(strings.find(s))
		triples.append(triple)

	var retained: int = tree_strings.size()
	var total: int = strings.size()
	var width: int = 1 if total <= 255 else (2 if total <= 65535 else 4)
	var out := PackedByteArray()
	out.append_array(MAGIC.to_ascii_buffer())
	_put_u32(out, retained)
	_put_u32(out, file_refs.size())
	_put_u32(out, 0)
	_put_u32(out, total)
	for s2: String in strings:
		var raw: PackedByteArray = s2.to_utf8_buffer()
		_put_u32(out, (_crc32(raw) + raw.size()) & 0xffffffff)
		_put_u32(out, raw.size())
		out.append_array(raw)
		out.append(0)
	var padn: int = (out.size() - 0x1c) & 3
	for _p: int in range(padn):
		out.append(0)
	for triple2: Array in triples:
		for ordv: int in triple2:
			_put_width(out, ordv, width)
	out.append_array("DATA".to_ascii_buffer())
	_put_u32(out, records.size())
	_put_u32(out, 0)
	_put_u32(out, 0)
	_put_u32(out, 0)
	_put_u32(out, 0)
	for rec: Array in records:
		_put_u32(out, rec[0])
		_put_u32(out, rec[1])
	out.append_array(_md5(out))
	return out


# ------------------------------------------------------------- language API

static func read_language(path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return language_from_bytes(bytes)


static func language_from_bytes(bytes: PackedByteArray) -> int:
	var tree: Dictionary = decode(bytes)
	if tree.is_empty():
		return -1
	var option: Variant = _dict_get(tree, "option")
	if option == null:
		return -1
	var lang: Variant = _dict_get(option, "language")
	if lang == null:
		return -1
	var idx: int = -1
	match String(lang.get("k", "")):
		"float":
			idx = int(round(_bits_float(int(lang["bits"]))))
		"int":
			idx = int(lang["v"])
		_:
			return -1
	if idx < 0 or idx > 7:
		return -1
	return idx


static func _dict_get(node: Dictionary, key: String) -> Variant:
	if String(node.get("k", "")) != "dict":
		return null
	for pair: Array in node["items"]:
		var k: Dictionary = pair[0]
		if String(k.get("k", "")) == "str" and String(k["v"]) == key:
			return pair[1]
	return null


static func write_language(path: String, language_index: int) -> bool:
	_last_error = ""
	if language_index < 0 or language_index > 7:
		_last_error = "language index outside 0..7"
		return false
	var tree: Dictionary = {}
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			_last_error = "cannot open existing settings.dat"
			return false
		var bytes: PackedByteArray = f.get_buffer(f.get_length())
		f.close()
		tree = decode(bytes)
		if tree.is_empty():
			_last_error = "refusing to overwrite unparseable settings.dat: " + _last_error
			return false
		var option: Variant = _dict_get(tree, "option")
		if option == null:
			tree = default_tree(language_index)
		else:
			var lang: Variant = _dict_get(option, "language")
			if lang == null:
				option["items"].append([_str_node("language"), _float_node(float(language_index))])
			else:
				lang["k"] = "float"
				lang["bits"] = _float_bits(float(language_index))
				if lang.has("v"):
					lang.erase("v")
	else:
		tree = default_tree(language_index)
	var encoded: PackedByteArray = encode(tree)
	if encoded.is_empty():
		_last_error = "encode failed: " + _last_error
		return false
	if language_from_bytes(encoded) != language_index:
		_last_error = "encoded blob does not read back the requested language"
		return false
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		_last_error = "cannot open settings.dat for write"
		return false
	out.store_buffer(encoded)
	out.close()
	if read_language(path) != language_index:
		_last_error = "written settings.dat does not read back the requested language"
		return false
	return true


static func inspect(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "error": "missing"}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"exists": true, "error": "unreadable"}
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var doc: Dictionary = _parse(bytes)
	if doc.is_empty():
		return {"exists": true, "error": _last_error}
	var tree: Dictionary = _read_node(doc, 0, [0])
	return {"exists": true, "error": _last_error, "bytes": bytes.size(),
			"strings": (doc["strings"] as Array).size(), "records": (doc["recs"] as Array).size(),
			"language": language_from_bytes(bytes), "tree": tree}

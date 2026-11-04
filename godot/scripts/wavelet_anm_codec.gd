extends RefCounted
class_name WaveletAnmCodec

## Proven native KDF `waveletsample` decoder (bone position / bone rotation).
##
## Direct ARM evidence, libdefault.so
## sha256 1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70:
##   CWaveletDecoder<int,float>::UpdateToFrame    @ 0x00418aa0
##   CWaveletDecoder<short,float>::UpdateToFrame  @ 0x0041a914
##   CWaveletDecoder<int,float>::CWaveletDecoder  @ 0x0041932c  (scale/fields)
##   CWaveletPosCodec::CopyFrame                  @ 0x004189b4  (offset->GVec3)
##
## Layout of the sample `data` word array:
##   words[0 .. approximations-1]  root offsets; words[0] == approximations
##   at root offset R:
##     words[R]                    first node index
##     words[R+1 ..]              channel initial values (element_bytes each)
##   node streams:
##     internal node N: words[N], words[N+1] = child for sample bit 0/1,
##                      Huffman bits start at word N+2
##     leaf node N:     Huffman bits start at word N
##
## Huffman entries are four u32 words (left-aligned prefix, bit length, code
## count, first symbol). Symbols are int32 for 3-component tracks and int16 for
## 4-component tracks. Channels are bone-major: [i*components ..] belong to
## offsets[i]. Every deviation fails closed.

const REASON_TRACK: String = "wavelet-track-invalid"
const REASON_DATA: String = "wavelet-data-invalid"
const REASON_HUFFMAN: String = "wavelet-huffman-invalid"
const REASON_STREAM: String = "wavelet-stream-invalid"
const REASON_RANGE: String = "wavelet-sample-out-of-range"


static func f32(value: float) -> float:
    var buffer := PackedFloat32Array()
    buffer.append(value)
    return float(buffer[0])


static func s32(value: int) -> int:
    value &= 0xFFFFFFFF
    if value & 0x80000000:
        return value - 0x100000000
    return value


static func _is_int(value: Variant) -> bool:
    if typeof(value) == TYPE_INT:
        return true
    if typeof(value) == TYPE_FLOAT:
        var number: float = float(value)
        return number == floor(number) and absf(number) <= 9.0e15
    return false


static func _validate_entries(entries: Array) -> String:
    if entries.is_empty():
        return "huffman table is empty"
    var previous_end: int = 0
    var next_symbol: int = 0
    for ordinal in entries.size():
        var entry: Variant = entries[ordinal]
        if not (entry is Array) or entry.size() != 4:
            return "huffman entry is not four integers"
        for field in entry:
            if not _is_int(field):
                return "huffman entry field is not an integer"
        var prefix: int = int(entry[0])
        var length: int = int(entry[1])
        var count: int = int(entry[2])
        var start: int = int(entry[3])
        if length < 1 or length > 32 or count <= 0:
            return "huffman code length or count is invalid"
        if prefix < 0 or prefix > 0xFFFFFFFF:
            return "huffman prefix is out of range"
        var shift: int = 32 - length
        if prefix & ((1 << shift) - 1):
            return "huffman prefix is not left aligned"
        var end: int = prefix + (count << shift)
        if end > (1 << 32) or prefix < previous_end:
            return "huffman prefixes overlap or are out of order"
        if start != next_symbol:
            return "huffman symbol ranges are not contiguous"
        if length == 32:
            return "32-bit huffman code is unsupported"
        previous_end = end
        next_symbol += count
    return ""


static func _mask_start(sample_count: int) -> int:
    var value: int = sample_count - 1
    value |= value >> 1
    value |= value >> 2
    value |= value >> 4
    value |= value >> 8
    value |= value >> 16
    return (value + 1) >> 1


static func _root_bits(approximations: int, start: int) -> Array:
    var bits: int = 0
    var mask: int = start
    while (1 << bits) < approximations:
        mask >>= 1
        bits += 1
    return [bits, mask]


static func _stream_layout(words: Array, first: int, first_mask: int) -> Dictionary:
    ## All node header word addresses of one approximation (ascending).
    var headers: Array = []
    var pending: Array = [[first, first_mask]]
    var seen: Dictionary = {}
    while not pending.is_empty():
        var item: Array = pending.pop_back()
        var node: int = int(item[0])
        var mask: int = int(item[1])
        if node == 0:
            continue
        var key: String = "%d:%d" % [node, mask]
        if seen.has(key):
            continue
        seen[key] = true
        headers.append(node)
        if mask <= 1:
            continue
        if node < 0 or node + 1 >= words.size():
            return {"ok": false, "reason": REASON_DATA + ":internal node header is truncated"}
        for child in [int(words[node]), int(words[node + 1])]:
            if child != 0:
                if child < first or child >= words.size():
                    return {"ok": false, "reason": REASON_STREAM + ":child is outside the approximation"}
                pending.append([child, mask >> 1])
    headers.sort()
    return {"ok": true, "headers": headers}


static func _bit_window(words: Array, start: int, position: int) -> int:
    var index: int = start + (position >> 5)
    var offset: int = position & 31
    if index < 0 or index >= words.size():
        return -1
    var current: int = (int(words[index]) << offset) & 0xFFFFFFFF
    if offset != 0:
        var following: int = 0
        if index + 1 < words.size():
            following = int(words[index + 1]) & 0xFFFFFFFF
        current |= following >> (32 - offset)
    return current & 0xFFFFFFFF


static func _symbol(words: Array, start: int, position: int, entries: Array,
                    symbols: Array) -> Array:
    ## Returns [symbol, length] or an empty array on failure.
    var window: int = _bit_window(words, start, position)
    if window < 0:
        return []
    var ordinal: int = -1
    for index in entries.size():
        var prefix: int = int(entries[index][0])
        if prefix <= window:
            ordinal = index
        else:
            break
    if ordinal < 0:
        return []
    var entry: Array = entries[ordinal]
    var length: int = int(entry[1])
    var code_start: int = int(entry[3])
    var code: int = code_start + ((window - int(entry[0])) >> (32 - length))
    if code < 0 or code >= symbols.size():
        return []
    return [int(symbols[code]), length]


static func _initial_values(words: Array, root: int, channels: int,
                            element_bytes: int) -> Array:
    var values: Array = []
    if element_bytes == 4:
        for index in channels:
            values.append(s32(int(words[root + 1 + index])))
    else:
        for index in channels:
            var word: int = int(words[root + 1 + (index >> 1)])
            var half: int = (word >> ((index & 1) * 16)) & 0xFFFF
            if half & 0x8000:
                half -= 0x10000
            values.append(half)
    return values


static func decode(track: Dictionary) -> Dictionary:
    ## Decode every frame of a `waveletsample` track.
    ##
    ## track fields: data_words, huffman_entries, huffman_symbols,
    ## sample_count, approximations, channels, components, element_bytes,
    ## radix.  Returns {ok, keys, frames, channels, components,
    ## nonzero_padding_streams, reason}.
    if not (track is Dictionary):
        return {"ok": false, "reason": REASON_TRACK}
    var words: Variant = track.get("data_words", null)
    var entries: Variant = track.get("huffman_entries", null)
    var symbols: Variant = track.get("huffman_symbols", null)
    if not (words is Array) or not (entries is Array) or not (symbols is Array):
        return {"ok": false, "reason": REASON_TRACK + ":arrays-required"}
    if int(track.get("components", 0)) not in [3, 4]:
        return {"ok": false, "reason": REASON_TRACK + ":components"}
    var components: int = int(track["components"])
    var element_bytes: int = int(track.get("element_bytes", 0))
    if (components == 3 and element_bytes != 4) or (components == 4 and element_bytes != 2):
        return {"ok": false, "reason": REASON_TRACK + ":element-bytes"}
    var channels: int = int(track.get("channels", 0))
    if channels <= 0 or channels % components != 0:
        return {"ok": false, "reason": REASON_TRACK + ":channels"}
    var sample_count: int = int(track.get("sample_count", 0))
    if sample_count <= 0:
        return {"ok": false, "reason": REASON_TRACK + ":sample-count"}
    var approximations: int = int(track.get("approximations", 0))
    if approximations <= 0 or approximations > words.size():
        return {"ok": false, "reason": REASON_DATA + ":approximation-count"}
    var radix: int = int(track.get("radix", -1))
    if radix < 0 or radix > 30:
        return {"ok": false, "reason": REASON_TRACK + ":radix"}
    for word in words:
        if not _is_int(word) or int(word) < 0 or int(word) > 0xFFFFFFFF:
            return {"ok": false, "reason": REASON_DATA + ":word"}
    for symbol in symbols:
        if not _is_int(symbol):
            return {"ok": false, "reason": REASON_HUFFMAN + ":symbol"}
    var entry_error: String = _validate_entries(entries)
    if not entry_error.is_empty():
        return {"ok": false, "reason": REASON_HUFFMAN + ":" + entry_error}
    var covered_symbols: int = 0
    for entry in entries:
        covered_symbols += int(entry[2])
    if covered_symbols != symbols.size():
        return {"ok": false, "reason": REASON_HUFFMAN + ":symbol-count"}
    if int(words[0]) != approximations:
        return {"ok": false, "reason": REASON_DATA + ":root-table"}
    var roots: Array = []
    for index in approximations:
        roots.append(int(words[index]))
    for index in range(1, roots.size()):
        if int(roots[index]) <= int(roots[index - 1]):
            return {"ok": false, "reason": REASON_DATA + ":root-order"}
    if int(roots[roots.size() - 1]) >= words.size():
        return {"ok": false, "reason": REASON_DATA + ":root-range"}

    var first_mask: int = int(_root_bits(approximations, _mask_start(sample_count))[1])
    var root_bits: int = int(_root_bits(approximations, _mask_start(sample_count))[0])
    var start_mask: int = _mask_start(sample_count)
    var scale: float = (f32(1.0 / float(1 << radix)) if radix != 0 else 0.0)
    var layouts: Dictionary = {}
    var region_end: Dictionary = {}
    for index in roots.size():
        var root: int = int(roots[index])
        region_end[root] = (int(roots[index + 1]) if index + 1 < roots.size()
                            else words.size())
        if int(words[root]) == 0:
            layouts[root] = []
            continue
        var first: int = root + 1 + ((channels * element_bytes + 3) >> 2)
        if first > words.size():
            return {"ok": false, "reason": REASON_DATA + ":first-node"}
        if int(words[root]) != first:
            return {"ok": false, "reason": REASON_DATA + ":first-node"}
        var layout: Dictionary = _stream_layout(words, first, first_mask)
        if not bool(layout["ok"]):
            return layout
        layouts[root] = layout["headers"]

    var keys: Array = []
    var raw_pairs: Array = []
    var streams: Dictionary = {}
    var total_pairs: int = (sample_count + 1) >> 1
    for pair in total_pairs:
        var frame: int = pair * 2
        var mask: int = start_mask
        var root_index: int = 0
        for _bit in root_bits:
            root_index = (root_index << 1) | (1 if frame & mask else 0)
            mask >>= 1
        if root_index >= approximations:
            return {"ok": false, "reason": REASON_RANGE + ":approximation"}
        var root: int = int(roots[root_index])
        var state: Array = []
        for value in _initial_values(words, root, channels, element_bytes):
            state.append([0, int(value)])
        var active: Array = []
        for channel in channels:
            active.append(channel)
        var result: Array = []
        result.resize(channels)
        var node: int = int(words[root])
        mask = first_mask
        while mask > 1 and not active.is_empty():
            if node == 0:
                break
            if node + 1 >= words.size():
                return {"ok": false, "reason": REASON_DATA + ":internal-node"}
            var branch: int = 1 if (frame & mask) else 0
            var bits_start: int = node + 2
            var bits_end: int = int(region_end[root])
            for header in layouts[root]:
                if int(header) > bits_start:
                    bits_end = int(header)
                    break
            var position: int = 0
            var remaining: Array = []
            for channel in active:
                var symbol_result: Array = _symbol(words, bits_start, position,
                                                   entries, symbols)
                if symbol_result.is_empty():
                    return {"ok": false, "reason": REASON_STREAM + ":huffman-code"}
                var symbol: int = int(symbol_result[0])
                var length: int = int(symbol_result[1])
                position += length
                if bits_start * 32 + position > bits_end * 32:
                    return {"ok": false, "reason": REASON_STREAM + ":code-crosses-boundary"}
                state[channel][branch] = s32(int(state[channel][branch]) + symbol)
                if symbol == 0:
                    if bits_start * 32 + position + 1 > bits_end * 32:
                        return {"ok": false, "reason": REASON_STREAM + ":control-crosses-boundary"}
                    var window: int = _bit_window(words, bits_start, position)
                    if window < 0:
                        return {"ok": false, "reason": REASON_STREAM + ":control-crosses-boundary"}
                    var stop_bit: int = (window >> 31) & 1
                    position += 1
                    if stop_bit == 1:
                        var constant: float = f32(f32(float(
                            s32(int(state[channel][1]) - int(state[channel][0])))) * scale)
                        result[channel] = [constant, constant]
                        continue
                remaining.append(channel)
            if not _record_stream(streams, bits_start, position, "internal", root):
                return {"ok": false, "reason": REASON_STREAM + ":shared-stream"}
            active = remaining
            node = int(words[node + branch])
            mask >>= 1
        if not active.is_empty() and node != 0 and mask <= 1:
            var bits_start: int = node
            var bits_end: int = int(region_end[root])
            for header in layouts[root]:
                if int(header) > bits_start:
                    bits_end = int(header)
                    break
            var position: int = 0
            for channel in active:
                var symbol_result: Array = _symbol(words, bits_start, position,
                                                   entries, symbols)
                if symbol_result.is_empty():
                    return {"ok": false, "reason": REASON_STREAM + ":huffman-code"}
                var symbol: int = int(symbol_result[0])
                var length: int = int(symbol_result[1])
                position += length
                if bits_start * 32 + position > bits_end * 32:
                    return {"ok": false, "reason": REASON_STREAM + ":code-crosses-boundary"}
                var difference: int = s32(int(state[channel][1]) - int(state[channel][0]))
                result[channel] = [
                    f32(f32(float(s32(difference - symbol))) * scale),
                    f32(f32(float(s32(difference + symbol))) * scale),
                ]
            if not _record_stream(streams, bits_start, position, "leaf", root):
                return {"ok": false, "reason": REASON_STREAM + ":shared-stream"}
        else:
            for channel in active:
                var constant: float = f32(f32(float(
                    s32(int(state[channel][1]) - int(state[channel][0])))) * scale)
                result[channel] = [constant, constant]
        for channel in channels:
            if result[channel] == null:
                return {"ok": false, "reason": REASON_STREAM + ":missing-channel"}
        raw_pairs.append(result)
        for side in 2:
            if frame + side >= sample_count:
                break
            var vectors: Array = []
            for bone in range(0, channels, components):
                var vector: Array = []
                for component in components:
                    vector.append(float(result[bone + component][side]))
                vectors.append(vector)
            keys.append(vectors)
    var nonzero_padding: int = 0
    for start in streams.size():
        var stream: Dictionary = streams[streams.keys()[start]]
        var end: int = int(region_end[stream["root"]])
        for header in layouts[stream["root"]]:
            if int(header) > int(stream["start"]):
                end = int(header)
                break
        if int(stream["bits"]) > (end - int(stream["start"])) * 32:
            return {"ok": false, "reason": REASON_STREAM + ":overrun"}
        if _tail_is_zero(words, int(stream["start"]), int(stream["bits"]), end):
            continue
        nonzero_padding += 1
    return {
        "ok": true,
        "keys": keys,
        "frames": keys.size(),
        "channels": channels,
        "components": components,
        "scale": scale,
        "nonzero_padding_streams": nonzero_padding,
        "streams": streams.size(),
    }


static func _record_stream(streams: Dictionary, start: int, bits: int,
                           kind: String, root: int) -> bool:
    var key: String = str(start)
    if streams.has(key):
        return (int(streams[key]["bits"]) == bits
                and String(streams[key]["kind"]) == kind
                and int(streams[key]["root"]) == root)
    streams[key] = {"start": start, "bits": bits, "kind": kind, "root": root}
    return true


static func _tail_is_zero(words: Array, start: int, bits: int, end: int) -> bool:
    var absolute: int = start * 32 + bits
    if absolute >= end * 32:
        return true
    var index: int = absolute >> 5
    var offset: int = absolute & 31
    if int(words[index]) & ((1 << (32 - offset)) - 1):
        return false
    for word in range(index + 1, end):
        if int(words[word]) != 0:
            return false
    return true

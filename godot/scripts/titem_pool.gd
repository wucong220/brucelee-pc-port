extends RefCounted
class_name TItemPool

## Recovered krm::krt::CHStrMgr::TItem lifetime / ownership (read-only evidence).
##
## Native evidence (libdefault.so sha256 1da7a30c...), Ghidra project addresses:
##   CHStrMgr::GetItem(char const*, bool)          @ 0x150220
##     -> ComputeCRC32NS -> ComputeCRC32Lower  @ 0x1508fc / 0x15096c
##   CHStrMgr::GetItemCommon                  @ 0x150008
##   CHStrMgr::SearchNoSensitive            @ 0x14fa18
##   CHStrMgr::AddItemAndPointToItself     @ 0x14ff24
##   CHStrMgr::AddItemAndPointToObj        @ 0x14ff88
##   CHStrMgr::RemoveItem(TItem*)          @ 0x14fbbc
##   CHStrMgr::RemoveRef(TItem*)           @ 0x17816c (and 14 clones)
##   manipulator<TFighterActionRecord>::createcopy @ 0x188028
##   manipulator<TFighterActionRecord>::destroy    @ 0x18b294
##
## Proven TItem facts (direct disassembly, not inferred):
##   +0x00 uint  intern hash (CRC32 of lowercased ASCII); bucket = hash & 0x3ffff
##   +0x04 char* string data (freed by mem::Free on RemoveItem)
##   +0x08 uint  size class (<8 / <0x10 / <0x20 / else -> pool free fn)
##   +0x0c int   REFERENCE COUNT. Copy/addref = +1; release = -1.
##   +0x14 TItem* parent (suffix sharing); RemoveItem releases it recursively.
##   +0x18 byte  self/parent flag
##   +0x1c/+0x20 global LRU list links
##   +0x24.. inline short-string storage / pool bookkeeping
##   RemoveItem() unlinks from bucket + global list, releases +0x14, frees
##   +0x04 and returns the item to its size-classed objectPool. Two static
##   singleton items are never freed (RemoveItem returns immediately).
##
##   createcopy() copies the 0x2c record and does `item->refs++`  => the record
##   OWNS one strong reference. destroy() does `item->refs--` and calls
##   RemoveItem at zero                                          => releasing the
##   record drops that reference.
##   SetAnimation @ 0x1b6e94 addrefs the caller's HashString item into the stack
##   record, calls createcopy (addref), then releases the stack copy.
##   SetReplayCurrentTime @ 0x1b4480 / RecordReplayUpdate @ 0x1b8db8 addref the
##   record's item for the duration of the SetAnimationFrame/SetAnimation call
##   and release it after (RemoveItem when the count reaches zero).
##
## => A TItem pointer stays valid for exactly as long as at least one strong
##    reference is held. The record itself is one such owner. It is an interned,
##    pool-allocated PROCESS-LOCAL address: it is NOT stable across runs and must
##    NEVER be serialized. Persistence across processes must use the interned
##    string / explicit handle table; this module enforces that (fail closed).

const HASH_MASK: int = 0x3FFFF
const BUCKET_COUNT: int = 0x40000
const REFCOUNT_OFFSET_NATIVE: int = 0x0C
const HASH_OFFSET_NATIVE: int = 0x00
const PARENT_OFFSET_NATIVE: int = 0x14

const REASON_DANGLING: String = "dangling-titem"
const REASON_EMPTY: String = "empty-animation-name"
const REASON_NOT_IN_TABLE: String = "unknown-animation-handle"
const REASON_POINTER_SERIALIZATION: String = "pointer-serialization-refused"

var _items: Dictionary = {}          # int id -> item dictionary
var _buckets: Dictionary = {}        # int bucket -> Array[int]
var _next_id: int = 1
var _static_empty: int = 0
var freed_count: int = 0
var last_error: String = ""


func _init() -> void:
    # Native CHStrMgr has static singleton items that RemoveItem never frees.
    _static_empty = _allocate("", 0, 0, -1)
    _items[_static_empty]["static"] = true
    _items[_static_empty]["refs"] = 1


static func crc_table_entry(index: int) -> int:
    ## Standard CRC32 table (verified byte-for-byte against native
    ## gCRC32Table @ elf 0x5b7490 by validate_titem_persistence.gd).
    var c: int = index & 0xFF
    for _k in 8:
        if (c & 1) != 0:
            c = ((c >> 1) ^ 0xEDB88320) & 0xFFFFFFFF
        else:
            c = (c >> 1) & 0xFFFFFFFF
    return c


static func crc32_lower(text: String) -> int:
    ## Native ComputeCRC32Lower(char const*, uint&): CRC32 over lowercased bytes.
    ## gLowerTable @ elf 0x5b7410 maps ASCII A-Z to a-z (verified from ELF data).
    var crc: int = 0xFFFFFFFF
    var bytes: PackedByteArray = text.to_lower().to_ascii_buffer()
    for b in bytes:
        var low: int = b
        if low >= 65 and low <= 90:
            low += 32
        crc = ((crc >> 8) ^ crc_table_entry((low ^ (crc & 0xFF)) & 0xFF)) & 0xFFFFFFFF
    return (~crc) & 0xFFFFFFFF


static func bucket_of(hash_value: int) -> int:
    return hash_value & HASH_MASK


func _allocate(name: String, hash_value: int, length: int, parent: int) -> int:
    var id: int = _next_id
    _next_id += 1
    _items[id] = {
        "name": name,
        "hash": hash_value,
        "length": length,
        "refs": 0,
        "parent": parent,
        "static": false,
        "alive": true,
    }
    var bucket: int = bucket_of(hash_value)
    if not _buckets.has(bucket):
        _buckets[bucket] = [] as Array[int]
    (_buckets[bucket] as Array).append(id)
    if parent >= 0:
        addref(parent)   # AddItemAndPointToObj: parent->refs++ (0x14ff88)
    return id


func intern(name: String) -> int:
    ## GetItemCommon / SearchNoSensitive: bucket by (hash & 0x3ffff), compare
    ## hash + length + string. Case-sensitive match wins; otherwise a
    ## case-insensitive match becomes the parent of a new item.
    last_error = ""
    if name.is_empty():
        return _static_empty
    var hash_value: int = crc32_lower(name)
    var length: int = name.to_ascii_buffer().size()
    var bucket: int = bucket_of(hash_value)
    var ids: Array = _buckets.get(bucket, [])
    for id in ids:
        var item: Dictionary = _items.get(id, {})
        if item.is_empty() or not item["alive"] or item["static"]:
            continue
        if int(item["hash"]) == hash_value and int(item["length"]) == length \
                and String(item["name"]) == name:
            return int(id)
    for id in ids:
        var item2: Dictionary = _items.get(id, {})
        if item2.is_empty() or not item2["alive"] or item2["static"]:
            continue
        if int(item2["hash"]) == hash_value and int(item2["length"]) == length \
                and String(item2["name"]).to_lower() == name.to_lower():
            return _allocate(name, hash_value, length, int(id))
    return _allocate(name, hash_value, length, -1)


func is_alive(id: int) -> bool:
    var item: Dictionary = _items.get(id, {})
    return not item.is_empty() and bool(item["alive"])


func addref(id: int) -> bool:
    ## HashString copy / record createcopy: `item->refs++` at +0x0c.
    if not is_alive(id):
        last_error = "%s: %d" % [REASON_DANGLING, id]
        return false
    _items[id]["refs"] = int(_items[id]["refs"]) + 1
    return true


func release(id: int) -> bool:
    ## HashString destructor / record destroy / RemoveRef: `--refs`, and at zero
    ## CHStrMgr::RemoveItem(mgr, item).
    if not is_alive(id):
        last_error = "%s: %d" % [REASON_DANGLING, id]
        return false
    if bool(_items[id]["static"]):
        return true
    var refs: int = int(_items[id]["refs"]) - 1
    _items[id]["refs"] = refs
    if refs <= 0:
        _remove_item(id)
    return true


func _remove_item(id: int) -> void:
    if not is_alive(id) or bool(_items[id]["static"]):
        return
    var item: Dictionary = _items[id]
    var parent: int = int(item["parent"])
    if parent >= 0 and parent != id:
        release(parent)                       # RemoveItem releases +0x14 parent
    var bucket: int = bucket_of(int(item["hash"]))
    if _buckets.has(bucket):
        (_buckets[bucket] as Array).erase(id) # unlink from bucket chain
    item["alive"] = false                     # mem::Free(+0x04) + pool free
    _items[id] = item
    freed_count += 1


func refs_of(id: int) -> int:
    if not is_alive(id):
        return -1
    return int(_items[id]["refs"])


func name_of(id: int) -> String:
    if not is_alive(id):
        last_error = "%s: %d" % [REASON_DANGLING, id]
        return ""
    return String(_items[id]["name"])


func hash_of(id: int) -> int:
    if not is_alive(id):
        return -1
    return int(_items[id]["hash"])


func parent_of(id: int) -> int:
    if not is_alive(id):
        return -1
    return int(_items[id]["parent"])


func live_count() -> int:
    var n: int = 0
    for id in _items.keys():
        if is_alive(int(id)):
            n += 1
    return n


## HashString construction: intern + one strong reference.
func new_hash_string(name: String) -> int:
    var id: int = intern(name)
    if not addref(id):
        return -1
    return id


## Record createcopy: the 0x2c record owns one strong reference.
func record_create_copy(id: int) -> bool:
    return addref(id)


## Record destroy: releases the reference; zero -> RemoveItem.
func record_destroy(id: int) -> bool:
    return release(id)


## Persistence bridge: serialize the INTERNED STRING, never the pointer id.
## The native pointer is a process-local pool address and is not reproducible.
func persist_name(id: int) -> String:
    last_error = ""
    if not is_alive(id):
        last_error = "%s: %d" % [REASON_DANGLING, id]
        return ""
    return name_of(id)


func refuse_pointer_serialization(_id: int) -> bool:
    last_error = REASON_POINTER_SERIALIZATION
    return false

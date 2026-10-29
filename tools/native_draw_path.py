#!/usr/bin/env python3
"""Verify the recorded scene-object draw path in the known local ELF."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from native_hierarchy_links import HierarchyLinkError, file_offset

_SHA256 = "1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70"
_WORDS = {
    0x0036E1FC: 0xEBF6E2DA,
    0x0036E480: 0xEBF6E239,
    0x00307598: 0xEBF86AF7,
    0x0032D6FC: 0xEBF7FD88,
    0x0032D710: 0xEBF7EE05,
    0x0032D774: 0xEBF7EDEC,
    0x0032D348: 0xEBF7C61D,
    0x0032D46C: 0xEBF7C5D4,
    0x0032D534: 0xEBF7C5A2,
    0x0032D580: 0xEBF7C58F,
    0x0033BCF4: 0xEBF7A400,
    0x003162EC: 0xEBF844B7,
    0x00316758: 0xEBF8439C,
    0x00316848: 0xEBF847F5,
}
_DRAW_RELOCATIONS = {
    0x006004CC: "glDrawElements",
    0x00600AE8: "glDrawArrays",
}


def _dynamic_symbols(elf: bytes) -> dict[int, str]:
    e_shoff = struct.unpack_from("<I", elf, 32)[0]
    e_shentsize, e_shnum, e_shstrndx = struct.unpack_from("<HHH", elf, 46)
    if e_shentsize < 40 or e_shoff + e_shnum * e_shentsize > len(elf):
        raise HierarchyLinkError("ELF section headers are truncated")

    def header(index: int) -> tuple[int, ...]:
        return struct.unpack_from("<IIIIIIIIII", elf, e_shoff + index * e_shentsize)

    names = header(e_shstrndx)
    name_base = names[4]

    def section_name(offset: int) -> bytes:
        end = elf.index(b"\x00", name_base + offset)
        return elf[name_base + offset:end]

    sections = {}
    for index in range(e_shnum):
        item = header(index)
        sections[section_name(item[0])] = item
    dynsym = sections[b".dynsym"]
    dynstr_off = sections[b".dynstr"][4]
    rel = sections[b".rel.plt"]
    result = {}
    for index in range(rel[5] // 8):
        address, info = struct.unpack_from("<II", elf, rel[4] + index * 8)
        name_off = struct.unpack_from("<I", elf, dynsym[4] + (info >> 8) * dynsym[9])[0]
        end = elf.index(b"\x00", dynstr_off + name_off)
        result[address] = elf[dynstr_off + name_off:end].decode("ascii", "replace")
    return result


def verify_bytes(elf: bytes) -> None:
    if hashlib.sha256(elf).hexdigest() != _SHA256:
        raise HierarchyLinkError("ELF SHA-256 does not match the recorded libdefault.so")
    for address, expected in _WORDS.items():
        offset = file_offset(elf, address)
        actual = struct.unpack_from("<I", elf, offset)[0]
        if actual != expected:
            raise HierarchyLinkError(
                f"instruction 0x{address:08x} is 0x{actual:08x}, expected 0x{expected:08x}"
            )
    symbols = _dynamic_symbols(elf)
    for address, expected in _DRAW_RELOCATIONS.items():
        actual = symbols.get(address)
        if actual != expected:
            raise HierarchyLinkError(
                f"relocation 0x{address:08x} is {actual!r}, expected {expected!r}"
            )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elf", type=Path, help="local libdefault.so")
    args = parser.parse_args()
    try:
        verify_bytes(args.elf.read_bytes())
    except (OSError, HierarchyLinkError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(f"verified {len(_WORDS)} draw-path instructions and 2 draw relocations")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

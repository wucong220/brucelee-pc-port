#!/usr/bin/env python3
"""Check CHierarchyNode link-field instructions in the known local ELF.

The checker reads the ELF program headers and compares instruction words. It
does not disassemble, modify, or copy the original library.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import struct
import sys

_SHA256 = "1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70"
_WORDS = {
    0x003C0E80: 0xE3A02000,
    0x003C0E84: 0xE58C30C8,
    0x003C0E90: 0xE58C20B4,
    0x003C0E9C: 0xE58C20B8,
    0x003C0EAC: 0xE58C20BC,
    0x003C0EB4: 0xE58C20C0,
    0x003C0EBC: 0xE58C20C4,
    0x003C1608: 0xE59530BC,
    0x003C160C: 0xE58540BC,
    0x003C1614: 0x058540B8,
    0x003C1618: 0x158430C4,
    0x003C1620: 0x158420C0,
    0x003C1624: 0x158340C0,
    0x003C1634: 0xE58450B4,
    0x003C1D78: 0xE59030B4,
    0x003C1D90: 0xE59530C4,
    0x003C1DAC: 0x158320C0,
    0x003C1DB4: 0x058120B8,
    0x003C1DBC: 0xE58570C0,
    0x003C1DC0: 0x158230C4,
    0x003C1DC8: 0xE58570C4,
    0x003C1DCC: 0xE58570B4,
    0x003C1DD0: 0x058230BC,
    0x0035BA10: 0xE3530206,
    0x0035BA60: 0xE153000A,
    0x0035BF70: 0xEBF70D74,
    0x0035B420: 0xEBF73F52,
    0x0035C2E4: 0xEBF73853,
}
_CHILD_RELOCATION = (0x00603548, "gid_Childs")


class HierarchyLinkError(ValueError):
    """The local ELF does not match the recorded hierarchy instructions."""


def file_offset(elf: bytes, address: int) -> int:
    if elf[:4] != b"\x7fELF" or len(elf) < 52 or elf[4] != 1 or elf[5] != 1:
        raise HierarchyLinkError("expected a little-endian ELF32")
    phoff = struct.unpack_from("<I", elf, 28)[0]
    phentsize, phnum = struct.unpack_from("<HH", elf, 42)
    if phentsize < 32 or phoff + phnum * phentsize > len(elf):
        raise HierarchyLinkError("ELF program headers are truncated")
    for index in range(phnum):
        entry = phoff + index * phentsize
        p_type, p_offset, p_vaddr, _paddr, p_filesz = struct.unpack_from("<IIIII", elf, entry)
        if p_type == 1 and p_vaddr <= address < p_vaddr + p_filesz:
            return p_offset + (address - p_vaddr)
    raise HierarchyLinkError(f"address 0x{address:08x} is outside loadable file bytes")



def _section(elf: bytes, name: bytes) -> tuple[int, int, int, int, int]:
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

    found = None
    for index in range(e_shnum):
        item = header(index)
        if section_name(item[0]) == name:
            found = item
            break
    if found is None:
        raise HierarchyLinkError(f"ELF section {name.decode()} is missing")
    return found[4], found[5], found[6], found[9], name_base


def verify_child_relocation(elf: bytes) -> None:
    address, expected = _CHILD_RELOCATION
    rel_off, rel_size, _link, _entsize, _names = _section(elf, b".rel.dyn")
    dynsym_off, _size, dynsym_link, dynsym_entsize, _names = _section(elf, b".dynsym")
    dynstr_off = _section(elf, b".dynstr")[0]
    if dynsym_entsize < 16 or rel_size % 8:
        raise HierarchyLinkError("unexpected dynamic symbol or relocation layout")
    for index in range(rel_size // 8):
        rel_address, info = struct.unpack_from("<II", elf, rel_off + index * 8)
        if rel_address != address:
            continue
        name_off = struct.unpack_from("<I", elf, dynsym_off + (info >> 8) * dynsym_entsize)[0]
        end = elf.index(b"\x00", dynstr_off + name_off)
        symbol = elf[dynstr_off + name_off:end].decode("ascii", "replace")
        if expected not in symbol:
            raise HierarchyLinkError(f"relocation 0x{address:08x} targets {symbol}")
        return
    raise HierarchyLinkError(f"relocation 0x{address:08x} was not found")

def verify_bytes(elf: bytes) -> None:
    digest = hashlib.sha256(elf).hexdigest()
    if digest != _SHA256:
        raise HierarchyLinkError("ELF SHA-256 does not match the recorded libdefault.so")
    for address, expected in _WORDS.items():
        offset = file_offset(elf, address)
        if offset + 4 > len(elf):
            raise HierarchyLinkError(f"instruction 0x{address:08x} is truncated")
        actual = struct.unpack_from("<I", elf, offset)[0]
        if actual != expected:
            raise HierarchyLinkError(
                f"instruction 0x{address:08x} is 0x{actual:08x}, expected 0x{expected:08x}"
            )
    verify_child_relocation(elf)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elf", type=Path, help="local libdefault.so")
    args = parser.parse_args()
    try:
        verify_bytes(args.elf.read_bytes())
    except (OSError, HierarchyLinkError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(f"verified {len(_WORDS)} hierarchy instruction words and gid_Childs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

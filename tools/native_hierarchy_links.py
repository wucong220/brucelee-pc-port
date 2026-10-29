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
}


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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elf", type=Path, help="local libdefault.so")
    args = parser.parse_args()
    try:
        verify_bytes(args.elf.read_bytes())
    except (OSError, HierarchyLinkError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(f"verified {len(_WORDS)} hierarchy instruction words")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

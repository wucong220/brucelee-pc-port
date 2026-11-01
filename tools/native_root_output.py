#!/usr/bin/env python3
"""Verify the GetOutput sample-to-output instructions in the known ELF."""
from __future__ import annotations

import argparse
import hashlib
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from native_hierarchy_links import HierarchyLinkError, _section, file_offset
from native_root_motion import _SHA256


# The root output object stores a three-float sample at +0xc/+0x10/+0x14
# before applying the rotation/scale transform. This verifies instruction
# identity only; the ANM property-to-sample binding remains a separate claim.
_WORDS = {
    0x00407B34: 0xE284500C,  # add r5, r4, #0xc
    0x00407B38: 0xE0827107,  # add r7, r2, r7, lsl #2
    0x00407B44: 0xE8970007,  # ldm r7, {r0, r1, r2}
    0x00407B50: 0xE8850007,  # stm r5, {r0, r1, r2}
    0x00407C94: 0xEDC44A05,  # vstr s9, [r4, #0x14]
    0x00407CB0: 0xED845A04,  # vstr s10, [r4, #0x10]
    0x00407CB4: 0xEDC45A03,  # vstr s11, [r4, #0xc]
}

_SYMBOL = "_ZN3krm3anm15CRootPlayerBase9GetOutputERKNS0_10CAnimStateE"
_SYMBOL_ADDRESS = 0x00407A04
_SYMBOL_SIZE = 936


def _symbol_table(elf: bytes) -> dict[str, tuple[int, int]]:
    table = _section(elf, b".symtab")
    strings = _section(elf, b".strtab")[0]
    offset, size, _link, entry_size, _names = table
    if entry_size < 16:
        raise HierarchyLinkError("unexpected symbol table entry size")
    result: dict[str, tuple[int, int]] = {}
    for index in range(size // entry_size):
        entry = offset + index * entry_size
        name_offset, value, symbol_size = struct.unpack_from("<III", elf, entry)
        if name_offset == 0:
            continue
        end = elf.index(b"\x00", strings + name_offset)
        name = elf[strings + name_offset:end].decode("ascii", "replace")
        result[name] = (value, symbol_size)
    return result


def verify_bytes(elf: bytes) -> dict:
    if hashlib.sha256(elf).hexdigest() != _SHA256:
        raise HierarchyLinkError("ELF SHA-256 does not match the recorded libdefault.so")
    for address, expected in _WORDS.items():
        actual = struct.unpack_from("<I", elf, file_offset(elf, address))[0]
        if actual != expected:
            raise HierarchyLinkError(
                f"instruction 0x{address:08x} is 0x{actual:08x}, "
                f"expected 0x{expected:08x}"
            )
    symbols = _symbol_table(elf)
    if symbols.get(_SYMBOL) != (_SYMBOL_ADDRESS, _SYMBOL_SIZE):
        raise HierarchyLinkError("CRootPlayerBase::GetOutput symbol is not the recorded function")
    return {
        "function": _SYMBOL,
        "address": _SYMBOL_ADDRESS,
        "size": _SYMBOL_SIZE,
        "sample_load": "0x00407B44 ldm r7, {r0, r1, r2}",
        "sample_store": "0x00407B50 stm r5, {r0, r1, r2}; r5 = r4 + 0xc",
        "output_offsets": [0xC, 0x10, 0x14],
        "scope": "instruction identity only; ANM property-to-sample binding remains unverified",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elf", type=Path)
    args = parser.parse_args()
    try:
        result = verify_bytes(args.elf.read_bytes())
    except (OSError, HierarchyLinkError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(
        "verified root output sample path: "
        f"{result['function']} at 0x{result['address']:08x}, "
        f"output offsets 0x{result['output_offsets'][0]:x}/"
        f"0x{result['output_offsets'][1]:x}/0x{result['output_offsets'][2]:x}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

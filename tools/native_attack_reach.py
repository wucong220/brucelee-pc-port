#!/usr/bin/env python3
"""Verify the recovered native attack-reach data flow in libdefault.so."""
from __future__ import annotations

import argparse
import hashlib
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from native_hierarchy_links import HierarchyLinkError, file_offset


_SHA256 = "1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70"
_WORDS = {
    0x0017DB40: 0xEDD57A1F,  # vldr s15,[config,#0x80]
    0x0017DB60: 0xEDC47A57,  # vstr s15,[fighter,#0x15c]
    0x001FFAD0: 0xEBFCB4C0,  # bl GetCharacterDisplacementMultiplier
    0x001FFAE0: 0xEBFCA3A0,  # bl GetCharacterRadiusMultiplier
    0x001FFAF0: 0xE5840080,  # str r0,[config,#0x80]
    0x0019E2B8: 0x03A085FE,  # moveq r8,#0x3f800000 (default radius scale 1.0)
    0x001A03E0: 0xED947A57,  # vldr s14,[fighter,#0x15c]
    0x001A03E4: 0xEDD07A2F,  # vldr s15,[animation,#0xbc]
    0x001A03E8: 0xEE676A27,  # vmul.f32 s13,s14,s15
    0x0022ED48: 0xE59F13DC,  # ldr r1, literal for "radius"
    0x0022ED50: 0xE7940006,  # ldr r0,[r4,r6]
    0x0022ED60: 0xE2811040,  # add r1,r1,#0x40
    0x0022ED90: 0xE59D34C0,  # ldr r3,[sp,#0x4c0] value node
    0x0022ED98: 0xEDD37A01,  # vldr s15,[r3,#4]
    0x0022ED9C: 0xEDC57A2F,  # vstr s15,[animation-descr,#0xbc]
    0x001A42FC: 0xEDD37A57,  # vldr s15,[attacker,#0x15c]
    0x001A4304: 0xE5933164,  # ldr r3,[attacker,#0x164] current impact
    0x001A4308: 0xED937A04,  # vldr s14,[impact,#0x10] attack radius
    0x001A430C: 0xEE278A27,  # vmul.f32 s16,s14,s15
    0x001A4310: 0xEBFDEE7B,  # bl GetRadius(defender)
    0x001A4318: 0xEE388A27,  # vadd.f32 s16,s16,s15
    0x001A431C: 0xEEF48AC8,  # vcmpe.f32 distance,reach
    0x001A4324: 0xDA000016,  # ble when distance <= reach
}
_RADIUS_STRING_ADDRESS = 0x005BDD14


def verify_bytes(elf: bytes) -> None:
    if hashlib.sha256(elf).hexdigest() != _SHA256:
        raise HierarchyLinkError("ELF SHA-256 does not match the recorded libdefault.so")
    for address, expected in _WORDS.items():
        actual = struct.unpack_from("<I", elf, file_offset(elf, address))[0]
        if actual != expected:
            raise HierarchyLinkError(
                f"instruction 0x{address:08x} is 0x{actual:08x}, "
                f"expected 0x{expected:08x}"
            )
    string_offset = file_offset(elf, _RADIUS_STRING_ADDRESS)
    if elf[string_offset:string_offset + 7] != b"radius\x00":
        raise HierarchyLinkError(
            f"literal at 0x{_RADIUS_STRING_ADDRESS:08x} is not the radius key"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elf", type=Path)
    args = parser.parse_args()
    try:
        verify_bytes(args.elf.read_bytes())
    except (OSError, HierarchyLinkError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(f"verified {len(_WORDS)} native attack-reach instructions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

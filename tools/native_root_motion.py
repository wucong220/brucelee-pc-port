#!/usr/bin/env python3
"""Verify the native root-displacement animation transform path."""
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
    0x001A83B0: 0xEBFDDBAA,  # bl CFighter::UpdatePositionWithRootDisplacement
    0x001A1934: 0xE5903030,  # ldr r3,[fighter,#0x30] final frame
    0x001A1938: 0xE5902034,  # ldr r2,[fighter,#0x34] current frame
    0x001A193C: 0xE2433001,  # sub r3,r3,#1
    0x001A1958: 0xE2805F4F,  # add r5,fighter,#0x13c scene object
    0x001A196C: 0xEBFE0169,  # bl gfxScnObj::GetFrame
    0x001A1978: 0xEBFDF863,  # bl gfxScnFrame::GetRot
    0x001A1998: 0xEBFE27E0,  # bl gfxScnObj::GetHierarchyAnim
    0x001A19A8: 0xEBFE25F6,  # bl gfxAnimLayerList::GetBaseAnim
    0x001A19C0: 0xEBFE0ACC,  # bl gfxAnimation::GetAnimState
    0x001A19C8: 0xEBFE0F9B,  # bl anmState::GetAnimTime
    0x001A19DC: 0xEBFE0366,  # bl anmRoot::SetToTime
    0x001A1AE4: 0xEBFE2655,  # bl gfxScnFrame::SetRot
    0x001A1AF8: 0xEBFE0106,  # bl gfxScnObj::GetFrame
    0x001A1B04: 0xEBFDF620,  # bl gfxScnFrame::GetPos
    0x001A1C74: 0xEBFE04F4,  # bl gfxScnFrame::SetPos
}


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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elf", type=Path)
    args = parser.parse_args()
    try:
        verify_bytes(args.elf.read_bytes())
    except (OSError, HierarchyLinkError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(f"verified {len(_WORDS)} native root-motion instructions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

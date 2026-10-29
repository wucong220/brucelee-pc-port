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
from native_draw_path import _dynamic_symbols


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
    # SetToTime result components, saved state and the two subtractions.
    0x001A1A3C: 0xED9DAA00,
    0x001A1A40: 0xEDDDAA01,
    0x001A1A44: 0xED9D8A02,
    0x001A1B34: 0xED9F2A56,  # load literal 1.0
    0x001A1B38: 0xED940A21,  # previous component 0
    0x001A1B3C: 0xED848A23,  # save component 2
    0x001A1B40: 0xED84AA21,  # save component 0
    0x001A1B44: 0xEDDF1A53,  # load literal 0.0
    0x001A1B48: 0xED941A56,  # fighter+0x158 scale
    0x001A1B4C: 0xEDD40A22,  # previous component 1
    0x001A1B50: 0xEDC4AA22,  # save component 1
    0x001A1BD4: 0xEE3AAA40,  # component 0 delta
    0x001A1BF0: 0xEE6A7A01,  # scale component 0 delta
    0x001A1C0C: 0xEE7AAAE0,  # component 1 delta
    0x001A1C28: 0xEE2A9A81,  # scale component 1 delta
    0x001A1C58: 0xEE788AA7,  # add prior scene position
    0x001A1C60: 0xEE3A8A08,
    0x001A1C68: 0xEE799AA7,
    0x001A1C94: 0x3F800000,  # 1.0 literal
    0x001A1C98: 0x00000000,  # 0.0 literal
    # SetToTime clamps an integer time and passes its state to GetOutput.
    0x00406890: 0xE3560000,
    0x00406894: 0xBD9F8A2E,
    0x0040689C: 0xE597309C,
    0x004068A4: 0xA1A06003,
    0x004068AC: 0xEDD77A29,
    0x004068BC: 0xEBF49405,
    0x004068C0: 0xED9F7A24,
    0x004068D8: 0xEEC77A27,
    0x004068DC: 0xEE687A27,
    0x004068E0: 0xEEFD7AE7,
    0x004068E4: 0xEDC77A26,
    0x004068E8: 0xEBF479C0,
    0x004068EC: 0xE3A02028,
    0x004068F8: 0xEBF476B3,
    0x00406954: 0x00000000,
    0x00406958: 0x3F800000,
    0x00407A98: 0xEBF46B76,  # GetOutput: floor in one branch
    0x00407D84: 0xEBF49101,  # GetOutput: BuildFrame in one branch
}

# PLT relocation names, plus each stub's three words, tie call sites to symbols.
_PLT = {
    0x0012B8D8: (0x00601B24, "zlibm_fabs", (0xE28FC604, 0xE28CCAD6, 0xE5BCF244)),
    0x00124FF0: (0x005FF82C, "_ZN3krm3anm15CRootPlayerBase9GetOutputERKNS0_10CAnimStateE", (0xE28FC604, 0xE28CCADA, 0xE5BCF834)),
    0x001243CC: (0x005FF420, "memmove", (0xE28FC604, 0xE28CCADB, 0xE5BCF04C)),
    0x00122878: (0x005FEB04, "zlibm_floor", (0xE28FC604, 0xE28CCADC, 0xE5BCF284)),
    0x0012C190: (0x00601E0C, "_ZNK3krm3anm13CAnimProvider10BuildFrameEf", (0xE28FC604, 0xE28CCAD5, 0xE5BCFC74)),
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
    symbols = _dynamic_symbols(elf)
    for address, (relocation, name, words) in _PLT.items():
        actual_words = struct.unpack_from("<III", elf, file_offset(elf, address))
        if actual_words != words or symbols.get(relocation) != name:
            raise HierarchyLinkError(f"PLT or relocation mismatch at 0x{address:08x}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elf", type=Path)
    args = parser.parse_args()
    try:
        verify_bytes(args.elf.read_bytes())
    except (OSError, HierarchyLinkError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(f"verified {len(_WORDS)} root-motion words and {len(_PLT)} PLT relocations")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

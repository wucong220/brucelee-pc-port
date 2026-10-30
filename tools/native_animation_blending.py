#!/usr/bin/env python3
"""Verify the native fade-animation blending control flow."""
from __future__ import annotations

import argparse
import hashlib
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from native_draw_path import _dynamic_symbols
from native_hierarchy_links import HierarchyLinkError, file_offset
from native_root_motion import _plt_target


_SHA256 = "1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70"

# Representative instructions bind the static conclusions to this exact ELF:
# queue dispatch, fade weighting, output/root blending, frame blending and the
# transition-duration multiplication.  The parser, FollowLink and SetAnimation
# instructions also bind the fighting-set "blending" value to transitionInfo+8.
_WORDS = {
    # CFadeQueue::UpdateOutput forwards its active player to CFadePlayer.
    0x003FE128: 0xE5900084,  # ldr r0, [r0, #0x84]
    0x003FE12C: 0xE3500000,  # cmp r0, #0
    0x003FE130: 0x012FFF1E,  # bxeq lr
    0x003FE134: 0xEAF4846A,  # b CFadePlayer::UpdateOutput PLT
    # CFadePlayer::UpdateOutput handles the recursive player and fade weight.
    0x003FC768: 0xE5900008,  # ldr r0, [r0, #8]
    0x003FC77C: 0x0A000049,  # beq copy-output path
    0x003FC780: 0xEBF48AD7,  # bl recursive CFadePlayer::UpdateOutput
    0x003FC7B8: 0xEEB58AC0,  # vcmpe.f32 fade weight, #0
    0x003FC7C0: 0xCA000006,  # bgt to the blend path
    0x003FC8A0: 0xEBF492C0,  # bl CAnimPlayer::BlendOutput
    0x003FC8AC: 0xEBF4BA05,  # bl CAnimPlayer::CopyOutput
    # CFadePlayer::GetRootOutput selects root blending or a direct sample.
    0x003FC8C4: 0xE5903004,  # ldr r3, [r0, #4]
    0x003FC8CC: 0xE3530000,  # cmp r3, #0
    0x003FC988: 0xEBF49640,  # bl CRootPlayerBase::BlendOutput
    0x003FC9BC: 0xEBF4A18B,  # bl CRootPlayerBase::GetOutput
    # CRootPlayerBase::BlendOutput branches on weight -1/1/0 and interpolates.
    0x00407DE8: 0xED9D8A1B,  # vldr s16, [sp, #0x6c]
    0x00407E5C: 0xEEB58AC0,  # vcmpe.f32 weight, #0
    0x00407E64: 0x4AFFFFED,  # bmi return without changing the old output
    0x00407E68: 0xED9F7A47,  # vldr one
    0x00407E6C: 0xEEB48AC7,  # vcmpe.f32 weight, one
    0x00407E74: 0xCA000000,  # bgt copy current output
    0x00407E78: 0xBA000004,  # blt fractional blend
    0x00407E80: 0xE3A02028,  # mov r2, #0x28
    0x00407E88: 0xEBF4714F,  # bl memmove
    0x00407E90: 0xEEB58AC0,  # vcmpe.f32 weight, #0
    0x00407E98: 0xDAFFFFE0,  # ble leave the old output unchanged
    0x00407EC8: 0xEE685A25,  # vmul.f32 current, weight
    0x00407ECC: 0xEE377A48,  # vsub.f32 one, weight
    0x00407ED0: 0xEE475A2A,  # vmla.f32 current, one-minus-weight, old
    0x00407EE8: 0x4EB18A48,  # vnegmi.f32 weight for signed rotation terms
    0x00407F8C: 0x3F800000,  # 1.0
    # CAnimPlayer::BlendOutput selects copy versus frame blending.
    0x003F8EEC: 0xEEB58AC0,  # vcmpe.f32 weight, #0
    0x003F8EFC: 0x4A000037,  # bmi return
    0x003F8F00: 0xEDDF8A73,  # vldr one
    0x003F8F04: 0xEEB48AE8,  # vcmpe.f32 weight, one
    0x003F8F0C: 0xCA000036,  # bgt copy output
    0x003F8F10: 0xAA000035,  # bge copy output when weight equals one
    0x003F8F8C: 0xEBF4A639,  # bl zlibm_floor
    0x003F8FC8: 0xEBF4BF0B,  # bl CopyBlendFrames
    0x003F8FFC: 0xEAF4C831,  # tail-call CopyOutput
    0x003F90D4: 0x3F800000,  # 1.0
    # The blended frame path reaches CAnimProvider::BuildFrame.
    0x003F7A08: 0xEBF4D1E0,  # bl CAnimProvider::BuildFrame
    # CFadePlayer::Init computes framerate times transition duration and
    # converts the positive result to an unsigned integer.
    0x003FCED8: 0xED937A06,  # vldr s14, [r3, #0x18]
    0x003FCEDC: 0xEEB87AC7,  # vcvt.f32.s32 framerate
    0x003FCEE4: 0xEDD27A02,  # vldr s15, [transition_info, #8]
    0x003FCEFC: 0xEE677A27,  # vmul.f32 framerate, duration
    0x003FCF00: 0xEEFC7AE7,  # vcvt.u32.f32 product
    0x003FCF04: 0xEE173A90,  # vmov integer product
    0x003FCF08: 0xEBF48B44,  # bl CFadeController constructor
    # CLinkDescr::ParseFromKDF parses the "blending" node.  An absent node
    # defaults to 6; a present integer value is copied from the KDF dictionary.
    0x001C4498: 0xE59F1868,  # ldr r1, pc-relative "blending" address
    0x001C44A4: 0xE08F1001,  # add r1, pc, r1
    0x001C44AC: 0xE2811068,  # add r1, r1, #0x68
    0x001C44B0: 0xEBFD7350,  # bl CHStrMgr::GetItem
    0x001C45E4: 0xE35A0000,  # cmp sl, #0
    0x001C45E8: 0x03A04006,  # moveq r4, #6
    0x001C45EC: 0x1A000079,  # bne parse-present-value path
    0x001C45F0: 0xE58640DC,  # str r4, [CLinkDescr, #0xDC]
    0x001C47D8: 0xE59F1530,  # ldr r1, pc-relative "blending" address
    0x001C47F0: 0xEBFD7280,  # bl CHStrMgr::GetItem
    0x001C4818: 0xE59D303C,  # ldr r3, [sp, #0x3c]
    0x001C4820: 0xE5934004,  # ldr r4, [r3, #4]
    # CFighter::FollowLink converts blending / fighter-framerate into the
    # float parameter of SetAnimation and reads entry_frame for the uint arg.
    0x001A8294: 0xED957A37,  # vldr s14, [link, #0xDC]
    0x001A8298: 0xEDD47A0C,  # vldr s15, [fighter, #0x30]
    0x001A829C: 0xEEB87A47,  # vcvt.f32.u32 blending
    0x001A82A0: 0xE59530D8,  # ldr r3, [link, #0xD8] entry_frame
    0x001A82AC: 0xEEF87A67,  # vcvt.f32.u32 fighter framerate
    0x001A82B0: 0xEEC77A27,  # vdiv.f32 blending / framerate
    0x001A82B4: 0xEDCD7A01,  # vstr s15, [sp, #4] fifth argument
    0x001A82B8: 0xEBFDF1A5,  # bl CFighter::SetAnimation
    # CFighter::SetAnimation receives that float and copies it to +8 of the
    # anmTransitionInfo passed into gfxAnimation::AddTransition.
    0x001A6EA0: 0xEDDD9A5B,  # vldr s19, [caller stack, #0x16c]
    0x001A7214: 0xEDCD9A2B,  # vstr s19, [transition_info, #8]
    0x001A722C: 0xEBFDE4C1,  # bl gfxAnimation::AddTransition
}

_STRINGS = {
    0x005BB0F0: b"linking_frame\0",
    0x005BB100: b"entry_frame\0",
    0x005BB10C: b"blending\0",
}

_PLT = {
    0x00120538: (
        0x005FDF44,
        "_ZN3krm12gfxAnimation13AddTransitionERKNS_3res7CResRefERKNS_"
        "13anmSourceInfoERKNS_17anmTransitionInfoE",
        (0xE28FC604, 0xE28CCADD, 0xE5BCFA04),
    ),
    0x001211F8: (
        0x005FE384,
        "_ZN3krm3krt8CHStrMgr7GetItemEPKcb",
        (0xE28FC604, 0xE28CCADD, 0xE5BCF184),
    ),
    0x00124954: (
        0x005FF5F8,
        "_ZN3krm8CFighter12SetAnimationENS_3krt10HashStringINS1_10CHStrMgrNSEEEjjbf",
        (0xE28FC604, 0xE28CCADA, 0xE5BCFC9C),
    ),
    0x0011F2E4: (
        0x005FD928,
        "_ZN3krm3anm11CFadePlayer12UpdateOutputEv",
        (0xE28FC604, 0xE28CCADE, 0xE5BCF63C),
    ),
    0x001213A8: (
        0x005FE414,
        "_ZN3krm3anm11CAnimPlayer11BlendOutputEf",
        (0xE28FC604, 0xE28CCADD, 0xE5BCF064),
    ),
    0x00122290: (
        0x005FE90C,
        "_ZN3krm3anm15CRootPlayerBase11BlendOutputERKNS0_10CAnimStateENS0_10TTransformEf",
        (0xE28FC604, 0xE28CCADC, 0xE5BCF674),
    ),
    0x00122878: (
        0x005FEB04,
        "zlibm_floor",
        (0xE28FC604, 0xE28CCADC, 0xE5BCF284),
    ),
    0x001243CC: (
        0x005FF420,
        "memmove",
        (0xE28FC604, 0xE28CCADB, 0xE5BCF04C),
    ),
    0x00124FF0: (
        0x005FF82C,
        "_ZN3krm3anm15CRootPlayerBase9GetOutputERKNS0_10CAnimStateE",
        (0xE28FC604, 0xE28CCADA, 0xE5BCF834),
    ),
    0x00128BFC: (
        0x00600C30,
        "_ZN3krm3anm11CAnimPlayer15CopyBlendFramesERNS_6ptableERKNS0_9CBindListINS0_9TBindAnimEEEff",
        (0xE28FC604, 0xE28CCAD8, 0xE5BCF02C),
    ),
    0x0012B0C8: (
        0x00601874,
        "_ZN3krm3anm11CAnimPlayer10CopyOutputEv",
        (0xE28FC604, 0xE28CCAD6, 0xE5BCF7A4),
    ),
    0x0012C190: (
        0x00601E0C,
        "_ZNK3krm3anm13CAnimProvider10BuildFrameEf",
        (0xE28FC604, 0xE28CCAD5, 0xE5BCFC74),
    ),
}


def verify_bytes(elf: bytes) -> None:
    """Authenticate the recorded ELF and its blending evidence."""
    if hashlib.sha256(elf).hexdigest() != _SHA256:
        raise HierarchyLinkError(
            "ELF SHA-256 does not match the recorded libdefault.so"
        )
    for address, expected in _WORDS.items():
        actual = struct.unpack_from("<I", elf, file_offset(elf, address))[0]
        if actual != expected:
            raise HierarchyLinkError(
                f"instruction at 0x{address:08x} is 0x{actual:08x}, "
                f"expected 0x{expected:08x}"
            )

    for address, expected in _STRINGS.items():
        offset = file_offset(elf, address)
        if elf[offset : offset + len(expected)] != expected:
            raise HierarchyLinkError(
                f"property string at 0x{address:08x} does not match "
                f"{expected.rstrip(bytes([0]))!r}"
            )

    symbols = _dynamic_symbols(elf)
    for address, (relocation, name, expected_words) in _PLT.items():
        words = struct.unpack_from("<III", elf, file_offset(elf, address))
        if (
            words != expected_words
            or _plt_target(address, words) != relocation
            or symbols.get(relocation) != name
        ):
            raise HierarchyLinkError(f"PLT or relocation mismatch at 0x{address:08x}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elf", type=Path, help="local libdefault.so")
    args = parser.parse_args()
    try:
        verify_bytes(args.elf.read_bytes())
    except (OSError, HierarchyLinkError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(
        f"verified {len(_WORDS)} animation-blending words and "
        f"{len(_PLT)} PLT relocations with {len(_STRINGS)} property strings"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

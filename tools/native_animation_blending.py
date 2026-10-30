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
from native_hierarchy_links import HierarchyLinkError, _section, file_offset
from native_root_motion import _plt_target


_SHA256 = "1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70"

# Representative instructions bind the static conclusions to this exact ELF:
# queue dispatch, fade weighting, output/root blending, frame blending and the
# transition-duration multiplication.  The parser, FollowLink and SetAnimation
# instructions also bind the fighting-set "blending" value to transitionInfo+8.
_WORDS = {
    # gfxAnimation stores a CScnAnim reference and dispatches AddTransition
    # through that object's vtable slot +0x18.
    0x00380174: 0xE5801000,  # str r1, [gfxAnimation]
    0x003802B0: 0xE590C000,  # ldr ip, [gfxAnimation]
    0x003802F8: 0xE59CC000,  # ldr ip, [ip] object vptr
    0x003802FC: 0xE1A0E00F,  # mov lr, pc
    0x00380300: 0xE59CF018,  # ldr pc, [ip, #0x18]
    # CScnAnim's constructor installs the vtable and initializes its queue
    # pointer to null. AddTransition lazily allocates CFadeQueue (+0x10).
    0x003807A0: 0xE59F3048,
    0x003807A4: 0xE59F2048,
    0x003807A8: 0xE08F3003,
    0x003807B0: 0xE7932002,
    0x003807BC: 0xE2822008,  # add r2, r2, #8 vtable object pointer
    0x003807CC: 0xE5842000,  # str vptr, [CScnAnim]
    0x003807E4: 0xE5845010,  # str zero, [CScnAnim+0x10]
    0x00380BF0: 0xE5965010,  # ldr r5, [CScnAnim+0x10]
    0x00380BF8: 0x0A000064,  # beq allocate queue
    0x00380B7C: 0xE1A08003,  # transition-info argument
    0x00380B80: 0xE1A0A002,  # source-info argument
    0x00380B84: 0xE1A07001,  # resource-reference argument
    0x00380BFC: 0xE5973000,
    0x00380C08: 0xE1530002,
    0x00380C10: 0x0A000005,
    0x00380C14: 0xE5972004,
    0x00380C18: 0xE58D300C,
    0x00380C1C: 0xE58D2010,
    0x00380C64: 0xE28D100C,  # resource reference at start of queued record
    0x00380C48: 0xE5953068,  # ldr r3, [queue+0x68] transition table
    0x00380C58: 0xE595C070,  # ldr ip, [queue+0x70] record count
    0x00380C68: 0xE5950074,  # ldr r0, [queue+0x74] record storage
    0x00380C6C: 0xE5852070,  # increment record count
    0x00380C70: 0xE0200C9E,  # locate next record by checked stride
    0x00380C78: 0xE593F004,  # virtual copy transition record
    0x00380D90: 0xE3A01002,
    0x00380D94: 0xE3A00088,  # mov r0, #0x88 CFadeQueue size
    0x00380D98: 0xEBF67642,  # bl allocator
    0x00380DA0: 0xEBF694DC,  # bl CFadeQueue::C1
    0x00380DA4: 0xE5865010,  # store queue at CScnAnim+0x10
    # CFadeQueue::C1 initializes the transition-record count and active player
    # slots, then CFadeQueue::UpdateTime calls ActiveNext when records exist.
    0x003FE32C: 0xE4803068,  # initialize queue storage at +0x68
    0x003FE334: 0xE5846084,  # initialize active player at +0x84
    0x003FDD78: 0xE5953070,  # ldr r3, [queue+0x70] record count
    0x003FDD7C: 0xE3530000,  # cmp record count, #0
    0x003FDD80: 0x0AFFFFEE,  # skip ActiveNext when empty
    0x003FDD88: 0xEBF49644,  # bl CFadeQueue::ActiveNext
    # ActiveNext creates a CFadePlayer from the queued state and calls Init
    # before publishing it as the queue's current active player.
    0x003FDADC: 0xE92D4FF0,
    0x003FDB78: 0xE5943048,  # ldr r3, [queue+0x48] queued state
    0x003FDB7C: 0xE3530000,
    0x003FDB80: 0x0A000031,
    0x003FDBA0: 0xE1A07000,  # save constructed CFadePlayer
    0x003FDBA8: 0xE594C084,  # previous active player from queue+0x84
    0x003FDBAC: 0xE1A02005,
    0x003FDBB0: 0xE2853008,
    0x003FDBB4: 0xE2841008,
    0x003FDBB8: 0xE1A00007,
    0x003FDBBC: 0xE98D1040,  # seventh argument at caller sp+8 is previous
    0x003FDBC0: 0xE2855014,
    0x003FDBC4: 0xE58D5000,
    0x003FDBC8: 0xEBF49465,  # bl CFadePlayer::Init
    0x003FDBCC: 0xE5847084,  # publish active player at queue+0x84
    # CTransQueue selects TInfo createcopy; GetTimeCorrection initially
    # copies the reference and other record fields before correction calls.
    0x003FE31C: 0xE59F3024,
    0x003FE324: 0xE7953003,
    0x003FE328: 0xE2833008,
    0x003FE330: 0xEBF4AA37,
    0x003FE340: 0x001FF114,
    0x003FE348: 0x00006BF4,
    0x004141A0: 0xE59F5080,
    0x004141A4: 0xE59F2080,
    0x004141AC: 0xE08F5005,
    0x004141BC: 0xE7956002,
    0x004141C0: 0xE3A02020,
    0x004141C4: 0xE5802010,
    0x004141DC: 0xE59F704C,
    0x004141E0: 0xE7952007,
    0x004141F4: 0xE5842000,
    0x0041420C: 0xE59F701C,
    0x00414214: 0xE5942010,
    0x00414218: 0xE7953007,
    0x0041421C: 0xE583200C,
    0x00414228: 0x001E9264,
    0x0041422C: 0x00006C38,
    0x00414230: 0x000060A4,
    0x00413D28: 0xE52D4004,
    0x00413D2C: 0xE3A02000,
    0x00413D30: 0xE5802000,
    0x00413D34: 0xE5913000,
    0x00413D38: 0xE5802004,
    0x00413D3C: 0xE1530002,
    0x00413D40: 0x0A000005,
    0x00413D44: 0xE5912004,
    0x00413D48: 0xE5803000,
    0x00413D4C: 0xE5802004,
    0x00413D50: 0xE5932030,
    0x00413D54: 0xE2822001,
    0x00413D58: 0xE5832030,
    0x00413D5C: 0xE2812008,
    0x00413D60: 0xE2814014,
    0x00413D64: 0xE2803008,
    0x00413D68: 0xE280C014,
    0x00413D6C: 0xE8920007,
    0x00413D70: 0xE8A30003,
    0x00413D74: 0xE1C320B0,
    0x00413D78: 0xE8940007,
    0x00413D7C: 0xE88C0007,
    0x00413D80: 0xE8BD0010,
    0x00413D84: 0xE12FFF1E,
    0x003FDAEC: 0xE28D5014,
    0x003FDAF0: 0xE2841068,
    0x003FDAF4: 0xE5942074,
    0x003FDB00: 0xE1A03000,
    0x003FDB04: 0xE1A00005,
    0x003FDB08: 0xEBF4A458,
    0x00413F30: 0xE92D41F0,
    0x00413F34: 0xE1A04000,
    0x00413F38: 0xE1A08003,
    0x00413F3C: 0xE3A00000,
    0x00413F40: 0xE5840000,
    0x00413F44: 0xE1A05001,
    0x00413F48: 0xE5923000,
    0x00413F4C: 0xE5840004,
    0x00413F50: 0xE1530000,
    0x00413F54: 0x0A000005,
    0x00413F58: 0xE5921004,
    0x00413F5C: 0xE5843000,
    0x00413F60: 0xE5841004,
    0x00413F64: 0xE5931030,
    0x00413F68: 0xE2811001,
    0x00413F6C: 0xE5831030,
    0x00413F70: 0xE2823008,
    0x00413F74: 0xE2827014,
    0x00413F78: 0xE284C008,
    0x00413F7C: 0xE2846014,
    0x00413F80: 0xE8930007,
    0x00413F84: 0xE3580000,
    0x00413F88: 0xE8AC0003,
    0x00413F8C: 0xE1CC20B0,
    0x00413F90: 0xE8970007,
    0x00413F94: 0xE8860007,
    0x00413F98: 0x0A000009,
    # Full correction functions and the tail of GetTimeCorrection bind
    # the paths that alter timing while preserving the record reference.
    0x00413BF0: 0xEDD17A05,
    0x00413BF4: 0xEEF57AC0,
    0x00413BF8: 0xEEF1FA10,
    0x00413BFC: 0xB12FFF1E,
    0x00413C00: 0xE5D13010,
    0x00413C04: 0xE3530000,
    0x00413C08: 0x112FFF1E,
    0x00413C0C: 0xED917A03,
    0x00413C10: 0xEEB57AC0,
    0x00413C14: 0xEEF1FA10,
    0x00413C18: 0xDA00001B,
    0x00413C1C: 0xED9F7A37,
    0x00413C20: 0xEE777A67,
    0x00413C24: 0xE592C010,
    0x00413C28: 0xEE06CA10,
    0x00413C2C: 0xE5900018,
    0x00413C30: 0xEEF86AC6,
    0x00413C34: 0xEE677AA6,
    0x00413C38: 0xEEFD7AE7,
    0x00413C3C: 0xEE173A90,
    0x00413C40: 0xE1500003,
    0x00413C44: 0xA12FFF1E,
    0x00413C48: 0xE15C0003,
    0x00413C4C: 0x0EF07A47,
    0x00413C50: 0x0A000009,
    0x00413C54: 0xEE073A90,
    0x00413C58: 0xEEF86AE7,
    0x00413C5C: 0xEDD27A08,
    0x00413C60: 0xEE667AA7,
    0x00413C64: 0xEEF57AC0,
    0x00413C68: 0xEEF1FA10,
    0x00413C6C: 0x4A00001F,
    0x00413C70: 0xEEF47A47,
    0x00413C74: 0xEEF1FA10,
    0x00413C78: 0xCEF07A47,
    0x00413C7C: 0xED9F7A1F,
    0x00413C80: 0xEE777A67,
    0x00413C84: 0xEDC17A05,
    0x00413C88: 0xE12FFF1E,
    0x00413C8C: 0xE592C010,
    0x00413C90: 0xEE06CA10,
    0x00413C94: 0xEEB87AC6,
    0x00413C98: 0xE5900018,
    0x00413C9C: 0xEE677A87,
    0x00413CA0: 0xEEFD7AE7,
    0x00413CA4: 0xEE173A90,
    0x00413CA8: 0xE1500003,
    0x00413CAC: 0xA12FFF1E,
    0x00413CB0: 0xE15C0003,
    0x00413CB4: 0x0A00000F,
    0x00413CB8: 0xEEB87AE7,
    0x00413CBC: 0xEDD27A08,
    0x00413CC0: 0xEE677A27,
    0x00413CC4: 0xEEF57AC0,
    0x00413CC8: 0xEEF1FA10,
    0x00413CCC: 0x4A000005,
    0x00413CD0: 0xED9F7A0A,
    0x00413CD4: 0xEEF47A47,
    0x00413CD8: 0xEEF1FA10,
    0x00413CDC: 0xCEF07A47,
    0x00413CE0: 0xEDC17A05,
    0x00413CE4: 0xE12FFF1E,
    0x00413CE8: 0xEDDF7A05,
    0x00413CEC: 0xEAFFFFFB,
    0x00413CF0: 0xEDDF7A03,
    0x00413CF4: 0xEAFFFFE0,
    0x00413CF8: 0xEDDF7A00,
    0x00413CFC: 0xEAFFFFF7,
    0x00413D88: 0xE92D4070,
    0x00413D8C: 0xED2D8B02,
    0x00413D90: 0xE1A05002,
    0x00413D94: 0xE5912000,
    0x00413D98: 0xE1A04001,
    0x00413D9C: 0xE59F3184,
    0x00413DA0: 0xE3520000,
    0x00413DA4: 0xE08F3003,
    0x00413DA8: 0x0A000004,
    0x00413DAC: 0xE59FC178,
    0x00413DB0: 0xE5921010,
    0x00413DB4: 0xE793300C,
    0x00413DB8: 0xE1510003,
    0x00413DBC: 0x0A000000,
    0x00413DC0: 0xE3A02000,
    0x00413DC4: 0xE5D43010,
    0x00413DC8: 0xE5922040,
    0x00413DCC: 0xE3530000,
    0x00413DD0: 0xE5903014,
    0x00413DD4: 0x0A00000C,
    0x00413DD8: 0xEDD47A03,
    0x00413DDC: 0xEEF57AC0,
    0x00413DE0: 0xED947A02,
    0x00413DE4: 0xEE062A10,
    0x00413DE8: 0xEEF1FA10,
    0x00413DEC: 0xCDDF6A4B,
    0x00413DF0: 0xCE367AC7,
    0x00413DF4: 0xEEF87AC6,
    0x00413DF8: 0xEE677A87,
    0x00413DFC: 0xEEFD7AE7,
    0x00413E00: 0xEE172A90,
    0x00413E04: 0xE1530002,
    0x00413E08: 0xA1A03002,
    0x00413E0C: 0xE5952010,
    0x00413E10: 0xE1530002,
    0x00413E14: 0x0A000037,
    0x00413E18: 0xEE063A10,
    0x00413E1C: 0xEEB87AC6,
    0x00413E20: 0xEDD57A08,
    0x00413E24: 0xEE677A27,
    0x00413E28: 0xEEF57AC0,
    0x00413E2C: 0xEEF1FA10,
    0x00413E30: 0x4A00002E,
    0x00413E34: 0xED9F7A39,
    0x00413E38: 0xEEF47A47,
    0x00413E3C: 0xEEF1FA10,
    0x00413E40: 0xCEF07A47,
    0x00413E44: 0xED947A07,
    0x00413E48: 0xEEF47A47,
    0x00413E4C: 0xE5D53008,
    0x00413E50: 0xEEF1FA10,
    0x00413E54: 0xCEF07A47,
    0x00413E58: 0xE3530000,
    0x00413E5C: 0xEDC47A07,
    0x00413E60: 0x0A000020,
    0x00413E64: 0xED947A05,
    0x00413E68: 0xEEB57AC0,
    0x00413E6C: 0xEEF1FA10,
    0x00413E70: 0xAA000013,
    0x00413E74: 0xE595600C,
    0x00413E78: 0xE595301C,
    0x00413E7C: 0xE1560003,
    0x00413E80: 0x0A000024,
    0x00413E84: 0xEDD57A06,
    0x00413E88: 0xEEB76AE7,
    0x00413E8C: 0xED958A08,
    0x00413E90: 0xEC510B16,
    0x00413E94: 0xEBF45E8F,
    0x00413E98: 0xEE066A90,
    0x00413E9C: 0xEEB87AE6,
    0x00413EA0: 0xEC410B16,
    0x00413EA4: 0xEEF77BC6,
    0x00413EA8: 0xEE677A27,
    0x00413EAC: 0xEE287A27,
    0x00413EB0: 0xEEB57AC0,
    0x00413EB4: 0xEEF1FA10,
    0x00413EB8: 0x5A000010,
    0x00413EBC: 0xEDD47A07,
    0x00413EC0: 0xED9F7A17,
    0x00413EC4: 0xEDD56A01,
    0x00413EC8: 0xEEF56AC0,
    0x00413ECC: 0xEEF1FA10,
    0x00413ED0: 0xCDDF6A12,
    0x00413ED4: 0xCE367AC7,
    0x00413ED8: 0xEEB47A67,
    0x00413EDC: 0xEEF1FA10,
    0x00413EE0: 0xCEB07A67,
    0x00413EE4: 0xED847A07,
    0x00413EE8: 0xECBD8B02,
    0x00413EEC: 0xE8BD8070,
    0x00413EF0: 0xEDDF7A0B,
    0x00413EF4: 0xEAFFFFD2,
    0x00413EF8: 0xEDDF7A08,
    0x00413EFC: 0xEAFFFFD0,
    0x00413F00: 0xEDDF7A06,
    0x00413F04: 0xEEB47AE7,
    0x00413F08: 0xEEF1FA10,
    0x00413F0C: 0xCEB07A67,
    0x00413F10: 0xEDD47A07,
    0x00413F14: 0xEAFFFFEA,
    0x00413F18: 0xED9F7A00,
    0x00413F1C: 0xEAFFFFE8,
    0x00413F9C: 0xE1A00005,
    0x00413FA0: 0xE1A01004,
    0x00413FA4: 0xE1A02008,
    0x00413FA8: 0xEBF44C89,
    0x00413FAC: 0xE1A00005,
    0x00413FB0: 0xE1A01004,
    0x00413FB4: 0xE1A02008,
    0x00413FB8: 0xEBF4592A,
    0x00413FBC: 0xE1A00004,
    0x00413FC0: 0xE8BD81F0,
    0x00413FC4: 0xEDDF7A05,
    0x00413FC8: 0xE1A00004,
    0x00413FCC: 0xEDC47A06,
    0x00413FD0: 0xEDC47A07,
    0x00413FD4: 0xEDDF7A02,
    0x00413FD8: 0xEDC47A05,
    0x00413FDC: 0xE8BD81F0,
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
    # CFadePlayer::Init multiplies an object field by transitionInfo+8 and
    # converts the product to an unsigned integer; field semantics remain open.
    0x003FCED8: 0xED937A06,  # vldr s14, [r3, #0x18]
    0x003FCEDC: 0xEEB87AC7,  # vcvt.f32.s32 object field
    0x003FCEE4: 0xEDD27A02,  # vldr s15, [transition_info, #8]
    0x003FCEFC: 0xEE677A27,  # vmul.f32 object field, transition parameter
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
    # CFighter::FollowLink divides blending by fighter+0x30 for the
    # float parameter of SetAnimation; the denominator semantics remain open.
    0x001A8294: 0xED957A37,  # vldr s14, [link, #0xDC]
    0x001A8298: 0xEDD47A0C,  # vldr s15, [fighter, #0x30]
    0x001A829C: 0xEEB87A47,  # vcvt.f32.u32 blending
    0x001A82A0: 0xE59530D8,  # ldr r3, [link, #0xD8] entry_frame
    0x001A82AC: 0xEEF87A67,  # vcvt.f32.u32 fighter field
    0x001A82B0: 0xEEC77A27,  # vdiv.f32 blending / fighter field
    0x001A82B4: 0xEDCD7A01,  # vstr s15, [sp, #4] fifth argument
    0x001A82B8: 0xEBFDF1A5,  # bl CFighter::SetAnimation
    # On the non-null, matching-type path, SetAnimation obtains the active
    # animation record and copies its +0x3c field to fighter+0x30. The
    # alternate branches must not be assumed to yield a valid pointer.
    0x001A7150: 0xE1A01008,
    0x001A7154: 0xEBFE1098,  # bl CFighter::GetActiveSetAnimation
    # SetAnimation stores the index returned by FindAnimationIndex and uses
    # that same index when looking up the associated animation resource.
    0x001A6F9C: 0xEBFE06CE,
    0x001A6FA8: 0xE1A08000,
    0x001A6FD0: 0xE584802C,
    0x001A6FDC: 0xE594102C,
    0x001A6FF8: 0xEBFE10EF,
    0x001A6EC4: 0xE59F5460,  # GOT base literal
    0x001A6ECC: 0xE08F5005,
    0x001A7158: 0xE5903008,
    0x001A715C: 0xE1A06000,
    0x001A7160: 0xE3530000,
    0x001A716C: 0x0A00000D,
    0x001A7170: 0xE59F11B8,  # CAnimRes type-id GOT offset
    0x001A7174: 0xE5932010,
    0x001A717C: 0xE7951001,
    0x001A7188: 0xE1510002,
    0x001A718C: 0x01A02003,
    0x001A7190: 0x13A02000,
    0x001A7194: 0xE592203C,
    0x001A7198: 0xE5842030,
    # Reuse the active resource reference, when non-null, to construct the
    # reference passed to gfxAnimation::AddTransition.
    0x001A71B0: 0xE3A02000,
    0x001A71B4: 0xE58D2100,
    0x001A71BC: 0xE5963008,
    0x001A71C4: 0xE58D2104,
    0x001A71CC: 0xE1530002,
    0x001A71D0: 0x0A000005,
    0x001A71D4: 0xE596200C,
    0x001A71D8: 0xE58D3100,
    0x001A71DC: 0xE58D2104,
    0x001A71E0: 0xE5932030,
    0x001A71E4: 0xE2822001,
    0x001A71E8: 0xE5832030,
    0x001A71F4: 0xE28D1C01,
    0x001A732C: 0x00456544,
    0x001A7330: 0x00005578,
    # GetActiveSetAnimation either indexes the fighter's table or delegates
    # to the internal-fighting-set accessor on the object at fighter+0x7c.
    0x001A00D0: 0xE5D03135,
    0x001A00D4: 0xE1A02001,
    0x001A00D8: 0xE3530000,
    0x001A00DC: 0x1A000004,
    0x001A00E0: 0xE59010D8,
    0x001A00E4: 0xE59030D4,
    0x001A00E8: 0xE0020291,
    0x001A00EC: 0xE7930002,
    0x001A00F0: 0xE12FFF1E,
    0x001A00F4: 0xE590007C,
    0x001A00F8: 0xEAFE1AFD,
    # FollowLink may first set animation on the object at fighter+0x7c.
    # The later divisor and SetAnimation call use the original fighter.
    0x001A8200: 0xE594207C,
    0x001A8228: 0xE5C2E135,
    0x001A8240: 0xEBFDF1C3,
    0x001A8278: 0xE1A00004,
    0x001A80E8: 0xE594102C,
    0x001A8100: 0xE5942034,
    0x001A8108: 0x858430F4,
    0x001A810C: 0x858450F0,
    0x001A8110: 0x8A00007D,
    # CAnimRes::UpdateProperties identifies gid_duration and writes its
    # integer value, or zero on the recorded failure branch, to +0x3c.
    0x00416814: 0xE92D4FF0,
    0x00416818: 0xE5919000,
    0x0041681C: 0xE59F4760,
    0x0041682C: 0xE08F4004,
    0x00416830: 0xE1A06000,
    0x00416874: 0xE59FB710,
    0x004168C8: 0xE794000B,
    0x004168D0: 0xE5908000,
    0x004168D4: 0xE1530008,
    0x004168D8: 0x13A08000,
    0x004168DC: 0x03A08001,
    0x004168F4: 0xE3580000,
    0x004168F8: 0x0AFFFFE3,
    0x00416918: 0xE28D7030,
    0x0041691C: 0xE1A01009,
    0x00416920: 0xE1A00007,
    0x00416924: 0xEBF43480,
    0x00416928: 0xE59D3030,
    0x0041692C: 0xE3530000,
    0x00416930: 0x0A000135,
    0x00416934: 0xE59D3034,
    0x00416938: 0xE3530000,
    0x0041693C: 0x0A000132,
    0x00416940: 0xE5932000,
    0x00416944: 0xE312020F,
    0x00416948: 0x05933004,
    0x0041694C: 0x1A00012E,
    0x00416950: 0xE586303C,
    0x00416E0C: 0xE3A03000,
    0x00416E10: 0xEAFFFECE,
    0x00416F84: 0x001E6BE4,
    0x00416F8C: 0x000065D4,
    # CAnimRes divides the low 32 bits of duration*1000 by framerate on the
    # identified path, using 30 when attribute reading takes the fallback.
    0x0041695C: 0xE596303C,
    0x00416960: 0xE3A02FFA,
    0x00416968: 0xE0020392,
    0x00416970: 0xE58D2004,
    0x004169AC: 0xE59FB5DC,
    0x004169F4: 0xE794000B,
    0x004169FC: 0xE5908000,
    0x00416A00: 0xE1530008,
    0x00416A20: 0xE3580000,
    0x00416A24: 0x0AFFFFE3,
    0x00416A74: 0x05931004,
    0x00416A78: 0x1A0000E5,
    0x00416A7C: 0xE59D0004,
    0x00416A80: 0xEBF432A9,
    0x00416A84: 0xE5860040,
    0x00416E14: 0xE3A0101E,
    0x00416E18: 0xE59D0004,
    0x00416E1C: 0xEBF431C2,
    0x00416E20: 0xE5860040,
    0x00416F90: 0x00006AAC,
    # SetSource copies the CAnimRes duration_ms through CTimeController into
    # CAnimPlayer+0x18. Init leaves that controller input word unchanged.
    0x003F943C: 0xE92D4FF0,
    0x003F9454: 0xE1A04000,
    0x003F9530: 0xE28D804C,
    0x003F9534: 0xE5932040,
    0x003F9538: 0xE1A00008,
    0x003F9540: 0xE58D2050,
    0x003F9544: 0xE593303C,
    0x003F9548: 0xE58D3054,
    0x003F954C: 0xEBF4BDC5,
    0x003F9550: 0xE1A0C008,
    0x003F9554: 0xE28DE01C,
    0x003F9560: 0xE8BC000F,
    0x003F9568: 0xE8A8000F,
    0x003F9574: 0xE89C0007,
    0x003F9578: 0xE8880007,
    0x003F959C: 0xE284C014,
    0x003F95B4: 0xE8BE000F,
    0x003F95B8: 0xE8AC000F,
    0x003F95BC: 0xE89E0007,
    0x003F95C0: 0xE88C0007,
    0x004139C8: 0xE990000C,
    0x004139CC: 0xE3530000,
    0x004139D0: 0x12433001,
    0x004139D4: 0x15803008,
    0x004139D8: 0xE3520000,
    0x004139DC: 0xCE062A90,
    0x004139E0: 0xCD9F7A0A,
    0x004139E4: 0xDD9F7A0A,
    0x004139E8: 0xCEF87AE6,
    0x004139EC: 0xEE063A90,
    0x004139F0: 0xE5802010,
    0x004139F4: 0xCE877A27,
    0x004139F8: 0xEEF87A66,
    0x004139FC: 0xED807A05,
    0x00413A00: 0xED9F7A02,
    0x00413A04: 0xEEC77A27,
    0x00413A08: 0xEDC07A06,
    0x00413A0C: 0xE12FFF1E,
    0x003FCD58: 0xE59D4098,
    0x003FCD4C: 0xE1A08002,  # retain resource-reference argument
    0x003FCDEC: 0xE1A0300A,
    0x003FCDF0: 0xE5950000,
    0x003FCDF4: 0xE1A01008,
    0x003FCDF8: 0xE1A02007,
    0x003FCDFC: 0xEBF4A1F2,  # SetSource with the retained reference
    0x003FCD20: 0xE92D4FF0,  # save 9 registers (36 bytes)
    0x003FCD3C: 0xE24DD06C,  # additional 108-byte stack frame
    0x003FCECC: 0xE5854008,  # keep previous player
    0x003FCED0: 0x0A000011,  # skip multiply when previous is absent
    0x003FCED4: 0xE5943000,
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

_DYN_RELOCATIONS = {
    0x006034BC: "_ZZN3krm3dtl7svectorINS_3anm11CTransQueue5TInfoEE6__InitEvE5gInfo",
    0x00606FF4: "_ZN3krm3dtl11manipulatorINS_3anm11CTransQueue5TInfoEvE10createcopyEPvPKv",
    0x00602990: "_ZZN3krm3dtl6TypeIdINS_3anm8CAnimResEEEjvE5sType",
    0x006039EC: "_ZN3krm3anm12gid_durationE",
    0x00603EC4: "_ZN3krm3anm13gid_framerateE",
    0x00603B60: "_ZTVN3krm3gfx8CScnAnimE",
    0x005F9170: (
        "_ZN3krm3gfx8CScnAnim13AddTransitionERKNS_3res7CResRefERKNS_"
        "13anmSourceInfoERKNS_17anmTransitionInfoE"
    ),
}

_PLT = {
    0x001255CC: (
        0x005FFA20,
        "_ZN3krm3anm11CAnimPlayer9SetSourceERKNS_3res7CResRefERKNS_12anmHeadChunkERKNS_13anmSourceInfoE",
        (0xE28FC604, 0xE28CCADA, 0xE5BCF44C),
    ),
    0x001271D4: (
        0x00600378,
        "_ZNK3krm3anm11CTransQueue16CorrectTransTimeERNS1_5TInfoEPKNS0_10CAnimStateE",
        (0xE28FC604, 0xE28CCAD9, 0xE5BCF19C),
    ),
    0x0012A468: (
        0x00601454,
        "_ZNK3krm3anm11CTransQueue15CorrectFadeTimeERNS1_5TInfoEPKNS0_10CAnimStateE",
        (0xE28FC604, 0xE28CCAD6, 0xE5BCFFE4),
    ),
    0x0012B8D8: (
        0x00601B24,
        "zlibm_fabs",
        (0xE28FC604, 0xE28CCAD6, 0xE5BCF244),
    ),
    0x00128C14: (
        0x00600C38,
        "_ZN3krm3anm11CTransQueueC1Ev",
        (0xE28FC604, 0xE28CCAD8, 0xE5BCF01C),
    ),
    0x00126C70: (
        0x006001AC,
        "_ZNK3krm3anm11CTransQueue17GetTimeCorrectionERKNS1_5TInfoEPKNS0_10CAnimStateE",
        (0xE28FC604, 0xE28CCAD9, 0xE5BCF534),
    ),
    0x0012352C: (
        0x005FEF40,
        "__aeabi_uidiv",
        (0xE28FC604, 0xE28CCADB, 0xE5BCFA0C),
    ),
    0x00128C68: (
        0x00600C54,
        "_ZN3krm3anm15CTimeController4InitEv",
        (0xE28FC604, 0xE28CCAD7, 0xE5BCFFE4),
    ),
    0x00128ADC: (
        0x00600BD0,
        "_ZN3krm8CFighter18FindAnimationIndexENS_3krt10HashStringINS1_10CHStrMgrNSEEE",
        (0xE28FC604, 0xE28CCAD8, 0xE5BCF0EC),
    ),
    0x00126CF4: (
        0x006001D8,
        "_ZN3krm8CFighter31GetInternalFightingSetAnimationEj",
        (0xE28FC604, 0xE28CCAD9, 0xE5BCF4DC),
    ),
    0x0012B3BC: (
        0x00601970,
        "_ZN3krm8CFighter21GetActiveSetAnimationEj",
        (0xE28FC604, 0xE28CCAD6, 0xE5BCF5AC),
    ),
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
    0x00122D64: (
        0x005FECA8,
        "_ZN3krm3anm11CFadePlayer4InitEPNS0_14CFadeQueueBaseERKNS_3res7CResRefERKNS_"
        "13anmSourceInfoERKNS_17anmTransitionInfoERKNS_10CPropTableEPS1_",
        (0xE28FC604, 0xE28CCADB, 0xE5BCFF3C),
    ),
    0x001236A0: (
        0x005FEFBC,
        "_ZN3krm3anm10CFadeQueue10ActiveNextEv",
        (0xE28FC604, 0xE28CCADB, 0xE5BCF914),
    ),
    0x00126118: (
        0x005FFDE4,
        "_ZN3krm3anm10CFadeQueueC1Ev",
        (0xE28FC604, 0xE28CCAD9, 0xE5BCFCC4),
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


def _dynamic_relocation_symbols(elf: bytes) -> dict[int, str]:
    """Resolve .rel.dyn entries, including vtable slots."""
    rel_off, rel_size, _link, _entsize, _names = _section(elf, b".rel.dyn")
    dynsym_off, _size, _dynsym_link, dynsym_entsize, _names = _section(
        elf, b".dynsym"
    )
    dynstr_off = _section(elf, b".dynstr")[0]
    if dynsym_entsize < 16 or rel_size % 8:
        raise HierarchyLinkError(
            "unexpected dynamic symbol or relocation layout"
        )
    result = {}
    for index in range(rel_size // 8):
        address, info = struct.unpack_from("<II", elf, rel_off + index * 8)
        name_off = struct.unpack_from(
            "<I", elf, dynsym_off + (info >> 8) * dynsym_entsize
        )[0]
        end = elf.index(b"\x00", dynstr_off + name_off)
        result[address] = elf[dynstr_off + name_off : end].decode(
            "ascii", "replace"
        )
    return result


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

    dynamic_relocations = _dynamic_relocation_symbols(elf)
    for address, expected in _DYN_RELOCATIONS.items():
        actual = dynamic_relocations.get(address)
        if actual != expected:
            raise HierarchyLinkError(
                f"dynamic relocation 0x{address:08x} is {actual!r}, "
                f"expected {expected!r}"
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
    print(
        f"verified {len(_WORDS)} animation-blending words and "
        f"{len(_PLT)} PLT relocations, {len(_DYN_RELOCATIONS)} dynamic "
        f"relocations and {len(_STRINGS)} property strings"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

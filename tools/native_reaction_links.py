#!/usr/bin/env python3
"""Verify the native fighting-set reaction-link control flow."""
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
    0x00218E3C: 0xE59FBFF0,  # GIDs initializer loads its rodata base
    0x00218E44: 0xE08FB00B,  # resolve GIDs rodata base
    0x00218EA0: 0xE28B3D0A,  # first GID-literal table address
    0x00218EA8: 0xE58D3008,  # save GID-literal table address
    0x0021B120: 0xE59D3008,  # gid_Press init loads literal-table base
    0x0021B12C: 0xE283CE31,  # gid_Press literal = table + 0x310
    0x0021B130: 0xE59F3F48,  # gid_Press init loads GOT offset
    0x0021B13C: 0xE7943003,  # load gid_Press object from GOT
    0x0021B14C: 0xE583E038,  # store previous-link field
    0x0021B150: 0xE583C034,  # store "Press" literal object
    0x0021B15C: 0xEBFC1F21,  # initialize gid_Press from stored fields
    0x0017F860: 0xE3A02000,  # new event flag value
    0x0017F864: 0xE5CD206C,  # event +0x10 = 0 on stack
    0x0017F868: 0xE58D3068,  # event +0x0c = caller argument
    0x00177FAC: 0xE5D12010,  # event copy reads flag
    0x00177FB4: 0xE5C02010,  # event copy writes flag
    0x001A0B5C: 0xE5934008,  # ConsumeEvents reads event string item
    0x001A0B64: 0xE1550004,  # compare desired string item
    0x001A0B68: 0x05C38010,  # on match write flag = 1
    0x001A0B6C: 0x02466001,  # advance desired sequence on match
    0x0017C1D8: 0xE594274C,  # first event queue size
    0x0017C204: 0xE5940750,  # first event queue data
    0x0017C20C: 0xE594C754,  # first event queue stride
    0x0017C214: 0xE593300C,  # last event's +0x0c field
    0x0017C218: 0xE2833F7D,  # add 500 clock units
    0x0017C21C: 0xE1580003,  # compare Update argument
    0x0017C220: 0x9A000008,  # leave queue unchanged when <=
    0x0017C240: 0xE5C16010,  # otherwise mark each event
    0x0017C248: 0xE5942760,  # second event queue size
    0x0017C264: 0xE593300C,  # last event's +0x0c field
    0x0017C268: 0xE2833F7D,  # add 500 clock units
    0x0017C26C: 0xE1580003,  # compare Update argument
    0x0017C270: 0x9A000008,  # leave queue unchanged when <=
    0x0017C290: 0xE5C16010,  # otherwise mark each event
    0x001A0184: 0xE5915008,  # ldr r5,[keysequence,#8] size
    0x001A0188: 0xE3A03001,  # mov r3,#1
    0x001A018C: 0xE3A00000,  # mov r0,#0
    0x001A0194: 0xE1500005,  # cmp r0,r5
    0x001A019C: 0x3A000004,  # blo non-empty path
    0x001A01A0: 0xE1550000,  # cmp r5,r0
    0x001A01A4: 0x83A00000,  # movhi r0,#0
    0x001A01A8: 0x93A00001,  # movls r0,#1 (empty sequence passes)
    0x001A01B4: 0xE5924008,  # event vector size
    0x001A01B8: 0xE0607008,  # reverse index into requested sequence
    0x001A01C4: 0xE06CC006,  # reverse index into event vector
    0x001A01E4: 0xE79A6007,  # requested string item
    0x001A01E8: 0xE59C4008,  # event string item at +8
    0x001A01EC: 0xE1560004,  # compare interned items
    0x001A01F0: 0x12833001,  # skip nonmatching event
    0x001A01F4: 0x1AFFFFE6,  # retry with the preceding event
    0x001A01F8: 0xE5DCC010,  # event byte at +0x10
    0x001A01FC: 0xE2833001,  # advance event scan
    0x001A0200: 0xE35C0000,  # check byte
    0x001A0204: 0x02800001,  # zero byte advances requested match
    0x001A0208: 0xEAFFFFE1,  # continue reverse scan
    0x001A0210: 0xE591B008,  # ldr fp,[keystatus,#8] size
    0x001A0218: 0xE35B0000,  # cmp fp,#0
    0x001A021C: 0xDA000026,  # ble empty-status path
    0x001A02BC: 0xE3A00001,  # mov r0,#1 (empty status passes)
    0x001A3928: 0xE591B008,  # ldr fp,[conditions,#8] size
    0x001A3934: 0xE35B0000,  # cmp fp,#0
    0x001A3940: 0xD3A02001,  # movle r2,#1
    0x001A3948: 0xD58D2004,  # strle r2,[sp,#4]
    0x001A394C: 0xDA0000B2,  # ble common return
    0x001A3C1C: 0xE59D0004,  # ldr r0,[sp,#4]
    0x001A3C20: 0xE28DD034,  # add sp,sp,#0x34
    0x001A8A34: 0xEBFE0E32,  # bl CFighter::TimeWindowCheck
    0x001A8A54: 0xEBFE0C08,  # bl CFighter::InputSequenceCheck
    0x001A8A74: 0xEBFDFDBD,  # bl CFighter::InputStatusCheck
    0x001A8A84: 0xEBFE056C,  # bl CFighter::CheckConditions
    0x001A8A88: 0xE3570000,  # cmp r7,#0 (time window)
    0x001A8A8C: 0x0AFFFFD7,  # beq next link
    0x001A8A90: 0xE3580000,  # cmp r8,#0 (key sequence)
    0x001A8A94: 0x0AFFFFD5,  # beq next link
    0x001A8A98: 0xE35B0000,  # cmp fp,#0 (key status)
    0x001A8A9C: 0x0AFFFFD3,  # beq next link
    0x001A8AA0: 0xE3500000,  # cmp r0,#0 (conditions)
    0x001A8AA4: 0x0AFFFFD1,  # beq next link
    0x001A8AB4: 0xEBFDE4D8,  # bl CFighter::FollowLink
    0x001A8AD0: 0xEBFDF96E,  # bl CFighter::ConsumeEvents
    0x001A8AD4: 0xE5D530E0,  # load link byte at +0xe0
    0x001A8ADC: 0x0A00000D,  # skip marking all when byte is zero
    0x001A8B10: 0xE5C1C010,  # otherwise mark each event
    0x001A1FA8: 0xE1520003,  # cmp currentFrame,windowStart
    0x001A1FAC: 0x3A000009,  # blo false
    0x001A1FB0: 0xE5910004,  # ldr r0,[window,#4] windowEnd
    0x001A1FB4: 0xE1520000,  # cmp currentFrame,windowEnd
    0x001A1FB8: 0x83A00000,  # movhi r0,#0
    0x001A1FBC: 0x93A00001,  # movls r0,#1
    0x001A5554: 0xEBFE1798,  # bl CFighter::GetActiveSetAnimation
    0x001A5570: 0xEBFDEF20,  # bl CHStrMgr::GetItem("ReceiveDamage")
    0x001A5590: 0xEBFE0124,  # bl CAnimationDescr::BelongsToGroup
    0x001A55E0: 0xE3540000,  # cmp r4,#0
    0x001A55E4: 0x0AFFFFCC,  # beq without ReceiveDamage
    0x001A5600: 0xEBFE023A,  # bl CFighter::AttackDamage
    0x001A5610: 0xEBFE08C3,  # bl CFighter::ModifyHealth
}
_STRINGS = {
    0x005BAB9C: b"ReceiveDamage\x00",
    0x005BD2D8: b"Press\x00",
    0x005BD2E0: b"Pressed\x00",
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
    for address, expected in _STRINGS.items():
        string_offset = file_offset(elf, address)
        actual = elf[string_offset:string_offset + len(expected)]
        if actual != expected:
            raise HierarchyLinkError(
                f"literal at 0x{address:08x} is {actual!r}, "
                f"expected {expected!r}"
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
    print(f"verified {len(_WORDS)} native reaction-link instructions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

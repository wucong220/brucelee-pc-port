#!/usr/bin/env python3
"""Verify the native attacktofloor group-link control flow."""
from __future__ import annotations

import argparse
import hashlib
import struct
import sys
from collections.abc import Mapping
from pathlib import Path
from typing import TypeVar

sys.path.insert(0, str(Path(__file__).resolve().parent))
from native_hierarchy_links import HierarchyLinkError, file_offset


_SHA256 = "1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70"
_WORDS = {
    0x001BFC38: 0xE5C42008,  # CLinkDescr constructor: group flag = 0
    0x001C266C: 0xE3A03001,  # from_group parse path: value 1
    0x001C2670: 0xE5C63008,  # store group flag = 1
    0x001C2834: 0xE3A03000,  # direct-from parse path: value 0
    0x001C2838: 0xE5C63008,  # store direct flag = 0
    0x001C409C: 0xE1540009,  # parse time: compare start and end
    0x001C40A0: 0xE3023710,  # equal endpoints use 10000
    0x001C40A4: 0x01A04003,  # move equal-end sentinel
    0x001C40A8: 0x13A04000,  # otherwise endpoint value = 0
    0x001C40B8: 0xE58640D0,  # store parsed end/sentinel at link+0xd0
    0x001C40C0: 0xE58630CC,  # store parsed start at link+0xcc
    0x001A1F00: 0xE5D13008,  # TimeWindowCheck reads group flag
    0x001A1F04: 0xE3530000,  # compare group flag
    0x001A1F08: 0x0A00002D,  # direct path when flag is zero
    0x001A1FA4: 0xE7933009,  # group path reads member window start
    0x001A1FA8: 0xE1520003,  # compare current frame with start
    0x001A1FAC: 0x3A000009,  # current frame before start fails
    0x001A1FB0: 0xE5910004,  # group path reads member window end
    0x001A1FB4: 0xE1520000,  # compare current frame with end
    0x001A1FB8: 0x83A00000,  # current frame after end fails
    0x001A1FBC: 0x93A00001,  # inclusive group-window success
    0x001A1FC4: 0xE5903034,  # direct path reads current frame
    0x001A1FC8: 0xE59120CC,  # direct path reads link start
    0x001A1FCC: 0xE59100D0,  # direct path reads link end
    0x001A8040: 0xE5D13008,  # FollowLink reads group flag
    0x001A8048: 0xE3530000,  # compare group flag
    0x001A8104: 0xE1530002,  # compare group member third value with current frame
    0x001A8108: 0x858430F4,  # store deferred transition frame at fighter+0xf4
    0x001A810C: 0x858450F0,  # defer selected link at fighter+0xf0
    0x001A8110: 0x8A00007D,  # return before executing the group link
    0x001A83BC: 0xE59420F0,  # BasicUpdate reads pending link
    0x001A83C0: 0xE3520000,  # check pending link
    0x001A83C8: 0xE5941034,  # read current frame
    0x001A83CC: 0xE59430F4,  # read deferred frame
    0x001A83D0: 0xE1510003,  # compare current frame with deferred end
    0x001A83D4: 0x2A000066,  # execute transition once the deferred frame is reached
    0x001A8574: 0xE5923004,  # delayed link execution begins here
    0x001A3B2C: 0xE59F3544,  # CheckConditions loads OppPoseLaying GOT offset
    0x001A3B30: 0xE7943003,  # resolve OppPoseLaying GID
    0x001A3B38: 0xE1530001,  # compare condition with OppPoseLaying
    0x001A3B3C: 0x0A0000BD,  # branch to pose check
    0x001A3E38: 0xE595007C,  # load opponent pointer from fighter+0x7c
    0x001A3E3C: 0xEBFDEC4A,  # call opponent current-animation accessor
    0x001A3E40: 0xE59070AC,  # read animation descriptor pose field
    0x001A3E44: 0xE3570000,  # check pose pointer
    0x001A3E48: 0x0A000182,  # null pose fails
    0x001A3E4C: 0xE59F2288,  # load gid_laying GOT offset
    0x001A3E54: 0xE7942002,  # resolve gid_laying
    0x001A3E5C: 0xE5928000,  # load laying GID value
    0x001A3E74: 0xE1570008,  # compare animation pose with gid_laying
    0x0022EBB8: 0xE51F1550,  # CAnimationDescr::ParseFromKDF loads pose key base
    0x0022EBC8: 0xE08F1001,  # resolve pose key string
    0x0022EBD0: 0xE2811038,  # select exact "pose" literal
    0x0022EBD4: 0xEBFBC987,  # query "pose" property
    0x0022EC1C: 0xE59510AC,  # old animation descriptor pose field
    0x0022EC20: 0xE7938002,  # parsed pose value
    0x0022EC34: 0xE1580001,  # compare parsed and old pose values
    0x0022EC5C: 0xE58580AC,  # store parsed pose at descriptor+0xac
    0x001A89DC: 0xE59460F0,  # UserControlUpdate reads link index/pending link
    0x001A89FC: 0xE5903100,  # load current animation link count
    0x001A8A04: 0xE1560003,  # compare index with link count
    0x001A8A28: 0xE2866001,  # visit links in ascending vector order
}
_RELOCATIONS = {
    0x00603FD4: "_ZN3krm17gid_OppPoseLayingE",
    0x00602A9C: "_ZN3krm10gid_layingE",
}
_STRINGS = {
    0x005BDD0C: b"pose\x00",
}

_Value = TypeVar("_Value")


def _verify_map(
    expected: Mapping[int, _Value],
    actual: Mapping[int, _Value],
    description: str,
) -> None:
    for address, expected_value in expected.items():
        if address not in actual:
            raise HierarchyLinkError(
                f"{description} at 0x{address:08x} is missing"
            )
        actual_value = actual[address]
        if actual_value != expected_value:
            raise HierarchyLinkError(
                f"{description} at 0x{address:08x} is {actual_value!r}, "
                f"expected {expected_value!r}"
            )


def _dynamic_symbols(elf: bytes) -> dict[int, str]:
    e_shoff = struct.unpack_from("<I", elf, 32)[0]
    e_shentsize, e_shnum, e_shstrndx = struct.unpack_from("<HHH", elf, 46)
    if e_shentsize < 40 or e_shoff + e_shnum * e_shentsize > len(elf):
        raise HierarchyLinkError("ELF section headers are truncated")

    def section_header(index: int) -> tuple[int, ...]:
        return struct.unpack_from(
            "<IIIIIIIIII", elf, e_shoff + index * e_shentsize
        )

    names_header = section_header(e_shstrndx)
    name_base = names_header[4]

    def section_name(offset: int) -> bytes:
        end = elf.index(b"\x00", name_base + offset)
        return elf[name_base + offset:end]

    sections: dict[bytes, tuple[int, ...]] = {}
    for index in range(e_shnum):
        item = section_header(index)
        sections[section_name(item[0])] = item

    dynsym = sections[b".dynsym"]
    dynstr_offset = sections[b".dynstr"][4]
    result: dict[int, str] = {}
    for section_key in (b".rel.dyn", b".rel.plt"):
        relocation_section = sections.get(section_key)
        if relocation_section is None:
            raise HierarchyLinkError(f"ELF section {section_key!r} is missing")
        for index in range(relocation_section[5] // 8):
            address, info = struct.unpack_from(
                "<II", elf, relocation_section[4] + index * 8
            )
            name_offset = struct.unpack_from(
                "<I",
                elf,
                dynsym[4] + (info >> 8) * dynsym[9],
            )[0]
            end = elf.index(b"\x00", dynstr_offset + name_offset)
            result[address] = elf[dynstr_offset + name_offset:end].decode(
                "ascii", "replace"
            )
    return result


def verify_bytes(elf: bytes) -> None:
    if hashlib.sha256(elf).hexdigest() != _SHA256:
        raise HierarchyLinkError(
            "ELF SHA-256 does not match the recorded libdefault.so"
        )
    actual_words = {
        address: struct.unpack_from("<I", elf, file_offset(elf, address))[0]
        for address in _WORDS
    }
    _verify_map(_WORDS, actual_words, "instruction")

    symbols = _dynamic_symbols(elf)
    _verify_map(
        _RELOCATIONS,
        {address: symbols[address] for address in _RELOCATIONS if address in symbols},
        "relocation",
    )

    actual_strings = {}
    for address, expected in _STRINGS.items():
        offset = file_offset(elf, address)
        actual_strings[address] = elf[offset:offset + len(expected)]
    _verify_map(_STRINGS, actual_strings, "literal")


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
        f"verified {len(_WORDS)} attacktofloor-link instructions, "
        f"{len(_RELOCATIONS)} relocations and {len(_STRINGS)} literal"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

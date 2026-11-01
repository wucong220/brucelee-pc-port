#!/usr/bin/env python3
"""Check static ARM root binding evidence in the recorded local ELF; never execute it."""
import argparse
import hashlib
import struct
import sys
from pathlib import Path

from native_hierarchy_links import HierarchyLinkError, file_offset, _section
from native_root_motion import _plt_target

SHA256 = '1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70'
# Exact instruction words preserve register flow and conditional branches.
WORDS = {
 0x407578:0xe92d45f0, 0x407588:0xe2806074, 0x407590:0xe1a05000,
 0x4075a4:0xe59f4138, 0x4075ac:0xe08f4004,
 0x407610:0xe59f30d0, 0x407614:0xe1a00007, 0x407618:0xe1a01006,
 0x40761c:0xe7942003, 0x407620:0xebf48080,
 0x407624:0xe59d300c, 0x407628:0xe3530000, 0x40762c:0x0a00000f,
 0x407630:0xe59d3010, 0x407634:0xe3530000, 0x407638:0x0a00000c,
 0x40763c:0xe59f30a8, 0x407640:0xe1a00007, 0x407644:0xe2852080,
 0x407648:0xe7941003, 0x40764c:0xebf4767f, 0x407650:0xe2506000,
 0x407654:0x1a000012, 0x4076a4:0xe59f3044, 0x4076a8:0xe1a00007,
 0x4076ac:0xe2852084, 0x4076b0:0xe7941003, 0x4076b4:0xebf47665,
 0x4076b8:0xe3500000, 0x4076bc:0x0affffe5, 0x4076c0:0xe59f302c,
 0x4076c4:0xe1a00007, 0x4076c8:0xe2852088, 0x4076cc:0xe7941003,
 0x4076d0:0xebf4765e, 0x4076d4:0xe3500000, 0x4076d8:0x0affffde,
 0x4076e4:0x001f5e64, 0x4076e8:0x5b8c, 0x4076ec:0x7938,
 0x4076f0:0x66d0, 0x4076f4:0x6108,
 # GetOutput: +0x80 index, three-word sample path and conditional BuildFrame.
 0x407afc:0xe593607c, 0x407b08:0xe284a080, 0x407b0c:0xe5947080,
 0x407b10:0xe596500c, 0x407b14:0xedd57a05, 0x407b18:0xeeb48a67,
 0x407b1c:0xeef1fa10, 0x407b20:0x01a03005, 0x407b24:0x1a000094,
 0x407b28:0xe5952008, 0x407b2c:0xe0877087, 0x407b34:0xe284500c,
 0x407b38:0xe0827107, 0x407b3c:0xe596c010, 0x407b40:0xe59ab004,
 0x407b44:0xe8970007, 0x407b48:0xe083700c, 0x407b4c:0xe8880007,
 0x407b50:0xe8850007, 0x407d7c:0xe1a00005, 0x407d80:0xee181a10,
 0x407d84:0xebf49101, 0x407d88:0xe596300c, 0x407d8c:0xeaffff65,
}
GOT = {0x602fa4:'_ZN3krm3anm13gid_CharacterE',
       0x604d50:'_ZN3krm3anm13gid_PositionsE',
       0x603ae8:'_ZN3krm3anm13gid_RotationsE',
       0x603520:'_ZN3krm3anm10gid_ScalesE'}
PLT = {0x127828:(0x600594, '_ZNK3krm12anmHeadChunk9FindChunkERKNS_3krt10HashStringINS1_10CHStrMgrNSEEE', (0xe28fc604,0xe28ccad8,0xe5bcfd64)),
       0x125050:(0x5ff84c, '_ZNK3krm12anmHeadChunk10FindOffsetERKNS_3krt10HashStringINS1_10CHStrMgrNSEEERj', (0xe28fc604,0xe28ccada,0xe5bcf7f4)),
       0x12c190:(0x601e0c, '_ZNK3krm3anm13CAnimProvider10BuildFrameEf', (0xe28fc604,0xe28ccad5,0xe5bcfc74))}

def relocations(elf, section):
    off, size, link, entsize, _ = _section(elf, section)
    sym, sym_size, _, sym_ent, _ = _section(elf, b'.dynsym')
    strings, str_size, _, _, _ = _section(elf, b'.dynstr')
    if entsize != 8 or size % 8 or sym_ent < 16 or off+size > len(elf) or sym+sym_size > len(elf) or strings+str_size > len(elf):
        raise HierarchyLinkError('invalid relocation or symbol section')
    out = {}
    for pos in range(off, off+size, 8):
        address, info = struct.unpack_from('<II', elf, pos)
        idx = info >> 8
        if idx*sym_ent+16 > sym_size:
            raise HierarchyLinkError('symbol index outside dynsym')
        name = struct.unpack_from('<I', elf, sym+idx*sym_ent)[0]
        if name >= str_size:
            raise HierarchyLinkError('symbol name outside dynstr')
        end = elf.find(b'\0', strings+name, strings+str_size)
        if end < 0:
            raise HierarchyLinkError('unterminated symbol name')
        if address in out:
            raise HierarchyLinkError('duplicate relocation')
        out[address] = (info & 255, elf[strings+name:end].decode('ascii'))
    return out

def branch(address, word):
    displacement = word & 0xffffff
    if displacement & 0x800000:
        displacement -= 0x1000000
    return address + 8 + displacement*4

def verify_bytes(elf, expected_sha256=SHA256):
    if hashlib.sha256(elf).hexdigest() != expected_sha256:
        raise HierarchyLinkError('ELF SHA-256 mismatch')
    try:
        if len(elf) < 52 or elf[:6] != b'\x7fELF\x01\x01' or struct.unpack_from('<HH',elf,16) != (3,40):
            raise HierarchyLinkError('expected little-endian ARM ELF32 ET_DYN')
        for address, expected in WORDS.items():
            pos = file_offset(elf,address)
            if pos+4 > len(elf) or struct.unpack_from('<I',elf,pos)[0] != expected:
                raise HierarchyLinkError(f'word mismatch at 0x{address:x}')
        gotbase = 0x4075b4 + WORDS[0x4076e4]
        if gotbase != 0x5fd418 or [gotbase+WORDS[a] for a in (0x4076e8,0x4076ec,0x4076f0,0x4076f4)] != list(GOT):
            raise HierarchyLinkError('literal/GOT computation mismatch')
        dynamic = relocations(elf,b'.rel.dyn')
        for address, name in GOT.items():
            if dynamic.get(address) != (21,name):
                raise HierarchyLinkError(f'GOT relocation mismatch at 0x{address:x}')
        calls = {0x407620:0x127828, 0x40764c:0x125050, 0x4076b4:0x125050, 0x4076d0:0x125050, 0x407d84:0x12c190}
        for address, target in calls.items():
            if branch(address,WORDS[address]) != target:
                raise HierarchyLinkError(f'call mismatch at 0x{address:x}')
        plt_rels = relocations(elf,b'.rel.plt')
        for address,(slot,name,expected) in PLT.items():
            pos=file_offset(elf,address)
            actual=struct.unpack_from('<III',elf,pos)
            if actual != expected or _plt_target(address,actual) != slot or plt_rels.get(slot) != (22,name):
                raise HierarchyLinkError(f'PLT relocation mismatch at 0x{address:x}')
    except (IndexError, KeyError, ValueError, struct.error) as exc:
        if isinstance(exc, HierarchyLinkError):
            raise
        raise HierarchyLinkError(f'malformed ELF: {exc}') from exc

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('elf',type=Path)
    args=parser.parse_args()
    try:
        verify_bytes(args.elf.read_bytes())
    except (OSError,HierarchyLinkError) as exc:
        print(f'error: {exc}',file=sys.stderr)
        return 1
    print('verified static UpdateBinding/GetOutput instructions, four GOT relocations and three PLT targets; no runtime behavior established')
    return 0

if __name__ == '__main__':
    sys.exit(main())

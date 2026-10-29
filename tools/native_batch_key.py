#!/usr/bin/env python3
"""Verify the observed three-word CGeometryBatcher grouping key."""
from __future__ import annotations
import argparse, hashlib, struct, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from native_hierarchy_links import HierarchyLinkError, file_offset
_SHA256='1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70'
_WORDS={
0x0032CDD0:0xE8860003, # stm r6,{r0,r1}; key words at +4/+8
0x0032CDD4:0xE785700C, # str r7,[r5,ip]; j word at +0
0x0032D6D4:0xE5942000, # ldr r2,[r4,#0]
0x0032D6E4:0xE594303C, # ldr r3,[r4,#0x3c]
0x0032D6E8:0xE1520003, # cmp r2,r3
0x0032D7D0:0xE5981004, # ldr r1,[r8,#4]
0x0032D7D4:0xE5943004, # ldr r3,[r4,#4]
0x0032D7D8:0xE1510003, # cmp r1,r3
0x0032D7E0:0xE5980008, # ldr r0,[r8,#8]
0x0032D7E4:0xE5943008, # ldr r3,[r4,#8]
0x0032D7E8:0xE1500003, # cmp r0,r3
0x0032D818:0xE5963000, # ldr r3,[r6,#0]
0x0032D81C:0xE1520003, # cmp r2,r3
0x0032D820:0x1AFFFFB2, # bne split
}
def verify_bytes(elf:bytes)->None:
 if hashlib.sha256(elf).hexdigest()!=_SHA256: raise HierarchyLinkError('ELF SHA-256 does not match the recorded libdefault.so')
 for address,expected in _WORDS.items():
  actual=struct.unpack_from('<I',elf,file_offset(elf,address))[0]
  if actual!=expected: raise HierarchyLinkError(f'instruction 0x{address:08x} is 0x{actual:08x}, expected 0x{expected:08x}')
def main()->int:
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('elf',type=Path);a=p.parse_args()
 try:verify_bytes(a.elf.read_bytes())
 except(OSError,HierarchyLinkError) as exc:print(f'error: {exc}',file=sys.stderr);return 1
 print(f'verified {len(_WORDS)} batch-key instructions');return 0
if __name__=='__main__':raise SystemExit(main())

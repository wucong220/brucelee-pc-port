#!/usr/bin/env python3
"""Verify the CShaderInstance table used as TBatchID by CRenderTargetBase::Commit."""
from __future__ import annotations
import argparse, hashlib, struct, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from native_hierarchy_links import HierarchyLinkError, file_offset
_SHA256='1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70'
_WORDS={
0x003070B8:0xE1A04001,0x003070C4:0xE1A05000,0x00307168:0xE59510CC,0x0030716C:0xE28DC058,0x00307170:0xE1A0200C,
0x00307174:0xE59D3098,0x00307178:0xE0844181,0x0030717C:0xE28440D4,
0x00307180:0xE8940003,0x00307184:0xE88C0003,0x00307188:0xE1A00007,
0x0030718C:0xE1A01006,0x00307190:0xEBF87B1A,
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
 print(f'verified {len(_WORDS)} TBatchID-source instructions');return 0
if __name__=='__main__':raise SystemExit(main())

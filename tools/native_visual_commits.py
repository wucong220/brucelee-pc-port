#!/usr/bin/env python3
"""Verify the observed per-visual subset commit loop in the known local ELF."""
from __future__ import annotations
import argparse, hashlib, struct, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from native_hierarchy_links import HierarchyLinkError, file_offset
_SHA256='1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70'
_WORDS={
0x0036E1B0:0xE5953050,0x0036E1BC:0xE5947014,0x0036E1C0:0xE3570000,
0x0036E1C8:0xE5944018,0x0036E1CC:0xE0847107,0x0036E1D8:0xE4942004,
0x0036E1FC:0xEBF6E2DA,0x0036E204:0x8AFFFFF3,0x0036E260:0xE2866030,
0x0036E268:0x1AFFFF9B,0x0036E434:0xE5953050,0x0036E440:0xE5947014,
0x0036E44C:0xE5944018,0x0036E45C:0xE4942004,0x0036E480:0xEBF6E239,
0x0036E4E4:0xE2866030,0x0036E4EC:0x1AFFFF9A,
}
def verify_bytes(elf:bytes)->None:
 if hashlib.sha256(elf).hexdigest()!=_SHA256: raise HierarchyLinkError('ELF SHA-256 does not match the recorded libdefault.so')
 for address,expected in _WORDS.items():
  offset=file_offset(elf,address); actual=struct.unpack_from('<I',elf,offset)[0]
  if actual!=expected: raise HierarchyLinkError(f'instruction 0x{address:08x} is 0x{actual:08x}, expected 0x{expected:08x}')
def main()->int:
 p=argparse.ArgumentParser(description=__doc__); p.add_argument('elf',type=Path); a=p.parse_args()
 try: verify_bytes(a.elf.read_bytes())
 except (OSError,HierarchyLinkError) as exc: print(f'error: {exc}',file=sys.stderr); return 1
 print(f'verified {len(_WORDS)} visual-subset commit instructions'); return 0
if __name__=='__main__': raise SystemExit(main())

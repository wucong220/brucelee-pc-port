#!/usr/bin/env python3
"""Verify CShaderInstance pass-mask construction and scene filtering."""
from __future__ import annotations
import argparse, hashlib, struct, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from native_draw_path import _dynamic_symbols
from native_hierarchy_links import HierarchyLinkError, file_offset
_SHA256='1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70'
_WORDS={
0x002FC5D4:0xE5845050,0x002FC6F4:0xE1A01005,0x002FC6F8:0xE1A02004,
0x002FC6FC:0xEBF89866,0x002FC71C:0xE5941050,0x002FC72C:0xE181151C,
0x002FC730:0xE5841050,0x002FD124:0xE5848050,0x0037297C:0xE5902050,
0x00372984:0xE1833002,0x00372988:0xE5853024,0x003729C0:0xE5902050,
0x003729C4:0xE1833002,0x003729C8:0xE5853024,0x0036E1B0:0xE5953050,
0x0036E1B4:0xE013321C,0x0036E1B8:0x0A000012,0x0036E434:0xE5953050,
0x0036E438:0xE013321C,0x0036E43C:0x0A000012,
}
_GET_VARIATION=(0x005FEB10,'CShader12GetVariation')
def verify_bytes(elf:bytes)->None:
 if hashlib.sha256(elf).hexdigest()!=_SHA256: raise HierarchyLinkError('ELF SHA-256 does not match the recorded libdefault.so')
 for address,expected in _WORDS.items():
  actual=struct.unpack_from('<I',elf,file_offset(elf,address))[0]
  if actual!=expected: raise HierarchyLinkError(f'instruction 0x{address:08x} is 0x{actual:08x}, expected 0x{expected:08x}')
 symbol=_dynamic_symbols(elf).get(_GET_VARIATION[0])
 if symbol is None or _GET_VARIATION[1] not in symbol: raise HierarchyLinkError(f'GetVariation relocation is {symbol!r}')
def main()->int:
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('elf',type=Path);a=p.parse_args()
 try:verify_bytes(a.elf.read_bytes())
 except(OSError,HierarchyLinkError) as exc:print(f'error: {exc}',file=sys.stderr);return 1
 print(f'verified {len(_WORDS)} pass-mask instructions and GetVariation');return 0
if __name__=='__main__':raise SystemExit(main())

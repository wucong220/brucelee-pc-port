#!/usr/bin/env python3
"""Extract selected named native functions from ARM ELF with readelf/nm.
Requires GNU nm + c++filt, or llvm-nm with C++ demangling in a compatible form.
Addresses are ELF symbol values, *not* absolute loaded process addresses.
"""
from __future__ import annotations
import argparse, csv, re, subprocess
from pathlib import Path

CATEGORIES={
 'resource': re.compile(r'(CPakDFilesManager|CPackagerFileSystem|CResManager|CResourceManager)',re.I),
 'fight': re.compile(r'(CFighter::|CBeatEmUpGame::|CBeatEmUpMatch::|StartFight\(|RestartFight\()',re.I),
 'animation': re.compile(r'(Animation|AnimLayer|CAnimationDescr)',re.I),
 'input': re.compile(r'(OnKeyPress|InputManager|OnMouseClick)',re.I),
}

def collect(path:Path):
    proc=subprocess.run(['nm','-D','-C',str(path)],text=True,capture_output=True,check=True)
    rows=[]
    for line in proc.stdout.splitlines():
        m=re.match(r'^([0-9a-fA-F]+)\s+([TtWw])\s+(.+)$',line)
        if not m:continue
        addr,typ,name=m.groups()
        categories=[cat for cat,rx in CATEGORIES.items() if rx.search(name)]
        if categories:rows.append({'address':f'0x{int(addr,16):08x}','kind':typ,'category':'|'.join(categories),'symbol':name})
    return sorted(rows,key=lambda x:int(x['address'],16))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('elf',type=Path);p.add_argument('--out',type=Path,required=True)
    a=p.parse_args();rows=collect(a.elf)
    a.out.parent.mkdir(parents=True,exist_ok=True)
    with a.out.open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=['address','kind','category','symbol']);w.writeheader();w.writerows(rows)
    print(f'{len(rows)} candidate symbols -> {a.out}')

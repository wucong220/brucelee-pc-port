#!/usr/bin/env python3
"""Safely extract only the three known resource members, never whole user archives."""
from __future__ import annotations
import argparse, shutil, zipfile
from pathlib import Path

def unpack(zpak:Path, output:Path):
    output.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(zpak) as z:
        for name in ('Core.pakh','Core.pakd000','metadata.xml'):
            info=z.getinfo(name)
            if info.file_size>150_000_000:raise ValueError('Unexpectedly large member')
            with z.open(name) as r,(output/name).open('wb') as w:shutil.copyfileobj(r,w,1024*1024)
            print(name,info.file_size)

if __name__=='__main__':
    a=argparse.ArgumentParser(description=__doc__);a.add_argument('zpak',type=Path);a.add_argument('--out',type=Path,required=True)
    b=a.parse_args();unpack(b.zpak,b.out)

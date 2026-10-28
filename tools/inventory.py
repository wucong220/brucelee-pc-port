#!/usr/bin/env python3
"""Read-only inventory of user-supplied Bruce Lee APK + external content ZIP/ZPAK.
No code from the APK is executed. Standard-library only.
"""
from __future__ import annotations
import argparse, hashlib, json, struct, zipfile
from pathlib import Path

EXPECTED = ('Core.pakh','Core.pakd000','metadata.xml')

def digest_file(path: Path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for part in iter(lambda:f.read(1024*1024),b''):h.update(part)
    return h.hexdigest()

def info(z: zipfile.ZipFile):
    return [{'name':e.filename, 'uncompressed':e.file_size,'compressed':e.compress_size,'crc32':f'{e.CRC:08x}'} for e in z.infolist() if not e.is_dir()]

def inventory(apk:Path, content:Path):
    report={'schema':1,'input':{},'android':{},'content':{},'unknowns':[]}
    for k,p in [('apk',apk),('content',content)]:
        if not p.is_file():raise FileNotFoundError(f'{k} missing: {p}')
        report['input'][k]={'path':str(p.resolve()), 'bytes':p.stat().st_size,'sha256':digest_file(p)}
    with zipfile.ZipFile(apk) as z:
        members={i.filename:i for i in z.infolist()}
        report['android']={'members':info(z), 'native_libraries':[]}
        for n in members:
            if n.startswith('lib/') and n.endswith('.so'):
                with z.open(n) as src:head=src.read(20)
                arch=struct.unpack_from('<H',head,18)[0] if head.startswith(b'\x7fELF') and len(head)>=20 else None
                report['android']['native_libraries'].append({'path':n,'elf_machine':arch,'elf_bits':32 if head[4]==1 else 64 if head[4]==2 else None})
    with zipfile.ZipFile(content) as z:
        names=z.namelist()
        if all(n in names for n in EXPECTED):
            report['content']={'kind':'zpak','members':info(z)}
            pakh=z.read('Core.pakh'); report['content']['pakh_signature']=pakh[:4].decode('ascii','backslashreplace')
            report['content']['pakh_bytes']=len(pakh)
            report['content']['pakh_u32_at_0x14']=struct.unpack_from('<I',pakh,0x14)[0] if len(pakh)>=0x18 else None
            report['unknowns']+=['The pakh 0x14 integer is not yet independently verified as an asset count','Core.pakd000 resource mapping and its internal file format are not reconstructed']
        else:
            report['content']={'kind':'container-zip','members':info(z)}
            if len(names)==1 and names[0].endswith('data.zpak'):
                report['unknowns'].append('This is the outer game-data ZIP, not data.zpak itself; extract data.zpak safely before inventory')
    return report

if __name__=='__main__':
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument('--apk',type=Path,required=True)
    a.add_argument('--zpak',type=Path,required=True)
    a.add_argument('--out',type=Path)
    args=a.parse_args();result=inventory(args.apk,args.zpak)
    data=json.dumps(result,indent=2,ensure_ascii=False)+'\n'
    if args.out:
        args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(data,encoding='utf-8');print('Saved',args.out)
    else:print(data)

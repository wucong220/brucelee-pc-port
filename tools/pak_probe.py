#!/usr/bin/env python3
"""Forensic, bounded probe of compressed frames in Core.pakd000.

WARNING: The original PAK container format has not been reconstructed.
Do not infer that sequential frames are individual named assets. Do not silently
continue past a truncated or ambiguous frame. The script consumes a ZPAK ZIP.
"""
from __future__ import annotations
import argparse, csv, io, struct, zipfile, zlib
from pathlib import Path

_MAX_COMPRESSED=4*1024*1024
_MAX_OUTPUT=1024*1024

def probe(zpak:Path,limit:int=64, output_dir:Path|None=None):
    records=[]
    with zipfile.ZipFile(zpak) as z, z.open('Core.pakd000') as f:
        offset=0
        for i in range(limit):
            header=f.read(8)
            if not header:break
            if len(header)!=8:
                records.append({'index':i,'pakd_offset':offset,'status':'truncated-header'});break
            cap,length=struct.unpack('<II',header)
            if not (0<cap<=_MAX_OUTPUT and 0<length<=_MAX_COMPRESSED):
                records.append({'index':i,'pakd_offset':offset,'declared_output_cap':cap,'compressed_bytes':length,'status':'unsupported-header'});break
            chunk=f.read(length)
            if len(chunk)!=length:
                records.append({'index':i,'pakd_offset':offset,'status':'truncated-payload'});break
            decompressor=zlib.decompressobj()
            try:
                data=decompressor.decompress(chunk,cap+1)
                if len(data)>cap:
                    status='output-over-cap'
                elif decompressor.eof and not decompressor.unconsumed_tail and not decompressor.unused_data:
                    status='complete-zlib-stream'
                else:
                    # The payload can fill the declared 256K block without an Adler-32
                    # trailer. No claim of complete file/stream is made.
                    status='partial-stream-or-block'
            except zlib.error as ex:
                records.append({'index':i,'pakd_offset':offset,'compressed_bytes':length,'status':'zlib-error','reason':str(ex)});break
            row={'index':i,'pakd_offset':offset,'declared_output_cap':cap,'compressed_bytes':length,'decoded_bytes':len(data),'status':status,'signature_hex':data[:16].hex()}
            records.append(row)
            if output_dir and status=='complete-zlib-stream':
                output_dir.mkdir(parents=True,exist_ok=True)
                (output_dir / f'frame_{i:04d}_{offset:010d}.bin').write_bytes(data)
            offset+=8+length
            if status!='complete-zlib-stream':break
    return records

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('zpak',type=Path);p.add_argument('--limit',type=int,default=64)
    p.add_argument('--csv',type=Path);p.add_argument('--extract-verified',type=Path)
    a=p.parse_args()
    rows=probe(a.zpak,a.limit,a.extract_verified)
    if a.csv:
        a.csv.parent.mkdir(parents=True,exist_ok=True)
        with a.csv.open('w',newline='',encoding='utf-8') as f:
            fields=['index','pakd_offset','declared_output_cap','compressed_bytes','decoded_bytes','status','signature_hex','reason']
            w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(rows)
        print('Wrote',a.csv)
    for row in rows:print(row)

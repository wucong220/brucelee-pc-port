#!/usr/bin/env python3
"""Read-only static check of GetOutput's UpdateBinding call in the known ARM ELF.

Register flow establishes the same object argument at this call site. The PLT
relocation names a local definition, but dynamic symbol interposition can select
another implementation at runtime; this check does not establish runtime binding.
"""
import argparse
import hashlib
import struct
import sys
from pathlib import Path

SHA256 = '1da7a30cb8344484bfed7a4d9d578e128bff69f22f73833d95db563b353b2e70'
SYMBOL = b'_ZN3krm3anm15CRootPlayerBase13UpdateBindingERKNS0_10CAnimStateE'
WORDS = {0x407a20: 0xe1a05001, 0x407a24: 0xe1a04000,
         0x407aa4: 0xe1a00004, 0x407aa8: 0xe1a01005,
         0x407aac: 0xebf45e45, 0x11f3c8: 0xe28fc604,
         0x11f3cc: 0xe28ccade, 0x11f3d0: 0xe5bcf5a4}

class VerificationError(ValueError):
    """The input does not match the recorded evidence."""

def verify_bytes(data, expected_sha256=SHA256):
    if hashlib.sha256(data).hexdigest() != expected_sha256:
        raise VerificationError('ELF SHA-256 mismatch')
    try:
        if len(data) < 52 or data[:6] != b'\x7fELF\x01\x01' or struct.unpack_from('<HH', data, 16) != (3, 40):
            raise VerificationError('expected little-endian ARM ELF32 ET_DYN')
        phoff, shoff = struct.unpack_from('<II', data, 28)
        phent, phnum, shent, shnum, shstr = struct.unpack_from('<HHHHH', data, 42)
        if phent < 32 or shent < 40 or phoff + phent * phnum > len(data) or shoff + shent * shnum > len(data) or shstr >= shnum:
            raise VerificationError('invalid ELF header tables')
        segments = [struct.unpack_from('<IIIII', data, phoff + i * phent) for i in range(phnum)]
        def word(address):
            for typ, offset, va, _, size in segments:
                if typ == 1 and va <= address and address + 4 <= va + size and offset + size <= len(data):
                    return struct.unpack_from('<I', data, offset + address - va)[0]
            raise VerificationError(f'address 0x{address:x} outside loadable bytes')
        for address, expected in WORDS.items():
            if word(address) != expected:
                raise VerificationError(f'word mismatch at 0x{address:x}')
        displacement = WORDS[0x407aac] & 0xffffff
        if displacement & 0x800000:
            displacement -= 0x1000000
        if 0x407aac + 8 + displacement * 4 != 0x11f3c8:
            raise VerificationError('branch target mismatch')
        # ADD ip,pc,#0x400000; ADD ip,ip,#0xde000; LDR pc,[ip,#0x5a4]!
        if 0x11f3c8 + 8 + 0x400000 + 0xde000 + 0x5a4 != 0x5fd974:
            raise VerificationError('PLT GOT calculation mismatch')
        headers = [struct.unpack_from('<IIIIIIIIII', data, shoff + i * shent) for i in range(shnum)]
        def contents(h):
            if h[4] + h[5] > len(data):
                raise VerificationError('section outside file')
            return data[h[4]:h[4]+h[5]]
        names = contents(headers[shstr])
        def string(blob, offset):
            if offset >= len(blob):
                raise VerificationError('string offset outside section')
            end = blob.find(b'\0', offset)
            if end < 0:
                raise VerificationError('unterminated string')
            return blob[offset:end]
        found = {}
        for index, h in enumerate(headers):
            name = string(names, h[0])
            if name in (b'.dynsym', b'.dynstr', b'.rel.plt'):
                if name in found:
                    raise VerificationError('duplicate section')
                found[name] = (index, h)
        symidx, sym = found[b'.dynsym']; stridx, strings_hdr = found[b'.dynstr']; _, rel = found[b'.rel.plt']
        if sym[1] != 11 or sym[6] != stridx or sym[9] != 16 or sym[5] % 16 or rel[1] != 9 or rel[6] != symidx or rel[9] != 8 or rel[5] % 8:
            raise VerificationError('invalid dynamic table metadata')
        syms, strings, rels = contents(sym), contents(strings_hdr), contents(rel)
        matches = []
        for i in range(0, len(syms), 16):
            name, value, size, info, other, section = struct.unpack_from('<IIIBBH', syms, i)
            if string(strings, name) == SYMBOL:
                matches.append((i // 16, value, size, info, other, section))
        if len(matches) != 1 or matches[0][1:5] != (0x407578, 384, 0x12, 0) or not 0 < matches[0][5] < shnum:
            raise VerificationError('dynamic symbol definition mismatch')
        entries = [struct.unpack_from('<II', rels, i) for i in range(0, len(rels), 8)]
        got = [info for address, info in entries if address == 0x5fd974]
        if got != [(matches[0][0] << 8) | 22]:
            raise VerificationError('GOT relocation mismatch')
        initial_got = word(0x5fd974)
        return {'got_initial': initial_got, 'symbol_address': 0x407578, 'symbol_size': 384}
    except (KeyError, IndexError, struct.error, OverflowError) as exc:
        raise VerificationError(f'malformed ELF: {exc}') from exc

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('elf', type=Path)
    args = parser.parse_args()
    try:
        result = verify_bytes(args.elf.read_bytes())
    except (OSError, VerificationError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    print(f"verified GetOutput same-object argument and UpdateBinding PLT relocation; GOT file value 0x{result['got_initial']:x}; local dynsym 0x407578 size 384. Interposition may change runtime binding; runtime is not verified.")
    return 0

if __name__ == '__main__':
    sys.exit(main())

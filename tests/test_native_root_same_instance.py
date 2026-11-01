import hashlib
import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from native_root_same_instance import VerificationError, verify_bytes

# Frozen fixture, independently specified; no original binary bytes are used.
def fixture():
    b = bytearray(0x600800)
    b[:6] = b'\x7fELF\x01\x01'
    struct.pack_into('<HH', b, 16, 3, 40)
    struct.pack_into('<II', b, 28, 52, 0x600500)
    struct.pack_into('<HHHHH', b, 42, 32, 1, 40, 5, 1)
    struct.pack_into('<IIIII', b, 52, 1, 0, 0, 0, 0x5fe000)
    for address, word in ((0x407a20,0xe1a05001),(0x407a24,0xe1a04000),
                          (0x407aa4,0xe1a00004),(0x407aa8,0xe1a01005),
                          (0x407aac,0xebf45e45),(0x11f3c8,0xe28fc604),
                          (0x11f3cc,0xe28ccade),(0x11f3d0,0xe5bcf5a4)):
        struct.pack_into('<I', b, address, word)
    struct.pack_into('<I', b, 0x5fd974, 0x11e3c4)
    names = b'\0.shstrtab\0.dynstr\0.dynsym\0.rel.plt\0'
    strings = b'\0_ZN3krm3anm15CRootPlayerBase13UpdateBindingERKNS0_10CAnimStateE\0'
    b[0x600000:0x600000+len(names)] = names
    b[0x600100:0x600100+len(strings)] = strings
    struct.pack_into('<IIIBBH', b, 0x600210, 1, 0x407578, 384, 0x12, 0, 4)
    struct.pack_into('<II', b, 0x600300, 0x5fd974, 0x116)
    def section(i, name, typ, off, size, link=0, ent=0):
        struct.pack_into('<IIIIIIIIII', b, 0x600500+i*40, names.index(name), typ, 0, 0, off, size, link, 0, 1, ent)
    section(1,b'.shstrtab',3,0x600000,len(names))
    section(2,b'.dynstr',3,0x600100,len(strings))
    section(3,b'.dynsym',11,0x600200,32,2,16)
    section(4,b'.rel.plt',9,0x600300,8,3,8)
    return b

def check(b):
    return verify_bytes(bytes(b), hashlib.sha256(b).hexdigest())

class SameInstanceTests(unittest.TestCase):
    def test_valid_fixture(self):
        self.assertEqual(check(fixture())['got_initial'], 0x11e3c4)

    def test_instruction_plt_and_relocation_mutations(self):
        for address in (0x407a20,0x407a24,0x407aa4,0x407aa8,0x407aac,
                        0x11f3c8,0x11f3cc,0x11f3d0,0x600300,0x600304,
                        0x600101,0x600214,0x600218,0x60021c,0x60021e):
            with self.subTest(address=hex(address)):
                b = fixture(); b[address] ^= 1
                with self.assertRaises(VerificationError): check(b)

    def test_digest_truncation_and_table_links(self):
        with self.assertRaises(VerificationError): verify_bytes(bytes(fixture()))
        with self.assertRaises(VerificationError): check(fixture()[:100])
        for address in (0x600500+3*40+24, 0x600500+4*40+24):
            b = fixture(); b[address] ^= 1
            with self.assertRaises(VerificationError): check(b)

if __name__ == '__main__':
    unittest.main()

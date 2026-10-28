import io, struct, sys, tempfile, unittest, zipfile, zlib
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from inventory import inventory
from pak_probe import probe

class TestPreservationTooling(unittest.TestCase):
    def test_valid_synthetic_bundle(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);apk=root/'a.apk';zpak=root/'data.zpak'
            with zipfile.ZipFile(apk,'w') as z:
                e=bytearray(32);e[:4]=b'\x7fELF';e[4]=1;struct.pack_into('<H',e,18,40)
                z.writestr('lib/armeabi/libexample.so',e)
            with zipfile.ZipFile(zpak,'w') as z:
                hdr=b'8KAP'+bytes(16)+struct.pack('<I',2144)+bytes(40)
                z.writestr('Core.pakh',hdr)
                data=b'RIFF' + bytes(16)
                packed=zlib.compress(data)
                z.writestr('Core.pakd000',struct.pack('<II',262144,len(packed))+packed)
                z.writestr('metadata.xml',b'<metadata/>')
            meta=inventory(apk,zpak)
            self.assertEqual(meta['android']['native_libraries'][0]['elf_machine'],40)
            self.assertEqual(meta['content']['pakh_signature'],'8KAP')
            self.assertEqual(meta['content']['pakh_u32_at_0x14'],2144)
            frames=probe(zpak)
            self.assertEqual(len(frames),1)
            self.assertEqual(frames[0]['status'],'complete-zlib-stream')
            self.assertEqual(frames[0]['decoded_bytes'],20)

    def test_incomplete_zlib_not_labeled_complete(self):
        with tempfile.TemporaryDirectory() as d:
            zpak=Path(d)/'data.zpak';raw=b'x'*262144
            compressed=zlib.compress(raw)
            with zipfile.ZipFile(zpak,'w') as z:
                z.writestr('Core.pakd000',struct.pack('<II',262144,len(compressed)-4)+compressed[:-4])
            res=probe(zpak)
            self.assertEqual(res[0]['status'],'partial-stream-or-block')

    def test_bad_header_stops_without_guessing(self):
        with tempfile.TemporaryDirectory() as d:
            zpak=Path(d)/'data.zpak'
            with zipfile.ZipFile(zpak,'w') as z:
                z.writestr('Core.pakd000',struct.pack('<II',2**31,2**31))
            res=probe(zpak)
            self.assertEqual(res[0]['status'],'unsupported-header')

if __name__=='__main__':unittest.main()

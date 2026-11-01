import hashlib
import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from native_hierarchy_links import HierarchyLinkError
from native_root_binding import GOT, PLT, WORDS, verify_bytes

def fixture():
    # Synthetic ELF with one load segment and independently constructed tables.
    b=bytearray(0x409000)
    b[:6]=b'\x7fELF\x01\x01'
    struct.pack_into('<HH',b,16,3,40)
    struct.pack_into('<I',b,28,52)
    struct.pack_into('<HH',b,42,32,1)
    struct.pack_into('<IIIII',b,52,1,0,0,0,0x408000)
    for a,w in WORDS.items(): struct.pack_into('<I',b,a,w)
    for a,(_,_,words) in PLT.items(): struct.pack_into('<III',b,a,*words)
    names=b'\0.shstrtab\0.dynstr\0.dynsym\0.rel.dyn\0.rel.plt\0'
    shstr=0x408000; b[shstr:shstr+len(names)]=names
    dynstr=0x408100; sym=0x408600; rd=0x408800; rp=0x408880; sh=0x408a00
    strings=bytearray(b'\0'); entries=[]
    for slot,name in GOT.items(): entries.append((rd,slot,21,name))
    for _,(slot,name,_) in PLT.items(): entries.append((rp,slot,22,name))
    counts={rd:0,rp:0}
    for index,(section,slot,typ,name) in enumerate(entries,1):
        namepos=len(strings); strings.extend(name.encode()+b'\0')
        struct.pack_into('<I',b,sym+index*16,namepos)
        struct.pack_into('<II',b,section+counts[section]*8,slot,index*256+typ)
        counts[section]+=1
    b[dynstr:dynstr+len(strings)]=strings
    struct.pack_into('<I',b,32,sh); struct.pack_into('<HHH',b,46,40,6,1)
    def section(index,name,typ,offset,size,link=0,entsize=0):
        struct.pack_into('<IIIIIIIIII',b,sh+index*40,names.index(name),typ,0,0,offset,size,link,0,1,entsize)
    section(1,b'.shstrtab',3,shstr,len(names))
    section(2,b'.dynstr',3,dynstr,len(strings))
    section(3,b'.dynsym',11,sym,(len(entries)+1)*16,2,16)
    section(4,b'.rel.dyn',9,rd,counts[rd]*8,3,8)
    section(5,b'.rel.plt',9,rp,counts[rp]*8,3,8)
    return b

def check(b): verify_bytes(bytes(b),hashlib.sha256(b).hexdigest())

class BindingTests(unittest.TestCase):
    def test_synthetic_elf(self): check(fixture())
    def test_instruction_and_offset_mutations(self):
        for address in (0x407610,0x407644,0x4076e4,0x4076f0,0x407620,0x127828,0x407b0c,0x407b24,0x407b38,0x407d84,0x407d8c):
            with self.subTest(address=hex(address)):
                b=fixture(); b[address]^=1
                with self.assertRaises(HierarchyLinkError): check(b)
    def test_relocation_type_slot_and_symbol(self):
        for address in (0x408800,0x408804,0x408880,0x408884,0x408101):
            with self.subTest(address=hex(address)):
                b=fixture(); b[address]^=1
                with self.assertRaises(HierarchyLinkError): check(b)
    def test_digest_and_truncation(self):
        with self.assertRaises(HierarchyLinkError): verify_bytes(bytes(fixture()))
        b=fixture()[:100]
        with self.assertRaises(HierarchyLinkError): check(b)

if __name__=='__main__': unittest.main()

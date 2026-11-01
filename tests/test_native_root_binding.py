import hashlib
import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from native_hierarchy_links import HierarchyLinkError
from native_root_binding import verify_bytes

# Independent, frozen fixture values; not imported from the verifier.
FIXTURE_WORDS = {4221052: 3785379841,
 4221060: 3785375744,
 4221124: 3851759616,
 4221136: 3800240268,
 4221140: 3785359363,
 4221160: 3958667712,
 4221164: 3818922024,
 4221168: 3785363456,
 4221172: 3785359364,
 4221176: 3958666931,
 4224376: 3912058352,
 4224388: 3800137776,
 4224392: 3800064116,
 4224396: 3785363464,
 4224400: 3785379840,
 4224420: 3852419384,
 4224428: 3767484420,
 4224528: 3852415184,
 4224532: 3785359367,
 4224536: 3785363462,
 4224540: 3885244419,
 4224544: 3958669440,
 4224548: 3852283916,
 4224552: 3813867520,
 4224556: 167772175,
 4224560: 3852283920,
 4224564: 3813867520,
 4224568: 167772172,
 4224572: 3852415144,
 4224576: 3785359367,
 4224580: 3800375424,
 4224584: 3885240323,
 4224588: 3958666879,
 4224592: 3796918272,
 4224596: 436207634,
 4224676: 3852415044,
 4224680: 3785359367,
 4224684: 3800375428,
 4224688: 3885240323,
 4224692: 3958666853,
 4224696: 3813670912,
 4224700: 184549349,
 4224704: 3852415020,
 4224708: 3785359367,
 4224712: 3800375432,
 4224716: 3885240323,
 4224720: 3958666846,
 4224724: 3813670912,
 4224728: 184549342,
 4224740: 2055780,
 4224744: 23436,
 4224748: 31032,
 4224752: 26320,
 4224756: 24840,
 4225568: 3785379841,
 4225572: 3785375744,
 4225788: 3851640956,
 4225800: 3800342656,
 4225804: 3851710592,
 4225808: 3851833356,
 4225812: 3990190597,
 4225816: 4004809319,
 4225820: 4008835600,
 4225824: 27275269,
 4225828: 436207764,
 4225832: 3851755528,
 4225836: 3766972551,
 4225844: 3800322060,
 4225848: 3766644999,
 4225852: 3851862032,
 4225856: 3852120068,
 4225860: 3902210055,
 4225864: 3766710284,
 4225868: 3901227015,
 4225872: 3901030407,
 4226428: 3785359365,
 4226432: 3994556944,
 4226436: 3958673665,
 4226440: 3851825164,
 4226444: 3942645605}
FIXTURE_GOT = {6303652: '_ZN3krm3anm13gid_CharacterE',
 6305056: '_ZN3krm3anm10gid_ScalesE',
 6306536: '_ZN3krm3anm13gid_RotationsE',
 6311248: '_ZN3krm3anm13gid_PositionsE'}
FIXTURE_PLT = {1200208: (6289484,
           '_ZNK3krm12anmHeadChunk10FindOffsetERKNS_3krt10HashStringINS1_10CHStrMgrNSEEERj',
           (3801073156, 3800877786, 3854366708)),
 1210408: (6292884,
           '_ZNK3krm12anmHeadChunk9FindChunkERKNS_3krt10HashStringINS1_10CHStrMgrNSEEE',
           (3801073156, 3800877784, 3854368100)),
 1229200: (6299148,
           '_ZNK3krm3anm13CAnimProvider10BuildFrameEf',
           (3801073156, 3800877781, 3854367860))}

def fixture():
    # Synthetic ELF with one load segment and independently constructed tables.
    b=bytearray(0x409000)
    b[:6]=b'\x7fELF\x01\x01'
    struct.pack_into('<HH',b,16,3,40)
    struct.pack_into('<I',b,28,52)
    struct.pack_into('<HH',b,42,32,1)
    struct.pack_into('<IIIII',b,52,1,0,0,0,0x408000)
    for a,w in FIXTURE_WORDS.items(): struct.pack_into('<I',b,a,w)
    for a,(_,_,words) in FIXTURE_PLT.items(): struct.pack_into('<III',b,a,*words)
    names=b'\0.shstrtab\0.dynstr\0.dynsym\0.rel.dyn\0.rel.plt\0'
    shstr=0x408000; b[shstr:shstr+len(names)]=names
    dynstr=0x408100; sym=0x408600; rd=0x408800; rp=0x408880; sh=0x408a00
    strings=bytearray(b'\0'); entries=[]
    for slot,name in FIXTURE_GOT.items(): entries.append((rd,slot,21,name))
    for _,(slot,name,_) in FIXTURE_PLT.items(): entries.append((rp,slot,22,name))
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
        for address in (0x407610,0x407644,0x4076e4,0x4076f0,0x407620,0x127828,0x407b0c,0x407b24,0x407b38,0x407d84,0x407d8c,0x407590,0x407a20,0x407a24,0x40687c,0x406884,0x4068c4,0x4068d0,0x4068d4,0x4068e8,0x4068f0,0x4068f4,0x4068f8):
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

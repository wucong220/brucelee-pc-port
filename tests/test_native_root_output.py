import hashlib
import struct
import sys
from pathlib import Path
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from native_hierarchy_links import HierarchyLinkError
import native_root_output
from native_root_output import _WORDS, verify_bytes


def _elf_fixture(*, bad_word: int | None = None,
                 symbol_address: int = 0x00407A04,
                 symbol_size: int = 936) -> bytes:
    load_offset = 0x100
    load_vaddr = 0x400000
    load_size = 0x8000
    image = bytearray(0x9000)
    image[0:4] = b"\x7fELF"
    image[4:6] = b"\x01\x01"  # ELF32, little endian
    image[6] = 1
    struct.pack_into("<I", image, 28, 52)          # e_phoff
    struct.pack_into("<I", image, 32, 0x2000)      # e_shoff
    struct.pack_into("<HHH", image, 42, 32, 1, 40)
    struct.pack_into("<HHH", image, 46, 40, 4, 3)
    struct.pack_into("<IIIIIIII", image, 52,
                     1, load_offset, load_vaddr, 0, load_size, load_size, 5, 4)
    for address, word in _WORDS.items():
        if address == bad_word:
            word ^= 1
        struct.pack_into("<I", image, load_offset + address - load_vaddr, word)

    shstr = b"\0.symtab\0.strtab\0.shstrtab\0"
    symstr = b"\0" + native_root_output._SYMBOL.encode("ascii") + b"\0"
    shstr_off = 0x2800
    symstr_off = 0x2900
    symtab_off = 0x2980
    image[shstr_off:shstr_off + len(shstr)] = shstr
    image[symstr_off:symstr_off + len(symstr)] = symstr
    struct.pack_into("<IIIBBH", image, symtab_off,
                    1, symbol_address, symbol_size, 0x12, 0, 1)
    sh = 0x2000
    def section(index, name, kind, offset, size, link=0, entsize=0):
        struct.pack_into("<IIIIIIIIII", image, sh + index * 40,
                         name, kind, 0, 0, offset, size, link, 0, 4, entsize)
    section(0, 0, 0, 0, 0)
    section(1, 1, 2, symtab_off, 16, link=2, entsize=16)
    section(2, 9, 3, symstr_off, len(symstr))
    section(3, 17, 3, shstr_off, len(shstr))
    return bytes(image)


class TestNativeRootOutput(unittest.TestCase):
    def test_unknown_binary_is_rejected(self):
        with self.assertRaisesRegex(HierarchyLinkError, "SHA-256"):
            verify_bytes(b"not the recorded ELF")

    def test_complete_fixture_passes(self):
        elf = _elf_fixture()
        with patch.object(native_root_output, "_SHA256",
                          hashlib.sha256(elf).hexdigest()):
            result = verify_bytes(elf)
        self.assertEqual(result["address"], 0x00407A04)
        self.assertEqual(result["output_offsets"], [0xC, 0x10, 0x14])

    def test_wrong_instruction_is_rejected(self):
        elf = _elf_fixture(bad_word=0x00407B44)
        with patch.object(native_root_output, "_SHA256",
                          hashlib.sha256(elf).hexdigest()):
            with self.assertRaisesRegex(HierarchyLinkError, "instruction"):
                verify_bytes(elf)

    def test_wrong_symbol_is_rejected(self):
        elf = _elf_fixture(symbol_address=0x00407A08)
        with patch.object(native_root_output, "_SHA256",
                          hashlib.sha256(elf).hexdigest()):
            with self.assertRaisesRegex(HierarchyLinkError, "symbol"):
                verify_bytes(elf)


if __name__ == "__main__":
    unittest.main()

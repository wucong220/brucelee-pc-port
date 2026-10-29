import struct
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from native_hierarchy_links import HierarchyLinkError, file_offset, verify_bytes


def elf_with_word(address: int, word: int) -> bytes:
    payload_offset = 52 + 32
    padding = address
    raw = bytearray(payload_offset + padding + 4)
    raw[0:4] = b"\x7fELF"
    raw[4] = 1
    raw[5] = 1
    struct.pack_into("<I", raw, 28, 52)
    struct.pack_into("<HH", raw, 42, 32, 1)
    struct.pack_into("<IIIII", raw, 52, 1, payload_offset, 0, 0, padding + 4)
    struct.pack_into("<I", raw, payload_offset + address, word)
    return bytes(raw)


class TestNativeHierarchyLinks(unittest.TestCase):
    def test_load_segment_translates_virtual_address(self):
        raw = elf_with_word(0x20, 0x11223344)
        self.assertEqual(file_offset(raw, 0x20), 52 + 32 + 0x20)
        with self.assertRaises(HierarchyLinkError):
            file_offset(raw, 0x1000)

    def test_recorded_binary_mismatch_is_rejected(self):
        with self.assertRaisesRegex(HierarchyLinkError, "SHA-256"):
            verify_bytes(elf_with_word(0x20, 0))


if __name__ == "__main__":
    unittest.main()

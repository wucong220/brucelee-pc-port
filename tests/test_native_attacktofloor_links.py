from pathlib import Path
import sys
import hashlib
import struct
from unittest.mock import patch
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import native_attacktofloor_links as native
from native_attacktofloor_links import _verify_map, verify_bytes
from native_hierarchy_links import HierarchyLinkError


class TestNativeAttackToFloorLinks(unittest.TestCase):
    def test_unknown_binary_is_rejected(self):
        with self.assertRaisesRegex(HierarchyLinkError, "SHA-256"):
            verify_bytes(b"not the recorded ELF")

    def test_instruction_mismatch_is_rejected(self):
        with self.assertRaisesRegex(
            HierarchyLinkError, r"instruction at 0x00000010 is 2, expected 1"
        ):
            _verify_map({0x10: 1}, {0x10: 2}, "instruction")

    def test_parser_and_array_instruction_mutations_are_rejected(self):
        # Build an in-memory fixture with virtual addresses mapped to the same
        # offsets; bypass only ELF parsing and authenticate the mutated fixture.
        critical = (0x1A1F94, 0x1A1F98, 0x1A80F0, 0x1A80F4,
                    0x1A80FC, 0x22E4A8, 0x22E52C, 0x22E5E4,
                    0x22E690, 0x22E6FC, 0x22E7A8, 0x22E7D4,
                    0x22E7E8, 0x2320D4, 0x2320D8)
        fixture = bytearray(max(max(native._WORDS), max(native._STRINGS)) + 8)
        for address, word in native._WORDS.items():
            struct.pack_into("<I", fixture, address, word)
        for address, value in native._STRINGS.items():
            fixture[address:address + len(value)] = value
        with patch.object(native, "file_offset", side_effect=lambda elf, address: address), \
             patch.object(native, "_dynamic_symbols", return_value=native._RELOCATIONS):
            with patch.object(native, "_SHA256", hashlib.sha256(fixture).hexdigest()):
                verify_bytes(fixture)
            for address in critical:
                with self.subTest(address=hex(address)):
                    self.assertIn(address, native._WORDS)
                    altered = bytearray(fixture)
                    altered[address] ^= 1
                    with patch.object(native, "_SHA256", hashlib.sha256(altered).hexdigest()):
                        with self.assertRaisesRegex(HierarchyLinkError, f"instruction at 0x{address:08x}"):
                            verify_bytes(altered)

    def test_missing_relocation_is_rejected(self):
        with self.assertRaisesRegex(
            HierarchyLinkError, r"relocation at 0x00000020 is missing"
        ):
            _verify_map({0x20: "expected"}, {}, "relocation")

    def test_relocations_cannot_be_swapped(self):
        with self.assertRaisesRegex(HierarchyLinkError, r"relocation at 0x00000030"):
            _verify_map(
                {0x30: "gid_laying", 0x34: "gid_OppPoseLaying"},
                {0x30: "gid_OppPoseLaying", 0x34: "gid_laying"},
                "relocation",
            )

    def test_literal_mismatch_is_rejected(self):
        with self.assertRaisesRegex(HierarchyLinkError, r"literal at 0x00000040"):
            _verify_map(
                {0x40: b"pose\x00"},
                {0x40: b"puse\x00"},
                "literal",
            )


if __name__ == "__main__":
    unittest.main()

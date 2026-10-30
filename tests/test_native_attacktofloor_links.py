from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
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

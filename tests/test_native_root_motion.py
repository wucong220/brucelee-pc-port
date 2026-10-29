from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from native_hierarchy_links import HierarchyLinkError
from native_root_motion import _plt_target, verify_bytes


class TestNativeRootMotion(unittest.TestCase):
    def test_plt_stub_resolves_its_got_slot(self):
        words = (0xE28FC604, 0xE28CCAD6, 0xE5BCF244)
        self.assertEqual(_plt_target(0x12B8D8, words), 0x601B24)
        self.assertNotEqual(_plt_target(0x12B8D8, words[:2] + (0xE5BCF240,)), 0x601B24)

    def test_unknown_binary_is_rejected(self):
        with self.assertRaisesRegex(HierarchyLinkError, "SHA-256"):
            verify_bytes(b"not the recorded ELF")


if __name__ == "__main__":
    unittest.main()

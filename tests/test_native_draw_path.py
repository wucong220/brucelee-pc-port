from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from native_draw_path import verify_bytes
from native_hierarchy_links import HierarchyLinkError


class TestNativeDrawPath(unittest.TestCase):
    def test_unknown_binary_is_rejected(self):
        with self.assertRaisesRegex(HierarchyLinkError, "SHA-256"):
            verify_bytes(b"not the recorded ELF")


if __name__ == "__main__":
    unittest.main()

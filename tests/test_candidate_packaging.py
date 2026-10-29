from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class CandidatePackagingTests(unittest.TestCase):
    def test_windows_export_includes_runtime_path_resolver(self):
        preset = (ROOT / "godot" / "export_presets.cfg").read_text(encoding="utf-8")
        resolver = ROOT / "godot" / "tools" / "resolve_candidate_path.ps1"

        self.assertIn('include_filter="tools/*.ps1"', preset)
        self.assertTrue(resolver.is_file())
        self.assertIn("GetFinalPathNameByHandleW", resolver.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from automation import codex_dispatch as m


class ValidatePaths(unittest.TestCase):
    def test_allowed_source_files(self):
        with tempfile.TemporaryDirectory() as t:
            self.assertTrue(m.valid_staged("tools/pak_extract.py", Path(t)))
            self.assertTrue(m.valid_staged("reports/P1_validation.md", Path(t)))
            self.assertTrue(m.valid_staged("godot/scripts/fighter.gd", Path(t)))

    def test_rejects_game_binary_and_unexpected_paths(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            for path in ("godot/assets/lee.glb", "reports/example.apk", "tools/key.pem",
                         "outside/hello.py", "reports/../secrets.txt", "reports/original.wav"):
                self.assertFalse(m.valid_staged(path, root), path)

    def test_rejects_large_file(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            (root / "reports").mkdir()
            (root / "reports" / "large.md").write_bytes(b"a" * 3_000_001)
            self.assertFalse(m.valid_staged("reports/large.md", root))

    def test_issue_author_and_ready_label(self):
        fake = [
            {"number": 3, "title": "bad", "body": "", "author": {"login": "stranger"}, "labels": [{"name": "codex-ready"}]},
            {"number": 2, "title": "good", "body": "", "author": {"login": m.OWNER}, "labels": [{"name": "codex-ready"}]},
            {"number": 1, "title": "not ready", "body": "", "author": {"login": m.OWNER}, "labels": []},
        ]

        class FakeResult:
            stdout = __import__("json").dumps(fake)

        with patch.object(m, "command", return_value=FakeResult()):
            self.assertEqual([i["number"] for i in m.ready_issues()], [2])


if __name__ == "__main__":
    unittest.main()

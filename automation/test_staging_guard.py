import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from automation import staging_guard as guard


class TestStagingGuard(unittest.TestCase):
    def test_paths_are_bounded(self):
        for path in ("reports/ok.md", "automation/check.py", ".gitignore"):
            self.assertTrue(guard.allowed_path(path), path)
        for path in ("../secret.md", "reports/../secret.md", "reports/secret.bin",
                     "reports/a:stream.md", "outside/a.md", "reports\\secret.md", "reports/a\nfile.md"):
            self.assertFalse(guard.allowed_path(path), path)

    def test_content_blocks_binary_invalid_utf8_and_known_credentials(self):
        gh_credential = ("gh" + "p_" + "A" * 40).encode()
        key_header = ("-----BEGIN " + "PRIVATE KEY-----\n" + "A" * 40).encode()
        assignment = ("pass" + "word=" + "c" * 24).encode()
        for data in (b"\x00binary", b"\xff", b"%PDF-fake", gh_credential, key_header, assignment):
            with self.subTest(size=len(data)):
                with self.assertRaises(guard.ValidationError):
                    guard.check_blob("reports/file.md", data)
        guard.check_blob("reports/file.md", "正常文本\r\n".encode("utf-8"))

    def test_error_does_not_include_credential(self):
        secret = ("gh" + "p_" + "B" * 40).encode()
        with self.assertRaises(guard.ValidationError) as raised:
            guard.check_blob("reports/file.md", secret)
        self.assertNotIn(secret.decode(), str(raised.exception))

    def test_index_blob_is_checked_instead_of_worktree(self):
        oid = "a" * 40
        record = f"100644 {oid} 0\treports/file.md\0".encode()
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "reports").mkdir()
            (root / "reports" / "file.md").write_text("safe working file", encoding="utf-8")

            def fake_git(_root, *args):
                if args[0] == "ls-files": return record
                if args[:2] == ("cat-file", "-s"): return b"7\n"
                if args[:2] == ("cat-file", "blob"): return b"\x00binary"
                raise AssertionError(args)

            with patch.object(guard, "_git", side_effect=fake_git):
                with self.assertRaises(guard.ValidationError):
                    guard.read_index(root)

    def test_index_rejects_symlink_and_conflict(self):
        oid = "a" * 40
        for mode, stage in (("120000", "0"), ("100644", "1")):
            record = f"{mode} {oid} {stage}\treports/file.md\0".encode()
            with self.subTest(mode=mode, stage=stage), patch.object(guard, "_git", return_value=record):
                with self.assertRaises(guard.ValidationError):
                    guard.read_index(Path("."))

    def test_changed_index_tree_is_rejected(self):
        with patch.object(guard, "index_tree", side_effect=["a" * 40, "b" * 40]), \
             patch.object(guard, "read_index", return_value={"README.md": b"ok"}):
            with self.assertRaises(guard.ValidationError):
                guard.validated_index(Path("."))


if __name__ == "__main__":
    unittest.main()

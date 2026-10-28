import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
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

    def test_rejects_junction_in_parent_path(self):
        with tempfile.TemporaryDirectory() as t, patch.object(Path, "is_junction", return_value=True):
            self.assertFalse(m.valid_staged("reports/result.md", Path(t)))

    def test_origin_checks_both_fetch_and_push_destinations(self):
        def fake_command(*args, **_kwargs):
            if args[:2] == ("git", "branch"): return SimpleNamespace(stdout="main\n")
            if args[:2] == ("git", "status"): return SimpleNamespace(stdout="")
            if "--push" in args: return SimpleNamespace(stdout="https://evil.invalid/github.com/wucong220/brucelee-pc-port\n")
            return SimpleNamespace(stdout="https://github.com/wucong220/brucelee-pc-port.git\n")
        with patch.object(m, "command", side_effect=fake_command):
            with self.assertRaises(RuntimeError):
                m.clean_main()

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


class TestPublishGate(unittest.TestCase):
    def _run(self, *, sandbox_error=None, final_tree="tree-id", remaining_status="", parent="base-id"):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "reports").mkdir()
            (root / "reports" / "result.md").write_text("safe", encoding="utf-8")
            calls = []
            diff_count = 0

            def fake_command(*args, **_kwargs):
                nonlocal diff_count
                calls.append(args)
                code, out = 0, ""
                if args[:2] == ("git", "show-ref"): code = 1
                elif args[:2] == ("git", "branch"): out = "codex/issue-7\n"
                elif args[:3] == ("git", "rev-parse", "HEAD"): out = "base-id\n"
                elif args[:3] == ("git", "rev-parse", "HEAD^{tree}"): out = final_tree + "\n"
                elif args[:2] == ("git", "rev-list"): out = "new-id " + parent + "\n"
                elif args[:4] == ("git", "diff", "--cached", "--name-only"):
                    diff_count += 1
                    out = "" if diff_count == 1 else "reports/result.md\0"
                elif args[:2] == ("git", "ls-files"): out = "reports/result.md\0"
                elif args[:4] == ("git", "-c", "status.renames=false", "status"): out = remaining_status
                elif args[:3] == ("gh", "pr", "create"): out = "https://example.invalid/pr\n"
                return SimpleNamespace(returncode=code, stdout=out, stderr="")

            sandbox_effect = sandbox_error if sandbox_error else None
            with patch.object(m, "ROOT", root), patch.object(m, "clean_main"), \
                 patch.object(m, "local_log_dir", return_value=root), \
                 patch.object(m, "command", side_effect=fake_command), \
                 patch.object(m.subprocess, "run", return_value=SimpleNamespace(returncode=0)), \
                 patch.object(m.staging_guard, "validated_index", return_value=("tree-id", {"reports/result.md": b"safe"})), \
                 patch.object(m.staging_guard, "index_tree", return_value="tree-id"), \
                 patch.object(m, "verify_origin"), \
                 patch.object(m.sandbox_tests, "run_isolated", side_effect=sandbox_effect):
                if sandbox_error or final_tree != "tree-id" or remaining_status or parent != "base-id":
                    with self.assertRaises(RuntimeError):
                        m.run_issue({"number": 7, "title": "test", "body": ""}, 60)
                else:
                    m.run_issue({"number": 7, "title": "test", "body": ""}, 60)
            return calls

    def test_failed_sandbox_never_commits_or_publishes(self):
        calls = self._run(sandbox_error=m.sandbox_tests.SandboxError("test failure"))
        self.assertFalse(any(args[:2] in (("git", "commit"), ("git", "push")) for args in calls))
        self.assertFalse(any(args[:3] == ("gh", "pr", "create") for args in calls))

    def test_commit_tree_mismatch_never_pushes(self):
        calls = self._run(final_tree="different-tree")
        self.assertTrue(any(args[:2] == ("git", "commit") for args in calls))
        self.assertFalse(any(args[:2] == ("git", "push") for args in calls))

    def test_remaining_untracked_file_never_publishes(self):
        calls = self._run(remaining_status="?? unexpected/file.txt\0")
        self.assertFalse(any(args[:2] == ("git", "add") for args in calls))
        self.assertFalse(any(args[:2] in (("git", "commit"), ("git", "push")) for args in calls))

    def test_changed_commit_parent_never_pushes(self):
        calls = self._run(parent="unexpected-parent")
        self.assertFalse(any(args[:2] == ("git", "push") for args in calls))

    def test_success_pushes_and_opens_a_draft(self):
        calls = self._run()
        self.assertTrue(any(args[:2] == ("git", "push") for args in calls))
        pr_calls = [args for args in calls if args[:3] == ("gh", "pr", "create")]
        self.assertEqual(len(pr_calls), 1)
        self.assertIn("--draft", pr_calls[0])


if __name__ == "__main__":
    unittest.main()

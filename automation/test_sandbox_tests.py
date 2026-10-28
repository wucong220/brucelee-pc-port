import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from automation import sandbox_tests as sandbox


class FakeListener:
    def __enter__(self): return self
    def __exit__(self, *_args): pass
    def bind(self, _address): pass
    def listen(self, _backlog): pass
    def getsockname(self): return ("127.0.0.1", 12345)


class TestSandboxRunner(unittest.TestCase):
    def test_environment_drops_credentials_and_python_overrides(self):
        with patch.dict(os.environ, {"GH_TOKEN": "dummy", "PYTHONPATH": "outside"}):
            env = sandbox._environment(Path("."))
        self.assertNotIn("GH_TOKEN", env)
        self.assertNotIn("PYTHONPATH", env)

    def test_snapshot_rejects_traversal(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaises(sandbox.SandboxError):
                sandbox._materialize(Path(temp), {"../outside.md": b"x"})

    def test_sandbox_failure_is_not_retried_on_host(self):
        with tempfile.TemporaryDirectory() as temp, \
             patch.object(sandbox.socket, "socket", return_value=FakeListener()), \
             patch.object(sandbox, "_sandbox_command", return_value=["mock-sandbox"]), \
             patch.object(sandbox.subprocess, "run", return_value=SimpleNamespace(returncode=1, stdout="", stderr="blocked")) as run:
            with self.assertRaises(sandbox.SandboxError):
                sandbox.run_isolated({"tests/test_one.py": b"pass"}, Path(temp))
            self.assertEqual(run.call_count, 1)

    def test_success_requires_explicit_success_marker(self):
        with tempfile.TemporaryDirectory() as temp, \
             patch.object(sandbox.socket, "socket", return_value=FakeListener()), \
             patch.object(sandbox, "_sandbox_command", return_value=["mock-sandbox"]), \
             patch.object(sandbox.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout="", stderr="")):
            with self.assertRaises(sandbox.SandboxError):
                sandbox.run_isolated({"tests/test_one.py": b"pass"}, Path(temp))

    @unittest.skipUnless(os.name == "nt", "Windows MXC command")
    def test_windows_command_requires_mxc_and_denies_network(self):
        with patch.object(sandbox.shutil, "which", return_value="codex.exe"):
            args = sandbox._sandbox_command(Path("."), Path("canary"), 12345, "marker")
        self.assertIn('windows.sandbox="mxc"', args)
        self.assertTrue(any(x.endswith(".network.enabled=false") for x in args))
        self.assertIn("-I", args)


if __name__ == "__main__":
    unittest.main()

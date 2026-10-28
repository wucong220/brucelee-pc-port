"""Test an index snapshot inside a checked, offline Codex sandbox.

The command fails closed if the required sandbox or its boundary probes fail.
The snapshot is disposable; test code never runs directly in the user's checkout.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import uuid


class SandboxError(RuntimeError):
    pass


_BOOTSTRAP = r'''
import os, pathlib, socket, sys, tempfile, unittest

canary, port, marker = sys.argv[1:4]
try:
    pathlib.Path(canary).read_bytes()
except OSError:
    pass
else:
    raise SystemExit("Isolation failed: outside file is readable")

try:
    connection = socket.create_connection(("127.0.0.1", int(port)), timeout=2)
except OSError:
    pass
else:
    connection.close()
    raise SystemExit("Isolation failed: outside network is reachable")

private_temp = pathlib.Path.cwd() / ".t"
os.environ["TEMP"] = os.environ["TMP"] = str(private_temp)
tempfile.tempdir = str(private_temp)
sys.path.insert(0, str(pathlib.Path.cwd()))
suite = unittest.TestSuite()
for start in ("tests", "automation"):
    discovered = unittest.TestLoader().discover(start, pattern="test*.py")
    if discovered.countTestCases() == 0:
        raise SystemExit("No tests discovered in " + start)
    suite.addTests(discovered)
result = unittest.TextTestRunner(verbosity=2).run(suite)
if not result.wasSuccessful():
    raise SystemExit(1)
print(marker, flush=True)
'''


def _environment(temp: Path) -> dict[str, str]:
    # In particular, do not inherit GitHub/OpenAI tokens or arbitrary PYTHON* env.
    keep = {
        "SYSTEMROOT", "SYSTEMDRIVE", "WINDIR", "COMSPEC", "PATHEXT", "USERPROFILE",
        "LOCALAPPDATA", "APPDATA", "PROGRAMDATA", "PROGRAMFILES",
        "PROCESSOR_ARCHITECTURE", "NUMBER_OF_PROCESSORS", "PATH",
    }
    env = {key: value for key, value in os.environ.items() if key.upper() in keep}
    # The sandbox resolves :tmpdir before starting Python. Pointing TEMP here
    # at the workspace would make the explicit :tmpdir deny shadow workspace
    # writes. The bootstrap sets tempfile.tempdir after the sandbox starts.
    return env


def _materialize(snapshot: Path, files: dict[str, bytes]) -> None:
    root = snapshot.resolve()
    for relative, data in files.items():
        target = (root / Path(relative)).resolve()
        if not target.is_relative_to(root) or target == root:
            raise SandboxError("快照路径不在测试目录中")
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as output:
            output.write(data)


def _sandbox_command(snapshot: Path, canary: Path, port: int, marker: str) -> list[str]:
    codex = shutil.which("codex")
    if not codex:
        raise SandboxError("未找到 Codex CLI；不能在无隔离条件下运行测试")
    profile = "dispatch_" + uuid.uuid4().hex
    python_root = str(Path(sys.executable).resolve().parent)
    # One inline table avoids ambiguous dotted-key parsing of ':root' and Windows paths.
    filesystem = (
        '{":root"="deny",":minimal"="read",":tmpdir"="deny",'
        '":slash_tmp"="deny",' + json.dumps(python_root, ensure_ascii=False) + '="read"}'
    )
    settings = [
        f'permissions.{profile}.extends=":workspace"',
        f'permissions.{profile}.filesystem={filesystem}',
        f'permissions.{profile}.network.enabled=false',
    ]
    args = [codex]
    if os.name == "nt":
        # MXC supports deny-read rules; never fall back to the weaker legacy sandbox.
        settings.insert(0, 'windows.sandbox="mxc"')
    for setting in settings:
        args.extend(["-c", setting])
    if os.name != "nt":
        # This project targets Windows; no unverified fallback to host execution.
        raise SandboxError("当前仅支持经过验证的 Windows MXC 测试隔离")
    args += ["sandbox", "--include-managed-config", "-P", profile, "-C", str(snapshot),
             "--", sys.executable, "-X", "utf8", "-I", "-B", "-c", _BOOTSTRAP,
             str(canary), str(port), marker]
    return args


def run_isolated(files: dict[str, bytes], log_dir: Path, timeout: int = 180) -> str:
    """Return sandbox output only after all checks and both test suites pass."""
    base = log_dir.resolve()
    base.mkdir(parents=True, exist_ok=True)
    # Keep paths short: packaged Windows LOCALAPPDATA paths can be lengthy.
    sandbox_base = (base / "t").resolve()
    if not sandbox_base.is_relative_to(base) or sandbox_base == base:
        raise SandboxError("临时目录不在预期的本机日志目录中")
    sandbox_base.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="d-", dir=sandbox_base) as temp_name:
        temporary = Path(temp_name).resolve()
        if temporary.parent != sandbox_base:
            raise SandboxError("测试临时目录位置异常")
        snapshot = temporary / "w"
        snapshot.mkdir()
        _materialize(snapshot, files)
        private_temp = snapshot / ".t"
        private_temp.mkdir()
        canary = temporary / "outside-canary"
        canary.write_bytes(b"dispatch isolation canary")
        marker = "DISPATCH_TESTS_OK_" + uuid.uuid4().hex
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
            listener.bind(("127.0.0.1", 0))
            listener.listen(1)
            args = _sandbox_command(snapshot, canary, listener.getsockname()[1], marker)
            try:
                result = subprocess.run(args, cwd=snapshot, env=_environment(private_temp),
                                        capture_output=True, text=True, encoding="utf-8",
                                        errors="replace", timeout=timeout, check=False)
            except (OSError, subprocess.TimeoutExpired) as exc:
                raise SandboxError("隔离测试未能启动或超时；没有使用无沙箱回退") from exc
        output = result.stdout + result.stderr
        diagnostic = base / ("isolated-tests-" + uuid.uuid4().hex + ".log")
        with diagnostic.open("x", encoding="utf-8") as log:
            log.write(output)
        if result.returncode != 0 or marker not in result.stdout.splitlines():
            raise SandboxError(f"隔离检查或测试失败 (exit={result.returncode})；日志：{diagnostic}")
        return output

"""Validate the Git index before publishing a dispatcher task branch.

This is a conservative content check, not a proof that material is licensed or
free of secrets. The caller must test and commit exactly the validated tree.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path, PurePosixPath
import re
import subprocess

ALLOWED = (
    ".gitignore", "AGENTS.md", "README.md", "README_zh.md", "build_windows.ps1",
    "docs/", "tools/", "tests/", "automation/", "reports/",
    "godot/project.godot", "godot/export_presets.cfg", "godot/scenes/", "godot/scripts/",
    "evidence/candidate_symbols.csv", "evidence/pak_frames.csv", "evidence/source_inventory.json",
)
TEXT_EXT = {".md", ".py", ".gd", ".tscn", ".godot", ".cfg", ".ps1", ".csv", ".json", ".txt", ".yml", ".yaml", ".toml"}
MAX_FILE_BYTES = 3_000_000
MAX_TREE_BYTES = 50_000_000
_OID = re.compile(r"[0-9a-f]{40,64}\Z")
_SECRETS = (
    ("private key", re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----\s+[A-Za-z0-9+/]{32,}")),
    ("GitHub credential", re.compile(rb"\bgh[pousr]_[A-Za-z0-9]{30,}\b")),
    ("GitHub credential", re.compile(rb"\bgithub_pat_[A-Za-z0-9_]{50,}\b")),
    ("AWS access key", re.compile(rb"\bAKIA[A-Z0-9]{16}\b")),
    ("API credential", re.compile(rb"\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b")),
    ("credential assignment", re.compile(
        rb'''(?im)\b(?:password|passwd|secret|api[_-]?key|access[_-]?token)\b["']?\s*[:=]\s*(?:"[^"\r\n]{12,}"|'[^'\r\n]{12,}'|[A-Za-z0-9_./+@=-]{16,})''')),
)
_MAGIC = (b"\x7fELF", b"MZ", b"PK\x03\x04", b"%PDF-", b"\x89PNG\r\n\x1a\n", b"RIFF", b"\x1f\x8b")


class ValidationError(RuntimeError):
    """A path, index entry, or indexed blob is not safe to publish."""


@dataclass(frozen=True)
class Entry:
    path: str
    mode: str
    oid: str


def allowed_path(path: str) -> bool:
    if not path or "\\" in path or ":" in path or any(ord(char) < 32 or ord(char) == 127 for char in path):
        return False
    p = PurePosixPath(path)
    if p.is_absolute() or any(part in ("", ".", "..") for part in path.split("/")):
        return False
    if not any(path == item or (item.endswith("/") and path.startswith(item)) for item in ALLOWED):
        return False
    return path == ".gitignore" or p.suffix.lower() in TEXT_EXT


def check_blob(path: str, data: bytes) -> None:
    if len(data) > MAX_FILE_BYTES:
        raise ValidationError(f"文件过大：{path}")
    if data.startswith(_MAGIC) or any(b < 32 and b not in (9, 10, 13) for b in data):
        raise ValidationError(f"文件不是允许的文本内容：{path}")
    try:
        data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValidationError(f"文件不是 UTF-8 文本：{path}") from exc
    for description, pattern in _SECRETS:
        if pattern.search(data):
            # Never include matched material in errors, logs, or the PR.
            raise ValidationError(f"文件中发现疑似 {description}：{path}")


def _git(root: Path, *args: str) -> bytes:
    proc = subprocess.run(["git", *args], cwd=root, capture_output=True, timeout=120, check=False)
    if proc.returncode:
        raise ValidationError(f"Git 检查失败：{args[0]} (exit={proc.returncode})")
    return proc.stdout


def index_tree(root: Path) -> str:
    result = _git(root, "write-tree").decode("ascii").strip()
    if not _OID.fullmatch(result):
        raise ValidationError("Git 返回了无效的索引树标识")
    return result


def read_index(root: Path) -> dict[str, bytes]:
    """Read immutable index blobs, not the possibly different working files."""
    raw = _git(root, "ls-files", "--stage", "-z")
    entries: list[Entry] = []
    for record in raw.split(b"\0"):
        if not record:
            continue
        try:
            meta, raw_path = record.split(b"\t", 1)
            mode, oid, stage = meta.decode("ascii").split(" ")
            path = raw_path.decode("utf-8")
        except (ValueError, UnicodeError) as exc:
            raise ValidationError("无法安全读取 Git 索引") from exc
        if stage != "0" or mode not in ("100644", "100755") or not _OID.fullmatch(oid):
            raise ValidationError(f"索引包含冲突、符号链接或非普通文件：{path}")
        if not allowed_path(path):
            raise ValidationError(f"文件不在允许清单内：{path}")
        entries.append(Entry(path, mode, oid))

    # Windows cannot safely materialize two case-insensitively identical paths.
    folded = [entry.path.casefold() for entry in entries]
    if len(folded) != len(set(folded)):
        raise ValidationError("索引中有大小写冲突的路径")
    total = 0
    result: dict[str, bytes] = {}
    for entry in entries:
        try:
            size = int(_git(root, "cat-file", "-s", entry.oid).decode("ascii").strip())
        except (ValueError, UnicodeError) as exc:
            raise ValidationError(f"无法核验文件大小：{entry.path}") from exc
        if size < 0 or size > MAX_FILE_BYTES:
            raise ValidationError(f"文件过大：{entry.path}")
        total += size
        if total > MAX_TREE_BYTES:
            raise ValidationError("索引内容超过安全检查的总大小限制")
        data = _git(root, "cat-file", "blob", entry.oid)
        if len(data) != size:
            raise ValidationError(f"Git 对象大小不一致：{entry.path}")
        check_blob(entry.path, data)
        result[entry.path] = data
    return result


def validated_index(root: Path) -> tuple[str, dict[str, bytes]]:
    tree = index_tree(root)
    files = read_index(root)
    if not files or index_tree(root) != tree:
        raise ValidationError("检查期间 Git 索引发生变化或为空")
    return tree, files

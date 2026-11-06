#!/usr/bin/env python3
"""Run the windowed character-unlock captures and write their PNGs + reports.

The DSH sandbox denies file writes to the Godot process, so
`godot/tests/capture_character_locks.gd` streams every screenshot and report over
a framed localhost TCP connection; this runner owns the receiver and writes the
files.

Frame: u32 little-endian length, then a UTF-8 JSON header line, then the body
(PNG bytes for a screenshot, JSON text for a report).

Seven independent runs, each with its own environment.  `dock_*` runs set
`BRUCELEE_HUD_ART=1` so main.gd shows the decoded selectfighter.ui dock; `text_*`
runs leave it unset so the text OPPONENTS rows stay visible.  `dock_off` sets
`BRUCELEE_CHARACTER_UNLOCK=0` (the pre-gating dock); every other run leaves the
gate on and points it at a save fixture from
`tools/make_character_lock_fixtures.py`:

  dock_off      gate off, dock                     01
  dock_none     gate on, no save                   02..03
  dock_partial  gate on, save with ids 7+13        04..05
  dock_full     gate on, every grant               06
  dock_missing  gate on, unmappable dock           07
  text_none     gate on, text rows, no save        08..09
  text_full     gate on, text rows, every grant    10

Usage:
    python -X utf8 tools\\run_character_lock_capture.py --out screenshots
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "godot"
CAPTURE_SCRIPT = "res://tests/capture_character_locks.gd"
GODOT_DEFAULT = (
    r"C:\Users\Lenovo\AppData\Local\BruceLee-PC-Port\godot-portable-773280yg"
    r"\Godot_v4.7.2-stable_win64_console.exe"
)
FIXTURES = ROOT / "evidence" / "fixtures"

RUNS = [
    {
        # Ungated regression: the dock every card open, exactly as before the gate.
        "mode": "dock_off",
        "hud_art": "1",
        "character_unlock": "0",
        "save": "save_does_not_exist.json",
        "expected": ["01_dock_gate_off_brick.png"],
    },
    {
        # No save: the thirteen gated cards draw the decoded lockedpicture.
        "mode": "dock_none",
        "hud_art": "1",
        "character_unlock": "",
        "save": "save_does_not_exist.json",
        "expected": [
            "02_dock_nosave_brick_locked.png",
            "03_dock_nosave_shenlo_open.png",
        ],
    },
    {
        # sin fu (id 7) and lo ming a (id 13) granted: mixed open/locked cards.
        "mode": "dock_partial",
        "hud_art": "1",
        "character_unlock": "",
        "save": "save_partial.json",
        "expected": [
            "04_dock_partial_sinfu_open.png",
            "05_dock_partial_master_locked.png",
        ],
    },
    {
        # Every grant: all cards draw their character icons.
        "mode": "dock_full",
        "hud_art": "1",
        "character_unlock": "",
        "save": "save_full.json",
        "expected": ["06_dock_full_brick_open.png"],
    },
    {
        # The decoded dock cannot be mapped: main.gd restores the text rows, which
        # keep the same lock state (full save -> no suffix, message shown).
        "mode": "dock_missing",
        "hud_art": "1",
        "character_unlock": "",
        "save": "save_full.json",
        "dock": "dock_does_not_exist.json",
        "expected": ["07_dock_fallback_missing_layout.png"],
    },
    {
        # Text OPPONENTS rows with no save: eight (LOCKED) rows, confirm blocked.
        "mode": "text_none",
        "hud_art": "",
        "character_unlock": "",
        "save": "save_does_not_exist.json",
        "expected": [
            "08_text_nosave_locked_rows.png",
            "09_text_nosave_confirm_blocked.png",
        ],
    },
    {
        # Text OPPONENTS rows with every grant: no suffix.
        "mode": "text_full",
        "hud_art": "",
        "character_unlock": "",
        "save": "save_full.json",
        "expected": ["10_text_full_rows.png"],
    },
]


class Receiver:
    def __init__(self, out_dir: Path) -> None:
        self.out_dir = out_dir
        self.files: list[dict] = []
        self.error = ""
        self.server: socket.socket | None = None
        self.port = 0

    def start(self) -> None:
        self.server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server.bind(("127.0.0.1", 0))
        self.port = self.server.getsockname()[1]
        self.server.listen(1)
        self.server.settimeout(300.0)
        threading.Thread(target=self._serve, daemon=True).start()

    def _serve(self) -> None:
        try:
            conn, _address = self.server.accept()
            conn.settimeout(300.0)
            buffer = b""
            while True:
                chunk = conn.recv(65536)
                if not chunk:
                    break
                buffer += chunk
                while len(buffer) >= 4:
                    length = int.from_bytes(buffer[:4], "little")
                    if len(buffer) < 4 + length:
                        break
                    payload = buffer[4:4 + length]
                    buffer = buffer[4 + length:]
                    head, _, body = payload.partition(b"\n")
                    header = json.loads(head.decode("utf-8"))
                    if header["type"] == "screenshot":
                        target = self.out_dir / header["name"]
                    elif header["type"] == "report":
                        target = self.out_dir / f"{header['name']}.json"
                    else:
                        raise ValueError(f"unknown frame type {header['type']}")
                    target.write_bytes(body)
                    self.files.append({"type": header["type"],
                                       "name": header["name"],
                                       "bytes": len(body)})
            conn.close()
        except Exception as error:  # noqa: BLE001 - reported by the caller
            self.error = f"{type(error).__name__}: {error}"


def run_one(run: dict, godot: str, out_dir: Path, timeout: float) -> dict:
    receiver = Receiver(out_dir)
    receiver.start()
    env = dict(os.environ)
    for name in (
        "BRUCELEE_STORY_FLOW", "BRUCELEE_STORY_LAUNCH", "BRUCELEE_GAME_MODE",
        "BRUCELEE_MODE_LAUNCH", "BRUCELEE_ATTRACT", "BRUCELEE_CONTINUE",
        "BRUCELEE_PROGRESS", "BRUCELEE_STYLE_EDITOR", "BRUCELEE_SCENE",
        "BRUCELEE_MENU_ART", "BRUCELEE_SCENE_SELECT", "BRUCELEE_SCENE_UNLOCK",
        "BRUCELEE_SCENE_UNLOCK_SAVE", "BRUCELEE_SCENE_UNLOCK_UNLOCKS",
        "BRUCELEE_SCENE_UNLOCK_STORY", "BRUCELEE_ROUND_INTRO",
        "BRUCELEE_CHARACTER_UNLOCK", "BRUCELEE_CHARACTER_UNLOCK_SAVE",
        "BRUCELEE_CHARACTER_UNLOCK_UNLOCKS", "BRUCELEE_CHARACTER_UNLOCK_STORY",
        "BRUCELEE_CHARACTER_UNLOCK_MENU_ART", "BRUCELEE_CHARACTER_UNLOCK_DOCK",
        "BRUCELEE_HUD_ART",
    ):
        env.pop(name, None)
    env.update({
        "BRUCELEE_MAIN_MENU": "1",
        "BRUCELEE_LANG": "en",
        "BRUCELEE_HUD_ART": run["hud_art"],
        "BRUCELEE_CHARACTER_UNLOCK": run["character_unlock"],
        "BRUCELEE_CHARACTER_UNLOCK_SAVE": str(FIXTURES / run["save"]),
        "CHARACTER_LOCK_CAPTURE": run["mode"],
        "CHARACTER_LOCK_CAPTURE_PORT": str(receiver.port),
    })
    if "dock" in run:
        env["BRUCELEE_CHARACTER_UNLOCK_DOCK"] = str(FIXTURES / run["dock"])
    command = [godot, "--path", str(PROJECT), "--script", CAPTURE_SCRIPT,
               "--quit-after", "9000"]
    started = time.time()
    completed = subprocess.run(command, env=env, cwd=str(PROJECT),
                               capture_output=True, text=True, timeout=timeout)
    elapsed = time.time() - started
    report = {"mode": run["mode"], "exit_code": completed.returncode,
              "seconds": round(elapsed, 1), "files": receiver.files,
              "receiver_error": receiver.error,
              "expected": run["expected"],
              "stdout_tail": completed.stdout[-4000:],
              "stderr_tail": completed.stderr[-4000:]}
    missing = [name for name in run["expected"]
               if not any(entry["name"] == name for entry in receiver.files)]
    report["missing"] = missing
    report["ok"] = completed.returncode == 0 and not missing
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / "screenshots")
    parser.add_argument("--godot", default=GODOT_DEFAULT)
    parser.add_argument("--timeout", type=float, default=420.0)
    parser.add_argument("--only", default="")
    args = parser.parse_args()

    if not Path(args.godot).exists():
        print(f"error: Godot not found at {args.godot}", file=sys.stderr)
        return 2
    if not (PROJECT / "tests" / "capture_character_locks.gd").exists():
        print("error: capture_character_locks.gd missing", file=sys.stderr)
        return 2
    args.out.mkdir(parents=True, exist_ok=True)

    reports = []
    ok = True
    for run in RUNS:
        if args.only and run["mode"] != args.only:
            continue
        print(f"=== capture mode {run['mode']} ===", flush=True)
        report = run_one(run, str(args.godot), args.out, args.timeout)
        reports.append(report)
        print(json.dumps({k: report[k] for k in
                          ("mode", "exit_code", "seconds", "ok", "missing")},
                         indent=1), flush=True)
        if not report["ok"]:
            ok = False
            print(report["stdout_tail"][-1500:], file=sys.stderr)
            print(report["stderr_tail"][-1500:], file=sys.stderr)
    (args.out / "character_lock_capture_runs.json").write_text(
        json.dumps(reports, indent=1), encoding="utf-8")
    print("RESULT=" + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())

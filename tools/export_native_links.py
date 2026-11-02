#!/usr/bin/env python3
"""Export fighting-set link metadata for the PC port runtime.

Derived metadata only: action names, group windows, link key sequences,
key status, time windows and flags. No original payload is written.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from kdf_fighting_set import read_archive_resource
import kdf_combat_reactions as reactions


def build(archive: Path) -> dict:
    raw, info = read_archive_resource(archive, "adreno_200/set/brucelee.set")
    _reader, _root, actions, links = reactions._parse_set(raw)
    action_rows = []
    for action in actions:
        groups = {}
        for entry in action.get("groups") or []:
            if not isinstance(entry, list) or len(entry) < 3:
                continue
            groups[str(entry[0])] = [int(entry[1][0]), int(entry[1][1]), int(entry[2])]
        binary = action.get("binary") or {}
        attack = action.get("attack") or {}
        counter_time = attack.get("counter_time")
        if (not isinstance(counter_time, list) or len(counter_time) != 2
                or any(type(item) is not int for item in counter_time)):
            counter_time = None
        grab_distance = attack.get("grab_distance")
        if not isinstance(grab_distance, (int, float)):
            grab_distance = None
        facing_window = action.get("facing")
        if (not isinstance(facing_window, list) or len(facing_window) != 2
                or any(type(item) is not int for item in facing_window)):
            facing_window = None
        action_rows.append({
            "name": str(action.get("name", "")),
            "pose": action.get("pose"),
            "animation": binary.get("basename"),
            "ordinal": binary.get("ordinal"),
            "counter_time": counter_time,
            "grab_distance": grab_distance,
            "facing": facing_window,
            "groups": groups,
        })
    link_rows = []
    for index, link in enumerate(links):
        link_rows.append({
            "order": index,
            "from": link.get("from"),
            "from_group": link.get("from_group"),
            "to": link.get("to"),
            "keysequence": link.get("keysequence") or [],
            "keystatus": link.get("keystatus") or [],
            "time": link.get("time"),
            "entry_frame": link.get("entry_frame"),
            "linking_frame": link.get("linking_frame"),
            "blending": link.get("blending"),
            "conditions": link.get("conditions") or [],
            "input_reset": link.get("input_reset"),
            "unique": link.get("unique") or [],
        })
    return {
        "schema_version": 1,
        "source": {
            "set_path": "adreno_200/set/brucelee.set",
            "action_count": len(actions),
            "link_count": len(links),
            "set_sha256": info.get("sha256") if isinstance(info, dict) else None,
        },
        "actions": action_rows,
        "links": link_rows,
        "note": (
            "Derived metadata only. Link order is the native link scan order. "
            "keysequence and keystatus entries are alternative sequences selected "
            "by CLinkDescr::GetKeySequence(index = fighter+0x1c), not three steps; "
            "the selector value is not yet recovered."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    report = build(args.archive)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, separators=(",", ":")),
                           encoding="utf-8")
    print(f"actions={len(report['actions'])} links={len(report['links'])} "
          f"bytes={args.output.stat().st_size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

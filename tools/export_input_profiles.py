#!/usr/bin/env python3
"""Export control-profile metadata from adreno_200/input.config.

Derived metadata only: profile names, virtual-key names and Android key codes.
No original payload is written.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

from kdf_data import parse_context, parse_container
from kdf_fighting_set import RecordReader, read_archive_resource


def _decode(reader: RecordReader, index: int):
    record = reader.record(index)
    tag = record["first"] & 0xFFFF0000
    if tag == 0x30000000:
        return {key: _decode(reader, value) for key, value in reader.dictionary(index).items()}
    if tag == 0x40000000:
        return [_decode(reader, value) for value in reader.array(index)]
    if tag == 0x60000000:
        return reader.string(index)
    if tag == 0x70000000:
        return reader.file(index)
    if record["first"] == 0:
        return reader.scalar(index)
    if tag == 0x20000000:
        return struct.unpack("<f", struct.pack("<I", record["second"]))[0]
    raise ValueError(f"unsupported record {index}: {record}")


def _bindings(profile: list) -> list[dict]:
    rows = []
    for item in profile:
        if not isinstance(item, dict) or "vkey" not in item:
            continue
        row = {"vkey": item["vkey"]}
        if "keyboard" in item:
            row["keyboard"] = item["keyboard"]
        if "fighter" in item:
            row["fighter"] = item["fighter"]
        if "mirrorkey" in item:
            row["mirrorkey"] = item["mirrorkey"]
        if "mouse" in item:
            row["mouse"] = {
                key: item["mouse"][key]
                for key in ("x", "y", "width", "height")
                if key in item["mouse"]
            }
        rows.append(row)
    return rows


def build(zpak: Path) -> dict:
    raw, _info = read_archive_resource(zpak, "adreno_200/input.config")
    context = parse_context(raw)
    container = parse_container(raw, data_offset=context["data_offset"])
    reader = RecordReader(container, context)
    root = reader.dictionary(0)
    decoded = {key: _decode(reader, value) for key, value in root.items()}
    layouts = []
    for name, layout in decoded.items():
        if not isinstance(layout, dict) or "configs" not in layout:
            continue
        profiles = []
        for profile in layout["configs"]:
            control = None
            bindings = []
            for item in profile:
                if isinstance(item, dict) and "control_profile" in item:
                    control = item["control_profile"]
                elif isinstance(item, dict) and "vkey" in item:
                    bindings.extend(_bindings([item]))
            profiles.append({"control_profile": control, "bindings": bindings})
        layouts.append({
            "name": name,
            "width": layout.get("width"),
            "height": layout.get("height"),
            "profiles": profiles,
        })
    return {
        "schema_version": 1,
        "source": {
            "resource": "adreno_200/input.config",
            "sha256": hashlib.sha256(raw).hexdigest(),
        },
        "layouts": layouts,
        "note": (
            "Derived metadata only. control_profile is the index passed to "
            "CLinkDescr::GetKeySequence; the default layout has a/b only, the zdk "
            "keyboard layout adds c/d."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    report = build(args.archive)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"layouts={len(report['layouts'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Derive the grab-finisher evidence report from a decoded fighting set.

The report lists every endattack* link with its original links index, target
action record, animation, radius and conditions, plus the only recovered stun
entries. It is derived metadata only; no original payload is written.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import sys

from kdf_data import KdfError, parse_container, parse_context
from kdf_fighting_set import RecordReader, read_archive_resource
import kdf_combat_reactions as reactions

_DEFAULT_SET_PATH = "adreno_200/set/brucelee.set"
_GROUP = "candobasicattacks"
_STUN_TARGETS = ("impactstunhigh", "impactstunlow")


def action_metadata(raw: bytes) -> dict:
    context = parse_context(raw)
    container = parse_container(raw, data_offset=context["data_offset"])
    reader = RecordReader(container, context)
    root = reader.dictionary(0)
    metadata = {}
    for record in reader.array(root["animations"]):
        item = reader.dictionary(record)
        name = reader.string(item["name"])
        binary = reader.file(item["binary"]) if "binary" in item else {}
        radius = (
            reader.decoded_value(item["radius"]).get("value")
            if "radius" in item else None
        )
        metadata[name] = {
            "record": record,
            "animation": (
                f"{binary.get('basename')}.{binary.get('extension')}"
                if binary else None
            ),
            "animation_ordinal": binary.get("ordinal") if binary else None,
            "radius": radius,
        }
    return metadata


def build_report(metadata: dict, links: list[dict]) -> dict:
    group_links = []
    stun_entries = []
    for index, link in enumerate(links):
        target = link.get("to")
        if isinstance(target, str) and target.startswith("endattack"):
            meta = metadata.get(target, {})
            group_links.append({
                "source_index": index,
                "to": target,
                "target_record": meta.get("record"),
                "target_animation": meta.get("animation"),
                "target_animation_ordinal": meta.get("animation_ordinal"),
                "target_radius": meta.get("radius"),
                "keysequence": link.get("keysequence"),
                "conditions": link.get("conditions", []),
                "entry_frame": link.get("entry_frame"),
                "blending": link.get("blending"),
            })
        if target in _STUN_TARGETS:
            meta = metadata.get(target, {})
            stun_link = next(
                ({"source_index": other_index, **_entry}
                 for other_index, _entry in enumerate(links)
                 if _entry.get("from") == target and _entry.get("to") == "stun"),
                None,
            )
            stun_entries.append({
                "source_index": index,
                "to": target,
                "target_record": meta.get("record"),
                "target_animation": meta.get("animation"),
                "conditions": link.get("conditions", []),
                "stun_link": stun_link,
            })
    group_links.sort(key=lambda item: item["to"])
    return {
        "schema_version": 1,
        "group": _GROUP,
        "link_count": len(group_links),
        "links": group_links,
        "stun_entry_count": len(stun_entries),
        "stun_entry_evidence": stun_entries,
        "blockers": [
            "All endattack links require oppposestun; the prototype has no stun state.",
            "Most links also require grabdistance; distance-to-grab semantics are not recovered.",
            "Target animations m0x_end_attack_0x are not in any current candidate GLB.",
            "The only recovered stun entries are gated by healthzero (a lethal hit), so wiring grab finishers to them would misrepresent normal stun.",
        ],
        "note": "Derived metadata only; source_index is the original links array position.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=pathlib.Path, required=True)
    parser.add_argument("--set-path", default=_DEFAULT_SET_PATH)
    parser.add_argument("--out", type=pathlib.Path, required=True)
    args = parser.parse_args()
    try:
        if args.out.exists():
            raise KdfError(f"report already exists: {args.out}")
        raw, _archive = read_archive_resource(args.archive, args.set_path)
        reader, _root, _actions, links = reactions._parse_set(raw)
        report = build_report(action_metadata(raw), links)
        report["source"] = {
            "set_path": args.set_path,
            "set_sha256": hashlib.sha256(raw).hexdigest(),
        }
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
            newline="\n",
        )
    except (OSError, KdfError, KeyError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(f"endattack links {report['link_count']}, stun entries {report['stun_entry_count']} -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

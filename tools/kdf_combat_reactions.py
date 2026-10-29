#!/usr/bin/env python3
"""Export safe combat reaction metadata from the original fighting sets."""
from __future__ import annotations

import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_data import KdfError, parse_container, scalar_property
from kdf_fighting_set import RecordReader, parse_context, read_archive_resource


_SETS = (
    "adreno_200/set/Default.set",
    "adreno_200/set/brucelee.set",
)
_ACTION_NAMES = {
    "idle",
    "highblock",
    "midblock",
    "lowblock",
    "stun",
    "stun2",
    "stunfall",
    "impactlightfrontlow",
    "impactlightfrontmid",
    "impactlightfronthigh",
    "impacthardfrontlow",
    "impacthardfrontmid",
    "impacthardfronthigh",
    "impactbrutalmid",
    "stunlighthighimpact",
    "stunlightlowimpact",
    "stunmediumimpact",
    "stunhardimpact",
    "stunbrutalimpact",
}
_IMPACT_HEIGHTS = (("low", "low"), ("medium", "med"), ("high", "high"))
_BLOCK_GROUPS = ("canblock", "canblock2")


class ReactionInventoryError(KdfError):
    pass


def _is_number(value: object) -> bool:
    return type(value) in (int, float)


def _decoded(reader: RecordReader, ordinal: int, depth: int = 0) -> object:
    if depth > 16:
        raise ReactionInventoryError("fighting-set value nesting is too deep")
    record = reader.record(ordinal)
    tag = record["first"] & 0xF0000000
    if tag == 0x30000000:
        return {
            key: _decoded(reader, value, depth + 1)
            for key, value in reader.dictionary(ordinal).items()
        }
    if tag == 0x40000000:
        return [
            _decoded(reader, value, depth + 1)
            for value in reader.array(ordinal)
        ]
    decoded = reader.decoded_value(ordinal)
    return decoded.get("value", decoded)


def _parse_set(raw: bytes) -> tuple[RecordReader, dict, list[dict], list[dict]]:
    context = parse_context(raw)
    container = parse_container(raw, data_offset=context["data_offset"])
    reader = RecordReader(container, context)
    root = reader.dictionary(0)
    if "animations" not in root or "links" not in root:
        raise ReactionInventoryError("fighting set lacks animations or links")
    actions = [
        _decoded(reader, action)
        for action in reader.array(root["animations"])
    ]
    links = [
        _decoded(reader, link)
        for link in reader.array(root["links"])
    ]
    return reader, root, actions, links


def _full_resource_path(file_value: dict) -> str:
    return (
        "adreno_200/"
        + file_value["directory"]
        + file_value["basename"]
        + "."
        + file_value["extension"]
    )


def _animation_metadata(raw: bytes) -> dict:
    try:
        container = parse_container(raw)
        values = {
            key: scalar_property(container, key)
            for key in ("version", "pose", "firstframe", "framerate", "duration")
        }
    except (KdfError, KeyError, ValueError) as exc:
        raise ReactionInventoryError(f"animation header could not be read: {exc}") from exc
    framerate = values["framerate"]
    if not _is_number(framerate) or framerate <= 0:
        raise ReactionInventoryError("animation framerate is missing or invalid")
    duration = values["duration"]
    if not _is_number(duration) or duration < 0:
        raise ReactionInventoryError("animation duration is missing or invalid")
    values["duration_seconds"] = duration / framerate
    return values


def _condition_matches(link: dict, *, strength: str, height: str,
                       direction: str | None = None) -> bool:
    conditions = link.get("conditions")
    if not isinstance(conditions, list):
        return False
    height_token = "med" if height == "medium" else height
    required = {
        "impact",
        f"oppattackstrength{strength}",
        f"oppattackheight{height_token}",
    }
    if direction is not None:
        required.add(f"oppattackdir{direction}")
    return required.issubset(set(conditions))


def _select_links(links: list[dict], *, group: str, strength: str,
                  height: str, direction: str | None = None) -> list[dict]:
    return [
        link for link in links
        if link.get("from_group") == group
        and _condition_matches(
            link,
            strength=strength,
            height=height,
            direction=direction,
        )
    ]


def _return_links(links: list[dict], actions: set[str]) -> dict[str, list[dict]]:
    result = defaultdict(list)
    for link in links:
        source = link.get("from")
        if source in actions and link.get("to") == "idle":
            result[source].append(link)
    rendered = {}
    for action in sorted(result):
        entries = []
        for item in sorted(
                result[action],
                key=lambda value: (
                    value.get("time", [0, 0])[0],
                    json.dumps(value, sort_keys=True),
                )):
            start, end = item.get("time", [0, 0])
            entries.append({
                **item,
                "transition_start_frame": start,
                "transition_end_frame": end,
            })
        rendered[action] = entries
    return rendered


def inspect_archive(path: Path) -> dict:
    resources = {}
    action_inventory = []
    all_links = []
    source_sets = []
    for set_path in _SETS:
        raw, archive = read_archive_resource(path, set_path)
        reader, _, actions, links = _parse_set(raw)
        source_sets.append({
            "path": set_path,
            "sha256": hashlib.sha256(raw).hexdigest(),
            "resource_id": archive["resource_id"],
            "pakd_offset": archive["pakd_offset"],
            "outer_source_sha256": archive["source_sha256"],
            "data_zpak_sha256": archive["data_zpak_sha256"],
        })
        all_links.extend(links)
        for action in actions:
            name = action.get("name")
            if name not in _ACTION_NAMES:
                continue
            if "binary" not in action or "radius" not in action:
                raise ReactionInventoryError(
                    f"{set_path}:{name} lacks binary or radius"
                )
            animation_path = _full_resource_path(action["binary"])
            if animation_path not in resources:
                animation_raw, animation_archive = read_archive_resource(
                    path, animation_path)
                resources[animation_path] = {
                    "sha256": hashlib.sha256(animation_raw).hexdigest(),
                    "resource_id": animation_archive["resource_id"],
                    "pakd_offset": animation_archive["pakd_offset"],
                    **_animation_metadata(animation_raw),
                }
            action_inventory.append({
                "source_set": set_path,
                "name": name,
                "animation": animation_path,
                "radius": action["radius"],
                "groups": action.get("groups"),
                "categories": action.get("categories"),
                "animation_metadata": resources[animation_path],
            })
    if not action_inventory:
        raise ReactionInventoryError("no reaction actions were found")

    hit_mappings = {}
    for strength in ("normal", "hard", "brutal"):
        hit_mappings[strength] = {
            height: _select_links(
                all_links,
                group="impactable",
                strength=strength,
                height=height,
                direction="frontal",
            )
            for height, _ in _IMPACT_HEIGHTS
        }
    block_mappings = {}
    for group in _BLOCK_GROUPS:
        block_mappings[group] = {
            height: _select_links(
                all_links,
                group=group,
                strength="normal",
                height=height,
            )
            for height, _ in _IMPACT_HEIGHTS
        }
    stun_links = [
        link for link in all_links
        if link.get("from_group") == "impactsfromstun"
    ]
    target_actions = {
        link["to"]
        for group in block_mappings.values()
        for links in group.values()
        for link in links
    }
    target_actions.update(
        link["to"]
        for strength_mappings in hit_mappings.values()
        for links in strength_mappings.values()
        for link in links
    )
    target_actions.update(link["to"] for link in stun_links)
    returns = _return_links(all_links, target_actions)
    metadata_by_name = {
        action["name"]: action["animation_metadata"]
        for action in action_inventory
    }
    for source, source_links in returns.items():
        metadata = metadata_by_name.get(source)
        if metadata is None:
            continue
        for link in source_links:
            link["animation_duration_frames"] = metadata["duration"]
            link["animation_duration_seconds"] = metadata["duration_seconds"]
    return {
        "schema_version": 1,
        "source_archive": {
            "sha256": source_sets[0].get("outer_source_sha256"),
            "data_zpak_sha256": source_sets[0].get("data_zpak_sha256"),
        },
        "sets": source_sets,
        "actions": sorted(
            action_inventory,
            key=lambda item: (item["source_set"], item["name"]),
        ),
        "normal_frontal_hit_links": hit_mappings["normal"],
        "all_frontal_hit_links": hit_mappings,
        "normal_block_links": block_mappings,
        "stun_links": stun_links,
        "return_to_idle_links": returns,
        "evidence": {
            "configured_action_names_and_metadata": "STATIC_VERIFIED",
            "condition_to_action_links": "STATIC_VERIFIED",
            "time_windows_are_in_animation_frames": "STATIC_SUPPORTED",
            "potential_earliest_idle_transition": "STATIC_SUPPORTED",
            "effective_hitstun_or_blockstun_duration": "UNVERIFIED",
            "push_mapping": "UNVERIFIED",
            "note": (
                "Transition windows are exported without treating animation "
                "duration as loss-of-control duration."
            ),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, help="outer ZIP or data.zpak, read only")
    parser.add_argument("--report", type=Path, help="write a new JSON report")
    args = parser.parse_args()
    try:
        report = inspect_archive(args.archive)
        rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
        if args.report is None:
            print(rendered, end="")
        else:
            if args.report.exists():
                raise ReactionInventoryError(
                    f"report path already exists: {args.report}"
                )
            args.report.write_text(rendered, encoding="utf-8", newline="\n")
            print(
                f"wrote {len(report['actions'])} actions and "
                f"{len(report['return_to_idle_links'])} return links to "
                f"{args.report}"
            )
    except (OSError, KdfError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

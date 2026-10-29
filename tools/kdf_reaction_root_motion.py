#!/usr/bin/env python3
"""Export reaction-animation positions tracks without assigning push semantics."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_animation import inspect_animation
from kdf_data import KdfError
from kdf_fighting_set import read_archive_resource


_ACTIONS = {
    "impactlightfrontlow": "adreno_200/animation/all_impct_light_frnt_low.anm",
    "impactlightfrontmid": "adreno_200/animation/all_impct_light_frnt_mid.anm",
    "impactlightfronthigh": "adreno_200/animation/all_impct_light_frnt_high.anm",
    "lowblock": "adreno_200/animation/all_block_low.anm",
    "midblock": "adreno_200/animation/all_block_mid.anm",
    "highblock": "adreno_200/animation/all_block_high.anm",
}


class ReactionRootMotionError(KdfError):
    pass


def summarize_vectors(values: list[list[float]]) -> dict:
    if not values:
        raise ReactionRootMotionError("positions track is empty")
    for value in values:
        if len(value) != 3:
            raise ReactionRootMotionError("positions sample is not a three-component vector")
        if not all(type(component) in (int, float) and math.isfinite(component)
                   for component in value):
            raise ReactionRootMotionError("positions sample contains a non-finite numeric value")
    columns = list(zip(*values))
    minimum = [min(column) for column in columns]
    maximum = [max(column) for column in columns]
    return {
        "frame_count": len(values),
        "first": list(values[0]),
        "last": list(values[-1]),
        "minimum": minimum,
        "maximum": maximum,
        "range": [
            maximum[index] - minimum[index]
            for index in range(3)
        ],
        "maximum_absolute": [
            max(abs(component) for component in column)
            for column in columns
        ],
    }


def validate_positions_frame_count(values: list[list[float]], expected: int) -> None:
    if type(expected) is not int or expected <= 0:
        raise ReactionRootMotionError("animation duration is missing or invalid")
    if len(values) != expected:
        raise ReactionRootMotionError(
            f"positions track has {len(values)} frames, expected {expected}"
        )


def _inspect_tracks(inspection: dict) -> tuple[list[dict], list[dict] | None]:
    tracks = []
    positions_values = None
    for group in inspection["track_groups"]:
        for track in group["tracks"]:
            sample = track["sample"]
            data = sample["data"]
            tracks.append({
                "group": group["ordinal"],
                "name": track["name"],
                "codec": sample["codec"],
                "decode_status": sample["decode_status"],
                "element_count": data.get("element_count"),
                "element_stride": data.get("element_stride"),
            })
            if track["name"] != "positions":
                continue
            decoded = data.get("decoded")
            if not isinstance(decoded, dict) or not isinstance(decoded.get("values"), list):
                raise ReactionRootMotionError(
                    "positions track does not have decoded fixed-point values"
                )
            if positions_values is not None:
                raise ReactionRootMotionError(
                    "animation contains more than one positions track"
                )
            positions_values = decoded["values"]
    return tracks, positions_values


def inspect_archive(path: Path) -> dict:
    actions = []
    source_hashes = None
    for action, animation_path in sorted(_ACTIONS.items()):
        raw, archive = read_archive_resource(path, animation_path)
        if source_hashes is None:
            source_hashes = {
                "sha256": archive["source_sha256"],
                "data_zpak_sha256": archive["data_zpak_sha256"],
            }
        inspection = inspect_animation(
            raw,
            include_values=True,
            decode_wavelet_values=False,
        )
        tracks, positions = _inspect_tracks(inspection)
        action_report = {
            "source_action": action,
            "animation": animation_path,
            "sha256": hashlib.sha256(raw).hexdigest(),
            "resource_id": archive["resource_id"],
            "pakd_offset": archive["pakd_offset"],
            "headers": inspection["headers"],
            "tracks": tracks,
            "positions_track_present": positions is not None,
            "track_presence": {
                name: any(track["name"] == name for track in tracks)
                for name in ("positions", "bonepos", "bonerot", "scales")
            },
        }
        if positions is not None:
            validate_positions_frame_count(
                positions,
                inspection["headers"]["duration"],
            )
            action_report["positions"] = positions
            action_report["positions_summary"] = summarize_vectors(positions)
        actions.append(action_report)
    if source_hashes is None:
        raise ReactionRootMotionError("no reaction animations were requested")
    return {
        "schema_version": 1,
        "source_archive": source_hashes,
        "actions": actions,
        "evidence": {
            "positions_track_values": "STATIC_VERIFIED",
            "native_instruction_chain": "STATIC_VERIFIED",
            "positions_track_consumed_by_root_transform": "STATIC_SUPPORTED",
            "positions_axis_semantics": "UNVERIFIED",
            "push_or_knockback_mapping": "HYPOTHESIS",
            "note": (
                "The report exports positions tracks and frame values only. "
                "It does not classify an axis as horizontal push or replace "
                "the Godot prototype push."
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
                raise ReactionRootMotionError(
                    f"report path already exists: {args.report}"
                )
            args.report.write_text(rendered, encoding="utf-8", newline="\n")
            print(
                f"wrote {len(report['actions'])} reaction root-motion records to "
                f"{args.report}"
            )
    except (OSError, KdfError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

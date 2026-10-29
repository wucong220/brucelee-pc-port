#!/usr/bin/env python3
"""Report one opponent's local resource chain without exporting binary payloads."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_animation import inspect_animation
from kdf_animation_binding import _header_reference
from kdf_data import KdfError, parse_container, parse_context
from kdf_fighting_set import read_archive_resource
from kdf_mesh import inspect_mesh
from kdf_object import inspect_object
from kdf_skeleton import inspect_skeleton
from tex_convert import _property_u32


TARGET = "bl_brick_davis_01"
SKELETON = "adreno_200/skeletons/BL_Brick_Davis_01_High.Skl"
SKELETON_REFERENCE = "skeletons/bl_brick_davis_01_high.skl"
OBJECT = "adreno_200/objects/BL_Brick_Davis_01_High.obj"
MESHES = {
    "body": "adreno_200/objects/hw/bl_brick_davis_01_high/meshes/"
            "bl_brick_davis_01_body_hw_kinetic.Mesh",
    "shadows": "adreno_200/objects/hw/bl_brick_davis_01_high/meshes/"
               "bl_brick_davis_01_body_hw_shadows.Mesh",
}
TEXTURES = {
    "diffuse": "adreno_200/objects/hw/bl_brick_davis_01_high/textures/"
               "19820ad048bfb97f17e3d9bd4118004252bf273f.tex",
    "normal": "adreno_200/objects/hw/bl_brick_davis_01_high/textures/"
              "00b10ae060e9dc141268c2fc23f46a7e69403a5e.tex",
    "material": "adreno_200/objects/hw/bl_brick_davis_01_high/textures/"
                "5c4dc7f7333f7fc62ae1229fbcdc0f58e877fb1d.tex",
}
ANIMATIONS = (
    "adreno_200/animation/m03_idle_01.anm",
    "adreno_200/animation/m03_pnch_low_01.anm",
    "adreno_200/animation/m03_kck_low_01.anm",
    "adreno_200/animation/m03_movefwd.anm",
)


class OpponentInventoryError(KdfError):
    pass


def _read(archive: Path, path: str) -> tuple[bytes, dict]:
    try:
        return read_archive_resource(archive, path)
    except (OSError, KdfError) as exc:
        raise OpponentInventoryError(f"could not read {path}: {exc}") from exc


def _identity(raw: bytes, metadata: dict) -> dict:
    return {
        "sha256": hashlib.sha256(raw).hexdigest(),
        "decoded_bytes": len(raw),
        "resource_id": metadata["resource_id"],
        "pakd_offset": metadata["pakd_offset"],
    }


def _archive_path(reference: str) -> str:
    normalized = reference.replace("\\", "/")
    return normalized if normalized.startswith("adreno_200/") else "adreno_200/" + normalized


def _texture_metadata(raw: bytes) -> dict:
    container = parse_container(raw)
    strings = [entry["text"] for entry in container["strings"]]
    record_start = (
        container["data_offset"] + 20 + 4 * (container["offset_count"] + 1)
    )

    def scalar(name: str) -> int:
        return _property_u32(
            raw, record_start, container["record_count"], strings.index(name)
        )

    formats = {
        value for value in strings
        if value in {"atc_rgb", "atc_rgba", "r8g8b8a8"}
    }
    if len(formats) != 1:
        raise OpponentInventoryError("texture format declaration is missing or ambiguous")
    return {
        "width": scalar("sizex"),
        "height": scalar("sizey"),
        "depth": scalar("sizez"),
        "has_alpha": bool(scalar("hasalpha")),
        "format": next(iter(formats)),
        "payload_bytes": container["payload_bytes"],
    }


def build_inventory(archive: Path) -> dict:
    skeleton_raw, skeleton_meta = _read(archive, SKELETON)
    skeleton = inspect_skeleton(skeleton_raw)
    object_raw, object_meta = _read(archive, OBJECT)
    object_report = inspect_object(object_raw)

    references = {
        entry["ordinal"]: _archive_path(entry["path"])
        for entry in object_report["external_references"]
        if not entry.get("sentinel")
    }
    texture_uses = {}
    for use in object_report["external_reference_uses"]:
        if use["property"] in TEXTURES:
            if use["property"] in texture_uses:
                raise OpponentInventoryError(
                    f"object repeats texture property {use['property']}"
                )
            texture_uses[use["property"]] = references[use["reference_id"]]

    mesh_reports = {}
    mesh_identities = {}
    for kind, path in MESHES.items():
        raw, metadata = _read(archive, path)
        report = inspect_mesh(raw)
        mesh_identities[kind] = {**_identity(raw, metadata), "path": path}
        mesh_reports[kind] = {
            "vertex_count": report["vertex_count"],
            "triangle_count": report["triangle_count"],
            "subset_count": report["subset_count"],
            "skin_bone_count": report["skeleton"]["bone_count"],
            "position_min": report["position_min"],
            "position_max": report["position_max"],
            "subsets": [
                {
                    "material": subset["material"],
                    "triangle_count": subset["triangle_count"],
                }
                for subset in report["subsets"]
            ],
        }

    texture_reports = {}
    for property_name, path in TEXTURES.items():
        if texture_uses.get(property_name, "").casefold() != path.casefold():
            raise OpponentInventoryError(
                f"object {property_name} texture does not match the expected path"
            )
        raw, metadata = _read(archive, path)
        texture = _texture_metadata(raw)
        texture_reports[property_name] = {
            **_identity(raw, metadata),
            "path": path,
            "width": texture["width"],
            "height": texture["height"],
            **texture,
        }

    animation_reports = {}
    for path in ANIMATIONS:
        raw, metadata = _read(archive, path)
        context = parse_context(raw)
        container = parse_container(raw, data_offset=context["data_offset"])
        reference = _header_reference(context, container)["reference"]
        if reference.casefold() != SKELETON_REFERENCE:
            raise OpponentInventoryError(
                f"{path} references {reference!r}, expected the Brick skeleton"
            )
        inspection = inspect_animation(raw, data_offset=context["data_offset"])
        animation_reports[Path(path).stem] = {
            **_identity(raw, metadata),
            "path": path,
            "skeleton_reference": reference,
            "headers": inspection["headers"],
            "tracks": sorted({
                track["name"]
                for group in inspection["track_groups"]
                for track in group["tracks"]
            }),
        }

    expected_references = {
        MESHES["body"],
        MESHES["shadows"],
        *TEXTURES.values(),
        _archive_path("shaders/character.shd"),
    }
    if ({path.casefold() for path in references.values()}
            != {path.casefold() for path in expected_references}):
        raise OpponentInventoryError("object references do not match the expected Brick resources")

    archive_meta = skeleton_meta
    return {
        "schema_version": 1,
        "target": TARGET,
        "source_archive": {
            "sha256": archive_meta["source_sha256"],
            "data_zpak_sha256": archive_meta["data_zpak_sha256"],
        },
        "skeleton": {
            **_identity(skeleton_raw, skeleton_meta),
            "path": SKELETON,
            "node_count": len(skeleton["nodes"]),
            "bone_count": sum(node["type"] == "bone" for node in skeleton["nodes"]),
            "object_count": sum(node["type"] == "object" for node in skeleton["nodes"]),
        },
        "object": {
            **_identity(object_raw, object_meta),
            "path": OBJECT,
            "scene_node_count": object_report["scene_node_count"],
            "external_references": sorted(references.values()),
            "texture_properties": {
                name: path for name, path in sorted(texture_uses.items())
            },
        },
        "meshes": mesh_identities,
        "mesh_details": mesh_reports,
        "textures": texture_reports,
        "animations": animation_reports,
        "evidence": {
            "paths_and_hashes": "STATIC_VERIFIED",
            "object_texture_properties": "STATIC_VERIFIED",
            "animation_skeleton_reference": "STATIC_VERIFIED",
            "godot_opponent_integration": "UNVERIFIED",
            "opponent_combat_configuration": "UNVERIFIED",
            "visual_runtime_parity": "UNVERIFIED",
        },
        "boundaries": [
            "The object's empty external-reference slot is treated as a sentinel "
            "whose runtime reference indices are shifted by one.",
            "Texture properties are static object references; GPU sampling and final "
            "pixel output are not verified. ATC texture payloads are not decoded here.",
            "The listed m03 animations target the Brick skeleton, but their runtime "
            "combination, blending and original combat use remain to be verified.",
            "No original resource bytes or decoded binary payloads are included.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, help="outer ZIP or data.zpak, read only")
    parser.add_argument("--report", type=Path, help="new metadata JSON output")
    args = parser.parse_args()
    try:
        report = build_inventory(args.archive)
        rendered = json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
        if args.report is None:
            sys.stdout.write(rendered)
        else:
            with args.report.open("x", encoding="utf-8", newline="\n") as output:
                output.write(rendered)
    except (OSError, KdfError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Convert a validated Mesh geometry to local Wavefront OBJ without asset packaging."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_data import KdfError
from kdf_mesh import inspect_file

_PROJECT_ROOT = Path(__file__).resolve().parents[1]


class MeshExportError(ValueError):
    """OBJ conversion target is unsafe or the Mesh profile is unsupported."""


def _safe_output_path(path: Path) -> Path:
    target = path.expanduser().resolve()
    project = _PROJECT_ROOT.resolve()
    if target == project or target.is_relative_to(project):
        raise MeshExportError('OBJ output must be outside the project checkout')
    sync_names = {'baidusyncdisk', 'onedrive', 'dropbox', 'google drive', 'icloud drive'}
    for part in target.parts:
        name = part.casefold()
        if name in sync_names or name.startswith('onedrive - '):
            raise MeshExportError('OBJ output is inside a known sync folder')
    for name in ('OneDrive', 'OneDriveConsumer', 'OneDriveCommercial',
                 'DROPBOX_PATH', 'GOOGLE_DRIVE_PATH', 'BAIDU_SYNC_ROOT'):
        value = os.environ.get(name)
        if value:
            root = Path(value).expanduser().resolve()
            if target == root or target.is_relative_to(root):
                raise MeshExportError('OBJ output is inside a configured sync folder')
    if target.exists():
        raise MeshExportError('OBJ output already exists')
    if not target.parent.is_dir():
        raise MeshExportError('OBJ output parent is not an existing directory')
    if target.suffix.casefold() != '.obj':
        raise MeshExportError('OBJ output must use the .obj extension')
    return target


def _material_name(value: str, subset: int) -> str:
    safe = re.sub(r'[^A-Za-z0-9_.-]+', '_', value).strip('_')
    return safe or f'subset_{subset}'


def _wavefront(geometry: dict) -> bytes:
    lines = [
        '# Bruce Lee PC port research export; original source digest: '
        + geometry['sha256'],
        '# Stored axes: X horizontal, Y depth, Z up; Godot mapping unverified.',
        '# OBJ contains geometry and UV only; skin indices/weights are not included.',
        'o brucelee_mesh',
    ]
    vertices = geometry['vertices']
    for vertex in vertices:
        position = vertex['position']
        lines.append(f'v {position[0]:.9g} {position[1]:.9g} {position[2]:.9g}')
    for vertex in vertices:
        uv = vertex['uv']
        lines.append(f'vt {uv[0]:.9g} {uv[1]:.9g}')
    indices = geometry['indices']
    for subset_ordinal, subset in enumerate(geometry['subsets']):
        start, end = subset['index_range']
        material = _material_name(subset['material'], subset_ordinal)
        lines.append(f'g subset_{subset_ordinal}')
        lines.append(f'usemtl {material}')
        for offset in range(start, end, 3):
            a, b, c = indices[offset:offset + 3]
            lines.append(
                f'f {a + 1}/{a + 1} {b + 1}/{b + 1} {c + 1}/{c + 1}')
    return ('\n'.join(lines) + '\n').encode('utf-8')


def convert_file(source: Path, destination: Path) -> dict:
    geometry = inspect_file(
        source, include_vertices=True, include_indices=True)
    target = _safe_output_path(destination)
    payload = _wavefront(geometry)
    with target.open('xb') as file:
        file.write(payload)
    return {
        'source': str(source),
        'output': str(target),
        'obj_bytes': len(payload),
        'obj_sha256': hashlib.sha256(payload).hexdigest(),
        'vertex_count': geometry['vertex_count'],
        'index_count': geometry['index_count'],
        'triangle_count': geometry['triangle_count'],
        'subset_count': geometry['subset_count'],
        'geometry_axes': geometry['geometry_axes'],
        'godot_axis_mapping': 'unverified',
        'skin_data_included': False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='decoded Mesh CTX3 resource')
    parser.add_argument('--output', type=Path, required=True,
                        help='new OBJ outside the checkout and sync directories')
    args = parser.parse_args()
    try:
        result = convert_file(args.source, args.output)
    except (OSError, KdfError, MeshExportError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

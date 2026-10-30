#!/usr/bin/env python3
"""Compare one ANM's candidate track targets in two local Skl files.

This is a read-only diagnostic. Matching indices or names do not establish
native cross-skeleton retargeting, rest-space compatibility, or safe playback.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from kdf_animation_binding import bind_animation
from kdf_data import KdfError


def compare(source: dict, target: dict) -> dict:
    if source['animation_sha256'] != target['animation_sha256']:
        raise KdfError('bindings do not refer to the same animation')
    if (source['skeleton_reference']['reference']
            != target['skeleton_reference']['reference']):
        raise KdfError('bindings have different animation skeleton references')

    def indexed(binding: dict) -> dict:
        result = {}
        for item in binding['bindings']:
            key = (item['track'], item['offset'])
            if key in result:
                raise KdfError('duplicate track/offset key')
            result[key] = item
        return result

    left, right = indexed(source), indexed(target)
    if left.keys() != right.keys():
        raise KdfError('binding track/offset keys differ')
    differences = []
    for track, offset in sorted(left):
        a, b = left[(track, offset)], right[(track, offset)]
        if (a['node_name'], a['node_type']) != (b['node_name'], b['node_type']):
            differences.append({
                'track': track, 'offset': offset,
                'source_name': a['node_name'], 'source_type': a['node_type'],
                'target_name': b['node_name'], 'target_type': b['node_type'],
            })
    return {
        'animation_sha256': source['animation_sha256'],
        'animation_skeleton_reference': source['skeleton_reference']['reference'],
        'source_skeleton_sha256': source['skeleton_sha256'],
        'target_skeleton_sha256': target['skeleton_sha256'],
        'binding_count': len(left),
        'same_name_and_type_count': len(left) - len(differences),
        'differences': differences,
        'pairing_status': 'unverified',
        'note': (
            'Index comparison is diagnostic only; it does not validate native '
            'retargeting, transform spaces, or playback on the target skeleton.'
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('animation', type=Path)
    parser.add_argument('source_skeleton', type=Path)
    parser.add_argument('target_skeleton', type=Path)
    args = parser.parse_args()
    try:
        animation = args.animation.read_bytes()
        source = bind_animation(animation, args.source_skeleton.read_bytes())
        target = bind_animation(animation, args.target_skeleton.read_bytes())
        print(json.dumps(compare(source, target), indent=2, ensure_ascii=False))
    except (OSError, KdfError, KeyError, TypeError, ValueError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

#!/usr/bin/env python3
"""Audit candidate track identities across skeletons; do not retarget or export."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from kdf_animation_binding import bind_animation
from kdf_data import KdfError
from kdf_skeleton import inspect_skeleton


def _paths(skeleton: dict) -> tuple[dict, dict]:
    nodes = skeleton['nodes']
    ids = {node['nodeid']: node for node in nodes}
    if len(ids) != len(nodes):
        raise KdfError('duplicate node IDs')
    paths = {}
    for node in nodes:
        current = node
        seen = set()
        path = []
        while True:
            nodeid = current['nodeid']
            if nodeid in seen:
                raise KdfError('cyclic skeleton hierarchy')
            seen.add(nodeid)
            name, kind = current['name'], current['type']
            if not isinstance(name, str) or not name:
                raise KdfError('skeleton node has no name')
            path.append((kind, name))
            if kind == 'root':
                break
            parent = current['parentid']
            if parent not in ids:
                raise KdfError('skeleton node has missing parent')
            current = ids[parent]
        paths[node['nodeid']] = tuple(reversed(path))
    return ids, paths


def audit(binding: dict, source: dict, target: dict) -> dict:
    """Identify candidate targets, rejecting ambiguous paths and channel collisions."""
    if binding['skeleton_sha256'] != source['sha256']:
        raise KdfError('binding and source skeleton do not match')
    source_ids, source_paths = _paths(source)
    target_ids, target_paths = _paths(target)
    target_by_path = {}
    for nodeid, path in target_paths.items():
        if path in target_by_path:
            raise KdfError('target skeleton has ambiguous node path')
        target_by_path[path] = target_ids[nodeid]
    if len(set(source_paths.values())) != len(source_paths):
        raise KdfError('source skeleton has ambiguous node path')
    mappings, seen = [], set()
    checked_fields = set()
    for item in binding['bindings']:
        source_node = source_ids.get(item['nodeid'])
        if (source_node is None or source_node['name'] != item['node_name']
                or source_node['type'] != item['node_type']
                or source_node.get(item['index_field']) != item['offset']):
            raise KdfError('source binding does not match skeleton node')
        path = source_paths[item['nodeid']]
        destination = target_by_path.get(path)
        if destination is None:
            raise KdfError('target skeleton lacks matching typed path')
        index = destination.get(item['index_field'])
        if type(index) is not int or index < 0:
            raise KdfError('target node lacks valid channel index')
        field = item['index_field']
        if field not in checked_fields:
            indices = [node[field] for node in target['nodes'] if field in node]
            if (any(type(value) is not int or value < 0 for value in indices)
                    or len(set(indices)) != len(indices)):
                raise KdfError('target channel indices are invalid or ambiguous')
            checked_fields.add(field)
        key = (destination['nodeid'], item['target'])
        if key in seen:
            raise KdfError('multiple tracks target the same node channel')
        seen.add(key)
        mappings.append({
            'track': item['track'], 'channel': item['target'],
            'path': [list(part) for part in path],
            'source_offset': item['offset'], 'target_offset': index,
            'source_nodeid': item['nodeid'], 'target_nodeid': destination['nodeid'],
        })
    if not mappings:
        raise KdfError('no animation tracks to audit')
    return {
        'animation_sha256': binding['animation_sha256'],
        'source_skeleton_sha256': source['sha256'],
        'target_skeleton_sha256': target['sha256'],
        'mapping_count': len(mappings),
        'mappings': mappings,
        'status': 'identity-candidate-only',
        'note': ('Matching typed paths does not verify transform semantics, rest pose, '
                 'mesh binding, native remapping, or playback.'),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('animation', type=Path)
    parser.add_argument('source_skeleton', type=Path)
    parser.add_argument('target_skeleton', type=Path)
    args = parser.parse_args()
    try:
        animation = args.animation.read_bytes()
        source_raw = args.source_skeleton.read_bytes()
        target_raw = args.target_skeleton.read_bytes()
        source = inspect_skeleton(source_raw)
        target = inspect_skeleton(target_raw)
        result = audit(bind_animation(animation, source_raw), source, target)
        print(json.dumps(result, indent=2, ensure_ascii=False))
    except (OSError, KdfError, KeyError, TypeError, ValueError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

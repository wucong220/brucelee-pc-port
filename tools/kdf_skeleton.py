#!/usr/bin/env python3
"""Recover validated Skl node hierarchy without exporting binary assets."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_data import KdfError, parse_container, property_occurrences, scalar_occurrences

_MAX_RESOURCE_BYTES = 16 * 1024 * 1024
_NODE_TYPE_MARKER = 0x60000000
_PROPERTY_MARKERS = {
    'type': {_NODE_TYPE_MARKER},
    'nodeid': {0},
    'parentid': {0x10000000},
    'treesize': {0},
    'offset': {0x30000000, 0x30000003},
}


def _string_ordinal(container: dict, value: str) -> int:
    matches = [entry['ordinal'] for entry in container['strings'] if entry['text'] == value]
    if len(matches) != 1:
        raise KdfError(f'expected one Skl string named {value!r}')
    return matches[0]


def inspect_skeleton(raw: bytes) -> dict:
    container = parse_container(raw)
    occurrences = {
        key: property_occurrences(container, key, value_markers=markers)
        for key, markers in _PROPERTY_MARKERS.items()
    }
    node_type_ordinals = {_string_ordinal(container, value) for value in ('root', 'object', 'bone')}
    type_starts = [
        entry['key_record'] for entry in occurrences['type']
        if entry['value'] in node_type_ordinals
    ]
    records_end = container['record_count']
    nodes = []
    for ordinal, start in enumerate(type_starts):
        end = type_starts[ordinal + 1] if ordinal + 1 < len(type_starts) else records_end
        fields = {}
        for key in ('nodeid', 'parentid', 'treesize', 'offset'):
            found = [entry for entry in occurrences[key] if start <= entry['key_record'] < end]
            if len(found) != 1:
                fields = {}
                break
            fields[key] = found[0]['value']
        if not fields:
            continue
        type_value = next(
            entry['value'] for entry in occurrences['type'] if entry['key_record'] == start
        )
        type_name = container['strings'][type_value]['text']
        parent_raw = fields['parentid']
        parent = struct.unpack('<i', struct.pack('<I', parent_raw))[0]
        nodes.append({
            'nodeid': fields['nodeid'],
            'parentid': parent,
            'treesize': fields['treesize'],
            'offset': fields['offset'],
            'type_id': type_value,
            'type': type_name,
            'record_start': start,
            'record_end': end,
        })
    if not nodes:
        raise KdfError('no Skl node records found')
    ids = [node['nodeid'] for node in nodes]
    if len(set(ids)) != len(ids):
        raise KdfError('duplicate Skl nodeid')
    by_id = {node['nodeid']: node for node in nodes}
    children = {node['nodeid']: [] for node in nodes}
    roots = []
    for node in nodes:
        if node['parentid'] == -2:
            roots.append(node['nodeid'])
        elif node['parentid'] not in by_id:
            raise KdfError(f'Skl node {node["nodeid"]} has missing parent {node["parentid"]}')
        else:
            children[node['parentid']].append(node['nodeid'])
    if len(roots) != 1:
        raise KdfError('Skl must contain exactly one root node')

    def subtree_size(node_id: int, active: set[int]) -> int:
        if node_id in active:
            raise KdfError('cycle detected in Skl hierarchy')
        active.add(node_id)
        size = 1 + sum(subtree_size(child, active) for child in children[node_id])
        active.remove(node_id)
        return size

    for node in nodes:
        calculated = subtree_size(node['nodeid'], set())
        if calculated != node['treesize']:
            raise KdfError(
                f'Skl node {node["nodeid"]} treesize {node["treesize"]} != {calculated}'
            )
        node['children'] = children[node['nodeid']]
    names = {entry['text'] for entry in container['strings']}
    bone_positions = (
        [entry['value'] for entry in scalar_occurrences(container, 'bonepos')]
        if 'bonepos' in names else []
    )
    bone_rotations = (
        [entry['value'] for entry in scalar_occurrences(container, 'bonerot')]
        if 'bonerot' in names else []
    )
    return {
        'sha256': container['sha256'],
        'decoded_bytes': container['decoded_bytes'],
        'node_count': len(nodes),
        'roots': roots,
        'nodes': nodes,
        'bone_position_indices': bone_positions,
        'bone_rotation_indices': bone_rotations,
        'sections': container['sections'],
        'tail_identity_hex': container['tail_identity_hex'],
    }


def inspect_file(path: Path) -> dict:
    with path.open('rb') as file:
        raw = file.read(_MAX_RESOURCE_BYTES + 1)
    if len(raw) > _MAX_RESOURCE_BYTES:
        raise KdfError('decoded skeleton exceeds inspection size limit')
    result = inspect_skeleton(raw)
    result['source'] = str(path)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='decoded Skl CTX3 resource')
    args = parser.parse_args()
    try:
        result = inspect_file(args.source)
    except (OSError, KdfError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

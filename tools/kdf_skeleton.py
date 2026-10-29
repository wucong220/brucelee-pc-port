#!/usr/bin/env python3
"""Recover validated Skl node hierarchy without exporting binary assets."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_data import KdfError, parse_container, property_occurrences

_MAX_RESOURCE_BYTES = 16 * 1024 * 1024
_NODE_TYPE_MARKER = 0x60000000
_POSITION_SECTION = 0
_POSITION_INDEX_SECTION = 1
_OBJECT_POSITION_SECTION = 2
_OBJECT_POSITION_INDEX_SECTION = 3
_ROTATION_SECTION = 4
_ROTATION_INDEX_SECTION = 5
_OBJECT_ROTATION_SECTION = 6
_OBJECT_ROTATION_INDEX_SECTION = 7
_SCALE_SECTION = 8
_SCALE_INDEX_SECTION = 9
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


def _node_property(occurrences: list[dict], start: int, end: int,
                   key: str, nodeid: int) -> int | None:
    found = [
        entry for entry in occurrences
        if start <= entry['key_record'] < end
    ]
    if len(found) > 1:
        raise KdfError(f'Skl node {nodeid} repeats property {key!r}')
    return found[0]['value'] if found else None


def _validate_dense_indices(values: list[int], label: str) -> None:
    if sorted(values) != list(range(len(values))):
        raise KdfError(f'Skl {label} indices do not densely cover 0..{len(values) - 1}')


def _validate_object_indices(values: list[int], label: str) -> None:
    if len(set(values)) != len(values):
        raise KdfError(f'Skl object {label} indices contain duplicates')
    if any(value >= len(values) for value in values):
        raise KdfError(f'Skl object {label} index is out of range')


def _object_scalar_property(
        occurrences: list[dict], node: dict, key: str) -> int:
    found = [
        entry for entry in occurrences
        if node['record_start'] <= entry['key_record'] < node['record_end']
    ]
    if len(found) != 1 or found[0]['value_marker'] != 0:
        raise KdfError(
            f'Skl object {node["nodeid"]} requires one scalar {key!r} property'
        )
    return found[0]['value']


def _resolve_node_names(container: dict, node_starts: list[int]) -> dict[int, str]:
    count = len(node_starts)
    first_node = node_starts[0]
    table_start = first_node - count * 2
    if table_start < 0:
        raise KdfError('Skl name-reference table starts before DATA records')
    records = container['records']
    strings = container['strings']
    names = {}
    for table_index, target in enumerate(node_starts):
        key_record = table_start + table_index * 2
        pointer_record = key_record + 1
        key = records[key_record]
        pointer = records[pointer_record]
        if key['first'] != 0x60000000:
            raise KdfError(f'Skl name reference {table_index} has invalid key marker')
        if key['second'] >= len(strings):
            raise KdfError(f'Skl name reference {table_index} has invalid string ordinal')
        if pointer['first'] not in (0x30000005, 0x30000006):
            raise KdfError(f'Skl name reference {table_index} has invalid pointer marker')
        if pointer_record + pointer['second'] != target:
            raise KdfError(f'Skl name reference {table_index} does not target its node')
        names[target] = strings[key['second']]['text']
    if set(names) != set(node_starts) or len(names) != count:
        raise KdfError('Skl name references do not uniquely cover every node')
    return names


def _node_region_end(container: dict, node_starts: list[int]) -> tuple[int, bool]:
    if not any(entry['text'] == 'rawfloatsample' for entry in container['strings']):
        return container['record_count'], False
    trailing_samples = property_occurrences(container, 'rawfloatsample')
    candidates = [
        entry['key_record'] for entry in trailing_samples
        if entry['key_record'] > node_starts[-1]
    ]
    if not candidates:
        return container['record_count'], False
    first_sample = min(candidates)
    type_ordinal = _string_ordinal(container, 'type')
    records = container['records']
    if (
        first_sample > 0
        and records[first_sample - 1]['first'] == 0x60000000
        and records[first_sample - 1]['second'] == type_ordinal
    ):
        first_sample -= 1
    names = ('bonepos', 'positions', 'bonerot', 'rotations', 'scales')
    declaration_start = first_sample - len(names) * 2
    if declaration_start <= node_starts[-1]:
        return first_sample, False

    def record_text(ordinal: int) -> str | None:
        record = records[ordinal]
        if record['first'] != 0x60000000:
            return None
        index = record['second']
        if index >= len(container['strings']):
            return None
        return container['strings'][index]['text']

    if any(
            record_text(declaration_start + ordinal * 2) != name
            for ordinal, name in enumerate(names)):
        return first_sample, False

    references = {
        item['record_ordinal']: item for item in container['array_references']
    }
    for ordinal, (name, stride) in enumerate(zip(names, (12, 12, 16, 16, 12))):
        pointer_ordinal = declaration_start + ordinal * 2 + 1
        pointer = records[pointer_ordinal]
        sample_start = first_sample + ordinal * 6
        if (pointer['first'] != 0x30000003
                or pointer_ordinal + pointer['second'] != sample_start
                or sample_start + 5 >= len(records)
                or record_text(sample_start) != 'type'
                or record_text(sample_start + 1) != 'rawfloatsample'
                or record_text(sample_start + 2) != 'data'
                or record_text(sample_start + 4) != 'offset'):
            raise KdfError(f'Skl {name} sample declaration is invalid')
        data = references.get(sample_start + 3)
        offset = references.get(sample_start + 5)
        if (data is None or offset is None
                or data['section_index'] != ordinal * 2
                or offset['section_index'] != ordinal * 2 + 1
                or data['element_stride'] != stride
                or offset['element_stride'] != 2
                or data['element_count'] != offset['element_count']):
            raise KdfError(f'Skl {name} sample array layout is invalid')
    return declaration_start, True


def _section_start(container: dict, section_index: int) -> int:
    section = container['sections'][section_index]
    return container['payload_offset'] + section['start_relative']


def _validate_index_section(container: dict, section_index: int, count: int) -> None:
    section = container['sections'][section_index]
    required = count * 2
    if section['bytes'] < required or section['bytes'] - required > 3:
        raise KdfError(
            f'Skl index section {section_index} has {section["bytes"]} bytes; '
            f'expected {required} plus at most 3 padding bytes'
        )


def _read_u16_indices(raw: bytes, container: dict, section_index: int,
                      count: int) -> tuple[int, ...]:
    _validate_index_section(container, section_index, count)
    return struct.unpack_from(f'<{count}H', raw, _section_start(container, section_index))


def _read_vectors(raw: bytes, container: dict, section_index: int, count: int,
                  width: int) -> list[tuple[float, ...]]:
    section = container['sections'][section_index]
    expected = count * width * 4
    if section['bytes'] != expected:
        raise KdfError(
            f'Skl vector section {section_index} has {section["bytes"]} bytes; '
            f'expected {expected}'
        )
    start = _section_start(container, section_index)
    return [
        struct.unpack_from(f'<{width}f', raw, start + index * width * 4)
        for index in range(count)
    ]


def _extract_static_transforms(raw: bytes, container: dict, nodes: list[dict],
                               scale_indices: list[int]) -> list[dict] | None:
    if len(container['sections']) < 10:
        return None
    bones = [node for node in nodes if node['type'] == 'bone']
    bone_count = len(bones)
    if not bone_count:
        return []
    positions = _read_vectors(raw, container, _POSITION_SECTION, bone_count, 3)
    rotations = _read_vectors(raw, container, _ROTATION_SECTION, bone_count, 4)
    scales = _read_vectors(raw, container, _SCALE_SECTION, len(scale_indices), 3)
    position_order = _read_u16_indices(
        raw, container, _POSITION_INDEX_SECTION, bone_count)
    rotation_order = _read_u16_indices(
        raw, container, _ROTATION_INDEX_SECTION, bone_count)
    scale_order = _read_u16_indices(
        raw, container, _SCALE_INDEX_SECTION, len(scale_indices))
    if position_order != tuple(range(bone_count)):
        raise KdfError('Skl position index section is not ordered 0..bone_count-1')
    if rotation_order != tuple(range(bone_count)):
        raise KdfError('Skl rotation index section is not ordered 0..bone_count-1')
    if scale_order != tuple(range(len(scale_indices))):
        raise KdfError('Skl scale index section is not ordered 0..scale_count-1')

    transforms = []
    for node, position_index, rotation_index in zip(
            bones, (node['bone_position_index'] for node in bones),
            (node['bone_rotation_index'] for node in bones), strict=True):
        scale_index = node.get('scale_index')
        if scale_index is None:
            raise KdfError(f'Skl bone {node["nodeid"]} has no scale index')
        if position_index >= bone_count or rotation_index >= bone_count:
            raise KdfError(f'Skl bone {node["nodeid"]} transform index is out of range')
        if scale_index >= len(scales):
            raise KdfError(f'Skl bone {node["nodeid"]} scale index is out of range')
        position = positions[position_index]
        rotation = rotations[rotation_index]
        scale = scales[scale_index]
        if not all(math.isfinite(value) for value in position + rotation + scale):
            raise KdfError(f'Skl bone {node["nodeid"]} transform is not finite')
        norm = math.sqrt(sum(value * value for value in rotation))
        if abs(norm - 1.0) > 1e-5:
            raise KdfError(f'Skl bone {node["nodeid"]} rotation norm {norm} is not 1')
        transforms.append({
            'nodeid': node['nodeid'],
            'position_index': position_index,
            'rotation_index': rotation_index,
            'scale_index': scale_index,
            'position': list(position),
            'rotation_xyzw_unverified': list(rotation),
            'scale': list(scale),
        })
    return transforms


def _extract_object_static_transforms(
        raw: bytes, container: dict, nodes: list[dict],
        scale_indices: list[int]) -> list[dict]:
    objects = [node for node in nodes if node['type'] == 'object']
    if not objects:
        return []
    if len(container['sections']) != 10:
        raise KdfError('Skl object transforms require the observed 10-section layout')

    count = len(objects)
    positions = _read_vectors(raw, container, _OBJECT_POSITION_SECTION, count, 3)
    rotations = _read_vectors(raw, container, _OBJECT_ROTATION_SECTION, count, 4)
    scales = _read_vectors(raw, container, _SCALE_SECTION, len(scale_indices), 3)
    position_order = _read_u16_indices(
        raw, container, _OBJECT_POSITION_INDEX_SECTION, count)
    rotation_order = _read_u16_indices(
        raw, container, _OBJECT_ROTATION_INDEX_SECTION, count)
    scale_order = _read_u16_indices(
        raw, container, _SCALE_INDEX_SECTION, len(scale_indices))
    if position_order != tuple(range(count)):
        raise KdfError('Skl object position index section is not ordered 0..object_count-1')
    if rotation_order != tuple(range(count)):
        raise KdfError('Skl object rotation index section is not ordered 0..object_count-1')
    if scale_order != tuple(range(len(scale_indices))):
        raise KdfError('Skl scale index section is not ordered 0..scale_count-1')

    transforms = []
    for node in objects:
        position_index = node['object_position_index']
        rotation_index = node['object_rotation_index']
        scale_index = node['scale_index']
        if position_index >= count or rotation_index >= count:
            raise KdfError(f'Skl object {node["nodeid"]} transform index is out of range')
        if scale_index >= len(scales):
            raise KdfError(f'Skl object {node["nodeid"]} scale index is out of range')
        position = positions[position_index]
        rotation = rotations[rotation_index]
        scale = scales[scale_index]
        if not all(math.isfinite(value) for value in position + rotation + scale):
            raise KdfError(f'Skl object {node["nodeid"]} transform is not finite')
        norm = math.sqrt(sum(value * value for value in rotation))
        if abs(norm - 1.0) > 1e-5:
            raise KdfError(f'Skl object {node["nodeid"]} rotation norm {norm} is not 1')
        transforms.append({
            'nodeid': node['nodeid'],
            'position_index': position_index,
            'rotation_index': rotation_index,
            'scale_index': scale_index,
            'position': list(position),
            'rotation_xyzw_unverified': list(rotation),
            'scale': list(scale),
        })
    return transforms


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
    if not type_starts:
        raise KdfError('no Skl node records found')
    records_end, object_sample_layout = _node_region_end(container, type_starts)
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
        node = {
            'nodeid': fields['nodeid'],
            'parentid': parent,
            'treesize': fields['treesize'],
            'offset': fields['offset'],
            'type_id': type_value,
            'type': type_name,
            'record_start': start,
            'record_end': end,
        }
        nodes.append(node)
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
    node_names = _resolve_node_names(container, type_starts)
    for node in nodes:
        node['name'] = node_names[node['record_start']]

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

    track_occurrences = {
        key: property_occurrences(container, key, value_markers={0})
        for key in ('scales', 'bonepos', 'bonerot')
    }
    for node in nodes:
        for output_key, source_key in (
                ('scale_index', 'scales'),
                ('bone_position_index', 'bonepos'),
                ('bone_rotation_index', 'bonerot')):
            value = _node_property(
                track_occurrences[source_key], node['record_start'], node['record_end'],
                source_key, node['nodeid'])
            if value is not None:
                node[output_key] = value
        if node['type'] == 'bone':
            missing = [
                key for key in ('scale_index', 'bone_position_index', 'bone_rotation_index')
                if key not in node
            ]
            if missing:
                raise KdfError(
                    f'Skl bone {node["nodeid"]} is missing {", ".join(missing)}'
                )

    objects = [node for node in nodes if node['type'] == 'object']
    if objects and object_sample_layout:
        object_occurrences = {
            key: property_occurrences(container, key)
            for key in ('positions', 'rotations', 'scales')
        }
        for node in objects:
            for output_key, source_key in (
                    ('object_position_index', 'positions'),
                    ('object_rotation_index', 'rotations'),
                    ('scale_index', 'scales')):
                node[output_key] = _object_scalar_property(
                    object_occurrences[source_key], node, source_key)

    bone_positions = [
        node['bone_position_index'] for node in nodes if node['type'] == 'bone'
    ]
    bone_rotations = [
        node['bone_rotation_index'] for node in nodes if node['type'] == 'bone'
    ]
    scale_indices = [
        node['scale_index'] for node in nodes if 'scale_index' in node
    ]
    object_positions = (
        [node['object_position_index'] for node in objects]
        if object_sample_layout or not objects else None
    )
    object_rotations = (
        [node['object_rotation_index'] for node in objects]
        if object_sample_layout or not objects else None
    )
    _validate_dense_indices(bone_positions, 'bonepos')
    _validate_dense_indices(bone_rotations, 'bonerot')
    _validate_dense_indices(scale_indices, 'scales')
    if object_positions is not None:
        _validate_object_indices(object_positions, 'position')
        _validate_object_indices(object_rotations, 'rotation')
    static_transforms = _extract_static_transforms(raw, container, nodes, scale_indices)
    object_static_transforms = (
        _extract_object_static_transforms(raw, container, nodes, scale_indices)
        if object_sample_layout or not objects else None
    )
    return {
        'sha256': container['sha256'],
        'decoded_bytes': container['decoded_bytes'],
        'node_count': len(nodes),
        'roots': roots,
        'nodes': nodes,
        'name_reference_count': len(node_names),
        'name_reference_source': 'validated-relative-pointer-table',
        'bone_position_indices': bone_positions,
        'bone_rotation_indices': bone_rotations,
        'object_position_indices': object_positions,
        'object_rotation_indices': object_rotations,
        'scale_indices': scale_indices,
        'static_transforms': static_transforms,
        'object_static_transforms': object_static_transforms,
        'transform_coordinate_space': 'unverified',
        'transform_quaternion_component_order': 'unverified',
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

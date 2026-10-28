#!/usr/bin/env python3
"""Inspect validated Mesh geometry, subsets, and skin data without exporting assets."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_data import KdfError, parse_container, scalar_property

_MAX_RESOURCE_BYTES = 16 * 1024 * 1024
_VERTEX_LAYOUTS = {
    0x42: {'stride': 20, 'skinned': False},
    0x342: {'stride': 40, 'skinned': True},
}
_VECTOR_MARKER = 0x20000000
_RANGE_MARKER = 0x00800002


def _string_ordinal(container: dict, value: str) -> int:
    matches = [entry['ordinal'] for entry in container['strings'] if entry['text'] == value]
    if len(matches) != 1:
        raise KdfError(f'expected one mesh string named {value!r}')
    return matches[0]


def _key_records(container: dict, value: str) -> list[int]:
    ordinal = _string_ordinal(container, value)
    return [
        record['ordinal'] for record in container['records']
        if record['first'] == 0x60000000 and record['second'] == ordinal
    ]


def _one_key_record(container: dict, value: str) -> int:
    records = _key_records(container, value)
    if len(records) != 1:
        raise KdfError(f'expected one mesh property named {value!r}')
    return records[0]


def _array_map(container: dict) -> dict[int, dict]:
    return {
        reference['record_ordinal']: reference
        for reference in container['array_references']
    }


def _array_after(container: dict, arrays: dict[int, dict],
                 record_ordinal: int, name: str) -> dict:
    reference = arrays.get(record_ordinal + 1)
    if reference is None:
        raise KdfError(f'mesh {name!r} has no array descriptor')
    return reference


def _section_data(raw: bytes, container: dict, section_index: int) -> bytes:
    if section_index >= len(container['sections']):
        raise KdfError(f'mesh section index {section_index} is out of range')
    section = container['sections'][section_index]
    start = container['payload_offset'] + section['start_relative']
    return raw[start:start + section['bytes']]


def _read_vectors(raw: bytes, container: dict, section_index: int, count: int,
                  width: int) -> list[tuple[float, ...]]:
    section = container['sections'][section_index]
    expected = count * width * 4
    if section['bytes'] != expected:
        raise KdfError(
            f'mesh vector section {section_index} has {section["bytes"]} bytes; '
            f'expected {expected}'
        )
    start = container['payload_offset'] + section['start_relative']
    return [
        struct.unpack_from(f'<{width}f', raw, start + index * width * 4)
        for index in range(count)
    ]


def _quaternion_matrix(value: tuple[float, ...]) -> tuple[tuple[float, ...], ...]:
    x, y, z, w = value
    return (
        (1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)),
        (2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)),
        (2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)),
    )


def _read_geometry(raw: bytes, container: dict) -> dict:
    arrays = _array_map(container)
    format_key = _one_key_record(container, 'format')
    format_value = container['records'][format_key + 1]
    if format_value['first'] != 0x60000000:
        raise KdfError('mesh format value is not a string reference')
    format_name = container['strings'][format_value['second']]['text']
    if format_name != 'float':
        raise KdfError(f'unsupported mesh scalar format {format_name!r}')
    index_key = _one_key_record(container, 'indices')
    vertex_key = _one_key_record(container, 'vertices')
    index_ref = _array_after(container, arrays, index_key, 'indices')
    vertex_ref = _array_after(container, arrays, vertex_key, 'vertices')
    if index_ref['element_stride'] != 2:
        raise KdfError('mesh indices are not uint16 elements')
    index_section = container['sections'][index_ref['section_index']]
    if index_section['bytes'] - index_ref['required_bytes'] not in range(4):
        raise KdfError('mesh index section has invalid padding')
    index_start = container['payload_offset'] + index_section['start_relative']
    indices = struct.unpack_from(
        f'<{index_ref["element_count"]}H', raw, index_start)

    vertex_format = scalar_property(container, 'vertexformat')
    layout = _VERTEX_LAYOUTS.get(vertex_format)
    if layout is None:
        raise KdfError(f'unsupported mesh vertexformat 0x{vertex_format:x}')
    if vertex_ref['element_stride'] != layout['stride']:
        raise KdfError(
            f'mesh vertexformat 0x{vertex_format:x} does not match stride '
            f'{vertex_ref["element_stride"]}'
        )
    vertex_section = container['sections'][vertex_ref['section_index']]
    if vertex_section['bytes'] != vertex_ref['required_bytes']:
        raise KdfError('mesh vertex section has unexpected padding')
    vertex_data = _section_data(raw, container, vertex_ref['section_index'])

    vertices = []
    weight_errors = []
    for ordinal in range(vertex_ref['element_count']):
        offset = ordinal * layout['stride']
        position = struct.unpack_from('<3f', vertex_data, offset)
        uv = struct.unpack_from('<2f', vertex_data, offset + 12)
        values = position + uv
        bone_indices = ()
        weights = ()
        if layout['skinned']:
            bone_indices = tuple(vertex_data[offset + 20:offset + 24])
            weights = struct.unpack_from('<4f', vertex_data, offset + 24)
            values += weights
            error = abs(sum(weights) - 1.0)
            weight_errors.append(error)
            if error > 1e-5:
                raise KdfError(f'mesh vertex {ordinal} skin weights do not sum to 1')
            if any(weight < 0 for weight in weights):
                raise KdfError(f'mesh vertex {ordinal} has a negative skin weight')
        if not all(math.isfinite(value) for value in values):
            raise KdfError(f'mesh vertex {ordinal} is not finite')
        vertices.append({
            'position': list(position),
            'uv': list(uv),
            'bone_indices_local': list(bone_indices),
            'weights': list(weights),
        })

    vertex_count = len(vertices)
    if not indices or len(indices) % 3:
        raise KdfError('mesh index count is not a positive triangle multiple')
    if max(indices) >= vertex_count:
        raise KdfError('mesh index exceeds vertex count')
    degenerate_triangles = sum(
        len(set(indices[start:start + 3])) < 3
        for start in range(0, len(indices), 3)
    )
    positions = [vertex['position'] for vertex in vertices]
    position_min = [min(value[axis] for value in positions) for axis in range(3)]
    position_max = [max(value[axis] for value in positions) for axis in range(3)]
    return {
        'vertices': vertices,
        'indices': list(indices),
        'vertex_format': vertex_format,
        'vertex_stride': layout['stride'],
        'skinned': layout['skinned'],
        'index_count': len(indices),
        'vertex_count': vertex_count,
        'triangle_count': len(indices) // 3,
        'degenerate_triangles': degenerate_triangles,
        'position_min': position_min,
        'position_max': position_max,
        'weight_sum_max_error': max(weight_errors) if weight_errors else None,
    }


def _parse_subsets(raw: bytes, container: dict) -> list[dict]:
    records = container['records']
    strings = container['strings']
    arrays = _array_map(container)
    range_ordinal = _string_ordinal(container, 'rangeidx')
    vtx_range_ordinal = _string_ordinal(container, 'rangevtx')
    material_ordinal = _string_ordinal(container, 'mtlid')
    skl_ordinal = next(
        (entry['ordinal'] for entry in strings if entry['text'] == 'skl'), None)
    subsets = []
    for record in records[:-5]:
        ordinal = record['ordinal']
        if record['first'] != 0x60000000 or record['second'] != range_ordinal:
            continue
        index_value = records[ordinal + 1]
        vtx_key = records[ordinal + 2]
        vtx_value = records[ordinal + 3]
        material_key = records[ordinal + 4]
        material_value = records[ordinal + 5]
        if (index_value['first'] != _RANGE_MARKER
                or vtx_key['first'] != 0x60000000
                or vtx_key['second'] != vtx_range_ordinal
                or vtx_value['first'] != _RANGE_MARKER
                or material_key['first'] != 0x60000000
                or material_key['second'] != material_ordinal
                or material_value['first'] != 0x60000000):
            raise KdfError(f'malformed mesh subset at record {ordinal}')
        index_section = _section_data(raw, container, index_value['second'])
        vtx_section = _section_data(raw, container, vtx_value['second'])
        if len(index_section) != 8 or len(vtx_section) != 8:
            raise KdfError(f'mesh subset ranges at record {ordinal} are not uint32[2]')
        index_range = struct.unpack('<2I', index_section)
        vertex_range = struct.unpack('<2I', vtx_section)
        material_ordinal_value = material_value['second']
        if material_ordinal_value >= len(strings):
            raise KdfError(f'mesh subset material at record {ordinal} is invalid')
        local_map = None
        if (ordinal + 6 < len(records)
                and skl_ordinal is not None
                and records[ordinal + 6]['first'] == 0x60000000
                and records[ordinal + 6]['second'] == skl_ordinal):
            reference = arrays.get(ordinal + 7)
            if reference and reference['element_stride'] == 1:
                local_map = list(_section_data(
                    raw, container, reference['section_index']
                )[:reference['element_count']])
        subsets.append({
            'record_start': ordinal,
            'index_range': list(index_range),
            'vertex_range': list(vertex_range),
            'triangle_count': (index_range[1] - index_range[0]) // 3,
            'material': strings[material_ordinal_value]['text'],
            'local_to_global_bone_indices': local_map,
        })
    if not subsets:
        raise KdfError('mesh has no subsets')
    subset_key = _one_key_record(container, 'subsets')
    declared_count = container['records'][subset_key + 1]['first'] & 0xffff
    if declared_count != len(subsets):
        raise KdfError(
            f'mesh declares {declared_count} subsets but contains {len(subsets)}')
    if subsets[0]['index_range'][0] != 0 or subsets[0]['vertex_range'][0] != 0:
        raise KdfError('mesh subset ranges do not start at zero')
    for left, right in zip(subsets, subsets[1:], strict=False):
        if left['index_range'][1] != right['index_range'][0]:
            raise KdfError('mesh index ranges are not contiguous')
        if left['vertex_range'][1] != right['vertex_range'][0]:
            raise KdfError('mesh vertex ranges are not contiguous')
    for subset in subsets:
        if (subset['index_range'][1] - subset['index_range'][0]) % 3:
            raise KdfError('mesh subset index range is not a triangle multiple')
    return subsets


def _parse_skeleton(raw: bytes, container: dict) -> dict | None:
    records = container['records']
    strings = container['strings']
    by_text = {entry['text']: entry['ordinal'] for entry in strings}
    if 'skl' not in by_text or 'names' not in by_text:
        return None
    arrays = _array_map(container)
    target = None
    for record in records[:-1]:
        ordinal = record['ordinal']
        value = records[ordinal + 1]
        if (record['first'] == 0x60000000
                and record['second'] == by_text['skl']
                and value['first'] == 0x30000005):
            candidate = ordinal + 1 + value['second']
            if (candidate < len(records)
                    and records[candidate]['first'] == 0x60000000
                    and records[candidate]['second'] == by_text['names']):
                target = candidate
                break
    if target is None or target + 9 >= len(records):
        return None
    name_reference = records[target + 1]
    if name_reference['first'] >> 28 != 4:
        raise KdfError('mesh skeleton names descriptor is invalid')
    bone_count = name_reference['first'] & 0xffff
    if not bone_count:
        raise KdfError('mesh skeleton has no bones')
    if target + 10 + bone_count > len(records):
        raise KdfError('mesh skeleton name records are truncated')
    position_key = records[target + 2]
    rotation_key = records[target + 4]
    transform_key = records[target + 6]
    bounds_key = records[target + 8]
    if (position_key['second'] != by_text['positions']
            or rotation_key['second'] != by_text['rotations']
            or transform_key['second'] != by_text['transforms']
            or bounds_key['second'] != by_text['bv']):
        raise KdfError('mesh skeleton property order is invalid')
    position_ref = arrays.get(target + 3)
    rotation_ref = arrays.get(target + 5)
    transform_ref = arrays.get(target + 7)
    if not position_ref or not rotation_ref or not transform_ref:
        raise KdfError('mesh skeleton transform descriptor is missing')
    for reference, width in (
            (position_ref, 12), (rotation_ref, 16), (transform_ref, 48)):
        if reference['element_count'] != bone_count or reference['element_stride'] != width:
            raise KdfError('mesh skeleton transform dimensions are inconsistent')
    positions = _read_vectors(
        raw, container, position_ref['section_index'], bone_count, 3)
    rotations = _read_vectors(
        raw, container, rotation_ref['section_index'], bone_count, 4)
    matrices = _read_vectors(
        raw, container, transform_ref['section_index'], bone_count, 12)
    names = []
    for index in range(bone_count):
        record = records[target + 10 + index]
        if record['first'] != 0x60000000 or record['second'] >= len(strings):
            raise KdfError(f'mesh skeleton name {index} is invalid')
        names.append(strings[record['second']]['text'])
    if len(set(names)) != len(names):
        raise KdfError('mesh skeleton bone names are not unique')
    max_norm_error = 0.0
    max_matrix_error = 0.0
    max_bind_position_residual = 0.0
    translations = []
    for index, rotation in enumerate(rotations):
        norm = math.sqrt(sum(value * value for value in rotation))
        max_norm_error = max(max_norm_error, abs(norm - 1.0))
        if max_norm_error > 1e-5:
            raise KdfError(f'mesh skeleton rotation {index} is not normalized')
        matrix = matrices[index]
        expected = _quaternion_matrix(rotation)
        stored_columns = (
            tuple(matrix[0:3]),
            tuple(matrix[4:7]),
            tuple(matrix[8:11]),
        )
        expected_columns = (
            tuple(expected[row][0] for row in range(3)),
            tuple(expected[row][1] for row in range(3)),
            tuple(expected[row][2] for row in range(3)),
        )
        error = max(
            abs(actual - wanted)
            for actual_column, wanted_column in zip(
                stored_columns, expected_columns, strict=True)
            for actual, wanted in zip(
                actual_column, wanted_column, strict=True)
        )
        max_matrix_error = max(max_matrix_error, error)
        if max_matrix_error > 1e-5:
            raise KdfError(
                f'mesh skeleton matrix {index} does not match its quaternion')
        translation = [matrix[3], matrix[7], matrix[11]]
        position = positions[index]
        residual = [
            sum(stored_columns[column][row] * position[row] for row in range(3))
            + translation[column]
            for column in range(3)
        ]
        error = max(abs(value) for value in residual)
        max_bind_position_residual = max(max_bind_position_residual, error)
        if error > 2e-5:
            raise KdfError(
                f'mesh skeleton inverse bind matrix {index} misses its position')
        translations.append(translation)
    return {
        'record_start': target,
        'bone_count': bone_count,
        'names': names,
        'positions': [list(value) for value in positions],
        'rotations_xyzw': [list(value) for value in rotations],
        'bind_translations': translations,
        'rotation_norm_max_error': max_norm_error,
        'quaternion_component_order': 'xyzw-verified-relative-to-matrix',
        'matrix_layout': 'transposed-rotation-rows-with-translation-tail',
        'rotation_matrix_max_error': max_matrix_error,
        'bind_position_residual_max': max_bind_position_residual,
        'matrix_transform_semantics': 'inverse-bind-candidate',
    }


def _validate_skinning(geometry: dict, subsets: list[dict],
                       skeleton: dict | None) -> None:
    if not geometry['skinned']:
        return
    if skeleton is None:
        raise KdfError('skinned mesh has no skeleton')
    bone_count = skeleton['bone_count']
    for subset in subsets:
        local_map = subset['local_to_global_bone_indices']
        if local_map is not None:
            if any(index >= bone_count for index in local_map):
                raise KdfError('mesh subset bone map exceeds skeleton bone count')
            if len(set(local_map)) != len(local_map):
                raise KdfError('mesh subset bone map contains duplicates')
    for ordinal, vertex in enumerate(geometry['vertices']):
        subset = next(
            (item for item in subsets
             if item['vertex_range'][0] <= ordinal < item['vertex_range'][1]),
            None,
        )
        if subset is None:
            raise KdfError(f'mesh vertex {ordinal} is outside every subset')
        local_map = subset['local_to_global_bone_indices']
        allowed = len(local_map) if local_map is not None else bone_count
        if any(index >= allowed for index in vertex['bone_indices_local']):
            raise KdfError(f'mesh vertex {ordinal} bone index exceeds subset map')
        if local_map is not None:
            vertex['bone_indices_global'] = [
                local_map[index] for index in vertex['bone_indices_local']
            ]
        else:
            vertex['bone_indices_global'] = list(vertex['bone_indices_local'])


def inspect_mesh(raw: bytes, *, include_vertices: bool = False,
                 include_indices: bool = False) -> dict:
    container = parse_container(raw)
    geometry = _read_geometry(raw, container)
    subsets = _parse_subsets(raw, container)
    skeleton = _parse_skeleton(raw, container)
    _validate_skinning(geometry, subsets, skeleton)
    if (subsets[-1]['index_range'][1] != geometry['index_count']
            or subsets[-1]['vertex_range'][1] != geometry['vertex_count']):
        raise KdfError('mesh subset ranges do not cover all geometry')
    for subset in subsets:
        index_start, index_end = subset['index_range']
        vertex_start, vertex_end = subset['vertex_range']
        if any(index < vertex_start or index >= vertex_end
               for index in geometry['indices'][index_start:index_end]):
            raise KdfError('mesh subset triangle references vertices outside its range')
    vertices = geometry['vertices']
    result = {
        'sha256': hashlib.sha256(raw).hexdigest(),
        'decoded_bytes': len(raw),
        'data_offset': container['data_offset'],
        'record_count': container['record_count'],
        'section_count': container['offset_count'],
        'payload_bytes': container['payload_bytes'],
        'vertex_format': geometry['vertex_format'],
        'vertex_stride': geometry['vertex_stride'],
        'index_count': geometry['index_count'],
        'index_max': max(geometry['indices']),
        'vertex_count': geometry['vertex_count'],
        'triangle_count': geometry['triangle_count'],
        'degenerate_triangles': geometry['degenerate_triangles'],
        'position_min': geometry['position_min'],
        'position_max': geometry['position_max'],
        'weight_sum_max_error': geometry['weight_sum_max_error'],
        'subset_count': len(subsets),
        'subsets': subsets,
        'skeleton': skeleton,
        'geometry_axes': 'x-horizontal-y-depth-z-up-observed',
        'godot_axis_mapping': 'unverified',
        'matrix_transform_semantics': 'inverse-bind-candidate',
        'tail_identity_hex': container['tail_identity_hex'],
    }
    if include_vertices:
        result['vertices'] = vertices
    else:
        result['vertex_preview'] = vertices[:3]
    if include_indices:
        result['indices'] = geometry['indices']
    return result


def inspect_file(path: Path, *, include_vertices: bool = False,
                 include_indices: bool = False) -> dict:
    with path.open('rb') as file:
        raw = file.read(_MAX_RESOURCE_BYTES + 1)
    if len(raw) > _MAX_RESOURCE_BYTES:
        raise KdfError('decoded mesh exceeds inspection size limit')
    result = inspect_mesh(
        raw, include_vertices=include_vertices, include_indices=include_indices)
    result['source'] = str(path)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='decoded Mesh CTX3 resource')
    parser.add_argument('--vertices', action='store_true', help='include every decoded vertex')
    parser.add_argument('--indices', action='store_true', help='include the uint16 index array')
    args = parser.parse_args()
    try:
        result = inspect_file(
            args.source, include_vertices=args.vertices,
            include_indices=args.indices)
    except (OSError, KdfError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

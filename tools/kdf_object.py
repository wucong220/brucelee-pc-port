#!/usr/bin/env python3
"""Inspect validated object metadata and external references without exporting assets."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_data import KdfError, parse_container

_MAX_RESOURCE_BYTES = 16 * 1024 * 1024
_EXTERNAL_REFERENCE_MARKER = 0x70000000


def _string_ordinal(container: dict, value: str) -> int:
    matches = [entry['ordinal'] for entry in container['strings'] if entry['text'] == value]
    if len(matches) != 1:
        raise KdfError(f'expected one object string named {value!r}')
    return matches[0]


def _inspect_external_references(raw: bytes, container: dict) -> dict:
    count = container['header_words'][1]
    gap = raw[container['string_table_end']:container['data_offset']]
    if len(gap) != count * 3:
        raise KdfError(
            f'object external reference table has {len(gap)} bytes; expected {count * 3}'
        )
    strings = container['strings']
    references = []
    for ordinal in range(count):
        path_index, basename_index, extension_index = gap[
            ordinal * 3:(ordinal + 1) * 3]
        if any(index >= len(strings) for index in (
                path_index, basename_index, extension_index)):
            raise KdfError(f'object external reference {ordinal} has invalid string index')
        path = strings[path_index]['text']
        basename = strings[basename_index]['text']
        extension = strings[extension_index]['text']
        references.append({
            'ordinal': ordinal,
            'path_index': path_index,
            'basename_index': basename_index,
            'extension_index': extension_index,
            'path': f'{path}{basename}.{extension}',
        })

    uses = []
    for record_ordinal, record in enumerate(container['records']):
        if record['first'] != _EXTERNAL_REFERENCE_MARKER:
            continue
        if record['second'] >= count:
            raise KdfError(
                f'object external reference use {record_ordinal} is out of range')
        property_name = None
        if (record_ordinal > 0
                and container['records'][record_ordinal - 1]['first'] == 0x60000000):
            key_ordinal = container['records'][record_ordinal - 1]['second']
            if key_ordinal < len(strings):
                property_name = strings[key_ordinal]['text']
        uses.append({
            'record_ordinal': record_ordinal,
            'property': property_name,
            'reference_id': record['second'],
        })
    used_ids = {entry['reference_id'] for entry in uses}
    if used_ids != set(range(count)):
        raise KdfError('object external reference IDs are not densely used')
    return {'references': references, 'uses': uses}


def _array_by_record(container: dict) -> dict[int, dict]:
    result = {}
    for reference in container['array_references']:
        ordinal = reference['record_ordinal']
        if ordinal in result:
            raise KdfError(f'duplicate object array descriptor at record {ordinal}')
        result[ordinal] = reference
    return result


def _descriptor(reference: dict | None, record_ordinal: int,
                count: int, stride: int) -> dict:
    if reference is None:
        raise KdfError(f'object transform descriptor missing at record {record_ordinal}')
    if (reference['element_count'], reference['element_stride']) != (count, stride):
        raise KdfError(
            f'object transform descriptor {record_ordinal} is not '
            f'{count}x{stride} bytes'
        )
    return reference


def _read_vector(raw: bytes, container: dict, reference: dict,
                 width: int) -> tuple[float, ...]:
    section_index = reference['section_index']
    section = container['sections'][section_index]
    expected = width * 4
    if section['bytes'] != expected:
        raise KdfError(
            f'object vector section {section_index} has {section["bytes"]} bytes; '
            f'expected {expected}'
        )
    start = container['payload_offset'] + section['start_relative']
    return struct.unpack_from(f'<{width}f', raw, start)


def _inspect_pose_transforms(raw: bytes, container: dict) -> list[dict]:
    ordinals = {
        value: _string_ordinal(container, value)
        for value in ('position', 'rotation', 'scale')
    }
    arrays = _array_by_record(container)
    records = container['records']
    transforms = []
    used_sections = set()
    record_ordinal = 0
    while record_ordinal + 5 < len(records):
        if records[record_ordinal] != {
                'ordinal': record_ordinal,
                'first': 0x60000000,
                'second': ordinals['position'],
        }:
            record_ordinal += 1
            continue
        position_ref = _descriptor(
            arrays.get(record_ordinal + 1), record_ordinal + 1, 1, 12)
        if records[record_ordinal + 2]['first'] != 0x60000000 or records[
                record_ordinal + 2]['second'] != ordinals['rotation']:
            raise KdfError(f'malformed object rotation key at record {record_ordinal + 2}')
        rotation_ref = _descriptor(
            arrays.get(record_ordinal + 3), record_ordinal + 3, 1, 16)
        if records[record_ordinal + 4]['first'] != 0x60000000 or records[
                record_ordinal + 4]['second'] != ordinals['scale']:
            raise KdfError(f'malformed object scale key at record {record_ordinal + 4}')
        scale_ref = _descriptor(
            arrays.get(record_ordinal + 5), record_ordinal + 5, 1, 12)
        position = _read_vector(raw, container, position_ref, 3)
        rotation = _read_vector(raw, container, rotation_ref, 4)
        scale = _read_vector(raw, container, scale_ref, 3)
        if not all(math.isfinite(value) for value in position + rotation + scale):
            raise KdfError(f'object transform at record {record_ordinal} is not finite')
        norm = math.sqrt(sum(value * value for value in rotation))
        if abs(norm - 1.0) > 1e-5:
            raise KdfError(
                f'object transform at record {record_ordinal} rotation norm {norm} is not 1')
        transforms.append({
            'record_start': record_ordinal,
            'position_section': position_ref['section_index'],
            'rotation_section': rotation_ref['section_index'],
            'scale_section': scale_ref['section_index'],
            'position': list(position),
            'rotation_xyzw_unverified': list(rotation),
            'scale': list(scale),
        })
        used_sections.update((
            position_ref['section_index'],
            rotation_ref['section_index'],
            scale_ref['section_index'],
        ))
        record_ordinal += 6
    if not transforms:
        raise KdfError('no object pose transforms found')
    if used_sections != set(range(container['offset_count'])):
        raise KdfError('object pose sections do not consume every DATA section')
    return transforms


def _dictionary_fields(records: list[dict], strings: list[dict], index: int) -> dict[str, int]:
    """Read one observed `0x30000000` dictionary of key/value record pairs."""
    first, relative = records[index]["first"], records[index]["second"]
    if first & 0xffff0000 != 0x30000000:
        raise KdfError(f"object record {index} is not a relative dictionary")
    count = first & 0xffff
    if count == 0:
        return {}
    start = index + relative
    if start <= index or start + count * 2 > len(records):
        raise KdfError(f"object dictionary {index} has an invalid child range")
    fields = {}
    for item in range(count):
        key_index = start + item * 2
        key = records[key_index]
        if key["first"] != 0x60000000 or key["second"] >= len(strings):
            raise KdfError(f"object dictionary key {key_index} is invalid")
        name = strings[key["second"]]["text"]
        if name in fields:
            raise KdfError(f"object dictionary {index} repeats {name!r}")
        fields[name] = key_index + 1
    return fields


def _string_value(records: list[dict], strings: list[dict], index: int) -> str:
    record = records[index]
    if record["first"] != 0x60000000 or record["second"] >= len(strings):
        raise KdfError(f"object record {index} is not a string value")
    return strings[record["second"]]["text"]


def _section_value(records: list[dict], index: int) -> int:
    record = records[index]
    if record["first"] >> 28 != 4:
        raise KdfError(f"object record {index} is not an array descriptor")
    return record["second"]


def _parse_scene_tree(records: list[dict], strings: list[dict], transforms: list[dict]) -> dict:
    """Parse the observed relative scene dictionary, or leave it unresolved.

    The native parent-pointer representation and runtime draw-call order are
    not inferred from this resource encoding.
    """
    if not records or records[0]["first"] & 0xffff0000 != 0x30000000:
        return {"scene_tree_status": "unresolved", "scene_node_count": 0, "scene_nodes": []}
    root = _dictionary_fields(records, strings, 0)
    if set(root) != {"scene"}:
        raise KdfError("object relative dictionary root is not the scene")
    nodes = []
    seen = set()

    def walk(dict_index: int, name: str, parent: str | None, depth: int) -> None:
        if name in seen:
            raise KdfError(f"object scene node {name!r} is duplicated")
        seen.add(name)
        fields = _dictionary_fields(records, strings, dict_index)
        if "type" not in fields or "properties" not in fields:
            raise KdfError(f"object scene node {name!r} lacks type or properties")
        properties = _dictionary_fields(records, strings, fields["properties"])
        for key in ("position", "rotation", "scale"):
            if key not in properties:
                raise KdfError(f"object scene node {name!r} lacks {key}")
        children = []
        child_fields = {}
        if "childs" in fields:
            child_fields = _dictionary_fields(records, strings, fields["childs"])
            children = list(child_fields)
        visuals = []
        if "visuals" in fields:
            visuals = list(_dictionary_fields(records, strings, fields["visuals"]))
        nodes.append({
            "name": name,
            "type": _string_value(records, strings, fields["type"]),
            "parent": parent,
            "depth": depth,
            "children": children,
            "visuals": visuals,
            "position_section": _section_value(records, properties["position"]),
            "rotation_section": _section_value(records, properties["rotation"]),
            "scale_section": _section_value(records, properties["scale"]),
        })
        for child_name in children:
            walk(child_fields[child_name], child_name, name, depth + 1)

    walk(root["scene"], "scene", None, 0)
    linked = [
        (node["position_section"], node["rotation_section"], node["scale_section"])
        for node in nodes
    ]
    if len(set(linked)) != len(linked):
        raise KdfError("object scene nodes repeat a pose transform")
    pose = {
        (item["position_section"], item["rotation_section"], item["scale_section"])
        for item in transforms
    }
    if set(linked) != pose:
        raise KdfError("object scene nodes do not match pose transform sections")
    return {
        "scene_tree_status": "relative-dictionary",
        "scene_node_count": len(nodes),
        "scene_nodes": nodes,
    }


def inspect_object(raw: bytes) -> dict:
    container = parse_container(raw)
    external = _inspect_external_references(raw, container)
    transforms = _inspect_pose_transforms(raw, container)
    scene = _parse_scene_tree(container["records"], container["strings"], transforms)
    return {
        'sha256': hashlib.sha256(raw).hexdigest(),
        'decoded_bytes': len(raw),
        'data_offset': container['data_offset'],
        'record_count': container['record_count'],
        'section_count': container['offset_count'],
        'payload_bytes': container['payload_bytes'],
        'external_reference_count': len(external['references']),
        'external_references': external['references'],
        'external_reference_uses': external['uses'],
        'pose_transform_count': len(transforms),
        'pose_transforms': transforms,
        **scene,
        'mesh_payload_status': 'external-resource',
        'transform_coordinate_space': 'unverified',
        'transform_quaternion_component_order': 'unverified',
        'tail_identity_hex': container['tail_identity_hex'],
    }


def inspect_file(path: Path) -> dict:
    with path.open('rb') as file:
        raw = file.read(_MAX_RESOURCE_BYTES + 1)
    if len(raw) > _MAX_RESOURCE_BYTES:
        raise KdfError('decoded object resource exceeds inspection size limit')
    result = inspect_object(raw)
    result['source'] = str(path)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='decoded object CTX3 resource')
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

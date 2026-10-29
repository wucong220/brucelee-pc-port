#!/usr/bin/env python3
"""Bind observed ANM tracks to Skl nodes without composing transforms."""
from __future__ import annotations

import hashlib
import math
from typing import Any

from kdf_animation import inspect_animation
from kdf_data import KdfError, parse_container, parse_context, property_occurrences
from kdf_skeleton import inspect_skeleton


_TRACKS = {
    'bonepos': ('bone_position_index', 'translation', 'bone', 3,
                'skl-bone-position-index-verified'),
    'bonerot': ('bone_rotation_index', 'rotation', 'bone', 4,
                'skl-bone-rotation-index-verified'),
    'scales': ('scale_index', 'scale', None, 3, 'skl-scale-index-verified'),
    'positions': ('object_position_index', 'translation', 'object', 3,
                  'unverified'),
    'rotations': ('object_rotation_index', 'rotation', 'object', 4,
                  'skl-object-rotation-index-verified'),
}
_SECTIONS = {'anmdata', 'anmstatic'}


def _header_reference(context: dict, container: dict) -> dict:
    ordinals = [
        item['ordinal'] for item in container['strings']
        if item['text'] == 'anmheader'
    ]
    if len(ordinals) != 1:
        raise KdfError('animation must have exactly one anmheader string')
    records = container['records']
    keys = [
        index for index, record in enumerate(records)
        if record['first'] == 0x60000000 and record['second'] == ordinals[0]
    ]
    if len(keys) != 1 or keys[0] + 1 >= len(records):
        raise KdfError('animation must have exactly one complete anmheader property')
    key = keys[0]
    value = records[key + 1]
    if value['first'] != 0x70000000:
        raise KdfError('animation anmheader is not a file-reference marker')
    reference_id = value['second']
    references = context['file_references']
    if reference_id >= len(references):
        raise KdfError('animation anmheader file-reference index is out of range')
    reference = references[reference_id]
    directory = reference['directory']['text']
    basename = reference['basename']['text']
    extension = reference['extension']['text']
    if not basename or extension != 'skl':
        raise KdfError('animation anmheader does not reference an skl resource')
    text = directory + basename + '.' + extension
    records_start = (
        container['data_offset'] + 20 + 4 * (container['offset_count'] + 1)
    )
    return {
        'reference': text,
        'reference_id': reference_id,
        'marker': '0x70000000',
        'key_record': key,
        'value_record': key + 1,
        'key_record_offset': records_start + key * 8,
        'value_record_offset': records_start + (key + 1) * 8,
        'reference_record_offset': reference['record_offset'],
        'directory': dict(reference['directory']),
        'basename': dict(reference['basename']),
        'extension': dict(reference['extension']),
    }


def _header_values(animation: dict) -> dict:
    headers = animation.get('headers')
    if not isinstance(headers, dict):
        raise KdfError('animation headers are missing')
    for name in ('version', 'pose', 'firstframe', 'duration', 'framerate'):
        if type(headers.get(name)) is not int:
            raise KdfError(f'animation {name} is not an integer')
    if headers['version'] != 7 or headers['pose'] != 1 or headers['firstframe'] != 0:
        raise KdfError('animation header is outside the observed version/pose/frame profile')
    if headers['duration'] <= 0 or headers['framerate'] <= 0:
        raise KdfError('animation duration and framerate must be positive')
    return dict(headers)


def _domains(skeleton: dict) -> dict[str, dict[int, dict]]:
    nodes = skeleton.get('nodes')
    if not isinstance(nodes, list) or not nodes:
        raise KdfError('Skl nodes are missing')
    ids = set()
    maps: dict[str, dict[int, dict]] = {
        'bone_position_index': {},
        'bone_rotation_index': {},
        'scale_index': {},
        'object_position_index': {},
        'object_rotation_index': {},
    }
    for node in nodes:
        if not isinstance(node, dict):
            raise KdfError('Skl node is malformed')
        nodeid = node.get('nodeid')
        kind = node.get('type')
        if type(nodeid) is not int or nodeid < 0 or nodeid in ids:
            raise KdfError('Skl node IDs must be unique nonnegative integers')
        if kind not in ('root', 'object', 'bone'):
            raise KdfError('Skl node type is unsupported')
        ids.add(nodeid)
        required = {
            'root': (),
            'object': ('object_position_index', 'scale_index'),
            'bone': ('bone_position_index', 'bone_rotation_index', 'scale_index'),
        }[kind]
        if any(field not in node for field in required):
            raise KdfError(f'Skl {kind} node {nodeid} is missing an index')
        for field, domain in maps.items():
            if field not in node:
                continue
            allowed = (
                ('bone',) if field.startswith('bone_')
                else ('object',) if field in (
                    'object_position_index', 'object_rotation_index')
                else ('bone', 'object')
            )
            value = node[field]
            if kind not in allowed or type(value) is not int or value < 0:
                raise KdfError(f'Skl {field} has an invalid node type or index')
            if value in domain:
                raise KdfError(f'Skl {field} indices contain duplicates')
            domain[value] = node
    for field, domain in maps.items():
        if sorted(domain) != list(range(len(domain))):
            raise KdfError(f'Skl {field} indices are out of range or not dense')
    return maps


def _check_group_section(container: dict, group: dict, seen: set[str]) -> str:
    source = group.get('source_section')
    start = group.get('record_start')
    if source not in _SECTIONS or type(start) is not int or start < 0:
        raise KdfError('animation track group is missing verified source section metadata')
    if source in seen:
        raise KdfError('animation source section is bound to multiple track groups')
    matches = property_occurrences(container, source)
    if (len(matches) != 1 or matches[0]['value_marker'] >> 28 != 3
            or matches[0]['value_record'] + matches[0]['value'] != start):
        raise KdfError(f'animation {source} does not uniquely target its track group')
    seen.add(source)
    return source


def _vector(value: Any, width: int, label: str) -> list[float]:
    if not isinstance(value, (list, tuple)) or len(value) != width:
        raise KdfError(f'animation {label} has an invalid component count')
    if any(type(component) not in (int, float) or not math.isfinite(component)
           for component in value):
        raise KdfError(f'animation {label} contains a non-finite or non-numeric value')
    return list(value)


def _track_values(
        sample: dict, source: str, offsets: list[int], duration: int,
        width: int, name: str) -> tuple[str, str, list[list[list[float]]]]:
    codec = sample.get('codec')
    data = sample.get('data')
    if not isinstance(data, dict) or type(data.get('element_count')) is not int:
        raise KdfError(f'animation {name} sample data descriptor is missing')
    if codec == 'rawfixedsample':
        if sample.get('decode_status') != 'decoded-fixed-point':
            raise KdfError(f'animation {name} raw-fixed sample is not decoded')
        decoded = data.get('decoded')
        values = decoded.get('values') if isinstance(decoded, dict) else None
        if not isinstance(values, list) or len(values) != data['element_count']:
            raise KdfError(f'animation {name} raw-fixed value count is invalid')
        if source == 'anmdata':
            if len(offsets) == 1 and len(values) == duration:
                return 'per-frame', 'frame-major-single-offset', [
                    [_vector(value, width, name)] for value in values
                ]
            if len(offsets) > 1 and len(values) == len(offsets) * duration:
                frames = []
                for frame_ordinal in range(duration):
                    frame_start = frame_ordinal * len(offsets)
                    frames.append([
                        _vector(values[frame_start + offset_ordinal], width, name)
                        for offset_ordinal in range(len(offsets))
                    ])
                return 'per-frame', 'frame-major-candidate', frames
            if len(offsets) != 1 or len(values) != duration:
                raise KdfError(f'animation {name} raw-fixed anmdata layout is unsupported')
        if len(values) != len(offsets):
            raise KdfError(f'animation {name} raw-fixed anmstatic layout is unsupported')
        return (
            'constant',
            'constant-offset',
            [[_vector(value, width, name) for value in values]],
        )
    if codec == 'waveletsample':
        if source != 'anmdata' or sample.get('decode_status') != 'decoded-wavelet-candidate':
            raise KdfError(f'animation {name} wavelet source or decode status is unsupported')
        wavelet = sample.get('wavelet')
        decoded = wavelet.get('decoded') if isinstance(wavelet, dict) else None
        if not isinstance(decoded, dict):
            raise KdfError(f'animation {name} wavelet values are missing')
        values = decoded.get('values')
        if (decoded.get('sample_count') != duration
                or decoded.get('components_per_track') != width
                or decoded.get('channel_count') != len(offsets) * width
                or not isinstance(values, list) or len(values) != duration):
            raise KdfError(f'animation {name} wavelet dimensions are invalid')
        frames = []
        for frame in values:
            if not isinstance(frame, list) or len(frame) != len(offsets):
                raise KdfError(f'animation {name} wavelet frame dimensions are invalid')
            frames.append([_vector(value, width, name) for value in frame])
        return 'per-frame', 'frame-major', frames
    raise KdfError(f'animation {name} codec is unsupported')


def bind_animation(
        animation_raw: bytes, skeleton_raw: bytes, *,
        expected_reference: str | None = None,
        expected_skeleton_sha256: str | None = None) -> dict:
    """Return candidate node tracks; no rest-pose composition is performed."""
    if (expected_reference is None) != (expected_skeleton_sha256 is None):
        raise KdfError('expected reference and skeleton SHA-256 must be provided together')
    context = parse_context(animation_raw)
    container = parse_container(animation_raw, data_offset=context['data_offset'])
    reference = _header_reference(context, container)
    skeleton_hash = hashlib.sha256(skeleton_raw).hexdigest()
    pairing_status = 'unverified'
    if expected_reference is not None:
        if (expected_reference != reference['reference']
                or expected_skeleton_sha256 != skeleton_hash):
            raise KdfError('animation reference or skeleton SHA-256 does not match expectation')
        pairing_status = 'matched-provided-reference-and-hash'

    skeleton = inspect_skeleton(skeleton_raw)
    if skeleton.get('sha256') != skeleton_hash:
        raise KdfError('Skl inspector SHA-256 does not match its input')
    objects = [node for node in skeleton['nodes'] if node['type'] == 'object']
    object_transforms = skeleton.get('object_static_transforms')
    if (objects and (not isinstance(object_transforms, list)
                     or len(object_transforms) != len(objects)
                     or {value['nodeid'] for value in object_transforms}
                     != {node['nodeid'] for node in objects})):
        raise KdfError('Skl object transforms are missing or incomplete')
    animation = inspect_animation(
        animation_raw, include_values=True, decode_wavelet_values=True,
        data_offset=context['data_offset'])
    animation_hash = hashlib.sha256(animation_raw).hexdigest()
    if (animation.get('sha256') != animation_hash
            or animation.get('data_offset') != context['data_offset']):
        raise KdfError('animation inspector identity or DATA offset does not match its input')
    headers = _header_values(animation)
    domains = _domains(skeleton)
    groups = animation.get('track_groups')
    if not isinstance(groups, list) or not groups:
        raise KdfError('animation track groups are missing')

    bindings = []
    targets = set()
    seen_sections: set[str] = set()
    group_ordinals = set()
    for group in groups:
        if not isinstance(group, dict):
            raise KdfError('animation track group is malformed')
        source = _check_group_section(container, group, seen_sections)
        group_ordinal = group.get('ordinal')
        tracks = group.get('tracks')
        if (type(group_ordinal) is not int or group_ordinal < 0
                or group_ordinal in group_ordinals
                or not isinstance(tracks, list) or not tracks):
            raise KdfError('animation track group ordinal or tracks are invalid')
        group_ordinals.add(group_ordinal)
        for track in tracks:
            if not isinstance(track, dict) or track.get('name') not in _TRACKS:
                raise KdfError('animation track name is unsupported')
            name = track['name']
            field, target, required_type, width, semantics = _TRACKS[name]
            sample = track.get('sample')
            if not isinstance(sample, dict):
                raise KdfError(f'animation {name} sample is missing')
            offset_info = sample.get('offsets')
            if not isinstance(offset_info, dict):
                raise KdfError(f'animation {name} offset descriptor is missing')
            offsets = offset_info.get('values')
            if (not isinstance(offsets, list) or not offsets
                    or offset_info.get('element_count') != len(offsets)
                    or offset_info.get('element_stride') != 2
                    or offset_info.get('semantics') != semantics
                    or any(type(value) is not int or value < 0 for value in offsets)):
                raise KdfError(f'animation {name} offsets or index semantics are invalid')
            sample_ordinal = track.get('sample_ordinal')
            if type(sample_ordinal) is not int or sample_ordinal < 0:
                raise KdfError(f'animation {name} sample record is missing')
            layout, sample_layout, frames = _track_values(
                sample, source, offsets, headers['duration'], width, name)
            for offset_ordinal, offset in enumerate(offsets):
                node = domains[field].get(offset)
                if node is None or (required_type is not None and node['type'] != required_type):
                    raise KdfError(f'animation {name} offset is out of range or has wrong node type')
                target_key = (node['nodeid'], target)
                if target_key in targets:
                    raise KdfError('animation contains a duplicate node and target')
                targets.add(target_key)
                bindings.append({
                    'nodeid': node['nodeid'],
                    'node_name': node.get('name'),
                    'node_type': node['type'],
                    'target': target,
                    'track': name,
                    'index_field': field,
                    'offset': offset,
                    'offset_ordinal': offset_ordinal,
                    'source_section': source,
                    'group_ordinal': group_ordinal,
                    'group_record_start': group['record_start'],
                    'sample_record_ordinal': sample_ordinal,
                    'codec': sample['codec'],
                    'decode_status': sample['decode_status'],
                    'layout': layout,
                    'sample_layout': sample_layout,
                    'values': [frame[offset_ordinal] for frame in frames],
                    'application_semantics': (
                        'root-motion-application-unverified'
                        if name == 'positions'
                        else 'object-rotation-application-unverified'
                        if name == 'rotations' else 'unverified'),
                })
    if not bindings:
        raise KdfError('animation contains no bound tracks')
    return {
        'status': 'candidate',
        'pairing_status': pairing_status,
        'animation_sha256': animation_hash,
        'skeleton_sha256': skeleton_hash,
        'skeleton_reference': reference,
        'headers': headers,
        'bindings': bindings,
        'semantics': {
            'transform_coordinate_space': 'unverified',
            'transform_composition': 'unverified',
            'quaternion_component_order': 'unverified',
            'wavelet_frame_slot_order': 'unverified',
            'positions': 'root-motion-application-unverified',
        },
    }

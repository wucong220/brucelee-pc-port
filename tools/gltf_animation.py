#!/usr/bin/env python3
"""Assemble bounded candidate glTF animations from bound ANM tracks."""
from __future__ import annotations

import math
import re
import struct
from typing import Any

from kdf_data import KdfError
from kdf_pose import (
    closest_quaternion, compose_rotation, compose_translation, normalize_rotation,
)

_FLOAT = 5126
_MAX_ANIMATIONS = 64
_MAX_CHANNELS = 4096
_MAX_SAMPLES = 65_535
_MAX_SCALARS = 2_000_000
_TRACKS = {
    'bonepos': ('bone_position_index', 'translation', ('bone',), 3),
    'positions': ('object_position_index', 'translation', ('object',), 3),
    'bonerot': ('bone_rotation_index', 'rotation', ('bone',), 4),
    'rotations': ('object_rotation_index', 'rotation', ('object',), 4),
    'scales': ('scale_index', 'scale', ('bone', 'object'), 3),
}
_SHA256 = re.compile(r'[0-9a-f]{64}\Z')


def _vector(value: Any, width: int, label: str) -> tuple[float, ...]:
    if not isinstance(value, (list, tuple)) or len(value) != width:
        raise KdfError(f'{label} must have {width} components')
    result = []
    for component in value:
        if type(component) not in (int, float):
            raise KdfError(f'{label} must contain finite numeric components')
        try:
            number = float(component)
        except OverflowError as exc:
            raise KdfError(f'{label} must contain finite numeric components') from exc
        if not math.isfinite(number):
            raise KdfError(f'{label} must contain finite numeric components')
        result.append(number)
    return tuple(result)


def _float32(values: tuple[float, ...], label: str) -> tuple[float, ...]:
    try:
        packed = struct.pack(f'<{len(values)}f', *values)
    except (OverflowError, struct.error) as exc:
        raise KdfError(f'{label} cannot be represented as float32') from exc
    result = struct.unpack(f'<{len(values)}f', packed)
    if not all(math.isfinite(value) for value in result):
        raise KdfError(f'{label} cannot be represented as finite float32')
    return result


def _pack(values: list[tuple[float, ...]]) -> bytes:
    count = sum(len(value) for value in values)
    return struct.pack(f'<{count}f', *(component for value in values for component in value))


def _rest_nodes(skeleton: dict, node_index_by_id: dict) -> tuple[dict, dict]:
    if not isinstance(skeleton, dict) or not isinstance(node_index_by_id, dict):
        raise KdfError('skeleton or glTF node map is invalid')
    nodes = skeleton.get('nodes')
    if not isinstance(nodes, list) or not nodes:
        raise KdfError('skeleton node list is missing')
    by_id = {}
    for node in nodes:
        if not isinstance(node, dict):
            raise KdfError('skeleton node is malformed')
        nodeid = node.get('nodeid')
        if (type(nodeid) is not int or nodeid < 0 or nodeid in by_id
                or node.get('type') not in ('root', 'object', 'bone')):
            raise KdfError('skeleton node ID or type is invalid')
        by_id[nodeid] = node
    if (any(type(nodeid) is not int for nodeid in node_index_by_id)
            or set(node_index_by_id) != set(by_id)):
        raise KdfError('glTF node IDs do not match the complete Skl hierarchy')
    indices = list(node_index_by_id.values())
    if (any(type(value) is not int or value < 0 for value in indices)
            or len(set(indices)) != len(indices)):
        raise KdfError('glTF node indices must be unique nonnegative integers')

    rest = {}
    for field, expected_type in (
            ('static_transforms', 'bone'), ('object_static_transforms', 'object')):
        transforms = skeleton.get(field)
        if not isinstance(transforms, list):
            raise KdfError(f'skeleton {field} is missing')
        for transform in transforms:
            if not isinstance(transform, dict):
                raise KdfError(f'skeleton {field} entry is malformed')
            nodeid = transform.get('nodeid')
            if (type(nodeid) is not int or nodeid in rest or nodeid not in by_id
                    or by_id[nodeid]['type'] != expected_type):
                raise KdfError('skeleton rest transform node ID or type is invalid')
            position = _vector(transform.get('position'), 3, 'rest translation')
            rotation = _vector(
                transform.get('rotation_xyzw_unverified'), 4, 'rest rotation')
            scale = _vector(transform.get('scale'), 3, 'rest scale')
            norm = math.hypot(*rotation)
            if not math.isfinite(norm) or abs(norm - 1.0) > 1e-5:
                raise KdfError('rest rotation must be approximately unit length')
            rest[nodeid] = {'position': position, 'rotation': rotation, 'scale': scale}
    expected = {
        nodeid for nodeid, node in by_id.items() if node['type'] in ('bone', 'object')
    }
    if set(rest) != expected:
        raise KdfError('skeleton rest transforms do not cover bone and object nodes')
    return by_id, rest


def _candidate_times(duration: int, framerate: int) -> tuple[int, list[tuple[float, ...]]]:
    duration_ms = duration * 1000 // framerate
    if duration == 1:
        return duration_ms, [(0.0,)]
    times = [
        _float32((index * duration_ms / (1000.0 * (duration - 1)),), 'sample time')
        for index in range(duration)
    ]
    if any(left[0] >= right[0] for left, right in zip(times, times[1:])):
        raise KdfError('float32 animation sample times are not strictly increasing')
    return duration_ms, times


def _metadata(name: str, bound: dict, skeleton: dict, *,
              allow_experimental_retarget: bool = False) -> tuple[dict, int, int]:
    if not isinstance(bound, dict):
        raise KdfError(f'animation {name!r} is not a candidate binding')
    experimental = bound.get('status') == 'experimental-cross-skeleton-candidate'
    if experimental:
        if allow_experimental_retarget is not True:
            raise KdfError(f'animation {name!r} requires explicit experimental retarget opt-in')
        if (bound.get('source_pairing_status') != 'matched-provided-reference-and-hash'
                or bound.get('mapping_status') != 'identity-candidate-only'):
            raise KdfError(f'animation {name!r} has invalid candidate evidence')
        skeleton_hash = bound.get('source_skeleton_sha256')
        target_hash = bound.get('target_skeleton_sha256')
        reference = bound.get('source_skeleton_reference')
    else:
        if bound.get('status') != 'candidate':
            raise KdfError(f'animation {name!r} is not a candidate binding')
        if bound.get('pairing_status') != 'matched-provided-reference-and-hash':
            raise KdfError(f'animation {name!r} has an unverified skeleton pairing')
        skeleton_hash = bound.get('skeleton_sha256')
        target_hash = skeleton_hash
        reference = bound.get('skeleton_reference')
        reference = reference.get('reference') if isinstance(reference, dict) else None
    animation_hash = bound.get('animation_sha256')
    if (not isinstance(animation_hash, str) or _SHA256.fullmatch(animation_hash) is None
            or not isinstance(skeleton_hash, str) or _SHA256.fullmatch(skeleton_hash) is None
            or not isinstance(target_hash, str) or _SHA256.fullmatch(target_hash) is None
            or skeleton.get('sha256') != target_hash):
        raise KdfError(f'animation {name!r} source SHA-256 metadata is invalid')
    if (not isinstance(reference, str) or not reference.endswith('.skl')
            or not reference or len(reference.encode('utf-8')) > 4096):
        raise KdfError(f'animation {name!r} skeleton reference is invalid')
    headers = bound.get('headers')
    if not isinstance(headers, dict):
        raise KdfError(f'animation {name!r} headers are missing')
    if any(type(headers.get(key)) is not int
           for key in ('version', 'pose', 'firstframe', 'duration', 'framerate')):
        raise KdfError(f'animation {name!r} headers are invalid')
    duration = headers['duration']
    framerate = headers['framerate']
    if (headers['version'] != 7 or headers['pose'] != 1 or headers['firstframe'] != 0
            or not 1 <= duration <= _MAX_SAMPLES or framerate <= 0):
        raise KdfError(f'animation {name!r} header is outside the supported profile')
    extras = {
        'status': 'candidate',
        'sourceAnimationSha256': animation_hash,
        'sourceSkeletonSha256': skeleton_hash,
        'skeletonReference': reference,
        'sourceFrameCount': duration,
        'sourceFramerate': framerate,
        'pose': 1,
        'composition': 'pose-1-native-static-trace-runtime-unverified',
        'coordinateSpace': 'unverified',
        'quaternionSourceOrder': 'xyzw-candidate',
        'objectPositionBinding': 'object-index-candidate-root-player-unverified',
        'objectPositionComposition': 'pose-1-formula-candidate-unverified',
        'scaleOutput': 'direct-track-value-candidate-unverified',
        'rootMotionWorldApplication': 'unverified',
        'timing': 'floor-duration-ms-distributed-over-frame-intervals-candidate',
        'interpolation': 'STEP-candidate-native-interpolation-not-reproduced',
        'nativeRuntimeComparison': 'unverified',
        'godotPlayback': 'unverified',
    }
    if experimental:
        extras.update({
            'status': 'experimental-cross-skeleton-candidate',
            'targetSkeletonSha256': target_hash,
            'sourcePairingStatus': bound['source_pairing_status'],
            'targetPairingStatus': 'unverified',
            'mappingStatus': bound['mapping_status'],
            'retargetComposition': 'raw-track-applied-to-target-rest-candidate-unverified',
            'composition': 'target-rest-pose-1-formula-candidate-unverified',
            'retargetSemantics': 'unverified',
        })
    else:
        extras['pairingStatus'] = bound['pairing_status']
    return extras, duration, framerate


def _prepare(
        node_index_by_id: dict, skeleton: dict, animations: list, *,
        allow_experimental_retarget: bool = False) -> list[dict]:
    if not isinstance(animations, (list, tuple)) or len(animations) > _MAX_ANIMATIONS:
        raise KdfError('animation list is invalid or too large')
    nodes, rest = _rest_nodes(skeleton, node_index_by_id)
    names: set[str] = set()
    channel_count = 0
    scalar_count = 0
    prepared = []
    for item in animations:
        if not isinstance(item, (list, tuple)) or len(item) != 2:
            raise KdfError('animation entry must contain a name and binding')
        name, bound = item
        if (not isinstance(name, str) or not name or len(name.encode('utf-8')) > 256
                or name in names):
            raise KdfError('animation names must be unique nonempty short strings')
        names.add(name)
        extras, duration, framerate = _metadata(
            name, bound, skeleton, allow_experimental_retarget=allow_experimental_retarget)
        bindings = bound.get('bindings')
        if not isinstance(bindings, list) or not bindings:
            raise KdfError(f'animation {name!r} has no bound tracks')
        if bound.get('status') == 'experimental-cross-skeleton-candidate':
            from audit_animation_retarget import _paths

            _, target_paths = _paths(skeleton)
            mapping = bound.get('mapping')
            if not isinstance(mapping, list) or len(mapping) != len(bindings):
                raise KdfError('experimental candidate mapping is incomplete')
            for binding, entry in zip(bindings, mapping, strict=True):
                if not isinstance(binding, dict) or not isinstance(entry, dict):
                    raise KdfError('experimental candidate mapping is malformed')
                nodeid = binding.get('nodeid')
                node = nodes.get(nodeid) if type(nodeid) is int else None
                if (node is None or binding.get('node_name') != node.get('name')
                        or entry.get('target_nodeid') != nodeid
                        or entry.get('target_offset') != binding.get('offset')
                        or entry.get('track') != binding.get('track')
                        or entry.get('channel') != binding.get('target')
                        or entry.get('path') != [list(part) for part in target_paths[nodeid]]
                        or type(entry.get('source_nodeid')) is not int
                        or entry['source_nodeid'] < 0
                        or type(entry.get('source_offset')) is not int
                        or entry['source_offset'] < 0):
                    raise KdfError('experimental candidate mapping does not match target')
            extras['retargetMapping'] = [
                {key: entry[key] for key in (
                    'track', 'channel', 'path', 'source_offset', 'target_offset',
                    'source_nodeid', 'target_nodeid')}
                for entry in mapping
            ]
        channel_count += len(bindings)
        if channel_count > _MAX_CHANNELS:
            raise KdfError('animation channel count exceeds the export limit')

        seen = set()
        clip_channels = []
        for binding in bindings:
            if (not isinstance(binding, dict)
                    or not isinstance(binding.get('track'), str)
                    or binding['track'] not in _TRACKS):
                raise KdfError('animation bound track is invalid')
            track = binding['track']
            field, target, allowed_types, width = _TRACKS[track]
            nodeid = binding.get('nodeid')
            node = nodes.get(nodeid) if type(nodeid) is int else None
            if (type(nodeid) is not int or node is None or nodeid not in rest
                    or node['type'] not in allowed_types
                    or binding.get('node_type') != node['type']
                    or binding.get('target') != target
                    or binding.get('index_field') != field
                    or type(binding.get('offset')) is not int
                    or node.get(field) != binding['offset']):
                raise KdfError(f'animation {name!r} bound node or index is invalid')
            key = (node_index_by_id[nodeid], target)
            if key in seen:
                raise KdfError(f'animation {name!r} repeats a node and target')
            seen.add(key)
            layout = binding.get('layout')
            values = binding.get('values')
            if (layout not in ('per-frame', 'constant') or not isinstance(values, list)
                    or len(values) != (duration if layout == 'per-frame' else 1)):
                raise KdfError(f'animation {name!r} sample layout or count is invalid')
            scalar_count += len(values) * width
            if scalar_count > _MAX_SCALARS:
                raise KdfError('animation sample scalar count exceeds the export limit')

            frame_values = []
            previous = None
            for value in values:
                source = _vector(value, width, 'animation sample')
                transform = rest[nodeid]
                if target == 'translation':
                    output = compose_translation(
                        transform['position'], transform['rotation'], source)
                elif target == 'rotation':
                    output = normalize_rotation(compose_rotation(transform['rotation'], source))
                    if previous is not None:
                        output = closest_quaternion(previous, output)
                else:
                    output = source
                output = _float32(output, 'animation sample')
                if target == 'rotation':
                    if previous is not None:
                        output = closest_quaternion(previous, output)
                    previous = output
                frame_values.append(output)
            clip_channels.append({
                'node': node_index_by_id[nodeid],
                'target': target,
                'layout': layout,
                'width': width,
                'payload': _pack(frame_values),
                'count': len(frame_values),
            })
        has_per_frame = any(
            channel['layout'] == 'per-frame' for channel in clip_channels)
        if has_per_frame:
            duration_ms, times = _candidate_times(duration, framerate)
        else:
            duration_ms, times = duration * 1000 // framerate, [(0.0,)]
        if duration == 1 or not has_per_frame:
            # A clip containing only one-key samplers has zero glTF duration.
            # Hold each value through a synthetic candidate endpoint; mixed
            # multi-frame clips keep their normal constant sampler behavior.
            endpoint = _float32((duration_ms / 1000.0,), 'candidate clip end time')[0]
            if endpoint <= 0.0:
                raise KdfError('float32 animation sample times are not strictly increasing')
            scalar_count += sum(channel['width'] for channel in clip_channels)
            if scalar_count > _MAX_SCALARS:
                raise KdfError('animation sample scalar count exceeds the export limit')
            times = [(0.0,), (endpoint,)]
            for channel in clip_channels:
                channel['layout'] = 'held-span'
                channel['payload'] *= 2
                channel['count'] = 2
            extras['singleKeyHold'] = 'synthetic-candidate-endpoint'
        extras['durationMsCandidate'] = duration_ms
        prepared.append({
            'name': name,
            'extras': extras,
            'channels': clip_channels,
            'per_frame_times': times,
        })
    return prepared


def build_animations(
        builder: Any, accessors: list, node_index_by_id: dict,
        skeleton: dict, animations: list, *,
        allow_experimental_retarget: bool = False) -> list[dict]:
    """Append glTF accessors and bufferViews after validating all candidates."""
    if not callable(getattr(builder, 'add', None)) or not isinstance(accessors, list):
        raise KdfError('glTF builder or accessor list is invalid')
    prepared = _prepare(node_index_by_id, skeleton, animations,
                        allow_experimental_retarget=allow_experimental_retarget)
    result = []
    for clip in prepared:
        input_accessors = {}
        channels = []
        samplers = []
        for channel in clip['channels']:
            layout = channel['layout']
            if layout not in input_accessors:
                times = (
                    clip['per_frame_times']
                    if layout in ('per-frame', 'held-span')
                    else [(0.0,)]
                )
                view = builder.add(_pack(times))
                input_accessors[layout] = len(accessors)
                accessors.append({
                    'bufferView': view,
                    'componentType': _FLOAT,
                    'count': len(times),
                    'type': 'SCALAR',
                    'min': [times[0][0]],
                    'max': [times[-1][0]],
                })
            view = builder.add(channel['payload'])
            output_accessor = len(accessors)
            accessors.append({
                'bufferView': view,
                'componentType': _FLOAT,
                'count': channel['count'],
                'type': f'VEC{channel["width"]}',
            })
            samplers.append({
                'input': input_accessors[layout],
                'output': output_accessor,
                'interpolation': 'STEP',
            })
            channels.append({
                'sampler': len(samplers) - 1,
                'target': {'node': channel['node'], 'path': channel['target']},
            })
        result.append({
            'name': clip['name'],
            'channels': channels,
            'samplers': samplers,
            'extras': clip['extras'],
        })
    return result

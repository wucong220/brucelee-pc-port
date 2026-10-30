#!/usr/bin/env python3
"""Build local candidate GLB files from validated Mesh, Skl, and ANM resources."""
from __future__ import annotations

import argparse
import hashlib
from itertools import islice
import json
import math
import os
from pathlib import Path
import struct
import sys
import tempfile
from typing import Iterable

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_data import KdfError
from kdf_mesh import inspect_file as inspect_mesh_file
from kdf_skeleton import inspect_file as inspect_skeleton_file
from gltf_animation import build_animations

_PROJECT_ROOT = Path(__file__).resolve().parents[1]
_ARRAY_BUFFER = 34962
_ELEMENT_ARRAY_BUFFER = 34963
_FLOAT = 5126
_UNSIGNED_BYTE = 5121
_UNSIGNED_SHORT = 5123
_MAX_ANIMATION_BYTES = 16 * 1024 * 1024
# This slice adds the recovered highpunch1/highkick1 clips to the 23-clip
# Bruce candidate used by the ground-reaction prototype, plus headroom for the
# four *_03 / m01_sp_* attacks that the group inventory lists. The cap stays
# explicit so an accidental unbounded import is rejected.
_MAX_ANIMATION_FILES = 44
# Raising the per-file count must not leave the total input unbounded. 32 files
# at the 16 MiB per-file cap would otherwise allow about 512 MiB of animation
# input, so the sum of the declared ANM sizes is capped separately.
_MAX_TOTAL_ANIMATION_BYTES = 64 * 1024 * 1024
_MAX_RIGID_ATTACHMENTS = 16


class GltfExportError(ValueError):
    """Inputs cannot be represented by the candidate GLB exporter profile."""


def _check_animation_total_bytes(sources, limit: int | None = None) -> int:
    """Reject an animation set whose declared sizes exceed the total budget."""
    if limit is None:
        limit = _MAX_TOTAL_ANIMATION_BYTES
    total = 0
    for source in sources:
        try:
            total += Path(source).stat().st_size
        except OSError:
            # A missing file is reported later when the binding opens it.
            continue
        if total > limit:
            raise GltfExportError(
                'candidate animation input exceeds the total size limit')
    return total


def _safe_output_path(path: Path) -> Path:
    requested = path.expanduser()
    if requested.is_symlink():
        raise GltfExportError('GLB output already exists')
    target = requested.resolve()
    project = _PROJECT_ROOT.resolve()
    if target == project or target.is_relative_to(project):
        raise GltfExportError('GLB output must be outside the project checkout')
    sync_names = {'baidusyncdisk', 'onedrive', 'dropbox', 'google drive', 'icloud drive'}
    for part in target.parts:
        name = part.casefold()
        if name in sync_names or name.startswith('onedrive - '):
            raise GltfExportError('GLB output is inside a known sync folder')
    for name in ('OneDrive', 'OneDriveConsumer', 'OneDriveCommercial',
                 'DROPBOX_PATH', 'GOOGLE_DRIVE_PATH', 'BAIDU_SYNC_ROOT'):
        value = os.environ.get(name)
        if value:
            root = Path(value).expanduser().resolve()
            if target == root or target.is_relative_to(root):
                raise GltfExportError('GLB output is inside a configured sync folder')
    if target.exists():
        raise GltfExportError('GLB output already exists')
    if target.suffix.casefold() != '.glb':
        raise GltfExportError('GLB output must use the .glb extension')
    if not target.parent.is_dir():
        raise GltfExportError('GLB output parent is not an existing directory')
    return target


def _publish_glb(target: Path, payload: bytes) -> None:
    """Publish a complete file without replacing a concurrent destination."""
    fd, temp_name = tempfile.mkstemp(prefix='.brucelee-glb-', suffix='.tmp', dir=target.parent)
    temp_path = Path(temp_name)
    try:
        try:
            file = os.fdopen(fd, 'wb')
        except BaseException:
            os.close(fd)
            raise
        with file:
            if file.write(payload) != len(payload):
                raise OSError('incomplete GLB write')
            file.flush()
            os.fsync(file.fileno())
        # Windows rename fails when the target exists, including on filesystems
        # without hard links. POSIX rename may overwrite, so use link instead.
        if os.name == 'nt':
            os.rename(temp_path, target)
        else:
            os.link(temp_path, target)
    finally:
        temp_path.unlink(missing_ok=True)


def _quaternion_matrix(value: Iterable[float]) -> tuple[tuple[float, ...], ...]:
    x, y, z, w = value
    return (
        (1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)),
        (2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)),
        (2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)),
    )


def _mesh_inverse_bind_math_matrix(values: Iterable[float]) -> list[list[float]]:
    """Decode the Mesh 12-float layout as a row-major mathematical matrix."""
    value = list(values)
    if len(value) != 12:
        raise GltfExportError('Mesh inverse bind matrix must contain 12 floats')
    rows = (value[0:4], value[4:8], value[8:12])
    return [
        list(rows[0]),
        list(rows[1]),
        list(rows[2]),
        [0.0, 0.0, 0.0, 1.0],
    ]


def _mesh_inverse_bind_buffer(values: Iterable[float]) -> list[float]:
    """Preserve the original Mesh inverse bind matrix in glTF column order."""
    matrix = _mesh_inverse_bind_math_matrix(values)
    return [
        matrix[0][0], matrix[1][0], matrix[2][0], 0.0,
        matrix[0][1], matrix[1][1], matrix[2][1], 0.0,
        matrix[0][2], matrix[1][2], matrix[2][2], 0.0,
        matrix[0][3], matrix[1][3], matrix[2][3], 1.0,
    ]


def _local_matrix(transform: dict) -> list[list[float]]:
    rotation = _quaternion_matrix(transform['rotation_xyzw_unverified'])
    scale = transform['scale']
    position = transform['position']
    result = []
    for row in range(3):
        result.append([
            rotation[row][column] * scale[column]
            for column in range(3)
        ] + [position[row]])
    result.append([0.0, 0.0, 0.0, 1.0])
    return result


def _matrix_multiply(left: list[list[float]],
                     right: list[list[float]]) -> list[list[float]]:
    return [
        [
            sum(left[row][inner] * right[inner][column] for inner in range(4))
            for column in range(4)
        ]
        for row in range(4)
    ]


def _skeleton_transforms(skeleton: dict, *, include_objects: bool = False) -> dict[int, dict]:
    values = list(skeleton['static_transforms'] or [])
    if include_objects:
        values.extend(skeleton.get('object_static_transforms', []))
    transforms = {item['nodeid']: item for item in values}
    if len(transforms) != len(values):
        raise GltfExportError('Skl contains duplicate node transforms')
    return transforms


def _compose_skeleton(
        skeleton: dict, *, include_objects: bool = False,
        ) -> tuple[dict[int, list[list[float]]], dict[str, dict]]:
    nodes = {node['nodeid']: node for node in skeleton['nodes']}
    transforms = _skeleton_transforms(skeleton, include_objects=include_objects)
    cache = {}

    def global_matrix(nodeid: int) -> list[list[float]]:
        if nodeid in cache:
            return cache[nodeid]
        node = nodes[nodeid]
        parent = node['parentid']
        matrix = (
            global_matrix(parent)
            if parent in nodes
            else [[1.0, 0.0, 0.0, 0.0],
                  [0.0, 1.0, 0.0, 0.0],
                  [0.0, 0.0, 1.0, 0.0],
                  [0.0, 0.0, 0.0, 1.0]]
        )
        if nodeid in transforms:
            matrix = _matrix_multiply(matrix, _local_matrix(transforms[nodeid]))
        cache[nodeid] = matrix
        return matrix

    for nodeid in nodes:
        global_matrix(nodeid)
    by_name = {
        node['name']: {'node': node, 'matrix': cache[node['nodeid']]}
        for node in skeleton['nodes'] if node['type'] == 'bone'
    }
    return cache, by_name


def _validate_rest_pose(mesh: dict, skl_by_name: dict[str, dict]) -> dict:
    max_position_error = 0.0
    max_rotation_error = 0.0
    max_skin_rotation_error = 0.0
    max_skin_translation_error = 0.0
    worst_skin_translation_joint = None
    skin_matrices = []
    identity = [
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]
    for index, name in enumerate(mesh['skeleton']['names']):
        if name not in skl_by_name:
            raise GltfExportError(f'Mesh bone {name!r} is missing from Skl')
        matrix = skl_by_name[name]['matrix']
        expected_position = mesh['skeleton']['positions'][index]
        position_error = max(
            abs(matrix[row][3] - expected_position[row]) for row in range(3))
        expected_rotation = _quaternion_matrix(
            mesh['skeleton']['rotations_xyzw'][index])
        rotation_error = max(
            abs(matrix[row][column] - expected_rotation[row][column])
            for row in range(3) for column in range(3)
        )
        max_position_error = max(max_position_error, position_error)
        max_rotation_error = max(max_rotation_error, rotation_error)
        inverse_bind = _mesh_inverse_bind_math_matrix(
            mesh['skeleton']['bind_matrices'][index])
        skin_matrix = _matrix_multiply(matrix, inverse_bind)
        skin_matrices.append(skin_matrix)
        skin_rotation_error = max(
            abs(skin_matrix[row][column] - identity[row][column])
            for row in range(3) for column in range(3)
        )
        skin_translation_error = max(
            abs(skin_matrix[row][3] - identity[row][3])
            for row in range(3)
        )
        max_skin_rotation_error = max(
            max_skin_rotation_error, skin_rotation_error)
        if skin_translation_error > max_skin_translation_error:
            max_skin_translation_error = skin_translation_error
            worst_skin_translation_joint = name
    if max_position_error > 2e-3 or max_rotation_error > 2e-3:
        raise GltfExportError(
            f'Mesh/Skl rest pose mismatch: position={max_position_error}, '
            f'rotation={max_rotation_error}')
    model_span = max(
        upper - lower
        for lower, upper in zip(
            mesh['position_min'], mesh['position_max'], strict=True)
    )
    max_skin_vertex_displacement = 0.0
    worst_skin_vertex = None
    for vertex_index, vertex in enumerate(mesh.get('vertices', [])):
        position = vertex['position']
        transformed = [0.0, 0.0, 0.0]
        for joint_index, weight in zip(
                vertex['bone_indices_global'], vertex['weights'], strict=True):
            if weight == 0.0:
                continue
            skin_matrix = skin_matrices[joint_index]
            for row in range(3):
                transformed[row] += weight * (
                    sum(
                        skin_matrix[row][column] * position[column]
                        for column in range(3)
                    ) + skin_matrix[row][3]
                )
        displacement = math.sqrt(sum(
            (transformed[axis] - position[axis]) ** 2
            for axis in range(3)
        ))
        if displacement > max_skin_vertex_displacement:
            max_skin_vertex_displacement = displacement
            worst_skin_vertex = vertex_index
    return {
        'position_max_error': max_position_error,
        'rotation_max_error': max_rotation_error,
        'skin_matrix_rotation_max_error': max_skin_rotation_error,
        'skin_matrix_translation_max_error': max_skin_translation_error,
        'skin_matrix_translation_max_error_relative_to_model_span': (
            max_skin_translation_error / model_span if model_span else None),
        'worst_skin_translation_joint': worst_skin_translation_joint,
        'skin_vertex_max_displacement': max_skin_vertex_displacement,
        'skin_vertex_max_displacement_relative_to_model_span': (
            max_skin_vertex_displacement / model_span if model_span else None),
        'worst_skin_vertex': worst_skin_vertex,
        'model_span': model_span,
    }


def _lowest_common_ancestor(node_ids: list[int], nodes_by_id: dict[int, dict]) -> int:
    def ancestors(nodeid: int) -> list[int]:
        result = []
        while nodeid in nodes_by_id:
            result.append(nodeid)
            parent = nodes_by_id[nodeid]['parentid']
            if parent == nodeid:
                break
            nodeid = parent
        return result

    lineages = [ancestors(nodeid) for nodeid in node_ids]
    common = set(lineages[0]).intersection(*(set(value) for value in lineages[1:]))
    return next(nodeid for nodeid in lineages[0] if nodeid in common)


class _BufferBuilder:
    def __init__(self):
        self.data = bytearray()
        self.views = []

    def add(self, payload: bytes, target: int | None = None) -> int:
        while len(self.data) % 4:
            self.data.append(0)
        offset = len(self.data)
        self.data.extend(payload)
        view = {'buffer': 0, 'byteOffset': offset, 'byteLength': len(payload)}
        if target is not None:
            view['target'] = target
        self.views.append(view)
        return len(self.views) - 1


def _pack_floats(values: Iterable[float]) -> bytes:
    values = list(values)
    return struct.pack(f'<{len(values)}f', *values)


def _build_glb(gltf: dict, binary: bytes) -> bytes:
    json_payload = json.dumps(
        gltf, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    json_payload += b' ' * (-len(json_payload) % 4)
    binary += b'\0' * (-len(binary) % 4)
    total = 12 + 8 + len(json_payload) + 8 + len(binary)
    return b''.join((
        struct.pack('<4sII', b'glTF', 2, total),
        struct.pack('<II', len(json_payload), 0x4E4F534A),
        json_payload,
        struct.pack('<II', len(binary), 0x004E4942),
        binary,
    ))


def convert_file(mesh_source: Path, destination: Path, *,
                 skeleton_source: Path | None = None,
                 validate_rest_pose: bool = True,
                 include_object_transforms: bool = False,
                 animation_sources: Iterable[Path] | None = None,
                 expected_skeleton_reference: str | None = None,
                 expected_skeleton_sha256: str | None = None,
                 retarget_animations: Iterable[tuple[Path, str]] | None = None,
                 retarget_source_skeleton: Path | None = None,
                 retarget_source_reference: str | None = None,
                 retarget_source_sha256: str | None = None,
                 retarget_target_sha256: str | None = None,
                 rigid_attachments: Iterable[tuple[Path, str]] | None = None) -> dict:
    animation_sources = list(animation_sources or [])
    retarget_animations = list(retarget_animations or [])
    if len(animation_sources) + len(retarget_animations) > _MAX_ANIMATION_FILES:
        raise GltfExportError('too many candidate animation files')
    # The total budget covers both paths; retarget animations used to bypass a
    # check that only looked at animation_sources.
    _check_animation_total_bytes(
        list(animation_sources)
        + [source for source, _expected in retarget_animations])
    retarget_options = (retarget_source_skeleton, retarget_source_reference,
                        retarget_source_sha256, retarget_target_sha256)
    if bool(retarget_animations) != all(retarget_options) or (
            not retarget_animations and any(retarget_options)):
        raise GltfExportError('retargeting requires animations and all source/target identity options')
    rigid_attachments = list(islice(rigid_attachments or (), _MAX_RIGID_ATTACHMENTS + 1))
    if len(rigid_attachments) > _MAX_RIGID_ATTACHMENTS:
        raise GltfExportError('too many candidate rigid attachments')
    if rigid_attachments and (skeleton_source is None or not include_object_transforms):
        raise GltfExportError(
            'rigid attachments require --skeleton and --include-object-transforms')
    mesh = inspect_mesh_file(
        mesh_source, include_vertices=True, include_indices=True)
    skeleton = inspect_skeleton_file(skeleton_source) if skeleton_source else None
    if mesh['skeleton'] is not None and skeleton is None:
        raise GltfExportError('skinned Mesh requires --skeleton')
    if include_object_transforms and skeleton is None:
        raise GltfExportError('object transforms require --skeleton')
    if include_object_transforms:
        object_nodes = [node for node in skeleton['nodes'] if node['type'] == 'object']
        object_transforms = skeleton.get('object_static_transforms')
        if (not isinstance(object_transforms, list)
                or len(object_transforms) != len(object_nodes)
                or {value['nodeid'] for value in object_transforms}
                != {node['nodeid'] for node in object_nodes}):
            raise GltfExportError('object transforms are missing or incomplete')
    attachments = []
    for item in rigid_attachments:
        if not isinstance(item, (tuple, list)) or len(item) != 2:
            raise GltfExportError('rigid attachment must specify a Mesh and object node name')
        source, node_name = item
        if (not isinstance(source, (str, os.PathLike))
                or not isinstance(node_name, str) or not node_name):
            raise GltfExportError('rigid attachment Mesh or object node name is invalid')
        source = Path(source)
        matches = [node for node in skeleton['nodes'] if node['name'] == node_name]
        if len(matches) != 1 or matches[0]['type'] not in ('object', 'bone'):
            raise GltfExportError(
                f'rigid attachment target {node_name!r} must match one unique Skl object or bone node')
        if matches[0]['type'] == 'object':
            object_transforms = skeleton.get('object_static_transforms') or []
            if sum(value['nodeid'] == matches[0]['nodeid'] for value in object_transforms) != 1:
                raise GltfExportError(
                    f'rigid attachment target {node_name!r} has no unique object transform')
        attachment_mesh = inspect_mesh_file(
            source, include_vertices=True, include_indices=True)
        if attachment_mesh['skeleton'] is not None:
            raise GltfExportError('rigid attachment Mesh must not be skinned')
        attachments.append({
            'source': source,
            'mesh': attachment_mesh,
            'target': matches[0],
        })
    bound_animations = []
    if animation_sources:
        if skeleton is None or mesh['skeleton'] is None:
            raise GltfExportError('candidate animation requires a skinned Mesh and Skl')
        if not include_object_transforms:
            raise GltfExportError('candidate animation requires --include-object-transforms')
        if not expected_skeleton_reference or not expected_skeleton_sha256:
            raise GltfExportError(
                'candidate animation requires the expected Skl reference and SHA-256')
        from kdf_animation_binding import bind_animation

        with skeleton_source.open('rb') as file:
            skeleton_raw = file.read(_MAX_ANIMATION_BYTES + 1)
        if len(skeleton_raw) > _MAX_ANIMATION_BYTES:
            raise GltfExportError('Skl exceeds the candidate animation size limit')
        if hashlib.sha256(skeleton_raw).hexdigest() != skeleton['sha256']:
            raise GltfExportError('Skl changed between inspection and animation binding')
        for source in animation_sources:
            with source.open('rb') as file:
                animation_raw = file.read(_MAX_ANIMATION_BYTES + 1)
            if len(animation_raw) > _MAX_ANIMATION_BYTES:
                raise GltfExportError('ANM exceeds the candidate animation size limit')
            bound = bind_animation(
                animation_raw, skeleton_raw,
                expected_reference=expected_skeleton_reference,
                expected_skeleton_sha256=expected_skeleton_sha256)
            bound_animations.append((source.stem, bound))

    if retarget_animations:
        if skeleton is None or mesh['skeleton'] is None or not include_object_transforms:
            raise GltfExportError('retargeting requires a skinned Mesh, Skl and object transforms')
        if skeleton['sha256'] != retarget_target_sha256:
            raise GltfExportError('retarget target Skl SHA-256 does not match')
        from kdf_animation_binding import bind_animation
        from kdf_skeleton import inspect_skeleton
        from retarget_animation_binding import retarget_candidate

        with Path(retarget_source_skeleton).open('rb') as file:
            source_raw = file.read(_MAX_ANIMATION_BYTES + 1)
        if len(source_raw) > _MAX_ANIMATION_BYTES:
            raise GltfExportError('retarget source Skl exceeds size limit')
        source_skeleton = inspect_skeleton(source_raw)
        for source, expected_animation_hash in retarget_animations:
            source = Path(source)
            with source.open('rb') as file:
                animation_raw = file.read(_MAX_ANIMATION_BYTES + 1)
            if len(animation_raw) > _MAX_ANIMATION_BYTES:
                raise GltfExportError('retarget ANM exceeds size limit')
            bound = bind_animation(
                animation_raw, source_raw, expected_reference=retarget_source_reference,
                expected_skeleton_sha256=retarget_source_sha256)
            candidate = retarget_candidate(
                bound, source_skeleton, skeleton,
                expected_animation_sha256=expected_animation_hash,
                expected_source_sha256=retarget_source_sha256,
                expected_target_sha256=retarget_target_sha256,
                expected_reference=retarget_source_reference)
            bound_animations.append((source.stem, candidate))

    skl_global = None
    skl_by_name = None
    rest_pose_validation = None
    if skeleton is not None:
        skl_global, skl_by_name = _compose_skeleton(
            skeleton, include_objects=include_object_transforms)
        if mesh['skeleton'] is not None and validate_rest_pose:
            rest_pose_validation = _validate_rest_pose(mesh, skl_by_name)

    builder = _BufferBuilder()
    vertices = mesh['vertices']
    view_positions = builder.add(
        _pack_floats(value for vertex in vertices for value in vertex['position']),
        _ARRAY_BUFFER,
    )
    view_uvs = builder.add(
        _pack_floats(value for vertex in vertices for value in vertex['uv']),
        _ARRAY_BUFFER,
    )
    view_joints = None
    view_weights = None
    if mesh['skeleton'] is not None:
        view_joints = builder.add(
            bytes(value for vertex in vertices for value in vertex['bone_indices_global']),
            _ARRAY_BUFFER,
        )
        view_weights = builder.add(
            _pack_floats(value for vertex in vertices for value in vertex['weights']),
            _ARRAY_BUFFER,
        )
    indices = mesh['indices']
    view_indices = builder.add(
        struct.pack(f'<{len(indices)}H', *indices), _ELEMENT_ARRAY_BUFFER)
    view_inverse_bind = None
    inverse_bind_values = []
    if mesh['skeleton'] is not None:
        for matrix in mesh['skeleton']['bind_matrices']:
            inverse_bind_values.extend(_mesh_inverse_bind_buffer(matrix))
        view_inverse_bind = builder.add(_pack_floats(inverse_bind_values))

    accessors = [
        {
            'bufferView': view_positions,
            'componentType': _FLOAT,
            'count': mesh['vertex_count'],
            'type': 'VEC3',
            'min': mesh['position_min'],
            'max': mesh['position_max'],
        },
        {
            'bufferView': view_uvs,
            'componentType': _FLOAT,
            'count': mesh['vertex_count'],
            'type': 'VEC2',
        },
    ]
    attributes = {'POSITION': 0, 'TEXCOORD_0': 1}
    if mesh['skeleton'] is not None:
        attributes['JOINTS_0'] = len(accessors)
        accessors.append({
            'bufferView': view_joints,
            'componentType': _UNSIGNED_BYTE,
            'count': mesh['vertex_count'],
            'type': 'VEC4',
        })
        attributes['WEIGHTS_0'] = len(accessors)
        accessors.append({
            'bufferView': view_weights,
            'componentType': _FLOAT,
            'count': mesh['vertex_count'],
            'type': 'VEC4',
        })

    materials = []
    material_indices = {}
    palette = ([0.72, 0.2, 0.16, 1.0], [0.22, 0.55, 0.3, 1.0],
               [0.2, 0.34, 0.72, 1.0], [0.65, 0.5, 0.2, 1.0])
    subsets = mesh['subsets']
    index_accessors = []
    for subset_ordinal, subset in enumerate(subsets):
        start, end = subset['index_range']
        accessor_index = len(accessors)
        accessors.append({
            'bufferView': view_indices,
            'byteOffset': start * 2,
            'componentType': _UNSIGNED_SHORT,
            'count': end - start,
            'type': 'SCALAR',
        })
        index_accessors.append(accessor_index)
        name = subset['material']
        if name not in material_indices:
            material_indices[name] = len(materials)
            materials.append({
                'name': name,
                'pbrMetallicRoughness': {
                    'baseColorFactor': palette[len(materials) % len(palette)],
                    'metallicFactor': 0.0,
                    'roughnessFactor': 0.8,
                },
            })

    inverse_bind_accessor = None
    if mesh['skeleton'] is not None:
        inverse_bind_accessor = len(accessors)
        accessors.append({
            'bufferView': view_inverse_bind,
            'componentType': _FLOAT,
            'count': mesh['skeleton']['bone_count'],
            'type': 'MAT4',
        })

    nodes = [{
        'name': 'Z_up_to_glTF_Y_up',
        'rotation': [-0.7071067811865475, 0.0, 0.0, 0.7071067811865476],
        'children': [],
    }]
    node_index_by_id = {}
    if skeleton is not None:
        transforms = _skeleton_transforms(
            skeleton, include_objects=include_object_transforms)
        for value in skeleton['nodes']:
            node_index = len(nodes)
            node_index_by_id[value['nodeid']] = node_index
            gltf_node = {'name': value['name'], 'children': []}
            if value['nodeid'] in transforms:
                transform = transforms[value['nodeid']]
                gltf_node['translation'] = transform['position']
                gltf_node['rotation'] = transform['rotation_xyzw_unverified']
                gltf_node['scale'] = transform['scale']
            nodes.append(gltf_node)
        nodes_by_id = {value['nodeid']: value for value in skeleton['nodes']}
        for value in skeleton['nodes']:
            node_index = node_index_by_id[value['nodeid']]
            if value['parentid'] in node_index_by_id:
                nodes[node_index_by_id[value['parentid']]]['children'].append(node_index)
            elif value['parentid'] == -2:
                nodes[0]['children'].append(node_index)

    mesh_node_index = len(nodes)
    mesh_node = {'name': mesh_source.stem}
    nodes.append(mesh_node)
    nodes[0]['children'].append(mesh_node_index)

    primitives = []
    for subset, accessor_index in zip(subsets, index_accessors, strict=True):
        primitives.append({
            'attributes': attributes,
            'indices': accessor_index,
            'material': material_indices[subset['material']],
            'mode': 4,
        })
    gltf_meshes = [{'name': mesh_source.stem, 'primitives': primitives}]
    mesh_node['mesh'] = 0

    skins = []
    if mesh['skeleton'] is not None:
        mesh_bone_names = mesh['skeleton']['names']
        if any(name not in skl_by_name for name in mesh_bone_names):
            raise GltfExportError('mesh bone table contains names absent from Skl')
        joint_node_ids = [skl_by_name[name]['node']['nodeid'] for name in mesh_bone_names]
        common = _lowest_common_ancestor(joint_node_ids, nodes_by_id)
        mesh_node['skin'] = 0
        skins.append({
            'name': mesh_source.stem + '_skin',
            'inverseBindMatrices': inverse_bind_accessor,
            'joints': [node_index_by_id[nodeid] for nodeid in joint_node_ids],
            'skeleton': node_index_by_id[common],
        })

    attachment_metadata = []
    for attachment in attachments:
        source = attachment['source']
        value = attachment['mesh']
        target_node = attachment['target']
        position_view = builder.add(
            _pack_floats(
                component for vertex in value['vertices']
                for component in vertex['position']),
            _ARRAY_BUFFER,
        )
        uv_view = builder.add(
            _pack_floats(
                component for vertex in value['vertices']
                for component in vertex['uv']),
            _ARRAY_BUFFER,
        )
        index_view = builder.add(
            struct.pack(f'<{len(value["indices"])}H', *value['indices']),
            _ELEMENT_ARRAY_BUFFER,
        )
        position_accessor = len(accessors)
        accessors.append({
            'bufferView': position_view,
            'componentType': _FLOAT,
            'count': value['vertex_count'],
            'type': 'VEC3',
            'min': value['position_min'],
            'max': value['position_max'],
        })
        uv_accessor = len(accessors)
        accessors.append({
            'bufferView': uv_view,
            'componentType': _FLOAT,
            'count': value['vertex_count'],
            'type': 'VEC2',
        })
        rigid_primitives = []
        for subset in value['subsets']:
            start, end = subset['index_range']
            index_accessor = len(accessors)
            accessors.append({
                'bufferView': index_view,
                'byteOffset': start * 2,
                'componentType': _UNSIGNED_SHORT,
                'count': end - start,
                'type': 'SCALAR',
            })
            material_name = subset['material']
            if material_name not in material_indices:
                material_indices[material_name] = len(materials)
                materials.append({
                    'name': material_name,
                    'pbrMetallicRoughness': {
                        'baseColorFactor': palette[len(materials) % len(palette)],
                        'metallicFactor': 0.0,
                        'roughnessFactor': 0.8,
                    },
                })
            rigid_primitives.append({
                'attributes': {
                    'POSITION': position_accessor,
                    'TEXCOORD_0': uv_accessor,
                },
                'indices': index_accessor,
                'material': material_indices[material_name],
                'mode': 4,
            })
        gltf_mesh_index = len(gltf_meshes)
        gltf_meshes.append({'name': source.stem, 'primitives': rigid_primitives})
        metadata = {
            'sourceMeshSha256': value['sha256'],
            'targetNodeName': target_node['name'],
            'targetNodeId': target_node['nodeid'],
            'status': 'candidate',
            'placement': 'unverified',
        }
        attachment_metadata.append(metadata)
        attachment_index = len(nodes)
        nodes.append({
            'name': source.stem + '_rigid_attachment',
            'mesh': gltf_mesh_index,
            'extras': dict(metadata),
        })
        nodes[node_index_by_id[target_node['nodeid']]]['children'].append(attachment_index)

    animations = []
    if bound_animations:
        from gltf_animation import build_animations

        animations = build_animations(
            builder, accessors, node_index_by_id, skeleton, bound_animations,
            allow_experimental_retarget=bool(retarget_animations))

    gltf = {
        'asset': {
            'version': '2.0',
            'generator': 'BruceLee PC Port static-pose converter',
            'extras': {
                'meshSha256': mesh['sha256'],
                'skeletonSha256': None if skeleton is None else skeleton['sha256'],
                'geometryAxes': mesh['geometry_axes'],
                'originalRotationComponentOrder': 'xyzw',
                'inverseBindSource': 'mesh-original-float32',
                'inverseBindMatrixSemantics': 'candidate',
                'restPoseValidation': rest_pose_validation,
                'animationsIncluded': bool(animations),
            },
        },
        'scene': 0,
        'scenes': [{'nodes': [0]}],
        'nodes': nodes,
        'meshes': gltf_meshes,
        'materials': materials,
        'accessors': accessors,
        'bufferViews': builder.views,
        'buffers': [{'byteLength': len(builder.data)}],
    }
    if skins:
        gltf['skins'] = skins
    if animations:
        gltf['animations'] = animations
        gltf['asset']['generator'] = 'BruceLee PC Port candidate animation converter'
    if include_object_transforms:
        gltf['asset']['extras']['objectTransformsIncluded'] = True
        gltf['asset']['extras']['objectTransformSpace'] = 'unverified'
    if attachment_metadata:
        gltf['asset']['extras']['rigidAttachments'] = attachment_metadata

    target = _safe_output_path(destination)
    glb = _build_glb(gltf, bytes(builder.data))
    _publish_glb(target, glb)
    result = {
        'mesh_source': str(mesh_source),
        'skeleton_source': None if skeleton_source is None else str(skeleton_source),
        'output': str(target),
        'glb_bytes': len(glb),
        'glb_sha256': hashlib.sha256(glb).hexdigest(),
        'vertex_count': mesh['vertex_count'],
        'triangle_count': mesh['triangle_count'],
        'subset_count': mesh['subset_count'],
        'skin_joint_count': None if not skins else len(skins[0]['joints']),
        'rest_pose_validation': rest_pose_validation,
        'animations_included': bool(animations),
    }
    if include_object_transforms:
        result['object_transforms_included'] = True
        result['object_transform_space'] = 'unverified'
    if animations:
        result['animation_names'] = [animation['name'] for animation in animations]
        result['animation_status'] = 'candidate'
    if attachments:
        result['rigid_attachments'] = [
            {'mesh_source': str(attachment['source']), **metadata}
            for attachment, metadata in zip(attachments, attachment_metadata, strict=True)
        ]
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mesh', type=Path, help='decoded Mesh CTX3 resource')
    parser.add_argument('--skeleton', type=Path,
                        help='decoded Skl resource; required for skinned Mesh')
    parser.add_argument('--output', type=Path, required=True,
                        help='new GLB outside the checkout and sync directories')
    parser.add_argument(
        '--include-object-transforms', action='store_true',
        help='include candidate Skl object transforms; coordinate space remains unverified')
    parser.add_argument(
        '--animation', type=Path, action='append', default=[],
        help='decoded ANM to include as a candidate animation; may be repeated')
    parser.add_argument(
        '--expected-skeleton-reference',
        help='expected ANM skeleton reference from a trusted extraction record')
    parser.add_argument(
        '--expected-skeleton-sha256',
        help='expected SHA-256 of the matching Skl from that record')
    parser.add_argument(
        '--retarget-animation', nargs=2, action='append', default=[],
        metavar=('ANM', 'SHA256'),
        help='explicit experimental cross-skeleton ANM and expected hash; repeatable')
    parser.add_argument('--retarget-source-skeleton', type=Path)
    parser.add_argument('--retarget-source-reference')
    parser.add_argument('--retarget-source-sha256')
    parser.add_argument('--retarget-target-sha256')
    parser.add_argument(
        '--rigid-attachment', nargs=2, action='append', default=[],
        metavar=('MESH', 'NODE'),
        help='candidate unskinned Mesh attached to an exactly named Skl object; repeatable')
    args = parser.parse_args()
    try:
        result = convert_file(
            args.mesh, args.output, skeleton_source=args.skeleton,
            include_object_transforms=args.include_object_transforms,
            animation_sources=args.animation,
            expected_skeleton_reference=args.expected_skeleton_reference,
            expected_skeleton_sha256=args.expected_skeleton_sha256,
            retarget_animations=args.retarget_animation,
            retarget_source_skeleton=args.retarget_source_skeleton,
            retarget_source_reference=args.retarget_source_reference,
            retarget_source_sha256=args.retarget_source_sha256,
            retarget_target_sha256=args.retarget_target_sha256,
            rigid_attachments=args.rigid_attachment)
    except (OSError, KdfError, GltfExportError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

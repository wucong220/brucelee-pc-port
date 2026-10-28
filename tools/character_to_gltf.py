#!/usr/bin/env python3
"""Build a local static-pose GLB from validated Mesh and Skl resources."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import sys
from typing import Iterable

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_data import KdfError
from kdf_mesh import inspect_file as inspect_mesh_file
from kdf_skeleton import inspect_file as inspect_skeleton_file

_PROJECT_ROOT = Path(__file__).resolve().parents[1]
_ARRAY_BUFFER = 34962
_ELEMENT_ARRAY_BUFFER = 34963
_FLOAT = 5126
_UNSIGNED_BYTE = 5121
_UNSIGNED_SHORT = 5123


class GltfExportError(ValueError):
    """Inputs cannot be represented by the validated static-pose GLB profile."""


def _safe_output_path(path: Path) -> Path:
    target = path.expanduser().resolve()
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


def _quaternion_matrix(value: Iterable[float]) -> tuple[tuple[float, ...], ...]:
    x, y, z, w = value
    return (
        (1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)),
        (2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)),
        (2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)),
    )


def _inverse_bind_math_matrix(
        rotation: Iterable[float],
        translation: Iterable[float]) -> list[list[float]]:
    """Return the row-major mathematical inverse bind matrix."""
    bind_rotation = _quaternion_matrix(rotation)
    tx, ty, tz = translation
    return [
        [
            bind_rotation[0][0], bind_rotation[1][0],
            bind_rotation[2][0], tx,
        ],
        [
            bind_rotation[0][1], bind_rotation[1][1],
            bind_rotation[2][1], ty,
        ],
        [
            bind_rotation[0][2], bind_rotation[1][2],
            bind_rotation[2][2], tz,
        ],
        [0.0, 0.0, 0.0, 1.0],
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


def _compose_skeleton(skeleton: dict) -> tuple[dict[int, list[list[float]]], dict[str, dict]]:
    nodes = {node['nodeid']: node for node in skeleton['nodes']}
    transforms = {item['nodeid']: item for item in skeleton['static_transforms']}
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
        inverse_bind = _inverse_bind_math_matrix(
            mesh['skeleton']['rotations_xyzw'][index],
            mesh['skeleton']['bind_translations'][index],
        )
        skin_matrix = _matrix_multiply(matrix, inverse_bind)
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
    return {
        'position_max_error': max_position_error,
        'rotation_max_error': max_rotation_error,
        'skin_matrix_rotation_max_error': max_skin_rotation_error,
        'skin_matrix_translation_max_error': max_skin_translation_error,
        'skin_matrix_translation_max_error_relative_to_model_span': (
            max_skin_translation_error / model_span if model_span else None),
        'worst_skin_translation_joint': worst_skin_translation_joint,
        'model_span': model_span,
    }


def _inverse_bind_matrix(rotation: Iterable[float],
                         translation: Iterable[float]) -> list[float]:
    matrix = _quaternion_matrix(rotation)
    tx, ty, tz = translation
    return [
        matrix[0][0], matrix[0][1], matrix[0][2], 0.0,
        matrix[1][0], matrix[1][1], matrix[1][2], 0.0,
        matrix[2][0], matrix[2][1], matrix[2][2], 0.0,
        tx, ty, tz, 1.0,
    ]


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
                 validate_rest_pose: bool = True) -> dict:
    mesh = inspect_mesh_file(
        mesh_source, include_vertices=True, include_indices=True)
    skeleton = inspect_skeleton_file(skeleton_source) if skeleton_source else None
    if mesh['skeleton'] is not None and skeleton is None:
        raise GltfExportError('skinned Mesh requires --skeleton')

    skl_global = None
    skl_by_name = None
    rest_pose_validation = None
    if skeleton is not None:
        skl_global, skl_by_name = _compose_skeleton(skeleton)
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
        for rotation, translation in zip(
                mesh['skeleton']['rotations_xyzw'],
                mesh['skeleton']['bind_translations'], strict=True):
            inverse_bind_values.extend(_inverse_bind_matrix(rotation, translation))
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
        transforms = {item['nodeid']: item for item in skeleton['static_transforms']}
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

    gltf = {
        'asset': {
            'version': '2.0',
            'generator': 'BruceLee PC Port static-pose converter',
            'extras': {
                'meshSha256': mesh['sha256'],
                'skeletonSha256': None if skeleton is None else skeleton['sha256'],
                'geometryAxes': mesh['geometry_axes'],
                'originalRotationComponentOrder': 'xyzw',
                'inverseBindMatrixSemantics': 'candidate',
                'restPoseValidation': rest_pose_validation,
                'animationsIncluded': False,
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

    target = _safe_output_path(destination)
    glb = _build_glb(gltf, bytes(builder.data))
    with target.open('xb') as file:
        file.write(glb)
    return {
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
        'animations_included': False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mesh', type=Path, help='decoded Mesh CTX3 resource')
    parser.add_argument('--skeleton', type=Path,
                        help='decoded Skl resource; required for skinned Mesh')
    parser.add_argument('--output', type=Path, required=True,
                        help='new GLB outside the checkout and sync directories')
    args = parser.parse_args()
    try:
        result = convert_file(
            args.mesh, args.output, skeleton_source=args.skeleton)
    except (OSError, KdfError, GltfExportError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_data import KdfError
from kdf_mesh import inspect_mesh
from mesh_to_obj import convert_file
from character_to_gltf import (
    GltfExportError, _compose_skeleton, _local_matrix, _matrix_multiply,
    _validate_rest_pose,
)
from character_to_gltf import convert_file as convert_glb
from kdf_skeleton import inspect_skeleton
from test_kdf_animation_binding import animation_fixture
from test_kdf_skeleton import object_skeleton_fixture, skeleton_fixture


def descriptor(count: int, stride: int) -> int:
    return 0x40000000 | (stride << 21) | count


def mesh_fixture(*, skinned=True, bad_index=False, single_bone=False) -> bytes:
    bone_count = 1 if single_bone else 2
    strings = [
        'subsets', 'rangeidx', 'rangevtx', 'mtlid', 'material',
        'skl', 'format', 'float', 'vertexformat', 'indices', 'vertices',
        'properties', 'bone_a', 'bone_b', 'names', 'positions',
        'rotations', 'transforms', 'bv', 'min', 'max', 'sphere',
    ]
    indices = struct.pack('<3H', 0, 255 if bad_index else 1, 2)
    range_indices = struct.pack('<2I', 0, 3)
    range_vertices = struct.pack('<2I', 0, 3)
    vertices = bytearray()
    for position, uv, bones, weights in (
            ((0, 0, 0), (0, 0), (0, 1, 0, 0), (0.75, 0.25, 0, 0)),
            ((1, 0, 0), (1, 0), (1, 0, 0, 0), (1, 0, 0, 0)),
            ((0, 1, 0), (0, 1), (0, 0, 0, 0), (0.5, 0.5, 0, 0))):
        vertices += struct.pack('<3f', *position)
        vertices += struct.pack('<2f', *uv)
        if skinned:
            if single_bone:
                bones = (0, 0, 0, 0)
            vertices += bytes(bones)
            vertices += struct.pack('<4f', *weights)

    records = [
        (0x30000006, 1),
        (0x60000000, strings.index('subsets')),
        (descriptor(1, 0), 11),
        (0x60000000, strings.index('format')),
        (0x60000000, strings.index('float')),
        (0x60000000, strings.index('vertexformat')),
        (0, 0x342 if skinned else 0x42),
        (0x60000000, strings.index('indices')),
        (descriptor(3, 2), 0),
        (0x60000000, strings.index('vertices')),
        (descriptor(3, 40 if skinned else 20), 1),
        (0x60000000, strings.index('properties')),
        (0x30000002, 16),
        (0x60000000, strings.index('rangeidx')),
        (0x00800002, 2),
        (0x60000000, strings.index('rangevtx')),
        (0x00800002, 3),
        (0x60000000, strings.index('mtlid')),
        (0x60000000, strings.index('material')),
    ]
    groups = [indices, bytes(vertices), range_indices, range_vertices]
    if skinned:
        records.extend([
            (0x60000000, strings.index('skl')),
            (descriptor(bone_count, 1), 4),
            (0x60000000, strings.index('skl')),
            (0x30000005, 1),
            (0x60000000, strings.index('names')),
            (descriptor(bone_count, 0), 4),
            (0x60000000, strings.index('positions')),
            (descriptor(bone_count, 12), 5),
            (0x60000000, strings.index('rotations')),
            (descriptor(bone_count, 16), 6),
            (0x60000000, strings.index('transforms')),
            (descriptor(bone_count, 48), 7),
            (0x60000000, strings.index('bv')),
            (descriptor(bone_count, 0), 4),
            (0x60000000, strings.index('bone_a')),
        ])
        if not single_bone:
            records.append((0x60000000, strings.index('bone_b')))
        groups.extend([
            bytes(range(bone_count)),
            struct.pack('<6f', 0, 0, 0, 1, 0, 0)[:bone_count * 12],
            struct.pack('<8f', 0, 0, 0, 1, 0, 0, 0, 1)[:bone_count * 16],
            struct.pack(
                '<24f',
                1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0,
                1, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1, 0,
            )[:bone_count * 48],
        ])

    offsets = [0, 0]
    for group in groups[:-1]:
        offsets.append(offsets[-1] + len(group))
    payload = b''.join(groups)
    raw = bytearray(b'1FDKENONCTX3' + struct.pack(
        '<IIII', len(strings), 0, 0, len(strings)))
    for text in strings:
        encoded = text.encode()
        identifier = (zlib.crc32(encoded) + len(encoded)) & 0xffffffff
        raw += struct.pack('<II', identifier, len(encoded)) + encoded + b'\0'
    raw += b'DATA'
    raw += struct.pack('<IIII', len(records), len(groups), 0, len(payload))
    raw += struct.pack(f'<{len(offsets)}I', *offsets)
    for record in records:
        raw += struct.pack('<II', *record)
    raw += payload + b'mesh-identity!!!'
    return bytes(raw)


def read_glb(path: Path):
    payload = path.read_bytes()
    magic, version, total = struct.unpack_from('<4sII', payload)
    if (magic, version, total) != (b'glTF', 2, len(payload)):
        raise ValueError('invalid GLB header')
    json_length, json_type = struct.unpack_from('<II', payload, 12)
    if json_type != 0x4e4f534a:
        raise ValueError('invalid GLB JSON chunk')
    gltf = json.loads(payload[20:20 + json_length])
    binary_length, binary_type = struct.unpack_from('<II', payload, 20 + json_length)
    if binary_type != 0x004e4942:
        raise ValueError('invalid GLB binary chunk')
    return gltf, payload[28 + json_length:28 + json_length + binary_length]


def accessor_values(gltf: dict, binary: bytes, index: int):
    accessor = gltf['accessors'][index]
    view = gltf['bufferViews'][accessor['bufferView']]
    offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    components = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
    codes = {5121: 'B', 5123: 'H', 5126: 'f'}
    width = components[accessor['type']]
    code = codes[accessor['componentType']]
    item_size = struct.calcsize('<' + code * width)
    stride = view.get('byteStride', item_size)
    return [
        struct.unpack_from('<' + code * width, binary, offset + row * stride)
        for row in range(accessor['count'])
    ]


class TestKdfMesh(unittest.TestCase):
    def test_legacy_object_hierarchy_allows_static_export_but_rejects_object_transforms(self):
        nodes = [
            ('root', 0, -2, 4, 0), ('object', 1, 0, 3, 1),
            ('bone', 2, 1, 2, 2), ('bone', 4, 2, 1, 3),
        ]
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            mesh = folder / 'mesh.bin'
            skeleton = folder / 'skeleton.bin'
            static_output = folder / 'static.glb'
            candidate_output = folder / 'candidate.glb'
            mesh.write_bytes(mesh_fixture(skinned=False))
            skeleton.write_bytes(skeleton_fixture(nodes))
            convert_glb(mesh, static_output, skeleton_source=skeleton)
            self.assertTrue(static_output.is_file())
            with self.assertRaisesRegex(GltfExportError, 'object transforms are missing or incomplete'):
                convert_glb(mesh, candidate_output, skeleton_source=skeleton,
                            include_object_transforms=True)
            self.assertFalse(candidate_output.exists())

    def test_rigid_geometry_and_subset(self):
        result = inspect_mesh(mesh_fixture(skinned=False), include_vertices=True)
        self.assertEqual(result['vertex_format'], 0x42)
        self.assertEqual(result['vertex_stride'], 20)
        self.assertEqual(result['vertex_count'], 3)
        self.assertEqual(result['triangle_count'], 1)
        self.assertIsNone(result['skeleton'])
        self.assertEqual(result['subsets'][0]['material'], 'material')
        self.assertEqual(result['vertices'][1]['position'], [1.0, 0.0, 0.0])
        self.assertEqual(result['vertices'][1]['bone_indices_local'], [])

    def test_skinned_geometry_bone_map_and_skeleton(self):
        result = inspect_mesh(mesh_fixture(), include_vertices=True)
        self.assertEqual(result['vertex_format'], 0x342)
        self.assertEqual(result['vertex_stride'], 40)
        self.assertEqual(result['subsets'][0]['local_to_global_bone_indices'], [0, 1])
        self.assertEqual(result['skeleton']['names'], ['bone_a', 'bone_b'])
        self.assertEqual(result['weight_sum_max_error'], 0.0)
        self.assertEqual(
            result['vertices'][0]['bone_indices_global'], [0, 1, 0, 0])
        self.assertEqual(result['skeleton']['rotation_norm_max_error'], 0.0)
        self.assertEqual(
            result['skeleton']['quaternion_component_order'],
            'xyzw-verified-relative-to-matrix',
        )
        self.assertEqual(
            result['skeleton']['matrix_layout'],
            'transposed-rotation-rows-with-translation-tail',
        )
        self.assertEqual(len(result['skeleton']['bind_matrices']), 2)
        self.assertEqual(
            result['skeleton']['bind_matrices'][1],
            [1.0, 0.0, 0.0, -1.0, 0.0, 1.0, 0.0, 0.0,
             0.0, 0.0, 1.0, 0.0],
        )
        self.assertEqual(result['skeleton']['bind_position_residual_max'], 0.0)
        self.assertEqual(
            result['skeleton']['matrix_transform_semantics'],
            'inverse-bind-candidate',
        )
        self.assertEqual(result['geometry_axes'], 'x-horizontal-y-depth-z-up-observed')
        self.assertEqual(result['godot_axis_mapping'], 'unverified')

    def test_out_of_range_index_is_rejected(self):
        with self.assertRaisesRegex(KdfError, 'index exceeds vertex count'):
            inspect_mesh(mesh_fixture(bad_index=True))

    def test_cli_outputs_summary(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / 'test.mesh'
            source.write_bytes(mesh_fixture())
            script = Path(__file__).resolve().parents[1] / 'tools' / 'kdf_mesh.py'
            run = subprocess.run(
                [sys.executable, '-X', 'utf8', str(script), str(source)],
                capture_output=True, text=True, encoding='utf-8', check=False,
            )
            self.assertEqual(run.returncode, 0, run.stderr)
            report = json.loads(run.stdout)
            self.assertEqual(report['triangle_count'], 1)
            self.assertNotIn('vertices', report)
            self.assertNotIn('indices', report)

    def test_obj_export_contains_geometry_only(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / 'test.mesh'
            output = Path(temp) / 'test.obj'
            source.write_bytes(mesh_fixture())
            result = convert_file(source, output)
            self.assertEqual(result['triangle_count'], 1)
            self.assertFalse(result['skin_data_included'])
            text = output.read_text(encoding='utf-8')
            self.assertEqual(sum(line.startswith('v ') for line in text.splitlines()), 3)
            self.assertEqual(sum(line.startswith('vt ') for line in text.splitlines()), 3)
            self.assertEqual(sum(line.startswith('f ') for line in text.splitlines()), 1)

    def test_static_pose_glb_contains_skin(self):
        with tempfile.TemporaryDirectory() as temp:
            mesh_source = Path(temp) / 'test.mesh'
            skeleton_source = Path(temp) / 'test.skl'
            output = Path(temp) / 'test.glb'
            mesh_source.write_bytes(mesh_fixture())
            skeleton_source.write_bytes(skeleton_fixture())
            result = convert_glb(
                mesh_source, output, skeleton_source=skeleton_source,
                validate_rest_pose=False)
            payload = output.read_bytes()
            self.assertEqual(payload[:4], b'glTF')
            self.assertEqual(result['skin_joint_count'], 2)
            json_length = struct.unpack_from('<I', payload, 12)[0]
            gltf = json.loads(payload[20:20 + json_length].decode('utf-8'))
            self.assertEqual(gltf['asset']['version'], '2.0')
            self.assertEqual(len(gltf['skins'][0]['joints']), 2)
            attributes = gltf['meshes'][0]['primitives'][0]['attributes']
            self.assertIn('JOINTS_0', attributes)
            self.assertIn('WEIGHTS_0', attributes)
            binary_length = struct.unpack_from('<I', payload, 20 + json_length)[0]
            binary_start = 28 + json_length
            binary = payload[binary_start:binary_start + binary_length]
            inverse_accessor = gltf['accessors'][
                gltf['skins'][0]['inverseBindMatrices']]
            view = gltf['bufferViews'][inverse_accessor['bufferView']]
            start = view.get('byteOffset', 0) + inverse_accessor.get('byteOffset', 0)
            matrices = struct.unpack_from('<32f', binary, start)
            self.assertEqual(matrices[12:16], (0.0, 0.0, 0.0, 1.0))
            self.assertEqual(matrices[28:32], (-1.0, 0.0, 0.0, 1.0))

    def test_candidate_object_transforms_preserve_hierarchy_and_affect_bone_globals(self):
        skeleton = inspect_skeleton(object_skeleton_fixture())
        original_globals, _ = _compose_skeleton(skeleton)
        candidate_globals, _ = _compose_skeleton(skeleton, include_objects=True)
        self.assertEqual([row[3] for row in original_globals[42][:3]], [1.0, 2.0, 3.0])
        for actual, expected in zip(
                [row[3] for row in candidate_globals[42][:3]],
                [5.0, 14.0, 25.0], strict=True):
            self.assertAlmostEqual(actual, expected, places=5)

        with tempfile.TemporaryDirectory() as temp:
            mesh_source = Path(temp) / 'test.mesh'
            skeleton_source = Path(temp) / 'test.skl'
            output = Path(temp) / 'candidate.glb'
            mesh_source.write_bytes(mesh_fixture(skinned=False))
            skeleton_source.write_bytes(object_skeleton_fixture())
            result = convert_glb(
                mesh_source, output, skeleton_source=skeleton_source,
                include_object_transforms=True)
            payload = output.read_bytes()
            json_length = struct.unpack_from('<I', payload, 12)[0]
            gltf = json.loads(payload[20:20 + json_length].decode('utf-8'))
            nodes = {node['name']: (i, node) for i, node in enumerate(gltf['nodes'])}
            object_a_index, object_a = nodes['object_a']
            bone_index, bone = nodes['bone_a']
            object_b_index, object_b = nodes['object_b']
            self.assertEqual(object_a['translation'], [11.0, 12.0, 13.0])
            self.assertEqual(object_a['scale'], [2.0, 3.0, 4.0])
            self.assertIn(bone_index, object_a['children'])
            self.assertIn(object_b_index, bone['children'])
            self.assertEqual(object_b['translation'], [3.25, -4.5, 6.75])
            self.assertTrue(result['object_transforms_included'])
            self.assertEqual(result['object_transform_space'], 'unverified')
            self.assertEqual(gltf['asset']['extras']['objectTransformSpace'], 'unverified')

    def test_candidate_animation_is_bound_and_exported_to_glb(self):
        with tempfile.TemporaryDirectory() as temp:
            mesh_source = Path(temp) / 'test.mesh'
            skeleton_source = Path(temp) / 'test.skl'
            animation_source = Path(temp) / 'move.anm'
            output = Path(temp) / 'animated.glb'
            mesh_source.write_bytes(mesh_fixture())
            skeleton_raw = skeleton_fixture()
            skeleton_source.write_bytes(skeleton_raw)
            animation_source.write_bytes(animation_fixture(bone_only=True))
            result = convert_glb(
                mesh_source, output, skeleton_source=skeleton_source,
                validate_rest_pose=False, include_object_transforms=True,
                animation_sources=[animation_source],
                expected_skeleton_reference='skeletons/hero.skl',
                expected_skeleton_sha256=hashlib.sha256(skeleton_raw).hexdigest(),
            )
            payload = output.read_bytes()
            json_length = struct.unpack_from('<I', payload, 12)[0]
            gltf = json.loads(payload[20:20 + json_length].decode('utf-8'))
            binary_start = 28 + json_length
            binary = payload[binary_start:]
            self.assertTrue(result['animations_included'])
            self.assertEqual(result['animation_status'], 'candidate')
            self.assertEqual(len(gltf['animations']), 1)
            animation = gltf['animations'][0]
            self.assertEqual(animation['name'], 'move')
            node_names = [node['name'] for node in gltf['nodes']]
            channels = {
                (node_names[channel['target']['node']], channel['target']['path']): channel
                for channel in animation['channels']
            }
            translation_channel = channels[('bone_a', 'translation')]
            sampler = animation['samplers'][translation_channel['sampler']]
            self.assertEqual(sampler['interpolation'], 'STEP')

            def read_floats(accessor_index, width):
                accessor = gltf['accessors'][accessor_index]
                view = gltf['bufferViews'][accessor['bufferView']]
                start = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
                return struct.unpack_from(
                    f'<{accessor["count"] * width}f', binary, start)

            self.assertEqual(read_floats(sampler['output'], 3), (
                1.0, 2.0, 3.0, 2.0, 2.0, 3.0, 3.0, 2.0, 3.0,
            ))
            times = read_floats(sampler['input'], 1)
            self.assertEqual(len(times), 3)
            self.assertAlmostEqual(times[0], 0.0)
            self.assertAlmostEqual(times[-1], 0.1)

    def test_candidate_animation_requires_skeleton_expectations(self):
        with tempfile.TemporaryDirectory() as temp:
            mesh_source = Path(temp) / 'test.mesh'
            skeleton_source = Path(temp) / 'test.skl'
            animation_source = Path(temp) / 'move.anm'
            output = Path(temp) / 'animated.glb'
            mesh_source.write_bytes(mesh_fixture())
            skeleton_source.write_bytes(skeleton_fixture())
            animation_source.write_bytes(animation_fixture(bone_only=True))
            with self.assertRaisesRegex(ValueError, 'expected Skl reference and SHA-256'):
                convert_glb(
                    mesh_source, output, skeleton_source=skeleton_source,
                    validate_rest_pose=False, include_object_transforms=True,
                    animation_sources=[animation_source])
            self.assertFalse(output.exists())

    def test_rigid_attachments_preserve_body_and_follow_animated_object_hierarchy(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            body = folder / 'body.mesh'
            hair = folder / 'hair.mesh'
            accessory = folder / 'accessory.mesh'
            skeleton_source = folder / 'hero.skl'
            animation_source = folder / 'move.anm'
            body.write_bytes(mesh_fixture(single_bone=True))
            hair.write_bytes(mesh_fixture(skinned=False))
            accessory.write_bytes(mesh_fixture(skinned=False))
            skeleton_raw = object_skeleton_fixture()
            skeleton_source.write_bytes(skeleton_raw)
            animation_source.write_bytes(animation_fixture(bone_only=True))
            options = {
                'skeleton_source': skeleton_source,
                'validate_rest_pose': False,
                'include_object_transforms': True,
                'animation_sources': [animation_source],
                'expected_skeleton_reference': 'skeletons/hero.skl',
                'expected_skeleton_sha256': hashlib.sha256(skeleton_raw).hexdigest(),
            }
            baseline_path = folder / 'baseline.glb'
            attached_path = folder / 'attached.glb'
            convert_glb(body, baseline_path, **options)
            result = convert_glb(
                body, attached_path, **options,
                rigid_attachments=[(hair, 'object_b'), (accessory, 'object_a')])
            baseline, base_binary = read_glb(baseline_path)
            gltf, binary = read_glb(attached_path)

            # The body skin and primitive references remain intact.
            self.assertEqual(gltf['skins'], baseline['skins'])
            self.assertEqual(gltf['meshes'][0], baseline['meshes'][0])
            body_attributes = gltf['meshes'][0]['primitives'][0]['attributes']
            for attribute in ('POSITION', 'TEXCOORD_0', 'JOINTS_0', 'WEIGHTS_0'):
                self.assertEqual(
                    accessor_values(gltf, binary, body_attributes[attribute]),
                    accessor_values(baseline, base_binary, body_attributes[attribute]))
            names = {node['name']: index for index, node in enumerate(gltf['nodes'])}
            self.assertEqual(gltf['nodes'][names['body']]['skin'], 0)

            # object_b is a child of the animated bone; the rigid child inherits
            # that complete hierarchy without adding a second transform or skin.
            bone_index = names['bone_a']
            object_index = names['object_b']
            attachment_index = names['hair_rigid_attachment']
            self.assertIn(object_index, gltf['nodes'][bone_index]['children'])
            self.assertIn(attachment_index, gltf['nodes'][object_index]['children'])
            self.assertIn(names['accessory_rigid_attachment'],
                          gltf['nodes'][names['object_a']]['children'])
            attachment_node = gltf['nodes'][attachment_index]
            self.assertNotIn('skin', attachment_node)
            self.assertNotIn('matrix', attachment_node)
            self.assertNotIn('translation', attachment_node)
            self.assertNotIn('rotation', attachment_node)
            self.assertNotIn('scale', attachment_node)
            primitive = gltf['meshes'][attachment_node['mesh']]['primitives'][0]
            self.assertEqual(set(primitive['attributes']), {'POSITION', 'TEXCOORD_0'})
            self.assertEqual(accessor_values(
                gltf, binary, primitive['attributes']['POSITION']),
                [(0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)])
            self.assertEqual(accessor_values(
                gltf, binary, primitive['attributes']['TEXCOORD_0']),
                [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0)])
            self.assertEqual(accessor_values(gltf, binary, primitive['indices']),
                             [(0,), (1,), (2,)])
            self.assertIn('pbrMetallicRoughness', gltf['materials'][primitive['material']])

            metadata = attachment_node['extras']
            self.assertEqual(metadata['sourceMeshSha256'],
                             hashlib.sha256(hair.read_bytes()).hexdigest())
            self.assertEqual(metadata['targetNodeName'], 'object_b')
            self.assertEqual(metadata['targetNodeId'], 90)
            self.assertEqual(metadata['status'], 'candidate')
            self.assertEqual(metadata['placement'], 'unverified')
            self.assertEqual(gltf['asset']['extras']['rigidAttachments'][0], metadata)
            self.assertEqual(result['rigid_attachments'][0]['targetNodeId'], 90)
            self.assertEqual(result['rigid_attachments'][0]['status'], 'candidate')

            # Accessor indices can shift, but the animation targets and bytes
            # must describe the same motion as the export without attachments.
            def animation_tracks(document, payload):
                animation = document['animations'][0]
                tracks = {}
                for channel in animation['channels']:
                    target = channel['target']
                    name = document['nodes'][target['node']]['name']
                    sampler = animation['samplers'][channel['sampler']]
                    tracks[(name, target['path'])] = (
                        sampler['interpolation'],
                        accessor_values(document, payload, sampler['input']),
                        accessor_values(document, payload, sampler['output']),
                    )
                return tracks

            attached_tracks = animation_tracks(gltf, binary)
            self.assertEqual(attached_tracks, animation_tracks(baseline, base_binary))
            self.assertEqual(attached_tracks[('bone_a', 'translation')][2], [
                (1.0, 2.0, 3.0), (2.0, 2.0, 3.0), (3.0, 2.0, 3.0)])
            def attachment_origin(bone_translation):
                matrix = [
                    [1.0, 0.0, 0.0, 0.0],
                    [0.0, 1.0, 0.0, 0.0],
                    [0.0, 0.0, 1.0, 0.0],
                    [0.0, 0.0, 0.0, 1.0],
                ]
                for index in (0, names['object_a'], bone_index,
                              object_index, attachment_index):
                    node = gltf['nodes'][index]
                    transform = {
                        'position': (
                            bone_translation if index == bone_index
                            else node.get('translation', [0.0, 0.0, 0.0])),
                        'rotation_xyzw_unverified': node.get(
                            'rotation', [0.0, 0.0, 0.0, 1.0]),
                        'scale': node.get('scale', [1.0, 1.0, 1.0]),
                    }
                    matrix = _matrix_multiply(matrix, _local_matrix(transform))
                return [row[3] for row in matrix[:3]]

            first, last = attached_tracks[('bone_a', 'translation')][2][::2]
            start, end = attachment_origin(first), attachment_origin(last)
            for delta, expected in zip(
                    (b - a for a, b in zip(start, end, strict=True)),
                    (0.0, 0.0, -4.0), strict=True):
                self.assertAlmostEqual(delta, expected, places=5)

    def test_rigid_attachment_can_target_a_bone(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            body = folder / 'body.mesh'
            hair = folder / 'hair.mesh'
            skeleton_source = folder / 'hero.skl'
            output = folder / 'bone.glb'
            body.write_bytes(mesh_fixture(single_bone=True))
            hair.write_bytes(mesh_fixture(skinned=False))
            skeleton_source.write_bytes(object_skeleton_fixture())
            convert_glb(
                body, output,
                skeleton_source=skeleton_source,
                validate_rest_pose=False,
                include_object_transforms=True,
                rigid_attachments=[(hair, 'bone_a')])
            gltf, _binary = read_glb(output)
            names = {node['name']: index for index, node in enumerate(gltf['nodes'])}
            attachment = gltf['nodes'][names['hair_rigid_attachment']]
            self.assertIn(names['hair_rigid_attachment'],
                          gltf['nodes'][names['bone_a']]['children'])
            self.assertNotIn('skin', attachment)
            self.assertNotIn('matrix', attachment)
            self.assertEqual(attachment['extras']['targetNodeName'], 'bone_a')
            self.assertEqual(attachment['extras']['status'], 'candidate')

    def test_rigid_attachment_errors_do_not_write_output(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            body = folder / 'body.mesh'
            rigid = folder / 'rigid.mesh'
            skinned = folder / 'skinned.mesh'
            malformed = folder / 'bad.mesh'
            skeleton_source = folder / 'hero.skl'
            output = folder / 'candidate.glb'
            body.write_bytes(mesh_fixture(skinned=False))
            rigid.write_bytes(mesh_fixture(skinned=False))
            skinned.write_bytes(mesh_fixture())
            malformed.write_bytes(mesh_fixture(skinned=False, bad_index=True))
            skeleton_source.write_bytes(object_skeleton_fixture())
            cases = [
                {'rigid_attachments': [(rigid, 'object_a')]},
                {'skeleton_source': skeleton_source,
                 'rigid_attachments': [(rigid, 'object_a')]},
                {'skeleton_source': skeleton_source, 'include_object_transforms': True,
                 'rigid_attachments': [(rigid, 'missing')]},
                {'skeleton_source': skeleton_source, 'include_object_transforms': True,
                 'rigid_attachments': [(rigid, 'OBJECT_A')]},
                {'skeleton_source': skeleton_source, 'include_object_transforms': True,
                 'rigid_attachments': [(skinned, 'object_a')]},
                {'skeleton_source': skeleton_source, 'include_object_transforms': True,
                 'rigid_attachments': [(malformed, 'object_a')]},
                {'skeleton_source': skeleton_source, 'include_object_transforms': True,
                 'rigid_attachments': [(folder / 'missing.mesh', 'object_a')]},
                {'skeleton_source': skeleton_source, 'include_object_transforms': True,
                 'rigid_attachments': [(rigid,)]},
                {'skeleton_source': skeleton_source, 'include_object_transforms': True,
                 'rigid_attachments': [(rigid, 'object_a')] * 17},
            ]
            for options in cases:
                with self.subTest(options=options):
                    with self.assertRaises((GltfExportError, KdfError, OSError)):
                        convert_glb(body, output, **options)
                    self.assertFalse(output.exists())
            duplicate = inspect_skeleton(object_skeleton_fixture())
            duplicate['nodes'][-1]['name'] = 'object_a'
            with patch('character_to_gltf.inspect_skeleton_file', return_value=duplicate):
                with self.assertRaisesRegex(GltfExportError, 'unique Skl object'):
                    convert_glb(
                        body, output, skeleton_source=skeleton_source,
                        include_object_transforms=True,
                        rigid_attachments=[(rigid, 'object_a')])
            self.assertFalse(output.exists())

    def test_rigid_attachment_cli_accepts_repeated_mesh_and_node_pairs(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            body = folder / 'body.mesh'
            first = folder / 'first.mesh'
            second = folder / 'second.mesh'
            skeleton = folder / 'hero.skl'
            output = folder / 'attached.glb'
            for path in (body, first, second):
                path.write_bytes(mesh_fixture(skinned=False))
            skeleton.write_bytes(object_skeleton_fixture())
            script = Path(__file__).resolve().parents[1] / 'tools' / 'character_to_gltf.py'
            run = subprocess.run([
                sys.executable, '-B', '-X', 'utf8', str(script), str(body),
                '--skeleton', str(skeleton), '--include-object-transforms',
                '--rigid-attachment', str(first), 'object_a',
                '--rigid-attachment', str(second), 'object_b',
                '--output', str(output),
            ], capture_output=True, text=True, encoding='utf-8', check=False)
            self.assertEqual(run.returncode, 0, run.stderr)
            report = json.loads(run.stdout)
            self.assertEqual(
                [item['targetNodeName'] for item in report['rigid_attachments']],
                ['object_a', 'object_b'])
            document, _ = read_glb(output)
            self.assertEqual(len(document['asset']['extras']['rigidAttachments']), 2)

    def test_rest_pose_validation_reports_complete_skin_matrix_error(self):
        angle = 1e-3
        cosine = math.cos(angle)
        sine = math.sin(angle)
        mesh = {
            'skeleton': {
                'names': ['joint'],
                'positions': [[100.0, 0.0, 0.0]],
                'rotations_xyzw': [[0.0, 0.0, 0.0, 1.0]],
                'bind_translations': [[-100.0, 0.0, 0.0]],
                'bind_matrices': [[
                    1.0, 0.0, 0.0, -100.0,
                    0.0, 1.0, 0.0, 0.0,
                    0.0, 0.0, 1.0, 0.0,
                ]],
            },
            'position_min': [-100.0, -1.0, -1.0],
            'position_max': [100.0, 1.0, 1.0],
            'vertices': [{
                'position': [0.0, 0.0, 0.0],
                'bone_indices_global': [0, 0, 0, 0],
                'weights': [1.0, 0.0, 0.0, 0.0],
            }],
        }
        skeleton = {
            'joint': {
                'matrix': [
                    [cosine, -sine, 0.0, 100.0],
                    [sine, cosine, 0.0, 0.0],
                    [0.0, 0.0, 1.0, 0.0],
                    [0.0, 0.0, 0.0, 1.0],
                ],
            },
        }
        result = _validate_rest_pose(mesh, skeleton)
        self.assertEqual(result['position_max_error'], 0.0)
        self.assertAlmostEqual(result['rotation_max_error'], 1e-3, places=7)
        self.assertAlmostEqual(
            result['skin_matrix_rotation_max_error'], 1e-3, places=7)
        self.assertAlmostEqual(
            result['skin_matrix_translation_max_error'], 0.1, places=7)
        self.assertAlmostEqual(
            result[
                'skin_matrix_translation_max_error_relative_to_model_span'],
            5e-4,
            places=7,
        )
        self.assertAlmostEqual(
            result['skin_vertex_max_displacement'], 0.1, places=7)
        self.assertAlmostEqual(
            result['skin_vertex_max_displacement_relative_to_model_span'],
            5e-4,
            places=7,
        )
        self.assertEqual(result['worst_skin_vertex'], 0)
        self.assertEqual(result['worst_skin_translation_joint'], 'joint')


if __name__ == '__main__':
    unittest.main()

import json
import math
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_data import KdfError
from kdf_mesh import inspect_mesh
from mesh_to_obj import convert_file
from character_to_gltf import _validate_rest_pose
from character_to_gltf import convert_file as convert_glb
from test_kdf_skeleton import skeleton_fixture


def descriptor(count: int, stride: int) -> int:
    return 0x40000000 | (stride << 21) | count


def mesh_fixture(*, skinned=True, bad_index=False) -> bytes:
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
            (descriptor(2, 1), 4),
            (0x60000000, strings.index('skl')),
            (0x30000005, 1),
            (0x60000000, strings.index('names')),
            (descriptor(2, 0), 4),
            (0x60000000, strings.index('positions')),
            (descriptor(2, 12), 5),
            (0x60000000, strings.index('rotations')),
            (descriptor(2, 16), 6),
            (0x60000000, strings.index('transforms')),
            (descriptor(2, 48), 7),
            (0x60000000, strings.index('bv')),
            (descriptor(2, 0), 4),
            (0x60000000, strings.index('bone_a')),
            (0x60000000, strings.index('bone_b')),
        ])
        groups.extend([
            b'\x00\x01',
            struct.pack('<6f', 0, 0, 0, 1, 0, 0),
            struct.pack('<8f', 0, 0, 0, 1, 0, 0, 0, 1),
            struct.pack(
                '<24f',
                1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0,
                1, 0, 0, -1, 0, 1, 0, 0, 0, 0, 1, 0,
            ),
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


class TestKdfMesh(unittest.TestCase):
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
            },
            'position_min': [-100.0, -1.0, -1.0],
            'position_max': [100.0, 1.0, 1.0],
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
        self.assertEqual(result['worst_skin_translation_joint'], 'joint')


if __name__ == '__main__':
    unittest.main()

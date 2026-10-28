import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_data import KdfError
from kdf_skeleton import inspect_skeleton


NODES = [
    ('root', 0, -2, 3, 0),
    ('bone', 2, 0, 2, 1),
    ('bone', 4, 2, 1, 2),
]


def skeleton_fixture(
        nodes=None, *, rotations=None, position_indices=None) -> bytes:
    nodes = NODES if nodes is None else nodes
    strings = [
        'type', 'nodeid', 'parentid', 'treesize', 'offset',
        'root', 'object', 'bone', 'scales', 'bonepos', 'bonerot',
    ]
    records = []

    def value_record(marker, value):
        records.append((marker, value & 0xffffffff))

    def property_value(key, value, marker=0):
        records.append((0x60000000, strings.index(key)))
        value_record(marker, value)

    bone_index = 0
    for type_name, nodeid, parentid, treesize, offset in nodes:
        property_value('type', strings.index(type_name), 0x60000000)
        property_value('nodeid', nodeid)
        property_value('parentid', parentid, 0x10000000)
        property_value('treesize', treesize)
        property_value('offset', offset, 0x30000000)
        if type_name == 'bone':
            property_value('scales', bone_index)
            property_value('bonepos', bone_index)
            property_value('bonerot', bone_index)
            bone_index += 1

    raw = bytearray(b'1FDKENONCTX3' + struct.pack('<IIII', len(strings), 1, 0, len(strings)))
    for text in strings:
        encoded = text.encode()
        identifier = (zlib.crc32(encoded) + len(encoded)) & 0xffffffff
        raw += struct.pack('<II', identifier, len(encoded)) + encoded + b'\0'
    raw += b'\0'

    positions = struct.pack('<6f', 1, 2, 3, 4, 5, 6)
    position_indices = position_indices or struct.pack('<2H', 0, 1)
    rotations = rotations or struct.pack('<8f', 0, 0, 0, 1, 0, 0, 0, 1)
    rotation_indices = struct.pack('<2H', 0, 1)
    scales = struct.pack('<6f', 1, 1, 1, 2, 2, 2)
    scale_indices = struct.pack('<2H', 0, 1)
    groups = (
        positions, position_indices, b'', b'', rotations, rotation_indices,
        b'', b'', scales, scale_indices,
    )
    offsets = [0, 0]
    for group in groups[:-1]:
        offsets.append(offsets[-1] + len(group))
    payload = b''.join(groups)
    raw += b'DATA'
    raw += struct.pack('<IIII', len(records), len(groups), 0, len(payload))
    raw += struct.pack(f'<{len(offsets)}I', *offsets)
    for record in records:
        raw += struct.pack('<II', *record)
    raw += payload + b'skeleton-ident!!'
    return bytes(raw)


class TestKdfSkeleton(unittest.TestCase):
    def test_hierarchy_names_and_subtree_sizes(self):
        result = inspect_skeleton(skeleton_fixture())
        self.assertEqual(result['node_count'], 3)
        self.assertEqual(result['roots'], [0])
        self.assertEqual([node['type'] for node in result['nodes']], ['root', 'bone', 'bone'])
        self.assertEqual(result['nodes'][0]['children'], [2])
        self.assertEqual(result['nodes'][1]['children'], [4])
        self.assertEqual(result['bone_position_indices'], [0, 1])
        self.assertEqual(result['bone_rotation_indices'], [0, 1])
        self.assertEqual(result['scale_indices'], [0, 1])
        self.assertEqual(result['static_transforms'][0]['position'], [1.0, 2.0, 3.0])
        self.assertEqual(result['static_transforms'][1]['scale'], [2.0, 2.0, 2.0])
        self.assertEqual(result['transform_coordinate_space'], 'unverified')

    def test_missing_parent_and_bad_subtree_size_are_rejected(self):
        missing_parent = [
            NODES[0],
            ('bone', 2, 99, 1, 1),
        ]
        with self.assertRaisesRegex(KdfError, 'missing parent'):
            inspect_skeleton(skeleton_fixture(missing_parent))
        bad_size = [NODES[0], ('bone', 2, 0, 5, 1)]
        with self.assertRaisesRegex(KdfError, 'treesize'):
            inspect_skeleton(skeleton_fixture(bad_size))

    def test_static_transform_sections_are_validated(self):
        with self.assertRaisesRegex(KdfError, 'position index section'):
            inspect_skeleton(skeleton_fixture(position_indices=struct.pack('<2H', 1, 0)))
        with self.assertRaisesRegex(KdfError, 'rotation norm'):
            inspect_skeleton(skeleton_fixture(
                rotations=struct.pack('<8f', 0, 0, 0, 2, 0, 0, 0, 1)))

    def test_cli_outputs_hierarchy_json(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / 'bruce.skl'
            source.write_bytes(skeleton_fixture())
            script = Path(__file__).resolve().parents[1] / 'tools' / 'kdf_skeleton.py'
            run = subprocess.run(
                [sys.executable, '-X', 'utf8', str(script), str(source)],
                capture_output=True, text=True, encoding='utf-8', check=False,
            )
            self.assertEqual(run.returncode, 0, run.stderr)
            report = json.loads(run.stdout)
            self.assertEqual(report['roots'], [0])
            self.assertEqual(report['nodes'][2]['parentid'], 2)


if __name__ == '__main__':
    unittest.main()

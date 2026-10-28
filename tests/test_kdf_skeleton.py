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


def skeleton_fixture(nodes=None) -> bytes:
    nodes = NODES if nodes is None else nodes
    strings = [
        'type', 'nodeid', 'parentid', 'treesize', 'offset',
        'root', 'bone', 'bonepos', 'bonerot',
    ]
    records = []

    def scalar(key, value):
        records.append((0x60000000, strings.index(key)))
        records.append((0, value & 0xffffffff))

    for type_name, nodeid, parentid, treesize, offset in nodes:
        scalar('type', strings.index(type_name))
        scalar('nodeid', nodeid)
        scalar('parentid', parentid)
        scalar('treesize', treesize)
        scalar('offset', offset)
    scalar('bonepos', 0)
    scalar('bonepos', 1)
    scalar('bonerot', 0)
    scalar('bonerot', 1)

    raw = bytearray(b'1FDKENONCTX3' + struct.pack('<IIII', len(strings), 1, 0, len(strings)))
    for text in strings:
        encoded = text.encode()
        identifier = (zlib.crc32(encoded) + len(encoded)) & 0xffffffff
        raw += struct.pack('<II', identifier, len(encoded)) + encoded + b'\0'
    raw += b'\0'
    raw += b'DATA'
    raw += struct.pack('<IIII', len(records), 1, 0, 1)
    raw += struct.pack('<II', 0, 0)
    for record in records:
        raw += struct.pack('<II', *record)
    raw += b'x' + b'skeleton-ident!!'
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

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
from kdf_skeleton import inspect_skeleton


NODES = [
    ('root', 0, -2, 3, 0),
    ('bone', 2, 0, 2, 1),
    ('bone', 4, 2, 1, 2),
]


def skeleton_fixture(
        nodes=None, *, rotations=None, position_indices=None,
        name_pointer_delta=0, append_trailing_sample=False) -> bytes:
    nodes = NODES if nodes is None else nodes
    strings = [
        'type', 'nodeid', 'parentid', 'treesize', 'offset',
        'root', 'object', 'bone', 'scales', 'bonepos', 'bonerot',
        'root_node', 'object_node', 'bone_a', 'bone_b',
        'rawfloatsample',
    ]
    node_records = []

    def value_record(marker, value):
        node_records.append((marker, value & 0xffffffff))

    def property_value(key, value, marker=0):
        node_records.append((0x60000000, strings.index(key)))
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

    node_starts = []
    cursor = len(nodes) * 2
    for type_name, *_ in nodes:
        node_starts.append(cursor)
        length = 16 if type_name == 'bone' else 10
        cursor += length
    name_ordinals = []
    bone_name_index = 0
    for type_name, *_ in nodes:
        if type_name == 'bone':
            name = 'bone_a' if bone_name_index == 0 else 'bone_b'
            bone_name_index += 1
        else:
            name = 'root_node' if type_name == 'root' else 'object_node'
        name_ordinals.append(strings.index(name))
    records = []
    for table_index, (target, string_ordinal) in enumerate(
            zip(node_starts, name_ordinals, strict=True)):
        pointer_record = table_index * 2 + 1
        relative = target - pointer_record + name_pointer_delta
        records.append((0x60000000, string_ordinal))
        records.append((0x30000005, relative & 0xffffffff))
    records.extend(node_records)
    if append_trailing_sample:
        records.extend([
            (0x60000000, strings.index('type')),
            (0x60000000, strings.index('rawfloatsample')),
            (0x41800002, 0),
        ])

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


def object_skeleton_fixture(
        *, position_indices=(1, 0), rotation_indices=(0, 1),
        object_scales=(2, 0), position_order=(0, 1), rotation_order=(0, 1),
        positions=None, rotations=None, scales=None,
        first_position_marker=0, duplicate_position=False,
        broken_sample_pointer=False, section_count=10) -> bytes:
    strings = [
        'type', 'nodeid', 'parentid', 'treesize', 'offset',
        'root', 'object', 'bone', 'scales', 'bonepos', 'bonerot',
        'positions', 'rotations', 'root_node', 'object_a', 'bone_a', 'object_b',
        'rawfloatsample', 'data',
    ]
    nodes = [
        ('root', 100, -2, 4, 'root_node'),
        ('object', 17, 100, 3, 'object_a'),
        ('bone', 42, 17, 2, 'bone_a'),
        ('object', 90, 42, 1, 'object_b'),
    ]
    node_records = []
    node_starts = []
    object_ordinal = 0

    def property_value(key, value, marker=0):
        node_records.append((0x60000000, strings.index(key)))
        node_records.append((marker, value & 0xffffffff))

    for type_name, nodeid, parentid, treesize, _ in nodes:
        node_starts.append(len(nodes) * 2 + len(node_records))
        property_value('type', strings.index(type_name), 0x60000000)
        property_value('nodeid', nodeid)
        property_value('parentid', parentid, 0x10000000)
        property_value('treesize', treesize)
        property_value('offset', 0, 0x30000000)
        if type_name == 'bone':
            property_value('scales', 1)
            property_value('bonepos', 0)
            property_value('bonerot', 0)
        elif type_name == 'object':
            marker = first_position_marker if object_ordinal == 0 else 0
            property_value('positions', position_indices[object_ordinal], marker)
            if duplicate_position and object_ordinal == 0:
                property_value('positions', position_indices[object_ordinal])
            property_value('rotations', rotation_indices[object_ordinal])
            property_value('scales', object_scales[object_ordinal])
            object_ordinal += 1

    records = []
    for table_index, (node, start) in enumerate(zip(nodes, node_starts, strict=True)):
        records.append((0x60000000, strings.index(node[4])))
        records.append((0x30000005, start - (table_index * 2 + 1)))
    records.extend(node_records)
    declaration_start = len(records)
    sample_names = ('bonepos', 'positions', 'bonerot', 'rotations', 'scales')
    for ordinal, name in enumerate(sample_names):
        pointer_ordinal = declaration_start + ordinal * 2 + 1
        sample_start = declaration_start + len(sample_names) * 2 + ordinal * 6
        relative = sample_start - pointer_ordinal
        if broken_sample_pointer and name == 'positions':
            relative += 1
        records.extend([
            (0x60000000, strings.index(name)),
            (0x30000003, relative),
        ])
    for ordinal, (count, stride) in enumerate(
            ((1, 12), (2, 12), (1, 16), (2, 16), (3, 12))):
        records.extend([
            (0x60000000, strings.index('type')),
            (0x60000000, strings.index('rawfloatsample')),
            (0x60000000, strings.index('data')),
            (0x40000000 | (stride << 21) | count, ordinal * 2),
            (0x60000000, strings.index('offset')),
            (0x40000000 | (2 << 21) | count, ordinal * 2 + 1),
        ])

    raw = bytearray(b'1FDKENONCTX3' + struct.pack('<IIII', len(strings), 1, 0, len(strings)))
    for text in strings:
        encoded = text.encode()
        identifier = (zlib.crc32(encoded) + len(encoded)) & 0xffffffff
        raw += struct.pack('<II', identifier, len(encoded)) + encoded + b'\0'
    raw += b'\0'

    half_turn = math.sqrt(0.5)
    if positions is None:
        positions = struct.pack('<6f', 3.25, -4.5, 6.75, 11, 12, 13)
    if rotations is None:
        rotations = struct.pack(
            '<8f', 0, 0, half_turn, half_turn, half_turn, 0, 0, half_turn)
    if scales is None:
        scales = struct.pack('<9f', 0.5, 1.5, 2, 1.25, 1.25, 1.25, 2, 3, 4)
    groups = [
        struct.pack('<3f', 1, 2, 3), struct.pack('<2H', 0, 0),
        positions, struct.pack('<2H', *position_order),
        struct.pack('<4f', 0, 0, 0, 1), struct.pack('<2H', 0, 0),
        rotations, struct.pack('<2H', *rotation_order),
        scales, struct.pack('<4H', 0, 1, 2, 0),
    ]
    if section_count < len(groups):
        groups = groups[:section_count]
    else:
        groups.extend([b'\0\0\0\0'] * (section_count - len(groups)))
    offsets = [0, 0]
    for group in groups[:-1]:
        offsets.append(offsets[-1] + len(group))
    payload = b''.join(groups)
    raw += b'DATA'
    raw += struct.pack('<IIII', len(records), len(groups), 0, len(payload))
    raw += struct.pack(f'<{len(offsets)}I', *offsets)
    for record in records:
        raw += struct.pack('<II', *record)
    raw += payload + b'test-identity!!!'
    return bytes(raw)


class TestKdfSkeleton(unittest.TestCase):
    def test_legacy_object_hierarchy_without_transform_samples_remains_readable(self):
        nodes = [
            ('root', 0, -2, 4, 0), ('object', 1, 0, 3, 1),
            ('bone', 2, 1, 2, 2), ('bone', 4, 2, 1, 3),
        ]
        result = inspect_skeleton(skeleton_fixture(nodes))
        self.assertEqual(result['node_count'], 4)
        self.assertEqual(result['nodes'][1]['type'], 'object')
        self.assertEqual(result['nodes'][1]['children'], [2])
        self.assertIsNone(result['object_position_indices'])
        self.assertIsNone(result['object_static_transforms'])

    def test_hierarchy_names_and_subtree_sizes(self):
        result = inspect_skeleton(skeleton_fixture())
        self.assertEqual(result['node_count'], 3)
        self.assertEqual(result['roots'], [0])
        self.assertEqual([node['name'] for node in result['nodes']], [
            'root_node', 'bone_a', 'bone_b',
        ])
        self.assertEqual([node['type'] for node in result['nodes']], ['root', 'bone', 'bone'])
        self.assertEqual(result['nodes'][0]['children'], [2])
        self.assertEqual(result['nodes'][1]['children'], [4])
        self.assertEqual(result['bone_position_indices'], [0, 1])
        self.assertEqual(result['bone_rotation_indices'], [0, 1])
        self.assertEqual(result['object_position_indices'], [])
        self.assertEqual(result['object_rotation_indices'], [])
        self.assertEqual(result['scale_indices'], [0, 1])
        self.assertEqual(result['static_transforms'][0]['position'], [1.0, 2.0, 3.0])
        self.assertEqual(result['static_transforms'][1]['scale'], [2.0, 2.0, 2.0])
        self.assertEqual(result['object_static_transforms'], [])
        self.assertEqual(result['transform_coordinate_space'], 'unverified')
        self.assertEqual(result['nodes'][-1]['record_end'], len(result['nodes']) * 2 + 42)

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

    def test_name_pointer_must_target_node_start(self):
        with self.assertRaisesRegex(KdfError, 'does not target its node'):
            inspect_skeleton(skeleton_fixture(name_pointer_delta=1))

    def test_missing_node_records_are_rejected(self):
        with self.assertRaisesRegex(KdfError, 'no Skl node records found'):
            inspect_skeleton(skeleton_fixture([
                ('rawfloatsample', 0, -2, 1, 0),
            ]))

    def test_last_node_stops_before_trailing_sample_records(self):
        result = inspect_skeleton(skeleton_fixture(append_trailing_sample=True))
        self.assertEqual(result['nodes'][-1]['record_start'], 32)
        self.assertEqual(result['nodes'][-1]['record_end'], 48)

    def test_static_transform_sections_are_validated(self):
        with self.assertRaisesRegex(KdfError, 'position index section'):
            inspect_skeleton(skeleton_fixture(position_indices=struct.pack('<2H', 1, 0)))
        with self.assertRaisesRegex(KdfError, 'rotation norm'):
            inspect_skeleton(skeleton_fixture(
                rotations=struct.pack('<8f', 0, 0, 0, 2, 0, 0, 0, 1)))

    def test_object_transforms_follow_indices_with_shared_scale_domain(self):
        result = inspect_skeleton(object_skeleton_fixture())
        self.assertEqual([node['nodeid'] for node in result['nodes']], [100, 17, 42, 90])
        self.assertEqual(result['object_position_indices'], [1, 0])
        self.assertEqual(result['object_rotation_indices'], [0, 1])
        self.assertEqual(result['nodes'][1]['object_position_index'], 1)
        self.assertEqual(result['nodes'][3]['object_rotation_index'], 1)
        self.assertEqual([item['nodeid'] for item in result['static_transforms']], [42])
        self.assertEqual(result['static_transforms'][0]['scale'], [1.25, 1.25, 1.25])
        objects = result['object_static_transforms']
        self.assertEqual([item['nodeid'] for item in objects], [17, 90])
        self.assertEqual(objects[0]['position'], [11.0, 12.0, 13.0])
        self.assertEqual(objects[0]['scale'], [2.0, 3.0, 4.0])
        self.assertAlmostEqual(objects[0]['rotation_xyzw_unverified'][2], math.sqrt(0.5))
        self.assertEqual(objects[1]['position'], [3.25, -4.5, 6.75])
        self.assertEqual(objects[1]['scale'], [0.5, 1.5, 2.0])
        self.assertAlmostEqual(objects[1]['rotation_xyzw_unverified'][0], math.sqrt(0.5))

    def test_object_indices_reject_duplicates_and_out_of_range(self):
        for kwargs, pattern in (
                ({'position_indices': (0, 0)}, 'object position indices contain duplicates'),
                ({'rotation_indices': (1, 1)}, 'object rotation indices contain duplicates'),
                ({'position_indices': (0, 2)}, 'object position index is out of range'),
                ({'rotation_indices': (2, 0)}, 'object rotation index is out of range'),
                ({'object_scales': (1, 0)}, 'scales indices'),
                ({'object_scales': (3, 0)}, 'scales indices')):
            with self.subTest(kwargs=kwargs):
                with self.assertRaisesRegex(KdfError, pattern):
                    inspect_skeleton(object_skeleton_fixture(**kwargs))

    def test_object_index_sections_and_property_markers_are_validated(self):
        for kwargs, pattern in (
                ({'position_order': (1, 0)}, 'object position index section'),
                ({'rotation_order': (1, 0)}, 'object rotation index section'),
                ({'first_position_marker': 0x10000000}, 'requires one scalar'),
                ({'duplicate_position': True}, 'requires one scalar'),
                ({'broken_sample_pointer': True}, 'sample declaration is invalid'),
                ({'section_count': 9}, 'sample array layout|observed 10-section layout'),
                ({'section_count': 11}, 'observed 10-section layout'),
                ({'positions': struct.pack('<3f', 1, 2, 3)},
                 'array descriptor|vector section 2')):
            with self.subTest(kwargs=kwargs):
                with self.assertRaisesRegex(KdfError, pattern):
                    inspect_skeleton(object_skeleton_fixture(**kwargs))

    def test_object_transforms_reject_nonfinite_and_nonunit_values(self):
        good_rotation = (0.0, 0.0, 0.0, 1.0)
        for kwargs, pattern in (
                ({'positions': struct.pack('<6f', 0, 0, 0, math.nan, 1, 2)},
                 'transform is not finite'),
                ({'scales': struct.pack('<9f', 1, 1, 1, 1, 1, 1, math.inf, 1, 1)},
                 'transform is not finite'),
                ({'rotations': struct.pack('<8f', 0, 0, 0, 2, *good_rotation)},
                 'rotation norm'),
                ({'rotations': struct.pack('<8f', 0, 0, 0, 0, *good_rotation)},
                 'rotation norm'),
                ({'rotations': struct.pack('<8f', 0, 0, 0, math.nan, *good_rotation)},
                 'transform is not finite')):
            with self.subTest(kwargs=kwargs):
                with self.assertRaisesRegex(KdfError, pattern):
                    inspect_skeleton(object_skeleton_fixture(**kwargs))

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

import copy
import json
import math
from pathlib import Path
import struct
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from gltf_animation import build_animations
from kdf_data import KdfError


class BufferBuilder:
    def __init__(self):
        self.data = bytearray(b'\x7f')
        self.views = []

    def add(self, payload):
        while len(self.data) % 4:
            self.data.append(0)
        self.views.append({
            'buffer': 0, 'byteOffset': len(self.data), 'byteLength': len(payload),
        })
        self.data.extend(payload)
        return len(self.views) - 1


def synthetic_fixture(duration=5):
    root_half = math.sqrt(0.5)
    rotation_z = [0.0, 0.0, root_half, root_half]
    skeleton = {
        'sha256': '1' * 64,
        'nodes': [
            {'nodeid': 1, 'type': 'root'},
            {'nodeid': 7, 'type': 'object', 'object_position_index': 0, 'scale_index': 0},
            {'nodeid': 23, 'type': 'bone', 'bone_position_index': 0,
             'bone_rotation_index': 0, 'scale_index': 1},
            {'nodeid': 71, 'type': 'bone', 'bone_position_index': 1,
             'bone_rotation_index': 1, 'scale_index': 2},
        ],
        'static_transforms': [
            {'nodeid': 23, 'position': [10.0, 20.0, 30.0],
             'rotation_xyzw_unverified': rotation_z, 'scale': [2.0, 3.0, 4.0]},
            {'nodeid': 71, 'position': [0.0, 1.0, 0.0],
             'rotation_xyzw_unverified': [0.0, 0.0, 0.0, 1.0], 'scale': [1.0, 1.0, 1.0]},
        ],
        'object_static_transforms': [
            {'nodeid': 7, 'position': [2.0, 3.0, 4.0],
             'rotation_xyzw_unverified': rotation_z, 'scale': [10.0, 20.0, 30.0]},
        ],
    }
    rotation_x = [root_half, 0.0, 0.0, root_half]
    animated_rotations = [
        rotation_x if index % 2 == 0 else [-component for component in rotation_x]
        for index in range(duration)
    ]
    bindings = [
        {'nodeid': 23, 'node_type': 'bone', 'track': 'bonepos', 'target': 'translation',
         'index_field': 'bone_position_index', 'offset': 0, 'layout': 'per-frame',
         'values': [[1.0, 0.0, 0.0] for _ in range(duration)]},
        {'nodeid': 23, 'node_type': 'bone', 'track': 'bonerot', 'target': 'rotation',
         'index_field': 'bone_rotation_index', 'offset': 0, 'layout': 'per-frame',
         'values': animated_rotations},
        {'nodeid': 23, 'node_type': 'bone', 'track': 'scales', 'target': 'scale',
         'index_field': 'scale_index', 'offset': 1, 'layout': 'constant',
         'values': [[1.5, 1.25, 0.75]]},
        {'nodeid': 7, 'node_type': 'object', 'track': 'positions', 'target': 'translation',
         'index_field': 'object_position_index', 'offset': 0, 'layout': 'per-frame',
         'values': [[1.0, 0.0, 0.0] for _ in range(duration)]},
        {'nodeid': 7, 'node_type': 'object', 'track': 'scales', 'target': 'scale',
         'index_field': 'scale_index', 'offset': 0, 'layout': 'constant',
         'values': [[0.5, 1.0, 1.5]]},
    ]
    bound = {
        'status': 'candidate',
        'pairing_status': 'matched-provided-reference-and-hash',
        'animation_sha256': 'a' * 64,
        'skeleton_sha256': '1' * 64,
        'skeleton_reference': {'reference': 'skeletons/hero.skl'},
        'headers': {
            'firstframe': 0, 'duration': duration, 'framerate': 30,
            'version': 7, 'pose': 1,
        },
        'bindings': bindings,
    }
    node_map = {1: 0, 7: 3, 23: 5, 71: 8}
    return skeleton, node_map, bound


def read_accessor(builder, accessors, index):
    accessor = accessors[index]
    view = builder.views[accessor['bufferView']]
    components = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[accessor['type']]
    values = struct.unpack_from(
        f'<{accessor["count"] * components}f', builder.data, view['byteOffset'])
    return [values[index:index + components] for index in range(0, len(values), components)]


class TestGltfAnimation(unittest.TestCase):
    def setUp(self):
        self.skeleton, self.node_map, self.bound = synthetic_fixture()
        self.builder = BufferBuilder()
        self.accessors = [{'existing': True}]

    def build(self, bound=None, skeleton=None, node_map=None):
        return build_animations(
            self.builder, self.accessors,
            self.node_map if node_map is None else node_map,
            self.skeleton if skeleton is None else skeleton,
            [('candidate', self.bound if bound is None else bound)],
        )[0]

    def test_pose_composition_time_and_accessor_structure(self):
        clip = self.build()
        self.assertEqual(clip['name'], 'candidate')
        self.assertEqual(clip['extras']['durationMsCandidate'], 166)
        self.assertEqual(clip['extras']['rootMotionWorldApplication'], 'unverified')
        self.assertEqual(
            clip['extras']['objectPositionBinding'],
            'object-index-candidate-root-player-unverified')
        self.assertEqual(
            clip['extras']['objectPositionComposition'],
            'pose-1-formula-candidate-unverified')
        self.assertEqual(
            clip['extras']['scaleOutput'], 'direct-track-value-candidate-unverified')
        self.assertEqual(clip['extras']['nativeRuntimeComparison'], 'unverified')
        self.assertEqual(clip['extras']['godotPlayback'], 'unverified')
        json.dumps(clip, allow_nan=False)
        by_target = {
            (channel['target']['node'], channel['target']['path']):
            clip['samplers'][channel['sampler']]
            for channel in clip['channels']
        }
        self.assertNotIn(8, [channel['target']['node'] for channel in clip['channels']])
        self.assertEqual(len(by_target), 5)
        self.assertTrue(all(sampler['interpolation'] == 'STEP'
                            for sampler in clip['samplers']))
        for view in self.builder.views:
            self.assertEqual(view['byteOffset'] % 4, 0)
        for accessor in self.accessors[1:]:
            self.assertEqual(accessor['componentType'], 5126)

        translation = by_target[(5, 'translation')]
        time_accessor = self.accessors[translation['input']]
        times = read_accessor(self.builder, self.accessors, translation['input'])
        self.assertEqual(time_accessor['type'], 'SCALAR')
        self.assertEqual(time_accessor['min'], [0.0])
        self.assertEqual(time_accessor['max'], [times[-1][0]])
        self.assertEqual(len(times), 5)
        self.assertAlmostEqual(times[-1][0], 0.166, places=6)
        self.assertTrue(all(a[0] < b[0] for a, b in zip(times, times[1:])))
        bone_translation = read_accessor(self.builder, self.accessors, translation['output'])
        self.assertEqual(self.accessors[translation['output']]['type'], 'VEC3')
        self.assertAlmostEqual(bone_translation[0][0], 10.0)
        self.assertAlmostEqual(bone_translation[0][1], 21.0)
        self.assertAlmostEqual(bone_translation[0][2], 30.0)

        object_translation = read_accessor(
            self.builder, self.accessors, by_target[(3, 'translation')]['output'])
        self.assertAlmostEqual(object_translation[0][0], 2.0)
        self.assertAlmostEqual(object_translation[0][1], 4.0)
        self.assertAlmostEqual(object_translation[0][2], 4.0)

        rotation_sampler = by_target[(5, 'rotation')]
        rotations = read_accessor(self.builder, self.accessors, rotation_sampler['output'])
        self.assertEqual(self.accessors[rotation_sampler['output']]['type'], 'VEC4')
        for component in rotations[0]:
            self.assertAlmostEqual(component, 0.5, places=6)
        for before, after in zip(rotations, rotations[1:]):
            self.assertGreaterEqual(sum(a * b for a, b in zip(before, after)), 0.0)
        self.assertTrue(all(abs(math.hypot(*value) - 1.0) < 1e-6 for value in rotations))
        self.assertEqual(rotation_sampler['input'], translation['input'])

        scale_sampler = by_target[(5, 'scale')]
        self.assertEqual(read_accessor(self.builder, self.accessors, scale_sampler['input']), [(0.0,)])
        self.assertEqual(read_accessor(self.builder, self.accessors, scale_sampler['output']),
                         [(1.5, 1.25, 0.75)])
        self.assertEqual(scale_sampler['input'], by_target[(3, 'scale')]['input'])
        self.assertNotEqual(scale_sampler['input'], translation['input'])

    def test_single_frame_mixed_tracks_hold_initial_values_to_candidate_end(self):
        skeleton, node_map, bound = synthetic_fixture(duration=1)
        clip = self.build(bound, skeleton, node_map)
        self.assertEqual(clip['extras']['durationMsCandidate'], 33)
        self.assertEqual(clip['extras']['singleKeyHold'], 'synthetic-candidate-endpoint')
        for sampler in clip['samplers']:
            times = read_accessor(self.builder, self.accessors, sampler['input'])
            values = read_accessor(self.builder, self.accessors, sampler['output'])
            self.assertEqual(len(times), 2)
            self.assertEqual(times[0], (0.0,))
            self.assertAlmostEqual(times[1][0], 0.033, places=6)
            self.assertEqual(len(values), 2)
            self.assertEqual(values[0], values[1])
        by_target = {
            (channel['target']['node'], channel['target']['path']):
            clip['samplers'][channel['sampler']]
            for channel in clip['channels']
        }
        translation = read_accessor(
            self.builder, self.accessors, by_target[(5, 'translation')]['output'])[0]
        for actual, expected in zip(translation, (10.0, 21.0, 30.0), strict=True):
            self.assertAlmostEqual(actual, expected)

    def test_single_frame_constant_tracks_hold_and_obey_limits(self):
        skeleton, node_map, bound = synthetic_fixture(duration=1)
        bound['bindings'] = [
            item for item in bound['bindings'] if item['layout'] == 'constant']
        clip = self.build(bound, skeleton, node_map)
        self.assertEqual(clip['extras']['durationMsCandidate'], 33)
        for sampler in clip['samplers']:
            times = read_accessor(self.builder, self.accessors, sampler['input'])
            values = read_accessor(self.builder, self.accessors, sampler['output'])
            self.assertEqual(times[0], (0.0,))
            self.assertAlmostEqual(times[1][0], 0.033, places=6)
            self.assertEqual(values[0], values[1])

        builder, accessors = BufferBuilder(), []
        bad = copy.deepcopy(bound)
        bad['headers']['framerate'] = 1_001
        with self.assertRaisesRegex(KdfError, 'strictly increasing'):
            build_animations(builder, accessors, node_map, skeleton, [('single', bad)])
        with patch('gltf_animation._MAX_SCALARS', 10):
            with self.assertRaisesRegex(KdfError, 'scalar count'):
                build_animations(builder, accessors, node_map, skeleton, [('single', bound)])
        self.assertEqual(builder.views, [])
        self.assertEqual(accessors, [])

    def test_single_frame_mixed_tracks_reject_unrepresentable_duration_and_limit(self):
        skeleton, node_map, bound = synthetic_fixture(duration=1)
        bound['headers']['framerate'] = 1_001
        with self.assertRaisesRegex(KdfError, 'strictly increasing'):
            self.build(bound, skeleton, node_map)
        bound['headers']['framerate'] = 30
        with patch('gltf_animation._MAX_SCALARS', 20):
            with self.assertRaisesRegex(KdfError, 'scalar count'):
                self.build(bound, skeleton, node_map)
        self.assertEqual(self.builder.views, [])
        self.assertEqual(self.accessors, [{'existing': True}])

    def test_frame_count_is_not_truncated_to_framerate(self):
        skeleton, node_map, bound = synthetic_fixture(duration=69)
        bound['bindings'][0]['values'] = [
            [float(index), 0.0, 0.0] for index in range(69)]
        clip = self.build(bound, skeleton, node_map)
        self.assertEqual(clip['extras']['sourceFrameCount'], 69)
        channel = next(
            item for item in clip['channels']
            if item['target'] == {'node': 5, 'path': 'translation'})
        sampler = clip['samplers'][channel['sampler']]
        times = read_accessor(self.builder, self.accessors, sampler['input'])
        values = read_accessor(self.builder, self.accessors, sampler['output'])
        self.assertEqual(len(times), 69)
        self.assertEqual(len(values), 69)
        self.assertEqual(times[0], (0.0,))
        self.assertAlmostEqual(times[-1][0], 2.3, places=6)
        for actual, expected in zip(values[0], (10.0, 20.0, 30.0), strict=True):
            self.assertAlmostEqual(actual, expected)
        for actual, expected in zip(values[-1], (10.0, 88.0, 30.0), strict=True):
            self.assertAlmostEqual(actual, expected)

    def test_multiple_clips_have_valid_independent_accessor_references(self):
        clips = build_animations(
            self.builder, self.accessors, self.node_map, self.skeleton,
            [('first', self.bound), ('second', copy.deepcopy(self.bound))],
        )
        self.assertEqual([clip['name'] for clip in clips], ['first', 'second'])
        for clip in clips:
            for channel in clip['channels']:
                sampler = clip['samplers'][channel['sampler']]
                self.assertEqual(len(read_accessor(self.builder, self.accessors, sampler['input'])),
                                 len(read_accessor(self.builder, self.accessors, sampler['output'])))
        self.assertNotEqual(
            clips[0]['samplers'][0]['input'], clips[1]['samplers'][0]['input'])

    def test_all_constant_clip_preserves_candidate_duration_in_glb(self):
        from character_to_gltf import _build_glb

        bound = copy.deepcopy(self.bound)
        bound['bindings'] = [
            item for item in bound['bindings'] if item['layout'] == 'constant']
        builder = BufferBuilder()
        accessors = []
        clip = build_animations(
            builder, accessors, self.node_map, self.skeleton, [('constant', bound)]
        )[0]
        gltf = {
            'asset': {'version': '2.0'},
            'nodes': [{} for _ in range(max(self.node_map.values()) + 1)],
            'animations': [clip],
            'accessors': accessors,
            'bufferViews': builder.views,
            'buffers': [{'byteLength': len(builder.data)}],
        }
        glb = _build_glb(gltf, bytes(builder.data))
        magic, version, length = struct.unpack_from('<4sII', glb)
        self.assertEqual((magic, version, length), (b'glTF', 2, len(glb)))
        json_length, json_kind = struct.unpack_from('<II', glb, 12)
        self.assertEqual(json_kind, 0x4E4F534A)
        decoded = json.loads(glb[20:20 + json_length])
        bin_header = 20 + json_length
        bin_length, bin_kind = struct.unpack_from('<II', glb, bin_header)
        self.assertEqual(bin_kind, 0x004E4942)
        binary = glb[bin_header + 8:bin_header + 8 + bin_length]

        def unpack_accessor(index):
            accessor = decoded['accessors'][index]
            view = decoded['bufferViews'][accessor['bufferView']]
            width = {'SCALAR': 1, 'VEC3': 3}[accessor['type']]
            offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
            flat = struct.unpack_from(
                f'<{accessor["count"] * width}f', binary, offset)
            return [flat[i:i + width] for i in range(0, len(flat), width)]

        self.assertEqual(decoded['animations'][0]['extras']['durationMsCandidate'], 166)
        for channel in decoded['animations'][0]['channels']:
            sampler = decoded['animations'][0]['samplers'][channel['sampler']]
            self.assertEqual(sampler['interpolation'], 'STEP')
            times = unpack_accessor(sampler['input'])
            values = unpack_accessor(sampler['output'])
            self.assertEqual(len(times), 2)
            self.assertEqual(times[0], (0.0,))
            self.assertAlmostEqual(times[1][0], 0.166, places=6)
            self.assertEqual(len(values), 2)
            self.assertEqual(values[0], values[1])

    def test_all_constant_clip_rejects_unrepresentable_duration_and_scalar_overflow(self):
        bound = copy.deepcopy(self.bound)
        bound['bindings'] = [
            item for item in bound['bindings'] if item['layout'] == 'constant']
        bound['headers']['framerate'] = 1_000_000
        with self.assertRaisesRegex(KdfError, 'strictly increasing'):
            self.build(bound=bound)
        bound['headers']['framerate'] = 30
        with patch('gltf_animation._MAX_SCALARS', 10):
            with self.assertRaisesRegex(KdfError, 'scalar count'):
                self.build(bound=bound)
        self.assertEqual(self.builder.views, [])
        self.assertEqual(self.accessors, [{'existing': True}])

    def test_invalid_pairing_nodes_duplicates_and_quaternion_are_rejected(self):
        mutations = [
            lambda bound: bound.update(pairing_status='unverified'),
            lambda bound: bound.update(skeleton_sha256='2' * 64),
            lambda bound: bound['headers'].update(pose=0),
            lambda bound: bound['bindings'][0].update(nodeid=99),
            lambda bound: bound['bindings'][0].update(offset=1),
            lambda bound: bound['bindings'].append(copy.deepcopy(bound['bindings'][0])),
            lambda bound: bound['bindings'][1]['values'].__setitem__(0, [0.0, 0.0, 0.0, 0.0]),
            lambda bound: bound['bindings'][0]['values'].__setitem__(0, [math.inf, 0.0, 0.0]),
            lambda bound: bound['bindings'][0]['values'].pop(),
        ]
        for mutation in mutations:
            with self.subTest(mutation=mutations.index(mutation)):
                bad = copy.deepcopy(self.bound)
                mutation(bad)
                with self.assertRaises(KdfError):
                    self.build(bad)
                self.assertEqual(self.builder.views, [])
                self.assertEqual(self.accessors, [{'existing': True}])

    def test_rest_hierarchy_and_duplicate_names_are_rejected(self):
        invalid = [
            lambda skeleton, node_map: skeleton['object_static_transforms'].append(
                copy.deepcopy(skeleton['object_static_transforms'][0])),
            lambda skeleton, node_map: skeleton['static_transforms'].pop(),
            lambda skeleton, node_map: node_map.pop(71),
            lambda skeleton, node_map: node_map.update({71: 5}),
            lambda skeleton, node_map: skeleton['static_transforms'][0].update(
                rotation_xyzw_unverified=[0.0, 0.0, 0.0, 0.0]),
        ]
        for mutation in invalid:
            with self.subTest(mutation=invalid.index(mutation)):
                skeleton = copy.deepcopy(self.skeleton)
                node_map = dict(self.node_map)
                mutation(skeleton, node_map)
                with self.assertRaises(KdfError):
                    self.build(skeleton=skeleton, node_map=node_map)
        with self.assertRaisesRegex(KdfError, 'names must be unique'):
            build_animations(
                self.builder, self.accessors, self.node_map, self.skeleton,
                [('same', self.bound), ('same', self.bound)],
            )
        self.assertEqual(self.builder.views, [])
        self.assertEqual(self.accessors, [{'existing': True}])

    def test_nonincreasing_float32_times_and_work_limits_are_rejected(self):
        bad = copy.deepcopy(self.bound)
        bad['headers']['framerate'] = 1_000_000
        with self.assertRaisesRegex(KdfError, 'strictly increasing'):
            self.build(bad)
        with patch('gltf_animation._MAX_SCALARS', 2):
            with self.assertRaisesRegex(KdfError, 'scalar count'):
                self.build()
        with patch('gltf_animation._MAX_CHANNELS', 2):
            with self.assertRaisesRegex(KdfError, 'channel count'):
                self.build()
        self.assertEqual(self.builder.views, [])
        self.assertEqual(self.accessors, [{'existing': True}])


if __name__ == '__main__':
    unittest.main()

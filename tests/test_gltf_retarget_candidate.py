import copy
import math
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from gltf_animation import build_animations
from kdf_data import KdfError
from retarget_animation_binding import retarget_candidate
from test_gltf_animation import BufferBuilder, read_accessor, synthetic_fixture


def fixture():
    source, _, binding = synthetic_fixture(duration=2)
    for node, name, parent in zip(
            source['nodes'], ('root', 'object', 'bone', 'other'), (-2, 1, 7, 7)):
        node.update(name=name, parentid=parent)
    for track in binding['bindings']:
        track['node_name'] = {7: 'object', 23: 'bone'}[track['nodeid']]
    target = copy.deepcopy(source)
    target['sha256'] = '2' * 64
    ids = {1: 101, 7: 107, 23: 123, 71: 171}
    for node in target['nodes']:
        node['nodeid'] = ids[node['nodeid']]
        if node['parentid'] >= 0:
            node['parentid'] = ids[node['parentid']]
        for field in ('object_position_index', 'bone_position_index',
                      'bone_rotation_index', 'scale_index'):
            if field in node:
                node[field] += 10
    for transform in target['static_transforms'] + target['object_static_transforms']:
        transform['nodeid'] = ids[transform['nodeid']]
    target['static_transforms'][0]['position'] = [100, 200, 300]
    target['static_transforms'][0]['rotation_xyzw_unverified'] = [0, 0, 0, 1]
    candidate = retarget_candidate(
        binding, source, target, expected_animation_sha256='a' * 64,
        expected_source_sha256='1' * 64, expected_target_sha256='2' * 64,
        expected_reference='skeletons/hero.skl')
    return source, target, binding, candidate


class RetargetAnimationTests(unittest.TestCase):
    def setUp(self):
        self.source, self.target, self.binding, self.candidate = fixture()
        self.node_map = {101: 0, 107: 3, 123: 5, 171: 8}
        self.builder = BufferBuilder()
        self.accessors = []

    def build(self, candidate=None, target=None, opt_in=True):
        return build_animations(
            self.builder, self.accessors, self.node_map,
            self.target if target is None else target,
            [('experiment', self.candidate if candidate is None else candidate)],
            allow_experimental_retarget=opt_in)[0]

    def test_opt_in_metadata_and_target_rest_composition(self):
        with self.assertRaisesRegex(KdfError, 'opt-in'):
            self.build(opt_in=False)
        clip = self.build()
        extras = clip['extras']
        self.assertEqual(extras['sourceSkeletonSha256'], '1' * 64)
        self.assertEqual(extras['targetSkeletonSha256'], '2' * 64)
        self.assertEqual(extras['sourceAnimationSha256'], 'a' * 64)
        self.assertEqual(extras['sourcePairingStatus'], 'matched-provided-reference-and-hash')
        self.assertEqual(extras['targetPairingStatus'], 'unverified')
        self.assertEqual(extras['mappingStatus'], 'identity-candidate-only')
        self.assertEqual(extras['retargetSemantics'], 'unverified')
        self.assertEqual(extras['retargetMapping'], self.candidate['mapping'])
        self.assertNotIn('pairingStatus', extras)
        channels = {(c['target']['node'], c['target']['path']):
                    clip['samplers'][c['sampler']] for c in clip['channels']}
        self.assertEqual(set(channels), {(5, 'translation'), (5, 'rotation'),
                                         (5, 'scale'), (3, 'translation'), (3, 'scale')})
        translation = read_accessor(self.builder, self.accessors,
                                    channels[(5, 'translation')]['output'])
        self.assertEqual(translation[0], (101.0, 200.0, 300.0))
        rotation = read_accessor(self.builder, self.accessors,
                                 channels[(5, 'rotation')]['output'])
        self.assertAlmostEqual(rotation[0][0], math.sqrt(0.5), places=6)
        self.assertAlmostEqual(rotation[0][2], 0.0, places=6)
        self.assertGreaterEqual(sum(a * b for a, b in zip(*rotation)), 0)
        scale = read_accessor(self.builder, self.accessors, channels[(5, 'scale')]['output'])
        self.assertEqual(scale, [(1.5, 1.25, 0.75)])

    def test_rejects_invalid_metadata_and_mapping_before_mutation(self):
        changes = [
            lambda c: c.update(source_skeleton_sha256='bad'),
            lambda c: c.update(target_skeleton_sha256='3' * 64),
            lambda c: c.update(animation_sha256='bad'),
            lambda c: c.update(source_pairing_status='unverified'),
            lambda c: c.update(mapping_status='verified'),
            lambda c: c['mapping'][0].update(target_nodeid=171),
            lambda c: c['mapping'][0].update(path=[['root', 'wrong']]),
            lambda c: c['bindings'][0].update(offset=0),
            lambda c: c['bindings'].append(copy.deepcopy(c['bindings'][0])),
        ]
        for change in changes:
            candidate = copy.deepcopy(self.candidate)
            change(candidate)
            with self.subTest(change=change), self.assertRaises(KdfError):
                self.build(candidate)
            self.assertEqual(self.builder.views, [])
            self.assertEqual(self.accessors, [])

    def test_strict_path_still_rejects_wrong_skeleton_even_with_opt_in(self):
        with self.assertRaises(KdfError):
            self.build(candidate=self.binding)
        builder, accessors = BufferBuilder(), []
        clips = build_animations(builder, accessors, {1: 0, 7: 3, 23: 5, 71: 8},
                                 self.source, [('strict', self.binding)])
        self.assertEqual(clips[0]['extras']['pairingStatus'],
                         'matched-provided-reference-and-hash')
        self.assertNotIn('targetPairingStatus', clips[0]['extras'])


if __name__ == '__main__':
    unittest.main()

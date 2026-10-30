from copy import deepcopy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_data import KdfError
from retarget_animation_binding import retarget_candidate
from test_audit_animation_retarget import skeleton, binding


class RetargetCandidateTests(unittest.TestCase):
    def setUp(self):
        self.source = skeleton(2, 28, 'a' * 64)
        self.target = skeleton(3, 15, 'b' * 64)
        self.bound = binding()
        self.bound.update({
            'animation_sha256': 'c' * 64,
            'skeleton_sha256': 'a' * 64,
            'pairing_status': 'matched-provided-reference-and-hash',
            'skeleton_reference': {'reference': 'skeletons/source.skl'},
            'headers': {'duration': 2},
        })
        self.bound['bindings'][0]['values'] = [[0, 0, 0, 1], [0, 1, 0, 0]]
        self.args = {'expected_animation_sha256': 'c' * 64,
                     'expected_source_sha256': 'a' * 64,
                     'expected_target_sha256': 'b' * 64,
                     'expected_reference': 'skeletons/source.skl'}

    def test_preserves_source_and_raw_values_while_mapping_target(self):
        original = deepcopy(self.bound)
        out = retarget_candidate(self.bound, self.source, self.target, **self.args)
        self.assertEqual(self.bound, original)
        self.assertEqual(out['status'], 'experimental-cross-skeleton-candidate')
        self.assertEqual(out['source_skeleton_sha256'], 'a' * 64)
        self.assertEqual(out['target_skeleton_sha256'], 'b' * 64)
        self.assertEqual(out['bindings'][0]['nodeid'], 3)
        self.assertEqual(out['bindings'][0]['offset'], 15)
        self.assertEqual(out['bindings'][0]['values'], original['bindings'][0]['values'])
        out['bindings'][0]['values'][0][0] = 9
        self.assertEqual(self.bound, original)

    def test_rejects_each_incorrect_identity_and_unverified_pairing(self):
        for field in self.args:
            args = dict(self.args)
            args[field] = 'wrong'
            with self.subTest(field=field), self.assertRaises(KdfError):
                retarget_candidate(self.bound, self.source, self.target, **args)
        bound = deepcopy(self.bound)
        bound['pairing_status'] = 'unverified'
        with self.assertRaises(KdfError):
            retarget_candidate(bound, self.source, self.target, **self.args)

    def test_rejects_ambiguous_target(self):
        target = deepcopy(self.target)
        duplicate = deepcopy(target['nodes'][-1])
        duplicate['nodeid'] = 4
        target['nodes'].append(duplicate)
        with self.assertRaises(KdfError):
            retarget_candidate(self.bound, self.source, target, **self.args)


if __name__ == '__main__':
    unittest.main()

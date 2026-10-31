from copy import deepcopy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from audit_animation_retarget import audit
from kdf_data import KdfError


def skeleton(eye_id, eye_index, sha):
    return {'sha256': sha, 'nodes': [
        {'nodeid': 0, 'parentid': -2, 'name': 'root', 'type': 'root'},
        {'nodeid': 1, 'parentid': 0, 'name': 'head', 'type': 'bone'},
        {'nodeid': eye_id, 'parentid': 1, 'name': 'r eyeball', 'type': 'bone',
         'bone_rotation_index': eye_index},
    ]}


def binding():
    return {'animation_sha256': 'animation', 'skeleton_sha256': 'source',
            'bindings': [{'nodeid': 2, 'node_name': 'r eyeball',
                          'node_type': 'bone', 'index_field': 'bone_rotation_index',
                          'offset': 28, 'track': 'bonerot', 'target': 'rotation'}]}


def object_skeletons():
    source = {'sha256': 'source', 'nodes': [
        {'nodeid': 0, 'parentid': -2, 'name': 'root', 'type': 'root'},
        {'nodeid': 1, 'parentid': 0, 'name': 'skeleton', 'type': 'bone'},
        {'nodeid': 2, 'parentid': 1, 'name': 'bl_x_body', 'type': 'object',
         'object_scale_index': 5},
    ]}
    target = {'sha256': 'target', 'nodes': [
        {'nodeid': 0, 'parentid': -2, 'name': 'root', 'type': 'root'},
        {'nodeid': 1, 'parentid': 0, 'name': 'skeleton', 'type': 'bone'},
        {'nodeid': 3, 'parentid': 1, 'name': 'bl_y_body', 'type': 'object',
         'object_scale_index': 7},
    ]}
    binding = {'animation_sha256': 'animation', 'skeleton_sha256': 'source',
               'bindings': [{'nodeid': 2, 'node_name': 'bl_x_body',
                             'node_type': 'object', 'index_field': 'object_scale_index',
                             'offset': 5, 'track': 'scales', 'target': 'scale'}]}
    return source, target, binding


class AuditRetargetTests(unittest.TestCase):
    def setUp(self):
        self.source = skeleton(2, 28, 'source')
        self.target = skeleton(3, 15, 'target')

    def test_maps_identity_to_different_channel_index(self):
        result = audit(binding(), self.source, self.target)
        self.assertEqual(result['status'], 'identity-candidate-only')
        self.assertEqual(result['mappings'][0]['source_offset'], 28)
        self.assertEqual(result['mappings'][0]['target_offset'], 15)

    def test_rejects_missing_or_changed_parent_and_ambiguous_path(self):
        for mutation in ('missing', 'parent', 'duplicate'):
            target = deepcopy(self.target)
            if mutation == 'missing':
                target['nodes'].pop()
            elif mutation == 'parent':
                target['nodes'][-1]['parentid'] = 0
            else:
                duplicate = deepcopy(target['nodes'][-1])
                duplicate['nodeid'] = 4
                target['nodes'].append(duplicate)
            with self.subTest(mutation=mutation), self.assertRaises(KdfError):
                audit(binding(), self.source, target)

    def test_rejects_collision_and_wrong_source(self):
        duplicate = binding()
        duplicate['bindings'].append(deepcopy(duplicate['bindings'][0]))
        with self.assertRaises(KdfError):
            audit(duplicate, self.source, self.target)
        wrong = binding()
        wrong['skeleton_sha256'] = 'wrong'
        with self.assertRaises(KdfError):
            audit(wrong, self.source, self.target)

    def test_rejects_hierarchy_cycle(self):
        target = deepcopy(self.target)
        target['nodes'][1]['parentid'] = 3
        with self.assertRaises(KdfError):
            audit(binding(), self.source, target)

    def test_rejects_duplicate_target_channel_index(self):
        target = deepcopy(self.target)
        target['nodes'][1]['bone_rotation_index'] = 15
        with self.assertRaises(KdfError):
            audit(binding(), self.source, target)

    def test_rejects_missing_parent_and_source_hierarchy_errors(self):
        for mutation in ('missing_parent', 'source_duplicate', 'source_cycle'):
            source, target = deepcopy(self.source), deepcopy(self.target)
            if mutation == 'missing_parent':
                target['nodes'][-1]['parentid'] = 999
            elif mutation == 'source_duplicate':
                duplicate = deepcopy(source['nodes'][-1])
                duplicate['nodeid'] = 4
                source['nodes'].append(duplicate)
            else:
                source['nodes'][1]['parentid'] = 2
            with self.subTest(mutation=mutation), self.assertRaises(KdfError):
                audit(binding(), source, target)

    def test_maps_unique_object_role_and_rejects_ambiguous_role(self):
        source, target, bound = object_skeletons()
        result = audit(bound, source, target, allow_object_track_mismatch=True)
        self.assertEqual(result['mappings'][0]['target_offset'], 7)
        duplicate = deepcopy(target['nodes'][-1])
        duplicate['nodeid'] = 4
        duplicate['name'] = 'bl_z_body'
        target['nodes'].append(duplicate)
        with self.assertRaises(KdfError):
            audit(bound, source, target, allow_object_track_mismatch=True)



if __name__ == '__main__':
    unittest.main()

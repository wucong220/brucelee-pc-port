from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from compare_animation_bindings import compare
from kdf_data import KdfError


def binding(name, *, animation='a', offset=28):
    return {
        'animation_sha256': animation,
        'skeleton_sha256': name,
        'skeleton_reference': {'reference': 'skeletons/source.skl'},
        'bindings': [{
            'track': 'bonerot', 'offset': offset,
            'node_name': name, 'node_type': 'bone',
        }],
    }


class TestCompareAnimationBindings(unittest.TestCase):
    def test_detects_same_index_with_different_node_name(self):
        result = compare(binding('right eye'), binding('left eyebrow'))
        self.assertEqual(result['binding_count'], 1)
        self.assertEqual(result['same_name_and_type_count'], 0)
        self.assertEqual(result['differences'][0]['offset'], 28)
        self.assertEqual(result['pairing_status'], 'unverified')

    def test_rejects_different_animation_or_offset_set(self):
        with self.assertRaises(KdfError):
            compare(binding('a'), binding('b', animation='other'))
        with self.assertRaises(KdfError):
            compare(binding('a'), binding('b', offset=29))

    def test_rejects_duplicate_track_offset(self):
        source = binding('a')
        source['bindings'].append(source['bindings'][0])
        with self.assertRaises(KdfError):
            compare(source, binding('b'))


if __name__ == '__main__':
    unittest.main()

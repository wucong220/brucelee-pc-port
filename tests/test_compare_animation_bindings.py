from pathlib import Path
import subprocess
import sys
import tempfile
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

    def test_rejects_inconsistent_reference(self):
        target = binding('b')
        target['skeleton_reference']['reference'] = 'skeletons/other.skl'
        with self.assertRaises(KdfError):
            compare(binding('a'), target)

    def test_cli_rejects_missing_and_invalid_files(self):
        script = Path(__file__).resolve().parents[1] / 'tools' / 'compare_animation_bindings.py'
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'bad.anm'
            missing = path.with_name('missing.skl')
            path.write_bytes(b'not an animation')
            for paths in ((missing, missing, missing), (path, path, path)):
                result = subprocess.run([sys.executable, str(script), *map(str, paths)],
                                        capture_output=True, text=True, encoding='utf-8')
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')
                self.assertIn('error:', result.stderr)


if __name__ == '__main__':
    unittest.main()

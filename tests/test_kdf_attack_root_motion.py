import json
import tempfile
import unittest
from pathlib import Path

from tools.kdf_attack_root_motion import actions_from_config


class AttackRootMotionTests(unittest.TestCase):
    def test_maps_attack_animations(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'attacks.json'
            path.write_text(json.dumps({'attacks': {
                'punch': {'animation': 'm01_pnch_low_01'},
                'kick': {'animation': 'm01_kick_low_01'},
            }}), encoding='utf-8')
            self.assertEqual(actions_from_config(path), {
                'punch': 'adreno_200/animation/m01_pnch_low_01.anm',
                'kick': 'adreno_200/animation/m01_kick_low_01.anm',
            })

    def test_rejects_missing_attacks(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'attacks.json'
            path.write_text('{}', encoding='utf-8')
            with self.assertRaises(ValueError):
                actions_from_config(path)


if __name__ == '__main__':
    unittest.main()

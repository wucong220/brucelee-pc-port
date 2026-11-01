import json
import tempfile
import unittest
from pathlib import Path

from tools.kdf_attack_root_motion import actions_from_config


ROOT = Path(__file__).resolve().parents[1]


class AttackRootMotionTests(unittest.TestCase):
    def test_real_config_uses_source_action(self):
        actions = actions_from_config(
            ROOT / 'godot' / 'data' / 'fighting_set_low_attacks.json'
        )
        self.assertEqual(len(actions), 28)
        self.assertEqual(
            actions['lowpunch1'],
            'adreno_200/animation/m01_pnch_low_01.anm',
        )
        self.assertEqual(
            actions['specialpunchlowhit'],
            'adreno_200/animation/m01_sp_pnch_low.anm',
        )
        self.assertNotIn('punch', actions)

    def test_maps_attack_animations(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'attacks.json'
            path.write_text(json.dumps({'attacks': {
                'punch': {'source_action': 'lowpunch1', 'animation': 'm01_pnch_low_01'},
                'kick': {'source_action': 'lowkick1', 'animation': 'm01_kick_low_01'},
            }}), encoding='utf-8')
            self.assertEqual(actions_from_config(path), {
                'lowpunch1': 'adreno_200/animation/m01_pnch_low_01.anm',
                'lowkick1': 'adreno_200/animation/m01_kick_low_01.anm',
            })

    def test_rejects_missing_attacks(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'attacks.json'
            path.write_text('{}', encoding='utf-8')
            with self.assertRaises(ValueError):
                actions_from_config(path)


if __name__ == '__main__':
    unittest.main()

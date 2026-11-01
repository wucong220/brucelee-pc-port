import json
import math
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'godot' / 'data' / 'attack_root_motion.json'
REPORTS = [
    ROOT / 'reports' / 'attack_root_motion_inventory.json',
    ROOT / 'reports' / 'attack_root_motion_m03_inventory.json',
]


def report_tracks():
    tracks = {}
    for report in REPORTS:
        data = json.loads(report.read_text(encoding='utf-8'))
        for action in data['actions']:
            positions = action.get('positions')
            if not positions:
                continue
            key = Path(action['animation']).stem
            if key in tracks and tracks[key] != positions:
                raise AssertionError(f'conflicting report tracks for {key}')
            tracks[key] = positions
    return tracks


def shipped_tracks():
    return json.loads(DATA.read_text(encoding='utf-8'))


class AttackRootDataTests(unittest.TestCase):
    def test_shipped_tracks_match_reports(self):
        expected = report_tracks()
        actual = shipped_tracks()
        self.assertEqual(set(actual), set(expected))
        for key, positions in expected.items():
            self.assertEqual(len(actual[key]), len(positions), key)
            for left, right in zip(actual[key], positions):
                self.assertEqual(len(left), 3, key)
                self.assertEqual(len(right), 3, key)
                for a, b in zip(left, right):
                    self.assertTrue(math.isclose(a, b, rel_tol=0.0, abs_tol=1e-9), key)


if __name__ == '__main__':
    unittest.main()

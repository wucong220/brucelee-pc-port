import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class BruceMovementTest(unittest.TestCase):
    def test_movement_clips_match_recovered_actions(self) -> None:
        source = (ROOT / "godot" / "scripts" / "fighter.gd").read_text(encoding="utf-8")
        report = json.loads(
            (ROOT / "reports" / "bruce_movement_evidence.json").read_text(encoding="utf-8")
        )["actions"]
        expected = {
            "moveleft": "m01_moverht",
            "moveright": "m01_movelft",
            "stepleft": "m01_steplft",
            "stepright": "m01_steprht",
        }
        for action, animation in expected.items():
            self.assertEqual(report[action]["animation"], animation)
            self.assertIn('"%s": "%s"' % (action, animation), source)
        self.assertIn('"move": "m01_movelft"', source)


if __name__ == "__main__":
    unittest.main()

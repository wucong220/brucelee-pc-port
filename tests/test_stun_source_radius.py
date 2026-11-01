import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIGHTER = ROOT / "godot" / "scripts" / "fighter.gd"
REPORT = ROOT / "reports" / "reaction_action_inventory.json"


def _radius_entry(text: str, animation: str) -> float:
    match = re.search(
        r'"' + re.escape(animation) + r'": ([0-9.]+)',
        text,
    )
    if match is None:
        raise AssertionError(f"missing radius entry for {animation}")
    return float(match.group(1))


class StunSourceRadiusTest(unittest.TestCase):
    def test_stun_radii_match_recovered_actions(self) -> None:
        report = json.loads(REPORT.read_text(encoding="utf-8"))
        actions = {entry["name"]: entry for entry in report["actions"]}
        text = FIGHTER.read_text(encoding="utf-8")
        self.assertEqual(
            _radius_entry(text, "all_stunned"),
            float(actions["stun"]["radius"]),
        )
        self.assertEqual(
            _radius_entry(text, "all_stunned_fall"),
            float(actions["stunfall"]["radius"]),
        )
        self.assertIn('if state in ["stun", "stun2"]', text)
        self.assertIn('if state == "stunfall"', text)


if __name__ == "__main__":
    unittest.main()

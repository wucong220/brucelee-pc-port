import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "godot" / "scripts" / "fighter.gd"
IMPACT_REPORT = ROOT / "reports" / "bruce_faceup_fields.json"
REACTION_REPORT = ROOT / "reports" / "reaction_action_inventory.json"


class ImpactToFloorRadiusTest(unittest.TestCase):
    def test_shared_animation_uses_state_specific_radii(self) -> None:
        impact = json.loads(IMPACT_REPORT.read_text(encoding="utf-8"))
        reactions = json.loads(REACTION_REPORT.read_text(encoding="utf-8"))
        stunfall = next(
            entry for entry in reactions["actions"] if entry["name"] == "stunfall"
        )
        self.assertEqual(impact["actions"]["impacttofloor"]["radius"], 75.0)
        self.assertEqual(stunfall["radius"], 70.0)
        text = SOURCE.read_text(encoding="utf-8")
        self.assertIn('if state == "impacttofloor"', text)
        self.assertIn("return 75.0 * radius_scale", text)


if __name__ == "__main__":
    unittest.main()

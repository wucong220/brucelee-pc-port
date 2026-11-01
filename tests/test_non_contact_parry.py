import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class NonContactParryTest(unittest.TestCase):
    def test_parry_high_is_not_a_contact_attack(self) -> None:
        source = (ROOT / "godot" / "scripts" / "fighter.gd").read_text(encoding="utf-8")
        self.assertIn('"parry_high": true', source)
        report = json.loads(
            (ROOT / "reports" / "raw_attack_fields.json").read_text(encoding="utf-8")
        )["actions"]["parryhigh"]
        self.assertEqual(report["animation"], "m01_parry_high")
        self.assertEqual(report["impacts"], [])


if __name__ == "__main__":
    unittest.main()

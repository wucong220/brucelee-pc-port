import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIGHTER = ROOT / "godot" / "scripts" / "fighter.gd"
REPORT = ROOT / "reports" / "special_moves_evidence.json"


class SpecialPunchHighReturnTest(unittest.TestCase):
    def test_miss_return_target_matches_recovered_link(self) -> None:
        report = json.loads(REPORT.read_text(encoding="utf-8"))
        miss = report["special_moves"]["specialpunchhigh"]["miss_return"]
        self.assertEqual(miss["to"], "idle2")
        self.assertEqual([int(v) for v in miss["time"]], [116, 122])
        text = FIGHTER.read_text(encoding="utf-8")
        self.assertIn('attack_kind == "special_punch_high_miss"', text)
        self.assertIn("next_state = \"idle2\"", text)


if __name__ == "__main__":
    unittest.main()

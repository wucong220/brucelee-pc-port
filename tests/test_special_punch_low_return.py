import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIGHTER = ROOT / "godot" / "scripts" / "fighter.gd"
REPORT = ROOT / "reports" / "special_moves_evidence.json"


class SpecialPunchLowReturnTest(unittest.TestCase):
    def test_candidate_exit_is_inside_recovered_return_window(self) -> None:
        report = json.loads(REPORT.read_text(encoding="utf-8"))
        window = report["special_moves"]["specialpunchlow"]["miss_return"]["time"]
        text = FIGHTER.read_text(encoding="utf-8")
        match = re.search(
            r"const SPECIAL_PUNCH_LOW_MISS_RETURN_FRAME: float = ([0-9.]+)",
            text,
        )
        self.assertIsNotNone(match)
        candidate_exit = float(match.group(1))
        self.assertGreaterEqual(candidate_exit, float(window[0]))
        self.assertLessEqual(candidate_exit, float(window[1]))


if __name__ == "__main__":
    unittest.main()

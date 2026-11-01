import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "godot" / "data" / "fighting_set_low_attacks.json"
REPORT = ROOT / "reports" / "special_moves_evidence.json"


class SpecialPunchLowHitWindowTest(unittest.TestCase):
    def test_active_frames_cover_recovered_damage_window(self) -> None:
        config = json.loads(CONFIG.read_text(encoding="utf-8"))
        report = json.loads(REPORT.read_text(encoding="utf-8"))
        action = config["attacks"]["special_punch_low_hit"]
        damage = report["special_moves"]["specialpunchlow"]
        self.assertEqual(
            [
                action["startup_frames"],
                action["startup_frames"] + action["active_frames"] - 1,
            ],
            [int(value) for value in damage["hit_damage_time"]],
        )
        self.assertEqual(
            action["startup_frames"]
            + action["active_frames"]
            + action["recovery_frames"],
            action["animation_frame_count"],
        )


if __name__ == "__main__":
    unittest.main()

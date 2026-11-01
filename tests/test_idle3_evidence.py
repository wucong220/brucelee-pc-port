import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "godot" / "scripts" / "fighter.gd"
REPORT = ROOT / "reports" / "idle3_evidence.json"


class Idle3EvidenceTest(unittest.TestCase):
    def test_idle3_constants_match_recovered_metadata(self) -> None:
        report = json.loads(REPORT.read_text(encoding="utf-8"))
        text = SOURCE.read_text(encoding="utf-8")
        clip = re.search(r'const IDLE3_CLIP: String = "([^"]+)"', text)
        duration = re.search(r"const IDLE3_DURATION_FRAMES: int = ([0-9]+)", text)
        self.assertIsNotNone(clip)
        self.assertIsNotNone(duration)
        self.assertEqual(clip.group(1), report["animation"])
        self.assertEqual(int(duration.group(1)), report["duration_frames"])
        self.assertEqual(report["animation_radius"], 40.0)
        self.assertIn('attack_kind == "special_kick_high"', text)
        self.assertIn('next_state = "idle3"', text)
        self.assertIn("IDLE2_CLIP, IDLE3_CLIP, FACEDOWN_IDLE_CLIP", text)
        self.assertIn(
            "IDLE2_CLIP, IDLE3_CLIP, FACEDOWN_IDLE_CLIP, "
            "BRICK_FACEDOWN_IDLE_CLIP, FACEUP_IDLE_CLIP",
            text,
        )


if __name__ == "__main__":
    unittest.main()

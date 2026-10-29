import json
from pathlib import Path
import unittest

CONFIG = Path(__file__).resolve().parents[1] / "godot" / "data" / "fighting_set_low_attacks.json"

class TestFightingConfig(unittest.TestCase):
    def test_low_attack_config_matches_verified_metadata(self):
        data = json.loads(CONFIG.read_text(encoding="utf-8"))
        self.assertEqual(data["schema_version"], 1)
        self.assertEqual(data["source_archive"], "brucelee.set")
        self.assertEqual(data["frame_rate"], 30.0)
        attacks = data["attacks"]
        self.assertEqual(set(attacks), {"punch", "kick"})
        self.assertEqual(attacks["punch"]["source_action"], "lowpunch1")
        self.assertEqual(attacks["kick"]["source_action"], "lowkick1")
        self.assertEqual(
            [attacks["punch"][key] for key in ("startup_frames", "active_frames", "recovery_frames")],
            [5, 4, 60],
        )
        self.assertEqual(
            [attacks["kick"][key] for key in ("startup_frames", "active_frames", "recovery_frames")],
            [7, 4, 75],
        )
        self.assertEqual(attacks["punch"]["damage"], 5.0)
        self.assertEqual(attacks["kick"]["damage"], 5.0)
        self.assertEqual(attacks["punch"]["source_impact"], {
            "attack_radius": 70.0,
            "body_part": "larm",
            "height": "medium",
            "strength": "normal",
            "direction": "frontal",
        })
        self.assertEqual(attacks["kick"]["source_impact"], {
            "attack_radius": 70.0,
            "body_part": "lleg",
            "height": "low",
            "strength": "normal",
            "direction": "frontal",
        })

if __name__ == "__main__":
    unittest.main()

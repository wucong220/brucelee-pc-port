import json
import math
from pathlib import Path
import unittest

CONFIG = Path(__file__).resolve().parents[1] / "godot" / "data" / "fighting_set_low_attacks.json"

class TestFightingConfig(unittest.TestCase):
    def test_low_attack_config_matches_verified_metadata(self):
        data = json.loads(CONFIG.read_text(encoding="utf-8"))
        self.assertEqual(data["schema_version"], 2)
        self.assertEqual(data["source_archive"], "brucelee.set")
        self.assertEqual(data["frame_rate"], 30.0)
        self.assertEqual(data["source_geometry"], {
            "source_height": 173.415954589844,
            "world_height": 1.8,
            "radius_scale": 1.0,
            "idle_source_archive": "Default.set",
            "animation_radii": {
                "m01_idle_01": 25.0,
                "m01_pnch_low_01": 40.0,
                "m01_kick_low_01": 50.0,
            },
        })
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
        for action in attacks.values():
            self.assertNotIn("prototype_range", action)
        geometry = data["source_geometry"]
        world_scale = geometry["world_height"] / geometry["source_height"]
        self.assertTrue(math.isclose(
            (attacks["punch"]["source_impact"]["attack_radius"]
             * geometry["radius_scale"]
             + geometry["animation_radii"]["m01_idle_01"]) * world_scale,
            0.9860684410753432,
            rel_tol=0.0,
            abs_tol=1e-12,
        ))

if __name__ == "__main__":
    unittest.main()

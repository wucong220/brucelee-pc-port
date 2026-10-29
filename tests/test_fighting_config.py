import json
import math
from pathlib import Path
import unittest

CONFIG = Path(__file__).resolve().parents[1] / "godot" / "data" / "fighting_set_low_attacks.json"
REPORT = Path(__file__).resolve().parents[1] / "reports" / "reaction_action_inventory.json"

class TestFightingConfig(unittest.TestCase):
    def test_low_attack_config_matches_verified_metadata(self):
        data = json.loads(CONFIG.read_text(encoding="utf-8"))
        self.assertEqual(data["schema_version"], 3)
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
                "all_impct_light_frnt_low": 40.0,
                "all_impct_light_frnt_mid": 40.0,
                "all_impct_light_frnt_high": 40.0,
                "all_block_low": 40.0,
                "all_block_mid": 40.0,
                "all_block_high": 40.0,
            },
        })
        self.assertEqual(data["reaction_profiles"], {
            "hit": {
                "low": {
                    "source_action": "impactlightfrontlow",
                    "animation": "all_impct_light_frnt_low",
                    "exit_start_frame": 13,
                    "animation_duration_frames": 17,
                    "linking_frame": 0,
                },
                "medium": {
                    "source_action": "impactlightfrontmid",
                    "animation": "all_impct_light_frnt_mid",
                    "exit_start_frame": 14,
                    "animation_duration_frames": 16,
                    "linking_frame": 0,
                },
                "high": {
                    "source_action": "impactlightfronthigh",
                    "animation": "all_impct_light_frnt_high",
                    "exit_start_frame": 13,
                    "animation_duration_frames": 17,
                    "linking_frame": 0,
                },
            },
            "block": {
                "low": {
                    "source_action": "lowblock",
                    "animation": "all_block_low",
                    "exit_start_frame": 12,
                    "animation_duration_frames": 23,
                    "linking_frame": 14,
                },
                "medium": {
                    "source_action": "midblock",
                    "animation": "all_block_mid",
                    "exit_start_frame": 12,
                    "animation_duration_frames": 14,
                    "linking_frame": 0,
                },
                "high": {
                    "source_action": "highblock",
                    "animation": "all_block_high",
                    "exit_start_frame": 12,
                    "animation_duration_frames": 14,
                    "linking_frame": 0,
                },
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

    def test_reaction_profiles_match_inventory_links_and_animation_metadata(self):
        config = json.loads(CONFIG.read_text(encoding="utf-8"))
        report = json.loads(REPORT.read_text(encoding="utf-8"))
        actions = {action["name"]: action for action in report["actions"]}
        for group in ("hit", "block"):
            for height in ("low", "medium", "high"):
                profile = config["reaction_profiles"][group][height]
                if group == "hit":
                    links = report["normal_frontal_hit_links"][height]
                else:
                    links = report["normal_block_links"]["canblock"][height]
                self.assertEqual(len(links), 1)
                self.assertEqual(links[0]["to"], profile["source_action"])
                action = actions[profile["source_action"]]
                self.assertEqual(
                    Path(action["animation"]).stem,
                    profile["animation"],
                )
                self.assertEqual(
                    action["animation_metadata"]["duration"],
                    profile["animation_duration_frames"],
                )
                self.assertEqual(
                    config["source_geometry"]["animation_radii"][profile["animation"]],
                    action["radius"],
                )
                returns = report["return_to_idle_links"][profile["source_action"]]
                self.assertEqual(len(returns), 1)
                self.assertEqual(
                    returns[0]["transition_start_frame"],
                    profile["exit_start_frame"],
                )
                self.assertEqual(
                    returns[0]["linking_frame"],
                    profile["linking_frame"],
                )

if __name__ == "__main__":
    unittest.main()

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

    def test_bruce_exact_hard_reactions_are_not_presented_as_clips(self):
        data = json.loads(CONFIG.read_text(encoding="utf-8"))
        exact = data["exact_reactions"]
        self.assertEqual([item["source_action"] for item in exact["hit"]], [
            "impacthardfrontmid",
            "impacthardrightlow",
        ])
        self.assertEqual(exact["hit"][0]["exit_start_frame"], 27)
        self.assertEqual(exact["hit"][0]["animation_duration_frames"], 30)
        self.assertEqual(exact["hit"][0]["animation_radius"], 40.0)
        self.assertEqual(exact["hit"][0]["return_action"], "idle")
        self.assertTrue(exact["hit"][0]["return_implemented"])
        self.assertFalse(exact["hit"][0]["clip_implemented"])
        self.assertEqual(exact["hit"][1]["exit_start_frame"], 23)
        self.assertEqual(exact["hit"][1]["animation_radius"], 70.0)
        self.assertEqual(exact["hit"][1]["return_action"], "facedownidle")
        self.assertFalse(exact["hit"][1]["return_implemented"])
        self.assertFalse(exact["hit"][1]["clip_implemented"])
        self.assertEqual(exact["block"][0]["source_action"], "highblockhard")
        self.assertEqual(exact["block"][0]["exit_start_frame"], 11)
        self.assertEqual(exact["block"][0]["animation_duration_frames"], 14)
        self.assertEqual(exact["block"][0]["animation_radius"], 25.0)
        self.assertEqual(exact["block"][0]["return_action"], "idle2")
        self.assertFalse(exact["block"][0]["return_implemented"])
        self.assertFalse(exact["block"][0]["clip_implemented"])

    def test_brick_mapping_is_limited_to_the_four_current_clips(self):
        path = CONFIG.with_name("fighting_set_m03_mapped_attacks.json")
        data = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(data["schema_version"], 4)
        self.assertEqual(data["source_archive"], "thai.set")
        self.assertFalse(data["metadata"]["radiusscale_present"])
        self.assertEqual(data["source_geometry"]["radius_scale"], 1.0)
        self.assertEqual(data["source_geometry"]["animation_radii"], {
            "m03_idle_01": 43.0,
            "m03_pnch_low_01": 40.0,
            "m03_kck_low_01": 50.0,
            "m03_movefwd": 50.0,
        })
        punch = data["attacks"]["punch"]
        kick = data["attacks"]["kick"]
        self.assertEqual(punch["source_action"], "lowpunch3")
        self.assertEqual(
            [punch[key] for key in ("startup_frames", "active_frames", "recovery_frames")],
            [8, 4, 26],
        )
        self.assertEqual(punch["damage"], 7.0)
        self.assertEqual(punch["source_impact"]["strength"], "hard")
        self.assertEqual(punch["source_impact"]["direction"], "frontal")
        self.assertEqual(kick["source_action"], "lowkick3")
        self.assertEqual(
            [kick[key] for key in ("startup_frames", "active_frames", "recovery_frames")],
            [9, 3, 29],
        )
        self.assertEqual(kick["damage"], 7.0)
        self.assertEqual(kick["source_impact"]["direction"], "fromright")
        for group in data["reaction_profiles"].values():
            for profile in group.values():
                self.assertFalse(profile["clip_implemented"])



if __name__ == "__main__":
    unittest.main()

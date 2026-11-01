import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from kdf_reaction_root_motion import (
    ReactionRootMotionError,
    summarize_vectors,
    validate_positions_frame_count,
)

REPORT = (
    Path(__file__).resolve().parents[1]
    / "reports"
    / "reaction_root_motion_inventory.json"
)


class TestReactionRootMotion(unittest.TestCase):
    def test_summarize_positions_vectors(self):
        result = summarize_vectors([
            [0.0, 0.0, 0.0],
            [0.5, 3.0, -1.0],
            [1.0, 6.0, 2.0],
        ])
        self.assertEqual(result["frame_count"], 3)
        self.assertEqual(result["first"], [0.0, 0.0, 0.0])
        self.assertEqual(result["last"], [1.0, 6.0, 2.0])
        self.assertEqual(result["minimum"], [0.0, 0.0, -1.0])
        self.assertEqual(result["maximum"], [1.0, 6.0, 2.0])
        self.assertEqual(result["range"], [1.0, 6.0, 3.0])
        self.assertEqual(result["maximum_absolute"], [1.0, 6.0, 2.0])

    def test_invalid_positions_vectors_are_rejected(self):
        with self.assertRaisesRegex(ReactionRootMotionError, "three-component"):
            summarize_vectors([[0.0, 0.0]])
        with self.assertRaisesRegex(ReactionRootMotionError, "non-finite"):
            summarize_vectors([[0.0, float("nan"), 0.0]])

    def test_frame_count_must_match_animation_duration(self):
        values = [[0.0, 0.0, 0.0], [0.0, 1.0, 0.0]]
        validate_positions_frame_count(values, 2)
        with self.assertRaisesRegex(ReactionRootMotionError, "expected 3"):
            validate_positions_frame_count(values, 3)
        with self.assertRaisesRegex(ReactionRootMotionError, "duration"):
            validate_positions_frame_count(values, 0)

    def test_checked_in_report_matches_observed_tracks(self):
        report = json.loads(REPORT.read_text(encoding="utf-8"))
        actions = {action["source_action"]: action for action in report["actions"]}
        self.assertEqual(set(actions), {
            "impactlightfrontlow",
            "impactlightfrontmid",
            "impactlightfronthigh",
            "lowblock",
            "midblock",
            "highblock",
            "impactlightlefthigh", "impactlightrighthigh",
            "impactlightleftlow", "impactlightrightlow",
            "impacthardleftlow", "impacthardlefthigh", "impacthardabove",
            "impacthardfrontlow", "impacthardfrontmid", "impacthardrighthigh",
            "impacthardfronthigh", "impactbrutalmid", "impactbrutalleft",
            "impactbrutalright",
        })
        expected_last = {
            "impactlightleftlow": [7.284912109375, 1.511962890625, 0.0],
            "impactlightrightlow": [12.990478515625, 0.0, 0.0],
            "impacthardleftlow": [-37.579345703125, -6.0205078125, 0.0],
            "impacthardlefthigh": [-199.57080078125, 51.24755859375, 0.0],
            "impacthardabove": [0.0, -35.1337890625, 0.0],
            "impacthardfrontlow": [-2.05224609375, -3.348388671875, 0.0],
            "impacthardfrontmid": [0.0009765625, 69.15380859375, 0.0],
            "impacthardrighthigh": [194.52294921875, 31.501220703125, 0.0],
            "impacthardfronthigh": [-0.761962890625, 200.7998046875, 0.0],
            "impactbrutalmid": [12.145263671875, 181.56494140625, 0.0],
            "impactbrutalleft": [-187.198974609375, 19.37939453125, -0.136962890625],
            "impactbrutalright": [187.095458984375, 43.887451171875, 0.0],
        }
        for name, last in expected_last.items():
            with self.subTest(action=name):
                self.assertTrue(actions[name]["positions_track_present"])
                self.assertTrue(actions[name]["track_presence"]["positions"])
                self.assertEqual(actions[name]["positions"][-1], last)
                self.assertEqual(actions[name]["positions_summary"]["last"], last)
        for name in ("impactlightlefthigh", "impactlightrighthigh"):
            with self.subTest(action=name):
                self.assertFalse(actions[name]["positions_track_present"])
                self.assertFalse(actions[name]["track_presence"]["positions"])
                self.assertNotIn("positions", actions[name])
                self.assertTrue(actions[name]["track_presence"]["bonepos"])
        expected_animations = {
            "impactlightlefthigh": "all_impct_light_lft_high.anm",
            "impactlightrighthigh": "all_impct_light_rht_high.anm",
            "impactlightleftlow": "all_impct_light_lft_low.anm",
            "impactlightrightlow": "all_impct_light_rht_low.anm",
            "impacthardleftlow": "all_impct_hard_lft_low.anm",
            "impacthardlefthigh": "all_impct_hard_lft_high.anm",
            "impacthardabove": "all_impct_hard_above.anm",
            "impacthardfrontlow": "all_impct_hard_frnt_low.anm",
            "impacthardfrontmid": "all_impct_crotch.anm",
            "impacthardrighthigh": "all_impct_hard_rht_high.anm",
            "impacthardfronthigh": "all_impct_hard_frnt_high.anm",
            "impactbrutalmid": "all_sp_pnch_low_forset04.anm",
            "impactbrutalleft": "all_impct_spectacular_lft.anm",
            "impactbrutalright": "all_impct_spectacular_rht.anm",
        }
        for name, filename in expected_animations.items():
            with self.subTest(action=name):
                self.assertEqual(actions[name]["animation"],
                                 f"adreno_200/animation/{filename}")
        for name, action in actions.items():
            with self.subTest(action=name):
                if action["positions_track_present"]:
                    self.assertEqual(len(action["positions"]), action["headers"]["duration"])
                    self.assertEqual(action["positions_summary"],
                                     summarize_vectors(action["positions"]))
                else:
                    self.assertNotIn("positions", action)
                    self.assertNotIn("positions_summary", action)
        self.assertEqual(report["evidence"]["positions_axis_semantics"], "UNVERIFIED")
        self.assertEqual(
            actions["impactlightfrontlow"]["positions_summary"]["maximum_absolute"],
            [0.0, 18.252197265625, 0.0],
        )
        self.assertEqual(
            actions["impactlightfrontmid"]["positions_summary"]["last"],
            [0.0, 22.845458984375, 0.0],
        )
        self.assertEqual(
            actions["impactlightfronthigh"]["positions_summary"]["last"],
            [0.373291015625, 36.86962890625, 0.0],
        )
        for action in ("lowblock", "midblock", "highblock"):
            self.assertFalse(actions[action]["positions_track_present"])
            self.assertTrue(actions[action]["track_presence"]["bonepos"])
        self.assertEqual(
            report["evidence"]["push_or_knockback_mapping"],
            "HYPOTHESIS",
        )


if __name__ == "__main__":
    unittest.main()

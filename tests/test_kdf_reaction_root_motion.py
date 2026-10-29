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
        })
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

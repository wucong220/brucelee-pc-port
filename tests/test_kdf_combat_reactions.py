from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from kdf_combat_reactions import _condition_matches, _return_links, _select_links


class TestKdfCombatReactions(unittest.TestCase):
    def test_condition_selection_is_exact(self):
        links = [
            {
                "from_group": "impactable",
                "to": "impactlightfrontlow",
                "conditions": [
                    "impact",
                    "oppattackstrengthnormal",
                    "oppattackheightlow",
                    "oppattackdirfrontal",
                ],
            },
            {
                "from_group": "impactable",
                "to": "impacthardfrontlow",
                "conditions": [
                    "impact",
                    "oppattackstrengthhard",
                    "oppattackheightlow",
                    "oppattackdirfrontal",
                ],
            },
        ]
        selected = _select_links(
            links,
            group="impactable",
            strength="normal",
            height="low",
            direction="frontal",
        )
        self.assertEqual([item["to"] for item in selected], ["impactlightfrontlow"])
        self.assertFalse(_condition_matches(
            links[0],
            strength="normal",
            height="medium",
            direction="frontal",
        ))

    def test_return_links_are_sorted_by_transition_start(self):
        links = [
            {"from": "impactlightfrontmid", "to": "idle", "time": [14, 16]},
            {"from": "impactlightfrontmid", "to": "idle", "time": [12, 16]},
            {"from": "impactlightfrontlow", "to": "idle", "time": [13, 16]},
            {"from": "impactlightfrontlow", "to": "stun", "time": [0, 1]},
        ]
        result = _return_links(
            links,
            {"impactlightfrontmid", "impactlightfrontlow"},
        )
        self.assertEqual(
            [item["time"][0] for item in result["impactlightfrontmid"]],
            [12, 14],
        )
        self.assertEqual(
            [item["transition_start_frame"] for item in result["impactlightfrontmid"]],
            [12, 14],
        )
        self.assertEqual(len(result["impactlightfrontlow"]), 1)


if __name__ == "__main__":
    unittest.main()

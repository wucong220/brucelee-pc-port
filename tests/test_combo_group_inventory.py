from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from kdf_combo_group_inventory import (  # noqa: E402
    GroupInventoryError,
    collect_links,
    collect_members,
)


def _action(name, groups, animation="m01_test", pose="stand"):
    return {
        "name": name,
        "groups": groups,
        "binary": {"basename": animation},
        "pose": pose,
    }


class TestComboGroupInventory(unittest.TestCase):
    def test_members_are_filtered_sorted_and_normalized(self):
        actions = [
            _action("highpunch1", [["impactable", [0, 101], 0],
                                   ["candobasicattacks", [17, 101], 0]], "m01_pnch_high_01"),
            _action("idle", [["candobasicattacks", [0, 140], 0]], "m01_idle_04"),
            _action("lowpunch1", [["canmove", [0, 69], 0]], "m01_pnch_low_01"),
            _action("lowkick1", [["candobasicattacks", [31, 86], 0]], "m01_kick_low_01"),
        ]
        members = collect_members(actions, "candobasicattacks")
        self.assertEqual([item["name"] for item in members],
                         ["idle", "highpunch1", "lowkick1"])
        self.assertEqual(members[1]["window"], [17, 101])
        self.assertEqual(members[1]["animation"], "m01_pnch_high_01")
        self.assertEqual(members[1]["linking_frame"], 0)

    def test_unknown_group_returns_no_members(self):
        actions = [_action("idle", [["candobasicattacks", [0, 140], 0]])]
        self.assertEqual(collect_members(actions, "canmove"), [])

    def test_malformed_group_entry_is_rejected(self):
        actions = [_action("idle", [["candobasicattacks", [0], 0]])]
        with self.assertRaises(GroupInventoryError):
            collect_members(actions, "candobasicattacks")
        actions = [_action("idle", [["candobasicattacks", [5, 1], 0]])]
        with self.assertRaises(GroupInventoryError):
            collect_members(actions, "candobasicattacks")
        actions = [_action("idle", [["candobasicattacks", [0, 140], -1]])]
        with self.assertRaises(GroupInventoryError):
            collect_members(actions, "candobasicattacks")
        actions = [_action("idle", [["candobasicattacks", [0, 140], 0], "bad"])]
        with self.assertRaises(GroupInventoryError):
            collect_members(actions, "candobasicattacks")

    def test_links_are_filtered_and_sorted(self):
        links = [
            {"from_group": "canblock", "to": "all_block_low", "keysequence": []},
            {"from_group": "candobasicattacks", "to": "highpunch1",
             "keysequence": [["pressa"], ["pressa"], ["pressa"]],
             "conditions": [], "entry_frame": 0, "blending": 2},
            {"from_group": "candobasicattacks", "to": "lowkick1",
             "keysequence": [["pressb"], ["pressd"], ["pressd"]],
             "conditions": [], "entry_frame": 0, "blending": 2},
        ]
        selected = collect_links(links, "candobasicattacks")
        self.assertEqual([item["to"] for item in selected], ["highpunch1", "lowkick1"])
        self.assertEqual(selected[0]["blending"], 2)

    def test_link_without_key_sequence_is_rejected(self):
        links = [{"from_group": "candobasicattacks", "to": "highpunch1"}]
        with self.assertRaises(GroupInventoryError):
            collect_links(links, "candobasicattacks")

    def test_empty_group_name_is_rejected(self):
        with self.assertRaises(GroupInventoryError):
            collect_members([], "")
        with self.assertRaises(GroupInventoryError):
            collect_links([], "")


if __name__ == "__main__":
    unittest.main()

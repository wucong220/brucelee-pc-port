import json
from pathlib import Path
import unittest

REPORTS = Path(__file__).resolve().parents[1] / "reports"


def _load(name):
    return json.loads((REPORTS / name).read_text(encoding="utf-8"))


class TestReportConsistency(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inventory = _load("candobasicattacks_group_inventory.json")
        cls.grab = _load("grab_finisher_evidence.json")
        cls.directional = _load("directional_combo_evidence.json")

    def test_grab_links_match_the_group_inventory(self):
        inventory_links = {
            link["source_index"]: link for link in self.inventory["links"]
        }
        self.assertGreater(len(self.grab["links"]), 0)
        for link in self.grab["links"]:
            with self.subTest(link=link["to"]):
                source = inventory_links[link["source_index"]]
                self.assertEqual(source["to"], link["to"])
                self.assertEqual(source["conditions"], link["conditions"])
                self.assertEqual(source["keysequence"], link["keysequence"])
                self.assertEqual(source["entry_frame"], link["entry_frame"])
                self.assertEqual(source["blending"], link["blending"])
                self.assertTrue(link["to"].startswith("endattack"))

    def test_grab_stun_entries_are_gated_by_healthzero(self):
        self.assertGreater(self.grab["stun_entry_count"], 0)
        for entry in self.grab["stun_entry_evidence"]:
            with self.subTest(target=entry["to"]):
                self.assertIn("healthzero", entry["conditions"])
                self.assertIn(entry["to"], ("impactstunhigh", "impactstunlow"))
                self.assertIsNotNone(entry["stun_link"])
                self.assertEqual(entry["stun_link"]["to"], "stun")

    def test_directional_actions_match_inventory_members(self):
        members = {item["name"]: item for item in self.inventory["members"]}
        for name, action in self.directional["actions"].items():
            with self.subTest(action=name):
                member = members[name]
                self.assertEqual(member["window"], action["candobasicattacks_window"])
                self.assertEqual(member["animation"], action["animation"])
                self.assertGreater(action["animation_frame_count"], 0)
                self.assertGreater(action["damage"], 0)
                self.assertEqual(
                    action["damage_time"][0] < action["damage_time"][1], True
                )

    def test_directional_reaction_link_matches_source_group(self):
        reaction = self.directional["reaction"]
        self.assertEqual(reaction["trigger"]["from_group"], "impactable")
        self.assertIn("oppattackstrengthhard", reaction["trigger"]["conditions"])
        self.assertIn("oppattackheighthigh", reaction["trigger"]["conditions"])
        self.assertIn("oppattackdirfromright", reaction["trigger"]["conditions"])
        self.assertEqual(reaction["return_link"]["to"], "faceupidle")


if __name__ == "__main__":
    unittest.main()

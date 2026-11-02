import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "godot" / "data" / "move_training_catalog.json"
PLAYER_CONFIG = ROOT / "godot" / "data" / "fighting_set_low_attacks.json"

SUCCESS = {"hit", "parry", "started"}
EXTRA_ATTACK_ACTIONS = {"attacktofloor", "facedownattack", "heavy"}
SETUPS = {
    "idle", "source_punch", "source_kick", "source_high_punch",
    "source_high_kick", "source_high_punch2", "source_low_punch2",
    "source_low_kick2", "source_high_kick2", "source_high_punch3",
    "parry_high", "parry_low", "parry_attack",
    "endattack1", "endattack2", "target_down", "player_down",
}


class MoveTrainingCatalogTest(unittest.TestCase):
    def setUp(self):
        self.data = json.loads(CATALOG.read_text(encoding="utf-8"))
        self.entries = self.data["entries"]
        self.attacks = json.loads(PLAYER_CONFIG.read_text(encoding="utf-8"))["attacks"]

    def test_catalog_is_sequential_and_unique(self):
        self.assertEqual(len(self.entries), 26)
        ids = [entry["id"] for entry in self.entries]
        self.assertEqual(len(ids), len(set(ids)))
        groups = [entry["group"] for entry in self.entries]
        self.assertEqual(groups[0], "BASIC")
        self.assertEqual(groups[-1], "BASIC")

    def test_entries_have_valid_schema(self):
        for entry in self.entries:
            self.assertIn(entry["success"], SUCCESS)
            self.assertIn(entry["setup"], SETUPS)
            self.assertTrue(entry["input"])
            self.assertTrue(entry["actions"])
            self.assertTrue(all(
                action in self.attacks or action in EXTRA_ATTACK_ACTIONS
                for action in entry["actions"]
            ), entry["id"])

    def test_miss_variants_are_not_lessons(self):
        for entry in self.entries:
            self.assertFalse(any("_miss" in action for action in entry["actions"]),
                             entry["id"])


if __name__ == "__main__":
    unittest.main()

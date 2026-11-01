import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "godot" / "data" / "fighting_set_low_attacks.json"
RAW = ROOT / "reports" / "raw_attack_fields.json"

KEYS = {
    "highpunch2": "high_punch2",
    "endattack1": "endattack1",
    "endattack2": "endattack2",
    "specialkicklowhit": "special_kick_low_hit",
    "parryattack": "parry_attack",
    "grab1": "grab1",
    "grab2": "grab2",
    "grab1miss": "grab1_miss",
    "grab2miss": "grab2_miss",
}


class RawAttackFieldsTest(unittest.TestCase):
    def test_config_matches_recovered_attack_fields(self) -> None:
        config = json.loads(CONFIG.read_text(encoding="utf-8"))["attacks"]
        raw = json.loads(RAW.read_text(encoding="utf-8"))["actions"]
        for raw_name, config_name in KEYS.items():
            action = config[config_name]
            impacts = raw[raw_name]["impacts"]
            if "multi_impacts" in action:
                actual = action["multi_impacts"]
                self.assertEqual(len(actual), len(impacts), config_name)
                for got, expected in zip(actual, impacts):
                    self.assertEqual(
                        {
                            "damage": got["damage"],
                            "damage_time": got["damage_time"],
                            "attack_radius": got["attack_radius"],
                            "body_part": got["body_part"],
                            "height": got["height"],
                            "strength": got["strength"],
                            "direction": got["direction"],
                        },
                        {
                            "damage": expected["damage_amount"],
                            "damage_time": expected["damage_time"],
                            "attack_radius": expected["attack_radius"],
                            "body_part": expected["body_part"],
                            "height": expected["height"],
                            "strength": expected["strength"],
                            "direction": expected["direction"],
                        },
                        config_name,
                    )
                continue
            expected = impacts[0]
            self.assertEqual(action["damage"], expected["damage_amount"], config_name)
            self.assertEqual(
                action["source_impact"],
                {
                    "attack_radius": expected["attack_radius"],
                    "body_part": expected["body_part"],
                    "height": expected["height"],
                    "strength": expected["strength"],
                    "direction": expected["direction"],
                },
                config_name,
            )
            if expected["damage_amount"] > 0 or config_name.startswith("grab"):
                self.assertEqual(
                    [
                        action["startup_frames"],
                        action["startup_frames"] + action["active_frames"] - 1,
                    ],
                    expected["damage_time"],
                    config_name,
                )
        fighter_source = (ROOT / "godot" / "scripts" / "fighter.gd").read_text(
            encoding="utf-8"
        )
        self.assertIn('attack_kind == "parry_attack"', fighter_source)
        self.assertIn('attack_kind == "parry_low"', fighter_source)
        self.assertIn('attack_kind == "special_punch_low_miss"', fighter_source)
        self.assertEqual(raw["parrylow"]["animation_radius"], 40.0)
        self.assertEqual(raw["specialpunchlowmiss"]["animation_radius"], 45.0)
        self.assertIn("return 25.0 * radius_scale", fighter_source)
        self.assertIn("return 40.0 * radius_scale", fighter_source)
        self.assertIn("return 45.0 * radius_scale", fighter_source)


if __name__ == "__main__":
    unittest.main()

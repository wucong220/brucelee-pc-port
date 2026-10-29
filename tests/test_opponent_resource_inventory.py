import json
from pathlib import Path
import unittest


REPORT = Path(__file__).resolve().parents[1] / "reports" / "brick_opponent_inventory.json"


def _keys(value):
    if isinstance(value, dict):
        for key, child in value.items():
            yield key
            yield from _keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from _keys(child)


class TestOpponentResourceInventory(unittest.TestCase):
    def test_report_is_deterministic_and_contains_no_binary_payload(self):
        raw = REPORT.read_text(encoding="utf-8")
        report = json.loads(raw)
        self.assertEqual(
            json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            raw,
        )
        self.assertEqual(report["target"], "bl_brick_davis_01")
        self.assertEqual(report["skeleton"]["bone_count"], 70)
        self.assertEqual(report["object"]["scene_node_count"], 76)
        self.assertEqual(
            sorted(report["animations"]),
            [
                "m03_idle_01",
                "m03_kck_low_01",
                "m03_movefwd",
                "m03_pnch_low_01",
            ],
        )
        self.assertEqual(
            {entry["skeleton_reference"] for entry in report["animations"].values()},
            {"skeletons/bl_brick_davis_01_high.skl"},
        )
        forbidden = {"pixels", "payload", "binary", "raw_bytes"}
        self.assertFalse(forbidden.intersection(_keys(report)))

    def test_report_marks_runtime_opponent_work_unverified(self):
        report = json.loads(REPORT.read_text(encoding="utf-8"))
        self.assertEqual(report["evidence"]["godot_opponent_integration"], "UNVERIFIED")
        self.assertEqual(report["evidence"]["opponent_combat_configuration"], "UNVERIFIED")
        self.assertEqual(report["evidence"]["visual_runtime_parity"], "UNVERIFIED")


if __name__ == "__main__":
    unittest.main()

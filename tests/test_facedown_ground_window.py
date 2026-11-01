import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIGHTER = ROOT / "godot" / "scripts" / "fighter.gd"
REPORT = ROOT / "reports" / "bruce_facedown_followups.json"
FACEUP_REPORT = ROOT / "reports" / "bruce_faceup_fields.json"


def _window(text: str, state: str) -> tuple[float, float]:
    pattern = re.compile(
        r'\(state == "' + re.escape(state) + r'"'
        r'\s+and source_frame \+ 0\.0001 >= ([0-9.]+)'
        r'\s+and source_frame <= ([0-9.]+)\)'
    )
    match = pattern.search(text)
    if match is None:
        raise AssertionError(f"missing impact-to-floor window for {state}")
    return float(match.group(1)), float(match.group(2))


class FacedownGroundWindowTest(unittest.TestCase):
    def test_facedown_attack_window_matches_recovered_group(self) -> None:
        data = json.loads(REPORT.read_text(encoding="utf-8"))
        groups = {
            entry[0]: entry[1]
            for entry in data["actions"]["facedownattack"]["groups"]
        }
        expected = groups["impactablefromground"]
        actual = _window(FIGHTER.read_text(encoding="utf-8"), "facedownattack")
        self.assertEqual(
            (actual[0], round(actual[1] - 0.0001, 4)),
            (float(expected[0]), float(expected[1])),
        )

    def test_faceup_attack_window_remains_separate(self) -> None:
        data = json.loads(FACEUP_REPORT.read_text(encoding="utf-8"))
        groups = {
            entry[0]: entry[1]
            for entry in data["actions"]["faceupattack"]["groups"]
        }
        actual = _window(FIGHTER.read_text(encoding="utf-8"), "faceupattack")
        expected = groups["impactablefromground"]
        self.assertEqual(
            (actual[0], round(actual[1] - 0.0001, 4)),
            (float(expected[0]), float(expected[1])),
        )

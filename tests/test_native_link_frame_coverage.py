import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class NativeLinkFrameCoverageTests(unittest.TestCase):
    def test_link_fallbacks_are_zero_and_backed_by_data(self):
        source = (ROOT / "godot" / "scripts" / "fighter.gd").read_text(encoding="utf-8")
        links = json.loads(
            (ROOT / "godot" / "data" / "native_links.json").read_text(encoding="utf-8")
        )["links"]

        start_calls = re.findall(
            r'_native_link_start_frame\("([^"]+)",\s*(\d+)\)', source
        )
        self.assertTrue(start_calls)
        for action, fallback in start_calls:
            self.assertEqual(fallback, "0", f"{action} still uses a numeric fallback")
            self.assertTrue(
                any(str(link.get("from")) == action for link in links),
                f"{action} has no outgoing native link",
            )

        entry_calls = re.findall(
            r'_native_entry_frame\("([^"]+)",\s*(\d+)\)', source
        )
        self.assertTrue(entry_calls)
        for action, fallback in entry_calls:
            self.assertEqual(fallback, "0", f"{action} still uses a numeric fallback")
            self.assertTrue(
                any(str(link.get("to")) == action for link in links),
                f"{action} has no incoming native link with entry_frame",
            )

    def test_no_removed_candidate_blend_constants(self):
        source = (ROOT / "godot" / "scripts" / "fighter.gd").read_text(encoding="utf-8")
        for name in (
            "CANDIDATE_ATTACK_TO_FLOOR_BLENDING_FRAMES",
            "CANDIDATE_ATTACK_TO_FLOOR_RETURN_BLENDING_FRAMES",
            "CANDIDATE_BRICK_FACEDOWN_IMPACT_BLENDING_FRAMES",
        ):
            self.assertNotIn(name, source)


if __name__ == "__main__":
    unittest.main()

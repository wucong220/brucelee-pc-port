import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LINKS = ROOT / "godot" / "data" / "native_links.json"

# Tokens the GDScript normalizer understands.
PRESS_TOKENS = {
    "pressa", "pressb", "pressc", "pressd",
    "pressup", "pressdown", "pressleft", "pressright",
    "pressin", "pressout",
}
# Explicitly inert sentinel used by disabled native links.
INERT_PRESS = {"pressimpossible"}
STATUS_KEYS = {"left", "right", "up", "down", "in", "out"}
INERT_STATUS = {"impossible"}
STATUS_VALUES = {"pressed", "released"}


class LinkTokenCoverageTest(unittest.TestCase):
    def setUp(self) -> None:
        self.links = json.loads(LINKS.read_text(encoding="utf-8"))["links"]

    def test_every_press_token_is_supported_or_inert(self) -> None:
        unknown = set()
        for link in self.links:
            for sequence in link.get("keysequence", []):
                for token in sequence:
                    if token not in PRESS_TOKENS and token not in INERT_PRESS:
                        unknown.add(str(token))
        self.assertEqual(unknown, set())

    def test_every_keystatus_key_is_supported_or_inert(self) -> None:
        unknown = set()
        values = set()
        for link in self.links:
            for sequence in link.get("keystatus", []):
                for pair in sequence:
                    key = str(pair[0])
                    values.add(str(pair[1]))
                    if key not in STATUS_KEYS and key not in INERT_STATUS:
                        unknown.add(key)
        self.assertEqual(unknown, set())
        self.assertLessEqual(values, STATUS_VALUES)


if __name__ == "__main__":
    unittest.main()

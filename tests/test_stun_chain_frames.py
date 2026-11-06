import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIGHTER = ROOT / "godot" / "scripts" / "fighter.gd"
LINKS = ROOT / "godot" / "data" / "native_links.json"


class StunChainFramesTest(unittest.TestCase):
    def test_stun_constants_match_recovered_link_windows(self) -> None:
        text = FIGHTER.read_text(encoding="utf-8")
        stun = int(re.search(r"const STUN_DURATION_FRAMES: int = (\d+)", text).group(1))
        fall = int(re.search(r"const STUN_FALL_DURATION_FRAMES: int = (\d+)", text).group(1))
        links = json.loads(LINKS.read_text(encoding="utf-8"))["links"]

        def start(source: str, target: str) -> int:
            for link in links:
                if str(link.get("from", "")) == source and str(link.get("to", "")) == target:
                    return int(link["time"][0])
            self.fail(source + "->" + target + " link is missing")

        self.assertEqual(stun, start("stun", "stun2"))
        self.assertEqual(stun, start("stun2", "stunfall"))
        self.assertEqual(fall, start("stunfall", "faceupko"))


if __name__ == "__main__":
    unittest.main()

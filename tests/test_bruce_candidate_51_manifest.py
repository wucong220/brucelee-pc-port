import json
from pathlib import Path
import re
import unittest


MANIFEST = (
    Path(__file__).resolve().parents[1]
    / "reports"
    / "bruce_candidate_51_manifest.json"
)


class TestBruceCandidate51Manifest(unittest.TestCase):
    def test_manifest_records_the_expected_external_candidate(self):
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(data["bytes"], 4222908)
        self.assertEqual(
            data["sha256"],
            "c9e40355bd61a9e897c3e81342b10e2c9b68cf45c0d5f77d861f96817e70d73c",
        )
        self.assertEqual(data["animation_count"], 51)
        self.assertEqual(
            data["skeleton_sha256"],
            "4a6d4532b42d6cbee3016b849befc2dc98c089e72fa4cfe291d9550f059412e3",
        )
        animations = data["animations"]
        self.assertEqual(len(animations), 51)
        names = [animation["name"] for animation in animations]
        self.assertEqual(len(set(names)), 51)
        for animation in animations:
            self.assertRegex(
                animation["source_animation_sha256"], re.compile(r"^[0-9a-f]{64}$")
            )
        target = next(
            animation
            for animation in animations
            if animation["name"] == "all_impct_hard_frnt_low"
        )
        self.assertEqual(
            target["source_animation_sha256"],
            "c38c0b8c3445ec9f4f237c9a882ed960ce6c7b0e333dbdd9e127742d33ff1647",
        )


if __name__ == "__main__":
    unittest.main()

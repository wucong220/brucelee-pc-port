from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from kdf_grab_finisher_evidence import build_report  # noqa: E402


class TestGrabFinisherEvidence(unittest.TestCase):
    def test_endattack_links_keep_source_index_and_target_metadata(self):
        metadata = {
            "endattack1": {
                "record": 44,
                "animation": "m01_end_attack_01.anm",
                "animation_ordinal": 5,
                "radius": 45.0,
            },
            "impactstunhigh": {
                "record": 47,
                "animation": "all_impct_light_frnt_high.anm",
                "animation_ordinal": 7,
                "radius": 25.0,
            },
        }
        links = [
            {"to": "endattack1", "keysequence": [["pressb"], ["pressa"], ["pressa"]],
             "conditions": ["oppposestun", "grabdistance"], "entry_frame": 0, "blending": 2},
            {"to": "impactstunhigh", "conditions": ["impact", "healthzero"]},
            {"from": "impactstunhigh", "to": "stun", "time": [14, 17], "blending": 3},
            {"to": "lowpunch1", "conditions": []},
        ]
        report = build_report(metadata, links)
        self.assertEqual(report["link_count"], 1)
        link = report["links"][0]
        self.assertEqual(link["source_index"], 0)
        self.assertEqual(link["target_record"], 44)
        self.assertEqual(link["target_animation"], "m01_end_attack_01.anm")
        self.assertEqual(link["target_radius"], 45.0)
        self.assertEqual(report["stun_entry_count"], 1)
        stun = report["stun_entry_evidence"][0]
        self.assertEqual(stun["source_index"], 1)
        self.assertEqual(stun["target_record"], 47)
        self.assertEqual(stun["stun_link"]["source_index"], 2)
        self.assertEqual(stun["stun_link"]["time"], [14, 17])

    def test_no_endattack_links_is_valid(self):
        report = build_report({}, [{"to": "lowpunch1"}])
        self.assertEqual(report["link_count"], 0)
        self.assertEqual(report["stun_entry_count"], 0)


if __name__ == "__main__":
    unittest.main()

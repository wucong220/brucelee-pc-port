import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ATTACKS = ROOT / "godot" / "data" / "fighting_set_low_attacks.json"
LINKS = ROOT / "godot" / "data" / "native_links.json"


class AttackPhaseWindowTest(unittest.TestCase):
    def setUp(self) -> None:
        self.attacks = json.loads(ATTACKS.read_text(encoding="utf-8"))["attacks"]
        payload = json.loads(LINKS.read_text(encoding="utf-8"))
        rows = payload["actions"]
        self.links = payload["links"]
        self.rows = {str(row["name"]): row for row in rows}

    def test_phase_windows_match_recovered_damage_time(self) -> None:
        checked = 0
        for kind, attack in self.attacks.items():
            source = str(attack.get("source_action", ""))
            row = self.rows.get(source)
            if row is None:
                # parry_low has no native action; it is an invented low parry
                # that gameplay no longer uses (parry is parryhigh only).
                self.assertEqual(kind, "parry_low")
                continue
            windows = []
            impact = row.get("impact") or {}
            if isinstance(impact.get("damage_time"), list):
                windows.append(impact["damage_time"])
            for extra in attack.get("multi_impacts", []) or []:
                if isinstance(extra.get("damage_time"), list):
                    windows.append(extra["damage_time"])
            if not windows:
                # No recovered impact: non-damaging actions (miss/parry) take
                # their phase split from the outgoing hit link window, or use
                # the whole clip when there is no such link.
                outgoing = [
                    link["time"]
                    for link in self.links
                    if str(link.get("from", "")) == source
                    and str(link.get("to", "")) != "idle"
                    and str(link.get("to", "")) != "idle2"
                    and isinstance(link.get("time"), list)
                ]
                if kind == "parry_low":
                    # No native action; invented low parry, gameplay-unused.
                    outgoing = []
                if outgoing:
                    start = int(min(window[0] for window in outgoing))
                    end = int(max(window[1] for window in outgoing))
                    self.assertEqual(int(attack["startup_frames"]), start, kind)
                    self.assertEqual(int(attack["active_frames"]), end - start + 1, kind)
                else:
                    self.assertEqual(int(attack["startup_frames"]), 0, kind)
                    self.assertEqual(int(attack["active_frames"]), 0, kind)
                self.assertEqual(
                    int(attack["startup_frames"])
                    + int(attack["active_frames"])
                    + int(attack["recovery_frames"]),
                    int(attack["animation_frame_count"]),
                    kind,
                )
                checked += 1
                continue
            start = min(int(window[0]) for window in windows)
            end = max(int(window[1]) for window in windows)
            self.assertEqual(int(attack["startup_frames"]), start, kind)
            self.assertEqual(int(attack["active_frames"]), end - start + 1, kind)
            self.assertEqual(
                int(attack["startup_frames"])
                + int(attack["active_frames"])
                + int(attack["recovery_frames"]),
                int(attack["animation_frame_count"]),
                kind,
            )
            checked += 1
        self.assertGreater(checked, 20)


if __name__ == "__main__":
    unittest.main()

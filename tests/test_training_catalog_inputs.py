import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
KEYS = {
    "pressa": "J", "pressb": "K", "pressc": "L", "pressd": "U",
    "pressup": "W", "pressdown": "S", "pressleft": "A", "pressright": "D",
    "pressin": "W", "pressout": "S",
    "up": "W", "down": "S", "left": "A", "right": "D", "in": "W", "out": "S",
}


class TrainingCatalogInputTests(unittest.TestCase):
    def test_catalog_inputs_include_the_full_prerequisite_chain(self):
        data = ROOT / "godot" / "data"
        links = json.loads((data / "native_links.json").read_text(encoding="utf-8"))["links"]
        catalog = json.loads((data / "move_training_catalog.json").read_text(encoding="utf-8"))
        attacks = json.loads((data / "fighting_set_low_attacks.json").read_text(encoding="utf-8"))["attacks"]
        source_of = {kind: row["source_action"] for kind, row in attacks.items()}
        kind_of = {source: kind for kind, source in source_of.items()}
        by_id = {str(entry["id"]): entry for entry in catalog["entries"]}

        def sequence_for(target):
            native_target = source_of.get(target, target)
            for link in links:
                if str(link.get("to")) != native_target:
                    continue
                variants = link.get("keysequence", [])
                statuses = link.get("keystatus", [])
                variant = variants[1] if len(variants) > 1 else []
                status = statuses[1] if len(statuses) > 1 else []
                return [KEYS.get(token, token) for token in variant], status, link.get("from")
            return [], [], None

        def immediate_for(entry):
            target = str(entry["actions"][0])
            sequence, status, source = sequence_for(target)
            if not sequence:
                fallback_kind = kind_of.get(source)
                if fallback_kind:
                    sequence, status, _ = sequence_for(fallback_kind)
            held = [
                KEYS.get(str(pair[0]), str(pair[0]))
                for pair in status
                if len(pair) >= 2 and str(pair[1]) == "pressed"
            ]
            body = ", ".join(sequence) if sequence else "(automatic / wait for window)"
            if held:
                body = "HOLD " + "+".join(dict.fromkeys(held)) + " + " + body
            return body

        def full_for(entry, seen):
            parts = []
            setup = str(entry.get("setup", "idle"))
            if setup.startswith("source_"):
                source_id = setup[len("source_"):]
                prerequisite = by_id.get(source_id)
                if prerequisite and source_id not in seen:
                    parts.extend(full_for(prerequisite, seen | {source_id}))
            elif setup in ("stepback", "stepleft", "stepright"):
                parts.append({"stepback": "S (hold)", "stepleft": "A (hold)",
                              "stepright": "D (hold)"}[setup])
            parts.append(immediate_for(entry))
            return parts

        for entry in catalog["entries"]:
            expected = ", ".join(full_for(entry, {str(entry["id"])}))
            self.assertEqual(
                entry["input"], expected,
                f"{entry['id']} instruction does not include the full prerequisite chain",
            )


if __name__ == "__main__":
    unittest.main()

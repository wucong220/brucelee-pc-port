import json
import math
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FINDINGS = ROOT / 'reports' / 'reaction_root_motion_inventory.json'
FIGHTER = ROOT / 'godot' / 'scripts' / 'fighter.gd'
BLOCK = re.compile(
    r'const REACTION_ROOT_PUSH_SOURCE: Dictionary = \{(.*?)\n\}',
    re.DOTALL,
)
ENTRY = re.compile(r'^\s*"([^"]+)":\s*([-+0-9.eE]+),?\s*$', re.MULTILINE)


def expected_values():
    report = json.loads(FINDINGS.read_text(encoding='utf-8'))
    values = {}
    for action in report['actions']:
        positions = action.get('positions')
        if not positions:
            continue
        values[action['source_action']] = max(
            abs(float(point[0])) for point in positions
        )
        values[action['source_action']] = max(
            values[action['source_action']],
            max(abs(float(point[1])) for point in positions),
        )
    return values


def configured_values():
    text = FIGHTER.read_text(encoding='utf-8')
    match = BLOCK.search(text)
    if match is None:
        raise AssertionError('REACTION_ROOT_PUSH_SOURCE block not found')
    return {
        name: float(value)
        for name, value in ENTRY.findall(match.group(1))
    }


class ReactionPushSourceTests(unittest.TestCase):
    def test_every_decoded_reaction_has_matching_source_value(self):
        expected = expected_values()
        actual = configured_values()
        self.assertEqual(set(actual), set(expected))
        for name, value in expected.items():
            self.assertTrue(
                math.isclose(actual[name], value, rel_tol=0.0, abs_tol=1e-9),
                f'{name}: configured {actual[name]} != report {value}',
            )

    def test_no_extra_reaction_entries(self):
        expected = expected_values()
        actual = configured_values()
        self.assertEqual(set(actual) - set(expected), set())


if __name__ == '__main__':
    unittest.main()

#!/usr/bin/env python3
"""Export source attack-animation positions tracks without assigning push semantics."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_reaction_root_motion import inspect_archive


def actions_from_config(path: Path) -> dict[str, str]:
    data = json.loads(path.read_text(encoding='utf-8'))
    attacks = data.get('attacks')
    if not isinstance(attacks, dict):
        raise ValueError('attack config does not contain an attacks object')
    actions: dict[str, str] = {}
    for key, entry in attacks.items():
        if not isinstance(key, str) or not isinstance(entry, dict):
            raise ValueError('attack config contains an invalid entry')
        animation = entry.get('animation')
        if animation is None:
            continue
        if not isinstance(animation, str) or not animation:
            raise ValueError(f'attack {key} has an invalid animation name')
        actions[key] = 'adreno_200/animation/' + animation + '.anm'
    if not actions:
        raise ValueError('attack config has no animations')
    return actions


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path, help='outer ZIP or data.zpak, read only')
    parser.add_argument('--config', type=Path, required=True,
                        help='Godot fighting_set_* attack JSON')
    parser.add_argument('--report', type=Path, help='write a new JSON report')
    args = parser.parse_args()
    try:
        actions = actions_from_config(args.config)
        report = inspect_archive(args.archive, actions)
        rendered = json.dumps(report, indent=2, sort_keys=True) + '\n'
        if args.report is None:
            print(rendered, end='')
        else:
            if args.report.exists():
                raise ValueError(f'report path already exists: {args.report}')
            args.report.write_text(rendered, encoding='utf-8', newline='\n')
            print(f'wrote {len(report["actions"])} attack root-motion records to {args.report}')
    except (OSError, ValueError, KeyboardInterrupt) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

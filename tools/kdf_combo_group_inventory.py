#!/usr/bin/env python3
"""Inventory one fighting-set action group and the links that start from it.

The report is derived metadata only: member windows, the member record's third
field, action names, animation basenames and link key sequences. It contains no
original binary payload and the source archive is opened read only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

from kdf_data import KdfError
from kdf_fighting_set import read_archive_resource
import kdf_combat_reactions as reactions

_DEFAULT_SET_PATH = 'adreno_200/set/brucelee.set'
_DEFAULT_GROUP = 'candobasicattacks'
_MAX_REPORT_BYTES = 8 * 1024 * 1024


class GroupInventoryError(KdfError):
    pass


def _window(value: object, name: str) -> list[int]:
    if (not isinstance(value, list) or len(value) != 2
            or any(type(item) is not int for item in value)):
        raise GroupInventoryError(f'{name} group window is not two integers')
    start, end = value
    if start < 0 or end < start:
        raise GroupInventoryError(f'{name} group window is invalid: {value}')
    return [start, end]


def collect_members(actions: list[dict], group: str) -> list[dict]:
    """Return the actions that declare a window in the requested group."""
    if not group:
        raise GroupInventoryError('group must be a non-empty name')
    members = []
    for action in actions:
        name = action.get('name')
        if not isinstance(name, str) or not name:
            raise GroupInventoryError('action has no usable name')
        groups = action.get('groups')
        if groups is None:
            continue
        if not isinstance(groups, list):
            raise GroupInventoryError(f'{name} groups is not a list')
        for entry in groups:
            if not isinstance(entry, list) or len(entry) < 3:
                raise GroupInventoryError(f'{name} has a malformed group entry')
            label = entry[0]
            if not isinstance(label, str):
                raise GroupInventoryError(f'{name} has a non-string group name')
            if label != group:
                continue
            linking_frame = entry[2]
            if type(linking_frame) is not int or linking_frame < 0:
                raise GroupInventoryError(
                    f'{name} group record third field is not a frame: {linking_frame!r}')
            binary = action.get('binary')
            animation = binary.get('basename') if isinstance(binary, dict) else None
            members.append({
                'name': name,
                'animation': animation if isinstance(animation, str) else None,
                'pose': action.get('pose') if isinstance(action.get('pose'), str) else None,
                'window': _window(entry[1], name),
                'linking_frame': linking_frame,
            })
    members.sort(key=lambda item: (item['window'][0], item['window'][1], item['name']))
    return members


def collect_links(links: list[dict], group: str) -> list[dict]:
    """Return the links whose source is the requested group."""
    if not group:
        raise GroupInventoryError('group must be a non-empty name')
    selected = []
    for link in links:
        if not isinstance(link, dict) or link.get('from_group') != group:
            continue
        target = link.get('to')
        if not isinstance(target, str) or not target:
            raise GroupInventoryError(f'{group} link has no target action')
        keysequence = link.get('keysequence')
        if not isinstance(keysequence, list):
            raise GroupInventoryError(f'{group} -> {target} link has no key sequence')
        selected.append({
            'to': target,
            'keysequence': keysequence,
            'conditions': link.get('conditions', []),
            'entry_frame': link.get('entry_frame'),
            'blending': link.get('blending'),
            'input_reset': link.get('input_reset'),
        })
    selected.sort(key=lambda item: (item['to'], json.dumps(item['keysequence'])))
    return selected


def build_report(raw: bytes, *, group: str, set_path: str = _DEFAULT_SET_PATH) -> dict:
    reader, root, actions, links = reactions._parse_set(raw)
    members = collect_members(actions, group)
    group_links = collect_links(links, group)
    if not members:
        raise GroupInventoryError(f'no action declares a {group} window')
    return {
        'schema_version': 1,
        'source': {
            'set_path': set_path,
            'action_count': len(actions),
            'link_count': len(links),
        },
        'group': group,
        'member_count': len(members),
        'link_count': len(group_links),
        'members': members,
        'links': group_links,
        'note': (
            'Derived metadata only. The member record third field and native link '
            'priority remain unverified at runtime.'
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True,
                        help='data.zpak or its containing outer ZIP, read only')
    parser.add_argument('--group', default=_DEFAULT_GROUP,
                        help=f'group name to inventory (default: {_DEFAULT_GROUP})')
    parser.add_argument('--set-path', default=_DEFAULT_SET_PATH,
                        help=f'archive set path (default: {_DEFAULT_SET_PATH})')
    parser.add_argument('--out', type=Path, required=True,
                        help='new JSON report path; the file must not exist')
    parser.add_argument('--expected-set-sha256',
                        help='require this SHA-256 for the decoded set')
    args = parser.parse_args()
    try:
        if args.out.exists():
            raise GroupInventoryError(f'report already exists: {args.out}')
        raw, archive = read_archive_resource(args.archive, args.set_path)
        if args.expected_set_sha256:
            actual = hashlib.sha256(raw).hexdigest()
            if actual != args.expected_set_sha256:
                raise GroupInventoryError('decoded set SHA-256 does not match expectation')
        report = build_report(raw, group=args.group, set_path=args.set_path)
        report['source']['set_sha256'] = hashlib.sha256(raw).hexdigest()
        report['source']['resource_id'] = archive.get('resource_id')
        text = json.dumps(report, ensure_ascii=False, indent=2)
        if len(text.encode('utf-8')) > _MAX_REPORT_BYTES:
            raise GroupInventoryError('report exceeds the size limit')
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text + '\n', encoding='utf-8')
    except (OSError, KeyError, KdfError, ValueError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    print(f"{report['group']}: {report['member_count']} members, "
          f"{report['link_count']} links -> {args.out}")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

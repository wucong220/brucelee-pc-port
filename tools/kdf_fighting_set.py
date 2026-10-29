#!/usr/bin/env python3
"""Inspect selected fighting-set records; values remain raw and uncalibrated.

This covers the observed CTX3 record-only profile and direct relative record
references. It rejects indirect or otherwise unsupported encodings.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import struct
import sys
import zipfile

from kdf_data import KdfError, parse_container, parse_context
from pak_extract import (_MAX_DATA_BYTES, _MAX_INDEX_BYTES, PakError, _open_zpak_info,
                         iter_resources, parse_directory, parse_index)

_SET_PATH = 'adreno_200/set/brucelee.set'


class RecordReader:
    def __init__(self, container: dict, context: dict):
        if container['offset_count'] != 0 or container['payload_bytes'] != 0:
            raise KdfError('expected record-only fighting-set profile')
        self.records = container['records']
        self.strings = context['strings']
        self.files = context['file_references']
        self.base = container['data_offset'] + 24

    def record(self, index: int) -> dict:
        if not 0 <= index < len(self.records):
            raise KdfError(f'record index {index} out of range')
        return self.records[index]

    def _children(self, index: int, marker: int, width: int) -> list[int]:
        record = self.record(index)
        first, relative = record['first'], record['second']
        if first & 0xffff0000 != marker:
            raise KdfError(f'record {index} has unsupported container type 0x{first:08x}')
        count = first & 0xffff
        if count == 0:
            return []
        start = index + relative
        # The observed encoding is forward relative. This also rejects cycles
        # and self references rather than trying unsupported indirect forms.
        if start <= index or start + count * width > len(self.records):
            raise KdfError(f'record {index} has invalid relative children')
        return [start + n * width for n in range(count)]

    def dictionary(self, index: int) -> dict[str, int]:
        result = {}
        for key_index in self._children(index, 0x30000000, 2):
            key = self.string(key_index)
            if key in result:
                raise KdfError(f'duplicate key {key!r} in record {index}')
            result[key] = key_index + 1
        return result

    def array(self, index: int) -> list[int]:
        return self._children(index, 0x40000000, 1)

    def string(self, index: int) -> str:
        r = self.record(index)
        if r['first'] != 0x60000000 or r['second'] >= len(self.strings):
            raise KdfError(f'record {index} has invalid string reference')
        return self.strings[r['second']]['text']

    def file(self, index: int) -> dict:
        r = self.record(index)
        if r['first'] != 0x70000000 or r['second'] >= len(self.files):
            raise KdfError(f'record {index} has invalid file reference')
        ref = self.files[r['second']]
        return {'ordinal': ref['ordinal'], 'directory': ref['directory']['text'],
                'basename': ref['basename']['text'], 'extension': ref['extension']['text']}

    def scalar(self, index: int) -> int:
        r = self.record(index)
        if r['first'] != 0:
            raise KdfError(f'record {index} has unsupported scalar type')
        return r['second']

    def decoded_value(self, index: int) -> dict:
        r = self.record(index)
        if r['first'] == 0:
            return {'type': 'integer', 'value': r['second']}
        if r['first'] == 0x20000000:
            return {'type': 'float', 'value': struct.unpack('<f', struct.pack('<I', r['second']))[0]}
        if r['first'] == 0x60000000:
            return {'type': 'string', 'value': self.string(index)}
        if r['first'] == 0x70000000:
            return {'type': 'file', 'value': self.file(index)}
        raise KdfError(f'record {index} has unsupported tagged value type 0x{r["first"]:08x}')

    def raw(self, index: int) -> dict:
        r = self.record(index)
        return {'record': index, 'offset': self.base + index * 8,
                'first': r['first'], 'second': r['second']}


def inspect_bytes(raw: bytes, actions: list[str] | None = None, *, list_actions: bool = False,
                  summary: bool = False) -> dict:
    if summary and not list_actions:
        raise KdfError('summary requires list_actions')
    if list_actions and actions:
        raise KdfError('list actions and select actions are mutually exclusive')
    if not list_actions and (not actions or len(set(actions)) != len(actions) or any(not name for name in actions)):
        raise KdfError('select one or more distinct non-empty action names')
    context = parse_context(raw)
    container = parse_container(raw, data_offset=context['data_offset'])
    reader = RecordReader(container, context)
    root = reader.dictionary(0)
    if 'animations' not in root:
        raise KdfError('root has no animations array')
    requested, found = set(actions or []), {}
    listed = []
    for index in reader.array(root['animations']):
        animation = reader.dictionary(index)
        if 'name' not in animation:
            raise KdfError(f'animation record {index} has no name')
        name = reader.string(animation['name'])
        if not name:
            raise KdfError(f'animation record {index} has an empty name')
        if list_actions:
            item = {'name': name, 'record': index,
                    'animation_file': reader.file(animation['binary']) if 'binary' in animation else None}
            if summary:
                impact_count = 0
                if 'attack' in animation:
                    attack = reader.dictionary(animation['attack'])
                    if 'impacts' in attack:
                        impact_count = len(reader.array(attack['impacts']))
                item['impact_count'] = impact_count
            listed.append(item)
            continue
        if name not in requested:
            continue
        if name in found:
            raise KdfError(f'duplicate requested action {name!r}')
        if 'binary' not in animation or 'attack' not in animation:
            raise KdfError(f'action {name!r} lacks binary or attack')
        attack = reader.dictionary(animation['attack'])
        if 'impacts' not in attack:
            raise KdfError(f'action {name!r} lacks impacts')
        impacts = []
        for impact_index in reader.array(attack['impacts']):
            fields = reader.dictionary(impact_index)
            if 'damage_time' not in fields or 'damage_amount' not in fields:
                raise KdfError(f'impact {impact_index} lacks damage fields')
            time_nodes = reader.array(fields['damage_time'])
            if len(time_nodes) != 2:
                raise KdfError(f'impact {impact_index} damage_time must have two values')
            impacts.append({
                'record': impact_index,
                'raw_fields': {key: reader.raw(value) for key, value in fields.items()},
                'decoded_fields': {
                    key: ({"type": 'integer_array', "values": [reader.scalar(i) for i in time_nodes]}
                          if key == 'damage_time' else reader.decoded_value(value))
                    for key, value in fields.items()
                },
                'damage_time_raw': [reader.scalar(i) for i in time_nodes],
                'damage_time_records': [reader.raw(i) for i in time_nodes],
                'damage_amount_raw': reader.scalar(fields['damage_amount']),
            })
        found[name] = {'name': name, 'record': index,
                       'animation_file': reader.file(animation['binary']), 'impacts': impacts}
    if list_actions:
        counts = Counter(item['name'] for item in listed)
        for item in listed:
            item['name_occurrences'] = counts[item['name']]
        selected = listed
        duplicates = sorted(name for name, count in counts.items() if count > 1)
    else:
        selected = [found[n] for n in actions or [] if n in found]
        duplicates = []
    missing = requested - found.keys()
    if missing:
        raise KdfError('actions not found: ' + ', '.join(sorted(missing)))
    report = {'sha256': container['sha256'], 'data_offset': container['data_offset'],
              'record_count': container['record_count'], 'tail_identity_hex': container['tail_identity_hex'],
              'actions': selected,
              'note': 'Raw configuration values; runtime speed and effects are unverified.'}
    if list_actions:
        report['action_count'] = len(listed)
        report['duplicate_names'] = duplicates
        if summary:
            report['actions'] = [item['name'] for item in listed]
            report['attack_action_count'] = sum(item['impact_count'] > 0 for item in listed)
            report['impact_record_count'] = sum(item['impact_count'] for item in listed)
            report['impact_count_distribution'] = {
                count: sum(item['impact_count'] == count for item in listed)
                for count in sorted({item['impact_count'] for item in listed})
            }
            report['summary'] = True
    return report


def inspect_archive(path: Path, actions: list[str] | None = None, *, list_actions: bool = False,
                    summary: bool = False) -> dict:
    """Read the identified set from an outer ZIP or data.zpak without exporting it."""
    with _open_zpak_info(path) as (archive, source_hash, zpak_hash):
        members = {item.filename: item for item in archive.infolist() if not item.is_dir()}
        if 'Core.pakh' not in members or 'Core.pakd000' not in members:
            raise PakError('archive does not contain Core.pakh and Core.pakd000')
        if (members['Core.pakh'].file_size > _MAX_INDEX_BYTES
                or members['Core.pakd000'].file_size > _MAX_DATA_BYTES):
            raise PakError('PAK member exceeds size limit')
        index_bytes = archive.read('Core.pakh')
        records = parse_index(index_bytes)
        directory = parse_directory(index_bytes, records)
        entries = [item for item in directory['files'] if item['path'].casefold() == _SET_PATH]
        if len(entries) != 1:
            raise PakError('expected exactly one brucelee.set path')
        matches = [r for r in records if r.resource_id_hex == entries[0]['resource_id_hex']]
        if len(matches) != 1:
            raise PakError('set resource identity is ambiguous or missing')
        selected = matches[0]
        if (sum(r.pakd_offset == selected.pakd_offset for r in records) != 1
                or selected.pakd_offset + selected.stored_bytes > members['Core.pakd000'].file_size):
            raise PakError('set PAKD offset is ambiguous or outside the data member')
        with archive.open('Core.pakd000') as stream:
            stream.seek(selected.pakd_offset)
            row, payload = next(iter_resources(stream, 1, collect_data=True))
        if (row['pakd_offset'], row['decoded_bytes'], row['stored_bytes']) != (
                selected.pakd_offset, selected.decoded_bytes, selected.stored_bytes):
            raise PakError('set stream does not match index offset and lengths')
        report = inspect_bytes(payload, actions, list_actions=list_actions, summary=summary)
        if report['tail_identity_hex'] != selected.resource_id_hex:
            raise PakError('set CTX3 tail identity differs from the PAKH resource ID')
        report['archive'] = {'source_sha256': source_hash, 'data_zpak_sha256': zpak_hash,
                             'resource_path': entries[0]['path'],
                             'resource_id': selected.resource_id_hex,
                             'index_ordinal': selected.index_ordinal,
                             'pakd_offset': selected.pakd_offset}
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', nargs='?', type=Path, help='local decoded CTX3 file (read only)')
    parser.add_argument('--archive', type=Path, help='outer ZIP or data.zpak, read only')
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument('--action', action='append', help='exact action name; repeatable')
    selection.add_argument('--list-actions', action='store_true', help='list action names and available animation references')
    parser.add_argument('--summary', action='store_true', help='with --list-actions, emit names and counts only')
    args = parser.parse_args()
    if (args.source is None) == (args.archive is None):
        parser.error('provide exactly one decoded source path or --archive')
    try:
        if args.archive is not None:
            result = inspect_archive(args.archive, args.action, list_actions=args.list_actions,
                                     summary=args.summary)
        else:
            with args.source.open('rb') as stream:
                raw = stream.read(16 * 1024 * 1024 + 1)
            result = inspect_bytes(raw, args.action, list_actions=args.list_actions,
                                   summary=args.summary)
    except (OSError, KdfError, ValueError, zipfile.BadZipFile) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

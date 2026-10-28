#!/usr/bin/env python3
"""Inspect the observed KDF string table without exporting game resources.

The supported layout is based on a small set of local 1FDKENONCTX3 samples.
The observed CRC32-plus-length relation is reported, not assumed to be a
universal format rule. This tool does not parse meshes or animations.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
import zlib

_SIGNATURE = b'1FDKENONCTX3'
_MAX_FILE_BYTES = 16 * 1024 * 1024
_MAX_STRING_BYTES = 1024 * 1024
_MAX_STRINGS = 20000
_MAX_FILES = 20000
_PAIR = struct.Struct('<II')


class KdfError(ValueError):
    """Input is not an observed, bounded KDF string-table layout."""


class UnsupportedKdf(KdfError):
    """Input does not have the currently supported KDF signature."""


def inspect_bytes(data: bytes, *, include_strings: bool = False) -> dict:
    """Inspect the table at offset 0x1c; all offsets refer to decoded bytes."""
    if len(data) > _MAX_FILE_BYTES:
        raise KdfError('decoded resource exceeds the inspection size limit')
    if not data.startswith(_SIGNATURE):
        raise UnsupportedKdf('unsupported KDF signature')
    if len(data) < 28:
        raise KdfError('truncated KDF header')
    count = struct.unpack_from('<I', data, 0x18)[0]
    if count > _MAX_STRINGS:
        raise KdfError('string count exceeds inspection limit')
    position = 0x1c
    entries = []
    matches = 0
    for ordinal in range(count):
        record_offset = position
        if position + _PAIR.size > len(data):
            raise KdfError(f'truncated string record {ordinal}')
        stored_id, byte_length = _PAIR.unpack_from(data, position)
        position += _PAIR.size
        if byte_length > _MAX_STRING_BYTES:
            raise KdfError(f'string {ordinal} exceeds inspection limit')
        end = position + byte_length
        if end >= len(data) or data[end] != 0:
            raise KdfError(f'truncated or unterminated string {ordinal}')
        value = data[position:end]
        calculated = (zlib.crc32(value) + byte_length) & 0xffffffff
        matched = stored_id == calculated
        matches += int(matched)
        if include_strings:
            try:
                text = value.decode('utf-8')
            except UnicodeDecodeError:
                text = None
            entries.append({
                'ordinal': ordinal,
                'record_offset': record_offset,
                'string_offset': position,
                'byte_length': byte_length,
                'stored_id': f'{stored_id:08x}',
                'crc32_plus_length': f'{calculated:08x}',
                'matches_observed_rule': matched,
                'text': text,
            })
        position = end + 1
    result = {
        'decoded_bytes': len(data),
        'sha256': hashlib.sha256(data).hexdigest(),
        'signature': _SIGNATURE.decode('ascii'),
        'string_count': count,
        'table_end': position,
        'crc32_plus_length_matches': matches,
        'crc32_plus_length_mismatches': count - matches,
    }
    if include_strings:
        result['strings'] = entries
    return result


def inspect_file(path: Path, *, include_strings: bool = False) -> dict:
    """Read a single resource, retaining no decoded binary files."""
    with path.open('rb') as source:
        data = source.read(_MAX_FILE_BYTES + 1)
    if len(data) > _MAX_FILE_BYTES:
        raise KdfError('decoded resource exceeds the inspection size limit')
    return inspect_bytes(data, include_strings=include_strings)


def _input_files(paths: list[Path]) -> list[Path]:
    files = []
    for path in paths:
        if path.is_dir():
            found = []
            for item in path.glob('*.bin'):
                if item.is_file():
                    found.append(item)
                    if len(files) + len(found) > _MAX_FILES:
                        raise KdfError('file count exceeds inspection limit')
            files.extend(sorted(found))
        else:
            files.append(path)
        if len(files) > _MAX_FILES:
            raise KdfError('file count exceeds inspection limit')
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('inputs', type=Path, nargs='+', help='decoded files or directories containing .bin files')
    parser.add_argument('--strings', action='store_true', help='include observed string text and offsets in JSON output')
    args = parser.parse_args()
    files = _input_files(args.inputs)
    results = []
    invalid = 0
    unsupported = 0
    for path in files:
        try:
            result = inspect_file(path, include_strings=args.strings)
            results.append({'path': str(path), 'status': 'ok', **result})
        except UnsupportedKdf as exc:
            unsupported += 1
            results.append({'path': str(path), 'status': 'unsupported', 'error': str(exc)})
        except (OSError, KdfError) as exc:
            invalid += 1
            results.append({'path': str(path), 'status': 'invalid', 'error': str(exc)})
    json.dump({'files': results, 'input_count': len(files), 'unsupported': unsupported, 'invalid': invalid},
              sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 1 if invalid or not files else 0


if __name__ == '__main__':
    raise SystemExit(main())

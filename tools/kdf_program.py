#!/usr/bin/env python3
"""Inspect the observed KDF program profile without exporting shader source."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_data import KdfError
from kdf_strings import KdfError as StringKdfError
from kdf_strings import inspect_bytes

_SIGNATURE = b'1FDKENONCTX3'
_DATA_SIGNATURE = b'DATA'
_MAX_RESOURCE_BYTES = 16 * 1024 * 1024
_MAX_RECORDS = 100_000
_MAX_OFFSETS = 100_000
_OBSERVED_PROFILE_WORD = 15
_TEXTURE_CONSTANT_TAG = 0x40000004
_SAMPLER_RE = re.compile(
    rb'uniform\s+sampler2D\s+g_s([A-Za-z][A-Za-z0-9_]*)')


def inspect_program_bytes(raw: bytes) -> dict:
    """Parse the bounded program metadata profile used by ``Diffuse.program``.

    The trailing payload can contain shader source. This function records only
    counts, offsets, hashes, and texture-constant names; it never returns the
    source text or raw payload.
    """
    if len(raw) > _MAX_RESOURCE_BYTES:
        raise KdfError('decoded resource exceeds inspection size limit')
    if not raw.startswith(_SIGNATURE):
        raise KdfError('unsupported program signature')

    try:
        string_result = inspect_bytes(raw, include_strings=True)
    except StringKdfError as exc:
        raise KdfError(str(exc)) from exc
    if string_result['crc32_plus_length_mismatches']:
        raise KdfError('program string identifier does not match the observed rule')
    retained_count, file_count, function_count, total_count = struct.unpack_from(
        '<IIII', raw, 0x0C)
    if (file_count, function_count) != (0, 0):
        raise KdfError('program context reference tables are not supported')
    if retained_count > total_count:
        raise KdfError('program retained string count exceeds total')

    table_end = string_result['table_end']
    padding_length = (table_end - 0x1C) & 3
    data_offset = table_end + padding_length
    if data_offset + 20 > len(raw):
        raise KdfError('truncated program DATA header')
    if any(raw[table_end:data_offset]):
        raise KdfError('program string padding is not zero')
    if raw[data_offset:data_offset + 4] != _DATA_SIGNATURE:
        raise KdfError('program DATA marker is missing')

    record_count, offset_count, profile_word, payload_size = struct.unpack_from(
        '<IIII', raw, data_offset + 4)
    if not 0 < record_count <= _MAX_RECORDS:
        raise KdfError('program record count out of bounds')
    if offset_count > _MAX_OFFSETS:
        raise KdfError('program offset count out of bounds')
    if profile_word != _OBSERVED_PROFILE_WORD:
        raise KdfError(
            f'unsupported program profile word {profile_word}; '
            f'expected {_OBSERVED_PROFILE_WORD}'
        )

    offset_values = offset_count + 1
    offsets = list(struct.unpack_from(
        f'<{offset_values}I', raw, data_offset + 20))
    record_start = data_offset + 20 + offset_values * 4
    record_end = record_start + record_count * 8
    payload_offset = record_end
    payload_end = payload_offset + payload_size
    if payload_end > len(raw):
        raise KdfError('program payload exceeds resource length')

    strings = string_result['strings']
    records = []
    for ordinal in range(record_count):
        first, second = struct.unpack_from(
            '<II', raw, record_start + ordinal * 8)
        records.append({
            'ordinal': ordinal,
            'first': first,
            'second': second,
        })

    sampler_names = []
    for match in _SAMPLER_RE.finditer(raw):
        suffix = match.group(1).decode('ascii')
        sampler_names.append({
            'uniform': f'g_s{suffix}',
            'property_hint': suffix.casefold(),
        })
    if not sampler_names:
        raise KdfError('program source declares no sampler2D uniforms')

    texture_constants = []
    seen_texture_names = set()
    for sampler in sampler_names:
        hint = sampler['property_hint']
        matching_strings = [
            entry for entry in strings
            if entry['text'] is not None
            and entry['text'].casefold() == hint
        ]
        if len(matching_strings) != 1:
            raise KdfError(
                f'program sampler {sampler["uniform"]} has no unique property string'
            )
        string_entry = matching_strings[0]
        matching_records = [
            record for record in records
            if record['first'] == string_entry['ordinal']
            and record['second'] == _TEXTURE_CONSTANT_TAG
        ]
        if len(matching_records) != 1:
            raise KdfError(
                f'program sampler {sampler["uniform"]} has no unique constant record'
            )
        name = string_entry['text']
        if name in seen_texture_names:
            raise KdfError(f'program repeats texture constant {name!r}')
        seen_texture_names.add(name)
        texture_constants.append({
            'record_ordinal': matching_records[0]['ordinal'],
            'string_ordinal': string_entry['ordinal'],
            'name': name,
            'uniform': sampler['uniform'],
        })

    return {
        'sha256': hashlib.sha256(raw).hexdigest(),
        'decoded_bytes': len(raw),
        'string_count': total_count,
        'string_table_end': table_end,
        'data_offset': data_offset,
        'record_count': record_count,
        'offset_count': offset_count,
        'profile_word': profile_word,
        'payload_size': payload_size,
        'payload_offset': payload_offset,
        'offsets': offsets,
        'texture_constant_count': len(texture_constants),
        'texture_constants': texture_constants,
        'sampler2d_uniform_count': len(sampler_names),
        'records': records,
        'shader_source_status': 'present-but-not-returned',
    }


def inspect_file(path: Path) -> dict:
    with path.open('rb') as source:
        raw = source.read(_MAX_RESOURCE_BYTES + 1)
    if len(raw) > _MAX_RESOURCE_BYTES:
        raise KdfError('decoded program exceeds inspection size limit')
    result = inspect_program_bytes(raw)
    result['source'] = str(path)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='decoded program resource')
    args = parser.parse_args()
    try:
        result = inspect_file(args.source)
    except (OSError, KdfError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

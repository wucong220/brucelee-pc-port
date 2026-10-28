#!/usr/bin/env python3
"""Inspect the observed CTX3 string table and DATA header without exporting data."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
from typing import BinaryIO
import zlib

_SIGNATURE = b'1FDKENONCTX3'
_DATA_SIGNATURE = b'DATA'
_MAX_RESOURCE_BYTES = 16 * 1024 * 1024
_MAX_STRINGS = 20_000
_MAX_STRING_BYTES = 1024 * 1024
_MAX_NODES = 100_000
_MAX_METADATA_GAP = 1024 * 1024


class KdfError(ValueError):
    """Resource does not match the bounded CTX3 metadata profile."""


def read_strings(raw: bytes) -> tuple[list[dict], int]:
    if len(raw) < 0x1c or not raw.startswith(_SIGNATURE):
        raise KdfError('unsupported CTX3 signature')
    count = struct.unpack_from('<I', raw, 0x18)[0]
    if count > _MAX_STRINGS:
        raise KdfError('CTX3 string count exceeds limit')
    position = 0x1c
    strings = []
    for ordinal in range(count):
        if position + 8 > len(raw):
            raise KdfError(f'truncated CTX3 string record {ordinal}')
        identifier, length = struct.unpack_from('<II', raw, position)
        record_offset = position
        position += 8
        if length > _MAX_STRING_BYTES or position + length >= len(raw):
            raise KdfError(f'invalid CTX3 string length at record {ordinal}')
        value = raw[position:position + length]
        position += length
        if raw[position] != 0:
            raise KdfError(f'missing CTX3 string terminator at record {ordinal}')
        position += 1
        expected = (zlib.crc32(value) + length) & 0xffffffff
        if identifier != expected:
            raise KdfError(f'CTX3 string identifier mismatch at record {ordinal}')
        try:
            text = value.decode('utf-8')
        except UnicodeDecodeError as exc:
            raise KdfError(f'CTX3 string {ordinal} is not UTF-8') from exc
        strings.append({
            'ordinal': ordinal,
            'record_offset': record_offset,
            'identifier': f'{identifier:08x}',
            'text': text,
        })
    return strings, position


def parse_container(raw: bytes) -> dict:
    if len(raw) > _MAX_RESOURCE_BYTES:
        raise KdfError('decoded resource exceeds inspection size limit')
    if len(raw) < 0x1c + 16 or not raw.startswith(_SIGNATURE):
        raise KdfError('unsupported CTX3 signature')
    header_words = list(struct.unpack_from('<IIII', raw, 0x0c))
    strings, table_end = read_strings(raw)
    data_offset = raw.find(_DATA_SIGNATURE, table_end, len(raw) - 20)
    if data_offset < 0:
        raise KdfError('CTX3 DATA marker was not found')
    if data_offset - table_end > _MAX_METADATA_GAP:
        raise KdfError('CTX3 metadata gap exceeds limit')
    record_count, offset_count, reserved, payload_size = struct.unpack_from(
        '<IIII', raw, data_offset + 4)
    if not 0 < record_count <= _MAX_NODES:
        raise KdfError('CTX3 DATA record count out of bounds')
    if not 0 < offset_count <= _MAX_NODES:
        raise KdfError('CTX3 DATA offset count out of bounds')
    if reserved != 0:
        raise KdfError('CTX3 DATA reserved word is not zero')
    offset_values = offset_count + 1
    header_size = 20 + offset_values * 4 + record_count * 8
    payload_offset = data_offset + header_size
    payload_end = payload_offset + payload_size
    if payload_size <= 0 or payload_end + 16 != len(raw):
        raise KdfError('CTX3 DATA payload bounds do not match resource length')
    offsets = list(struct.unpack_from(f'<{offset_values}I', raw, data_offset + 20))
    if offsets[:2] != [0, 0] or any(a > b for a, b in zip(offsets, offsets[1:])):
        raise KdfError('CTX3 DATA section offsets are invalid')
    if offsets[-1] > payload_size:
        raise KdfError('CTX3 DATA section offset exceeds payload')
    record_start = data_offset + 20 + offset_values * 4
    records = []
    for record_ordinal in range(record_count):
        first, second = struct.unpack_from('<II', raw, record_start + record_ordinal * 8)
        records.append({'ordinal': record_ordinal, 'first': first, 'second': second})
    sections = []
    for index in range(offset_count):
        start_relative = offsets[index + 1]
        end_relative = offsets[index + 2] if index + 2 < len(offsets) else payload_size
        if start_relative > end_relative:
            raise KdfError('CTX3 DATA section range is inverted')
        sections.append({
            'ordinal': index,
            'start_relative': start_relative,
            'end_relative': end_relative,
            'bytes': end_relative - start_relative,
        })
    array_references = []
    for record_ordinal, record in enumerate(records):
        descriptor = record['first']
        if descriptor >> 28 != 4:
            continue
        element_count = descriptor & 0xffff
        element_stride = (descriptor & 0x0fff0000) >> 21
        section_index = record['second']
        if not element_count or not element_stride:
            continue
        if section_index >= len(sections):
            continue
        required = element_count * element_stride
        actual = sections[section_index]['bytes']
        if actual < required or actual - required > 3:
            raise KdfError(
                f'CTX3 array descriptor {record_ordinal} expects {required} bytes '
                f'from section {section_index}, found {actual}'
            )
        array_references.append({
            'record_ordinal': record_ordinal,
            'descriptor': descriptor,
            'element_count': element_count,
            'element_stride': element_stride,
            'section_index': section_index,
            'required_bytes': required,
            'section_bytes': actual,
        })
    return {
        'sha256': hashlib.sha256(raw).hexdigest(),
        'decoded_bytes': len(raw),
        'header_words': header_words,
        'string_count': len(strings),
        'strings': strings,
        'string_table_end': table_end,
        'metadata_gap': data_offset - table_end,
        'data_offset': data_offset,
        'record_count': record_count,
        'offset_count': offset_count,
        'offsets': offsets,
        'records': records,
        'sections': sections,
        'array_references': array_references,
        'header_bytes': header_size,
        'payload_offset': payload_offset,
        'payload_bytes': payload_size,
        'tail_identity_hex': raw[payload_end:].hex(),
    }


def property_occurrences(
        container: dict, key: str, *,
        value_markers: set[int] | None = None) -> list[dict]:
    """Return key/value records, optionally restricted by value type markers."""
    matches = [entry['ordinal'] for entry in container['strings'] if entry['text'] == key]
    if len(matches) != 1:
        raise KdfError(f'expected one string-table key named {key!r}')
    ordinal = matches[0]
    records = container['records']
    occurrences = []
    for index in range(len(records) - 1):
        if records[index]['first'] == 0x60000000 and records[index]['second'] == ordinal:
            value_record = records[index + 1]
            if value_markers is not None and value_record['first'] not in value_markers:
                continue
            occurrences.append({
                'key_record': index,
                'value_record': index + 1,
                'value_marker': value_record['first'],
                'value': value_record['second'],
            })
    return occurrences


def scalar_occurrences(container: dict, key: str) -> list[dict]:
    """Return locations and values for observed `(0, value)` scalar pairs."""
    return property_occurrences(container, key, value_markers={0})


def scalar_property(container: dict, key: str) -> int:
    """Read one observed `0x60000000/key, 0/value` scalar property."""
    values = [entry['value'] for entry in scalar_occurrences(container, key)]
    if len(values) != 1:
        raise KdfError(f'expected one scalar value for {key!r}')
    return values[0]


def inspect_file(path: Path, *, include_records: bool = False,
                 include_strings: bool = False) -> dict:
    with path.open('rb') as file:
        raw = file.read(_MAX_RESOURCE_BYTES + 1)
    if len(raw) > _MAX_RESOURCE_BYTES:
        raise KdfError('decoded resource exceeds inspection size limit')
    result = parse_container(raw)
    result['source'] = str(path)
    if not include_records:
        del result['records']
    if not include_strings:
        del result['strings']
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='decoded 1FDKENONCTX3 resource')
    parser.add_argument('--records', action='store_true', help='include all 8-byte DATA records')
    parser.add_argument('--strings', action='store_true', help='include all string-table entries')
    args = parser.parse_args()
    try:
        result = inspect_file(args.source, include_records=args.records,
                              include_strings=args.strings)
    except (OSError, KdfError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

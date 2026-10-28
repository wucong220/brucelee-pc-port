#!/usr/bin/env python3
"""Read-only metadata verification of Bruce Lee: Dragon Warrior's PAK container.

Recover data-stream boundaries and match assets to sorted index entries by
observed (uncompressed_size, stored_size). Exact original filenames and ambiguous
index identities are *not* recovered by this utility.

All original archives are opened read-only. Exporting decoded bytes is opt-in.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from contextlib import contextmanager
from dataclasses import dataclass
import hashlib
import io
import json
from pathlib import Path
import struct
from typing import Iterator
import zipfile
import zlib

_RECORD = struct.Struct('<I16sIIII')
_MAX_INDEX_ENTRIES = 20_000
_MAX_INDEX_BYTES = 8 * 1024 * 1024
_MAX_DATA_BYTES = 1_000_000_000
_MAX_RESOURCE_BYTES = 16 * 1024 * 1024
_MAX_CHUNK_BYTES = 2 * 1024 * 1024
_MAX_CHUNKS = 512


class PakError(ValueError):
    """Archive does not conform to the verified layout."""


@dataclass(frozen=True)
class IndexRecord:
    index_ordinal: int
    key: int
    unknown_16_hex: str
    reserved: int
    decoded_bytes: int
    stored_bytes: int
    flags: int


def parse_index(raw: bytes) -> list[IndexRecord]:
    if len(raw) < 28 or len(raw) > _MAX_INDEX_BYTES:
        raise PakError('unexpected Core.pakh size')
    if raw[:4] != b'8KAP' or raw[16:20] != b'DTRS':
        raise PakError('unknown PAK header or index signature')
    count = struct.unpack_from('<I', raw, 20)[0]
    if not 0 < count <= _MAX_INDEX_ENTRIES:
        raise PakError('index entry count out of bounds')
    table_end = 24 + count * _RECORD.size
    if table_end + 4 > len(raw):
        raise PakError('truncated index table')
    if struct.unpack_from('<I', raw, table_end)[0] != 1:
        raise PakError('unrecognized index footer/next-section marker')
    records: list[IndexRecord] = []
    last_key = -1
    for ordinal in range(count):
        key, unknown_16, reserved, decoded_bytes, stored_bytes, flags = _RECORD.unpack_from(raw, 24 + ordinal * 36)
        if key <= last_key or reserved != 0 or not (0 < decoded_bytes <= _MAX_RESOURCE_BYTES) or not (0 < stored_bytes <= _MAX_RESOURCE_BYTES):
            raise PakError(f'index row {ordinal} fails observed index constraints')
        last_key = key
        records.append(IndexRecord(ordinal, key, unknown_16.hex(), reserved, decoded_bytes, stored_bytes, flags))
    return records


@contextmanager
def open_zpak(path: Path) -> Iterator[zipfile.ZipFile]:
    """Accept either data.zpak or the user's outer ZIP containing it."""
    with zipfile.ZipFile(path) as outer:
        members = {i.filename: i for i in outer.infolist() if not i.is_dir()}
        if {'Core.pakh', 'Core.pakd000'} <= members.keys():
            yield outer
            return
        candidates = [i for name, i in members.items() if name.endswith('/data.zpak') or name == 'data.zpak']
        if len(candidates) != 1 or candidates[0].file_size > _MAX_DATA_BYTES:
            raise PakError('expected a single bounded data.zpak in the supplied ZIP')
        # ZipFile requires random access to the nested archive; memory is bounded.
        with outer.open(candidates[0]) as source:
            content = source.read(_MAX_DATA_BYTES + 1)
        if len(content) > _MAX_DATA_BYTES:
            raise PakError('nested ZPAK exceeds read limit')
        with zipfile.ZipFile(io.BytesIO(content)) as nested:
            yield nested


def _read_exact(stream, size: int) -> bytes:
    raw = stream.read(size)
    if len(raw) != size:
        raise PakError('truncated PAK data stream')
    return raw


def iter_resources(stream, resource_count: int, *, collect_data: bool = False):
    """Yield each zlib resource; continuation blocks have a 4-byte length only."""
    for ordinal in range(resource_count):
        begin = stream.tell()
        first_header = _read_exact(stream, 8)
        block_cap, compressed_len = struct.unpack('<II', first_header)
        # Observed container format uses 256 KiB output per intermediate block.
        if block_cap != 262144:
            raise PakError(f'resource {ordinal} has unsupported block cap {block_cap}')
        decompressor = zlib.decompressobj()
        digest = hashlib.sha256()
        decoded_size = 0
        chunks = 0
        collected = [] if collect_data else None
        while True:
            if not (0 < compressed_len <= _MAX_CHUNK_BYTES) or chunks >= _MAX_CHUNKS:
                raise PakError(f'resource {ordinal}: invalid compressed chunk size/count')
            payload = _read_exact(stream, compressed_len)
            try:
                data = decompressor.decompress(payload, _MAX_RESOURCE_BYTES - decoded_size + 1)
            except zlib.error as exc:
                raise PakError(f'resource {ordinal}: zlib decoding failed') from exc
            if decompressor.unconsumed_tail or decompressor.unused_data:
                raise PakError(f'resource {ordinal}: extra or unconsumed compressed data')
            decoded_size += len(data)
            if decoded_size > _MAX_RESOURCE_BYTES:
                raise PakError(f'resource {ordinal}: decompression exceeded limit')
            digest.update(data)
            if collected is not None:
                collected.append(data)
            chunks += 1
            if decompressor.eof:
                break
            compressed_len = struct.unpack('<I', _read_exact(stream, 4))[0]
        yield {
            'disk_ordinal': ordinal,
            'pakd_offset': begin,
            'decoded_bytes': decoded_size,
            'stored_bytes': stream.tell() - begin,
            'zlib_chunks': chunks,
            'sha256': digest.hexdigest(),
        }, (b''.join(collected) if collected is not None else None)


def scan_archive(path: Path, extract_dir: Path | None = None) -> dict:
    with open_zpak(path) as archive:
        members = {i.filename: i for i in archive.infolist()}
        if 'Core.pakh' not in members or 'Core.pakd000' not in members:
            raise PakError('archive does not contain Core.pakh and Core.pakd000')
        if members['Core.pakh'].file_size > _MAX_INDEX_BYTES or members['Core.pakd000'].file_size > _MAX_DATA_BYTES:
            raise PakError('PAK member exceeds size limit')
        records = parse_index(archive.read('Core.pakh'))
        expected_pairs = Counter((r.decoded_bytes, r.stored_bytes) for r in records)
        if sum(r.stored_bytes for r in records) != members['Core.pakd000'].file_size:
            raise PakError('index stored-size sum differs from actual PAKD length')
        index_by_pair = defaultdict(list)
        for r in records:
            index_by_pair[(r.decoded_bytes, r.stored_bytes)].append(r)
        observed_pairs = Counter()
        results = []
        with archive.open('Core.pakd000') as stream:
            for row, payload in iter_resources(stream, len(records), collect_data=extract_dir is not None):
                pair = (row['decoded_bytes'], row['stored_bytes'])
                observed_pairs[pair] += 1
                if observed_pairs[pair] > expected_pairs[pair]:
                    raise PakError(f'data record {row["disk_ordinal"]} not present in index length multiset')
                candidates = index_by_pair[pair]
                row['index_candidates'] = [item.index_ordinal for item in candidates]
                row['key'] = (f'{candidates[0].key:08x}' if len(candidates) == 1 else None)
                if extract_dir is not None:
                    extract_dir.mkdir(parents=True, exist_ok=True)
                    suffix = f'key_{candidates[0].key:08x}' if len(candidates) == 1 else 'ambiguous'
                    destination = extract_dir / f'disk_{row["disk_ordinal"]:04d}_{suffix}.bin'
                    # No overwrite of earlier work or original assets.
                    with destination.open('xb') as output:
                        output.write(payload)
                results.append(row)
            if stream.tell() != members['Core.pakd000'].file_size:
                raise PakError('trailing unaccounted compressed bytes')
        if observed_pairs != expected_pairs:
            raise PakError('full decoded-size/stored-size multiset does not match PAKH index')
        unique_count = sum(r['key'] is not None for r in results)
        return {
            'source': str(path),
            'index_count': len(records),
            'pakd_bytes': members['Core.pakd000'].file_size,
            'total_decoded_bytes': sum(r['decoded_bytes'] for r in results),
            'uniquely_matched': unique_count,
            'ambiguous': len(results) - unique_count,
            'multiset_verified': True,
            'resources': results,
        }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path, help='data.zpak or its containing outer ZIP')
    parser.add_argument('--report', type=Path, help='JSON report path; file must not exist')
    parser.add_argument('--extract', type=Path, help='opt-in local-only decoded .bin output directory')
    args = parser.parse_args()
    report = scan_archive(args.archive, args.extract)
    print(f"Verified {report['index_count']} resources, {report['pakd_bytes']} stored bytes, "
          f"{report['total_decoded_bytes']} decoded bytes, {report['uniquely_matched']} uniquely matched, "
          f"{report['ambiguous']} ambiguous.")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        with args.report.open('x', encoding='utf-8') as file:
            json.dump(report, file, ensure_ascii=False, indent=2)
        print(f'Report written to {args.report}')


if __name__ == '__main__':
    main()

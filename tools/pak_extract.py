#!/usr/bin/env python3
"""Read-only metadata verification of Bruce Lee: Dragon Warrior's PAK container.

Recover data-stream boundaries and match assets to sorted index entries by
the observed PAKD offset plus uncompressed and stored lengths. Parse the
PAKH directory nodes, reconstruct their tree, and validate the footer CRC.

All original archives are opened read-only. Exporting decoded bytes is opt-in.
"""
from __future__ import annotations

import argparse
from collections import Counter
from contextlib import contextmanager
from dataclasses import dataclass
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
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
_MAX_DIRECTORY_STRING_BYTES = 1024
_MAX_DIRECTORY_ROOTS = 32
_MAX_DIRECTORY_NODES = 20_000
_MAX_DIRECTORY_FILES = 100_000
_DEFAULT_MAX_TOTAL_DECODED_BYTES = 1024 * 1024 * 1024
_PROJECT_ROOT = Path(__file__).resolve().parents[1]


class PakError(ValueError):
    """Archive does not conform to the verified layout."""


@dataclass(frozen=True)
class IndexRecord:
    index_ordinal: int
    key: int
    unknown_16_hex: str
    resource_id_hex: str
    pakd_offset: int
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
        # Stored size includes zlib and block headers; incompressible data can
        # legitimately be larger than the allowed decoded size.
        if key <= last_key or reserved != 0 or not (0 < decoded_bytes <= _MAX_RESOURCE_BYTES) or not (0 < stored_bytes <= _MAX_DATA_BYTES):
            raise PakError(f'index row {ordinal} fails observed index constraints')
        last_key = key
        # Another read-only scan of the original package found that the last
        # four bytes of the formerly unknown 16-byte region equal the PAKD
        # stream offset. Validate that observation against every decoded stream.
        resource_id = struct.pack('<I', key) + unknown_16[:12]
        pakd_offset = struct.unpack_from('<I', unknown_16, 12)[0]
        records.append(IndexRecord(ordinal, key, unknown_16.hex(), resource_id.hex(),
                                   pakd_offset, reserved, decoded_bytes, stored_bytes, flags))
    return records


def _read_directory_string(raw: bytes, position: int) -> tuple[str, int]:
    if position < 0 or position + 4 > len(raw):
        raise PakError('truncated directory string length')
    length = struct.unpack_from('<I', raw, position)[0]
    if length > _MAX_DIRECTORY_STRING_BYTES:
        raise PakError('directory string exceeds size limit')
    start = position + 4
    end = start + length
    # Observed PAKH strings include at least one NUL, then NUL padding.
    padding = 4 - (length % 4)
    if end + padding > len(raw) or raw[end:end + padding] != b'\0' * padding:
        raise PakError('truncated or invalid directory string padding')
    data = raw[start:end]
    if b'\0' in data:
        raise PakError('directory string contains an embedded NUL')
    try:
        return data.decode('utf-8'), end + padding
    except UnicodeDecodeError as exc:
        raise PakError('directory string is not UTF-8') from exc


def parse_directory(raw: bytes, records: list[IndexRecord]) -> dict:
    """Parse the observed flat PAKH directory-node table and validate its tree."""
    table_end = 24 + len(records) * _RECORD.size
    by_identity = {record.resource_id_hex: record for record in records}
    if len(by_identity) != len(records):
        raise PakError('duplicate 16-byte resource identity in index')

    def u32(position: int) -> int:
        if position < 0 or position + 4 > len(raw):
            raise PakError('truncated PAKH directory field')
        return struct.unpack_from('<I', raw, position)[0]

    def take(position: int, size: int) -> tuple[bytes, int]:
        if size < 0 or position < 0 or position + size > len(raw):
            raise PakError('truncated PAKH directory data')
        return raw[position:position + size], position + size

    position = table_end
    root_count = u32(position)
    position += 4
    if not 0 < root_count <= _MAX_DIRECTORY_ROOTS:
        raise PakError('PAKH root namespace count out of bounds')

    roots = []
    nodes = {}
    files = []
    for _ in range(root_count):
        root_name, position = _read_directory_string(raw, position)
        if not root_name or '/' in root_name or '\\' in root_name:
            raise PakError('invalid PAKH root namespace')
        node_count = u32(position)
        position += 4
        if not 0 < node_count <= _MAX_DIRECTORY_NODES or len(nodes) + node_count > _MAX_DIRECTORY_NODES:
            raise PakError('PAKH directory node count out of bounds')
        roots.append({'name': root_name, 'node_count': node_count})

        for _ in range(node_count):
            node_offset = position
            path, position = _read_directory_string(raw, position)
            parent, position = _read_directory_string(raw, position)
            if (path and not path.endswith('/')) or (parent and not parent.endswith('/')):
                raise PakError('PAKH directory paths must end with a slash')
            normalized_path = path.casefold()
            if normalized_path in nodes:
                raise PakError(f'duplicate PAKH directory path: {path!r}')
            file_count = u32(position)
            position += 4
            if file_count > _MAX_DIRECTORY_FILES or len(files) + file_count > _MAX_DIRECTORY_FILES:
                raise PakError('PAKH file-reference count out of bounds')
            node_files = []
            for _ in range(file_count):
                record_offset = position
                record_header, position = take(position, 8)
                type_word, tag = struct.unpack('<II', record_header)
                if type_word & 0xFFFFFF:
                    raise PakError('unrecognized PAKH file type bits')
                folder, position = _read_directory_string(raw, position)
                name, position = _read_directory_string(raw, position)
                extension, position = _read_directory_string(raw, position)
                identity_offset = position
                identity_raw, position = take(position, 16)
                identity = identity_raw.hex()
                if folder != path or not name or any(char in name + extension for char in '/\\'):
                    raise PakError(f'invalid PAKH file reference at {record_offset}')
                record = by_identity.get(identity)
                if record is None:
                    raise PakError(f'unmatched PAKH file identity at {identity_offset}')
                full_path = folder + name + ('.' + extension if extension else '')
                file_info = {
                    'path': full_path,
                    'index_ordinal': record.index_ordinal,
                    'resource_id_hex': identity,
                    'pakh_offset': record_offset,
                    'identity_offset': identity_offset,
                    'type_word': type_word,
                    'tag': tag,
                }
                node_files.append(file_info)
                files.append(file_info)

            child_count = u32(position)
            position += 4
            if child_count > _MAX_DIRECTORY_NODES:
                raise PakError('PAKH child-directory count out of bounds')
            children = []
            for _ in range(child_count):
                child, position = _read_directory_string(raw, position)
                if not child or '/' in child or '\\' in child:
                    raise PakError('invalid PAKH child-directory name')
                children.append(child)
            if len({child.casefold() for child in children}) != len(children):
                raise PakError('duplicate PAKH child-directory name')
            nodes[normalized_path] = {
                'path': path,
                'parent': parent,
                'children': children,
                'files': node_files,
                'offset': node_offset,
            }

    if position + 4 != len(raw):
        raise PakError('unparsed or missing PAKH directory footer')
    expected_crc = u32(position)
    actual_crc = zlib.crc32(raw[:position]) & 0xffffffff
    if expected_crc != actual_crc:
        raise PakError('PAKH directory footer CRC32 mismatch')

    def walk(path: str, seen: set[str], active: set[str]) -> None:
        key = path.casefold()
        if key not in nodes or key in active or key in seen:
            raise PakError('missing, cyclic, or duplicate PAKH directory node')
        seen.add(key)
        active.add(key)
        node = nodes[key]
        for child in node['children']:
            child_path = path + child + '/'
            child_key = child_path.casefold()
            child_node = nodes.get(child_key)
            if child_node is None or child_node['parent'].casefold() != key:
                raise PakError('PAKH child directory does not match its parent')
            walk(child_node['path'], seen, active)
        active.remove(key)

    seen: set[str] = set()
    virtual_root = nodes.get('')
    if virtual_root is None:
        raise PakError('missing PAKH virtual root node')
    walk('', seen, set())
    if len(seen) != len(nodes):
        raise PakError('orphaned PAKH directory nodes')
    if len(nodes) != sum(root['node_count'] for root in roots):
        raise PakError('PAKH root node counts do not match parsed nodes')

    root_keys = {root['name'].casefold() for root in roots}
    virtual_children = {child.casefold() for child in virtual_root['children']}
    if virtual_children != root_keys:
        raise PakError('PAKH virtual root does not contain every root namespace')
    for root in roots:
        root_path = root['name'] + '/'
        root_node = nodes.get(root_path.casefold())
        if root_node is None or root_node['parent'] != '':
            raise PakError('PAKH root namespace does not match a directory node')

    covered = {entry['index_ordinal'] for entry in files}
    if covered != set(range(len(records))):
        raise PakError('PAKH directory references do not cover every index entry')
    return {
        'roots': roots,
        'nodes': nodes,
        'files': files,
        'footer_crc32': f'{actual_crc:08x}',
    }


def _sha256_stream(source) -> str:
    digest = hashlib.sha256()
    for chunk in iter(lambda: source.read(1024 * 1024), b''):
        digest.update(chunk)
    return digest.hexdigest()


def _checked_members(archive: zipfile.ZipFile) -> list[zipfile.ZipInfo]:
    members = [item for item in archive.infolist() if not item.is_dir()]
    for name in ('Core.pakh', 'Core.pakd000'):
        if sum(item.filename == name for item in members) > 1:
            raise PakError(f'duplicate PAK member: {name}')
    return members


@contextmanager
def _open_zpak_info(path: Path):
    """Yield the archive and hashes of both the supplied and inner containers."""
    with path.open('rb') as source_file:
        source_hash = _sha256_stream(source_file)
        source_file.seek(0)
        with zipfile.ZipFile(source_file) as outer:
            members = _checked_members(outer)
            names = {item.filename for item in members}
            if {'Core.pakh', 'Core.pakd000'} <= names:
                yield outer, source_hash, source_hash
            else:
                candidates = [item for item in members if item.filename.endswith('/data.zpak') or item.filename == 'data.zpak']
                if len(candidates) != 1 or candidates[0].file_size > _MAX_DATA_BYTES:
                    raise PakError('expected a single bounded data.zpak in the supplied ZIP')
                # ZipFile requires random access to the nested archive; memory is bounded.
                with outer.open(candidates[0]) as nested_source:
                    content = nested_source.read(_MAX_DATA_BYTES + 1)
                if len(content) > _MAX_DATA_BYTES:
                    raise PakError('nested ZPAK exceeds read limit')
                inner_hash = hashlib.sha256(content).hexdigest()
                with zipfile.ZipFile(io.BytesIO(content)) as nested:
                    _checked_members(nested)
                    yield nested, source_hash, inner_hash
        source_file.seek(0)
        if _sha256_stream(source_file) != source_hash:
            raise PakError('source archive changed during the scan')


@contextmanager
def open_zpak(path: Path) -> Iterator[zipfile.ZipFile]:
    """Accept either data.zpak or the user's outer ZIP containing it."""
    with _open_zpak_info(path) as (archive, _source_hash, _inner_hash):
        yield archive


class _HashingReader:
    def __init__(self, source):
        self.source = source
        self.digest = hashlib.sha256()

    def read(self, size: int) -> bytes:
        data = self.source.read(size)
        self.digest.update(data)
        return data

    def tell(self) -> int:
        return self.source.tell()


def _safe_extract_dir(path: Path) -> Path:
    """Reject output in the checkout and common, identifiable sync roots."""
    target = path.expanduser().resolve()
    project = _PROJECT_ROOT.resolve()
    if target == project or target.is_relative_to(project):
        raise PakError('extract directory must be outside the project checkout')
    sync_names = {'baidusyncdisk', 'onedrive', 'dropbox', 'google drive', 'icloud drive'}
    for part in target.parts:
        name = part.casefold()
        if name in sync_names or name.startswith('onedrive - '):
            raise PakError('extract directory is inside a known sync folder')
    for name in ('OneDrive', 'OneDriveConsumer', 'OneDriveCommercial', 'DROPBOX_PATH', 'GOOGLE_DRIVE_PATH', 'BAIDU_SYNC_ROOT'):
        value = os.environ.get(name)
        if value:
            root = Path(value).expanduser().resolve()
            if target == root or target.is_relative_to(root):
                raise PakError('extract directory is inside a configured sync folder')
    return target


def _check_free_space(path: Path, required: int) -> None:
    existing = path
    while not existing.exists():
        if existing.parent == existing:
            raise PakError('could not locate an existing output parent')
        existing = existing.parent
    if not existing.is_dir():
        raise PakError('output parent is not a directory')
    if shutil.disk_usage(existing).free < required:
        raise PakError('not enough free space for the decoded resources')


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
        # This word is 262144 in the observed samples. Its precise semantics
        # and whether it strictly caps every decoded block remain unverified.
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


def scan_archive(path: Path, extract_dir: Path | None = None, *,
                 max_total_decoded_bytes: int = _DEFAULT_MAX_TOTAL_DECODED_BYTES,
                 expected_zpak_sha256: str | None = None) -> dict:
    if max_total_decoded_bytes <= 0:
        raise PakError('maximum total decoded bytes must be positive')
    if expected_zpak_sha256 is not None and not re.fullmatch(r'[0-9a-fA-F]{64}', expected_zpak_sha256):
        raise PakError('expected ZPAK SHA-256 must be 64 hexadecimal characters')
    if extract_dir is not None:
        extract_dir = _safe_extract_dir(extract_dir)
    with _open_zpak_info(path) as (archive, source_hash, zpak_hash):
        if expected_zpak_sha256 is not None and zpak_hash != expected_zpak_sha256.lower():
            raise PakError('data.zpak SHA-256 does not match the expected input')
        members = {i.filename: i for i in archive.infolist()}
        if 'Core.pakh' not in members or 'Core.pakd000' not in members:
            raise PakError('archive does not contain Core.pakh and Core.pakd000')
        if members['Core.pakh'].file_size > _MAX_INDEX_BYTES or members['Core.pakd000'].file_size > _MAX_DATA_BYTES:
            raise PakError('PAK member exceeds size limit')
        pakh = archive.read('Core.pakh')
        records = parse_index(pakh)
        directory = parse_directory(pakh, records)
        paths_by_identity = {}
        for entry in directory['files']:
            paths_by_identity.setdefault(entry['resource_id_hex'], []).append({
                'pakh_offset': entry['pakh_offset'],
                'identity_offset': entry['identity_offset'],
                'path': entry['path'],
                'type_word': entry['type_word'],
                'tag': entry['tag'],
            })
        expected_decoded = sum(r.decoded_bytes for r in records)
        if expected_decoded > max_total_decoded_bytes:
            raise PakError(f'total decoded bytes {expected_decoded} exceed configured limit {max_total_decoded_bytes}')
        if extract_dir is not None:
            _check_free_space(extract_dir, expected_decoded)
        expected_pairs = Counter((r.decoded_bytes, r.stored_bytes) for r in records)
        if sum(r.stored_bytes for r in records) != members['Core.pakd000'].file_size:
            raise PakError('index stored-size sum differs from actual PAKD length')
        index_by_offset = {}
        for r in records:
            if r.pakd_offset in index_by_offset:
                raise PakError(f'duplicate PAKD offset {r.pakd_offset} in index')
            if r.pakd_offset + r.stored_bytes > members['Core.pakd000'].file_size:
                raise PakError(f'index row {r.index_ordinal} exceeds PAKD length')
            index_by_offset[r.pakd_offset] = r
        observed_pairs = Counter()
        results = []
        with archive.open('Core.pakd000') as raw_stream:
            stream = _HashingReader(raw_stream)
            for row, payload in iter_resources(stream, len(records), collect_data=extract_dir is not None):
                pair = (row['decoded_bytes'], row['stored_bytes'])
                observed_pairs[pair] += 1
                if observed_pairs[pair] > expected_pairs[pair]:
                    raise PakError(f'data record {row["disk_ordinal"]} not present in index length multiset')
                record = index_by_offset.get(row['pakd_offset'])
                if record is None or pair != (record.decoded_bytes, record.stored_bytes):
                    raise PakError(f'data record {row["disk_ordinal"]} fails index offset/length match')
                row['index_candidates'] = [record.index_ordinal]
                row['key'] = f'{record.key:08x}'
                row['resource_id_hex'] = record.resource_id_hex
                row['path_candidates'] = paths_by_identity.get(record.resource_id_hex, [])
                if extract_dir is not None:
                    extract_dir.mkdir(parents=True, exist_ok=True)
                    suffix = f'key_{record.key:08x}'
                    destination = extract_dir / f'disk_{row["disk_ordinal"]:04d}_{suffix}.bin'
                    # No overwrite of earlier work or original assets.
                    with destination.open('xb') as output:
                        output.write(payload)
                results.append(row)
            if stream.tell() != members['Core.pakd000'].file_size:
                raise PakError('trailing unaccounted compressed bytes')
            pakd_hash = stream.digest.hexdigest()
        if observed_pairs != expected_pairs:
            raise PakError('full decoded-size/stored-size multiset does not match PAKH index')
        unique_count = len(results)
        length_only_unique_count = sum(count for count in expected_pairs.values() if count == 1)
        return {
            'source': str(path),
            'source_sha256': source_hash,
            'data_zpak_sha256': zpak_hash,
            'pakh_sha256': hashlib.sha256(pakh).hexdigest(),
            'pakd_sha256': pakd_hash,
            'index_count': len(records),
            'pakd_bytes': members['Core.pakd000'].file_size,
            'total_decoded_bytes': sum(r['decoded_bytes'] for r in results),
            'matching_method': 'pakd_offset_and_lengths',
            'uniquely_matched': unique_count,
            'ambiguous': len(results) - unique_count,
            'length_only_uniquely_matched': length_only_unique_count,
            'length_only_ambiguous': len(results) - length_only_unique_count,
            'directory_parse_method': 'flat_nodes_reconstructed_by_parent_and_children',
            'directory_roots': directory['roots'],
            'directory_nodes': len(directory['nodes']),
            'directory_files': len(directory['files']),
            'directory_identities_covered': len(paths_by_identity),
            'multi_reference_identities': sum(len(paths) > 1 for paths in paths_by_identity.values()),
            'extra_references': len(directory['files']) - len(paths_by_identity),
            'pakh_footer_crc32': directory['footer_crc32'],
            'multiset_verified': True,
            'resources': results,
        }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path, help='data.zpak or its containing outer ZIP')
    parser.add_argument('--report', type=Path, help='JSON report path; file must not exist')
    parser.add_argument('--extract', type=Path, help='opt-in local-only decoded .bin output directory')
    parser.add_argument('--max-total-decoded-bytes', type=int, default=_DEFAULT_MAX_TOTAL_DECODED_BYTES,
                        help='maximum decoded bytes (default: 1073741824); raise explicitly if needed')
    parser.add_argument('--expected-zpak-sha256', help='require this SHA-256 for the inner data.zpak')
    args = parser.parse_args()
    report = scan_archive(args.archive, args.extract,
                          max_total_decoded_bytes=args.max_total_decoded_bytes,
                          expected_zpak_sha256=args.expected_zpak_sha256)
    print(f"Verified {report['index_count']} resources, {report['pakd_bytes']} stored bytes, "
          f"{report['total_decoded_bytes']} decoded bytes, {report['uniquely_matched']} uniquely matched, "
          f"{report['ambiguous']} ambiguous.")
    print(f"Source SHA-256: {report['source_sha256']}; data.zpak SHA-256: {report['data_zpak_sha256']}")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        with args.report.open('x', encoding='utf-8') as file:
            json.dump(report, file, ensure_ascii=False, indent=2)
        print(f'Report written to {args.report}')


if __name__ == '__main__':
    main()

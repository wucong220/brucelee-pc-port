import io
import hashlib
import json
import os
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
import warnings
import zipfile
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import pak_extract
from pak_extract import PakError, parse_index, scan_archive


def archive_fixture(path: Path, originals: list[bytes], level: int = zlib.Z_DEFAULT_COMPRESSION,
                    references: list[tuple[int, str]] | None = None) -> None:
    rows = []
    disk_data = bytearray()
    for idx, payload in enumerate(originals):
        # One zlib stream across chunks, with a sync-flush before each continuation.
        compressor = zlib.compressobj(level)
        blocks = []
        for start in range(0, len(payload), 262144):
            is_final = start + 262144 >= len(payload)
            part = payload[start:start + 262144]
            blocks.append(compressor.compress(part) + compressor.flush(zlib.Z_FINISH if is_final else zlib.Z_SYNC_FLUSH))
        if not blocks:
            raise ValueError('fixture requires nonempty payload')
        stored = bytearray(struct.pack('<II', 262144, len(blocks[0]))) + blocks[0]
        for block in blocks[1:]:
            stored += struct.pack('<I', len(block)) + block
        pakd_offset = len(disk_data)
        disk_data.extend(stored)
        index_extra = b'example-value!!!'[:12] + struct.pack('<I', pakd_offset)
        rows.append((100 + idx * 100, index_extra, 0, len(payload), len(stored), 1))
    if references is None:
        references = [(idx, f'adreno_200/objects/file{idx}.bin') for idx in range(len(rows))]
    pakh = build_pakh(rows, references)
    with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_STORED) as archive:
        archive.writestr('Core.pakh', pakh)
        archive.writestr('Core.pakd000', disk_data)


def directory_string(value: str) -> bytes:
    raw = value.encode('utf-8')
    return struct.pack('<I', len(raw)) + raw + b'\0' * (4 - len(raw) % 4)


def update_pakh_crc(pakh: bytearray) -> None:
    struct.pack_into('<I', pakh, len(pakh) - 4, zlib.crc32(pakh[:-4]) & 0xffffffff)


def build_pakh(rows: list[tuple], references: list[tuple[int, str]]) -> bytes:
    root_name = 'adreno_200'
    nodes = {
        '': {'path': '', 'parent': '', 'children': {root_name}, 'files': []},
        root_name + '/': {'path': root_name + '/', 'parent': '', 'children': set(), 'files': []},
    }
    for index, full_path in references:
        folder, name_with_extension = full_path.rsplit('/', 1)
        folder += '/'
        if name_with_extension.count('.') != 1:
            raise ValueError('fixture paths need one extension')
        name, extension = name_with_extension.rsplit('.', 1)
        parts = folder.rstrip('/').split('/')
        for depth in range(2, len(parts) + 1):
            path = '/'.join(parts[:depth]) + '/'
            parent = '/'.join(parts[:depth - 1]) + '/'
            nodes.setdefault(path, {'path': path, 'parent': parent, 'children': set(), 'files': []})
            nodes[parent]['children'].add(parts[depth - 1])
        nodes[folder]['files'].append((index, folder, name, extension))

    pakh = bytearray(b'8KAP' + b'\x00' * 12 + b'DTRS' + struct.pack('<I', len(rows)))
    for row in rows:
        pakh += struct.pack('<I16sIIII', *row)
    pakh += struct.pack('<I', 1) + directory_string(root_name) + struct.pack('<I', len(nodes))
    for path in sorted(nodes, reverse=True):
        node = nodes[path]
        pakh += directory_string(node['path']) + directory_string(node['parent'])
        node_files = sorted(node['files'])
        pakh += struct.pack('<I', len(node_files))
        for index, folder, name, extension in node_files:
            key, extra, *_ = rows[index]
            identity = struct.pack('<I', key) + extra[:12]
            pakh += struct.pack('<II', 0, 0x3ED94A35)
            pakh += directory_string(folder) + directory_string(name) + directory_string(extension)
            pakh += identity
        children = sorted(node['children'])
        pakh += struct.pack('<I', len(children))
        for child in children:
            pakh += directory_string(child)
    pakh += struct.pack('<I', zlib.crc32(pakh) & 0xffffffff)
    return bytes(pakh)


class TestPakIndex(unittest.TestCase):
    def test_multi_block_resource_and_report(self):
        with tempfile.TemporaryDirectory() as temp:
            data = Path(temp) / 'data.zpak'
            archive_fixture(data, [b'Hello' * 10, (b'A' * 262144) + (b'B' * 262144) + b'Z' * 123])
            out = scan_archive(data)
            self.assertTrue(out['multiset_verified'])
            self.assertEqual(out['index_count'], 2)
            self.assertEqual(out['uniquely_matched'], 2)
            self.assertEqual(out['resources'][1]['zlib_chunks'], 3)
            self.assertEqual(out['resources'][1]['decoded_bytes'], 524411)

    def test_duplicate_sizes_match_by_offset(self):
        with tempfile.TemporaryDirectory() as temp:
            data = Path(temp) / 'data.zpak'
            archive_fixture(data, [b'test' * 100, b'test' * 100])
            out = scan_archive(data)
            self.assertEqual(out['length_only_ambiguous'], 2)
            self.assertEqual(out['ambiguous'], 0)
            self.assertEqual([r['index_candidates'] for r in out['resources']], [[0], [1]])
            self.assertEqual([r['key'] for r in out['resources']], ['00000064', '000000c8'])
            self.assertTrue(all(len(r['resource_id_hex']) == 32 for r in out['resources']))

    def test_offset_matching_does_not_assume_index_and_disk_order_match(self):
        with tempfile.TemporaryDirectory() as temp:
            data = Path(temp) / 'data.zpak'
            archive_fixture(data, [b'A' * 400, b'B' * 500])
            with zipfile.ZipFile(data) as archive:
                pakh = bytearray(archive.read('Core.pakh'))
                pakd = archive.read('Core.pakd000')
            row0, row1 = pakh[28:60], pakh[64:96]
            pakh[28:60], pakh[64:96] = row1, row0
            update_pakh_crc(pakh)
            with zipfile.ZipFile(data, 'w') as archive:
                archive.writestr('Core.pakh', pakh)
                archive.writestr('Core.pakd000', pakd)
            out = scan_archive(data)
            self.assertEqual([r['index_candidates'] for r in out['resources']], [[1], [0]])
            self.assertEqual([r['key'] for r in out['resources']], ['000000c8', '00000064'])

    def test_duplicate_or_incorrect_index_offsets_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            data = Path(temp) / 'data.zpak'
            archive_fixture(data, [b'A' * 400, b'B' * 500])
            with zipfile.ZipFile(data) as archive:
                original_pakh = archive.read('Core.pakh')
                pakd = archive.read('Core.pakd000')
            for field_offset, replacement, message in ((24 + 36 + 16, 0, 'duplicate PAKD offset'),
                                                        (24 + 16, 1, 'offset/length match')):
                pakh = bytearray(original_pakh)
                struct.pack_into('<I', pakh, field_offset, replacement)
                update_pakh_crc(pakh)
                with zipfile.ZipFile(data, 'w') as archive:
                    archive.writestr('Core.pakh', pakh)
                    archive.writestr('Core.pakd000', pakd)
                with self.subTest(replacement=replacement), self.assertRaisesRegex(PakError, message):
                    scan_archive(data)

    def test_directory_string_padding_requires_nul_even_for_aligned_length(self):
        data = directory_string('ABCD')
        self.assertEqual(pak_extract._read_directory_string(data, 0), ('ABCD', 12))
        with self.assertRaises(PakError):
            pak_extract._read_directory_string(data[:-1], 0)
        with self.assertRaises(PakError):
            pak_extract._read_directory_string(data[:-1] + b'X', 0)

    def test_directory_tree_uses_identity_and_keeps_aliases(self):
        with tempfile.TemporaryDirectory() as temp:
            data = Path(temp) / 'data.zpak'
            archive_fixture(data, [b'A' * 400, b'B' * 500], references=[
                (0, 'adreno_200/ui/ABCD.tex'),
                (0, 'adreno_200/other/alias.tex'),
                (1, 'adreno_200/otherwise/solo.bin'),
            ])
            result = scan_archive(data)
            self.assertEqual(result['directory_roots'], [{'name': 'adreno_200', 'node_count': 5}])
            self.assertEqual(result['directory_nodes'], 5)
            self.assertEqual(result['directory_files'], 3)
            self.assertEqual(result['directory_identities_covered'], 2)
            self.assertEqual(result['multi_reference_identities'], 1)
            self.assertEqual(result['extra_references'], 1)
            self.assertRegex(result['pakh_footer_crc32'], r'^[0-9a-f]{8}$')
            paths = result['resources'][0]['path_candidates']
            self.assertEqual([item['path'] for item in paths],
                             ['adreno_200/ui/ABCD.tex', 'adreno_200/other/alias.tex'])
            self.assertTrue(all(item['type_word'] == 0 and item['tag'] == 0x3ED94A35 for item in paths))
            self.assertEqual([item['path'] for item in result['resources'][1]['path_candidates']],
                             ['adreno_200/otherwise/solo.bin'])

    def test_directory_footer_crc_and_identity_are_validated(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data = root / 'data.zpak'
            archive_fixture(data, [b'payload'])
            with zipfile.ZipFile(data) as archive:
                original_pakh = archive.read('Core.pakh')
                pakd = archive.read('Core.pakd000')
            cases = []
            bad_crc = bytearray(original_pakh)
            bad_crc[-1] ^= 0xFF
            cases.append((bad_crc, 'CRC32 mismatch'))
            bad_identity = bytearray(original_pakh)
            identity = original_pakh[24:40]
            table_end = 24 + 36
            identity_offset = bad_identity.find(identity, table_end)
            self.assertGreater(identity_offset, table_end)
            bad_identity[identity_offset] ^= 0xFF
            cases.append((bad_identity, 'unmatched PAKH file identity'))
            for pakh, message in cases:
                with zipfile.ZipFile(data, 'w') as archive:
                    archive.writestr('Core.pakh', pakh)
                    archive.writestr('Core.pakd000', pakd)
                with self.subTest(message=message), self.assertRaisesRegex(PakError, message):
                    scan_archive(data)

    def test_every_index_entry_requires_a_directory_reference(self):
        with tempfile.TemporaryDirectory() as temp:
            data = Path(temp) / 'data.zpak'
            archive_fixture(data, [b'first', b'second'], references=[
                (0, 'adreno_200/objects/first.bin'),
            ])
            with self.assertRaisesRegex(PakError, 'cover every index entry'):
                scan_archive(data)

    def test_directory_child_reference_must_resolve(self):
        with tempfile.TemporaryDirectory() as temp:
            data = Path(temp) / 'data.zpak'
            archive_fixture(data, [b'payload'])
            with zipfile.ZipFile(data) as archive:
                pakh = bytearray(archive.read('Core.pakh'))
                pakd = archive.read('Core.pakd000')
            table_end = 24 + 36
            child_entry = directory_string('objects')
            child_offset = pakh.find(child_entry, table_end)
            self.assertGreater(child_offset, table_end)
            pakh[child_offset + 4] = ord('X')
            update_pakh_crc(pakh)
            with zipfile.ZipFile(data, 'w') as archive:
                archive.writestr('Core.pakh', pakh)
                archive.writestr('Core.pakd000', pakd)
            with self.assertRaisesRegex(PakError, 'child directory does not match'):
                scan_archive(data)

    def test_reject_invalid_index_count(self):
        with self.assertRaises(PakError):
            parse_index(b'8KAP' + b'\0' * 12 + b'DTRS' + struct.pack('<I', 50000) + b'\0' * 64)

    def test_reject_corrupted_data_without_extraction(self):
        with tempfile.TemporaryDirectory() as temp:
            data = Path(temp) / 'data.zpak'
            archive_fixture(data, [b'x' * 100])
            with zipfile.ZipFile(data, 'r') as archive:
                idx = archive.read('Core.pakh')
                stream = bytearray(archive.read('Core.pakd000'))
            stream[-3] ^= 17
            with zipfile.ZipFile(data, 'w') as archive:
                archive.writestr('Core.pakh', idx)
                archive.writestr('Core.pakd000', stream)
            with self.assertRaises(PakError):
                scan_archive(data)

    def test_valid_resource_at_decoded_limit_can_have_larger_stored_size(self):
        with tempfile.TemporaryDirectory() as temp:
            data = Path(temp) / 'data.zpak'
            payload = bytes(range(256)) * 65536
            archive_fixture(data, [payload], level=0)
            out = scan_archive(data)
            self.assertEqual(out['total_decoded_bytes'], len(payload))
            self.assertGreater(out['resources'][0]['stored_bytes'], len(payload))
            self.assertEqual(out['resources'][0]['sha256'], hashlib.sha256(payload).hexdigest())

    def test_direct_and_nested_source_hashes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            inner = root / 'data.zpak'
            archive_fixture(inner, [b'example' * 100])
            inner_sha = hashlib.sha256(inner.read_bytes()).hexdigest()
            with zipfile.ZipFile(inner) as archive:
                pakh_sha = hashlib.sha256(archive.read('Core.pakh')).hexdigest()
                pakd_sha = hashlib.sha256(archive.read('Core.pakd000')).hexdigest()
            direct = scan_archive(inner, expected_zpak_sha256=inner_sha.upper())
            self.assertEqual(direct['source_sha256'], inner_sha)
            self.assertEqual(direct['data_zpak_sha256'], inner_sha)
            self.assertEqual(direct['pakh_sha256'], pakh_sha)
            self.assertEqual(direct['pakd_sha256'], pakd_sha)
            outer = root / 'outer.zip'
            with zipfile.ZipFile(outer, 'w') as archive:
                archive.write(inner, 'fixture/data.zpak')
            nested = scan_archive(outer, expected_zpak_sha256=inner_sha)
            self.assertEqual(nested['source_sha256'], hashlib.sha256(outer.read_bytes()).hexdigest())
            self.assertEqual(nested['data_zpak_sha256'], inner_sha)
            self.assertEqual(nested['pakd_sha256'], pakd_sha)
            self.assertEqual(nested['resources'][0]['sha256'], direct['resources'][0]['sha256'])

    def test_wrong_or_malformed_expected_hash_stops_before_extract(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data = root / 'data.zpak'
            archive_fixture(data, [b'example'])
            target = root / 'output'
            with patch.object(pak_extract, '_PROJECT_ROOT', root / 'project'):
                for expected in ('0' * 64, 'not-a-hash'):
                    with self.subTest(expected=expected), self.assertRaises(PakError):
                        scan_archive(data, target, expected_zpak_sha256=expected)
                self.assertFalse(target.exists())

    def test_total_limit_is_checked_before_extract(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data = root / 'data.zpak'
            archive_fixture(data, [b'A' * 400, b'B' * 500])
            target = root / 'output'
            with patch.object(pak_extract, '_PROJECT_ROOT', root / 'project'):
                with self.assertRaises(PakError):
                    scan_archive(data, target, max_total_decoded_bytes=899)
                self.assertFalse(target.exists())
                self.assertEqual(scan_archive(data, max_total_decoded_bytes=900)['total_decoded_bytes'], 900)
                with self.assertRaises(PakError):
                    scan_archive(data, max_total_decoded_bytes=0)

    def test_extract_rejects_project_and_known_sync_directories(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data = root / 'data.zpak'
            archive_fixture(data, [b'example'])
            project = root / 'project'
            with patch.object(pak_extract, '_PROJECT_ROOT', project):
                for target in (project / 'out', root / 'BaiduSyncdisk' / 'out'):
                    with self.subTest(target=target), self.assertRaises(PakError):
                        scan_archive(data, target)
                    self.assertFalse(target.exists())
                with patch.dict(os.environ, {'BAIDU_SYNC_ROOT': str(root / 'custom-sync')}):
                    with self.assertRaises(PakError):
                        scan_archive(data, root / 'custom-sync' / 'out')

    def test_safe_extract_and_low_space_guard(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data = root / 'data.zpak'
            payload = b'example' * 100
            archive_fixture(data, [payload])
            target = root / 'output'
            with patch.object(pak_extract, '_PROJECT_ROOT', root / 'project'):
                with patch.object(pak_extract.shutil, 'disk_usage', return_value=SimpleNamespace(free=0)):
                    with self.assertRaises(PakError):
                        scan_archive(data, target)
                    self.assertFalse(target.exists())
                out = scan_archive(data, target)
                extracted = list(target.glob('*.bin'))
                self.assertEqual(len(extracted), 1)
                self.assertEqual(hashlib.sha256(extracted[0].read_bytes()).hexdigest(), out['resources'][0]['sha256'])
                with self.assertRaises(FileExistsError):
                    scan_archive(data, target)
                self.assertEqual(extracted[0].read_bytes(), payload)

    def test_source_mutation_is_reported(self):
        with tempfile.TemporaryDirectory() as temp:
            data = Path(temp) / 'data.zpak'
            archive_fixture(data, [b'example'])
            with patch.object(pak_extract, '_sha256_stream', side_effect=['0' * 64, '1' * 64]):
                with self.assertRaisesRegex(PakError, 'changed during'):
                    scan_archive(data)

    def test_duplicate_pak_or_nested_container_names_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp, warnings.catch_warnings():
            warnings.simplefilter('ignore', UserWarning)
            root = Path(temp)
            direct = root / 'duplicate.zpak'
            with zipfile.ZipFile(direct, 'w') as archive:
                archive.writestr('Core.pakh', b'first')
                archive.writestr('Core.pakh', b'second')
                archive.writestr('Core.pakd000', b'data')
            with self.assertRaisesRegex(PakError, 'duplicate PAK'):
                scan_archive(direct)
            nested_outer = root / 'nested-duplicate.zip'
            with zipfile.ZipFile(nested_outer, 'w') as archive:
                archive.write(direct, 'fixture/data.zpak')
            with self.assertRaisesRegex(PakError, 'duplicate PAK'):
                scan_archive(nested_outer)
            outer = root / 'outer.zip'
            with zipfile.ZipFile(outer, 'w') as archive:
                archive.writestr('data.zpak', b'first')
                archive.writestr('data.zpak', b'second')
            with self.assertRaisesRegex(PakError, 'single bounded'):
                scan_archive(outer)

    def test_cli_writes_hashes_for_nested_archive(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            inner = root / 'data.zpak'
            archive_fixture(inner, [b'A' * 400, b'B' * 500])
            inner_sha = hashlib.sha256(inner.read_bytes()).hexdigest()
            outer = root / 'outer.zip'
            with zipfile.ZipFile(outer, 'w') as archive:
                archive.write(inner, 'fixture/data.zpak')
            report = root / 'report.json'
            script = Path(__file__).resolve().parents[1] / 'tools' / 'pak_extract.py'
            run = subprocess.run(
                [sys.executable, '-X', 'utf8', str(script), str(outer),
                 '--report', str(report), '--expected-zpak-sha256', inner_sha,
                 '--max-total-decoded-bytes', '900'],
                capture_output=True, text=True, encoding='utf-8', check=False,
            )
            self.assertEqual(run.returncode, 0, run.stderr)
            result = json.loads(report.read_text(encoding='utf-8'))
            self.assertEqual(result['source_sha256'], hashlib.sha256(outer.read_bytes()).hexdigest())
            self.assertEqual(result['data_zpak_sha256'], inner_sha)
            self.assertEqual(result['total_decoded_bytes'], 900)


if __name__ == '__main__':
    unittest.main()

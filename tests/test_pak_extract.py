import io
import struct
import sys
import tempfile
import unittest
from pathlib import Path
import zipfile
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from pak_extract import PakError, parse_index, scan_archive


def archive_fixture(path: Path, originals: list[bytes]) -> None:
    rows = []
    disk_data = bytearray()
    for idx, payload in enumerate(originals):
        # One zlib stream across chunks, with a sync-flush before each continuation.
        compressor = zlib.compressobj()
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
        disk_data.extend(stored)
        rows.append((100 + idx * 100, b'example-value!!!'[:16], 0, len(payload), len(stored), 1))
    pakh = b'8KAP' + b'\x00' * 12 + b'DTRS' + struct.pack('<I', len(rows))
    for row in rows:
        pakh += struct.pack('<I16sIIII', *row)
    pakh += struct.pack('<I', 1) + b'\x01\x00\x00\x00x'
    with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_STORED) as archive:
        archive.writestr('Core.pakh', pakh)
        archive.writestr('Core.pakd000', disk_data)


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

    def test_duplicate_sizes_remain_ambiguous(self):
        with tempfile.TemporaryDirectory() as temp:
            data = Path(temp) / 'data.zpak'
            archive_fixture(data, [b'test' * 100, b'test' * 100])
            out = scan_archive(data)
            self.assertEqual(out['ambiguous'], 2)
            self.assertTrue(all(r['key'] is None for r in out['resources']))

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


if __name__ == '__main__':
    unittest.main()

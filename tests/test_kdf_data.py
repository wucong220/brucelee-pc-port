import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_data import KdfError, parse_container, scalar_property


def kdf_container(nodes=((0x60000000, 2), (0, 123)), group_count=1, offsets=(0, 0),
                  payload=b'payload', tail=b'0123456789abcdef') -> bytes:
    strings = ['key', 'Data', 'duration']
    raw = bytearray(b'1FDKENONCTX3' + struct.pack('<IIII', len(strings), 1, 0, len(strings)))
    for text in strings:
        encoded = text.encode()
        identifier = (zlib.crc32(encoded) + len(encoded)) & 0xffffffff
        raw += struct.pack('<II', identifier, len(encoded)) + encoded + b'\0'
    raw += b'\0'
    raw += b'DATA'
    if len(offsets) != group_count + 1:
        raise ValueError('offsets must contain group_count + 1 entries')
    raw += struct.pack('<IIII', len(nodes), group_count, 0, len(payload))
    raw += struct.pack(f'<{len(offsets)}I', *offsets)
    for first, second in nodes:
        raw += struct.pack('<II', first, second)
    raw += payload + tail
    return bytes(raw)


class TestKdfData(unittest.TestCase):
    def test_counts_records_and_identity_tail(self):
        result = parse_container(kdf_container())
        self.assertEqual(result['string_count'], 3)
        self.assertEqual(result['record_count'], 2)
        self.assertEqual(result['offset_count'], 1)
        self.assertEqual(result['offsets'], [0, 0])
        self.assertEqual(result['records'][0], {'ordinal': 0, 'first': 0x60000000, 'second': 2})
        self.assertEqual(scalar_property(result, 'duration'), 123)
        self.assertEqual(result['sections'], [{
            'ordinal': 0, 'start_relative': 0, 'end_relative': 7, 'bytes': 7,
        }])
        self.assertEqual(result['payload_bytes'], len(b'payload'))
        self.assertEqual(result['tail_identity_hex'], b'0123456789abcdef'.hex())
        self.assertEqual(result['data_offset'], result['string_table_end'] + 1)

    def test_lengths_and_group_offsets_are_validated(self):
        cases = [
            (kdf_container(offsets=(0, 1)), 'section offsets are invalid'),
            (kdf_container(nodes=((0, 0), (0, 0)), group_count=2,
                           offsets=(0, 0, 8)), 'section offset exceeds payload'),
        ]
        for raw, message in cases:
            with self.subTest(message=message), self.assertRaisesRegex(KdfError, message):
                parse_container(raw)
        with self.assertRaisesRegex(KdfError, 'payload bounds'):
            parse_container(kdf_container()[:-1])

    def test_cli_can_omit_or_include_tables(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / 'sample.bin'
            source.write_bytes(kdf_container())
            script = Path(__file__).resolve().parents[1] / 'tools' / 'kdf_data.py'
            run = subprocess.run([sys.executable, '-X', 'utf8', str(script), str(source)],
                                 capture_output=True, text=True, encoding='utf-8', check=False)
            self.assertEqual(run.returncode, 0, run.stderr)
            report = json.loads(run.stdout)
            self.assertNotIn('records', report)
            self.assertNotIn('strings', report)
            run = subprocess.run(
                [sys.executable, '-X', 'utf8', str(script), str(source),
                 '--records', '--strings'],
                capture_output=True, text=True, encoding='utf-8', check=False,
            )
            self.assertEqual(run.returncode, 0, run.stderr)
            report = json.loads(run.stdout)
            self.assertEqual(report['strings'][0]['text'], 'key')
            self.assertEqual(report['records'][0]['second'], 2)


if __name__ == '__main__':
    unittest.main()

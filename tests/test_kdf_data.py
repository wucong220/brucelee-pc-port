import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_data import KdfError, parse_container


def kdf_container(nodes=((0, 0x60000000),), roots=(0,), payload=b'payload',
                  terminator=0, tail=b'0123456789abcdef') -> bytes:
    strings = ['key', 'Data']
    raw = bytearray(b'1FDKENONCTX3' + struct.pack('<IIII', len(strings), 1, 0, len(strings)))
    for text in strings:
        encoded = text.encode()
        identifier = (zlib.crc32(encoded) + len(encoded)) & 0xffffffff
        raw += struct.pack('<II', identifier, len(encoded)) + encoded + b'\0'
    raw += b'\0'
    raw += b'DATA'
    raw += struct.pack('<IIII', len(nodes), len(roots), 0, len(payload))
    raw += struct.pack(f'<{len(roots)}I', *roots)
    for first, second in nodes:
        raw += struct.pack('<II', first, second)
    raw += struct.pack('<I', terminator)
    raw += payload + tail
    return bytes(raw)


class TestKdfData(unittest.TestCase):
    def test_counts_records_and_identity_tail(self):
        result = parse_container(kdf_container())
        self.assertEqual(result['string_count'], 2)
        self.assertEqual(result['record_count'], 1)
        self.assertEqual(result['index_count'], 1)
        self.assertEqual(result['indices'], [0])
        self.assertEqual(result['records'], [{'ordinal': 0, 'first': 0, 'second': 0x60000000}])
        self.assertEqual(result['payload_bytes'], len(b'payload'))
        self.assertEqual(result['tail_identity_hex'], b'0123456789abcdef'.hex())
        self.assertEqual(result['data_offset'], result['string_table_end'] + 1)

    def test_lengths_roots_and_terminator_are_validated(self):
        cases = [
            (kdf_container(roots=(1,)), 'entry index out of bounds'),
            (kdf_container(terminator=1), 'terminator is not zero'),
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
            self.assertEqual(report['records'][0]['second'], 0x60000000)


if __name__ == '__main__':
    unittest.main()

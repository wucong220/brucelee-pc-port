import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_strings import KdfError, inspect_bytes, inspect_file


def sample_table(entries):
    data = bytearray(b'1FDKENONCTX3' + struct.pack('<IIII', len(entries), 0, 0, len(entries)))
    for stored_id, value in entries:
        data += struct.pack('<II', stored_id, len(value)) + value + b'\0'
    return bytes(data) + b'DATA'


class TestKdfStrings(unittest.TestCase):
    def test_observed_strings_and_offsets(self):
        data = sample_table([(0x0ddeb8b9, b'linear'), (0x85ce0669, b'texture2d')])
        result = inspect_bytes(data, include_strings=True)
        self.assertEqual(result['sha256'], hashlib.sha256(data).hexdigest())
        self.assertEqual(result['string_count'], 2)
        self.assertEqual(result['crc32_plus_length_matches'], 2)
        self.assertEqual(result['strings'][0]['record_offset'], 0x1c)
        self.assertEqual(result['strings'][0]['string_offset'], 0x24)
        self.assertEqual(result['strings'][0]['text'], 'linear')
        self.assertEqual(result['strings'][1]['stored_id'], '85ce0669')

    def test_rule_is_reported_not_enforced(self):
        data = sample_table([(0x12345678, b'linear')])
        result = inspect_bytes(data, include_strings=True)
        self.assertEqual(result['crc32_plus_length_mismatches'], 1)
        self.assertEqual(result['strings'][0]['crc32_plus_length'], '0ddeb8b9')
        self.assertFalse(result['strings'][0]['matches_observed_rule'])
        self.assertNotIn('strings', inspect_bytes(data))

    def test_non_utf8_strings_do_not_require_guessing_encoding(self):
        result = inspect_bytes(sample_table([(0, b'\xff\xfe')]), include_strings=True)
        self.assertIsNone(result['strings'][0]['text'])
        self.assertEqual(result['strings'][0]['byte_length'], 2)

    def test_truncated_and_excessive_tables_are_rejected(self):
        valid = sample_table([(0x0ddeb8b9, b'linear')])
        cases = [b'not-kdf', valid[:30], valid[:38],
                 valid[:40] + b'X' * 7,
                 valid[:24] + struct.pack('<I', 20001),
                 valid[:32] + struct.pack('<I', 1024 * 1024 + 1)]
        for data in cases:
            with self.subTest(length=len(data)), self.assertRaises(KdfError):
                inspect_bytes(data)

    def test_cli_scans_directory_and_reports_unsupported_files(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            data = sample_table([(0x0ddeb8b9, b'linear')])
            (root / 'a.bin').write_bytes(data)
            self.assertEqual(inspect_file(root / 'a.bin')['string_count'], 1)
            (root / 'b.bin').write_bytes(b'RIFF0000WAVE')
            script = Path(__file__).resolve().parents[1] / 'tools' / 'kdf_strings.py'
            run = subprocess.run([sys.executable, '-X', 'utf8', str(script), str(root)],
                                 capture_output=True, text=True, encoding='utf-8', check=False)
            self.assertEqual(run.returncode, 0, run.stderr)
            report = json.loads(run.stdout)
            self.assertEqual(report['input_count'], 2)
            self.assertEqual(report['unsupported'], 1)
            self.assertEqual(report['invalid'], 0)
            self.assertEqual([row['status'] for row in report['files']], ['ok', 'unsupported'])
            self.assertNotIn('strings', report['files'][0])
            (root / 'c.bin').write_bytes(b'1FDKENONCTX3')
            run = subprocess.run([sys.executable, '-X', 'utf8', str(script), str(root)],
                                 capture_output=True, text=True, encoding='utf-8', check=False)
            self.assertEqual(run.returncode, 1, run.stderr)
            report = json.loads(run.stdout)
            self.assertEqual(report['invalid'], 1)
            self.assertEqual(report['files'][2]['status'], 'invalid')


if __name__ == '__main__':
    unittest.main()

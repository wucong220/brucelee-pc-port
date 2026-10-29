import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_data import KdfError
from kdf_program import inspect_program_bytes


def program_fixture(*, texture_names=('diffuse', 'normal', 'material')) -> bytes:
    strings = ['fs', 'code', 'constants', *texture_names, 'error']
    records = [(0x60000000, strings.index('fs'))]
    for name in texture_names:
        records.append((strings.index(name), 0x40000004))
        records.append((0x60000000, strings.index('error')))

    raw = bytearray(
        b'1FDKENONCTX3'
        + struct.pack('<IIII', len(strings), 0, 0, len(strings))
    )
    for text in strings:
        encoded = text.encode()
        identifier = (zlib.crc32(encoded) + len(encoded)) & 0xFFFFFFFF
        raw += struct.pack('<II', identifier, len(encoded)) + encoded + b'\0'
    padding_length = (len(raw) - 0x1C) & 3
    raw += b'\0' * padding_length
    payload = b'uniform sampler2D g_sFakeMetadataName;\n'
    raw += b'DATA'
    raw += struct.pack('<IIII', len(records), 3, 15, len(payload))
    raw += struct.pack('<4I', 0, 0, 0, 0)
    for record in records:
        raw += struct.pack('<II', *record)
    sampler_source = ''.join(
        f'uniform sampler2D g_s{name.capitalize()};\n'
        for name in texture_names
    ).encode()
    raw += payload + sampler_source
    return bytes(raw)


class TestKdfProgram(unittest.TestCase):
    def test_extracts_texture_constant_names_without_source(self):
        result = inspect_program_bytes(program_fixture())
        self.assertEqual(result['profile_word'], 15)
        self.assertEqual(result['record_count'], 7)
        self.assertEqual(result['offset_count'], 3)
        self.assertEqual(result['texture_constant_count'], 3)
        self.assertEqual(
            [entry['name'] for entry in result['texture_constants']],
            ['diffuse', 'normal', 'material'],
        )
        self.assertEqual(result['shader_source_status'], 'present-but-not-returned')
        self.assertNotIn('uniform sampler2D', json.dumps(result))
        self.assertNotIn(
            'fake_metadata_name',
            [entry['name'] for entry in result['texture_constants']],
        )

    def test_rejects_missing_constant_record_and_sampler_uniform(self):
        raw = bytearray(program_fixture())
        data_offset = raw.find(b'DATA')
        record_start = data_offset + 20 + 4 * 4
        struct.pack_into('<I', raw, record_start + 8, 0x6FFFFFFF)
        with self.assertRaisesRegex(KdfError, 'no unique constant record'):
            inspect_program_bytes(bytes(raw))
        with self.assertRaisesRegex(KdfError, 'declares no sampler2D uniforms'):
            inspect_program_bytes(program_fixture(texture_names=()))

    def test_rejects_unsupported_profile(self):
        raw = bytearray(program_fixture())
        data_offset = raw.find(b'DATA')
        struct.pack_into('<I', raw, data_offset + 12, 16)
        with self.assertRaisesRegex(KdfError, 'unsupported program profile word'):
            inspect_program_bytes(bytes(raw))

    def test_truncation_always_raises_kdf_error(self):
        raw = program_fixture()
        data_offset = raw.find(b'DATA')
        record_start = data_offset + 20 + 4 * 4
        for cut in (0x1B, data_offset + 19, data_offset + 20,
                    record_start + 3):
            with self.subTest(cut=cut), self.assertRaises(KdfError):
                inspect_program_bytes(raw[:cut])

    def test_cli_outputs_program_metadata(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / 'sample.program'
            source.write_bytes(program_fixture())
            script = Path(__file__).resolve().parents[1] / 'tools' / 'kdf_program.py'
            run = subprocess.run(
                [sys.executable, '-X', 'utf8', str(script), str(source)],
                capture_output=True, text=True, encoding='utf-8', check=False,
            )
            self.assertEqual(run.returncode, 0, run.stderr)
            report = json.loads(run.stdout)
            self.assertEqual(report['texture_constant_count'], 3)


if __name__ == '__main__':
    unittest.main()

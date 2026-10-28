import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_animation import inspect_animation
from kdf_data import KdfError


HEADER_VALUES = {
    'firstframe': 0,
    'duration': 69,
    'framerate': 30,
    'version': 7,
    'pose': 1,
}


def animation_fixture(values=None) -> bytes:
    values = HEADER_VALUES if values is None else values
    strings = list(values) + ['waveletsample', 'quantizedbits']
    records = []
    for key, value in values.items():
        records.extend(((0x60000000, strings.index(key)), (0, value)))
    payload = bytes(range(16))
    offsets = (0, 0, 4, 8)
    raw = bytearray(b'1FDKENONCTX3' + struct.pack('<IIII', len(strings), 1, 0, len(strings)))
    for text in strings:
        encoded = text.encode()
        identifier = (zlib.crc32(encoded) + len(encoded)) & 0xffffffff
        raw += struct.pack('<II', identifier, len(encoded)) + encoded + b'\0'
    raw += b'\0'
    raw += b'DATA'
    raw += struct.pack('<IIII', len(records), 3, 0, len(payload))
    raw += struct.pack('<4I', *offsets)
    for record in records:
        raw += struct.pack('<II', *record)
    raw += payload + b'animation-ident!'
    return bytes(raw)


class TestKdfAnimation(unittest.TestCase):
    def test_verified_scalar_header_and_sections(self):
        for duration in (110, 69, 86):
            values = dict(HEADER_VALUES, duration=duration)
            with self.subTest(duration=duration):
                result = inspect_animation(animation_fixture(values))
                self.assertEqual(result['headers'], values)
                self.assertEqual(result['record_count'], 10)
                self.assertEqual(result['sections'], [
                    {'ordinal': 0, 'start_relative': 0, 'end_relative': 4, 'bytes': 4},
                    {'ordinal': 1, 'start_relative': 4, 'end_relative': 8, 'bytes': 4},
                    {'ordinal': 2, 'start_relative': 8, 'end_relative': 16, 'bytes': 8},
                ])
                self.assertIn('waveletsample', result['codec_keys_present'])

    def test_missing_header_key_is_rejected(self):
        values = dict(HEADER_VALUES)
        del values['framerate']
        with self.assertRaisesRegex(KdfError, 'framerate'):
            inspect_animation(animation_fixture(values))

    def test_cli_outputs_header_json(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / 'idle.bin'
            source.write_bytes(animation_fixture())
            script = Path(__file__).resolve().parents[1] / 'tools' / 'kdf_animation.py'
            run = subprocess.run(
                [sys.executable, '-X', 'utf8', str(script), str(source)],
                capture_output=True, text=True, encoding='utf-8', check=False,
            )
            self.assertEqual(run.returncode, 0, run.stderr)
            report = json.loads(run.stdout)
            self.assertEqual(report['headers']['duration'], 69)


if __name__ == '__main__':
    unittest.main()

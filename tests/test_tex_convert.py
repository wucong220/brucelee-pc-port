import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import tex_convert
from tex_convert import TextureError, convert_file, encode_png_rgba, parse_texture


STRINGS = [
    'linear', 'minfilter', 'magfilter', 'clamp', 'wraps', 'wrapt', 'id',
    'format', 'r8g8b8a8', 'sizex', 'sizey', 'sizez', 'hasalpha', 'type',
    'texture2d', 'mips', 'datasourcepath/sprites/fixture.tga',
]


def kdf_texture(width: int, height: int, pixels: bytes) -> bytes:
    raw = bytearray(b'1FDKENONCTX3' + struct.pack('<IIII', len(STRINGS), 0, 0, len(STRINGS)))
    for value in STRINGS:
        encoded = value.encode('utf-8')
        identifier = (zlib.crc32(encoded) + len(encoded)) & 0xffffffff
        raw += struct.pack('<II', identifier, len(encoded)) + encoded + b'\0'
    raw += b'\0' * (-len(raw) % 4)
    data_offset = len(raw)
    header = bytearray(236)
    header[:4] = b'DATA'
    struct.pack_into('<I', header, 0x10, len(pixels))
    struct.pack_into('<I', header, 0x90, width)
    struct.pack_into('<I', header, 0xA0, height)
    raw += header + pixels
    raw += hashlib.md5(raw).digest()
    return bytes(raw)


def png_scanlines(png: bytes) -> bytes:
    position = 8
    compressed = bytearray()
    while position < len(png):
        size = struct.unpack_from('>I', png, position)[0]
        tag = png[position + 4:position + 8]
        body = png[position + 8:position + 8 + size]
        if tag == b'IDAT':
            compressed += body
        position += 12 + size
    return zlib.decompress(compressed)


class TestTextureConversion(unittest.TestCase):
    def test_parse_metadata_and_md5(self):
        width, height = 2, 2
        pixels = bytes(range(width * height * 4))
        raw = kdf_texture(width, height, pixels)
        result = parse_texture(raw)
        self.assertEqual((result['width'], result['height']), (width, height))
        self.assertEqual(result['pixels'], pixels)
        self.assertEqual(result['sha256'], hashlib.sha256(raw).hexdigest())
        self.assertEqual(result['string_count'], len(STRINGS))

    def test_png_rows_are_flipped(self):
        pixels = (
            b'\xff\x00\x00\xff' * 2
            + b'\x00\x00\xff\xff' * 2
        )
        png = encode_png_rgba(2, 2, pixels)
        scanlines = png_scanlines(png)
        self.assertEqual(scanlines, b'\0' + b'\x00\x00\xff\xff' * 2
                         + b'\0' + b'\xff\x00\x00\xff' * 2)

    def test_md5_dimensions_and_size_are_validated(self):
        pixels = b'\x01\x02\x03\x04' * 4
        valid = kdf_texture(2, 2, pixels)
        cases = [
            (valid[:-1] + bytes([valid[-1] ^ 1]), 'MD5 footer mismatch'),
            (kdf_texture(3, 2, pixels), 'payload'),
        ]
        for raw, message in cases:
            with self.subTest(message=message), self.assertRaisesRegex(TextureError, message):
                parse_texture(raw)

    def test_output_must_be_new_and_outside_checkout(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / 'sample.bin'
            pixels = b'\x10\x20\x30\x40'
            source.write_bytes(kdf_texture(1, 1, pixels))
            output = root / 'sample.png'
            with patch.object(tex_convert, '_PROJECT_ROOT', root / 'project'):
                result = convert_file(source, output)
                self.assertEqual(result['png_bytes'], output.stat().st_size)
                with self.assertRaises(FileExistsError):
                    convert_file(source, output)
                with self.assertRaisesRegex(TextureError, 'outside the project'):
                    convert_file(source, root / 'project' / 'inside.png')

    def test_cli_emits_json_report(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / 'sample.bin'
            output = root / 'output' / 'sample.png'
            output.parent.mkdir()
            source.write_bytes(kdf_texture(1, 1, b'\xaa\xbb\xcc\xdd'))
            checkout = root / 'checkout'
            script = checkout / 'tools' / 'tex_convert.py'
            script.parent.mkdir(parents=True)
            shutil.copy2(Path(__file__).resolve().parents[1] / 'tools' / 'tex_convert.py', script)
            run = subprocess.run(
                [sys.executable, '-X', 'utf8', str(script), str(source),
                 '--output', str(output)],
                capture_output=True, text=True, encoding='utf-8', check=False,
            )
            self.assertEqual(run.returncode, 0, run.stderr)
            report = json.loads(run.stdout)
            self.assertEqual((report['width'], report['height']), (1, 1))
            self.assertTrue(report['vertical_flip'])
            self.assertTrue(output.is_file())


if __name__ == '__main__':
    unittest.main()

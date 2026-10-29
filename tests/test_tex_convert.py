import hashlib
import json
import os
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


def level_dimensions(width: int, height: int, levels: int):
    return [
        (max(1, width >> level), max(1, height >> level))
        for level in range(levels)
    ]


def block_element_count(width: int, height: int, level: int) -> int:
    level_width, level_height = level_dimensions(width, height, level + 1)[level]
    return ((level_width + 3) // 4) * ((level_height + 3) // 4)


def mip_descriptor(
        width: int, height: int, level: int, texture_format: str,
) -> tuple[int, int]:
    if texture_format == 'atc_rgb':
        elements = block_element_count(width, height, level)
        stride = 8
    else:
        level_width, level_height = level_dimensions(width, height, level + 1)[level]
        elements = level_width * level_height
        stride = 4
    encoded_elements = elements if elements <= 0xffff else 0
    return (0x40000000 | (stride << 21) | encoded_elements, level)


def kdf_texture(
        width: int, height: int, groups: tuple[bytes, ...], *,
        texture_format: str = 'r8g8b8a8',
        include_mips: bool | None = None,
        mip_count_override: int | None = None,
        mip_profile_word: int = 1,
        record_mutator=None,
) -> bytes:
    strings = [
        texture_format if value == 'r8g8b8a8' else value
        for value in STRINGS
    ]
    if include_mips is None:
        include_mips = len(groups) > 1
    record_count = 25 + len(groups) if include_mips else 26
    records = [(0, 0)] * record_count
    format_ordinal = strings.index('format')
    format_value = strings.index(texture_format)
    records[11] = (0x60000000, format_ordinal)
    records[12] = (0x60000000, format_value)
    records[13] = (0x60000000, strings.index('sizex'))
    records[14] = (0, width)
    records[15] = (0x60000000, strings.index('sizey'))
    records[16] = (0, height)
    if include_mips:
        mip_count = len(groups) if mip_count_override is None else mip_count_override
        records[23] = (0x60000000, strings.index('mips'))
        records[24] = (0x40000000 | mip_count, mip_profile_word)
        for level in range(len(groups)):
            records[25 + level] = mip_descriptor(width, height, level, texture_format)
    if record_mutator is not None:
        record_mutator(records)

    raw = bytearray(
        b'1FDKENONCTX3'
        + struct.pack('<IIII', len(strings), 0, 0, len(strings))
    )
    for value in strings:
        encoded = value.encode('utf-8')
        identifier = (zlib.crc32(encoded) + len(encoded)) & 0xffffffff
        raw += struct.pack('<II', identifier, len(encoded)) + encoded + b'\0'
    raw += b'\0' * (-len(raw) % 4)
    payload = b''.join(groups)
    raw += b'DATA'
    raw += struct.pack('<IIII', record_count, len(groups), 0, len(payload))
    offsets = [0, 0]
    for group in groups[:-1]:
        offsets.append(offsets[-1] + len(group))
    raw += struct.pack(f'<{len(offsets)}I', *offsets)
    for record in records:
        raw += struct.pack('<II', *record)
    raw += payload
    raw += hashlib.md5(raw).digest()
    return bytes(raw)


def direct_mip_groups(width: int, height: int, levels: int) -> tuple[bytes, ...]:
    groups = []
    for level, (level_width, level_height) in enumerate(
            level_dimensions(width, height, levels)):
        byte = bytes((level * 53 + channel) & 0xff for channel in range(4))
        groups.append(byte * (level_width * level_height))
    return tuple(groups)


def atc_rgb_block(color0: int, color1: int, indexes: tuple[int, ...]) -> bytes:
    if len(indexes) != 16 or any(not 0 <= value <= 3 for value in indexes):
        raise ValueError('ATC test block requires sixteen 2-bit indexes')
    lookup = sum(value << (pixel * 2) for pixel, value in enumerate(indexes))
    return struct.pack('<HHI', color0, color1, lookup)


def atc_mip_groups(width: int, height: int, levels: int) -> tuple[bytes, ...]:
    block = atc_rgb_block(
        (4 << 10) | (8 << 5) | 16,
        0xffff,
        (0, 1, 2, 3) * 4,
    )
    return tuple(
        block * block_element_count(width, height, level)
        for level in range(levels)
    )


def rgba_values(pixels: bytes):
    return [
        tuple(pixels[offset:offset + 4])
        for offset in range(0, len(pixels), 4)
    ]


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
    def test_parse_legacy_single_level_metadata_and_md5(self):
        width, height = 2, 2
        pixels = bytes(range(width * height * 4))
        raw = kdf_texture(width, height, (pixels,))
        result = parse_texture(raw)
        self.assertEqual((result['width'], result['height']), (width, height))
        self.assertEqual(result['pixels'], pixels)
        self.assertEqual(result['sha256'], hashlib.sha256(raw).hexdigest())
        self.assertEqual(result['string_count'], len(STRINGS))
        self.assertEqual(result['data_record_count'], 26)
        self.assertEqual(result['data_offset_count'], 1)
        self.assertEqual(result['data_header_bytes'], 236)
        self.assertEqual(result['mip_count'], 1)

    def test_full_size_rgba_mip_chain_extracts_first_level(self):
        width = height = 1024
        groups = direct_mip_groups(width, height, 11)
        result = parse_texture(kdf_texture(width, height, groups))
        self.assertEqual(
            [level['bytes'] for level in result['mip_levels']],
            [4194304, 1048576, 262144, 65536, 16384, 4096, 1024, 256, 64, 16, 4],
        )
        self.assertEqual(result['payload_bytes'], 5592404)
        self.assertEqual(result['mip_count'], 11)
        self.assertEqual(result['base_level_bytes'], 4194304)
        self.assertEqual(len(result['pixels']), 4194304)
        self.assertEqual(result['pixels'], groups[0])

    def test_full_size_atc_rgb_mip_chain_decodes_base_level(self):
        width = height = 1024
        groups = atc_mip_groups(width, height, 11)
        result = parse_texture(kdf_texture(
            width, height, groups, texture_format='atc_rgb'))
        self.assertEqual(
            [level['bytes'] for level in result['mip_levels']],
            [524288, 131072, 32768, 8192, 2048, 512, 128, 32, 8, 8, 8],
        )
        self.assertEqual(result['payload_bytes'], 699064)
        self.assertEqual(result['pixel_format'], 'atc_rgb')
        self.assertEqual(result['pixel_decoding'], 'block_decoded')
        self.assertEqual(result['base_level_bytes'], 524288)
        self.assertEqual(len(result['pixels']), 4194304)
        self.assertEqual(rgba_values(result['pixels'][:16]), [
            (33, 66, 132, 255),
            (116, 136, 178, 255),
            (171, 184, 208, 255),
            (255, 255, 255, 255),
        ])

    def test_mips_metadata_count_profile_and_descriptors_are_validated(self):
        width = height = 8
        groups = direct_mip_groups(width, height, 4)
        valid = kdf_texture(width, height, groups)
        cases = [
            (
                kdf_texture(width, height, groups, mip_count_override=3),
                'declares 3 levels',
            ),
            (
                kdf_texture(width, height, groups, mip_profile_word=2),
                'profile word',
            ),
            (
                kdf_texture(
                    width, height, groups,
                    record_mutator=lambda records: records.__setitem__(
                        26, (records[26][0], 2)),
                ),
                'array descriptor',
            ),
            (
                kdf_texture(
                    width, height, groups,
                    record_mutator=lambda records: records.__setitem__(
                        25, (0x41000040, 0)),
                ),
                'array descriptor',
            ),
        ]
        for raw, message in cases:
            with self.subTest(message=message), self.assertRaisesRegex(
                    TextureError, message):
                parse_texture(raw)
        self.assertEqual(parse_texture(valid)['mip_count'], 4)

    def test_each_mip_level_size_is_validated(self):
        width = height = 8
        groups = list(direct_mip_groups(width, height, 4))
        groups[-1] += b'\0'
        with self.assertRaisesRegex(TextureError, 'mip level 3'):
            parse_texture(kdf_texture(width, height, tuple(groups)))

    def test_atc_rgb_palette_indexes_and_mode_bit(self):
        normal = atc_rgb_block(
            (4 << 10) | (8 << 5) | 16,
            0xffff,
            (0, 1, 2, 3) * 4,
        )
        decoded = parse_texture(kdf_texture(
            4, 4, (normal,), texture_format='atc_rgb'))
        self.assertEqual(rgba_values(decoded['pixels'])[0:4], [
            (33, 66, 132, 255),
            (116, 136, 178, 255),
            (171, 184, 208, 255),
            (255, 255, 255, 255),
        ])

        endpoint0 = (31 << 10) | (31 << 5) | 31
        endpoint1 = (16 << 11) | (32 << 5) | 16
        mode_block = atc_rgb_block(
            0x8000 | endpoint0,
            endpoint1,
            (0, 1, 2, 3) * 4,
        )
        decoded = parse_texture(kdf_texture(
            4, 4, (mode_block,), texture_format='atc_rgb'))
        self.assertEqual(rgba_values(decoded['pixels'])[0:4], [
            (0, 0, 0, 255),
            (222, 223, 222, 255),
            (255, 255, 255, 255),
            (132, 130, 132, 255),
        ])

    def test_atc_rgb_partial_edge_block_is_clipped(self):
        block = atc_rgb_block(
            (4 << 10) | (8 << 5) | 16,
            0xffff,
            (0, 1, 2, 3) * 4,
        )
        decoded = parse_texture(kdf_texture(
            2, 2, (block,), texture_format='atc_rgb'))
        self.assertEqual(rgba_values(decoded['pixels']), [
            (33, 66, 132, 255),
            (116, 136, 178, 255),
            (33, 66, 132, 255),
            (116, 136, 178, 255),
        ])

    def test_atc_rgb_requires_one_complete_base_block(self):
        valid = atc_rgb_block(0x7fff, 0xffff, (0,) * 16)
        for encoded in (valid[:-1], valid + b'\0'):
            with self.subTest(length=len(encoded)), self.assertRaisesRegex(
                    TextureError, 'mip level 0'):
                parse_texture(kdf_texture(
                    2, 2, (encoded,), texture_format='atc_rgb'))

    def test_md5_dimensions_and_payload_bounds_are_validated(self):
        pixels = b'\x01\x02\x03\x04' * 4
        valid = kdf_texture(2, 2, (pixels,))
        cases = [
            (valid[:-1] + bytes([valid[-1] ^ 1]), 'MD5 footer mismatch'),
            (kdf_texture(0, 2, (pixels,)), 'dimensions'),
            (kdf_texture(3, 2, (pixels,)), 'mip level 0'),
        ]
        for raw, message in cases:
            with self.subTest(message=message), self.assertRaisesRegex(
                    TextureError, message):
                parse_texture(raw)

    def test_png_rows_are_flipped(self):
        pixels = (
            b'\xff\x00\x00\xff' * 2
            + b'\x00\x00\xff\xff' * 2
        )
        png = encode_png_rgba(2, 2, pixels)
        scanlines = png_scanlines(png)
        self.assertEqual(scanlines, b'\0' + b'\x00\x00\xff\xff' * 2
                         + b'\0' + b'\xff\x00\x00\xff' * 2)

    def test_output_is_new_outside_checkout_and_atomic(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / 'sample.bin'
            source.write_bytes(kdf_texture(1, 1, (b'\x10\x20\x30\x40',)))
            output = root / 'sample.png'
            with patch.object(tex_convert, '_PROJECT_ROOT', root / 'project'):
                result = convert_file(source, output)
                self.assertEqual(result['png_bytes'], output.stat().st_size)
                with self.assertRaises(FileExistsError):
                    convert_file(source, output)
                with self.assertRaisesRegex(TextureError, 'outside the project'):
                    convert_file(source, root / 'project' / 'inside.png')

                failed = root / 'failed.png'
                with patch.object(tex_convert.os, 'fsync', side_effect=OSError('disk full')):
                    with self.assertRaisesRegex(OSError, 'disk full'):
                        convert_file(source, failed)
                self.assertFalse(failed.exists())
                self.assertEqual(list(root.glob('.failed.png.*.tmp')), [])

                operation = 'rename' if os.name == 'nt' else 'link'
                real_publish = getattr(os, operation)
                concurrent = root / 'concurrent.png'
                concurrent_data = b'created by another process'

                def create_competing_target(src, dst):
                    Path(dst).write_bytes(concurrent_data)
                    real_publish(src, dst)

                with patch.object(tex_convert.os, operation, side_effect=create_competing_target):
                    with self.assertRaises(FileExistsError):
                        convert_file(source, concurrent)
                self.assertEqual(concurrent.read_bytes(), concurrent_data)
                self.assertEqual(list(root.glob('.concurrent.png.*.tmp')), [])

                if os.name == 'nt':
                    hardlink_free = root / 'hardlink-free.png'
                    with patch.object(
                            tex_convert.os, 'link', side_effect=OSError('link unsupported')) as link:
                        convert_file(source, hardlink_free)
                    link.assert_not_called()
                    self.assertTrue(hardlink_free.is_file())
                    self.assertEqual(list(root.glob('.hardlink-free.png.*.tmp')), [])

    def test_cli_emits_json_report_for_mip_packed_rgba(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / 'sample.bin'
            output = root / 'output' / 'sample.png'
            output.parent.mkdir()
            source.write_bytes(kdf_texture(
                2, 2, direct_mip_groups(2, 2, 2)))
            checkout = root / 'checkout'
            script = checkout / 'tools' / 'tex_convert.py'
            script.parent.mkdir(parents=True)
            shutil.copy2(
                Path(__file__).resolve().parents[1] / 'tools' / 'tex_convert.py',
                script,
            )
            shutil.copy2(
                Path(__file__).resolve().parents[1] / 'tools' / 'kdf_data.py',
                script.parent / 'kdf_data.py',
            )
            run = subprocess.run(
                [sys.executable, '-X', 'utf8', str(script), str(source),
                 '--output', str(output)],
                capture_output=True, text=True, encoding='utf-8', check=False,
            )
            self.assertEqual(run.returncode, 0, run.stderr)
            report = json.loads(run.stdout)
            self.assertEqual((report['width'], report['height']), (2, 2))
            self.assertEqual(report['mip_count'], 2)
            self.assertTrue(report['vertical_flip'])
            self.assertTrue(output.is_file())


if __name__ == '__main__':
    unittest.main()

#!/usr/bin/env python3
"""Convert supported decoded Bruce Lee .tex CTX3 files to local RGBA PNGs.

The supported profile expands observed r8g8b8 and r8g8b8a8 payloads, and
extracts the base level from standard ATC RGB mip-packed payloads. Input
archives and binary resources remain read-only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_data import KdfError as KdfContainerError, parse_container

_MAX_RESOURCE_BYTES = 16 * 1024 * 1024
_PROJECT_ROOT = Path(__file__).resolve().parents[1]
_PIXEL_FORMATS = {
    # Both observed r8g8b8 files store 0x00640000 in the descriptor's upper
    # bits. The business meaning of the decoded value 50 is not yet known, so
    # validate the complete observed marker instead of presenting it as stride.
    'r8g8b8': {'kind': 'direct', 'stride': 3, 'descriptor_marker': 0x00640000},
    'r8g8b8a8': {'kind': 'direct', 'stride': 4},
    'atc_rgb': {'kind': 'atc_rgb', 'stride': 8},
}


class TextureError(ValueError):
    """Resource does not match the observed texture format profile."""


def _property_u32(raw: bytes, record_start: int, record_count: int, ordinal: int) -> int:
    """Read a string-keyed value encoded in the low 24 bits of record words."""
    for index in range(record_count - 1):
        key_record = struct.unpack_from('<II', raw, record_start + index * 8)
        value_record = struct.unpack_from('<II', raw, record_start + (index + 1) * 8)
        if key_record == (0x60000000, ordinal) and value_record[0] == 0:
            return value_record[1] & 0xffffff
    raise TextureError(f'texture metadata property {ordinal} was not found')


def _property_matches(container: dict, strings: list[str], name: str) -> list[int]:
    if strings.count(name) != 1:
        raise TextureError(f'texture metadata key {name!r} is missing or ambiguous')
    ordinal = strings.index(name)
    return [
        index for index, record in enumerate(container['records'][:-1])
        if record['first'] == 0x60000000 and record['second'] == ordinal
    ]


def _property_record(container: dict, strings: list[str], name: str) -> tuple[int, dict]:
    """Return the unique value record paired with a string-table key."""
    matches = _property_matches(container, strings, name)
    if len(matches) != 1:
        raise TextureError(f'texture metadata property {name!r} is missing or repeated')
    value_index = matches[0] + 1
    return value_index, container['records'][value_index]


def _declared_format(container: dict, strings: list[str]) -> str:
    """Resolve the format key to its string-table value."""
    value_index, value = _property_record(container, strings, 'format')
    if value['first'] != 0x60000000 or value['second'] >= len(strings):
        raise TextureError('texture format declaration is malformed')
    return strings[value['second']]


def _mip_dimensions(width: int, height: int, level: int) -> tuple[int, int]:
    return max(1, width >> level), max(1, height >> level)


def _mip_elements(width: int, height: int, level: int, pixel_format: str) -> int:
    level_width, level_height = _mip_dimensions(width, height, level)
    if pixel_format == 'atc_rgb':
        return ((level_width + 3) // 4) * ((level_height + 3) // 4)
    return level_width * level_height


def _validate_mip_layout(
        container: dict, strings: list[str], width: int, height: int,
        pixel_format: str,
) -> dict:
    """Validate the observed mips key and its ordered section descriptors."""
    sections = container['sections']
    group_count = container['offset_count']
    expected_levels = max(width, height).bit_length()
    spec = _PIXEL_FORMATS[pixel_format]

    mip_matches = _property_matches(container, strings, 'mips')
    if not mip_matches:
        if group_count != 1:
            raise TextureError('multi-section texture is missing mips metadata')
        mip_count = 1
        descriptor_records = None
    else:
        if len(mip_matches) != 1:
            raise TextureError("texture metadata property 'mips' is missing or repeated")
        value_index, mips_value = _property_record(container, strings, 'mips')
        descriptor = mips_value['first']
        if descriptor >> 28 != 4:
            raise TextureError('texture mips metadata is not an array descriptor')
        mip_count = descriptor & 0xffff
        if not 1 <= mip_count <= expected_levels:
            raise TextureError('texture mips metadata level count is out of bounds')
        if mips_value['second'] != 1:
            raise TextureError('texture mips metadata profile word is unsupported')
        if pixel_format == 'r8g8b8':
            # The two observed r8g8b8 backgrounds declare a one-element mips
            # array even though only the 512x512 base section is stored.
            if mip_count != 1:
                raise TextureError(
                    'observed r8g8b8 profile requires exactly one mip descriptor'
                )
        elif mip_count != expected_levels:
            raise TextureError(
                f'texture mips metadata declares {mip_count} levels; '
                f'{width}x{height} requires {expected_levels}'
            )
        if group_count != mip_count:
            raise TextureError(
                f'texture DATA declares {group_count} sections; '
                f'mips metadata declares {mip_count}'
            )
        end = value_index + 1 + mip_count
        if end > len(container['records']):
            raise TextureError('texture mips descriptor array is truncated')
        descriptor_records = container['records'][value_index + 1:end]

    if group_count != mip_count:
        raise TextureError(
            f'texture DATA declares {group_count} sections; expected {mip_count}'
        )

    levels = []
    total_bytes = 0
    for level in range(mip_count):
        level_width, level_height = _mip_dimensions(width, height, level)
        elements = _mip_elements(width, height, level, pixel_format)
        expected_bytes = elements * spec['stride']
        actual_bytes = sections[level]['bytes']
        if actual_bytes != expected_bytes:
            raise TextureError(
                f'texture mip level {level} is {actual_bytes} bytes; '
                f'expected {expected_bytes} for {level_width}x{level_height} {pixel_format}'
            )
        if descriptor_records is not None:
            record = descriptor_records[level]
            descriptor = record['first']
            if descriptor >> 28 != 4:
                raise TextureError(f'texture mip descriptor {level} has an invalid tag')
            descriptor_upper = descriptor & 0x0fff0000
            if 'descriptor_marker' in spec:
                if descriptor_upper != spec['descriptor_marker']:
                    raise TextureError(
                        f'texture mip descriptor {level} marker is '
                        f'0x{descriptor_upper:08x}; expected '
                        f'0x{spec["descriptor_marker"]:08x}'
                    )
            else:
                stride = descriptor_upper >> 21
                if stride != spec['stride']:
                    raise TextureError(
                        f'texture mip descriptor {level} stride is {stride}; '
                        f'expected {spec["stride"]}'
                    )
            encoded_elements = descriptor & 0xffff
            if elements <= 0xffff:
                elements_valid = encoded_elements == elements
            else:
                # Both observed 65536- and 1048576-element base arrays store
                # zero in the descriptor's low 16-bit element-count field.
                elements_valid = encoded_elements == 0
            if not elements_valid:
                raise TextureError(
                    f'texture mip descriptor {level} element count '
                    f'{encoded_elements} does not match {elements}'
                )
            if record['second'] != level:
                raise TextureError(
                    f'texture mip descriptor {level} references section '
                    f'{record["second"]}'
                )
        total_bytes += actual_bytes
        levels.append({
            'level': level,
            'width': level_width,
            'height': level_height,
            'elements': elements,
            'bytes': actual_bytes,
        })

    if total_bytes != container['payload_bytes']:
        raise TextureError('texture mip level sizes do not match the payload')
    return {
        'mip_count': mip_count,
        'mip_levels': levels,
        'base_level_bytes': levels[0]['bytes'],
    }


def _expand_5(value: int) -> int:
    expanded = value << 3
    return expanded | (value >> 2)


def _expand_6(value: int) -> int:
    expanded = value << 2
    return expanded | (value >> 4)


def _atc_rgb_palette(block: bytes) -> tuple[tuple[int, int, int], ...]:
    """Return standard ATC RGB's four colors for one 8-byte block."""
    if len(block) != 8:
        raise TextureError('ATC RGB block must be exactly 8 bytes')
    color0, color1 = struct.unpack_from('<HH', block)
    endpoint0 = (
        _expand_5((color0 >> 10) & 0x1f),
        _expand_5((color0 >> 5) & 0x1f),
        _expand_5(color0 & 0x1f),
    )
    endpoint1 = (
        _expand_5((color1 >> 11) & 0x1f),
        _expand_6((color1 >> 5) & 0x3f),
        _expand_5(color1 & 0x1f),
    )
    if color0 & 0x8000:
        return (
            (0, 0, 0),
            tuple(max(0, endpoint0[index] - endpoint1[index] // 4)
                  for index in range(3)),
            endpoint0,
            endpoint1,
        )
    return (
        endpoint0,
        tuple((5 * endpoint0[index] + 3 * endpoint1[index]) // 8
              for index in range(3)),
        tuple((3 * endpoint0[index] + 5 * endpoint1[index]) // 8
              for index in range(3)),
        endpoint1,
    )


def _decode_atc_rgb(encoded: bytes, width: int, height: int) -> bytes:
    """Decode a standard ATC RGB base level and clip partial edge blocks."""
    blocks_wide = (width + 3) // 4
    blocks_high = (height + 3) // 4
    expected_bytes = blocks_wide * blocks_high * 8
    if len(encoded) != expected_bytes:
        raise TextureError(
            f'ATC RGB base-level payload is {len(encoded)} bytes; '
            f'expected {expected_bytes} for {width}x{height}'
        )
    pixels = bytearray(width * height * 4)
    source = 0
    for block_y in range(blocks_high):
        for block_x in range(blocks_wide):
            palette = _atc_rgb_palette(encoded[source:source + 8])
            color_indexes = int.from_bytes(encoded[source + 4:source + 8], 'little')
            source += 8
            for local_y in range(4):
                target_y = block_y * 4 + local_y
                if target_y >= height:
                    break
                for local_x in range(4):
                    target_x = block_x * 4 + local_x
                    if target_x >= width:
                        break
                    pixel_index = local_y * 4 + local_x
                    target = (target_y * width + target_x) * 4
                    red, green, blue = palette[(color_indexes >> (pixel_index * 2)) & 3]
                    pixels[target:target + 4] = bytes((red, green, blue, 255))
    return bytes(pixels)


def _expand_rgb_to_rgba(encoded: bytes) -> bytes:
    """Expand tightly packed RGB pixels to opaque RGBA."""
    if len(encoded) % 3:
        raise TextureError('r8g8b8 payload length is not divisible by three')
    pixels = bytearray((len(encoded) // 3) * 4)
    target = 0
    for source in range(0, len(encoded), 3):
        pixels[target:target + 3] = encoded[source:source + 3]
        pixels[target + 3] = 255
        target += 4
    return bytes(pixels)


def parse_texture(raw: bytes) -> dict:
    """Return validated metadata, decoded RGBA pixels, and observed row order."""
    if len(raw) > _MAX_RESOURCE_BYTES:
        raise TextureError('decoded texture exceeds inspection size limit')
    try:
        container = parse_container(raw)
    except KdfContainerError as exc:
        raise TextureError(str(exc)) from exc
    strings = [entry['text'] for entry in container['strings']]
    required = {'format', 'type', 'sizex', 'sizey'}
    if not required <= set(strings):
        raise TextureError('texture metadata strings are missing')
    if 'texture2d' not in strings:
        raise TextureError('unsupported texture type')
    pixel_format = _declared_format(container, strings)
    if pixel_format not in _PIXEL_FORMATS:
        raise TextureError(f'unsupported texture format {pixel_format!r}')

    data_offset = container['data_offset']
    record_count = container['record_count']
    offset_count = container['offset_count']
    payload_size = container['payload_bytes']
    record_start = data_offset + 20 + (offset_count + 1) * 4
    header_size = container['header_bytes']
    width = _property_u32(raw, record_start, record_count, strings.index('sizex'))
    height = _property_u32(raw, record_start, record_count, strings.index('sizey'))
    if not (0 < width <= 4096 and 0 < height <= 4096):
        raise TextureError('texture dimensions are out of bounds')
    mip_layout = _validate_mip_layout(
        container, strings, width, height, pixel_format)

    payload_offset = container['payload_offset']
    payload_end = payload_offset + payload_size
    footer = raw[payload_end:]
    if len(footer) != 16 or hashlib.md5(raw[:payload_end]).digest() != footer:
        raise TextureError('texture MD5 footer mismatch')

    base_payload_end = payload_offset + mip_layout['base_level_bytes']
    base_payload = raw[payload_offset:base_payload_end]
    if pixel_format == 'atc_rgb':
        pixels = _decode_atc_rgb(base_payload, width, height)
        pixel_decoding = 'block_decoded'
    elif pixel_format == 'r8g8b8':
        pixels = _expand_rgb_to_rgba(base_payload)
        pixel_decoding = 'rgb_expanded'
    else:
        pixels = base_payload
        pixel_decoding = 'direct'
    return {
        'sha256': hashlib.sha256(raw).hexdigest(),
        'decoded_bytes': len(raw),
        'string_count': len(strings),
        'data_offset': data_offset,
        'data_record_count': record_count,
        'data_offset_count': offset_count,
        'data_header_bytes': header_size,
        'payload_offset': payload_offset,
        'payload_bytes': payload_size,
        'width': width,
        'height': height,
        'pixel_format': pixel_format,
        'output_pixel_format': 'r8g8b8a8',
        'pixel_decoding': pixel_decoding,
        **mip_layout,
        'orientation': 'top_down' if pixel_format == 'r8g8b8' else 'bottom_up',
        'pixels': pixels,
    }


def _png_chunk(tag: bytes, data: bytes) -> bytes:
    return (struct.pack('>I', len(data)) + tag + data
            + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))


def encode_png_rgba(width: int, height: int, pixels: bytes, *, flip_vertical: bool = True) -> bytes:
    if len(pixels) != width * height * 4:
        raise TextureError('RGBA pixel byte length does not match dimensions')
    rows = [pixels[row * width * 4:(row + 1) * width * 4] for row in range(height)]
    if flip_vertical:
        rows.reverse()
    scanlines = b''.join(b'\0' + row for row in rows)
    return b''.join((
        b'\x89PNG\r\n\x1a\n',
        _png_chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)),
        _png_chunk(b'IDAT', zlib.compress(scanlines, 9)),
        _png_chunk(b'IEND', b''),
    ))


def _safe_output_path(path: Path) -> Path:
    target = path.expanduser().resolve()
    project = _PROJECT_ROOT.resolve()
    if target == project or target.is_relative_to(project):
        raise TextureError('PNG output must be outside the project checkout')
    sync_names = {'baidusyncdisk', 'onedrive', 'dropbox', 'google drive', 'icloud drive'}
    for part in target.parts:
        name = part.casefold()
        if name in sync_names or name.startswith('onedrive - '):
            raise TextureError('PNG output is inside a known sync folder')
    for name in ('OneDrive', 'OneDriveConsumer', 'OneDriveCommercial',
                 'DROPBOX_PATH', 'GOOGLE_DRIVE_PATH', 'BAIDU_SYNC_ROOT'):
        value = os.environ.get(name)
        if value:
            root = Path(value).expanduser().resolve()
            if target == root or target.is_relative_to(root):
                raise TextureError('PNG output is inside a configured sync folder')
    if not target.parent.is_dir():
        raise TextureError('PNG output parent is not an existing directory')
    return target


def _write_atomic_exclusive(target: Path, data: bytes) -> None:
    """Publish a complete file without replacing a concurrent destination."""
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f'.{target.name}.', suffix='.tmp', dir=target.parent)
    temporary = Path(temporary_name)
    try:
        try:
            file = os.fdopen(descriptor, 'wb')
        except BaseException:
            os.close(descriptor)
            raise
        with file:
            if file.write(data) != len(data):
                raise OSError('incomplete PNG write')
            file.flush()
            os.fsync(file.fileno())
        # Windows rename fails when the target exists, including on filesystems
        # without hard links. POSIX rename may overwrite, so use link instead.
        if os.name == 'nt':
            os.rename(temporary, target)
        else:
            os.link(temporary, target)
    finally:
        temporary.unlink(missing_ok=True)


def convert_file(
        source: Path,
        destination: Path,
        *,
        flip_vertical: bool | None = None,
) -> dict:
    with source.open('rb') as file:
        raw = file.read(_MAX_RESOURCE_BYTES + 1)
    if len(raw) > _MAX_RESOURCE_BYTES:
        raise TextureError('decoded texture exceeds inspection size limit')
    texture = parse_texture(raw)
    if flip_vertical is None:
        flip_vertical = texture['orientation'] == 'bottom_up'
    png = encode_png_rgba(texture['width'], texture['height'], texture['pixels'],
                          flip_vertical=flip_vertical)
    target = _safe_output_path(destination)
    _write_atomic_exclusive(target, png)
    return {
        key: value for key, value in texture.items() if key != 'pixels'
    } | {
        'source': str(source),
        'output': str(target),
        'png_bytes': len(png),
        'png_sha256': hashlib.sha256(png).hexdigest(),
        'vertical_flip': flip_vertical,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='decoded 1FDKENONCTX3 .tex stream')
    parser.add_argument('--output', type=Path, required=True,
                        help='new PNG outside the checkout and sync directories')
    parser.add_argument('--no-flip', action='store_true',
                        help='preserve the stored row order')
    args = parser.parse_args()
    try:
        result = convert_file(
            args.source,
            args.output,
            flip_vertical=False if args.no_flip else None,
        )
    except (OSError, TextureError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

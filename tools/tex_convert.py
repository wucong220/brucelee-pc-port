#!/usr/bin/env python3
"""Convert supported decoded Bruce Lee .tex CTX3 files to local RGBA PNGs.

The current format profile is based on three observed v1.15.26 samples. It only
supports a single bottom-up r8g8b8a8 texture level and validates its MD5 footer.
Input archives and binary resources remain read-only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_data import KdfError as KdfContainerError, parse_container

_MAX_RESOURCE_BYTES = 16 * 1024 * 1024
_PROJECT_ROOT = Path(__file__).resolve().parents[1]


class TextureError(ValueError):
    """Resource does not match the observed texture format profile."""


def _property_u32(raw: bytes, record_start: int, record_count: int, ordinal: int) -> int:
    """Read a key/value pair encoded as two consecutive 8-byte records."""
    for index in range(record_count - 1):
        key, reserved = struct.unpack_from('<II', raw, record_start + index * 8)
        if key == ordinal and reserved == 0:
            value, value_type = struct.unpack_from('<II', raw, record_start + (index + 1) * 8)
            if value_type == 0x60000000:
                return value
    raise TextureError(f'texture metadata property {ordinal} was not found')


def parse_texture(raw: bytes) -> dict:
    """Return validated metadata and the bottom-up RGBA base-level pixels."""
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
    if 'r8g8b8a8' not in strings or 'texture2d' not in strings:
        raise TextureError('unsupported texture format or type')

    data_offset = container['data_offset']
    record_count = container['record_count']
    index_count = container['index_count']
    payload_size = container['payload_bytes']
    record_start = data_offset + 20 + index_count * 4
    header_size = container['header_bytes']
    width = _property_u32(raw, record_start, record_count, strings.index('sizex'))
    height = _property_u32(raw, record_start, record_count, strings.index('sizey'))
    if not (0 < width <= 4096 and 0 < height <= 4096):
        raise TextureError('texture dimensions are out of bounds')
    expected_bytes = width * height * 4
    if payload_size != expected_bytes:
        raise TextureError(
            f'unsupported texture payload: {payload_size} bytes for {width}x{height}; '
            'this converter currently accepts one uncompressed RGBA level'
        )

    payload_offset = container['payload_offset']
    payload_end = payload_offset + payload_size
    footer = raw[payload_end:]
    if len(footer) != 16 or hashlib.md5(raw[:payload_end]).digest() != footer:
        raise TextureError('texture MD5 footer mismatch')
    return {
        'sha256': hashlib.sha256(raw).hexdigest(),
        'decoded_bytes': len(raw),
        'string_count': len(strings),
        'data_offset': data_offset,
        'data_record_count': record_count,
        'data_index_count': index_count,
        'data_header_bytes': header_size,
        'payload_offset': payload_offset,
        'payload_bytes': payload_size,
        'width': width,
        'height': height,
        'pixel_format': 'r8g8b8a8',
        'orientation': 'bottom_up',
        'pixels': raw[payload_offset:payload_end],
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


def convert_file(source: Path, destination: Path, *, flip_vertical: bool = True) -> dict:
    with source.open('rb') as file:
        raw = file.read(_MAX_RESOURCE_BYTES + 1)
    if len(raw) > _MAX_RESOURCE_BYTES:
        raise TextureError('decoded texture exceeds inspection size limit')
    texture = parse_texture(raw)
    png = encode_png_rgba(texture['width'], texture['height'], texture['pixels'],
                          flip_vertical=flip_vertical)
    target = _safe_output_path(destination)
    with target.open('xb') as file:
        file.write(png)
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
        result = convert_file(args.source, args.output, flip_vertical=not args.no_flip)
    except (OSError, TextureError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

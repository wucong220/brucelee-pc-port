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

_SIGNATURE = b'1FDKENONCTX3'
_DATA_SIGNATURE = b'DATA'
_DATA_HEADER_BYTES = 236
_MAX_RESOURCE_BYTES = 16 * 1024 * 1024
_MAX_STRINGS = 20_000
_MAX_STRING_BYTES = 1024 * 1024
_PROJECT_ROOT = Path(__file__).resolve().parents[1]


class TextureError(ValueError):
    """Resource does not match the observed texture format profile."""


def _read_strings(raw: bytes) -> tuple[list[str], int]:
    if len(raw) < 0x1c or not raw.startswith(_SIGNATURE):
        raise TextureError('unsupported CTX3 signature')
    count = struct.unpack_from('<I', raw, 0x18)[0]
    if count > _MAX_STRINGS:
        raise TextureError('CTX3 string count exceeds limit')
    position = 0x1c
    strings = []
    for ordinal in range(count):
        if position + 8 > len(raw):
            raise TextureError(f'truncated CTX3 string record {ordinal}')
        identifier, length = struct.unpack_from('<II', raw, position)
        position += 8
        if length > _MAX_STRING_BYTES or position + length >= len(raw):
            raise TextureError(f'invalid CTX3 string length at record {ordinal}')
        value = raw[position:position + length]
        position += length
        if raw[position] != 0:
            raise TextureError(f'missing CTX3 string terminator at record {ordinal}')
        position += 1
        expected = (zlib.crc32(value) + length) & 0xffffffff
        if identifier != expected:
            raise TextureError(f'CTX3 string identifier mismatch at record {ordinal}')
        try:
            strings.append(value.decode('utf-8'))
        except UnicodeDecodeError as exc:
            raise TextureError(f'CTX3 string {ordinal} is not UTF-8') from exc
    return strings, position


def _find_data_section(raw: bytes, search_from: int) -> int:
    position = search_from
    for _ in range(32):
        position = raw.find(_DATA_SIGNATURE, position)
        if position < 0:
            break
        if position + _DATA_HEADER_BYTES + 16 <= len(raw):
            payload_size = struct.unpack_from('<I', raw, position + 0x10)[0]
            payload_end = position + _DATA_HEADER_BYTES + payload_size
            if 0 < payload_size <= _MAX_RESOURCE_BYTES and payload_end + 16 == len(raw):
                return position
        position += 1
    raise TextureError('could not locate a bounded texture DATA section')


def parse_texture(raw: bytes) -> dict:
    """Return validated metadata and the bottom-up RGBA base-level pixels."""
    if len(raw) > _MAX_RESOURCE_BYTES:
        raise TextureError('decoded texture exceeds inspection size limit')
    strings, table_end = _read_strings(raw)
    required = {'format', 'type', 'sizex', 'sizey'}
    if not required <= set(strings):
        raise TextureError('texture metadata strings are missing')
    if 'r8g8b8a8' not in strings or 'texture2d' not in strings:
        raise TextureError('unsupported texture format or type')

    data_offset = _find_data_section(raw, table_end)
    payload_size = struct.unpack_from('<I', raw, data_offset + 0x10)[0]
    # These observed offsets are metadata values associated with sizex/sizey
    # in the 26-entry DATA descriptor used by the inspected v1.15.26 samples.
    width = struct.unpack_from('<I', raw, data_offset + 0x90)[0]
    height = struct.unpack_from('<I', raw, data_offset + 0xA0)[0]
    if not (0 < width <= 4096 and 0 < height <= 4096):
        raise TextureError('texture dimensions are out of bounds')
    expected_bytes = width * height * 4
    if payload_size != expected_bytes:
        raise TextureError(
            f'unsupported texture payload: {payload_size} bytes for {width}x{height}; '
            'this converter currently accepts one uncompressed RGBA level'
        )

    payload_offset = data_offset + _DATA_HEADER_BYTES
    payload_end = payload_offset + payload_size
    footer = raw[payload_end:]
    if len(footer) != 16 or hashlib.md5(raw[:payload_end]).digest() != footer:
        raise TextureError('texture MD5 footer mismatch')
    return {
        'sha256': hashlib.sha256(raw).hexdigest(),
        'decoded_bytes': len(raw),
        'string_count': len(strings),
        'data_offset': data_offset,
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

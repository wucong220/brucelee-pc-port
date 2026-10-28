#!/usr/bin/env python3
"""Inspect verified scalar animation headers and binary section ranges."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_data import KdfError, parse_container, scalar_property

_MAX_RESOURCE_BYTES = 16 * 1024 * 1024
_HEADER_KEYS = ('firstframe', 'duration', 'framerate', 'version', 'pose')
_CODEC_KEYS = (
    'rawfloatsample', 'rawfixedsample', 'waveletsample',
    'quantizedbits', 'quantizedradix', 'huffsize', 'huffcode',
    'compresschannels',
)


def inspect_animation(raw: bytes) -> dict:
    container = parse_container(raw)
    names = {entry['text'] for entry in container['strings']}
    missing = [key for key in _HEADER_KEYS if key not in names]
    if missing:
        raise KdfError(f'animation header keys missing: {", ".join(missing)}')
    headers = {key: scalar_property(container, key) for key in _HEADER_KEYS}
    return {
        'sha256': container['sha256'],
        'decoded_bytes': container['decoded_bytes'],
        'data_offset': container['data_offset'],
        'record_count': container['record_count'],
        'offset_count': container['offset_count'],
        'payload_bytes': container['payload_bytes'],
        'headers': headers,
        'sections': container['sections'],
        'codec_keys_present': [key for key in _CODEC_KEYS if key in names],
        'tail_identity_hex': container['tail_identity_hex'],
    }


def inspect_file(path: Path) -> dict:
    with path.open('rb') as file:
        raw = file.read(_MAX_RESOURCE_BYTES + 1)
    if len(raw) > _MAX_RESOURCE_BYTES:
        raise KdfError('decoded animation exceeds inspection size limit')
    result = inspect_animation(raw)
    result['source'] = str(path)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='decoded 1FDKENONCTX3 animation resource')
    args = parser.parse_args()
    try:
        result = inspect_file(args.source)
    except (OSError, KdfError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

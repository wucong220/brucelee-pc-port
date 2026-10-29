#!/usr/bin/env python3
"""Inspect verified animation tracks, codec metadata, and fixed-point samples."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kdf_data import KdfError, parse_container, property_occurrences, scalar_property
from kdf_wavelet import decode_wavelet

_MAX_RESOURCE_BYTES = 16 * 1024 * 1024
_MAX_WAVELET_TRACKS = 512
_MAX_WAVELET_WORDS = 2_000_000
_MAX_WAVELET_SYMBOLS = 2_000_000
_MAX_WAVELET_SCALARS = 2_000_000
_HEADER_KEYS = ('firstframe', 'duration', 'framerate', 'version', 'pose')
_CODEC_KEYS = (
    'rawfloatsample', 'rawfixedsample', 'waveletsample',
    'quantizedbits', 'quantizedradix', 'huffsize', 'huffcode',
    'compresschannels',
)
_SAMPLE_CODECS = {'rawfixedsample', 'rawfloatsample', 'waveletsample'}
_TRACK_POINTER_MARKERS = {
    'rawfixedsample': 0x30000003,
    'waveletsample': 0x30000004,
}
_TRACK_CHANNELS = {
    'bonepos': 3,
    'positions': 3,
    'bonerot': 4,
    'rotations': 4,
    'scales': 3,
}
_OFFSET_SEMANTICS = {
    'bonepos': 'skl-bone-position-index-verified',
    'bonerot': 'skl-bone-rotation-index-verified',
    'scales': 'skl-scale-index-verified',
    'positions': 'unverified',
    'rotations': 'skl-object-rotation-index-verified',
}
_WAVELET_SCALAR_PROPERTIES = (
    'quantizedbits',
    'quantizedradix',
    'firsthuffmanlevel',
    'numaproximations',
    'compresschannels',
)
_WAVELET_ARRAY_PROPERTIES = ('huffsize', 'huffcode')


def _record_text(container: dict, ordinal: int) -> str | None:
    record = container['records'][ordinal]
    if record['first'] != 0x60000000 or record['second'] >= len(container['strings']):
        return None
    return container['strings'][record['second']]['text']


def _array_by_record(container: dict, ordinal: int, label: str) -> dict:
    reference = next(
        (item for item in container['array_references']
         if item['record_ordinal'] == ordinal),
        None,
    )
    if reference is None:
        raise KdfError(f'animation {label} is not a validated array descriptor')
    return reference


def _array_bytes(raw: bytes, container: dict, reference: dict) -> bytes:
    section = container['sections'][reference['section_index']]
    start = container['payload_offset'] + section['start_relative']
    return raw[start:start + reference['required_bytes']]


def _array_u16(raw: bytes, container: dict, reference: dict, label: str) -> list[int]:
    if reference['element_stride'] != 2:
        raise KdfError(f'animation {label} array is not uint16')
    values = _array_bytes(raw, container, reference)
    return list(struct.unpack(f'<{reference["element_count"]}H', values))


def _array_signed_symbols(
        raw: bytes, container: dict, reference: dict, label: str) -> list[int]:
    values = _array_bytes(raw, container, reference)
    if reference['element_stride'] == 2:
        return list(struct.unpack(f'<{reference["element_count"]}h', values))
    if reference['element_stride'] == 4:
        return list(struct.unpack(f'<{reference["element_count"]}i', values))
    raise KdfError(f'animation {label} array has an unsupported symbol width')


def _array_descriptor(container: dict, reference: dict) -> dict:
    return {
        'section_index': reference['section_index'],
        'element_count': reference['element_count'],
        'element_stride': reference['element_stride'],
        'required_bytes': reference['required_bytes'],
    }


def _is_track_declaration(container: dict, ordinal: int) -> bool:
    if ordinal + 1 >= len(container['records']):
        return False
    name = _record_text(container, ordinal)
    next_record = container['records'][ordinal + 1]
    return name in _TRACK_CHANNELS and next_record['first'] >> 28 == 3


def _is_sample_start(container: dict, ordinal: int) -> bool:
    if ordinal + 1 >= len(container['records']):
        return False
    if _record_text(container, ordinal) != 'type':
        return False
    value = container['records'][ordinal + 1]
    return (
        value['first'] == 0x60000000
        and _record_text(container, ordinal + 1) in _SAMPLE_CODECS
    )


def _expect_key(container: dict, ordinal: int, expected: str) -> None:
    actual = _record_text(container, ordinal)
    if actual != expected:
        raise KdfError(
            f'animation sample record {ordinal} is {actual!r}; expected {expected!r}'
        )


def _parse_wavelet_properties(
        container: dict, start: int) -> tuple[dict, dict, int]:
    if start + 1 >= len(container['records']):
        raise KdfError('animation wavelet properties marker is truncated')
    _expect_key(container, start, 'properties')
    marker_record = container['records'][start + 1]
    marker = marker_record['first']
    if marker >> 28 != 3:
        raise KdfError('animation wavelet properties marker is not a pointer')
    properties_ordinal = start + 1 + marker_record['second']
    if properties_ordinal != start + 2:
        raise KdfError(
            f'animation wavelet properties pointer at record {start + 1} '
            f'targets {properties_ordinal}, expected {start + 2}'
        )
    scalar = {}
    arrays = {}
    position = start + 2
    while position < len(container['records']):
        if (_is_track_declaration(container, position)
                or _is_sample_start(container, position)):
            break
        name = _record_text(container, position)
        if name is None or position + 1 >= len(container['records']):
            raise KdfError(
                f'animation wavelet property at record {position} is malformed'
            )
        value_record = container['records'][position + 1]
        if name in _WAVELET_SCALAR_PROPERTIES:
            if value_record['first'] != 0:
                raise KdfError(f'animation wavelet property {name!r} is not scalar')
            if name in scalar:
                raise KdfError(f'animation wavelet property {name!r} is repeated')
            scalar[name] = value_record['second']
        elif name in _WAVELET_ARRAY_PROPERTIES:
            if value_record['first'] >> 28 != 4:
                raise KdfError(f'animation wavelet property {name!r} is not an array')
            if name in arrays:
                raise KdfError(f'animation wavelet property {name!r} is repeated')
            arrays[name] = _array_by_record(container, position + 1, name)
        else:
            raise KdfError(f'unexpected animation wavelet property {name!r}')
        position += 2
    missing_scalars = [
        name for name in _WAVELET_SCALAR_PROPERTIES if name not in scalar
    ]
    missing_arrays = [
        name for name in _WAVELET_ARRAY_PROPERTIES if name not in arrays
    ]
    if missing_scalars or missing_arrays:
        missing = missing_scalars + missing_arrays
        raise KdfError(
            f'animation wavelet sample is missing properties: {", ".join(missing)}'
        )
    return scalar, arrays, position


def _prefixes_are_prefix_free(entries: list[tuple[int, int, int, int]]) -> bool:
    ranges = []
    for prefix, bit_length, code_count, _ in entries:
        if bit_length <= 0 or bit_length > 32 or code_count <= 0:
            return False
        base = prefix >> (32 - bit_length)
        if base < 0 or base + code_count > 1 << bit_length:
            return False
        shift = 32 - bit_length
        ranges.append((base << shift, (base + code_count) << shift))
    ranges.sort()
    for (_, left_end), (right_start, _) in zip(ranges, ranges[1:], strict=False):
        if left_end > right_start:
            return False
    return True


def _decode_raw_fixed(
        raw: bytes, container: dict, reference: dict, track: str,
        include_values: bool) -> dict:
    data = _array_bytes(raw, container, reference)
    count = reference['element_count']
    stride = reference['element_stride']
    if track in ('bonerot', 'rotations'):
        if stride != 8:
            raise KdfError(f'raw-fixed {track} samples are not int16[4]')
        values = [
            tuple(value / 16384.0 for value in struct.unpack_from('<4h', data, index * 8))
            for index in range(count)
        ]
        decoded = {
            'kind': 'quaternion-fixed-q14',
            'component_order': 'unverified',
        }
    elif track in ('bonepos', 'positions', 'scales'):
        if stride != 12:
            raise KdfError(f'raw-fixed {track} samples are not int32[3]')
        values = [
            tuple(value / 4096.0 for value in struct.unpack_from('<3i', data, index * 12))
            for index in range(count)
        ]
        decoded = {
            'kind': 'vector-fixed-q12',
        }
    else:
        raise KdfError(f'unsupported raw-fixed track {track!r}')
    decoded['value_preview'] = values[:3]
    decoded['values_omitted'] = not include_values
    if include_values:
        decoded['values'] = values
    return decoded


def _offset_semantics(track: str) -> str:
    return _OFFSET_SEMANTICS[track]


def _decode_wavelet(
        raw: bytes, container: dict, track: str, data_reference: dict,
        offset_reference: dict, properties_start: int,
        include_values: bool, sample_count: int,
        decode_wavelet_values: bool, budget: dict[str, int]) -> tuple[dict, dict, int]:
    if data_reference['element_stride'] != 4:
        raise KdfError('wavelet data is not a uint32 word array')
    offsets = _array_u16(raw, container, offset_reference, 'offset')
    scalar, arrays, next_record = _parse_wavelet_properties(
        container, properties_start)

    huffsize_reference = arrays['huffsize']
    huffcode_reference = arrays['huffcode']
    budget['tracks'] += 1
    budget['words'] += data_reference['element_count']
    budget['symbols'] += huffcode_reference['element_count']
    if decode_wavelet_values:
        budget['scalars'] += sample_count * scalar['compresschannels']
    if (budget['tracks'] > _MAX_WAVELET_TRACKS
            or budget['words'] > _MAX_WAVELET_WORDS
            or budget['symbols'] > _MAX_WAVELET_SYMBOLS
            or budget['scalars'] > _MAX_WAVELET_SCALARS):
        raise KdfError('animation wavelet file exceeds the aggregate work limit')
    if huffsize_reference['element_stride'] != 16:
        raise KdfError('wavelet huffsize entries are not four uint32 words')
    expected_symbol_stride = 4 if _TRACK_CHANNELS[track] == 3 else 2
    if huffcode_reference['element_stride'] != expected_symbol_stride:
        raise KdfError(
            f'wavelet huffcode entries do not use {expected_symbol_stride}-byte symbols'
        )

    huffsize_bytes = _array_bytes(raw, container, huffsize_reference)
    huffsize = [
        struct.unpack_from('<4I', huffsize_bytes, index * 16)
        for index in range(huffsize_reference['element_count'])
    ]
    huffcodes = _array_signed_symbols(
        raw, container, huffcode_reference, 'huffcode')

    next_code_start = 0
    for ordinal, (prefix, bit_length, code_count, code_start) in enumerate(huffsize):
        if bit_length <= 0 or bit_length > 32:
            raise KdfError(
                f'wavelet huffsize entry {ordinal} has invalid bit length'
            )
        if prefix & ((1 << (32 - bit_length)) - 1):
            raise KdfError(
                f'wavelet huffsize entry {ordinal} is not left-aligned'
            )
        if code_count <= 0 or code_start != next_code_start:
            raise KdfError(
                f'wavelet huffsize entry {ordinal} has a non-contiguous code range'
            )
        next_code_start += code_count
    if next_code_start != len(huffcodes):
        raise KdfError(
            'wavelet huffsize counts do not cover every huffcode symbol'
        )
    if not _prefixes_are_prefix_free(huffsize):
        raise KdfError('wavelet huffsize prefixes are not prefix-free')

    expected_channels = len(offsets) * _TRACK_CHANNELS[track]
    if scalar['compresschannels'] != expected_channels:
        raise KdfError(
            'wavelet compresschannels does not match offset_count × components'
        )
    data = _array_bytes(raw, container, data_reference)
    leading_words = list(struct.unpack_from(
        f'<{min(8, data_reference["element_count"])}I', data))
    if leading_words and leading_words[0] != scalar['numaproximations']:
        raise KdfError(
            'wavelet data leading approximation count does not match properties'
        )

    wavelet = {
        'properties': scalar,
        'offset_count': len(offsets),
        'expected_compresschannels': expected_channels,
        'data_leading_words': leading_words,
        'huffman_entry_count': len(huffsize),
        'huffman_code_count': len(huffcodes),
        'huffman_symbol_signedness': 'unverified',
        'huffman_entries': [
            {
                'left_aligned_prefix': f'{prefix:08x}',
                'bit_length': bit_length,
                'code_count': code_count,
                'huffcode_start': code_start,
            }
            for prefix, bit_length, code_count, code_start in huffsize
        ],
        'huffman_code_preview': huffcodes[:16],
        'huffman_codes_omitted': not include_values and len(huffcodes) > 16,
        'bitstream_decoding': 'unresolved',
    }
    if include_values:
        wavelet['huffcodes'] = huffcodes
    decode_status = 'unresolved-wavelet'
    if decode_wavelet_values:
        if scalar['quantizedbits'] != 32:
            raise KdfError('wavelet quantizedbits is outside the observed profile')
        if scalar['firsthuffmanlevel'] != 0:
            raise KdfError('wavelet firsthuffmanlevel is outside the observed profile')
        wavelet['decoded'] = decode_wavelet(
            data, sample_count=sample_count,
            channels=scalar['compresschannels'], components=_TRACK_CHANNELS[track],
            element_bytes=expected_symbol_stride,
            approximations=scalar['numaproximations'],
            radix=scalar['quantizedradix'], huffman_entries=huffsize,
            huffman_symbols=huffcodes, include_values=include_values,
        )
        wavelet['bitstream_decoding'] = 'decoded-observed-profile'
        decode_status = 'decoded-wavelet-candidate'
    return {
        'codec': 'waveletsample',
        'data': _array_descriptor(container, data_reference),
        'offsets': {
            **_array_descriptor(container, offset_reference),
            'values': offsets,
            'semantics': _offset_semantics(track),
        },
        'wavelet': wavelet,
        'decode_status': decode_status,
    }, {}, next_record


def _parse_sample(
        raw: bytes, container: dict, start: int, track: str,
        include_values: bool, sample_count: int,
        decode_wavelet_values: bool, budget: dict[str, int]) -> tuple[dict, int]:
    if start + 5 >= len(container['records']):
        raise KdfError(f'animation sample at record {start} is truncated')
    _expect_key(container, start, 'type')
    codec = _record_text(container, start + 1)
    if codec not in _SAMPLE_CODECS:
        raise KdfError(f'animation sample at record {start} has an unknown codec')
    _expect_key(container, start + 2, 'data')
    data_reference = _array_by_record(container, start + 3, 'data')
    _expect_key(container, start + 4, 'offset')
    offset_reference = _array_by_record(container, start + 5, 'offset')

    if codec == 'rawfixedsample':
        offsets = _array_u16(raw, container, offset_reference, 'offset')
        return {
            'codec': codec,
            'data': {
                **_array_descriptor(container, data_reference),
                **{
                    'decoded': _decode_raw_fixed(
                        raw, container, data_reference, track, include_values)
                },
            },
            'offsets': {
                **_array_descriptor(container, offset_reference),
                'values': offsets,
                'semantics': _offset_semantics(track),
            },
            'decode_status': 'decoded-fixed-point',
        }, start + 6
    if codec == 'waveletsample':
        sample, _, next_record = _decode_wavelet(
            raw, container, track, data_reference, offset_reference,
            start + 6, include_values, sample_count, decode_wavelet_values, budget)
        return sample, next_record
    return {
        'codec': codec,
        'data': _array_descriptor(container, data_reference),
        'offsets': {
            **_array_descriptor(container, offset_reference),
            'values': _array_u16(raw, container, offset_reference, 'offset'),
            'semantics': _offset_semantics(track),
        },
        'decode_status': 'unsupported-codec',
    }, start + 6


def _parse_tracks(
        raw: bytes, container: dict, include_values: bool, sample_count: int,
        decode_wavelet_values: bool) -> list[dict]:
    records = container['records']
    blocks = []
    active_tracks = []
    active_block = None
    budget = {'tracks': 0, 'words': 0, 'symbols': 0, 'scalars': 0}
    ordinal = 0
    while ordinal < len(records):
        if _is_track_declaration(container, ordinal):
            if active_tracks:
                raise KdfError('animation track block has missing sample definitions')
            active_block = {
                'ordinal': len(blocks), 'record_start': ordinal, 'tracks': [],
            }
            blocks.append(active_block)
            while _is_track_declaration(container, ordinal):
                name = _record_text(container, ordinal)
                binding = records[ordinal + 1]
                sample_ordinal = ordinal + 1 + binding['second']
                if not _is_sample_start(container, sample_ordinal):
                    raise KdfError(
                        f'animation track {name!r} at record {ordinal} points to '
                        f'record {sample_ordinal}, which is not a sample start'
                    )
                codec = _record_text(container, sample_ordinal + 1)
                expected_marker = _TRACK_POINTER_MARKERS.get(codec)
                if expected_marker is not None and binding['first'] != expected_marker:
                    raise KdfError(
                        f'animation track {name!r} pointer marker '
                        f'0x{binding["first"]:08x} does not match {codec!r}'
                    )
                if any(
                        track['sample_ordinal'] == sample_ordinal
                        for track in active_tracks):
                    raise KdfError(
                        f'animation tracks share sample record {sample_ordinal}'
                    )
                active_tracks.append({
                    'name': name,
                    'binding_marker': f'{binding["first"]:08x}',
                    'binding_value': binding['second'],
                    'sample_ordinal': sample_ordinal,
                })
                ordinal += 2
            continue
        if _is_sample_start(container, ordinal):
            if active_block is None or not active_tracks:
                raise KdfError(
                    f'animation sample at record {ordinal} has no track declaration'
                )
            track_index = next(
                (index for index, track in enumerate(active_tracks)
                 if track['sample_ordinal'] == ordinal),
                None,
            )
            if track_index is None:
                expected = ', '.join(
                    str(track['sample_ordinal']) for track in active_tracks)
                raise KdfError(
                    f'animation sample at record {ordinal} does not match '
                    f'active track targets: {expected}'
                )
            track = active_tracks.pop(track_index)
            sample, ordinal = _parse_sample(
                raw, container, ordinal, track['name'], include_values,
                sample_count, decode_wavelet_values, budget)
            active_block['tracks'].append({**track, 'sample': sample})
            continue
        ordinal += 1
    if active_tracks:
        raise KdfError('animation track block has missing sample definitions')
    if not blocks:
        raise KdfError('animation has no verified track blocks')
    return blocks


def _identify_track_sections(container: dict, groups: list[dict]) -> None:
    """Bind observed anmdata/anmstatic labels through their relative pointers."""
    strings = {item['text'] for item in container['strings']}
    by_start = {group['record_start']: group for group in groups}
    seen = set()
    for key in ('anmdata', 'anmstatic'):
        if key not in strings:
            continue
        matches = property_occurrences(container, key)
        if len(matches) != 1 or matches[0]['value_marker'] >> 28 != 3:
            raise KdfError(f'animation {key} section pointer is invalid')
        match = matches[0]
        target = match['value_record'] + match['value']
        if target not in by_start or target in seen:
            raise KdfError(f'animation {key} does not uniquely target a track group')
        by_start[target]['source_section'] = key
        seen.add(target)


def inspect_animation(
        raw: bytes, *, include_values: bool = False,
        decode_wavelet_values: bool = False,
        data_offset: int | None = None) -> dict:
    container = parse_container(raw, data_offset=data_offset)
    names = {entry['text'] for entry in container['strings']}
    missing = [key for key in _HEADER_KEYS if key not in names]
    if missing:
        raise KdfError(f'animation header keys missing: {", ".join(missing)}')
    headers = {key: scalar_property(container, key) for key in _HEADER_KEYS}
    if decode_wavelet_values and headers['version'] != 7:
        raise KdfError('animation version is outside the observed wavelet profile')
    track_groups = _parse_tracks(
        raw, container, include_values, headers['duration'], decode_wavelet_values)
    _identify_track_sections(container, track_groups)
    codecs = [
        {
            'track_group': group['ordinal'],
            'track': track['name'],
            'codec': track['sample']['codec'],
            'decode_status': track['sample']['decode_status'],
            'data_element_count': track['sample']['data']['element_count'],
        }
        for group in track_groups
        for track in group['tracks']
    ]
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
        'track_groups': track_groups,
        'codecs': codecs,
        'tail_identity_hex': container['tail_identity_hex'],
    }


def inspect_file(
        path: Path, *, include_values: bool = False,
        decode_wavelet_values: bool = False) -> dict:
    with path.open('rb') as file:
        raw = file.read(_MAX_RESOURCE_BYTES + 1)
    if len(raw) > _MAX_RESOURCE_BYTES:
        raise KdfError('decoded animation exceeds inspection size limit')
    result = inspect_animation(
        raw, include_values=include_values,
        decode_wavelet_values=decode_wavelet_values)
    result['source'] = str(path)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='decoded 1FDKENONCTX3 animation resource')
    parser.add_argument(
        '--values', action='store_true',
        help='include every decoded sample and Huffman symbol')
    parser.add_argument(
        '--decode-wavelet', action='store_true',
        help='decode the observed wavelet profile; output remains a candidate')
    args = parser.parse_args()
    try:
        result = inspect_file(
            args.source, include_values=args.values,
            decode_wavelet_values=args.decode_wavelet)
    except (OSError, KdfError) as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

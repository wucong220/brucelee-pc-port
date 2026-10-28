import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_animation import (
    _decode_raw_fixed,
    _offset_semantics,
    _prefixes_are_prefix_free,
    inspect_animation,
)
from kdf_data import KdfError


HEADER_VALUES = {
    'firstframe': 0,
    'duration': 69,
    'framerate': 30,
    'version': 7,
    'pose': 1,
}


def animation_fixture(values=None, *, compresschannels=None) -> bytes:
    values = HEADER_VALUES if values is None else values
    strings = list(values) + [
        'bonepos', 'bonerot', 'scales', 'positions',
        'type', 'rawfixedsample', 'data', 'offset',
        'waveletsample', 'properties', 'quantizedbits', 'quantizedradix',
        'firsthuffmanlevel', 'numaproximations',
        'huffsize', 'huffcode', 'compresschannels',
    ]
    records = []
    for key, value in values.items():
        records.extend(((0x60000000, strings.index(key)), (0, value)))

    records.extend((
        (0x60000000, strings.index('bonepos')),
        (0x30000003, 0),
        (0x60000000, strings.index('bonerot')),
        (0x30000004, 1),
    ))
    records.extend((
        (0x60000000, strings.index('type')),
        (0x60000000, strings.index('rawfixedsample')),
        (0x60000000, strings.index('data')),
        (0x41800002, 0),
        (0x60000000, strings.index('offset')),
        (0x40400001, 1),
    ))
    records.extend((
        (0x60000000, strings.index('type')),
        (0x60000000, strings.index('waveletsample')),
        (0x60000000, strings.index('data')),
        (0x40800004, 2),
        (0x60000000, strings.index('offset')),
        (0x40400002, 3),
        (0x60000000, strings.index('properties')),
        (0x30000007, 1),
        (0x60000000, strings.index('quantizedbits')),
        (0, 32),
        (0x60000000, strings.index('quantizedradix')),
        (0, 12),
        (0x60000000, strings.index('firsthuffmanlevel')),
        (0, 0),
        (0x60000000, strings.index('numaproximations')),
        (0, 3),
        (0x60000000, strings.index('huffsize')),
        (0x42000001, 4),
        (0x60000000, strings.index('huffcode')),
        (0x40400002, 5),
        (0x60000000, strings.index('compresschannels')),
        (0, 8 if compresschannels is None else compresschannels),
    ))
    records.extend((
        (0x60000000, strings.index('bonerot')),
        (0x30000003, 3),
        (0x60000000, strings.index('scales')),
        (0x30000003, 7),
        (0x60000000, strings.index('type')),
        (0x60000000, strings.index('rawfixedsample')),
        (0x60000000, strings.index('data')),
        (0x41000002, 6),
        (0x60000000, strings.index('offset')),
        (0x40400001, 7),
        (0x60000000, strings.index('type')),
        (0x60000000, strings.index('rawfixedsample')),
        (0x60000000, strings.index('data')),
        (0x41800002, 8),
        (0x60000000, strings.index('offset')),
        (0x40400002, 9),
    ))

    sections = (
        struct.pack('<3i3i', 4096, -8192, 4095, -4096, 8192, -4095),
        struct.pack('<HH', 0, 0),
        struct.pack('<4I', 3, 0, 1, 2),
        struct.pack('<2H', 0, 1),
        struct.pack('<4I', 0, 2, 2, 0),
        struct.pack('<2h', -1, 1),
        struct.pack(
            '<4h4h',
            0, 0, 0, 16384,
            8192, -8192, 0, 16384,
        ),
        struct.pack('<2H', 1, 0),
        struct.pack('<3i3i', 4096, 4096, 4096, 2048, 4096, 4096),
        struct.pack('<2H', 7, 28),
    )
    payload = b''.join(sections)
    offsets = [0, 0]
    for section in sections[:-1]:
        offsets.append(offsets[-1] + len(section))
    raw = bytearray(b'1FDKENONCTX3' + struct.pack('<IIII', len(strings), 1, 0, len(strings)))
    for text in strings:
        encoded = text.encode()
        identifier = (zlib.crc32(encoded) + len(encoded)) & 0xffffffff
        raw += struct.pack('<II', identifier, len(encoded)) + encoded + b'\0'
    raw += b'\0'
    raw += b'DATA'
    raw += struct.pack('<IIII', len(records), len(sections), 0, len(payload))
    raw += struct.pack(f'<{len(offsets)}I', *offsets)
    for record in records:
        raw += struct.pack('<II', *record)
    raw += payload + b'animation-ident!'
    return bytes(raw)


class TestKdfAnimation(unittest.TestCase):
    def test_verified_header_tracks_and_codecs(self):
        for duration in (110, 69, 86):
            values = dict(HEADER_VALUES, duration=duration)
            with self.subTest(duration=duration):
                result = inspect_animation(animation_fixture(values))
                self.assertEqual(result['headers'], values)
                self.assertIn('waveletsample', result['codec_keys_present'])
                self.assertEqual(
                    [(item['track'], item['codec']) for item in result['codecs']],
                    [
                        ('bonepos', 'rawfixedsample'),
                        ('bonerot', 'waveletsample'),
                        ('bonerot', 'rawfixedsample'),
                        ('scales', 'rawfixedsample'),
                    ],
                )
                self.assertEqual(len(result['track_groups']), 2)
                self.assertTrue(all(
                    section['bytes'] > 0 for section in result['sections']))

    def test_raw_fixed_q12_vectors_are_decoded(self):
        result = inspect_animation(animation_fixture(), include_values=True)
        sample = result['track_groups'][0]['tracks'][0]['sample']
        self.assertEqual(sample['decode_status'], 'decoded-fixed-point')
        self.assertEqual(
            sample['data']['decoded']['kind'], 'vector-fixed-q12')
        self.assertEqual(sample['data']['decoded']['values'], [
            (1.0, -2.0, 0.999755859375),
            (-1.0, 2.0, -0.999755859375),
        ])
        self.assertEqual(sample['offsets']['values'], [0])
        self.assertEqual(
            sample['offsets']['semantics'],
            'skl-bone-position-index-verified',
        )

    def test_raw_fixed_q14_quaternions_are_decoded(self):
        container = {
            'payload_offset': 0,
            'sections': [{'start_relative': 0}],
        }
        reference = {
            'section_index': 0,
            'element_count': 2,
            'element_stride': 8,
            'required_bytes': 16,
        }
        raw = struct.pack(
            '<4h4h',
            0, 0, 0, 16384,
            8192, -8192, 0, 16384,
        )
        result = _decode_raw_fixed(
            raw, container, reference, 'bonerot', include_values=True)
        self.assertEqual(result['kind'], 'quaternion-fixed-q14')
        self.assertEqual(result['component_order'], 'unverified')
        self.assertEqual(result['values'], [
            (0.0, 0.0, 0.0, 1.0),
            (0.5, -0.5, 0.0, 1.0),
        ])

    def test_wavelet_metadata_is_validated_without_claiming_decode(self):
        result = inspect_animation(animation_fixture())
        sample = result['track_groups'][0]['tracks'][1]['sample']
        self.assertEqual(sample['decode_status'], 'unresolved-wavelet')
        self.assertEqual(sample['offsets']['values'], [0, 1])
        self.assertEqual(sample['wavelet']['properties'], {
            'quantizedbits': 32,
            'quantizedradix': 12,
            'firsthuffmanlevel': 0,
            'numaproximations': 3,
            'compresschannels': 8,
        })
        self.assertEqual(sample['wavelet']['data_leading_words'], [3, 0, 1, 2])
        self.assertEqual(sample['wavelet']['huffman_entry_count'], 1)
        self.assertEqual(sample['wavelet']['huffman_code_count'], 2)
        self.assertEqual(sample['wavelet']['huffman_code_preview'], [-1, 1])
        self.assertEqual(
            sample['wavelet']['bitstream_decoding'], 'unresolved')
        self.assertEqual(
            sample['offsets']['semantics'],
            'skl-bone-rotation-index-verified',
        )

    def test_second_track_group_decodes_q14_rotation_and_scale(self):
        result = inspect_animation(animation_fixture(), include_values=True)
        self.assertEqual(len(result['track_groups']), 2)
        rotation = result['track_groups'][1]['tracks'][0]
        scales = result['track_groups'][1]['tracks'][1]
        self.assertEqual(rotation['name'], 'bonerot')
        self.assertEqual(rotation['sample']['data']['decoded']['values'], [
            (0.0, 0.0, 0.0, 1.0),
            (0.5, -0.5, 0.0, 1.0),
        ])
        self.assertEqual(
            rotation['sample']['offsets']['semantics'],
            'skl-bone-rotation-index-verified',
        )
        self.assertEqual(scales['name'], 'scales')
        self.assertEqual(scales['sample']['offsets']['values'], [7, 28])
        self.assertEqual(
            scales['sample']['offsets']['semantics'],
            'skl-scale-index-verified',
        )

    def test_position_offsets_remain_unverified(self):
        self.assertEqual(_offset_semantics('bonepos'),
                         'skl-bone-position-index-verified')
        self.assertEqual(_offset_semantics('bonerot'),
                         'skl-bone-rotation-index-verified')
        self.assertEqual(_offset_semantics('scales'),
                         'skl-scale-index-verified')
        self.assertEqual(_offset_semantics('positions'), 'unverified')

    def test_huffman_prefix_check_expands_every_code_in_each_range(self):
        self.assertFalse(_prefixes_are_prefix_free([
            (0x00000000, 2, 4, 0),
            (0xC0000000, 3, 1, 4),
        ]))
        self.assertFalse(_prefixes_are_prefix_free([
            (0xF0000000, 4, 2, 0),
        ]))
        self.assertFalse(_prefixes_are_prefix_free([
            (0x00000000, 2, 1, 0),
            (0x00000000, 2, 1, 1),
        ]))
        self.assertTrue(_prefixes_are_prefix_free([
            (0x00000000, 2, 2, 0),
            (0x80000000, 2, 2, 2),
        ]))

    def test_wavelet_compresschannels_must_match_track_width(self):
        with self.assertRaisesRegex(KdfError, 'compresschannels'):
            inspect_animation(animation_fixture(compresschannels=9))

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
                [sys.executable, '-X', 'utf8', str(script), str(source), '--values'],
                capture_output=True, text=True, encoding='utf-8', check=False,
            )
            self.assertEqual(run.returncode, 0, run.stderr)
            report = json.loads(run.stdout)
            self.assertEqual(report['headers']['duration'], 69)
            self.assertEqual(
                report['track_groups'][0]['tracks'][0]['sample']['data']
                ['decoded']['values'][0][:2],
                [1.0, -2.0],
            )


if __name__ == '__main__':
    unittest.main()

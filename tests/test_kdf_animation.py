import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_animation import (
    _decode_raw_fixed,
    _offset_semantics,
    _prefixes_are_prefix_free,
    inspect_animation,
)
from kdf_data import KdfError
from kdf_wavelet import _stream_bounds


HEADER_VALUES = {
    'firstframe': 0,
    'duration': 69,
    'framerate': 30,
    'version': 7,
    'pose': 1,
}


def animation_fixture(
        values=None, *, compresschannels=None,
        track_pointer_targets=None, track_pointer_markers=None,
        reverse_first_declarations=False,
        wavelet_properties_pointer=1, wavelet_words=None,
        numaproximations=3, first_huffman_level=0, quantizedbits=32,
        duplicate_wavelets=0, include_section_pointers=False,
        section_pointer_delta=0) -> bytes:
    values = HEADER_VALUES if values is None else values
    wavelet_words = [3, 0, 1, 2] if wavelet_words is None else wavelet_words
    strings = list(values) + [
        'bonepos', 'bonerot', 'scales', 'positions',
        'type', 'rawfixedsample', 'data', 'offset',
        'waveletsample', 'properties', 'quantizedbits', 'quantizedradix',
        'firsthuffmanlevel', 'numaproximations',
        'huffsize', 'huffcode', 'compresschannels',
    ]
    if include_section_pointers:
        strings.extend(['anmdata', 'anmstatic'])
    records = []
    for key, value in values.items():
        records.extend(((0x60000000, strings.index(key)), (0, value)))

    section_pointer_records = {}
    if include_section_pointers:
        for name in ('anmdata', 'anmstatic'):
            records.append((0x60000000, strings.index(name)))
            section_pointer_records[name] = len(records)
            records.append((0x30000003, 0))

    first_declarations = [
        ('bonepos', 'bonepos_raw', 'bonepos_raw', 0x30000003),
        ('bonerot', 'bonerot_wavelet', 'bonerot_wavelet', 0x30000004),
    ]
    if reverse_first_declarations:
        first_declarations.reverse()
    first_track_start = len(records)
    for name, _, _, marker in first_declarations:
        records.extend(((0x60000000, strings.index(name)), (marker, 0)))
    first_bonepos_sample = len(records)
    records.extend((
        (0x60000000, strings.index('type')),
        (0x60000000, strings.index('rawfixedsample')),
        (0x60000000, strings.index('data')),
        (0x41800002, 0),
        (0x60000000, strings.index('offset')),
        (0x40400001, 1),
    ))
    first_bonerot_sample = len(records)
    records.extend((
        (0x60000000, strings.index('type')),
        (0x60000000, strings.index('waveletsample')),
        (0x60000000, strings.index('data')),
        (0x40800000 | len(wavelet_words), 2),
        (0x60000000, strings.index('offset')),
        (0x40400002, 3),
        (0x60000000, strings.index('properties')),
        (0x30000007, wavelet_properties_pointer),
        (0x60000000, strings.index('quantizedbits')),
        (0, quantizedbits),
        (0x60000000, strings.index('quantizedradix')),
        (0, 12),
        (0x60000000, strings.index('firsthuffmanlevel')),
        (0, first_huffman_level),
        (0x60000000, strings.index('numaproximations')),
        (0, numaproximations),
        (0x60000000, strings.index('huffsize')),
        (0x42000001, 4),
        (0x60000000, strings.index('huffcode')),
        (0x40400002, 5),
        (0x60000000, strings.index('compresschannels')),
        (0, 8 if compresschannels is None else compresschannels),
    ))
    second_track_start = len(records)
    records.extend((
        (0x60000000, strings.index('bonerot')),
        (0x30000003, 0),
        (0x60000000, strings.index('scales')),
        (0x30000003, 0),
    ))
    second_bonerot_sample = len(records)
    records.extend((
        (0x60000000, strings.index('type')),
        (0x60000000, strings.index('rawfixedsample')),
        (0x60000000, strings.index('data')),
        (0x41000002, 6),
        (0x60000000, strings.index('offset')),
        (0x40400001, 7),
    ))
    second_scales_sample = len(records)
    records.extend((
        (0x60000000, strings.index('type')),
        (0x60000000, strings.index('rawfixedsample')),
        (0x60000000, strings.index('data')),
        (0x41800002, 8),
        (0x60000000, strings.index('offset')),
        (0x40400002, 9),
    ))
    sample_targets = {
        'bonepos_raw': first_bonepos_sample,
        'bonerot_wavelet': first_bonerot_sample,
        'bonerot_raw': second_bonerot_sample,
        'scales_raw': second_scales_sample,
    }
    sample_targets.update(track_pointer_targets or {})
    pointer_records = {
        slot_name: first_track_start + index * 2 + 1
        for index, (_, slot_name, _, _) in enumerate(first_declarations)
    }
    pointer_records.update({
        'bonerot_raw': second_track_start + 1,
        'scales_raw': second_track_start + 3,
    })
    pointer_markers = {
        'bonepos_raw': 0x30000003,
        'bonerot_wavelet': 0x30000004,
        'bonerot_raw': 0x30000003,
        'scales_raw': 0x30000003,
    }
    pointer_markers.update(track_pointer_markers or {})
    for name, pointer_ordinal in pointer_records.items():
        records[pointer_ordinal] = (
            pointer_markers[name], sample_targets[name] - pointer_ordinal)

    if include_section_pointers:
        for name, target in (('anmdata', first_track_start),
                             ('anmstatic', second_track_start)):
            pointer_ordinal = section_pointer_records[name]
            delta = section_pointer_delta if name == 'anmdata' else 0
            records[pointer_ordinal] = (0x30000003, target - pointer_ordinal + delta)

    for _ in range(duplicate_wavelets):
        records.extend((
            (0x60000000, strings.index('bonerot')),
            (0x30000004, 1),
        ))
        records.extend(records[first_bonerot_sample:second_track_start])

    sections = (
        struct.pack('<3i3i', 4096, -8192, 4095, -4096, 8192, -4095),
        struct.pack('<HH', 0, 0),
        struct.pack(f'<{len(wavelet_words)}I', *wavelet_words),
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
                self.assertEqual(
                    [
                        track['sample_ordinal']
                        for group in result['track_groups']
                        for track in group['tracks']
                    ],
                    [14, 20, 46, 52],
                )
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

    def test_opt_in_wavelet_decode_through_animation_inspector(self):
        # Eight invented int16 channels; all intermediate symbols are +1,
        # followed by -1 in each terminal stream.
        words = [
            1, 6, 0, 0, 0, 0, 9, 10, 0x55550000, 0, 0,
        ]
        raw = animation_fixture(
            dict(HEADER_VALUES, duration=4), wavelet_words=words,
            numaproximations=1,
        )
        result = inspect_animation(
            raw, include_values=True, decode_wavelet_values=True)
        sample = result['track_groups'][0]['tracks'][1]['sample']
        self.assertEqual(sample['decode_status'], 'decoded-wavelet-candidate')
        decoded = sample['wavelet']['decoded']
        self.assertEqual(decoded['sample_count'], 4)
        self.assertEqual(decoded['native_runtime_comparison'], 'unverified')
        self.assertEqual(decoded['values'], [
            [[0.0] * 4, [0.0] * 4],
            [[-2.0 / 4096] * 4, [-2.0 / 4096] * 4],
            [[2.0 / 4096] * 4, [2.0 / 4096] * 4],
            [[0.0] * 4, [0.0] * 4],
        ])

    def test_wavelet_decode_rejects_unobserved_version_and_properties(self):
        words = [1, 6, 0, 0, 0, 0, 9, 10, 0x55550000, 0, 0]
        for arguments, message in (
                ({'values': dict(HEADER_VALUES, duration=4, version=8)},
                 'version'),
                ({'values': dict(HEADER_VALUES, duration=4), 'quantizedbits': 0},
                 'quantizedbits'),
                ({'values': dict(HEADER_VALUES, duration=4), 'first_huffman_level': 1},
                 'firsthuffmanlevel')):
            with self.subTest(message=message):
                raw = animation_fixture(
                    wavelet_words=words, numaproximations=1, **arguments)
                # Metadata inspection remains possible without candidate decoding.
                inspect_animation(raw)
                with self.assertRaisesRegex(KdfError, message):
                    inspect_animation(raw, decode_wavelet_values=True)

    def test_wavelet_decode_applies_a_file_level_budget_across_tracks(self):
        words = [1, 6, 0, 0, 0, 0, 9, 10, 0x55550000, 0, 0]
        raw = animation_fixture(
            dict(HEADER_VALUES, duration=4), wavelet_words=words,
            numaproximations=1, duplicate_wavelets=1,
        )
        with mock.patch('kdf_animation._MAX_WAVELET_SCALARS', 48):
            with self.assertRaisesRegex(KdfError, 'aggregate work limit'):
                inspect_animation(raw, decode_wavelet_values=True)

    def test_track_section_labels_follow_relative_pointers(self):
        result = inspect_animation(animation_fixture(include_section_pointers=True))
        self.assertEqual(
            [group['source_section'] for group in result['track_groups']],
            ['anmdata', 'anmstatic'],
        )
        with self.assertRaisesRegex(KdfError, 'anmdata does not uniquely target'):
            inspect_animation(animation_fixture(
                include_section_pointers=True, section_pointer_delta=1))

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
        # A large contiguous range must not be expanded into billions of codes.
        self.assertTrue(_prefixes_are_prefix_free([
            (0x00000000, 32, 0x80000000, 0),
        ]))

    def test_wavelet_compresschannels_must_match_track_width(self):
        with self.assertRaisesRegex(KdfError, 'compresschannels'):
            inspect_animation(animation_fixture(compresschannels=9))

    def test_track_pointer_must_reference_sample_start(self):
        with self.assertRaisesRegex(
                KdfError, r'points to record 15, which is not a sample start'):
            inspect_animation(animation_fixture(
                track_pointer_targets={'bonepos_raw': 15}))

    def test_track_binding_uses_target_not_declaration_order(self):
        result = inspect_animation(animation_fixture(
            reverse_first_declarations=True))
        first_group = {
            track['name']: track for track in result['track_groups'][0]['tracks']
        }
        self.assertEqual(
            first_group['bonepos']['sample']['codec'], 'rawfixedsample')
        self.assertEqual(first_group['bonepos']['sample_ordinal'], 14)
        self.assertEqual(
            first_group['bonerot']['sample']['codec'], 'waveletsample')
        self.assertEqual(first_group['bonerot']['sample_ordinal'], 20)

    def test_track_pointer_targets_must_be_unique(self):
        with self.assertRaisesRegex(KdfError, 'share sample record 14'):
            inspect_animation(animation_fixture(
                track_pointer_targets={'bonerot_wavelet': 14},
                track_pointer_markers={'bonerot_wavelet': 0x30000003},
            ))

    def test_track_pointer_marker_must_match_sample_codec(self):
        with self.assertRaisesRegex(
                KdfError, r'pointer marker 0x30000004 does not match '
                r"'rawfixedsample'"):
            inspect_animation(animation_fixture(
                track_pointer_markers={'bonepos_raw': 0x30000004}))

    def test_wavelet_properties_pointer_must_target_first_property(self):
        with self.assertRaisesRegex(
                KdfError, r'wavelet properties pointer.*expected 28'):
            inspect_animation(animation_fixture(
                wavelet_properties_pointer=2))

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


class TestWaveletZeroRoot(unittest.TestCase):
    def test_unused_zeroed_approximation_root_is_skipped(self):
        # m01_pnch_low_02 carries a zeroed third root with no channel array.
        internal, leaf = _stream_bounds((1, 0), 1, 3, 4, 1)
        self.assertEqual(internal, {})
        self.assertEqual(leaf, {})

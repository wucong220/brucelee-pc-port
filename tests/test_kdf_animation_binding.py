import hashlib
import math
from pathlib import Path
import struct
import sys
import unittest
from unittest.mock import patch
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_animation import inspect_animation
from kdf_animation_binding import bind_animation
from kdf_data import KdfError, parse_container, parse_context
from kdf_skeleton import inspect_skeleton
from test_kdf_skeleton import object_skeleton_fixture, skeleton_fixture


def animation_fixture(
        *, reference_id=0, reference_marker=0x70000000, extension='skl',
        duplicate_header=False, section_delta=0, sample_delta=0,
        duplicate_target=False, header_overrides=None,
        bone_only=False, data_marker_in_references=False,
        include_object_rotation=False) -> bytes:
    headers = {
        'firstframe': 0, 'duration': 3, 'framerate': 30, 'version': 7, 'pose': 1,
    }
    headers.update(header_overrides or {})
    strings = list(headers) + [
        'anmheader', 'anmdata', 'anmstatic', 'bonepos', 'bonerot', 'positions',
        'scales', 'type', 'rawfixedsample', 'data', 'offset',
        'skeletons/', 'hero', extension,
    ]
    if include_object_rotation:
        strings.insert(strings.index('positions') + 1, 'rotations')
    if data_marker_in_references:
        parts = ('skeletons/', 'hero', extension)
        other_strings = [value for value in strings if value not in parts]
        ordered = [f'fixture_filler_{i}' for i in range(85)]
        ordered[68], ordered[65], ordered[84] = parts
        available = (i for i in range(len(ordered)) if i not in (68, 65, 84))
        for value in other_strings:
            ordered[next(available)] = value
        strings = ordered
    records = []
    sections = []

    def text(value):
        return (0x60000000, strings.index(value))

    def descriptor(count, stride):
        return 0x40000000 | (stride << 21) | count

    for key, value in headers.items():
        records.extend((text(key), (0, value)))
    records.extend((text('anmheader'), (reference_marker, reference_id)))
    if duplicate_header:
        records.extend((text('anmheader'), (reference_marker, reference_id)))
    section_pointers = {}
    for section_name in ('anmdata', 'anmstatic'):
        records.append(text(section_name))
        section_pointers[section_name] = len(records)
        records.append((0x30000003, 0))

    groups = [
        ('anmdata', [
            ('bonepos', [(0, 0, 0), (4096, 0, 0), (8192, 0, 0)], [0]),
            ('positions', [(0, 0, 0), (0, 4096, 0), (0, 8192, 0)], [0]),
        ]),
        ('anmstatic', [
            ('bonerot', [(0, 0, 0, 16384)], [0]),
            ('scales', [(8192, 8192, 8192), (6144, 6144, 6144),
                        (2048, 2048, 2048)], [2, 1, 0]),
        ]),
    ]
    if include_object_rotation:
        groups[0][1].append((
            'rotations',
            [(0, 0, 0, 16384), (0, 0, 8192, 14189), (0, 0, 0, 16384)],
            [0],
        ))
    if bone_only:
        groups[0][1][:] = [track for track in groups[0][1] if track[0] != 'positions']
        groups[1][1][:] = [
            (name, values[:2], offsets[:2]) if name == 'scales'
            else (name, values, offsets)
            for name, values, offsets in groups[1][1]
        ]
        # The two-bone skeleton fixture uses scale indices 0 and 1.
        name, values, _ = groups[1][1][-1]
        groups[1][1][-1] = (name, values, [1, 0])
    if duplicate_target:
        groups[1][1].append(('bonepos', [(0, 0, 0)], [0]))
    for section_name, tracks in groups:
        group_start = len(records)
        pointer = section_pointers[section_name]
        records[pointer] = (
            0x30000003, group_start - pointer
            + (section_delta if section_name == 'anmdata' else 0),
        )
        pointers = {}
        for name, _, _ in tracks:
            records.append(text(name))
            pointers[name] = len(records)
            records.append((0x30000003, 0))
        for name, values, offsets in reversed(tracks):
            sample_start = len(records)
            pointer = pointers[name]
            records[pointer] = (
                0x30000003, sample_start - pointer
                + (sample_delta if name == 'positions' else 0),
            )
            quaternion = name in ('bonerot', 'rotations')
            width = 4 if quaternion else 3
            code = 'h' if quaternion else 'i'
            stride = width * (2 if quaternion else 4)
            flat = [component for value in values for component in value]
            data_section = len(sections)
            sections.append(struct.pack(f'<{len(flat)}{code}', *flat))
            offset_section = len(sections)
            sections.append(struct.pack(f'<{len(offsets)}H', *offsets))
            records.extend((
                text('type'), text('rawfixedsample'), text('data'),
                (descriptor(len(values), stride), data_section), text('offset'),
                (descriptor(len(offsets), 2), offset_section),
            ))

    reference_count = 2 if data_marker_in_references else 1
    raw = bytearray(
        b'1FDKENONCTX3' + struct.pack(
            '<IIII', len(strings), reference_count, 0, len(strings)))
    for value in strings:
        encoded = value.encode()
        identifier = (zlib.crc32(encoded) + len(encoded)) & 0xffffffff
        raw += struct.pack('<II', identifier, len(encoded)) + encoded + b'\0'
    raw += b'\0' * ((len(raw) - 0x1c) & 3)
    raw += bytes(strings.index(value) for value in ('skeletons/', 'hero', extension))
    if data_marker_in_references:
        raw += bytes((65, 0, 1))
    offsets = [0, 0]
    for section in sections[:-1]:
        offsets.append(offsets[-1] + len(section))
    payload = b''.join(sections)
    raw += b'DATA'
    raw += struct.pack('<IIII', len(records), len(sections), 0, len(payload))
    raw += struct.pack(f'<{len(offsets)}I', *offsets)
    for record in records:
        raw += struct.pack('<II', *record)
    raw += payload + b'animation-ident!'
    return bytes(raw)


class TestAnimationBinding(unittest.TestCase):
    def setUp(self):
        self.animation_raw = animation_fixture()
        self.skeleton_raw = object_skeleton_fixture()
        self.skeleton_hash = hashlib.sha256(self.skeleton_raw).hexdigest()

    def test_legacy_object_hierarchy_is_rejected_for_animation_binding(self):
        nodes = [
            ('root', 0, -2, 4, 0), ('object', 1, 0, 3, 1),
            ('bone', 2, 1, 2, 2), ('bone', 4, 2, 1, 3),
        ]
        skeleton_raw = skeleton_fixture(nodes)
        with self.assertRaisesRegex(KdfError, 'object transforms are missing or incomplete'):
            bind_animation(self.animation_raw, skeleton_raw)

    def test_partial_object_transforms_are_rejected_for_animation_binding(self):
        with self._mock_skeleton(lambda skeleton: skeleton['object_static_transforms'].pop()):
            with self.assertRaisesRegex(KdfError, 'object transforms are missing or incomplete'):
                bind_animation(self.animation_raw, self.skeleton_raw)

    def _mock_animation(self, mutation):
        animation = inspect_animation(
            self.animation_raw, include_values=True, decode_wavelet_values=True)
        mutation(animation)
        return patch('kdf_animation_binding.inspect_animation', return_value=animation)

    def _mock_skeleton(self, mutation):
        skeleton = inspect_skeleton(self.skeleton_raw)
        mutation(skeleton)
        return patch('kdf_animation_binding.inspect_skeleton', return_value=skeleton)

    def test_binding_maps_shuffled_indices_and_preserves_samples(self):
        result = bind_animation(self.animation_raw, self.skeleton_raw)
        self.assertEqual(result['status'], 'candidate')
        self.assertEqual(result['pairing_status'], 'unverified')
        self.assertEqual(result['skeleton_reference']['reference'], 'skeletons/hero.skl')
        for component in ('directory', 'basename', 'extension'):
            entry = result['skeleton_reference'][component]
            expected = entry['text'].encode('utf-8')
            self.assertEqual(
                self.animation_raw[entry['string_offset']:entry['string_offset'] + len(expected)],
                expected,
            )
        self.assertEqual(
            self.animation_raw[result['skeleton_reference']['key_record_offset']:
                               result['skeleton_reference']['key_record_offset'] + 4],
            struct.pack('<I', 0x60000000),
        )
        tracks = {(item['nodeid'], item['track']): item for item in result['bindings']}
        self.assertEqual(len(tracks), 6)
        self.assertEqual(tracks[(42, 'bonepos')]['values'], [
            [0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [2.0, 0.0, 0.0],
        ])
        self.assertEqual(tracks[(90, 'positions')]['values'][1], [0.0, 1.0, 0.0])
        self.assertEqual(tracks[(90, 'positions')]['layout'], 'per-frame')
        self.assertEqual(tracks[(90, 'positions')]['application_semantics'],
                         'root-motion-application-unverified')
        self.assertEqual(tracks[(17, 'scales')]['values'], [[2.0, 2.0, 2.0]])
        self.assertEqual(tracks[(42, 'scales')]['values'], [[1.5, 1.5, 1.5]])
        self.assertEqual(tracks[(90, 'scales')]['values'], [[0.5, 0.5, 0.5]])
        self.assertEqual(tracks[(42, 'bonerot')]['values'], [[0.0, 0.0, 0.0, 1.0]])
        self.assertEqual(tracks[(42, 'bonerot')]['layout'], 'constant')
        self.assertEqual(result['semantics']['transform_composition'], 'unverified')

    def test_object_rotation_track_uses_the_skeleton_object_index(self):
        result = bind_animation(
            animation_fixture(include_object_rotation=True), self.skeleton_raw)
        tracks = {(item['nodeid'], item['track']): item for item in result['bindings']}
        rotation = tracks[(17, 'rotations')]
        self.assertEqual(rotation['index_field'], 'object_rotation_index')
        self.assertEqual(rotation['offset'], 0)
        self.assertEqual(rotation['node_type'], 'object')
        self.assertEqual(rotation['target'], 'rotation')
        self.assertEqual(rotation['layout'], 'per-frame')
        self.assertEqual(rotation['decode_status'], 'decoded-fixed-point')
        self.assertEqual(rotation['values'][0], [0.0, 0.0, 0.0, 1.0])
        self.assertEqual(rotation['values'][1][2], 0.5)
        self.assertEqual(
            rotation['application_semantics'],
            'object-rotation-application-unverified')
        self.assertNotIn((90, 'rotations'), tracks)

    def test_provided_reference_and_full_hash_are_both_required(self):
        result = bind_animation(
            self.animation_raw, self.skeleton_raw,
            expected_reference='skeletons/hero.skl',
            expected_skeleton_sha256=self.skeleton_hash,
        )
        self.assertEqual(result['pairing_status'], 'matched-provided-reference-and-hash')
        for kwargs in (
                {'expected_reference': 'skeletons/hero.skl'},
                {'expected_skeleton_sha256': self.skeleton_hash},
                {'expected_reference': 'skeletons/HERO.skl',
                 'expected_skeleton_sha256': self.skeleton_hash},
                {'expected_reference': 'skeletons/hero.skl',
                 'expected_skeleton_sha256': '0' * 64}):
            with self.subTest(kwargs=kwargs):
                with self.assertRaises(KdfError):
                    bind_animation(self.animation_raw, self.skeleton_raw, **kwargs)

    def test_header_reference_must_be_unique_typed_and_in_bounds(self):
        for kwargs in (
                {'reference_marker': 0x70000001},
                {'reference_id': 1},
                {'extension': 'anm'},
                {'duplicate_header': True}):
            with self.subTest(kwargs=kwargs):
                with self.assertRaises(KdfError):
                    bind_animation(animation_fixture(**kwargs), self.skeleton_raw)

    def test_context_and_container_must_find_same_data_boundary(self):
        def wrong_boundary(raw):
            result = parse_context(raw)
            result['data_offset'] += 1
            return result
        with patch('kdf_animation_binding.parse_context', side_effect=wrong_boundary):
            with self.assertRaisesRegex(KdfError, 'explicit DATA offset is invalid'):
                bind_animation(self.animation_raw, self.skeleton_raw)

    def test_reference_table_data_bytes_do_not_confuse_binding(self):
        raw = animation_fixture(data_marker_in_references=True)
        context = parse_context(raw)
        self.assertEqual(raw[context['reference_start']:context['reference_start'] + 4],
                         b'DATA')
        # Legacy scanning rejects the decoy, but binding uses the exact context
        # boundary and must still accept this structurally valid fixture.
        with self.assertRaises(KdfError):
            parse_container(raw)
        result = bind_animation(raw, self.skeleton_raw)
        self.assertEqual(result['skeleton_reference']['reference'], 'skeletons/hero.skl')
        self.assertEqual(len(result['bindings']), 6)

    def test_section_and_sample_pointers_are_validated(self):
        for kwargs in ({'section_delta': 1}, {'sample_delta': 1}):
            with self.subTest(kwargs=kwargs):
                with self.assertRaises(KdfError):
                    bind_animation(animation_fixture(**kwargs), self.skeleton_raw)
        with self._mock_animation(lambda animation: animation['track_groups'][0].pop('source_section')):
            with self.assertRaisesRegex(KdfError, 'missing verified source'):
                bind_animation(self.animation_raw, self.skeleton_raw)

    def test_duplicate_node_and_target_are_rejected(self):
        with self.assertRaisesRegex(KdfError, 'duplicate node and target'):
            bind_animation(animation_fixture(duplicate_target=True), self.skeleton_raw)

    def test_header_profile_and_missing_groups_are_rejected(self):
        for headers in (
                {'version': 8}, {'pose': 0}, {'firstframe': 1},
                {'duration': 0}, {'framerate': 0}):
            with self.subTest(headers=headers):
                with self.assertRaises(KdfError):
                    bind_animation(
                        animation_fixture(header_overrides=headers), self.skeleton_raw)
        with self._mock_animation(lambda animation: animation.update(track_groups=[])):
            with self.assertRaisesRegex(KdfError, 'track groups are missing'):
                bind_animation(self.animation_raw, self.skeleton_raw)

    def test_skeleton_domains_reject_duplicate_wrong_type_and_out_of_range(self):
        def duplicate_scale(skeleton):
            skeleton['nodes'][1]['scale_index'] = skeleton['nodes'][2]['scale_index']
        def wrong_type(skeleton):
            skeleton['nodes'][1]['bone_position_index'] = 1
        def out_of_range(skeleton):
            skeleton['nodes'][1]['object_position_index'] = 4
        for mutation in (duplicate_scale, wrong_type, out_of_range):
            with self.subTest(mutation=mutation.__name__):
                with self._mock_skeleton(mutation):
                    with self.assertRaises(KdfError):
                        bind_animation(self.animation_raw, self.skeleton_raw)

    def test_offsets_and_rawfixed_dimensions_are_checked(self):
        def invalid_offset(animation):
            track = animation['track_groups'][0]['tracks'][0]
            track['sample']['offsets']['values'][0] = 99
        def multiple_dynamic_offsets(animation):
            track = animation['track_groups'][0]['tracks'][0]
            offsets = track['sample']['offsets']
            offsets['values'] = [0, 1]
            offsets['element_count'] = 2
        def invalid_components(animation):
            track = animation['track_groups'][0]['tracks'][0]
            track['sample']['data']['decoded']['values'][0] = [1.0, 2.0]
        def invalid_static_count(animation):
            track = animation['track_groups'][1]['tracks'][0]
            track['sample']['data']['decoded']['values'].pop()
        for mutation in (invalid_offset, multiple_dynamic_offsets,
                         invalid_components, invalid_static_count):
            with self.subTest(mutation=mutation.__name__):
                with self._mock_animation(mutation):
                    with self.assertRaises(KdfError):
                        bind_animation(self.animation_raw, self.skeleton_raw)

    def test_nonfinite_values_are_rejected(self):
        def invalid_value(animation):
            track = animation['track_groups'][0]['tracks'][0]
            track['sample']['data']['decoded']['values'][0] = [math.nan, 0.0, 0.0]
        with self._mock_animation(invalid_value):
            with self.assertRaisesRegex(KdfError, 'non-finite'):
                bind_animation(self.animation_raw, self.skeleton_raw)

    def test_wavelet_candidate_requires_data_section_and_exact_shape(self):
        def make_wavelet(animation):
            track = animation['track_groups'][0]['tracks'][0]
            sample = track['sample']
            sample['codec'] = 'waveletsample'
            sample['decode_status'] = 'decoded-wavelet-candidate'
            sample['wavelet'] = {'decoded': {
                'sample_count': 3, 'components_per_track': 3, 'channel_count': 3,
                'values': [
                    [[0.0, 0.0, 0.0]], [[1.0, 0.0, 0.0]], [[2.0, 0.0, 0.0]],
                ],
            }}
        with self._mock_animation(make_wavelet):
            result = bind_animation(self.animation_raw, self.skeleton_raw)
            item = next(item for item in result['bindings'] if item['track'] == 'positions')
            self.assertEqual(item['codec'], 'waveletsample')
            self.assertEqual(item['values'][1], [1.0, 0.0, 0.0])
        def missing_frame(animation):
            make_wavelet(animation)
            animation['track_groups'][0]['tracks'][0]['sample']['wavelet']['decoded']['values'].pop()
        def wrong_frame_width(animation):
            make_wavelet(animation)
            animation['track_groups'][0]['tracks'][0]['sample']['wavelet']['decoded']['values'][0] = []
        def wavelet_in_static(animation):
            sample = animation['track_groups'][1]['tracks'][0]['sample']
            sample['codec'] = 'waveletsample'
            sample['decode_status'] = 'decoded-wavelet-candidate'
        for mutation in (missing_frame, wrong_frame_width, wavelet_in_static):
            with self.subTest(mutation=mutation.__name__):
                with self._mock_animation(mutation):
                    with self.assertRaises(KdfError):
                        bind_animation(self.animation_raw, self.skeleton_raw)


if __name__ == '__main__':
    unittest.main()

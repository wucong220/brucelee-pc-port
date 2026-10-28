import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_data import KdfError
from kdf_wavelet import decode_wavelet


def fixture_words() -> list[int]:
    # One approximation, three independent scalar channels, and a tree with
    # one internal node and two terminal nodes. These are invented values.
    return [
        1, 5, 100, 200, (-100) & 0xffffffff,
        8, 9, 0x4c000000, 0xc0000000, 0x90000000,
    ]


def decode_fixture(words=None, **overrides):
    words = fixture_words() if words is None else words
    arguments = {
        'sample_count': 4,
        'channels': 3,
        'components': 3,
        'element_bytes': 4,
        'approximations': 1,
        'radix': 0,
        'huffman_entries': [(0, 2, 4, 0)],
        'huffman_symbols': [0, 1, -2, 2],
        'include_values': True,
    }
    arguments.update(overrides)
    return decode_wavelet(struct.pack(f'<{len(words)}I', *words), **arguments)


class TestWaveletDecoder(unittest.TestCase):
    def test_two_branches_stop_flag_and_adjacent_frame_values(self):
        result = decode_fixture()
        self.assertEqual(result['values'], [
            [[97.0, 200.0, -98.0]],
            [[101.0, 200.0, -98.0]],
            [[103.0, 200.0, -103.0]],
            [[99.0, 200.0, -101.0]],
        ])
        self.assertEqual(result['nonzero_padding_streams'], 0)
        self.assertEqual(result['native_runtime_comparison'], 'unverified')

    def test_cross_word_codes_and_an_odd_sample_count(self):
        # 18 symbols require 36 bits in each internal/terminal stream.
        words = (
            [1, 20] + [0] * 18 + [24, 26, 0x55555555, 0x50000000]
            + [0xaaaaaaaa, 0xa0000000, 0xaaaaaaaa, 0xa0000000]
        )
        result = decode_fixture(
            words, sample_count=3, channels=18, components=3,
        )
        self.assertEqual(len(result['values']), 3)
        self.assertEqual(result['values'][0], [[1.0, 1.0, 1.0]] * 6)
        self.assertEqual(result['values'][1], [[-3.0, -3.0, -3.0]] * 6)
        self.assertEqual(result['values'][2], [[3.0, 3.0, 3.0]] * 6)
        self.assertEqual(result['nonzero_padding_streams'], 0)

    def test_invalid_huffman_code_is_rejected(self):
        words = fixture_words()
        words[7] = 0xc0000000
        with self.assertRaisesRegex(KdfError, 'Huffman code is invalid'):
            decode_fixture(
                words, huffman_entries=[(0, 2, 3, 0)],
                huffman_symbols=[0, 1, -2])

    def test_truncated_child_and_control_bit_are_rejected(self):
        words = fixture_words()
        words[6] = len(words)
        with self.assertRaisesRegex(KdfError, 'child is outside'):
            decode_fixture(words)
        words = fixture_words()
        # A one-bit nonzero code followed by a 31-bit zero code leaves no
        # room for the zero code's control bit.
        words[7] = 0x80000000
        with self.assertRaisesRegex(KdfError, 'control bit crosses'):
            decode_fixture(
                words, huffman_entries=[
                    (0, 31, 1, 0), (0x80000000, 1, 1, 1),
                ], huffman_symbols=[0, 1])

    def test_32_bit_zero_codes_are_outside_the_supported_profile(self):
        with self.assertRaisesRegex(KdfError, '32-bit zero'):
            decode_fixture(
                huffman_entries=[(0, 32, 1, 0)], huffman_symbols=[0])

    def test_overlapping_huffman_prefixes_are_rejected(self):
        with self.assertRaisesRegex(KdfError, 'prefixes overlap'):
            decode_fixture(
                huffman_entries=[(0, 1, 1, 0), (0x40000000, 2, 1, 1)],
                huffman_symbols=[0, 1])

    def test_nonzero_padding_is_reported_without_changing_decoded_values(self):
        words = fixture_words()
        words[7] |= 1
        result = decode_fixture(words)
        self.assertEqual(result['values'][0], [[97.0, 200.0, -98.0]])
        self.assertEqual(result['nonzero_padding_streams'], 1)

    def test_missing_child_uses_the_current_channel_difference(self):
        words = fixture_words()
        words[6] = 0
        result = decode_fixture(words)
        self.assertEqual(result['values'][2:], [
            [[101.0, 200.0, -102.0]],
            [[101.0, 200.0, -102.0]],
        ])

    def test_integer_operations_wrap_before_float32_conversion(self):
        words = fixture_words()
        words[2] = 0x80000000
        result = decode_fixture(words)
        self.assertEqual(result['values'][0][0][0], 2147483648.0)
        self.assertEqual(result['values'][1][0][0], -2147483648.0)
        self.assertEqual(result['values'][2][0][0], -2147483648.0)
        self.assertEqual(result['values'][3][0][0], 2147483648.0)


if __name__ == '__main__':
    unittest.main()

#!/usr/bin/env python3
"""Decode the bounded, observed KDF wavelet animation profile.

The channel values follow the statically traced native decoder. Bone binding,
coordinate conventions, and comparison with a running original remain separate
validation steps.
"""
from __future__ import annotations

from bisect import bisect_right
import struct

from kdf_data import KdfError

_MAX_WORDS = 65_535
_MAX_SAMPLES = 65_535
_MAX_SCALARS = 2_000_000


def _signed32(value: int) -> int:
    value &= 0xffffffff
    return value if value < 0x80000000 else value - 0x100000000


def _float32(value: float) -> float:
    return struct.unpack('<f', struct.pack('<f', value))[0]


def _validate_huffman(
        entries: list[tuple[int, int, int, int]],
        symbols: list[int]) -> tuple[list[int], list[tuple[int, int, int, int]]]:
    if not entries or not symbols:
        raise KdfError('wavelet Huffman table is empty')
    starts = []
    previous_end = 0
    next_symbol = 0
    for prefix, length, count, start in entries:
        if not 1 <= length <= 32 or count <= 0:
            raise KdfError('wavelet Huffman code length or count is invalid')
        shift = 32 - length
        if prefix < 0 or prefix > 0xffffffff or prefix & ((1 << shift) - 1):
            raise KdfError('wavelet Huffman prefix is not left aligned')
        end = prefix + (count << shift)
        if end > 1 << 32 or prefix < previous_end:
            raise KdfError('wavelet Huffman prefixes overlap or are out of order')
        if start != next_symbol:
            raise KdfError('wavelet Huffman symbol ranges are not contiguous')
        if length == 32 and 0 in symbols[start:start + count]:
            raise KdfError('wavelet 32-bit zero Huffman codes are unsupported')
        starts.append(prefix)
        previous_end = end
        next_symbol += count
    if next_symbol != len(symbols):
        raise KdfError('wavelet Huffman symbols do not match the table')
    return starts, entries


def _stream_bounds(
        words: tuple[int, ...], roots: int, channels: int,
        element_bytes: int, first_mask: int) -> tuple[dict[int, int], dict[int, int]]:
    if roots <= 0 or roots > len(words) or words[0] != roots:
        raise KdfError('wavelet approximation root table is invalid')
    root_offsets = words[:roots]
    if (root_offsets[0] != roots
            or any(a >= b for a, b in zip(root_offsets, root_offsets[1:]))
            or root_offsets[-1] >= len(words)):
        raise KdfError('wavelet approximation roots are out of bounds')

    internal_bounds: dict[int, int] = {}
    leaf_bounds: dict[int, int] = {}
    for ordinal, root in enumerate(root_offsets):
        end = root_offsets[ordinal + 1] if ordinal + 1 < roots else len(words)
        first = root + 1 + (channels * element_bytes + 3) // 4
        if words[root] == 0:
            # Some animations carry an unused zeroed approximation root, seen in
            # m01_pnch_low_02. It has no channel array, so it contributes no
            # stream bounds.
            continue
        if first >= end or words[root] != first:
            raise KdfError('wavelet initial channel array or first node is invalid')
        pending = [(first, first_mask)]
        internal: dict[int, int] = {}
        leaves: set[int] = set()
        while pending:
            node, mask = pending.pop()
            if node == 0:
                continue
            if not first <= node < end:
                raise KdfError('wavelet node is outside its approximation')
            if mask <= 1:
                if node in internal:
                    raise KdfError('wavelet node is both an internal node and a leaf')
                leaves.add(node)
                continue
            if node in leaves:
                raise KdfError('wavelet node is both an internal node and a leaf')
            if node in internal:
                if internal[node] != mask:
                    raise KdfError('wavelet node is used at inconsistent depths')
                continue
            if node + 2 > end:
                raise KdfError('wavelet node header is truncated')
            internal[node] = mask
            for child in words[node:node + 2]:
                if child:
                    if not first <= child < end:
                        raise KdfError('wavelet child is outside its approximation')
                    pending.append((child, mask >> 1))

        starts = sorted(internal.keys() | leaves)
        for index, node in enumerate(starts):
            bound = starts[index + 1] if index + 1 < len(starts) else end
            if node in internal:
                if node + 2 > bound:
                    raise KdfError('wavelet internal node overlaps another stream')
                internal_bounds[node] = bound
            else:
                leaf_bounds[node] = bound
    return internal_bounds, leaf_bounds


class _Bits:
    def __init__(
            self, words: tuple[int, ...], start: int, end: int,
            prefixes: list[int], entries: list[tuple[int, int, int, int]],
            symbols: list[int]):
        self.words = words
        self.start = start
        self.end = end
        self.prefixes = prefixes
        self.entries = entries
        self.symbols = symbols
        self.position = 0

    def _window(self) -> int:
        index = self.start + self.position // 32
        offset = self.position % 32
        if index >= self.end:
            raise KdfError('wavelet bitstream ended before a Huffman code')
        current = (self.words[index] << offset) & 0xffffffff
        # The native decoder reads the next word for lookahead. Zero extension
        # here is safe only because symbol() also checks the consumed code length.
        following = self.words[index + 1] if index + 1 < self.end else 0
        return current | ((following >> (32 - offset)) if offset else 0)

    def symbol(self) -> int:
        window = self._window()
        ordinal = bisect_right(self.prefixes, window) - 1
        if ordinal < 0:
            raise KdfError('wavelet bitstream has no matching Huffman prefix')
        prefix, length, count, start = self.entries[ordinal]
        index = (window - prefix) >> (32 - length)
        if index >= count or self.start * 32 + self.position + length > self.end * 32:
            raise KdfError('wavelet Huffman code is invalid or crosses a stream boundary')
        self.position += length
        return self.symbols[start + index]

    def bit(self) -> int:
        absolute = self.start * 32 + self.position
        if absolute >= self.end * 32:
            raise KdfError('wavelet control bit crosses a stream boundary')
        value = (self.words[absolute // 32] >> (31 - absolute % 32)) & 1
        self.position += 1
        return value

    def remaining_is_zero(self) -> bool:
        absolute = self.start * 32 + self.position
        if absolute >= self.end * 32:
            return True
        word_index, offset = divmod(absolute, 32)
        if self.words[word_index] & ((1 << (32 - offset)) - 1):
            return False
        return not any(self.words[word_index + 1:self.end])


def decode_wavelet(
        data: bytes, *, sample_count: int, channels: int, components: int,
        element_bytes: int, approximations: int, radix: int,
        huffman_entries: list[tuple[int, int, int, int]],
        huffman_symbols: list[int], include_values: bool = False) -> dict:
    """Decode observed even/odd channel pairs with bounded stream reads."""
    if len(data) % 4 or not 1 <= len(data) // 4 <= _MAX_WORDS:
        raise KdfError('wavelet data word count is invalid')
    if (not 1 <= sample_count <= _MAX_SAMPLES or channels <= 0
            or components not in (3, 4)
            or channels % components or sample_count * channels > _MAX_SCALARS):
        raise KdfError('wavelet sample or channel count is invalid or too large')
    if element_bytes not in (2, 4) or not 0 <= radix <= 30:
        raise KdfError('wavelet integer width or quantization radix is unsupported')
    words = struct.unpack(f'<{len(data) // 4}I', data)
    prefixes, entries = _validate_huffman(huffman_entries, huffman_symbols)
    mask_start = (1 << (sample_count - 1).bit_length()) >> 1
    first_mask = mask_start
    root_bits = 0
    while (1 << root_bits) < approximations:
        first_mask >>= 1
        root_bits += 1
    internal_bounds, leaf_bounds = _stream_bounds(
        words, approximations, channels, element_bytes, first_mask)
    scale = _float32(1.0 / (1 << radix))
    values: list[list[list[float]]] = []
    preview: list[list[list[float]]] = []
    nonzero_padding: set[tuple[int, int]] = set()
    padding_cache: dict[tuple[int, int, int], bool] = {}

    def store_result(integer: int) -> float:
        return _float32(_float32(_signed32(integer)) * scale)

    def remember_padding(bits: _Bits) -> None:
        key = (bits.start, bits.end, bits.position)
        if key not in padding_cache:
            padding_cache[key] = bits.remaining_is_zero()
        if not padding_cache[key]:
            nonzero_padding.add((bits.start, bits.end))

    for frame in range(0, sample_count, 2):
        mask = mask_start
        root_index = 0
        for _ in range(root_bits):
            root_index = (root_index << 1) | bool(frame & mask)
            mask >>= 1
        if root_index >= approximations:
            raise KdfError('wavelet frame selects a missing approximation')
        root = words[root_index]
        code = 'i' if element_bytes == 4 else 'h'
        initial = struct.unpack_from(f'<{channels}{code}', data, (root + 1) * 4)
        state = [[0, value] for value in initial]
        active = list(range(channels))
        pairs: list[tuple[float, float] | None] = [None] * channels
        node = words[root]

        while mask > 1 and node and active:
            if node not in internal_bounds:
                raise KdfError('wavelet frame selected an invalid internal node')
            branch = int(bool(frame & mask))
            next_node = words[node + branch]
            bits = _Bits(
                words, node + 2, internal_bounds[node], prefixes, entries,
                huffman_symbols)
            remaining = []
            for channel in active:
                symbol = bits.symbol()
                state[channel][branch] = _signed32(state[channel][branch] + symbol)
                stopped = symbol == 0 and bits.bit() == 1
                if stopped:
                    value = store_result(state[channel][1] - state[channel][0])
                    pairs[channel] = (value, value)
                else:
                    remaining.append(channel)
            remember_padding(bits)
            active = remaining
            node = next_node
            mask >>= 1

        if active and node and mask <= 1:
            if node not in leaf_bounds:
                raise KdfError('wavelet frame selected an invalid terminal node')
            bits = _Bits(
                words, node, leaf_bounds[node], prefixes, entries, huffman_symbols)
            for channel in active:
                symbol = bits.symbol()
                difference = _signed32(state[channel][1] - state[channel][0])
                pairs[channel] = (
                    store_result(difference - symbol),
                    store_result(difference + symbol),
                )
            remember_padding(bits)
        else:
            for channel in active:
                value = store_result(state[channel][1] - state[channel][0])
                pairs[channel] = (value, value)

        for side in range(min(2, sample_count - frame)):
            flat = [pair[side] for pair in pairs if pair is not None]
            if len(flat) != channels:
                raise KdfError('wavelet did not produce every channel')
            grouped = [flat[i:i + components] for i in range(0, channels, components)]
            if frame + side < 2:
                preview.append(grouped[:3])
            if include_values:
                values.append(grouped)

    result = {
        'sample_count': sample_count,
        'channel_count': channels,
        'components_per_track': components,
        'scale': scale,
        'value_preview': preview,
        'values_omitted': not include_values,
        'nonzero_padding_streams': len(nonzero_padding),
        'native_runtime_comparison': 'unverified',
    }
    if include_values:
        result['values'] = values
    return result

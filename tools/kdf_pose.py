#!/usr/bin/env python3
"""Compose candidate local animation poses using the traced pose=1 path."""
from __future__ import annotations

import math
from typing import Iterable

from kdf_data import KdfError


def _vector(values: Iterable[float], size: int, label: str) -> tuple[float, ...]:
    result = tuple(values)
    if len(result) != size or not all(math.isfinite(value) for value in result):
        raise KdfError(f'{label} must have {size} finite components')
    return result


def _quaternion(values: Iterable[float], label: str) -> tuple[float, float, float, float]:
    value = _vector(values, 4, label)
    norm = math.hypot(*value)
    if not math.isfinite(norm) or norm <= 1e-12:
        raise KdfError(f'{label} must have nonzero length')
    return value


def compose_translation(
        rest_translation: Iterable[float], rest_rotation: Iterable[float],
        animated_translation: Iterable[float]) -> tuple[float, float, float]:
    """Apply t_rest + R_rest * t_anim; scale is not part of this path."""
    translation = _vector(rest_translation, 3, 'rest translation')
    x, y, z, w = _quaternion(rest_rotation, 'rest rotation')
    if abs(math.hypot(x, y, z, w) - 1.0) > 1e-5:
        raise KdfError('rest rotation must be approximately unit length')
    dx, dy, dz = _vector(animated_translation, 3, 'animated translation')
    rotation = (
        (1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)),
        (2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)),
        (2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)),
    )
    return tuple(
        translation[row] + rotation[row][0] * dx
        + rotation[row][1] * dy + rotation[row][2] * dz
        for row in range(3)
    )


def compose_rotation(
        rest_rotation: Iterable[float],
        animated_rotation: Iterable[float]) -> tuple[float, float, float, float]:
    """Multiply XYZW quaternions in native order: q_rest * q_anim."""
    x, y, z, w = _quaternion(rest_rotation, 'rest rotation')
    if abs(math.hypot(x, y, z, w) - 1.0) > 1e-5:
        raise KdfError('rest rotation must be approximately unit length')
    a, b, c, d = _quaternion(animated_rotation, 'animated rotation')
    return (
        x * d + w * a + y * c - z * b,
        y * d + w * b + z * a - x * c,
        z * d + w * c + x * b - y * a,
        w * d - x * a - y * b - z * c,
    )


def normalize_rotation(values: Iterable[float]) -> tuple[float, float, float, float]:
    """Normalize an XYZW quaternion for a target requiring unit rotations."""
    value = _quaternion(values, 'rotation')
    norm = math.hypot(*value)
    return tuple(component / norm for component in value)


def closest_quaternion(
        previous: Iterable[float], current: Iterable[float],
        ) -> tuple[float, float, float, float]:
    """Choose the equivalent sign in the previous quaternion's hemisphere."""
    before = _quaternion(previous, 'previous rotation')
    after = _quaternion(current, 'current rotation')
    if sum(a * b for a, b in zip(before, after, strict=True)) < 0:
        return tuple(-component for component in after)
    return after

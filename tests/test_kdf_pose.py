import math
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_data import KdfError
from kdf_pose import (
    closest_quaternion,
    compose_rotation,
    compose_translation,
    normalize_rotation,
)


class TestPoseComposition(unittest.TestCase):
    def assertVectorAlmostEqual(self, actual, expected):
        self.assertEqual(len(actual), len(expected))
        for left, right in zip(actual, expected, strict=True):
            self.assertAlmostEqual(left, right, places=7)

    def test_translation_is_rotated_before_adding_rest_translation(self):
        half = math.sqrt(0.5)
        result = compose_translation((10, 20, 30), (0, 0, half, half), (1, 2, 3))
        self.assertVectorAlmostEqual(result, (8, 21, 33))
        # Applying a non-unit rest scale first would instead give (4, 22, 42).
        self.assertNotEqual(tuple(round(v) for v in result), (4, 22, 42))

    def test_rotation_order_is_rest_then_animation(self):
        half = math.sqrt(0.5)
        rest_z = (0, 0, half, half)
        animated_x = (half, 0, 0, half)
        self.assertVectorAlmostEqual(
            compose_rotation(rest_z, animated_x), (0.5, 0.5, 0.5, 0.5))
        self.assertVectorAlmostEqual(
            compose_rotation(animated_x, rest_z), (0.5, -0.5, 0.5, 0.5))

    def test_identity_delta_preserves_rest_pose(self):
        half = math.sqrt(0.5)
        rest = (0, 0, half, half)
        self.assertVectorAlmostEqual(compose_translation((3, 4, 5), rest, (0, 0, 0)),
                                     (3, 4, 5))
        self.assertVectorAlmostEqual(compose_rotation(rest, (0, 0, 0, 1)), rest)

    def test_normalization_and_equivalent_sign_selection(self):
        first = normalize_rotation((0, 0, 2, 2))
        second = closest_quaternion(first, (0, 0, -2, -2))
        self.assertVectorAlmostEqual(normalize_rotation(second), first)

    def test_invalid_quaternions_and_nonfinite_values_fail(self):
        for call in (
                lambda: normalize_rotation((0, 0, 0, 0)),
                lambda: compose_translation((0, 0, 0), (0, 0, 0, 2), (1, 2, 3)),
                lambda: compose_rotation((0, 0, 0, 1), (math.nan, 0, 0, 1)),
                lambda: compose_translation((math.inf, 0, 0), (0, 0, 0, 1), (0, 0, 0)),
        ):
            with self.assertRaises(KdfError):
                call()


if __name__ == '__main__':
    unittest.main()

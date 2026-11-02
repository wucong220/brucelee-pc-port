import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from merge_glb_animations import _read_glb, _write_glb, merge  # noqa: E402


def _fixture(path: Path, animation_name: str, value: float) -> None:
    payload = struct.pack("<f", value)
    document = {
        "asset": {"version": "2.0"},
        "nodes": [{"name": "root"}],
        "buffers": [{"byteLength": len(payload)}],
        "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": len(payload)}],
        "accessors": [{
            "bufferView": 0,
            "componentType": 5126,
            "count": 1,
            "type": "SCALAR",
            "min": [value],
            "max": [value],
        }],
        "animations": [{
            "name": animation_name,
            "samplers": [{"input": 0, "output": 0, "interpolation": "LINEAR"}],
            "channels": [{"sampler": 0, "target": {"node": 0, "path": "translation"}}],
        }],
    }
    _write_glb(path, document, payload)


class MergeGlbAnimationsTest(unittest.TestCase):
    def test_merges_animation_and_remaps_node(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            base = root / "base.glb"
            add = root / "add.glb"
            out = root / "merged.glb"
            _fixture(base, "base", 1.0)
            _fixture(add, "victim", 2.0)
            report = merge(base, add, out)
            self.assertEqual(report["animation_count"], 2)
            document, binary = _read_glb(out)
            self.assertEqual([a["name"] for a in document["animations"]], ["base", "victim"])
            self.assertEqual(document["nodes"], [{"name": "root"}])
            self.assertEqual(len(binary), 8)
            self.assertAlmostEqual(struct.unpack("<f", binary[:4])[0], 1.0)
            self.assertAlmostEqual(struct.unpack("<f", binary[4:8])[0], 2.0)

    def test_rejects_duplicate_animation_name(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            base = root / "base.glb"
            add = root / "add.glb"
            _fixture(base, "same", 1.0)
            _fixture(add, "same", 2.0)
            with self.assertRaises(Exception):
                merge(base, add, root / "merged.glb")


if __name__ == "__main__":
    unittest.main()

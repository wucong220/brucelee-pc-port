import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_data import KdfError
from kdf_object import inspect_object


def object_fixture(*, bad_reference=False) -> bytes:
    strings = [
        'objects/', 'body', 'mesh', 'shaders/', 'character', 'shd',
        'position', 'rotation', 'scale',
    ]
    references = bytearray((0, 1, 2, 3, 4, 5))
    if bad_reference:
        references[0] = 255
    records = [
        (0x60000000, strings.index('mesh')),
        (0x70000000, 0),
        (0x60000000, strings.index('character')),
        (0x70000000, 1),
        (0x60000000, strings.index('position')),
        (0x41800001, 0),
        (0x60000000, strings.index('rotation')),
        (0x42000001, 1),
        (0x60000000, strings.index('scale')),
        (0x41800001, 2),
    ]
    payload = (
        struct.pack('<3f', 1, 2, 3)
        + struct.pack('<4f', 0, 0, 0, 1)
        + struct.pack('<3f', 1, 1, 1)
    )
    offsets = (0, 0, 12, 28)

    raw = bytearray(b'1FDKENONCTX3' + struct.pack(
        '<IIII', len(strings), 2, 0, len(strings)))
    for text in strings:
        encoded = text.encode()
        identifier = (zlib.crc32(encoded) + len(encoded)) & 0xffffffff
        raw += struct.pack('<II', identifier, len(encoded)) + encoded + b'\0'
    raw += references
    raw += b'DATA'
    raw += struct.pack('<IIII', len(records), 3, 0, len(payload))
    raw += struct.pack(f'<{len(offsets)}I', *offsets)
    for record in records:
        raw += struct.pack('<II', *record)
    raw += payload + b'object-ident!!!!'
    return bytes(raw)


class TestKdfObject(unittest.TestCase):
    def test_external_references_and_pose_transforms(self):
        result = inspect_object(object_fixture())
        self.assertEqual(result['external_reference_count'], 2)
        self.assertEqual(
            [entry['path'] for entry in result['external_references']],
            ['objects/body.mesh', 'shaders/character.shd'],
        )
        self.assertEqual(result['external_reference_uses'], [
            {'record_ordinal': 1, 'property': 'mesh', 'reference_id': 0},
            {'record_ordinal': 3, 'property': 'character', 'reference_id': 1},
        ])
        self.assertEqual(result['pose_transform_count'], 1)
        self.assertEqual(result['pose_transforms'][0]['position'], [1.0, 2.0, 3.0])
        self.assertEqual(result['mesh_payload_status'], 'external-resource')
        self.assertEqual(result['scene_tree_status'], 'unresolved')

    def test_invalid_reference_table_is_rejected(self):
        with self.assertRaisesRegex(KdfError, 'invalid string index'):
            inspect_object(object_fixture(bad_reference=True))
        raw = bytearray(object_fixture())
        struct.pack_into('<I', raw, 0x10, 3)
        with self.assertRaisesRegex(KdfError, 'external reference table'):
            inspect_object(bytes(raw))

    def test_cli_outputs_object_json(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / 'test.obj'
            source.write_bytes(object_fixture())
            script = Path(__file__).resolve().parents[1] / 'tools' / 'kdf_object.py'
            run = subprocess.run(
                [sys.executable, '-X', 'utf8', str(script), str(source)],
                capture_output=True, text=True, encoding='utf-8', check=False,
            )
            self.assertEqual(run.returncode, 0, run.stderr)
            report = json.loads(run.stdout)
            self.assertEqual(report['pose_transform_count'], 1)



    def test_relative_scene_dictionary_links_pose_sections(self):
        strings = [
            "scene", "childs", "type", "frame", "object", "properties",
            "position", "rotation", "scale", "pelvis",
        ]
        records = [
            (0x30000001, 1),
            (0x60000000, strings.index("scene")),
            (0x30000003, 1),
            (0x60000000, strings.index("childs")),
            (0x30000001, 5),
            (0x60000000, strings.index("type")),
            (0x60000000, strings.index("frame")),
            (0x60000000, strings.index("properties")),
            (0x30000003, 13),
            (0x60000000, strings.index("pelvis")),
            (0x30000002, 1),
            (0x60000000, strings.index("type")),
            (0x60000000, strings.index("object")),
            (0x60000000, strings.index("properties")),
            (0x30000003, 1),
            (0x60000000, strings.index("position")),
            (0x41800001, 3),
            (0x60000000, strings.index("rotation")),
            (0x42000001, 4),
            (0x60000000, strings.index("scale")),
            (0x41800001, 5),
            (0x60000000, strings.index("position")),
            (0x41800001, 0),
            (0x60000000, strings.index("rotation")),
            (0x42000001, 1),
            (0x60000000, strings.index("scale")),
            (0x41800001, 2),
        ]
        payload = b"".join((
            struct.pack("<3f", 1, 2, 3),
            struct.pack("<4f", 0, 0, 0, 1),
            struct.pack("<3f", 1, 1, 1),
            struct.pack("<3f", 4, 5, 6),
            struct.pack("<4f", 0, 0, 0, 1),
            struct.pack("<3f", 1, 1, 1),
        ))
        offsets = (0, 0, 12, 28, 40, 52, 68)
        raw = bytearray(b"1FDKENONCTX3" + struct.pack(
            "<IIII", len(strings), 0, 0, len(strings)))
        for text in strings:
            encoded = text.encode()
            identifier = (zlib.crc32(encoded) + len(encoded)) & 0xffffffff
            raw += struct.pack("<II", identifier, len(encoded)) + encoded + b"\0"
        raw += b"DATA"
        raw += struct.pack("<IIII", len(records), 6, 0, len(payload))
        raw += struct.pack(f"<{len(offsets)}I", *offsets)
        for record in records:
            raw += struct.pack("<II", *record)
        raw += payload + b"object-ident!!!!"
        result = inspect_object(bytes(raw))
        self.assertEqual(result["scene_tree_status"], "relative-dictionary")
        self.assertEqual(
            [(node["name"], node["parent"], node["type"]) for node in result["scene_nodes"]],
            [("scene", None, "frame"), ("pelvis", "scene", "object")],
        )
        self.assertEqual(result["scene_nodes"][1]["position_section"], 3)


if __name__ == '__main__':
    unittest.main()

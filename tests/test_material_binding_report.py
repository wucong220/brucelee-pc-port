from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from kdf_data import KdfError
from material_binding_report import build_report


def object_report():
    references = [
        {'ordinal': 0, 'path': 'objects/hair_hw_skhigh.mesh'},
        {'ordinal': 1, 'path': 'objects/hair/textures/diffuse.tex'},
        {'ordinal': 2, 'path': 'objects/hair/textures/normal.tex'},
        {'ordinal': 3, 'path': 'objects/hair/textures/material.tex'},
        {'ordinal': 4, 'path': 'objects/body_hw_skhigh.mesh'},
        {'ordinal': 5, 'path': 'objects/body/textures/diffuse.tex'},
        {'ordinal': 6, 'path': 'objects/body/textures/normal.tex'},
        {'ordinal': 7, 'path': 'objects/body/textures/material.tex'},
    ]
    uses = [
        {'record_ordinal': 10, 'property': 'mesh', 'reference_id': 0},
        {'record_ordinal': 12, 'property': 'diffuse', 'reference_id': 1},
        {'record_ordinal': 13, 'property': 'normal', 'reference_id': 2},
        {'record_ordinal': 14, 'property': 'material', 'reference_id': 3},
        {'record_ordinal': 20, 'property': 'mesh', 'reference_id': 4},
        {'record_ordinal': 22, 'property': 'diffuse', 'reference_id': 5},
        {'record_ordinal': 23, 'property': 'normal', 'reference_id': 6},
        {'record_ordinal': 24, 'property': 'material', 'reference_id': 7},
    ]
    return {
        'sha256': 'object-hash',
        'decoded_bytes': 100,
        'external_references': references,
        'external_reference_uses': uses,
    }


def program_report():
    return {
        'sha256': 'program-hash',
        'decoded_bytes': 200,
        'texture_constants': [
            {'name': 'diffuse'},
            {'name': 'normal'},
            {'name': 'material'},
        ],
    }


class TestMaterialBindingReport(unittest.TestCase):
    def test_builds_hair_and_body_mappings(self):
        result = build_report(object_report(), program_report())
        self.assertEqual(result['evidence_level'], 'STATIC_VERIFIED')
        self.assertEqual(result['program_texture_constants'], [
            'diffuse', 'normal', 'material',
        ])
        self.assertEqual(
            result['bindings']['hair']['textures']['normal']['reference_id'],
            2,
        )
        self.assertEqual(
            result['bindings']['body']['textures']['material']['path'],
            'objects/body/textures/material.tex',
        )

    def test_rejects_missing_texture_property(self):
        source = object_report()
        source['external_reference_uses'] = [
            use for use in source['external_reference_uses']
            if not (use['record_ordinal'] == 13)
        ]
        with self.assertRaisesRegex(KdfError, 'missing texture properties: normal'):
            build_report(source, program_report())


if __name__ == '__main__':
    unittest.main()
